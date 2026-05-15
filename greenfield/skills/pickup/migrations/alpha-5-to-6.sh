#!/usr/bin/env bash
# alpha-5-to-6.sh — R6 extracted migration: alpha.5 -> alpha.6
#
# Initializes Round 5 phase blocks (featureRoadmap, schemaDraftReview) as
# {skipped: true} so onboard falls back to interactive handoff for sessions
# that predate alpha.6. Moves schemaVersion from top-level to .meta.

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-5-to-6: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REASON="Round 5 phase added 2026-05-15; pre-R5 sessions skip"

echo "$INPUT" | jq --arg ts "$NOW" --arg reason "$REASON" '
  .meta = (.meta // {})
  | .meta.schemaVersion = "alpha.6"
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.5", to: "alpha.6"}]
  | del(.schemaVersion)
  | .phases = (.phases // {})
  | .phases.featureRoadmap = (.phases.featureRoadmap // {skipped: true, deferredReason: $reason})
  | .phases.schemaDraftReview = (.phases.schemaDraftReview // {skipped: true, deferredReason: $reason})
'
