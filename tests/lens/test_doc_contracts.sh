#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ASM="$ROOT/lens/skills/review/references/review-model-assembly.md"
REC="$ROOT/lens/skills/review/references/reconcile.md"
SKILL="$ROOT/lens/skills/review/SKILL.md"
CLAUDEMD="$ROOT/lens/CLAUDE.md"
FC="$ROOT/lens/skills/engine/references/finder-contract.md"
READMEMD="$ROOT/lens/README.md"
CHANGELOGMD="$ROOT/lens/CHANGELOG.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ASM" "$REC" "$SKILL" "$CLAUDEMD" "$FC" "$READMEMD" "$CHANGELOGMD"; do [ -s "$f" ] || fail "missing $f"; done

# C1 — ids are within-run stable; cross-run identity is the reconcile fingerprint, never the id.
grep -qiE 'within[- ]run' "$PIPE" || fail "C1: pipeline must call ids within-run stable"
grep -qi 'globally-stable' "$PIPE" && fail "C1: 'globally-stable' must be gone from pipeline"
grep -qi 'globally-stable' "$ASM"  && fail "C1: 'globally-stable' must be gone from review-model-assembly"
grep -qi 'globally-stable' "$FC"   && fail "C1: 'globally-stable' must be gone from finder-contract"

# C3 — no dangling cross-plugin reference to walkthrough's authoring-guide.md.
grep -qi 'authoring-guide' "$ASM" && fail "C3: dangling authoring-guide ref must be gone from review-model-assembly"

# W1 — severity trend is computed from the 4-value recommendedEscalation, not the 3-value verdict.
grep -qi 'collapses' "$REC" || fail "W1: trend section must explain verdict collapses major+critical (key on escalation)"

# D3 — state write-back is deferred until the render succeeds (no stale 'fixed' after a failed render).
grep -qi 'after a successful render' "$SKILL" || fail "D3: SKILL must write state only after a successful render"
grep -qi 'only after the render succeeds' "$REC" || fail "D3: reconcile write-back must be deferred to post-render"

# D4 — v1.1 acknowledged/won't-fix is fenced as not yet wired (no input path in v1).
grep -qiE 'not yet wired|no input path' "$REC" || fail "D4: v1.1 won't-fix must be fenced as not yet wired"

# W2 — the finding-status (confirmed vs flagged) is disambiguated from the verifier's status.
grep -qi 'distinct from the verifier' "$ASM" || fail "W2: status clarifier missing in review-model-assembly"

# W3 — CLAUDE.md's skill inventory names every skill that actually exists (derived, not a count literal).
for d in "$ROOT"/lens/skills/*/; do
  s="$(basename "$d")"
  grep -q "$s" "$CLAUDEMD" || fail "W3: lens CLAUDE.md must mention skill '$s'"
done

# W1/D3 consistency — the renamed 'severity trend' / deferred write-back must not leave stale 'verdict trend' wording in the operative docs.
grep -qi 'verdict trend' "$REC" && fail "reconcile must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$SKILL" && fail "SKILL must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$CLAUDEMD" && fail "CLAUDE.md must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$READMEMD" && fail "README must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$CHANGELOGMD" && fail "CHANGELOG must say 'severity trend', not 'verdict trend'"

# C2/I1 — the possibly-resolved enum mapping must state the ' — verify' suffix is markdown-only (dropped for the bare enum value).
grep -qi 'suffix is markdown-only' "$ASM" || fail "review-model-assembly must explain possibly-resolved suffix is dropped for the enum"

# L1 — engine stage count is 4 and ASSEMBLE is not attributed to the engine as a render step.
grep -q '4 engine stages' "$CLAUDEMD" || fail "L1: CLAUDE.md must say '4 engine stages'"
grep -qi '5 engine stages' "$CLAUDEMD" && fail "L1: CLAUDE.md must not say '5 engine stages'"
grep -qi 'delegates the 5-stage engine' "$CLAUDEMD" && fail "L1: CLAUDE.md skills list must not say '5-stage engine'"
# the render (review-model + walkthrough:render) must be named as the review skill's stage, not an engine stage.
grep -qi "review.* skill.s render stage" "$CLAUDEMD" || fail "L1: CLAUDE.md must attribute review-model/walkthrough:render to the review skill's render stage"
# pipeline.md must agree on the 4-stage framing.
grep -q 'four stages' "$PIPE" || fail "L1: pipeline.md must say 'four stages'"
grep -qi 'five stages' "$PIPE" && fail "L1: pipeline.md must not say 'five stages'"

# L5 — the schema exists now: no stale '(built in a later task)'; and the vicario/matali roles are stated.
grep -qi 'built in a later task' "$CLAUDEMD" && fail "L5: CLAUDE.md must drop the stale '(built in a later task)' — the schema exists"
grep -qi 'schema-parity target' "$CLAUDEMD" || fail "L5: CLAUDE.md must state vicario = schema-parity target"
grep -qi 'live consumer' "$CLAUDEMD" || fail "L5: CLAUDE.md must state matali = the live consumer"

# L2 — the headless path consumes the engine's returned adherence block first; derive-from-gaps is the true fallback.
grep -qi "engine.*adherence" "$ASM" || fail "L2: review-model-assembly headless path must consume the engine's adherence block when present"
grep -qiE "true fallback|only when.*adherence.*absent|only if.*adherence.*absent" "$ASM" || fail "L2: derive-from-requirements must be framed as the fallback used only when the engine's adherence block is absent"

echo "PASS: lens doc contracts"
