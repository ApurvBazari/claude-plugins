#!/usr/bin/env bash
# Merge or replace a YAML-frontmatter key in a markdown file.
#
# Usage: merge-fm-key.sh <file> <key> <value>
#   - If <file> does not exist: create it with `---\n<key>: <value>\n---\n`.
#   - If <file> exists with frontmatter and the key is present: replace its value.
#   - If <file> exists with frontmatter and the key is absent: append the key
#     just before the closing `---`.
#   - If <file> exists but has NO frontmatter: error out (cannot merge a key
#     into a file with no `---`…`---` block).
#
# Used by handoff/skills/save (writing archive-retention + gitignore-prompt)
# and handoff/skills/pickup (writing deferred-at).
#
# Exit 0 on success, 2 on missing args, 3 on a frontmatter-less file.

set -euo pipefail

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

# H3: a file with no YAML frontmatter cannot have a key merged into it. The old
# awk silently no-op'd (exit 0) → callers lost the write (e.g. a snooze that
# never persisted). Fail loudly instead.
if ! awk '/^---[[:space:]]*$/{c++} c>=2{f=1} END{exit f?0:1}' "$file"; then
  echo "error: $file has no YAML frontmatter (need a '---' … '---' block); cannot merge '$key'" >&2
  exit 3
fi

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
    # By the time this awk runs the file is guaranteed to have frontmatter —
    # the frontmatter-presence check above exits 3 on a frontmatter-less file,
    # and the bootstrap path handles a missing file. Nothing to do here.
  }
' "$file" > "$tmp" && mv "$tmp" "$file"

exit 0
