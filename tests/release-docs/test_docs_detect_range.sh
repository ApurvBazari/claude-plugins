#!/usr/bin/env bash
# test_docs_detect_range.sh — prerequisite-new, stale-mention and --candidates (release-docs spec § 5).
# shellcheck disable=SC2016
# SC2015: each `check && echo ok || fail` reporter is intended — echo cannot fail, so fail runs
# exactly when the check does.
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"

# T4-PREREQ: a script changed in range adds hard deps (a for-loop form); git is listed, python3 is
# only a mention inside the jq bullet, so it still counts as missing. An `if command -v` is optional.
fx_repo prereq
put alpha/scripts/new.sh '#!/usr/bin/env bash' 'set -euo pipefail' \
  'for cmd in git python3; do' \
  '  command -v "$cmd" >/dev/null 2>&1 || { echo "need $cmd" >&2; exit 2; }' 'done' \
  'if command -v jq >/dev/null 2>&1; then jq . x; fi'
git add -A && git commit -qm script
detect
expect "T4-PREREQ README + page" 2 "$(count prerequisite-new)"
expect "T4-PREREQ names python3" "python3" "$(field prerequisite-new item)"

# T4-MISSINGVAR: the `missing=` accumulator form counts as hard.
fx_repo missingvar
put alpha/scripts/acc.sh '#!/usr/bin/env bash' 'missing=""' \
  'command -v node >/dev/null 2>&1 || missing="node"' '[ -z "$missing" ] || exit 2'
git add -A && git commit -qm acc
detect
expect "T4-MISSINGVAR node flagged (README + page)" 2 "$(count prerequisite-new)"

# T4-IFNOT: `if ! command -v X; then … exit 1; fi` is hard, however far down the block its exit is
# (notify/scripts/install-notifier.sh's idiom); an `if !` block with no exit is still optional.
fx_repo ifnot
put alpha/scripts/neg.sh '#!/usr/bin/env bash' \
  'if ! command -v node >/dev/null 2>&1; then' '  echo "node is required" >&2' \
  '  echo "install it first" >&2' '  echo "then re-run" >&2' '  exit 1' 'fi' \
  'if ! command -v jq >/dev/null 2>&1; then echo "no jq; falling back"; fi'
git add -A && git commit -qm neg
detect
expect "T4-IFNOT node flagged (README + page)" 2 "$(count prerequisite-new)"
expect "T4-IFNOT names node, never the exit-less jq" "node node" \
  "$(field prerequisite-new item 0) $(field prerequisite-new item 1)"

# T4-NOSECTION: a README with no Prerequisites section and a page with no prerequisites grid still
# owe the hard dep — each obligation says to add the missing list.
fx_repo nosection
put alpha/README.md '# alpha' '' '## Skills' '' '### `/alpha:run`' '' 'Runs.'
sed -i.bak -e '/sec-label">prerequisites/d' \
  -e 's#<div class="edge"><div class="n">git</div><div class="t">Required</div></div></section>#</section>#' \
  site/alpha/index.html
rm -f site/alpha/index.html.bak
git add -A && git commit -qm "no prerequisites" && git branch -f main HEAD
put alpha/scripts/py.sh '#!/usr/bin/env bash' 'command -v python3 >/dev/null 2>&1 || exit 2'
git add -A && git commit -qm py
detect
expect "T4-NOSECTION README obligation" 1 "$(count prerequisite-new alpha/README.md)"
expect "T4-NOSECTION page obligation" 1 "$(count prerequisite-new site/alpha/index.html)"
case "$(field prerequisite-new detail 0)" in
  *"add a Prerequisites section"*) echo "ok: T4-NOSECTION README detail says to add the section" ;;
  *) fail "T4-NOSECTION README detail: $(field prerequisite-new detail 0)" ;;
esac
case "$(field prerequisite-new detail 1)" in
  *"add a prerequisites grid"*) echo "ok: T4-NOSECTION page detail says to add the grid" ;;
  *) fail "T4-NOSECTION page detail: $(field prerequisite-new detail 1)" ;;
