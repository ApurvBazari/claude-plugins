#!/usr/bin/env bash
# Regression tests for handoff/scripts/compute-progress.sh.
#
# Anchors the eval-safety contract: the check skill bash-eval's this
# script's stdout, so any caller-controlled value emitted here MUST be
# quoted such that bash re-evaluation cannot perform command substitution.
# The retention field is read directly from settings.md frontmatter and
# is therefore the most exposed surface.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/handoff/scripts/compute-progress.sh"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

trap cleanup EXIT
setup_fake_project >/dev/null

write_settings() {
  mkdir -p "$FIXTURE_ROOT/.claude/handoff"
  cat > "$FIXTURE_ROOT/.claude/handoff/settings.md" <<EOF
---
archive-retention: $1
---
EOF
}

# Run the script and bash-eval its output in a subshell, echoing the
# resolved retention_value so the parent shell can assert without
# polluting its own scope. retention_value is assigned dynamically by
# the eval'd script output — that is the exact contract under test, so
# the SC2154 "referenced but not assigned" warning is a false positive.
# shellcheck disable=SC2154
run_eval() {
  ( eval "$(bash "$SCRIPT" "$FIXTURE_ROOT")"; echo "$retention_value" )
}

canary_dir="$(mktemp -d)"

# Case 1: $(...) substitution must not execute
write_settings "\$(touch $canary_dir/pwned-dollar && echo 99)"
got="$(run_eval)"
assert_eq "10" "$got" "command substitution defaults to 10"
if [[ ! -e "$canary_dir/pwned-dollar" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: command substitution did not execute"
else
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: command substitution executed"
fi

# Case 2: backtick substitution must not execute
write_settings "\`touch $canary_dir/pwned-backtick\`"
got="$(run_eval)"
assert_eq "10" "$got" "backtick substitution defaults to 10"
if [[ ! -e "$canary_dir/pwned-backtick" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: backticks did not execute"
else
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: backticks executed"
fi

# Case 3: happy path — integer 5
write_settings "5"
assert_eq "5" "$(run_eval)" "happy path: integer 5"

# Case 4: happy path — 0 (every-write-prunes mode per CLAUDE.md)
write_settings "0"
assert_eq "0" "$(run_eval)" "happy path: 0 preserved"

# Case 5: happy path — unlimited
write_settings "unlimited"
assert_eq "unlimited" "$(run_eval)" "happy path: unlimited preserved"

# Case 6: happy path — -1 (synonym for unlimited)
write_settings "-1"
assert_eq "-1" "$(run_eval)" "happy path: -1 preserved"

# Case 7: garbage value collapses to default
write_settings "bogus"
assert_eq "10" "$(run_eval)" "garbage value defaults to 10"

# Case 8: empty value collapses to default
write_settings ""
assert_eq "10" "$(run_eval)" "empty value defaults to 10"

# Case 9: no settings file at all defaults to 10
rm -f "$FIXTURE_ROOT/.claude/handoff/settings.md"
assert_eq "10" "$(run_eval)" "absent settings.md defaults to 10"

rm -rf "$canary_dir"

echo
echo "Pass: $PASS_COUNT  Fail: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
