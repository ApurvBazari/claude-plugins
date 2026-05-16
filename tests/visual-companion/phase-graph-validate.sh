#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GRAPH="${ROOT}/greenfield/skills/visual-companion/references/phase-graph.json"

echo "## phase-graph: JSON valid"
jq empty "$GRAPH" || { echo "FAIL: not valid JSON"; exit 1; }
echo "  ok"

echo "## phase-graph: 18 phases present"
COUNT=$(jq '.phases | length' "$GRAPH")
[ "$COUNT" = "18" ] || { echo "FAIL: expected 18 phases, got $COUNT"; exit 1; }
echo "  ok ($COUNT phases)"

echo "## phase-graph: every required key exists"
REQUIRED='["architecturalFraming","domainModel","dataArchitecture","apiIntegration","auth","search","caching","realtime","fileUploads","payments","privacy","security","runtimeOperations","cicdAndDelivery","frontendArchitecture","designSystem","uxAccessibilityPerf","i18nL10n"]'
for p in $(echo "$REQUIRED" | jq -r '.[]'); do
  jq -e --arg p "$p" '.phases[$p] != null' "$GRAPH" >/dev/null || { echo "FAIL: phase $p missing"; exit 1; }
done
echo "  ok"

echo "## phase-graph: all 'requires' references resolve"
MISSING=$(jq -r '
  .phases as $p
  | [$p | to_entries[] | .value.requires // [] | .[]]
  | unique
  | map(select(. as $r | ($p | has($r)) | not))
  | .[]
' "$GRAPH")
[ -z "$MISSING" ] || { echo "FAIL: requires references missing phases: $MISSING"; exit 1; }
echo "  ok"

echo "## phase-graph: no cycles (DFS)"
python3 -c '
import json, sys
g = json.load(open(sys.argv[1]))["phases"]
WHITE, GRAY, BLACK = 0, 1, 2
color = {k: WHITE for k in g}
def visit(n):
    if color[n] == GRAY:
        print(f"FAIL: cycle at {n}"); sys.exit(1)
    if color[n] == BLACK: return
    color[n] = GRAY
    for r in g[n].get("requires", []):
        visit(r)
    color[n] = BLACK
for k in g: visit(k)
print("  ok")
' "$GRAPH"

echo "## phase-graph: requiredForCompletion has exactly 6 phases"
RC=$(jq '[.phases | to_entries[] | select(.value.requiredForCompletion == true)] | length' "$GRAPH")
[ "$RC" = "6" ] || { echo "FAIL: expected 6 requiredForCompletion, got $RC"; exit 1; }
echo "  ok"
