# onboard

> Part of [`claude-plugins`](../README.md) — see also [`notify`](../notify/) and [`handoff`](../handoff/).

Lifecycle manager for AI configs. Generates Claude tooling on day one, then **detects code-vs-config drift** as the project evolves and offers to fix it.

Generating `CLAUDE.md` is well-covered in 2026 — Claude Code's `/init`, GitHub Copilot, OpenAI Codex, Cursor, and several web tools all do it. onboard's focus is the step after: keeping those configs aligned as your code grows.

## Install

```bash
claude plugin install onboard@apurvbazari-plugins
```

## Skills

All skills are invoked with the `/onboard:<name>` slash syntax. Read-only helpers (`check`, `verify`, `evolve`) can also be auto-invoked by Claude when relevant. Destructive skills (`start`, `update`) require explicit invocation.

### `/onboard:evolve` — the drift detection loop

The drift loop. Reads `.claude/greenfield-drift.json` (populated by auto-evolution hooks `onboard:start` writes during initial setup), compares the snapshot against current code state, and proposes targeted updates: new languages added, new dependencies, structural changes, missing hooks, stale rules.

You decide which proposed updates to apply. Snapshot then updates so the next `/onboard:evolve` run is incremental.

This is the heart of the lifecycle loop — see [Drift detection deep dive](#drift-detection-deep-dive) below.

### `/onboard:start` *(destructive — user-invoked only)*

Main entry point. Runs a grounded, research-first guided workflow:

1. **Recon** — codebase-analyzer agent (read-only, script-free — native Glob/Grep/Read + git one-liners) scans languages, frameworks, testing setup, CI/CD, project structure and emits `reconHints`. Output stays in conversation context, not written to disk.
2. **Profile select** — pick Minimal / Standard / Comprehensive. The profile sets how deep the research goes and how much tooling is generated (no Custom path).
3. **Deep Research** — `onboard:research` fans out specialists, adversarially verifies, and synthesizes a research dossier plus 4 artifacts (research-dossier, architecture, risk-register, glossary).
4. **Grounded Wizard** — instead of cold Q&A, you confirm or override the wizard answers the research already inferred (`research.wizardInferences`). Autonomy level is always asked cold, never inferred.
5. **Generation** — config-generator agent emits Core artifacts (always) and Enriched artifacts (when enabled): see [Generated artifacts](#generated-artifacts).
6. **Education & Handoff** — explains what was generated and how to use it.

Includes an empty-repo guard — if the repo is empty, offers a 3-option menu (abort / placeholder / canonical stub) before running.

### `/onboard:update` *(destructive — user-invoked only)*

Re-aligns your tooling against the latest Claude Code best practices. Compares current setup against both the plugin's built-in knowledge and live Claude Code documentation. Preserves your manual customisations.

### `/onboard:verify`

Independent feature verification. Spawns the `feature-evaluator` agent in worktree isolation to test features against `docs/feature-list.json`. Supports single-feature, sprint, or all-incomplete modes. Includes sprint-contract gate checking.

### `/onboard:check`

Quick health check showing last run date, generated artifacts, integrity status, and recommendations.

### `/onboard:generate` *(internal API — `user-invocable: false`, hidden from `/` menu)*

Internal generation step invoked by `/onboard:start` (after the grounded wizard) and by `/onboard:update` / `/onboard:evolve` (for missing-file repair). Consumes the v3 context shape (`version: 3`, per `skills/generate/references/context-shape-v3.json`) and emits all Claude tooling artifacts without re-running the interactive wizard or codebase analysis. This is not an external API — the v2 headless contract was removed in 3.0.0.

## Architecture

```
/onboard:start
     │
     ▼
Phase 0: Empty-Repo Guard ──→ no source files? 3-option menu
     │
     ▼
Phase 1: Recon ──→ codebase-analyzer agent (read-only, script-free)
     │              └── native Glob/Grep/Read + git one-liners → reconHints
     ▼
Phase 1.4: Profile select ──→ Minimal / Standard / Comprehensive
     │                          └── sets research depth + generation scope
     ▼
Phase 1.5: Research ──→ Skill(onboard:research)
     │                   └── dossier + research-dossier / architecture / risk-register / glossary
     ▼
Phase 2: Grounded Wizard ──→ confirm/override from research.wizardInferences
     │                        (autonomy asked cold)
     ▼
Phase 2.5: Plugin Detection ──→ siblings + marketplace probe
     │
     ▼
Phase 2.7-2.9: Plan → Preview → HARD GATE ──→ Skill(onboard:generate {mode:plan})
     │                                         └── previewModel (research + blueprint) → walkthrough:render
     │                                             Approve → write │ Adjust → re-plan │ Cancel → nothing
     ▼
Phase 3: Generation (post-gate) ──→ Skill(onboard:generate {mode:"write"})
     │                   └── config-generator agent (write)
     ▼
Phase 4: Handoff ──→ explains generated artifacts, suggests next steps
```

**The components that do the work:**

- **codebase-analyzer agent** — read-only, script-free recon of project structure, dependencies, patterns
- **research engine** (`onboard:research`) — fans out specialists, verifies, and synthesizes the dossier + 4 artifacts that ground the wizard
- **wizard skill** — grounded confirm/override surface seeded by the research inferences
- **config-generator agent** — takes the v3 context (recon + research + wizard) and produces all artifacts

Internal architecture and agent contracts: [`onboard/CLAUDE.md`](./CLAUDE.md).

## Drift detection deep dive

When `/onboard:start` runs in **enriched mode**, it installs auto-evolution hooks that quietly track changes:

- **FileChanged hooks** on `package.json`, `tsconfig.json`, `pyproject.toml`, lockfiles, and structural anchors → log diffs to `.claude/greenfield-drift.json`
- **SessionStart hook** → summarises pending drift at the start of each Claude Code session

Then `/onboard:evolve` reads the drift log, compares against the original snapshot, categorises changes (new dependencies, structural shifts, config diffs, missing hooks), proposes targeted updates, and applies the ones you approve. Snapshot updates after each run so subsequent invocations are incremental.

See the [Example](#example) below for a full two-run transcript showing init followed by evolve detecting drift two weeks later.

## Example

`/onboard:start` on an existing Next.js 15 project, then `/onboard:evolve` two weeks later:

```
> /onboard:start

Phase 1: Recon
━━━━━━━━━━━━━━
Scanning codebase… (script-free — native search + git)

  Languages    TypeScript (94%), CSS (6%)
  Framework    Next.js 15 (App Router)
  Testing      Vitest + React Testing Library
  Styling      Tailwind CSS + shadcn/ui
  Linting      ESLint (flat config) + Prettier
  CI/CD        GitHub Actions (1 workflow)
  Size         48 files, 3,200 LOC

Phase 1.4: Profile
━━━━━━━━━━━━━━━━━━
How deep should I go?
  (a) Minimal       — shallow research, core tooling only
  (b) Standard      — balanced research + tooling   (recommended)
  (c) Comprehensive — full research + enriched tooling

> b

Phase 1.5: Research
━━━━━━━━━━━━━━━━━━━
Fanning out specialists → verifying → synthesizing dossier…
  Wrote research-dossier, architecture, risk-register, glossary

Phase 2: Grounded Wizard
━━━━━━━━━━━━━━━━━━━━━━━━
From the research I inferred the following — confirm or override:

  Testing philosophy   TDD          (vitest + RTL, tests co-located)   [confirm / change]
> confirm

  What level of autonomy should Claude have?   (asked cold — never inferred)
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

  Snapshot saved to .claude/onboard-meta.json

Phase 4: Handoff
━━━━━━━━━━━━━━━━
Your project is set up for AI-assisted development. Try:
  1. Open a file — Claude has context about your conventions
  2. Ask Claude to create a new component — it'll follow your patterns
  3. Run /onboard:check anytime to check the health of your setup

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

### Enriched (when the wizard enables it)

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

- **bash** — evolution + CI-audit scripts and generated hooks (recon itself is script-free; macOS and Linux ship with it)
- **git** — repository analysis and contributor detection
- **tree** (optional) — directory visualisation; falls back to `find`
- **jq** (optional) — JSON parsing in hooks; generated hooks include a `python3` fallback

## License

[MIT](../LICENSE)
