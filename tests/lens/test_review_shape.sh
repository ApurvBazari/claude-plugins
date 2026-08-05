#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEMA="$ROOT/lens/schemas/review-findings.schema.json"
FIX="$ROOT/tests/lens/fixtures/engine-output-sample.json"
DEGRADED="$ROOT/tests/lens/fixtures/engine-output-degraded-sample.json"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$SCHEMA" ] || fail "schema missing"
[ -s "$FIX" ] || fail "fixture missing"
[ -s "$DEGRADED" ] || fail "degraded fixture missing"

# GLOB the fixture list so any future engine-output-*.json fixture is auto-covered by the shape
# and bidirectional-degrade checks below, rather than requiring an explicit arg per new fixture.
FIXTURES=("$ROOT"/tests/lens/fixtures/engine-output-*.json)

python3 - "$SCHEMA" "$FIX" "$DEGRADED" "${FIXTURES[@]}" <<'PY' || fail "fixture does not match schema"
import json,sys
schema=json.load(open(sys.argv[1]))
dims=set(schema["properties"]["findings"]["items"]["properties"]["dimension"]["enum"])
sev={"critical","high","medium","low"}
def check(path):
    doc=json.load(open(path))
    assert {"findings","recommendedEscalation","degraded"} <= set(doc), f"{path}: missing top-level keys"
    assert doc["recommendedEscalation"] in {"minor","moderate","major","critical"}, f"{path}: bad escalation"
    assert isinstance(doc["degraded"], bool), f"{path}: degraded must be a bool"
    for f in doc["findings"]:
        assert {"id","title","severity","dimension","verified"} <= set(f), f"{path}: finding missing keys: {f.get('id')}"
        assert f["severity"] in sev and f["dimension"] in dims, f"{path}: bad severity/dimension in {f.get('id')}"
    # U2 — bidirectional invariant: degraded:true if and only if degradedReasons[] is non-empty,
    # checked uniformly across every engine-output-*.json fixture (present + future).
    assert bool(doc.get("degradedReasons")) == doc["degraded"], (
        f"{path}: degraded ({doc['degraded']}) must agree with degradedReasons "
        f"non-emptiness ({doc.get('degradedReasons')})"
    )
    return doc

for p in sys.argv[4:]:
    check(p)

# Nominal path — pinned by name (not glob position), so the by-name checks below survive
# regardless of how many fixtures the glob picks up or in what order.
nominal=check(sys.argv[2])
assert nominal["degraded"] is False, "nominal fixture should have degraded:false"
assert not nominal.get("degradedReasons"), "nominal fixture must omit degradedReasons (or leave it empty)"
# Degraded path — verify-error / null-finder / reconstructed-intent / truncation. This is the
# branch the only prior fixture never exercised; this very review run sets degraded:true.
deg=check(sys.argv[3])
assert deg["degraded"] is True, "degraded fixture must set degraded:true"
assert deg.get("degradedReasons"), "degraded fixture must carry a non-empty degradedReasons[]"
assert any(f["verified"] is False for f in deg["findings"]), \
    "degraded fixture must exercise an unverified-flagged finding (verified:false)"
print("PASS: review-findings contract (nominal + degraded, globbed fixtures)")
PY

# L5 — lens dispatches ONE verifier per finding; the sample fixture's votes.total must be 1
# (a 3-vote panel is matali/vicario behavior, not lens).
python3 - "$FIX" <<'PY' || fail "sample fixture votes.total must be 1 (single verifier)"
import json, sys
d = json.load(open(sys.argv[1]))
for fnd in d["findings"]:
    v = fnd.get("votes")
    if v is not None:
        assert v["total"] == 1, f"{fnd['id']}: votes.total must be 1 (lens runs one verifier), got {v['total']}"
        assert v["couldNotRefute"] + v["refuted"] <= v["total"], f"{fnd['id']}: vote tallies exceed total"
print("PASS: sample fixture single-verifier votes")
PY
