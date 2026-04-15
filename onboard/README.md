# onboard

Interactive wizard that analyzes your codebase and generates complete Claude tooling infrastructure for AI-assisted development.

## What It Does

`onboard` bridges the gap between traditional development and AI-assisted workflows. It performs deep codebase analysis, walks you through an interactive setup wizard, and generates a full suite of Claude tooling tailored to your project.

### Generated Artifacts

- **Root `CLAUDE.md`** — Project overview, tech stack, commands, conventions, critical rules
- **Subdirectory `CLAUDE.md` files** — Context-specific guidance for major directories
- **`.claude/rules/*.md`** — Path-scoped rules for testing, APIs, components, security
- **`.claude/skills/`** — Stack-specific and workflow skills
- **`.claude/agents/`** — Specialized agents (code reviewer, test writer, etc.)
- **`.claude/output-styles/<name>.md`** — Project-scoped custom output style tuned to archetype (onboarding / teaching / production-ops / research / solo)
- **Hook entries in `.claude/settings.json`** — Auto-format, lint checks, tailored to your tooling

All generated files include self-maintaining headers that prompt Claude to notify you when configurations drift from actual code patterns.

## Skills

All skills are invoked with the `/onboard:<name>` slash syntax. Read-only helpers (`status`, `verify`, `evolve`) can also be auto-invoked by Claude when relevant. Destructive skills (`init`, `update`) require explicit invocation.

### `/onboard:init`

Main entry point. Runs a 4-phase guided workflow:

1. **Automated Analysis** — Scans your codebase for languages, frameworks, testing setup, CI/CD, project structure
2. **Interactive Wizard** — Asks adaptive questions about your project context, workflow, pain points, and preferences
3. **Generation** — Creates all Claude tooling artifacts tailored to your answers and analysis
4. **Education & Handoff** — Explains what was generated and how to use it

### `/onboard:update`

Checks whether your Claude tooling is aligned with the latest best practices. Compares your current setup against both the plugin's built-in knowledge and live Claude Code documentation. Preserves your manual customizations.

### `/onboard:generate`

Headless generation mode for programmatic consumers. Accepts pre-seeded context (analysis data + wizard answers) and generates all Claude tooling artifacts without running the interactive wizard or codebase analysis. Designed for plugins like Forge that gather their own project context and delegate tooling generation to onboard.

### `/onboard:verify`

Independent feature verification. Spawns a feature-evaluator agent (in worktree isolation) to test features against `docs/feature-list.json`. Supports single feature, sprint, or all-incomplete modes. Includes sprint contract gate checking.

### `/onboard:evolve`

Apply pending tooling drift updates. Reads `.claude/forge-drift.json` (populated by auto-evolution hooks) and updates CLAUDE.md, rules, and skills to stay in sync with codebase changes.

### `/onboard:status`

Quick health check showing last run date, generated artifacts, integrity status, and recommendations.

## Installation

```bash
# From the marketplace
claude plugin install onboard

# Or from a local path (for development)
claude plugin add /path/to/onboard
```

## Prerequisites

- **bash** — analysis scripts require bash (macOS and Linux have it by default)
- **git** — required for repository analysis and contributor detection
- **tree** (optional) — used for directory visualization; falls back to `find` if unavailable
- **jq** (optional) — used for JSON parsing in hooks; generated hooks include a fallback for systems without `jq`

## How It Works

The plugin uses three specialized components:

- **Codebase Analyzer Agent** — Read-only deep scan of your project structure, dependencies, and patterns
- **Wizard Skill** — Adaptive question flow that tailors questions based on what the analyzer found
- **Config Generator Agent** — Takes analysis + your answers and produces all Claude tooling artifacts

## Example

Running `/onboard:init` on an existing Next.js project:

```
> /onboard:init

Phase 1: Analysis
━━━━━━━━━━━━━━━━━
Scanning codebase...

  Languages:    TypeScript (94%), CSS (6%)
  Framework:    Next.js 15 (App Router)
  Testing:      Vitest + React Testing Library
  Styling:      Tailwind CSS + shadcn/ui
  Linting:      ESLint (flat config) + Prettier
  CI/CD:        GitHub Actions (1 workflow)
  Size:         48 files, 3,200 LOC

Phase 2: Wizard
━━━━━━━━━━━━━━━
Claude: I detected Next.js 15 with App Router. A few questions to tailor
        your tooling:

        What's your testing philosophy?
        (a) TDD — write tests first, always
        (b) Test after — write tests for completed features
        (c) Coverage targets — aim for a % threshold
        (d) Minimal — only test critical paths

You: (a) TDD

Claude: What level of autonomy should Claude have?
        (a) Always ask — suggest but never act without confirmation
        (b) Balanced — auto-format, advisory lint, blocking pre-commit
        (c) Autonomous — auto-format, auto-lint, enforce all gates

You: (b) Balanced

Phase 3: Generation
━━━━━━━━━━━━━━━━━━━
Generated 12 artifacts:

  CLAUDE.md                          — 142 lines (project overview + conventions)
  src/CLAUDE.md                      — 38 lines (component patterns)
  .claude/rules/testing.md           — TDD workflow with vitest patterns
  .claude/rules/components.md        — React component conventions
  .claude/rules/api-routes.md        — Next.js route handler patterns
  .claude/skills/run-tests/SKILL.md  — Project-specific test runner
  .claude/agents/code-reviewer.md    — Review agent with project context
  .claude/settings.json              — Prettier on Write, ESLint on Edit
  + 4 more files

Phase 4: Handoff
━━━━━━━━━━━━━━━━
Your project is now set up for AI-assisted development. Try these:
  1. Open a file and notice how Claude has context about your conventions
  2. Ask Claude to create a new component — it will follow your patterns
  3. Run /onboard:status anytime to check the health of your setup
```

## Supported Project Types

- Node.js / TypeScript (React, Next.js, Express, NestJS, etc.)
- Python (Django, Flask, FastAPI, etc.)
- Go
- Rust
- Ruby (Rails)
- Monorepos (npm/yarn/pnpm workspaces, Turborepo, Nx, Lerna)
- Mixed-language projects

## Used By

- **forge** — Uses onboard's headless mode (`/onboard:generate`) to generate all Claude tooling for newly scaffolded projects. If you install forge, onboard is a required dependency.

## Works Well With

- **claude-md-management** — Maintains the CLAUDE.md files that onboard generates. onboard bootstraps, claude-md-management handles ongoing quality scoring and revision as your project evolves.
- **hookify** — Adds behavioral rules incrementally after onboard's initial setup. onboard writes hooks to `settings.json`; hookify uses `.local.md` rule files for on-the-fly additions.
- **security-guidance** — Passive security warnings during development. Complements onboard's generated hooks with OWASP-aware file-edit checks.

## License

MIT
