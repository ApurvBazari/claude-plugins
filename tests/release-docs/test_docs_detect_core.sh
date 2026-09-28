#!/usr/bin/env bash
# test_docs_detect_core.sh — docs-detect CLI, CHANGELOG parsing, entry ids, the ledger and the
# changelog-entry gate (release-docs spec § 5). Fixture markdown carries literal backticks.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"

# T2-CLEAN: a synced fixture has no changelog-entry obligation and the gate passes.
fx_repo clean
detect
expect "T2-CLEAN exit" 0 "$RC"
expect "T2-CLEAN no changelog-entry" 0 "$(count changelog-entry)"
RC=0; bash "$DETECT" --range main..HEAD --gate >/dev/null 2>&1 || RC=$?
expect "T2-CLEAN gate passes" 0 "$RC"

# T2-ENTRIES: 2 bullets + 1 standalone paragraph under ### headings -> 3 entries.
fx_repo entries
bump 1.1.0 '### Added' '- New `alpha:fly` skill.' '- Faster run' '  (continued line).' '' '### Notes' '' 'Nothing else changes.'
detect
expect "T2-ENTRIES three changelog-entry obligations" 3 "$(count changelog-entry)"
expect "T2-ENTRIES version field" "1.1.0" "$(field changelog-entry version)"
expect "T2-ENTRIES continuation joined" "Faster run (continued line)." "$(field changelog-entry text 1)"
RC=0; out="$(bash "$DETECT" --range main..HEAD --gate 2>&1)" || RC=$?
expect "T2-ENTRIES gate fails" 1 "$RC"
case "$out" in *"OPEN changelog-entry"*) echo "ok: T2-ENTRIES gate lists OPEN lines" ;; *) fail "T2-ENTRIES gate output: $out" ;; esac

# T2-LEDGER: covered with a real anchor, not-user-facing with a reason resolve; a bad anchor does not.
id0="$(field changelog-entry id 0)"; id1="$(field changelog-entry id 1)"; id2="$(field changelog-entry id 2)"
python3 - "$id0" "$id1" "$id2" <<'PY'
import json, sys
a, b, c = sys.argv[1:]
json.dump({"schemaVersion": 1, "intentional": [], "entries": {
    a: {"disposition": "covered", "at": ["site/alpha/index.html#skills"]},
    b: {"disposition": "not-user-facing", "reason": "internal speed-up"},
    c: {"disposition": "covered", "at": ["site/alpha/index.html#nowhere"]}}},
    open(".github/docs-ledger.json", "w"))
PY
detect
expect "T2-LEDGER one entry still open" 1 "$(count changelog-entry)"
case "$(field changelog-entry detail)" in *"not found"*) echo "ok: T2-LEDGER bad anchor named" ;; *) fail "T2-LEDGER detail: $(field changelog-entry detail)" ;; esac

# T2-REASON: not-user-facing / waived without a reason stay open; waived with a reason resolves.
python3 - "$id0" "$id1" "$id2" <<'PY'
import json, sys
a, b, c = sys.argv[1:]
json.dump({"schemaVersion": 1, "intentional": [], "entries": {
    a: {"disposition": "covered", "at": ["README.md#nope", "site/alpha/index.html#top"]},
    b: {"disposition": "not-user-facing"},
    c: {"disposition": "waived", "reason": "owner call"}}},
    open(".github/docs-ledger.json", "w"))
PY
detect
expect "T2-REASON two open (bad md anchor, missing reason)" 2 "$(count changelog-entry)"

# T2-MDANCHOR: a markdown heading slug is a valid anchor.
python3 - "$id0" "$id1" "$id2" <<'PY'
import json, sys
a, b, c = sys.argv[1:]
json.dump({"schemaVersion": 1, "intentional": [], "entries": {
    a: {"disposition": "covered", "at": ["alpha/README.md#alpharun"]},
    b: {"disposition": "not-user-facing", "reason": "internal"},
    c: {"disposition": "covered", "at": ["alpha/README.md#prerequisites"]}}},
    open(".github/docs-ledger.json", "w"))