esac

# T4-STALE: a CHANGELOG rename makes the old name a candidate; README still names it.
fx_repo stale
put alpha/README.md '# alpha' '' '## Skills' '' '### `/alpha:run`' '' 'Writes `.claude/old-log.json`.' '' \
  '## Prerequisites' '' '- **git** — history'
git add -A && git commit -qm readme
git branch -f main HEAD
bump 1.1.0 '- The log `.claude/old-log.json` is renamed to `.claude/new-log.json`.'
detect
expect "T4-STALE one stale-mention (path and basename on one line collapse)" 1 "$(count stale-mention alpha/README.md)"
expect "T4-STALE token is the longest match" ".claude/old-log.json" "$(field stale-mention token)"
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if '.claude/old-log.json' in c and 'old-log.json' in c and '.claude/new-log.json' not in c else 1)" \
  && echo "ok: T4-CANDIDATES old in, new out" || fail "T4-CANDIDATES $(cat "$SCRATCH/c.json")"

# T4-INTENTIONAL: context on the line resolves; a different line is still open.
python3 - <<'PY'
import json
json.dump({"schemaVersion": 1, "entries": {}, "intentional": [
    {"file": "alpha/README.md", "token": ".claude/old-log.json", "context": "legacy",
     "reason": "legacy name is still read"}]}, open(".github/docs-ledger.json", "w"))
PY
detect
expect "T4-INTENTIONAL context absent from the line -> still open" 1 "$(count stale-mention)"
sed -i.bak 's/Writes `.claude\/old-log.json`./Reads the legacy `.claude\/old-log.json` too./' alpha/README.md
detect
expect "T4-INTENTIONAL context on the line -> resolved" 0 "$(count stale-mention)"

# T4-RETIRED + T4-BOUNDARY: a retired token is flagged on a page; /alpha:ru does not match /alpha:run.
fx_repo retired
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=['/alpha:ru','old-thing.json']; json.dump(d, open(p,'w'))"
sed -i.bak 's#<h1>alpha</h1>#<h1>alpha</h1><p>See <code>old-thing.json</code>.</p>#' site/alpha/index.html
detect
expect "T4-RETIRED page mention" 1 "$(count stale-mention site/alpha/index.html)"
expect "T4-BOUNDARY /alpha:ru never matches /alpha:run" "old-thing.json" "$(field stale-mention token)"
mkdir -p site/alpha/examples && printf '<p>old-thing.json</p>\n' > site/alpha/examples/session.html
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['surfaces'].append('site/**/*.html'); json.dump(d, open(p,'w'))"
detect
expect "T4-FROZEN a surface glob that reaches examples/ is still overruled by frozen" 1 "$(count stale-mention)"
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['frozen']=[]; json.dump(d, open(p,'w'))"
detect
expect "T4-FROZEN non-vacuous: without frozen the example is flagged" 2 "$(count stale-mention)"

# T4-BOUNDARY-HYPHEN: a retired name never matches a live one it prefixes across `-` or `.x`
# (Review Focus 4: /lens:render vs /lens:render-review); sentence punctuation still ends a name.
fx_repo hyphen
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=['/alpha:go','alpha-log']; json.dump(d, open(p,'w'))"
put alpha/README.md '# alpha' '' '## Skills' '' '### `/alpha:run`' '' 'Use `/alpha:go-fast` now.' \
  'Writes `alpha-log.json`.' 'See `alpha-log-v2`.' '' '## Prerequisites' '' '- **git** — history'
detect
expect "T4-BOUNDARY-HYPHEN no match across - or .x" 0 "$(count stale-mention)"
printf '%s\n' 'Old: `/alpha:go`.' 'Old log: alpha-log.' >> alpha/README.md
detect
expect "T4-BOUNDARY-HYPHEN non-vacuous: exact names before punctuation match" 2 "$(count stale-mention)"

