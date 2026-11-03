#!/usr/bin/env bash
set -uo pipefail
# notify.sh — Dynamic notification script for Claude Code hooks
# Usage: echo '<stdin_json>' | notify.sh <event>
# Events: stop, notification, subagentStop
# Supports: macOS (terminal-notifier) and Linux (notify-send)
# Runs as an async Claude Code hook: it prints nothing to stdout and always exits 0.

EVENT="${1:-stop}"

# Allowlist known events — silently exit on unknown values to prevent
# injection into jq paths and defensive-depth for future callers.
case "$EVENT" in
  stop|notification|subagentStop) ;;
  *) exit 0 ;;
esac

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$BASE_DIR/notify-config.json"

# --- Detect platform ---
PLATFORM="unknown"
case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
esac

# --- JSON parsing: jq only, one call per document ---
# jq is a recommended dependency (/notify:setup and /notify:check report it).
# Without jq the hook still runs: it skips parsing, uses the per-event defaults
# below and the generic fallback message, and never fails.
HAVE_JQ=false
command -v jq &>/dev/null && HAVE_JQ=true

# json_fields <json> <jq-filter> [jq args...] — run ONE jq call whose filter emits
# a stream of values; print each as a NUL-terminated string (null → "", booleans
# and numbers → their text). Callers read the fields back with `read -d ''`.
json_fields() {
  local json="$1" filter="$2"
  shift 2
  [[ "$HAVE_JQ" = "true" ]] || return 0
  printf '%s' "$json" | jq -j "$@" \
    "$filter | (if . == null then \"\" else tostring end | gsub(\"\\u0000\"; \"\")) + \"\\u0000\"" \
    2>/dev/null
  return 0
}

# --- Read stdin JSON early (Claude Code passes hook context via stdin) ---
# Read once, up front, so the cooldown timestamp can be keyed per session.
STDIN_JSON=""
if ! [[ -t 0 ]]; then
  STDIN_JSON="$(cat)"
fi

# Parse the hook input once: session_id, last_assistant_message, agent_type, message.
SESSION_ID=""; IN_LAST_MESSAGE=""; IN_AGENT_TYPE=""; IN_MESSAGE=""
{
  IFS= read -r -d '' SESSION_ID
  IFS= read -r -d '' IN_LAST_MESSAGE
  IFS= read -r -d '' IN_AGENT_TYPE
  IFS= read -r -d '' IN_MESSAGE
} < <(json_fields "$STDIN_JSON" '(.session_id, .last_assistant_message, .agent_type, .message)')

# --- Per-session cooldown timestamp file ---
# Key by the hook's session_id when present so concurrent Claude sessions keep
# independent cooldown clocks; fall back to a per-user key otherwise (N2).
# Sanitize the id to a safe filename fragment.
if [[ -n "$SESSION_ID" ]]; then
  SESSION_KEY="session-$(printf '%s' "$SESSION_ID" | tr -c 'A-Za-z0-9._-' '_')"
else
  SESSION_KEY="uid-${UID:-$(id -u)}"
fi
TIMESTAMP_FILE="${TMPDIR:-/tmp}/claude-notify-${SESSION_KEY}"

# Defensive: if another process (or attacker on a world-writable $TMPDIR) has
# pre-created the path as a symlink, named pipe, or other non-regular file,
# refuse to reuse it. Delete it and let the normal write create a fresh file.
# Note: [[ -f ]] follows symlinks, so we test [[ -L ]] first to catch them.
if [[ -L "$TIMESTAMP_FILE" ]] || { [[ -e "$TIMESTAMP_FILE" ]] && [[ ! -f "$TIMESTAMP_FILE" ]]; }; then
  rm -f "$TIMESTAMP_FILE" 2>/dev/null
fi

# --- Read config ---
# Per-event defaults, used when there is no config file, no jq, or a key is absent.
ENABLED="true"; SOUND="Ping"; ACTIVATE="com.microsoft.VSCode"
FALLBACK_MESSAGE="Notification"; MIN_DURATION=0; SHOW_MESSAGE="true"
case "$EVENT" in
  stop)
    ENABLED="true";  SOUND="Hero";  FALLBACK_MESSAGE="Task completed" ;;
  notification)
    ENABLED="true";  SOUND="Glass"; FALLBACK_MESSAGE="Needs your attention" ;;
  subagentStop)
    ENABLED="false"; SOUND="Ping";  FALLBACK_MESSAGE="Subagent task completed" ;;
esac

