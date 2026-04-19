# forge

> Part of [`claude-plugins`](../README.md) — see also [`onboard`](../onboard/) (required dependency) and [`notify`](../notify/) (optional add-on).

Stack-agnostic greenfield scaffolder for Claude Code. Researches your stack via WebSearch, scaffolds the app, then **delegates** all Claude tooling generation to `onboard`. Built to compose, not to reinvent.

The defining design choice: forge is a **thin orchestrator**. Tooling generation lives in `onboard`. forge calls it via the `Skill` tool (`/onboard:generate`) and adds only what requires scaffold-specific knowledge — `init.sh`, `docs/feature-list.json`, and the wizard-driven context that onboard needs.

## Install

```bash
claude plugin install forge@apurvbazari-plugins
```

`forge` requires the `onboard` plugin for Phase 3 — install it with `claude plugin install onboard@apurvbazari-plugins`. Optionally also install [`notify`](../notify/) so long scaffold sessions notify you when they finish.

## Skills

All skills are invoked with the `/forge:<name>` slash syntax.

### `/forge:init` *(destructive — user-invoked only)*

Main entry point. Runs the full 3-phase guided workflow, with checkpoints written to `.claude/forge-state.json` after every step so the workflow is interruption-safe. Detects an in-flight session at startup and offers `/forge:resume` instead of restarting.

### `/forge:resume`

