# devkit

Unified developer workflow toolkit for Claude Code. Config-driven commands that adapt to any project — commit, review, lint, test, and ship with quality gates.

## What It Does

`devkit` provides a standard set of development workflow skills that read their configuration from your project rather than relying on hardcoded commands. Run setup once, and every skill knows your package manager, test runner, linter, commit style, and PR template.

### Available Skills

| Skill | Description |
|-------|-------------|
| `/devkit:setup` | **Required first step** — detects tooling, verifies with you, writes config |
| `/devkit:commit` | Create a commit following your configured style |
| `/devkit:review` | Multi-category code review against main |
| `/devkit:lint` | Run linter with auto-fix |
| `/devkit:test` | Run tests (all / coverage / watch / specific) |
| `/devkit:check` | Production readiness scan (debug artifacts, security, performance, quality) |
| `/devkit:pr` | Create PR with pre-flight checks and auto-populated description |
| `/devkit:ship` | Full pipeline: test → lint → check → commit (configurable) |

## Prerequisites

- **git** — required for all skills (commit, review, PR)
- **gh** (GitHub CLI) — required for `/devkit:pr` to create pull requests. Install: `brew install gh` or see [cli.github.com](https://cli.github.com)

## Quick Start

```bash
# From the marketplace
claude plugin install devkit

# Or from a local path (for development)
claude plugin add /path/to/devkit

# Run setup in your project
/devkit:setup

# Ship your changes
/devkit:ship
```

## Setup

`/devkit:setup` scans your project and presents detected values for verification:

1. **Package manager** — detected from lock files
2. **Test/lint/build commands** — detected from config files and package.json scripts
3. **Commit style** — detected from git history (conventional, simple, ticket, freeform)
4. **Ship pipeline** — configurable steps that run before every commit
5. **PR template** — uses your existing template or a built-in default

Config is saved to `.claude/devkit.json`. All other skills read from this file.

## How It Works

Every skill reads `.claude/devkit.json` for project-specific commands. No hardcoded paths, no runtime detection after setup — just fast, consistent execution.

### Ship Pipeline

The ship pipeline (`/devkit:ship`) runs a configurable sequence of quality checks before committing:

```
test → lint → check → commit
```

- **CRITICAL** issues block the pipeline
- **WARNING** issues pause for your confirmation
- Steps are configurable — add or remove from `shipPipeline` in your config

### Commit Styles

| Style | Format | Example |
|-------|--------|---------|
| Conventional | `type(scope): msg` | `feat(auth): add session management` |
| Simple | `type: msg` | `fix: resolve login crash` |
| Ticket | `TICKET-123: msg` | `JIRA-456: add password reset` |
| Freeform | Any format | `Add password reset feature` |

## Supported Tooling

**Package managers**: npm, pnpm, yarn, bun, pipenv, poetry, go modules, cargo, bundler

**Test runners**: vitest, jest, pytest, go test, cargo test, rspec

**Linters**: eslint, biome, ruff, golangci-lint, clippy, rubocop

**Formatters**: prettier, biome, black, rustfmt

**Task runners**: Makefile, Taskfile.yml (detected as overrides)

## Configuration

Config lives at `.claude/devkit.json`:

```json
{
  "_generated": {
    "by": "devkit",
    "version": "0.1.0",
    "date": "2026-02-24"
  },
  "tooling": {
    "packageManager": "pnpm",
    "testCommand": "pnpm test",
    "testRunner": "vitest",
    "lintCommand": "pnpm lint",
    "linter": "eslint",
    "buildCommand": "pnpm build",
    "formatter": "prettier"
  },
  "commitStyle": "conventional",
  "shipPipeline": ["test", "lint", "check"],
  "prTemplate": "existing"
}
```

Edit directly or re-run `/devkit:setup` to reconfigure.

## License

MIT
