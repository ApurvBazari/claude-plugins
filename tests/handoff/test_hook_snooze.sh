#!/usr/bin/env bash
# Snooze: the hook stays silent while .claude/handoff/snooze-until's mtime is in the
# future, and announces otherwise. A deferred-at with no marker (a 1.0.x snooze, or a
# hand-edited value) never suppresses the handoff (the H9 "no forever-suppress" rule).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

iso() { # <seconds-offset-from-now>  → ISO-8601 UTC
  local off="$1"
  if date -u -d "@$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :; \
  else date -u -r "$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ; fi
}

# Case A: marker 23h ahead → SILENT
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso -3600)"
set_snooze_marker "$FIXTURE_ROOT" 82800
assert_eq "" "$(run_hook_in "$FIXTURE_ROOT")" "A: marker in the future → hook silent (snoozed)"
cleanup

# Case B: marker 1h in the past → window over → ANNOUNCES
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso -90000)"
set_snooze_marker "$FIXTURE_ROOT" -3600
assert_contains "handoff:pickup" "$(run_hook_in "$FIXTURE_ROOT")" "B: marker in the past → hook announces"
cleanup

# Case C: deferred-at 1h ago but NO marker → ANNOUNCES (deferred-at alone never snoozes)
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso -3600)"
assert_contains "handoff:pickup" "$(run_hook_in "$FIXTURE_ROOT")" "C: deferred-at without marker → hook announces"
cleanup

# Case D: deferred-at far in the FUTURE, no marker → ANNOUNCES (H9: no forever-suppress)
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso 259200)"
assert_contains "handoff:pickup" "$(run_hook_in "$FIXTURE_ROOT")" "D: future deferred-at → hook announces"
cleanup

# Case E: a marker with no active handoff → SILENT (nothing to announce)
FIXTURE_ROOT="$(setup_fake_project)"
set_snooze_marker "$FIXTURE_ROOT" -3600
assert_eq "" "$(run_hook_in "$FIXTURE_ROOT")" "E: marker but no active.md → hook silent"
cleanup

summary
