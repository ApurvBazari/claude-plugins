#!/usr/bin/env bash
# render-common.sh — R6 shared helper library
#
# Sourced by every renderer module in greenfield/scripts/render-*.sh.
# Provides 6 helpers replacing duplicated logic from R5.
#
# Helpers exit non-zero on failure; callers are expected to use `set -euo pipefail`.
# All helpers are pure shell — no external state beyond their args + stdin.

set -euo pipefail

# Guard against double-sourcing.
[[ "${__RENDER_COMMON_SH_SOURCED:-}" == "1" ]] && return 0
readonly __RENDER_COMMON_SH_SOURCED=1

command -v jq >/dev/null || { echo "render-common: jq is required" >&2; exit 2; }

# _emit_warning <level> <code> <message>
#   Appends a warning object to the JSON array passed via the $WARNINGS variable
#   in the caller's scope. Caller pattern:
#     WARNINGS=$(_emit_warning "warn" "W-DB-pk" "Aggregate root has no PK" "$WARNINGS")
_emit_warning() {
  local level="$1" code="$2" message="$3" warnings_json="${4:-[]}"
  jq --arg id "$code" --arg lvl "$level" --arg msg "$message" \
    '. + [{id: $id, level: $lvl, message: $msg, addressed: false}]' <<< "$warnings_json"
}

# _check_pii_encryption <entity-attr-path> <pii-array> <warnings-json>
#   Looks up entity.attribute in the privacy.piiFields[] array. If matched and
#   no encryption hint declared, returns a `warn`-level warning appended to
#   the warnings JSON. No-op if path not in PII list.
_check_pii_encryption() {
  local path="$1" pii_array="$2" warnings_json="${3:-[]}"
  local hit
  hit=$(jq --arg p "$path" '[.[] | select(.path == $p)] | length' <<< "$pii_array")
  if [[ "$hit" -gt 0 ]]; then
    local enc
    enc=$(jq -r --arg p "$path" '[.[] | select(.path == $p) | .encryption // ""] | first // ""' <<< "$pii_array")
    if [[ -z "$enc" ]]; then
      local code msg
      code="W-PII-$(echo "$path" | tr '.' '-')"
      msg="Field \`$path\` (PII) has no encryption hint — review storage strategy"
      _emit_warning "warn" "$code" "$msg" "$warnings_json"
      return 0
    fi
  fi
  echo "$warnings_json"
}

# _atomic_write <target-path> <content-string>
#   Writes content to <target-path>.tmp then atomically renames over <target-path>.
#   Ensures readers never see a partial write. Exits non-zero on failure.
_atomic_write() {
  local target="$1" content="$2"
  local tmp="${target}.tmp.$$"
  printf '%s' "$content" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$target"
}

# _render_handlebars <template-string> <data-json>
#   Minimal Handlebars-flavored substitution: {{phase.field}}, {{#each list}}{{this.field}}{{/each}}.
#   data-json is the rooted phase block (e.g., contents of .phases.search).
#   For complex iteration, callers should pre-flatten or use jq directly.
_render_handlebars() {
  local tpl="$1" data="$2"
  local out="$tpl"
  # Simple {{field}} or {{nested.field}} substitution
  while [[ "$out" =~ \{\{([a-zA-Z_][a-zA-Z0-9_.]*)\}\} ]]; do
    local key="${BASH_REMATCH[1]}"
    local val
    val=$(jq -r --arg k "$key" 'getpath($k | split(".")) // ""' <<< "$data" 2>/dev/null || echo "")
    out="${out//\{\{${key}\}\}/$val}"
  done
  echo "$out"
}

# _emit_dependency <phase> <path> <value-json> <rationale>
#   Appends a dependency record to a dependencies.json file at $DEPS_PATH.
#   The caller is responsible for setting DEPS_PATH before calling.
_emit_dependency() {
  local phase="$1" path="$2" value="$3" rationale="$4"
  : "${DEPS_PATH:?DEPS_PATH must be set}"
  if [[ ! -f "$DEPS_PATH" ]]; then
    printf '%s\n' "{\"schemaVersion\":1,\"phase\":\"$phase\",\"dependencies\":[]}" > "$DEPS_PATH"
  fi
  local tmp="${DEPS_PATH}.tmp.$$"
  jq --arg p "$path" --argjson v "$value" --arg r "$rationale" \
    '.dependencies += [{path: $p, value: $v, rationale: $r}]' \
    "$DEPS_PATH" > "$tmp" && mv "$tmp" "$DEPS_PATH"
}

# _validate_jq_path <state-file> <jq-path> <required-bool>
#   Reads a jq path from the state file. Exits non-zero with a clear message if
#   `required` is "true" and the path is empty/null. Otherwise prints the value.
_validate_jq_path() {
  local state_file="$1" path="$2" required="${3:-false}"
  local val
  val=$(jq -r "$path" "$state_file" 2>/dev/null || echo "")
  if [[ "$required" == "true" && ( -z "$val" || "$val" == "null" ) ]]; then
    echo "render-common: required path missing: $path" >&2
    exit 3
  fi
  echo "$val"
}

# Marker so callers can verify the library was sourced rather than re-implementing inline.
export __RENDER_COMMON_API_VERSION=1
