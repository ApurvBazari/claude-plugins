#!/usr/bin/env bash
set -euo pipefail

# FileChanged hook: detect dependency changes in package manifests.
# Appends change entries to .claude/forge-drift.json.
# Called when package.json, pyproject.toml, Cargo.toml, go.mod, or Gemfile changes.

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

# Detect changes based on file type
CHANGES=""
BASENAME=$(basename "$FILE_PATH")

case "$BASENAME" in
  package.json)
    # Compare current deps against what's in forge-meta.json (if available)
    if command -v python3 >/dev/null 2>&1 && [ -f "$FILE_PATH" ]; then
      CHANGES=$(python3 -c "
import json, sys
try:
    pkg = json.load(open('$FILE_PATH'))
    deps = list(pkg.get('dependencies', {}).keys())
    dev_deps = list(pkg.get('devDependencies', {}).keys())
    scripts = list(pkg.get('scripts', {}).keys())
    changes = []
    for d in deps + dev_deps:
        changes.append({'action': 'present', 'name': d, 'type': 'dependency'})
    for s in scripts:
        changes.append({'action': 'present', 'name': s, 'type': 'script'})
    print(json.dumps(changes))
except Exception:
    print('[]')
" 2>/dev/null || echo "[]")
    fi
    ;;
  pyproject.toml)
    CHANGES='[{"action": "modified", "name": "pyproject.toml", "type": "dependency"}]'
    ;;
  Cargo.toml)
    CHANGES='[{"action": "modified", "name": "Cargo.toml", "type": "dependency"}]'
    ;;
  go.mod)
    CHANGES='[{"action": "modified", "name": "go.mod", "type": "dependency"}]'
    ;;
  Gemfile)
    CHANGES='[{"action": "modified", "name": "Gemfile", "type": "dependency"}]'
    ;;
  *)
    exit 0
    ;;
esac

if [ -z "$CHANGES" ] || [ "$CHANGES" = "[]" ]; then
  exit 0
fi

# Append entry to drift file
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json
drift = json.load(open('$DRIFT_FILE'))
drift['entries'].append({
    'timestamp': '$TIMESTAMP',
    'file': '$BASENAME',
    'type': 'dependency',
    'changes': $CHANGES
})
with open('$DRIFT_FILE', 'w') as f:
    json.dump(drift, f, indent=2)
" 2>/dev/null || true
fi

exit 0
