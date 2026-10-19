# onboard

> Part of [`claude-plugins`](../README.md) — see also [`notify`](../notify/) and [`handoff`](../handoff/).

Lifecycle manager for AI configs. Generates Claude tooling on day one, then **detects code-vs-config drift** as the project evolves and updates the tooling to match.

Generating `CLAUDE.md` is well-covered in 2026 — Claude Code's `/init`, GitHub Copilot, OpenAI Codex, Cursor, and several web tools all do it. onboard's focus is the step after: keeping those configs aligned as your code grows.

## Install

```bash
claude plugin install onboard@apurvbazari-plugins
```

## What onboard changes

Know this before you run it:

- **It writes Claude tooling files into your project**: `CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, `.claude/agents/`, hook entries in `.claude/settings.json`, and its own state files under `.claude/`. `/onboard:start` shows every one of them in a preview and writes none of them until you approve it. Before that point it writes only its research notes (`.claude/onboard-research.json`, plus `docs/onboard/` if you choose to keep the research docs in the repo) and the preview page itself.
- **It writes a project `.mcp.json`** with MCP servers matched to your stack. `context7` is added on every project; others (GitHub, Vercel, Supabase, Chrome DevTools) are added when your stack calls for them. Some of these start an `npx` package and some connect to a vendor URL. Prisma's server ships inside the `prisma` plugin, so onboard writes no entry for it and offers the plugin instead. An existing `.mcp.json` is never overwritten. The preview lists the servers.
- **It installs other Claude Code plugins only when you accept an offer that names them.** That covers language-server (LSP) plugins, the plugins that go with those MCP servers, `walkthrough` and `notify`. The MCP-plugin rows start unchecked, a skipped question installs nothing, and the preview lists every plugin that will be installed.
- **`/onboard:evolve` and `/onboard:verify` write files, and Claude can start them.** Each skill's section below says exactly what it changes.

## Skills

All skills are invoked with the `/onboard:<name>` slash syntax. They fall into three groups:

- **Writes nothing:** `check`. Claude can start it when relevant.
- **Writes to your project, and Claude can start it when relevant:** `verify` and `evolve`. Neither installs a plugin without asking.
- **Runs only when you invoke it:** `start`, `update` and `adopt`.

### `/onboard:evolve` — the drift loop

Reads `.claude/onboard-drift.json` (populated by the auto-evolution hooks `onboard:start` writes during initial setup), compares its snapshots against the current project, and brings the tooling back in line. (Legacy projects: the old `greenfield-drift.json` is still read; `/onboard:evolve` migrates it.)

**It applies most drift without asking.** That includes updating `CLAUDE.md`, rules, hook scripts and `settings.json` entries, and adding newly relevant MCP servers to `.mcp.json`.

**It also removes tooling that no longer applies:** rules that reference a package you removed, the `CLAUDE.md` of a directory you deleted, hook scripts for a plugin you uninstalled, and generated files that an installed plugin has made redundant (for example a standalone TDD skill once `superpowers` is installed). In `CLAUDE.md` it changes only the sections affected and keeps your own additions. It shows a diff of everything it changed when it finishes.

**It stops and asks before** installing any plugin, adding a built-in-skill recommendation, or creating a new subdirectory `CLAUDE.md`. If nobody answers, none of those happen.

For per-item approval of every change, use `/onboard:update` instead.

This is the heart of the lifecycle loop — see [Drift detection deep dive](#drift-detection-deep-dive) below.

### `/onboard:start` *(destructive — user-invoked only)*

Main entry point. Runs a grounded, research-first guided workflow:

1. **Recon** — codebase-analyzer agent (read-only, script-free — native Glob/Grep/Read + git one-liners) scans languages, frameworks, testing setup, CI/CD, project structure and emits `reconHints`. Output stays in conversation context, not written to disk.
2. **Profile select** — pick Minimal / Standard / Comprehensive. The profile sets how deep the research goes and how much tooling is generated (no Custom path).
3. **Deep Research** — `onboard:research` fans out specialists, adversarially verifies, and synthesizes a research dossier plus 4 artifacts (research-dossier, architecture, risk-register, glossary).
4. **Grounded Wizard** — instead of cold Q&A, you confirm or override the wizard answers the research already inferred (`research.wizardInferences`). Autonomy level is always asked cold, never inferred. The wizard also offers plugins by name (LSP plugins, and the plugins that go with detected MCP servers); only the ones you select are installed.
5. **Preview & gate** — onboard computes a generation plan and shows a full preview (research findings, the blueprint of every file it will write, the MCP servers it will add and every plugin it will install) behind a hard Approve / Adjust / Cancel gate. No tooling file is written until you approve; only the research notes and the preview page exist before that.
6. **Generation** — config-generator agent emits Core artifacts (always) and Enriched artifacts (when enabled): see [Generated artifacts](#generated-artifacts).
7. **Education & Handoff** — explains what was generated and how to use it.

Includes an empty-repo guard — if the repo is empty, offers a 3-option menu (abort / placeholder / canonical stub) before running.

### `/onboard:update` *(destructive — user-invoked only)*

Re-aligns your tooling against onboard's bundled best-practice guides and offers each change for approval. It also checks the live Claude Code docs for features newer than those guides and lists them for you; that list is information only and never supplies what gets written. A plugin is installed only if you select its own row. Preserves your manual customisations.

### `/onboard:adopt` *(destructive — user-invoked only)*

For repos that already have **hand-crafted** Claude tooling not generated by onboard. Adopt catalogs the existing surface, researches the codebase, and synthesizes an onboard baseline (`onboard-meta.json` `mode:"retrofit"` + snapshots) so `/onboard:update` works — **without modifying any hand-crafted file**. Every adopted artifact is tracked `origin:"adopted"`; modernization (e.g. adding maintenance headers, migrating to conventions) is deferred to `/onboard:update`, where you approve each change. Reachable directly, from `/onboard:start`'s existing-config branch, or from `/onboard:update` when no baseline exists yet.

### `/onboard:verify`

Independent feature verification. Spawns the `feature-evaluator` agent in worktree isolation to test features against `docs/feature-list.json`. Supports single-feature, sprint, or all-incomplete modes. Includes sprint-contract gate checking.

It writes its results: `docs/feature-list.json` (a feature is marked passing only on a PASS), `docs/progress.md`, and a report under `docs/verification-reports/`. The evaluator itself runs in a throwaway worktree and cannot change your files.

### `/onboard:check`

Quick health check showing last run date, generated artifacts, integrity status, and recommendations. Writes nothing.

### `/onboard:generate` *(internal API — `user-invocable: false`, hidden from `/` menu)*

Internal generation step invoked by `/onboard:start` (after the grounded wizard) and by `/onboard:update` / `/onboard:evolve` (for missing-file repair). Consumes the v3 context shape (`version: 3`, per `schemas/context-shape-v3.json`) and emits all Claude tooling artifacts without re-running the interactive wizard or codebase analysis. This is not an external API — the v2 external-caller contract was removed in 3.0.0. It accepts a `mode`: `"plan"` computes the `generationManifest` (what it *would* write) for the pre-implementation gate without writing; `"write"` (default) runs the full pipeline.

### `onboard:maintain` *(internal — `user-invocable: false`, hidden from `/` menu)*

The apply half of the **maintain entry**, called by an orchestrator's maintain phase after a change lands. It runs non-interactively: given a `maintain-detect` report and optional owner-approved lessons, it writes each new `package.json` script as one line in the nearest fitting commands section of a `CLAUDE.md` (in that section's own style), writes the approved lessons into `.claude/rules/lessons*.md` or a marked section, and returns `applied[]` / `deferred[]` / `skipped[]` in `maintain-result.json`. It never prompts, never commits, and writes only tooling files.

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
Phase 2: Research ──→ profile-select (Minimal / Standard / Comprehensive) → Skill(onboard:research)
     │                  └── sets research depth + gen scope; dossier + research-dossier / architecture / risk-register / glossary
     ▼
Phase 3: Grounded Wizard ──→ confirm/override from research.wizardInferences
     │                        (autonomy asked cold)
     ▼
Phase 4: Plugin Detection & Context ──→ siblings + marketplace probe → build v3 context
     │
     ▼
Phase 5: Plan → Preview → HARD GATE ──→ Skill(onboard:generate {mode:plan})
     │                                    └── previewModel (research + blueprint) → walkthrough:render
     │                                        Approve → write │ Adjust → re-plan │ Cancel → nothing
     ▼
Phase 6: Generation (post-gate) ──→ Skill(onboard:generate {mode:"write"})
     │                   └── config-generator agent (write; installs only the plugins you accepted)
     ▼
Phase 7: Handoff ──→ explains generated artifacts, suggests next steps
```

