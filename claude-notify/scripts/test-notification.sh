#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOME/.claude/notify-config.json"

# Check terminal-notifier
if ! command -v terminal-notifier &>/dev/null; then
  echo "ERROR: terminal-notifier is not installed. Run the setup command first."
  exit 1
fi

# Check notify.sh
NOTIFY_SCRIPT="$HOME/.claude/hooks/notify.sh"
if [ ! -x "$NOTIFY_SCRIPT" ]; then
  echo "ERROR: $NOTIFY_SCRIPT not found or not executable."
  exit 1
fi

echo "Sending test notification..."
"$NOTIFY_SCRIPT" "Claude Code" "Test notification — setup is working!" "Glass" "com.microsoft.VSCode"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "Test notification sent successfully. You should see it on your screen."
else
  echo "ERROR: Notification failed with exit code $EXIT_CODE."
  exit 1
fi
