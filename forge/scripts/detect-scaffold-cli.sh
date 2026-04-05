#!/usr/bin/env bash
set -euo pipefail

# Detect available scaffold CLIs on the system.
# Outputs a JSON-like list of available tools.

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "  $1: available ($("$1" --version 2>/dev/null | head -1 || echo 'version unknown'))"
  fi
}

echo "## Available Scaffold CLIs"
echo ""

echo "### Package Managers"
check_cmd npm
check_cmd pnpm
check_cmd yarn
check_cmd bun
check_cmd pip
check_cmd pip3
check_cmd poetry
check_cmd uv
check_cmd cargo
check_cmd go
check_cmd gem
check_cmd bundle

echo ""
echo "### Runtimes"
check_cmd node
check_cmd python3
check_cmd python
check_cmd go
check_cmd rustc
check_cmd ruby

echo ""
echo "### Scaffold Tools"
check_cmd npx
check_cmd pnpx
check_cmd django-admin
check_cmd rails
check_cmd gh

echo ""
echo "### Container Tools"
check_cmd docker
check_cmd docker-compose

echo ""
echo "### Version Control"
check_cmd git
