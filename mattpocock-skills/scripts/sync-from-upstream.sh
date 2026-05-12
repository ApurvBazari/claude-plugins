#!/usr/bin/env bash
# sync-from-upstream.sh — Compare vendored skill files against upstream
# mattpocock/skills and report drift. Non-destructive — does not modify
# any files. Use the output to decide whether to pull updates and bump
# the plugin version.
#
# Requirements: gh CLI, python3
# Usage:
#   ./scripts/sync-from-upstream.sh [<target-sha>]
# Defaults to upstream main HEAD if no SHA passed.

set -euo pipefail

UPSTREAM="mattpocock/skills"
TARGET_SHA="${1:-$(gh api "repos/${UPSTREAM}/commits/main" --jq '.sha')}"

# (skill-dir, upstream-category)
SKILLS=(
  "grill-me:productivity"
  "grill-with-docs:engineering"
  "setup-matt-pocock-skills:engineering"
  "triage:engineering"
  "prototype:engineering"
  "zoom-out:engineering"
  "handoff:productivity"
  "improve-codebase-architecture:engineering"
)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "${script_dir}/.." && pwd)"

current_sha=$(grep -E "Vendored from SHA" "${plugin_root}/README.md" | grep -oE '[a-f0-9]{40}' || echo "unknown")

echo "Vendored SHA (per README): ${current_sha}"
echo "Target SHA (upstream):     ${TARGET_SHA}"
echo

if [[ "${current_sha}" == "${TARGET_SHA}" ]]; then
  echo "Already at target SHA. Nothing to compare."
  exit 0
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

drift_count=0
new_count=0

for entry in "${SKILLS[@]}"; do
  skill="${entry%%:*}"
  cat="${entry##*:}"
  local_dir="${plugin_root}/skills/${skill}"

  # List the upstream files for this skill at TARGET_SHA
  url="repos/${UPSTREAM}/contents/skills/${cat}/${skill}?ref=${TARGET_SHA}"
  if ! upstream_files=$(gh api "${url}" --jq '.[].name' 2>/dev/null); then
    echo "WARN: cannot list upstream ${cat}/${skill} (renamed or removed?)"
    continue
  fi

  for f in ${upstream_files}; do
    local_file="${local_dir}/${f}"
    upstream_url="repos/${UPSTREAM}/contents/skills/${cat}/${skill}/${f}?ref=${TARGET_SHA}"
    upstream_content=$(gh api "${upstream_url}" --jq '.content' | base64 -d)

    if [[ ! -f "${local_file}" ]]; then
      echo "NEW: ${skill}/${f}"
      new_count=$((new_count + 1))
      continue
    fi

    if ! echo "${upstream_content}" | diff -q - "${local_file}" > /dev/null 2>&1; then
      echo "DRIFT: ${skill}/${f}"
      drift_count=$((drift_count + 1))
    fi
  done
done

echo
echo "Summary: ${drift_count} file(s) drifted, ${new_count} new file(s) upstream"
if [[ ${drift_count} -gt 0 || ${new_count} -gt 0 ]]; then
  echo
  echo "To pull updates:"
  echo "  1. Use 'gh api repos/${UPSTREAM}/contents/<path>?ref=${TARGET_SHA}' to fetch updated files"
  echo "  2. Update 'Vendored from SHA' in README.md to ${TARGET_SHA}"
  echo "  3. Bump 'version' in .claude-plugin/plugin.json"
  echo "  4. Bump matching version in .claude-plugin/marketplace.json"
fi
