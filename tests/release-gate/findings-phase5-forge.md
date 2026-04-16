# Phase 5 Findings — `/forge:init` End-to-End

Date: 2026-04-16
Target: test-forge (fresh empty repo, health/fitness mobile app, Expo + Express + GraphQL)

## Verification Results

**5 pass, 16 warnings, 2 failures** out of 23 checks.

## Forge Pipeline Summary

| Phase | Status | Duration | Notes |
|---|---|---|---|
| Phase 1: Context Gathering | PASS | ~15 min | 8 wizard steps, stack research, feature decomposition (21 features / 4 sprints) |
| Phase 2: Scaffold | PASS | ~10 min | Full Turborepo monorepo, API verified at localhost:4000, 53 files committed |
| Phase 3a: Plugin Discovery | PASS | ~2 min | 9 plugins matched, 8 installed (engineering not found) |
| Phase 3b: Tooling Generation | PARTIAL | ~8 min | CLAUDE.md + rules + CI/CD + harness generated; hooks, agents, MCP, snapshots missing |
| Phase 4: Lifecycle Setup | SKIPPED | — | Engineering plugin not available in marketplace |

Total session: ~$13.82, ~30 min, 18% context used

## Failures (blocking)

| ID | Issue | Details |
|---|---|---|
| FF1 | `settings.json` not created | No hook configuration generated. The onboard init path creates settings.json with hooks — the forge headless path skipped it entirely. |
| FF2 | `.mcp.json` not generated | MCP generation phase (PR #35) didn't fire. This project has Prisma + Express + TypeScript — should have context7 at minimum. |

## Warnings (16 total)

### Missing artifacts (should have been generated)

| Artifact | Expected | Actual | Root cause |
|---|---|---|---|
| `.claude/agents/*.md` | 3-5 agents (reviewer, test-writer, security, feature-builder, infra) | 0 agents | Headless generation didn't invoke agent creation |
| `.claude/output-styles/*.md` | 1 output style | None | Output style phase skipped |
| `.claude/skills/*/SKILL.md` | 2-3 skills | 0 skills | Skill generation skipped |

### Missing snapshots (all 6)

| Snapshot | Status |
|---|---|
| `onboard-mcp-snapshot.json` | Missing |
| `onboard-skill-snapshot.json` | Missing |
| `onboard-agent-snapshot.json` | Missing |
| `onboard-output-style-snapshot.json` | Missing |
| `onboard-lsp-snapshot.json` | Missing |
| `onboard-builtin-skills-snapshot.json` | Missing |

### Missing telemetry keys in onboard-meta.json

| Key | Status |
|---|---|
| `hookStatus` | Present (only one) |
| `skillStatus` | Missing |
| `agentStatus` | Missing |
| `mcpStatus` | Missing |
| `outputStyleStatus` | Missing |
| `lspStatus` | Missing |
| `builtInSkillsStatus` | Missing |

### CLAUDE.md content gaps

- No built-in skills section (PR #39)
- No output style reference (PR #37)
- LSP section: correctly not expected for forge (scaffold has placeholder code, LSP signals premature)

## Root Cause Analysis

The `tooling-generation` skill invoked `Skill(onboard:generate)` which loaded the generate skill. However, the generation then wrote a subset of artifacts directly instead of running the full onboard generation pipeline:

**What was generated (13 files):**
- `CLAUDE.md` (root) + `apps/api/CLAUDE.md` + `apps/mobile/CLAUDE.md` — 3 files
- `.claude/rules/` — 4 rules (graphql-resolvers, prisma-schema, expo-screens, security)
- `.github/workflows/ci.yml` + `.github/PULL_REQUEST_TEMPLATE.md` — 2 files
- `init.sh` + `docs/feature-list.json` + `docs/progress.md` + `docs/sprint-contracts/sprint-1.json` — 4 files

**What was NOT generated (expected from PRs #30-#39):**
- `.claude/settings.json` with hooks (PR #32, #34)
- `.claude/agents/*.md` with YAML frontmatter (PR #36)
- `.claude/skills/*/SKILL.md` (PR #36)
- `.mcp.json` (PR #35)
- `.claude/output-styles/*.md` (PR #37)
- All 6 snapshot files (PRs #35-#39)
- Built-in skills and LSP sections in CLAUDE.md (PRs #38-#39)

**Hypothesis**: The `callerExtras` disable flags (`disableMCP: true`, `disableSkillTuning: true`, `disableAgentTuning: true`, `disableOutputStyleTuning: true`, `disableLSP: true`, `disableBuiltInSkills: true`) are intended to suppress interactive wizard prompts during headless runs. But the generation pipeline interprets them as "skip the entire phase" rather than "apply defaults without prompting." This means the disable flags are too aggressive — they should suppress interactivity, not generation.

## Forge-Specific Observations

### What worked well

- **Context gathering wizard** is excellent — 8 structured steps, checkpointing to `forge-state.json` at each step, research agent for stack version lookups
- **Scaffold quality** is impressive — full working Turborepo monorepo with Expo Router, Express + Apollo Server + Pothos, Prisma schema with 9 health domain models, Docker Compose, shared TypeScript types, JWT auth middleware, seed data
- **API verified running** — health endpoint returned `{"status":"ok"}`, GraphQL at `/graphql`
- **Plugin discovery** correctly matched 9 plugins from the catalog based on project context
- **Feature decomposition** produced a solid 21-feature, 4-sprint breakdown with acceptance criteria
- **Graceful degradation** — engineering plugin not found, Phase 4 skipped cleanly with clear messaging

### Issues specific to forge (not shared with onboard)

| ID | Issue | Severity |
|---|---|---|
| FO1 | `engineering` plugin referenced in catalog but doesn't exist in marketplace | Medium — Phase 4 always skips |
| FO2 | `forge-meta.json` uses non-standard key format (`generated.tooling`, `generated.cicd`, `generated.harness`) instead of the `toolingFlags` structure documented in the forge CLAUDE.md | Low — cosmetic but inconsistent |
| FO3 | Scaffold research agent dispatched to background but failed (no web access) — had to re-run research in main session | Medium — wasted turns |
| FO4 | `pnpm approve-builds` interactive prompt not handled — took multiple attempts with workarounds | Medium — fragile dependency setup |
| FO5 | DateTime scalar not registered in Pothos builder — API failed on first start, required a fix before verify | Low — scaffold quality issue |
| FO6 | `onboard-meta.json` records `pluginVersion: "1.2.0"` but the actual onboard version is 1.9.0 | Low — stale version in headless context |

### Forge → Onboard delegation

The transcript shows `Skill(onboard:generate)` was invoked, but the actual artifact writing happened inline rather than through the config-generator agent. The expected flow per the forge `tooling-generation` skill:

```
Expected:
  forge:tooling-generation
    → prepares onboard-context.json
    → Skill(onboard:generate)
      → config-generator agent (write)
        → generates ALL artifacts (CLAUDE.md + rules + hooks + agents + skills + MCP + snapshots)

Actual:
  forge:tooling-generation
    → prepares onboard-context.json
    → Skill(onboard:generate)
    → writes CLAUDE.md + rules + CI/CD + harness DIRECTLY (bypassing config-generator agent)
    → skips hooks, agents, skills, MCP, output styles, LSP, built-in skills, snapshots
```

This is the core integration bug: the headless generate skill doesn't properly delegate to the config-generator agent, which is where all the generation logic lives.

## What passed verification

- CLAUDE.md exists with correct project context (125 lines)
- `.claude/` directory created
- `onboard-meta.json` exists and is valid JSON
- `hookStatus` telemetry key present (though minimal)
- CLAUDE.md correctly does NOT reference LSP (premature for scaffold)
