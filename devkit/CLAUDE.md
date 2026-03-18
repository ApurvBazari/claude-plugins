# devkit — Internal Conventions

Config-driven unified developer workflow toolkit.

## Guard Pattern

Every skill (except `/devkit:setup`) starts with:

```
Read `.claude/devkit.json` in the project root. If not found:
> Run `/devkit:setup` first to configure your project.
Stop and do not proceed.
```

This is the single most important pattern in devkit — `/devkit:setup` MUST run before any other skill works.

## Setup-First Architecture

```
/devkit:setup
     │
     ├── tooling-detector agent (read-only scan)
     │     ├── lock files → package manager
     │     ├── config files → test runner, linter, formatter
     │     └── git history → commit style
     │
     ├── user verification (present + confirm)
     │
     └── writes .claude/devkit.json
           │
           └── all other skills read this config
```

## Skill Invocation Chain

```
/devkit:ship ──→ sequential pipeline
     │
     ├── /devkit:test    (mode: all)
     ├── /devkit:lint    (with auto-fix)
     ├── /devkit:check   (production readiness)
     ├── /devkit:review  (optional, code review vs base branch)
     └── /devkit:commit  (final step, always last)
```

Each step is invoked via the Skill tool — ship does NOT duplicate skill logic.

## Config Schema

```json
{
  "_generated": { "by": "devkit", "version": "<config-schema-version>", "date": "YYYY-MM-DD" },
  "tooling": {
    "packageManager": "pnpm|npm|yarn|bun|pipenv|poetry|go|cargo|bundler",
    "testCommand": "pnpm test",
    "testRunner": "vitest|jest|pytest|go test|cargo test|rspec",
    "lintCommand": "pnpm lint",
    "linter": "eslint|biome|ruff|golangci-lint|clippy|rubocop",
    "buildCommand": "pnpm build",
    "formatter": "prettier|biome|black|rustfmt"
  },
  "commitStyle": "conventional|simple|ticket|freeform",
  "baseBranch": "main",
  "shipPipeline": ["test", "lint", "check"],
  "prTemplate": "existing|builtin"
}
```

Null tooling fields are omitted entirely, not set to null.

## Multi-Runner Support Tables

Every skill that runs external tools includes a table mapping runners to their specific commands and flags. Example from `/devkit:test`:

| Runner | All | Coverage | Watch | Specific |
|--------|-----|----------|-------|----------|
| vitest | `vitest run` | `vitest run --coverage` | `vitest` | `vitest run <path>` |
| jest | `jest` | `jest --coverage` | `jest --watch` | `jest <path>` |

This pattern ensures consistent cross-ecosystem support.

## Step Result Classification

Ship pipeline classifies each step's result:

| Result | Action |
|--------|--------|
| PASS | Proceed to next step |
| CRITICAL | Block pipeline, show issues, ask user |
| WARNING | Show issues, ask user to continue or fix |
| SKIP | Skip silently (tooling not configured) |
| ERROR | Report error, ask user to continue or abort |

## Notify Integration

After ship pipeline completes, check for `notify-config.json` in `~/.claude/` or `<project>/.claude/`. If found, send `terminal-notifier` notification with result. If not found, skip silently — never prompt to install notify.

## Commit Style Enforcement

| Style | Format | Scope detection |
|-------|--------|-----------------|
| Conventional | `type(scope): desc` | Auto-detected from changed file directories |
| Simple | `type: desc` | No scope |
| Ticket | `TICKET-ID: desc` | Extracted from branch name |
| Freeform | No enforcement | — |
