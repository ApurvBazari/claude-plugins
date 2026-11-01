#!/usr/bin/env bash
# archive-active.sh — move the active handoff into archive/ and apply retention.
#
# Usage: archive-active.sh <project-root> <consumed|discarded|expired>
#
# Moves <project-root>/.claude/handoff/active.md to
# .claude/handoff/archive/<kind>-<YYYYMMDDTHHMMSS>.md, removes the snooze marker
# (it belongs to the handoff that just left), then runs prune-archive.sh.
# Prints the archive path, relative to the project root, on success.
#
# Used by the pickup skill (Execute → consumed, Discard → discarded, stale →
# expired) and by the discard skill.
#
# Exit 0 on success, 2 on bad arguments, 3 when there is no active handoff,
# 1 when the move fails.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $(basename "$0") <project-root> <consumed|discarded|expired>" >&2
  exit 2
fi

root="$1"
kind="$2"
case "$kind" in
  consumed|discarded|expired) ;;
  *)
    echo "error: kind must be consumed, discarded or expired (got '$kind')" >&2
    exit 2
    ;;
esac

handoff_dir="$root/.claude/handoff"
active="$handoff_dir/active.md"
if [[ ! -f "$active" ]]; then
  echo "error: no active handoff at $active" >&2
  exit 3
fi

mkdir -p "$handoff_dir/archive"
ts="$(date +%Y%m%dT%H%M%S)"
name="$kind-$ts.md"
# Two archives in the same second get a numeric suffix instead of overwriting.
n=1
while [[ -e "$handoff_dir/archive/$name" ]]; do
  name="$kind-$ts-$n.md"
  n=$((n + 1))
done

mv "$active" "$handoff_dir/archive/$name"
rm -f "$handoff_dir/snooze-until"

# Retention is best-effort: a prune failure must not undo or hide the archive.
bash "$(dirname "${BASH_SOURCE[0]}")/prune-archive.sh" "$root" || true

printf '.claude/handoff/archive/%s\n' "$name"
