#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

trap cleanup EXIT
setup_fake_project >/dev/null

# Seed 12 pre-existing archives.
for i in $(seq 1 12); do
  : > "$FIXTURE_ROOT/.claude/handoff/archive/consumed-$(printf '%05d' "$i").md"
done

# Default retention is 10 (no settings.md). Hook stale-archive will add one
# new file (expired-<ts>.md) → 13 total → prune should leave 10.

# Saved 200 days ago.
saved_at="$(date -u -d "200 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -v-200d +%Y-%m-%dT%H:%M:%SZ)"
write_active_handoff "$saved_at" "abc1234" "main" "$FIXTURE_ROOT"

printf '{"cwd": "%s"}' "$FIXTURE_ROOT" | bash "$REPO_ROOT/handoff/hooks/session-start.sh" >/dev/null

count="$(find "$FIXTURE_ROOT/.claude/handoff/archive" -name '*.md' | wc -l | tr -d ' ')"
assert_eq "10" "$count" "stale sweep then prune leaves exactly 10 archives"
# Verify archive directory was not removed by prune (prune only removes files).
if [[ -d "$FIXTURE_ROOT/.claude/handoff/archive" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: archive/ directory still exists after prune"
else
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: archive/ directory missing after prune"
fi

# The freshly written expired-* file must be one of the survivors.
expired_present="$(find "$FIXTURE_ROOT/.claude/handoff/archive" -name 'expired-*.md' | wc -l | tr -d ' ')"
assert_eq "1" "$expired_present" "newly-written expired-*.md survives the prune"

summary
