#!/usr/bin/env bash
# The engine-insert command, exactly as render-contract.md documents it. This belt takes the command
# text out of the doc and runs it: on a freshly assembled page, and on the ways it can go wrong. It
# also proves the committed golden page is a current build of the scaffold, the interactivity bundle,
# the recipe CSS, the engine and the fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RC="$ROOT/walkthrough/skills/render/references/render-contract.md"
E="$ROOT/walkthrough/skills/create/references/system-map-engine.js"
B="$ROOT/tests/walkthrough/sysmap/build-sample.js"
GOLD="$ROOT/tests/walkthrough/fixtures/sysmap-sample.html"
fail(){ echo "FAIL: $1"; exit 1; }
ok(){ echo "ok: $1"; }
for f in "$RC" "$E" "$B" "$GOLD"; do [ -s "$f" ] || fail "missing $f"; done

# --- the documented command: one line, inside a bash fence, naming both placeholders ---
CMD="$(awk '/^[[:space:]]*```bash[[:space:]]*$/{f=1;next} /^[[:space:]]*```[[:space:]]*$/{f=0} f && /@@SYSMAP-ENGINE@@/' "$RC" | sed 's/^[[:space:]]*//')"
[ -n "$CMD" ] || fail "render-contract.md has no bash block holding the engine-insert command"
[ "$(printf '%s\n' "$CMD" | wc -l | tr -d ' ')" -eq 1 ] || fail "the engine-insert command must be exactly one line"
case "$CMD" in *"'<ENGINE>'"*"'<PAGE>'"*) ;; *) fail "the command must take its paths as '<ENGINE>' and '<PAGE>'" ;; esac
ok "render-contract.md documents a one-line insert command"

if ! command -v node >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail "node is required in CI"
  echo "SKIP: node is not installed, so no page was built and the insert command was not run"
  exit 0
fi

T="$(mktemp -d "${TMPDIR:-/tmp}/sysmap-insert.XXXXXX")"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/dir with space"
cp "$E" "$T/dir with space/engine.js"
# bash 5.2 reads "&" in a ${var//pattern/replacement} as "the matched text"; the paths below are data
shopt -u patsub_replacement 2>/dev/null || true
insert() {  # insert <engine> <page>: the documented command with its two placeholders filled in
  local cmd="${CMD//<ENGINE>/$1}"
  cmd="${cmd//<PAGE>/$2}"
  bash -c "$cmd"
}

# --- success: a freshly assembled page, with a space in the engine path ---
node "$B" "$T/page.html"
[ "$(grep -cx '/\*@@SYSMAP-ENGINE@@\*/' "$T/page.html")" -eq 1 ] || fail "a freshly assembled page must carry the marker line exactly once"
insert "$T/dir with space/engine.js" "$T/page.html" || fail "the documented command failed on a good page"
if grep -q '@@SYSMAP-ENGINE@@' "$T/page.html"; then fail "the marker is still in the page after the insert"; fi
[ "$(grep -cx '/\* walkthrough system-map engine v1 \*/' "$T/page.html")" -eq 1 ] || fail "the start sentinel must be in the page exactly once"
[ "$(grep -cx '/\* end walkthrough system-map engine \*/' "$T/page.html")" -eq 1 ] || fail "the end sentinel must be in the page exactly once"
[ ! -e "$T/page.html.tmp" ] || fail "the command left a temp file behind"
awk '/<script id="wt-sysmap">$/{f=1;next} f&&/^<\/script>$/{exit} f' "$T/page.html" | cmp -s - "$E" \
  || fail "the inserted block is not byte-identical to the engine file"
ok "insert on a fresh page: marker gone, each sentinel once, block identical to the engine file"

cmp -s "$T/page.html" "$GOLD" \
  || fail "tests/walkthrough/fixtures/sysmap-sample.html is stale. Regenerate it: node tests/walkthrough/sysmap/build-sample.js tests/walkthrough/fixtures/sysmap-sample.html --inserted"
ok "the golden page is a current build, and the shell insert gives the same bytes as the generator"

# --- hostile paths: the command holds both paths in single quotes, so every shell metacharacter but
# the single quote itself must stay inert. A path that tries to run something must run nothing. ---
HOSTILE="$T/a \$(touch PWNED1) \`touch PWNED2\`; touch PWNED3 \"q\" * \$HOME"
mkdir -p "$HOSTILE"
cp "$E" "$HOSTILE/engine.js"
node "$B" "$HOSTILE/page.html"
# run from $T, so that anything the path managed to execute would leave its file there
( cd "$T" && insert "$HOSTILE/engine.js" "$HOSTILE/page.html" ) || fail "the documented command failed on a path full of shell metacharacters"
cmp -s "$HOSTILE/page.html" "$GOLD" || fail "a path full of shell metacharacters changed what was inserted"
for p in PWNED1 PWNED2 PWNED3; do
  [ ! -e "$T/$p" ] || fail "a shell metacharacter in a path was executed ($p was created): the paths must stay inside single quotes"
done
grep -qF "Never run it when either path contains a single quote" "$RC" \
  || fail "render-contract.md must forbid the shell insert for a path that contains a single quote: it is the one character single quotes cannot hold"
ok "metacharacters in a path run nothing; the single quote is ruled out in writing"

# --- failure: each must exit non-zero, leave the page byte-identical and leave no temp file ---
refuse() {  # refuse <label> <engine> <page>
  local before; before="$(cksum < "$3")"
  if insert "$2" "$3" 2>/dev/null; then fail "$1: the command must fail"; fi
  [ "$(cksum < "$3")" = "$before" ] || fail "$1: the page was changed"
  [ ! -e "$3.tmp" ] || fail "$1: a temp file was left behind"
}
node "$B" "$T/a.html"
sed 's#^/\*@@SYSMAP-ENGINE@@\*/$#/* no marker */#' "$T/a.html" > "$T/nomarker.html"
refuse "no marker line" "$E" "$T/nomarker.html"
awk '{print} $0=="/*@@SYSMAP-ENGINE@@*/"{print}' "$T/a.html" > "$T/two.html"
refuse "two marker lines" "$E" "$T/two.html"
sed 's#^/\*@@SYSMAP-ENGINE@@\*/$#  /*@@SYSMAP-ENGINE@@*/#' "$T/a.html" > "$T/indented.html"
refuse "indented marker line" "$E" "$T/indented.html"
cp "$T/a.html" "$T/b.html"
refuse "engine file missing" "$T/nope.js" "$T/b.html"
: > "$T/empty.js"
refuse "engine file empty" "$T/empty.js" "$T/b.html"
ok "five ways to go wrong: each fails, leaves the page untouched and leaves no temp file"

echo "PASS: system-map engine insert"
