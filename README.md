# claude-plugins

A curated collection of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — powering AI-driven development and agentic workflows.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [claude-onboard](./claude-onboard/) | Analyzes your codebase and generates tailored Claude tooling — `CLAUDE.md` files, rules, skills, agents, and hooks — through an interactive wizard |
| [claude-notify](./claude-notify/) | macOS system notifications for Claude Code — get notified when tasks complete, Claude needs input, or subagents finish |

## Quick Start

```bash
# Add the marketplace
claude marketplace add https://github.com/apurvbazari/claude-plugins

# Install a plugin
claude plugin install claude-onboard
```

## claude-onboard

Bridges traditional development and AI-assisted workflows. Performs deep codebase analysis, walks you through an interactive setup, and generates a full suite of Claude tooling tailored to your project.

**Key commands:**

- `/claude-onboard:init` — Run the 4-phase guided workflow (analyze, wizard, generate, handoff)
- `/claude-onboard:update` — Check alignment with latest best practices and update tooling
- `/claude-onboard:status` — Quick health check on generated artifacts

Supports Node.js/TypeScript, Python, Go, Rust, Java/Kotlin, Ruby, monorepos, and mixed-language projects.

[Full documentation →](./claude-onboard/README.md)

## claude-notify

Configures Claude Code hooks to send native macOS notifications via `terminal-notifier`. Clicking a notification brings your editor to the foreground.

**Key commands:**

- `/claude-notify:setup` — Install and configure notifications (global or per-project)
- `/claude-notify:notify-status` — Health check and test notifications

Supports custom message text, sounds, and app activation per event type.

[Full documentation →](./claude-notify/README.md)

## Links

- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code plugins guide](https://docs.anthropic.com/en/docs/claude-code/plugins)

## License

[MIT](./LICENSE)
