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
grep -qE 'wt-credit.*(utm_|\?ref=|track)' "$PS" \
  && fail "the provenance footer must not carry tracking parameters"
ok "FOOTER: provenance footer single-sourced in page-scaffold.md, reconciled in document + update, untracked"

# --- published examples are current-engine renders carrying the provenance footer ---
ex_count=0
for ex in "$ROOT"/site/walkthrough/examples/*.html; do
  [ -e "$ex" ] || continue
  ex_count=$((ex_count+1))
  grep -qF 'wt-credit' "$ex" \
    || fail "published example $(basename "$ex") predates the provenance footer - re-render it with the current engine"
  grep -qiE 'vicario|matali|mimir|asgard|iris|jamakhata|wallet' "$ex" \
    && fail "published example $(basename "$ex") leaks an unreleased-project reference"
done
[ "$ex_count" -ge 1 ] || fail "expected at least 1 published example under site/walkthrough/examples/, found $ex_count"
ok "EXAMPLES: $ex_count published example(s), provenance footer present, leak-free"

# --- 1.6.0: the system map replaces the architecture map and the dependency graph ---
SYS="$ROOT/walkthrough/skills/create/references/components/system-map.md"
IDX="$ROOT/walkthrough/skills/create/references/components/index.md"
for f in "$SYS" "$IDX"; do
  [ -s "$f" ] || fail "missing $f"
done

if grep -qE '^## (Architecture map|Dependency graph)' "$DIAG"; then fail "diagrams.md must not carry the retired architecture-map or dependency-graph recipe"; fi
if grep -qE '^\| (Architecture map|Dependency graph) \|' "$IDX"; then fail "components/index.md must not list the retired diagrams"; fi
grep -qE '^\| System map \|.*`system-map\.md`' "$IDX" || fail "components/index.md must route System map to system-map.md"
grep -qE '`nonlinear-system`.*\| system map \|' "$CC" || fail "concept-coverage.md must route nonlinear-system to the system map"
grep -qE '`module-dependency`.*\| system map \|' "$CC" || fail "concept-coverage.md must route module-dependency to the system map"
if grep -qE '\| (architecture map|dependency graph) \|' "$CC"; then fail "concept-coverage.md still routes a concept type to a retired diagram"; fi
grep -qF '`nonlinear-system` vs `state-machine`' "$CC" || fail "concept-coverage.md must tell a system with a cycle apart from a state machine"
grep -qE '^\| 18 \|.*system map' "$SC" || fail "self-check #18 must exempt a cycle between components on a system map"
grep -qE '^\| 22 \|.*\.sysmap' "$SC" || fail "self-check #22 must list .sysmap among the structural renderers"
grep -qE '^\| 23 \|.*\.sys-node' "$SC" || fail "self-check #23 must list .sys-node among the keyboard-operable interactives"
if grep -qE '^\| 23 \|.*\.flow-node' "$SC"; then fail "self-check #23 still names the retired .flow-node"; fi
ok "RETIRED: architecture map and dependency graph are gone from the catalog, the routing table and the self-check"

# --- the system-map recipe: its own prefix, a plain view, and the back-compat CSS for old markup ---
if grep -q 'class="sm-' "$SYS"; then fail "system-map.md must not use the sm- prefix: it belongs to the state diagram"; fi
grep -qF 'class="sm-node' "$DIAG" || fail "the state diagram is expected to own the sm- prefix (if that changed, revisit the sys- prefix rule)"
grep -qF 'class="sysmap"' "$SYS" || fail "system-map.md recipe must show the .sysmap container"
grep -qF 'class="sys-links"' "$SYS" || fail "system-map.md recipe must include the connections list: it is the no-JS view"
grep -qF '<details class="sys-conn" open>' "$SYS" || fail "the connections list must be open in the plain view"
grep -q 'role="button"' "$SYS" || fail "system-map.md recipe must carry role=\"button\" on a box that has a detail"
grep -q 'tabindex' "$SYS" || fail "system-map.md recipe must carry tabindex on a box that has a detail"
grep -qF '.archmap{' "$SYS" || fail "system-map.md must keep the .archmap back-compat CSS for old markup"
grep -qF '.depgraph{' "$SYS" || fail "system-map.md must keep the .depgraph back-compat CSS for old markup"
grep -qF '.sysmap' "$RM" || fail "reconstruct-and-merge.md must recover a system map from its HTML"
grep -qF '.archmap' "$RM" || fail "reconstruct-and-merge.md must upgrade an old architecture map"
grep -qF '.depgraph' "$RM" || fail "reconstruct-and-merge.md must upgrade an old dependency graph"
for n in 24 25 26 27; do
  grep -qE "^\| $n \|" "$SC" || fail "self-check.md must carry row $n"
done
grep -qF '## Change marks' "$SM" || fail "session-model.md must define the change-mark rules self-check #26 verifies"
grep -qF '"graphs"' "$SM" || fail "session-model.md must declare graphs[]"
# author text is escaped wherever the recipe has a producer write it: a quote ends an attribute, a "<" becomes markup
grep -qF 'is never markup' "$SYS" || fail "system-map.md must say that every label is escaped text, never markup"
grep -qF '`&`, `<`, `>` and `"`' "$SYS" || fail "system-map.md must name the four characters a producer escapes"
ok "SYSMAP: recipe uses sys-, keeps a plain view and the old-markup CSS; update reads all three shapes; rows 24-27 exist"

# --- engine delivery: one description, one slot, and the path named where a variable is replaced ---
RENDER_SKILL="$ROOT/walkthrough/skills/render/SKILL.md"
README="$ROOT/walkthrough/README.md"
SYSAD="$ROOT/walkthrough/skills/document/references/adapters/system.md"
RULES="$ROOT/walkthrough/references/system-reading.md"
GS="$ROOT/walkthrough/skills/document/references/gather-subject.md"
for f in "$RENDER_SKILL" "$README" "$SYSAD" "$RULES" "$GS"; do
  [ -s "$f" ] || fail "missing $f"
done
grep -qF '{{SYSMAP_ENGINE}}' "$PS" || fail "page-scaffold.md must have the {{SYSMAP_ENGINE}} slot"
grep -qF '/*@@SYSMAP-ENGINE@@*/' "$PS" || fail "page-scaffold.md must show the engine block's marker line"
grep -qi '### insert the system-map engine' "$RC" || fail "render-contract.md must define the engine-insert step"
for line in 'System map engine: inserted by shell command.' 'System map engine: typed by the model' 'System map engine: not included'; do
  grep -qF "$line" "$RC" || fail "render-contract.md must give the message: $line"
