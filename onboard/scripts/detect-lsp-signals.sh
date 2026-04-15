#!/usr/bin/env bash
# detect-lsp-signals.sh — Detect which LSP plugins should be recommended based on file presence
# Usage: bash detect-lsp-signals.sh [project-root]
# Output: JSON array on stdout, sorted by fileCount desc. One object per candidate LSP plugin.
#
# Schema:
#   [
#     { "language": "typescript", "plugin": "typescript-lsp", "fileCount": 1247,
#       "extensions": [".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs"] },
#     { "language": "rust", "plugin": "rust-analyzer-lsp", "fileCount": 312,
#       "extensions": [".rs"] }
#   ]
#
# A language with fileCount 0 is omitted. Caller maps `plugin` to claude plugin install.
# Vendor/build/cache directories are pruned (node_modules, .git, dist, build, target,
# .venv, venv, __pycache__, vendor, .next, .cache).
#
# Compatible with bash 3.2 (macOS default) — no associative arrays.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
# -P resolves the physical path (no symlink following), keeping subsequent file counts
# honest if any component of the supplied path is a symlink pointing outside the tree.
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"

# Count files matching any of the given extensions under PROJECT_ROOT, pruning
# vendor/build/cache directories. Works on BSD (macOS) and GNU (Linux) find.
# Uses -print0 + NUL counting so filenames containing newlines don't over-count
# (closes L1 from the 1.8.0 security audit — advisory only, but cheap to fix).
count_ext() {
  local total=0 c
  for ext in "$@"; do
    c=$(find "$PROJECT_ROOT" \
      -type d \( -name node_modules -o -name .git -o -name dist -o -name build \
                 -o -name target -o -name .venv -o -name venv -o -name __pycache__ \
                 -o -name vendor -o -name .next -o -name .cache \) -prune -o \
      -type f -iname "*$ext" -print0 2>/dev/null | tr -cd '\0' | wc -c | tr -d ' ')
    total=$((total + c))
  done
  echo "$total"
}

# Escape a string for embedding inside a JSON double-quoted value. Handles
# backslash and double-quote — sufficient for ASCII content from the hardcoded
# LANGUAGES array. Closes L2 from the 1.8.0 security audit — defends against
# future extensions where catalog entries might contain external input.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# Language rows: language-label | marketplace-plugin | space-separated extensions.
# typescript-lsp covers both TS and JS per plugin.json — one combined row.
# clangd-lsp extension list omits .h family; .c/.cpp alone is enough signal.
LANGUAGES=(
  "typescript|typescript-lsp|.ts .tsx .mts .cts .js .jsx .mjs .cjs"
  "go|gopls-lsp|.go"
  "rust|rust-analyzer-lsp|.rs"
  "c-cpp|clangd-lsp|.c .cpp .cc .cxx"
  "csharp|csharp-lsp|.cs"
  "java|jdtls-lsp|.java"
  "kotlin|kotlin-lsp|.kt .kts"
  "lua|lua-lsp|.lua"
  "php|php-lsp|.php"
  "python|pyright-lsp|.py"
  "ruby|ruby-lsp|.rb"
  "swift|swift-lsp|.swift"
)

# Build sortable lines: "count|plugin|language|extensions"
sortable=()
for row in "${LANGUAGES[@]}"; do
  IFS='|' read -r lang plugin exts_str <<< "$row"
  # Default-IFS split for extension tokens
  IFS=' ' read -r -a exts_arr <<< "$exts_str"
  c=$(count_ext "${exts_arr[@]}")
  if [[ "$c" -gt 0 ]]; then
    sortable+=("$c|$plugin|$lang|$exts_str")
  fi
done

# Sort by count desc
if [[ ${#sortable[@]} -gt 0 ]]; then
  sorted=$(printf '%s\n' "${sortable[@]}" | sort -t'|' -k1,1 -n -r)
else
  sorted=""
fi

# Emit JSON array
printf '['
first=true
if [[ -n "$sorted" ]]; then
  while IFS='|' read -r count plugin lang exts_str; do
    [[ -z "$count" ]] && continue
    if $first; then first=false; else printf ','; fi
    IFS=' ' read -r -a exts_arr <<< "$exts_str"
    ext_json=""
    for e in "${exts_arr[@]}"; do
      [[ -z "$e" ]] && continue
      e_escaped=$(json_escape "$e")
      if [[ -z "$ext_json" ]]; then
        ext_json="\"$e_escaped\""
      else
        ext_json="$ext_json,\"$e_escaped\""
      fi
    done
    printf '{"language":"%s","plugin":"%s","fileCount":%s,"extensions":[%s]}' \
      "$(json_escape "$lang")" "$(json_escape "$plugin")" "$count" "$ext_json"
  done <<< "$sorted"
fi
printf ']\n'
