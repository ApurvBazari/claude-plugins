# forge

Scaffold new projects with AI-native tooling that evolves with your code.

## What It Does

Forge is a guided project bootstrapper for Claude Code. It takes you from "I want to build X" to a running application with auto-evolving AI tooling — in one conversation.

Think of it as `create-react-app` for the AI-assisted development era: it scaffolds your app, sets up Claude Code tooling, configures CI/CD pipelines, installs ecosystem plugins, and optionally generates engineering lifecycle documents (ADRs, testing strategies, deploy checklists). The tooling it generates doesn't just sit there — it detects changes in your codebase and evolves alongside your code.

### What Gets Created

- **A running application** — Scaffolded with your chosen tech stack, verified with Hello World
- **Claude Code tooling** — CLAUDE.md, path-scoped rules, skills, agents, hooks (via onboard)
- **CI/CD pipelines** — GitHub Actions for testing, deployment, AI-powered PR review, and tooling audit
- **Auto-evolution hooks** — Detect dependency, config, and structural changes; keep tooling in sync
- **Ecosystem plugins** — Curated recommendations installed based on your stack and workflow
- **Engineering documents** — Architecture Decision Records, testing strategies, deploy checklists, runbooks (via `engineering` plugin)

## Commands

### `/forge:init`

Main entry point. Runs a guided workflow with 4 main phases (plus a resume check and two optional sub-phases):

0. **Resume check** — If a forge session is already in progress in this directory (detected via `.claude/forge-state.json`), offer to resume instead of restarting.
1. **Context Gathering** — Adaptive 8-step wizard that discusses your app idea, researches your tech stack via web search, and captures all preferences (testing, security, CI/CD behavior, etc.). Emits a `Step X of 8` progress indicator at every step, supports a "Park it" escape hatch when a question triggers deep research, and makes feature decomposition mandatory.
2. (**1.5. Architectural Research** — optional; runs only if questions were parked during Phase 1, deep-dives on them before scaffolding)
3. **Scaffold** — Creates the application using the chosen approach: official CLI, from scratch, your template, or a **walking skeleton** (one representative example of each architectural pattern, for stacks without a mature CLI or with complex architecture). Detects sibling projects in the parent directory and offers to anchor versions to them.
4. (**2b. Expand Scaffold** — only in walking-skeleton mode; runs after Phase 3 AI tooling to expand the skeleton under the guidance of generated rules)
5. **AI Tooling** — Invokes onboard headless for Claude tooling, generates GitHub Actions pipelines, adds auto-evolution hooks, discovers and installs ecosystem plugins
6. **Lifecycle Setup** (optional) — Generates engineering documents (ADRs, testing strategy, deploy checklists, system design, runbooks) using the `engineering` plugin with Phase 1 context

