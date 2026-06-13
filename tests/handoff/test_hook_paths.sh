#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

trap cleanup EXIT
setup_fake_project >/dev/null

# Active handoff at the NEW path.
write_active_handoff "2026-05-20T10:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"

# Run the hook with the cwd-providing stdin contract.
out="$(printf '{"cwd": "%s"}' "$FIXTURE_ROOT" | bash "$REPO_ROOT/handoff/hooks/session-start.sh")"

# The hook should surface our directive AND the new path in its routing instruction.
assert_contains "Test directive body." "$out" "hook surfaces directive from .claude/handoff/active.md"
assert_contains ".claude/handoff/active.md" "$out" "routing instruction references new path"
assert_contains "saved-at-sha: abc1234" "$out" "metadata block emitted"

summary
