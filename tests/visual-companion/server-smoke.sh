#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export CLAUDE_PLUGIN_ROOT="${ROOT}/greenfield"
WORKDIR=$(mktemp -d)
mkdir -p "${WORKDIR}/docs/adr"
cat > "${WORKDIR}/state.json" <<EOF
{"phases":{"architecturalFraming":{"status":"AVAILABLE"}}}
EOF
cat > "${WORKDIR}/docs/adr/architectural-framing.html" <<EOF
<!doctype html><html><body>arch framing ADR</body></html>
EOF

[ -f "${CLAUDE_PLUGIN_ROOT}/scripts/visual-companion-assets/index.html" ] \
  || { echo "FAIL: visual-companion-assets/index.html missing — is CLAUDE_PLUGIN_ROOT set correctly?"; rm -rf "$WORKDIR"; exit 1; }

PORT_FILE="${WORKDIR}/port.txt"
PID_FILE="${WORKDIR}/pid.txt"
INTENT="${WORKDIR}/intent.json"

cd "$WORKDIR"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/serve-companion.sh" \
  --state "${WORKDIR}/state.json" \
  --intent "$INTENT" \
  --port-file "$PORT_FILE" \
  --pid-file "$PID_FILE" \
  --no-launch
PORT=$(cat "$PORT_FILE")
SERVER_PID=$(cat "$PID_FILE")

cleanup() {
  curl -sS -X POST "http://127.0.0.1:$PORT/shutdown" >/dev/null 2>&1 || true
  sleep 0.3
  kill -0 "$SERVER_PID" 2>/dev/null && kill "$SERVER_PID" 2>/dev/null || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "## GET / returns index.html"
curl -sS "http://127.0.0.1:$PORT/" | grep -qi 'html' || { echo "FAIL"; exit 1; }
echo "  ok"

echo "## GET /state.json returns the fixture"
curl -sS "http://127.0.0.1:$PORT/state.json" | jq -e '.phases.architecturalFraming.status == "AVAILABLE"' >/dev/null \
  || { echo "FAIL"; exit 1; }
echo "  ok"

echo "## POST /intent (valid) writes intent file"
curl -sS -X POST -H "Content-Type: application/json" \
  -d '{"action":"activate","phase":"architecturalFraming"}' \
  "http://127.0.0.1:$PORT/intent" | jq -e '.status == "accepted"' >/dev/null \
  || { echo "FAIL: POST /intent did not return accepted"; exit 1; }
sleep 0.2
[ -f "$INTENT" ] && jq -e '.phase == "architecturalFraming"' "$INTENT" >/dev/null || { echo "FAIL: intent file not written"; exit 1; }
echo "  ok"

echo "## POST /intent (LOCKED phase) returns 409"
echo '{"phases":{"dataArchitecture":{"status":"LOCKED"}}}' > "${WORKDIR}/state.json"
rm -f "$INTENT"
STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"action":"activate","phase":"dataArchitecture"}' \
  "http://127.0.0.1:$PORT/intent")
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409, got $STATUS"; exit 1; }
[ ! -f "$INTENT" ] || { echo "FAIL: intent file written for LOCKED phase"; exit 1; }
echo "  ok"

echo "## GET /adr/architectural-framing returns the synthesis HTML"
curl -sS "http://127.0.0.1:$PORT/adr/architectural-framing" | grep -q 'arch framing ADR' \
  || { echo "FAIL"; exit 1; }
echo "  ok"

echo "## POST /shutdown stops the server"
curl -sS -X POST "http://127.0.0.1:$PORT/shutdown" >/dev/null
# Python's serve_forever() polls every 0.5s by default, so the server can
# take up to ~0.5s to notice the shutdown_event. Poll up to 3s in 100ms
# steps to avoid a flaky 0.3s race.
for _ in $(seq 1 30); do
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "FAIL: server still running 3s after /shutdown"; exit 1
fi
echo "  ok"
