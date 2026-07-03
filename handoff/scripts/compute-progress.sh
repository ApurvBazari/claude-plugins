#!/usr/bin/env bash
# compute-progress.sh — compute progress signals for the handoff check skill.
#
# Reads frontmatter from <project-root>/.claude/handoff/active.md and optional
# overrides from .claude/handoff/settings.md. Emits a key=value block on stdout
# that the caller eval's.
#
# Always exits 0. On parse failure, emits "unknown" values rather than failing,
# so the caller's `eval` does not tear down the calling skill.

set -uo pipefail

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/handoff-lib.sh"

PROJECT_ROOT="${1:-$(pwd)}"
ACTIVE_FILE="$PROJECT_ROOT/.claude/handoff/active.md"
SETTINGS_FILE="$PROJECT_ROOT/.claude/handoff/settings.md"
ARCHIVE_DIR="$PROJECT_ROOT/.claude/handoff/archive"

saved_at="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-at')"
saved_at_sha="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-at-sha')"
saved_from_cwd="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-from-cwd')"
deferred_at="$(hf_get_fm_value "$ACTIVE_FILE" 'deferred-at')"

snooze_hours="$(hf_get_fm_value "$SETTINGS_FILE" 'deferral-snooze-hours')"
[[ -z "$snooze_hours" ]] && snooze_hours=24

now_epoch="$(date +%s)"
days_old="unknown"
if [[ -n "$saved_at" ]]; then
  saved_epoch="$(hf_iso_to_epoch "$saved_at")"
  if [[ "$saved_epoch" -gt 0 ]]; then
    days_old=$(( (now_epoch - saved_epoch) / 86400 ))
  fi
fi

current_branch="$(cd "$PROJECT_ROOT" 2>/dev/null && git branch --show-current 2>/dev/null)"
[[ -z "$current_branch" ]] && current_branch="unknown"

commits_past="unknown"
if [[ -n "$saved_at_sha" && "$saved_at_sha" != "unknown" ]]; then
  count="$(cd "$PROJECT_ROOT" 2>/dev/null && git rev-list --count "${saved_at_sha}..HEAD" 2>/dev/null)"
  [[ -n "$count" ]] && commits_past="$count"
fi

cwd_match="mismatch"
[[ -n "$saved_from_cwd" && "$saved_from_cwd" == "$(pwd)" ]] && cwd_match="match"

snooze_remaining="not snoozed"
if [[ -n "$deferred_at" ]]; then
  deferred_epoch="$(hf_iso_to_epoch "$deferred_at")"
  if [[ "$deferred_epoch" -gt 0 ]]; then
    # Mirror the SessionStart hook's guard EXACTLY (handoff/hooks/session-start.sh):
    # snooze holds ONLY within the window `0 <= elapsed < snooze_seconds`. A future
    # deferred-at (elapsed<0) is NOT snoozed — the hook surfaces it — so the display
    # must report will-surface, never "snoozed". Reporting "snoozed" for a future
    # deferred-at is the snooze analog of the H6 display-vs-behavior disagreement.
    snooze_seconds=$(( snooze_hours * 3600 ))
    elapsed=$(( now_epoch - deferred_epoch ))
    if [[ "$elapsed" -ge 0 && "$elapsed" -lt "$snooze_seconds" ]]; then
      remaining=$(( (snooze_seconds - elapsed) / 3600 ))
      snooze_remaining="snoozed (${remaining}h remaining)"
    elif [[ "$elapsed" -lt 0 ]]; then
      snooze_remaining="will surface (deferred-at is in the future)"
    else
      snooze_remaining="snooze expired — will surface at next SessionStart"
    fi
  fi
fi

archive_count=0
if [[ -d "$ARCHIVE_DIR" ]]; then
  archive_count="$(find "$ARCHIVE_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
fi

# Normalize to the canonical form both this script (display) and prune-archive
# (behavior) agree on (audit H6): `unlimited` | non-negative int | `10` (default).
# hf_normalize_retention also collapses shell metacharacters from a hostile
# settings.md to `10`, preserving the eval-safety contract below.
retention_value="$(hf_normalize_retention "$(hf_get_fm_value "$SETTINGS_FILE" 'archive-retention')")"

# Eval-safe output: every value is emitted via `printf '%q'`, which produces
# a bash-quoted form that survives `eval` without expansion. Combined with
# the retention_value validation above, no caller-controlled value can run
# arbitrary commands when the check skill eval's this stdout.
printf 'days_old=%q\n'         "$days_old"
printf 'current_branch=%q\n'   "$current_branch"
printf 'commits_past=%q\n'     "$commits_past"
printf 'cwd_match=%q\n'        "$cwd_match"
printf 'snooze_remaining=%q\n' "$snooze_remaining"
printf 'archive_count=%q\n'    "$archive_count"
printf 'retention_value=%q\n'  "$retention_value"

exit 0
