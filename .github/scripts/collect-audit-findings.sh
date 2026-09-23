#!/usr/bin/env bash
set -euo pipefail

# collect-audit-findings.sh — the tooling-gap audit's drift facts, one per line, sorted and unique.
# Usage: collect-audit-findings.sh <DRIFT_REPORT> <BASELINE_JSON>   (run from the repository root)
#
# Two deterministic sources, no model involved:
#   - the structural drift items onboard/scripts/audit-tooling.sh lists under "### Drift Detected"
#   - paths in the baseline's .tooling inventory that no longer exist
# open-gap-audit-issue.sh fingerprints this list, so the same drift always yields the same
# fingerprint however the model words its report. Empty output means nothing drifted.

DRIFT_REPORT="${1:-}"
BASELINE="${2:-}"

if [[ ! -f "$DRIFT_REPORT" || ! -f "$BASELINE" ]]; then
  echo "Usage: collect-audit-findings.sh <DRIFT_REPORT> <BASELINE_JSON>" >&2
  exit 2
fi

{
  awk '/^### Drift Detected/ { in_drift = 1; next }
       /^### /               { in_drift = 0 }
       in_drift && /^  - /   { sub(/^  - /, ""); print "structural: " $0 }' "$DRIFT_REPORT"
  jq -r '.tooling | to_entries[] | .value[]' "$BASELINE" | while IFS= read -r path; do
    if [[ ! -e "$path" ]]; then
      echo "baseline path missing: ${path}"
    fi
  done
} | LC_ALL=C sort -u
