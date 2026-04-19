#!/usr/bin/env bash
# validate-bash.sh — PreToolUse hook: block destructive bash commands
# Usage: echo '<stdin_json>' | validate-bash.sh

STDIN_JSON=""
if ! [[ -t 0 ]]; then
  STDIN_JSON="$(cat)"
fi

# Extract the command from stdin JSON
# Prefer jq; fall back to python3 (handles escaped quotes correctly);
# last-resort grep fallback is deliberately loose and may truncate
# on escaped quotes — the destructive-command case patterns below
# still catch the dangerous prefixes even on truncated input.
COMMAND=""
if command -v jq &>/dev/null; then
  COMMAND="$(echo "$STDIN_JSON" | jq -r '.tool_input.command // ""' 2>/dev/null)"
elif command -v python3 &>/dev/null; then
  COMMAND="$(echo "$STDIN_JSON" | python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    print(data.get("tool_input",{}).get("command",""))
except Exception:
    pass' 2>/dev/null)"
else
  COMMAND="$(echo "$STDIN_JSON" | grep -o '"command": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')"
fi

# Skip if no command extracted
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Block destructive commands
# Note: --force-with-lease is safe and explicitly allowed
case "$COMMAND" in
  *"rm -rf /"*|*"rm -rf ~"*)
    echo "BLOCKED: Destructive rm -rf on root or home directory."
    exit 1
    ;;
  *"git push "*"--force-with-lease"*) ;;
  *"git push --force"*|*"git push -f "*)
    echo "BLOCKED: Force push is dangerous. Use --force-with-lease or ask the user first."
    exit 1
    ;;
  *"git reset --hard"*)
    echo "BLOCKED: Hard reset discards uncommitted work. Confirm with the user first."
    exit 1
    ;;
  *"git clean -f"*)
    echo "BLOCKED: git clean removes untracked files permanently. Confirm with the user first."
    exit 1
    ;;
esac

# All clear
exit 0
