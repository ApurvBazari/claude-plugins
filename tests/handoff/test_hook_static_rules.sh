#!/usr/bin/env bash
# Pins the directory review rules for a plugin that lives in a subfolder of its
# repository (claude.com/docs/plugins/pre-submission-checklist): a script a hook runs
# must contain no shell variables other than ${CLAUDE_PLUGIN_ROOT}, no command
# substitution, no calls to other files in the plugin, and no package launchers.
# Breaking any of these holds the plugin for a reviewer ("Scripts the validator
# couldn't follow").
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
HOOK="$REPO_ROOT/handoff/hooks/session-start.sh"
fail(){ echo "FAIL: $1"; exit 1; }
[ -f "$HOOK" ] || fail "missing $HOOK"

# Code lines only (comments may explain the rules in prose).
code="$(grep -v -E '^[[:space:]]*(#|$)' "$HOOK")"

printf '%s\n' "$code" | grep -q '\$' && fail "hook script uses a shell variable or \$(…): $(printf '%s\n' "$code" | grep '\$' | head -1)"
printf '%s\n' "$code" | grep -q '`' && fail "hook script uses backtick command substitution"
printf '%s\n' "$code" | grep -q -E '(^|[[:space:];&|])(\.|source)[[:space:]]' && fail "hook script sources another file"
printf '%s\n' "$code" | grep -q -E 'scripts/|\.sh\b' && fail "hook script calls another file in the plugin"
printf '%s\n' "$code" | grep -q -E '\b(npx|bunx|uvx|pipx|pnpm|yarn|uv|npm|pip3?|curl|wget)\b' && fail "hook script runs a package launcher or a network tool"
printf '%s\n' "$code" | grep -q -E '(cat|head|tail|sed|awk|less|more)[[:space:]].*active\.md' && fail "hook script reads the handoff file's contents"

echo "PASS: handoff hook follows the subfolder-script rules"
