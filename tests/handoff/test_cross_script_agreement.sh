#!/usr/bin/env bash
# H2 pin: compute-progress.sh must NOT re-read frontmatter keys from the directive
# BODY when the body contains a `---` horizontal rule. The old naive `/^---/` toggle
# in compute-progress re-entered "frontmatter mode" on a body hr and mis-read a
# body-decoy `deferred-at:` line — silently snoozing (suppressing) the handoff.
# After consolidation onto hf_get_fm_value (which stops at the 2nd `---`), the body
# is ignored. Since 1.1.0 the snooze is the marker file, so a body decoy cannot
# snooze at all; the assertions below still pin the H2 parser fix.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib.sh"

FIXTURE_ROOT="$(setup_fake_project)"
# Directive body deliberately contains a `---` hr AND decoy `deferred-at:` /
# `saved-at-branch:` lines. Both keys are ABSENT from this frontmatter, so a buggy
# parser's body-read is observable: it would set branch_changed (and deferred-at).
cat > "$FIXTURE_ROOT/.claude/handoff/active.md" <<'EOF'
---
saved-at: 2026-06-01T10:00:00Z
saved-at-sha: deadbee
saved-from-cwd: /tmp/x
---
First body line.

---

deferred-at: 2099-01-01T00:00:00Z
saved-at-branch: decoy-branch
EOF

# compute-progress must NOT pick up the body decoys. A buggy fm_get re-enters
# frontmatter mode on the body `---` and reads saved-at-branch=decoy-branch →
# branch_changed "yes". The shared reader stops at the 2nd `---` → no branch →
# "unknown"; and with no snooze marker the display is "not snoozed".
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
# branch_changed / snooze_remaining are assigned dynamically by the eval'd script
# output — that is the exact contract under test, so SC2154 is a false positive.
# shellcheck disable=SC2154
assert_eq "unknown" "$branch_changed" "compute-progress ignores a body-decoy saved-at-branch (H2)"
# shellcheck disable=SC2154
assert_eq "not snoozed" "$snooze_remaining" "body-decoy deferred-at does not snooze"

# Direct parity: the shared reader returns the REAL saved-at, ignoring the body decoy.
# shellcheck source=/dev/null
. "$REPO_ROOT/handoff/scripts/handoff-lib.sh"
assert_eq "2026-06-01T10:00:00Z" \
  "$(hf_get_fm_value "$FIXTURE_ROOT/.claude/handoff/active.md" saved-at)" \
  "hf_get_fm_value ignores body decoy"
assert_eq "" "$(hf_get_fm_value "$FIXTURE_ROOT/.claude/handoff/active.md" deferred-at)" \
  "hf_get_fm_value: body-decoy deferred-at is not frontmatter"

cleanup

# ---- Snooze parity: the hook and compute-progress read the SAME marker test ----
# The SessionStart hook decides "snoozed" with `find snooze-until -newermt now`;
# compute-progress must agree in both directions, and a deferred-at without a marker
# (including a future one, the H9 case) must read as not snoozed on both sides.
iso() { # <seconds-offset-from-now> → ISO-8601 UTC
  local off="$1"
  if date -u -d "@$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :; \
  else date -u -r "$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ; fi
}

check_parity() { # <label> <marker-offset-seconds|none> <deferred-at-offset|none> <expect: silent|announce>
  local label="$1" moff="$2" doff="$3" expect="$4" deferred=""
  FIXTURE_ROOT="$(setup_fake_project)"
  [[ "$doff" != none ]] && deferred="$(iso "$doff")"
  write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$deferred"
  [[ "$moff" != none ]] && set_snooze_marker "$FIXTURE_ROOT" "$moff"
  local hook_out; hook_out="$(run_hook_in "$FIXTURE_ROOT")"
  eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
  # snooze_remaining is assigned dynamically by the eval'd stdout — SC2154 false positive.
  # shellcheck disable=SC2154
  if [[ "$expect" == silent ]]; then
    assert_eq "" "$hook_out" "$label: hook silent"
    assert_contains "snoozed (" "$snooze_remaining" "$label: display says snoozed"
  else
    assert_contains "handoff:pickup" "$hook_out" "$label: hook announces"
    if printf '%s' "$snooze_remaining" | grep -q -F -- "snoozed ("; then
      FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $label: display says snoozed while the hook announces ($snooze_remaining)"
    else
      PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok: $label: display agrees (not snoozed)"
    fi
  fi
  cleanup
}

check_parity "marker +6h"                         21600 -3600  silent
check_parity "marker -1h (expired)"               -3600 -90000 announce
check_parity "deferred-at -1h, no marker"         none  -3600  announce
check_parity "future deferred-at, no marker (H9)" none  259200 announce

summary