done
# shellcheck disable=SC2016  # the literal variable name is what the file must contain
for f in "$CREATE_SKILL" "$UPDATE_SKILL" "$DOCUMENT_SKILL" "$RENDER_SKILL"; do
  grep -qF '${CLAUDE_PLUGIN_ROOT}/skills/create/references/system-map-engine.js' "$f" \
    || fail "$(basename "$(dirname "$f")")/SKILL.md must name the engine path itself: a path variable is only replaced in a SKILL.md body"
done
# a path variable in a reference file reaches the shell as literal text, so none may be relied on there
if grep -lE 'CLAUDE_PLUGIN_ROOT|CLAUDE_SKILL_DIR' "$RC" "$PS" "$SYS" "$SYSAD" "$RULES" 2>/dev/null | grep -q .; then
  fail "a reference file names a path variable; name the path in the SKILL.md body instead"
fi
# the command holds its paths in single quotes; the one character they cannot hold must be ruled out
grep -qF "Never run it when either path contains a single quote" "$RC" \
  || fail "render-contract.md must forbid the shell insert for a path that contains a single quote"
grep -qiE 'slug' "$SYS" || fail "system-map.md must require a slug for data-id: it is written into onclick and attributes"
# a page that shows the marker text in its own content must not make a second marker line. The pin is
# a phrase of the rule's own line: the literal &#47; is also in the retry paragraph, so it outlives the rule
grep -qF 'has to show the marker text, write its first' "$RC" || fail "render-contract.md must say how a page shows the marker text without making a second marker line"
grep -qF 'system-map-engine.js' "$CLAUDEMD" || fail "CONVENTIONS.md must name the engine file"
grep -qi 'FOURTH' "$CLAUDEMD" || fail "CONVENTIONS.md must say a page with a system map carries a fourth script block"
# the paths are literal text: a shell expansion would run outside the single quotes the safety argument rests on
grep -qF 'literal paths and never build either with a shell expansion' "$RC" \
  || fail "render-contract.md must say the two paths are literal and never built with a shell expansion"
