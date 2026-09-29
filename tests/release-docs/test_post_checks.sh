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
within() { # <seconds> <cmd...> — a hard timeout, so a hang fails the belt; RC is 124 on timeout
  RC=0
  python3 - "$@" <<'PY' || RC=$?
import os, signal, subprocess, sys
p = subprocess.Popen(sys.argv[2:], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    sys.exit(p.wait(timeout=float(sys.argv[1])))
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    sys.exit(124)
PY
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

# T6-RETIRED-SHRINK (final review I2): retired[] only grows (spec § 5). Dropping a token silently
# closes every stale-mention of it without making a doc true, so the fence fails the run and names
# it. Adding a token, reordering the list and editing og stay allowed (T6-RETIRED-GROW).
fx_repo shrink
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=['old-a.json','old-b.json']; json.dump(d, open(p,'w'))"
git commit -qam 'seed retired'
snap b-shrink
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=['old-b.json','new-c.json']; json.dump(d, open(p,'w'))"
post b-shrink shrink.md
expect "T6-RETIRED-SHRINK exit 1" 1 "$RC"
has "T6-RETIRED-SHRINK names the dropped token" shrink.md 'dropped "old-a.json" from .github/docs-surfaces.json retired[]'
fx_repo grow
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=['old-a.json','old-b.json']; json.dump(d, open(p,'w'))"
git commit -qam 'seed retired'
snap b-grow
python3 - <<'PY'
import json
p = ".github/docs-surfaces.json"
d = json.load(open(p))
d["retired"] = ["new-c.json", "old-b.json", "old-a.json"]
d["og"]["site/alpha/index.html"]["title"] = "alpha — renamed"
json.dump(d, open(p, "w"))
PY
post b-grow grow.md
expect "T6-RETIRED-GROW exit 0 (grown, reordered, og edited)" 0 "$RC"
has "T6-RETIRED-GROW fence ok" grow.md '- ok: write fence'
# M5 (final review): a skipped step says so, so a local run's exit 0 is never read as a full pass.
has "M5-SKIPPED gate" grow.md '- SKIPPED: docs-detect gate'
has "M5-SKIPPED render" grow.md '- SKIPPED: render-check'
has "M5-SKIPPED belts" grow.md '- SKIPPED: tests/run-all.sh and the .github/scripts guards'

# T6-BELT-NAMES (rehearsal #14): a failing run-all names each failing belt with its FAIL lines, so the
# model can tell whether the failure is inside the doc surfaces; a passing belt is not named.
fx_repo beltnames
mkdir -p tests/a tests/b
cp "$ROOT/tests/run-all.sh" tests/run-all.sh
put tests/a/test_one.sh 'echo "ok: fine"'
put tests/b/test_two.sh 'echo "ok: first"' 'echo "FAIL: AC25 the belt count is stale"' 'exit 1'
git add -A && git commit -qm belts
snap b-beltnames
RC=0
RELEASE_DOCS_SKIP=gate,render bash "$POST" --before "$SCRATCH/b-beltnames" --report "$SCRATCH/beltnames.md" >/dev/null 2>&1 || RC=$?
expect "T6-BELT-NAMES exit 1" 1 "$RC"
has "T6-BELT-NAMES names the failing belt" beltnames.md 'tests/b/test_two.sh'
has "T6-BELT-NAMES carries its FAIL line" beltnames.md 'FAIL: AC25 the belt count is stale'
lacks "T6-BELT-NAMES a passing belt is not named" beltnames.md 'tests/a/test_one.sh'
# A retired that is no longer a list is a shrink too, and reported, never a crash.
fx_repo notlist
snap b-notlist
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']={'a': 1}; json.dump(d, open(p,'w'))"
post b-notlist notlist.md
expect "T6-RETIRED-NOTLIST exit 1" 1 "$RC"
has "T6-RETIRED-NOTLIST reported" notlist.md 'retired[] is no longer a list'

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
mkdir -p alpha/references
printf 'x\n' > "alpha/references/c
d.md"
post b-names names.md
expect "T6-NAMES exit 1" 1 "$RC"
gone "T6-NAMES café removed" "alpha/café.sh"
gone "T6-NAMES quote removed" 'alpha/q"uote.sh'
gone "T6-NAMES backslash removed" 'alpha/back\slash.sh'
gone "T6-NAMES newline removed" "alpha/new
line.sh"
gone "T6-NAMES star removed" 'alpha/scripts/*'
gone "T6-NAMES newline name under an allowed doc dir removed" "alpha/references/c
d.md"
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

# T6-DEEP: a working-tree config nested past Python's recursion limit cannot crash the fence before
# it reverts — the reverts come first, and the unreadable config is a FAIL line.
fx_repo deep
snap b-deep
python3 -c "print('[' * 200000 + ']' * 200000)" > .github/docs-surfaces.json
put alpha/scripts/tool.sh 'echo evil'
put alpha/evil.py 'x=1'
put .github/workflows/pwn.yml 'on: push'
post b-deep deep.md
expect "T6-DEEP exit 1" 1 "$RC"
expect "T6-DEEP tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
gone "T6-DEEP new file removed" alpha/evil.py
gone "T6-DEEP new workflow removed" .github/workflows/pwn.yml
has "T6-DEEP reported" deep.md 'left .github/docs-surfaces.json unreadable'
lacks "T6-DEEP no traceback" deep.md 'Traceback'

# T6-HEADCONF: a committed config that is not UTF-8, or nested too deep, still yields the static
# minimum fence — never "no fence".
fx_repo nonutf8
printf '{"schemaVersion":1, "x":"\377\376"}\n' > .github/docs-surfaces.json
git commit -qam 'non-UTF-8 config'
snap b-nonutf8
put alpha/scripts/tool.sh 'echo evil'
post b-nonutf8 nonutf8.md
expect "T6-HEADCONF non-UTF-8: exit 1" 1 "$RC"
expect "T6-HEADCONF non-UTF-8: tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
has "T6-HEADCONF non-UTF-8: static minimum" nonutf8.md 'static minimum'
fx_repo headdeep
python3 -c "print('{\"schemaVersion\":1,\"x\":' + '[' * 200000 + ']' * 200000 + '}')" > .github/docs-surfaces.json
git commit -qam 'nested config'
snap b-headdeep
put alpha/scripts/tool.sh 'echo evil'
post b-headdeep headdeep.md
expect "T6-HEADCONF deep: exit 1" 1 "$RC"
expect "T6-HEADCONF deep: tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
has "T6-HEADCONF deep: static minimum" headdeep.md 'static minimum'

# T6-NOMARKER: a fence that never printed FENCE-COMPLETE did not complete, whatever it said and
# whatever it exited with: exit 2, never "fenced".
fx_repo nomarker
snap b-nomarker
mkdir -p "$SCRATCH/stub"
cp "$POST" "$SCRATCH/stub/post-checks.sh"
printf '#!/usr/bin/env bash\necho "- ok: write fence"\n' > "$SCRATCH/stub/docs-detect.sh"
RC=0; bash "$SCRATCH/stub/post-checks.sh" --before "$SCRATCH/b-nomarker" --report "$SCRATCH/nm1.md" >/dev/null 2>&1 || RC=$?
expect "T6-NOMARKER 'ok' without the marker -> exit 2" 2 "$RC"
has "T6-NOMARKER reported" nm1.md 'did not run to completion'
printf '#!/usr/bin/env bash\necho "Traceback (most recent call last):" >&2\nexit 1\n' > "$SCRATCH/stub/docs-detect.sh"
RC=0; bash "$SCRATCH/stub/post-checks.sh" --before "$SCRATCH/b-nomarker" --report "$SCRATCH/nm2.md" >/dev/null 2>&1 || RC=$?
expect "T6-NOMARKER a crash exiting 1 -> exit 2" 2 "$RC"

# T6-RESNAP: the run cannot re-take the snapshot to launder its changes as the owner's.
fx_repo resnap
snap b-resnap
put alpha/scripts/tool.sh 'echo evil'
put .github/workflows/pwn.yml 'on: push'
RC=0; bash "$POST" --snapshot "$SCRATCH/b-resnap" >/dev/null 2>&1 || RC=$?
expect "T6-RESNAP a second --snapshot to the same file is refused" 2 "$RC"
post b-resnap resnap.md
expect "T6-RESNAP exit 1" 1 "$RC"
expect "T6-RESNAP tool.sh restored" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
gone "T6-RESNAP new workflow removed" .github/workflows/pwn.yml

# T6-EXPECT-CLEAN: CI's snapshot must be empty (a fresh checkout). A dirty one is reported, still
# fenced, and exits 2 — without deleting what it lists.
fx_repo cleanci
snap b-cleanci
put alpha/README.md '# alpha' '' 'edited'
RC=0; bash "$POST" --before "$SCRATCH/b-cleanci" --expect-clean --report "$SCRATCH/ci0.md" >/dev/null 2>&1 || RC=$?
expect "T6-EXPECT-CLEAN a clean snapshot and an allowed edit -> exit 0" 0 "$RC"
fx_repo dirtyci
put owner-scratch.txt 'mine'
snap b-dirtyci
put alpha/scripts/tool.sh 'echo evil'
RC=0; bash "$POST" --before "$SCRATCH/b-dirtyci" --expect-clean --report "$SCRATCH/ci1.md" >/dev/null 2>&1 || RC=$?
expect "T6-EXPECT-CLEAN a dirty snapshot -> exit 2" 2 "$RC"
has "T6-EXPECT-CLEAN reported" ci1.md '--expect-clean: the snapshot lists 1 dirty path(s)'
expect "T6-EXPECT-CLEAN still fenced" "echo tool" "$(tail -n 1 alpha/scripts/tool.sh)"
kept "T6-EXPECT-CLEAN the listed file is not deleted" owner-scratch.txt

# T6-IGNORE: .gitignore edits are put back before anything reads `git status`, so the owner's
# ignored files never look like the run's and are never deleted.
fx_repo ignore
printf 'private/\n*.local\n' > .gitignore
git add .gitignore && git commit -qm 'ignore private'
put private/plan.md 'owner plan'
put alpha/settings.local 'owner local'
snap b-ignore
printf '# tidied\n' > .gitignore
post b-ignore ignore.md
expect "T6-IGNORE-BLANK exit 1" 1 "$RC"
kept "T6-IGNORE-BLANK owner's ignored dir file kept" private/plan.md
kept "T6-IGNORE-BLANK owner's ignored *.local kept" alpha/settings.local
expect "T6-IGNORE-BLANK .gitignore restored" "*.local" "$(tail -n 1 .gitignore)"
has "T6-IGNORE-BLANK reported" ignore.md 'the run changed .gitignore (restored)'
fx_repo ignoreneg
printf '*.local\n' > .gitignore
git add .gitignore && git commit -qm 'ignore local'
put alpha/settings.local 'owner local'
snap b-ignoreneg
printf '!*.local\n' > alpha/.gitignore
post b-ignoreneg ignoreneg.md
expect "T6-IGNORE-NEG exit 1" 1 "$RC"
kept "T6-IGNORE-NEG owner's ignored file kept" alpha/settings.local
gone "T6-IGNORE-NEG new .gitignore removed" alpha/.gitignore
has "T6-IGNORE-NEG reported" ignoreneg.md 'the run created alpha/.gitignore (removed)'
fx_repo ignorehide
snap b-ignorehide
printf 'alpha/evil.py\n' > .gitignore
put alpha/evil.py 'x=1'
post b-ignorehide ignorehide.md
expect "T6-IGNORE-HIDE exit 1" 1 "$RC"
gone "T6-IGNORE-HIDE the file it hid is removed" alpha/evil.py

# T6-SYMLINK: only regular files may change, even at an allowed path; a symlink is never followed.
fx_repo symlink
snap b-symlink
mkdir -p alpha/references
ln -s /etc/passwd alpha/references/creds.md
rm site/alpha/index.html
ln -s ../../alpha/scripts/tool.sh site/alpha/index.html
post b-symlink symlink.md
expect "T6-SYMLINK exit 1" 1 "$RC"
gone "T6-SYMLINK new symlink at an allowed path removed" alpha/references/creds.md
if [ -L site/alpha/index.html ]; then fail "T6-SYMLINK page is still a symlink"; else echo "ok: T6-SYMLINK page is a regular file again"; fi
has "T6-SYMLINK page content restored" symlink.md 'symlink at site/alpha/index.html (restored)'
has "T6-SYMLINK reported" symlink.md 'symlink at alpha/references/creds.md (removed)'
fx_repo symconf
printf '.release-docs/\n' > .gitignore
git add .gitignore && git commit -qm 'ignore run dir'
snap b-symconf
mkdir -p .release-docs/run
cp .github/docs-surfaces.json .release-docs/run/s.json
rm .github/docs-surfaces.json
ln -s ../.release-docs/run/s.json .github/docs-surfaces.json
post b-symconf symconf.md
expect "T6-SYMCONF exit 1" 1 "$RC"
if [ -L .github/docs-surfaces.json ] || [ ! -f .github/docs-surfaces.json ]; then fail "T6-SYMCONF config not a regular file"; else echo "ok: T6-SYMCONF config is a regular file again"; fi
has "T6-SYMCONF reported" symconf.md 'symlink at .github/docs-surfaces.json'
kept "T6-SYMCONF the ignored target is not touched" .release-docs/run/s.json

# T6-GITLINK: index-only entries that aren't regular files. `git apply --index` of a submodule entry
# stages a 160000 gitlink and leaves an empty directory, which git add -A then keeps staged; a
# symlink can be staged with no file in the tree. Each is unstaged (its empty directory removed),
# at an allowed path as outside the surfaces, and reported.
fx_repo gitlink
snap b-gitlink
git update-index --add --cacheinfo 160000,1111111111111111111111111111111111111111,site/zzz/index.html
mkdir -p site/zzz/index.html
git update-index --add --cacheinfo 160000,2222222222222222222222222222222222222222,alpha/zzz
mkdir -p alpha/zzz
mkdir -p alpha/references
link_blob="$(printf '/etc/passwd' | git hash-object -w --stdin)"
git update-index --add --cacheinfo "120000,$link_blob,alpha/references/creds.md"
post b-gitlink gitlink.md
expect "T6-GITLINK exit 1" 1 "$RC"
expect "T6-GITLINK nothing but regular files left staged" "" "$(git ls-files -s | awk '$1 != "100644" && $1 != "100755"')"
gone "T6-GITLINK the empty directory at an allowed path is removed" site/zzz/index.html
gone "T6-GITLINK the empty directory outside the surfaces is removed" alpha/zzz
has "T6-GITLINK reported at an allowed path" gitlink.md 'gitlink at site/zzz/index.html'
has "T6-GITLINK reported outside the surfaces" gitlink.md 'gitlink at alpha/zzz'
has "T6-GITLINK index-only symlink reported" gitlink.md 'symlink at alpha/references/creds.md'
expect "T6-GITLINK git add -A stages nothing odd afterwards" "" \
  "$(git add -A && git diff --cached --raw --no-renames HEAD | awk '$2 != "100644" && $2 != "000000"')"

# T6-GITLINK-IGNORED: the same gitlinks, with a .gitmodules the run wrote saying `ignore = all` for
# both. git diff-index and git status honour it and would hide the entries, so the fence must read
# with --ignore-submodules=none: the gitlinks are still unstaged and reported, and .gitmodules goes.
fx_repo gitlink-ignored
snap b-gitlink-ignored
git update-index --add --cacheinfo 160000,1111111111111111111111111111111111111111,site/zzz/index.html
mkdir -p site/zzz/index.html
git update-index --add --cacheinfo 160000,2222222222222222222222222222222222222222,alpha/zzz
mkdir -p alpha/zzz
printf '[submodule "a"]\n\tpath = site/zzz/index.html\n\turl = ./a\n\tignore = all\n[submodule "b"]\n\tpath = alpha/zzz\n\turl = ./b\n\tignore = all\n' > .gitmodules
post b-gitlink-ignored gitlink-ignored.md
expect "T6-GITLINK-IGNORED exit 1" 1 "$RC"
expect "T6-GITLINK-IGNORED no gitlink left staged" "" "$(git ls-files -s | awk '$1 == "160000"')"
gone "T6-GITLINK-IGNORED the empty directory at an allowed path is removed" site/zzz/index.html
gone "T6-GITLINK-IGNORED the empty directory outside the surfaces is removed" alpha/zzz
gone "T6-GITLINK-IGNORED the run's .gitmodules is removed" .gitmodules
has "T6-GITLINK-IGNORED reported at an allowed path" gitlink-ignored.md 'gitlink at site/zzz/index.html'
has "T6-GITLINK-IGNORED reported outside the surfaces" gitlink-ignored.md 'gitlink at alpha/zzz'
expect "T6-GITLINK-IGNORED git add -A stages no gitlink afterwards" "" \
  "$(git add -A && git ls-files -s | awk '$1 == "160000"')"

# T6-FIFO: a FIFO at the config path is reverted, never opened — the fence finishes, no hang.
fx_repo fifo
snap b-fifo
put alpha/scripts/tool.sh 'echo evil'
rm .github/docs-surfaces.json
mkfifo .github/docs-surfaces.json
within 30 bash "$POST" --before "$SCRATCH/b-fifo" --report "$SCRATCH/fifo.md"
expect "T6-FIFO finishes (no hang) with exit 1" 1 "$RC"
if [ -p .github/docs-surfaces.json ] || [ ! -f .github/docs-surfaces.json ]; then fail "T6-FIFO config not restored"; else echo "ok: T6-FIFO config restored as a regular file"; fi
has "T6-FIFO reported" fifo.md 'FIFO at .github/docs-surfaces.json'

# T6-IGNORE-CASE: with core.ignorecase (macOS) git honours `.GITIGNORE` too, so the fence treats
# any case of the name as an ignore file: put back first, never able to expose an owner's file.
fx_repo ignorecase
printf '*.local\n' > .gitignore
git add .gitignore && git commit -qm 'ignore local'
put alpha/x.local 'owner local'
snap b-icase
printf '!*.local\n' > alpha/.GITIGNORE
post b-icase icase.md
expect "T6-IGNORE-CASE exit 1" 1 "$RC"
kept "T6-IGNORE-CASE owner's ignored file kept" alpha/x.local
gone "T6-IGNORE-CASE case-variant ignore file removed" alpha/.GITIGNORE
has "T6-IGNORE-CASE reported as an ignore file" icase.md 'the run created alpha/.GITIGNORE (removed)'

# T6-OUT: the output flags cannot write into the working tree outside .release-docs/, or into .git.
# The CI model once emptied post-checks.sh itself with --report. Refused before any write, exit 2.
fx_repo outputs
printf '.release-docs/\n' >> .git/info/exclude
snap b-out
tool_sum="$(cksum < alpha/scripts/tool.sh)"
RC=0; bash "$POST" --before "$SCRATCH/b-out" --report alpha/scripts/tool.sh >/dev/null 2>&1 || RC=$?
expect "T6-OUT --report onto a tracked file -> exit 2" 2 "$RC"
expect "T6-OUT the tracked file is untouched" "$tool_sum" "$(cksum < alpha/scripts/tool.sh)"
excl_sum="$(cksum < .git/info/exclude)"
RC=0; bash "$DETECT" --range main..HEAD --out .git/info/exclude >/dev/null 2>&1 || RC=$?
expect "T6-OUT --out into .git/info/exclude -> exit 2" 2 "$RC"
expect "T6-OUT .git/info/exclude untouched" "$excl_sum" "$(cksum < .git/info/exclude)"
RC=0; bash "$DETECT" --range main..HEAD --out alpha/obligations.json >/dev/null 2>&1 || RC=$?
expect "T6-OUT --out into the tree -> exit 2" 2 "$RC"
gone "T6-OUT no --out file written in the tree" alpha/obligations.json
RC=0; bash "$POST" --snapshot alpha/snap.json >/dev/null 2>&1 || RC=$?
expect "T6-OUT --snapshot into the tree -> exit 2" 2 "$RC"
gone "T6-OUT no snapshot written in the tree" alpha/snap.json
RC=0; bash "$POST" --before "$SCRATCH/b-out" --shots site/shots >/dev/null 2>&1 || RC=$?
expect "T6-OUT post-checks --shots into the tree -> exit 2" 2 "$RC"
gone "T6-OUT post-checks created no shots dir" site/shots
RC=0; bash "$RENDER" --shots alpha/shots site/alpha/index.html >/dev/null 2>"$SCRATCH/rc-err" || RC=$?
expect "T6-OUT render-check --shots into the tree -> exit 2" 2 "$RC"
has "T6-OUT render-check refuses it before looking for Chrome" rc-err 'refusing --shots directory'
gone "T6-OUT render-check created no shots dir" alpha/shots
mkdir -p .release-docs/run
ln -s ../../alpha/scripts/tool.sh .release-docs/run/link.md
RC=0; bash "$POST" --before "$SCRATCH/b-out" --report .release-docs/run/link.md >/dev/null 2>&1 || RC=$?
expect "T6-OUT a symlink from .release-docs/ into the tree -> exit 2" 2 "$RC"
ln alpha/scripts/tool.sh "$SCRATCH/hard.md"
RC=0; bash "$POST" --before "$SCRATCH/b-out" --report "$SCRATCH/hard.md" >/dev/null 2>&1 || RC=$?
expect "T6-OUT a hard link to a tracked file -> exit 2" 2 "$RC"
expect "T6-OUT the tracked file is still untouched" "$tool_sum" "$(cksum < alpha/scripts/tool.sh)"
# A `..` after a symlink climbs from the link's target, the way the OS resolves it, not from the
# link's own directory the way a textual collapse reads it. With .release-docs/l -> alpha/scripts/d,
# .release-docs/l/../tool.sh IS alpha/scripts/tool.sh, and .release-docs/l/.. IS alpha/scripts.
mkdir -p alpha/scripts/d
ln -s ../alpha/scripts/d .release-docs/l
RC=0; bash "$POST" --before "$SCRATCH/b-out" --report .release-docs/l/../tool.sh >/dev/null 2>&1 || RC=$?
expect "T6-OUT --report through a symlink's '..' onto a tracked file -> exit 2" 2 "$RC"
expect "T6-OUT the tracked file behind the symlink's '..' is untouched" "$tool_sum" "$(cksum < alpha/scripts/tool.sh)"
RC=0; bash "$DETECT" --check-output-dir .release-docs/l/.. >/dev/null 2>&1 || RC=$?
expect "T6-OUT --check-output-dir through a symlink's '..' -> exit 2" 2 "$RC"
RC=0; bash "$DETECT" --range main..HEAD --out .release-docs/l/../x.json >/dev/null 2>&1 || RC=$?
expect "T6-OUT --out through a symlink's '..' -> exit 2" 2 "$RC"
gone "T6-OUT no --out file written beside the symlink's target" alpha/scripts/x.json
RC=0; bash "$RENDER" --shots .release-docs/l/../shots site/alpha/index.html >/dev/null 2>"$SCRATCH/rc-err2" || RC=$?
expect "T6-OUT render-check --shots through a symlink's '..' -> exit 2" 2 "$RC"
has "T6-OUT render-check refuses the symlink's '..' before looking for Chrome" rc-err2 'refusing --shots directory'
gone "T6-OUT render-check created no shots dir beside the symlink's target" alpha/scripts/shots
# A symlink loop: the OS can't resolve it, and realpath collapses what follows it as text, so the
# check refuses it outright instead of answering for a path nobody can write.
ln -s loop .release-docs/loop
RC=0; bash "$DETECT" --check-output .release-docs/loop/../x.md >/dev/null 2>"$SCRATCH/loop-err" || RC=$?
expect "T6-OUT --check-output through a symlink loop -> exit 2" 2 "$RC"
has "T6-OUT the loop is named" loop-err 'symlink loop'
RC=0; bash "$POST" --before "$SCRATCH/b-out" --report .release-docs/run/x.md >/dev/null 2>&1 || RC=$?
expect "T6-OUT --report under .release-docs/run/ works" 0 "$RC"
if grep -q 'ok: write fence' .release-docs/run/x.md 2>/dev/null; then echo "ok: T6-OUT .release-docs/run/x.md written"; else fail "T6-OUT .release-docs/run/x.md not written"; fi
post b-out tmp-report.md
expect "T6-OUT --report under \$TMPDIR works" 0 "$RC"
has "T6-OUT the \$TMPDIR report is written" tmp-report.md 'ok: write fence'

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

# T7-PRBODY-* (final review I4, I5, I2/I3's listings, T6 M5/M6, T7, rehearsal #17-#19).
prbody() { # <before.json> [verifier] — BODY and RC of docs-detect --pr-body
  RC=0
  if [ -n "${2:-}" ]; then
    BODY="$(bash "$DETECT" --range main..HEAD --pr-body --before "$1" --verifier "$2" 2>"$SCRATCH/stderr")" || RC=$?
  else
    BODY="$(bash "$DETECT" --range main..HEAD --pr-body --before "$1" 2>"$SCRATCH/stderr")" || RC=$?
  fi
}
body_has() { # <what> <text>
  case "$BODY" in *"$2"*) echo "ok: $1" ;; *) fail "$1 — no [$2] in: $BODY" ;; esac
}
body_lacks() { # <what> <text>
  case "$BODY" in *"$2"*) fail "$1 — [$2] in: $BODY" ;; *) echo "ok: $1" ;; esac
}

