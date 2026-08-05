#!/usr/bin/env bash
# Leading-edge INVARIANT (fork §6a): a suppressed event must NOT refresh the
# cooldown clock. This is the single property that separates leading-edge from
# trailing-edge — test_cooldown_leading_edge.sh pins the observable
# fire→suppress→fire sequence, but a trailing-edge implementation passes THAT
# identically (proven by lens 2026-07-06). Here we assert the invariant
# DETERMINISTICALLY, with no timing race: a huge window (minDurationSeconds=100)
# guarantees the second stop is suppressed regardless of scheduling jitter, and
# we read the clock file directly — under leading-edge its contents are
# unchanged; under trailing-edge the suppressed event would have re-stamped it
# to a later epoch (the `sleep 1` guarantees the epoch would differ).
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

nt_make_sandbox '{ "events": { "stop": { "enabled": true, "minDurationSeconds": 100 } } }'

nt_run stop '{"last_assistant_message":"1","session_id":"s"}'   # first stop → fires, stamps the clock
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "first stop must fire and stamp the cooldown clock"

TS_FILE="$SANDBOX/tmp/claude-notify-session-s"
[ -f "$TS_FILE" ] || nt_fail "cooldown clock file not created after the first fire ($TS_FILE)"
TS1="$(cat "$TS_FILE")"

sleep 1                                                          # ensure a re-stamp would carry a later epoch
nt_run stop '{"last_assistant_message":"2","session_id":"s"}'   # within the 100s window → suppressed
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "second stop within the window must be suppressed"

TS2="$(cat "$TS_FILE")"
[ "$TS1" = "$TS2" ] || nt_fail "LEADING-EDGE VIOLATION: a suppressed event refreshed the cooldown clock ($TS1 → $TS2) — that is trailing-edge (fork §6a). The refresh block must stay AFTER the suppression exit in notify.sh."
echo "PASS: notify leading-edge invariant (suppressed events do NOT refresh the clock)"
