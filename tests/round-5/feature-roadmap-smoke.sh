#!/usr/bin/env bash
# feature-roadmap-smoke.sh — verifies the R5 feature-roadmap fixture is
# internally consistent and that downstream onboard generation would produce
# valid feature-list.json + sprint-1.json. Structural test only — no actual
# onboard invocation.
#
# shellcheck disable=SC2016  # jq filters intentionally use single quotes — vars are jq vars, not shell

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/feature-roadmap-fixture.json"
FAIL=0

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "✓ $name"
  else
    echo "✗ $name"
    FAIL=1
  fi
}

check "fixture parses as JSON" jq empty "$FIXTURE"
check "schemaVersion is alpha.6" jq -e '.meta.schemaVersion == "3.0.0-alpha.6"' "$FIXTURE"
check "5 features present" jq -e '.phases.featureRoadmap.features | length == 5' "$FIXTURE"
check "feature IDs zero-padded F001-F005" jq -e '[.phases.featureRoadmap.features[].id] == ["F001","F002","F003","F004","F005"]' "$FIXTURE"
check "sprint1 has 3 features" jq -e '.phases.featureRoadmap.sprint1.featureIds | length == 3' "$FIXTURE"
check "sprint1 featureIds subset of features[].id" jq -e '. as $r | [$r.phases.featureRoadmap.sprint1.featureIds[]] | all(. as $f | $r.phases.featureRoadmap.features | any(.id == $f))' "$FIXTURE"
check "all personaIds resolve" jq -e '. as $r | $r.phases.featureRoadmap.features | map(.personaIds // []) | add | unique | all(. as $p | $r.phases.personas.primary | any(.id == $p))' "$FIXTURE"
check "all entityIds resolve" jq -e '. as $r | $r.phases.featureRoadmap.features | map(.entityIds // []) | add | unique | all(. as $e | $r.phases.domainModel.entities | any(.id == $e))' "$FIXTURE"
check "all riskIds resolve" jq -e '. as $r | $r.phases.featureRoadmap.features | map(.riskIds // []) | add | unique | all(. as $i | $r.risks | any(.id == $i))' "$FIXTURE"
check "sprint1 has functional+quality+testing required criteria" jq -e '[.phases.featureRoadmap.sprint1.criteria[] | select(.weight == "required") | .name] | sort == ["functional","quality","testing"]' "$FIXTURE"

exit $FAIL