ok "ENGINE: one insert step in render-contract.md, a scaffold slot, and the path named in all four SKILL.md bodies"

# --- code reading: two read-only agents, one rules file in the flat references/ home ---
for a in system-analyzer system-verifier; do
  A="$ROOT/walkthrough/agents/$a.md"
  [ -s "$A" ] || fail "missing agent walkthrough/agents/$a.md"
  grep -qE '^tools: Read, Grep, Glob$' "$A" || fail "$a must be read-only: its tools are exactly Read, Grep, Glob"
  grep -q "$a" "$CLAUDEMD" || fail "CONVENTIONS.md must name the $a agent"
  grep -q "walkthrough:$a" "$SYSAD" || fail "adapters/system.md must dispatch walkthrough:$a"
done
[ -z "$(find "$ROOT/walkthrough/agents" -mindepth 1 -type d)" ] || fail "only agent files may live under walkthrough/agents/: every .md there is registered as an agent"
# shellcheck disable=SC2016  # the literal variable name is what the file must contain
grep -qF '${CLAUDE_PLUGIN_ROOT}/references/system-reading.md' "$DOCUMENT_SKILL" || fail "document/SKILL.md must name the reading-rules path it passes to the agents"
grep -qF 'adapters/system.md' "$GS" || fail "gather-subject.md must route to the system adapter"
grep -qF 'adapters/system.md' "$DOCUMENT_SKILL" || fail "document/SKILL.md must follow the system adapter"
grep -qi 'inline' "$SYSAD" || fail "adapters/system.md must say what happens when agents cannot be dispatched"
grep -qF 'not independently verified' "$SYSAD" || fail "an inline reading must be labelled as not independently verified"
grep -qF '.env' "$RULES" || fail "system-reading.md must name the files that are never opened"
grep -qi 'manifests beat prose' "$RULES" || fail "system-reading.md must state that manifests beat prose"
# three rules whose loss would let a secret or an unverified claim reach the page
grep -qF 'Every content search leaves these paths out' "$RULES" || fail "system-reading.md must say a content search leaves the never-opened paths out: a search returns the matching line, value included"
grep -qF 'refute it without opening the file' "$ROOT/walkthrough/agents/system-verifier.md" || fail "system-verifier must refute evidence in a never-opened file without opening it"
grep -qF 'Before you open anything, check every path' "$ROOT/walkthrough/agents/system-verifier.md" || fail "system-verifier must check the cited paths against the never-opened list before it opens anything"
grep -qF 'never re-reads the codebase and never brings back a dropped claim' "$SYSAD" || fail "adapters/system.md must say the coverage critic never re-reads the codebase and never brings back a dropped claim"
# the two sentences that close the rules-unreadable path. Without them a run whose rules could not be
# read can end on the generic route, which reads the subject with no never-opened list
grep -qF 'If you cannot read the rules file, stop the whole skill here' "$SYSAD" || fail "adapters/system.md must stop the whole skill, and build no page, when the skill cannot read the reading rules"
grep -qF 'could not read the rules,** treat its reply as a failed dispatch' "$SYSAD" || fail "adapters/system.md must treat an agent's could-not-read-the-rules reply as a failed dispatch, never as a result"
if grep -niE 'pure-skill|no agents' "$README" "$CLAUDEMD" >/dev/null; then
  fail "README.md and CONVENTIONS.md must not claim the plugin is pure-skill or has no agents: it ships two"
fi
ok "READING: two read-only agents, rules in the flat references/ home, an inline fallback, no stale no-agents claim"

echo "PASS: walkthrough doc contracts"
