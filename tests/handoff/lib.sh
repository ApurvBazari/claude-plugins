#!/usr/bin/env bash
# Shared helpers for handoff bash tests.
# Usage from a test: `. "$(dirname "$0")/lib.sh"` then `setup_fake_project`.

set -uo pipefail

FIXTURE_ROOT=""
PASS_COUNT=0
FAIL_COUNT=0

setup_fake_project() {
  FIXTURE_ROOT="$(mktemp -d 2>/dev/null || mktemp -d -t handoff-test)"
  mkdir -p "$FIXTURE_ROOT/.claude/handoff/archive"
  # Initialize a git repo so the hook's git probes do not crash.
  (cd "$FIXTURE_ROOT" && git init -q && git commit -q --allow-empty -m "init")
  echo "$FIXTURE_ROOT"
}

cleanup() {
  [[ -n "$FIXTURE_ROOT" && -d "$FIXTURE_ROOT" ]] && rm -rf "$FIXTURE_ROOT"
  FIXTURE_ROOT=""
}

write_active_handoff() {
  # Usage: write_active_handoff <iso8601> <sha> <branch> <cwd> [<deferred-at>]
  local saved_at="$1" sha="$2" branch="$3" cwd="$4" deferred="${5:-}"
  {
    echo "---"
    echo "saved-at: $saved_at"
    echo "saved-at-sha: $sha"
    echo "saved-at-branch: $branch"
    echo "saved-from-cwd: $cwd"
    [[ -n "$deferred" ]] && echo "deferred-at: $deferred"
    echo "---"
    echo "Test directive body."
  } > "$FIXTURE_ROOT/.claude/handoff/active.md"
}

assert_eq() {
  # Usage: assert_eq <expected> <actual> <label>
  if [[ "$1" == "$2" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  ok: $3"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  FAIL: $3"
    echo "       expected: $1"
    echo "       actual:   $2"
  fi
}

assert_file_exists() {
  if [[ -f "$1" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: exists $1"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: missing $1"
  fi
}

assert_file_absent() {
  if [[ ! -e "$1" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: absent $1"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: present (should be absent) $1"
  fi
}

assert_contains() {
  # Usage: assert_contains <needle> <haystack> <label>
  if printf '%s' "$2" | grep -q -F -- "$1"; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: $3"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  FAIL: $3"
    echo "       needle:   $1"
    echo "       haystack: $(printf '%s' "$2" | head -c 200)..."
  fi
}

summary() {
  echo
  echo "Pass: $PASS_COUNT  Fail: $FAIL_COUNT"
  [[ "$FAIL_COUNT" -gt 0 ]] && exit 1
  exit 0
}
