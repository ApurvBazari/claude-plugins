# claude-plugins

A curated collection of plugins for [Claude Code](https://code.claude.com/docs/en) — powering AI-driven development and agentic workflows.

## Plugins

| Plugin | Description |
|--------|-------------|
| [onboard](./onboard/) | Analyzes your codebase and generates tailored Claude tooling — CLAUDE.md files, rules, skills, agents, and hooks |
| [forge](./forge/) | Scaffolds new projects with AI-native tooling that evolves with your code |
| [notify](./notify/) | Cross-platform system notifications for Claude Code (macOS + Linux) |

## Quick Start

```bash
# Add the marketplace
claude marketplace add https://github.com/apurvbazari/claude-plugins

# Install a plugin
claude plugin install onboard
```

**Which plugin should I start with?**

- **New project from scratch?** Install `forge` — it scaffolds your app and generates all Claude tooling in one conversation
- **Existing project?** Install `onboard` — it analyzes your codebase and generates Claude tooling tailored to what's already there
- **Already have Claude tooling set up?** Add `notify` for system notifications

**See it in action:**

```
> /onboard:init

Scanning codebase... TypeScript, Next.js 15, Vitest, Tailwind CSS
Wizard: 6 adaptive questions about your workflow and preferences
Generating: CLAUDE.md, 4 rules, 2 skills, 1 agent, 3 hooks

Your project is now set up for AI-assisted development.
```

Each plugin README has a full walkthrough — see [onboard](./onboard/), [forge](./forge/), or [notify](./notify/).

---

## onboard

Bridges traditional development and AI-assisted workflows. Performs deep codebase analysis, walks you through an interactive setup wizard, and generates a full suite of Claude tooling tailored to your project.

**What gets generated:**

- Root and subdirectory `CLAUDE.md` files
- Path-scoped rules (`.claude/rules/*.md`)
- Project-specific skills and agents
- Hook entries for auto-formatting and lint checks
- PR template and commit conventions

**Commands:**

| Command | What it does |
|---------|-------------|
| `/onboard:init` | Full 4-phase workflow: analyze → wizard → generate → handoff |
| `/onboard:update` | Check alignment with latest best practices and update tooling |
| `/onboard:status` | Quick health check on generated artifacts |
| `/onboard:verify` | Independent feature verification via evaluator agent |
| `/onboard:evolve` | Apply pending tooling drift updates |

Supports Node.js/TypeScript, Python, Go, Rust, Java/Kotlin, Ruby, monorepos, and mixed-language projects.

[Full documentation →](./onboard/README.md)

---

## forge

Guided project bootstrapper for Claude Code. Takes you from "I want to build X" to a running application with auto-evolving AI tooling — in one conversation. Think of it as `create-react-app` for the AI-assisted development era.

**4-phase flow:**

```
Phase 1: Context        Phase 2: Scaffold    Phase 3: AI Tooling    Phase 4: Lifecycle
┌────────────────┐     ┌────────────────┐   ┌────────────────┐     ┌────────────────┐
│ Adaptive wizard │ →  │ Scaffold app   │ → │ Claude tooling │ →   │ ADRs, testing  │
│ Stack research  │    │ Git + branching│   │ CI/CD pipelines│     │ strategy, deploy│
│ Preferences     │    │ Verify Hello   │   │ Plugin install │     │ checklists,    │
└────────────────┘     │ World          │   │ Evolution hooks│     │ runbooks       │
                       └────────────────┘   └────────────────┘     │ (optional)     │
                                                                    └────────────────┘
```

**Commands:**

| Command | What it does |
|---------|-------------|
| `/forge:init` | Full 4-phase guided workflow |
| `/forge:evolve` | Apply pending tooling updates from drift detection |

**Prerequisites:** Requires the `onboard` plugin. The `engineering` plugin (optional) enables Phase 4 lifecycle document generation.

Stack-agnostic — works with any technology. Researches your stack via web search rather than relying on built-in templates.

[Full documentation →](./forge/README.md)

---

## notify

Cross-platform system notifications for Claude Code. Get notified when tasks complete, Claude needs your input, or subagents finish work.

**Supported platforms:**

| Platform | Backend | Sound | Click-to-focus |
|----------|---------|-------|----------------|
| macOS | `terminal-notifier` | 14 system sounds | Yes |
| Linux | `notify-send` | Urgency levels | No |

**Commands:**

| Command | What it does |
|---------|-------------|
| `/notify:setup` | Install backend and configure notifications (global or per-project) |
| `/notify:status` | Health check and test notifications |

Notifications show contextual messages extracted from Claude's actual response, not generic text. Each notification displays the current repo and branch as a subtitle. Supports duration filtering to suppress notifications for fast responses.

[Full documentation →](./notify/README.md)

---

## Workflow Guide

These plugins cover different phases of the development lifecycle. Here's how they fit together with companion plugins from the broader Claude Code ecosystem:

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Setup   │ ──→ │ Develop  │ ──→ │  Refine  │ ──→ │   Ship   │ ──→ │ Monitor  │
│          │     │          │     │          │     │          │     │          │
│ onboard  │     │feature-  │     │code-     │     │commit-   │     │ notify   │
│ hookify  │     │dev       │     │simplifier│     │commands  │     │ Native   │
│ forge *  │     │superpow- │     │          │     │pr-review-│     │ OTEL     │
│          │     │ers       │     │          │     │toolkit   │     │          │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
      │                │                                  │
      └────────────────┴──────────────────────────────────┘
                    engineering (cross-phase)
                                                    * = new projects only
```

### Setup

**`onboard`** bootstraps your project's Claude tooling in one pass — CLAUDE.md, rules, skills, agents, hooks. For new projects, **`forge`** scaffolds the entire app, calls onboard for tooling, and optionally generates engineering lifecycle documents (ADRs, testing strategies, deploy checklists) via its Phase 4 integration with the **`engineering`** plugin. After initial setup, **`hookify`** (companion) lets you add behavioral rules incrementally without re-running onboard.

### Develop

The development phase is handled by companion plugins. **`feature-dev`** provides a structured 7-phase workflow: Discovery → Exploration → Clarification → Architecture → Implementation → Review → Handoff. **`superpowers`** adds process discipline — TDD, systematic debugging, planning, and code review skills. **`engineering:system-design`** and **`engineering:testing-strategy`** (companion) complement feature-dev for upfront design and test planning. **`engineering:debug`** provides structured debugging sessions.

### Refine

**`code-simplifier`** (companion) cleans up recently modified code for clarity, consistency, and maintainability. It focuses on what you just changed, keeping refactoring scoped and safe. **`claude-md-management`** (companion) maintains your CLAUDE.md files over time with quality scoring and revision suggestions.

### Ship

**`commit-commands`** (companion) handles git commits and PR creation. **`pr-review-toolkit`** (companion) provides deep specialist review with multiple focused agents — code review, type design analysis, silent failure detection, test coverage analysis, and comment review. **`code-review`** (companion) posts review comments directly on PRs. **`engineering:deploy-checklist`** (companion) provides pre-deployment verification.

### Monitor

**`notify`** sends system notifications when Claude finishes tasks or needs your attention. For usage analytics, Claude Code has **native OpenTelemetry support** — set `OTEL_LOGS_EXPORTER=otlp` to export tool calls, token usage, costs, and session traces to any OTEL backend. **`engineering:incident-response`** and **`engineering:tech-debt`** (companion) help with post-deploy triage and periodic code health audits. **`engineering:standup`** helps track progress across projects.

## Companion Plugins

These are plugins from the broader Claude Code ecosystem that pair well with this collection:

| Plugin | Phase | What It Does |
|--------|-------|-------------|
| `feature-dev` | Develop | Guided 7-phase feature development workflow |
| `superpowers` | All | TDD, systematic debugging, planning, code review skills |
| `engineering` | Setup, Develop, Ship, Monitor | ADRs, system design, deploy checklists, debugging, incident response, tech debt audits, standups, testing strategy, documentation (from `knowledge-work-plugins` marketplace) |
| `product-management` | Setup, Ship | Feature specs/PRDs, roadmap planning, sprint planning, stakeholder updates, competitive analysis (from `knowledge-work-plugins` marketplace) |
| `commit-commands` | Ship | Git commits + PR creation (`/commit`, `/commit-push-pr`) |
| `pr-review-toolkit` | Ship | Multi-agent code review with specialist reviewers |
| `code-review` | Ship | PR review comments |
| `hookify` | Setup | Incremental behavioral rules for Claude Code |
| `security-guidance` | Setup, Develop | Passive hook-based security warnings on file edits |
| `claude-md-management` | Maintain | CLAUDE.md quality scoring and revision |
| `code-simplifier` | Refine | Post-implementation code cleanup |
| `plugin-dev` | Meta | Plugin authoring toolkit (for plugin authors) |
| `skill-creator` | Meta | Skill benchmarking and iteration (for plugin authors) |

## Links

- [Claude Code documentation](https://code.claude.com/docs/en)
- [Claude Code plugins guide](https://code.claude.com/docs/en/plugins)

## License

[MIT](./LICENSE)
