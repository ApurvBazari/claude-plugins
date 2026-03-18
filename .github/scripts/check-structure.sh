#!/usr/bin/env bash
set -euo pipefail

# check-structure.sh — Verify plugin directory structure
# Usage: check-structure.sh

ERRORS=0
WARNINGS=0
MARKETPLACE=".claude-plugin/marketplace.json"

echo "## Plugin Structure Validation"
echo ""

if [ ! -f "$MARKETPLACE" ]; then
  echo "FAIL: $MARKETPLACE not found"
  exit 1
fi

# Get plugin list from marketplace
PLUGIN_COUNT=$(jq '.plugins | length' "$MARKETPLACE")

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
  PLUGIN_NAME=$(jq -r ".plugins[$i].name" "$MARKETPLACE")
  PLUGIN_SOURCE=$(jq -r ".plugins[$i].source" "$MARKETPLACE")
  PLUGIN_DIR="${PLUGIN_SOURCE#./}"

  PLUGIN_ERRORS=0
  echo "Checking structure: $PLUGIN_NAME ($PLUGIN_DIR)"

  # Check plugin directory exists
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "  FAIL: Directory not found"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check .claude-plugin/plugin.json
  if [ ! -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
    echo "  FAIL: Missing .claude-plugin/plugin.json"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi

  # Check README.md
  if [ ! -f "$PLUGIN_DIR/README.md" ]; then
    echo "  FAIL: Missing README.md"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi

  # Check at least one component directory
  HAS_COMPONENT=false
  for DIR in skills commands agents; do
    if [ -d "$PLUGIN_DIR/$DIR" ]; then
      HAS_COMPONENT=true
      break
    fi
  done
  if [ "$HAS_COMPONENT" = false ]; then
    echo "  FAIL: No skills/, commands/, or agents/ directory found"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi

  # Check SKILL.md files have proper H1 title
  if [ -d "$PLUGIN_DIR/skills" ]; then
    while IFS= read -r -d '' skill_file; do
      FIRST_H1=$(grep -m1 '^# ' "$skill_file" 2>/dev/null || true)
      if [ -z "$FIRST_H1" ]; then
        echo "  WARN: $skill_file has no H1 title"
        WARNINGS=$((WARNINGS + 1))
      elif ! echo "$FIRST_H1" | grep -q '^# /'; then
        echo "  WARN: $skill_file H1 should start with '/' — found: $FIRST_H1"
        WARNINGS=$((WARNINGS + 1))
      fi
    done < <(find "$PLUGIN_DIR/skills" -name "SKILL.md" -type f -print0 2>/dev/null)
  fi

  # Check command files have proper H1 title
  if [ -d "$PLUGIN_DIR/commands" ]; then
    while IFS= read -r -d '' cmd_file; do
      FIRST_H1=$(grep -m1 '^# ' "$cmd_file" 2>/dev/null || true)
      if [ -z "$FIRST_H1" ]; then
        echo "  WARN: $cmd_file has no H1 title"
        WARNINGS=$((WARNINGS + 1))
      elif ! echo "$FIRST_H1" | grep -q '^# /'; then
        echo "  WARN: $cmd_file H1 should start with '/' — found: $FIRST_H1"
        WARNINGS=$((WARNINGS + 1))
      fi
    done < <(find "$PLUGIN_DIR/commands" -name "*.md" -type f -print0 2>/dev/null)
  fi

  ERRORS=$((ERRORS + PLUGIN_ERRORS))
  if [ "$PLUGIN_ERRORS" -eq 0 ]; then
    echo "  PASS (structure OK)"
  fi
  echo ""
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "PASSED with $WARNINGS warning(s)"
  exit 0
else
  echo "All plugin structures validated successfully"
  exit 0
fi
