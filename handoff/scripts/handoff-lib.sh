#!/usr/bin/env bash
# handoff-lib.sh — shared functions for the handoff plugin.
#
# Sourced by hooks/session-start.sh, scripts/compute-progress.sh, and
# scripts/prune-archive.sh. This is the SINGLE source of truth for frontmatter
# reading, body extraction, ISO→epoch parsing, and retention normalization —
# it exists so those three consumers cannot drift (audit H2/H6/H7).
#
# Contract: pure functions only. NO `set -e`, NO top-level side effects, NO
# `exit`. Safe to source into a hook that must always exit 0.

# Extract a single frontmatter value (between the first two `---` lines only).
# Strips surrounding quotes. Empty string (return 0) if file missing / key absent.
# Usage: hf_get_fm_value <file> <key>
hf_get_fm_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || { printf ''; return 0; }
  awk -v key="$key" '
    BEGIN { in_fm = 0; fm_count = 0 }
    /^---[[:space:]]*$/ { fm_count++; in_fm = (fm_count == 1); next }
    fm_count >= 2 { exit }
    in_fm {
      pos = index($0, ":")
      if (pos == 0) next
      k = substr($0, 1, pos - 1)
      v = substr($0, pos + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/^["'\'']|["'\'']$/, "", v)
      if (k == key) { print v; exit }
    }
  ' "$file" 2>/dev/null
  return 0
}

# Extract the body (everything after the closing `---` of frontmatter).
# Usage: hf_get_body <file>
hf_get_body() {
  local file="$1"
  [[ -f "$file" ]] || { printf ''; return 0; }
  awk '
    BEGIN { fm_count = 0 }
    /^---[[:space:]]*$/ && fm_count < 2 { fm_count++; next }
    fm_count >= 2 { print }
  ' "$file" 2>/dev/null
  return 0
}

# Parse an ISO-8601 timestamp to Unix seconds. Prints 0 (never non-zero) on
# empty / non-ISO-shaped / unparseable input. GNU date first, then BSD date.
# Usage: hf_iso_to_epoch <iso>
hf_iso_to_epoch() {
  local ts="$1"
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]] || { printf '0'; return 0; }
  date -d "$ts" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ts" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
    || printf '0'
  return 0
}

# Normalize an archive-retention raw value to the canonical form both
# compute-progress (display) and prune-archive (behavior) agree on (audit H6).
# Prints: `unlimited` | <non-negative int> | `10` (default for empty/garbage).
# Usage: hf_normalize_retention <raw>
hf_normalize_retention() {
  local raw="$1"
  case "$raw" in
    unlimited|-1|null) printf 'unlimited' ;;
    ''|*[!0-9]*)       printf '10' ;;
    *)                 printf '%s' "$raw" ;;  # non-negative integer, incl. 0
  esac
  return 0
}
