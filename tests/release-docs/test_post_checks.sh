#!/usr/bin/env bash
# test_post_checks.sh — the write fence, the no-waiver rule and --pr-body (release-docs spec § 6–7).
# Gate, render and belts are skipped here: they run against the real repo in CI and in Task 10.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"
export RELEASE_DOCS_SKIP=gate,render,belts

fx_repo fence
put owner-scratch.txt 'mine'                       # untracked before the run: must survive
git status --porcelain --untracked-files=all > "$SCRATCH/before"
put alpha/README.md '# alpha' '' 'edited'          # a doc surface: allowed
put alpha/scripts/tool.sh 'echo changed'           # tracked, outside the surfaces: restored
put alpha/new-code.py 'x = 1'                      # new, outside the surfaces: removed
RC=0; bash "$POST" --before "$SCRATCH/before" --report "$SCRATCH/r.md" >/dev/null 2>&1 || RC=$?
expect "T6-FENCE exit 1" 1 "$RC"
expect "T6-FENCE tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
[ -e alpha/new-code.py ] && fail "T6-FENCE new-code.py survived" || echo "ok: T6-FENCE new file removed"
[ -e owner-scratch.txt ] && echo "ok: T6-FENCE pre-existing untracked file untouched" || fail "T6-FENCE deleted the owner's file"
expect "T6-FENCE README edit kept" "edited" "$(tail -n 1 alpha/README.md)"
grep -q 'FENCE: restored alpha/scripts/tool.sh' "$SCRATCH/r.md" && echo "ok: T6-FENCE reported" || fail "T6-FENCE report: $(cat "$SCRATCH/r.md")"

RC=0; bash "$POST" --before "$SCRATCH/before" --report "$SCRATCH/r2.md" >/dev/null 2>&1 || RC=$?
expect "T6-CLEAN only allowed edits -> exit 0" 0 "$RC"

python3 -c "import json; json.dump({'schemaVersion':1,'intentional':[],'entries':{'alpha@1.1.0#abc':{'disposition':'waived','reason':'x'}}}, open('.github/docs-ledger.json','w'))"
RC=0; bash "$POST" --before "$SCRATCH/before" --report "$SCRATCH/r3.md" >/dev/null 2>&1 || RC=$?
expect "T6-WAIVED exit 1" 1 "$RC"
grep -q 'waived' "$SCRATCH/r3.md" && echo "ok: T6-WAIVED reported" || fail "T6-WAIVED report: $(cat "$SCRATCH/r3.md")"

RC=0; bash "$POST" --report "$SCRATCH/r4.md" >/dev/null 2>&1 || RC=$?
expect "T6-NOBEFORE exit 2" 2 "$RC"
RC=0; bash "$POST" --before >/dev/null 2>&1 || RC=$?
expect "T6-NOBEFORE a valueless --before exits 2" 2 "$RC"

# T6-WAIVER-KEPT: the ledger re-dumped (new indent, sorted keys, one entry added) still holds the
# owner's committed waiver unchanged — not an added waiver, though a line diff shows it as "+".
fx_repo waiver
python3 -c "import json; json.dump({'schemaVersion':1,'intentional':[],'entries':{'alpha@1.0.0#own':{'disposition':'waived','reason':'owner call'}}}, open('.github/docs-ledger.json','w'))"
git commit -qam 'owner waiver'
git status --porcelain --untracked-files=all > "$SCRATCH/before-w"
python3 - <<'PY'
import json
d = json.load(open(".github/docs-ledger.json"))
d["entries"]["alpha@1.1.0#new"] = {"disposition": "covered", "at": ["site/alpha/index.html#skills"]}
json.dump(d, open(".github/docs-ledger.json", "w"), indent=2, sort_keys=True)
PY
RC=0; bash "$POST" --before "$SCRATCH/before-w" --report "$SCRATCH/w1.md" >/dev/null 2>&1 || RC=$?
expect "T6-WAIVER-KEPT reformatted ledger keeping the owner's waiver -> exit 0" 0 "$RC"

# T6-WAIVER-EDITED: rewording the owner's waiver is a change to a waiver, so it fails.
python3 - <<'PY'
import json
d = json.load(open(".github/docs-ledger.json"))
d["entries"]["alpha@1.0.0#own"]["reason"] = "the bot's reason"
json.dump(d, open(".github/docs-ledger.json", "w"), indent=2)
PY
RC=0; bash "$POST" --before "$SCRATCH/before-w" --report "$SCRATCH/w2.md" >/dev/null 2>&1 || RC=$?
expect "T6-WAIVER-EDITED exit 1" 1 "$RC"
grep -q 'alpha@1.0.0#own' "$SCRATCH/w2.md" && echo "ok: T6-WAIVER-EDITED names the entry" || fail "T6-WAIVER-EDITED report: $(cat "$SCRATCH/w2.md")"

# T6-WAIVER-BADJSON: an unparseable ledger fails the check with a message; it does not crash.
put .github/docs-ledger.json '{ not json'
RC=0; bash "$POST" --before "$SCRATCH/before-w" --report "$SCRATCH/w3.md" >/dev/null 2>&1 || RC=$?
expect "T6-WAIVER-BADJSON exit 1" 1 "$RC"
grep -q 'not valid JSON' "$SCRATCH/w3.md" && echo "ok: T6-WAIVER-BADJSON reported" || fail "T6-WAIVER-BADJSON report: $(cat "$SCRATCH/w3.md")"

# T6-PRBODY: resolved / still open / ledger table / verifier disputes.
fx_repo prbody
bump 1.1.0 '- New fly skill.'
detect; cp "$OUT" "$SCRATCH/before.json"
bash "$DETECT" --fix-mechanical >/dev/null
printf '[{"file":"site/alpha/index.html","claim":"fly is fast","verdict":"unsupported","evidence":"no source"},{"file":"x","claim":"y","verdict":"ok","evidence":"z"}]\n' > "$SCRATCH/v.json"
body="$(bash "$DETECT" --range main..HEAD --pr-body --before "$SCRATCH/before.json" --verifier "$SCRATCH/v.json")"
case "$body" in *"### Resolved (3)"*) echo "ok: T6-PRBODY resolved badges" ;; *) fail "T6-PRBODY resolved: $body" ;; esac
case "$body" in *"**undeclared**"*) echo "ok: T6-PRBODY undeclared entry shown" ;; *) fail "T6-PRBODY ledger table: $body" ;; esac
case "$body" in *"Verifier disagreements (1)"*"fly is fast"*) echo "ok: T6-PRBODY dispute listed, ok verdict dropped" ;; *) fail "T6-PRBODY verifier: $body" ;; esac

# T6-PRBODY-ID: two undeclared entries share one detail line; declaring one resolves that one only,
# so obligations are matched by entry id too, not by their identical text.
fx_repo prbody-id
bump 1.1.0 '- New fly skill.' '- Faster run.'
detect; cp "$OUT" "$SCRATCH/before-id.json"
id0="$(field changelog-entry id 0)"
python3 - "$id0" <<'PY'
import json, sys
json.dump({"schemaVersion": 1, "intentional": [], "entries": {
    sys.argv[1]: {"disposition": "not-user-facing", "reason": "internal"}}}, open(".github/docs-ledger.json", "w"))
PY
body="$(bash "$DETECT" --range main..HEAD --pr-body --before "$SCRATCH/before-id.json")"
case "$body" in *"### Resolved (1)"*"$id0"*"### Still open"*) echo "ok: T6-PRBODY-ID the declared entry alone is resolved" ;; *) fail "T6-PRBODY-ID: $body" ;; esac

exit "$failures"
