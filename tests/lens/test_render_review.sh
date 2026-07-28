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

# 8. All four step headings present verbatim — proves Steps 2-4 were not reshaped by the emptyScope edit.
for heading in \
  '## Step 1: Reconcile (compute-only, in memory)' \
  '## Step 2: Assemble the review-model' \
  '## Step 3: Render' \
  '## Step 4: Return'; do
  grep -qF "$heading" "$SKILL" || fail "missing step heading: $heading"
done

# 9. The emptyScope short-circuit: declared as an input and enforced as a Step 1 guard.
grep -qF 'emptyScope' "$SKILL" || fail "skill must document the emptyScope discriminator"
grep -qF 'skipped: nothing to review' "$SKILL" || fail "skill must document the literal 'skipped: nothing to review' return"
printf '%s\n' "$STEP1" | grep -qF 'emptyScope' || fail "Step 1 must guard on emptyScope"
printf '%s\n' "$STEP1" | grep -qF 'skipped: nothing to review' || fail "Step 1 must return the literal 'skipped: nothing to review'"

# 10. The emptyScope input bullet cites the engine-api.md contract.
grep -qF '../engine/references/engine-api.md' "$SKILL" || fail "skill must cite ../engine/references/engine-api.md as the emptyScope contract"

echo "OK"
