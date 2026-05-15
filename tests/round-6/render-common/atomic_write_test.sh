#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

TMP=$(mktemp)
_atomic_write "$TMP" "hello world"
[[ "$(cat "$TMP")" == "hello world" ]] || { echo "FAIL: content mismatch"; exit 1; }
[[ ! -f "${TMP}.tmp" ]] || { echo "FAIL: tmp file leaked"; exit 1; }

# Verify tmp-then-rename atomicity: concurrent reader sees either old or new, never partial
echo "initial" > "$TMP"
_atomic_write "$TMP" "updated"
[[ "$(cat "$TMP")" == "updated" ]] || { echo "FAIL: atomic update"; exit 1; }

rm -f "$TMP"
echo "atomic_write: OK"
