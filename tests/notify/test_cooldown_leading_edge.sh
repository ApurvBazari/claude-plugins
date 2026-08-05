#!/usr/bin/env bash
# Leading-edge cooldown contract (fork resolution §6a): a notification fires,
# then further stops are suppressed until N seconds pass since the FIRED one,
# then the next fires.
#
# Sizing the window: the belt drives notify.sh through its jq-less python3
# fallback (lib.sh deliberately omits jq), so each nt_run costs ~0.8s of wall
# time. Cooldown granularity is whole seconds (date +%s), so the window
# (minDurationSeconds) must sit comfortably ABOVE that per-run cost — otherwise
# the "immediate" second stop lands a whole second later and reads as elapsed,
# not suppressed. 3s window + a 4s sleep leaves a ~2s margin on both the
# suppress side and the fire side, keeping the characterization deterministic.
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

nt_make_sandbox '{ "events": { "stop": { "enabled": true, "minDurationSeconds": 3 } } }'

nt_run stop '{"last_assistant_message":"1","session_id":"s"}'   # fire (1)
nt_run stop '{"last_assistant_message":"2","session_id":"s"}'   # within window → suppress
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "second stop within the cooldown window must be suppressed"

sleep 4
nt_run stop '{"last_assistant_message":"3","session_id":"s"}'   # past window → fire (2)
[ "$(nt_fired_count)" -eq 2 ] || nt_fail "a stop past the cooldown window must fire"

echo "PASS: notify leading-edge cooldown (fire → suppress → fire)"
