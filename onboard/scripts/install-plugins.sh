#!/usr/bin/env bash
# install-plugins.sh — Install Claude Code plugins by qualified name (shared by MCP + LSP emission)
# Usage: bash install-plugins.sh <plugin>[@<marketplace>] [<plugin>[@<marketplace>] ...]
# Output: JSON object on stdout summarizing install results.
#
# Callers pass ONLY names a person accepted in an offer that named them, or a programmatic
# caller's explicit list. This script does not ask. The rule, the offer shape and what happens
# when nobody answers live in references/plugin-install-consent.md.
#
# Every install is qualified with its marketplace, so a name can never resolve against some other
# marketplace that happens to list a plugin with the same name:
#   - A bare name means claude-plugins-official (every catalog LSP and MCP plugin lives there).
#   - Any other marketplace must be named explicitly (e.g. walkthrough@apurvbazari-plugins) and must
#     already be added; the script never adds a marketplace. If it is missing, the plugin is
#     reported as failed with reason "marketplace-not-added" and nothing is installed.
# Plugins install at Claude Code's default scope (user).
#
# Schema:
#   {
#     "installed": ["vercel"],
#     "alreadyInstalled": ["context7"],
#     "failed": [{"plugin": "supabase", "marketplace": "claude-plugins-official", "reason": "exit-code-1"}]
#   }
#
# Never exits non-zero — the install layer must not fail MCP emission. Failures are reported via
# the JSON output for the caller to surface in its stdout summary and mcpStatus telemetry.

# NOTE: utility script, but intentionally hook-style error handling — this is a
# best-effort installer whose failure must NEVER abort onboard generation.
# It reports per-plugin status via JSON and always exits 0.
set -uo pipefail

OFFICIAL="claude-plugins-official"

if [[ $# -lt 1 ]]; then
  echo '{"installed":[],"alreadyInstalled":[],"failed":[]}'
  exit 0
fi

have_claude=false
command -v claude &>/dev/null && have_claude=true

# Probe once each; tolerate failure (older CLIs may lack --json).
installed_plugins=""
marketplaces=""
if $have_claude; then
  installed_plugins=$(claude plugin list --json 2>/dev/null | tr -d '\n' || true)
  marketplaces=$(claude plugin marketplace list --json 2>/dev/null | tr -d '\n' || true)
fi

# Strict charset for both halves, checked before either value reaches a grep pattern, the JSON
# output or the install command (closes regex and JSON-string injection, audit M1/M2).
is_valid_part() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

# Installed under this name from ANY source (a marketplace, claude.ai sync, a skills dir).
# `claude plugin list --json` reports each install as "id": "<name>@<source>". Fixed-string match.
is_installed() {
  local plugin="$1"
  printf '%s' "$installed_plugins" | grep -qF "\"id\":\"${plugin}@" && return 0
  printf '%s' "$installed_plugins" | grep -qF "\"id\": \"${plugin}@" && return 0
  return 1
}

# claude-plugins-official is always available; any other marketplace must already be added.
marketplace_added() {
  local mkt="$1"
  [[ "$mkt" == "$OFFICIAL" ]] && return 0
  printf '%s' "$marketplaces" | grep -qF "\"name\":\"${mkt}\"" && return 0
  printf '%s' "$marketplaces" | grep -qF "\"name\": \"${mkt}\"" && return 0
  return 1
}

installed_list=()
already_list=()
failed_list=()

fail_entry() { # <plugin> <marketplace> <reason>
  failed_list+=("{\"plugin\":\"$1\",\"marketplace\":\"$2\",\"reason\":\"$3\"}")
}

for arg in "$@"; do
  plugin="${arg%%@*}"
  if [[ "$arg" == *@* ]]; then
    marketplace="${arg#*@}"
  else
    marketplace="$OFFICIAL"
  fi

  if ! is_valid_part "$plugin" || ! is_valid_part "$marketplace"; then
    failed_list+=('{"plugin":"<invalid>","reason":"invalid-plugin-name"}')
    continue
  fi

  if is_installed "$plugin"; then
    already_list+=("$plugin")
    continue
  fi

  if ! $have_claude; then
    fail_entry "$plugin" "$marketplace" "claude-cli-not-found"
    continue
  fi

  if ! marketplace_added "$marketplace"; then
    fail_entry "$plugin" "$marketplace" "marketplace-not-added"
    continue
  fi

  # Capture the install exit code BEFORE any if/test construct so $? isn't
  # clobbered by the if-test's own exit status (L1 fix).
  claude plugin install "${plugin}@${marketplace}" >/dev/null 2>&1
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    installed_list+=("$plugin")
  else
    fail_entry "$plugin" "$marketplace" "exit-code-$rc"
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
