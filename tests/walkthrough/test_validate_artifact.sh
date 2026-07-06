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

echo "PASS test_validate_artifact.sh (Task 1 slice)"
