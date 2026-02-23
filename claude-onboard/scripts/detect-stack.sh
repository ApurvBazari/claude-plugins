#!/usr/bin/env bash
# detect-stack.sh — Tech stack detection
# Detects languages, frameworks, libraries, build tools, testing tools, and CI/CD pipelines.
# Usage: bash detect-stack.sh [project-root]

set -euo pipefail

# Check Python 3 availability
PYTHON3_AVAILABLE=false
if command -v python3 &>/dev/null; then
  PYTHON3_AVAILABLE=true
fi

# Structured warning for skipped/degraded operations
warn_skip() {
  local operation="$1"
  local reason="$2"
  echo "[WARN] Skipped: $operation — $reason" >&2
}

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "=== TECH STACK DETECTION ==="
echo "Root: $PROJECT_ROOT"
echo ""

# --- Language detection by file extension ---
echo "## Languages Detected"

detect_lang() {
  local ext="$1"
  local label="$2"
  local COUNT
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
    2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    local LOC
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
      2>/dev/null -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    echo "  ${label}: $COUNT files, ~$LOC lines"
  fi
}

detect_lang "ts" "TypeScript"
detect_lang "tsx" "TypeScript (JSX)"
detect_lang "js" "JavaScript"
detect_lang "jsx" "JavaScript (JSX)"
detect_lang "py" "Python"
detect_lang "go" "Go"
detect_lang "rs" "Rust"
detect_lang "rb" "Ruby"
detect_lang "java" "Java"
detect_lang "kt" "Kotlin"
detect_lang "swift" "Swift"
detect_lang "cs" "C#"
detect_lang "cpp" "C++"
detect_lang "c" "C"
detect_lang "php" "PHP"
detect_lang "dart" "Dart"
detect_lang "ex" "Elixir"
detect_lang "exs" "Elixir"
detect_lang "scala" "Scala"
detect_lang "clj" "Clojure"
detect_lang "lua" "Lua"
detect_lang "zig" "Zig"
echo ""

# --- Framework detection ---
echo "## Frameworks & Libraries"

