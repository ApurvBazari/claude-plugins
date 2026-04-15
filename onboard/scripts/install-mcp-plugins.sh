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

# Validate plugin names against a strict charset before any use in regex/JSON/shell.
# Claude Code plugin names are kebab-case alphanumerics; anything else is rejected.
# Closes M1 (regex injection) and M2 (JSON string injection) — both trace back to
# unsanitized $plugin values. Names failing validation are recorded as failures and
# never flow into grep patterns, JSON output, or install invocations.
is_valid_plugin_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

is_installed() {
  local plugin="$1"
  # Fixed-string match on the JSON fragment `"name":"<plugin>"`. Use grep -F so
  # regex metacharacters in plugin names can't produce false positives. Tolerant
  # of whitespace variants by trying both compact and spaced forms.
  if echo "$installed_plugins" | grep -qF "\"name\":\"${plugin}\""; then
    return 0
  fi
  if echo "$installed_plugins" | grep -qF "\"name\": \"${plugin}\""; then
    return 0
  fi
  return 1
}

installed_list=()
already_list=()
failed_list=()

for plugin in "$@"; do
  if ! is_valid_plugin_name "$plugin"; then
    failed_list+=('{"plugin":"<invalid>","reason":"invalid-plugin-name"}')
    continue
  fi

  if is_installed "$plugin"; then
    already_list+=("$plugin")
    continue
  fi

  if ! command -v claude &>/dev/null; then
    failed_list+=("{\"plugin\":\"$plugin\",\"reason\":\"claude-cli-not-found\"}")
    continue
  fi

  # Capture the install exit code BEFORE any if/test construct so $? isn't
  # clobbered by the if-test's own exit status (L1 fix — previously reported
  # a constant exit-code-1 regardless of actual failure).
  claude plugin install "$plugin" >/dev/null 2>&1
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    installed_list+=("$plugin")
  else
    failed_list+=("{\"plugin\":\"$plugin\",\"reason\":\"exit-code-$rc\"}")
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
