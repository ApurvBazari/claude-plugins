#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SM="$ROOT/walkthrough/skills/create/references/session-model.md"
REV="$ROOT/walkthrough/skills/create/references/components/review.md"
PJSON="$ROOT/walkthrough/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/walkthrough/CHANGELOG.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$SM" "$REV" "$PJSON" "$MKT" "$CHANGELOG"; do [ -s "$f" ] || fail "missing $f"; done

grep -qi 'groups' "$SM" || fail "session-model adherence must document the optional groups[] form"
grep -qiE '"kind"|kind.*spec.*plan' "$SM" || fail "session-model groups must carry kind spec|plan"
grep -qi 'groups' "$REV" || fail "review component must render adherence groups"
grep -qiE 'per-group|per group|sub-section' "$REV" || fail "review component must render a per-group sub-section"
grep -qiE 'falls back|fallback|otherwise' "$REV" || fail "review component must fall back to the flat panel"

PV=$(python3 -c "import json;print(json.load(open('$PJSON'))['version'])")
MV=$(python3 -c "import json;d=json.load(open('$MKT'));print([p['version'] for p in d['plugins'] if p['name']=='walkthrough'][0])")
[ "$PV" = "1.4.0" ] || fail "walkthrough plugin.json must be 1.4.0 (got $PV)"
[ "$MV" = "1.4.0" ] || fail "walkthrough marketplace.json must be 1.4.0 (got $MV)"
grep -q '1.4.0' "$CHANGELOG" || fail "walkthrough CHANGELOG must have a 1.4.0 entry"

echo "PASS: walkthrough grouped adherence"
