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
# F1 — emptyScope discriminator: must exist as boolean, must NOT be required
# (field-additive — vicario's validator ignores it; only the dimension enum is co-owned)
assert top["emptyScope"]["type"]=="boolean", "emptyScope must be a boolean property"
assert "emptyScope" not in s.get("required",[]), \
    "emptyScope must stay optional (field-additive; vicario must not require it)"
# L3 — adherence item shape is declared (additive: properties only, never required,
# no additionalProperties:false — matali payloads valid under 1.4.1 must stay valid).
adh = top["adherence"]
assert adh["type"] == "object", "adherence must be an object"
assert "adherence" not in s.get("required", []), "adherence must stay optional (field-additive)"
si = adh["properties"]["specItems"]
ps = adh["properties"]["planSteps"]
assert si["type"] == "array" and ps["type"] == "array", "specItems/planSteps must be arrays"
si_props = si["items"]["properties"]
ps_props = ps["items"]["properties"]
for k in ("label", "state", "sourceSpec"):
    assert k in si_props, f"specItems.items must declare '{k}' property"
for k in ("label", "state", "sourcePlan"):
    assert k in ps_props, f"planSteps.items must declare '{k}' property"
# additive-safety: the item objects must NOT force required keys or seal additionalProperties,
# or a valid 1.4.1 adherence payload (e.g. flat single-spec items lacking sourceSpec) would be rejected.
assert "required" not in si["items"] and "required" not in ps["items"], \
    "adherence item objects must not add a required[] (would reject 1.4.1-valid payloads)"
assert si["items"].get("additionalProperties", True) is not False, "specItems.items must not seal additionalProperties"
assert ps["items"].get("additionalProperties", True) is not False, "planSteps.items must not seal additionalProperties"
print("PASS: schema integer-type parity + 9-value dimension enum + convergence fields + emptyScope + adherence item shape")
PY
