#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/tests/lens/fixtures/fallback-sample.md"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$F" ] || fail "fixture missing: produce via markdown-fallback on the sample review-model"
grep -qiE 'verdict:?\s*(ship|fix|block)' "$F" || fail "no verdict header"
grep -qi 'adherence' "$F" || fail "no adherence section"
grep -qi 'F1' "$F" || fail "no findings listed"
grep -qi 'walkthrough is not installed' "$F" || fail "missing fallback notice"
echo "PASS: lens fallback report"
