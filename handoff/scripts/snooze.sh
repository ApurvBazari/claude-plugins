#!/usr/bin/env bash
# snooze.sh — "Save for later": record deferred-at and set the snooze marker.
#
# Usage: snooze.sh <project-root>
#
# Writes `deferred-at: <now, ISO-8601 UTC>` into the active handoff's frontmatter
# and sets the modification time of .claude/handoff/snooze-until to the end of the
# snooze window (now + deferral-snooze-hours, default 24). The SessionStart hook
# stays silent while that time is in the future. Prints `snoozed-until=<iso>`.
#
# The window is capped at 8760 hours (one year) so a mistyped setting cannot hide
# a handoff indefinitely.
#
# Exit 0 on success, 2 on missing args, 3 when there is no active handoff.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <project-root>" >&2
  exit 2
fi

here="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=/dev/null
. "$here/handoff-lib.sh"

root="$1"
handoff_dir="$root/.claude/handoff"
active="$handoff_dir/active.md"
if [[ ! -f "$active" ]]; then
  echo "error: no active handoff at $active" >&2
  exit 3
fi

hours="$(hf_int_setting "$(hf_get_fm_value "$handoff_dir/settings.md" 'deferral-snooze-hours')" 24 8760)"

now_epoch="$(date +%s)"
until_epoch=$(( now_epoch + hours * 3600 ))
now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# GNU date takes -d @<epoch>; BSD date takes -r <epoch>.
until_iso="$(date -u -d "@$until_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
             || date -u -r "$until_epoch" +%Y-%m-%dT%H:%M:%SZ)"

bash "$here/merge-fm-key.sh" "$active" deferred-at "$now_iso"
# GNU and BSD touch both accept `-d YYYY-MM-DDThh:mm:SSZ`.
touch -d "$until_iso" "$handoff_dir/snooze-until"

printf 'snoozed-until=%s\n' "$until_iso"