PY
detect
expect "T2-MDANCHOR all resolved" 0 "$(count changelog-entry)"

# T2-REWORD: rewording a declared bullet reopens it.
sed -i.bak 's/Faster run/Much faster run/' alpha/CHANGELOG.md && rm -f alpha/CHANGELOG.md.bak
detect
expect "T2-REWORD reworded entry reopens" 1 "$(count changelog-entry)"

# T2-TWICE: two versions in one range (1.1.0 then 1.2.0) both count.
fx_repo twice
bump 1.1.0 '- One.'
bump 1.2.0 '- Two.' '- Three.'
detect
expect "T2-TWICE entries from both versions" 3 "$(count changelog-entry)"

# T2-CRLF: CRLF line endings give the same ids as LF.
fx_repo crlf
bump 1.1.0 '- One.' '- Two.'
detect; lf="$(field changelog-entry id 0) $(field changelog-entry id 1)"
python3 -c "import sys; p='alpha/CHANGELOG.md'; t=open(p,newline='').read(); open(p,'w',newline='').write(t.replace('\n','\r\n'))"
detect; crlf="$(field changelog-entry id 0) $(field changelog-entry id 1)"
expect "T2-CRLF ids unchanged" "$lf" "$crlf"

# T2-PLEASE: release-please headings and * bullets parse.
fx_repo please
python3 - <<'PY'
import json
for f in (".claude-plugin/marketplace.json", "alpha/.claude-plugin/plugin.json"):
    d = json.load(open(f))
    (d["plugins"][0] if "plugins" in d else d)["version"] = "1.2.0"
    json.dump(d, open(f, "w"))
t = open("alpha/CHANGELOG.md").read().replace("# Changelog\n\n", "# Changelog\n\n## [1.2.0](https://x/compare) (2026-03-01)\n\n### Features\n\n* add a thing ([abc](https://x))\n* add another\n\n", 1)
open("alpha/CHANGELOG.md", "w").write(t)
PY
git add -A && git commit -qm please
detect
expect "T2-PLEASE two entries" 2 "$(count changelog-entry)"

# T2-SUBDIR: running from a subdirectory gives the same report.
cd "$SCRATCH/please/alpha" || exit 1
detect
expect "T2-SUBDIR same count from alpha/" 2 "$(count changelog-entry)"
cd "$SCRATCH/please" || exit 1

# T2-BADREF / bad input: exit 2 with a message, never a traceback.
RC=0; bash "$DETECT" --range origin/main..HEAD --out "$SCRATCH/x.json" 2>"$SCRATCH/err" || RC=$?
expect "T2-BADREF exit 2" 2 "$RC"
case "$(cat "$SCRATCH/err")" in *"unknown ref: origin/main"*) echo "ok: T2-BADREF message" ;; *) fail "T2-BADREF stderr: $(cat "$SCRATCH/err")" ;; esac
grep -q Traceback "$SCRATCH/err" && fail "T2-BADREF printed a traceback"
printf 'not json' > .github/docs-ledger.json
RC=0; bash "$DETECT" --range main..HEAD --out "$SCRATCH/x.json" 2>/dev/null || RC=$?
expect "T2-BADLEDGER exit 2" 2 "$RC"
git checkout -q -- .github/docs-ledger.json
mv .github/docs-surfaces.json "$SCRATCH/s.json"
RC=0; bash "$DETECT" --range main..HEAD --out "$SCRATCH/x.json" 2>/dev/null || RC=$?
expect "T2-NOSURFACES exit 2" 2 "$RC"
mv "$SCRATCH/s.json" .github/docs-surfaces.json
RC=0; (cd "$SCRATCH" && bash "$DETECT" --out x.json 2>/dev/null) || RC=$?
expect "T2-NOREPO exit 2" 2 "$RC"
RC=0; bash "$DETECT" --range main..HEAD 2>/dev/null || RC=$?
expect "T2-NOMODE exit 2" 2 "$RC"

exit "$failures"
