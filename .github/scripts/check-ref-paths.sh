#!/usr/bin/env bash
# check-ref-paths.sh — every path-shaped (slash-containing) non-SKILL.md `.md` or `.json`
# reference in onboard/ prose must resolve (see the two accepted forms below), OR be a known
# exemption. Companion to check-skill-refs.sh (which handles `<path>/SKILL.md`).
#
# `.json` is covered because onboard's prose cites its schemas (e.g. schemas/context-shape-v3.json)
# from several directory depths, and a schema citation is exactly as breakable as a prose one —
# more so, since a schema relocation moves the target out from under every citing depth at once.
#
# Two citation forms are both in use and both legitimate, so a ref resolves if EITHER holds:
# relative to the citing file's directory (`../../schemas/x.json`), or relative to the repo root
# (`onboard/schemas/x.json`, as the research agents/references cite their schemas). A ref that
# resolves under neither is dangling however you read it — that is the bug this catches.
#
# Approach A: a non-resolving ref whose basename exists somewhere under ROOT is a real wrong-path
# bug; one whose basename is absent is a lookalike (a name onboard GENERATES into a target project,
# a target path, or a cross-plugin path) and is exempt. COLLISION_EXEMPT lists the few basenames
# that exist in onboard yet are universal target names (a non-resolving path-shaped ref to one means
# the target project's copy, not ours). Bare refs (no slash) are not extracted — prose mentions like
# "document in CLAUDE.md" are not references. Usage: check-ref-paths.sh [root]   (default: onboard)
#
# Failure and emptiness are both reportable outcomes: a guard that cannot read the tree, finds no files
# in it, or cannot read a file it found must NOT print success. A bad root, an empty dir and a clean
# tree used to be indistinguishable — all three exited 0.
set -uo pipefail

ROOT="${1:-onboard}"
broken=0
scanned=0

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

LIST="$(mktemp "${TMPDIR:-/tmp}/ref-paths.XXXXXX")"
trap 'rm -f "$LIST"' EXIT
if ! find "$ROOT" -name '*.md' ! -iname 'CHANGELOG*' -print0 > "$LIST"; then
  echo "ref-paths: cannot scan '$ROOT' — find failed"
  exit 1
fi

while IFS= read -r -d '' f; do
  scanned=$((scanned + 1))
  dir="$(dirname "$f")"
  # Path-shaped `.md`/`.json` tokens — the `/[seg].<ext>` tail requires a slash, so bare prose
  # mentions are never extracted. Drop `/SKILL.md` (check-skill-refs.sh covers it), leading-slash
  # runtime paths, and `.claude/` generated-into-target paths.
  # Extraction status is checked (grep >=2 = could not read the file), so an unreadable file is an
  # error rather than a file that silently contributes zero refs and zero complaints.
  raw="$(grep -oE '[.A-Za-z0-9_/-]*/[.A-Za-z0-9_-]+\.(md|json)' "$f")"
  st=$?
  if [ "$st" -ge 2 ]; then
    echo "  UNREADABLE: ${f} (grep exit ${st}) — references could not be extracted"
    broken=$((broken + 1))
    continue
  fi
  refs="$(printf '%s\n' "$raw" \
            | grep -vE '/SKILL\.md$' \
            | grep -vE '^/' \
            | grep -vE '^\.claude/' \
            | sort -u)"
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    [ -f "${dir}/${ref}" ] && continue                  # resolves from the citing file → OK
    [ -f "$ref" ] && continue                           # resolves from the repo root → OK
    base="$(basename "$ref")"
    is_collision_exempt "$base" && continue             # curated collision → exempt
    candidates="$(find "$ROOT" -name "$base" | sort | tr '\n' ' ')"
    if [ -n "$candidates" ]; then                       # basename exists → real wrong-path bug
      echo "  BROKEN: ${f} -> '${ref}' (no file at ${dir}/${ref}; basename exists at: ${candidates})"
      broken=$((broken + 1))
    fi                                                  # else: lookalike → exempt
  done <<EOF
$refs
EOF
done < "$LIST"

if [ "$scanned" -eq 0 ]; then
  echo "ref-paths: no .md files under '$ROOT' — nothing was checked"
  exit 1
fi

if [ "$broken" -eq 0 ]; then
  echo "ref-paths: all non-SKILL.md .md/.json references resolve or are exempt (${scanned} file(s) scanned)"
  exit 0
fi
echo "ref-paths: ${broken} broken reference(s)"
exit 1
