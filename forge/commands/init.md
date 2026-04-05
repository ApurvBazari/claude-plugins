# /forge:init — Scaffold a New Project with AI-Native Tooling

You are running the Forge initialization wizard. This is a guided, 3-phase process that discusses what the developer wants to build, scaffolds the application, and equips it with auto-evolving Claude Code tooling.

## Overview

Tell the developer:

> Starting **Forge** — I'll help you create a new project from scratch with AI-native tooling built in from day one.
>
> This runs in 3 phases:
> 1. **Context Gathering** — We'll discuss what you want to build, your tech stack, and preferences
> 2. **Scaffold** — I'll create the application and set up git
> 3. **AI Tooling** — I'll generate Claude tooling, CI/CD pipelines, and auto-evolution hooks
>
> By the end, you'll have a running app with world-class AI tooling that evolves alongside your code.

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

### Step 3.1: Generate Claude Tooling

Use the `tooling-generation` skill which:
- Maps Phase 1 context to onboard's format
- Invokes `/onboard:generate` (headless) for CLAUDE.md, rules, skills, agents, hooks
- Presents a brief summary for optional developer review

### Step 3.2: Generate CI/CD Pipelines

The tooling-generation skill also handles:
- Application CI pipeline (lint → test → build → deploy)
- Tooling audit pipeline (structural checks + semantic analysis)
- PR review pipeline (claude-code-action)
- Dependency management (Dependabot/Renovate)
- Auto-evolution hooks (FileChanged + SessionStart)

**Skip CI/CD entirely if the developer chose not to deploy.**

### Step 3.3: Plugin Discovery

Use the `plugin-discovery` skill which:
- Matches curated catalog against project context
- Presents an interactive checklist of recommended plugins
- Optionally searches the web for additional plugins
- Installs selected plugins
- Updates CLAUDE.md with plugin references

---

## Handoff

After all three phases complete, present the completion summary:

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
> **What to do next:**
> 1. Review CLAUDE.md — it's the source of truth for how Claude understands your project
> 2. Start building — describe what you want to add, or use /feature-dev for guided development
> 3. Your tooling evolves — [auto-updates / run /forge:evolve when notified] to keep tooling current
> 4. Check health — run /forge:status anytime to verify tooling is in sync

---

## Error Handling

If any phase fails:
- **Phase 1 failure**: Unlikely (it's conversational). If the developer abandons, stop gracefully.
- **Phase 2 failure**: Leave partial files, show the error, diagnose, offer retry or alternative approach. Record failure in forge-meta.json.
- **Phase 3 failure**: If onboard headless fails, report the error. CI/CD and hooks can still be generated independently. Continue with what works.

Never auto-clean partial state. The developer should be able to inspect what happened.
