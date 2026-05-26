#!/usr/bin/env bash
# Merge or replace a YAML-frontmatter key in a markdown file.
#
# Usage: merge-fm-key.sh <file> <key> <value>
#   - If <file> does not exist: create it with `---\n<key>: <value>\n---\n`.
#   - If <file> exists with frontmatter and the key is present: replace its value.
#   - If <file> exists with frontmatter and the key is absent: append the key
#     just before the closing `---`.
#
# Used by handoff/skills/save (writing archive-retention + gitignore-prompt)
# and handoff/skills/pickup (writing deferred-at).
#
# Exit 0 on success, 2 on missing args.

set -uo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $(basename "$0") <file> <key> <value>" >&2
  exit 2
fi

file="$1"
key="$2"
val="$3"

# File doesn't exist → bootstrap a fresh frontmatter-only file.
if [[ ! -f "$file" ]]; then
  mkdir -p "$(dirname "$file")"
  printf -- '---\n%s: %s\n---\n' "$key" "$val" > "$file"
  exit 0
fi

# File exists → merge.
# Use mktemp for an unpredictable name and trap so an interrupt between
# awk write and mv does not leave an orphaned temp file behind.
tmp="$(mktemp "${file}.tmp.XXXXXX")" || exit 1
trap 'rm -f "$tmp"' EXIT
awk -v k="$key" -v v="$val" '
  BEGIN { in_fm = 0; fm_count = 0; emitted = 0 }
  /^---[[:space:]]*$/ {
    if (fm_count == 1 && !emitted) print k ": " v
    fm_count++
    in_fm = (fm_count == 1)
    print
    next
  }
  in_fm && $0 ~ "^"k":" { print k ": " v; emitted = 1; next }
  { print }
  END {
    # File had no frontmatter at all — synthesize one at the top is risky
    # for a markdown file with a body. Skip silently and let the caller
    # decide. (The bootstrap path above handles the empty-file case.)
  }
' "$file" > "$tmp" && mv "$tmp" "$file"

exit 0
