#!/usr/bin/env bash
# N2 — two concurrent sessions must keep independent cooldown clocks.
# With per-UID keying (pre-fix) session s2's first stop is suppressed by the
# timestamp s1 just wrote. With per-session keying both fire.
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

nt_make_sandbox '{ "events": { "stop": { "enabled": true, "minDurationSeconds": 30 } } }'
nt_run stop '{"last_assistant_message":"a","session_id":"s1"}'   # first for s1 → fires
nt_run stop '{"last_assistant_message":"b","session_id":"s2"}'   # first for s2 → must fire

c="$(nt_fired_count)"
[ "$c" -eq 2 ] || nt_fail "concurrent sessions share a cooldown clock; expected 2 fires, got $c (N2)"
echo "PASS: notify per-session cooldown isolation (N2)"
