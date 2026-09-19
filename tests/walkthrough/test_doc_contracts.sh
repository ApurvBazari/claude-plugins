#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PS="$ROOT/walkthrough/skills/create/references/page-scaffold.md"
DS="$ROOT/walkthrough/skills/create/references/design-system.md"
SEED="$ROOT/walkthrough/skills/create/references/seed.html"
RC="$ROOT/walkthrough/skills/render/references/render-contract.md"
CREATE_SKILL="$ROOT/walkthrough/skills/create/SKILL.md"
UPDATE_SKILL="$ROOT/walkthrough/skills/update/SKILL.md"
DOCUMENT_SKILL="$ROOT/walkthrough/skills/document/SKILL.md"
CLAUDEMD="$ROOT/walkthrough/CONVENTIONS.md"
AG="$ROOT/walkthrough/skills/create/references/authoring-guide.md"
CC="$ROOT/walkthrough/skills/create/references/concept-coverage.md"
SM="$ROOT/walkthrough/skills/create/references/session-model.md"
COMP="$ROOT/walkthrough/skills/create/references/completeness.md"
SC="$ROOT/walkthrough/skills/create/references/self-check.md"
RM="$ROOT/walkthrough/skills/update/references/reconstruct-and-merge.md"
IJ="$ROOT/walkthrough/skills/create/references/interactivity.md"
DATA="$ROOT/walkthrough/skills/create/references/components/data.md"
DIAG="$ROOT/walkthrough/skills/create/references/components/diagrams.md"
FT="$ROOT/walkthrough/skills/create/references/components/files-timeline.md"
REASON="$ROOT/walkthrough/skills/create/references/components/reasoning.md"
REVIEW="$ROOT/walkthrough/skills/create/references/components/review.md"
DEC="$ROOT/walkthrough/skills/create/references/components/decisions.md"

fail(){ echo "FAIL: $1"; exit 1; }
ok(){ echo "ok: $1"; }

for f in "$PS" "$DS" "$SEED" "$RC" "$CREATE_SKILL" "$UPDATE_SKILL" "$DOCUMENT_SKILL" "$CLAUDEMD" \
         "$AG" "$CC" "$SM" "$COMP" "$SC" "$RM" "$IJ" "$DATA" "$DIAG" "$FT" "$REASON" "$REVIEW" "$DEC"; do
  [ -s "$f" ] || fail "missing $f"
done

# --- page-scaffold.md is the single base-CSS home; seed.html is a demo, not a source ---
grep -qF -- '--accent:#22d3ee' "$PS" || fail "page-scaffold.md must carry the dark-theme --accent token"
grep -qF -- '--accent:#c05e2b' "$PS" || fail "page-scaffold.md must carry the light-theme --accent token"
grep -qF -- 'html.js section:not(.vis)' "$PS" || fail "page-scaffold.md must gate hidden state on html.js section:not(.vis)"
grep -qF -- 'counter-increment:sec' "$PS" || fail "page-scaffold.md must carry the auto-numbering counter-increment:sec"

grep -qF -- '--bg-deep:#08090c;--bg-card' "$DS" && fail "design-system.md must not re-materialize the packed :root token line — page-scaffold.md is the single base-CSS home"
grep -qi 'page-scaffold.md' "$DS" || fail "design-system.md must name page-scaffold.md"
grep -qi 'base-CSS home' "$DS" || fail "design-system.md must name page-scaffold.md as the base-CSS home"

grep -qF -- 'html.js section:not(.vis)' "$SEED" || fail "seed.html must use the same html.js section:not(.vis) reveal gate"
grep -qF -- 'counter-increment:sec' "$SEED" || fail "seed.html must carry counter-increment:sec"
grep -qF -- 'section{opacity:0' "$SEED" && fail "seed.html must not carry a bare, un-gated section{opacity:0} reveal rule"

if grep -rn 'lifted verbatim from seed.html\|never invent base styles' "$ROOT/walkthrough" >/dev/null 2>&1; then
  fail "no walkthrough/ doc may claim seed.html as the base-CSS source (base-CSS home is page-scaffold.md)"
fi
ok "page-scaffold.md single base-CSS home; seed.html demo-only"

# --- render-contract.md is the single source for the shared render stages ---
grep -qi '### select' "$RC" || fail "render-contract.md must define the select stage"
grep -qi '### assemble' "$RC" || fail "render-contract.md must define the assemble stage"
grep -qi '### self-check' "$RC" || fail "render-contract.md must define the self-check stage"
grep -qi '### write' "$RC" || fail "render-contract.md must define the write stage"

for f in "$CREATE_SKILL" "$UPDATE_SKILL" "$DOCUMENT_SKILL"; do
  grep -q 'render-contract.md' "$f" || fail "$(basename "$(dirname "$f")")/SKILL.md must defer the shared render stages to render-contract.md"
done
grep -q 'render-contract.md' "$CLAUDEMD" || fail "CLAUDE.md must defer the shared render stages to render-contract.md"

grep -qi 'not\*\* invoke the .render. skill\|do not invoke the render skill' "$CLAUDEMD" || fail "CLAUDE.md must state producers do NOT invoke the render skill (they PERFORM the contract)"
ok "render-contract.md is the single source; producers defer, never invoke render"

# --- concept-type -> renderer mapping lives once, in concept-coverage.md ---
grep -qE 'type:branching-logic|type:data-model|type:hierarchy|type:layering|type:causal-chain' "$AG" && fail "authoring-guide.md must not duplicate the concept-type mapping rows — concept-coverage.md is the single source"
grep -qi 'concept-coverage.md' "$AG" || fail "authoring-guide.md must point to concept-coverage.md for concept-type routing"
grep -qi 'dependency-depth' "$CC" || fail "concept-coverage.md data-model row must still describe dependency-depth banding"
ok "concept-type mapping lives once, in concept-coverage.md"

