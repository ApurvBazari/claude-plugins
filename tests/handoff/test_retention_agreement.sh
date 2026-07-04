#!/usr/bin/env bash
# H6 pin: compute-progress's displayed retention_value and prune-archive's actual
# behavior must AGREE on every documented value — especially `null`, where the
# audit found compute-progress collapsed to 10 while prune treated it as unlimited.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib.sh"

check_case() {
  # <retention-setting> <expected-display> <expect-prune-keeps-all: 1|0>
  local setting="$1" expect_display="$2" keeps_all="$3"
  local root; root="$(setup_fake_project)"
  printf -- '---\narchive-retention: %s\n---\n' "$setting" \
    > "$root/.claude/handoff/settings.md"
  # Seed 3 archive files.
  for n in 1 2 3; do echo x > "$root/.claude/handoff/archive/consumed-000$n.md"; done

  eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$root")"
  # retention_value is assigned dynamically by the eval'd script output — that is
  # the exact contract under test, so SC2154 "referenced but not assigned" is a
  # false positive here.
  # shellcheck disable=SC2154
  assert_eq "$expect_display" "$retention_value" "display($setting) = $expect_display"

  bash "$REPO_ROOT/handoff/scripts/prune-archive.sh" "$root"
  local remaining; remaining="$(find "$root/.claude/handoff/archive" -name '*.md' | wc -l | tr -d ' ')"
  if [[ "$keeps_all" == "1" ]]; then
    assert_eq "3" "$remaining" "prune($setting) keeps all 3"
  else
    assert_eq "0" "$remaining" "prune($setting) deletes all"
  fi
  # cleanup (from lib.sh, sourced above) reads FIXTURE_ROOT to rm the fixture;
  # setup_fake_project ran in a command-subst subshell so its global assignment
  # did not reach us — set it here. SC2034 is a false positive (source not followed).
  # shellcheck disable=SC2034
  FIXTURE_ROOT="$root"; cleanup
}

check_case unlimited unlimited 1
check_case null      unlimited 1     # the H6 bug: must be unlimited, not 10
check_case -1        unlimited 1
check_case 0         0         0     # 0 = delete-all

summary
