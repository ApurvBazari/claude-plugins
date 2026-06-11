#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEMA="$ROOT/lens/schemas/review-findings.schema.json"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$SCHEMA" ] || fail "schema missing"
python3 - "$SCHEMA" <<'PY' || fail "schema integer-type parity"
import json,sys
s=json.load(open(sys.argv[1]))
props=s["properties"]["findings"]["items"]["properties"]
assert props["line"]["type"]=="integer", "line must be integer (vicario parity)"
v=props["votes"]["properties"]
for k in ("total","couldNotRefute","refuted"):
    assert v[k]["type"]=="integer", f"votes.{k} must be integer (vicario parity)"
print("PASS: schema integer-type parity")
PY
