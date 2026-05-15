#!/usr/bin/env bash
# alpha-4-to-5.sh — R6 extracted migration: alpha.4 -> alpha.5
#
# Mirrors the R4 inline logic in pickup/SKILL.md (the "State migration: alpha.4
# → alpha.5" section). Initializes Round 4 collections (personas, domainModel,
# risks) with safe defaults; sets mode flags to mid-session-safe values.

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-4-to-5: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$INPUT" | jq --arg ts "$NOW" '
  .schemaVersion = "alpha.5"
  | .mode = (.mode // {})
  | .mode.depth = (.mode.depth // "heavy")
  | .mode.coupling = (.mode.coupling // "hybrid")
  | .mode.domainFormat = (.mode.domainFormat // "ddd-lite")
  | .phaseStatus = (.phaseStatus // {})
  | .phaseStatus.personas = (.phaseStatus.personas // {status: "not-yet-walked", approvedAt: null, lastModified: $ts, staleReason: null})
  | .phaseStatus.domainModel = (.phaseStatus.domainModel // {status: "not-yet-walked", approvedAt: null, lastModified: $ts, staleReason: null})
  | .context = (.context // {})
  | .context.personas = (.context.personas // {primary: [], secondary: [], antiPersonas: []})
  | .context.domainModel = (.context.domainModel // {contexts: [], entities: [], valueObjects: [], domainEvents: [], crossContextRelationships: [], ubiquitousLanguage: [], antiCorruption: ""})
  | .context.risks = (.context.risks // [])
  | .context.phases = (.context.phases // {})
  | .context.phases.architecturalValidation = (.context.phases.architecturalValidation // {})
  | .context.phases.architecturalValidation.riskReconciliation = (.context.phases.architecturalValidation.riskReconciliation // {summary: {}, topFollowups: []})
  | .meta = (.meta // {})
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.4", to: "alpha.5"}]
'
