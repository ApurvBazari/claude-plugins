#!/usr/bin/env bash
set -euo pipefail

# verify-init-output.sh — Verify /onboard:start generated artifacts
# Usage: verify-init-output.sh <REPO_PATH> <PROFILE>
# Profiles: nextjs | python | monorepo | empty

REPO="${1:-}"
PROFILE="${2:-nextjs}"

if [[ -z "$REPO" || ! -d "$REPO" ]]; then
  echo "Usage: verify-init-output.sh <REPO_PATH> <PROFILE>"
  echo "Profiles: nextjs | python | monorepo | empty"
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

echo "## Verify /onboard:start Output"
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
# Detect stub mode once (used across sections). Post-Cluster-2 stubs emit
# top-level mode:"stub-empty-repo" in canonical-schema onboard-meta.json.
STUB_MODE=""
if [[ -f "$META" ]]; then
  STUB_MODE=$(jq -r '.mode // empty' "$META" 2>/dev/null)
fi
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
  # Post-Cluster-2, canonical stubs emit top-level mode:"stub-empty-repo" and
  # keep all 7 Phase 7 telemetry keys present (each status:"skipped", reason:
  # "stub-mode-no-code"). Pre-Cluster-2 empty fixtures may legitimately lack
  # keys. STUB_MODE was set once at the top of the script.
  IS_CANONICAL_STUB=0
  [[ "$STUB_MODE" == "stub-empty-repo" ]] && IS_CANONICAL_STUB=1

  STATUS_KEYS=("hookStatus" "skillStatus" "agentStatus" "mcpStatus" "outputStyleStatus" "lspStatus" "builtInSkillsStatus")
  for key in "${STATUS_KEYS[@]}"; do
    HAS_KEY=$(jq "has(\"${key}\")" "$META" 2>/dev/null || echo "false")
    if [[ "$HAS_KEY" != "true" ]]; then
      if [[ "$IS_CANONICAL_STUB" -eq 1 ]]; then
        # Canonical stub MUST have all 7 keys. Missing is a hard fail in stub mode.
        fail "telemetry: ${key} missing in canonical stub — stub schema requires all 7 Phase 7 keys with status:\"skipped\""
      elif [[ "$PROFILE" == "empty" ]]; then
        warn "telemetry: ${key} missing (acceptable for empty repo pre-Cluster-2 schema)"
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
  elif [[ "$RECORDED_VER" == "1.0.0" && "$STUB_MODE" == "stub-empty-repo" ]]; then
    # B15: pre-Cluster-2 stubs hardcoded "1.0.0"; post-Cluster-2 stubs resolve dynamically.
    fail "pluginVersion hardcoded '1.0.0' in stub mode (B15 regression — must read from plugin.json)"
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
echo "### 12. Wizard telemetry (v3 collapsed wizard — canonical 5-key wizardStatus)"
# ─────────────────────────────────────────────────
# v3 dropped the "Choose Wizard Mode" / Quick-Mode-vs-Guided step and the Custom
# preset. The canonical wizardStatus shape (wizard/SKILL.md Key Rule 7) has EXACTLY
# 5 keys: presetUsed, exchangesUsed, phasesAsked, phasesSkipped, escapeHatchTriggered.
#   - presetUsed enum: minimal | standard | comprehensive (NO custom/quick-mode/interactive)
#   - escapeHatchTriggered: always false (escape hatch removed; key retained for shape stability)
if [[ -f "$META" ]]; then
  HAS_WIZ=$(jq 'has("wizardStatus")' "$META" 2>/dev/null || echo "false")
  if [[ "$HAS_WIZ" == "true" ]]; then
    pass "telemetry: wizardStatus present"
    # Canonical 5-key shape — every key MUST be present (empty arrays valid; missing keys not).
    for sub in presetUsed exchangesUsed phasesAsked phasesSkipped escapeHatchTriggered; do
      HAS_SUB=$(jq ".wizardStatus | has(\"${sub}\")" "$META" 2>/dev/null || echo "false")
      if [[ "$HAS_SUB" == "true" ]]; then
        pass "wizardStatus.${sub} present"
      else
        fail "wizardStatus.${sub} missing — v3 canonical shape requires all 5 keys"
      fi
    done

    # presetUsed enum: minimal | standard | comprehensive only.
    PRESET_USED=$(jq -r '.wizardStatus.presetUsed // empty' "$META" 2>/dev/null)
    case "$PRESET_USED" in
      minimal|standard|comprehensive)
        pass "wizardStatus.presetUsed=\"${PRESET_USED}\" (valid v3 enum)"
        ;;
      custom|quick-mode|interactive)
        fail "wizardStatus.presetUsed=\"${PRESET_USED}\" is a dropped v2 value — must be minimal|standard|comprehensive"
        ;;
      "")
        fail "wizardStatus.presetUsed missing or empty"
        ;;
      *)
        fail "wizardStatus.presetUsed=\"${PRESET_USED}\" is not in {minimal|standard|comprehensive}"
        ;;
    esac

    # escapeHatchTriggered: always false in v3 (escape hatch removed, key retained).
    ESCAPE_HATCH=$(jq -r '.wizardStatus.escapeHatchTriggered' "$META" 2>/dev/null)
    if [[ "$ESCAPE_HATCH" == "false" ]]; then
      pass "wizardStatus.escapeHatchTriggered=false (v3 escape hatch removed; key retained)"
    else
      fail "wizardStatus.escapeHatchTriggered=\"${ESCAPE_HATCH}\" — v3 requires it to always be false"
    fi
  else
    if [[ "$PROFILE" == "empty" ]]; then
      warn "wizardStatus missing (empty profile may skip)"
    else
      fail "telemetry: wizardStatus missing — v3 requires per-run wizard telemetry"
    fi
  fi

  # wizardAnswers.selectedPreset enum: minimal | standard | comprehensive (dropped custom).
  HAS_ANSWERS=$(jq 'has("wizardAnswers")' "$META" 2>/dev/null || echo "false")
  if [[ "$HAS_ANSWERS" == "true" ]]; then
    SELECTED_PRESET=$(jq -r '.wizardAnswers.selectedPreset // empty' "$META" 2>/dev/null)
    case "$SELECTED_PRESET" in
      minimal|standard|comprehensive)
        pass "wizardAnswers.selectedPreset=\"${SELECTED_PRESET}\" (valid v3 enum)"
        ;;
      custom|quick-mode|interactive)
        fail "wizardAnswers.selectedPreset=\"${SELECTED_PRESET}\" is a dropped v2 value — must be minimal|standard|comprehensive"
        ;;
      "")
        # Stub-mode paths emit wizardAnswers:{} (no selectedPreset). Acceptable.
        if [[ "$STUB_MODE" == "stub-empty-repo" || "$PROFILE" == "empty" ]]; then
          pass "wizardAnswers.selectedPreset absent (acceptable for stub/empty path)"
        else
          fail "wizardAnswers.selectedPreset missing — v3 canonical shape requires it"
        fi
        ;;
      *)
        fail "wizardAnswers.selectedPreset=\"${SELECTED_PRESET}\" is not in {minimal|standard|comprehensive}"
        ;;
    esac
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 13. v3 research artifacts (recon → profile → research spine)"
# ─────────────────────────────────────────────────
# The v3 flow runs onboard:research between profile-select and the grounded wizard.
# The research engine ALWAYS writes .claude/onboard-research.json (every location
# choice, including "none"); it writes docs/onboard/{research-dossier,architecture,
# risk-register,glossary}.md ONLY when the per-run location choice is "committed".
# The test harness runs /onboard:start manually and does not control that choice,
# so the docs/onboard/ files are CONDITIONAL — present them as informational, never
# a hard fail. (research/SKILL.md Step 7.)
RESEARCH=".claude/onboard-research.json"
if [[ -f "$RESEARCH" ]]; then
  if jq empty "$RESEARCH" 2>/dev/null; then
    pass "research: ${RESEARCH} exists and is valid JSON"
  else
    fail "research: ${RESEARCH} exists but is invalid JSON"
  fi
