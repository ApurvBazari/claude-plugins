#!/bin/bash
set -e

# Check if terminal-notifier is already installed
if command -v terminal-notifier &>/dev/null; then
  echo "terminal-notifier is already installed at $(which terminal-notifier)"
  terminal-notifier -help &>/dev/null && echo "Verified: terminal-notifier is working." || echo "Warning: terminal-notifier found but may not be functional."
  exit 0
fi

# Check if Homebrew is available
if ! command -v brew &>/dev/null; then
  echo "ERROR: Homebrew is not installed."
  echo ""
  echo "Install Homebrew first:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo ""
  echo "Then re-run this script."
  exit 1
fi

echo "Installing terminal-notifier via Homebrew..."
brew install terminal-notifier

# Verify
if command -v terminal-notifier &>/dev/null; then
  echo "terminal-notifier installed successfully."
else
  echo "ERROR: Installation failed. Please install manually: brew install terminal-notifier"
  exit 1
fi