# T7-PRBODY-VERIFIER-BAD: a verifier.json that is code-fenced, not a list, or a list of non-objects is
# one "unreadable" line; the body is still built (exit 0), never exit 2 and an empty body.
fx_repo prbody-bad
bump 1.1.0 '- New fly skill.'
detect; cp "$OUT" "$SCRATCH/before-bad.json"
n=0
for v in '```json\n[{"verdict":"refuted"}]\n```' '{"verdict":"refuted"}' '["refuted"]'; do
  n=$((n + 1))
  printf "$v\n" > "$SCRATCH/vbad$n.json"
  prbody "$SCRATCH/before-bad.json" "$SCRATCH/vbad$n.json"
  expect "T7-PRBODY-VERIFIER-BAD $n exit 0" 0 "$RC"
  body_has "T7-PRBODY-VERIFIER-BAD $n says unreadable" "verifier output unreadable:"
  body_has "T7-PRBODY-VERIFIER-BAD $n the rest of the body is there" "### Still open"
done

# T7-PRBODY-INJECT: no model-written value (verifier fields, a ledger reason or disposition) renders as
# markup: outside code spans the body holds no `<`, so a `<!--` can't hide the report after it.
printf '%s\n' '[{"file":"site/alpha/index.html","claim":"a <!-- hidden `x` @owner","verdict":"refuted","evidence":"<script>e</script> | pipe"}]' > "$SCRATCH/vinj.json"
eid="$(field changelog-entry id 0)"
python3 - "$eid" <<'PY'
import json, sys
json.dump({"schemaVersion": 1, "intentional": [], "entries": {
    sys.argv[1]: {"disposition": "not-user-facing", "reason": "internal <!-- swallow the rest"}}},
    open(".github/docs-ledger.json", "w"))
