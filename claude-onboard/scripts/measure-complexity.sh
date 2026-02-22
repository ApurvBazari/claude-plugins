#!/usr/bin/env bash
# measure-complexity.sh — Project complexity scorer
# Computes a complexity profile based on LOC, file count, directory depth, language diversity, etc.
# Usage: bash measure-complexity.sh [project-root]

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "=== PROJECT COMPLEXITY ANALYSIS ==="
echo "Root: $PROJECT_ROOT"
echo ""

# Exclusion pattern for find
EXCLUDE="-not -path */node_modules/* -not -path */.git/* -not -path */__pycache__/* -not -path */.venv/* -not -path */venv/* -not -path */dist/* -not -path */build/* -not -path */target/* -not -path */vendor/* -not -path */.next/*"

# --- File counts ---
echo "## File Metrics"

TOTAL_FILES=$(find "$PROJECT_ROOT" -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/venv/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  -not -path '*/.next/*' \
  2>/dev/null | wc -l | tr -d ' ')
echo "Total files: $TOTAL_FILES"

SOURCE_EXTENSIONS="ts tsx js jsx py go rs rb java kt cs cpp c php dart ex exs scala clj swift lua zig"
SOURCE_FILES=0
for ext in $SOURCE_EXTENSIONS; do
  COUNT=$(find "$PROJECT_ROOT" -name "*.${ext}" \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/venv/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -not -path '*/.next/*' \
    2>/dev/null | wc -l | tr -d ' ')
  SOURCE_FILES=$((SOURCE_FILES + COUNT))
done
echo "Source files: $SOURCE_FILES"

