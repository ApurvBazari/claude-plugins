#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIX="${SCRIPT_DIR}/phase-smoke-fixture.json"

echo "## Phase smoke — verifying fixture parses + all 9 phases present"

jq empty "$FIX" || { echo "FAIL: fixture not valid JSON"; exit 1; }

for p in search caching realtime fileUploads payments frontendArchitecture designSystem uxAccessibilityPerf i18nL10n; do
  jq -e --arg p "$p" '.phases[$p] != null' "$FIX" >/dev/null || { echo "FAIL: phase $p missing"; exit 1; }
  echo "  phase $p: present"
done

echo "## Gate coherence — CHECK-R6-1"
jq -e '
  [ (.phases.auth.concerns // {}),
    (.phases.uxAccessibilityPerf.concerns // {}),
    (.phases.cicdAndDelivery.concerns // {}) ]
  | map(to_entries[]) | flatten
  | all(.value.needed != true or ((.value.vendor // "") | length > 0))
' "$FIX" || { echo "FAIL: CHECK-R6-1 gate vendor coherence"; exit 1; }

echo "## P5 framework match — CHECK-R6-4"
jq -e '.phases.frontendArchitecture.frameworkConfirmed == .phases.architecturalFraming.frontendFramework' "$FIX" || { echo "FAIL"; exit 1; }

echo "## P5.6 persona coverage — CHECK-R6-5"
jq -e '
  . as $root
  | (($root.phases.personas.primary // []) + ($root.phases.personas.secondary // []) | [.[].id]) as $pids
  | $pids | all(. as $id | ($root.phases.uxAccessibilityPerf.surfacesByPersona[$id] // []) | length > 0)
' "$FIX" || { echo "FAIL"; exit 1; }

echo "## Synthesis template variable presence (sample 3 phases)"
for phase in search caching realtime; do
  TPL="${ROOT}/greenfield/skills/synthesis-review/references/templates/${phase}.html"
  case "$phase" in
    file-uploads|fileUploads) KEY="fileUploads" ;;
    *)                        KEY="$phase" ;;
  esac
  COUNT=$(grep -c "{{${KEY}\." "$TPL" || echo 0)
  [[ "$COUNT" -ge 1 ]] || { echo "FAIL: template $phase has no $KEY placeholders"; exit 1; }
  echo "  template $phase: $COUNT placeholders"
done

echo
echo "phase-smoke: 10/10 OK"
