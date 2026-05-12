# mattpocock-skills

A curated subset of [Matt Pocock's engineering skills](https://github.com/mattpocock/skills), vendored into the `apurvbazari-plugins` Claude Code marketplace so they can be installed via the standard `claude plugin install` path.

## Why this exists

Upstream `mattpocock/skills` is a single-plugin GitHub repo without a `.claude-plugin/marketplace.json`. Four pull requests proposing one (mattpocock/skills#8, #32, #40, #41) were all closed by the maintainer. Without `marketplace.json` upstream, `claude plugin marketplace add mattpocock/skills` doesn't resolve and the skills can't be installed through the standard CLI flow.

This plugin wraps a hand-picked subset of those skills so they install cleanly:

```bash
claude plugin marketplace add ApurvBazari/claude-plugins
claude plugin install mattpocock-skills@apurvbazari-plugins
```

## What's included

| Skill | What it does |
|---|---|
| `grill-me` | Interview the user relentlessly about a plan or design until shared understanding is reached, resolving each branch of the decision tree |
| `grill-with-docs` | Same as `grill-me` but also maintains `CONTEXT.md` (shared domain language) and `docs/adr/` inline as decisions crystallise |
| `setup-matt-pocock-skills` | Configures `AGENTS.md`/`CLAUDE.md` skill block, picks an issue-tracker mode (GitHub / GitLab / local files), defines triage label vocabulary, and sets the docs directory. Required for `grill-with-docs`, `triage`, and `to-issues` (not vendored) to work fully |
| `triage` | Issue triage state machine driven by triage roles |
| `prototype` | Build a throwaway prototype to flesh out a design before committing |
| `zoom-out` | Tell the agent to step back and give broader context |
| `handoff` | Compact the current conversation into a handoff document for another agent to pick up |
| `improve-codebase-architecture` | Find deepening opportunities in a codebase, informed by domain language in `CONTEXT.md` and decisions in `docs/adr/` |

## What's NOT included (and why)

| Skill | Why excluded |
|---|---|
| `to-prd` | Overlaps with `superpowers:brainstorming` for spec/design generation; the unique value is publishing to issue trackers — narrow use case |
| `to-issues` | Overlaps with `superpowers:writing-plans` for breakdown; same narrow tracker-publishing scope |
| `tdd` | Would shadow `superpowers:test-driven-development` |
| `diagnose` | Would shadow `superpowers:systematic-debugging` |
| `write-a-skill` | Overlaps with `plugin-dev:skill-development` and `skill-creator` plugins |
| `caveman` | Off-mission — token-compression mode unrelated to scaffolding/planning |

If you want any of these, clone upstream directly: `git clone https://github.com/mattpocock/skills && claude --plugin-dir ./skills` for per-session use.

## Provenance

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream license**: MIT (preserved verbatim in `LICENSE`)
- **Vendored from SHA**: `f304057d61d3df3c9fd992ac2b6e3833cb9325fb` (2026-05-12)
- **Vendor scope**: 8 of 14 skills, copied without modification — companion `.md` files (e.g., `LOGIC.md`, `CONTEXT-FORMAT.md`) preserved alongside each `SKILL.md` to keep upstream's internal references intact

## Keeping in sync with upstream

Run `scripts/sync-from-upstream.sh` to diff vendored files against the upstream HEAD and report drift. The script is non-destructive — it shows what changed and exits; pulling updates is a manual step.

```bash
./mattpocock-skills/scripts/sync-from-upstream.sh
```

Bump `mattpocock-skills/.claude-plugin/plugin.json` `version` when you pull updates, and update the **Vendored from SHA** line above.

## Attribution

All skill content is © 2026 Matt Pocock under the MIT License. This package adds nothing to the skills themselves — it only repackages them as an installable Claude Code marketplace plugin. If you find these skills valuable, follow [@mattpocockuk](https://github.com/mattpocock) and [aihero.dev](https://www.aihero.dev/) for new ones.
