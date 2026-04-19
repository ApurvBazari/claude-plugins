#!/usr/bin/env bash
set -euo pipefail

# open-gap-audit-pr.sh — Diff audit report and open PR if content changed
# Usage: open-gap-audit-pr.sh <DATE> <BRANCH>
# Env: GH_TOKEN (required for gh pr create)

DATE="${1:-}"
BRANCH="${2:-}"
REPORT_DIR="docs/tooling-gap-reports"

if [[ -z "$DATE" || -z "$BRANCH" ]]; then
  echo "Usage: open-gap-audit-pr.sh <DATE> <BRANCH>"
  exit 0
fi

REPORT_FILE="${REPORT_DIR}/${DATE}-gap-report.md"

# 1. Check report exists
if [[ ! -f "$REPORT_FILE" ]]; then
  echo "No report found for ${DATE}, skipping PR"
  exit 0
fi

# 2. Check for existing open PR from this branch
EXISTING_PR=$(gh pr list --base develop --head "$BRANCH" --state open --json number --jq '.[0].number // ""' 2>/dev/null || echo "")
if [[ -n "$EXISTING_PR" ]]; then
  echo "PR #${EXISTING_PR} already open for ${BRANCH}, skipping"
  exit 0
fi

# 3. Find most recent previous report (exclude today's)
PREV=$(find "$REPORT_DIR" -name '*-gap-report.md' ! -name "${DATE}-gap-report.md" 2>/dev/null | sort | tail -1)

# 4. If no previous report, open PR unconditionally (first-ever run)
if [[ -z "$PREV" ]]; then
  echo "First audit report — opening PR"
else
  # 5. Strip date header lines and diff content
  STRIPPED_CURR=$(grep -v '^# Tooling Gap Audit — ' "$REPORT_FILE" || true)
  STRIPPED_PREV=$(grep -v '^# Tooling Gap Audit — ' "$PREV" || true)

  if [[ "$STRIPPED_CURR" == "$STRIPPED_PREV" ]]; then
    echo "No content change vs previous report ($(basename "$PREV")), skipping PR"
    exit 0
  fi

  echo "Content differs from previous report ($(basename "$PREV")) — opening PR"
fi

# 6. Extract Summary section for PR body
SUMMARY=$(sed -n '/^## Summary$/,/^## /{ /^## Summary$/d; /^## /d; p; }' "$REPORT_FILE" | sed '/^$/d')
if [[ -z "$SUMMARY" ]]; then
  SUMMARY="See full report: ${REPORT_FILE}"
fi

# 7. Write PR body to a tempfile (defense in depth — LLM-generated $SUMMARY
#    content is never interpolated through shell expansion).
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

{
  printf '## Tooling Gap Audit — %s\n\n' "$DATE"
  printf '%s\n\n' "$SUMMARY"
  printf -- '---\n\n'
  # shellcheck disable=SC2016  # backticks here are markdown code formatting, not shell expansion
  printf 'Full report: `%s`\n' "$REPORT_FILE"
} > "$BODY_FILE"

# 8. Open PR
if gh pr create \
  --base develop \
  --head "$BRANCH" \
  --title "chore(audit): tooling gap report ${DATE}" \
  --body-file "$BODY_FILE"; then
  echo "PR created successfully"
else
  echo "WARN: PR creation failed — continuing without PR"
  exit 0
fi
