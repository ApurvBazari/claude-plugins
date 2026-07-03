#!/usr/bin/env bash
# H2 pin: compute-progress.sh must NOT re-read frontmatter keys from the directive
# BODY when the body contains a `---` horizontal rule. The old naive `/^---/` toggle
# in compute-progress re-entered "frontmatter mode" on a body hr and mis-read a
# body-decoy `deferred-at:` line — silently snoozing (suppressing) the handoff.
# After consolidation onto hf_get_fm_value (which stops at the 2nd `---`), the body
# is ignored, so the hook (session-start.sh) and compute-progress agree.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib.sh"

FIXTURE_ROOT="$(setup_fake_project)"
# Directive body deliberately contains a `---` hr AND a decoy `deferred-at:` line.
# `deferred-at` is normally ABSENT from the frontmatter (only set on "save for later"),
# so the buggy parser's body-read of it is observable: it flips snooze_remaining.
cat > "$FIXTURE_ROOT/.claude/handoff/active.md" <<'EOF'
---
saved-at: 2026-06-01T10:00:00Z
saved-at-sha: deadbee
saved-from-cwd: /tmp/x
---
First body line.

---

deferred-at: 2099-01-01T00:00:00Z
EOF

# compute-progress must NOT pick up the body-decoy deferred-at. A buggy fm_get
# re-enters frontmatter mode on the body `---` and reads 2099 -> "snoozed (...)".
# The shared reader stops at the 2nd `---` -> deferred-at empty -> "not snoozed".
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
# snooze_remaining is assigned dynamically by the eval'd script output — that is the
# exact contract under test, so the SC2154 "referenced but not assigned" is a false positive.
# shellcheck disable=SC2154
assert_eq "not snoozed" "$snooze_remaining" \
  "compute-progress ignores a body-decoy deferred-at (H2)"

# Direct parity: the shared reader returns the REAL saved-at, ignoring the body decoy.
# shellcheck source=/dev/null
. "$REPO_ROOT/handoff/scripts/handoff-lib.sh"
assert_eq "2026-06-01T10:00:00Z" \
  "$(hf_get_fm_value "$FIXTURE_ROOT/.claude/handoff/active.md" saved-at)" \
  "hf_get_fm_value ignores body decoy"

cleanup

# ---- Snooze-display parity: a FUTURE deferred-at (hook surfaces ⇒ display must agree) ----
# The SessionStart hook SURFACES a future deferred-at (elapsed<0 is outside the snooze
# window; test_hook_snooze.sh Case C pins the hook side). compute-progress's display MUST
# agree: snooze_remaining must NOT say "snoozed" — it must report will-surface. Pre-fix
# compute-progress reported "snoozed (Nh remaining)" for a future deferred-at (RED); after
# mirroring the hook's `0 <= elapsed < snooze_seconds` guard it reports will-surface (GREEN).
# This is the snooze analog of the H6 display-vs-behavior disagreement this branch fixes.
iso() { # <seconds-offset-from-now> → ISO-8601 UTC
  local off="$1"
  if date -u -d "@$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :; \
  else date -u -r "$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ; fi
}

FIXTURE_ROOT="$(setup_fake_project)"
# saved 7d ago, deferred 72h in the FUTURE.
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso 259200)"

# Hook side: surfaces (routes to /handoff:pickup) despite the future deferred-at.
hook_out="$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/handoff" bash "$REPO_ROOT/handoff/hooks/session-start.sh" \
  <<<"{\"cwd\":\"$FIXTURE_ROOT\"}" 2>/dev/null)"
assert_contains "handoff:pickup" "$hook_out" \
  "future deferred-at → hook surfaces (Case C parity)"

# Display side: compute-progress must AGREE — never "snoozed" for a future deferred-at.
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
# snooze_remaining is assigned dynamically by the eval'd stdout — SC2154 false positive.
# shellcheck disable=SC2154
if printf '%s' "$snooze_remaining" | grep -q -F -- "snoozed"; then
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "  FAIL: compute-progress says \"snoozed\" for a future deferred-at (disagrees with the surfacing hook)"
  echo "       snooze_remaining: $snooze_remaining"
else
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  ok: compute-progress does NOT say \"snoozed\" for a future deferred-at (agrees with hook)"
fi
# ...and positively reports that it will surface.
assert_contains "will surface" "$snooze_remaining" \
  "future deferred-at → compute-progress reports will-surface"

cleanup
summary
