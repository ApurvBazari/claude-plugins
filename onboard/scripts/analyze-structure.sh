#!/usr/bin/env bash
# analyze-structure.sh — Project structure scanner
# Outputs a structured summary of the project's directory layout, key files, and organization patterns.
# Usage: bash analyze-structure.sh [project-root]

set -euo pipefail

# Structured warning for skipped/degraded operations
warn_skip() {
  local operation="$1"
  local reason="$2"
  echo "[WARN] Skipped: $operation — $reason" >&2
}

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "=== PROJECT STRUCTURE ANALYSIS ==="
echo "Root: $PROJECT_ROOT"
echo ""

# --- Top-level directory listing ---
echo "## Top-Level Contents"
ls -1F "$PROJECT_ROOT" | head -50
echo ""

# --- Directory tree (depth-limited) ---
echo "## Directory Tree (depth 3)"
if command -v tree &>/dev/null; then
  tree -d -L 3 --noreport -I 'node_modules|.git|__pycache__|.venv|venv|dist|build|.next|target|vendor|.tox|.mypy_cache|.pytest_cache|coverage|.nyc_output' "$PROJECT_ROOT" 2>/dev/null || true
else
  find "$PROJECT_ROOT" -maxdepth 3 -type d \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/venv/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/.next/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -not -name '.git' \
    -not -name 'node_modules' \
    2>/dev/null | sort | head -100
fi
echo ""

# --- Total directory count ---
echo "## Directory Count"
DIR_COUNT=$(find "$PROJECT_ROOT" -type d \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/venv/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  2>/dev/null | wc -l | tr -d ' ')
echo "Total directories (excluding generated): $DIR_COUNT"
echo ""

# --- Total file count ---
echo "## File Count"
FILE_COUNT=$(find "$PROJECT_ROOT" -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/venv/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  2>/dev/null | wc -l | tr -d ' ')
echo "Total files (excluding generated): $FILE_COUNT"
echo ""

# --- Key files detection ---
echo "## Key Files Detected"
KEY_FILES=(
  "package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "bun.lockb"
  "tsconfig.json" "jsconfig.json"
  "requirements.txt" "setup.py" "setup.cfg" "pyproject.toml" "Pipfile" "poetry.lock"
  "go.mod" "go.sum"
  "Cargo.toml" "Cargo.lock"
  "Gemfile" "Gemfile.lock"
  "pom.xml" "build.gradle" "build.gradle.kts"
  "Makefile" "CMakeLists.txt"
  "Dockerfile" "docker-compose.yml" "docker-compose.yaml"
  ".github/workflows" ".gitlab-ci.yml" ".circleci/config.yml" "Jenkinsfile" "bitbucket-pipelines.yml"
  ".eslintrc.js" ".eslintrc.json" ".eslintrc.yml" ".eslintrc.cjs" "eslint.config.js" "eslint.config.mjs"
  ".prettierrc" ".prettierrc.json" ".prettierrc.js" "prettier.config.js"
  "biome.json" "biome.jsonc"
  "jest.config.js" "jest.config.ts" "vitest.config.ts" "vitest.config.js"
  "pytest.ini" "conftest.py" "tox.ini" ".coveragerc"
  "webpack.config.js" "vite.config.ts" "vite.config.js" "rollup.config.js" "next.config.js" "next.config.mjs" "next.config.ts"
  "tailwind.config.js" "tailwind.config.ts" "postcss.config.js"
  "CLAUDE.md" ".claude/settings.json" ".claude/settings.local.json"
  "turbo.json" "nx.json" "lerna.json"
  ".env" ".env.example" ".env.local"
  ".nvmrc" ".node-version" ".python-version" ".tool-versions"
)

for f in "${KEY_FILES[@]}"; do
  if [ -e "$PROJECT_ROOT/$f" ]; then
    echo "  [found] $f"
  fi
done
echo ""

# --- Monorepo detection ---
echo "## Monorepo Detection"
MONOREPO="none"

if [ -f "$PROJECT_ROOT/package.json" ]; then
  if grep -q '"workspaces"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    MONOREPO="npm/yarn workspaces"
  fi
fi
if [ -f "$PROJECT_ROOT/pnpm-workspace.yaml" ]; then
  MONOREPO="pnpm workspaces"
fi
if [ -f "$PROJECT_ROOT/turbo.json" ]; then
  MONOREPO="turborepo${MONOREPO:+ + $MONOREPO}"
fi
if [ -f "$PROJECT_ROOT/nx.json" ]; then
  MONOREPO="nx${MONOREPO:+ + $MONOREPO}"
fi
if [ -f "$PROJECT_ROOT/lerna.json" ]; then
  MONOREPO="lerna${MONOREPO:+ + $MONOREPO}"
fi

echo "Monorepo type: $MONOREPO"
echo ""

# --- Largest directories by file count ---
echo "## Largest Directories (by file count, top 10)"
find "$PROJECT_ROOT" -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  2>/dev/null \
  | sed "s|$PROJECT_ROOT/||" \
  | awk -F/ '{if(NF>1) print $1"/"$2; else print $1}' \
  | sort | uniq -c | sort -rn | head -10
echo ""

# --- Entry points ---
echo "## Potential Entry Points"
ENTRY_PATTERNS=("src/index" "src/main" "src/app" "index" "main" "app" "server" "cmd/main" "lib/main")
EXTENSIONS=("ts" "tsx" "js" "jsx" "py" "go" "rs" "rb" "java" "kt")

for pattern in "${ENTRY_PATTERNS[@]}"; do
  for ext in "${EXTENSIONS[@]}"; do
    if [ -f "$PROJECT_ROOT/${pattern}.${ext}" ]; then
      echo "  [entry] ${pattern}.${ext}"
    fi
  done
done
echo ""

# --- Git info ---
echo "## Git Information"
if [ -d "$PROJECT_ROOT/.git" ]; then
  echo "Git repo: yes"
  BRANCH_COUNT=$(git -C "$PROJECT_ROOT" branch -a 2>/dev/null | wc -l | tr -d ' ')
  echo "Branch count: $BRANCH_COUNT"
  COMMIT_COUNT=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "unknown")
  echo "Commit count: $COMMIT_COUNT"
  CONTRIBUTOR_COUNT=$(git -C "$PROJECT_ROOT" shortlog -sn --all 2>/dev/null | wc -l | tr -d ' ')
  echo "Contributors: $CONTRIBUTOR_COUNT"
  LAST_COMMIT=$(git -C "$PROJECT_ROOT" log -1 --format="%cr" 2>/dev/null || echo "unknown")
  echo "Last commit: $LAST_COMMIT"
else
  echo "Git repo: no"
fi
echo ""

echo "=== END STRUCTURE ANALYSIS ==="
