# Recommended Stack — Full AI-Driven Dev Environment

How to combine this repo's plugins with official marketplace companions for a complete AI-driven development workflow.

## Workflow Map

| Phase | This Repo | Official Companion | Role |
|-------|-----------|-------------------|------|
| **Setup** | `onboard` | `hookify` | Bootstrap tooling, then manage behavioral rules incrementally |
| **Develop** | — | `feature-dev` | Structured 7-phase development workflow (discovery → handoff) |
| **Refine** | — | `code-simplifier` | Simplify and clean up code for clarity and maintainability |
| **Maintain** | — | `claude-md-management` | Ongoing quality scoring and revision of CLAUDE.md files |
| **Guard** | — | `security-guidance` | Passive security checks, primarily for GitHub Actions workflows |
| **Ship** | `devkit` | `code-review` / `pr-review-toolkit` | Quality gates, commits, PRs, and async review |
| **Monitor** | `notify` | — | macOS notifications on task completion and attention needed |
| **Meta** | — | `plugin-dev` / `skill-creator` | Plugin authoring and skill benchmarking (for plugin authors) |

## Installation Order

Install in this order to build each layer on top of the previous:

1. **`onboard`** — Analyzes your codebase and generates all Claude tooling (CLAUDE.md, rules, skills, hooks)
2. **`devkit`** — Run `/devkit:setup` to detect your test/lint/build tooling
3. **`notify`** — Run `/notify:setup` to configure macOS notifications
4. **Official companions** — Add any that fill gaps in your workflow (see below)

## Phase Details

### Setup: onboard + hookify

`onboard` bootstraps your project's Claude tooling in one pass. After that initial setup, `hookify` lets you add behavioral rules incrementally without re-running onboard. They coexist cleanly — onboard writes to `settings.json` hooks, hookify uses `.claude/hookify.*.local.md` files.

### Develop: feature-dev

The development phase (between setup and ship) is handled by the official `feature-dev` plugin. It provides a structured 7-phase workflow: Discovery → Exploration → Clarification → Architecture → Implementation → Review → Handoff. Use it alongside devkit for a complete develop-then-ship cycle.

### Refine: code-simplifier

After implementation, use `code-simplifier` to clean up recently modified code for clarity, consistency, and maintainability. It focuses on what you just changed, keeping refactoring scoped and safe.

### Maintain: claude-md-management

`onboard` bootstraps your CLAUDE.md files; `claude-md-management` maintains them over time. The handoff workflow:

1. Run `/onboard:init` to generate initial tooling
2. Install `claude-md-management`
3. Periodically run its quality scoring to audit generated files
4. Use `/revise-claude-md` at end of sessions to capture learnings

### Guard: security-guidance

Optional add-on for projects with CI/CD workflows. Provides passive security checks with a focus on GitHub Actions. Zero conflict with other plugins — install if relevant to your project.

### Ship: devkit + code-review + pr-review-toolkit

`devkit` handles the local quality pipeline (test → lint → check → commit → PR). For async review:

- **`code-review`** — Posts review comments directly on PRs. Best for async, team-facing feedback.
- **`pr-review-toolkit`** — Deep specialist review with multiple focused agents. Best for thorough pre-merge analysis.

See [best-practices.md](./best-practices.md) for a decision tree on when to use each.

### Monitor: notify

`notify` sends macOS notifications when Claude finishes tasks or needs your attention. No companion needed — it covers the monitoring phase on its own. When used alongside devkit, you get notifications when the ship pipeline completes.

### Meta: plugin-dev + skill-creator

For plugin authors maintaining this repo or building new plugins:

- **`plugin-dev`** — Plugin authoring toolkit with a validator agent that catches manifest issues
- **`skill-creator`** — Eval/iteration loop for benchmarking skill trigger accuracy and output quality
