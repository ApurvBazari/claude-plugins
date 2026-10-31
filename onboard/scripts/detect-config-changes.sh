#!/usr/bin/env bash
set -uo pipefail

# FileChanged hook: detect configuration file changes.
# Appends change entries to the drift log (.claude/onboard-drift.json).
# Called when tsconfig, eslint, prettier, biome, or ruff configs change.

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

# Ensure drift file exists
mkdir -p .claude
if [ ! -f "$DRIFT_FILE" ]; then
  printf '{"lastAuditedAt":null,"entries":[]}\n' > "$DRIFT_FILE"
fi

BASENAME=$(basename "$FILE_PATH")

# Only process known config files
case "$BASENAME" in
  tsconfig*.json|.eslintrc*|eslint.config*|prettier.config*|.prettierrc*|biome.json|ruff.toml|.ruff.toml|pyproject.toml)
    ;;
  *)
    exit 0
    ;;
esac

# Detect what type of config this is
CONFIG_TYPE="unknown"
case "$BASENAME" in
  tsconfig*) CONFIG_TYPE="typescript" ;;
  .eslintrc*|eslint.config*) CONFIG_TYPE="eslint" ;;
  prettier.config*|.prettierrc*) CONFIG_TYPE="prettier" ;;
  biome.json) CONFIG_TYPE="biome" ;;
  ruff.toml|.ruff.toml) CONFIG_TYPE="ruff" ;;
  pyproject.toml) CONFIG_TYPE="python-project" ;;
esac

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

# Append entry to drift file
# shellcheck disable=SC2016  # jq variables, not shell expansions
append_entry '{timestamp: $ts, file: $bn, type: "config", changes: [{action: "modified", configType: $ct, path: $fp}]}' \
  --arg ts "$TIMESTAMP" --arg bn "$BASENAME" --arg ct "$CONFIG_TYPE" --arg fp "$FILE_PATH"

exit 0