Resume an in-progress session from the last checkpoint. Reads `.claude/forge-state.json`, shows you where you left off (which phase, which step, what's next), and picks up from that point. Works across fresh Claude Code sessions — close your laptop mid-wizard and come back days later.

### `/forge:status`

Project health check. If a session is in-flight, reports the state (phase, step, next action). If setup is complete, reports artifact integrity: CLAUDE.md, rules, skills, agents, hooks, CI/CD workflows, pending drift, and stack freshness vs when the project was scaffolded.

> `/forge:evolve` and `/forge:verify` no longer exist — they live in `onboard` as `/onboard:evolve` and `/onboard:verify` (universal, not forge-specific).

## The 3 phases

```
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ 1. Context       │ →  │ 2. Scaffold      │ →  │ 3. AI Tooling    │
│                  │    │                  │    │                  │
│ Adaptive wizard  │    │ Stack-specific   │    │ Plugin discovery │
│ Stack research   │    │ scaffold + git   │    │ /onboard:generate│
│ Pain points      │    │ Hello-world ver. │    │ CI/CD + hooks    │
└──────────────────┘    └──────────────────┘    └──────────────────┘
```

### Phase 1 — Context Gathering

An adaptive 8-step wizard. Questions adapt to prior answers — a CLI tool dev answers ~10 questions, a full-stack production team answers ~20. Highlights:

- **Step indicator** — every step emits `Step X of 8 — [name]` so long sessions don't silently derail.
- **Stack research** — the [`stack-researcher`](./agents/stack-researcher.md) agent uses WebSearch + WebFetch for current versions, official scaffolders, and idiomatic patterns. No pre-built templates.
- **Deep Research Park** — when a question triggers research that would take more than a few minutes ("which on-device LLM tier for a mobile app?"), the wizard offers three options: **Park it** (placeholder, continue, deep-dive later), **Deep-dive now** (pause), or **Take a default**.
- **Sub-agent fallback** — if the web-research sub-agent's permission sandbox blocks web tools, falls back to main-session research with user-approved WebFetch calls; degrades to training-data-only mode with an explicit warning.
- **Feature decomposition is mandatory** — produces at least a skeletal `docs/feature-list.json` because downstream phases depend on it.
- **Phase 1.5 sub-phase** (conditional) — if any questions were parked during Phase 1, runs a focused architectural-research pass before Phase 2. Skipped entirely if nothing was parked.

### Phase 2 — Scaffold

Executes the chosen scaffold approach, adds project infrastructure (`.env`, Docker, i18n…), sets up git with the chosen branching strategy, and verifies the app runs.

**Four scaffold paths:**

- **A — External CLI** — runs `create-next-app`, `npm create vite`, `uv init`, `cargo new`, etc. Default for stacks with a mature CLI.
- **B — From scratch** — writes config + layout files following research-informed defaults. Used when no CLI exists.
- **C — Developer's template** — clone a user-specified template or boilerplate.
- **D — Walking skeleton** — scaffolds *one representative example of each architectural pattern* (one entity, one DAO, one service, one route, one test). Phase 3 then runs against the skeleton and Phase 2b expands it under the AI tooling's guidance. Recommended for native mobile, custom backends, game engines.

**Sibling project detection** — before scaffolding, forge scans the parent directory for existing projects in the same stack family and offers to anchor versions to them. Invaluable when you have multiple related projects.

### Phase 3 — AI Tooling

The composability beat. forge does **not** generate Claude tooling itself — it prepares context and calls onboard:

```
plugin-discovery skill   →   curated catalog match + web search → install plugins
                              compiles coveredCapabilities

tooling-generation skill →   Skill(onboard:generate) (enriched mode)
                              ├── Core:     CLAUDE.md, rules, skills, agents, hooks
                              └── Enriched: CI/CD, harness, evolution, teams, verification

forge-only artifacts     →   init.sh (stack-specific bootstrap)
                              docs/feature-list.json (from Phase 1 decomposition)
```

In walking-skeleton mode (Path D from Phase 2), Phase 3 runs against the skeleton, and **Phase 2b** then expands the scaffold under the rules onboard wrote.

## Example

A FastAPI scaffold from start to finish:

```
> /forge:init

Phase 1: Context Gathering — Step 1 of 8
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
What do you want to build?

> A REST API for a task management app with user auth and team workspaces

Step 2 of 8 — Tech Stack
Researching via web: "FastAPI 2026 best practices project structure" …

  Recommended stack:
    Runtime    Python 3.13
    Framework  FastAPI + Pydantic v2
    Database   PostgreSQL + SQLAlchemy 2.0
    Auth       JWT via python-jose
    Testing    pytest + httpx (async)

  Does this look right, or would you like to adjust?

> Looks good

Step 5 of 8 — Testing philosophy?

> TDD

Phase 2: Scaffold
━━━━━━━━━━━━━━━━━
Scaffolding with `uv init` + FastAPI project layout …
Creating directory structure …
Installing dependencies …
Writing hello-world endpoint …

Verifying: uvicorn running on http://localhost:8000 ✓
GET /health returns 200 ✓

Phase 3: AI Tooling
━━━━━━━━━━━━━━━━━━━
Plugin discovery — recommended for your project:
  [x] superpowers           (TDD, debugging, planning)
  [x] commit-commands       (git workflow)
  [x] security-guidance     (API security hooks)
  [x] notify                (task completion notifications)
  [ ] playwright            (no frontend detected)

Installing 4 plugins …

Calling /onboard:generate (enriched) …
Generated CLAUDE.md, 4 rules, 2 skills, 1 agent, 3 hooks
Setting up CI/CD:
  .github/workflows/ci.yml             pytest + ruff
  .github/workflows/tooling-audit.yml  weekly drift check
  .github/workflows/pr-review.yml      AI-powered PR review

Done! Your project is ready at ./task-manager/
Next: cd task-manager && /feature-dev Add user registration
```

## Resumability

Forge's workflow can take significant time — especially the wizard (Phase 1) and AI tooling generation (Phase 3). If the session is interrupted (session ends, laptop closes, Ctrl-C, crash), nothing is lost.

**How it works:**

- Every skill writes `.claude/forge-state.json` after each natural checkpoint (each wizard step, each scaffold sub-step, each Phase 3 action).
- Writes are atomic (`.tmp` + rename) to avoid corruption if killed mid-write.
- The state file tracks current phase, current step, completed steps, accumulated context, research findings, and parked questions.
- `/forge:init` checks for an existing state file at startup and offers resume instead of silently restarting.
- `/forge:resume` reads the state and fast-forwards the appropriate skill to exactly where you left off.
- `/forge:status` prominently reports in-flight sessions so you know they exist.

**Cross-session resume** works in a completely fresh Claude Code conversation — the state file is the source of truth; memory files and research findings carry the context.

## Auto-Evolution

After forge sets up your project, hooks keep tooling in sync. **These hooks are written by `onboard` during Phase 3** — forge doesn't manage drift directly; it just ensures onboard's enriched mode is enabled so the hooks ship with the scaffold:

- **FileChanged hooks** — detect changes to `package.json`, config files, project structure
- Drift logged to `.claude/forge-drift.json`
- **SessionStart hook** — summarises drift at the start of each Claude session
- Apply updates with `/onboard:evolve` (or configure auto-updates during setup) — see [`onboard/README.md`](../onboard/README.md#drift-detection-deep-dive) for the full mechanism
- **Weekly CI audit** — catches drift that local hooks miss

## Supported stacks

forge is stack-agnostic in principle — the [`stack-researcher`](./agents/stack-researcher.md) agent investigates whatever stack you describe rather than relying on built-in templates. But some stacks are verified end-to-end, others are known to work, others are experimental:

### Verified (tested end-to-end)

- **Next.js (App Router)** — TypeScript, Tailwind, Prisma, NextAuth
- **Python FastAPI** — Pydantic, SQLAlchemy, pytest
- **Go HTTP services** — chi/gin routers, standard layout

### Known to work (community-reported)

React (Vite), Vue, Svelte · Express, NestJS · Rust (Axum, Actix) · Ruby on Rails · Monorepos (Turborepo, Nx, pnpm workspaces)

### Experimental — walking-skeleton mode recommended

These lack a mature scaffold CLI or have significantly different architecture from web/server projects:

- **Android native** (Kotlin + Compose + Hilt + Room) — no `create-*` CLI; walking skeleton with sibling-project anchoring
- **iOS native** (Swift + SwiftUI) — similar pattern; SPM setup
- **Desktop** (Tauri, Electron) — partial CLI coverage
- **Game engines** (Unity, Godot, Bevy) — architecture is framework-specific
- **Custom backends** without an obvious scaffold tool

If your stack isn't listed, forge will still try. Use `scaffoldMode: walking-skeleton` if you're unsure — it produces a minimal representative project the AI tooling can analyse, rather than guessing at a full scaffold and getting it wrong.

## Prerequisites

- **`onboard`** plugin (required) — forge delegates all Claude tooling generation to onboard's headless `/onboard:generate`
- **git** — repository setup and branching
- **`gh`** (GitHub CLI) — branch protection and CI/CD setup (optional if you're not using GitHub)
- Bash ≥ 4 — all forge scripts

## Internals

For internal architecture, agent contracts, state-machine details, and anti-patterns, see [`forge/CLAUDE.md`](./CLAUDE.md).

## License

[MIT](../LICENSE)
