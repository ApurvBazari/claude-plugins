#!/usr/bin/env bash
# test_maintain_detect.sh — maintain-detect.sh core behaviour (onboard maintain spec § 7, § 6.5):
# input checks and error objects, R10, the changed set, the package.json kinds, the file-set
# kinds, research-stale, and that detect writes nothing but --out. AC1–AC7, AC19.
# Markdown fixtures carry literal backticks inside single quotes.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

pkg() { put package.json "{\"name\":\"root\",\"scripts\":{$1},\"dependencies\":{$2}}"; }

# --- AC1: one added dependency -> exactly one inform item; one added script -> one apply item ---
new_repo ac1-dep
pkg '"dev":"next dev"' '"zod":"^3"'
put CLAUDE.md '# Root' '' '## Commands' '' '- `npm run dev` — next dev'
commit_base
pkg '"dev":"next dev"' '"zod":"^3","decimal.js":"^10.6.0"'
detect
expect "AC1 dependency: exit 0" 0 "$RC"
expect "AC1 dependency: exactly one inform item" "dependency-added:inform" "$(kinds)"
expect "AC1 dependency: fields" "decimal.js ^10.6.0 package.json" \
  "$(item dependency-added 'i["name"] + " " + i["version"] + " " + i["file"]')"
schema_ok "AC1 dependency report"

new_repo ac1-script
pkg '"dev":"next dev"' '"zod":"^3"'
put CLAUDE.md '# Root' '' '## Commands' '' '- `npm run dev` — next dev'
commit_base
pkg '"dev":"next dev","price:check":"tsx scripts/price-check.ts"' '"zod":"^3"'
detect
expect "AC1 script: exactly one apply item" "script-added:apply" "$(kinds)"
expect "AC1 script: fields" "price:check|tsx scripts/price-check.ts|package.json|root" \
  "$(item script-added '"|".join([i["name"], i["run"], i["file"], i["package"]])')"
schema_ok "AC1 script report"

# --- AC2: a source-only change no tooling line mentions -> no items ---
new_repo ac2
put src/a.ts 'export const a = 1'
put CLAUDE.md '# Root'
commit_base
put src/a.ts 'export const a = 2'
detect
expect "AC2: exit 0" 0 "$RC"
expect "AC2: no items" "" "$(kinds)"

# --- AC3: tooling-only changes -> no items ---
new_repo ac3
put CLAUDE.md '# Root'
put .claude/rules/x.md '# rule'
commit_base
put CLAUDE.md '# Root' '- new guidance'
put .claude/rules/x.md '# rule' '- more'
put .mcp.json '{}'
put apps/web/CLAUDE.md '# Web'
detect
expect "AC3: tooling-only diff has no items" "" "$(kinds)"

# --- AC4 / R10: no onboard-meta.json -> exactly one not-onboarded item ---
new_repo ac4 --no-meta
put src/a.ts 'x'
commit_base
put package.json '{"dependencies":{"zod":"^3"}}'
detect
expect "AC4: exit 0" 0 "$RC"
expect "AC4: only not-onboarded" "not-onboarded:defer" "$(kinds)"
expect "AC4: onboarded false, command /onboard:start" "False /onboard:start" \
  "$(q 'str(d["project"]["onboarded"]) + " " + d["items"][0]["command"]')"
schema_ok "AC4 report"

