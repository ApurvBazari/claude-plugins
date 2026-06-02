#!/usr/bin/env bash
# Read-only git context for walkthrough generation. Emits a small JSON object.
# Usage: collect-git-context.sh [dir]   (defaults to cwd). Always exits 0.
# No -e on purpose: this must never abort the skill — on any git failure it
# degrades to partial/empty JSON rather than failing (see CLAUDE.md § Script safety).
set -uo pipefail

DIR="${1:-$PWD}"
cd "$DIR" 2>/dev/null || { printf '{"in_repo": false}\n'; exit 0; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '{"in_repo": false}\n'; exit 0
fi

# JSON-escape: backslashes first (git quotes paths with \), then double quotes.
jesc='s/\\/\\\\/g; s/"/\\"/g'
branch="$(git branch --show-current 2>/dev/null | sed "$jesc" || echo unknown)"
changed="$(git status --porcelain 2>/dev/null | head -50 | sed "$jesc" | awk '{printf "%s\"%s\"", (NR>1?",":""), $0}')"
diffstat="$(git diff --stat 2>/dev/null | tail -1 | sed "$jesc" | tr -d '\n')"
log="$(git log --oneline -15 2>/dev/null | sed "$jesc" | awk '{printf "%s\"%s\"", (NR>1?",":""), $0}')"

printf '{"in_repo": true, "branch": "%s", "diffstat": "%s", "changed_files": [%s], "recent_log": [%s]}\n' \
  "$branch" "$diffstat" "$changed" "$log"
exit 0
