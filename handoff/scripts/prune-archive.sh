#!/usr/bin/env bash
# Prune .claude/handoff/archive/ down to the archive-retention cap.
#
# Usage: prune-archive.sh <project-root>
#   Reads <project-root>/.claude/handoff/settings.md frontmatter for
#   `archive-retention`. Defaults to 10. Special values:
#     0           → remove every file in archive/
#     unlimited   → skip pruning entirely (also accepts -1)
#
# Exits 0 in every non-crash case. Missing archive/ dir is a silent no-op.
# Conventions: hook-script style (no `set -e`).

set -uo pipefail

PROJECT_ROOT="${1:-.}"
ARCHIVE_DIR="$PROJECT_ROOT/.claude/handoff/archive"
SETTINGS_FILE="$PROJECT_ROOT/.claude/handoff/settings.md"

[[ -d "$ARCHIVE_DIR" ]] || exit 0

# Default cap.
retention="10"

if [[ -f "$SETTINGS_FILE" ]]; then
  # Parse frontmatter line `archive-retention: <value>` (between the first two `---`).
  v="$(awk '
    BEGIN { in_fm = 0; fm_count = 0 }
    /^---[[:space:]]*$/ { fm_count++; in_fm = (fm_count == 1); next }
    fm_count >= 2 { exit }
    in_fm {
      pos = index($0, ":")
      if (pos == 0) next
      k = substr($0, 1, pos - 1); v = substr($0, pos + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/^["'\''"]|["'\''"]$/, "", v)
      if (k == "archive-retention") { print v; exit }
    }
  ' "$SETTINGS_FILE" 2>/dev/null)"
  [[ -n "$v" ]] && retention="$v"
fi

# Special values.
case "$retention" in
  unlimited|-1)
    exit 0
    ;;
  0)
    find "$ARCHIVE_DIR" -maxdepth 1 -name '*.md' -type f -exec rm -f {} +
    exit 0
    ;;
esac

# Numeric cap. Anything non-numeric falls back to default 10.
if ! [[ "$retention" =~ ^[0-9]+$ ]]; then
  retention="10"
fi

# Sort newest-first by mtime, keep first <retention>, rm the rest.
# Use `find -printf` substitute via `stat`-free portable trick.
# shellcheck disable=SC2012
# ls -t is used intentionally here: we need mtime-based ordering, which ls -t
# provides portably across macOS (BSD) and Linux without requiring stat or find -printf.
files_to_delete="$(
  find "$ARCHIVE_DIR" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null \
    | awk -v keep="$retention" 'NR > keep'
)"

# IFS=newline only.
if [[ -n "$files_to_delete" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && rm -f -- "$f"
  done <<< "$files_to_delete"
fi

exit 0
