#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESOLVER="${ROOT}/greenfield/scripts/resolve-phase-status.sh"
GRAPH="${ROOT}/greenfield/skills/visual-companion/references/phase-graph.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

run() {
  cat > "${TMP}/state.json"
  bash "$RESOLVER" --graph "$GRAPH" --state "${TMP}/state.json"
}

echo "## library appType: domainModel hidden"
run <<'EOF' | jq -e '.phases.domainModel.status == "HIDDEN"' >/dev/null \
  || { echo "FAIL"; exit 1; }
{"phase0":{"appType":"library"},"synthesisStatus":{},"parkedPhases":[]}
EOF
echo "  ok"

echo "## prototype scale: i18nL10n hidden"
run <<'EOF' | jq -e '.phases.i18nL10n.status == "HIDDEN"' >/dev/null \
  || { echo "FAIL"; exit 1; }
{"phase0":{"appType":"web","scale":"prototype"},"synthesisStatus":{"architecturalFraming":"approved","apiIntegration":"approved","frontendArchitecture":"approved"},"parkedPhases":[]}
EOF
echo "  ok"

echo "## commerceUser:false hides payments"
run <<'EOF' | jq -e '.phases.payments.status == "HIDDEN"' >/dev/null \
  || { echo "FAIL: payments should be hidden"; exit 1; }
{"phase0":{"appType":"web","scale":"team","personas":[{"label":"buyer","commerceUser":false}]},"synthesisStatus":{},"parkedPhases":[]}
EOF
echo "  ok (hidden)"

echo "## commerceUser:true keeps payments visible"
run <<'EOF' | jq -e '.phases.payments.status != "HIDDEN"' >/dev/null \
  || { echo "FAIL: payments should NOT be hidden when commerceUser=true"; exit 1; }
{"phase0":{"appType":"web","scale":"team","personas":[{"label":"buyer","commerceUser":true}]},"synthesisStatus":{},"parkedPhases":[]}
EOF
echo "  ok (visible)"

echo "## api appType: frontendArchitecture hidden"
run <<'EOF' | jq -e '.phases.frontendArchitecture.status == "HIDDEN"' >/dev/null \
  || { echo "FAIL"; exit 1; }
{"phase0":{"appType":"api","scale":"team"},"synthesisStatus":{},"parkedPhases":[]}
EOF
echo "  ok"

echo "## HIDDEN beats LOCKED: cli app with approved apiIntegration still hides frontendArchitecture"
run <<'EOF' | jq -e '.phases.frontendArchitecture.status == "HIDDEN"' >/dev/null \
  || { echo "FAIL"; exit 1; }
{"phase0":{"appType":"cli","scale":"prototype"},"synthesisStatus":{"architecturalFraming":"approved","apiIntegration":"approved"},"parkedPhases":[]}
EOF
echo "  ok"
