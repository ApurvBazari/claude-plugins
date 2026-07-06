#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }
ok(){ echo "ok: $1"; }

PS="$ROOT/walkthrough/skills/create/references/page-scaffold.md"

# --- Task 1: page-scaffold structural contract ---
[ -s "$PS" ] || fail "missing $PS"
grep -q 'type="application/json" id="wt-data"' "$PS" || fail "scaffold must emit inert <script type=application/json id=wt-data>"
grep -q '{{DATA_JSON}}' "$PS"                        || fail "scaffold must have the {{DATA_JSON}} slot"
grep -q '<script>{{INTERACTIVITY_JS}}</script>' "$PS" || fail "interactivity must be its own <script>"
grep -q '<script>{{COMPONENT_JS}}</script>' "$PS"     || fail "component JS must be its own <script>"
grep -q 'html.js section' "$PS"                       || fail "scaffold must gate the hidden state on html.js"
! grep -q '{{DETAIL_DATA}}' "$PS"                     || fail "scaffold must retire the {{DETAIL_DATA}} slot"
! grep -q '{{SURFACE_MAP}}' "$PS"                     || fail "scaffold must retire the {{SURFACE_MAP}} slot"
ok "page-scaffold: three-block + json-data island + html.js gate"

# --- Task 2: interactivity js-gate + JSON.parse(DET/SURF) + failsafe ---
IJ="$ROOT/walkthrough/skills/create/references/interactivity.md"
[ -s "$IJ" ] || fail "missing $IJ"
grep -q "classList.add('js')" "$IJ"        || fail "interactivity must add the html.js class as its first act"
grep -q "getElementById('wt-data')" "$IJ"  || fail "interactivity must read the #wt-data island"
grep -q 'JSON.parse' "$IJ"                 || fail "interactivity must JSON.parse the data island"
grep -qE "add\('vis'\)\),?2500|2500\)" "$IJ" || fail "interactivity must have the 2.5s failsafe reveal timer"
ok "interactivity: js-gate + JSON.parse(DET/SURF) + failsafe"

# --- Task 3: golden new-layout artifact — self-contained + parse-valid + js-gated ---
FIX="$ROOT/tests/walkthrough/fixtures/failure-arch-sample.html"
[ -s "$FIX" ] || fail "missing new-layout fixture $FIX"
# self-contained
! grep -qE '<script[^>]*src=' "$FIX"        || fail "fixture: <script src> — not self-contained"
! grep -qiE '<link[^>]*stylesheet' "$FIX"   || fail "fixture: external stylesheet"
! grep -q '<img' "$FIX"                      || fail "fixture: <img> present"
# visible-unless-JS: html.js gate present, no bare section{opacity:0}
grep -q 'html.js section' "$FIX"            || fail "fixture: hidden state not gated on html.js"
# parse validity: every executable <script> node --check-clean; #wt-data is valid JSON with no raw </script>
python3 - "$FIX" <<'PY' || fail "fixture: script/json validation failed (see above)"
import re,sys,subprocess,json,shutil
html=open(sys.argv[1]).read()
node=shutil.which("node")
# json island
m=re.search(r'<script type="application/json" id="wt-data">(.*?)</script>',html,re.S)
if not m: print("no #wt-data island"); sys.exit(1)
raw=m.group(1)
if "</script" in raw: print("raw </script> inside #wt-data (must be <\\/script)"); sys.exit(1)
try: json.loads(raw)
except Exception as e: print("#wt-data not valid JSON:",e); sys.exit(1)
# every OTHER <script> must node --check (skip the json island)
if not node: print("SKIP node --check (node not installed)"); sys.exit(0)
for sm in re.finditer(r'<script(?![^>]*application/json)[^>]*>(.*?)</script>',html,re.S):
    body=sm.group(1)
    open("/tmp/wt_chk.js","w").write(body)
    r=subprocess.run([node,"--check","/tmp/wt_chk.js"],capture_output=True,text=True)
    if r.returncode: print("node --check failed:",r.stderr); sys.exit(1)
print("ok: fixture scripts node-check clean, #wt-data valid JSON")
PY
ok "fixture: self-contained + parse-valid + js-gated"

# --- Task 4: self-check #20 is an executed node --check + JSON-island validation ---
SC="$ROOT/walkthrough/skills/create/references/self-check.md"
[ -s "$SC" ] || fail "missing $SC"
grep -qi 'node --check' "$SC" || fail "self-check #20 must require an executed node --check"
grep -qi 'JSON.parse\|application/json' "$SC" || fail "self-check #20 must validate the #wt-data island"
ok "self-check: #20 is executed node --check + JSON validation"

# --- Task 5: reconstruct three-layout probe + per-layout fixtures ---
RM="$ROOT/walkthrough/skills/update/references/reconstruct-and-merge.md"
[ -s "$RM" ] || fail "missing $RM"
grep -q 'wt-data' "$RM"                  || fail "reconstruct must detect the new #wt-data JSON layout"
grep -qi 'application/json' "$RM"        || fail "reconstruct must parse the JSON island for the new layout"
grep -q 'const SURF' "$RM"               || fail "reconstruct must keep the structured inline-const layout branch"
grep -qiE 'flat|k,h,b|pre-1.1' "$RM"     || fail "reconstruct must keep the pre-1.1.0 flat-DET branch"
ok "reconstruct: three-layout probe documented"

for f in new structured flat; do
  FF="$ROOT/tests/walkthrough/fixtures/reconstruct-$f.html"; [ -s "$FF" ] || fail "missing $FF"
done
grep -q 'id="wt-data"' "$ROOT/tests/walkthrough/fixtures/reconstruct-new.html" || fail "new fixture must carry #wt-data"
grep -q 'const SURF' "$ROOT/tests/walkthrough/fixtures/reconstruct-structured.html" || fail "structured fixture must carry inline const SURF"
! grep -q 'const SURF' "$ROOT/tests/walkthrough/fixtures/reconstruct-flat.html" || fail "flat fixture must NOT carry const SURF"
grep -q '"b"' "$ROOT/tests/walkthrough/fixtures/reconstruct-flat.html" || fail "flat fixture must carry the legacy b field"
ok "reconstruct: three per-layout fixtures present + distinct"

echo "PASS test_validate_artifact.sh (Task 1 slice)"
