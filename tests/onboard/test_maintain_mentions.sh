#!/usr/bin/env bash
# test_maintain_mentions.sh — the one mention predicate (D24, spec § 7.2) through
# `maintain-detect.sh --mentioned`, and detect's use of it: D15 (an added script already mentioned
# is dropped), the removal rule (a removed script mentioned on several lines is one stale-line with
# alsoAt), and D21 (dependency mentions are case-insensitive). AC21.
# Markdown fixtures carry literal backticks inside single quotes.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

new_repo mono
put package.json '{"name":"root","scripts":{"dev":"next dev"}}'
put apps/crm/package.json '{"name":"@repo/crm","scripts":{"test":"vitest"}}'
put apps/web/package.json '{"name":"@repo/web","scripts":{"test":"vitest"}}'
put packages/tool/package.json '{"scripts":{"gen":"node gen.js"}}'
commit_base

# mentioned <expected-exit> <what> <file> <line> <script> <package> [--manifest <path>]
mentioned() {
  local want="$1" what="$2" file="$3" line="$4" script="$5" package="$6"
  shift 6
  put "$file" '# fixture' "$line"
  local rc=0
  bash "$DETECT" --mentioned "$script" --package "$package" "$@" "$file" >/dev/null 2>&1 || rc=$?
  expect "AC21: $what" "$want" "$rc"
}

mentioned 0 "pnpm --filter <pkg> <s>"            CLAUDE.md 'pnpm --filter @repo/crm price:check' price:check @repo/crm
mentioned 0 "pnpm --filter=<pkg> <s>"            CLAUDE.md 'pnpm --filter=@repo/crm price:check' price:check @repo/crm
mentioned 0 "pnpm -F <pkg> <s>"                  CLAUDE.md 'pnpm -F @repo/crm price:check' price:check @repo/crm
mentioned 0 "npm run <s> -w <pkg>"               CLAUDE.md 'npm run price:check -w @repo/crm' price:check @repo/crm
mentioned 0 "npm run <s> --workspace <pkg>"      CLAUDE.md 'npm run price:check --workspace @repo/crm' price:check @repo/crm
mentioned 0 "yarn workspace <pkg> <s>"           CLAUDE.md 'yarn workspace @repo/crm price:check' price:check @repo/crm
mentioned 0 "turbo run <s> in the root file counts for the root package" CLAUDE.md 'turbo run dev' dev root
mentioned 1 "turbo run <s> in the root file is not a nested package's"   CLAUDE.md 'turbo run test' test @repo/crm
mentioned 0 "selector by directory"              CLAUDE.md 'pnpm --filter ./apps/crm test' test @repo/crm
mentioned 0 "selector glob"                      CLAUDE.md 'pnpm --filter "@repo/*" test' test @repo/crm
mentioned 0 "pnpm graph selector <pkg>..."       CLAUDE.md 'pnpm --filter @repo/crm... test' test @repo/crm
mentioned 1 "a selector naming another package"  CLAUDE.md 'pnpm --filter @repo/web test' test @repo/crm
mentioned 1 "an exclusion selector"              CLAUDE.md 'pnpm --filter !@repo/crm test' test @repo/crm
mentioned 0 "-r names every package"             CLAUDE.md 'pnpm -r test' test @repo/web
mentioned 0 "unselected line in a nested CLAUDE.md counts for that package" apps/crm/CLAUDE.md 'pnpm test' test @repo/crm
mentioned 1 "unselected line in a nested CLAUDE.md is not the root's" apps/crm/CLAUDE.md 'pnpm dev' dev root
mentioned 1 "unselected line in the root CLAUDE.md is not a nested package's" CLAUDE.md 'pnpm test' test @repo/crm
mentioned 0 "a rule file counts for the root package" .claude/rules/r.md '- run `pnpm dev` first' dev root
mentioned 1 "no runner word: not a mention"      CLAUDE.md 'run the test suite before pushing' test @repo/crm
mentioned 1 "a longer script name is another token" CLAUDE.md 'pnpm --filter @repo/crm test:all' test @repo/crm
mentioned 0 "punctuation around the token"       CLAUDE.md '(see `pnpm --filter @repo/crm test`).' test @repo/crm
mentioned 0 "list line with a description"       CLAUDE.md '- `npm run dev` — next dev' dev root
mentioned 0 "an unnamed package via --manifest"  packages/tool/CLAUDE.md 'pnpm gen' gen - --manifest packages/tool/package.json
mentioned 1 "an unnamed package: another package's line" CLAUDE.md 'pnpm gen' gen - --manifest packages/tool/package.json

rc=0; bash "$DETECT" --mentioned test >/dev/null 2>&1 || rc=$?
expect "--mentioned without --package or files: exit 2" 2 "$rc"
put CLAUDE.md '# Root' 'pnpm dev'
expect "--mentioned prints the mentioning line refs" "CLAUDE.md:2" \
  "$(bash "$DETECT" --mentioned dev --package root CLAUDE.md)"

# --- D15: an added script already mentioned anywhere is dropped; the removal rule uses the same predicate ---
new_repo detect-side
put package.json '{"name":"root","scripts":{"dev":"x"}}'
put apps/crm/package.json '{"name":"@repo/crm","scripts":{"old":"x","keep":"y"}}'
put CLAUDE.md '# Root' '```bash' 'pnpm --filter @repo/crm old      # old thing' '```'
put apps/crm/CLAUDE.md '# CRM' '- `pnpm old` runs the old thing'
commit_base
put apps/crm/package.json '{"name":"@repo/crm","scripts":{"keep":"y","price:check":"tsx p.ts"}}'
put CLAUDE.md '# Root' '```bash' 'pnpm --filter @repo/crm old      # old thing' 'pnpm --filter @repo/crm price:check   # tsx p.ts' '```'
detect
expect "D15: a mentioned added script is dropped; the removed one is one stale-line" "script-removed:defer" "$(kinds)"
expect "removal rule: line + alsoAt across files and selectors" "CLAUDE.md:3 apps/crm/CLAUDE.md:2" \
  "$(item script-removed 'i["line"] + " " + " ".join(i["alsoAt"])')"
expect "script items carry the package name" "@repo/crm" "$(item script-removed 'i["package"]')"
schema_ok "mentions report"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_mentions: all checks passed"; exit 0; fi
echo "test_maintain_mentions: $failures check(s) failed"; exit 1
