# Transcript Analysis — Actionable Findings Across All Phases

Date: 2026-04-16
Transcripts analyzed: Phase 2 (onboard:init), Phase 4 (onboard:update), Phase 5 (forge:init)

## Critical (3)

### A1. Wizard 6-exchange hard limit exhausted too early

**Phase**: 2 (onboard:init)
**Source**: wizard/SKILL.md defines a hard 6-exchange limit

The Custom preset consumed all 6 exchanges on Phases 1-5.1, leaving no room for Phase 5.6 (LSP), Phase 5.7 (Built-in Skills), or Phase 3 (Tech-Stack Specific). The wizard correctly said "I'm at my last wizard exchange" and defaulted remaining fields.

**Impact**: Absent wizard answers for LSP and built-in skills should trigger Quick Mode defaults in generation (accept all detected candidates), but the generation pipeline didn't apply this fallback.

**Fix**: Either increase exchange limit for Custom preset (to 8-9), or combine Phases 5.6 and 5.7 into one multiSelect exchange. Also ensure generation treats absent fields as "use Quick Mode defaults."

### A2. Config-generator agent skipped all Phase 7 blocks

**Phase**: 2 (onboard:init)
**Source**: generation/SKILL.md defines Phase 7a (MCP), 7b (Output Styles), 7c (LSP), 7d (Built-in Skills) as mandatory

The config-generator ran for 6m 36s and generated 23 artifacts — but none from Phase 7. All four Phase 7 blocks have clear "When to run" conditions that were met (Prisma + Vercel signals for MCP, TypeScript for LSP, CI/CD for built-in skills). The generation skill documents fallback logic for absent wizard answers (Quick Mode semantics).

**Impact**: .mcp.json, output styles, LSP setup, built-in skills section, and 5 of 6 snapshots were not generated.

**Fix**: Investigate whether the config-generator agent is running out of turn budget before reaching Phase 7, or whether the Phase 7 instructions are insufficiently prominent in the generation skill for the agent to follow consistently.

### A9. onboard:generate did NOT spawn config-generator agent (forge)

**Phase**: 5 (forge:init)
**Source**: generate/SKILL.md explicitly says "Spawn the `config-generator` agent" at Step 3

The transcript shows onboard:generate was invoked via Skill tool, but artifacts were written directly in the main conversation context instead of spawning the config-generator agent. This means the entire generation pipeline was bypassed — no hooks, no agents, no skills, no MCP, no output styles, no snapshots.

**Impact**: Forge-scaffolded projects get CLAUDE.md + rules + CI/CD but miss all onboard-owned artifacts.

**Fix**: The generate skill needs stronger instruction to spawn config-generator. The current instruction may be getting lost when invoked headlessly through multiple skill layers (forge → tooling-generation → generate → should spawn agent).

## High (2)

### A3. Agents generated without YAML frontmatter

**Phase**: 2 (onboard:init)
**Source**: PR #36 added agent frontmatter generation

The agent snapshot (`onboard-agent-snapshot.json`) records frontmatter fields per agent — but the actual `.claude/agents/*.md` files have NO `---` frontmatter. The snapshot and files are inconsistent.

**Fix**: Strengthen agents-guide.md instructions to require YAML frontmatter, or check if config-generator is generating agents using an older template.

### A10. callerExtras disable flags misinterpreted as "skip entirely"

**Phase**: 5 (forge:init)
**Source**: generate/SKILL.md documents disable flags as "suppress confirmation, emit defaults directly"

Documented behavior: `disableOutputStyleTuning: true` → "emit archetype-matched style without asking"
Actual behavior: output style generation skipped entirely

**Fix**: Config-generator instructions need explicit distinction between "disable tuning" (skip confirmation, use defaults) and "disable generation" (skip phase entirely). Currently treated as equivalent.

## Medium (5)

### A5. AskUserQuestion not used consistently in wizard

**Phase**: 2 (onboard:init)

Wizard asked questions as inline text ("1. Minimal 2. Standard 3. Comprehensive 4. Custom") rather than using AskUserQuestion with structured option buttons. The wizard SKILL.md instructs to use AskUserQuestion for all interactive selections.

### A7. Update used inline text for approval instead of AskUserQuestion

**Phase**: 4 (onboard:update)

Presented 10 numbered offers and asked "Which updates would you like me to apply? (all / specific numbers / none)" as inline text rather than AskUserQuestion with multiSelect.

### A11. Stack research agent failed silently (forge)

**Phase**: 5 (forge:init)

`forge:stack-researcher` was dispatched as a background agent but "didn't have web access in this session." Forge had to redo web searches in the main session, wasting ~2 min and several turns.

**Fix**: Stack-researcher agent needs WebSearch/WebFetch in its tools list, or forge should detect background agent failure and handle without re-asking.

### A13. pnpm approve-builds not handled programmatically (forge)

**Phase**: 5 (forge:init)

Scaffold tried `pnpm approve-builds --allow` (invalid flag), then interactive TUI (can't script), then multiple workarounds before using `pnpm.onlyBuiltDependencies` in package.json.

**Fix**: Scaffolding skill should use `pnpm.onlyBuiltDependencies` in package.json from the start.

### A14. Engineering plugin referenced but doesn't exist

**Phase**: 5 (forge:init)

Plugin catalog references `engineering` plugin for Phase 4 (lifecycle docs). `claude plugins install engineering` fails — not in marketplace.

**Fix**: Remove from catalog or mark as "planned" so forge doesn't offer it.

## Low (4)

### A4. Model recommendation asked as separate post-wizard question

**Phase**: 2 (onboard:init)

After wizard summary, Claude asked "Which model would you like to use?" as a separate interaction. Could be folded into the wizard flow to save an exchange.

### A6. Update fetched wrong docs URLs (301 redirects)

**Phase**: 4 (onboard:update)

Fetched `docs.anthropic.com/en/docs/claude-code` (301) before finding `code.claude.com/docs/en/settings`. Wasted 4 turns.

**Fix**: Update reference URLs to `code.claude.com/docs/en/*`.

### A8. Rust LSP not explicitly listed as numbered offer in update

**Phase**: 4 (onboard:update)

Mentioned in narrative but not in the numbered upgrade offers. User had to infer it was optional.

### A12. DateTime scalar missing from forge scaffold

**Phase**: 5 (forge:init)

Pothos builder didn't register DateTime scalar. API failed on first start — Claude fixed it in-session.

**Fix**: From-scratch template should include `builder.addScalarType('DateTime', DateTimeResolver)`.

## Causal Chain

The three critical issues form a causal chain:

```
A1 (wizard exchange limit)
  → wizard defaults LSP + built-in skills fields
    → generation receives incomplete wizard answers
      → A2 (config-generator skips Phase 7 blocks)
        → missing .mcp.json, output styles, LSP, built-in skills, snapshots

A9 (generate doesn't spawn config-generator in headless mode)
  → forge writes artifacts directly
    → A10 (disable flags misinterpreted)
      → entire generation pipeline bypassed for forge
```

Fixing A1 + A2 addresses the onboard:init path.
Fixing A9 + A10 addresses the forge:init path.
Both share the same downstream effect: Phase 7 blocks don't fire.
