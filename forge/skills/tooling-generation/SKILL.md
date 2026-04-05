# Tooling Generation Skill — AI Infrastructure & CI/CD

You are executing Phase 3a of Forge: generating AI tooling infrastructure, CI/CD pipelines, and auto-evolution hooks. This phase is mostly automated from Phase 1 context, with minimal developer interaction.

## Purpose

Equip the scaffolded project with Claude Code tooling (via onboard headless), GitHub Actions CI/CD pipelines, and auto-evolution hooks that keep tooling in sync with the codebase.

## Inputs

You receive:
1. The complete Phase 1 context object
2. The scaffolded project (Phase 2 output)
3. The `.claude/forge-meta.json` metadata file

## Step 1: Prepare Onboard Context

Map the Phase 1 context to onboard's expected format. The context JSON must include:

```json
{
  "source": "forge",
  "version": "1.0.0",
  "projectPath": "[absolute path]",
  "analysis": {
    "structure": {},
    "stack": {},
    "complexity": {},
    "configs": {}
  },
  "wizardAnswers": {},
  "modelChoice": "sonnet",
  "ecosystemPlugins": {},
  "callerExtras": {}
}
```

### Building the analysis object

Run a lightweight scan of the scaffolded project to populate the analysis:
- Count files and directories
- Read generated config files (tsconfig, eslint, prettier)
- Detect the project structure and entry points
- Calculate a basic complexity score

This is NOT a full codebase analysis — the project was just scaffolded, so it's small. Just enough for onboard to generate accurate tooling.

### Mapping wizard answers

Map Phase 1 context fields to onboard's wizard answer format:

| Forge field | Onboard field |
|---|---|
| `appDescription` | `projectDescription` |
| `teamSize` | `teamSize` |
| `testingPhilosophy` | `testingPhilosophy` |
| `codeStyleStrictness` | `codeStyleStrictness` |
| `securitySensitivity` | `securitySensitivity` |
| `autonomyLevel` | `autonomyLevel` |
| `branchingStrategy` | `branchingStrategy` |
| `deployTarget` → frequency | `deployFrequency` |

Fields not directly mappable are passed through in `callerExtras`.

## Step 2: Invoke Onboard Headless

Call `/onboard:generate` with the prepared context. Onboard generates:
- Root CLAUDE.md
- Subdirectory CLAUDE.md files (if applicable)
- Path-scoped rules (`.claude/rules/*.md`)
- Skills (`.claude/skills/*/SKILL.md`)
- Agents (`.claude/agents/*.md`)
- PostToolUse hooks (format, lint)
- PR template
- `onboard-meta.json`

After generation, present a brief summary to the developer:

> Onboard generated your AI tooling:
> - CLAUDE.md ([N] lines)
> - [N] rules: [names]
> - [N] skills: [names]
> - [N] agents: [names]
> - Format + lint hooks configured
>
> Quick review — anything you want to adjust before I continue?

Options: **Continue** | **Let me review CLAUDE.md first** | **Adjust**

If the developer wants to review or adjust, accommodate their changes before proceeding.

## Step 3: Generate CI/CD Pipelines

**Skip entirely if `willDeploy === false`.**

Generate GitHub Actions workflows based on Phase 1 context. See `references/ci-cd-templates.md` for patterns.

### Pipeline 1: Application CI (`.github/workflows/ci.yml`)
- **Trigger**: push to main, PR to main (adjust for branching strategy)
- **Jobs**: lint, test, build (parallel where possible), deploy (conditional on main)
- **Stack-aware**: use the correct commands from the scaffold (npm test, pytest, go test, etc.)

### Pipeline 2: Tooling Audit (`.github/workflows/tooling-audit.yml`)
- **Trigger**: push to main (paths: package.json, configs, src/**), weekly schedule, manual
- **Layer 1**: Structural checks via bundled shell script (`.github/scripts/audit-tooling.sh`)
- **Layer 2**: Semantic analysis via `anthropics/claude-code-action@v1` (only if drift detected)
- **Action**: configurable from Phase 1 (`ciAuditAction`): auto-fix PR / comment / issue

### Pipeline 3: PR Review (`.github/workflows/pr-review.yml`)
- **Trigger**: configurable from Phase 1 (`prReviewTrigger`)
- **Uses**: `anthropics/claude-code-action@v1`
- **Reviews against**: CLAUDE.md + `.claude/rules/`

Also generate:
- `.github/scripts/audit-tooling.sh` — Copy from Forge's `scripts/audit-tooling.sh`
- `.github/dependabot.yml` or `renovate.json` (if `depManagement` ≠ "manual")

## Step 4: Add Auto-Evolution Hooks

Based on `autoEvolutionMode` from Phase 1:

### If "auto-update":
- FileChanged hooks that directly update CLAUDE.md and rules when config/deps/structure change
- SessionStart hook that summarizes changes since last session

### If "manual" (default):
- FileChanged hooks that log changes to `.claude/forge-drift.json`
- SessionStart hook that summarizes drift and suggests running `/forge:evolve`
- The evolve skill handles actual updates

### If "notify-only":
- FileChanged hooks that log to drift file
- SessionStart hook that shows drift summary (no evolve skill)

**Hook scripts to copy into the project:**
- `.claude/scripts/detect-dep-changes.sh` — from Forge's `scripts/detect-dep-changes.sh`
- `.claude/scripts/detect-config-changes.sh` — from Forge's `scripts/detect-config-changes.sh`
- `.claude/scripts/detect-structure-changes.sh` — from Forge's `scripts/detect-structure-changes.sh`

**Merge into `.claude/settings.json`**: Read existing file first (onboard may have already written hooks). Add Forge's hooks alongside, never overwrite.

## Step 5: Update Forge Metadata

Update `.claude/forge-meta.json` with:
- `generated.tooling`: list of all tooling files created
- `generated.cicd`: list of CI/CD workflow files
- `generated.hooks`: list of hook scripts and settings entries

## Key Rules

1. **Onboard generates Claude tooling, Forge generates CI/CD** — Clear responsibility boundary.
2. **Merge, never overwrite** — settings.json is touched by both onboard and Forge. Always read first.
3. **Skip CI/CD for local projects** — If `willDeploy === false`, do not generate any GitHub Actions workflows.
4. **Light confirmation after onboard** — Show what was generated, let developer review if they want.
5. **Copy scripts, don't reference** — Hook and audit scripts are copied into the project (self-contained).