# --- AC5: bad input -> exit 2 and an error object ---
new_repo ac5
put a.txt a
commit_base
detect nope-not-a-ref
expect "AC5 bad ref: exit 2" 2 "$RC"
expect "AC5 bad ref: error code" "bad-ref" "$(q 'd["error"]["code"]')"
schema_ok "AC5 error object"
RC=0; bash "$DETECT" --out "$REPO/.claude/run/detect.json" 2>/dev/null || RC=$?
expect "AC5 missing --base: exit 2" 2 "$RC"
expect "AC5 missing --base: bad-args" "bad-args" "$(q 'd["error"]["code"]')"
RC=0; bash "$DETECT" --base HEAD --out "$SCRATCH/no/such/dir/out.json" 2>/dev/null || RC=$?
expect "AC5 missing out dir: exit 2" 2 "$RC"
if [ -e "$SCRATCH/no" ]; then fail "AC5 created a directory"; else echo "ok: AC5 missing out dir: nothing created"; fi
mkdir -p "$SCRATCH/plain"
RC=0; (cd "$SCRATCH/plain" && bash "$DETECT" --base HEAD --out "$SCRATCH/plain/out.json" 2>/dev/null) || RC=$?
expect "AC5 not a repo: exit 2" 2 "$RC"
expect "AC5 not a repo: not-a-repo" "not-a-repo" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["error"]["code"])' "$SCRATCH/plain/out.json")"

# --- AC6: detect writes nothing but --out (and no bytecode into the plugin) ---
new_repo ac6
pkg '"dev":"x"' '"zod":"^3"'
put CLAUDE.md '# Root' '- Uses zod.'
put src/a.ts 'x'
commit_base
pkg '"dev":"x","t":"y"' '"zod":"^4","left-pad":"^1"'
put src/b.ts 'y'
snap() { git status --porcelain=v1 -uall -z | tr '\0' '\n' | grep -v '^?? .claude/run/'; find . -path ./.git -prune -o -type f -print | grep -v '^./.claude/run/' | sort | xargs shasum; }
before="$(snap)"
pycache() { find "$ROOT/onboard/scripts" -name __pycache__ -o -name '*.pyc' | sort; }
plugin_before="$(pycache)"
detect
expect "AC6: repo unchanged apart from --out" "$before" "$(snap)"
expect "AC6: no bytecode written into the plugin" "$plugin_before" "$(pycache)"
if [ -f "$OUT" ]; then echo "ok: AC6 report written"; else fail "AC6 report missing"; fi
leftover="$(find "$REPO/.claude/run" -type f ! -name detect.json ! -name stderr)"
expect "AC6: no temp files left beside --out" "" "$leftover"

# --- package.json kinds: removal rules (mentioned -> stale-line, unmentioned -> dropped), D21 ---
new_repo removals
pkg '"dev":"x","old":"y"' '"recharts":"^2","lodash":"^4"'
put CLAUDE.md '# Root' '' '- Charts use Recharts.' '- `npm run old` does the old thing.'
commit_base
pkg '"dev":"x"' '"Zod":"^3"'
put CLAUDE.md '# Root' '' '- Charts use Recharts.' '- `npm run old` does the old thing.' '- Validation uses zod.'
detect
expect "removals: kinds" "recheck-line:inform dependency-removed:defer script-removed:defer" "$(kinds)"
expect "removals: mentioned dependency is a stale-line at its line" "recharts CLAUDE.md:3 stale-line" \
  "$(item dependency-removed 'i["name"] + " " + i["line"] + " " + i["reason"]')"
expect "removals: mentioned script is a stale-line" "old CLAUDE.md:4" \
  "$(item script-removed 'i["name"] + " " + i["line"]')"
schema_ok "removals report"
# lodash was removed but never mentioned -> dropped. Zod was added and "zod" is mentioned, so its
# dependency-added item is dropped (D15, case-insensitive D21) and the line becomes a name recheck.
expect "removals: D21 — the added Zod is a name recheck on the zod line, not a dependency-added" \
  "CLAUDE.md:5 name Zod" "$(item recheck-line 'i["line"] + " " + i["matched"][0]["by"] + " " + i["matched"][0]["value"]')"

# --- invalid / odd package.json never crashes detect ---
new_repo badjson
pkg '"dev":"x"' '"zod":"^3"'
put apps/a/package.json '{"name":"a","scripts":[]}'
commit_base
put package.json '{"name": "root", '
put apps/a/package.json '{"name":"a","scripts":null,"dependencies":"nope"}'
detect
expect "bad package.json: exit 0" 0 "$RC"
expect "bad package.json: one manifest-changed item for the unparsable file" "manifest-changed:defer package.json" \
  "$(q '" ".join(i["kind"] + ":" + i["disposition"] + " " + i["file"] for i in d["items"])')"

