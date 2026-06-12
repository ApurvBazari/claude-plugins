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
python3 - "$SCHEMA" "$FIX" "$DEGRADED" <<'PY' || fail "fixture does not match schema"
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
    return doc
# Nominal path.
nominal=check(sys.argv[2])
assert nominal["degraded"] is False, "nominal fixture should have degraded:false"
# Degraded path — verify-error / null-finder / reconstructed-intent / truncation. This is the
# branch the only prior fixture never exercised; this very review run sets degraded:true.
deg=check(sys.argv[3])
assert deg["degraded"] is True, "degraded fixture must set degraded:true"
assert any(f["verified"] is False for f in deg["findings"]), \
    "degraded fixture must exercise an unverified-flagged finding (verified:false)"
print("PASS: review-findings contract (nominal + degraded)")
PY
