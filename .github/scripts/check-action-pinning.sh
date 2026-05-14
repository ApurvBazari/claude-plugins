#!/usr/bin/env bash
# check-action-pinning.sh — verify every GitHub Action `uses:` is pinned to a
# version or SHA, not a mutable branch/tag like master/main/latest/HEAD/beta.
#
# Supply-chain hardening: if an action maintainer's default branch (or any
# moving tag like @beta) is compromised, workflows pinned to that ref auto-
# pull the attacker's code on the next run. Versions and SHAs freeze the
# action at a known-good state.
#
# Allowed forms:
#   uses: owner/action@v1                (version tag)
#   uses: owner/action@1.2.3             (semver)
#   uses: owner/action@abc1234...        (full SHA, 40 chars)
#
# Rejected forms:
#   uses: owner/action@master | main | develop | latest | HEAD
#   uses: owner/action@beta | alpha | next | canary | nightly
#   uses: owner/action@rc | dev | edge | preview | staging
#
# Allowlist (explicit, documented exceptions):
#   anthropics/claude-code-action@beta
#     — Anthropic's official action ships features on @beta; we accept the
#       upstream-trust assumption to get auto-upgrades without manual bumps.
#       Tracked PR #50 / 2026-05-14 audit finding M3.
#       To revoke: remove the entry and pin every claude-code-action ref to
#       a specific version tag (e.g., @v1) or commit SHA.

set -euo pipefail

failed=0
workflow_dir=".github/workflows"

# Documented exceptions. Match against the full `owner/action@ref` form so
# both halves matter — partial matches (just the owner, just the ref) are
# rejected by design.
ALLOWLIST=(
  "anthropics/claude-code-action@beta"
)

if [[ ! -d "$workflow_dir" ]]; then
  echo "No workflows directory — skipping"
  exit 0
fi

while IFS= read -r -d '' file; do
  # Find all `uses:` lines that reference an external action (owner/repo format)
  # and check their ref is not a mutable branch/tag.
  while IFS= read -r line; do
    # Extract the owner/action@ref string after `uses:`
    uses_target="${line#*uses:}"
    uses_target="${uses_target#"${uses_target%%[![:space:]]*}"}"   # ltrim
    uses_target="${uses_target%%[[:space:]]*}"                     # rtrim
    uses_target="${uses_target%\"}"
    uses_target="${uses_target#\"}"

    # Skip if explicitly allowlisted (owner/action@ref form)
    is_allowed=0
    for allowed in "${ALLOWLIST[@]}"; do
      if [[ "$uses_target" == "$allowed" ]]; then
        is_allowed=1
        break
      fi
    done
    if [[ "$is_allowed" -eq 1 ]]; then
      continue
    fi

    # Extract the ref after the last `@`
    ref="${uses_target##*@}"

    case "$ref" in
      master|main|latest|HEAD|develop|beta|alpha|next|canary|nightly|rc|dev|edge|preview|staging)
        lineno=$(grep -n -F "$line" "$file" | head -1 | cut -d: -f1)
        echo "::error file=${file},line=${lineno}::Action pinned to mutable ref '${ref}' — pin to a version tag (e.g. @v3) or full commit SHA instead" >&2
        echo "  → ${file}:${lineno}: ${line}" >&2
        echo "  → If this ref is intentional (trusted publisher), add '${uses_target}' to the ALLOWLIST in this script with a one-line justification." >&2
        failed=1
        ;;
    esac
  done < <(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+' "$file" || true)
done < <(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

if [[ "$failed" -eq 1 ]]; then
  echo "" >&2
  echo "One or more GitHub Actions are pinned to mutable refs. Pin to a version tag or SHA, or add a documented allowlist entry." >&2
  echo "See: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions" >&2
  exit 1
fi

echo "All GitHub Actions are pinned to immutable refs (or documented allowlist exceptions)"
