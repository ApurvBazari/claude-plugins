# Changelog

## v0.1.0 — 2026-02-24

Initial release with two plugins.

### claude-onboard

- Codebase analyzer agent for deep project scanning
- Interactive wizard with adaptive question flow
- Config generator producing `CLAUDE.md` files, `.claude/rules/`, `.claude/skills/`, `.claude/agents/`, and hook entries
- `/claude-onboard:init`, `/claude-onboard:update`, and `/claude-onboard:status` commands
- Support for Node.js/TypeScript, Python, Go, Rust, Java/Kotlin, Ruby, and monorepos

### claude-notify

- macOS system notifications via `terminal-notifier`
- Task completed, needs attention, and subagent done event types
- Global and per-project install scopes
- Customizable message text, sounds, and app activation
- `/claude-notify:setup` and `/claude-notify:notify-status` commands
