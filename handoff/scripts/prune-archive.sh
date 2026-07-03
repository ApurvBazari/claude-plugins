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

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/handoff-lib.sh"

PROJECT_ROOT="${1:-.}"
ARCHIVE_DIR="$PROJECT_ROOT/.claude/handoff/archive"
SETTINGS_FILE="$PROJECT_ROOT/.claude/handoff/settings.md"

[[ -d "$ARCHIVE_DIR" ]] || exit 0

# Resolve the retention cap via the SHARED normalizer, so prune and
# compute-progress cannot drift (audit H6/H7). hf_normalize_retention returns
# `unlimited` | a non-negative integer | `10` (default for empty/garbage) —
# so past the `unlimited`/`0` cases below, `retention` is guaranteed a
# non-negative integer and the numeric-cap block needs no further validation.
retention="$(hf_normalize_retention "$(hf_get_fm_value "$SETTINGS_FILE" 'archive-retention')")"

case "$retention" in
  unlimited)
    exit 0
    ;;
  0)
    find "$ARCHIVE_DIR" -maxdepth 1 -name '*.md' -type f -exec rm -f {} +
    exit 0
    ;;
esac

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
