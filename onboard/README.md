# onboard

> Part of [`claude-plugins`](../README.md) — see also [`forge`](../forge/) (uses onboard's headless mode) and [`notify`](../notify/).

Lifecycle manager for AI configs. Generates Claude tooling on day one, then **detects code-vs-config drift** as the project evolves and offers to fix it.

Auto-generating `CLAUDE.md` is commodity in 2026 — Claude Code's `/init`, GitHub Copilot, OpenAI Codex, Cursor, and several web tools all do it. Maintaining those configs as your code grows is what onboard does that nothing else does.

## Install

```bash
claude plugin install onboard@apurvbazari-plugins
```

## Skills

All skills are invoked with the `/onboard:<name>` slash syntax. Read-only helpers (`status`, `verify`, `evolve`) can also be auto-invoked by Claude when relevant. Destructive skills (`init`, `update`) require explicit invocation.

### `/onboard:evolve` — the drift detection loop

The capability no competitor ships. Reads `.claude/forge-drift.json` (populated by auto-evolution hooks `onboard:init` writes during initial setup), compares the snapshot against current code state, and proposes targeted updates: new languages added, new dependencies, structural changes, missing hooks, stale rules.

You decide which proposed updates to apply. Snapshot then updates so the next `/onboard:evolve` run is incremental.

This is the lifecycle differentiator — see [Drift detection deep dive](#drift-detection-deep-dive) below.

### `/onboard:init` *(destructive — user-invoked only)*

Main entry point. Runs a 4-phase guided workflow:

1. **Automated Analysis** — codebase-analyzer agent (read-only) scans languages, frameworks, testing setup, CI/CD, project structure. Output stays in conversation context, not written to disk.
2. **Interactive Wizard** — adaptive Q&A about project context, workflow, pain points, plugin preferences. Presets: Minimal / Standard / Comprehensive / Custom.
3. **Generation** — config-generator agent emits Core artifacts (always) and Enriched artifacts (when enabled): see [Generated artifacts](#generated-artifacts).
4. **Education & Handoff** — explains what was generated and how to use it.

Includes an empty-repo guard — if the repo is empty, offers a 3-option menu (abort / placeholder / canonical stub) before running.

### `/onboard:update` *(destructive — user-invoked only)*

Re-aligns your tooling against the latest Claude Code best practices. Compares current setup against both the plugin's built-in knowledge and live Claude Code documentation. Preserves your manual customisations.

### `/onboard:verify`

Independent feature verification. Spawns the `feature-evaluator` agent in worktree isolation to test features against `docs/feature-list.json`. Supports single-feature, sprint, or all-incomplete modes. Includes sprint-contract gate checking.

### `/onboard:status`

Quick health check showing last run date, generated artifacts, integrity status, and recommendations.

### `/onboard:generate` *(internal API — `user-invocable: false`, hidden from `/` menu)*

Headless generation mode for programmatic consumers. Accepts pre-seeded context (analysis data + wizard answers) and emits all Claude tooling artifacts without running the interactive wizard or codebase analysis.

This is what `forge` invokes via the `Skill` tool to delegate Phase 3 of its scaffold flow. The contract is intentionally stable so external plugins can rely on it.

## Architecture

```
/onboard:init
     │
     ▼
Phase 0: Empty-Repo Guard ──→ no source files? 3-option menu
     │
     ▼
Phase 1: Analysis ──→ codebase-analyzer agent (read-only)
     │                  ├── analyze-structure.sh
     │                  ├── detect-stack.sh
     │                  └── measure-complexity.sh
     ▼
Phase 2: Wizard ──→ wizard skill (adaptive Q&A, presets)
     │
     ▼
Phase 2.5: Plugin Detection ──→ siblings + marketplace probe
     │
     ▼
Phase 3: Generation ──→ Skill(onboard:generate) [same contract as forge]
     │                   └── config-generator agent (write)
     ▼
Phase 4: Handoff ──→ explains generated artifacts, suggests next steps
```

**Three specialised components do the work:**

- **codebase-analyzer agent** — read-only deep scan of project structure, dependencies, patterns
- **wizard skill** — adaptive question flow, tailors questions to what the analyser found
- **config-generator agent** — takes analysis + wizard answers and produces all artifacts

Internal architecture and agent contracts: [`onboard/CLAUDE.md`](./CLAUDE.md).

## Drift detection deep dive

When `/onboard:init` runs in **enriched mode** (default for forge-scaffolded projects), it installs auto-evolution hooks that quietly track changes:

- **FileChanged hooks** on `package.json`, `tsconfig.json`, `pyproject.toml`, lockfiles, and structural anchors → log diffs to `.claude/forge-drift.json`
- **SessionStart hook** → summarises pending drift at the start of each Claude Code session

Then `/onboard:evolve` reads the drift log, compares against the original snapshot, categorises changes (new dependencies, structural shifts, config diffs, missing hooks), proposes targeted updates, and applies the ones you approve. Snapshot updates after each run so subsequent invocations are incremental.

See the [Example](#example) below for a full two-run transcript showing init followed by evolve detecting drift two weeks later.

## Example

`/onboard:init` on an existing Next.js 15 project, then `/onboard:evolve` two weeks later:

```
> /onboard:init

Phase 1: Analysis
━━━━━━━━━━━━━━━━━
Scanning codebase…

  Languages    TypeScript (94%), CSS (6%)
  Framework    Next.js 15 (App Router)
  Testing      Vitest + React Testing Library
  Styling      Tailwind CSS + shadcn/ui
  Linting      ESLint (flat config) + Prettier
  CI/CD        GitHub Actions (1 workflow)
  Size         48 files, 3,200 LOC

Phase 2: Wizard
━━━━━━━━━━━━━━━
I detected Next.js 15 with App Router. A few questions to tailor your tooling:

  What's your testing philosophy?
  (a) TDD — write tests first, always
  (b) Test after — write tests for completed features
  (c) Coverage targets — aim for a % threshold
  (d) Minimal — only test critical paths

> a

  What level of autonomy should Claude have?
  (a) Always ask — suggest but never act without confirmation
  (b) Balanced — auto-format, advisory lint, blocking pre-commit
  (c) Autonomous — auto-format, auto-lint, enforce all gates

> b

Phase 3: Generation
━━━━━━━━━━━━━━━━━━━
Generated 12 artifacts:

  CLAUDE.md                          142 lines (project overview + conventions)
  src/CLAUDE.md                       38 lines (component patterns)
  .claude/rules/testing.md           TDD workflow with vitest patterns
  .claude/rules/components.md        React component conventions
  .claude/rules/api-routes.md        Next.js route handler patterns
  .claude/skills/run-tests/SKILL.md  Project-specific test runner
  .claude/agents/code-reviewer.md    Review agent with project context
  .claude/settings.json              Prettier on Write, ESLint on Edit
  + 4 more files

  Snapshot saved to .claude/onboard-snapshot.json

Phase 4: Handoff
━━━━━━━━━━━━━━━━
Your project is set up for AI-assisted development. Try:
  1. Open a file — Claude has context about your conventions
  2. Ask Claude to create a new component — it'll follow your patterns
  3. Run /onboard:status anytime to check the health of your setup

# ── two weeks later — team added Playwright + extracted packages/shared ──

> /onboard:evolve

Reading snapshot vs current state…

Drift detected:
  + new dependency     @playwright/test in apps/web
  + new language area  Playwright config implies e2e tests (no rule yet)
  + structural change  packages/shared workspace appeared
  ~ tsconfig changes   paths added for @repo/shared

Proposed updates:
  • Add rule        testing/e2e-conventions.md (Playwright)
  • Update CLAUDE.md → mark monorepo, document workspace boundaries
  • Add hook        PostToolUse on apps/web/**/*.tsx → Playwright config check

Apply all? [Y/n]
> Y

Snapshot updated. AI configs realigned to current code.
```

## Generated artifacts

### Core (always)

- **Root `CLAUDE.md`** — Project overview, tech stack, commands, conventions, critical rules
- **Subdirectory `CLAUDE.md` files** — Context-specific guidance for major directories
- **`.claude/rules/*.md`** — Path-scoped rules for testing, APIs, components, security
- **`.claude/skills/`** — Stack-specific and workflow skills
- **`.claude/agents/`** — Specialised agents (plugin-aware — skips agents already covered by an installed plugin)
- **`.claude/output-styles/<name>.md`** — Project-scoped custom output style tuned to archetype (onboarding / teaching / production-ops / research / solo)
- **Hook entries in `.claude/settings.json`** — Auto-format, lint checks, tailored to your tooling
- **PR template + commit conventions**
- **`.claude/onboard-meta.json`** — generation manifest

### Enriched (when wizard or headless flags enable)

- **CI/CD pipelines** (GitHub Actions: ci, tooling-audit, pr-review)
- **Harness artifacts** (`docs/progress.md`, `docs/HARNESS-GUIDE.md`)
- **Auto-evolution hooks** (FileChanged + SessionStart) + drift-detection scripts that power `/onboard:evolve`
- **Sprint contracts** (`docs/sprint-contracts/`)
- **Agent team support** (quality hooks, env vars)

All generated files include self-maintaining headers (version + date) that prompt Claude to notify you when configurations drift from actual code patterns.

## Supported project types

- Node.js / TypeScript (React, Next.js, Express, NestJS, …)
- Python (Django, Flask, FastAPI, …)
- Go
- Rust
- Java / Kotlin
- Ruby (Rails)
- Monorepos (npm/yarn/pnpm workspaces, Turborepo, Nx, Lerna)
- Mixed-language projects

## Prerequisites

- **bash** — analysis scripts (macOS and Linux ship with it)
- **git** — repository analysis and contributor detection
- **tree** (optional) — directory visualisation; falls back to `find`
- **jq** (optional) — JSON parsing in hooks; generated hooks include a `python3` fallback

## License

[MIT](../LICENSE)
