#!/usr/bin/env bash
# F8 regression — a non-numeric minDurationSeconds must NOT silently drop the notification.
#
# notify.sh runs `set -uo pipefail`. Before the numeric guard, the duration check
# `[[ "$MIN_DURATION" -gt 0 ]]` evaluated a non-numeric value (e.g. a malformed config
# "minDurationSeconds": "abc") in an arithmetic context, hit the set -u unbound-variable
# trap, and aborted the hook BEFORE it fired — losing the notification with no trace.
# This test reproduces the mechanism and asserts the live script survives it.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
NOTIFY="$ROOT/notify/scripts/notify.sh"
fail(){ echo "FAIL: $1"; exit 1; }
[ -f "$NOTIFY" ] || fail "notify.sh missing at $NOTIFY"

SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t notify-test)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/scripts" "$SANDBOX/bin" "$SANDBOX/tmp"

# Mirror the plugin layout so notify.sh resolves CONFIG_FILE to our crafted config:
# BASE_DIR = dirname($0)/.. , CONFIG_FILE = BASE_DIR/notify-config.json.
cp "$NOTIFY" "$SANDBOX/scripts/notify.sh"

# Malformed config: stop enabled, but a NON-NUMERIC minDurationSeconds.
cat > "$SANDBOX/notify-config.json" <<'JSON'
{ "events": { "stop": { "enabled": true, "minDurationSeconds": "abc" } } }
JSON

# Stub the platform notifier (macOS terminal-notifier / Linux notify-send) so a fired
# notification leaves an observable trace instead of a real desktop popup.
SENTINEL="$SANDBOX/fired"
for n in terminal-notifier notify-send; do
  cat > "$SANDBOX/bin/$n" <<STUB
#!/usr/bin/env bash
: > "$SENTINEL"
exit 0
STUB
  chmod +x "$SANDBOX/bin/$n"
done

# Precondition: confirm the mechanism is real on this bash — the bare arithmetic test really
# does abort under set -u. Guards against a false PASS of the assertion below. If the bare
# test ever stops aborting, REACHED prints, the command exits 0, and we fail loudly here.
if bash -c 'set -uo pipefail; MIN_DURATION="abc"; if [[ "$MIN_DURATION" -gt 0 ]]; then :; fi; echo REACHED' \
     >/dev/null 2>&1; then
  fail "precondition: expected the bare arithmetic test to abort under set -u, but it did not"
fi

# Run the live script with the malformed config under set -u and assert it FIRES.
# TMPDIR points at the sandbox so the shared timestamp file is isolated from the real one.
rc=0
TMPDIR="$SANDBOX/tmp" PATH="$SANDBOX/bin:$PATH" \
  bash "$SANDBOX/scripts/notify.sh" stop <<<'{"last_assistant_message":"done"}' || rc=$?

[ "$rc" -eq 0 ] || fail "notify.sh must exit 0 (hook contract), got $rc"
[ -e "$SENTINEL" ] || fail "notification was silently dropped on malformed minDurationSeconds (F8 regression)"

echo "PASS: notify min-duration numeric guard"