# --- file-set kinds ---
new_repo filesets
put package.json '{"name":"root","dependencies":{}}'
put src/a.ts 'x'
put tsconfig.json '{}'
commit_base
put tsconfig.json '{"compilerOptions":{}}'
put pyproject.toml '[project]'
put requirements-dev.txt 'pytest'
for i in 1 2 3 4 5; do put "services/api/src/m$i.go" "package m"; done
for i in 1 2 3 4; do put "tools/small/t$i.ts" "x"; done
put .github/workflows/ci.yml 'on: push'
put package.json '{"name":"root","dependencies":{"next":"^15","@anthropic-ai/sdk":"^1"}}'
detect
expect "file-set kinds" "dependency-added:inform dependency-added:inform manifest-changed:defer manifest-changed:defer config-changed:defer directory-new:defer language-new:defer signal-mcp:defer signal-mcp:defer signal-builtin-skill:defer" "$(kinds)"
expect "directory-new: topmost new directory, recursive count" "services 5" \
  "$(item directory-new 'i["path"] + " " + str(i["count"])')"
expect "language-new: go" "go 5" "$(item language-new 'i["name"] + " " + str(i["count"])')"
expect "signal-mcp: github then chrome-devtools-mcp" "github chrome-devtools-mcp" \
  "$(q '" ".join(i["name"] for i in d["items"] if i["kind"] == "signal-mcp")')"
expect "signal-builtin-skill: /claude-api" "/claude-api @anthropic-ai/sdk" \
  "$(item signal-builtin-skill 'i["name"] + " " + i["dependency"]')"
schema_ok "file-set report"

# --- AC19: lessons-large fires past the threshold, not at it ---
new_repo lessons
put src/a.ts x
commit_base
mkdir -p .claude/rules
python3 -c "print('\n'.join('- lesson %d' % n for n in range(60)))" > .claude/rules/lessons.md
detect
expect "AC19: 60 lines is not large" "" "$(kinds)"
echo "- one more" >> .claude/rules/lessons.md
detect
expect "AC19: 61 lines is large" "lessons-large:defer 61 60" \
  "$(item lessons-large '"lessons-large:" + i["disposition"] + " " + str(i["lines"]) + " " + str(i["threshold"])')"

# --- research-stale: mapped dimensions ∩ the stored depth's roster ---
new_repo research
printf '{"pluginVersion":"3.2.0","research":{"depth":"standard"}}\n' > .claude/onboard-meta.json
put package.json '{"name":"root","dependencies":{"next":"^14.0.0"}}'
put src/a.ts x
commit_base
put package.json '{"name":"root","dependencies":{"next":"^15.0.0"}}'
put src/auth/session.ts x
put prisma/migrations/001/migration.sql 'create table x();'
detect
expect "research-stale: dimensions and escalation" "architecture data-model security True" \
  "$(item research-stale '" ".join(i["dimensions"]) + " " + str(i["escalatedToFull"])')"
printf '{"pluginVersion":"3.2.0","research":{"depth":"minimal"}}\n' > .claude/onboard-meta.json
detect
expect "research-stale: minimal depth never reports" "" "$(item research-stale 'i["kind"]')"

# --- review focus: odd paths, other ref forms, running from a subdirectory ---
new_repo odd
put CLAUDE.md '# Root' '- The café helper is `src/café.ts`.'
put 'src/my file.ts' x
put src/café.ts x
commit_base
put 'src/my file.ts' y
put src/café.ts y
detect
expect "odd paths: exit 0" 0 "$RC"
expect "odd paths: unicode path mention is a recheck" "CLAUDE.md:2 src/café.ts" \
  "$(item recheck-line 'i["line"] + " " + i["matched"][0]["value"]')"
