#!/usr/bin/env bash
# check-state-gitignore.sh — verify the root .gitignore ignores forge+onboard
# runtime state files.
#
# These files persist wizard answers that may include user-entered free-text
# (project descriptions, pain points, custom conventions). A user who pastes
# a secret into a wizard answer would otherwise see it committed to git on
# the next `git add .`. Keeping them gitignored is a simple, durable guard.
#
# Required entries:
#   .claude/forge-state.json
#   .claude/forge-state.json.tmp
#   .claude/forge-drift.json
#   .claude/forge-meta.json
#   .claude/onboard-snapshot.json
#   .claude/onboard-meta.json

set -euo pipefail

gitignore=".gitignore"

if [[ ! -f "$gitignore" ]]; then
  echo "::error::$gitignore not found at repo root" >&2
  exit 1
fi

required=(
  ".claude/forge-state.json"
  ".claude/forge-state.json.tmp"
  ".claude/forge-drift.json"
  ".claude/forge-meta.json"
  ".claude/onboard-snapshot.json"
  ".claude/onboard-meta.json"
)

missing=()
for entry in "${required[@]}"; do
  if ! grep -qxF "$entry" "$gitignore"; then
    missing+=("$entry")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  {
    echo "::error::.gitignore is missing required forge/onboard state-file entries:"
    printf '  %s\n' "${missing[@]}"
    echo ""
    echo "Add these lines to .gitignore — they persist wizard answers that may contain user-entered secrets."
  } >&2
  exit 1
fi

echo "All forge/onboard state-file entries are present in .gitignore"
