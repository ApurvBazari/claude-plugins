#!/usr/bin/env bash
# check-skill-refs.sh — every `<path>/SKILL.md` reference in onboard/ prose must resolve to an
# existing file from its citing file's directory. Guards cross-skill references, which
# check-references.sh does not validate. Usage: check-skill-refs.sh [root]   (default: onboard)
#
# Failure and emptiness are both reportable outcomes: a guard that cannot read the tree, finds no files
# in it, or cannot read a file it found must NOT print success. A bad root, an empty dir and a clean
# tree used to be indistinguishable — all three exited 0.
set -uo pipefail

ROOT="${1:-onboard}"
broken=0
scanned=0

LIST="$(mktemp "${TMPDIR:-/tmp}/skill-refs.XXXXXX")"
trap 'rm -f "$LIST"' EXIT
if ! find "$ROOT" -name '*.md' ! -iname 'CHANGELOG*' -print0 > "$LIST"; then
  echo "skill-refs: cannot scan '$ROOT' — find failed"
  exit 1
fi

while IFS= read -r -d '' f; do
  scanned=$((scanned + 1))
  dir="$(dirname "$f")"
  # Path-shaped tokens ending in /SKILL.md. Match stops at SKILL.md, so `x/SKILL.md § Phase 2`
  # is captured as `x/SKILL.md`. Drop two non-repo classes: leading-slash matches (runtime
  # ${VAR}/skills/... paths) and `.claude/...` matches — the project-relative form documenting a
  # skill onboard GENERATES into a target project (e.g. `.claude/skills/run-tests/SKILL.md`), the
  # documentation analogue of the `.claude/scripts/...` generated-artifact path. Neither denotes a
  # file in THIS repo, so neither is a cross-skill reference this gate should resolve.
  # Extraction status is checked (grep >=2 = could not read the file), so an unreadable file is an
  # error rather than a file that silently contributes zero refs and zero complaints.
  raw="$(grep -oE '[.A-Za-z0-9_/-]+/SKILL\.md' "$f")"
  st=$?
  if [ "$st" -ge 2 ]; then
    echo "  UNREADABLE: ${f} (grep exit ${st}) — references could not be extracted"
    broken=$((broken + 1))
    continue
  fi
  refs="$(printf '%s\n' "$raw" | grep -vE '^/|^\.claude/' | sort -u)"
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [ ! -f "${dir}/${ref}" ]; then
      echo "  BROKEN: ${f} -> '${ref}' (no file at ${dir}/${ref})"
      broken=$((broken + 1))
    fi
  done <<EOF
$refs
EOF
done < "$LIST"

if [ "$scanned" -eq 0 ]; then
  echo "skill-refs: no .md files under '$ROOT' — nothing was checked"
  exit 1
fi

if [ "$broken" -eq 0 ]; then
  echo "skill-refs: all <path>/SKILL.md references resolve (${scanned} file(s) scanned)"
  exit 0
fi
echo "skill-refs: ${broken} broken reference(s)"
exit 1
