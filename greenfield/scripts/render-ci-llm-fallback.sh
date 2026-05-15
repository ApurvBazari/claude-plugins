#!/usr/bin/env bash
# render-ci-llm-fallback.sh — R6 CI renderer (LLM fallback)
# Emits a starter stub when provider falls outside {gha, gitlab, circleci}.
# The Adjust loop in the wizard is the LLM-edit mechanism; this script only
# produces the initial structure + a hard banner forcing CHECK-R6-8 user ack.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-llm-fallback.sh <state-file>}"
PROVIDER=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.provider // "unknown"' true)
STAGES=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.cicd.stages // ["lint","test","build"]' false)
DEPLOY=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.cicd.deploy.environment // ""' false)

WARNINGS="[]"
WARNINGS=$(_emit_warning "warn" "W-CI-LLM-fallback" "Provider '$PROVIDER' has no vetted renderer. Output is an LLM-fallback starter — review carefully and Adjust before Approve." "$WARNINGS")

STAGE_LIST=$(jq -r 'join(", ")' <<< "$STAGES")

CONTENT="# ⚠ LLM draft — review carefully
# Provider: ${PROVIDER}
# This is a starter stub. The wizard's Adjust path uses an LLM to edit this
# YAML based on your natural-language corrections. Cross-check before Approve.
#
# Detected stages: ${STAGE_LIST}
# Deploy target: ${DEPLOY:-none}

# ------------------------------------------------------------------------------
# TODO: Replace this stub with provider-specific YAML.
# Look up '${PROVIDER}' documentation for the canonical pipeline syntax.
# Map the detected stages onto your provider's job/step concept.
# ------------------------------------------------------------------------------

pipeline:
  stages: [${STAGE_LIST}]
  on_main_branch_deploy: '${DEPLOY:-none}'

# Reference: Each stage should run a matching script:
#   lint       → npm run lint
#   typecheck  → npm run typecheck
#   test       → npm test
#   build      → npm run build
#   deploy     → echo \"Deploy step — configure per project\"
"

# Pre-write YAML-lint stub: a real lint would call yq/yamllint; we surface
# any obviously broken structure here as an error-level warning.
if ! echo "$CONTENT" | grep -q "^pipeline:"; then
  WARNINGS=$(_emit_warning "error" "E-CI-LLM-lint" "LLM fallback YAML did not include the required 'pipeline:' root key" "$WARNINGS")
fi

SRC_REFS=$(jq -n --arg p "$PROVIDER" '[{"path":"cicdAndDelivery.provider","renderedAs":("LLM-fallback starter for " + $p)}]')
jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
