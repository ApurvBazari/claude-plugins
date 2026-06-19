#!/usr/bin/env bash
# check-skill-refs.sh — every `<path>/SKILL.md` reference in onboard/ prose must resolve to an
# existing file from its citing file's directory. Guards cross-skill references, which
# check-references.sh does not validate. Usage: check-skill-refs.sh [root]   (default: onboard)
set -uo pipefail

ROOT="${1:-onboard}"
broken=0

while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  # Path-shaped tokens ending in /SKILL.md. Match stops at SKILL.md, so `x/SKILL.md § Phase 2`
  # is captured as `x/SKILL.md`. Drop two non-repo classes: leading-slash matches (runtime
  # ${VAR}/skills/... paths) and `.claude/...` matches — the project-relative form documenting a
  # skill onboard GENERATES into a target project (e.g. `.claude/skills/run-tests/SKILL.md`), the
  # documentation analogue of the `.claude/scripts/...` generated-artifact path. Neither denotes a
  # file in THIS repo, so neither is a cross-skill reference this gate should resolve.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [ ! -f "${dir}/${ref}" ]; then
      echo "  BROKEN: ${f} -> '${ref}' (no file at ${dir}/${ref})"
      broken=$((broken + 1))
    fi
  done < <(grep -oE '[.A-Za-z0-9_/-]+/SKILL\.md' "$f" 2>/dev/null | grep -vE '^/|^\.claude/' | sort -u)
done < <(find "$ROOT" -name '*.md' ! -iname 'CHANGELOG*' -print0)

if [ "$broken" -eq 0 ]; then
  echo "skill-refs: all <path>/SKILL.md references resolve"
  exit 0
fi
echo "skill-refs: ${broken} broken reference(s)"
exit 1
