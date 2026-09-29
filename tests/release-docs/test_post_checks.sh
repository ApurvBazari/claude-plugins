#!/usr/bin/env bash
# test_post_checks.sh — the write fence, the no-waiver rule and --pr-body (release-docs spec § 6–7).
# Gate, render and belts are skipped here: they run against the real repo in CI and in Task 10.
# The render page *selection* is covered through docs-detect.sh --render-pages, which post-checks uses.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"
export RELEASE_DOCS_SKIP=gate,render,belts

snap() { # <name> — the pre-run snapshot, taken the way callers take it
  bash "$POST" --snapshot "$SCRATCH/$1" >/dev/null 2>&1 || fail "post-checks --snapshot $1 failed"
}
post() { # <snapshot> <report> — run post-checks after the "apply"; RC is its exit code
  RC=0
  bash "$POST" --before "$SCRATCH/$1" --report "$SCRATCH/$2" >/dev/null 2>&1 || RC=$?
}
has() { # <what> <report> <text> — the report holds the text
  if grep -qF -- "$3" "$SCRATCH/$2"; then echo "ok: $1"; else fail "$1 — no [$3] in: $(cat "$SCRATCH/$2")"; fi
}
lacks() { # <what> <report> <text>
  if grep -qF -- "$3" "$SCRATCH/$2"; then fail "$1 — [$3] in: $(cat "$SCRATCH/$2")"; else echo "ok: $1"; fi
}
gone() { # <what> <path>
  if [ -e "$2" ] || [ -L "$2" ]; then fail "$1 — $2 survived"; else echo "ok: $1"; fi
}
kept() { # <what> <path>
  if [ -e "$2" ]; then echo "ok: $1"; else fail "$1 — $2 is gone"; fi
}

fx_repo fence
put owner-scratch.txt 'mine'                       # untracked before the run: must survive
snap before
put alpha/README.md '# alpha' '' 'edited'          # a doc surface: allowed
put alpha/scripts/tool.sh 'echo changed'           # tracked, outside the surfaces: restored
put alpha/new-code.py 'x = 1'                      # new, outside the surfaces: removed
post before r.md
expect "T6-FENCE exit 1" 1 "$RC"
expect "T6-FENCE tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
gone "T6-FENCE new file removed" alpha/new-code.py
kept "T6-FENCE pre-existing untracked file untouched" owner-scratch.txt
expect "T6-FENCE README edit kept" "edited" "$(tail -n 1 alpha/README.md)"
has "T6-FENCE reported" r.md 'FENCE: restored alpha/scripts/tool.sh'

post before r2.md
expect "T6-CLEAN only allowed edits -> exit 0" 0 "$RC"

python3 -c "import json; json.dump({'schemaVersion':1,'intentional':[],'entries':{'alpha@1.1.0#abc':{'disposition':'waived','reason':'x'}}}, open('.github/docs-ledger.json','w'))"
post before r3.md
expect "T6-WAIVED exit 1" 1 "$RC"
has "T6-WAIVED reported" r3.md 'waived'

RC=0; bash "$POST" --report "$SCRATCH/r4.md" >/dev/null 2>&1 || RC=$?
expect "T6-NOBEFORE exit 2" 2 "$RC"
RC=0; bash "$POST" --before >/dev/null 2>&1 || RC=$?
expect "T6-NOBEFORE a valueless --before exits 2" 2 "$RC"

# T6-OLDSNAP: a plain `git status --porcelain` text snapshot is refused (exit 2) before anything is
# touched — matching it by line is what let the fence revert owner files.
fx_repo oldsnap
git status --porcelain --untracked-files=all > "$SCRATCH/old-snap"
put alpha/scripts/tool.sh 'echo changed'
post old-snap old.md
expect "T6-OLDSNAP exit 2" 2 "$RC"
expect "T6-OLDSNAP nothing restored" "echo changed" "$(tail -n 1 alpha/scripts/tool.sh)"
has "T6-OLDSNAP reason in the report" old.md 'snapshot'

# T6-WIDEN: the run widens its own fence three ways — a "**" surface, a page pointed at code, a
# phantom plugin whose dir is alpha/scripts. The allowlist comes from HEAD, so none of it works.
fx_repo widen
snap b-widen
python3 - <<'PY'
import json
d = json.load(open(".github/docs-surfaces.json"))
d["surfaces"].append("**")
d["pages"]["alpha"] = "alpha/scripts/tool.sh"
json.dump(d, open(".github/docs-surfaces.json", "w"))
m = json.load(open(".claude-plugin/marketplace.json"))
m["plugins"].append({"name": "x", "source": "./alpha/scripts", "version": "1.0.0", "description": "d"})
json.dump(m, open(".claude-plugin/marketplace.json", "w"))
PY
put alpha/scripts/tool.sh 'echo evil'
put alpha/scripts/README.md 'phantom plugin readme'
put .github/workflows/pwn.yml 'on: push'
post b-widen widen.md
expect "T6-WIDEN exit 1" 1 "$RC"
expect "T6-WIDEN tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
gone "T6-WIDEN new workflow removed" .github/workflows/pwn.yml
gone "T6-WIDEN phantom-plugin README removed" alpha/scripts/README.md
has "T6-WIDEN marketplace restored" widen.md 'FENCE: restored .claude-plugin/marketplace.json'
has "T6-WIDEN config change reported" widen.md 'changed .github/docs-surfaces.json key(s) pages, surfaces'

