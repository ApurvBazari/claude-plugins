#!/usr/bin/env bash
# test_ref_anchors.sh — resolve section/anchor cross-references in onboard/ and self-test vs fixtures.
#
# Closes the gap CI's file-level .github/scripts/check-ref-paths.sh leaves open: that belt proves the
# referenced FILE exists; this one proves the referenced SECTION/ANCHOR inside it exists too. Two forms:
#   Form 1 (prose):    `relpath.md` § Section Name
#   Form 2 (md-link):  [text](relpath.md#anchor)
# File-only refs (no § / no #) are already covered by check-ref-paths.sh and are out of scope here.
#
# For each ref: the target file must resolve from the citing file's directory AND a matching heading
# must exist in it (prose -> first-N-word key match on normalized headings; md-link -> GitHub-style
# slug match). Prints one `STALE(...): <src> -> <ref>` line per unresolved ref.
#
# Usage: test_ref_anchors.sh [root ...]      (default roots: onboard/skills onboard/agents)
# Exit:  0 iff the fixture self-test passes AND every parseable cross-ref in the scanned roots resolves
#        to an existing file + heading; nonzero if any STALE ref is found (or a fixture regresses).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 1

# Collect real-scan STALE findings in a temp file (mktemp — no predictable /tmp name, per SP-6 lesson).
# The exit code is decided by grepping this file, NOT by a variable set inside a `grep | while` pipe
# (that runs in a subshell, so an inner `fail=1` would never reach the outer shell — the brief's bug #1).
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

norm(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/ /g; s/^ +//; s/ +$//'; }
headings(){ grep -hE '^#{1,6} ' "$1" 2>/dev/null | sed -E 's/^#+ +//'; }

# Prose refs: `path.md` § Section Name. Roots are passed through as "$@" (bug #2 fix — each root a
# separate arg so BOTH onboard/skills and onboard/agents are actually scanned, not one literal path).
# shellcheck disable=SC2016  # the backticks and \1 in the grep/sed single-quotes are literal regex, not shell expansion
check_prose(){
  grep -rHnoE '`[^`]+\.md` § [A-Za-z][^`]*' "$@" 2>/dev/null | while IFS= read -r line; do
    src="${line%%:*}"; body="${line#*:}"; body="${body#*:}"
    case "$body" in *']('*) continue ;; esac       # a real md-link, not a prose ref — skip
    path="$(printf '%s' "$body" | sed -E 's/^`([^`]+\.md)`.*/\1/')"
    sec="$(printf '%s' "$body" | sed -E 's/^`[^`]+\.md` § //; s/ § .*//; s/[],.;)(].*//; s/ (for|before|with|consumes|drop|keys|as|and|must|into) .*//')"
    [ -n "$(printf '%s' "$sec" | tr -d ' ')" ] || continue
    tgt="$(cd "$(dirname "$src")" && cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$path")")"
    if [ ! -f "$tgt" ]; then echo "STALE(prose-file): $src -> $path"; continue; fi
    key="$(norm "$sec" | awk '{n=(NF<4?NF:4);for(i=1;i<=n;i++)printf (i>1?" ":"")$i}')"
    if ! headings "$tgt" | while IFS= read -r h; do norm "$h"; done | grep -qF "$key"; then
      echo "STALE(prose-section): $src -> \`$path\` § $sec  [key: $key]"
    fi
  done
}

# Markdown links: [text](path.md#anchor). Roots passed through as "$@" (same bug #2 fix).
check_links(){
  grep -rHnoE '\]\([^)]+\.md#[a-z0-9-]+\)' "$@" 2>/dev/null | sed -E 's/\]\(([^)]+)\)/\1/' | while IFS= read -r line; do
    src="${line%%:*}"; ref="${line#*:}"; ref="${ref#*:}"
    path="${ref%%#*}"; anchor="${ref#*#}"
    tgt="$(cd "$(dirname "$src")" && cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$path")")"
    if [ ! -f "$tgt" ]; then echo "STALE(md-file): $src -> $path"; continue; fi
    if ! headings "$tgt" | while IFS= read -r h; do printf '%s' "$h" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g'; done | grep -qiF "$anchor"; then
      echo "STALE(md-anchor): $src -> $path#$anchor"
    fi
  done
}

# --- Fixture self-test: the checker MUST flag stale.md and MUST NOT flag good.md. ---
FX="tests/onboard/fixtures/anchors"
if   check_prose "$FX/good.md"  | grep -q '^STALE'; then echo "FIXTURE-FAIL: good.md wrongly flagged"; exit 1; fi
if ! check_prose "$FX/stale.md" | grep -q '^STALE'; then echo "FIXTURE-FAIL: stale.md not flagged";    exit 1; fi

# --- Real scan. Exit code reflects findings via the temp file (fix for the brief's subshell `fail`). ---
if [ "$#" -gt 0 ]; then roots=("$@"); else roots=(onboard/skills onboard/agents); fi
{ check_prose "${roots[@]}"; check_links "${roots[@]}"; } | tee "$tmp"
grep -q '^STALE' "$tmp" && exit 1
exit 0
