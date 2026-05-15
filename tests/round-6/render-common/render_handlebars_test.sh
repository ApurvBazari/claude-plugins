#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

# Case 1: Simple {{key}} substitution
OUT1=$(_render_handlebars 'Hello {{name}}' '{"name":"world"}')
[[ "$OUT1" == "Hello world" ]] || { echo "FAIL: simple substitution — got '$OUT1'"; exit 1; }

# Case 2: Nested {{a.b}} substitution
OUT2=$(_render_handlebars 'X={{a.b}}' '{"a":{"b":"42"}}')
[[ "$OUT2" == "X=42" ]] || { echo "FAIL: nested substitution — got '$OUT2'"; exit 1; }

# Case 3: Missing key → empty replacement
OUT3=$(_render_handlebars 'Hi {{missing}}' '{}')
[[ "$OUT3" == "Hi " ]] || { echo "FAIL: missing key — got '$OUT3'"; exit 1; }

echo "render_handlebars: OK"