# T4-REMOVED: a removed skill becomes /alpha:<name>; a deleted file's full path is a candidate.
fx_repo removed
put alpha/skills/old/SKILL.md '---' 'name: old' 'description: Old.' '---'
put alpha/docs-note.md 'x'
git add -A && git commit -qm old && git branch -f main HEAD
git rm -rq alpha/skills/old alpha/docs-note.md && git commit -qm "remove old"
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if '/alpha:old' in c and 'alpha/docs-note.md' in c else 1)" \
  && echo "ok: T4-REMOVED candidates" || fail "T4-REMOVED $(cat "$SCRATCH/c.json")"

# T4-ALIVE: a token that still exists as a file is not a candidate.
fx_repo alive
put alpha/schema.json '{}'
git add -A && git commit -qm schema && git branch -f main HEAD
bump 1.1.0 '- `schema.json` relocated from `alpha/old/` to `alpha/`.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if 'schema.json' not in c and 'alpha/old/' in c else 1)" \
  && echo "ok: T4-ALIVE live file dropped, retired dir kept" || fail "T4-ALIVE $(cat "$SCRATCH/c.json")"

# T4-LIVE (final review C1): a live skill or agent named in a retirement sentence is never a
# candidate. The verb retires something of it (a flag, an output, a prompt), not the name, and on
# the real repo one such line opened 29 stale-mentions of `/onboard:evolve` on correct docs. Each
# phrasing reads the name (after a past verb, or under `### Removed`), so only liveness drops it.
# live_case <label> <live token> <changelog line...>
live_case() {
  local label="$1" tok="$2"
  shift 2
  fx_repo "live-$label"
  put alpha/skills/render-view/SKILL.md '---' 'name: render-view' 'description: Renders.' '---'
  printf '%s\n' '' 'Use `render-view`, and `alpha:checker` reviews.' >> alpha/README.md
  git add -A && git commit -qm live && git branch -f main HEAD
  bump 1.1.0 "$@"
  bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
  python3 -c "import json,sys; sys.exit(1 if sys.argv[1] in json.load(open(sys.argv[2])) else 0)" \
    "$tok" "$SCRATCH/c.json" \
    && echo "ok: T4-LIVE $label: live $tok is not a candidate" || fail "T4-LIVE $label $(tr -d '\n' < "$SCRATCH/c.json")"
  detect
  expect "T4-LIVE $label: no stale-mention of the live $tok" 0 "$(count stale-mention)"
}
live_case removed-from /alpha:run '- Removed the `--xx` flag from `/alpha:run`.'
live_case moved render-view '- Moved `render-view` output to a new path.'
live_case removed-heading /alpha:run '### Removed' '- `/alpha:run` no longer offers the `--yy` prompt.'
live_case agent alpha:checker '- Removed the `--zz` option from `alpha:checker`.'
# The retired name itself is still a candidate: a removed skill stays one beside a live sibling.
fx_repo live-removed
put alpha/skills/old-view/SKILL.md '---' 'name: old-view' 'description: Old.' '---'
git add -A && git commit -qm old && git branch -f main HEAD
git rm -rq alpha/skills/old-view && git commit -qm "remove old-view"
bump 1.1.0 '- Removed `old-view`; `/alpha:run` covers it.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open(sys.argv[1])); sys.exit(0 if 'old-view' in c and '/alpha:old-view' in c and '/alpha:run' not in c else 1)" \
  "$SCRATCH/c.json" && echo "ok: T4-LIVE non-vacuous: the removed skill is still a candidate" \
  || fail "T4-LIVE removed $(tr -d '\n' < "$SCRATCH/c.json")"

