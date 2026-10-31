#!/usr/bin/env bash
set -uo pipefail

# FileChanged hook: detect structural changes (new directories with source files).
# Appends change entries to the drift log (.claude/onboard-drift.json).
# Called on any file change — checks if the file's directory is a new, uncovered directory.

FILE_PATH="${1:-}"
DRIFT_FILE=".claude/onboard-drift.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Defensive: FileChanged hook payload should be a workspace-relative or
# absolute path. Refuse option-flag-looking input or shell metacharacters.
# Hook scripts must always exit 0 (see .claude/rules/shell-scripts.md).
case "$FILE_PATH" in
  /*|./*|[a-zA-Z0-9_]*) ;;
  *) exit 0 ;;
esac

# Only track source files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.rb|*.java|*.kt|*.swift|*.c|*.cpp|*.h)
    ;;
  *)
    exit 0
    ;;
esac

# Get the directory of the changed file
FILE_DIR=$(dirname "$FILE_PATH")

# Skip common non-architectural directories
case "$FILE_DIR" in
  node_modules*|.git*|dist*|build*|.next*|__pycache__*|target*|vendor*)
    exit 0
    ;;
esac

# Check if this directory already has a CLAUDE.md (already covered)
if [ -f "$FILE_DIR/CLAUDE.md" ]; then
  exit 0
fi

# Count source files in this directory
SOURCE_COUNT=$(find "$FILE_DIR" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" \) 2>/dev/null | wc -l | tr -d ' ')

# Only flag directories with a meaningful number of source files
if [ "$SOURCE_COUNT" -lt 5 ]; then
  exit 0
fi

# Ensure drift file exists
mkdir -p .claude
if [ ! -f "$DRIFT_FILE" ]; then
  printf '{"lastAuditedAt":null,"entries":[]}\n' > "$DRIFT_FILE"
fi

# Append one entry to the drift log with jq; skip quietly when jq is absent.
# Writes to a temp file first so a failed write never truncates the log.
append_entry() { # <jq-entry-filter> [jq args...]
  local filter="$1"; shift
  command -v jq >/dev/null 2>&1 || return 0
  local tmp
  tmp="$(mktemp "${DRIFT_FILE}.XXXXXX" 2>/dev/null)" || return 0
  if jq "$@" ".entries += [${filter}]" "$DRIFT_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$DRIFT_FILE" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
}

# jq does the JSON work; without it, drift logging is skipped.
command -v jq >/dev/null 2>&1 || exit 0

# Check if we already logged this directory in a recent entry (avoid duplicates)
ALREADY_LOGGED=$(jq -r --arg d "$FILE_DIR" '
  [ (.entries // [])[] | select(.type == "structure") | (.changes // [])[] | select(.path == $d) ]
  | if length > 0 then "true" else "false" end
' "$DRIFT_FILE" 2>/dev/null || echo "false")

if [ "$ALREADY_LOGGED" = "true" ]; then
  exit 0
fi

# Append entry to drift file
# shellcheck disable=SC2016  # jq variables, not shell expansions
append_entry '{timestamp: $ts, file: ($d + "/"), type: "structure", changes: [{action: "new-directory", path: $d, fileCount: $n}]}' \
  --arg ts "$TIMESTAMP" --arg d "$FILE_DIR" --argjson n "$SOURCE_COUNT"

exit 0
