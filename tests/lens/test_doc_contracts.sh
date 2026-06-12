#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ASM="$ROOT/lens/skills/review/references/review-model-assembly.md"
REC="$ROOT/lens/skills/review/references/reconcile.md"
SKILL="$ROOT/lens/skills/review/SKILL.md"
CLAUDEMD="$ROOT/lens/CLAUDE.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ASM" "$REC" "$SKILL" "$CLAUDEMD"; do [ -s "$f" ] || fail "missing $f"; done

# C1 — ids are within-run stable; cross-run identity is the reconcile fingerprint, never the id.
grep -qiE 'within[- ]run' "$PIPE" || fail "C1: pipeline must call ids within-run stable"
grep -qi 'globally-stable' "$PIPE" && fail "C1: 'globally-stable' must be gone from pipeline"
grep -qi 'globally-stable' "$ASM"  && fail "C1: 'globally-stable' must be gone from review-model-assembly"

# C3 — no dangling cross-plugin reference to walkthrough's authoring-guide.md.
grep -qi 'authoring-guide' "$ASM" && fail "C3: dangling authoring-guide ref must be gone from review-model-assembly"

# W1 — severity trend is computed from the 4-value recommendedEscalation, not the 3-value verdict.
grep -qi 'collapses' "$REC" || fail "W1: trend section must explain verdict collapses major+critical (key on escalation)"

# D3 — state write-back is deferred until the render succeeds (no stale 'fixed' after a failed render).
grep -qi 'after a successful render' "$SKILL" || fail "D3: SKILL must write state only after a successful render"
grep -qi 'only after the render succeeds' "$REC" || fail "D3: reconcile write-back must be deferred to post-render"

echo "PASS: lens doc contracts"
