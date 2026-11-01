# Companion plugins and credits

Detail moved out of the root [README](./README.md).

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

## Credits

### Claude Code & Anthropic

Built on top of [Claude Code](https://code.claude.com/docs/en) by **Anthropic** — the plugin system, the SKILL.md spec, the `Skill` tool, hook events, and the [`claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) marketplace this collection extends. The [`knowledge-work-plugins`](https://github.com/anthropics/knowledge-work-plugins) marketplace (also Anthropic) ships `engineering` and `product-management`, which appear in our Workflow guide.

`onboard` and `notify` are listed in Anthropic's plugin directory, which Claude Code also reads as the [`anthropics/claude-plugins-community`](https://github.com/anthropics/claude-plugins-community) marketplace. The [README](./README.md#install) has the install steps.

### Built-in skills referenced by generated tooling

When `onboard` writes its `Plugin Integration` section, it points to Claude Code's own bundled skills and commands where your project fits them, such as `/simplify`, `/debug` and `/loop`. It names only commands that ship with Claude Code, checked against the [commands reference](https://code.claude.com/docs/en/commands). The list lives in [`built-in-skills-catalog.md`](https://github.com/ApurvBazari/claude-plugins/blob/main/onboard/skills/generation/references/catalogs/built-in-skills-catalog.md).

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
- `python3` — runs onboard's maintain scripts
- `claude` CLI — used by `onboard/scripts/install-plugins.sh` to drive plugin installation
- Bash ≥ 4 — all scripts use `#!/usr/bin/env bash` and `set -euo pipefail` (utility scripts) or `exit 0` (hook scripts)

> LGPL/GPL utilities (`libnotify`, `tree`) are invoked at runtime, not linked or distributed — the MIT licence on this repo is unaffected.
