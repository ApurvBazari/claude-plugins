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
# convergence fields — optional + field-additive (must NOT enter required); iteration stays render-only.
top=s["properties"]
assert top["severityTrend"]["type"]=="string", "severityTrend must be a string"
assert set(top["severityTrend"]["enum"])=={"improving","same","regressed"}, \
    f"severityTrend enum must be improving/same/regressed, got {top['severityTrend']['enum']}"
assert top["delta"]["type"]=="object", "delta must be an object"
for k in ("fixed","new","stillOpen"):
    assert top["delta"]["properties"][k]["type"]=="integer", f"delta.{k} must be integer"
for k in ("delta","severityTrend"):
    assert k not in s.get("required",[]), f"{k} must stay optional (field-additive superset)"
print("PASS: schema integer-type parity + 9-value dimension enum + convergence fields")
PY
