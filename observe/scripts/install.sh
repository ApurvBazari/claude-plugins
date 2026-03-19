#!/usr/bin/env bash
set -euo pipefail

# install.sh — Post-install validation for the observe plugin
# Usage: bash install.sh

echo "Validating observe plugin installation..."

# Check python3 availability
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found."
  echo "Install Python 3.7+ from https://python.org or via your package manager."
  exit 1
fi

# Check python3 version >= 3.7
PY_VERSION="$(python3 -c 'import sys; v=sys.version_info; print(str(v.major)+"."+str(v.minor))')"
PY_MAJOR="$(echo "$PY_VERSION" | cut -d. -f1)"
PY_MINOR="$(echo "$PY_VERSION" | cut -d. -f2)"
if [[ "$PY_MAJOR" -lt 3 ]] || { [[ "$PY_MAJOR" -eq 3 ]] && [[ "$PY_MINOR" -lt 7 ]]; }; then
  echo "ERROR: Python 3.7+ required, found $PY_VERSION"
  exit 1
fi

# Check/create data directory
DATA_DIR="$HOME/.claude/observability/data"
if ! mkdir -p "$DATA_DIR" 2>/dev/null; then
  echo "ERROR: Cannot create data directory at $DATA_DIR"
  exit 1
fi

# Verify writability
TEST_FILE="$DATA_DIR/.write-test"
if ! touch "$TEST_FILE" 2>/dev/null; then
  echo "ERROR: Data directory $DATA_DIR is not writable"
  exit 1
fi
rm -f "$TEST_FILE"

echo "observe plugin validated successfully."
echo "  Python: $PY_VERSION"
echo "  Data directory: $DATA_DIR"
echo ""
echo "Hooks will start collecting data on your next Claude Code session."
