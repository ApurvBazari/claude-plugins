#!/usr/bin/env bash
set -euo pipefail

# FileChanged hook: detect structural changes (new directories with source files).
# Appends change entries to .claude/forge-drift.json.
# Called on any file change — checks if the file's directory is a new, uncovered directory.

FILE_PATH="${1:-}"
DRIFT_FILE=".claude/forge-drift.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only track source files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.rb|*.java|*.kt|*.swift|*.c|*.cpp|*.h)
    ;;
  *)
    exit 0
    ;;
esac

# Get the directory of the changed file
FILE_DIR=$(dirname "$FILE_PATH")

# Skip common non-architectural directories
case "$FILE_DIR" in
  node_modules*|.git*|dist*|build*|.next*|__pycache__*|target*|vendor*)
    exit 0
    ;;
esac

# Check if this directory already has a CLAUDE.md (already covered)
if [ -f "$FILE_DIR/CLAUDE.md" ]; then
  exit 0
fi

# Count source files in this directory
SOURCE_COUNT=$(find "$FILE_DIR" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" \) 2>/dev/null | wc -l | tr -d ' ')

# Only flag directories with a meaningful number of source files
if [ "$SOURCE_COUNT" -lt 5 ]; then
  exit 0
fi

# Ensure drift file exists
mkdir -p .claude
if [ ! -f "$DRIFT_FILE" ]; then
  printf '{"lastAuditedAt":null,"entries":[]}\n' > "$DRIFT_FILE"
fi

# Check if we already logged this directory in a recent entry (avoid duplicates)
if command -v python3 >/dev/null 2>&1; then
  ALREADY_LOGGED=$(python3 -c "
import json, sys
drift_file, file_dir = sys.argv[1], sys.argv[2]
drift = json.load(open(drift_file))
for entry in drift.get('entries', []):
    if entry.get('type') == 'structure':
        for change in entry.get('changes', []):
            if change.get('path') == file_dir:
                print('true')
                exit()
print('false')
" "$DRIFT_FILE" "$FILE_DIR" 2>/dev/null || echo "false")

  if [ "$ALREADY_LOGGED" = "true" ]; then
    exit 0
  fi

  # Append entry to drift file
  python3 -c "
import json, sys
drift_file, file_dir, timestamp, source_count = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
drift = json.load(open(drift_file))
drift['entries'].append({
    'timestamp': timestamp,
    'file': file_dir + '/',
    'type': 'structure',
    'changes': [{'action': 'new-directory', 'path': file_dir, 'fileCount': source_count}]
})
with open(drift_file, 'w') as f:
    json.dump(drift, f, indent=2)
" "$DRIFT_FILE" "$FILE_DIR" "$TIMESTAMP" "$SOURCE_COUNT" 2>/dev/null || true
fi

exit 0
