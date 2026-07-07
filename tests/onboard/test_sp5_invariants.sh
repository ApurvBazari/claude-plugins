#!/usr/bin/env bash
# test_sp5_invariants.sh — SP-5 doc-truth + code invariants (grep assertions).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 1
fail=0
must_absent(){ local desc="$1"; shift; if grep -rniE "$1" "${@:2}" >/dev/null 2>&1; then echo "FAIL: $desc"; grep -rniE "$1" "${@:2}"; fail=1; else echo "ok: $desc"; fi; }

# --- O1: no auto-promote branding survives (there is no auto-promote path;
#     re-run with code added falls through to the full flow + Phase 5 hard gate) ---
must_absent "O1: no auto-promote branding survives" \
  'auto-?promot' \
  onboard/skills/start/SKILL.md \
  onboard/skills/start/references/empty-repo-stub-procedure.md \
  onboard/skills/adopt/references/detection-and-classification.md \
  tests/release-gate/manual-test-plan.md

# --- O4: no source writer emits the legacy drift name; readers keep a fallback ---
must_absent "O4: no greenfield-drift writer in scripts" \
  'greenfield-drift' onboard/scripts
must_absent "O4: no greenfield-drift init in generation SKILL" \
  'greenfield-drift' onboard/skills/generation/SKILL.md
if ! grep -q 'onboard-drift.json' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4 evolve reads onboard-drift.json"; fail=1; else echo "ok: O4 evolve reads onboard-drift.json"; fi
if ! grep -q 'greenfield-drift.json' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4 evolve keeps legacy fallback mention"; fail=1; else echo "ok: O4 evolve read-both fallback"; fi

# --- O4b: evolve documents the legacy drift-file migration (move + re-emit) ---
if ! grep -qi 'Legacy drift-file migration' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4b migration step missing"; fail=1; else echo "ok: O4b migration step present"; fi
if ! grep -qi 're-emit' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4b re-emit missing"; fail=1; else echo "ok: O4b re-emit present"; fi

# --- O4b fixture: the legacy pre-migration drift shape exists (valid JSON carrying `entries`) ---
legacy_fixture="tests/onboard/fixtures/legacy-drift/.claude/greenfield-drift.json"
if [[ ! -f "$legacy_fixture" ]]; then
  echo "FAIL: O4b legacy-drift fixture missing"; fail=1
elif command -v python3 >/dev/null 2>&1 && ! python3 -c 'import json,sys; sys.exit(0 if "entries" in json.load(open(sys.argv[1])) else 1)' "$legacy_fixture" 2>/dev/null; then
  echo "FAIL: O4b legacy-drift fixture is not valid JSON carrying entries"; fail=1
elif ! grep -q '"entries"' "$legacy_fixture"; then
  echo "FAIL: O4b legacy-drift fixture lacks entries key"; fail=1
else
  echo "ok: O4b legacy-drift fixture present (valid JSON with entries)"
fi

exit $fail
