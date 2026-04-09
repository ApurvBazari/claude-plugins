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
         │      ├── skills/ (analysis, generation, wizard, verify, evolve)
         │      ├── agents/ (codebase-analyzer, config-generator, feature-evaluator)
         │      ├── commands/ (init, status, update, generate, verify, evolve)
         │      └── scripts/ (analyze-structure, detect-stack, measure-complexity)
         │
         ├──→ forge/                     ← project scaffolder with AI-native tooling
         │      ├── skills/ (context-gathering, scaffolding, tooling-generation, plugin-discovery)
         │      ├── agents/ (stack-researcher, scaffold-analyzer)
         │      └── commands/ (init, status)
         │
         ├──→ observe/                   ← zero-infrastructure observability
         │      ├── skills/ (observability-analytics)
         │      ├── commands/ (status, report, pipeline)
         │      └── scripts/ (collect.py, install.sh, query.py, generate_dashboard.py)
         │
         └──→ notify/                    ← cross-platform system notifications
                ├── skills/ (wizard)
                ├── commands/ (setup, status, uninstall)
                └── scripts/ (notify, install-notifier, test-notification)
```

## Plugin Structure Convention

Every plugin must have:
- `.claude-plugin/plugin.json` — manifest with name, version, description, author, license, keywords
- `README.md` — user-facing documentation
- At least one of: `skills/`, `commands/`, `agents/`

Components live at the plugin root, NOT inside `.claude-plugin/`. Only `plugin.json` goes in `.claude-plugin/`.

## File Type Conventions

| Type | Pattern | Key requirements |
|------|---------|-----------------|
| Skills | `skills/<name>/SKILL.md` | H1 `/plugin:skill` title, Guard section, step-numbered flow, Key Rules section |
| Agents | `agents/<name>.md` | H1 name, Tools section, Instructions with numbered steps, Output Format |
| Commands | `commands/<name>.md` | H1 `/plugin:command` title, orchestration logic referencing skills/agents |
| Shell scripts | `scripts/<name>.sh` | `#!/usr/bin/env bash`, `set -euo pipefail`, ShellCheck-clean, POSIX compat |
| Manifests | `.claude-plugin/plugin.json` | Required: name, version, description, author, license, keywords |
| References | `skills/<name>/references/*.md` | Supporting docs loaded by skill instructions |

## Naming Conventions

- File names: kebab-case (`codebase-analyzer.md`, `validate-bash.sh`)
- Plugin directories: lowercase (`onboard`, `forge`, `observe`, `notify`)
- Manifest names: match directory name
- Skill references: always in `references/` subdirectory inside the skill

## Cross-Plugin Integration

- **forge → onboard**: forge delegates all Claude tooling generation to onboard's headless mode (`/onboard:generate`)
- **forge → notify**: forge-scaffolded projects can include notify configuration as part of plugin discovery

## Quality Checks

- ShellCheck on all `.sh` scripts: `shellcheck scripts/*.sh`
- JSON validation on manifests: verify required fields in plugin.json + marketplace.json
- Reference integrity: every file referenced in skills/agents must exist
- Run `/validate` to check all plugins at once

## Git Discipline

- Conventional commits: `type(scope): description` — types: `feat`, `fix`, `refactor`, `docs`, `chore`
- Branch naming: `type/short-description` (e.g., `feat/observe-plugin`, `fix/notify-subtitle`)
- One logical change per commit — don't mix plugin changes across plugins
- Scope = plugin name when change is plugin-specific (e.g., `feat(onboard): add verify skill`)

## Adding a New Plugin

1. Create `<plugin>/` directory with `.claude-plugin/plugin.json`, `README.md`, and at least one skill or command
2. Add entry to `.claude-plugin/marketplace.json` — version must match plugin.json
3. Create `<plugin>/CLAUDE.md` documenting internal conventions
4. Follow patterns from existing plugins — use onboard as the most complete reference
