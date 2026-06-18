#!/usr/bin/env bash
# check-phase-tracking.sh — assert durable phase tracking is wired into onboard
# entry-point skills and the contract reference exists. Usage: check-phase-tracking.sh
set -uo pipefail
ROOT="onboard/skills"
fail=0
[ -f "${ROOT}/start/references/phase-tracking.md" ] || { echo "missing phase-tracking.md"; fail=1; }
for s in start update evolve adopt; do
  if ! grep -q 'TaskCreate' "${ROOT}/${s}/SKILL.md" 2>/dev/null; then
    echo "entry point '${s}' does not wire TaskCreate"; fail=1
  fi
done
grep -q 'currentPhase' "${ROOT}/start/SKILL.md" || { echo "start missing currentPhase anchor"; fail=1; }
[ "$fail" -eq 0 ] && { echo "phase-tracking: wired in all entry points + contract present"; exit 0; }
exit 1
