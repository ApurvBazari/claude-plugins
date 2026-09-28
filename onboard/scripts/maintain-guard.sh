#!/usr/bin/env bash
# maintain-guard.sh — the R9 write fence around onboard:maintain's in-session edits (spec § 9).
#
# Usage:
#   maintain-guard.sh before [--state <file>]     # snapshot; prints the state-file path
#   maintain-guard.sh after --state <file> [--allow <path> | --allow <dir>/]...
#   maintain-guard.sh prefix-ok <dir>/            # may <dir>/ be exempted? (D30)
#
# `after` allows CLAUDE.md at any depth, .claude/rules/** and each --allow; a disallowed change to
# a file that was clean before is restored from HEAD, anything else is reported, nothing is
# deleted. It prints {schemaVersion, changed, preDirty, violations} and exits 0 (no violations)
# or 3 (some); 2 on bad input or a refused --allow prefix.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "maintain-guard: $cmd not found" >&2; exit 2; }
done

exec python3 -B "$HERE/maintain-lib/guard.py" "$@"
