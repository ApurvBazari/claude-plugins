#!/usr/bin/env bash
# render-ci-drafts.sh — R6 (Step 20) CI Draft Review entrypoint
#
# Reads phases.cicdAndDelivery.provider from the state file and dispatches to
# per-provider modules. Writes phases.cicdAndDelivery.draftYaml + draftWarnings
# atomically. Used by the wizard Step 20 synthesis-review to produce Panel 3.
#
# Approve writes the YAML to phases.cicdAndDelivery.lockedYaml; this script
# does NOT lock — that is the wizard's job after user Approve.
#
# Usage: render-ci-drafts.sh <state-file-path>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-drafts.sh <state-file>}"
[[ -f "$STATE_FILE" ]] || { echo "render-ci-drafts: state file not found: $STATE_FILE" >&2; exit 1; }

PROVIDER=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.provider // "gha"' true)

case "$PROVIDER" in
  gha|github-actions) MODULE="render-ci-gha.sh"; FALLBACK=false ;;
  gitlab|gitlab-ci)   MODULE="render-ci-gitlab.sh"; FALLBACK=false ;;
  circle|circleci)    MODULE="render-ci-circleci.sh"; FALLBACK=false ;;
  *)                  MODULE="render-ci-llm-fallback.sh"; FALLBACK=true ;;
esac

MODULE_PATH="${SCRIPT_DIR}/${MODULE}"
[[ -x "$MODULE_PATH" ]] || { echo "render-ci-drafts: missing module: $MODULE_PATH" >&2; exit 3; }

RENDER_OUT=$("$MODULE_PATH" "$STATE_FILE") || {
  echo "render-ci-drafts: module '$MODULE' failed for provider '$PROVIDER'" >&2
  exit 4
}

RENDERED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DRAFT_YAML=$(echo "$RENDER_OUT" | jq -r '.content // empty')
WARNINGS=$(echo "$RENDER_OUT" | jq '.crossCheckWarnings // []')
SOURCE_REFS=$(echo "$RENDER_OUT" | jq '.sourceRefs // []')

TMP="${STATE_FILE}.tmp.$$"
jq --arg yaml "$DRAFT_YAML" \
   --arg ts "$RENDERED_AT" \
   --argjson warnings "$WARNINGS" \
   --argjson srcRefs "$SOURCE_REFS" \
   --argjson fallback "$FALLBACK" \
   --arg provider "$PROVIDER" \
   '.phases.cicdAndDelivery.draftYaml = $yaml
    | .phases.cicdAndDelivery.draftRenderedAt = $ts
    | .phases.cicdAndDelivery.draftSourceRefs = $srcRefs
    | .phases.cicdAndDelivery.draftWarnings = $warnings
    | .phases.cicdAndDelivery.draftFallback = $fallback
    | .phases.cicdAndDelivery.draftProvider = $provider' \
   "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

echo "render-ci-drafts: completed for provider '$PROVIDER' (fallback=$FALLBACK)"