# T4-ACTOR (final review C1, deferred T4 item): before a present-tense or base-form verb stands its
# actor, not the thing retired — "`/onboard:evolve` now removes …", "`newKey` replaces `oldKey`" —
# while a past form still reads both sides ("`x` is removed", "Removed `x`"). T4-HYPHEN: a verb
# glued behind a hyphen ("unanimous-drop") is part of a compound name, not a verb.
fx_repo actor
bump 1.1.0 '- `newKey` replaces `oldKey` in the config.' '- `stayKey` now drops stale rows.' \
  '- The unanimous-drop rule in `x-rule.md` is clarified.' '- `gone-key` is removed.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open(sys.argv[1])); sys.exit(0 if 'oldKey' in c and 'gone-key' in c and 'newKey' not in c and 'stayKey' not in c else 1)" \
  "$SCRATCH/c.json" && echo "ok: T4-ACTOR the actor of a present verb is not a candidate; its object is" \
  || fail "T4-ACTOR $(tr -d '\n' < "$SCRATCH/c.json")"
python3 -c "import json,sys; sys.exit(1 if 'x-rule.md' in json.load(open(sys.argv[1])) else 0)" "$SCRATCH/c.json" \
  && echo "ok: T4-HYPHEN unanimous-drop is not a verb" || fail "T4-HYPHEN $(tr -d '\n' < "$SCRATCH/c.json")"

# V4 tuning, pinned with the exact entry shapes the full history produced.
# T4-CLAUSE: a retirement verb reads only its own clause (`:`, `—`, `–` and parentheses bound it).
# Live names in a lead-in, an aside or a parenthetical were the history's false candidates
# (walkthrough:render, codebase-analyzer, claude-opus-4-8[1m], guides/agents-guide, paths: …).
# T4-EVERYVERB: every verb is read, not only the first — the rename below sits behind a bold lead-in
# whose own `renamed with` splits before any token (onboard 3.1.0's greenfield-drift.json entry).
# T4-FIXTURE: a legacy file kept under a tests fixtures/ dir does not keep the retired name alive.
fx_repo clause
put tests/alpha/fixtures/legacy/.claude/old-drift.json '{}'
git add -A && git commit -qm fixture && git branch -f main HEAD
bump 1.1.0 \
  '- fix: `alpha:run` is now model-invocable — dropped `disable-model-invocation: true` (kept `user-invocable: false`, matching `alpha:core`).' \
  '- **Dead `analysis` skill folded into `alpha-analyzer`**: the undispatched `old-analysis` skill is deleted;' \
  '- single-sourced the default (updated to `model-x[1m]`), and removed a phantom `answers.model` field.' \
  '- **Drift-log renamed with a migration (why)**: the drift log `.claude/old-drift.json` is renamed to `.claude/new-drift.json`.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); bad=[t for t in ('alpha:run','alpha:core','alpha-analyzer','model-x[1m]') if t in c]; sys.exit(1 if bad else 0)" \
  && echo "ok: T4-CLAUSE names outside the verb's clause are not candidates" || fail "T4-CLAUSE $(cat "$SCRATCH/c.json")"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if 'old-analysis' in c and 'answers.model' in c and '.claude/old-drift.json' in c else 1)" \
  && echo "ok: T4-EVERYVERB each verb's own object is a candidate" || fail "T4-EVERYVERB $(cat "$SCRATCH/c.json")"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if 'old-drift.json' in c and '.claude/new-drift.json' not in c else 1)" \
  && echo "ok: T4-FIXTURE a fixture copy does not keep old-drift.json alive" || fail "T4-FIXTURE $(cat "$SCRATCH/c.json")"

# Fix round 1 — recall holes the review found.
# T4-SECTION: a verbless bullet under a `### Removed` heading is a retirement (handoff 1.0.2's
# `trigger-phrases`); the same shape under `### Changed`, or under a heading that merely mentions a
# rename further in, is not.
fx_repo section
bump 1.1.0 '### Changed' '- The `other-knob` setting is documented.' '' \
  '### Fixes — the drift-log rename' '- The `live-knob` doc is clearer.' '' \
  '### Removed' '- The `trigger-knob` setting from the docs — it was never read by any code.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if c == ['trigger-knob'] else 1)" \
  && echo "ok: T4-SECTION only the Removed bullet's name" || fail "T4-SECTION $(cat "$SCRATCH/c.json")"

