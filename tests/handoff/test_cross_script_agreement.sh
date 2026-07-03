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
summary
