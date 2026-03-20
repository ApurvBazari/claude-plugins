#!/bin/bash
# notify.sh — Dynamic notification script for Claude Code hooks
# Usage: echo '<stdin_json>' | notify.sh <event>
# Events: stop, notification, subagentStop
# Supports: macOS (terminal-notifier) and Linux (notify-send)

EVENT="${1:-stop}"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$BASE_DIR/notify-config.json"
TIMESTAMP_FILE="${TMPDIR:-/tmp}/claude-notify-session-start"

# --- Detect platform ---
PLATFORM="unknown"
case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
esac

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
  if [[ "$result" = "null" ]] || [[ -z "$result" ]]; then
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
MIN_DURATION=0

if [[ -f "$CONFIG_FILE" ]]; then
  CONFIG="$(cat "$CONFIG_FILE")"
  EVENT_ENABLED="$(json_get "$CONFIG" ".events.${EVENT}.enabled")"
  EVENT_SOUND="$(json_get "$CONFIG" ".events.${EVENT}.sound")"
  EVENT_ACTIVATE="$(json_get "$CONFIG" ".events.${EVENT}.activate")"
  EVENT_MESSAGE="$(json_get "$CONFIG" ".events.${EVENT}.message")"
  EVENT_MIN_DURATION="$(json_get "$CONFIG" ".events.${EVENT}.minDurationSeconds")"

  [[ -n "$EVENT_ENABLED" ]] && ENABLED="$EVENT_ENABLED"
  [[ -n "$EVENT_SOUND" ]] && SOUND="$EVENT_SOUND"
  [[ -n "$EVENT_ACTIVATE" ]] && ACTIVATE="$EVENT_ACTIVATE"
  [[ -n "$EVENT_MESSAGE" ]] && FALLBACK_MESSAGE="$EVENT_MESSAGE"
  [[ -n "$EVENT_MIN_DURATION" ]] && MIN_DURATION="$EVENT_MIN_DURATION"
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
if [[ "$ENABLED" = "false" ]]; then
  exit 0
fi

# --- Duration filtering ---
# Record timestamp on stop events for future duration checks.
# On stop/subagentStop: check elapsed time since last prompt or session start.
NOW_EPOCH="$(date +%s 2>/dev/null || echo 0)"

if [[ "$EVENT" = "stop" ]] || [[ "$EVENT" = "subagentStop" ]]; then
  if [[ "$MIN_DURATION" -gt 0 ]] && [[ -f "$TIMESTAMP_FILE" ]]; then
    START_EPOCH="$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)"
    if [[ "$START_EPOCH" =~ ^[0-9]+$ ]] && [[ "$NOW_EPOCH" =~ ^[0-9]+$ ]]; then
      ELAPSED=$((NOW_EPOCH - START_EPOCH))
      if [[ "$ELAPSED" -lt "$MIN_DURATION" ]]; then
        # Response was too fast — skip notification
        exit 0
      fi
    fi
  fi
fi

# Update timestamp on every event (tracks last activity)
echo "$NOW_EPOCH" > "$TIMESTAMP_FILE" 2>/dev/null

# --- Read stdin JSON (Claude Code passes context via stdin) ---
STDIN_JSON=""
if ! [[ -t 0 ]]; then
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
    if [[ -n "$AGENT_TYPE" ]]; then
      TITLE="Claude Code ($AGENT_TYPE)"
    fi
    ;;
  notification)
    MESSAGE="$(json_get "$STDIN_JSON" ".message")"
    ;;
esac

# Fall back to config message if extraction failed
if [[ -z "$MESSAGE" ]]; then
  MESSAGE="$FALLBACK_MESSAGE"
fi

# Sanitize: replace newlines with spaces
MESSAGE="$(echo "$MESSAGE" | tr '\n' ' ' | tr '\r' ' ')"

# Truncate to 80 chars
if [[ "${#MESSAGE}" -gt 80 ]]; then
  MESSAGE="${MESSAGE:0:80}..."
fi

# --- Build subtitle from git context ---
SUBTITLE=""
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -n "$GIT_ROOT" ]]; then
  REPO_NAME="$(basename "$GIT_ROOT")"
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  SUBTITLE="$REPO_NAME / ${BRANCH:-detached}"
else
  SUBTITLE="$(basename "$PWD")"
fi

# --- Send notification (platform-specific) ---
if [[ "$PLATFORM" = "macos" ]]; then
  if command -v terminal-notifier &>/dev/null; then
    terminal-notifier \
      -title "$TITLE" \
      -subtitle "$SUBTITLE" \
      -message "$MESSAGE" \
      -sound "$SOUND" \
      -activate "$ACTIVATE"
  fi
elif [[ "$PLATFORM" = "linux" ]]; then
  if command -v notify-send &>/dev/null; then
    # Map sound config to urgency level
    URGENCY="normal"
    case "$SOUND" in
      Glass|Basso|Sosumi|Funk) URGENCY="critical" ;;
    esac
    notify-send \
      --app-name "$TITLE" \
      --urgency "$URGENCY" \
      "$SUBTITLE" \
      "$MESSAGE"
  fi
fi

# Always exit 0 — never block Claude
exit 0
