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

echo "OK"
