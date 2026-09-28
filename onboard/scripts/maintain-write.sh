#!/usr/bin/env bash
# maintain-write.sh — the writes onboard:maintain makes through a script: lesson entries and the
# result entries, because `.claude/` is a protected path that Claude Code's own Write/Edit tools
# may not write unattended (owner decision 2026-09-27, narrowing D13). The model still decides
# every write; this only formats and places it.
#
# Usage:
#   maintain-write.sh record --state <file> applied|skipped|deferred|item ...
#   maintain-write.sh lesson --id <id> --text <text> --summary <text> --ref <ref> [--paths <glob>... | --file <path>]
#   maintain-write.sh early --out <file> --id <id> --reason bad-input|not-onboarded (--hint <text> | --command <cmd>)
#
# Exit 0 ok, 2 bad input, 3 lesson id already in its destination. See maintain-lib/write.py.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "maintain-write: $cmd not found" >&2; exit 2; }
done

exec python3 -B "$HERE/maintain-lib/write.py" "$@"
