#!/usr/bin/env bash
# install-mcp-plugins.sh — Install Claude Code plugins for emitted MCP servers
# Usage: bash install-mcp-plugins.sh <plugin1> [plugin2] ...
# Output: JSON object on stdout summarizing install results.
#
# Schema:
#   {
#     "installed": ["vercel"],
#     "alreadyInstalled": ["context7"],
#     "failed": [{"plugin": "supabase", "reason": "exit-code-1"}]
#   }
#
# Never exits non-zero — install layer must not fail MCP emission. Failures
# are reported via the JSON output for the caller to surface in stdout summary
# and mcpStatus telemetry.

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo '{"installed":[],"alreadyInstalled":[],"failed":[]}'
  exit 0
fi

installed_plugins=""
if command -v claude &>/dev/null; then
  # Probe once; tolerate failure (claude CLI may not support --json in all versions)
  installed_plugins=$(claude plugin list --json 2>/dev/null | tr -d '\n' || true)
fi

is_installed() {
  local plugin="$1"
  # Match `"name":"<plugin>"` or `"name": "<plugin>"` to be tolerant of formatting
  if echo "$installed_plugins" | grep -qE "\"name\"[[:space:]]*:[[:space:]]*\"${plugin}\""; then
    return 0
  fi
  return 1
}

installed_list=()
already_list=()
failed_list=()

for plugin in "$@"; do
  if is_installed "$plugin"; then
    already_list+=("$plugin")
    continue
  fi

  if ! command -v claude &>/dev/null; then
    failed_list+=("{\"plugin\":\"$plugin\",\"reason\":\"claude-cli-not-found\"}")
    continue
  fi

  # Best-effort install; capture exit code
  if claude plugin install "$plugin" >/dev/null 2>&1; then
    installed_list+=("$plugin")
  else
    failed_list+=("{\"plugin\":\"$plugin\",\"reason\":\"exit-code-$?\"}")
  fi
done

# Render JSON output
printf '{"installed":['
first=true
for p in "${installed_list[@]+"${installed_list[@]}"}"; do
  if $first; then first=false; else printf ','; fi
  printf '"%s"' "$p"
done
printf '],"alreadyInstalled":['
first=true
for p in "${already_list[@]+"${already_list[@]}"}"; do
  if $first; then first=false; else printf ','; fi
  printf '"%s"' "$p"
done
printf '],"failed":['
first=true
for p in "${failed_list[@]+"${failed_list[@]}"}"; do
  if $first; then first=false; else printf ','; fi
  printf '%s' "$p"
done
printf ']}\n'

exit 0
