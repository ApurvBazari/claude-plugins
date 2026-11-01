#!/usr/bin/env bash
# Config and input parsing (2.1.0): notify.sh reads JSON with jq only, one jq
# call per document, and never needs python3.
#  1. N1 still holds on the jq path: enabled:false suppresses the event.
#  2. Without jq the hook exits 0, skips parsing and fires with the per-event
#     default fallback text; the default-off subagentStop stays off.
#  3. The hook prints nothing to stdout (it runs as an async hook).
#  4. No python3 anywhere in the script.
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'python3' "$ROOT/notify/scripts/notify.sh" && nt_fail "notify.sh must not use python3 (inline programs were removed in 2.1.0)"

# 1 — jq path honours enabled:false (N1).
nt_make_sandbox '{ "events": { "stop": { "enabled": false, "minDurationSeconds": 0 } } }'
out="$(nt_run stop '{"last_assistant_message":"x","session_id":"s1"}')"
[ "$(nt_fired_count)" -eq 0 ] || nt_fail "enabled:false must suppress the event on the jq path (N1)"
[ -z "$out" ] || nt_fail "notify.sh must print nothing to stdout (async hook); got: $out"
nt_cleanup

# 2 — no jq: defaults only, never fails, Claude's text is not parsed.
NT_NO_JQ=1 nt_make_sandbox '{ "events": { "stop": { "enabled": true } } }'
rc=0; out="$(nt_run stop '{"last_assistant_message":"secret text","session_id":"s2"}')" || rc=$?
[ "$rc" -eq 0 ] || nt_fail "notify.sh must exit 0 without jq, got $rc"
[ -z "$out" ] || nt_fail "notify.sh must print nothing to stdout without jq; got: $out"
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "stop must still fire without jq (per-event default: enabled)"
grep -qx 'Task completed' "$ARGS" || nt_fail "without jq the notification must carry the default fallback text"
grep -q 'secret text' "$ARGS" && nt_fail "without jq the hook input must not be parsed"
nt_run subagentStop '{"last_assistant_message":"y"}' >/dev/null
[ "$(nt_fired_count)" -eq 1 ] || nt_fail "subagentStop is off by default and must stay off without jq"

echo "PASS: notify config parsing (jq only, safe no-jq fallback, silent stdout)"
