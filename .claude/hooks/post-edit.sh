#!/usr/bin/env bash
# post-edit.sh — PostToolUse hook: advisory warnings on structural changes
# Usage: echo '<stdin_json>' | post-edit.sh
# Always exits 0 — advisory only, never blocks

STDIN_JSON=""
if ! [[ -t 0 ]]; then
  STDIN_JSON="$(cat)"
fi

# Extract file path from stdin JSON
FILE_PATH=""
if command -v jq &>/dev/null; then
  FILE_PATH="$(echo "$STDIN_JSON" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
else
  FILE_PATH="$(echo "$STDIN_JSON" | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')"
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  */.claude-plugin/plugin.json)
    echo "REMINDER: plugin.json was modified. Ensure the version matches marketplace.json."
    ;;
  */skills/*/SKILL.md)
    FIRST_H1="$(grep -m1 '^# ' "$FILE_PATH" 2>/dev/null || true)"
    if [[ -n "$FIRST_H1" ]] && ! echo "$FIRST_H1" | grep -q '^# /'; then
      echo "REMINDER: SKILL.md H1 should follow '/plugin:skill — Description' naming. Found: $FIRST_H1"
    fi
    ;;
  *.sh)
    if [[ -f "$FILE_PATH" ]] && [[ ! -x "$FILE_PATH" ]]; then
      echo "REMINDER: $FILE_PATH is not executable. Run: chmod +x $FILE_PATH"
    fi
    ;;
esac

# Always exit 0 — advisory only
exit 0
