#!/usr/bin/env bash
set -euo pipefail

# validate-manifests.sh — Verify plugin.json and marketplace.json integrity
# Usage: validate-manifests.sh

ERRORS=0
MARKETPLACE=".claude-plugin/marketplace.json"

echo "## Manifest Validation"
echo ""

# Check marketplace.json exists
if [ ! -f "$MARKETPLACE" ]; then
  echo "FAIL: $MARKETPLACE not found"
  exit 1
fi

# Validate marketplace.json is valid JSON
if ! jq empty "$MARKETPLACE" 2>/dev/null; then
  echo "FAIL: $MARKETPLACE is not valid JSON"
  exit 1
fi

echo "Checking marketplace.json..."

# Get plugin list from marketplace
PLUGIN_COUNT=$(jq '.plugins | length' "$MARKETPLACE")
echo "  Found $PLUGIN_COUNT plugins in marketplace"
echo ""

# Validate each plugin
for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
  # Extract marketplace fields in a single jq call
  read -r PLUGIN_NAME PLUGIN_SOURCE MARKETPLACE_VERSION < <(
    jq -r ".plugins[$i] | [.name, .source, .version] | @tsv" "$MARKETPLACE"
  )
  PLUGIN_DIR="${PLUGIN_SOURCE#./}"
  PLUGIN_ERRORS=0

  echo "Checking plugin: $PLUGIN_NAME ($PLUGIN_DIR)"

  # Check plugin directory exists
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "  FAIL: Plugin directory '$PLUGIN_DIR' not found"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check plugin.json exists
  MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
  if [ ! -f "$MANIFEST" ]; then
    echo "  FAIL: $MANIFEST not found"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Validate plugin.json is valid JSON
  if ! jq empty "$MANIFEST" 2>/dev/null; then
    echo "  FAIL: $MANIFEST is not valid JSON"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check all required fields in a single jq call
  MISSING_FIELDS=$(jq -r '[
    (if .name then empty else "name" end),
    (if .version then empty else "version" end),
    (if .description then empty else "description" end),
    (if .license then empty else "license" end),
    (if .author.name then empty else "author.name" end),
    (if (.keywords | length) > 0 then empty else "keywords" end)
  ] | .[]' "$MANIFEST" 2>/dev/null)

  if [ -n "$MISSING_FIELDS" ]; then
    while IFS= read -r field; do
      echo "  FAIL: Missing required field '$field' in $MANIFEST"
      PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
    done <<< "$MISSING_FIELDS"
  fi

  # Check name matches directory
  MANIFEST_NAME=$(jq -r '.name' "$MANIFEST")
  DIR_NAME=$(basename "$PLUGIN_DIR")
  if [ "$MANIFEST_NAME" != "$DIR_NAME" ]; then
    echo "  FAIL: Manifest name '$MANIFEST_NAME' does not match directory name '$DIR_NAME'"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi

  # Check version sync with marketplace
  MANIFEST_VERSION=$(jq -r '.version' "$MANIFEST")
  if [ "$MANIFEST_VERSION" != "$MARKETPLACE_VERSION" ]; then
    echo "  FAIL: Version mismatch — plugin.json=$MANIFEST_VERSION, marketplace.json=$MARKETPLACE_VERSION"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi

  # Check marketplace entry has required fields in a single jq call
  MISSING_MARKETPLACE=$(jq -r ".plugins[$i] | [
    (if .description then empty else \"description\" end),
    (if (.keywords | length) > 0 then empty else \"keywords\" end),
    (if .license then empty else \"license\" end)
  ] | .[]" "$MARKETPLACE" 2>/dev/null)

  if [ -n "$MISSING_MARKETPLACE" ]; then
    while IFS= read -r field; do
      echo "  FAIL: Missing '$field' in marketplace.json entry for $PLUGIN_NAME"
      PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
    done <<< "$MISSING_MARKETPLACE"
  fi

  ERRORS=$((ERRORS + PLUGIN_ERRORS))
  if [ "$PLUGIN_ERRORS" -eq 0 ]; then
    echo "  PASS"
  fi
  echo ""
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS error(s) found"
  exit 1
else
  echo "All manifests validated successfully"
  exit 0
fi
