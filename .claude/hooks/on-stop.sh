#!/usr/bin/env bash
# on-stop.sh — Stop hook: remind to run /validate if plugin files were modified
# Always exits 0

# Check staged + unstaged changes and untracked files in plugin directories
MODIFIED_PLUGINS="$(git diff --name-only HEAD 2>/dev/null | grep -E '^(onboard|forge|observe|notify)/' | head -5)"
UNTRACKED_PLUGINS="$(git ls-files --others --exclude-standard 2>/dev/null | grep -E '^(onboard|forge|observe|notify)/' | head -5)"

if [[ -n "$MODIFIED_PLUGINS" ]] || [[ -n "$UNTRACKED_PLUGINS" ]]; then
  echo "REMINDER: Plugin files were modified during this session. Consider running /validate to check plugin structure and consistency."
fi

exit 0
