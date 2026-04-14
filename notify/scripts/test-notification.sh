#!/usr/bin/env bash
set -euo pipefail

# Accept optional base directory as first argument (default: ~/.claude).
# Validate: must be an existing directory, must resolve (via realpath) to a
# path under $HOME so a caller can't point us at /etc, /tmp, or a symlinked
# location that executes a malicious notify.sh.
BASE_DIR_RAW="${1:-$HOME/.claude}"

if [[ ! -d "$BASE_DIR_RAW" ]]; then
  echo "ERROR: base directory '$BASE_DIR_RAW' does not exist."
  exit 1
fi

if command -v realpath >/dev/null 2>&1; then
  BASE_DIR="$(realpath "$BASE_DIR_RAW")"
elif command -v python3 >/dev/null 2>&1; then
  BASE_DIR="$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$BASE_DIR_RAW")"
else
  BASE_DIR="$BASE_DIR_RAW"
fi

HOME_RESOLVED="$(realpath "$HOME" 2>/dev/null || echo "$HOME")"
case "$BASE_DIR" in
  "$HOME_RESOLVED"|"$HOME_RESOLVED"/*) ;;
  *)
    echo "ERROR: base directory '$BASE_DIR' resolves outside \$HOME; refusing."
    exit 1
    ;;
esac

NOTIFY_SCRIPT="$BASE_DIR/hooks/notify.sh"

# Refuse symlinks at the script path — if someone placed a symlink pointing
# elsewhere, we should not blindly execute whatever it targets.
if [[ -L "$NOTIFY_SCRIPT" ]]; then
  echo "ERROR: $NOTIFY_SCRIPT is a symlink; refusing to execute."
  exit 1
fi

# Detect platform and check for notification backend
PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin)
    if ! command -v terminal-notifier &>/dev/null; then
      echo "ERROR: terminal-notifier is not installed. Run the setup command first."
      exit 1
    fi
    ;;
  Linux)
    if ! command -v notify-send &>/dev/null; then
      echo "ERROR: notify-send is not installed. Install libnotify (e.g., apt install libnotify-bin)."
      exit 1
    fi
    ;;
  *)
    echo "ERROR: Unsupported platform: $PLATFORM"
    exit 1
    ;;
esac

# Check notify.sh
if [[ ! -x "$NOTIFY_SCRIPT" ]]; then
  echo "ERROR: $NOTIFY_SCRIPT not found or not executable."
  exit 1
fi

echo "Sending test notification (base: $BASE_DIR)..."
echo '{"last_assistant_message":"Test notification — setup is working!"}' | "$NOTIFY_SCRIPT" stop

EXIT_CODE=$?
if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo "Test notification sent successfully. You should see it on your screen."
else
  echo "ERROR: Notification failed with exit code $EXIT_CODE."
  exit 1
fi
