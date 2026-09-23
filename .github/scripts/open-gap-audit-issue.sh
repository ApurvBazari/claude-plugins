#!/usr/bin/env bash
set -euo pipefail

# open-gap-audit-issue.sh — file the tooling-gap report as a GitHub issue when the drift changed.
# Usage: open-gap-audit-issue.sh <DATE> <REPORT_FILE> <FINDINGS_FILE>
# Env:   GH_TOKEN (gh auth; needs issues: write)
#
# Every decision comes from FINDINGS_FILE (collect-audit-findings.sh output), never from the
# model-written report, so rewording can neither open a duplicate nor close real drift:
#   no findings, no open issue          → nothing
#   no findings, open issue(s)          → close them (drift resolved)
#   an open issue carries this fingerprint → nothing
#   otherwise                            → open an issue, close the ones it supersedes
# The fingerprint travels in the issue body as <!-- audit-fingerprint: … -->. The body always goes
# through --body-file: report text is model output and is never expanded.

DATE="${1:-}"
REPORT_FILE="${2:-}"
FINDINGS_FILE="${3:-}"
LABEL="tooling-audit"
HEADER_PREFIX="# Tooling Gap Audit — "

if [[ -z "$DATE" || -z "$REPORT_FILE" || -z "$FINDINGS_FILE" ]]; then
  echo "Usage: open-gap-audit-issue.sh <DATE> <REPORT_FILE> <FINDINGS_FILE>" >&2
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

if [[ ! -f "$FINDINGS_FILE" ]]; then
  echo "::error::No findings file at ${FINDINGS_FILE} — run collect-audit-findings.sh first" >&2
  exit 1
fi

# Normalise (drop blank lines, sort, dedupe) so ordering and spacing never change the fingerprint.
findings="$(grep -v '^[[:space:]]*$' "$FINDINGS_FILE" | LC_ALL=C sort -u || true)"
fingerprint="$(printf '%s\n' "$findings" | git hash-object --stdin)"
marker="<!-- audit-fingerprint: ${fingerprint} -->"

open_json="$(gh issue list --label "$LABEL" --state open --limit 50 --json number,body)"
open_numbers="$(jq -r '.[].number' <<<"$open_json")"

if [[ -z "$findings" ]]; then
  if [[ -z "$open_numbers" ]]; then
    echo "No tooling drift and no open audit issue — nothing to file."
    exit 0
  fi
  while IFS= read -r number; do
    gh issue close "$number" --comment "Audit on ${DATE}: no tooling drift detected. Closing."
    echo "Drift resolved — closed #${number}."
  done <<<"$open_numbers"
  exit 0
fi

matching="$(jq -r --arg m "$marker" '[.[] | select(.body | contains($m))][0].number // empty' <<<"$open_json")"
if [[ -n "$matching" ]]; then
  echo "Findings unchanged vs open issue #${matching} — skipping."
  exit 0
fi

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
{
  cat "$REPORT_FILE"
  printf '\n\n%s\n' "$marker"
} > "$body_file"

gh label create "$LABEL" --color "5319e7" --description "Tooling-gap audit findings" --force >/dev/null
new_url="$(gh issue create --title "Tooling gap audit — ${DATE}" --label "$LABEL" --body-file "$body_file")"
echo "Opened ${new_url}"

if [[ -n "$open_numbers" ]]; then
  while IFS= read -r number; do
    gh issue close "$number" --comment "Superseded by ${new_url}"
    echo "Closed superseded #${number}."
  done <<<"$open_numbers"
fi
