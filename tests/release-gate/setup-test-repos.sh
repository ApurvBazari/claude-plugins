#!/usr/bin/env bash
set -euo pipefail

# setup-test-repos.sh — Create 4 scratch repos for release-gate testing
# Usage: setup-test-repos.sh [BASE_DIR]
# Default BASE_DIR: $TMPDIR/release-gate-tests

BASE_DIR="${1:-${TMPDIR:-/tmp}/release-gate-tests}"

echo "## Setting up test repos in: ${BASE_DIR}"
echo ""

# Clean previous run
if [[ -d "$BASE_DIR" ]]; then
  echo "Removing previous test repos..."
  rm -rf "$BASE_DIR"
fi
mkdir -p "$BASE_DIR"

# ─────────────────────────────────────────────────
# 1. test-nextjs — Next.js + Vercel + Prisma
# ─────────────────────────────────────────────────
REPO="${BASE_DIR}/test-nextjs"
echo "Creating test-nextjs (Next.js + Vercel + Prisma)..."
mkdir -p "${REPO}/src/app" "${REPO}/src/components" "${REPO}/src/lib" "${REPO}/prisma" "${REPO}/.github/workflows"

cat > "${REPO}/package.json" <<'EJSON'
{
  "name": "test-nextjs",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest"
  },
  "dependencies": {
    "next": "14.2.0",
    "react": "18.3.0",
    "react-dom": "18.3.0",
    "@prisma/client": "5.14.0",
    "@supabase/supabase-js": "2.43.0"
  },
  "devDependencies": {
    "typescript": "5.4.0",
    "@types/react": "18.3.0",
    "vitest": "1.6.0",
    "eslint": "8.57.0"
  }
}
EJSON

cat > "${REPO}/vercel.json" <<'EJSON'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "framework": "nextjs"
}
EJSON

cat > "${REPO}/tsconfig.json" <<'EJSON'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "es2017"],
    "jsx": "preserve",
    "module": "esnext",
    "moduleResolution": "bundler",
    "strict": true
  }
}
EJSON

echo 'datasource db { provider = "postgresql" url = env("DATABASE_URL") }' > "${REPO}/prisma/schema.prisma"
echo 'name: CI' > "${REPO}/.github/workflows/ci.yml"

# Create enough .tsx files to hit LSP threshold (≥10)
for f in page layout loading error not-found; do
  echo "export default function ${f}() { return <div>${f}</div> }" > "${REPO}/src/app/${f}.tsx"
done
for f in Button Card Header Footer Nav Sidebar Modal Input Table Badge; do
  echo "export function ${f}() { return <div>${f}</div> }" > "${REPO}/src/components/${f}.tsx"
done
echo "export function db() { return null }" > "${REPO}/src/lib/db.ts"
echo "export function auth() { return null }" > "${REPO}/src/lib/auth.ts"

(cd "$REPO" && git init -q && git add -A && git commit -q -m "init: Next.js + Vercel + Prisma scaffold")
echo "  OK: ${REPO} ($(find "${REPO}/src" -name '*.tsx' -o -name '*.ts' | wc -l | tr -d ' ') source files)"

# ─────────────────────────────────────────────────
# 2. test-python — Python CLI (minimal)
# ─────────────────────────────────────────────────
REPO="${BASE_DIR}/test-python"
echo "Creating test-python (Python CLI minimal)..."
mkdir -p "${REPO}/src" "${REPO}/tests"

cat > "${REPO}/pyproject.toml" <<'ETOML'
[project]
name = "test-cli"
version = "0.1.0"
dependencies = ["click>=8.0"]

[build-system]
requires = ["setuptools"]
build-backend = "setuptools.backends._legacy:_Backend"
ETOML

echo 'import click' > "${REPO}/src/main.py"
echo 'def helper(): pass' > "${REPO}/src/utils.py"
echo 'def parse(): pass' > "${REPO}/src/parser.py"
echo 'def test_main(): pass' > "${REPO}/tests/test_main.py"
echo 'def test_utils(): pass' > "${REPO}/tests/test_utils.py"

(cd "$REPO" && git init -q && git add -A && git commit -q -m "init: Python CLI scaffold")
echo "  OK: ${REPO} ($(find "${REPO}" -name '*.py' | wc -l | tr -d ' ') source files)"

# ─────────────────────────────────────────────────
# 3. test-monorepo — Turborepo
# ─────────────────────────────────────────────────
REPO="${BASE_DIR}/test-monorepo"
echo "Creating test-monorepo (Turborepo)..."
mkdir -p "${REPO}/apps/web/src" "${REPO}/apps/api/src" "${REPO}/packages/ui/src" "${REPO}/packages/shared/src"

cat > "${REPO}/package.json" <<'EJSON'
{
  "name": "test-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "devDependencies": {
    "turbo": "2.0.0",
    "typescript": "5.4.0"
  }
}
EJSON

cat > "${REPO}/turbo.json" <<'EJSON'
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": { "dependsOn": ["^build"] },
    "test": {},
    "lint": {}
  }
}
EJSON

# Scatter 15+ .ts files across the monorepo
for app in web api; do
  for f in index routes middleware utils config; do
    echo "export const ${f} = '${app}'" > "${REPO}/apps/${app}/src/${f}.ts"
  done
  echo '{"name":"@repo/'${app}'","version":"0.0.0"}' > "${REPO}/apps/${app}/package.json"
done
for pkg in ui shared; do
  for f in index helpers types; do
    echo "export const ${f} = '${pkg}'" > "${REPO}/packages/${pkg}/src/${f}.ts"
  done
  echo '{"name":"@repo/'${pkg}'","version":"0.0.0"}' > "${REPO}/packages/${pkg}/package.json"
done

(cd "$REPO" && git init -q && git add -A && git commit -q -m "init: Turborepo monorepo scaffold")
echo "  OK: ${REPO} ($(find "${REPO}" -name '*.ts' | wc -l | tr -d ' ') source files)"

# ─────────────────────────────────────────────────
# 4. test-empty — Edge case
# ─────────────────────────────────────────────────
REPO="${BASE_DIR}/test-empty"
echo "Creating test-empty (empty repo edge case)..."
mkdir -p "$REPO"

(cd "$REPO" && git init -q && git commit -q --allow-empty -m "init: empty repo")
echo "  OK: ${REPO} (0 source files)"

# ─────────────────────────────────────────────────
echo ""
echo "## All test repos created at: ${BASE_DIR}"
echo ""
echo "Next steps:"
echo "  1. cd ${BASE_DIR}/test-nextjs && claude  # Run /onboard:init"
echo "  2. cd ${BASE_DIR}/test-python && claude   # Run /onboard:init"
echo "  3. cd ${BASE_DIR}/test-monorepo && claude # Run /onboard:init"
echo "  4. cd ${BASE_DIR}/test-empty && claude    # Run /onboard:init"