**The components that do the work:**

- **codebase-analyzer agent** — read-only, script-free recon of project structure, dependencies, patterns
- **research engine** (`onboard:research`) — fans out specialists, verifies, and synthesizes the dossier + 4 artifacts that ground the wizard
- **wizard skill** — grounded confirm/override surface seeded by the research inferences
- **config-generator agent** — takes the v3 context (recon + research + wizard) and produces all artifacts

Internal architecture and agent contracts: [`onboard/CONVENTIONS.md`](./CONVENTIONS.md).

## Drift detection deep dive

When `/onboard:start` runs in **enriched mode**, it installs auto-evolution hooks that quietly track changes:

- **FileChanged hooks** on `package.json`, `tsconfig.json`, `pyproject.toml`, lockfiles, and structural anchors → log diffs to `.claude/onboard-drift.json`
- **SessionStart hook** → summarises pending drift at the start of each Claude Code session

Then `/onboard:evolve` reads the drift log, compares against the original snapshot, categorises changes (new dependencies, structural shifts, config diffs, missing hooks) and applies the matching tooling updates. Most are applied without asking and shown as a diff afterwards; a plugin install, a built-in-skill recommendation or a new subdirectory `CLAUDE.md` waits for your answer. Snapshots update after each run so subsequent invocations are incremental.