PY
prbody "$SCRATCH/before-bad.json" "$SCRATCH/vinj.json"
printf '%s\n' "$BODY" > "$SCRATCH/body-inj.md"
python3 - "$SCRATCH/body-inj.md" <<'PY' && echo "ok: T7-PRBODY-INJECT nothing untrusted renders as markup" || fail "T7-PRBODY-INJECT: $BODY"
import re, sys
text = open(sys.argv[1]).read()
bare = re.sub(r"`[^`\n]*`", "", text)
sys.exit(0 if "<" not in bare and ">" not in bare and "hidden" in text and "swallow" in text else 1)
PY
git checkout -q -- .github/docs-ledger.json

# T7-PRBODY-HEADER (#19): the header no longer claims every line comes from the detector and ledger.
body_lacks "T7-PRBODY-HEADER no false provenance claim" "Every line below comes from"
body_has "T7-PRBODY-HEADER names verifier.json as the verifier section's source" "verifier.json"
body_has "T7-PRBODY-LASTROUND (#17) the verifier section says it is the last round's" "last round"

# T7-PRBODY-SHIFT (T6 M5/M6): a stale-mention is matched by file and token, never its line. Deleting a
# line above two mentions and fixing one resolves one of two, not both.
fx_repo prbody-shift
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['retired']=['old-thing.json']; json.dump(d, open(p,'w'))"
printf '%s\n' 'Intro line.' 'Uses `old-thing.json` here.' 'Middle.' 'And `old-thing.json` again.' >> alpha/README.md
git commit -qam 'mentions'
detect; cp "$OUT" "$SCRATCH/before-shift.json"
python3 - <<'PY'
p = "alpha/README.md"
t = open(p).read().replace("Intro line.\n", "").replace("Uses `old-thing.json` here.", "Uses `new-thing.json` here.")
open(p, "w").write(t)
PY
prbody "$SCRATCH/before-shift.json"
body_has "T7-PRBODY-SHIFT one resolved" "### Resolved (1)"
body_has "T7-PRBODY-SHIFT one still open" "### Still open (1)"
body_has "T7-PRBODY-SHIFT counted by token" "1 of 2"

