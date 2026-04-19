#!/usr/bin/env bash
# check-action-pinning.sh — verify every GitHub Action `uses:` is pinned to a
# version or SHA, not a mutable branch/tag like master/main/latest/HEAD.
#
# Supply-chain hardening: if an action maintainer's default branch is
# compromised, workflows pinned to @master auto-pull the attacker's code on
# the next run. Versions and SHAs freeze the action at a known-good state.
#
# Allowed forms:
#   uses: owner/action@v1                (version tag)
#   uses: owner/action@1.2.3             (semver)
#   uses: owner/action@2.0.0             (semver)
#   uses: owner/action@abc1234...        (full SHA, 40 chars)
#
# Rejected forms:
#   uses: owner/action@master
#   uses: owner/action@main
#   uses: owner/action@latest
#   uses: owner/action@HEAD

set -euo pipefail

failed=0
workflow_dir=".github/workflows"

if [[ ! -d "$workflow_dir" ]]; then
  echo "No workflows directory — skipping"
  exit 0
fi

while IFS= read -r -d '' file; do
  # Find all `uses:` lines that reference an external action (owner/repo format)
  # and check their ref is not a mutable branch/tag.
  while IFS= read -r line; do
    # Extract the ref after the last `@`
    ref="${line##*@}"
    ref="${ref%%[[:space:]]*}"   # trim trailing whitespace/comment
    ref="${ref%\"}"              # trim trailing quote if any
    ref="${ref#\"}"              # trim leading quote if any

    case "$ref" in
      master|main|latest|HEAD|develop)
        lineno=$(grep -n -F "$line" "$file" | head -1 | cut -d: -f1)
        echo "::error file=${file},line=${lineno}::Action pinned to mutable ref '${ref}' — pin to a version tag (e.g. @v3) or full commit SHA instead" >&2
        echo "  → ${file}:${lineno}: ${line}" >&2
        failed=1
        ;;
    esac
  done < <(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+' "$file" || true)
done < <(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

if [[ "$failed" -eq 1 ]]; then
  echo "" >&2
  echo "One or more GitHub Actions are pinned to mutable refs. Pin to a version tag or SHA." >&2
  echo "See: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions" >&2
  exit 1
fi

echo "All GitHub Actions are pinned to immutable refs (version tags or SHAs)"