if [[ -f "$CONFIG_FILE" ]] && [[ "$HAVE_JQ" = "true" ]]; then
  CONFIG="$(cat "$CONFIG_FILE" 2>/dev/null)"
  EVENT_ENABLED=""; EVENT_SOUND=""; EVENT_ACTIVATE=""; EVENT_MESSAGE=""
  EVENT_MIN_DURATION=""; EVENT_SHOW_MESSAGE=""
  # One jq call for every config value this event needs. showMessage is read
  # per event first, then from the top level of the config.
  # shellcheck disable=SC2016  # $e and $ev are jq variables, not shell ones
  CONFIG_FILTER='(.events[$e] // {}) as $ev | ($ev.enabled, $ev.sound, $ev.activate, $ev.message, $ev.minDurationSeconds, (if $ev.showMessage != null then $ev.showMessage else .showMessage end))'
  {
    IFS= read -r -d '' EVENT_ENABLED
    IFS= read -r -d '' EVENT_SOUND
    IFS= read -r -d '' EVENT_ACTIVATE
    IFS= read -r -d '' EVENT_MESSAGE
    IFS= read -r -d '' EVENT_MIN_DURATION
    IFS= read -r -d '' EVENT_SHOW_MESSAGE
  } < <(json_fields "$CONFIG" "$CONFIG_FILTER" --arg e "$EVENT")

  [[ -n "$EVENT_ENABLED" ]] && ENABLED="$EVENT_ENABLED"
  [[ -n "$EVENT_SOUND" ]] && SOUND="$EVENT_SOUND"
  [[ -n "$EVENT_ACTIVATE" ]] && ACTIVATE="$EVENT_ACTIVATE"
  [[ -n "$EVENT_MESSAGE" ]] && FALLBACK_MESSAGE="$EVENT_MESSAGE"
  [[ -n "$EVENT_MIN_DURATION" ]] && MIN_DURATION="$EVENT_MIN_DURATION"
  [[ -n "$EVENT_SHOW_MESSAGE" ]] && SHOW_MESSAGE="$EVENT_SHOW_MESSAGE"
fi

# Exit silently if disabled
if [[ "$ENABLED" = "false" ]]; then
  exit 0
fi

# --- Notification cooldown (leading-edge): suppression check ---
# On stop/subagentStop, suppress the notification if fewer than MIN_DURATION
# seconds have elapsed since the last FIRED notification (the clock recorded in
# TIMESTAMP_FILE, refreshed below only for events that actually fire).
NOW_EPOCH="$(date +%s 2>/dev/null || echo 0)"

if [[ "$EVENT" = "stop" ]] || [[ "$EVENT" = "subagentStop" ]]; then
  # Guard MIN_DURATION numeric BEFORE the arithmetic test: under `set -u`, a non-numeric value
  # (e.g. a malformed minDurationSeconds in config) is evaluated as a variable name in the
  # arithmetic `-gt` context, hits the unbound-variable trap, and aborts the hook — silently
  # dropping the notification. Mirror the START_EPOCH numeric guard below.
  if [[ "$MIN_DURATION" =~ ^[0-9]+$ ]] && [[ "$MIN_DURATION" -gt 0 ]] && [[ -f "$TIMESTAMP_FILE" ]]; then
    START_EPOCH="$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)"
    if [[ "$START_EPOCH" =~ ^[0-9]+$ ]] && [[ "$NOW_EPOCH" =~ ^[0-9]+$ ]]; then
      ELAPSED=$((NOW_EPOCH - START_EPOCH))
      if [[ "$ELAPSED" -lt "$MIN_DURATION" ]]; then
        # Within the cooldown window — suppress this notification
        exit 0
      fi
    fi
  fi
fi

# Refresh the cooldown clock — reached ONLY past the suppression `exit 0` above,
# so only events that actually FIRE refresh it. This makes the cooldown
# leading-edge: "at most one notification per N seconds since the last fired one."
# Suppressed events deliberately do NOT refresh it. Moving this block above the
# suppression exit would silently make the cooldown trailing-edge — a fork
# violation (see spec 2026-07-02 §6a). Atomic write: create a sibling temp file,
# then rename. Closes the TOCTOU window between the symlink guard above and the
# write — even if an attacker drops a symlink at $TIMESTAMP_FILE after the check,
# the rename replaces the directory entry atomically and never writes through it.
if tmp="$(mktemp "${TIMESTAMP_FILE}.XXXXXX" 2>/dev/null)"; then
  if echo "$NOW_EPOCH" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$TIMESTAMP_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
fi

# --- Extract contextual message ---
# showMessage:false keeps Claude's text out of the notification: only the
# configured fallback message is shown.
MESSAGE=""
TITLE="Claude Code"

case "$EVENT" in
  stop)
    MESSAGE="$IN_LAST_MESSAGE"
    ;;
  subagentStop)
    MESSAGE="$IN_LAST_MESSAGE"
    if [[ -n "$IN_AGENT_TYPE" ]]; then
      TITLE="Claude Code ($IN_AGENT_TYPE)"
    fi
    ;;
  notification)
    MESSAGE="$IN_MESSAGE"
    ;;
esac

if [[ "$SHOW_MESSAGE" = "false" ]]; then
  MESSAGE=""
fi

# Fall back to config message if extraction failed
if [[ -z "$MESSAGE" ]]; then
  MESSAGE="$FALLBACK_MESSAGE"
fi

# Sanitize: replace newlines with spaces
MESSAGE="$(printf '%s' "$MESSAGE" | tr '\n\r' '  ')"

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
    # Build args so a config value of "none" omits the flag entirely — this is
    # how a user turns OFF the sound or click-to-focus app (N3). (The -n guard is
    # defensive; an empty/absent value falls back to the default above, not omission.)
    tn_args=( -title "$TITLE" -subtitle "$SUBTITLE" -message "$MESSAGE" )
    [[ -n "$SOUND"    && "$SOUND"    != "none" ]] && tn_args+=( -sound "$SOUND" )
    [[ -n "$ACTIVATE" && "$ACTIVATE" != "none" ]] && tn_args+=( -activate "$ACTIVATE" )
    # Async hooks may hand stdout back to Claude — keep the notifier silent.
    terminal-notifier "${tn_args[@]}" >/dev/null 2>&1
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
      "$MESSAGE" >/dev/null 2>&1
  fi
fi

# Always exit 0 — never block Claude
exit 0
