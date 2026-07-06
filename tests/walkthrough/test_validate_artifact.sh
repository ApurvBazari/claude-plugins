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

# --- Task 6: existing fixtures converted to new layout + every islanded fixture parse-valid + site pages parse-clean ---
# the two legacy fixtures must be converted to the new (#wt-data island) layout
for legacy in erd-sample review-sample; do
  grep -q 'id="wt-data"' "$ROOT/tests/walkthrough/fixtures/$legacy.html" || fail "$legacy.html not yet converted to the new layout"
done
# every fixture with a #wt-data island must be parse-valid JSON (no raw </script>) + js-gated + node --check-clean
for FF in "$ROOT"/tests/walkthrough/fixtures/*.html; do
  grep -q 'id="wt-data"' "$FF" || continue   # skip legacy reconstruct fixtures deliberately old-layout
  grep -q 'html.js section' "$FF" || fail "fixture $FF has #wt-data but no html.js gate"
  python3 - "$FF" <<'PY' || fail "fixture $FF: island/script validation failed (see above)"
import re,sys,subprocess,json,shutil
html=open(sys.argv[1]).read()
m=re.search(r'<script type="application/json" id="wt-data">(.*?)</script>',html,re.S)
if not m: print("no #wt-data island"); sys.exit(1)
raw=m.group(1)
if "</script" in raw: print("raw </script> inside #wt-data (must be <\\/script)"); sys.exit(1)
try: json.loads(raw)
except Exception as e: print("#wt-data not valid JSON:",e); sys.exit(1)
node=shutil.which("node")
if not node: print("SKIP node --check (node not installed)"); sys.exit(0)
for sm in re.finditer(r'<script(?![^>]*application/json)[^>]*>(.*?)</script>',html,re.S):
    open("/tmp/wt_fix.js","w").write(sm.group(1))
    r=subprocess.run([node,"--check","/tmp/wt_fix.js"],capture_output=True,text=True)
    if r.returncode: print("node --check failed:",r.stderr); sys.exit(1)
PY
done
# node --check every executable <script> across ALL site pages (layout-agnostic; old-layout is valid JS too)
if command -v node >/dev/null 2>&1; then
  python3 - "$ROOT" <<'PY' || fail "a site page has a script that fails node --check"
import re,glob,subprocess,shutil,sys,os
root=sys.argv[1] if len(sys.argv)>1 else "."
node=shutil.which("node"); bad=0
for p in glob.glob(os.path.join(root,"site/**/index.html"),recursive=True):
    html=open(p).read()
    for m in re.finditer(r'<script(?![^>]*application/json)[^>]*>(.*?)</script>',html,re.S):
        open("/tmp/wt_site.js","w").write(m.group(1))
        if subprocess.run([node,"--check","/tmp/wt_site.js"],capture_output=True).returncode:
            print("node --check FAIL:",p); bad+=1
sys.exit(1 if bad else 0)
PY
else echo "SKIP site node --check (no node)"; fi
ok "fixtures new-layout + all islands parse-valid + site pages parse-clean"

# --- reveal-gate specificity guard: the html.js gate must NOT out-specify section.vis ---
for GF in "$PS" "$ROOT"/tests/walkthrough/fixtures/*.html; do
  grep -q 'html.js section' "$GF" || continue
  grep -qE 'html\.js section:not\(\.vis\)' "$GF" || fail "$GF: reveal gate must be 'html.js section:not(.vis)' — a bare 'html.js section' gate out-specifies section.vis and blanks the page"
  ! grep -qE 'html\.js section ?\{' "$GF" || fail "$GF: bare 'html.js section{' gate present — out-specifies section.vis, sections never reveal"
done
ok "reveal gate is specificity-correct (:not(.vis)) in scaffold + all fixtures"

# --- Task 7: version 1.3.1 self-consistent across plugin.json / marketplace / CHANGELOG ---
bash "$ROOT/tests/lib/assert-versions.sh" walkthrough || fail "walkthrough version out of sync across plugin.json / marketplace / CHANGELOG"
grep -q '1.3.1' "$ROOT/walkthrough/CHANGELOG.md" || fail "CHANGELOG missing 1.3.1 entry"
ok "version 1.3.1 self-consistent"

# --- W3: card details route through the openSurface router, not the openCard bypass ---
FT="$ROOT/walkthrough/skills/create/references/components/files-timeline.md"
grep -q "openCard(this)" "$FT" && fail "files-timeline still instructs the openCard router-bypass"
grep -q "openSurface(" "$FT" || fail "files-timeline card-detail wiring must use openSurface"
ok "W3: card details route through openSurface"

# --- W4: docs stop claiming sheet-kind details live in DET ---
# Sheet-kind details are pre-rendered <dialog>s in {{SHEETS}} (routed via SURF[id]='sheet'), NOT DET records
# (DET holds only pane-kind records). Broad sweep per the SP-3 lesson: strip backticks first so the
# backtick-wrapped `a `DET` sheet entry` form (session-model:300) normalizes to `a DET sheet entry` and
# is caught — a naive contiguous grep would let that variant slip through.
SM="$ROOT/walkthrough/skills/create/references/session-model.md"
RC="$ROOT/walkthrough/skills/render/references/render-contract.md"
tr -d '`' < "$SM" | grep -niE 'DET sheet|a DET (sheet )?entry|also a DET' && fail "session-model still says sheet-kind lives in DET (W4)"
grep -niE 'one .?DET.? entry each' "$RC" && fail "render-contract still says findings get a DET entry each (W4)"
RV="$ROOT/walkthrough/skills/create/references/components/review.md"
[ -s "$RV" ] || fail "missing $RV"
tr -d '`' < "$RV" | grep -niE 'DET sheet|a DET (sheet )?entry|also a DET' && fail "review.md still claims findings are DET sheets (W4)"
ok "W4: no doc claims sheet-kind in DET"

# --- W5: update + document honor the persisted output base ---
# create Step 6.5 persists output-location: in <base>/settings.md; update/document must resolve
# <base> the same way, not hardcode .claude/walkthrough/ (blind to a Cowork-visible walkthroughs/ base).
UP="$ROOT/walkthrough/skills/update/SKILL.md"
DC="$ROOT/walkthrough/skills/document/SKILL.md"
grep -q 'settings.md' "$UP" || fail "update must resolve the persisted base from settings.md (W5)"
# Strengthening: 'settings.md' alone is WEAK — update already names .claude/walkthrough/settings.md for
# the gitignore choice, so the line above passes even at base. Gate the actual Step-1 base resolution on
# the <base> token, which is absent from update's Step 1 at base and only introduced by the W5 edit.
grep -q '<base>' "$UP" || fail "update Step 1 must resolve/list <base>, not a hardcoded .claude/walkthrough (W5)"
grep -qiE 'settings.md|persisted base|walkthroughs/' "$DC" || fail "document must honor the persisted base (W5)"
ok "W5: update+document resolve the persisted base"

echo "PASS test_validate_artifact.sh (Task 1 slice)"
