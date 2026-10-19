#!/usr/bin/env bash
# test_private_names.sh — no tracked file names one of the owner's private projects.
#
# Usage: tests/test_private_names.sh
#
# The names themselves never enter the repo: they live in a gitignored list, one name per line,
# with `#` comments and blank lines allowed. The list is $PRIVATE_NAMES_FILE, by default
# .claude/private-names.txt (under .claude/, which .gitignore already excludes). Matching is a
# case-insensitive fixed-string search over every tracked text file, so a name inside a path,
# an id or a sentence is caught alike. With no list on this machine the belt skips with a notice,
# which is what any other clone, and CI without the PRIVATE_NAMES secret, see.
#
# Under GitHub Actions (or PRIVATE_NAMES_QUIET=1) a hit prints only the name's position in the list
# and its line count, never the matching lines: CI logs are public, and GitHub's secret masking is
# case-sensitive while this match is not, so a printed line could carry a name past the mask.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${PRIVATE_NAMES_FILE:-$ROOT/.claude/private-names.txt}"
QUIET=0
if [[ "${GITHUB_ACTIONS:-}" == "true" || "${PRIVATE_NAMES_QUIET:-0}" == "1" ]]; then QUIET=1; fi

if [[ ! -f "$LIST" ]]; then
  echo "SKIP: no private-name list at ${LIST#"$ROOT"/} — nothing to check on this machine"
  exit 0
fi

names=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -n "$line" ]] && names+=("$line")
done < "$LIST"

if [[ "${#names[@]}" -eq 0 ]]; then
  echo "FAIL: ${LIST#"$ROOT"/} holds no names — an empty list would pass by construction"
  exit 1
fi

failed=0
position=0
for name in "${names[@]}"; do
  position=$((position + 1))
  hits="$(git -C "$ROOT" grep -n -i -I -F -e "$name" || true)"
  if [[ -n "$hits" ]]; then
    failed=$((failed + 1))
    count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
    if [[ "$QUIET" -eq 1 ]]; then
      echo "FAIL: listed name #$position appears on $count tracked line(s) — run tests/test_private_names.sh locally to see where"
    else
      echo "FAIL: $count tracked line(s) name a private project:"
      printf '%s\n' "$hits" | cut -c1-200 | head -20
    fi
  fi
done

if [[ "$failed" -gt 0 ]]; then
  echo "test_private_names: $failed of ${#names[@]} name(s) found in tracked files"
  exit 1
fi
echo "ok: none of the ${#names[@]} listed name(s) appears in a tracked file"
