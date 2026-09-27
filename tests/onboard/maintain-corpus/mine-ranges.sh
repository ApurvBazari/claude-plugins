#!/usr/bin/env bash
# mine-ranges.sh <repo> [max] — list candidate commit ranges for ranges.json (read-only).
#
# A candidate is a commit whose diff touches a dependency manifest, a package.json, or adds a
# directory of source files. Columns: base, head, onboarded at head (meta/-), CLAUDE.md files the
# same commit edited (their edit is the ground truth for inform items), subject.
# Labelling stays manual: read the range's diff and tooling, write the expected items, then run
# tests/onboard/test_maintain_corpus.sh. Never copy detect's output into a label unreviewed.
set -euo pipefail
repo="${1:?usage: mine-ranges.sh <repo> [max]}"
max="${2:-40}"
git -C "$repo" log --format='%H' -M --diff-filter=AMDR -n "$max" -- \
    '*package.json' '*pyproject.toml' '*requirements*.txt' '*Cargo.toml' '*go.mod' '*Gemfile' |
while IFS= read -r sha; do
  base="$(git -C "$repo" rev-parse --verify --quiet "$sha^" || true)"
  [ -n "$base" ] || continue
  meta="-"
  if git -C "$repo" cat-file -e "$sha:.claude/onboard-meta.json" 2>/dev/null; then meta="meta"; fi
  edited="$(git -C "$repo" diff --name-only "$base" "$sha" | grep -c 'CLAUDE\.md$' || true)"
  printf '%s %s %-4s claude-md-edits=%s  %s\n' "${base:0:10}" "${sha:0:10}" "$meta" "$edited" \
    "$(git -C "$repo" log -1 --format=%s "$sha")"
done
