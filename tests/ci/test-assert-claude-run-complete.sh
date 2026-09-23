#!/usr/bin/env bash
# test-assert-claude-run-complete.sh — fixture belt for .github/scripts/assert-claude-run-complete.sh.
# Every failing case asserts BOTH the exit code and the ::error:: text, so a guard that
# exits 1 for the wrong reason (or 0 for every reason) cannot pass.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="${REPO_ROOT}/.github/scripts/assert-claude-run-complete.sh"
PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run_guard() {  # $1 conclusion, $2 execution file path ("" for none)
  CLAUDE_CONCLUSION="$1" CLAUDE_EXECUTION_FILE="$2" bash "$GUARD" 2>&1
}

expect() {  # $1 name, $2 want_rc, $3 want_substring ("" = must NOT contain ::error), $4 conclusion, $5 file
  local out rc
  out="$(run_guard "$4" "$5")"; rc=$?
  if [ "$rc" -ne "$2" ]; then fail "$1 (rc=$rc want $2; out=$out)"; return; fi
  if [ -z "$3" ]; then
    if printf '%s' "$out" | grep -q '::error'; then fail "$1 (unexpected ::error: $out)"; return; fi
  else
    if ! printf '%s' "$out" | grep -qF -- "$3"; then fail "$1 (missing '$3' in: $out)"; return; fi
    if ! printf '%s' "$out" | grep -q '^::error title=Claude run incomplete::'; then fail "$1 (no ::error line: $out)"; return; fi
  fi
  pass "$1"
}

printf '[{"type":"system","subtype":"init"},{"type":"result","subtype":"success","is_error":false,"num_turns":7}]' > "$tmp/ok.json"
printf '[{"type":"system","subtype":"init"},{"type":"result","subtype":"error_max_turns","is_error":false,"num_turns":12}]' > "$tmp/maxturns.json"
printf '[{"type":"system","subtype":"init"},{"type":"assistant"}]' > "$tmp/truncated.json"
printf '[]' > "$tmp/empty.json"
printf '[{"type":"result",' > "$tmp/malformed.json"

expect "success conclusion -> pass"                0 ""                            success ""
expect "success conclusion ignores a file"         0 ""                            success "$tmp/maxturns.json"
expect "empty conclusion, no file -> skip is red"  1 "no execution record"         ""      ""
expect "empty conclusion, missing path -> red"     1 "no execution record"         ""      "$tmp/does-not-exist.json"
expect "max turns -> red with subtype"             1 "subtype=error_max_turns"     ""      "$tmp/maxturns.json"
expect "max turns -> red with turn count"          1 "turns=12"                    ""      "$tmp/maxturns.json"
expect "stream ended early -> red"                 1 "no result message"           ""      "$tmp/truncated.json"
expect "empty record -> red"                       1 "empty execution record"      ""      "$tmp/empty.json"
expect "malformed record -> red"                   1 "unreadable execution record" ""      "$tmp/malformed.json"
expect "explicit failure conclusion -> red"        1 "conclusion=failure"          failure ""
expect "success record but empty conclusion -> red (conclusion is the authority)" 1 "subtype=success" "" "$tmp/ok.json"

echo "  guard: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