Every phase writes checkpoints to `.claude/forge-state.json` so the whole workflow is interruption-safe. See [Resumability](#resumability) below.

### `/forge:resume`

Resume an in-progress Forge session from the last checkpoint. Reads `.claude/forge-state.json`, shows you where you left off (which phase, which step, what's next), and picks up exactly from that point. Works across fresh Claude Code sessions — you can close your laptop mid-wizard and come back days later.

### `/forge:status`

Project health check. If a Forge session is in progress, reports the in-flight state (phase, step, next action). If setup is complete, reports artifact integrity: CLAUDE.md, rules, skills, agents, hooks, CI/CD workflows, pending drift, and stack freshness relative to when the project was scaffolded.

> **Note**: `/forge:evolve` and `/forge:verify` have been moved to `onboard` — use `/onboard:evolve` and `/onboard:verify` respectively. They apply to all projects, not just forge-scaffolded ones.

## Installation

```bash
# From the marketplace
claude plugin install forge

# Or from a local path (for development)
claude plugin add /path/to/forge
```

## Prerequisites

- **Claude Code** with the **onboard** plugin installed (forge delegates tooling generation to onboard)
- **git** — required for repository setup and branching
- **gh** (GitHub CLI) — required for branch protection and CI/CD setup (optional if not using GitHub)
- **engineering** plugin (optional) — enables Phase 4 lifecycle document generation (ADRs, testing strategy, deploy checklists, system designs, runbooks, incident playbooks). Install from the `knowledge-work-plugins` marketplace:

  ```bash
  claude marketplace add knowledge-work-plugins
  claude plugin install engineering
  ```

  If you skip this, Phase 4 is gracefully skipped and you can install engineering later and run its skills directly on the project.

## How It Works

### Phase 1: Context Gathering

An adaptive 8-step wizard asks about your project one question at a time. Questions adapt based on prior answers — a CLI tool developer answers ~10 questions, while a full-stack production team answers ~20.

**Features that keep long sessions from derailing:**

- **Progress indicator** — every step emits a `Step X of 8 — [name]` banner so you can see exactly how much is left
- **Deep Research Park** — if a question triggers research that would take more than a few minutes (e.g., "which on-device LLM tier for a mobile app?"), the wizard offers three options: **Park it** (capture a placeholder, continue the wizard, deep-dive later), **Deep-dive now** (pause the wizard), or **Take a default**
- **Sub-agent fallback** — the web-research sub-agent has a permission sandbox that sometimes blocks web tools. The wizard detects this, falls back to main-session research with user-approved WebFetch calls, or degrades to training-data-only mode with an explicit warning
- **Feature decomposition is mandatory** — the wizard always produces at least a skeletal `docs/feature-list.json` because downstream phases depend on it

**Phase 1.5: Architectural Research (conditional)** — if any questions were parked during Phase 1, a dedicated sub-phase runs before scaffolding to resolve them with full attention. Skipped entirely if nothing was parked.

### Phase 2: Scaffold

Executes the agreed scaffold approach, adds project infrastructure (.env, Docker, i18n, etc.), sets up git with your chosen branching strategy, and verifies the app runs.

**Four scaffold paths** based on stack and preference:

- **Path A: External CLI** — runs `create-next-app`, `npm create vite`, `uv init`, `cargo new`, etc. Default for stacks with a mature CLI.
- **Path B: From scratch** — writes config + layout files following research-informed defaults. Used when no CLI exists.
- **Path C: Developer's template** — clone a user-specified template or boilerplate.
- **Path D: Walking skeleton** — scaffolds **one representative example of each architectural pattern** (one entity, one DAO, one service, one route, one test), enough for AI tooling to derive project-specific rules from. Then Phase 3 runs against the skeleton, then Phase 2b expands it under AI-tooling guidance. Recommended for native mobile (Android/iOS), custom backends, game engines, and other complex architectures.

**Sibling project detection** — before scaffolding, Forge scans the parent directory for existing projects in the same stack family and offers to anchor versions to them. This is invaluable when you have multiple related projects and want consistency.

### Phase 3: AI Tooling

- **Claude tooling** via onboard headless — CLAUDE.md, rules, skills, agents, hooks
- **CI/CD pipelines** — Application CI, tooling audit (detects drift), AI PR review
- **Auto-evolution hooks** — FileChanged hooks log drift, SessionStart summarizes changes
- **Plugin discovery** — Curated + web-searched recommendations, interactive selection

In walking-skeleton mode (Path D from Phase 2), this phase runs against the walking skeleton. Its output (CLAUDE.md, rules, hooks) then guides Phase 2b's expansion of the scaffold.

### Phase 4: Lifecycle Setup (Optional)

If the `engineering` plugin is installed, Forge presents a context-aware checklist of engineering documents to generate — Architecture Decision Records, testing strategies, deploy checklists, system design docs, runbooks, and incident playbooks. Each document is generated by invoking the corresponding `engineering:*` skill with context composed from Phase 1. Documents are saved to `docs/engineering/` and referenced in CLAUDE.md.

## Example

Running `/forge:init` to scaffold a new FastAPI project:

```
> /forge:init

Phase 1: Context Gathering — Step 1 of 8
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Claude: What do you want to build?

You: A REST API for a task management app with user auth and team workspaces

Claude: Step 2 of 8 — Tech Stack
        Based on your description, I'm researching Python + FastAPI...

        [Researching via web: "FastAPI 2026 best practices project structure"]

        Recommended stack:
          Runtime:    Python 3.13
          Framework:  FastAPI + Pydantic v2
          Database:   PostgreSQL + SQLAlchemy 2.0
          Auth:       JWT via python-jose
          Testing:    pytest + httpx (async)

        Does this look right, or would you like to adjust?

You: Looks good, let's go with it

Claude: Step 5 of 8 — Testing
        What's your testing philosophy?

You: TDD

Phase 2: Scaffold
━━━━━━━━━━━━━━━━━
Claude: Scaffolding with uv init + FastAPI project layout...
        Creating directory structure...
        Installing dependencies...
        Writing hello-world endpoint...

        Verifying: uvicorn running on http://localhost:8000 ✓
        GET /health returns 200 ✓

Phase 3: AI Tooling
━━━━━━━━━━━━━━━━━━━
Claude: Generating Claude tooling via onboard...
        Generated CLAUDE.md, 4 rules, 2 skills, 1 agent, 3 hooks

        Plugin discovery — recommended for your project:
        [x] superpowers (TDD, debugging, planning)
        [x] commit-commands (git workflow)
        [x] security-guidance (API security hooks)
        [x] notify (task completion notifications)
        [ ] playwright (no frontend detected)

        Installing 4 plugins...

        Setting up CI/CD:
          .github/workflows/ci.yml          — pytest + ruff
          .github/workflows/tooling-audit.yml — weekly drift check
          .github/workflows/pr-review.yml    — AI-powered PR review

Phase 4: Lifecycle Setup
━━━━━━━━━━━━━━━━━━━━━━━━
Claude: Engineering plugin detected. Generate documents?
        [x] Architecture Decision Record
        [x] Testing Strategy
        [ ] Deploy Checklist (skip for now)

        Generated:
          docs/engineering/adr-001-fastapi-sqlalchemy.md
          docs/engineering/testing-strategy.md

Done! Your project is ready at ./task-manager/
Next: cd task-manager && /feature-dev Add user registration
```

## Resumability

Forge's workflow can take significant time — especially the wizard (Phase 1) and AI tooling generation (Phase 3). If the session is interrupted (session ends, laptop closes, Ctrl-C, crash), nothing is lost.

**How it works:**

- Every skill writes `.claude/forge-state.json` after each natural checkpoint (after each wizard step, each scaffold sub-step, each Phase 3/4 action)
- Writes are atomic (`.tmp` + rename) to avoid corruption if killed mid-write
- The state file tracks current phase, current step, completed steps, accumulated context, research findings, and parked questions
- `/forge:init` checks for an existing state file at startup and offers resume instead of silently restarting
- `/forge:resume` is a direct entry point that reads state and fast-forwards the appropriate skill to exactly where you left off
- `/forge:status` prominently reports in-flight sessions so you know they exist

**Cross-session resume** works even in a completely fresh Claude Code conversation — the state file is the source of truth, and memory files / research findings carry the context.

## Auto-Evolution

After Forge sets up your project, hooks keep tooling in sync:

- **FileChanged hooks** detect when `package.json`, config files, or project structure change
- Changes are logged to `.claude/forge-drift.json`
- **SessionStart hook** summarizes drift at the start of each Claude session
- Run `/onboard:evolve` to apply updates (or configure auto-updates during setup)
- **Weekly CI audit** catches drift that local hooks miss

## Supported Stacks

Forge is stack-agnostic in principle — it researches whatever stack you describe via web search rather than relying on built-in templates. But some stacks are verified end-to-end, some are known to work, and some are experimental. Be honest about which is which:

### Verified (tested end-to-end)

These stacks have been scaffolded through the full forge workflow and the generated tooling has been validated:

- **Next.js (App Router)** — TypeScript, Tailwind, Prisma, NextAuth
- **Python FastAPI** — Pydantic, SQLAlchemy, pytest
- **Go HTTP services** — chi/gin routers, standard project layout

### Known to work (community-reported)

These stacks work but haven't been formally validated in CI:

- React (Vite), Vue, Svelte
- Express, NestJS
- Rust (Axum, Actix)
- Ruby on Rails
- Monorepos (Turborepo, Nx, pnpm workspaces)

### Experimental (walking-skeleton mode recommended)

These stacks lack a mature scaffold CLI or have significantly different architecture from web/server projects. Forge can still help but works best with `scaffoldMode: walking-skeleton`:

- **Android native (Kotlin + Compose + Hilt + Room)** — no `create-*` CLI; use walking skeleton, let AI tooling guide the expansion
- **iOS native (Swift + SwiftUI)** — similar pattern
- **Desktop (Tauri, Electron)** — partial CLI coverage
- **Game engines (Unity, Godot, Bevy)** — architecture is framework-specific
- **Custom backends without an obvious scaffold tool**

If your stack isn't listed here, forge will still try. Use `scaffoldMode: walking-skeleton` if you're unsure — it produces a minimal representative project forge's AI tooling can analyze, rather than guessing at a full scaffold and getting it wrong.

## Works Well With

- **onboard** — Forge delegates Claude tooling generation to onboard's headless mode
- **feature-dev** — After Forge sets up your project, use feature-dev for guided feature development
- **superpowers** — Planning, TDD, debugging skills complement Forge's generated tooling
- **commit-commands** — Git workflow automation for the scaffolded project
- **notify** — System notifications when Claude finishes tasks or needs input — recommended for long-running scaffold sessions
- **security-guidance** — Passive security warnings on file edits — pairs well with forge-generated CI/CD

## License

MIT
