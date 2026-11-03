#!/usr/bin/env bash
# showMessage (2.1.0): false keeps Claude's text out of the OS notification and
# shows only the configured fallback message. It is read per event first, then
# from the top level of notify-config.json. Default true (Claude's text shown).
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

# Default: Claude's text is shown.
nt_make_sandbox '{ "events": { "stop": { "enabled": true, "message": "Done" } } }'
nt_run stop '{"last_assistant_message":"Refactor finished","session_id":"a"}'
grep -qx 'Refactor finished' "$ARGS" || nt_fail "by default the notification must show Claude's message"
nt_cleanup

# Top-level showMessage:false hides it.
nt_make_sandbox '{ "showMessage": false, "events": { "stop": { "enabled": true, "message": "Done" } } }'
nt_run stop '{"last_assistant_message":"Refactor finished","session_id":"b"}'
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "showMessage:false must still fire the notification"
grep -q 'Refactor finished' "$ARGS" && nt_fail "top-level showMessage:false must hide Claude's text"
grep -qx 'Done' "$ARGS" || nt_fail "showMessage:false must show the configured fallback message"
nt_cleanup

# A per-event value wins over the top level.
nt_make_sandbox '{ "showMessage": false, "events": { "stop": { "enabled": true, "message": "Done", "showMessage": true } } }'
nt_run stop '{"last_assistant_message":"Refactor finished","session_id":"c"}'
grep -qx 'Refactor finished' "$ARGS" || nt_fail "per-event showMessage:true must override the top-level false"
nt_cleanup

# Per-event false hides it for that event (notification text included).
nt_make_sandbox '{ "events": { "notification": { "enabled": true, "message": "Needs you", "showMessage": false } } }'
nt_run notification '{"message":"Claude needs your permission to use Bash","session_id":"d"}'
grep -q 'permission to use Bash' "$ARGS" && nt_fail "per-event showMessage:false must hide the notification text"
grep -qx 'Needs you' "$ARGS" || nt_fail "per-event showMessage:false must show the fallback message"

echo "PASS: notify showMessage hides Claude's text when false"
