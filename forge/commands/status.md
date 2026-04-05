# /forge:status — Project Health Check

You are running the Forge status command. This provides a quick overview of the project's AI tooling health, pending drift, and setup metadata.

---

## Step 1: Check for Setup

Read `.claude/forge-meta.json`:

**If not found**:

> This project hasn't been set up with Forge yet.
>
> Run `/forge:init` to scaffold a new project with AI-native tooling.

Stop here.

---

## Step 2: Parse Metadata

Extract from `forge-meta.json`:
- `version` — Forge version used
- `createdAt` — When the project was scaffolded
- `context.stack` — Tech stack details
- `context.deployTarget` — Deployment target
- `context.branchingStrategy` — Git branching strategy
- `context.autoEvolutionMode` — How tooling updates work
- `generated.tooling` — List of generated tooling files
- `generated.cicd` — List of CI/CD workflows
- `webResearch.stackVersion` — Framework version at scaffold time

---

## Step 3: Check Artifact Integrity

Verify all generated artifacts still exist and are non-empty:

1. **CLAUDE.md** — exists, non-empty, contains maintenance header
2. **Path-scoped rules** — each `.claude/rules/*.md` file exists
3. **Skills** — each `.claude/skills/*/SKILL.md` file exists
4. **Agents** — each `.claude/agents/*.md` file exists
5. **Hooks** — `.claude/settings.json` exists, contains expected hook entries
6. **CI/CD** — `.github/workflows/*.yml` files exist (if deploying)
7. **Audit scripts** — `.github/scripts/audit-tooling.sh` exists (if deploying)
8. **Drift scripts** — `.claude/scripts/detect-*.sh` files exist

Report any missing or empty files.

---

## Step 4: Check Pending Drift

Read `.claude/forge-drift.json`:

- If entries exist: report count and categories (dependencies, configs, structure)
- If no entries or file missing: report "No pending drift"

---

## Step 5: Check Stack Freshness

Compare `webResearch.stackVersion` from metadata against current `package.json` (or equivalent manifest):
- If the framework version has been bumped since scaffold, note it
- If a major version change occurred, recommend re-running web research

---

## Step 6: Present Summary

> **Forge Status**
>
> **Project**: [appDescription]
> **Stack**: [framework] v[version] (scaffolded [date])
> **Deploy**: [target] | **Branching**: [strategy]
> **Auto-evolution**: [mode]
>
> **Tooling Health**
> | Artifact | Status |
> |---|---|
> | CLAUDE.md | [ok / missing / empty] |
> | Rules ([N]) | [ok / N missing] |
> | Skills ([N]) | [ok / N missing] |
> | Agents ([N]) | [ok / N missing] |
> | Hooks | [ok / missing entries] |
> | CI/CD | [ok / N/A (local project)] |
>
> **Pending Drift**: [N entries] or "None"
> [If drift exists]: Run `/forge:evolve` to apply updates.
>
> **Installed Plugins**: [list from metadata]