# Node.js / JavaScript / TypeScript frameworks
if [ -f "$PROJECT_ROOT/package.json" ]; then
  PKG="$PROJECT_ROOT/package.json"

  detect_pkg() {
    local name="$1"
    local label="$2"
    if grep -q "\"$name\"" "$PKG" 2>/dev/null; then
      VERSION=$(grep -o "\"$name\": *\"[^\"]*\"" "$PKG" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//')
      echo "  [npm] $label: $VERSION"
    fi
  }

  # Frontend frameworks
  detect_pkg "react" "React"
  detect_pkg "next" "Next.js"
  detect_pkg "vue" "Vue.js"
  detect_pkg "nuxt" "Nuxt"
  detect_pkg "@angular/core" "Angular"
  detect_pkg "svelte" "Svelte"
  detect_pkg "@sveltejs/kit" "SvelteKit"
  detect_pkg "astro" "Astro"
  detect_pkg "solid-js" "SolidJS"
  detect_pkg "remix" "Remix"
  detect_pkg "@remix-run/react" "Remix"
  detect_pkg "gatsby" "Gatsby"

  # Backend frameworks
  detect_pkg "express" "Express"
  detect_pkg "fastify" "Fastify"
  detect_pkg "@nestjs/core" "NestJS"
  detect_pkg "hono" "Hono"
  detect_pkg "koa" "Koa"

  # Styling
  detect_pkg "tailwindcss" "Tailwind CSS"
  detect_pkg "styled-components" "styled-components"
  detect_pkg "@emotion/react" "Emotion"
  detect_pkg "sass" "Sass"

  # State management
  detect_pkg "redux" "Redux"
  detect_pkg "@reduxjs/toolkit" "Redux Toolkit"
  detect_pkg "zustand" "Zustand"
  detect_pkg "jotai" "Jotai"
  detect_pkg "recoil" "Recoil"
  detect_pkg "mobx" "MobX"
  detect_pkg "@tanstack/react-query" "TanStack Query"

  # ORM / Database
  detect_pkg "prisma" "Prisma"
  detect_pkg "@prisma/client" "Prisma Client"
  detect_pkg "drizzle-orm" "Drizzle ORM"
  detect_pkg "typeorm" "TypeORM"
  detect_pkg "sequelize" "Sequelize"
  detect_pkg "mongoose" "Mongoose"
  detect_pkg "knex" "Knex.js"

  # Build tools
  detect_pkg "vite" "Vite"
  detect_pkg "webpack" "Webpack"
  detect_pkg "esbuild" "esbuild"
  detect_pkg "rollup" "Rollup"
  detect_pkg "turbo" "Turborepo"
  detect_pkg "tsup" "tsup"

  # Testing
  detect_pkg "jest" "Jest"
  detect_pkg "vitest" "Vitest"
  detect_pkg "@testing-library/react" "React Testing Library"
  detect_pkg "cypress" "Cypress"
  detect_pkg "playwright" "Playwright"
  detect_pkg "@playwright/test" "Playwright Test"
  detect_pkg "mocha" "Mocha"

  # Linting & formatting
  detect_pkg "eslint" "ESLint"
  detect_pkg "prettier" "Prettier"
  detect_pkg "biome" "Biome"
  detect_pkg "@biomejs/biome" "Biome"

  # Monorepo
  detect_pkg "lerna" "Lerna"
  detect_pkg "nx" "Nx"
fi

# Python frameworks
if [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ] || [ -f "$PROJECT_ROOT/Pipfile" ]; then
  echo ""
  echo "  ### Python Packages ###"

  detect_py_pkg() {
    local name="$1"
    local label="$2"
    if grep -qi "$name" "$PROJECT_ROOT/requirements.txt" 2>/dev/null || \
       grep -qi "$name" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null || \
       grep -qi "$name" "$PROJECT_ROOT/Pipfile" 2>/dev/null || \
       grep -qi "$name" "$PROJECT_ROOT/setup.py" 2>/dev/null; then
      echo "  [py] $label"
    fi
  }

  detect_py_pkg "django" "Django"
  detect_py_pkg "flask" "Flask"
  detect_py_pkg "fastapi" "FastAPI"
  detect_py_pkg "starlette" "Starlette"
  detect_py_pkg "tornado" "Tornado"
  detect_py_pkg "celery" "Celery"
  detect_py_pkg "sqlalchemy" "SQLAlchemy"
  detect_py_pkg "alembic" "Alembic"
  detect_py_pkg "pydantic" "Pydantic"
  detect_py_pkg "pytest" "pytest"
  detect_py_pkg "unittest" "unittest"
  detect_py_pkg "black" "Black (formatter)"
  detect_py_pkg "ruff" "Ruff (linter)"
  detect_py_pkg "mypy" "mypy (type checker)"
  detect_py_pkg "pylint" "Pylint"
  detect_py_pkg "flake8" "Flake8"
  detect_py_pkg "isort" "isort"
  detect_py_pkg "poetry" "Poetry"
fi

# Go modules
if [ -f "$PROJECT_ROOT/go.mod" ]; then
  echo ""
  echo "  ### Go Modules ###"
  grep -E '^\t' "$PROJECT_ROOT/go.mod" 2>/dev/null | head -20 | while read -r line; do
    echo "  [go] $line"
  done
fi

# Rust crates
if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
  echo ""
  echo "  ### Rust Dependencies ###"
  # Extract [dependencies] section
  sed -n '/^\[dependencies\]/,/^\[/p' "$PROJECT_ROOT/Cargo.toml" 2>/dev/null | grep -v '^\[' | head -20 | while read -r line; do
    if [ -n "$line" ]; then
      echo "  [rust] $line"
    fi
  done
fi

# Ruby gems
if [ -f "$PROJECT_ROOT/Gemfile" ]; then
  echo ""
  echo "  ### Ruby Gems ###"
  grep "^gem " "$PROJECT_ROOT/Gemfile" 2>/dev/null | head -20 | while read -r line; do
    echo "  [rb] $line"
  done
fi
echo ""

# --- Build system & scripts ---
echo "## Build System & Scripts"

if [ -f "$PROJECT_ROOT/package.json" ]; then
  echo "  ### npm scripts ###"
  # Extract script names from package.json
  if $PYTHON3_AVAILABLE; then
    python3 -c "
import json, sys
try:
    with open('$PROJECT_ROOT/package.json') as f:
        pkg = json.load(f)
    scripts = pkg.get('scripts', {})
    for name, cmd in scripts.items():
        print(f'  {name}: {cmd}')
except: pass
" 2>/dev/null || true
  else
    # Fallback: extract script names using grep/sed
    warn_skip "python3 JSON parse for npm scripts" "python3 not available, using grep fallback"
    sed -n '/"scripts"/,/}/p' "$PROJECT_ROOT/package.json" 2>/dev/null \
      | grep -E '^\s*"[^"]+"\s*:' \
      | sed 's/^\s*"\([^"]*\)"\s*:\s*"\(.*\)".*/  \1: \2/' \
      | head -30 || true
  fi
fi

if [ -f "$PROJECT_ROOT/Makefile" ]; then
  echo "  ### Makefile targets ###"
  grep -E '^[a-zA-Z_-]+:' "$PROJECT_ROOT/Makefile" 2>/dev/null | sed 's/:.*//' | head -20 | while read -r target; do
    echo "  make $target"
  done
fi
echo ""

# --- Testing setup ---
echo "## Testing Setup"

# Jest
if [ -f "$PROJECT_ROOT/jest.config.js" ] || [ -f "$PROJECT_ROOT/jest.config.ts" ] || [ -f "$PROJECT_ROOT/jest.config.json" ]; then
  echo "  [test] Jest config found"
fi

# Vitest
if [ -f "$PROJECT_ROOT/vitest.config.ts" ] || [ -f "$PROJECT_ROOT/vitest.config.js" ]; then
  echo "  [test] Vitest config found"
fi

# Pytest
if [ -f "$PROJECT_ROOT/pytest.ini" ] || [ -f "$PROJECT_ROOT/conftest.py" ]; then
  echo "  [test] pytest config found"
fi
if [ -f "$PROJECT_ROOT/pyproject.toml" ] && grep -q '\[tool.pytest' "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
  echo "  [test] pytest config in pyproject.toml"
fi

# Cypress
if [ -f "$PROJECT_ROOT/cypress.config.js" ] || [ -f "$PROJECT_ROOT/cypress.config.ts" ] || [ -d "$PROJECT_ROOT/cypress" ]; then
  echo "  [test] Cypress (E2E) found"
fi

# Playwright
if [ -f "$PROJECT_ROOT/playwright.config.ts" ] || [ -f "$PROJECT_ROOT/playwright.config.js" ]; then
  echo "  [test] Playwright (E2E) found"
fi

# Go tests
if [ -f "$PROJECT_ROOT/go.mod" ]; then
  GO_TEST_COUNT=$(find "$PROJECT_ROOT" -name "*_test.go" -not -path '*/vendor/*' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$GO_TEST_COUNT" -gt 0 ]; then
    echo "  [test] Go tests: $GO_TEST_COUNT test files"
  fi
fi

# Rust tests
if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
  if [ -d "$PROJECT_ROOT/tests" ]; then
    echo "  [test] Rust integration tests directory found"
  fi
fi

# Test file counts
TEST_FILES=$(find "$PROJECT_ROOT" \( -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" -o -name "*_test.go" -o -name "*_test.rs" \) \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  2>/dev/null | wc -l | tr -d ' ')
echo "  Total test files: $TEST_FILES"

# Coverage config
if [ -f "$PROJECT_ROOT/.coveragerc" ] || [ -f "$PROJECT_ROOT/.nycrc" ] || [ -f "$PROJECT_ROOT/.nycrc.json" ]; then
  echo "  [coverage] Coverage config found"
fi
echo ""

# --- CI/CD detection ---
echo "## CI/CD Pipelines"
if [ -d "$PROJECT_ROOT/.github/workflows" ]; then
  echo "  [ci] GitHub Actions"
  ls "$PROJECT_ROOT/.github/workflows/" 2>/dev/null | while read -r f; do
    echo "    - $f"
  done
fi
if [ -f "$PROJECT_ROOT/.gitlab-ci.yml" ]; then
  echo "  [ci] GitLab CI"
fi
if [ -d "$PROJECT_ROOT/.circleci" ]; then
  echo "  [ci] CircleCI"
fi
if [ -f "$PROJECT_ROOT/Jenkinsfile" ]; then
  echo "  [ci] Jenkins"
fi
if [ -f "$PROJECT_ROOT/bitbucket-pipelines.yml" ]; then
  echo "  [ci] Bitbucket Pipelines"
fi
if [ -f "$PROJECT_ROOT/.travis.yml" ]; then
  echo "  [ci] Travis CI"
fi
if [ -f "$PROJECT_ROOT/vercel.json" ] || [ -d "$PROJECT_ROOT/.vercel" ]; then
  echo "  [deploy] Vercel"
fi
if [ -f "$PROJECT_ROOT/netlify.toml" ]; then
  echo "  [deploy] Netlify"
fi
echo ""

# --- Existing Claude config ---
echo "## Existing Claude Configuration"
if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  echo "  [claude] Root CLAUDE.md found"
  CLAUDE_LINES=$(wc -l < "$PROJECT_ROOT/CLAUDE.md" | tr -d ' ')
  echo "  [claude] CLAUDE.md lines: $CLAUDE_LINES"
fi
if [ -d "$PROJECT_ROOT/.claude" ]; then
  echo "  [claude] .claude/ directory found"
  find "$PROJECT_ROOT/.claude" -type f 2>/dev/null | while read -r f; do
    echo "    - ${f#$PROJECT_ROOT/}"
  done
fi
# Check for subdirectory CLAUDE.md files
SUBDIR_CLAUDE=$(find "$PROJECT_ROOT" -name "CLAUDE.md" -not -path "$PROJECT_ROOT/CLAUDE.md" \
  -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
if [ -n "$SUBDIR_CLAUDE" ]; then
  echo "  [claude] Subdirectory CLAUDE.md files:"
  echo "$SUBDIR_CLAUDE" | while read -r f; do
    echo "    - ${f#$PROJECT_ROOT/}"
  done
fi
echo ""

echo "=== END STACK DETECTION ==="
