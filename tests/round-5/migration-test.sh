#!/usr/bin/env bash
# migration-test.sh — applies the alpha.5 → alpha.6 pickup shim logic
# inline (mirrors greenfield/skills/pickup/SKILL.md § Migration: alpha.5 → alpha.6)
# and asserts the 8 required invariants.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/migration-alpha5-fixture.json"
TMP=$(mktemp)
FAIL=0

# Apply the shim inline
jq '
  if .meta.schemaVersion < "3.0.0-alpha.6" then
    (if .phases.featureRoadmap == null then .phases.featureRoadmap = {skipped: true, deferredReason: "session predates Round 5"} else . end)
    | (if .phases.schemaDraftReview == null then .phases.schemaDraftReview = {skipped: true, deferredReason: "session predates Round 5"} else . end)
    | .meta.schemaVersion = "3.0.0-alpha.6"
  else . end
' "$FIXTURE" > "$TMP"

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "✓ $name"
  else
    echo "✗ $name"
    FAIL=1
  fi
}

check "migrated JSON parses" jq empty "$TMP"
check "schemaVersion bumped to alpha.6" jq -e '.meta.schemaVersion == "3.0.0-alpha.6"' "$TMP"
check "featureRoadmap.skipped = true" jq -e '.phases.featureRoadmap.skipped == true' "$TMP"
check "schemaDraftReview.skipped = true" jq -e '.phases.schemaDraftReview.skipped == true' "$TMP"
check "featureRoadmap has deferredReason" jq -e '.phases.featureRoadmap.deferredReason | startswith("session predates")' "$TMP"
check "personas preserved (no collision)" jq -e '.phases.personas.primary[0].name == "Sara"' "$TMP"
check "mode block preserved" jq -e '.mode.coupling == "auto-loop"' "$TMP"
check "risks[] preserved" jq -e '.risks | type == "array"' "$TMP"

rm -f "$TMP"
exit $FAIL
