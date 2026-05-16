#!/usr/bin/env bash
# Greenfield visual-companion server wrapper.
# Starts serve-companion.py in the background, returns the chosen port,
# optionally launches the browser, manages pid file.

set -euo pipefail

STATE=""
INTENT=""
PORT_FILE=""
PID_FILE=""
LAUNCH_BROWSER="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)       STATE="$2"; shift 2 ;;
    --intent)      INTENT="$2"; shift 2 ;;
    --port-file)   PORT_FILE="$2"; shift 2 ;;
    --pid-file)    PID_FILE="$2"; shift 2 ;;
    --no-launch)   LAUNCH_BROWSER="false"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$STATE" ] && [ -n "$INTENT" ] && [ -n "$PORT_FILE" ] && [ -n "$PID_FILE" ] \
  || { echo "usage: $0 --state S --intent I --port-file P --pid-file PID [--no-launch]" >&2; exit 2; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q '^Python 3'; then
  PY=python
else
  echo "ERROR: python3 not found. Visual companion requires Python 3 (stdlib only)." >&2
  echo "Hint: install via your OS package manager, or run with linear-wizard fallback." >&2
  exit 4
fi

ASSETS_DIR="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}/scripts/visual-companion-assets"
ADR_DIR="${PWD}/docs/adr"
mkdir -p "$ADR_DIR"

if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
  if [ -n "$OLD_PID" ] && ! kill -0 "$OLD_PID" 2>/dev/null; then
    rm -f "$PID_FILE" "$PORT_FILE"
  fi
fi

nohup "$PY" "${CLAUDE_PLUGIN_ROOT}/scripts/serve-companion.py" \
  --state "$STATE" \
  --intent "$INTENT" \
  --port-file "$PORT_FILE" \
  --assets-dir "$ASSETS_DIR" \
  --adr-dir "$ADR_DIR" \
  >/dev/null 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"

for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$PORT_FILE" ] && break
  sleep 0.5
done
if [ ! -s "$PORT_FILE" ]; then
  kill "$SERVER_PID" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "ERROR: server failed to bind a port within 5 seconds" >&2
  exit 5
fi

PORT=$(cat "$PORT_FILE")
URL="http://localhost:$PORT/"
echo "Visual companion serving at $URL (PID $SERVER_PID)"

if [ "$LAUNCH_BROWSER" = "true" ] && [ -z "${SSH_CONNECTION:-}" ]; then
  case "$(uname -s)" in
    Darwin)  open "$URL" 2>/dev/null || true ;;
    Linux)   xdg-open "$URL" 2>/dev/null || true ;;
    MINGW*|MSYS*|CYGWIN*) cmd /c start "" "$URL" 2>/dev/null || true ;;
  esac
fi

if [ -n "${SSH_CONNECTION:-}" ]; then
  echo "SSH detected. Forward this port from your local machine:"
  echo "  ssh -L $PORT:localhost:$PORT <your-ssh-target>"
fi
