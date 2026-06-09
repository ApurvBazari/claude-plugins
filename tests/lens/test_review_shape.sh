#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEMA="$ROOT/lens/schemas/review-findings.schema.json"
FIX="$ROOT/tests/lens/fixtures/engine-output-sample.json"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$SCHEMA" ] || fail "schema missing"; [ -s "$FIX" ] || fail "fixture missing"
python3 - "$SCHEMA" "$FIX" <<'PY' || fail "fixture does not match schema"
import json,sys
schema=json.load(open(sys.argv[1])); doc=json.load(open(sys.argv[2]))
assert {"findings","recommendedEscalation","degraded"} <= set(doc), "missing top-level keys"
assert doc["recommendedEscalation"] in {"minor","moderate","major","critical"}
dims=set(schema["properties"]["findings"]["items"]["properties"]["dimension"]["enum"])
sev={"critical","high","medium","low"}
for f in doc["findings"]:
    assert {"id","title","severity","dimension","verified"} <= set(f), f"finding missing keys: {f.get('id')}"
    assert f["severity"] in sev and f["dimension"] in dims
print("PASS: review-findings contract")
PY
