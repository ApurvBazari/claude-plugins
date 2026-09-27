#!/usr/bin/env bash
# test_maintain_write.sh — maintain-write.sh and `maintain-guard.sh after --result`: the exact
# bytes of lesson entries in each destination (D7, D20, lesson-entries.md), the refusals, and the
# result file assembled from recorded entries + guard output (§ 6.3). The model never writes these
# bytes itself (owner decision 2026-09-27: .claude/ is a protected path). AC13 (formatting), AC28.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"
WRITE="$ROOT/onboard/scripts/maintain-write.sh"

lesson() { bash "$WRITE" lesson "$@"; }
same_file() {  # same_file <what> <path> <expected text with \n escapes> — byte-exact, trailing newlines too
  local want
  want="$(printf '%b' "$3"; echo x)"
  if [ "$(cat "$2"; echo x)" = "$want" ]; then echo "ok: $1"; else fail "$1"; diff <(printf '%b' "$3") "$2" | head -20; fi
}

new_repo lessons
put CLAUDE.md '# Root' '' '- Keep functions pure.'
put src/a.ts x
commit_base

expect "untargeted: prints the file" '{"file": ".claude/rules/lessons.md"}' \
  "$(lesson --id L-1 --text 'Round only at the output boundary.' --summary 'gate-1 steer' --ref 'matali run 1')"
lesson --id L-2 --text 'Run the price belt first.' --summary 'owner note' --ref 'matali run 1' >/dev/null
same_file "untargeted: header, entries, one blank line between" .claude/rules/lessons.md \
'# Lessons\n\n<!-- lesson:L-1 -->\n- Round only at the output boundary.\n  _evidence: gate-1 steer (matali run 1)_\n\n<!-- lesson:L-2 -->\n- Run the price belt first.\n  _evidence: owner note (matali run 1)_\n'

expect "paths: a new lessons-<slug>.md" '{"file": ".claude/rules/lessons-crm-lib.md"}' \
  "$(lesson --id L-3 --text 'Money is decimal.' --summary 's' --ref 'r' --paths 'apps/crm/src/lib/**' 'lib/x/**')"
same_file "paths: frontmatter in the lesson's order, header, entry" .claude/rules/lessons-crm-lib.md \
'---\npaths:\n  - "apps/crm/src/lib/**"\n  - "lib/x/**"\n---\n\n# Lessons\n\n<!-- lesson:L-3 -->\n- Money is decimal.\n  _evidence: s (r)_\n'

put .claude/rules/lessons-web.md '---' 'paths: apps/web/**, "packages/ui/**"' '---' '' '# Lessons'
expect "AC28: an equal set written as a comma string is reused" '{"file": ".claude/rules/lessons-web.md"}' \
  "$(lesson --id L-4 --text 'Use the UI kit.' --summary 's' --ref 'r' --paths 'packages/ui/**' './apps/web/**')"
same_file "reuse: frontmatter untouched, entry appended" .claude/rules/lessons-web.md \
'---\npaths: apps/web/**, "packages/ui/**"\n---\n\n# Lessons\n\n<!-- lesson:L-4 -->\n- Use the UI kit.\n  _evidence: s (r)_\n'

lesson --id L-5 --text 'Server actions return BusinessError.' --summary 'owner note' --ref 'r' --file CLAUDE.md >/dev/null
lesson --id L-6 --text 'Never throw from actions.' --summary 'owner note' --ref 'r' --file CLAUDE.md >/dev/null
same_file "file target: a marker section, then an entry inserted before its end" CLAUDE.md \
'# Root\n\n- Keep functions pure.\n\n<!-- onboard:lessons:start -->\n<!-- lesson:L-5 -->\n- Server actions return BusinessError.\n  _evidence: owner note (r)_\n\n<!-- lesson:L-6 -->\n- Never throw from actions.\n  _evidence: owner note (r)_\n<!-- onboard:lessons:end -->\n'

