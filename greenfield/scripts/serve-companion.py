#!/usr/bin/env python3
"""Greenfield visual-companion HTTP server.

Reads state from --state, writes click intents to --intent.
Binds to localhost:0 (kernel picks free port), prints port to --port-file.
Exits when /shutdown is POSTed or SIGTERM received.

No external dependencies. Python 3 stdlib only.
"""
import argparse
import http.server
import json
import pathlib
import signal
import socketserver
import sys
import threading
import time

class Handler(http.server.BaseHTTPRequestHandler):
    state_path: pathlib.Path
    intent_path: pathlib.Path
    assets_dir: pathlib.Path
    adr_dir: pathlib.Path
    shutdown_event: threading.Event

    def log_message(self, fmt, *args):
        # Quiet by default.
        pass

    def _send(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            try:
                body = (self.assets_dir / "index.html").read_bytes()
            except FileNotFoundError:
                self._send(500, b'{"error":"asset not found \xe2\x80\x94 check --assets-dir"}'); return
            self._send(200, body, "text/html; charset=utf-8")
        elif self.path == "/styles.css":
            try:
                body = (self.assets_dir / "styles.css").read_bytes()
            except FileNotFoundError:
                self._send(500, b'{"error":"asset not found \xe2\x80\x94 check --assets-dir"}'); return
            self._send(200, body, "text/css; charset=utf-8")
        elif self.path == "/companion.js":
            try:
                body = (self.assets_dir / "companion.js").read_bytes()
            except FileNotFoundError:
                self._send(500, b'{"error":"asset not found \xe2\x80\x94 check --assets-dir"}'); return
            self._send(200, body, "application/javascript; charset=utf-8")
        elif self.path == "/state.json":
            try:
                body = self.state_path.read_bytes()
                self._send(200, body)
            except FileNotFoundError:
                self._send(503, b'{"error":"state not yet rendered"}')
        elif self.path.startswith("/adr/"):
            name = self.path[len("/adr/"):]
            safe = pathlib.Path(name).name + ".html"
            target = self.adr_dir / safe
            if target.exists():
                self._send(200, target.read_bytes(), "text/html; charset=utf-8")
            else:
                self._send(404, b'{"error":"adr not found"}')
        else:
            self._send(404, b'{"error":"not found"}')

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""
        if self.path == "/intent":
            try:
                payload = json.loads(body)
            except json.JSONDecodeError:
                self._send(400, b'{"error":"invalid JSON"}'); return
            if payload.get("action") != "activate" or "phase" not in payload:
                self._send(400, b'{"error":"missing action=activate or phase"}'); return
            try:
                state = json.loads(self.state_path.read_text())
                phases = state.get("phases", {})
                if payload["phase"] in phases:
                    target_phase = phases[payload["phase"]]
                    if target_phase.get("status") not in ("AVAILABLE", "PARKED"):
                        self._send(409, b'{"error":"phase not activatable"}'); return
                for k, v in phases.items():
                    if v.get("status") == "IN_PROGRESS":
                        self._send(409, b'{"error":"another phase is in progress"}'); return
            except FileNotFoundError:
                pass
            tmp = self.intent_path.with_suffix(f".{threading.get_ident()}.json.tmp")
            payload["ts"] = int(time.time())
            tmp.write_text(json.dumps(payload))
            tmp.replace(self.intent_path)
            self._send(202, b'{"status":"accepted"}')
        elif self.path == "/shutdown":
            self._send(200, b'{"status":"shutting down"}')
            self.shutdown_event.set()
        else:
            self._send(404, b'{"error":"not found"}')

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--intent", required=True)
    p.add_argument("--port-file", required=True)
    p.add_argument("--assets-dir", required=True)
    p.add_argument("--adr-dir", required=True)
    p.add_argument("--prefer-ports", default="38271,38272,38273")
    args = p.parse_args()

    Handler.state_path = pathlib.Path(args.state).resolve()
    Handler.intent_path = pathlib.Path(args.intent).resolve()
    Handler.assets_dir = pathlib.Path(args.assets_dir).resolve()
    Handler.adr_dir = pathlib.Path(args.adr_dir).resolve()
    shutdown_event = threading.Event()
    Handler.shutdown_event = shutdown_event

    server = None
    for port_str in args.prefer_ports.split(",") + ["0"]:
        port = int(port_str)
        try:
            server = socketserver.TCPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue
    if server is None:
        print("ERROR: could not bind any local port", file=sys.stderr)
        sys.exit(3)

    actual_port = server.server_address[1]
    pathlib.Path(args.port_file).write_text(str(actual_port))

    def _term(signum, frame):
        shutdown_event.set()
    signal.signal(signal.SIGTERM, _term)
    signal.signal(signal.SIGINT, _term)

    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    shutdown_event.wait()
    server.shutdown()
    server.server_close()

if __name__ == "__main__":
    main()