# T6-SURF-BROKEN: a malformed working-tree docs-surfaces.json still gets fenced around, and reported.
fx_repo broken
snap b-broken
put .github/docs-surfaces.json '{ broken'
put alpha/scripts/tool.sh 'echo evil'
put alpha/evil.py 'x=1'
post b-broken broken.md
expect "T6-SURF-BROKEN exit 1" 1 "$RC"
expect "T6-SURF-BROKEN tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
gone "T6-SURF-BROKEN new file removed" alpha/evil.py
has "T6-SURF-BROKEN reported" broken.md 'left .github/docs-surfaces.json unreadable'

# T6-STATIC: when HEAD's own config cannot be read, the fence still runs, against the static minimum.
fx_repo static
put .github/docs-surfaces.json '{ broken'
git commit -qam 'broken config'
snap b-static
put alpha/README.md '# alpha' '' 'edited'
put .github/docs-ledger.json '{"schemaVersion":1,"entries":{},"intentional":[]}' ''
post b-static static.md
expect "T6-STATIC exit 1" 1 "$RC"
expect "T6-STATIC README restored (no surfaces without a config)" "- **jq** (optional) — with a \`python3\` fallback" "$(tail -n 1 alpha/README.md)"
expect "T6-STATIC ledger (static minimum) kept" "" "$(tail -n 1 .github/docs-ledger.json)"
has "T6-STATIC reason reported" static.md 'static minimum'

# T6-ARROW: an untracked name holding " -> " is one path, not a rename.
fx_repo arrow
snap b-arrow
mkdir -p "evil -> site/alpha"
printf 'x\n' > "evil -> site/alpha/index.html"
post b-arrow arrow.md
expect "T6-ARROW exit 1" 1 "$RC"
gone "T6-ARROW crafted path removed" "evil -> site/alpha/index.html"
has "T6-ARROW reported by its real name" arrow.md 'removed new file evil -> site/alpha/index.html'

# T6-NAMES: non-ASCII, quote, backslash, newline and glob-character names are removed and reported
# as themselves; a file named `*` must not act as a pathspec and unstage its neighbours.
fx_repo names
snap b-names
printf 'x\n' > "alpha/café.sh"
printf 'x\n' > 'alpha/q"uote.sh'
printf 'x\n' > 'alpha/back\slash.sh'
printf 'x\n' > "alpha/new
line.sh"
printf 'x\n' > 'alpha/scripts/*'
post b-names names.md
expect "T6-NAMES exit 1" 1 "$RC"
gone "T6-NAMES café removed" "alpha/café.sh"
gone "T6-NAMES quote removed" 'alpha/q"uote.sh'
gone "T6-NAMES backslash removed" 'alpha/back\slash.sh'
gone "T6-NAMES newline removed" "alpha/new
line.sh"
gone "T6-NAMES star removed" 'alpha/scripts/*'
has "T6-NAMES café reported as itself" names.md 'removed new file alpha/café.sh'
has "T6-NAMES newline name quoted on one line" names.md 'removed new file "alpha/new\nline.sh"'
expect "T6-NAMES tool.sh still tracked and clean" "" "$(git status --porcelain -- alpha/scripts/tool.sh)"

# T6-OWNER: owner work dirty before the run is never restored or removed; the run touching it
# outside the surfaces is a FAIL, reported, not reverted.
fx_repo owner
put alpha/scripts/tool.sh '#!/usr/bin/env bash' 'echo OWNER-STAGED'
git add alpha/scripts/tool.sh
put notes/owner.txt 'mine'
put notes/gone.txt 'mine too'
snap b-owner
put alpha/README.md '# alpha' '' 'edited'
post b-owner owner0.md
expect "T6-OWNER-QUIET owner work untouched by the run -> exit 0" 0 "$RC"
put alpha/scripts/tool.sh '#!/usr/bin/env bash' 'echo OWNER-STAGED' 'echo run-edit'
rm notes/gone.txt
post b-owner owner.md
expect "T6-OWNER exit 1" 1 "$RC"
expect "T6-OWNER staged content kept" "echo OWNER-STAGED" "$(git show :alpha/scripts/tool.sh | tail -n 1)"
expect "T6-OWNER run edit left for the owner" "echo run-edit" "$(tail -n 1 alpha/scripts/tool.sh)"
kept "T6-OWNER untracked owner file under a dir untouched" notes/owner.txt
has "T6-OWNER edit reported" owner.md 'run touched an owner-dirty file: alpha/scripts/tool.sh'
has "T6-OWNER deletion reported" owner.md 'run touched an owner-dirty file: notes/gone.txt'
lacks "T6-OWNER not restored" owner.md 'FENCE: restored alpha/scripts/tool.sh'

