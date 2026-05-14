#!/usr/bin/env bash
# render-schema-drafts.sh — Round 5 (P10.5) entrypoint
#
# Reads phases.schemaDraftReview.{applicableArtifacts, languages} from the
# context-shape-v2 state file passed as $1. Dispatches to per-language
# renderer modules in this same directory. Writes drafts.{db,api,event}.*
# and crossCheckWarnings[] back to the state file atomically (.tmp + rename).
#
# Usage: render-schema-drafts.sh <state-file-path>
# Output: 0 on success; non-zero with stderr message on error.

set -euo pipefail

STATE_FILE="${1:?usage: render-schema-drafts.sh <state-file>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "$STATE_FILE" ]] || { echo "render-schema-drafts: state file not found: $STATE_FILE" >&2; exit 1; }
command -v jq >/dev/null || { echo "render-schema-drafts: jq is required" >&2; exit 2; }

TMP_OUT="${STATE_FILE}.tmp"
cp "$STATE_FILE" "$TMP_OUT"

ARTIFACTS=$(jq -r '.phases.schemaDraftReview.applicableArtifacts[]?' "$STATE_FILE" 2>/dev/null || true)
if [[ -z "$ARTIFACTS" ]]; then
  echo "render-schema-drafts: applicableArtifacts[] empty; nothing to do" >&2
  rm -f "$TMP_OUT"
  exit 0
fi

WARNINGS_JSON="[]"

for ART in $ARTIFACTS; do
  LANG=$(jq -r ".phases.schemaDraftReview.languages.$ART // \"none\"" "$STATE_FILE")
  case "$ART:$LANG" in
    db:prisma)         MODULE="render-db-prisma.sh" ;;
    db:sql-ddl)        MODULE="render-db-sql-ddl.sh" ;;
    api:openapi-3.0)   MODULE="render-api-openapi.sh" ;;
    api:graphql-sdl)   MODULE="render-api-graphql.sh" ;;
    event:asyncapi)    MODULE="render-event-asyncapi.sh" ;;
    event:json-schema) MODULE="render-event-json-schema.sh" ;;
    *)
      echo "render-schema-drafts: language '$LANG' for artifact '$ART' not yet supported in R5. Skipping; user must re-answer SDR.Q2 with a supported language or set drafts.$ART.skipped=true." >&2
      jq ".phases.schemaDraftReview.drafts.$ART = (.phases.schemaDraftReview.drafts.$ART // {}) + {skipped: true, deferredReason: \"language '$LANG' not yet supported in R5\"}" "$TMP_OUT" > "${TMP_OUT}.x" && mv "${TMP_OUT}.x" "$TMP_OUT"
      continue
      ;;
  esac

  MODULE_PATH="${SCRIPT_DIR}/${MODULE}"
  if [[ ! -x "$MODULE_PATH" ]]; then
    echo "render-schema-drafts: missing module: $MODULE_PATH" >&2
    rm -f "$TMP_OUT"
    exit 3
  fi

  RENDER_OUT=$("$MODULE_PATH" "$STATE_FILE") || {
    echo "render-schema-drafts: module '$MODULE' failed for artifact '$ART'" >&2
    rm -f "$TMP_OUT"
    exit 4
  }

  RENDERED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  CONTENT=$(echo "$RENDER_OUT" | jq -r '.content // empty')
  SOURCE_REFS=$(echo "$RENDER_OUT" | jq '.sourceRefs // []')
  MODULE_WARNINGS=$(echo "$RENDER_OUT" | jq '.crossCheckWarnings // []')

  jq --arg art "$ART" \
     --arg content "$CONTENT" \
     --arg renderedAt "$RENDERED_AT" \
     --argjson srcRefs "$SOURCE_REFS" \
     '.phases.schemaDraftReview.drafts[$art] = ((.phases.schemaDraftReview.drafts[$art] // {}) + {renderedAt: $renderedAt, sourceRefs: $srcRefs, content: $content, approved: false, skipped: false})' \
     "$TMP_OUT" > "${TMP_OUT}.x" && mv "${TMP_OUT}.x" "$TMP_OUT"

  WARNINGS_JSON=$(echo "$WARNINGS_JSON $MODULE_WARNINGS" | jq -s 'add')
done

jq --argjson w "$WARNINGS_JSON" '.phases.schemaDraftReview.crossCheckWarnings = $w' "$TMP_OUT" > "${TMP_OUT}.x" && mv "${TMP_OUT}.x" "$TMP_OUT"

mv "$TMP_OUT" "$STATE_FILE"
echo "render-schema-drafts: completed; drafts populated for [$ARTIFACTS]"
