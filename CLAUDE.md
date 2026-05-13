# claude-plugins

Claude Code plugin marketplace by Apurv Bazari. Four plugins — all markdown + shell + JSON, no compiled code.

## Repository

- GitHub: `ApurvBazari/claude-plugins` (public)
- Marketplace: `apurvbazari-plugins` (registered in `.claude-plugin/marketplace.json`)

## Architecture

```
.claude-plugin/marketplace.json          ← plugin registry
         │
         ├──→ onboard/                   ← codebase analyzer + tooling generator
         │      ├── skills/ (init, generate, update, status, verify, evolve,
         │      │           wizard, analysis, generation)
         │      ├── agents/ (codebase-analyzer, config-generator, feature-evaluator)
         │      └── scripts/ (analyze-structure, detect-stack, measure-complexity)
         │
         ├──→ greenfield/                ← project scaffolder with AI-native tooling
         │      ├── skills/ (init, resume, status, context-gathering, scaffolding,
         │      │           tooling-generation, plugin-discovery, lifecycle-setup)
         │      └── agents/ (stack-researcher, scaffold-analyzer)
         │
         ├──→ notify/                    ← cross-platform system notifications
         │      ├── skills/ (setup, status, uninstall, wizard)
         │      └── scripts/ (notify, install-notifier, test-notification)
         │
         └──→ mattpocock-skills/          ← vendored subset of mattpocock/skills (MIT)
                ├── skills/ (grill-me, grill-with-docs, setup-matt-pocock-skills,
                │           triage, prototype, zoom-out, handoff,
                │           improve-codebase-architecture)
                └── scripts/ (sync-from-upstream)
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
| References | `skills/<name>/references/*.md` | Supporting docs loaded by skill instructions |

## Skill Frontmatter Categories

Apply the right invocation policy per skill:

| Category | Who invokes | Frontmatter | Examples |
|---|---|---|---|
| Destructive / setup | User only (explicit) | `disable-model-invocation: true` | `onboard:start`, `onboard:update`, `greenfield:start`, `notify:setup`, `notify:uninstall` |
| Read-only helpers | User + auto | (default) — write a specific `description` | `onboard:check`, `onboard:verify`, `onboard:evolve`, `greenfield:pickup`, `greenfield:check`, `notify:check` |
| Programmatic API | Claude only, hidden | `user-invocable: false` | `onboard:generate` (invoked by greenfield via Skill tool) |
| Internal building blocks | Claude only, hidden | `user-invocable: false` | `wizard`, `analysis`, `generation`, `context-gathering`, `scaffolding`, `plugin-discovery`, `tooling-generation`, `lifecycle-setup` |

Canonical frontmatter spelling is **hyphenated** (`user-invocable`, `disable-model-invocation`) per the Claude Code docs. Underscore spelling is silently ignored.

## Naming Conventions

- File names: kebab-case (`codebase-analyzer.md`, `validate-bash.sh`)
- Plugin directories: lowercase (`onboard`, `greenfield`, `notify`)
- Manifest names: match directory name
- Skill references: always in `references/` subdirectory inside the skill
- Skill `name` frontmatter: lowercase letters, numbers, hyphens only (max 64 chars). If omitted, derives from the directory name.

## Cross-Plugin Integration

- **greenfield → onboard**: greenfield delegates all Claude tooling generation to onboard's headless `generate` skill (invoked via Skill tool as `onboard:generate`)
- **greenfield → notify**: greenfield-scaffolded projects can include notify configuration as part of plugin discovery

## Quality Checks

- ShellCheck on all `.sh` scripts: `shellcheck scripts/*.sh`
- JSON validation on manifests: verify required fields in plugin.json + marketplace.json
- Reference integrity: every file referenced in skills/agents must exist
- Run `/validate` to check all plugins at once

## Documentation URL convention

When referencing Claude Code documentation in any plugin file, use the current home `https://code.claude.com/docs/en/*`. The legacy `https://docs.anthropic.com/en/docs/claude-code/*` URLs 301-redirect and waste turns when programmatic WebFetch calls don't follow redirects (release-gate finding A6, 2026-04-16). Full mapping + verification recipe in `docs/url-conventions.md`.

## Git Discipline

- Conventional commits: `type(scope): description` — types: `feat`, `fix`, `refactor`, `docs`, `chore`
- Branch naming: `type/short-description` (e.g., `feat/notify-setup`, `fix/notify-subtitle`)
- One logical change per commit — don't mix plugin changes across plugins
- Scope = plugin name when change is plugin-specific (e.g., `feat(onboard): add verify skill`)

## Adding a New Plugin

1. Create `<plugin>/` directory with `.claude-plugin/plugin.json`, `README.md`, and at least one skill
2. Add entry to `.claude-plugin/marketplace.json` — version must match plugin.json
3. Create `<plugin>/CLAUDE.md` documenting internal conventions
4. Follow patterns from existing plugins — use onboard as the most complete reference