# T6-OWNER-DIR: a snapshot entry for a directory covers every path under it.
fx_repo ownerdir
put notes/owner.txt 'mine'
python3 - "$(git rev-parse HEAD)" > "$SCRATCH/b-dir" <<'PY'
import json, sys
print(json.dumps({"schemaVersion": 1, "kind": "release-docs-snapshot", "head": sys.argv[1],
                  "entries": {"notes/": {"xy": "??", "digest": "dir"}}}))
PY
post b-dir dir.md
expect "T6-OWNER-DIR exit 0" 0 "$RC"
kept "T6-OWNER-DIR file under the dir entry untouched" notes/owner.txt

# T6-HEADMOVED: a run that commits hides its changes from `git status`; that alone fails.
fx_repo moved
snap b-moved
put alpha/scripts/tool.sh 'echo evil'
git commit -qam 'the run commits'
post b-moved moved.md
expect "T6-HEADMOVED exit 1" 1 "$RC"
has "T6-HEADMOVED reported" moved.md 'HEAD moved during the run'

# T6-RENDER-SEL: only the landing page and plugin pages are rendered — never og-card.html, never
# a frozen path.
fx_repo render
put site/og-card.html '<html><body style="width:1200px">card</body></html>'
printf '<!-- run edit -->\n' >> site/alpha/index.html
printf '<!-- run edit -->\n' >> site/index.html
expect "T6-RENDER-SEL landing + plugin page, no og-card" "site/alpha/index.html site/index.html" \
  "$(bash "$DETECT" --render-pages | tr '\n' ' ' | sed 's/ $//')"
python3 - <<'PY'
import json
d = json.load(open(".github/docs-surfaces.json"))
d["frozen"].append("site/index.html")
json.dump(d, open(".github/docs-surfaces.json", "w"))
PY
git commit -qm 'freeze the landing' -- .github/docs-surfaces.json
expect "T6-RENDER-SEL frozen page skipped" "site/alpha/index.html" \
  "$(bash "$DETECT" --render-pages | tr '\n' ' ' | sed 's/ $//')"

# T6-WAIVER-KEPT: the ledger re-dumped (new indent, sorted keys, one entry added) still holds the
# owner's committed waiver unchanged — not an added waiver, though a line diff shows it as "+".
fx_repo waiver
python3 -c "import json; json.dump({'schemaVersion':1,'intentional':[],'entries':{'alpha@1.0.0#own':{'disposition':'waived','reason':'owner call'}}}, open('.github/docs-ledger.json','w'))"
git commit -qam 'owner waiver'
snap before-w
python3 - <<'PY'
import json
d = json.load(open(".github/docs-ledger.json"))
d["entries"]["alpha@1.1.0#new"] = {"disposition": "covered", "at": ["site/alpha/index.html#skills"]}
json.dump(d, open(".github/docs-ledger.json", "w"), indent=2, sort_keys=True)
PY
post before-w w1.md
expect "T6-WAIVER-KEPT reformatted ledger keeping the owner's waiver -> exit 0" 0 "$RC"

# T6-WAIVER-EDITED: rewording the owner's waiver is a change to a waiver, so it fails.
python3 - <<'PY'
import json
d = json.load(open(".github/docs-ledger.json"))
d["entries"]["alpha@1.0.0#own"]["reason"] = "the bot's reason"
json.dump(d, open(".github/docs-ledger.json", "w"), indent=2)
PY
post before-w w2.md
expect "T6-WAIVER-EDITED exit 1" 1 "$RC"
has "T6-WAIVER-EDITED names the entry" w2.md 'alpha@1.0.0#own'

# T6-WAIVER-BADJSON: an unparseable ledger fails the check with a message; it does not crash.
put .github/docs-ledger.json '{ not json'
post before-w w3.md
expect "T6-WAIVER-BADJSON exit 1" 1 "$RC"
has "T6-WAIVER-BADJSON reported" w3.md 'not valid JSON'

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

# T6-VERIFIER-MISSING: a --verifier file that is not there is said so, never dropped silently.
body="$(bash "$DETECT" --range main..HEAD --pr-body --before "$SCRATCH/before.json" --verifier "$SCRATCH/nope.json")"
case "$body" in *"### Verifier disagreements"*"verifier output missing: $SCRATCH/nope.json"*) echo "ok: T6-VERIFIER-MISSING said" ;; *) fail "T6-VERIFIER-MISSING: $body" ;; esac

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
