#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REC="$ROOT/lens/skills/review/references/reconcile.md"
SKILL="$ROOT/lens/skills/review/SKILL.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$REC" "$SKILL"; do [ -s "$f" ] || fail "missing $f"; done

# CO1 — reconcile documents a compute-only / orchestrator mode that returns and does not write.
grep -qi 'compute-only' "$REC" || fail "CO1: reconcile must document compute-only mode"
grep -qi 'orchestrator is the single writer' "$REC" || fail "CO1: reconcile must say the orchestrator owns persistence"

# CO2 — the returned object names delta + severityTrend.
grep -qi 'severityTrend' "$REC" || fail "CO2: reconcile must name severityTrend in the returned object"
grep -qi 'delta' "$REC" || fail "CO2: reconcile must name delta in the returned object"

# CO3 — SKILL exposes the compute-only branch: return, skip render (Step 4) and state write (Step 5).
grep -qi 'compute-only' "$SKILL" || fail "CO3: SKILL must document the compute-only branch"
grep -qiE 'skip .*render|skip Step 4' "$SKILL" || fail "CO3: SKILL compute-only must skip the render"

# CO4 — acknowledged suppression wired for orchestrator mode (caller supplies it); standalone stays fenced.
grep -qi 'wired in orchestrator mode' "$REC" || fail "CO4: reconcile must wire acknowledged for orchestrator mode"
grep -qiE 'suppressed|kept out' "$REC" || fail "CO4: acknowledged findings must be suppressed"
grep -qiE 'not yet wired|no input path' "$REC" || fail "CO4: standalone acknowledged fence must remain"

echo "PASS: lens convergence compute-only contracts"
