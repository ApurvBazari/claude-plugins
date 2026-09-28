#!/usr/bin/env bash
# test_maintain_paths.sh — path mentions and references: path-mention-broken with walk-up
# resolution (D18, D27, § 7.3), directory delete/rename, and reference-broken for rule `paths:`
# globs (D31) and hook commands (D29). AC18, AC24, AC26, AC28 (parsing).
# Markdown fixtures carry literal backticks inside single quotes.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

broken() {  # every path-mention-broken item as "line|mention|path|renamedTo"
  q '"\n".join("|".join([i["line"], i["mention"], i["path"], i.get("renamedTo", "")]) for i in d["items"] if i["kind"] == "path-mention-broken")'
}

# --- AC18: deleted and renamed files are reported; a path that never existed is not ---
new_repo ac18
put src/a.ts a
put src/b.ts b
put CLAUDE.md '# Root' '- Helper `src/a.ts`.' '- Other `src/b.ts`.' '- Planned `src/nope.ts`.'
commit_base
git rm -q src/a.ts
git mv src/b.ts src/c.ts
detect
expect "AC18: deleted + renamed, never-existed skipped" \
  "CLAUDE.md:2|src/a.ts|src/a.ts|
CLAUDE.md:3|src/b.ts|src/b.ts|src/c.ts" "$(broken)"
schema_ok "AC18 report"

# --- AC24: dir-relative, parent-relative and root-relative mentions each resolve; rules: root only ---
new_repo ac24
put apps/crm/src/lib/util/x.ts x
put apps/crm/src/lib/CLAUDE.md '# lib' '- `util/x.ts` (own dir)' '- `lib/util/x.ts` (parent)' \
  '- `apps/crm/src/lib/util/x.ts` (root)'
put .claude/rules/r.md '# rule' '- `util/x.ts` (not from the root)' '- `apps/crm/src/lib/util/x.ts`'
commit_base
git rm -q apps/crm/src/lib/util/x.ts
detect
expect "AC24: three nested forms + one rule form, each with mention and path" \
  "apps/crm/src/lib/CLAUDE.md:2|util/x.ts|apps/crm/src/lib/util/x.ts|
apps/crm/src/lib/CLAUDE.md:3|lib/util/x.ts|apps/crm/src/lib/util/x.ts|
apps/crm/src/lib/CLAUDE.md:4|apps/crm/src/lib/util/x.ts|apps/crm/src/lib/util/x.ts|
.claude/rules/r.md:3|apps/crm/src/lib/util/x.ts|apps/crm/src/lib/util/x.ts|" "$(broken)"

# --- directory mentions: renamed wholesale -> renamedTo; deleted -> none; partly left -> not broken ---
new_repo dirs
put src/old/a.ts a
put src/old/deep/b.ts b
put src/gone/c.ts c
put src/kept/d.ts d
put src/kept/e.ts e
put CLAUDE.md '# Root' '- `src/old/`' '- `src/gone`' '- `src/kept/`'
commit_base
git mv src/old src/legacy
git rm -rq src/gone
git rm -q src/kept/d.ts
detect
expect "directories: rename prefix, delete, partial" \
  "CLAUDE.md:2|src/old/|src/old|src/legacy
CLAUDE.md:3|src/gone|src/gone|" "$(broken)"

# --- AC28: paths: as a YAML list, a flow list and a comma string; globs: is never read ---
new_repo ac28
put src/old/a.ts a
put lib/x.tsx x
put .claude/rules/list.md '---' 'paths:' '  - "src/old/**"' '  - "lib/**/*.{ts,tsx}"' '---' '# list'
put .claude/rules/flow.md '---' 'paths: ["src/old/**", "lib/**"]' '---' '# flow'
put .claude/rules/comma.md '---' 'paths: src/old/**, lib/**' '---' '# comma'
put .claude/rules/globs.md '---' 'globs: src/old/**' '---' '# globs is ignored by Claude Code'
commit_base
git rm -rq src/old
detect
expect "AC28: one reference-broken per rule form, none for globs:" \
  ".claude/rules/comma.md src/old/**|.claude/rules/flow.md src/old/**|.claude/rules/list.md src/old/**" \
  "$(q '"|".join(i["file"] + " " + i["glob"] for i in d["items"] if i["kind"] == "reference-broken")')"
schema_ok "AC28 report"

# --- AC26: a hook's ${CLAUDE_PROJECT_DIR} script deleted -> reference-broken; a deleted .claude hook -> none ---
new_repo ac26
put scripts/check.sh 'echo check'
put scripts/two.sh 'echo two'
put .claude/hooks/x.sh 'echo x'
put .claude/settings.json '{"hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[
  {"type":"command","command":"bash ${CLAUDE_PROJECT_DIR}/scripts/check.sh"},
  {"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR\"/scripts/two.sh --quiet"},
  {"type":"command","command":"bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/x.sh"}]}]}}'
commit_base
git rm -q scripts/check.sh .claude/hooks/x.sh
git mv scripts/two.sh scripts/three.sh
detect
expect "AC26: deleted and renamed hook scripts; the .claude hook is not an item" \
  "scripts/check.sh -|scripts/two.sh scripts/three.sh" \
  "$(q '"|".join(i["path"] + " " + i.get("renamedTo", "-") for i in d["items"] if i["kind"] == "reference-broken")')"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_paths: all checks passed"; exit 0; fi
echo "test_maintain_paths: $failures check(s) failed"; exit 1
