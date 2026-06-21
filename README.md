# claude-plugins

> Sharp, honest tooling that makes Claude Code's work visible and verifiable. Claude Code plugins for the project lifecycle — `onboard` keeps AI configs aligned as your code evolves, `notify` closes the loop, `handoff` carries session intent across context boundaries, `walkthrough` turns a session into an explorable document, and `lens` reviews work against its spec before it ships. Five plugins that work on their own and **compose together**.

Built on top of [Claude Code](https://code.claude.com/docs/en) by Anthropic. Distributed under [MIT](./LICENSE).

**Docs site:** [apurvbazari.github.io/claude-plugins](https://apurvbazari.github.io/claude-plugins/) — a landing page plus one page per plugin (generated from these READMEs by [`walkthrough`](./walkthrough/)).

---

## Plugins at a glance

| Plugin | What it does | Reach for it when… |
|---|---|---|
| **[onboard](./onboard/)** | Lifecycle manager for AI configs — generates initial tooling, then **detects code-vs-config drift** as the project evolves and offers to fix it. | You have an existing repo, OR your AI configs are starting to lag behind the code. |
| **[notify](./notify/)** | macOS / Linux system notifications when Claude finishes a task. Duration-filtered so short tasks don't spam you. | You leave Claude running long jobs in the background. |
| **[handoff](./handoff/)** | Save the directive of a wrap-up session, then auto-surface it at the next SessionStart with an Execute / Edit / Discard / Save-for-later prompt. | You end sessions by pasting "continue this work in the new window" prompts into the next session. |
| **[walkthrough](./walkthrough/)** | Render the current session as a self-contained interactive HTML document with diagrams and clickable detail. | You want a readable, shareable artifact of a session instead of scrolling back through the transcript. |
| **[lens](./lens/)** | Intent-grounded review companion — reviews the session's diff **against the spec and plan it was meant to follow**, adversarially verifies the findings, and renders an interactive review. | You've finished a change and want a second, intent-aware opinion before you commit, push, or open a PR. |

---

## Commands

Every user-invocable command across the five plugins (internal building-block skills with `user-invocable: false` are omitted — these are the ones you invoke directly):

| Plugin | Commands |
|---|---|
| **onboard** | `/onboard:start` · `/onboard:check` · `/onboard:evolve` · `/onboard:update` · `/onboard:verify` |
| **notify** | `/notify:setup` · `/notify:check` · `/notify:uninstall` |
| **handoff** | `/handoff:save` · `/handoff:pickup` · `/handoff:check` · `/handoff:discard` |
| **walkthrough** | `/walkthrough:create` · `/walkthrough:document` · `/walkthrough:update` |
| **lens** | `/lens:review` |

---

## Quick Start

You can install from **two marketplaces**, depending on what you need:

### Option A — install from Anthropic's community marketplace (`onboard`, `notify`)

`onboard` and `notify` are mirrored in [`anthropics/claude-plugins-community`](https://github.com/anthropics/claude-plugins-community), Anthropic's reviewed community directory. This route gives you snapshots that have passed Anthropic's automated security scan and have auto-update enabled by default. Discoverable via `/plugin` → **Discover** tab.

```bash
# Add Anthropic's community marketplace
claude plugin marketplace add anthropics/claude-plugins-community

# Install
claude plugin install onboard@claude-community
claude plugin install notify@claude-community
```

### Option B — install from `apurvbazari-plugins` (all five plugins, latest commit)

This route always serves the latest commit when you want changes ahead of the community marketplace's nightly snapshot, and is the only route for `handoff`, `walkthrough`, and `lens`.

```bash
# Add this marketplace
claude plugin marketplace add apurvbazari/claude-plugins
```

**Existing project:**

```bash
claude plugin install onboard@apurvbazari-plugins
```

**Optional add-ons:**

```bash
claude plugin install notify@apurvbazari-plugins
claude plugin install handoff@apurvbazari-plugins
claude plugin install walkthrough@apurvbazari-plugins
claude plugin install lens@apurvbazari-plugins
```

---

## Examples

Each plugin's README contains a runnable transcript so you can see what a real session looks like before you install:

- **onboard** — initial `/onboard:start` on a Next.js 15 project, then `/onboard:evolve` two weeks later detecting drift and proposing updates → [onboard/README.md#example](./onboard/README.md#example)
- **notify** — `/notify:setup` followed by the duration filter suppressing a fast task and delivering a long one → [notify/README.md#example](./notify/README.md#example)
- **handoff** — saying "save handoff" mid-conversation, confirming the auto-save, then a fresh session starting with the four-option resume prompt → [handoff/README.md](./handoff/README.md)
- **walkthrough** — running `/walkthrough:create` after a feature, getting one self-contained HTML file with diagrams, decision records, and a dark/light toggle → [walkthrough/README.md](./walkthrough/README.md)

---

## onboard

The lifecycle manager for AI-assisted development. Generates Claude tooling on day one, then keeps it aligned as your code evolves.

**Two capabilities, one plugin:**

- **Initial generation** — analyse the codebase, run an adaptive wizard, then emit a full Claude tooling package: `CLAUDE.md` files, path-scoped rules, project-specific skills/agents, hook entries, plugin integration recommendations, and an `.mcp.json` wired to relevant servers.
- **Drift detection (`/onboard:evolve`)** — snapshot the project state at init time, then compare against current state on demand and surface what's out of date: new languages added, new dependencies, structural changes, missing hooks. Propose updates and apply on approval.

The drift loop is onboard's focus. Generating `CLAUDE.md` is well-covered in 2026 — Claude Code's `/init`, GitHub Copilot, OpenAI Codex, Cursor, and several web tools all do it. onboard's emphasis is the step after: keeping those configs aligned as the code grows.

For the full skill reference, the drift detection deep dive, generated artifact catalog, and supported project types: [onboard/README.md →](./onboard/README.md)

---

## notify

Cross-platform system notifications for Claude Code. macOS via `terminal-notifier`, Linux via `notify-send`. Notifications carry a contextual subtitle (`repo / branch`) and the actual content of Claude's last message — not generic text.

**Duration filtering.** `minDurationSeconds` per event suppresses notifications for fast responses, so notify only fires when Claude has actually been working for a while.

**Honest framing.** notify is intentionally minimal — `terminal-notifier` / `notify-send`, a Stop-hook wrapper, duration filtering, `repo/branch` subtitle. If you need Windows support, webhook fanout (Slack / Discord / Telegram), or typed event categories, the community has richer alternatives:

- [`777genius/claude-notifications-go`](https://github.com/777genius/claude-notifications-go) — Windows + webhook fanout, single Go binary
- [`cfngc4594/agent-notify`](https://github.com/cfngc4594/agent-notify) — covers Claude Code + Cursor + Codex with one config
- [`dazuiba/CCNotify`](https://github.com/dazuiba/CCNotify) and [`mylee04/code-notify`](https://github.com/mylee04/code-notify) — focused macOS options

This plugin is the *"it just works on my machine"* default, not a feature-complete notification platform.

For the full skill reference, install scopes, configuration precedence rules, customisation options (sounds, bundle IDs, duration filter), and troubleshooting: [notify/README.md →](./notify/README.md)

---

## handoff

Long Claude Code sessions often end with the user pasting a paragraph into the *next* session window to continue the work. That paragraph is reproducible — it's just "the directive of where we left off". `handoff` captures it at end-of-session and surfaces it at the start of the next, with a confirmation gate at both ends.

**Two ends of the loop:**

- **Save** — `/handoff:save` (or auto-invoked on phrases like *"pick this up later"* / *"continue in new session"*). Confirms via `AskUserQuestion` before writing — false-positive triggers are zero-cost.
- **Resume** — SessionStart hook surfaces a saved handoff, then routes to `/handoff:pickup` which asks: **Execute / Edit / Discard / Save-for-later**. Snooze defers re-surface for 24h; 90-day stale handoffs auto-archive. Git-activity tags ("3 commits past saved-at", "branch changed") inform the user's choice without dictating it.

**Trust model.** Directive content is wrapped in `<untrusted-source>` framing in the hook output — routing and metadata are trusted, the directive itself is data describing user intent. The four-option flow ensures the user confirms before any action. Standard defense-in-depth for a marketplace plugin.

For the full skill reference (`/handoff:save`, `/handoff:pickup`, `/handoff:check`, `/handoff:discard`), the SessionStart hook contract, configuration knobs (`stale-day-threshold`, `deferral-snooze-hours`, `trigger-phrases`), and storage model: [handoff/README.md →](./handoff/README.md)

---

## walkthrough

After a long session — a debugging marathon, a feature, an architecture decision — the record of what happened is buried in the transcript. `walkthrough` renders the current session as a self-contained interactive HTML document with diagrams and clickable detail: a synthesized model of the work, not a transcript dump.

**One skill, one artifact:**

- **Generate** — `/walkthrough:create [focus]` (or auto-invoked on phrases like *"visualize this session"* / *"make a session recap"*). The optional `focus` arg scopes the synthesis. Output is one HTML file in `.claude/walkthrough/`, with a gitignore prompt on first run.
- **Explore** — open the file in any browser: summary, inline-SVG architecture diagrams, decision records, a file-touch list with real `path:line` refs, timeline, and metrics, with expandable detail and an in-document dark / warm-light theme toggle.

**Self-contained.** All CSS, JS, and SVG are inlined; the only external resource is one Google Fonts `@import`. The file renders without the plugin, a server, or a build step — copy it anywhere. It's a snapshot of one session, not a live viewer, and it synthesizes a structured model rather than pasting the message log.

**One house style, open component system.** Every walkthrough shares a fixed design system (tokens only, two themes). The component catalog is a floor, not a ceiling — when content fits no catalog entry, a bespoke component is composed from the same primitives so it still looks native; empty sections are omitted, not stubbed.

For the skill reference, the design-system invariant, the 5-stage render pipeline, and the storage model: [walkthrough/README.md →](./walkthrough/README.md)

---

## lens

Review Claude's work **before it ships** — against the spec and plan it was meant to follow. `lens` runs inside the live session that produced the code, so it can ask the question a diff-only reviewer can't: *did this build what was actually asked, and did it follow the plan?* A bug-free implementation of the **wrong** spec is the failure `/code-review` and external PR bots can never catch.

**Brain and eyes.** lens is the brain — it judges (scope → intent → analyze → adversarially verify → assemble). [`walkthrough`](./walkthrough/) is the eyes — lens hands its structured findings to `walkthrough:render` for an interactive HTML review, and degrades to a self-contained markdown report when walkthrough isn't installed. Neither plugin imports the other.

**Read-only by contract.** lens never commits, edits, stages, or blocks — it reads the diff and source, verifies its findings adversarially, and renders a review for a human to act on. You decide what to do with it.

For the full five-stage pipeline, the 3-tier finder registry, the optional read-only adapters, and state-aware re-review: [lens/README.md →](./lens/README.md)

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

`onboard` and `notify` are also mirrored in Anthropic's reviewed community directory, [`anthropics/claude-plugins-community`](https://github.com/anthropics/claude-plugins-community) — see Quick Start above for the install commands.

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

- [Documentation site](https://apurvbazari.github.io/claude-plugins/) — landing + a page per plugin
- [Claude Code documentation](https://code.claude.com/docs/en)
- [Plugins guide](https://code.claude.com/docs/en/plugins)
- [Plugin marketplaces guide](https://code.claude.com/docs/en/plugin-marketplaces)
- [`claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) — Anthropic-managed marketplace this collection extends
- [`claude-plugins-community`](https://github.com/anthropics/claude-plugins-community) — Anthropic's reviewed community directory; mirrors `onboard` + `notify`
- [Contributing guide](./CONTRIBUTING.md) — how to add a plugin, branching/release flow, versioning, validation

## License

[MIT](./LICENSE)
