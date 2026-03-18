#!/usr/bin/env bash
set -euo pipefail

# check-references.sh — Verify reference integrity across all plugins
# Usage: check-references.sh

ERRORS=0
WARNINGS=0
MARKETPLACE=".claude-plugin/marketplace.json"

echo "## Reference Integrity Check"
echo ""

if [ ! -f "$MARKETPLACE" ]; then
  echo "FAIL: $MARKETPLACE not found"
  exit 1
fi

PLUGIN_COUNT=$(jq '.plugins | length' "$MARKETPLACE")

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
  read -r PLUGIN_NAME PLUGIN_SOURCE < <(
    jq -r ".plugins[$i] | [.name, .source] | @tsv" "$MARKETPLACE"
  )
  PLUGIN_DIR="${PLUGIN_SOURCE#./}"
  PLUGIN_ISSUES=0

  echo "Checking references: $PLUGIN_NAME"

  if [ ! -d "$PLUGIN_DIR" ]; then
    continue
  fi

  # Check skill reference directories
  if [ -d "$PLUGIN_DIR/skills" ]; then
    while IFS= read -r -d '' ref_dir; do
      # Every .md file in references/ should be non-empty
      while IFS= read -r -d '' ref_file; do
        if [ ! -s "$ref_file" ]; then
          echo "  FAIL: Empty reference file: $ref_file"
          ERRORS=$((ERRORS + 1))
          PLUGIN_ISSUES=$((PLUGIN_ISSUES + 1))
        fi
      done < <(find "$ref_dir" -name "*.md" -type f -print0 2>/dev/null)
    done < <(find "$PLUGIN_DIR/skills" -name "references" -type d -print0 2>/dev/null)
  fi

  # Check script references in agents — only match path-like refs (containing /)
  if [ -d "$PLUGIN_DIR/agents" ]; then
    while IFS= read -r -d '' agent_file; do
      while IFS= read -r script_ref; do
        SCRIPT_PATH="$PLUGIN_DIR/$script_ref"
        if [ ! -f "$SCRIPT_PATH" ] && [ ! -f "$script_ref" ]; then
          echo "  WARN: Agent $agent_file references script '$script_ref' — not found"
          WARNINGS=$((WARNINGS + 1))
          PLUGIN_ISSUES=$((PLUGIN_ISSUES + 1))
        fi
      done < <(grep -oE 'scripts/[a-zA-Z0-9_/-]+\.sh' "$agent_file" 2>/dev/null || true)
    done < <(find "$PLUGIN_DIR/agents" -name "*.md" -type f -print0 2>/dev/null)
  fi

  # Check that scripts/ directory files are executable
  if [ -d "$PLUGIN_DIR/scripts" ]; then
    while IFS= read -r -d '' script_file; do
      if [ ! -x "$script_file" ]; then
        echo "  WARN: $script_file is not executable"
        WARNINGS=$((WARNINGS + 1))
        PLUGIN_ISSUES=$((PLUGIN_ISSUES + 1))
      fi
    done < <(find "$PLUGIN_DIR/scripts" -name "*.sh" -type f -print0 2>/dev/null)
  fi

  if [ "$PLUGIN_ISSUES" -eq 0 ]; then
    echo "  OK"
  fi
  echo ""
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS broken reference(s), $WARNINGS warning(s)"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "PASSED with $WARNINGS warning(s)"
  exit 0
else
  echo "All references verified successfully"
  exit 0
fi
