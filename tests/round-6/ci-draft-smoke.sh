#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

mk_fixture() {
  local provider="$1"
  local tmp
  tmp=$(mktemp)
  cat > "$tmp" <<EOF
{
  "meta": { "schemaVersion": "alpha.7" },
  "phases": {
    "stack": { "language": "typescript", "nodeVersion": "20" },
    "architecturalFraming": { "frontendFramework": "next" },
    "cicdAndDelivery": {
      "provider": "${provider}",
      "cicd": { "stages": ["lint", "test", "build"], "runners": "ubuntu-latest", "deploy": { "environment": "production" } },
      "adjustHistory": []
    }
  }
}
EOF
  echo "$tmp"
}

PROVIDERS=("gha" "gitlab" "circle" "buildkite")

for p in "${PROVIDERS[@]}"; do
  FIX=$(mk_fixture "$p")
  bash "${ROOT}/greenfield/scripts/render-ci-drafts.sh" "$FIX"
  YAML=$(jq -r '.phases.cicdAndDelivery.draftYaml' "$FIX")
  FALLBACK=$(jq -r '.phases.cicdAndDelivery.draftFallback' "$FIX")

  if [[ -z "$YAML" || "$YAML" == "null" ]]; then
    echo "FAIL: $p produced no YAML"; exit 1
  fi

  case "$p" in
    gha)
      echo "$YAML" | grep -q "name: CI" || { echo "FAIL: gha missing 'name: CI'"; exit 1; }
      [[ "$FALLBACK" == "false" ]] || { echo "FAIL: gha shouldn't be fallback"; exit 1; }
      ;;
    gitlab)
      echo "$YAML" | grep -q "image:" || { echo "FAIL: gitlab missing 'image:'"; exit 1; }
      [[ "$FALLBACK" == "false" ]] || { echo "FAIL: gitlab shouldn't be fallback"; exit 1; }
      ;;
    circle)
      echo "$YAML" | grep -q "version: 2.1" || { echo "FAIL: circle missing 'version: 2.1'"; exit 1; }
      [[ "$FALLBACK" == "false" ]] || { echo "FAIL: circle shouldn't be fallback"; exit 1; }
      ;;
    buildkite)
      echo "$YAML" | grep -q "LLM draft" || { echo "FAIL: buildkite missing LLM banner"; exit 1; }
      [[ "$FALLBACK" == "true" ]] || { echo "FAIL: buildkite should be fallback"; exit 1; }
      ;;
  esac
  echo "  provider $p: OK (fallback=$FALLBACK)"
  rm -f "$FIX"
done

echo
echo "ci-draft-smoke: 4/4 OK"
