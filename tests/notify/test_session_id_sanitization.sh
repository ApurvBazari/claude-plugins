#!/usr/bin/env bash
# N2 security: the session_id arrives in hook stdin JSON (externally influenced)
# and is interpolated into the cooldown TIMESTAMP_FILE path. notify.sh sanitizes
# it with `tr -c 'A-Za-z0-9._-' '_'` before use. This test drives an adversarial
# session_id containing path separators + shell metacharacters and asserts the
# hook (a) still fires without crashing and (b) creates its clock file as a flat
# entry INSIDE the sandbox TMPDIR — never traversing out of it. A regression that
# dropped or weakened the sanitizer (e.g. left `/` intact) would write outside
# TMPDIR and this test would catch it.
set -uo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
trap nt_cleanup EXIT

nt_make_sandbox '{ "events": { "stop": { "enabled": true, "minDurationSeconds": 0 } } }'

# Path traversal + space + shell metacharacters in the session_id (valid JSON).
nt_run stop '{"last_assistant_message":"x","session_id":"../../../../etc/pwn ; rm -rf /"}'

[ "$(nt_fired_count)" -eq 1 ] || nt_fail "hook must still fire with an adversarial session_id (no crash)"

# The clock file must exist as a direct child of the sandbox TMPDIR.
found="$(find "$SANDBOX/tmp" -maxdepth 1 -name 'claude-notify-*' 2>/dev/null | head -1)"
[ -n "$found" ] || nt_fail "no cooldown clock file created for the sanitized session_id"
[ "$(dirname "$found")" = "$SANDBOX/tmp" ] || nt_fail "sanitizer failed: clock file is not a direct child of TMPDIR ($found)"

# No claude-notify file may have escaped TMPDIR (path traversal) — scan the whole
# sandbox and confirm nothing landed outside $SANDBOX/tmp/.
leaked="$(find "$SANDBOX" -name 'claude-notify-*' 2>/dev/null | grep -v "^$SANDBOX/tmp/" || true)"
[ -z "$leaked" ] || nt_fail "path traversal: a cooldown file escaped TMPDIR ($leaked)"

# The sanitized basename must carry no surviving path separator.
case "$(basename "$found")" in
  */*) nt_fail "sanitized filename still contains a path separator ($found)" ;;
esac

echo "PASS: notify session_id sanitization (adversarial id stays a flat file inside TMPDIR)"
