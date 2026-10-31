#!/usr/bin/env bash
set -uo pipefail

# FileChanged hook: detect dependency changes in package manifests.
# Appends change entries to the drift log (.claude/onboard-drift.json).
# Called when package.json, pyproject.toml, Cargo.toml, go.mod, or Gemfile changes.

FILE_PATH="${1:-}"
DRIFT_FILE=".claude/onboard-drift.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Defensive: FileChanged hook payload should be a workspace-relative or
# absolute path. Refuse option-flag-looking input or shell metacharacters.
# Hook scripts must always exit 0: a non-zero exit would surface as a hook error in the user's session.
case "$FILE_PATH" in
  /*|./*|[a-zA-Z0-9_]*) ;;
  *) exit 0 ;;
esac

# Ensure drift file exists
mkdir -p .claude
if [ ! -f "$DRIFT_FILE" ]; then
  printf '{"lastAuditedAt":null,"entries":[]}\n' > "$DRIFT_FILE"
fi

# Detect changes based on file type
CHANGES=""
BASENAME=$(basename "$FILE_PATH")

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

case "$BASENAME" in
  package.json)
    # Compare current deps against what's in the project metadata (if available)
    if command -v jq >/dev/null 2>&1 && [ -f "$FILE_PATH" ]; then
      CHANGES=$(jq -c '
        [ ((.dependencies // {}) | keys_unsorted[] | {action: "present", name: ., type: "dependency"}),
          ((.devDependencies // {}) | keys_unsorted[] | {action: "present", name: ., type: "dependency"}),
          ((.scripts // {}) | keys_unsorted[] | {action: "present", name: ., type: "script"}) ]
      ' "$FILE_PATH" 2>/dev/null || echo "[]")
    fi
    ;;
  pyproject.toml)
    CHANGES='[{"action": "modified", "name": "pyproject.toml", "type": "dependency"}]'
    ;;
  Cargo.toml)
    CHANGES='[{"action": "modified", "name": "Cargo.toml", "type": "dependency"}]'
    ;;
  go.mod)
    CHANGES='[{"action": "modified", "name": "go.mod", "type": "dependency"}]'
    ;;
  Gemfile)
    CHANGES='[{"action": "modified", "name": "Gemfile", "type": "dependency"}]'
    ;;
  *)
    exit 0
    ;;
esac

if [ -z "$CHANGES" ] || [ "$CHANGES" = "[]" ]; then
  exit 0
fi

# Append entry to drift file
# shellcheck disable=SC2016  # jq variables, not shell expansions
append_entry '{timestamp: $ts, file: $bn, type: "dependency", changes: $changes}' \
  --arg ts "$TIMESTAMP" --arg bn "$BASENAME" --argjson changes "$CHANGES"

exit 0
