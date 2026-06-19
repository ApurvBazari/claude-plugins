#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/tests/walkthrough/fixtures/review-sample.html"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$F" ] || fail "fixture missing: generate via walkthrough:render on the sample review-model"
grep -q '<script src' "$F" && fail "not self-contained: external <script src>"
grep -q '<img' "$F" && fail "not self-contained: <img> present"
grep -Eq 'class="chip (danger|warn|info|neutral|ok)"' "$F" || fail "no severity/adherence chips"
grep -q "openSurface('F" "$F" || fail "findings not wired to openSurface"
grep -q 'class="diff"' "$F" || fail "annotated-diff component missing"
grep -q 'class="adh"' "$F" || fail "adherence-panel component missing"
# tokens-only: raw 6-hex is allowed ONLY in token definitions (lines starting with --) and the grain SVG data-URI
if grep -vE 'data:image|feTurbulence' "$F" | grep -vE '^[[:space:]]*--' | grep -Eq '#[0-9a-fA-F]{6}'; then
  fail "raw hex outside grain SVG / token defs — tokens only"
fi
# C2 — the fixed/open/new iteration delta is structurally surfaced: a per-finding iteration chip + a delta subhead.
grep -q 'data-iter=' "$F" || fail "no iteration chip (data-iter) on findings cards"
grep -qiE '[0-9]+ (fixed|new|still-open)' "$F" || fail "no iteration delta subhead (e.g. '2 fixed · 1 new')"

# === F5 — grouped adherence component-contract ===
# The review-sample.html fixture above exercises only the FLAT adherence panel (Spec items | Plan steps).
# A true rendered golden fixture for adherence.groups[] (multi-spec) is DEFERRED — it requires invoking
# walkthrough:render with a grouped model, which cannot be faithfully hand-synthesized here without
# faking render output. Gap is explicitly noted; a future task should generate
# tests/walkthrough/fixtures/review-grouped-sample.html via the real renderer and add an HTML smoke test.
#
# What we CAN assert here (proportionate close per the brief): the component-contract in review.md
# explicitly specifies the grouped markup tokens — one .adh-col per group, .adh-h as the source heading,
# .adh-score for the per-group coverage count. This locks the spec so any silent removal of grouped support
# in the component doc fails the belt.
REV="$ROOT/walkthrough/skills/create/references/components/review.md"
[ -s "$REV" ] || fail "review component doc missing"
grep -qiE 'adherence\.groups\[\]|groups\[\] (present|is present)' "$REV" || fail "review.md must document the adherence.groups[] grouped form"
grep -qiE 'one.*adh-col.*per.*group|adh-col.*per.*source|per group.*sub-section' "$REV" || fail "review.md must specify one .adh-col per group (per-source sub-section)"
grep -qiE 'adh-h.*heading|adh-h.*source|source.*adh-h' "$REV" || fail "review.md must specify .adh-h as the group source heading"
grep -q 'adh-score' "$REV" || fail "review.md must document .adh-score for per-group coverage count"
# NOTE: a true rendered-HTML grouped fixture is DEFERRED (see comment above).

echo "PASS: review render smoke"
