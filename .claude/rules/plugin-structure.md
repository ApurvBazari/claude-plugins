---
paths:
  - "onboard/**"
  - "notify/**"
  - "devkit/**"
---

# Plugin Structure

## Required Files

Every plugin directory must contain:
- `.claude-plugin/plugin.json` — manifest (only file inside `.claude-plugin/`)
- `README.md` — user-facing documentation
- At least one of: `skills/`, `commands/`, `agents/`

All component directories live at the plugin root, never inside `.claude-plugin/`.

## Manifest Fields

`plugin.json` must include: `name`, `version`, `description`, `author.name`, `repository`, `license`, `keywords`.

- `name` must match the plugin directory name
- `version` must follow semver and stay in sync with the marketplace.json entry
- `keywords` must be lowercase, hyphen-separated

## Self-Contained Plugins

- No cross-plugin file imports — each plugin must be independently installable
- Shared patterns should be documented in conventions, not shared via file references
- If plugin A integrates with plugin B (e.g., devkit → notify), check for B's existence at runtime and skip silently if absent

## Adding Components

When adding a new skill, command, or agent to a plugin:
1. Follow the naming and structure conventions from the corresponding authoring rule
2. Update the plugin's README.md if the new component is user-facing
3. Update CHANGELOG.md with a version bump
