# /forge:init — Scaffold a New Project with AI-Native Tooling

You are running the Forge initialization wizard. This is a guided, 4-phase process that discusses what the developer wants to build, scaffolds the application, equips it with auto-evolving Claude Code tooling, and optionally generates engineering lifecycle documents.

## Guard

Before starting, verify the onboard plugin is installed. Check if `/onboard:generate` is available by looking for the onboard plugin in installed plugins.

If onboard is not installed:

> Forge requires the **onboard** plugin for AI tooling generation.
>
> Install it with: `claude plugin install onboard`
>
> Then run `/forge:init` again.

Stop and do not proceed.

---

## Overview

Tell the developer:

> Starting **Forge** — I'll help you create a new project from scratch with AI-native tooling built in from day one.
>
> This runs in 4 phases:
> 1. **Context Gathering** — We'll discuss what you want to build, your tech stack, and preferences
> 2. **Scaffold** — I'll create the application and set up git
> 3. **AI Tooling** — I'll generate Claude tooling, CI/CD pipelines, and auto-evolution hooks
> 4. **Lifecycle Setup** — I'll generate engineering documents (ADRs, testing strategy, deploy checklists) using your project context
>
> By the end, you'll have a running app with world-class AI tooling and engineering documents that evolve alongside your code.

---

## Phase 1: Context Gathering

Use the `context-gathering` skill to guide the developer through the adaptive wizard.

The skill handles:
- Project vision (what they want to build)
- Tech stack discussion + web research via the `stack-researcher` agent
- Project details (database, auth, deploy, monitoring, etc.)
- Workflow preferences (testing, style, security, autonomy)
- CI/CD and auto-evolution preferences
- Confirmation summary

**Key reminders:**
- One question at a time — don't overwhelm
- Spawn the `stack-researcher` agent after learning the tech stack
- Skip questions that don't apply (the skill's question bank has conditions)
- Present recommendations with reasoning, especially for stack and deploy choices
- Get explicit confirmation before moving to Phase 2

After the wizard completes, you have the full context object.

---

## Phase 2: Scaffold

Use the `scaffolding` skill to create the application.

The skill handles:
- Pre-scaffold validation (empty dir, CLIs installed, git ready)
- Executing the scaffold (CLI tool, from scratch, or template — per Phase 1 decision)
- Post-scaffold additions (.env, Docker, monorepo config, i18n, etc.)
- Git setup (init, branches, remote, branch protection)
- Hello World verification (start dev server, confirm it works)
- Saving `.claude/forge-meta.json`

Inform the developer:

> Scaffolding your project... This will create the application, set up git, and verify everything runs.

After scaffolding completes, confirm:

> Your app is scaffolded and running. [Dev server verified at localhost:PORT]
> Git initialized with [branching strategy].
> Moving to AI tooling setup...

---

## Phase 3: AI Tooling

### Step 3.1: Plugin Discovery (MUST run first)

Use the `plugin-discovery` skill which:
- Matches curated catalog against project context
- Presents an interactive checklist of recommended plugins
- Optionally searches the web for additional plugins
- Installs selected plugins
- **Compiles `coveredCapabilities`** — the list of capabilities covered by installed plugins

This step MUST complete before Step 3.2 because onboard needs `coveredCapabilities` to avoid generating agents that shadow installed plugins. The plugin-discovery skill returns both `installedPlugins` and `coveredCapabilities` for use in the next step.

### Step 3.2: Generate Claude Tooling

Use the `tooling-generation` skill, passing it the `installedPlugins` and `coveredCapabilities` from Step 3.1. The skill:
- Spawns the `scaffold-analyzer` agent to scan the scaffolded project
- Maps Phase 1 context + analysis + `coveredCapabilities` to onboard's format
- Invokes `/onboard:generate` (headless) for CLAUDE.md, rules, skills, agents, hooks
- Onboard skips agents for capabilities already covered by installed plugins
- Presents a brief summary for optional developer review

### Step 3.3: Generate CI/CD Pipelines

