#!/usr/bin/env bash
# check-ref-paths.sh — every path-shaped (slash-containing) non-SKILL.md `.md` reference in
# onboard/ prose must resolve from its citing file's directory, OR be a known exemption.
# Companion to check-skill-refs.sh (which handles `<path>/SKILL.md`).
#
# Approach A: a non-resolving ref whose basename exists somewhere under ROOT is a real wrong-path
# bug; one whose basename is absent is a lookalike (a name onboard GENERATES into a target project,
# a target path, or a cross-plugin path) and is exempt. COLLISION_EXEMPT lists the few basenames
# that exist in onboard yet are universal target names (a non-resolving path-shaped ref to one means
# the target project's copy, not ours). Bare refs (no slash) are not extracted — prose mentions like
# "document in CLAUDE.md" are not references. Usage: check-ref-paths.sh [root]   (default: onboard)
set -uo pipefail

ROOT="${1:-onboard}"
broken=0

COLLISION_EXEMPT=(
  "CLAUDE.md"   # onboard/CLAUDE.md exists, but `src/.../CLAUDE.md` etc. mean the target project's
)

is_collision_exempt() {
  local base="$1" x
  for x in "${COLLISION_EXEMPT[@]}"; do
    [ "$base" = "$x" ] && return 0
  done
  return 1
}

while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  # Path-shaped `.md` tokens — the `/[seg].md` tail requires a slash, so bare prose mentions are
  # never extracted. Drop `/SKILL.md` (check-skill-refs.sh covers it), leading-slash runtime paths,
  # and `.claude/` generated-into-target paths.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    [ -f "${dir}/${ref}" ] && continue                  # resolves → OK
    base="$(basename "$ref")"
    is_collision_exempt "$base" && continue             # curated collision → exempt
    candidates="$(find "$ROOT" -name "$base" 2>/dev/null | sort | tr '\n' ' ')"
    if [ -n "$candidates" ]; then                       # basename exists → real wrong-path bug
      echo "  BROKEN: ${f} -> '${ref}' (no file at ${dir}/${ref}; basename exists at: ${candidates})"
      broken=$((broken + 1))
    fi                                                  # else: lookalike → exempt
  done < <(grep -oE '[.A-Za-z0-9_/-]*/[.A-Za-z0-9_-]+\.md' "$f" 2>/dev/null \
             | grep -vE '/SKILL\.md$' \
             | grep -vE '^/' \
             | grep -vE '^\.claude/' \
             | sort -u)
done < <(find "$ROOT" -name '*.md' ! -iname 'CHANGELOG*' -print0)

if [ "$broken" -eq 0 ]; then
  echo "ref-paths: all non-SKILL.md .md references resolve or are exempt"
  exit 0
fi
echo "ref-paths: ${broken} broken reference(s)"
exit 1
