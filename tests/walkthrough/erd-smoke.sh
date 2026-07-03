#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/tests/walkthrough/fixtures/erd-sample.html"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$F" ] || fail "fixture missing: tests/walkthrough/fixtures/erd-sample.html"
grep -q '<script src' "$F" && fail "not self-contained: external <script src>"
grep -q '<img' "$F" && fail "not self-contained: <img> present"
grep -q '<link rel=stylesheet' "$F" && fail "not self-contained: external stylesheet"
grep -q 'class="erd-l"' "$F"     || fail "layered container .erd-l missing"
grep -q 'class="erd-wires"' "$F" || fail "hover overlay .erd-wires missing"
grep -q 'class="band"' "$F"      || fail "no layered bands"
grep -q 'class="band-label"' "$F" || fail "no band labels"
grep -q 'data-ent='  "$F"        || fail "entities not keyed with data-ent"
grep -q 'data-target=' "$F"      || fail "FK rows not keyed with data-target"
grep -qE 'class="ref"'      "$F" || fail "no forward field-anchored ref (.ref)"
grep -q 'class="ref self"'  "$F" || fail "self-reference not marked (.ref.self)"
grep -q 'class="ref cyc"'   "$F" || fail "back-edge not marked (.ref.cyc)"
grep -q 'class="rels"'      "$F" || fail "relationship summary (.rels) missing"
grep -q "openSurface('"     "$F" || fail "entities not wired to openSurface"
# tokens-only: raw 6-hex only on token-def lines (start with --) and the grain data-URI
if grep -vE 'data:image|feTurbulence' "$F" | grep -vE '^[[:space:]]*--' | grep -Eq '#[0-9a-fA-F]{6}'; then
  fail "raw hex outside grain SVG / token defs — tokens only"
fi
# inlined <script> must parse (skip gracefully if node absent)
if command -v node >/dev/null 2>&1; then
  TMP="$(mktemp -t erdjs.XXXXXX)"; JS="$TMP.js"
  awk '/<script>/{f=1;next} /<\/script>/{f=0} f' "$F" > "$JS"
  if [ -s "$JS" ]; then node --check "$JS" || { rm -f "$TMP" "$JS"; fail "inlined <script> is not valid JS"; }; fi
  rm -f "$TMP" "$JS"
else
  echo "  (node absent — skipped node --check)"
fi
echo "PASS: erd layered smoke"
