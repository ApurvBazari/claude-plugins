#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/lens/skills/render-review/SKILL.md"
fail(){ echo "FAIL: $1"; exit 1; }

# 1. Skill file exists and is non-empty
[ -s "$SKILL" ] || fail "render-review SKILL.md missing or empty"

# 2. Skill is internal (user-invocable: false)
grep -q "user-invocable: false" "$SKILL" || fail "skill must be internal (user-invocable: false)"

# 2b. Skill stays model-INVOKABLE — an orchestrator's subagent (e.g. matali's walkthrough-renderer)
#     dispatches it via the Skill tool, so it must NOT carry disable-model-invocation (that flag hides
#     a skill from ALL model/subagent invocation, silently degrading the orchestrator render path).
if grep -q "disable-model-invocation" "$SKILL"; then fail "render-review must stay model-invocable (no disable-model-invocation) so an orchestrator subagent can dispatch it"; fi

# 3. Skill renders via walkthrough:render
grep -q "walkthrough:render" "$SKILL" || fail "skill must document walkthrough:render as its render path"

# 4. Skill documents the no-state rule in a never-write context (not a write step)
grep -qiE "never write[^.]*review-state\.json|No .review-state\.json" "$SKILL" || fail "skill must document that it never writes review-state.json (in negative context)"

# 5. Referenced files exist (reuse, not fork)
[ -f "$ROOT/lens/skills/review/references/reconcile.md" ] || fail "reconcile.md reference missing"
[ -f "$ROOT/lens/skills/review/references/review-model-assembly.md" ] || fail "review-model-assembly.md reference missing"
[ -f "$ROOT/lens/skills/review/references/markdown-fallback.md" ] || fail "markdown-fallback.md reference missing"

# 6. Step 1 is where reconcile's compute-only mode is actually consumed: it reconciles in memory,
#    writes nothing, and defers to reconcile.md's orchestrator-mode contract rather than restating it.
#    Scoped to Step 1 so a citation that drifts to another step still fails.
STEP1="$(awk '/^## Step 1/{n=1} /^## Step 2/{n=0} n{print}' "$SKILL")"
[ -n "$STEP1" ] || fail "render-review Step 1 section is missing"
printf '%s\n' "$STEP1" | grep -qi 'compute-only' || fail "Step 1 must declare the reconcile compute-only"
printf '%s\n' "$STEP1" | grep -qiE 'write NOTHING|writes nothing' || fail "Step 1's compute-only reconcile must write nothing"
printf '%s\n' "$STEP1" | grep -qF '../review/references/reconcile.md' || fail "Step 1 must cite ../review/references/reconcile.md as the reconcile contract"
printf '%s\n' "$STEP1" | grep -qF '§ Orchestrator mode' || fail "Step 1 must cite reconcile.md's § Orchestrator mode section"

# 7. Frozen frontmatter: no disable-model-invocation was reintroduced (redundant with 2b, kept as an
#    independent assertion so a partial revert of one pin still fails the other).
grep -q "user-invocable: false" "$SKILL" || fail "frontmatter must keep user-invocable: false"
if grep -q "disable-model-invocation" "$SKILL"; then fail "frontmatter must not gain disable-model-invocation"; fi

# 8. All four step headings present verbatim, whole-line — proves the HEADINGS were not reshaped by
#    the emptyScope edit. A substring match would let e.g. '## Step 3: Render' silently grow into
#    '## Step 3: Render the artifact' and still pass, so this is grep -qxF (whole line), not -qF. This
#    does not by itself prove the step BODIES are unchanged — only that each heading text is intact.
for heading in \
  '## Step 1: Reconcile (compute-only, in memory)' \
  '## Step 2: Assemble the review-model' \
  '## Step 3: Render' \
  '## Step 4: Return'; do
  grep -qxF "$heading" "$SKILL" || fail "missing or altered step heading (whole line): $heading"
done

# 9. The emptyScope short-circuit: declared as an input and enforced as a Step 1 guard.
grep -qF 'emptyScope' "$SKILL" || fail "skill must document the emptyScope discriminator"
grep -qF 'noop: nothing to review' "$SKILL" || fail "skill must document the literal 'noop: nothing to review' return"
printf '%s\n' "$STEP1" | grep -qF 'emptyScope' || fail "Step 1 must guard on emptyScope"
printf '%s\n' "$STEP1" | grep -qF 'noop: nothing to review' || fail "Step 1 must return the literal 'noop: nothing to review'"

# 9b. An empty scope is a SUCCESS, so it must not answer on the failure channel. `skipped:` is declared
#     failure-only (Step 4, Key Rules), so returning it for an empty scope would make an ordinary
#     empty diff indistinguishable from a render that broke.
if grep -qF 'skipped: nothing to review' "$SKILL"; then
  fail "empty scope must not return on the failure channel — 'skipped:' is failure-only, the empty case is 'noop: nothing to review'"
fi

# 9c. All three returns are declared together where the caller reads them, and the failure channel is
#     named as such — this is what keeps the noop/failure conflation from creeping back.
STEP4="$(awk '/^## Step 4/{n=1} /^## Key Rules/{n=0} n{print}' "$SKILL")"
[ -n "$STEP4" ] || fail "render-review Step 4 section is missing"
for ret in 'wrote: <path>' 'noop: nothing to review' 'skipped: <one-line reason>'; do
  printf '%s\n' "$STEP4" | grep -qF "$ret" || fail "Step 4 must declare the return '$ret'"
done
printf '%s\n' "$STEP4" | grep -qiE 'failure channel only|failure only' \
  || fail "Step 4 must state that 'skipped:' is the failure channel only"

# 10. The emptyScope input bullet cites the engine-api.md contract.
grep -qF '../engine/references/engine-api.md' "$SKILL" || fail "skill must cite ../engine/references/engine-api.md as the emptyScope contract"

echo "OK"
