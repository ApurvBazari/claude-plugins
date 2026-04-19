# claude-plugins

> Claude Code plugins for the project lifecycle — `forge` scaffolds new projects, `onboard` keeps AI configs aligned as your code evolves, `notify` closes the loop. Three plugins that work on their own and **compose together**.

Built on top of [Claude Code](https://code.claude.com/docs/en) by Anthropic. Distributed under [MIT](./LICENSE).

---

## Plugins at a glance

| Plugin | What it does | Reach for it when… |
|---|---|---|
| **[forge](./forge/)** | Stack-agnostic greenfield scaffolder — researches your stack via WebSearch, scaffolds the app, then hands off to onboard for Claude tooling. | You're starting a new project from scratch. |
| **[onboard](./onboard/)** | Lifecycle manager for AI configs — generates initial tooling, then **detects code-vs-config drift** as the project evolves and offers to fix it. | You have an existing repo, OR your AI configs are starting to lag behind the code. |
| **[notify](./notify/)** | macOS / Linux system notifications when Claude finishes a task. Duration-filtered so short tasks don't spam you. | You leave Claude running long jobs in the background. |

---

## Quick Start

```bash
# Add the marketplace once
claude plugin marketplace add apurvbazari/claude-plugins
```

Then install the plugin that matches your situation:

**New project from scratch:**

```bash
claude plugin install forge@apurvbazari-plugins
```

> `forge` requires `onboard` for Claude tooling generation — install it as well: `claude plugin install onboard@apurvbazari-plugins`

**Existing project:**

```bash
claude plugin install onboard@apurvbazari-plugins
```

**Optional add-on for either:**

```bash
claude plugin install notify@apurvbazari-plugins
```

---

## Examples

Each plugin's README contains a runnable transcript so you can see what a real session looks like before you install:

- **forge** — full 3-phase scaffold of a Python FastAPI project (Context Gathering → Scaffold → AI Tooling delegation to onboard) → [forge/README.md#example](./forge/README.md#example)
- **onboard** — initial `/onboard:init` on a Next.js 15 project, then `/onboard:evolve` two weeks later detecting drift and proposing updates → [onboard/README.md#example](./onboard/README.md#example)
- **notify** — `/notify:setup` followed by the duration filter suppressing a fast task and delivering a long one → [notify/README.md#example](./notify/README.md#example)

The narrative beat to watch for: forge's Phase 3 calls `Skill(onboard:generate)` rather than reinventing tooling generation. That delegation is the composability story this whole repo is built around.

---

## forge

Guided project bootstrapper. Takes you from *"I want to build X"* to a running application with a complete Claude tooling package — in one conversation.

forge is a **thin orchestrator**. The defining design choice: it delegates all Claude tooling generation to `onboard:generate` rather than reimplementing it. That delegation is the composability story this whole repo is built around.

**Stack-agnostic.** forge researches your stack via WebSearch (current versions, official scaffolders, idiomatic patterns) rather than shipping pre-built templates. Whatever framework you name, forge investigates and uses the canonical CLI for it.

**Prerequisites:** the `onboard` plugin (forge calls it for Phase 3 generation).

For the 3-phase walkthrough, full skill reference (`/forge:init`, `/forge:resume`, `/forge:status`), supported stacks, resumability mechanics, and the runnable Example transcript: [forge/README.md →](./forge/README.md)

---

## onboard

The lifecycle manager for AI-assisted development. Generates Claude tooling on day one, then keeps it aligned as your code evolves.

**Two capabilities, one plugin:**

- **Initial generation** — analyse the codebase, run an adaptive wizard, then emit a full Claude tooling package: `CLAUDE.md` files, path-scoped rules, project-specific skills/agents, hook entries, plugin integration recommendations, and an `.mcp.json` wired to relevant servers.
- **Drift detection (`/onboard:evolve`)** — snapshot the project state at init time, then compare against current state on demand and surface what's out of date: new languages added, new dependencies, structural changes, missing hooks. Propose updates and apply on approval.

The drift loop is the differentiated piece. Auto-generating `CLAUDE.md` is commodity in 2026 — Claude Code's `/init`, GitHub Copilot, OpenAI Codex, Cursor, and several web tools all do it. Maintaining those configs as code grows is what onboard does that nothing else does.

For the full skill reference (5 user-facing skills + the headless `/onboard:generate` API forge consumes), the drift detection deep dive, generated artifact catalog, and supported project types: [onboard/README.md →](./onboard/README.md)

---

## notify

Cross-platform system notifications for Claude Code. macOS via `terminal-notifier`, Linux via `notify-send`. Notifications carry a contextual subtitle (`repo / branch`) and the actual content of Claude's last message — not generic text.

**Genuine differentiator: duration filtering.** `minDurationSeconds` per event suppresses notifications for fast responses, so notify only fires when Claude has actually been working for a while. None of the comparable plugins ship this.

**Honest framing.** notify is intentionally minimal — `terminal-notifier` / `notify-send`, a Stop-hook wrapper, duration filtering, `repo/branch` subtitle. If you need Windows support, webhook fanout (Slack / Discord / Telegram), or typed event categories, the community has richer alternatives:

- [`777genius/claude-notifications-go`](https://github.com/777genius/claude-notifications-go) — Windows + webhook fanout, single Go binary
- [`cfngc4594/agent-notify`](https://github.com/cfngc4594/agent-notify) — covers Claude Code + Cursor + Codex with one config
- [`dazuiba/CCNotify`](https://github.com/dazuiba/CCNotify) and [`mylee04/code-notify`](https://github.com/mylee04/code-notify) — focused macOS options

This plugin is the *"it just works on my machine"* default, not a feature-complete notification platform.

For the full skill reference, install scopes, configuration precedence rules, customisation options (sounds, bundle IDs, duration filter), and troubleshooting: [notify/README.md →](./notify/README.md)

---

## How these plugins fit together

These three plugins cover different phases of the lifecycle. They compose with each other, and they pair with companion plugins from the broader Claude Code ecosystem:

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Setup   │ ─→ │ Develop  │ ─→ │  Refine  │ ─→ │   Ship   │ ─→ │ Monitor  │
│          │    │          │    │          │    │          │    │          │
│ forge*   │    │feature-  │    │code-     │    │commit-   │    │ notify   │
│ onboard  │    │dev       │    │simplifier│    │commands  │    │ Native   │
│ hookify  │    │superpow- │    │          │    │pr-review-│    │ OTEL     │
│          │    │ers       │    │          │    │toolkit   │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
      │              │                                │
      └──────────────┴────────────────────────────────┘
                  engineering (cross-phase)
                                            * forge: new projects only
```

- **Setup** — `onboard` (existing repos) or `forge` (new). Add `hookify` for incremental behavioural rules.
- **Develop** — `feature-dev` for the structured 7-phase workflow; `superpowers` for TDD + systematic debugging discipline.
- **Refine** — `code-simplifier` for post-implementation cleanup; `claude-md-management` for ongoing memory maintenance.
- **Ship** — `commit-commands` for git/PR workflows; `pr-review-toolkit` and `code-review` for specialist PR review.
- **Monitor** — `notify` for desktop alerts; native OpenTelemetry (`OTEL_LOGS_EXPORTER=otlp`) for usage analytics.

---

## Companion plugins

Plugins from the broader Claude Code ecosystem that pair well with this collection. **Marketplace column** tells you where to install from.

| Plugin | Marketplace | Author | What it does |
|---|---|---|---|
| [`feature-dev`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/feature-dev) | `claude-plugins-official` | Anthropic | Guided 7-phase feature development workflow |
| [`superpowers`](https://github.com/obra/superpowers) | `obra/superpowers` | Jesse Vincent | TDD, systematic debugging, planning, and review skills |
| [`engineering`](https://github.com/anthropics/knowledge-work-plugins) | `knowledge-work-plugins` | Anthropic | ADRs, system design, deploy checklists, debugging, incident response, tech-debt, standups |
| [`product-management`](https://github.com/anthropics/knowledge-work-plugins) | `knowledge-work-plugins` | Anthropic | Feature specs / PRDs, roadmap, sprint planning, stakeholder updates |
| [`commit-commands`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/commit-commands) | `claude-plugins-official` | Anthropic | Git commits + PR creation (`/commit`, `/commit-push-pr`) |
| [`pr-review-toolkit`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/pr-review-toolkit) | `claude-plugins-official` | Anthropic | Multi-agent code review with specialist reviewers |
| [`code-review`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-review) | `claude-plugins-official` | Anthropic | Automated PR review with confidence-based scoring |
| [`hookify`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/hookify) | `claude-plugins-official` | Anthropic | Build hooks from conversation patterns or explicit rules |
| [`security-guidance`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance) | `claude-plugins-official` | Anthropic | Passive hook-based security warnings on file edits |
| [`claude-md-management`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) | `claude-plugins-official` | Anthropic | CLAUDE.md quality scoring and revision |
| [`code-simplifier`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-simplifier) | `claude-plugins-official` | Anthropic | Post-implementation code cleanup |
| [`plugin-dev`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/plugin-dev) | `claude-plugins-official` | Anthropic | Plugin authoring toolkit (7 expert skills) |
| [`skill-creator`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) | `claude-plugins-official` | Anthropic | Skill benchmarking and iteration |
| [`frontend-design`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design) | `claude-plugins-official` | Anthropic | Production-grade frontend interface generation |
| [`context7`](https://github.com/upstash/context7) | `claude-plugins-official` | Upstash | Up-to-date documentation lookup from source repos |
| [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) | `claude-plugins-official` | Google ChromeDevTools | Live Chrome browser control + performance traces |

> Each marketplace requires its own `claude plugin marketplace add` command. The two referenced above are `anthropics/claude-plugins-official` (auto-available in every Claude Code session) and `anthropics/knowledge-work-plugins`. Community marketplaces like `obra/superpowers` need explicit `marketplace add`. Current as of 2026-04-19 — see each marketplace for the authoritative list.

---

## Acknowledgements

### Claude Code & Anthropic

Built on top of [Claude Code](https://code.claude.com/docs/en) by **Anthropic** — the plugin system, the SKILL.md spec, the `Skill` tool, hook events, and the [`claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) marketplace this collection extends. The [`knowledge-work-plugins`](https://github.com/anthropics/knowledge-work-plugins) marketplace (also Anthropic) ships `engineering` and `product-management`, which appear in our Workflow guide.

### Built-in skills referenced by generated tooling

When `onboard` writes its `Plugin Integration` section, it recommends a curated set of skills that ship as Claude Code built-ins (no plugin install required). Source of truth: [`onboard/skills/generation/references/built-in-skills-catalog.md`](./onboard/skills/generation/references/built-in-skills-catalog.md).

- **Core (always recommended)**: `/loop`, `/simplify`, `/debug`, `/pr-summary`
- **Conditionally recommended** (only when project signals justify it): `/schedule`, `/claude-api`, `/explain-code`, `/codebase-visualizer`, `/batch`

A note on accuracy: a 2026-04 web audit confirmed `/loop`, `/simplify`, `/debug`, `/claude-api`, `/batch`, and `/codebase-visualizer` as Anthropic-shipped built-ins; `/pr-summary`, `/schedule`, and `/explain-code` were not surfaced as built-ins in that audit and may have moved to a plugin or been renamed in your Claude Code version. If you find a discrepancy, please open an issue — the catalog is what we keep honest.

### Companion plugin authors

Companion plugins from the [Anthropic-curated `claude-plugins-official` marketplace](https://github.com/anthropics/claude-plugins-official): `feature-dev`, `commit-commands`, `pr-review-toolkit`, `code-review`, `hookify`, `security-guidance`, `claude-md-management`, `code-simplifier`, `plugin-dev`, `skill-creator`, `frontend-design`. From the [`knowledge-work-plugins`](https://github.com/anthropics/knowledge-work-plugins) marketplace (also Anthropic): `engineering`, `product-management`.

Community plugins (each linked to its upstream repo in the table above):
- **`superpowers`** — Jesse Vincent ([@obra](https://github.com/obra))
- **`context7`** — Upstash
- **`chrome-devtools-mcp`** — Google ChromeDevTools team

### OSS utilities our scripts depend on

- [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) — macOS notifications (MIT, Julien Blanchard et al.)
- [`notify-send` / `libnotify`](https://gitlab.gnome.org/GNOME/libnotify) — Linux notifications (LGPL, GNOME)
- [`jq`](https://jqlang.org) — JSON parsing in hooks (MIT, Stephen Dolan)
- [`tree`](http://mama.indstate.edu/users/ice/tree/) — directory listing in codebase analysis (GPL, Steve Baker)
- [`git`](https://git-scm.com) — repo + branch context for notification subtitles
- `python3` — fallback JSON parser when `jq` is absent
- `claude` CLI — used by `onboard/scripts/install-plugins.sh` to drive plugin installation
- Bash ≥ 4 — all scripts use `#!/usr/bin/env bash` and `set -euo pipefail` (utility scripts) or `exit 0` (hook scripts)

> LGPL/GPL utilities (`libnotify`, `tree`) are invoked at runtime, not linked or distributed — the MIT licence on this repo is unaffected.

---

## Links

- [Claude Code documentation](https://code.claude.com/docs/en)
- [Plugins guide](https://code.claude.com/docs/en/plugins)
- [Plugin marketplaces guide](https://code.claude.com/docs/en/plugin-marketplaces)
- [`claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) — Anthropic-managed marketplace this collection extends

## License

[MIT](./LICENSE)
