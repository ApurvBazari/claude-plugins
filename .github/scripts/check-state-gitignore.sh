#!/usr/bin/env bash
# check-state-gitignore.sh — verify the root .gitignore ignores files that may
# contain user-entered or session content.
#
# Two privacy classes:
#   1. onboard runtime state — persists wizard answers (project descriptions,
#      pain points, custom conventions) that may include pasted secrets.
#   2. session-content dirs — walkthrough renders and handoff directives can
#      embed transcript/session content.
# Keeping all of them gitignored is a simple, durable guard against an accidental
# `git add .` committing them.
#
# Required entries:
#   .claude/onboard-snapshot.json
#   .claude/onboard-meta.json
#   .claude/walkthrough/
#   .claude/handoff/

set -euo pipefail

gitignore=".gitignore"

if [[ ! -f "$gitignore" ]]; then
  echo "::error::$gitignore not found at repo root" >&2
  exit 1
fi

required=(
  ".claude/onboard-snapshot.json"
  ".claude/onboard-meta.json"
  ".claude/walkthrough/"
  ".claude/handoff/"
)

missing=()
for entry in "${required[@]}"; do
  if ! grep -qxF "$entry" "$gitignore"; then
    missing+=("$entry")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  {
    echo "::error::.gitignore is missing required state-file / session-content entries:"
    printf '  %s\n' "${missing[@]}"
    echo ""
    echo "Add these lines to .gitignore — they persist wizard answers or session content that may contain secrets."
  } >&2
  exit 1
fi

echo "All required state-file / session-content entries are present in .gitignore"
