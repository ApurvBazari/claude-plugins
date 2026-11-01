#!/usr/bin/env bash
# compute-progress.sh — compute progress signals for the pickup and check skills.
#
# Usage: compute-progress.sh <project-root>
#
# Reads frontmatter from <project-root>/.claude/handoff/active.md, optional
# overrides from .claude/handoff/settings.md, and the snooze marker
# .claude/handoff/snooze-until. Emits a key=value block on stdout that the
# caller eval's.
#
# Always exits 0. On parse failure, emits "unknown" values rather than failing,
# so the caller's `eval` does not tear down the calling skill.

set -uo pipefail

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/handoff-lib.sh"

PROJECT_ROOT="${1:-$(pwd)}"
ACTIVE_FILE="$PROJECT_ROOT/.claude/handoff/active.md"
SETTINGS_FILE="$PROJECT_ROOT/.claude/handoff/settings.md"
SNOOZE_FILE="$PROJECT_ROOT/.claude/handoff/snooze-until"
ARCHIVE_DIR="$PROJECT_ROOT/.claude/handoff/archive"

saved_at="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-at')"
saved_at_sha="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-at-sha')"
# The file may come from someone else (a handoff committed to the repo). Accept only a
# 7–40 character hex object name before it reaches git: a value such as `--output=<path>`
# would otherwise be parsed as a git option rather than a revision.
[[ "$saved_at_sha" =~ ^[0-9a-fA-F]{7,40}$ ]] || saved_at_sha="unknown"
saved_at_branch="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-at-branch')"
saved_from_cwd="$(hf_get_fm_value "$ACTIVE_FILE" 'saved-from-cwd')"

# Thresholds: positive integers only; anything else falls back to the default.
stale_commit_threshold="$(hf_int_setting "$(hf_get_fm_value "$SETTINGS_FILE" 'stale-commit-threshold')" 3 999999)"
stale_day_threshold="$(hf_int_setting "$(hf_get_fm_value "$SETTINGS_FILE" 'stale-day-threshold')" 90 999999)"

now_epoch="$(date +%s)"
days_old="unknown"
stale="unknown"
if [[ -n "$saved_at" ]]; then
  saved_epoch="$(hf_iso_to_epoch "$saved_at")"
  if [[ "$saved_epoch" -gt 0 ]]; then
    days_old=$(( (now_epoch - saved_epoch) / 86400 ))
    if [[ "$days_old" -ge "$stale_day_threshold" ]]; then stale="yes"; else stale="no"; fi
  fi
fi

current_branch="$(cd "$PROJECT_ROOT" 2>/dev/null && git branch --show-current 2>/dev/null)"
[[ -z "$current_branch" ]] && current_branch="unknown"

branch_changed="unknown"
if [[ -n "$saved_at_branch" && "$saved_at_branch" != "unknown" && "$current_branch" != "unknown" ]]; then
  if [[ "$saved_at_branch" == "$current_branch" ]]; then branch_changed="no"; else branch_changed="yes"; fi
fi

commits_past="unknown"
if [[ -n "$saved_at_sha" && "$saved_at_sha" != "unknown" ]]; then
  count="$(cd "$PROJECT_ROOT" 2>/dev/null && git rev-list --count "${saved_at_sha}..HEAD" 2>/dev/null)"
  [[ -n "$count" ]] && commits_past="$count"
fi

progress_tags="none"
tags=()
if [[ "$commits_past" =~ ^[0-9]+$ ]] && [[ "$commits_past" -ge "$stale_commit_threshold" ]]; then
  tags+=("progress-made")
fi
[[ "$branch_changed" == "yes" ]] && tags+=("branch-changed")
if [[ "${#tags[@]}" -gt 0 ]]; then progress_tags="$(IFS=','; echo "${tags[*]}")"; fi

cwd_match="mismatch"
[[ -n "$saved_from_cwd" && "$saved_from_cwd" == "$(pwd)" ]] && cwd_match="match"

# A handoff tracked by git may have been written by someone else (it arrived with
# a clone or a pull). The pickup skill warns the user when this is "yes".
tracked_in_git="unknown"
if (cd "$PROJECT_ROOT" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
  if (cd "$PROJECT_ROOT" && git ls-files --error-unmatch .claude/handoff/active.md >/dev/null 2>&1); then
    tracked_in_git="yes"
  else
    tracked_in_git="no"
  fi
fi

# Snooze: the marker's mtime is the end of the window. Use the SAME test as the
# SessionStart hook (find -newermt now) so this display and the hook cannot
# disagree. A deferred-at with no marker (a 1.0.x snooze) does not snooze.
snooze_remaining="not snoozed"
if [[ -f "$SNOOZE_FILE" ]]; then
  if find "$SNOOZE_FILE" -newermt now 2>/dev/null | grep -q .; then
    until_epoch="$(stat -c %Y "$SNOOZE_FILE" 2>/dev/null || stat -f %m "$SNOOZE_FILE" 2>/dev/null || echo 0)"
    remaining=$(( (until_epoch - now_epoch + 3599) / 3600 ))
    snooze_remaining="snoozed (${remaining}h remaining)"
  else
    snooze_remaining="snooze expired — will surface at next SessionStart"
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
# the validation above, no caller-controlled value can run arbitrary commands
# when a skill eval's this stdout.
printf 'days_old=%q\n'               "$days_old"
printf 'stale=%q\n'                  "$stale"
printf 'stale_day_threshold=%q\n'    "$stale_day_threshold"
printf 'stale_commit_threshold=%q\n' "$stale_commit_threshold"
printf 'current_branch=%q\n'         "$current_branch"
printf 'branch_changed=%q\n'         "$branch_changed"
printf 'commits_past=%q\n'           "$commits_past"
printf 'progress_tags=%q\n'          "$progress_tags"
printf 'cwd_match=%q\n'              "$cwd_match"
printf 'tracked_in_git=%q\n'         "$tracked_in_git"
printf 'snooze_remaining=%q\n'       "$snooze_remaining"
printf 'archive_count=%q\n'          "$archive_count"
printf 'retention_value=%q\n'        "$retention_value"

exit 0
