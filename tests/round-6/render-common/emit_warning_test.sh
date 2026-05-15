#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

RESULT=$(_emit_warning "warn" "W-test" "msg" "[]")

# Assert: array length is 1
LEN=$(jq 'length' <<< "$RESULT")
[[ "$LEN" == "1" ]] || { echo "FAIL: expected length 1, got $LEN"; exit 1; }

# Assert: first entry has id="W-test"
ID=$(jq -r '.[0].id' <<< "$RESULT")
[[ "$ID" == "W-test" ]] || { echo "FAIL: id mismatch (got '$ID')"; exit 1; }

# Assert: level="warn"
LEVEL=$(jq -r '.[0].level' <<< "$RESULT")
[[ "$LEVEL" == "warn" ]] || { echo "FAIL: level mismatch (got '$LEVEL')"; exit 1; }

# Assert: message="msg"
MSG=$(jq -r '.[0].message' <<< "$RESULT")
[[ "$MSG" == "msg" ]] || { echo "FAIL: message mismatch (got '$MSG')"; exit 1; }

# Assert: addressed=false
ADDR=$(jq -r '.[0].addressed' <<< "$RESULT")
[[ "$ADDR" == "false" ]] || { echo "FAIL: addressed should be false (got '$ADDR')"; exit 1; }

echo "emit_warning: OK"
