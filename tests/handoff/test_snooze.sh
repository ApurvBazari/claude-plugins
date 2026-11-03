#!/usr/bin/env bash
# snooze.sh ("Save for later") writes deferred-at, sets the marker to now + the snooze
# window, and the hook then stays silent. Checked end to end with the real hook.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SNOOZE="$REPO_ROOT/handoff/scripts/snooze.sh"
# shellcheck disable=SC1091
. "$HERE/lib.sh"
# shellcheck source=/dev/null
. "$REPO_ROOT/handoff/scripts/handoff-lib.sh"

marker_offset_h() { # hours from now to the marker's mtime (rounded)
  local m; m="$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1")"
  echo $(( (m - $(date +%s) + 1800) / 3600 ))
}

# --- default window: 24h ---
setup_fake_project >/dev/null
write_active_handoff "2026-10-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
out="$(bash "$SNOOZE" "$FIXTURE_ROOT")"
assert_contains "snoozed-until=" "$out" "prints snoozed-until"
assert_eq "24" "$(marker_offset_h "$FIXTURE_ROOT/.claude/handoff/snooze-until")" "default window is 24h"
deferred="$(hf_get_fm_value "$FIXTURE_ROOT/.claude/handoff/active.md" deferred-at)"
assert_eq "1" "$([[ "$(hf_iso_to_epoch "$deferred")" -gt 0 ]] && echo 1 || echo 0)" "deferred-at written as an ISO timestamp"
assert_eq "abc1234" "$(hf_get_fm_value "$FIXTURE_ROOT/.claude/handoff/active.md" saved-at-sha)" "other frontmatter kept"
assert_contains "Test directive body." "$(cat "$FIXTURE_ROOT/.claude/handoff/active.md")" "body kept"
assert_eq "" "$(run_hook_in "$FIXTURE_ROOT")" "hook silent after Save for later"
cleanup

# --- settings override, and a hostile / huge value ---
setup_fake_project >/dev/null
write_active_handoff "2026-10-01T00:00:00Z" "abc1234" "main" "$FIXTURE_ROOT"
printf -- '---\ndeferral-snooze-hours: 2\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
bash "$SNOOZE" "$FIXTURE_ROOT" >/dev/null
assert_eq "2" "$(marker_offset_h "$FIXTURE_ROOT/.claude/handoff/snooze-until")" "deferral-snooze-hours: 2 honored"
# shellcheck disable=SC2016  # the $(…) is deliberately literal: it must never run
printf -- '---\ndeferral-snooze-hours: $(touch pwned)\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
(cd "$FIXTURE_ROOT" && bash "$SNOOZE" "$FIXTURE_ROOT" >/dev/null)
assert_eq "24" "$(marker_offset_h "$FIXTURE_ROOT/.claude/handoff/snooze-until")" "non-integer setting → default 24h"
assert_file_absent "$FIXTURE_ROOT/pwned"
printf -- '---\ndeferral-snooze-hours: 999999\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
bash "$SNOOZE" "$FIXTURE_ROOT" >/dev/null
assert_eq "8760" "$(marker_offset_h "$FIXTURE_ROOT/.claude/handoff/snooze-until")" "window capped at one year"
printf -- '---\ndeferral-snooze-hours: 08\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
bash "$SNOOZE" "$FIXTURE_ROOT" >/dev/null
assert_eq "8" "$(marker_offset_h "$FIXTURE_ROOT/.claude/handoff/snooze-until")" "zero-padded 08 → 8h, not read as octal"
printf -- '---\ndeferral-snooze-hours: 0\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
bash "$SNOOZE" "$FIXTURE_ROOT" >/dev/null
assert_contains "handoff:pickup" "$(run_hook_in "$FIXTURE_ROOT")" "0h window → hook announces again"
cleanup

# --- no active handoff ---
setup_fake_project >/dev/null
rc=0; bash "$SNOOZE" "$FIXTURE_ROOT" >/dev/null 2>&1 || rc=$?
assert_eq "3" "$rc" "no active handoff → exit 3"
assert_file_absent "$FIXTURE_ROOT/.claude/handoff/snooze-until"
cleanup

summary