The tooling-generation skill also handles:
- Application CI pipeline (lint → test → build → deploy)
- Tooling audit pipeline (structural checks + semantic analysis)
- PR review pipeline (claude-code-action)
- Dependency management (Dependabot/Renovate)
- Auto-evolution hooks (FileChanged + SessionStart)
- Agent team quality hooks (if production team project)

**Skip CI/CD entirely if the developer chose not to deploy.**

### Step 3.4: Update CLAUDE.md with Plugin References

After all generation is complete, update the project's CLAUDE.md with:
- Installed plugins section (what's available, key commands)
- Agent team guide section (if team hooks were generated)

---

## Phase 4: Lifecycle Setup (Optional)

Use the `lifecycle-setup` skill, passing it the full Phase 1 context, Phase 2 scaffold metadata, and Phase 3 installed plugins list.

The skill handles:
- Checking if the `engineering` plugin is installed (graceful skip if not)
- Presenting a context-aware checklist of engineering documents to generate
- Invoking `engineering:*` skills with composed context arguments
- Saving outputs to `docs/engineering/`
- Updating CLAUDE.md with an Engineering Documents section
- Updating `forge-meta.json` with lifecycle document metadata

Phase 4 is entirely optional. If the engineering plugin is not installed and the developer declines to install it, or if the developer deselects all documents, skip directly to Handoff.

Inform the developer before starting:

> **Phase 4: Lifecycle Setup** — I can generate engineering documents (ADRs, testing strategy, deploy checklists) using the project context we gathered earlier. This uses the `engineering` plugin.

---

## Handoff

After all phases complete, present the completion summary:

> **Forge complete!**
>
> **Project**
> - [app name] scaffolded with [framework version]
> - Dev server verified at http://localhost:[port]
> - Git: [branching strategy], pushed to [remote or "local only"]
>
> **AI Tooling**
> - CLAUDE.md ([N] lines)
> - [N] path-scoped rules
> - [N] skills, [N] agents
> - [N] hooks (format, lint, drift detection)
>
> **CI/CD** [if applicable]
> - Application pipeline (ci.yml)
> - Tooling audit pipeline (tooling-audit.yml)
> - PR review pipeline (pr-review.yml)
>
> **Plugins Installed**
> - [list installed plugins with key commands]
>
> **Engineering Documents** [if any generated in Phase 4]
> - [list each generated document with path, e.g., "docs/engineering/adr-001-tech-stack.md — Architecture Decision Record"]
>
> **Development Harness**
> - `init.sh` — run at the start of every session to bootstrap your environment
> - `docs/feature-list.json` — [N] features across [N] sprints (all starting as failing)
> - `docs/progress.md` — cross-session progress tracker
> - `docs/sprint-contracts/sprint-1.json` — Sprint 1 completion criteria (negotiated)
> - Session startup protocol + worktree workflow in CLAUDE.md
>
> **What to do next:**
> 1. Review CLAUDE.md and engineering documents in `docs/engineering/` — they capture your project's architectural decisions and strategies
> 2. Start your next session: `bash init.sh` → read progress → pick a feature from Sprint 1
> 3. Use worktrees for isolation: `git worktree add ../project-feat-F001 -b feat/F001-[name]`
> 4. After implementing a feature, run `/forge:verify F001` for independent evaluation
> 5. When Sprint 1 features are done, run `/forge:verify --sprint 1` to check the sprint contract
> 6. Your tooling evolves — [auto-updates / run /forge:evolve when notified] to keep AI tooling current
> 7. Check health — run `/forge:status` anytime to verify tooling is in sync

---

## Error Handling

If any phase fails:
- **Phase 1 failure**: Unlikely (it's conversational). If the developer abandons, stop gracefully.
- **Phase 2 failure**: Leave partial files, show the error, diagnose, offer retry or alternative approach. Record failure in forge-meta.json.
- **Phase 3 failure**: If onboard headless fails, report the error. CI/CD and hooks can still be generated independently. Continue with what works.
- **Phase 4 failure**: If the engineering plugin is not installed, skip Phase 4 gracefully. If individual document generation fails, report the error and continue with remaining documents. Phase 4 failures never block Handoff.

Never auto-clean partial state. The developer should be able to inspect what happened.
