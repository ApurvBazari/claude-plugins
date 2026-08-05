# claude-plugins

Claude Code plugin marketplace by Apurv Bazari. Five plugins — all markdown + shell + JSON, no compiled code. (onboard, notify, handoff, walkthrough, lens.)

## Repository

- GitHub: `ApurvBazari/claude-plugins` (public)
- Marketplace: `apurvbazari-plugins` (registered in `.claude-plugin/marketplace.json`)

## Architecture

```
.claude-plugin/marketplace.json          ← plugin registry
         │
         ├──→ onboard/                   ← codebase analyzer + tooling generator
         │      ├── skills/ (start, adopt, generate, update, check, verify, evolve,
         │      │           research, wizard, generation)
         │      ├── agents/ (codebase-analyzer, config-generator, feature-evaluator,
         │      │           research-specialist, research-verifier)
         │      └── scripts/ (detect-{config,dep,structure}-changes, detect-{lsp,mcp}-signals, audit-tooling, install-plugins)
         │
         ├──→ notify/                    ← cross-platform system notifications
         │      ├── skills/ (setup, check, uninstall, wizard)
         │      └── scripts/ (notify, install-notifier)
         │
         ├──→ handoff/                   ← session handoff continuity
         │      └── skills/ (save, pickup, check, discard)
         │
         ├──→ walkthrough/               ← session → self-contained interactive HTML
         │      └── skills/ (create, update, document, render)
         │
         └──→ lens/                      ← intent-grounded review companion (brain; renders via walkthrough)
                ├── skills/ (review, engine, render-review, capability)
                ├── agents/ (spec-adherence, plan-adherence, correctness,
                │           risk-classify, test-gaps, verifier)
                └── schemas/ (review-findings)
                    (runtime: hands off to walkthrough:render; markdown fallback if absent)
```

## Plugin Structure Convention

Every plugin must have:
- `.claude-plugin/plugin.json` — manifest with name, version, description, author, license, keywords
- `README.md` — user-facing documentation
- At least one of: `skills/`, `agents/`

Components live at the plugin root, NOT inside `.claude-plugin/`. Only `plugin.json` goes in `.claude-plugin/`.

Skills are the authoring form for all user-facing entrypoints and internal orchestration. Legacy `commands/` directories are no longer used — per [Claude Code docs](https://code.claude.com/docs/en/skills.md), commands have been merged into skills. A file at `commands/<name>.md` and a skill at `skills/<name>/SKILL.md` both create the `/<plugin>:<name>` slash entry, but only skills support frontmatter (`user-invocable`, `disable-model-invocation`), reference directories, and model-driven auto-invocation.

## File Type Conventions

| Type | Pattern | Key requirements |
|------|---------|-----------------|
| Skills | `skills/<name>/SKILL.md` | YAML frontmatter (`name`, `description`, optional `user-invocable`/`disable-model-invocation`), H1 title, Guard section (if applicable), numbered steps, Key Rules section |
| Agents | `agents/<name>.md` | H1 name, Tools section, Instructions with numbered steps, Output Format |
| Shell scripts | `scripts/<name>.sh` | `#!/usr/bin/env bash`, `set -euo pipefail`, ShellCheck-clean, POSIX compat |
| Manifests | `.claude-plugin/plugin.json` | Required: name, version, description, author, license, keywords |
| References | `skills/<name>/references/*.md` (skill-owned) or `agents/references/*.md` (agent-owned) | Supporting docs loaded by skill or agent instructions. A reference lives with whatever owns it: colocate with the skill that loads it; use the plugin's flat `agents/references/` home when the consumer is an agent rather than a skill. `check-references.sh` walks both. |

## Skill Frontmatter Categories

Apply the right invocation policy per skill:

| Category | Who invokes | Frontmatter | Examples |
|---|---|---|---|
| Destructive / setup | User only (explicit) | `disable-model-invocation: true` | `onboard:start`, `onboard:update`, `notify:setup`, `notify:uninstall` |
| Read-only helpers | User + auto | (default) — write a specific `description` | `onboard:check`, `onboard:verify`, `onboard:evolve`, `notify:check` |
| Programmatic API | Claude only, hidden | `user-invocable: false` | `onboard:generate` |
| Internal building blocks | Claude only, hidden | `user-invocable: false` | `wizard`, `generation` |

Canonical frontmatter spelling is **hyphenated** (`user-invocable`, `disable-model-invocation`) per the Claude Code docs. Underscore spelling is silently ignored.

## Naming Conventions

- File names: kebab-case (`codebase-analyzer.md`, `validate-bash.sh`)
- Plugin directories: lowercase (`onboard`, `notify`, `handoff`)
- Manifest names: match directory name
- References: always in a `references/` subdirectory owned by their consumer — inside the skill (`skills/<name>/references/`) for skill-loaded docs, or the plugin's flat `agents/references/` for agent-loaded docs
- Skill `name` frontmatter: lowercase letters, numbers, hyphens only (max 64 chars). If omitted, derives from the directory name.

## Quality Checks

- ShellCheck on all `.sh` scripts: `shellcheck scripts/*.sh`
- JSON validation on manifests: verify required fields in plugin.json + marketplace.json
- Reference integrity: every file referenced in skills/agents must exist
- Run `/validate` to check all plugins at once

## Documentation URL convention

When referencing Claude Code documentation in any plugin file, use the current home `https://code.claude.com/docs/en/*`. The legacy `https://docs.anthropic.com/en/docs/claude-code/*` URLs 301-redirect and waste turns when programmatic WebFetch calls don't follow redirects (release-gate finding A6, 2026-04-16).

## Git Discipline

- Conventional commits: `type(scope): description` — types: `feat`, `fix`, `refactor`, `docs`, `chore`
- Branch naming: `type/short-description` (e.g., `feat/notify-setup`, `fix/notify-subtitle`)
- One logical change per commit — don't mix plugin changes across plugins
- Scope = plugin name when change is plugin-specific (e.g., `feat(onboard): add verify skill`)

## Branching & Release

Two branches: `develop` (integration) and `main` (release). **`main` is the GitHub default branch** — it is what the published marketplace serves, so a fresh `/plugin marketplace add ApurvBazari/claude-plugins` installs released code, not in-flight work.

- Feature branches → PR to `develop` (squash merge). Pass `--base develop` explicitly — `gh pr create` targets `main` by default now.
- When ready to ship: PR from `develop` → `main` (**merge commit, never squash**)
- After shipping: merge `main` back into `develop` (merge commit) to keep them in sync

Version bumps are manual — bump `plugin.json` + `marketplace.json` + `CHANGELOG.md` in the feature PR. No release-please or automated version management.

Squash-merging develop→main causes permanent divergence — the two branches lose their shared history and can never cleanly sync again.

## Adding a New Plugin

1. Create `<plugin>/` directory with `.claude-plugin/plugin.json`, `README.md`, and at least one skill
2. Add entry to `.claude-plugin/marketplace.json` — version must match plugin.json
3. Create `<plugin>/CLAUDE.md` documenting internal conventions
4. Follow patterns from existing plugins — use onboard as the most complete reference
