#!/usr/bin/env bash
set -euo pipefail

# Detect platform
PLATFORM="unknown"
case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
esac

echo "Detected platform: $PLATFORM"

# --- macOS: terminal-notifier ---
if [[ "$PLATFORM" = "macos" ]]; then
  if command -v terminal-notifier &>/dev/null; then
    echo "terminal-notifier is already installed at $(command -v terminal-notifier)"
    terminal-notifier -help &>/dev/null && echo "Verified: terminal-notifier is working." || echo "Warning: terminal-notifier found but may not be functional."
    exit 0
  fi

  if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew is not installed."
    echo ""
    echo "Install Homebrew first:"
    # shellcheck disable=SC2016  # intentional: literal copy-paste instruction for user
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    echo "Then re-run this script."
    exit 1
  fi

  echo "Installing terminal-notifier via Homebrew..."
  brew install terminal-notifier

  if command -v terminal-notifier &>/dev/null; then
    echo "terminal-notifier installed successfully."
  else
    echo "ERROR: Installation failed. Please install manually: brew install terminal-notifier"
    exit 1
  fi

# --- Linux: notify-send (libnotify) ---
elif [[ "$PLATFORM" = "linux" ]]; then
  if command -v notify-send &>/dev/null; then
    echo "notify-send is already available at $(command -v notify-send)"
    echo "Verified: notify-send is ready."
    exit 0
  fi

  echo "notify-send is not installed."
  echo ""
  echo "Install libnotify for your distribution:"
  echo "  Ubuntu/Debian:  sudo apt install libnotify-bin"
  echo "  Fedora/RHEL:    sudo dnf install libnotify"
  echo "  Arch Linux:     sudo pacman -S libnotify"
  echo ""
  echo "Note: notify-send requires a desktop environment or notification daemon."
  echo "It may not work in headless/SSH sessions."
  exit 1

else
  echo "Unsupported platform: $(uname -s)"
  echo "Notify plugin currently supports macOS and Linux."
  exit 1
fi
