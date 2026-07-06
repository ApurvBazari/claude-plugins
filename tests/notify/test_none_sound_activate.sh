#!/usr/bin/env bash
# N3 — a representable "none" must let a user turn OFF sound / app-activation.
# Force the macOS send path (stub uname → Darwin) so terminal-notifier is the
# notifier; then assert the recorded args omit -sound and -activate.
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

nt_make_sandbox '{ "events": { "stop": { "enabled": true, "minDurationSeconds": 0, "sound": "none", "activate": "none" } } }'
printf '#!/bin/sh\necho Darwin\n' > "$FARM/uname"; chmod +x "$FARM/uname"   # force macOS send path

nt_run stop '{"last_assistant_message":"x","session_id":"s"}'
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "notification should still fire with sound/activate none"
grep -qx -- '-sound'    "$ARGS" && nt_fail "sound:none must omit the -sound flag (N3)"
grep -qx -- '-activate' "$ARGS" && nt_fail "activate:none must omit the -activate flag (N3)"
echo "PASS: notify representable none for sound/activate (N3)"
