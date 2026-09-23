#!/usr/bin/env bash
# check-action-pinning.sh — verify every external GitHub Action `uses:` is pinned to a full
# 40-character commit SHA followed by a `# <version>` comment.
#
# Supply-chain hardening: tags and branches are mutable — a compromised or force-moved ref
# silently changes the code a workflow runs, and a version tag is no exception. A commit SHA
# cannot move. The version comment keeps the pin readable, and Dependabot
# (.github/dependabot.yml) bumps the SHA and the comment together.
#
# Accepted:
#   uses: owner/action@<40-hex-sha> # v1.2.3
#   uses: owner/repo/path@<40-hex-sha> # v1.2.3
#   uses: ./local/action                 (local — not a supply-chain edge)
#   uses: docker://image:tag             (container image, not an Actions ref)
# Rejected: version tags (@v4), semver (@1.2.3), branches (@main), moving tags (@beta),
#   short or uppercase SHAs, a missing ref, and a full SHA without a version comment.
#
# Usage: check-action-pinning.sh [workflow-dir]    (default: .github/workflows)

set -euo pipefail

workflow_dir="${1:-.github/workflows}"
failed=0

if [[ ! -d "$workflow_dir" ]]; then
  echo "No workflows directory — skipping"
  exit 0
fi

re_uses='^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*(.*)$'
re_sha='^[0-9a-f]{40}$'
re_comment='#[[:space:]]*[^[:space:]]'

while IFS= read -r -d '' file; do
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    [[ "$line" =~ $re_uses ]] || continue
    rest="${BASH_REMATCH[2]}"
    target="${rest%%[[:space:]#]*}"
    target="${target#[\"\']}"
    target="${target%[\"\']}"
    case "$target" in
      ./*|docker://*) continue ;;
    esac
    ref=""
    [[ "$target" == *@* ]] && ref="${target##*@}"
    if ! [[ "$ref" =~ $re_sha ]]; then
      echo "::error file=${file},line=${lineno}::'${target}' is not pinned to a full commit SHA — use owner/action@<40-hex-sha> # <version>" >&2
      failed=1
    elif ! [[ "${rest#*"$ref"}" =~ $re_comment ]]; then
      echo "::error file=${file},line=${lineno}::'${target}' has no '# <version>' comment after the SHA" >&2
      failed=1
    fi
  done < "$file"
done < <(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

if [[ "$failed" -eq 1 ]]; then
  echo "" >&2
  echo "One or more GitHub Actions are not pinned to a commit SHA with a version comment." >&2
  echo "See: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions" >&2
  exit 1
fi

echo "All GitHub Actions are pinned to full commit SHAs with version comments"
