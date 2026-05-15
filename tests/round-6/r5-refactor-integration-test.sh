#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Running R5 smoke tests against post-R6-refactor renderers..."
bash "${ROOT}/tests/round-5/feature-roadmap-smoke.sh"
bash "${ROOT}/tests/round-5/migration-test.sh"

# Verify every renderer module sources render-common
MISSING=$(grep -L 'source.*render-common' "${ROOT}"/greenfield/scripts/render-*.sh | grep -v render-common.sh || true)
if [[ -n "$MISSING" ]]; then
  echo "FAIL: renderers missing render-common.sh source: $MISSING"
  exit 1
fi
echo "R5-refactor integration: OK"
