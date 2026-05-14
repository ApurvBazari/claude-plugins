#!/usr/bin/env bash
# back-fill-downstream-section.sh
#
# Re-render personas.html or domain-model.html with the "Decisions Driven Downstream"
# section populated from downstream sourceRef dependencies.
#
# Invoked by greenfield/skills/synthesis-review/SKILL.md after any downstream phase
# Approval (see § Back-fill mechanic in that file).
#
# Usage:
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/back-fill-downstream-section.sh" "$PROJECT_ROOT" "$APPROVED_PHASE_ID"
#
# Args:
#   $1 — PROJECT_ROOT — absolute path to scaffolded project root (contains docs/adr/).
#   $2 — APPROVED_PHASE_ID — the downstream phase that was just Approved
#        (e.g. "auth", "privacy") — drives the back-fill trigger but the script
#        re-renders BOTH personas.html and domain-model.html in one pass.
#
# Exit codes:
#   0   — success (back-fill completed OR no-op if no sourceRef matches found).
#   2   — usage error (missing args, project root not found).
#   3   — back-fill failed (e.g., template missing, malformed dependencies.json).
#
# This is currently a STUB. Production implementation is wired in a follow-up task
# once the synthesis-review SKILL's renderer exposes a re-render entry point.

set -euo pipefail

PROJECT_ROOT="${1:?usage: back-fill-downstream-section.sh PROJECT_ROOT APPROVED_PHASE_ID}"
APPROVED_PHASE_ID="${2:?usage: back-fill-downstream-section.sh PROJECT_ROOT APPROVED_PHASE_ID}"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "[back-fill] error: PROJECT_ROOT not a directory: $PROJECT_ROOT" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT/docs/adr" ]]; then
  echo "[back-fill] error: no docs/adr/ directory at: $PROJECT_ROOT/docs/adr" >&2
  exit 2
fi

# Logical implementation steps (to wire in follow-up):
#
# 1. Scan downstream dependency files:
#    find "$PROJECT_ROOT/docs/adr" -maxdepth 1 -name '*.dependencies.json' -type f
#
# 2. For each of {personas, domainModel}, filter entries whose sourceRef.phase matches:
#    jq --arg phase "personas" \
#       '[.dependencies[] | select(.sourceRef.phase == $phase)]' \
#       "<dep-file>"
#
# 3. Aggregate by downstream phase ID. Build a downstreamTraces[] template variable
#    structured as: [ { phase: "auth", entries: [ { path, value, sourceRef, rationale }, ... ] }, ... ]
#
# 4. Re-render via synthesis-review's renderer:
#      - personas.html with new {{downstreamTraces}} → Section 6 ("Decisions Driven Downstream")
#      - domain-model.html with new {{downstreamTraces}} → Section 10
#    The renderer preserves all other sections' existing Approved state.
#
# 5. Stamp <personas>.dependencies.json + <domain-model>.dependencies.json with:
#      { "lastBackFilledAt": "<iso8601-now>", "downstreamPhases": [ ... triggers seen so far ] }
#
# 6. Idempotency: if the new aggregation hash matches the previous (recorded in
#    dependencies.json.lastBackFillHash), exit 0 without rewriting files.

echo "[back-fill stub] project=$PROJECT_ROOT approved_phase=$APPROVED_PHASE_ID"
echo "[back-fill stub] would scan: $PROJECT_ROOT/docs/adr/*.dependencies.json"
echo "[back-fill stub] would re-render:"
echo "  - $PROJECT_ROOT/docs/adr/personas.html      (Section 6 — Decisions Driven Downstream)"
echo "  - $PROJECT_ROOT/docs/adr/domain-model.html  (Section 10 — Decisions Driven Downstream)"
echo "[back-fill stub] no-op for now — production implementation deferred"

exit 0
