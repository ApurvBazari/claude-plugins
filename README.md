# claude-plugins

A curated collection of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — powering AI-driven development and agentic workflows.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [onboard](./onboard/) | Analyzes your codebase and generates tailored Claude tooling — `CLAUDE.md` files, rules, skills, agents, and hooks — through an interactive wizard |
| [notify](./notify/) | macOS system notifications for Claude Code — get notified when tasks complete, Claude needs input, or subagents finish |
| [devkit](./devkit/) | Unified developer workflow toolkit — config-driven commit, review, lint, test, and ship commands that adapt to any project |

## Quick Start

```bash
# Add the marketplace
claude marketplace add https://github.com/apurvbazari/claude-plugins

# Install a plugin
claude plugin install onboard
```

## onboard

Bridges traditional development and AI-assisted workflows. Performs deep codebase analysis, walks you through an interactive setup, and generates a full suite of Claude tooling tailored to your project.

**Key commands:**

- `/onboard:init` — Run the 4-phase guided workflow (analyze, wizard, generate, handoff)
- `/onboard:update` — Check alignment with latest best practices and update tooling
- `/onboard:status` — Quick health check on generated artifacts

Supports Node.js/TypeScript, Python, Go, Rust, Java/Kotlin, Ruby, monorepos, and mixed-language projects.

[Full documentation →](./onboard/README.md)

## notify

Configures Claude Code hooks to send native macOS notifications via `terminal-notifier`. Clicking a notification brings your editor to the foreground.

**Key commands:**

- `/notify:setup` — Install and configure notifications (global or per-project)
- `/notify:status` — Health check and test notifications

Supports custom message text, sounds, and app activation per event type.

[Full documentation →](./notify/README.md)

## devkit

Unified developer workflow toolkit. Run setup once to detect your tooling, then use config-driven skills for committing, reviewing, linting, testing, and shipping code with quality gates.

**Key commands:**

- `/devkit:setup` — Detect tooling and write config (required first step)
- `/devkit:ship` — Full pipeline: test → lint → check → commit
- `/devkit:commit` — Create a commit following your configured style
- `/devkit:review` — Multi-category code review against main
- `/devkit:pr` — Create PR with pre-flight checks

Supports npm, pnpm, yarn, bun, pipenv, poetry, Go, Rust, and Ruby toolchains.

[Full documentation →](./devkit/README.md)

## Recommended Stack

These plugins are designed to work alongside official marketplace companions for a complete AI-driven dev environment. See the [Recommended Stack guide](./docs/recommended-stack.md) for a full workflow map, installation order, and companion plugin pairings — from setup through shipping to monitoring.

## Links

- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code plugins guide](https://docs.anthropic.com/en/docs/claude-code/plugins)

## License

[MIT](./LICENSE)