CONFIG_FILES=$(find "$PROJECT_ROOT" -maxdepth 2 \( \
  -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" \
  -o -name "*.ini" -o -name "*.cfg" -o -name "*.conf" \
  -o -name ".*rc" -o -name ".*.json" -o -name ".*.js" \
  \) -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
echo "Config files (top 2 levels): $CONFIG_FILES"
echo ""

# --- Lines of Code ---
echo "## Lines of Code"

TOTAL_LOC=0
for ext in $SOURCE_EXTENSIONS; do
  LOC=$(find "$PROJECT_ROOT" -name "*.${ext}" \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/venv/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -not -path '*/.next/*' \
    2>/dev/null -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
  if [ "$LOC" -gt 0 ]; then
    TOTAL_LOC=$((TOTAL_LOC + LOC))
  fi
done
echo "Total source LOC: $TOTAL_LOC"
echo ""

# --- Directory depth ---
echo "## Directory Depth"
MAX_DEPTH=$(find "$PROJECT_ROOT" -type d \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  2>/dev/null | awk -F/ '{print NF}' | sort -n | tail -1)
ROOT_DEPTH=$(echo "$PROJECT_ROOT" | awk -F/ '{print NF}')
RELATIVE_DEPTH=$((MAX_DEPTH - ROOT_DEPTH))
echo "Max directory depth: $RELATIVE_DEPTH"
echo ""

# --- Language diversity ---
echo "## Language Diversity"
LANG_COUNT=0
for ext in $SOURCE_EXTENSIONS; do
  COUNT=$(find "$PROJECT_ROOT" -name "*.${ext}" \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    LANG_COUNT=$((LANG_COUNT + 1))
  fi
done
echo "Language extensions with files: $LANG_COUNT"
echo ""

# --- Dependency count ---
echo "## Dependency Count"
DEP_COUNT=0

if [ -f "$PROJECT_ROOT/package.json" ]; then
  NPM_DEPS=$(python3 -c "
import json
try:
    with open('$PROJECT_ROOT/package.json') as f:
        pkg = json.load(f)
    deps = len(pkg.get('dependencies', {}))
    devdeps = len(pkg.get('devDependencies', {}))
    print(f'{deps + devdeps}')
except: print('0')
" 2>/dev/null || echo "0")
  echo "npm dependencies: $NPM_DEPS"
  DEP_COUNT=$((DEP_COUNT + NPM_DEPS))
fi

if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
  PY_DEPS=$(grep -c -v '^\s*#\|^\s*$' "$PROJECT_ROOT/requirements.txt" 2>/dev/null || echo "0")
  echo "Python dependencies (requirements.txt): $PY_DEPS"
  DEP_COUNT=$((DEP_COUNT + PY_DEPS))
fi

if [ -f "$PROJECT_ROOT/go.mod" ]; then
  GO_DEPS=$(grep -c '^\t' "$PROJECT_ROOT/go.mod" 2>/dev/null || echo "0")
  echo "Go dependencies: $GO_DEPS"
  DEP_COUNT=$((DEP_COUNT + GO_DEPS))
fi

echo "Total dependencies: $DEP_COUNT"
echo ""

# --- Compute complexity score ---
echo "## Complexity Score"

# File count score (0-25)
if [ "$SOURCE_FILES" -lt 50 ]; then
  FILE_SCORE=5
elif [ "$SOURCE_FILES" -lt 200 ]; then
  FILE_SCORE=10
elif [ "$SOURCE_FILES" -lt 500 ]; then
  FILE_SCORE=15
elif [ "$SOURCE_FILES" -lt 2000 ]; then
  FILE_SCORE=20
else
  FILE_SCORE=25
fi

# LOC score (0-25)
if [ "$TOTAL_LOC" -lt 5000 ]; then
  LOC_SCORE=5
elif [ "$TOTAL_LOC" -lt 20000 ]; then
  LOC_SCORE=10
elif [ "$TOTAL_LOC" -lt 50000 ]; then
  LOC_SCORE=15
elif [ "$TOTAL_LOC" -lt 200000 ]; then
  LOC_SCORE=20
else
  LOC_SCORE=25
fi

# Language diversity score (0-25)
if [ "$LANG_COUNT" -le 2 ]; then
  LANG_SCORE=5
elif [ "$LANG_COUNT" -le 4 ]; then
  LANG_SCORE=10
elif [ "$LANG_COUNT" -le 6 ]; then
  LANG_SCORE=15
elif [ "$LANG_COUNT" -le 8 ]; then
  LANG_SCORE=20
else
  LANG_SCORE=25
fi

# Depth score (0-25)
if [ "$RELATIVE_DEPTH" -le 3 ]; then
  DEPTH_SCORE=5
elif [ "$RELATIVE_DEPTH" -le 5 ]; then
  DEPTH_SCORE=10
elif [ "$RELATIVE_DEPTH" -le 8 ]; then
  DEPTH_SCORE=15
elif [ "$RELATIVE_DEPTH" -le 12 ]; then
  DEPTH_SCORE=20
else
  DEPTH_SCORE=25
fi

TOTAL_SCORE=$((FILE_SCORE + LOC_SCORE + LANG_SCORE + DEPTH_SCORE))

echo "File count score: $FILE_SCORE / 25"
echo "LOC score: $LOC_SCORE / 25"
echo "Language diversity score: $LANG_SCORE / 25"
echo "Directory depth score: $DEPTH_SCORE / 25"
echo "---"
echo "Total complexity score: $TOTAL_SCORE / 100"
echo ""

# Classification
if [ "$TOTAL_SCORE" -le 30 ]; then
  CATEGORY="small"
elif [ "$TOTAL_SCORE" -le 50 ]; then
  CATEGORY="medium"
elif [ "$TOTAL_SCORE" -le 70 ]; then
  CATEGORY="large"
else
  CATEGORY="enterprise"
fi
echo "Category: $CATEGORY"
echo ""

# --- Summary ---
echo "## Summary"
echo "Files: $SOURCE_FILES source files, $TOTAL_FILES total"
echo "LOC: $TOTAL_LOC"
echo "Languages: $LANG_COUNT"
echo "Max depth: $RELATIVE_DEPTH"
echo "Dependencies: $DEP_COUNT"
echo "Complexity: $CATEGORY ($TOTAL_SCORE/100)"
echo ""

echo "=== END COMPLEXITY ANALYSIS ==="
