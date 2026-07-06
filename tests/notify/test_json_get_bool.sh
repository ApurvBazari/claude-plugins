#!/usr/bin/env bash
# N1 — json_get python3 fallback must emit lowercase booleans.
# On jq-less machines the fallback printed Python's "False", so ENABLED="False"
# never matched the lowercase gate (notify.sh:100) → an enabled:false event still
# fired. Here `stop` is DISABLED; a correct fallback must suppress it.
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

nt_make_sandbox '{ "events": { "stop": { "enabled": false, "minDurationSeconds": 0 } } }'
nt_run stop '{"last_assistant_message":"x","session_id":"s1"}'

c="$(nt_fired_count)"
[ "$c" -eq 0 ] || nt_fail "enabled:false must suppress on the python3 (jq-less) path; fired $c time(s) (N1)"
echo "PASS: notify json_get boolean normalization (N1)"
