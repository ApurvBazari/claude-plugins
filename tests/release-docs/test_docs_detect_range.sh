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

exit "$failures"
