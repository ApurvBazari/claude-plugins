#!/usr/bin/env bash
# Shared harness for the notify belt. NOT a test — run-all.sh skips lib.sh.
#
# Builds a sandbox mirroring the plugin layout (BASE_DIR=dirname/.., so
# notify.sh resolves CONFIG_FILE to our crafted config) and a curated PATH
# holding every binary notify.sh needs (jq included), plus notifier stubs that
# record each fire and its args. Set NT_NO_JQ=1 before nt_make_sandbox to leave
# jq out and exercise the no-jq path (defaults only, never fails).

nt_fail() { echo "FAIL: $1"; exit 1; }

# nt_make_sandbox <config-json-string>
# Sets globals: SANDBOX, NOTIFY, COUNT (fire log), ARGS (notifier args log), FARM (bin dir).
nt_make_sandbox() {
  local cfg="$1"
  local root src
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  src="$root/notify/scripts/notify.sh"
  [ -f "$src" ] || nt_fail "notify.sh missing at $src"

  SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t notify-test)"
  mkdir -p "$SANDBOX/scripts" "$SANDBOX/bin" "$SANDBOX/tmp"
  cp "$src" "$SANDBOX/scripts/notify.sh"
  NOTIFY="$SANDBOX/scripts/notify.sh"
  printf '%s\n' "$cfg" > "$SANDBOX/notify-config.json"

  COUNT="$SANDBOX/fired.log"; : > "$COUNT"
  ARGS="$SANDBOX/args.log";   : > "$ARGS"
  FARM="$SANDBOX/bin"

  # Curated PATH: symlink every binary notify.sh needs. Includes bash + sh so
  # `PATH=$FARM bash ...` and the stub shebangs resolve. python3 is deliberately
  # absent: notify.sh must not depend on it.
  local b p
  for b in bash sh env date cat mktemp mv rm basename dirname uname tr sed grep head id; do
    p="$(command -v "$b" 2>/dev/null)" && ln -s "$p" "$FARM/$b"
  done
  if [ "${NT_NO_JQ:-0}" != "1" ]; then
    p="$(command -v jq 2>/dev/null)" || nt_fail "jq is required to run the notify belt"
    ln -s "$p" "$FARM/jq"
  fi

  # Counter-stub the notifiers: log a fire + record args. Absolute shebang so
  # the curated PATH (which may lack env) still execs them.
  local n
  for n in terminal-notifier notify-send; do
    cat > "$FARM/$n" <<STUB
#!/bin/sh
echo fired >> "$COUNT"
printf '%s\n' "\$@" >> "$ARGS"
exit 0
STUB
    chmod +x "$FARM/$n"
  done
}

# nt_run <event> <stdin-json> — run the sandbox notify.sh under the curated
# PATH with an isolated TMPDIR (so the cooldown file can't collide with
# the real one). Returns notify.sh's exit code.
nt_run() {
  local event="$1" stdin="$2"
  TMPDIR="$SANDBOX/tmp" PATH="$FARM" bash "$NOTIFY" "$event" <<<"$stdin"
}

# nt_fired_count — number of times a notifier fired so far. `grep -c` prints "0"
# AND exits non-zero on zero matches, so capture-then-fallback to emit exactly
# one integer (a bare `|| echo 0` would double-print "0\n0" for the no-fire case).
nt_fired_count() { local n; n="$(grep -c fired "$COUNT" 2>/dev/null)" || n=0; echo "$n"; }

nt_cleanup() { [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"; }
