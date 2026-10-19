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
# which is what CI and any other clone see.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${PRIVATE_NAMES_FILE:-$ROOT/.claude/private-names.txt}"

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
for name in "${names[@]}"; do
  hits="$(git -C "$ROOT" grep -n -i -I -F -e "$name" || true)"
  if [[ -n "$hits" ]]; then
    failed=$((failed + 1))
    echo "FAIL: $(printf '%s\n' "$hits" | wc -l | tr -d ' ') tracked line(s) name a private project:"
    printf '%s\n' "$hits" | cut -c1-200 | head -20
  fi
done

if [[ "$failed" -gt 0 ]]; then
  echo "test_private_names: $failed of ${#names[@]} name(s) found in tracked files"
  exit 1
fi
echo "ok: none of the ${#names[@]} listed name(s) appears in a tracked file"
