#!/usr/bin/env bash
# test_maintain_recheck.sh — recheck-line (D17, D28, § 7.1): the path / name / stem keys and their
# rank order, the tie-break (source-file matches first), the cap and truncated count, the
# modified-non-source rule (owner decision 2026-09-27), no repeats of stale-line lines, and
# stale-line's alsoAt. AC17, AC25, AC29.
# Markdown fixtures carry literal backticks inside single quotes.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

rechecks() {  # "line:by,by" per recheck item, in report order
  q '" ".join(i["line"] + ":" + ",".join(m["by"] for m in i["matched"]) for i in d["items"] if i["kind"] == "recheck-line")'
}

# --- AC17: ranks path > name > stem, whatever the document order ---
new_repo ac17
put package.json '{"name":"root","dependencies":{}}'
put src/pricing.ts x
put CLAUDE.md '# Root' '- Values keep 2 decimal places.' '- Money goes through decimal.js.' \
  '- Pricing lives in `src/pricing.ts`.'
commit_base
put package.json '{"name":"root","dependencies":{"decimal.js":"^10"}}'
put src/pricing.ts y
detect
expect "AC17: rank order" "CLAUDE.md:4:path CLAUDE.md:3:name CLAUDE.md:2:stem" "$(rechecks)"
expect "AC17: the added dependency is mentioned, so no dependency-added (D15)" "" \
  "$(item dependency-added 'i["name"]')"

# --- AC17: the cap keeps 8 and counts the rest; ties break by source match, then file order ---
new_repo cap
put src/a.ts x
put src/b.ts x
lines=('# Root')
for n in 1 2 3 4 5 6 7 8 9 10; do lines+=("- line $n about \`src/a.ts\`"); done
put CLAUDE.md "${lines[@]}"
put apps/x/CLAUDE.md '# X' '- see `../../src/b.ts` and `../../src/a.ts`'
commit_base
put src/a.ts y
put src/b.ts y
detect
expect "cap: 8 kept" 8 "$(q 'sum(1 for i in d["items"] if i["kind"] == "recheck-line")')"
expect "cap: truncated counts the rest" 3 "$(q 'd["truncated"]["recheck-line"]')"
expect "cap: within rank 1, more source-file matches sort first (a later file's line leads)" \
  "apps/x/CLAUDE.md:2" "$(item recheck-line 'i["line"]')"
expect "cap: then file order, then line order" "CLAUDE.md:2" "$(item recheck-line 'i["line"]' 1)"

# --- owner decision: a modified non-source file is not a key; an added one is; a modified source file is ---
new_repo nonsource
put docs/progress.md p
put src/a.ts x
put CLAUDE.md '# Root' '- Track work in `docs/progress.md`.' '- New notes in `docs/notes.md`.' '- Code in `src/a.ts`.'
commit_base
put docs/progress.md q
put docs/notes.md n
put src/a.ts y
detect
expect "modified doc: no key; added doc and modified source: keys" "CLAUDE.md:4:path CLAUDE.md:3:path" "$(rechecks)"

# --- AC25: resolved path, unique source basename, shared basename, manifest and config basenames ---
new_repo ac25
put apps/a/page.tsx a
put apps/b/page.tsx b
put src/helper.ts h
put vite.config.ts v
put package.json '{"name":"root"}'
put CLAUDE.md '# Root' '- `helper.ts` does the thing.' '- Each `page.tsx` renders.' \
  '- `vite.config.ts` sets aliases.' '- `package.json` lists scripts.' '- Full `src/helper.ts` path.'
commit_base
put apps/a/page.tsx a2
put src/helper.ts h2
put vite.config.ts v2
put package.json '{"name":"root","private":true}'
detect
expect "AC25: unique basename + resolved path match; shared/config/manifest basenames do not" \
  "CLAUDE.md:2:path CLAUDE.md:6:path" "$(rechecks)"

# --- AC29 + no repeats: a removed dependency on three lines is one stale-line with two alsoAt ---
new_repo ac29
put package.json '{"name":"root","dependencies":{"recharts":"^2","@playwright/test":"^1"}}'
put CLAUDE.md '# Root' '- Charts: recharts.' '- More recharts notes.' '- Tests run under test runners.'
put apps/x/CLAUDE.md '# X' '- recharts here too.'
commit_base
put package.json '{"name":"root","dependencies":{}}'
detect
expect "AC29: one stale-line, line + two alsoAt" "CLAUDE.md:2|CLAUDE.md:3 apps/x/CLAUDE.md:2" \
  "$(item dependency-removed 'i["line"] + "|" + " ".join(i["alsoAt"])')"
expect "AC29: the stale lines are not repeated as rechecks; the generic stem 'test' is not a key" \
  "" "$(rechecks)"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_recheck: all checks passed"; exit 0; fi
echo "test_maintain_recheck: $failures check(s) failed"; exit 1
