#!/usr/bin/env bash
# test_sp5_invariants.sh — SP-5 doc-truth + code invariants (grep assertions).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 1
fail=0
must_absent(){ local desc="$1"; shift; if grep -rniE "$1" "${@:2}" >/dev/null 2>&1; then echo "FAIL: $desc"; grep -rniE "$1" "${@:2}"; fail=1; else echo "ok: $desc"; fi; }

# --- O1: no auto-promote branding survives ---
must_absent "O1: no 'auto-promote' in start SKILL + empty-repo ref" \
  'auto-?promot' onboard/skills/start/SKILL.md onboard/skills/start/references/empty-repo-stub-procedure.md
must_absent "O1: no '(stub auto-promote)' parenthetical in adopt" \
  'stub auto-?promote' onboard/skills/adopt/references/detection-and-classification.md

exit $fail
