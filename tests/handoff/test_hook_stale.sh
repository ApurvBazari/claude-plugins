#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

trap cleanup EXIT
setup_fake_project >/dev/null

# Saved 200 days ago — well past the 90-day default threshold.
saved_at="$(date -u -d "200 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -v-200d +%Y-%m-%dT%H:%M:%SZ)"
write_active_handoff "$saved_at" "abc1234" "main" "$FIXTURE_ROOT"

out="$(printf '{"cwd": "%s"}' "$FIXTURE_ROOT" | bash "$REPO_ROOT/handoff/hooks/session-start.sh")"

# active.md should be moved out, an archive file should exist under the new path.
assert_file_absent "$FIXTURE_ROOT/.claude/handoff/active.md"

archive_count="$(find "$FIXTURE_ROOT/.claude/handoff/archive" -name 'expired-*.md' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "1" "$archive_count" "exactly one expired archive under .claude/handoff/archive/"

# Stale-archive message should reference the new archive directory.
assert_contains ".claude/handoff/archive/expired-" "$out" "stale message references new archive path"

summary
