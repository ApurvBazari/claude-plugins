#!/usr/bin/env bash
# test_maintain_guard.sh — maintain-guard.sh (spec § 9, D14, D30): restore a disallowed edit to a
# clean tracked file, report (never delete) the rest, leave pre-existing dirty files alone, list
# changed tooling files + preDirty, and exempt only a safe --out folder. AC8, AC27.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

field() { python3 -c "import json,sys; d=json.loads(sys.argv[1]); print($2)" "$1"; }

new_repo ac8
put src/a.ts a
put src/b.ts b
put CLAUDE.md '# Root'
put apps/x/CLAUDE.md '# X'
put .claude/settings.json '{}'
commit_base
echo "dirty before" >> src/b.ts          # the run's own uncommitted work
echo "dirty before" >> apps/x/CLAUDE.md  # a tooling file already dirty
put notes.txt 'wip'
state="$(bash "$GUARD" before)"
if [ -f "$state" ]; then echo "ok: before prints an existing state file"; else fail "before: no state file at [$state]"; fi
case "$state" in "$REPO"/*) fail "default state file is inside the repo: $state" ;; *) echo "ok: default state file lives outside the repo" ;; esac

echo "- new line" >> CLAUDE.md             # allowed tooling edit
echo "- more" >> apps/x/CLAUDE.md          # allowed, but pre-dirty
put .claude/rules/lessons.md '# Lessons'  # allowed new rule file
echo "bad" >> src/a.ts                     # disallowed, clean before -> restored
echo "bad again" >> src/b.ts               # disallowed, dirty before -> reported only
put src/new.ts 'x'                         # disallowed, new -> reported, never deleted
echo "{\"x\":1}" > .claude/settings.json   # disallowed .claude edit -> restored
rc=0; out="$(bash "$GUARD" after --state "$state")" || rc=$?
expect "AC8: exit 3 when violations were reported" 3 "$rc"
expect "AC8: changed tooling files" ".claude/rules/lessons.md CLAUDE.md apps/x/CLAUDE.md" \
  "$(field "$out" '" ".join(d["changed"])')"
expect "AC8: preDirty" "apps/x/CLAUDE.md" "$(field "$out" '" ".join(d["preDirty"])')"
expect "AC8: violations" ".claude/settings.json:restored src/a.ts:restored src/b.ts:reported src/new.ts:reported" \
  "$(field "$out" '" ".join(v["path"] + ":" + v["action"] for v in d["violations"])')"
expect "AC8: the clean file is back to HEAD" "a" "$(cat src/a.ts)"
expect "AC8: settings restored" "{}" "$(cat .claude/settings.json)"
expect "AC8: the pre-dirty file keeps both edits" "b|dirty before|bad again" "$(tr '\n' '|' < src/b.ts | sed 's/|$//')"
if [ -f src/new.ts ]; then echo "ok: AC8 new file not deleted"; else fail "AC8 deleted an untracked file"; fi
if [ -e "$state" ]; then fail "after left the state file"; else echo "ok: after removes the state file"; fi

# --- paths are literal, and "clean before, tracked" means absent from before and present in HEAD ---
# A Next.js route folder `[id]` is a glob that also matches `d`; the guard must not touch the user's
# dirty app/d/page.tsx. A file staged during apply, or an ignored file force-added, is not in HEAD:
# reported, never deleted (§ 9).
new_repo literal
put 'app/[id]/page.tsx' 'route'
put app/d/page.tsx 'd'
put .gitignore '.env'
commit_base
echo "user wip" >> app/d/page.tsx
put .env 'SECRET=1'
state="$(bash "$GUARD" before)"
echo "bad" >> 'app/[id]/page.tsx'
put src/staged.ts 'x' && git add src/staged.ts
git add -f .env
rc=0; out="$(bash "$GUARD" after --state "$state")" || rc=$?
expect "literal: only the edited route file is restored; staged + force-added files reported" \
  ".env:reported app/[id]/page.tsx:restored src/staged.ts:reported" \
  "$(field "$out" '" ".join(v["path"] + ":" + v["action"] for v in d["violations"])')"
expect "literal: the route file is back to HEAD" "route" "$(cat 'app/[id]/page.tsx')"
expect "literal: the user's dirty sibling keeps its work" "d|user wip" "$(tr '\n' '|' < app/d/page.tsx | sed 's/|$//')"
expect "literal: a staged new file is not deleted" "x" "$(cat src/staged.ts 2>/dev/null)"
expect "literal: a force-added ignored file is not deleted" "SECRET=1" "$(cat .env 2>/dev/null)"

# --- AC27: the --out folder exemption ---
new_repo ac27
put CLAUDE.md '# Root'
put .claude/settings.json '{}'
put .claude/tracked/keep.txt 'k'
commit_base
state="$(bash "$GUARD" before)"
mkdir -p .claude/maintain-run && put .claude/maintain-run/result.json '{}' && put .claude/maintain-run/log.txt 'x'
rc=0; out="$(bash "$GUARD" after --state "$state" --allow .claude/maintain-run/result.json --allow .claude/maintain-run/)" || rc=$?
expect "AC27: writes under an exempt --out folder are not violations" "0 0" "$rc $(field "$out" 'len(d["violations"])')"

for bad in ./ .claude/ .claude/rules/ .claude/rules/deep/ .claude/tracked/ src/; do
  rc=0; bash "$GUARD" prefix-ok "$bad" 2>/dev/null || rc=$?
  expect "AC27: prefix-ok refuses $bad" 2 "$rc"
done
rc=0; bash "$GUARD" prefix-ok .claude/maintain-run/ || rc=$?
expect "AC27: prefix-ok accepts an untracked folder under .claude/" 0 "$rc"

bash "$GUARD" before --state "$SCRATCH/refused.json" >/dev/null
rc=0; bash "$GUARD" after --state "$SCRATCH/refused.json" --allow .claude/ >/dev/null 2>&1 || rc=$?
expect "AC27: after refuses a bad --allow prefix with exit 2" 2 "$rc"

for out_at in result.json .claude/result.json; do
  state="$(bash "$GUARD" before)"
  put "$out_at" '{}'
  put "$(dirname "$out_at")/sibling.txt" 'x'
  rc=0; out="$(bash "$GUARD" after --state "$state" --allow "$out_at")" || rc=$?
  sibling="$(dirname "$out_at")/sibling.txt"
  sibling="${sibling#./}"
  expect "AC27: --out at $out_at exempts only the file" "$sibling" \
    "$(field "$out" '" ".join(v["path"] for v in d["violations"])')"
  rm -f "$out_at" "$sibling"
done

bash "$GUARD" before --state "$SCRATCH/foreign.json" >/dev/null
new_repo other
rc=0; bash "$GUARD" after --state "$SCRATCH/foreign.json" >/dev/null 2>&1 || rc=$?
expect "a state file from another repository is refused" 2 "$rc"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_guard: all checks passed"; exit 0; fi
echo "test_maintain_guard: $failures check(s) failed"; exit 1
