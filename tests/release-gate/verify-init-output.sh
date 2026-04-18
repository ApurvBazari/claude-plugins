#!/usr/bin/env bash
set -euo pipefail

# verify-init-output.sh — Verify /onboard:init generated artifacts
# Usage: verify-init-output.sh <REPO_PATH> <PROFILE>
# Profiles: nextjs | python | monorepo | empty | forge

REPO="${1:-}"
PROFILE="${2:-nextjs}"

if [[ -z "$REPO" || ! -d "$REPO" ]]; then
  echo "Usage: verify-init-output.sh <REPO_PATH> <PROFILE>"
  echo "Profiles: nextjs | python | monorepo | empty | forge"
  exit 1
fi

cd "$REPO"

PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

pass() { PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $1"; }
warn() { WARNINGS=$((WARNINGS + 1)); TOTAL=$((TOTAL + 1)); echo "  WARN: $1"; }

echo "## Verify /onboard:init Output"
echo ""
echo "Repo: ${REPO}"
echo "Profile: ${PROFILE}"
echo ""

# ─────────────────────────────────────────────────
echo "### 1. Core artifacts exist"
# ─────────────────────────────────────────────────

# CLAUDE.md (always generated)
if [[ -f "CLAUDE.md" ]]; then
  pass "CLAUDE.md exists"
else
  fail "CLAUDE.md missing"
fi

# .claude directory
if [[ -d ".claude" ]]; then
  pass ".claude/ directory exists"
else
  fail ".claude/ directory missing"
fi

# settings.json (always generated with hooks)
if [[ -f ".claude/settings.json" ]]; then
  if jq empty .claude/settings.json 2>/dev/null; then
    pass "settings.json exists and is valid JSON"
  else
    fail "settings.json exists but is invalid JSON"
  fi
else
  if [[ "$PROFILE" == "empty" ]]; then
    warn "settings.json missing (may be expected for empty repo)"
  else
    fail "settings.json missing"
  fi
fi

# onboard-meta.json
if [[ -f ".claude/onboard-meta.json" ]]; then
  if jq empty .claude/onboard-meta.json 2>/dev/null; then
    pass "onboard-meta.json exists and is valid JSON"
  else
    fail "onboard-meta.json exists but is invalid JSON"
  fi
else
  fail "onboard-meta.json missing"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 2. Hook schema validation (PR #32)"
# ─────────────────────────────────────────────────

if [[ -f ".claude/settings.json" ]]; then
  # Check for nested hooks structure (not flat)
  # Valid: { "Stop": [{ "hooks": [{ "type": "command", ... }] }] }
  # Invalid: { "Stop": [{ "type": "command", ... }] }
  HOOKS_JSON=$(jq '.hooks // {}' .claude/settings.json 2>/dev/null)
  if [[ "$HOOKS_JSON" != "{}" && "$HOOKS_JSON" != "null" ]]; then
    # Check that at least one event has the nested hooks array
    HAS_NESTED=$(echo "$HOOKS_JSON" | jq '[.[] | .[] | has("hooks")] | any' 2>/dev/null || echo "false")
    HAS_FLAT_TYPE=$(echo "$HOOKS_JSON" | jq '[.[] | .[] | has("type")] | any' 2>/dev/null || echo "false")

    if [[ "$HAS_NESTED" == "true" ]]; then
      pass "hooks use nested hooks:[...] schema"
    elif [[ "$HAS_FLAT_TYPE" == "true" ]]; then
      fail "hooks use FLAT schema (type at top level) — should be nested"
    else
      warn "hooks structure unclear — manual inspection needed"
    fi
  else
    if [[ "$PROFILE" == "empty" ]]; then
      warn "no hooks in settings.json (may be expected for empty repo)"
    else
      fail "no hooks object in settings.json"
    fi
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 3. Expanded hook events (PR #34)"
# ─────────────────────────────────────────────────

if [[ -f ".claude/settings.json" ]]; then
  HOOK_KEYS=$(jq -r '.hooks // {} | keys[]' .claude/settings.json 2>/dev/null || true)
  HOOK_COUNT=$(echo "$HOOK_KEYS" | grep -c '.' || true)

  if [[ "$PROFILE" == "empty" ]]; then
    pass "hook count: ${HOOK_COUNT} (empty repo — any count acceptable)"
  elif [[ "$HOOK_COUNT" -ge 5 ]]; then
    pass "hook events: ${HOOK_COUNT} events (≥5 expected)"
  else
    fail "hook events: only ${HOOK_COUNT} (expected ≥5 for non-empty project)"
  fi

  # Check for at least one expanded event (beyond the original 5)
  EXPANDED_EVENTS="SessionStart|SessionEnd|UserPromptSubmit|PreCompact|SubagentStart|TaskCreated|TaskCompleted|FileChanged|ConfigChange|Elicitation"
  EXPANDED_FOUND=$(echo "$HOOK_KEYS" | grep -cE "$EXPANDED_EVENTS" || true)
  if [[ "$PROFILE" != "empty" && "$EXPANDED_FOUND" -gt 0 ]]; then
    pass "expanded hook events found: ${EXPANDED_FOUND} new events"
  elif [[ "$PROFILE" == "empty" ]]; then
    pass "expanded events: skipped for empty repo"
  else
    warn "no expanded hook events found (may depend on wizard choices)"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 4. MCP generation (PR #35)"
# ─────────────────────────────────────────────────

if [[ -f ".mcp.json" ]]; then
  if jq empty .mcp.json 2>/dev/null; then
    pass ".mcp.json exists and is valid JSON"
  else
    fail ".mcp.json exists but is invalid JSON"
  fi

  MCP_KEYS=$(jq -r '.mcpServers // {} | keys[]' .mcp.json 2>/dev/null || true)

  # context7 should be present for all non-empty projects
  if echo "$MCP_KEYS" | grep -q "context7"; then
    pass "MCP: context7 present"
  elif [[ "$PROFILE" == "empty" ]]; then
    warn "MCP: context7 absent (may be expected for empty repo)"
  else
    fail "MCP: context7 missing (should always be present)"
  fi

  # Stack-specific MCP entries
  case "$PROFILE" in
    nextjs)
      if echo "$MCP_KEYS" | grep -qi "vercel"; then
        pass "MCP: vercel present (vercel.json detected)"
      else
        warn "MCP: vercel missing (vercel.json present in project)"
      fi
      if echo "$MCP_KEYS" | grep -qi "prisma"; then
        pass "MCP: prisma present (prisma/ detected)"
      else
        warn "MCP: prisma missing (prisma/ present in project)"
      fi
      ;;
    python|monorepo)
      pass "MCP: stack-specific entries not expected for ${PROFILE}"
      ;;
  esac
else
  if [[ "$PROFILE" == "empty" ]]; then
    warn ".mcp.json not generated (may be expected for empty repo)"
  else
    fail ".mcp.json missing"
  fi
fi

# MCP setup guide
if [[ -f ".claude/rules/mcp-setup.md" ]]; then
  pass "mcp-setup.md exists"
elif [[ "$PROFILE" == "empty" || "$PROFILE" == "python" ]]; then
  pass "mcp-setup.md: not expected for ${PROFILE}"
else
  warn "mcp-setup.md missing (expected for projects with auth-requiring MCP servers)"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 5. Agent frontmatter (PR #36 + C3 release-gate sweep — frontmatter now MANDATORY)"
# ─────────────────────────────────────────────────

AGENT_COUNT=0
AGENT_WITH_FM=0
if [[ -d ".claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    AGENT_COUNT=$((AGENT_COUNT + 1))
    if head -1 "$agent_file" | grep -q '^---$'; then
      AGENT_WITH_FM=$((AGENT_WITH_FM + 1))
      # Parse frontmatter and check required fields (C3: name + description MUST exist)
      FM=$(sed -n '2,/^---$/{ /^---$/d; p; }' "$agent_file" | head -20)
      if echo "$FM" | grep -qE '^name:'; then
        pass "agent frontmatter: $(basename "$agent_file") has name"
      else
        fail "agent frontmatter: $(basename "$agent_file") missing required 'name' field"
      fi
      if echo "$FM" | grep -qE '^description:'; then
        pass "agent frontmatter: $(basename "$agent_file") has description"
      else
        fail "agent frontmatter: $(basename "$agent_file") missing required 'description' field"
      fi
      # tools is optional per archetype, just informational
      if echo "$FM" | grep -q '^tools:'; then
        pass "agent frontmatter: $(basename "$agent_file") has tools field"
      fi
    else
      # C3 contract: missing frontmatter = HARD FAIL (was a warn pre-sweep)
      fail "agent frontmatter: $(basename "$agent_file") has NO frontmatter (C3 violation)"
    fi
  done < <(find .claude/agents -name '*.md' -print0 2>/dev/null)

  if [[ "$AGENT_COUNT" -gt 0 ]]; then
    pass "agents generated: ${AGENT_COUNT} total, ${AGENT_WITH_FM} with frontmatter"
  fi
else
  if [[ "$PROFILE" == "empty" ]]; then
    warn "no .claude/agents/ directory (may be expected for empty repo)"
  else
    warn "no .claude/agents/ directory"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 6. Output styles (PR #37)"
# ─────────────────────────────────────────────────

if [[ -d ".claude/output-styles" ]]; then
  STYLE_COUNT=0
  while IFS= read -r -d '' style_file; do
    STYLE_COUNT=$((STYLE_COUNT + 1))
    if head -1 "$style_file" | grep -q '^---$'; then
      pass "output style: $(basename "$style_file") has frontmatter"
    else
      fail "output style: $(basename "$style_file") missing frontmatter"
    fi
  done < <(find .claude/output-styles -name '*.md' -print0 2>/dev/null)

  if [[ "$STYLE_COUNT" -gt 0 ]]; then
    pass "output styles generated: ${STYLE_COUNT}"
  else
    warn "output-styles/ directory exists but is empty"
  fi
else
  if [[ "$PROFILE" == "empty" ]]; then
    warn "no output-styles/ directory (may be expected for empty repo)"
  else
    warn "no output-styles/ directory generated"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 7. Snapshots — coupled to telemetry status (C1 release-gate sweep)"
# ─────────────────────────────────────────────────
# Each snapshot is required ONLY when the corresponding telemetry status is "emitted".
# For status="skipped" / "declined", the snapshot is intentionally absent (PASS).
# For status="emitted" but missing snapshot, that's a contract violation (FAIL).

# Map: snapshot file -> telemetry key in onboard-meta.json
declare -a SNAPSHOT_PAIRS=(
  ".claude/onboard-mcp-snapshot.json:mcpStatus"
  ".claude/onboard-skill-snapshot.json:skillStatus"
  ".claude/onboard-agent-snapshot.json:agentStatus"
  ".claude/onboard-output-style-snapshot.json:outputStyleStatus"
  ".claude/onboard-lsp-snapshot.json:lspStatus"
  ".claude/onboard-builtin-skills-snapshot.json:builtInSkillsStatus"
)
META=".claude/onboard-meta.json"
for pair in "${SNAPSHOT_PAIRS[@]}"; do
  snap="${pair%%:*}"
  key="${pair#*:}"
  STATUS=""
  if [[ -f "$META" ]]; then
    STATUS=$(jq -r ".${key}.status // empty" "$META" 2>/dev/null)
  fi

  if [[ -f "$snap" ]]; then
    if jq empty "$snap" 2>/dev/null; then
      pass "snapshot: $(basename "$snap") (status=${STATUS:-unknown})"
    else
      fail "snapshot invalid JSON: $(basename "$snap")"
    fi
  else
    case "$STATUS" in
      emitted)
        fail "snapshot: $(basename "$snap") missing despite ${key}.status=\"emitted\""
        ;;
      documented)
        # "documented" means the artifact lives inside CLAUDE.md, not a separate
        # file/snapshot. Snapshot absence is EXPECTED. Builtin-skills is the
        # current canonical user of this status.
        pass "snapshot: $(basename "$snap") intentionally absent (${key}.status=\"documented\")"
        ;;
      skipped|declined|failed)
        pass "snapshot: $(basename "$snap") intentionally absent (${key}.status=\"${STATUS}\")"
        ;;
      "")
        if [[ "$PROFILE" == "empty" ]]; then
          warn "snapshot missing + telemetry key absent: $(basename "$snap") (acceptable for empty repo)"
        else
          fail "snapshot missing + telemetry key absent: $(basename "$snap")"
        fi
        ;;
      *)
        fail "snapshot missing + telemetry status='${STATUS}' is not in {emitted|documented|skipped|declined|failed}"
        ;;
    esac
  fi
done
echo ""

# ─────────────────────────────────────────────────
echo "### 8. Telemetry completeness — keys mandatory + status enum validated (C1 release-gate sweep)"
# ─────────────────────────────────────────────────

if [[ -f "$META" ]]; then
  STATUS_KEYS=("hookStatus" "skillStatus" "agentStatus" "mcpStatus" "outputStyleStatus" "lspStatus" "builtInSkillsStatus")
  for key in "${STATUS_KEYS[@]}"; do
    HAS_KEY=$(jq "has(\"${key}\")" "$META" 2>/dev/null || echo "false")
    if [[ "$HAS_KEY" != "true" ]]; then
      if [[ "$PROFILE" == "empty" ]]; then
        warn "telemetry: ${key} missing (acceptable for empty repo)"
      else
        # C1 contract: missing telemetry key = HARD FAIL (was a warn pre-sweep)
        fail "telemetry: ${key} missing — C1 contract requires every Phase 7 telemetry key to exist"
      fi
      continue
    fi

    # Validate the status enum value (post-C1.1: emitted | documented | skipped | declined | failed)
    # hookStatus/skillStatus/agentStatus may not have a top-level .status pre-sweep;
    # accept missing .status only on those three, but enforce on Phase 7 keys.
    STATUS_VAL=$(jq -r ".${key}.status // empty" "$META" 2>/dev/null)
    case "$key" in
      mcpStatus|outputStyleStatus|lspStatus|builtInSkillsStatus)
        case "$STATUS_VAL" in
          emitted|documented|skipped|declined|failed)
            pass "telemetry: ${key} present (status=\"${STATUS_VAL}\")"
            ;;
          "")
            fail "telemetry: ${key}.status missing — C1 contract requires the status enum"
            ;;
          *)
            fail "telemetry: ${key}.status=\"${STATUS_VAL}\" is not in {emitted|documented|skipped|declined|failed}"
            ;;
        esac
        ;;
      *)
        # hookStatus/skillStatus/agentStatus: status enum optional pre-sweep, just confirm key
        pass "telemetry: ${key} present"
        ;;
    esac
  done
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 9. CLAUDE.md content (PRs #37-#39)"
# ─────────────────────────────────────────────────

if [[ -f "CLAUDE.md" ]]; then
  # Built-in skills section (PR #39)
  if grep -qi "built-in.*skill\|claude code skill" CLAUDE.md; then
    pass "CLAUDE.md: built-in skills section found"
  else
    if [[ "$PROFILE" == "empty" ]]; then
      warn "CLAUDE.md: no built-in skills section (may be expected for empty repo)"
    else
      warn "CLAUDE.md: no built-in skills section"
    fi
  fi

  # Plugin Integration or LSP section (PR #38)
  if grep -qi "LSP\|language server" CLAUDE.md; then
    pass "CLAUDE.md: LSP reference found"
  else
    if [[ "$PROFILE" == "nextjs" || "$PROFILE" == "monorepo" ]]; then
      warn "CLAUDE.md: no LSP reference (expected for ${PROFILE})"
    else
      pass "CLAUDE.md: LSP reference not expected for ${PROFILE}"
    fi
  fi

  # Output style reference (PR #37)
  if grep -qi "output.style\|output style" CLAUDE.md; then
    pass "CLAUDE.md: output style reference found"
  else
    warn "CLAUDE.md: no output style reference"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 10. Session safety — no schema errors"
# ─────────────────────────────────────────────────

if [[ -f ".claude/settings.json" ]]; then
  # Basic schema validation: hooks should be an object, not array
  HOOKS_TYPE=$(jq -r '.hooks | type' .claude/settings.json 2>/dev/null || echo "null")
  if [[ "$HOOKS_TYPE" == "object" ]]; then
    pass "settings.json: hooks is an object (correct)"
  elif [[ "$HOOKS_TYPE" == "null" ]]; then
    if [[ "$PROFILE" == "empty" ]]; then
      pass "settings.json: no hooks (acceptable for empty)"
    else
      warn "settings.json: hooks is null"
    fi
  else
    fail "settings.json: hooks is ${HOOKS_TYPE} (expected object)"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 11. Dynamic onboard version (L4 release-gate sweep)"
# ─────────────────────────────────────────────────
# pluginVersion in onboard-meta.json must match the actual installed onboard
# plugin version, never a stale literal like "1.2.0".
if [[ -f "$META" ]]; then
  RECORDED_VER=$(jq -r '.pluginVersion // empty' "$META" 2>/dev/null)
  # Try to resolve actual installed onboard version via CLI then sibling-path heuristic
  ACTUAL_VER=""
  if command -v claude >/dev/null 2>&1; then
    ACTUAL_VER=$(claude plugins info onboard --format json 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)
  fi
  if [[ -z "$ACTUAL_VER" && -f "${CLAUDE_PLUGIN_ROOT:-}/../onboard/.claude-plugin/plugin.json" ]]; then
    ACTUAL_VER=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/../onboard/.claude-plugin/plugin.json" 2>/dev/null || true)
  fi
  # Fallback for repo-local testing: read from the claude-plugins checkout
  if [[ -z "$ACTUAL_VER" ]]; then
    REPO_ONBOARD_MANIFEST=""
    for candidate in "$HOME/Desktop/projects/claude-plugins/onboard/.claude-plugin/plugin.json" \
                     "$(git rev-parse --show-toplevel 2>/dev/null)/onboard/.claude-plugin/plugin.json"; do
      if [[ -f "$candidate" ]]; then
        REPO_ONBOARD_MANIFEST="$candidate"
        break
      fi
    done
    if [[ -n "$REPO_ONBOARD_MANIFEST" ]]; then
      ACTUAL_VER=$(jq -r '.version' "$REPO_ONBOARD_MANIFEST" 2>/dev/null || true)
    fi
  fi

  if [[ -z "$RECORDED_VER" ]]; then
    fail "pluginVersion missing from onboard-meta.json"
  elif [[ "$RECORDED_VER" == "1.2.0" ]]; then
    fail "pluginVersion is stale literal '1.2.0' (L4 violation — must be read at runtime)"
  elif [[ -z "$ACTUAL_VER" ]]; then
    warn "pluginVersion=${RECORDED_VER} recorded; could not resolve actual installed onboard for comparison"
  elif [[ "$RECORDED_VER" == "$ACTUAL_VER" ]]; then
    pass "pluginVersion=${RECORDED_VER} matches installed onboard"
  else
    warn "pluginVersion=${RECORDED_VER} but installed onboard is ${ACTUAL_VER} (may be stale post-upgrade)"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 12. Wizard telemetry (C4 release-gate sweep — wizardStatus added)"
# ─────────────────────────────────────────────────
if [[ -f "$META" ]]; then
  HAS_WIZ=$(jq 'has("wizardStatus")' "$META" 2>/dev/null || echo "false")
  if [[ "$HAS_WIZ" == "true" ]]; then
    pass "telemetry: wizardStatus present"
    # Expected sub-fields: presetUsed, exchangesUsed, phasesAsked, phasesSkipped, escapeHatchTriggered
    for sub in presetUsed exchangesUsed phasesAsked phasesSkipped escapeHatchTriggered; do
      HAS_SUB=$(jq ".wizardStatus | has(\"${sub}\")" "$META" 2>/dev/null || echo "false")
      if [[ "$HAS_SUB" == "true" ]]; then
        pass "wizardStatus.${sub} present"
      else
        warn "wizardStatus.${sub} missing"
      fi
    done
  else
    if [[ "$PROFILE" == "empty" || "$PROFILE" == "forge" ]]; then
      warn "wizardStatus missing (forge bypasses wizard; empty profile may skip)"
    else
      fail "telemetry: wizardStatus missing — C4 requires per-run wizard telemetry"
    fi
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 13. Forge metadata shape (L5 release-gate sweep — toolingFlags namespace)"
# ─────────────────────────────────────────────────
# Only applies to forge-scaffolded projects: forge-meta.json must use
# generated.toolingFlags.tooling/cicd/harness, NOT the old dot-notation siblings.
if [[ "$PROFILE" == "forge" ]]; then
  if [[ -f ".claude/forge-meta.json" ]]; then
    if jq empty .claude/forge-meta.json 2>/dev/null; then
      pass "forge-meta.json valid JSON"
      # Old shape: generated.tooling | generated.cicd | generated.harness as siblings
      OLD_SIBLINGS=$(jq -r '.generated | keys | map(select(. == "tooling" or . == "cicd" or . == "harness")) | .[]' .claude/forge-meta.json 2>/dev/null || true)
      if [[ -n "$OLD_SIBLINGS" ]]; then
        fail "forge-meta.json still uses dot-notation siblings (generated.tooling/cicd/harness) — L5 violation"
      else
        pass "forge-meta.json: no generated.tooling/cicd/harness sibling keys"
      fi
      # New shape: generated.toolingFlags should hold tooling/cicd/harness
      for sub in tooling cicd harness; do
        HAS_SUB=$(jq ".generated.toolingFlags | has(\"${sub}\")" .claude/forge-meta.json 2>/dev/null || echo "false")
        if [[ "$HAS_SUB" == "true" ]]; then
          pass "forge-meta.json: generated.toolingFlags.${sub} present"
        else
          fail "forge-meta.json: generated.toolingFlags.${sub} missing"
        fi
      done
    else
      fail "forge-meta.json invalid JSON"
    fi
  else
    fail "forge-meta.json missing for forge profile"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "## Summary — ${PROFILE}"
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
