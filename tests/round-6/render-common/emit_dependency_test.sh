#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export DEPS_PATH="${TMPDIR}/deps.json"

_emit_dependency "search" "dataArchitecture.entities[0].id" '"E001"' "Index scope"

# Verify file exists and contains valid JSON
[[ -f "$DEPS_PATH" ]] || { echo "FAIL: deps.json not created"; exit 1; }
jq -e . "$DEPS_PATH" >/dev/null || { echo "FAIL: deps.json is not valid JSON"; exit 1; }

# Verify shape
SCHEMA=$(jq -r '.schemaVersion' "$DEPS_PATH")
[[ "$SCHEMA" == "1" ]] || { echo "FAIL: schemaVersion mismatch (got '$SCHEMA')"; exit 1; }

PHASE=$(jq -r '.phase' "$DEPS_PATH")
[[ "$PHASE" == "search" ]] || { echo "FAIL: phase mismatch (got '$PHASE')"; exit 1; }

LEN=$(jq '.dependencies | length' "$DEPS_PATH")
[[ "$LEN" == "1" ]] || { echo "FAIL: expected 1 dependency, got $LEN"; exit 1; }

PATH_VAL=$(jq -r '.dependencies[0].path' "$DEPS_PATH")
[[ "$PATH_VAL" == "dataArchitecture.entities[0].id" ]] || { echo "FAIL: path mismatch (got '$PATH_VAL')"; exit 1; }

VAL=$(jq -r '.dependencies[0].value' "$DEPS_PATH")
[[ "$VAL" == "E001" ]] || { echo "FAIL: value mismatch (got '$VAL')"; exit 1; }

RATIONALE=$(jq -r '.dependencies[0].rationale' "$DEPS_PATH")
[[ "$RATIONALE" == "Index scope" ]] || { echo "FAIL: rationale mismatch (got '$RATIONALE')"; exit 1; }

echo "emit_dependency: OK"
