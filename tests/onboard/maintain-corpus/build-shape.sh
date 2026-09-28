#!/usr/bin/env bash
# build-shape.sh <shape> <dest> — materialise a shape fixture as a committed, onboarded git repo.
# Fixtures store CLAUDE.md as CLAUDE.fixture.md and .claude/ as dot-claude/ so this repository never
# loads them as project memory and its .gitignore (which ignores .claude/) never hides them.
# Sets no git identity itself: callers export GIT_CONFIG_GLOBAL=/dev/null and an author.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shape="$1" dest="$2"
src="$HERE/shapes/$shape"
[ -d "$src" ] || { echo "build-shape: no shape '$shape'" >&2; exit 2; }
mkdir -p "$dest"
cp -R "$src/." "$dest/"
find "$dest" -depth -name CLAUDE.fixture.md -exec sh -c 'mv "$1" "$(dirname "$1")/CLAUDE.md"' _ {} \;
if [ -d "$dest/dot-claude" ]; then mv "$dest/dot-claude" "$dest/.claude"; fi
git -C "$dest" init -q
git -C "$dest" add -A
git -C "$dest" commit -qm "shape: $shape"
