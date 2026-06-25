#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/lens/skills/render-review/SKILL.md"
fail(){ echo "FAIL: $1"; exit 1; }

# 1. Skill file exists and is non-empty
[ -s "$SKILL" ] || fail "render-review SKILL.md missing or empty"

# 2. Skill is internal (user-invocable: false)
grep -q "user-invocable: false" "$SKILL" || fail "skill must be internal (user-invocable: false)"

# 3. Skill renders via walkthrough:render
grep -q "walkthrough:render" "$SKILL" || fail "skill must document walkthrough:render as its render path"

# 4. Skill documents the no-state rule (never write review-state.json)
grep -q "review-state.json" "$SKILL" || fail "skill must document that it never writes review-state.json"

# 5. Referenced files exist (reuse, not fork)
[ -f "$ROOT/lens/skills/review/references/reconcile.md" ] || fail "reconcile.md reference missing"
[ -f "$ROOT/lens/skills/review/references/review-model-assembly.md" ] || fail "review-model-assembly.md reference missing"
[ -f "$ROOT/lens/skills/review/references/markdown-fallback.md" ] || fail "markdown-fallback.md reference missing"

echo "OK"