rc=0; lesson --id L-7 --text 'x' --summary 's' --ref 'r' --file src/a.ts 2>/dev/null || rc=$?
expect "a target outside tooling is refused" 2 "$rc"
rc=0; lesson --id L-1 --text 'again' --summary 's' --ref 'r' >/dev/null 2>&1 || rc=$?
expect "an id already in the destination: exit 3, nothing written" "3 1" "$rc $(grep -c 'lesson:L-1' .claude/rules/lessons.md)"
rc=0; lesson --id 'L--bad' --text 'x' --summary 's' --ref 'r' 2>/dev/null || rc=$?
expect "a marker-breaking id is refused" 2 "$rc"
rc=0; lesson --id L-8 --text $'two\nlines' --summary 's' --ref 'r' 2>/dev/null || rc=$?
expect "multi-line text is refused" 2 "$rc"

# --- existing bytes are never rewritten: CRLF files keep every line ending; a symlinked
# CLAUDE.md stays a symlink and the lesson lands in its target ---
new_repo bytes
printf '# Web\r\n\r\n## Notes\r\n- Keep it small.\r\n' > CLAUDE.md
printf '# Shared\n' > AGENTS.md
mkdir -p apps/web && ln -s ../../AGENTS.md apps/web/CLAUDE.md
commit_base
lesson --id L-20 --text 'First CRLF lesson.' --summary s --ref r --file CLAUDE.md >/dev/null
lesson --id L-21 --text 'Second CRLF lesson.' --summary s --ref r --file CLAUDE.md >/dev/null
expect "CRLF: no existing line is rewritten (0 deletions)" "0" "$(git diff --numstat -- CLAUDE.md | cut -f2)"
expect "CRLF: every line ending stays CRLF" "True" \
  "$(python3 -c 'import sys; b=open(sys.argv[1],"rb").read(); print(b.count(b"\n") == b.count(b"\r\n") and b"<!-- lesson:L-21 -->" in b)' CLAUDE.md)"
lesson --id L-22 --text 'Shared lesson.' --summary s --ref r --file apps/web/CLAUDE.md >/dev/null
if [ -L apps/web/CLAUDE.md ]; then echo "ok: symlink: CLAUDE.md is still a symlink"; else fail "symlink: CLAUDE.md was replaced by a regular file"; fi
expect "symlink: the lesson lands in the link's target" "1" "$(grep -c 'lesson:L-22' AGENTS.md)"

# --- result assembly: recorded entries + guard output ---
new_repo result
put CLAUDE.md '# Root'
put src/a.ts a
commit_base
put package.json '{"name":"x","scripts":{"t":"y"}}'
put tsconfig.json '{}'
git add -A && git commit -qm two
# shellcheck disable=SC2034  # BASE is read by detect() in maintain-helpers.sh
BASE="$(git rev-parse HEAD~1)"
detect
state="$(bash "$GUARD" before)"
echo "- \`npm run t\` — y" >> CLAUDE.md
bash "$WRITE" record --state "$state" applied --id D1 --file CLAUDE.md --summary '`npm run t` under # Root'
cfg_id="$(item config-changed 'i["id"]')"
bash "$WRITE" record --state "$state" item --detect "$OUT" --id "$cfg_id"
bash "$WRITE" record --state "$state" deferred --id L-9 --reason possible-duplicate --hint 'compare with the existing line' --existing CLAUDE.md:1
bash "$WRITE" record --state "$state" skipped --id L-10 --file .claude/rules/lessons.md
lesson --id L-11 --text 'A new rule.' --summary 's' --ref 'r' >/dev/null
echo "oops" >> src/a.ts
mkdir -p .claude/maintain-run
rc=0; bash "$GUARD" after --state "$state" --allow .claude/maintain-run/ --result .claude/maintain-run/maintain-result.json >/dev/null || rc=$?
expect "after --result: exit 3 with a violation" 3 "$rc"
OUT="$REPO/.claude/maintain-run/maintain-result.json"
expect "result: applied" "D1 CLAUDE.md" "$(q '" ".join(a["id"] + " " + a["file"] for a in d["applied"])')"
expect "result: deferred = recorded entries, then G1" "$cfg_id:needs-review:/onboard:update L-9:possible-duplicate:CLAUDE.md:1 G1:guard-violation:src/a.ts" \
  "$(q '" ".join(e["id"] + ":" + e["reason"] + ":" + (e.get("command") or e.get("existing") or e.get("path", "")) for e in d["deferred"])')"
