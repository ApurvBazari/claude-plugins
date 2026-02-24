# Changelog

## v0.2.0 — 2026-02-24

### devkit (new plugin)

- Config-driven developer workflow toolkit with setup-first approach
- Tooling detector agent for auto-detecting package manager, test runner, linter, formatter, commit style, and PR templates
- `/devkit:setup` — interactive setup wizard with smart defaults
- `/devkit:commit` — configurable commit style (conventional, simple, ticket, freeform)
- `/devkit:review` — multi-category code review (quality, security, tests, performance)
- `/devkit:lint` — linter with auto-fix support
- `/devkit:test` — multi-mode test runner (all, coverage, watch, specific)
- `/devkit:check` — production readiness scanner (debug, security, performance, quality)
- `/devkit:pr` — PR creation with pre-flight checks and template support
- `/devkit:ship` — configurable pipeline orchestrator (test → lint → check → commit)
- Support for npm, pnpm, yarn, bun, pipenv, poetry, Go, Rust, and Ruby toolchains

## v0.1.0 — 2026-02-24

Initial release with two plugins.

### onboard

- Codebase analyzer agent for deep project scanning
- Interactive wizard with adaptive question flow
- Config generator producing `CLAUDE.md` files, `.claude/rules/`, `.claude/skills/`, `.claude/agents/`, and hook entries
- `/onboard:init`, `/onboard:update`, and `/onboard:status` commands
- Support for Node.js/TypeScript, Python, Go, Rust, Java/Kotlin, Ruby, and monorepos

### notify

- macOS system notifications via `terminal-notifier`
- Task completed, needs attention, and subagent done event types
- Global and per-project install scopes
- Customizable message text, sounds, and app activation
- `/notify:setup` and `/notify:status` commands
