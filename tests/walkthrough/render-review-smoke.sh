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
echo "PASS: review render smoke"
