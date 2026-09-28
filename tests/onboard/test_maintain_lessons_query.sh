#!/usr/bin/env bash
# test_maintain_lessons_query.sh — the read-only lesson helpers onboard:maintain calls:
# `--lesson-file` (lesson-file slug and reuse on identical normalised `paths:` sets written as a
# list or a comma string, D7/D31) and `--lesson-present` (id marker and normalised exact text,
# the mechanical half of D8). AC28 (reuse).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

file_for() { bash "$DETECT" --lesson-file "$@" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["file"], d["exists"])'; }
present() { bash "$DETECT" --lesson-present --id "$1" --text "$2" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["status"], d["at"])'; }

new_repo lessons
put src/a.ts x
commit_base

expect "slug: last two literal segments, apps/src dropped" ".claude/rules/lessons-crm-lib.md False" \
  "$(file_for 'apps/crm/src/lib/**')"
expect "slug: nothing literal left -> scoped" ".claude/rules/lessons-scoped.md False" "$(file_for '**/*.ts')"

put .claude/rules/lessons-crm-lib.md '---' 'paths:' '  - "apps/crm/src/lib/**"' '  - "lib/x/**"' '---' '# Lessons'
expect "AC28: identical set written as a list is reused (order and ./ ignored)" \
  ".claude/rules/lessons-crm-lib.md True" "$(file_for 'lib/x/**' './apps/crm/src/lib/**')"
expect "a different set with the same slug gets -2" ".claude/rules/lessons-crm-lib-2.md False" \
  "$(file_for 'apps/crm/src/lib/**')"

put .claude/rules/lessons-web.md '---' 'paths: apps/web/**, "packages/ui/**"' '---' '# Lessons'
expect "AC28: identical set written as a comma string is reused" ".claude/rules/lessons-web.md True" \
  "$(file_for 'packages/ui/**' 'apps/web/**')"

rc=0; bash "$DETECT" --lesson-file >/dev/null 2>&1 || rc=$?
expect "--lesson-file with no glob: exit 2" 2 "$rc"

put .claude/rules/lessons.md '# Lessons' '' '<!-- lesson:L-1 -->' '- Always round at the output boundary.' \
  '  _evidence: gate-1 steer (matali run 1)_'
put CLAUDE.md '# Root' '- Prefer server actions over API routes.'
expect "present: id marker" "present-id .claude/rules/lessons.md:3" "$(present L-1 'anything')"
expect "present: normalised text (case, whitespace, trailing punctuation, list marker)" \
  "present-text .claude/rules/lessons.md:4" "$(present L-2 'always   ROUND at the output boundary')"
expect "present: text in a CLAUDE.md" "present-text CLAUDE.md:2" "$(present L-3 'Prefer server actions over API routes!')"
expect "absent" "absent None" "$(present L-4 'Something new entirely.')"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_lessons_query: all checks passed"; exit 0; fi
echo "test_maintain_lessons_query: $failures check(s) failed"; exit 1