else
  if [[ "$STUB_MODE" == "stub-empty-repo" || "$PROFILE" == "empty" ]]; then
    warn "research: ${RESEARCH} absent (acceptable for stub/empty path)"
  else
    fail "research: ${RESEARCH} missing — v3 research engine always writes it"
  fi
fi

# docs/onboard/ render artifacts — only when the run chose "committed". Conditional.
DOCS_PRESENT=0
for doc in research-dossier architecture risk-register glossary; do
  if [[ -f "docs/onboard/${doc}.md" ]]; then
    DOCS_PRESENT=$((DOCS_PRESENT + 1))
  fi
done
if [[ "$DOCS_PRESENT" -eq 4 ]]; then
  pass "research docs: all 4 docs/onboard/*.md present (run chose 'committed')"
elif [[ "$DOCS_PRESENT" -eq 0 ]]; then
  pass "research docs: docs/onboard/*.md absent (run chose 'local'/'none' — conditional, not required)"
else
  warn "research docs: ${DOCS_PRESENT}/4 docs/onboard/*.md present — expected all 4 or none"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 14. Plugin Integration slash-ref existence — no fabrications (Cluster 3)"
# ─────────────────────────────────────────────────
# Every /<plugin>:<slug> in the generated CLAUDE.md MUST correspond to an
# actual file at <plugin>/commands/<slug>.md OR <plugin>/skills/<slug>/SKILL.md.
# Fabricated refs were release-gate finding G.3 (2026-04-17) — the generator
# emitted /security-guidance:security-review for a hooks-only plugin.

