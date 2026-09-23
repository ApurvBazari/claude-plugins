#!/usr/bin/env bash
set -euo pipefail

# open-gap-audit-issue.sh — file the tooling-gap report as a GitHub issue when it changed.
# Usage: open-gap-audit-issue.sh <DATE> <REPORT_FILE>
# Env:   GH_TOKEN (gh auth; needs issues: write)
#
#   no drift, no open issue   → nothing
#   no drift, open issue      → close it (drift resolved)
#   same body as open issue   → nothing (the date line is ignored when comparing)
#   new or changed drift      → open an issue, close the one it supersedes
# The body always travels via --body-file: report text is model output and is never expanded.

DATE="${1:-}"
REPORT_FILE="${2:-}"
LABEL="tooling-audit"
HEADER_PREFIX="# Tooling Gap Audit — "

if [[ -z "$DATE" || -z "$REPORT_FILE" ]]; then
  echo "Usage: open-gap-audit-issue.sh <DATE> <REPORT_FILE>" >&2
  exit 2
fi

if [[ ! -s "$REPORT_FILE" ]]; then
  echo "::error::No audit report at ${REPORT_FILE} — the audit step did not write one" >&2
  exit 1
fi

first_line="$(head -n 1 "$REPORT_FILE")"
if [[ "$first_line" != "${HEADER_PREFIX}${DATE}" ]]; then
  echo "::error::Report header malformed: expected '${HEADER_PREFIX}${DATE}', got '${first_line}'" >&2
  exit 1
fi

# Normalise for comparison: drop CRs and the dated header line.
normalise() { tr -d '\r' | grep -v "^${HEADER_PREFIX}" || true; }

current="$(normalise < "$REPORT_FILE")"
no_drift=0
if grep -qF 'No tooling drift detected.' "$REPORT_FILE"; then
  no_drift=1
fi

open_json="$(gh issue list --label "$LABEL" --state open --limit 1 --json number,body)"
open_number="$(jq -r '.[0].number // empty' <<<"$open_json")"
open_body="$(jq -r '.[0].body // empty' <<<"$open_json" | normalise)"

if [[ -z "$open_number" && "$no_drift" -eq 1 ]]; then
  echo "No tooling drift and no open audit issue — nothing to file."
  exit 0
fi

if [[ -n "$open_number" && "$no_drift" -eq 1 ]]; then
  gh issue close "$open_number" --comment "Audit on ${DATE}: no tooling drift detected. Closing."
  echo "Drift resolved — closed #${open_number}."
  exit 0
fi

if [[ -n "$open_number" && "$current" == "$open_body" ]]; then
  echo "Report unchanged vs open issue #${open_number} — skipping."
  exit 0
fi

gh label create "$LABEL" --color "5319e7" --description "Tooling-gap audit findings" --force >/dev/null
new_url="$(gh issue create --title "Tooling gap audit — ${DATE}" --label "$LABEL" --body-file "$REPORT_FILE")"
echo "Opened ${new_url}"

if [[ -n "$open_number" ]]; then
  gh issue close "$open_number" --comment "Superseded by ${new_url}"
  echo "Closed superseded #${open_number}."
fi
