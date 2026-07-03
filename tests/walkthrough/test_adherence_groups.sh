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
grep -qiE 'groups.*kind|"kind":[[:space:]]*"spec\|plan"' "$SM" || fail "session-model groups must carry kind spec|plan"
grep -qiE 'mutually exclusive|never coexist' "$SM" || fail "session-model must state groups[] and flat adherence are mutually exclusive"
grep -qi 'groups' "$REV" || fail "review component must render adherence groups"
grep -qiE 'per-group|per group|sub-section' "$REV" || fail "review component must render a per-group sub-section"
grep -qiE 'falls back|fallback|otherwise' "$REV" || fail "review component must fall back to the flat panel"

bash "$ROOT/tests/lib/assert-versions.sh" walkthrough || fail "walkthrough version consistency (plugin.json = marketplace = CHANGELOG)"

echo "PASS: walkthrough grouped adherence"