expect "result: a copied item keeps its context and gets a summary" "config-changed tsconfig.json config-changed: tsconfig.json" \
  "$(q '" ".join([d["deferred"][0]["kind"], d["deferred"][0]["file"], d["deferred"][0]["summary"]])')"
expect "result: skipped" "L-10 already-present" "$(q '" ".join(s["id"] + " " + s["reason"] for s in d["skipped"])')"
expect "result: filesWritten from the guard" ".claude/rules/lessons.md CLAUDE.md" "$(q '" ".join(d["filesWritten"])')"
if python3 - "$ROOT/onboard/schemas/maintain-result.json" "$OUT" <<'PY'
import json, sys
try:
    import jsonschema
except ImportError:
    sys.exit(0)
jsonschema.validate(json.load(open(sys.argv[2])), json.load(open(sys.argv[1])))
PY
then echo "ok: result validates against maintain-result.json"; else fail "result does not validate"; fi

rc=0; bash "$WRITE" record --state "$SCRATCH/none.json" applied --id D1 --file CLAUDE.md --summary s 2>/dev/null || rc=$?
expect "record without a state file is refused" 2 "$rc"

# record stores repo-relative paths whatever form the model passes (§ 6.3): absolute, through a
# symlinked prefix ($TMPDIR is /var/… on macOS, git reports /private/var/…), or relative.
state="$(bash "$GUARD" before)"
real="$(pwd -P)"
bash "$WRITE" record --state "$state" applied --id D1 --file "$REPO/CLAUDE.md" --summary s
bash "$WRITE" record --state "$state" applied --id D2 --file "$real/CLAUDE.md" --summary s
bash "$WRITE" record --state "$state" skipped --id L-1 --file "$REPO/.claude/rules/lessons.md"
bash "$WRITE" record --state "$state" deferred --id L-2 --reason possible-duplicate --hint h --existing "$real/CLAUDE.md:24"
expect "record: absolute --file paths become repo-relative" "D1 CLAUDE.md D2 CLAUDE.md L-1 .claude/rules/lessons.md" \
  "$(python3 -c 'import json,sys; e=json.load(open(sys.argv[1]))["entries"]; print(" ".join(x["id"] + " " + x["file"] for x in e["applied"] + e["skipped"]))' "$state")"
expect "record: the file part of --existing becomes repo-relative" "CLAUDE.md:24" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["entries"]["deferred"][0]["existing"])' "$state")"
rc=0; bash "$WRITE" record --state "$state" applied --id D3 --file "$SCRATCH/elsewhere.md" --summary s 2>/dev/null || rc=$?
expect "record: a --file outside the repo is refused" 2 "$rc"
rm -f "$state"
rc=0; bash "$WRITE" early --out "$REPO/.claude/maintain-run/early.json" --id X1 --reason bad-input --hint 'detect.json is not JSON' || rc=$?
OUT="$REPO/.claude/maintain-run/early.json"
expect "early: one deferred bad-input, nothing else" "0 X1:bad-input 0 0 0" \
  "$rc $(q '" ".join(e["id"] + ":" + e["reason"] for e in d["deferred"]) + " " + str(len(d["applied"])) + " " + str(len(d["skipped"])) + " " + str(len(d["filesWritten"]))')"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_write: all checks passed"; exit 0; fi
echo "test_maintain_write: $failures check(s) failed"; exit 1
