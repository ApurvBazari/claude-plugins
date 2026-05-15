#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

FIX="${SCRIPT_DIR}/alpha-3-fixture.json"
EXP="${SCRIPT_DIR}/alpha-7-expected.json"

ACTUAL=$(cat "$FIX" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-3-to-4.sh" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-4-to-5.sh" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-5-to-6.sh" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-6-to-7.sh" \
  | jq -S . )

EXPECTED=$(jq -S . "$EXP")

# Compare ignoring dynamic timestamps
A_NORM=$(echo "$ACTUAL"   | jq 'del(.meta.migrations[].at) | del(.phaseStatus[]?.lastModified)')
E_NORM=$(echo "$EXPECTED" | jq 'del(.meta.migrations[].at) | del(.phaseStatus[]?.lastModified)')

if [[ "$A_NORM" != "$E_NORM" ]]; then
  echo "FAIL: actual vs expected diff:"
  diff <(echo "$A_NORM") <(echo "$E_NORM") | head -40
  exit 1
fi

# Sanity checks
COUNT=$(echo "$ACTUAL" | jq '.meta.migrations | length')
[[ "$COUNT" == "4" ]] || { echo "FAIL: expected 4 migrations, got $COUNT"; exit 1; }

SCHEMA=$(echo "$ACTUAL" | jq -r '.meta.schemaVersion')
[[ "$SCHEMA" == "alpha.7" ]] || { echo "FAIL: expected schemaVersion alpha.7, got $SCHEMA"; exit 1; }

echo "golden-output: OK"
