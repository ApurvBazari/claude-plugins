#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
echo '{"top":{"present":"yes"}}' > "$TMP"

# Branch 1: required=true with missing path → must exit non-zero
# Run in a subshell so the exit doesn't kill this test.
if ( _validate_jq_path "$TMP" '.top.missing' "true" ) >/dev/null 2>&1; then
  echo "FAIL: required=true with missing path should exit non-zero"
  exit 1
fi

# Branch 2: required=false with missing path → does not exit non-zero;
# helper prints jq's default for missing keys (empty or "null"), never aborts.
OUT=$(_validate_jq_path "$TMP" '.top.missing' "false")
[[ -z "$OUT" || "$OUT" == "null" ]] || { echo "FAIL: required=false with missing path should print empty or null, got '$OUT'"; exit 1; }

# Sanity: required=true with present path → prints value
OUT2=$(_validate_jq_path "$TMP" '.top.present' "true")
[[ "$OUT2" == "yes" ]] || { echo "FAIL: required=true with present path — got '$OUT2'"; exit 1; }

echo "validate_jq_path: OK"
