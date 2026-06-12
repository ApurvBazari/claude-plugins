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
# The dimension enum is the canonical 9-value SHARED contract (vicario's six + lens's
# test/risk/comment). Assert it EXACTLY: a subset check would let test/risk/comment be deleted
# silently (every other test still passes), and an extra value would diverge from the co-owned
# vicario enum. Lock both directions here.
expected={"requirements","correctness","security","types","silent-failure","simplify","test","risk","comment"}
dims=props["dimension"]["enum"]
assert len(dims)==len(expected) and set(dims)==expected, \
    f"dimension enum must be exactly the 9 canonical shared values, got {dims}"
print("PASS: schema integer-type parity + 9-value dimension enum")
PY
