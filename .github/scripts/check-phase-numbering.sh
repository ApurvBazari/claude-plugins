#!/usr/bin/env bash
# check-phase-numbering.sh — onboard phase labels must be whole numbers in 0–7.
# The only legitimate "Phase N" namespace is the START orchestrator (Phase 0–7);
# internal skills use "Step N". This gate fails on:
#   - fractional labels   ("Phase 1.4")
#   - lettered labels     ("Phase 7a")
#   - out-of-range labels ("Phase 8", "Phase 10" — START maxes at 7, so these
#                          are vestiges of the old global numbering)
# anywhere under onboard/ EXCEPT CHANGELOG.md (historical, immutable).
# Usage: check-phase-numbering.sh [root]   (default: onboard)
set -euo pipefail
ROOT="${1:-onboard}"
hits="$(grep -rnoE 'Phase [0-9]+\.[0-9]+|Phase [0-9]+[a-z]\b|Phase ([89]|[1-9][0-9]+)\b' \
          --include='*.md' "$ROOT" 2>/dev/null \
        | grep -v '/CHANGELOG.md:' || true)"
if [ -z "$hits" ]; then
  echo "phase-numbering: no fractional/lettered/out-of-range phase labels under ${ROOT} (CHANGELOG exempt)"
  exit 0
fi
echo "phase-numbering: forbidden phase labels found:"
echo "$hits"
exit 1
