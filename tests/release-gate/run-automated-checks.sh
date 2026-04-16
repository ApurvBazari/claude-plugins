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
  forge/.claude-plugin/plugin.json \
  notify/.claude-plugin/plugin.json; do
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
for plugin_dir in onboard forge notify; do
  MANIFEST="${plugin_dir}/.claude-plugin/plugin.json"
  if [[ -f "$MANIFEST" ]]; then
    PLUGIN_VER=$(jq -r '.version' "$MANIFEST")
    MARKET_VER=$(jq -r ".plugins[] | select(.name == \"${plugin_dir}\") | .version" .claude-plugin/marketplace.json)
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
echo "### 11. Engineering plugin removed from forge (M6 release-gate sweep)"
# ─────────────────────────────────────────────────
# forge/skills/lifecycle-setup/ deleted entirely; plugin-catalog.md must not
# reference engineering; onboard's plugin-detection-guide.md must not list
# engineering capabilities.
if [[ -d "forge/skills/lifecycle-setup" ]]; then
  fail "lifecycle-setup directory still exists at forge/skills/lifecycle-setup"
else
  pass "lifecycle-setup directory removed"
fi

if grep -qE '\| \*\*engineering\*\*|engineering-lifecycle' \
   forge/skills/plugin-discovery/references/plugin-catalog.md 2>/dev/null; then
  fail "engineering plugin still referenced in forge plugin-catalog.md"
else
  pass "engineering plugin removed from forge plugin-catalog.md"
fi

if grep -qE "\| \`engineering\`|engineering-lifecycle" \
   onboard/skills/generation/references/plugin-detection-guide.md 2>/dev/null; then
  fail "engineering capabilities still listed in onboard plugin-detection-guide.md"
else
  pass "engineering capabilities removed from onboard plugin-detection-guide.md"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 12. Wizard exchange cap removed (C4 release-gate sweep)"
# ─────────────────────────────────────────────────
# wizard/SKILL.md should no longer advertise a hard 6-exchange cap.
# Adaptive sizing language and the Custom-preset escape hatch should be present.
if grep -qE '6.exchange (hard )?(limit|cap)|Hard 6.exchange' \
   onboard/skills/wizard/SKILL.md 2>/dev/null; then
  fail "wizard/SKILL.md still mentions a hard 6-exchange cap"
else
  pass "wizard cap removed (no hard 6-exchange limit language)"
fi

if grep -q "Adaptive exchange sizing" onboard/skills/wizard/SKILL.md 2>/dev/null; then
  pass "wizard documents adaptive exchange sizing"
else
  fail "wizard missing 'Adaptive exchange sizing' section"
fi

if grep -q "Mid-wizard escape hatch" onboard/skills/wizard/SKILL.md 2>/dev/null; then
  pass "wizard has Custom-preset escape hatch (Phase 5.0)"
else
  fail "wizard missing escape hatch section"
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
