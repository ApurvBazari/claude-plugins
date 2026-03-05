#!/bin/bash
# notify.sh — Dynamic notification script for Claude Code hooks
# Usage: echo '<stdin_json>' | notify.sh <event>
# Events: stop, notification, subagentStop

EVENT="${1:-stop}"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$BASE_DIR/notify-config.json"

# --- JSON helper: tries jq, falls back to python3 ---
json_get() {
  local json="$1" path="$2"
  local result=""

  if command -v jq &>/dev/null; then
    result="$(echo "$json" | jq -r "$path" 2>/dev/null)"
  elif command -v python3 &>/dev/null; then
    result="$(echo "$json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    keys = '''$path'''.strip('.').split('.')
    val = data
    for k in keys:
        val = val[k]
    print(val if val is not None else '')
except Exception:
    print('')
" 2>/dev/null)"
  fi

  # jq returns "null" for missing keys
  if [ "$result" = "null" ] || [ -z "$result" ]; then
    echo ""
  else
    echo "$result"
  fi
}

# --- Read config ---
ENABLED="true"
SOUND="Ping"
ACTIVATE="com.microsoft.VSCode"
FALLBACK_MESSAGE="Notification"

if [ -f "$CONFIG_FILE" ]; then
  CONFIG="$(cat "$CONFIG_FILE")"
  EVENT_ENABLED="$(json_get "$CONFIG" ".events.${EVENT}.enabled")"
  EVENT_SOUND="$(json_get "$CONFIG" ".events.${EVENT}.sound")"
  EVENT_ACTIVATE="$(json_get "$CONFIG" ".events.${EVENT}.activate")"
  EVENT_MESSAGE="$(json_get "$CONFIG" ".events.${EVENT}.message")"

  [ -n "$EVENT_ENABLED" ] && ENABLED="$EVENT_ENABLED"
  [ -n "$EVENT_SOUND" ] && SOUND="$EVENT_SOUND"
  [ -n "$EVENT_ACTIVATE" ] && ACTIVATE="$EVENT_ACTIVATE"
  [ -n "$EVENT_MESSAGE" ] && FALLBACK_MESSAGE="$EVENT_MESSAGE"
else
  # No config file — use hardcoded defaults per event
  case "$EVENT" in
    stop)
      ENABLED="true"; SOUND="Hero"; FALLBACK_MESSAGE="Task completed" ;;
    notification)
      ENABLED="true"; SOUND="Glass"; FALLBACK_MESSAGE="Needs your attention" ;;
    subagentStop)
      ENABLED="false"; SOUND="Ping"; FALLBACK_MESSAGE="Subagent task completed" ;;
  esac
fi

# Exit silently if disabled
if [ "$ENABLED" = "false" ]; then
  exit 0
fi

# --- Read stdin JSON (Claude Code passes context via stdin) ---
STDIN_JSON=""
if ! [ -t 0 ]; then
  STDIN_JSON="$(cat)"
fi

# --- Extract contextual message ---
MESSAGE=""
TITLE="Claude Code"

case "$EVENT" in
  stop)
    MESSAGE="$(json_get "$STDIN_JSON" ".last_assistant_message")"
    ;;
  subagentStop)
    MESSAGE="$(json_get "$STDIN_JSON" ".last_assistant_message")"
    AGENT_TYPE="$(json_get "$STDIN_JSON" ".agent_type")"
    if [ -n "$AGENT_TYPE" ]; then
      TITLE="Claude Code ($AGENT_TYPE)"
    fi
    ;;
  notification)
    MESSAGE="$(json_get "$STDIN_JSON" ".message")"
    ;;
esac

# Fall back to config message if extraction failed
if [ -z "$MESSAGE" ]; then
  MESSAGE="$FALLBACK_MESSAGE"
fi

# Sanitize: replace newlines with spaces
MESSAGE="$(echo "$MESSAGE" | tr '\n' ' ' | tr '\r' ' ')"

# Truncate to 80 chars
if [ "${#MESSAGE}" -gt 80 ]; then
  MESSAGE="${MESSAGE:0:80}..."
fi

# --- Build subtitle from git context ---
SUBTITLE=""
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$GIT_ROOT" ]; then
  REPO_NAME="$(basename "$GIT_ROOT")"
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  SUBTITLE="📦 $REPO_NAME  🔀 ${BRANCH:-detached}"
else
  SUBTITLE="📂 $(basename "$PWD")"
fi

# --- Send notification ---
terminal-notifier -title "$TITLE" -subtitle "$SUBTITLE" -message "$MESSAGE" -sound "$SOUND" -activate "$ACTIVATE"

# Always exit 0 — never block Claude
exit 0
