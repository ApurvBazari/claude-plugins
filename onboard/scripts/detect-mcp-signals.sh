#!/usr/bin/env bash
# detect-mcp-signals.sh — Detect which MCP servers should be emitted based on project signals
# Usage: bash detect-mcp-signals.sh [project-root]
# Output: JSON array on stdout, one object per candidate MCP server.
#
# Schema:
#   [
#     { "server": "context7", "confidence": "always", "plugin": "context7",
#       "transport": "stdio", "signal": "any-project" },
#     { "server": "vercel",   "confidence": "high",   "plugin": "vercel",
#       "transport": "http",  "signal": "vercel.json" }
#   ]
#
# Reads stack fingerprints from the project directory. Does NOT read analysis JSON —
# the caller (config-generator) can merge this script's output with analysis results.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

candidates=()

# Always emit context7 — universally useful for docs lookup, zero auth, zero cost
candidates+=('{"server":"context7","confidence":"always","plugin":"context7","transport":"stdio","signal":"any-project"}')

# GitHub: signal is .github/workflows/
if [[ -d "${PROJECT_ROOT}/.github/workflows" ]]; then
  candidates+=('{"server":"github","confidence":"high","plugin":"github","transport":"http","signal":".github/workflows"}')
fi

# Vercel: signal is vercel.json OR @vercel/* in package.json
vercel_hit=false
if [[ -f "${PROJECT_ROOT}/vercel.json" ]]; then
  vercel_hit=true
fi
if ! $vercel_hit && [[ -f "${PROJECT_ROOT}/package.json" ]]; then
  if grep -qE '"@vercel/' "${PROJECT_ROOT}/package.json" 2>/dev/null; then
    vercel_hit=true
  fi
fi
if $vercel_hit; then
  candidates+=('{"server":"vercel","confidence":"high","plugin":"vercel","transport":"http","signal":"vercel-config-or-dep"}')
fi

# Prisma: signal is prisma/ directory OR @prisma/client / prisma in deps
prisma_hit=false
if [[ -d "${PROJECT_ROOT}/prisma" ]]; then
  prisma_hit=true
fi
if ! $prisma_hit && [[ -f "${PROJECT_ROOT}/package.json" ]]; then
  if grep -qE '"(@prisma/client|prisma)":' "${PROJECT_ROOT}/package.json" 2>/dev/null; then
    prisma_hit=true
  fi
fi
if $prisma_hit; then
  candidates+=('{"server":"prisma","confidence":"high","plugin":"prisma","transport":"stdio","signal":"prisma-dir-or-dep"}')
fi

# Supabase: signal is supabase/ config directory OR @supabase/* in deps
supabase_hit=false
if [[ -d "${PROJECT_ROOT}/supabase" ]]; then
  supabase_hit=true
fi
if ! $supabase_hit && [[ -f "${PROJECT_ROOT}/package.json" ]]; then
  if grep -qE '"@supabase/' "${PROJECT_ROOT}/package.json" 2>/dev/null; then
    supabase_hit=true
  fi
fi
if $supabase_hit; then
  candidates+=('{"server":"supabase","confidence":"high","plugin":"supabase","transport":"http","signal":"supabase-dir-or-dep"}')
fi

# Frontend framework: signal is any of the known frontend framework fingerprints in package.json
frontend_hit=false
if [[ -f "${PROJECT_ROOT}/package.json" ]]; then
  if grep -qE '"(react|next|vue|svelte|@sveltejs/kit|astro|@remix-run/|solid-js|nuxt|@builder.io/qwik)":' "${PROJECT_ROOT}/package.json" 2>/dev/null; then
    frontend_hit=true
  fi
fi
if $frontend_hit; then
  candidates+=('{"server":"chrome-devtools-mcp","confidence":"high","plugin":"chrome-devtools-mcp","transport":"stdio","signal":"frontend-framework"}')
fi

# Emit JSON array
printf '['
first=true
for c in "${candidates[@]}"; do
  if $first; then
    first=false
  else
    printf ','
  fi
  printf '%s' "$c"
done
printf ']\n'