# T7-PRBODY-INTENTIONAL (I3): a stale-mention closed by an intentional entry HEAD's ledger lacks says so.
git checkout -q -- alpha/README.md
python3 - <<'PY'
import json
json.dump({"schemaVersion": 1, "entries": {}, "intentional": [
    {"file": "alpha/README.md", "token": "old-thing.json", "context": "again, on purpose",
     "reason": "a deliberate legacy note"}]}, open(".github/docs-ledger.json", "w"))
p = "alpha/README.md"
open(p, "w").write(open(p).read().replace("And `old-thing.json` again.", "And `old-thing.json` again, on purpose."))
PY
prbody "$SCRATCH/before-shift.json"
body_has "T7-PRBODY-INTENTIONAL marked" "resolved by a new intentional entry"
body_has "T7-PRBODY-INTENTIONAL the new entry is listed" "new \`intentional\` entry"
git checkout -q -- alpha/README.md .github/docs-ledger.json

# T7-PRBODY-CONFIG (I2): retired[] additions and og changes are listed for review.
python3 - <<'PY'
import json
p = ".github/docs-surfaces.json"
d = json.load(open(p))
d["retired"].append("gone-tool.sh")
d["og"]["site/alpha/index.html"]["og:title"] = "alpha — retitled"
json.dump(d, open(p, "w"))
PY
prbody "$SCRATCH/before-shift.json"
body_has "T7-PRBODY-CONFIG retired addition listed" "gone-tool.sh"
body_has "T7-PRBODY-CONFIG og change listed" "alpha — retitled"
git checkout -q -- .github/docs-surfaces.json

# T7-PRBODY-OTHER (I5): every changed file no obligation names is listed by class, a plugin reference
# flagged as plugin-internal; the owner's file outside the surfaces is not.
mkdir -p alpha/references && put alpha/references/guide.md '# Guide' 'Do this.'
git add -A && git commit -qm guide
detect; cp "$OUT" "$SCRATCH/before-other.json"
put alpha/references/guide.md '# Guide' 'Do that.'
sed -i.bak 's#<h1>alpha</h1>#<h1>alpha, retold</h1>#' site/alpha/index.html && rm -f site/alpha/index.html.bak
put owner-notes.txt 'mine'
prbody "$SCRATCH/before-other.json"
body_has "T7-PRBODY-OTHER section" "### Other edits"
body_has "T7-PRBODY-OTHER plugin reference flagged" "plugin-internal: needs a version bump + CHANGELOG if kept"
body_has "T7-PRBODY-OTHER the reference is named" "alpha/references/guide.md"
body_has "T7-PRBODY-OTHER the page is named" "site/alpha/index.html"
body_lacks "T7-PRBODY-OTHER the owner's file is not" "owner-notes.txt"

exit "$failures"
