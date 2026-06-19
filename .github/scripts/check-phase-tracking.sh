#!/usr/bin/env bash
# check-phase-tracking.sh — assert durable phase tracking is wired into onboard
# entry-point skills and the contract reference exists. Usage: check-phase-tracking.sh
#
# NOTE: this gate is intentionally SUBJECT-AGNOSTIC. Task subjects are display labels
# only (see start/references/phase-tracking.md § slug scheme); nothing in the machinery
# parses them, so we assert only that TaskCreate wiring + the currentPhase anchor exist,
# not the literal slug values.
set -euo pipefail
ROOT="onboard/skills"
fail=0
[ -f "${ROOT}/start/references/phase-tracking.md" ] || { echo "missing phase-tracking.md"; fail=1; }
for s in start update evolve adopt; do
  skill="${ROOT}/${s}/SKILL.md"
  if [ ! -f "$skill" ]; then
    echo "entry point '${s}' SKILL.md missing"; fail=1; continue
  fi
  if ! grep -q 'TaskCreate' "$skill"; then
    echo "entry point '${s}' does not wire TaskCreate"; fail=1
  fi
done
grep -q 'currentPhase' "${ROOT}/start/SKILL.md" || { echo "start missing currentPhase anchor"; fail=1; }
if [ "$fail" -eq 0 ]; then
  echo "phase-tracking: wired in all entry points + contract present"
  exit 0
fi
exit 1
