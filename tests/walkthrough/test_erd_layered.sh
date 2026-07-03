#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DATA="$ROOT/walkthrough/skills/create/references/components/data.md"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$DATA" ] || fail "missing $DATA"

# --- data.md: layered ERD recipe ---
grep -q 'erd-l' "$DATA"       || fail "data.md must define the layered container .erd-l"
grep -q 'erd-wires' "$DATA"   || fail "data.md must define the hover-overlay svg.erd-wires"
grep -qE '\.band(\b|[^-])' "$DATA" || fail "data.md must define layered .band"
grep -q 'band-label' "$DATA"  || fail "data.md must define .band-label"
grep -q 'data-ent='  "$DATA"  || fail "data.md entities must carry data-ent"
grep -q 'data-target=' "$DATA" || fail "data.md FK rows must carry data-target"
grep -q 'ref self'   "$DATA"  || fail "data.md must document the self-reference ref (.ref.self)"
grep -q 'ref cyc'    "$DATA"  || fail "data.md must document the back-edge ref (.ref.cyc)"
grep -q 'class="rels"' "$DATA" || fail "data.md must document the relationship summary (.rels)"
grep -qi 'openSurface' "$DATA" || fail "data.md entities must wire openSurface"
grep -qi 'back-compat\|alias\|\.erd\b' "$DATA" || fail "data.md must keep .erd as a back-compat alias"
# tokens-only in the recipe: no raw 6-hex, no rgba color literals (color-mix only) except the card shadow
if grep -vE '^[[:space:]]*--|data:image' "$DATA" | grep -Eq '#[0-9a-fA-F]{6}'; then fail "data.md ERD recipe has raw hex — tokens only"; fi

echo "PASS: erd layered doc-contract"
