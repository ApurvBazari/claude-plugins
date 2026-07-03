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
grep -qF -- '.rel .e:hover' "$DATA" || fail "data.md must give .rel summary entity names the navigable hover affordance (.rel .e:hover)"
grep -q 'class="e" onclick="openSurface(' "$DATA" || fail "data.md recipe must wire .rel entity spans to openSurface (summary→entity star links, #14)"
grep -qi 'back-compat\|alias\|\.erd\b' "$DATA" || fail "data.md must keep .erd as a back-compat alias"
# tokens-only in the recipe: no raw 6-hex, no rgba color literals (color-mix only) except the card shadow
if grep -vE '^[[:space:]]*--|data:image' "$DATA" | grep -Eq '#[0-9a-fA-F]{6}'; then fail "data.md ERD recipe has raw hex — tokens only"; fi

# --- interactivity.md: hover-connector ---
JS="$ROOT/walkthrough/skills/create/references/interactivity.md"
[ -s "$JS" ] || fail "missing $JS"
grep -q 'erd-wires' "$JS"    || fail "interactivity.md must query svg.erd-wires"
grep -q "querySelectorAll('.erd-l')" "$JS" || fail "interactivity.md must iterate .erd-l containers"
grep -q 'data-target' "$JS"  || fail "interactivity.md must bind .fld[data-target] rows"
grep -qi 'getBoundingClientRect' "$JS" || fail "interactivity.md must position via getBoundingClientRect"
grep -qi 'prefers-reduced-motion' "$JS" || fail "interactivity.md must gate the draw-in on reduced-motion"
grep -qiE 'mouseenter|focus' "$JS" || fail "interactivity.md must draw on hover/focus"
# shellcheck disable=SC2015  # A && B || fail: fail runs when A(present) or B(no-resize) is false — intended
grep -q 'addEventListener' "$JS" && ! grep -qi "addEventListener('resize'" "$JS" || fail "no resize listener needed (transient line only)"

# --- session-model.md: dataModel ---
SM="$ROOT/walkthrough/skills/create/references/session-model.md"
[ -s "$SM" ] || fail "missing $SM"
grep -q 'dataModel' "$SM" || fail "session-model must document the dataModel field"
grep -qiE 'entities' "$SM" || fail "dataModel must document entities[]"
grep -qiE 'cardinality' "$SM" || fail "dataModel fields must carry cardinality on ref"
grep -qE 'never hand-authored' "$SM" || fail "session-model must note layer/edgeKind are computed (not authored)"

# --- authoring-guide.md: ERD layering + fidelity ---
AG="$ROOT/walkthrough/skills/create/references/authoring-guide.md"
[ -s "$AG" ] || fail "missing $AG"
grep -qi 'ERD layering' "$AG" || fail "authoring-guide must document 'ERD layering'"
grep -qiE 'longest-path|1 \+ max|max\(layer' "$AG" || fail "authoring-guide must give the longest-path rank rule"
grep -qiE 'back-edge|back edge' "$AG" || fail "authoring-guide must specify back-edge removal"
grep -qiE 'self-loop|self-reference' "$AG" || fail "authoring-guide must exclude self-loops from layering"
grep -qiE 'neutral|ambiguous' "$AG" || fail "authoring-guide must specify neutral-label fallback"
grep -qiE 'mark|never drop|not.*drop' "$AG" || fail "authoring-guide must require broken edges be marked, not dropped"
grep -qi 'out-degree' "$AG" || fail "authoring-guide must define more-dependent via out-degree (T5 determinism tie-break)"
grep -qi 'edge-declaration order' "$AG" || fail "authoring-guide must fix the DFS visitation order (edge-declaration order)"

# --- self-check.md + concept-coverage.md ---
SC="$ROOT/walkthrough/skills/create/references/self-check.md"
CC="$ROOT/walkthrough/skills/create/references/concept-coverage.md"
[ -s "$SC" ] || fail "missing $SC"
[ -s "$CC" ] || fail "missing $CC"
grep -qiE 'ERD.*(exempt|except)|except the ERD|ERD is exempt' "$SC" || fail "self-check #18 must carve out the ERD"
grep -qF -- '.erd-l' "$SC" || fail "self-check ledger must list the layered ERD structural class"
grep -qi 'marked, not dropped' "$SC" || fail "self-check must assert back-edges/self-loops are marked"
grep -qi 'dependency-depth' "$CC" || fail "concept-coverage data-model row must mention layering"

echo "PASS: erd layered doc-contract"
