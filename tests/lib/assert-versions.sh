#!/usr/bin/env bash
# Usage: assert-versions.sh <plugin-name>
# Asserts <plugin>/.claude-plugin/plugin.json version == marketplace.json entry
# == the plugin CHANGELOG's first "## X.Y.Z" heading. plugin.json is the source of truth.
# Set ROOT_OVERRIDE to point at an alternate repo root (used by the helper's own test).
set -euo pipefail
plugin="${1:?usage: assert-versions.sh <plugin-name>}"
ROOT="${ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PJSON="$ROOT/$plugin/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/$plugin/CHANGELOG.md"
fail(){ echo "FAIL: assert-versions[$plugin]: $1"; exit 1; }
for f in "$PJSON" "$MKT" "$CHANGELOG"; do [ -s "$f" ] || fail "missing $f"; done

PV=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$PJSON")
MV=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(next(p["version"] for p in d["plugins"] if p["name"]==sys.argv[2]))' "$MKT" "$plugin")
# First semver appearing on a markdown heading line (## X.Y.Z or ## [X.Y.Z] or ## vX.Y.Z).
CV=$(grep -oE '^#+[[:space:]]+v?\[?[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

[ -n "$CV" ] || fail "no 'X.Y.Z' heading found in $CHANGELOG"
[ "$MV" = "$PV" ] || fail "marketplace entry ($MV) != plugin.json ($PV)"
[ "$CV" = "$PV" ] || fail "CHANGELOG top heading ($CV) != plugin.json ($PV)"
echo "assert-versions[$plugin]: $PV consistent (plugin.json = marketplace = CHANGELOG)"
