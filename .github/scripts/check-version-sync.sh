#!/usr/bin/env bash
# check-version-sync.sh — verify each plugin's version in its plugin.json
# matches its version in the marketplace.json entry.
#
# Drift between these two sources of truth is invisible at install time —
# `claude plugin install` uses the marketplace.json version, while the plugin
# itself reports its plugin.json version. Keeping them in lock-step avoids
# silent version skew during the release cycle.
#
# Run in two contexts:
#   1. validate.yml — on every PR, catches hand-edit drift early
#   2. release-please.yml — after the sync-marketplace job, confirms the
#      automated sync actually produced a consistent manifest before commit

set -euo pipefail

marketplace_file=".claude-plugin/marketplace.json"

if [[ ! -f "$marketplace_file" ]]; then
  echo "::error::$marketplace_file not found" >&2
  exit 1
fi

failed=0
plugins=$(jq -r '.plugins[].name' "$marketplace_file")

for plugin in $plugins; do
  plugin_manifest="${plugin}/.claude-plugin/plugin.json"

  if [[ ! -f "$plugin_manifest" ]]; then
    echo "::error::Marketplace lists plugin '$plugin' but $plugin_manifest does not exist" >&2
    failed=1
    continue
  fi

  plugin_ver=$(jq -r '.version' "$plugin_manifest")
  marketplace_ver=$(jq -r --arg name "$plugin" \
    '.plugins[] | select(.name == $name) | .version' \
    "$marketplace_file")

  if [[ "$plugin_ver" != "$marketplace_ver" ]]; then
    echo "::error::Version mismatch for $plugin: plugin.json=$plugin_ver marketplace.json=$marketplace_ver" >&2
    failed=1
  fi
done

if [[ "$failed" -eq 1 ]]; then
  echo "" >&2
  echo "Version drift detected. Each plugin's plugin.json version must match its marketplace.json entry." >&2
  exit 1
fi

echo "All plugin versions are in sync between plugin.json and marketplace.json"
