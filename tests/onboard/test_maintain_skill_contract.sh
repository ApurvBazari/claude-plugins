#!/usr/bin/env bash
# test_maintain_skill_contract.sh — onboard:maintain's structural contract (spec § 8, AC14): an
# internal skill that never prompts, dispatches, tracks tasks, researches or commits; that calls
# the helpers by their plugin-root paths; and that names every result reason it can emit.
# Literal ${CLAUDE_PLUGIN_ROOT} and backticks are searched for as text.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
ok() { echo "ok: $1"; }
check() {  # check <what> <command...> — ok when the command succeeds
  local what="$1"
  shift
  if "$@"; then ok "$what"; else fail "$what"; fi
}
# shellcheck disable=SC2329  # called through check()
in_fm() { printf '%s\n' "$fm" | grep -q "$@"; }

SKILL="$ROOT/onboard/skills/maintain/SKILL.md"
DIR="$(dirname "$SKILL")"
[ -s "$SKILL" ] || { echo "FAIL: $SKILL missing or empty"; exit 1; }

fm="$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f' "$SKILL")"
check "frontmatter name: maintain" in_fm -x 'name: maintain'
check "frontmatter user-invocable: false" in_fm -x 'user-invocable: false'
check "frontmatter description present" in_fm '^description: .\{40,\}'
if printf '%s\n' "$fm" | grep -q 'user_invocable\|disable_model_invocation'; then
  fail "underscore frontmatter spelling is silently ignored — use hyphens"
else
  ok "hyphenated frontmatter spelling"
fi

# AC14 — the forbidden tool and action tokens, anywhere in the skill or its references.
forbidden='AskUserQuestion|TaskCreate|TaskUpdate|TodoWrite|subagent_type|Skill\(|Agent\(|onboard:research|git (add|commit|push|stage)'
hits="$(grep -rnE "$forbidden" "$DIR")"
rc=$?
case "$rc" in
  1) ok "AC14: no prompt / dispatch / task / research / commit instruction" ;;
  0) fail "AC14: forbidden token found:"; printf '%s\n' "$hits" ;;
  *) fail "AC14: grep errored (rc=$rc) — the assertion was never evaluated" ;;
esac

for helper in 'maintain-guard.sh" before' 'maintain-guard.sh" after' 'maintain-guard.sh" prefix-ok' \
              'maintain-detect.sh" --mentioned' 'maintain-detect.sh" --lesson-present' 'maintain-detect.sh" --lesson-file' \
              'maintain-write.sh" record' 'maintain-write.sh" lesson' 'maintain-write.sh" early'; do
  check "calls \${CLAUDE_PLUGIN_ROOT}/scripts/$helper" grep -qF "bash \"\${CLAUDE_PLUGIN_ROOT}/scripts/$helper" "$SKILL"
done
if grep -nE '\$H/|H="\$' "$SKILL"; then
  fail "helpers must be called by their full \${CLAUDE_PLUGIN_ROOT} path — a shell variable breaks per-command allowlists"
else
  ok "no shell-variable indirection in helper calls"
fi

for reason in bad-input not-onboarded no-matching-section unrecognized-style \
              target-outside-tooling possible-duplicate; do
  check "records the $reason reason" grep -qF -- "--reason $reason" "$SKILL"
done
check "records skipped entries" grep -qF 'record … skipped' "$SKILL"
check "the guard writes the result (--result)" grep -qF -- '--result <out>' "$SKILL"
check "says the model never writes under .claude/ itself" grep -qF 'Never write under `.claude/`' "$SKILL"

for ref in references/command-styles.md references/lesson-entries.md; do
  check "cites $ref" grep -qF "$ref" "$SKILL"
  check "$ref exists" test -s "$DIR/$ref"
done
for schema in maintain-detect.json maintain-lessons.json maintain-result.json; do
  check "cites schemas/$schema" grep -qF "\${CLAUDE_PLUGIN_ROOT}/schemas/$schema" "$SKILL"
  check "ships schemas/$schema" test -s "$ROOT/onboard/schemas/$schema"
done

for style in '**List**' '**Fenced block**' '**Table row**' '**Inline `A | B`**'; do
  check "command-styles.md names the $style style (D26)" grep -qF "$style" "$DIR/references/command-styles.md"
done
check "command-styles.md: npm lifecycle shortcuts are not a runner form (npm run <name>)" \
  grep -qF 'are not a runner form' "$DIR/references/command-styles.md"
check "lesson-entries.md pins the evidence line" grep -qF '_evidence: <summary> (<ref>)_' "$DIR/references/lesson-entries.md"
check "D20: lesson-entries.md says evidence.pointer is never written" \
  grep -qF '`evidence.pointer` is never written' "$DIR/references/lesson-entries.md"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_skill_contract: all checks passed"; exit 0; fi
echo "test_maintain_skill_contract: $failures check(s) failed"; exit 1
