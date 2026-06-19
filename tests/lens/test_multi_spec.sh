#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
SPECAG="$ROOT/lens/agents/spec-adherence.md"
PLANAG="$ROOT/lens/agents/plan-adherence.md"
ASM="$ROOT/lens/skills/review/references/review-model-assembly.md"
MDFB="$ROOT/lens/skills/review/references/markdown-fallback.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ESKILL" "$SPECAG" "$PLANAG" "$ASM" "$MDFB"; do [ -s "$f" ] || fail "missing $f"; done

# === INTENT: diff-correlated multi-spec/plan selection ===
grep -qi 'diff-correlated' "$PIPE" || fail "INTENT: pipeline must describe diff-correlated selection"
grep -qiE 'Added or Modified' "$PIPE" || fail "INTENT: must select specs/plans Added or Modified in the diff"
grep -qi 'Prefer Added' "$PIPE" || fail "INTENT: must prefer Added over Modified"
grep -qiE 'only Modified|Modified-only' "$PIPE" || fail "INTENT: modified-only must be a soft (degraded) signal"
grep -qi 'latest-only fallback' "$PIPE" || fail "INTENT: empty set must fall back to latest-only"
grep -qi 'name the skipped' "$PIPE" || fail "INTENT: over-cap specs must be named in summary, not dropped"
grep -qiE 'multiple specs|more than one spec|span' "$ESKILL" || fail "INTENT: engine SKILL Step 2 must state intent can span multiple specs/plans"
grep -qi 'diff-correlated' "$ESKILL" || fail "INTENT: engine SKILL Step 2 must reference diff-correlated selection"

echo "PASS: lens multi-spec"
