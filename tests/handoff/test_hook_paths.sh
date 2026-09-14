#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

trap cleanup EXIT
setup_fake_project >/dev/null

# Active handoff at the NEW path. saved-at must stay inside the hook's 90-day stale
# window, or the hook archives the fixture instead of surfacing it and every assertion
# below fails on a date rather than on behavior. Derive it relative to now — as
# test_hook_stale.sh and test_hook_snooze.sh already do — never pin a literal date.
saved_at="$(date -u -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)"
write_active_handoff "$saved_at" "abc1234" "main" "$FIXTURE_ROOT"

# Run the hook with the cwd-providing stdin contract.
out="$(printf '{"cwd": "%s"}' "$FIXTURE_ROOT" | bash "$REPO_ROOT/handoff/hooks/session-start.sh")"

# The hook should surface our directive AND the new path in its routing instruction.
assert_contains "Test directive body." "$out" "hook surfaces directive from .claude/handoff/active.md"
assert_contains ".claude/handoff/active.md" "$out" "routing instruction references new path"
assert_contains "saved-at-sha: abc1234" "$out" "metadata block emitted"

summary
