#!/usr/bin/env bash
# archive-active.sh: the one path that archives the active handoff (pickup Execute /
# Discard / stale, and /handoff:discard). Covers naming, the snooze-marker cleanup,
# retention after a stale sweep (formerly test_hook_prune_after_stale.sh), and the
# refusal paths. The stale archive moved here from the SessionStart hook in 1.1.0.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
ARCH="$REPO_ROOT/handoff/scripts/archive-active.sh"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

# --- Case 1: stale sweep then prune leaves exactly 10, and the new expired-* survives ---
setup_fake_project >/dev/null
for i in $(seq 1 12); do
  : > "$FIXTURE_ROOT/.claude/handoff/archive/consumed-$(printf '%05d' "$i").md"
  touch -d "2020-01-01T00:$(printf '%02d' "$i"):00Z" "$FIXTURE_ROOT/.claude/handoff/archive/consumed-$(printf '%05d' "$i").md"
done
write_active_handoff "2020-01-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
set_snooze_marker "$FIXTURE_ROOT" 3600
path="$(bash "$ARCH" "$FIXTURE_ROOT" expired)"
assert_contains ".claude/handoff/archive/expired-" "$path" "prints the expired archive path"
assert_file_absent "$FIXTURE_ROOT/.claude/handoff/active.md"
assert_file_exists "$FIXTURE_ROOT/$path"
assert_file_absent "$FIXTURE_ROOT/.claude/handoff/snooze-until"
count="$(find "$FIXTURE_ROOT/.claude/handoff/archive" -name '*.md' | wc -l | tr -d ' ')"
assert_eq "10" "$count" "stale sweep then prune leaves exactly 10 archives"
assert_eq "1" "$(find "$FIXTURE_ROOT/.claude/handoff/archive" -name 'expired-*.md' | wc -l | tr -d ' ')" "newly-written expired-*.md survives the prune"
cleanup

# --- Case 2: consumed / discarded naming, same-second collisions get a suffix ---
setup_fake_project >/dev/null
write_active_handoff "2026-10-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
p1="$(bash "$ARCH" "$FIXTURE_ROOT" consumed)"
assert_contains "archive/consumed-" "$p1" "consumed archive name"
write_active_handoff "2026-10-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
p2="$(bash "$ARCH" "$FIXTURE_ROOT" discarded)"
assert_contains "archive/discarded-" "$p2" "discarded archive name"
write_active_handoff "2026-10-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
p3="$(bash "$ARCH" "$FIXTURE_ROOT" discarded)"
if [[ "$p2" != "$p3" && -f "$FIXTURE_ROOT/$p2" && -f "$FIXTURE_ROOT/$p3" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: two archives never overwrite each other"
else
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: archive collision ($p2 vs $p3)"
fi
cleanup

# --- Case 3: refusals ---
setup_fake_project >/dev/null
rc=0; bash "$ARCH" "$FIXTURE_ROOT" consumed >/dev/null 2>&1 || rc=$?
assert_eq "3" "$rc" "no active handoff → exit 3"
write_active_handoff "2026-10-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
rc=0; bash "$ARCH" "$FIXTURE_ROOT" 'x;rm -rf' >/dev/null 2>&1 || rc=$?
assert_eq "2" "$rc" "unknown kind → exit 2"
assert_file_exists "$FIXTURE_ROOT/.claude/handoff/active.md"
cleanup

summary
