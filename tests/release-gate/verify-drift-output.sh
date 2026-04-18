#!/usr/bin/env bash
set -euo pipefail

# verify-drift-output.sh — Verify /onboard:update drift detection results
# Usage: verify-drift-output.sh <REPO_PATH>
# Run AFTER /onboard:update has completed on a mutated repo.

REPO="${1:-}"

if [[ -z "$REPO" || ! -d "$REPO" ]]; then
  echo "Usage: verify-drift-output.sh <REPO_PATH>"
  exit 1
fi

cd "$REPO" || exit 1

PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

pass() { PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $1"; }
warn() { WARNINGS=$((WARNINGS + 1)); TOTAL=$((TOTAL + 1)); echo "  WARN: $1"; }

echo "## Verify Drift Detection Results"
echo ""
echo "Repo: ${REPO}"
echo ""

# ─────────────────────────────────────────────────
echo "### 1. Deleted rule was regenerated (PR #33)"
# ─────────────────────────────────────────────────
RULE_COUNT=$(find .claude/rules -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$RULE_COUNT" -gt 0 ]]; then
  pass "rules directory has ${RULE_COUNT} files (deletion was repaired)"
else
  fail "rules directory is empty — deleted rule was NOT regenerated"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 2. Agent user-edit preserved (PR #36)"
# ─────────────────────────────────────────────────
AGENT_FILE=$(find .claude/agents -name '*.md' -type f 2>/dev/null | head -1)
if [[ -n "$AGENT_FILE" ]]; then
  if grep -q 'claude-haiku-4-5-20251001' "$AGENT_FILE"; then
    pass "agent edit preserved: model still set to haiku"
  else
    fail "agent edit reverted: haiku model was overwritten by update"
  fi
else
  warn "no agent files to check"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 3. Output style body edit not flagged (PR #37)"
# ─────────────────────────────────────────────────
STYLE_FILE=$(find .claude/output-styles -name '*.md' -type f 2>/dev/null | head -1 || true)
if [[ -n "$STYLE_FILE" ]]; then
  if grep -q "Custom Addition" "$STYLE_FILE"; then
    pass "output style body edit preserved (not reverted by update)"
  else
    fail "output style body edit was reverted — update should not touch body content"
  fi
else
  warn "no output style files to check"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 4. @anthropic-ai/sdk dependency present (PR #39)"
# ─────────────────────────────────────────────────
if [[ -f "package.json" ]]; then
  if jq -e '.dependencies["@anthropic-ai/sdk"]' package.json >/dev/null 2>&1; then
    pass "@anthropic-ai/sdk still in package.json"
  else
    fail "@anthropic-ai/sdk removed from package.json"
  fi

  # Check if builtInSkillsStatus was updated to reflect the new skill.
  # Walk nested structures: /claude-api lives in planned[], generated[], and
  # detectionSignals (keys + values) — never at top level. The original
  # to_entries walk checked only top-level keys and always false-negative WARNed.
  if [[ -f ".claude/onboard-meta.json" ]]; then
    BSS=$(jq '.builtInSkillsStatus // {}' .claude/onboard-meta.json 2>/dev/null)
    if echo "$BSS" | jq -e '[.planned[]?, .generated[]?, (.detectionSignals // {} | keys[]?), (.detectionSignals // {} | values[]?)] | any(. | tostring | test("claude-api"; "i"))' >/dev/null 2>&1; then
      pass "builtInSkillsStatus references claude-api"
    else
      warn "builtInSkillsStatus does not reference claude-api (may need manual approval during update)"
    fi
  fi
else
  warn "no package.json to check"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 5. Rust file exists (PR #38)"
# ─────────────────────────────────────────────────
if [[ -f "src/main.rs" ]]; then
  pass "src/main.rs exists"

  # Check if LSP snapshot was updated
  if [[ -f ".claude/onboard-lsp-snapshot.json" ]]; then
    LSP_SNAP=$(cat .claude/onboard-lsp-snapshot.json 2>/dev/null)
    if echo "$LSP_SNAP" | jq -e '.recommended | map(select(test("rust";"i"))) | length > 0' >/dev/null 2>&1; then
      pass "LSP snapshot includes rust-analyzer candidate"
    else
      warn "LSP snapshot does not include rust candidate (may need manual approval during update)"
    fi
  fi
else
  fail "src/main.rs missing — mutation was not applied or was deleted"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 6. Meta/snapshot integrity after update"
# ─────────────────────────────────────────────────

# onboard-meta.json still valid
if [[ -f ".claude/onboard-meta.json" ]]; then
  if jq empty .claude/onboard-meta.json 2>/dev/null; then
    pass "onboard-meta.json still valid JSON after update"
  else
    fail "onboard-meta.json corrupted after update"
  fi
fi

# settings.json still valid
if [[ -f ".claude/settings.json" ]]; then
  if jq empty .claude/settings.json 2>/dev/null; then
    pass "settings.json still valid JSON after update"
  else
    fail "settings.json corrupted after update"
  fi
fi

# CLAUDE.md still exists
if [[ -f "CLAUDE.md" ]]; then
  pass "CLAUDE.md still exists after update"
else
  fail "CLAUDE.md disappeared after update"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 7. Pending-updates snapshot — M2 release-gate sweep"
# ─────────────────────────────────────────────────
# When the developer chooses "Apply later" in the AskUserQuestion approval
# pre-question, /onboard:update writes .claude/onboard-pending-updates.json so
# the next run can re-present pending offers. After "Apply all" or per-group
# selection lands, the snapshot is deleted. State after this verify run depends
# on the choice the developer made — accept either: file exists with
# pendingOffers[] OR file absent (offers were applied).
if [[ -f ".claude/onboard-pending-updates.json" ]]; then
  if jq empty .claude/onboard-pending-updates.json 2>/dev/null; then
    HAS_OFFERS=$(jq 'has("pendingOffers")' .claude/onboard-pending-updates.json 2>/dev/null || echo "false")
    if [[ "$HAS_OFFERS" == "true" ]]; then
      pass "pending-updates snapshot present and well-formed (developer chose 'Apply later')"
    else
      fail "pending-updates snapshot missing 'pendingOffers' array"
    fi
  else
    fail "pending-updates snapshot exists but is invalid JSON"
  fi
else
  pass "pending-updates snapshot absent (developer chose 'Apply all' / per-group / 'Skip' — snapshot was deleted post-apply or never written)"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 8. URL convention in update skill (L2 release-gate sweep)"
# ─────────────────────────────────────────────────
# This verify runs against a project that ran /onboard:update — the update skill
# itself is in the onboard plugin, but if the update wrote any new artifacts
# referencing Claude Code docs, those should use code.claude.com URLs. This
# check scans the project's CLAUDE.md and any rules/skills it generated.
LEGACY_IN_PROJECT=$(grep -rn "docs.anthropic.com/en/docs/claude-code" \
  --include="*.md" \
  CLAUDE.md .claude/rules .claude/skills .claude/agents 2>/dev/null | head -5 || true)
if [[ -z "$LEGACY_IN_PROJECT" ]]; then
  pass "URL convention: no legacy docs.anthropic.com refs in project artifacts"
else
  fail "URL convention: legacy URLs leaked into project artifacts:"
  # shellcheck disable=SC2001  # per-line indent is clearer with sed
  echo "$LEGACY_IN_PROJECT" | sed 's/^/      /'
fi
echo ""

# ─────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "## Summary — Drift Verification"
echo ""
echo "  Passed:   ${PASSED}"
echo "  Warnings: ${WARNINGS}"
echo "  Failed:   ${FAILED}"
echo "  Total:    ${TOTAL}"
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  echo "RESULT: FAILED — ${FAILED} error(s)"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo "RESULT: PASSED with ${WARNINGS} warning(s) — review manually"
  exit 0
else
  echo "RESULT: ALL CHECKS PASSED"
  exit 0
fi