if [[ -f "CLAUDE.md" && "$IS_CANONICAL_STUB" -ne 1 ]]; then
  CACHE="$HOME/.claude/plugins/cache"
  # Sibling root — walk up from the fixture's parent; covers dev repo layout
  SIBLING_ROOT="$(dirname "$(pwd)")"
  # Also accept sibling of the caller (common when running from a subproject):
  [ -d "$SIBLING_ROOT/onboard" ] || SIBLING_ROOT="$HOME/Desktop/projects/claude-plugins"

  FABRICATED=0
  TOTAL_REFS=0
  while IFS= read -r ref; do
    TOTAL_REFS=$((TOTAL_REFS + 1))
    P="${ref#/}"; P="${P%%:*}"
    S="${ref##*:}"
    FOUND=0

    # Probe both locations; accept any matching file
    for candidate in \
      "$SIBLING_ROOT/$P/commands/$S.md" \
      "$SIBLING_ROOT/$P/skills/$S/SKILL.md" \
      "$CACHE"/*/"$P"/commands/"$S".md \
      "$CACHE"/*/"$P"/*/commands/"$S".md \
      "$CACHE"/*/"$P"/skills/"$S"/SKILL.md \
      "$CACHE"/*/"$P"/*/skills/"$S"/SKILL.md; do
      if [ -f "$candidate" ] 2>/dev/null; then
        FOUND=1
        break
      fi
    done

    if [ $FOUND -eq 0 ]; then
      fail "fabricated slash ref in CLAUDE.md: ${ref} (no file at <plugin>/commands/<slug>.md or <plugin>/skills/<slug>/SKILL.md)"
      FABRICATED=$((FABRICATED + 1))
    fi
  done < <(grep -oE '/[a-z][a-z0-9-]*:[a-z][a-z0-9-]*' CLAUDE.md | sort -u)

  if [ $TOTAL_REFS -gt 0 ] && [ $FABRICATED -eq 0 ]; then
    pass "Plugin Integration slash refs: ${TOTAL_REFS} checked, 0 fabricated"
  elif [ $TOTAL_REFS -eq 0 ]; then
    pass "Plugin Integration slash refs: none emitted (acceptable when no plugins installed)"
  fi
fi
echo ""

# ─────────────────────────────────────────────────
echo "### 15. v3 research consumption + verify-backlog (Plan 4b)"
# ─────────────────────────────────────────────────
# When a real /onboard:start run consumed research, generation records a minimal
# metadata.research block and (when verified risk/test-gap claims existed) seeds
# docs/feature-list.json in the evaluator-readable harness shape. Both are
# CONDITIONAL on the run actually having research + findings, so absence is not a
# hard fail here — this section is the dogfood gate, not a unit test.

if [[ -f "$META" ]]; then
  HAS_RESEARCH_META=$(jq 'has("research")' "$META" 2>/dev/null || echo "false")
  if [[ "$HAS_RESEARCH_META" == "true" ]]; then
    CONSUMED=$(jq -r '.research.consumed | if . == null then empty else tostring end' "$META" 2>/dev/null)
    if [[ "$CONSUMED" == "true" ]]; then
      # Minimal-useful block: all 5 keys must be present when consumed.
      for sub in consumed depth verifiedClaimCount backlogSeeded backlogItemCount; do
        if [[ "$(jq ".research | has(\"${sub}\")" "$META" 2>/dev/null)" == "true" ]]; then
          pass "metadata.research.${sub} present"
        else
          fail "metadata.research.${sub} missing — 4b minimal-useful block requires all 5 keys"
        fi
      done
    elif [[ "$CONSUMED" == "false" ]]; then
      pass "metadata.research.consumed=false (research-absent / regenerateOnly mode)"
    else
      fail "metadata.research present but .consumed is not a boolean"
    fi
  else
    warn "metadata.research absent (run had no research, or pre-4b output — informational)"
  fi
fi

# Verify-backlog: when seeded, docs/feature-list.json must be evaluator-readable.
if [[ -f "docs/feature-list.json" ]]; then
  if jq empty docs/feature-list.json 2>/dev/null; then
    HAS_SPRINTS=$(jq 'has("sprints")' docs/feature-list.json 2>/dev/null || echo "false")
    HAS_FEATURE_SHAPE=$(jq '[.sprints[]?.features[]? | has("id") and has("steps") and has("passes")] | (length > 0) and all' docs/feature-list.json 2>/dev/null || echo "false")
    if [[ "$HAS_SPRINTS" == "true" && "$HAS_FEATURE_SHAPE" == "true" ]]; then
      pass "feature-list: evaluator-readable harness shape (sprints[].features[].{id,steps,passes})"
    elif [[ "$HAS_SPRINTS" == "true" ]]; then
      warn "feature-list: sprints present but features missing id/steps/passes (or empty)"
    else
      warn "feature-list: present but not in sprints[] harness shape (may be a non-research list)"
    fi
  else
    fail "feature-list: docs/feature-list.json is invalid JSON"
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
