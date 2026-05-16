#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESOLVER="${ROOT}/greenfield/scripts/resolve-phase-status.sh"
GRAPH="${ROOT}/greenfield/skills/visual-companion/references/phase-graph.json"
FIX="${SCRIPT_DIR}/fixtures"

echo "## empty state: architecturalFraming + cicdAndDelivery AVAILABLE, others LOCKED/HIDDEN"
OUT=$(bash "$RESOLVER" --graph "$GRAPH" --state "${FIX}/state-empty.json")
echo "$OUT" | jq -e '.phases.architecturalFraming.status == "AVAILABLE"' >/dev/null || { echo "FAIL"; exit 1; }
echo "$OUT" | jq -e '.phases.cicdAndDelivery.status == "AVAILABLE"' >/dev/null || { echo "FAIL"; exit 1; }
echo "$OUT" | jq -e '.phases.dataArchitecture.status == "LOCKED"' >/dev/null || { echo "FAIL"; exit 1; }
echo "$OUT" | jq -e '.phases.payments.status == "HIDDEN"' >/dev/null || { echo "FAIL: payments should be hidden when commerceUser=false"; exit 1; }
echo "  ok"

echo "## foundation-done: dataArchitecture/apiIntegration/auth/domainModel become AVAILABLE"
OUT=$(bash "$RESOLVER" --graph "$GRAPH" --state "${FIX}/state-foundation-done.json")
for p in dataArchitecture apiIntegration auth domainModel; do
  echo "$OUT" | jq -e --arg p "$p" '.phases[$p].status == "AVAILABLE"' >/dev/null \
    || { echo "FAIL: $p should be AVAILABLE after architecturalFraming approved"; exit 1; }
done
echo "$OUT" | jq -e '.phases.architecturalFraming.status == "APPROVED"' >/dev/null || { echo "FAIL"; exit 1; }
echo "  ok"

echo "## cli-app: frontendArchitecture/designSystem/uxAccessibilityPerf/i18nL10n HIDDEN"
OUT=$(bash "$RESOLVER" --graph "$GRAPH" --state "${FIX}/state-cli-app.json")
for p in frontendArchitecture designSystem uxAccessibilityPerf i18nL10n; do
  echo "$OUT" | jq -e --arg p "$p" '.phases[$p].status == "HIDDEN"' >/dev/null \
    || { echo "FAIL: $p should be HIDDEN for cli appType"; exit 1; }
done
echo "  ok"

echo "## completionPolicy: empty state shows 0/6"
OUT=$(bash "$RESOLVER" --graph "$GRAPH" --state "${FIX}/state-empty.json")
echo "$OUT" | jq -e '.completionPolicy.requiredApproved == 6 and .completionPolicy.currentApproved == 0' >/dev/null \
  || { echo "FAIL: completion counts wrong"; exit 1; }
echo "  ok"
