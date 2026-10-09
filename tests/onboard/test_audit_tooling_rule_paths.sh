#!/usr/bin/env bash
# test_audit_tooling_rule_paths.sh — Check 2 of onboard/scripts/audit-tooling.sh, the rule-path check
# (issue #122). Every glob a .claude/rules/*.md frontmatter lists under `paths:` must match something
# in the tree; a glob that matches nothing is drift.
#
# Two defects sat in that check, and each case below is one of them or a boundary of the fix:
# - the frontmatter was read with a sed expression BSD sed rejects, and the error was discarded, so
#   on macOS the check read no paths and passed every project;
# - the globs were matched with `compgen -G`, where `**` is one level and `*` skips dot-directories,
#   so `**/marketplace.json` did not find `.claude-plugin/marketplace.json`.
#
# A "matches" case alone passes against a check that never runs, so every project here also carries
# globs that must be reported.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUDIT="$ROOT/onboard/scripts/audit-tooling.sh"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

DIRS=()
cleanup() { for d in "${DIRS[@]+"${DIRS[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

new_project() { P="$(mktemp -d)"; DIRS+=("$P"); mkdir -p "$P/.claude/rules"; }
put() { mkdir -p "$(dirname "$P/$1")"; printf 'x\n' > "$P/$1"; }
# rule <name> <frontmatter line>... — a rule file whose frontmatter is exactly those lines.
rule() {
  local name="$1"; shift
  { echo "---"; printf '%s\n' "$@"; echo "---"; echo; echo "# $name"; } > "$P/.claude/rules/$name.md"
}
# GITHUB_OUTPUT is unset so a CI run of this belt never writes into the real step's outputs.
audit() { OUT="$(env -u GITHUB_OUTPUT bash "$AUDIT" "$P" 2>&1)"; }
reported() {
  printf '%s\n' "$OUT" | grep -qxF "  - Rule '.claude/rules/$1.md' targets path '$2' but no matching files found"
}
matches() { if reported "$1" "$2"; then fail "$3: '$2' was reported as matching nothing"; else echo "ok: $3"; fi; }
drifts() { if reported "$1" "$2"; then echo "ok: $3"; else fail "$3: '$2' was not reported"; fi; }

# --- globs ---
new_project
put .claude-plugin/marketplace.json
put a/b/.hidden/deep.json
put onboard/.claude-plugin/plugin.json
put onboard/skills/start/SKILL.md
put top.md
put README.md
put src/x/y.tsx
put lib/a.ts
put docs/sub/x.md
put v1.txt
put w10.txt
put k1.txt
put "my dir/a.txt"
put "a+b/(x)/f.txt"
put .git/HEAD
put node_modules/pkg/only-here.json
mkdir -p "$P/emptydir"
rule dotdir 'paths:' '  - "**/.claude-plugin/**"' '  - "**/marketplace.json"' '  - "**/deep.json"' '  - "**/nope.json"'
rule stars 'paths:' '  - "onboard/**"' '  - "**/top.md"' '  - "docs/*.md"' '  - "docs/**/*.md"' '  - "**"' \
  '  - "emptydir/**"'
rule braces 'paths:' '  - "src/**/*.{ts,tsx}"' '  - "lib/*.{js,mjs}"' '  - "{lib,src}/a.ts"'
rule classes 'paths:' '  - "v?.txt"' '  - "w?.txt"' '  - "k[12].txt"' '  - "k[!1].txt"'
rule literal 'paths:' '  - "README.md"' '  - "MISSING.md"' '  - "my dir/**"' '  - "a+b/(x)/*.txt"'
rule pruned 'paths:' '  - "**/HEAD"' '  - "**/only-here.json"'
audit

matches dotdir '**/.claude-plugin/**' "a dot-directory named in the glob matches"
matches dotdir '**/marketplace.json' "#122: ** reaches a dot-directory at the root"
matches dotdir '**/deep.json' "** recurses through a nested dot-directory"
drifts dotdir '**/nope.json' "a glob that matches nothing is reported"

matches stars 'onboard/**' "a directory prefix matches what is under it"
matches stars '**/top.md' "**/ also spans zero directories"
drifts stars 'docs/*.md' "a single * does not cross a slash"
matches stars 'docs/**/*.md' "** in the middle spans directories"
matches stars '**' "a bare ** is never reported"
drifts stars 'emptydir/**' "an empty directory has nothing under it"

matches braces 'src/**/*.{ts,tsx}' "a brace list matches one of its alternatives"
drifts braces 'lib/*.{js,mjs}' "a brace list with no alternative present is reported"
matches braces '{lib,src}/a.ts' "a brace list in a directory position matches"

matches classes 'v?.txt' "? matches one character"
drifts classes 'w?.txt' "? does not match two characters"
matches classes 'k[12].txt' "a bracket class matches a listed character"
drifts classes 'k[!1].txt' "a negated bracket class excludes the listed character"

matches literal 'README.md' "a literal path that exists matches"
drifts literal 'MISSING.md' "a literal path that is missing is reported"
matches literal 'my dir/**' "a path with a space matches"
matches literal 'a+b/(x)/*.txt' "regex metacharacters in a path are literal"

drifts pruned '**/HEAD' ".git is not searched"
drifts pruned '**/only-here.json' "node_modules is not searched"

# --- reading the frontmatter ---
new_project
put single/a.txt
put bare/a.txt
put double/a.txt
put kept/a.txt
rule quotes 'paths:' "  - 'single/**'" '  - bare/**' '  - "double/**"' "  - 'gone-single/**'" \
  '  - gone-bare/**   # a trailing comment' '  - ""'
rule otherkeys 'description: a rule with more keys' 'paths:' '  - "kept/**"' '  - "gone-before-key/**"' \
  'tags:' '  - "a-tag-not-a-path/**"'
rule flush 'paths:' '- "kept/**"' '- "gone-flush/**"'
printf '%s\n' '---' 'paths:' '  - "kept/**"' '  - "gone-in-frontmatter/**"' '---' '' '# body' '' '---' '' \
  'paths:' '  - "ghost-in-body/**"' '---' > "$P/.claude/rules/bodylist.md"
printf '%s\n' '# no frontmatter' '' 'paths:' '  - "ghost-no-frontmatter/**"' > "$P/.claude/rules/nofm.md"
printf '%s\r\n' '---' 'paths:' '  - "kept/**"' '  - "gone-crlf/**"' '---' '' '# crlf' > "$P/.claude/rules/crlf.md"
audit

matches quotes 'single/**' "a single-quoted path is read"
matches quotes 'bare/**' "an unquoted path is read"
matches quotes 'double/**' "a double-quoted path is read"
drifts quotes 'gone-single/**' "a missing single-quoted path is reported without its quotes"
drifts quotes 'gone-bare/**' "a missing unquoted path is reported without its trailing comment"
matches quotes '' "an empty path is never reported"

matches otherkeys 'kept/**' "paths: after another key is read"
drifts otherkeys 'gone-before-key/**' "the last path before the next key is read"
matches otherkeys 'a-tag-not-a-path/**' "a list under another key is not a path"

drifts flush 'gone-flush/**' "a list flush with its key is read"

drifts bodylist 'gone-in-frontmatter/**' "the frontmatter of a rule with a --- in its body is read"
matches bodylist 'ghost-in-body/**' "a paths: block in the body is not frontmatter"
matches nofm 'ghost-no-frontmatter/**' "a rule with no frontmatter has no paths"

matches crlf 'kept/**' "a CRLF rule file is read"
drifts crlf 'gone-crlf/**' "a missing path in a CRLF rule file is reported without the carriage return"

# --- the report and the step outputs ---
new_project
put kept/a.txt
rule only 'paths:' '  - "kept/**"'
GH_OUT="$P/github-output"
: > "$GH_OUT"
OUT="$(GITHUB_OUTPUT="$GH_OUT" bash "$AUDIT" "$P" 2>&1)"
if printf '%s\n' "$OUT" | grep -qxF "### No Drift"; then echo "ok: a project whose paths all match reports no drift"
else fail "a project whose paths all match did not report '### No Drift'"; fi
if grep -qxF "has_drift=false" "$GH_OUT"; then echo "ok: has_drift=false is written to the step outputs"
else fail "has_drift=false was not written to the step outputs"; fi

rule only 'paths:' '  - "kept/**"' '  - "gone/**"'
: > "$GH_OUT"
OUT="$(GITHUB_OUTPUT="$GH_OUT" bash "$AUDIT" "$P" 2>&1)"
if printf '%s\n' "$OUT" | grep -qxF "### Drift Detected"; then echo "ok: one missing path reports drift"
else fail "one missing path did not report '### Drift Detected'"; fi
if grep -qxF "has_drift=true" "$GH_OUT"; then echo "ok: has_drift=true is written to the step outputs"
else fail "has_drift=true was not written to the step outputs"; fi
if grep -qxF "  - Rule '.claude/rules/only.md' targets path 'gone/**' but no matching files found" "$GH_OUT"; then
  echo "ok: the drift line is in the step's report output"
else fail "the drift line is missing from the step's report output"; fi

# A check that cannot run must say so. A python3 that fails stands in for a missing or broken one.
STUB="$(mktemp -d)"; DIRS+=("$STUB")
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$STUB/python3"
chmod +x "$STUB/python3"
rule only 'paths:' '  - "kept/**"'
OUT="$(PATH="$STUB:$PATH" env -u GITHUB_OUTPUT bash "$AUDIT" "$P" 2>&1)"
if printf '%s\n' "$OUT" | grep -qxF "  - Rule path check could not run (python3 missing or failed)"; then
  echo "ok: a rule-path check that cannot run is reported as drift"
else fail "a failing python3 left the rule-path check silent"; fi

new_project
rm -rf "$P/.claude"
audit
if printf '%s\n' "$OUT" | grep -qxF "### No Drift"; then echo "ok: a project with no rules directory reports no drift"
else fail "a project with no rules directory did not report '### No Drift'"; fi

if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures rule-path check(s)"
  exit 1
fi
echo "PASS: audit-tooling rule-path check"
