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

## plugin.json — Directory Listing Fields

Anthropic's plugin directory reads these from `plugin.json` (Claude Code ignores them at load time). Every plugin here sets them:

- `displayName`: the label people see, e.g. `"Onboard"`. Never change `name` to relabel a plugin; change `displayName`.
- `icon`: `"./assets/icon.png"` — a square PNG, 512–2048 px, under 2 MB. The directory rejects SVG; keep the SVG source beside it as `assets/icon.svg`. The icon is captured once, at the plugin's first portal save.
- `homepage` and `documentationUrl`: the plugin's docs-site page. `supportUrl`: the repo's issues page. `privacyPolicyUrl`: the root `PRIVACY.md`.

Set these only in `plugin.json`: `claude plugin validate` reports them as unknown fields in a marketplace entry.

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