git tag v0
git checkout -q -b topic
detect v0
expect "ref forms: a tag resolves to the same base" "$BASE" "$(q 'd["range"]["base"]')"
expect "ref forms: baseRef is echoed as given" "v0" "$(q 'd["range"]["baseRef"]')"
git commit -qam next
detect HEAD~1
expect "ref forms: HEAD~1" "$BASE" "$(q 'd["range"]["base"]')"
mkdir -p src/deep
RC=0; (cd src/deep && bash "$DETECT" --base v0 --out ../../.claude/run/sub.json) || RC=$?
expect "subdirectory: exit 0" 0 "$RC"
expect "subdirectory: same report as from the root" "$(q 'd["items"]')" \
  "$(OUT="$REPO/.claude/run/sub.json" q 'd["items"]')"

# --- review focus: a git worktree (matali builds features in worktrees) ---
new_repo wt-main
put package.json '{"name":"root","scripts":{"dev":"x"}}'
put CLAUDE.md '# Root'
commit_base
git worktree add -q "$SCRATCH/wt-linked" -b feature
REPO="$SCRATCH/wt-linked"
cd "$REPO" || exit 1
put package.json '{"name":"root","scripts":{"dev":"x","check":"y"}}'
mkdir -p .claude && printf '{"pluginVersion":"3.2.0"}\n' > .claude/onboard-meta.json
detect
expect "worktree: detect runs in a linked worktree" "0 script-added:apply" "$RC $(kinds)"

# --- review focus: CRLF line endings and a BOM in tooling ---
new_repo crlf
put package.json '{"name":"root","dependencies":{"recharts":"^2"}}'
printf '\xef\xbb\xbf# Root\r\n\r\n- Charts use recharts.\r\n' > CLAUDE.md
commit_base
put package.json '{"name":"root","dependencies":{}}'
detect
expect "CRLF + BOM: the stale line is found at its real line number" "CLAUDE.md:3" "$(item dependency-removed 'i["line"]')"

# --- review focus: bytes that are not UTF-8 never crash detect ---
new_repo latin1
put package.json '{"name":"root","dependencies":{}}'
printf '# Caf\xe9\n- Uses zod.\n' > CLAUDE.md
commit_base
printf '{"name":"root","dependencies":{"zod":"^3"},"description":"caf\xe9"}\n' > package.json
detect
expect "non-UTF-8: exit 0 and the mention still drops the dependency" "0 recheck-line:inform" "$RC $(kinds)"

# --- review focus: nothing changed since base -> an empty report ---
new_repo clean
put package.json '{"name":"root","scripts":{"dev":"x"}}'
put CLAUDE.md '# Root'
commit_base
detect HEAD
expect "clean tree, base = HEAD: exit 0, no items" "0 " "$RC $(kinds)"

# --- review focus: a large repo stays fast (5,000 files, 50 tooling lines) ---
new_repo large
python3 - <<'PY'
import os
for d in range(50):
    os.makedirs("src/m%d" % d, exist_ok=True)
    for f in range(100):
        open("src/m%d/f%d.ts" % (d, f), "w").write("export const x = %d;\n" % f)
open("CLAUDE.md", "w").write("# Root\n" + "".join("- module `src/m%d/f0.ts`\n" % d for d in range(50)))
open("package.json", "w").write('{"name":"root","dependencies":{}}\n')
PY
commit_base
for d in 1 2 3; do echo "export const y = 1;" >> "src/m$d/f0.ts"; done
start="$(python3 -c 'import time; print(time.time())')"
detect
secs="$(python3 -c "import time; print(int(time.time() - $start))")"
expect "large repo: three rechecks" "3" "$(q 'sum(1 for i in d["items"] if i["kind"] == "recheck-line")')"
if [ "$secs" -le 5 ]; then echo "ok: large repo: detect took ${secs}s (<= 5s)"; else fail "large repo: detect took ${secs}s (> 5s)"; fi

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_detect: all checks passed"; exit 0; fi
echo "test_maintain_detect: $failures check(s) failed"; exit 1
