#!/usr/bin/env bash
set -euo pipefail

# FileChanged hook: detect configuration file changes.
# Appends change entries to .claude/forge-drift.json.
# Called when tsconfig, eslint, prettier, biome, or ruff configs change.

FILE_PATH="${1:-}"
DRIFT_FILE=".claude/forge-drift.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Ensure drift file exists
mkdir -p .claude
if [ ! -f "$DRIFT_FILE" ]; then
  printf '{"lastAuditedAt":null,"entries":[]}\n' > "$DRIFT_FILE"
fi

BASENAME=$(basename "$FILE_PATH")

# Only process known config files
case "$BASENAME" in
  tsconfig*.json|.eslintrc*|eslint.config*|prettier.config*|.prettierrc*|biome.json|ruff.toml|.ruff.toml|pyproject.toml)
    ;;
  *)
    exit 0
    ;;
esac

# Detect what type of config this is
CONFIG_TYPE="unknown"
case "$BASENAME" in
  tsconfig*) CONFIG_TYPE="typescript" ;;
  .eslintrc*|eslint.config*) CONFIG_TYPE="eslint" ;;
  prettier.config*|.prettierrc*) CONFIG_TYPE="prettier" ;;
  biome.json) CONFIG_TYPE="biome" ;;
  ruff.toml|.ruff.toml) CONFIG_TYPE="ruff" ;;
  pyproject.toml) CONFIG_TYPE="python-project" ;;
esac

# Append entry to drift file
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json
drift = json.load(open('$DRIFT_FILE'))
drift['entries'].append({
    'timestamp': '$TIMESTAMP',
    'file': '$BASENAME',
    'type': 'config',
    'changes': [{'action': 'modified', 'configType': '$CONFIG_TYPE', 'path': '$FILE_PATH'}]
})
with open('$DRIFT_FILE', 'w') as f:
    json.dump(drift, f, indent=2)
" 2>/dev/null || true
fi

exit 0
