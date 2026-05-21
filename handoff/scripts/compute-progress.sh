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

PROJECT_ROOT="${1:-$(pwd)}"
ACTIVE_FILE="$PROJECT_ROOT/.claude/handoff/active.md"
SETTINGS_FILE="$PROJECT_ROOT/.claude/handoff/settings.md"
ARCHIVE_DIR="$PROJECT_ROOT/.claude/handoff/archive"

# Extract a value from YAML frontmatter (between the first --- pair).
fm_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || { echo ""; return 0; }
  awk -v key="$key" '
    /^---/ { fm=!fm; next }
    fm && $0 ~ "^" key ":" {
      sub("^" key ":[[:space:]]*", "")
      gsub(/^["'\''"]|["'\''"]$/, "")
      print
      exit
    }
  ' "$file"
}

# Parse ISO 8601 → epoch seconds. Try GNU date first, then BSD date.
iso_to_epoch() {
  local iso="$1"
  date -d "$iso" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null \
    || echo 0
}

saved_at="$(fm_get "$ACTIVE_FILE" 'saved-at')"
saved_at_sha="$(fm_get "$ACTIVE_FILE" 'saved-at-sha')"
saved_from_cwd="$(fm_get "$ACTIVE_FILE" 'saved-from-cwd')"
deferred_at="$(fm_get "$ACTIVE_FILE" 'deferred-at')"

snooze_hours="$(fm_get "$SETTINGS_FILE" 'deferral-snooze-hours')"
[[ -z "$snooze_hours" ]] && snooze_hours=24

now_epoch="$(date +%s)"
days_old="unknown"
if [[ -n "$saved_at" ]]; then
  saved_epoch="$(iso_to_epoch "$saved_at")"
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
  deferred_epoch="$(iso_to_epoch "$deferred_at")"
  if [[ "$deferred_epoch" -gt 0 ]]; then
    end_epoch=$(( deferred_epoch + snooze_hours * 3600 ))
    if [[ "$now_epoch" -lt "$end_epoch" ]]; then
      remaining=$(( (end_epoch - now_epoch) / 3600 ))
      snooze_remaining="snoozed (${remaining}h remaining)"
    else
      snooze_remaining="snooze expired — will surface at next SessionStart"
    fi
  fi
fi

archive_count=0
if [[ -d "$ARCHIVE_DIR" ]]; then
  archive_count="$(find "$ARCHIVE_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
fi

retention_value="$(fm_get "$SETTINGS_FILE" 'archive-retention')"
[[ -z "$retention_value" ]] && retention_value=10

# Eval-safe by construction: current_branch is git-constrained (no `"` in
# branch names); numeric fields are integers or the literal `unknown`.
cat <<EOF
days_old="$days_old"
current_branch="$current_branch"
commits_past="$commits_past"
cwd_match="$cwd_match"
snooze_remaining="$snooze_remaining"
archive_count="$archive_count"
retention_value="$retention_value"
EOF

exit 0
