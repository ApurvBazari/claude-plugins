#!/usr/bin/env bash
set -euo pipefail

# run-automated-checks.sh — Automated pre-flight checks for develop → main release
# Usage: run-automated-checks.sh
# Run from the claude-plugins repo root.

ERRORS=0
WARNINGS=0
PASSED=0
TOTAL=0

pass() { PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $1"; }
fail() { ERRORS=$((ERRORS + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $1"; }
warn() { WARNINGS=$((WARNINGS + 1)); TOTAL=$((TOTAL + 1)); echo "  WARN: $1"; }

# Verify we're in the right directory
if [[ ! -f ".claude-plugin/marketplace.json" ]]; then
  echo "ERROR: Must run from the claude-plugins repo root"
  exit 1
fi

echo "## Release Gate — Automated Checks"
echo ""
echo "Running from: $(pwd)"
echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
echo ""

# ─────────────────────────────────────────────────
echo "### 1. ShellCheck — All shell scripts"
# ─────────────────────────────────────────────────
if ! command -v shellcheck &>/dev/null; then
  warn "shellcheck not installed — skipping"
else
  SHELL_ERRORS=0
  while IFS= read -r -d '' script; do
    if shellcheck "$script" >/dev/null 2>&1; then
      pass "shellcheck: $(basename "$script")"
    else
      fail "shellcheck: $script"
      shellcheck "$script" 2>&1 | head -5
      SHELL_ERRORS=$((SHELL_ERRORS + 1))
    fi
  done < <(find . -name '*.sh' -not -path './.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null)
  if [[ "$SHELL_ERRORS" -eq 0 ]]; then
    echo "  All scripts clean"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 2. JSON validation"
# ─────────────────────────────────────────────────
for json_file in \
  .claude-plugin/marketplace.json \
  .claude/audit-baseline.json \
  onboard/.claude-plugin/plugin.json \
  notify/.claude-plugin/plugin.json \
  handoff/.claude-plugin/plugin.json; do
  if [[ ! -f "$json_file" ]]; then
    fail "missing: $json_file"
  elif jq empty "$json_file" 2>/dev/null; then
    pass "json: $json_file"
  else
    fail "invalid json: $json_file"
  fi
done
echo ""

# ─────────────────────────────────────────────────
echo "### 3. Existing CI validation scripts"
# ─────────────────────────────────────────────────
for script in \
  .github/scripts/validate-manifests.sh \
  .github/scripts/check-structure.sh \
  .github/scripts/check-references.sh; do
  if [[ ! -f "$script" ]]; then
    fail "missing: $script"
  elif bash "$script" >/dev/null 2>&1; then
    pass "$(basename "$script")"
  else
    fail "$(basename "$script")"
    bash "$script" 2>&1 | grep -E 'FAIL|ERROR' | head -5
  fi
done
echo ""

# ─────────────────────────────────────────────────
echo "### 4. Skill frontmatter lint"
# ─────────────────────────────────────────────────
while IFS= read -r -d '' skill_file; do
  skill_name=$(basename "$(dirname "$skill_file")")
  # Check for frontmatter delimiters
  if head -1 "$skill_file" | grep -q '^---$'; then
    # Check for name or description field
    frontmatter=$(sed -n '1,/^---$/{ /^---$/d; p; }' "$skill_file" | head -20)
    if echo "$frontmatter" | grep -qE '^(name|description):'; then
      pass "skill frontmatter: $skill_name"
    else
      warn "skill frontmatter missing name/description: $skill_file"
    fi
  else
    fail "skill missing frontmatter: $skill_file"
  fi
done < <(find . -path '*/skills/*/SKILL.md' -not -path './.git/*' -print0 2>/dev/null)
echo ""

# ─────────────────────────────────────────────────
echo "### 5. Agent format check (plugin agents — name/description/color frontmatter required after C3+L6)"
# ─────────────────────────────────────────────────
while IFS= read -r -d '' agent_file; do
  agent_name=$(basename "$agent_file" .md)
  AGENT_ISSUES=0

  # YAML frontmatter is REQUIRED on plugin agents per C3+L6 (release-gate sweep)
  if ! head -1 "$agent_file" | grep -q '^---$'; then
    fail "agent missing YAML frontmatter: $agent_file"
    AGENT_ISSUES=$((AGENT_ISSUES + 1))
  else
    # Parse frontmatter block and check name + description
    fm=$(sed -n '2,/^---$/{ /^---$/d; p; }' "$agent_file" | head -20)
    if ! echo "$fm" | grep -qE '^name:'; then
      fail "agent frontmatter missing name: $agent_file"
      AGENT_ISSUES=$((AGENT_ISSUES + 1))
    fi
    if ! echo "$fm" | grep -qE '^description:'; then
      fail "agent frontmatter missing description: $agent_file"
      AGENT_ISSUES=$((AGENT_ISSUES + 1))
    fi
  fi

  if ! grep -q '^## Tools' "$agent_file"; then
    warn "agent missing ## Tools: $agent_file"
    AGENT_ISSUES=$((AGENT_ISSUES + 1))
  fi
  if ! grep -q '^## Instructions' "$agent_file"; then
    warn "agent missing ## Instructions: $agent_file"
    AGENT_ISSUES=$((AGENT_ISSUES + 1))
  fi

  if [[ "$AGENT_ISSUES" -eq 0 ]]; then
    pass "agent format: $agent_name"
  fi
done < <(find . -path '*/agents/*.md' -not -path './.git/*' -not -path './.claude/agents/*' -print0 2>/dev/null)
echo ""

# ─────────────────────────────────────────────────
echo "### 6. Prompt contract validation"
# ─────────────────────────────────────────────────
for prompt_file in .claude/prompts/tooling-gap-audit-analyze.md .claude/prompts/tooling-gap-audit-report.md; do
  if [[ ! -f "$prompt_file" ]]; then
    fail "missing prompt contract: $prompt_file"
  elif head -5 "$prompt_file" | grep -q '^# '; then
    pass "prompt contract: $(basename "$prompt_file")"
  else
    fail "prompt contract missing H1: $prompt_file"
  fi
done
echo ""

# ─────────────────────────────────────────────────
echo "### 7. New artifact existence (PRs #34-#40)"
# ─────────────────────────────────────────────────

ARTIFACT_FILES=(
  # PR #34 — Hook expansion
  onboard/skills/generation/references/hooks-guide.md
  # PR #35 — MCP generation
  onboard/scripts/install-plugins.sh
  onboard/skills/generation/references/mcp-guide.md
  # PR #36 — Agent frontmatter
  onboard/skills/generation/references/agents-guide.md
  # PR #37 — Output styles
  onboard/skills/generation/references/output-styles-catalog.md
  onboard/skills/generation/references/output-styles-guide.md
  # PR #38 — LSP
  onboard/scripts/detect-lsp-signals.sh
  onboard/skills/generation/references/lsp-plugin-catalog.md
  # PR #39 — Built-in skills
  onboard/skills/generation/references/built-in-skills-catalog.md
  # PR #40 — Audit infrastructure
  .claude/audit-baseline.json
  .claude/prompts/tooling-gap-audit-analyze.md
  .claude/prompts/tooling-gap-audit-report.md
  .github/workflows/tooling-gap-audit.yml
  .github/scripts/open-gap-audit-pr.sh
  docs/tooling-gap-reports/README.md
  docs/tooling-gap-reports/.gitkeep
)
for f in "${ARTIFACT_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    pass "exists: $f"
  else
    fail "missing: $f"
  fi
done
echo ""

# ─────────────────────────────────────────────────
echo "### 8. Version sync check"
# ─────────────────────────────────────────────────
for plugin_dir in onboard notify handoff; do
  MANIFEST="${plugin_dir}/.claude-plugin/plugin.json"
  if [[ -f "$MANIFEST" ]]; then
    PLUGIN_VER=$(jq -r '.version' "$MANIFEST")
    MARKET_VER=$(jq -r --arg name "$plugin_dir" '.plugins[] | select(.name == $name) | .version' .claude-plugin/marketplace.json)
    if [[ "$PLUGIN_VER" == "$MARKET_VER" ]]; then
      pass "version sync: ${plugin_dir} (${PLUGIN_VER})"
    else
      fail "version mismatch: ${plugin_dir} — plugin.json=${PLUGIN_VER}, marketplace=${MARKET_VER}"
    fi
  fi
done
echo ""

# ─────────────────────────────────────────────────
echo "### 9. Script executability"
# ─────────────────────────────────────────────────
while IFS= read -r -d '' script; do
  if [[ -x "$script" ]]; then
    pass "executable: ${script#./}"
  else
    fail "not executable: $script"
  fi
done < <(find . -name '*.sh' -not -path './.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null)
echo ""

# ─────────────────────────────────────────────────
echo "### 10. Documentation URL convention (L2 release-gate sweep)"
# ─────────────────────────────────────────────────
# Every reference to Claude Code docs must use https://code.claude.com/docs/en/*
# Legacy https://docs.anthropic.com/en/docs/claude-code/* URLs 301-redirect.
# Allowed locations for the legacy URL: docs/url-conventions.md (the convention
# file itself documents both forms in its mapping table), root CLAUDE.md (the
# convention pointer), tests/release-gate/findings-* (historical reports),
# .claude/settings.local.json (user permission allowlist).
LEGACY_URL_HITS=$(grep -rl "docs.anthropic.com/en/docs/claude-code" \
  --include="*.md" \
  --exclude-dir=".git" \
  --exclude-dir="tests" \
  --exclude-dir="future-plans" \
  --exclude-dir="docs/tooling-gap-reports" \
  . 2>/dev/null \
  | grep -vE "^\\./docs/url-conventions\\.md$|^\\./CLAUDE\\.md$" || true)
if [[ -z "$LEGACY_URL_HITS" ]]; then
  pass "URL convention: zero legacy docs.anthropic.com refs in plugin/skill files"
else
  fail "URL convention: legacy URLs still present in:"
  # shellcheck disable=SC2001  # per-line indent is clearer with sed than parameter expansion
  echo "$LEGACY_URL_HITS" | sed 's/^/      /'
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 12. Wizard collapsed to grounded confirm/override (v3 flow)"
# ─────────────────────────────────────────────────
# v3 collapsed the wizard: no hard exchange cap, no preset-selection step, no
# Custom path, no mid-wizard escape hatch. The grounded surface confirms/overrides
# research.wizardInferences across a fixed three-exchange shape.
if grep -qE '6.exchange (hard )?(limit|cap)|Hard 6.exchange' \
   onboard/skills/wizard/SKILL.md 2>/dev/null; then
  fail "wizard/SKILL.md still mentions a hard 6-exchange cap"
else
  pass "wizard cap removed (no hard 6-exchange limit language)"
fi

if grep -q "Three-exchange shape" onboard/skills/wizard/SKILL.md 2>/dev/null; then
  pass "wizard documents the v3 three-exchange grounded shape"
else
  fail "wizard missing 'Three-exchange shape' section (v3 grounded flow)"
fi

# The v2 mid-wizard escape hatch and Custom path must be GONE (escapeHatchTriggered
# is now always false; presetUsed enum dropped custom). v2 documented the escape
# hatch as a markdown SECTION HEADING (e.g. "#### Phase 5.0 — Mid-wizard escape
# hatch"); v3 only references it inline as a negation in a Key Rule ("...no
# mid-wizard escape hatch"). Anchor the check to a heading so the inline v3
# disclaimer does NOT trip a false reintroduction.
if grep -qiE '^#+.*escape hatch' onboard/skills/wizard/SKILL.md 2>/dev/null; then
  fail "wizard/SKILL.md still documents a mid-wizard/Custom-preset escape hatch section (removed in v3)"
else
  pass "wizard escape hatch removed (v3 — no escape-hatch section heading)"
fi
echo ""

# ─────────────────────────────────────────────────
echo "## Plan 4b — research consumption contract (static)"
# ─────────────────────────────────────────────────
GEN_SKILL="onboard/skills/generate/SKILL.md"

if grep -q "onboard 3.x requires a \`research\` object for full (re)generation" "$GEN_SKILL"; then
  pass "4b: generate Step 0.1 carries the D2 missing-research reject error"
else
  fail "4b: generate Step 0.1 missing the D2 reject error string"
fi

if grep -q "failed \`research-dossier.json\` validation at" "$GEN_SKILL"; then
  pass "4b: generate Step 0.1 carries the malformed-research reject error"
else
  fail "4b: generate Step 0.1 missing the malformed-research reject error string"
fi

if grep -qi "regenerateOnly" "$GEN_SKILL"; then
  pass "4b: generate references the regenerateOnly research exemption"
else
  fail "4b: generate missing the regenerateOnly exemption"
fi

if grep -q "codebase-derived" "$GEN_SKILL" && grep -qi "not.*untrusted-user-input" "$GEN_SKILL"; then
  pass "4b: generate Step 3 threads research with the codebase-derived framing note"
else
  fail "4b: generate Step 3 missing the research dispatch framing note"
fi

CG="onboard/agents/config-generator.md"
if grep -q "research-consumption.md" "$CG" && grep -q "verify-backlog-seeding.md" "$CG"; then
  pass "4b: config-generator references both new consumption specs"
else
  fail "4b: config-generator missing references to research-consumption.md / verify-backlog-seeding.md"
fi
if grep -q "metadata.research" "$CG"; then
  pass "4b: config-generator writes the metadata.research block"
else
  fail "4b: config-generator missing the metadata.research write"
fi

RC="onboard/skills/generation/references/research-consumption.md"
GENERATION="onboard/skills/generation/SKILL.md"
if [[ -f "$RC" ]] && grep -q "Research-Grounded Generation (v3)" "$GENERATION" && grep -q "research-consumption.md" "$GENERATION"; then
  pass "4b: research-consumption.md exists + linked from generation/SKILL.md with the gated section"
else
  fail "4b: research-consumption.md missing or not linked/gated in generation/SKILL.md"
fi

VB="onboard/skills/generation/references/verify-backlog-seeding.md"
if [[ -f "$VB" ]] && grep -q "seed-if-absent" "$VB" && grep -q "verifiedClaims" "$VB"; then
  pass "4b: verify-backlog-seeding.md exists with seed-if-absent + verified-only source"
else
  fail "4b: verify-backlog-seeding.md missing or incomplete"
fi

ROSTER="onboard/skills/research/references/specialist-roster.md"
SYN="onboard/skills/research/references/synthesis-and-dossier.md"
TAG_COUNT=$(grep -c 'category:"test-gap"\|category:"risk"' "$ROSTER" || true)
if [[ "$TAG_COUNT" -ge 3 ]]; then
  pass "4b: specialist-roster tags categories in testing/security/dependencies (${TAG_COUNT} tags)"
else
  fail "4b: specialist-roster missing category-tagging instructions (found ${TAG_COUNT}, need ≥3)"
fi
if grep -q "verify-backlog-seeding.md" "$SYN" && grep -q 'category:"test-gap"' "$SYN"; then
  pass "4b: synthesis-and-dossier wired to verify-backlog + risk-register includes test-gap"
else
  fail "4b: synthesis-and-dossier not wired (line 131/137)"
fi

SC="onboard/skills/generation/references/sprint-contracts.md"
if grep -q "Round 5" "$SC" || grep -q "featureRoadmap.sprint1" "$SC"; then
  fail "4b: sprint-contracts.md still references the deleted Round-5/featureRoadmap mechanism"
else
  pass "4b: sprint-contracts.md no longer references the deleted Round-5 section"
fi

CSV3="onboard/skills/generate/references/context-shape-v3.json"
OBCLAUDE="onboard/CLAUDE.md"
if grep -qi "required for a full generation" "$CSV3" && grep -qi "regenerateOnly" "$CSV3"; then
  pass "4b: context-shape-v3.json description states runtime-required-unless-regenerateOnly"
else
  fail "4b: context-shape-v3.json description note missing/insufficient"
fi
if grep -qi "consumes.*research\|research.*sharpen\|verify backlog" "$OBCLAUDE"; then
  pass "4b: onboard/CLAUDE.md notes generation consumes research (v3)"
else
  fail "4b: onboard/CLAUDE.md missing the consumes-research note"
fi
echo ""

# ─────────────────────────────────────────────────
echo "## Plan 4c — re-research on update/evolve (static)"
# ─────────────────────────────────────────────────
GEN_SKILL="onboard/skills/generate/SKILL.md"
CSV3="onboard/skills/generate/references/context-shape-v3.json"

if grep -q "reResearch" "$CSV3"; then
  pass "4c: context-shape-v3.json documents the callerExtras.reResearch marker"
else
  fail "4c: context-shape-v3.json missing the reResearch marker doc"
fi

if grep -q "reResearch" "$GEN_SKILL"; then
  pass "4c: generate threads the reResearch marker into the dispatch"
else
  fail "4c: generate missing the reResearch marker threading"
fi

# Guard: 4b Step 0.1 D2 contract MUST remain intact (4c does not touch it).
if grep -q "onboard 3.x requires a \`research\` object for full (re)generation" "$GEN_SKILL"; then
  pass "4c: generate Step 0.1 D2 contract intact (unchanged by 4c)"
else
  fail "4c: generate Step 0.1 D2 contract was disturbed"
fi

DM="onboard/skills/research/references/dossier-merge.md"
RESEARCH="onboard/skills/research/SKILL.md"
if [[ -f "$DM" ]] && grep -q "dossier-merge.md" "$RESEARCH"; then
  pass "4c: dossier-merge.md exists + linked from research/SKILL.md"
else
  fail "4c: dossier-merge.md missing or not linked"
fi
if grep -qi "scoped/merge mode" "$RESEARCH" && grep -qi "refreshDimensions" "$RESEARCH"; then
  pass "4c: research/SKILL.md has the scoped/merge re-research mode"
else
  fail "4c: research/SKILL.md missing the scoped/merge mode"
fi

RR="onboard/skills/update/references/re-research.md"
if [[ -f "$RR" ]] && grep -q "## § Detection" "$RR" && grep -q "## § Orchestration" "$RR"; then
  pass "4c: re-research.md exists with split Detection (read-only) + Orchestration sections"
else
  fail "4c: re-research.md missing or not split into Detection/Orchestration"
fi
if grep -qi "escalat" "$RR" && grep -q "Depth-cap intersection" "$RR" && grep -q "not a snapshot replay" "$RR"; then
  pass "4c: re-research.md carries the escalation rule + depth-cap intersection + no-regenerateOnly construction"
else
  fail "4c: re-research.md missing escalation / depth-cap / no-regenerateOnly contract"
fi

CHECK="onboard/skills/check/SKILL.md"
if grep -q "re-research.md" "$CHECK" && grep -qi "research staleness" "$CHECK"; then
  pass "4c: check consumes the Detection map + reports research staleness"
else
  fail "4c: check missing the research-staleness report"
fi
# Guard: check stays read-only.
if grep -q "Never write to any file" "$CHECK"; then
  pass "4c: check remains read-only"
else
  fail "4c: check read-only guarantee disturbed"
fi

UPDATE="onboard/skills/update/SKILL.md"
if grep -q "re-research.md" "$UPDATE" && grep -qi "re-ground" "$UPDATE"; then
  pass "4c: update detects research staleness + offers a re-ground"
else
  fail "4c: update missing the re-research detector/offer"
fi

EVOLVE="onboard/skills/evolve/SKILL.md"
if grep -q "re-research.md" "$EVOLVE" && grep -qi "scoped" "$EVOLVE" && grep -qi "defer" "$EVOLVE"; then
  pass "4c: evolve runs scoped re-research silently + defers full-escalation to update"
else
  fail "4c: evolve missing the scoped-silent / full-defer re-research path"
fi

RRM="onboard/skills/generation/references/re-research-merge.md"
GENERATION="onboard/skills/generation/SKILL.md"
if [[ -f "$RRM" ]] && grep -q "Re-Research Merge-Aware Generation (v3)" "$GENERATION" && grep -q "re-research-merge.md" "$GENERATION"; then
  pass "4c: re-research-merge.md exists + linked from generation/SKILL.md with the gated section"
else
  fail "4c: re-research-merge.md missing or not linked/gated in generation/SKILL.md"
fi
if [[ -f "$RRM" ]] && grep -qi "customization floor" "$RRM" && grep -qi "marker-delimited surgery" "$RRM"; then
  pass "4c: re-research-merge.md carries the customization floor + marker surgery"
else
  fail "4c: re-research-merge.md missing the customization floor / marker surgery"
fi
CG="onboard/agents/config-generator.md"
if grep -q "reResearch" "$CG" && grep -q "re-research-merge.md" "$CG"; then
  pass "4c: config-generator honors the reResearch marker + loads the merge reference"
else
  fail "4c: config-generator missing the reResearch marker handling"
fi
if grep -q "refreshedDimensions" "$CG" && grep -q "backlogMerged" "$CG"; then
  pass "4c: config-generator writes the 4c re-research telemetry fields"
else
  fail "4c: config-generator missing the 4c telemetry fields"
fi
VB="onboard/skills/generation/references/verify-backlog-seeding.md"
OBCLAUDE="onboard/CLAUDE.md"
if grep -q "sourceClaim" "$VB" && grep -qi "Re-research merge" "$VB"; then
  pass "4c: verify-backlog-seeding has the merge path + sourceClaim provenance"
else
  fail "4c: verify-backlog-seeding missing the merge path / sourceClaim"
fi
if grep -qi "re-research" "$OBCLAUDE"; then
  pass "4c: onboard/CLAUDE.md notes the re-research capability"
else
  fail "4c: onboard/CLAUDE.md missing the re-research note"
fi
echo ""

# ─────────────────────────────────────────────────
echo "## Plan 5 — ship + 3.0.0 cutover (static)"
# ─────────────────────────────────────────────────
RA="onboard/skills/research/references/render-adapter.md"
RESEARCH="onboard/skills/research/SKILL.md"
SD="onboard/skills/research/references/synthesis-and-dossier.md"
if [[ -f "$RA" ]] && grep -q "render-adapter.md" "$RESEARCH"; then
  pass "5: render-adapter.md exists + linked from research/SKILL.md"
else
  fail "5: render-adapter.md missing or not linked"
fi
if grep -q "walkthrough:render" "$RESEARCH" && grep -q "render-adapter.md" "$SD"; then
  pass "5: synthesizer wires the walkthrough:render handoff"
else
  fail "5: synthesizer missing the walkthrough:render handoff"
fi
if grep -qi "set by the render" "$RESEARCH" && ! grep -qi "HTML render.*deferred\|render.*are deferred" "$RESEARCH"; then
  pass "5: artifacts.html no longer hardcoded null (render no longer deferred)"
else
  fail "5: research/SKILL.md still pins artifacts.html:null / 'render deferred'"
fi
CG="onboard/agents/config-generator.md"
if grep -q "engineUsed" "$CG" && grep -q "specialistsRun" "$CG" && grep -q "claimsDropped" "$CG" && grep -q "artifactsWritten" "$CG" && grep -q "htmlRendered" "$CG"; then
  pass "5: config-generator writes the full metadata.research block"
else
  fail "5: config-generator missing full-telemetry fields"
fi
if ! grep -qi "full telemetry block.*Plan 5\|do not add them here" "$CG"; then
  pass "5: config-generator deferral guard removed"
else
  fail "5: config-generator still defers the full block to Plan 5"
fi
if ! grep -rq "verifiedClaimCount" onboard; then
  pass "5: legacy verifiedClaimCount renamed to claimsVerified everywhere"
else
  fail "5: verifiedClaimCount still present (rename incomplete)"
fi
START="onboard/skills/start/SKILL.md"
if grep -qi "research self-audit" "$START" && grep -q "htmlRendered" "$START"; then
  pass "5: start Phase-7 self-audit covers the research telemetry"
else
  fail "5: start Phase-7 missing the research self-audit"
fi
if grep -qi "research self-audit" "$CG"; then
  pass "5: config-generator enforces the research self-audit (subagent-visible)"
else
  fail "5: config-generator missing the research self-audit (start summary alone is not subagent-visible)"
fi
echo ""

# ─────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "## Summary"
echo ""
echo "  Passed:   ${PASSED}"
echo "  Warnings: ${WARNINGS}"
echo "  Failed:   ${ERRORS}"
echo "  Total:    ${TOTAL}"
echo ""

if [[ "$ERRORS" -gt 0 ]]; then
  echo "RESULT: FAILED — ${ERRORS} error(s) must be fixed before release"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo "RESULT: PASSED with ${WARNINGS} warning(s)"
  exit 0
else
  echo "RESULT: ALL CHECKS PASSED"
  exit 0
fi