See the [Example](#example) below for a full two-run transcript showing start followed by evolve detecting drift two weeks later.

## Maintain entry (for orchestrators)

Two scripts and one internal skill keep tooling current after each change, without the wizard:

1. **`scripts/maintain-detect.sh --base <ref> --out <file>`** — no model, about a second. Reports only the drift the git range caused, each item labelled `apply` (a new script line maintain writes), `defer` (a to-do with a command or hint) or `inform` (context for the owner's lesson decisions: a new dependency, a tooling line that mentions a changed path).
2. **`onboard:maintain`** — run by the caller's model with `detect=… out=… [lessons=…]`; writes the `apply` items and the approved lessons, and returns `maintain-result.json`.
3. **`scripts/maintain-guard.sh`** fences that run to tooling files; **`scripts/maintain-write.sh`** writes the lesson entries and the result, because `.claude/` is a [protected path](https://code.claude.com/docs/en/permission-modes#protected-paths) that Claude Code's own tools may not write unattended.

The contract is three JSON schemas in `schemas/` — `maintain-detect.json`, `maintain-lessons.json`, `maintain-result.json`, all `schemaVersion: 1`. Callers locate the scripts with `claude plugin list --json` (`installPath`, `version` ≥ 3.2.0).

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

Phase 2: Research — profile select
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
How deep should I go?
  (a) Minimal       — shallow research, core tooling only
  (b) Standard      — balanced research + tooling   (recommended)
  (c) Comprehensive — full research + enriched tooling

> b

Phase 2: Research — deep research
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fanning out specialists → verifying → synthesizing dossier…
  Wrote research-dossier, architecture, risk-register, glossary

Phase 3: Grounded Wizard
━━━━━━━━━━━━━━━━━━━━━━━━
From the research I inferred the following — confirm or override:

  Testing philosophy   TDD          (vitest + RTL, tests co-located)   [confirm / change]
> confirm

  What level of autonomy should Claude have?   (asked cold — never inferred)
  (a) Always ask — suggest but never act without confirmation
  (b) Balanced — auto-format, advisory lint, blocking pre-commit
  (c) Autonomous — auto-format, auto-lint, enforce all gates

> b

  Plugins that go with the MCP servers I'll add — install any?   (all unchecked)
  [ ] context7   [ ] chrome-devtools-mcp   [ ] github
> (none)

Phase 5: Preview & Gate
━━━━━━━━━━━━━━━━━━━━━━━
Here's everything I'll create — review before I write anything:
  research: 3 risks, architecture map, glossary
  + 12 files (CLAUDE.md, 3 rules, 1 skill, 1 agent, settings.json, .mcp.json, …)
  MCP servers: context7, chrome-devtools-mcp, github
  Plugins to install: none

  Approve & generate?  [Approve / Adjust / Cancel]
> Approve

Phase 6: Generation
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
  .mcp.json                          context7, chrome-devtools-mcp, github
  + 3 more files

  Plugins: none installed. Add one later with `claude plugin install <name>`.

  Snapshot saved to .claude/onboard-meta.json

Phase 7: Handoff
━━━━━━━━━━━━━━━━
Your project is set up for AI-assisted development. Try:
  1. Open a file — Claude has context about your conventions
  2. Ask Claude to create a new component — it'll follow your patterns
  3. Run /onboard:check anytime to check the health of your setup

# ── two weeks later — team added Playwright, Supabase and packages/shared ──

> /onboard:evolve

Reading snapshots vs current state…

Drift detected:
  + new dependency     @playwright/test in apps/web
  + structural change  packages/shared workspace appeared
  ~ tsconfig changes   paths added for @repo/shared
  + new stack signal   supabase/ directory → supabase MCP server

Updates applied:
  • CLAUDE.md                    added @playwright/test, marked monorepo, documented workspace boundaries
  • .claude/rules/typescript.md  updated for the new paths
  • .mcp.json                    added supabase server (OAuth — run `claude mcp auth supabase`)

One question:
  New MCP server: supabase. Install the plugin that goes with it?
  [ ] supabase
> (none)

Not applied (needs your input):
  • New directory packages/shared — create a CLAUDE.md for it?
  • supabase plugin not installed. Add it later with `claude plugin install supabase`

Snapshots updated.
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
- **`.mcp.json`** — project MCP servers matched to your stack (an existing file is never overwritten)
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
- **`claude` CLI** — used to install the plugins you accept
- **python3** — required by the [maintain entry](#maintain-entry-for-orchestrators)'s `maintain-*` scripts (standard library only)
- **tree** (optional) — directory visualisation; falls back to `find`
- **jq** (optional) — JSON parsing in hooks; generated hooks include a `python3` fallback

## License

[MIT](../LICENSE)
