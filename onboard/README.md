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
- **Hook entries in `.claude/settings.json`** — Auto-format, lint checks, tailored to your tooling

All generated files include self-maintaining headers that prompt Claude to notify you when configurations drift from actual code patterns.

## Commands

### `/onboard:init`

Main entry point. Runs a 4-phase guided workflow:

1. **Automated Analysis** — Scans your codebase for languages, frameworks, testing setup, CI/CD, project structure
2. **Interactive Wizard** — Asks adaptive questions about your project context, workflow, pain points, and preferences
3. **Generation** — Creates all Claude tooling artifacts tailored to your answers and analysis
4. **Education & Handoff** — Explains what was generated and how to use it

### `/onboard:update`

Checks whether your Claude tooling is aligned with the latest best practices. Compares your current setup against both the plugin's built-in knowledge and live Claude Code documentation. Preserves your manual customizations.

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

## Supported Project Types

- Node.js / TypeScript (React, Next.js, Express, NestJS, etc.)
- Python (Django, Flask, FastAPI, etc.)
- Go
- Rust
- Ruby (Rails)
- Monorepos (npm/yarn/pnpm workspaces, Turborepo, Nx, Lerna)
- Mixed-language projects

## Works Well With

- **claude-md-management** — Maintains the CLAUDE.md files that onboard generates. onboard bootstraps, claude-md-management handles ongoing quality scoring and revision as your project evolves.
- **hookify** — Adds behavioral rules incrementally after onboard's initial setup. onboard writes hooks to `settings.json`; hookify uses `.local.md` rule files for on-the-fly additions.

See [docs/best-practices.md](../docs/best-practices.md) for handoff workflows and coexistence details.

## License

MIT