# T4-PRESENT: present and imperative verbs retire too (walkthrough 0.2.0's "Remove the …").
fx_repo present
bump 1.1.0 '- Remove the `collect-context.sh` helper and its smoke test — alpha is now script-free.' \
  '- Renames `old-key` to `new-key`.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if 'collect-context.sh' in c and 'old-key' in c and 'new-key' not in c else 1)" \
  && echo "ok: T4-PRESENT remove / renames" || fail "T4-PRESENT $(cat "$SCRATCH/c.json")"

# T4-WIDEN: when the verb's own clause holds no name and a colon or dash sits right beside the verb,
# the adjacent clause is read — the commonest retirement shapes.
fx_repo widen
bump 1.1.0 '- **Removed**: `old-tool.sh` and `other-tool.sh`.' '- Removed: `gone-tool.sh`.' \
  '- `dash-tool.sh` — removed; use `new-tool.sh` instead.'
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if sorted(c) == ['dash-tool.sh','gone-tool.sh','old-tool.sh','other-tool.sh'] else 1)" \
  && echo "ok: T4-WIDEN colon and dash shapes" || fail "T4-WIDEN $(cat "$SCRATCH/c.json")"

# T4-SCRIPTREL: a removed script or schema is a candidate as its plugin-relative path and basename
# too (spec § 5: removed script names and schema files), so a README naming scripts/tool.sh is caught.
fx_repo scriptrel
put alpha/schemas/out.schema.json '{}'
printf '%s\n' '' 'Run `scripts/tool.sh` to build.' >> alpha/README.md
git add -A && git commit -qm schema && git branch -f main HEAD
git rm -q alpha/scripts/tool.sh alpha/schemas/out.schema.json && git commit -qm "drop tool and schema"
detect
expect "T4-SCRIPTREL README names the removed script" 1 "$(count stale-mention alpha/README.md)"
expect "T4-SCRIPTREL token is the plugin-relative path" "scripts/tool.sh" "$(field stale-mention token)"
bash "$DETECT" --candidates main..HEAD > "$SCRATCH/c.json"
python3 -c "import json,sys; c=json.load(open('$SCRATCH/c.json')); sys.exit(0 if {'tool.sh','scripts/tool.sh','out.schema.json','schemas/out.schema.json'} <= set(c) else 1)" \
  && echo "ok: T4-SCRIPTREL relative path + basename for script and schema" || fail "T4-SCRIPTREL $(cat "$SCRATCH/c.json")"

# T4-BADDATA: malformed retired[] / intentional[] (the unattended model writes both) exits 2 with a
# message, never a traceback and never a pile of bogus obligations.
fx_repo baddata
for bad in "retired=[5]" 'retired=[""]' 'retired=["  "]'; do
  python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=json.loads('${bad#retired=}'); json.dump(d, open(p,'w'))"
  detect
  expect "T4-BADDATA $bad exits 2" 2 "$RC"
  expect "T4-BADDATA $bad no traceback" 0 "$(grep -c Traceback "$SCRATCH/stderr")"
done
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=[]; json.dump(d, open(p,'w'))"
for bad in '["oops"]' '[{"file": "alpha/README.md", "token": "x-y", "context": "", "reason": "r"}]' \
  '[{"file": "alpha/README.md", "token": "x-y", "context": "c", "reason": 5}]'; do
  python3 -c "import json,sys; json.dump({'schemaVersion': 1, 'entries': {}, 'intentional': json.loads(sys.argv[1])}, open('.github/docs-ledger.json', 'w'))" "$bad"
  detect
  expect "T4-BADDATA intentional $bad exits 2" 2 "$RC"
  expect "T4-BADDATA intentional $bad no traceback" 0 "$(grep -c Traceback "$SCRATCH/stderr")"
done

exit "$failures"
