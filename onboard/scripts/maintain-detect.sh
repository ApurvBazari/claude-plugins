#!/usr/bin/env bash
# maintain-detect.sh — the tooling drift a git range caused, for onboard:maintain (onboard 3.2.0).
#
# Usage:
#   maintain-detect.sh --base <ref> --out <path>
#   maintain-detect.sh --mentioned <script> --package <name|-> [--manifest <package.json>] <file>...
#   maintain-detect.sh --lesson-file <glob>...
#   maintain-detect.sh --lesson-present --id <id> --text <text>
#
# Detect writes only --out (schemas/maintain-detect.json) and exits 0, or writes an error object
# there and exits 2. The query modes write nothing: --mentioned exits 0 (mentioned, refs on
# stdout), 1 (not mentioned) or 2 (bad input); the lesson modes print one JSON object.
# No model, no network. The logic lives in maintain-lib/ (python3, standard library only).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

missing=""
command -v git >/dev/null 2>&1 || missing="git"
command -v python3 >/dev/null 2>&1 || missing="${missing:+$missing, }python3"
if [ -n "$missing" ]; then
  msg="maintain-detect: required command(s) not found: $missing"
  out=""
  prev=""
  for arg in "$@"; do
    [ "$prev" = "--out" ] && out="$arg"
    prev="$arg"
  done
  if [ -n "$out" ] && [ -d "$(dirname "$out")" ]; then
    printf '{"schemaVersion":1,"error":{"code":"missing-dependency","message":"%s"}}\n' "$msg" > "$out"
  fi
  echo "$msg" >&2
  exit 2
fi

exec python3 -B "$HERE/maintain-lib" "$@"