# --- the concepts[] ledger is gone; the anti-force-fit invariant is re-anchored at selection time ---
grep -q 'concepts\[\]' "$SM" && fail "session-model.md must not declare a concepts[] ledger field"
grep -qi 'Explained.*concepts' "$COMP" && fail "completeness.md must not carry an 'Explained N concepts' coverage line"
grep -qi 'Part 1b' "$COMP" && fail "completeness.md must not carry a Part 1b ledger step"
grep -qi 'Ledger cross-reference' "$SC" && fail "self-check.md must not carry a Ledger cross-reference bullet"
grep -qi 'Rebuild concepts\[\]' "$RM" && fail "reconstruct-and-merge.md must not instruct rebuilding a concepts[] ledger"
if grep -rn 'concepts\[\]' "$ROOT/walkthrough" 2>/dev/null | grep -v CHANGELOG >/dev/null; then
  grep -rn 'concepts\[\]' "$ROOT/walkthrough" | grep -v CHANGELOG
  fail "concepts[] must be fully retired from walkthrough/ docs (CHANGELOG history is the only permitted mention)"
fi
grep -qi 'registered in .concept-coverage.md.\|registered concept-type' "$SC" || fail "self-check.md must carry a re-anchored structural row tracing renderers to concept-coverage.md (no ledger)"
ok "concepts[] ledger retired; invariant re-anchored at selection time"

# --- CLAUDE.md accurately attributes which gate runs in which skills ---
grep -qi 'shared by all three skills' "$CLAUDEMD" && fail "CLAUDE.md must not claim self-check is shared by all three (user-facing) skills only — it also runs in render"
grep -qi 'all four skills' "$CLAUDEMD" || fail "CLAUDE.md must attribute self-check to all four skills (create/update/document/render)"
grep -qi 'three user-facing skills' "$CLAUDEMD" || fail "CLAUDE.md must attribute completeness to the three user-facing skills only"
grep -qi '\bsix\b' "$CLAUDEMD" || fail "CLAUDE.md must still reference the six shared references/ files"
ok "CLAUDE.md gate attribution is accurate (self-check x4, completeness x3)"

# --- every non-native onclick interactive is keyboard-operable ---
grep -qi 'role="button"' "$IJ" || fail "interactivity.md must document the role=\"button\" keyboard contract"
grep -qE "e\.key==='Enter'\|\|e\.key===' '" "$IJ" || fail "interactivity.md keydown handler must activate on Enter/Space"
grep -qF -- '[role="button"]' "$IJ" || fail "interactivity.md keydown handler must be keyed on [role=\"button\"]"

for f in "$DIAG" "$FT" "$REASON" "$DATA" "$REVIEW" "$DEC"; do
  grep -q 'role="button"' "$f" || fail "$(basename "$f") recipe must carry role=\"button\" on its onclick interactives"
  grep -q 'tabindex' "$f" || fail "$(basename "$f") recipe must carry tabindex on its onclick interactives"
done

grep -qF -- 'class="e" onclick="openSurface(' "$DATA" || fail "data.md must keep the .rel .e ERD-summary onclick wiring"
if grep -F 'class="e" onclick="openSurface(' "$DATA" | grep -q 'role='; then
  fail "data.md's .rel .e ERD-summary span is a deliberate pointer-only carve-out — it must NOT carry role=\"button\""
fi

grep -qi 'onclick.*keyboard-operable\|keyboard-operable' "$SC" || fail "self-check.md must carry the focusability/keyboard-operable structural row"
ok "onclick interactives are keyboard-operable (with the documented .rel .e carve-out)"

# --- COUNTS (derived) — CLAUDE.md names every skill directory that actually exists ---
EXPECTED_SKILLS="create document render update"
expected_count=$(echo "$EXPECTED_SKILLS" | wc -w | tr -d ' ')
actual_count=$(find "$ROOT/walkthrough/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$actual_count" -eq "$expected_count" ] || fail "expected $expected_count walkthrough skills (create/document/render/update), found $actual_count — update this belt if the skill set changed"
for d in "$ROOT"/walkthrough/skills/*/; do
  s="$(basename "$d")"
  grep -q "$s" "$CLAUDEMD" || fail "CLAUDE.md must mention skill '$s'"
done
ok "COUNTS: CLAUDE.md names every skill directory that exists (derived, not a bare literal)"

# --- provenance footer: scaffold-owned, one source, exempt from the document rebrand ---
grep -qF -- 'footer.wt-credit{' "$PS" \
  || fail "page-scaffold.md must carry the .wt-credit provenance footer CSS"
grep -qF -- '<footer class="wt-credit">' "$PS" \
  || fail "page-scaffold.md shell must emit the provenance footer element"
grep -qF -- 'https://github.com/ApurvBazari/claude-plugins' "$PS" \
  || fail "the provenance footer must link back to the marketplace repo"
grep -qF -- 'wt-credit' "$DOCUMENT_SKILL" \
  || fail "document/SKILL.md must state whether the chrome rebrand touches the provenance footer — an unreconciled rebrand rule silently strips it"
grep -qF -- 'wt-credit' "$RM" \
  || fail "reconstruct-and-merge.md must declare the provenance footer scaffold-owned (recovered into no model field)"
# the footer is provenance, not a tracking beacon
grep -qE 'wt-credit[^\n]*(utm_|\?ref=|track)' "$PS" \
  && fail "the provenance footer must not carry tracking parameters"
ok "FOOTER: provenance footer single-sourced in page-scaffold.md, reconciled in document + update, untracked"

echo "PASS: walkthrough doc contracts"
