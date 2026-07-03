---
paths:
  - "**/.claude-plugin/**"
  - "**/marketplace.json"
---

# Manifest Conventions

## plugin.json — Required Fields

Every plugin manifest must include:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief description under 120 characters",
  "author": { "name": "Author Name" },
  "repository": "https://github.com/owner/repo",
  "license": "MIT",
  "keywords": ["keyword-1", "keyword-2"]
}
```

## Field Rules

- `name`: must match the plugin directory name, kebab-case
- `version`: semver format (`MAJOR.MINOR.PATCH`), bump on every change
- `description`: concise, under 120 characters, describes what the plugin does
- `keywords`: lowercase, hyphen-separated, relevant for discovery
- `author.name`: required; `author.email` and `author.url` optional

## marketplace.json — Version Sync

The marketplace manifest at `.claude-plugin/marketplace.json` must list every plugin:

```json
{
  "plugins": [
    {
      "name": "plugin-name",
      "source": "./plugin-dir",
      "version": "1.0.0"
    }
  ]
}
```

- `source` paths are relative to the repo root
- `version` must match the corresponding `plugin.json` version
- Every plugin directory must have an entry — no orphaned plugins
- Plugin entries must have: `name`, `source`, `description`, `version`, `keywords`, `license`

## Version Bumping

When changing plugin code:
1. Bump version in `plugin.json`
2. Update matching version in `marketplace.json`
3. Add CHANGELOG.md entry

Forgetting either location causes version drift — the PostToolUse hook will remind you.
