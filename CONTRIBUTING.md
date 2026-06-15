# Contributing to claude-plugins

Thanks for your interest. This repo is a Claude Code plugin marketplace — four plugins
(`onboard`, `notify`, `handoff`, `walkthrough`), all markdown + shell + JSON + HTML, no compiled code.

## Repository layout

```
.claude-plugin/marketplace.json   ← plugin registry (every plugin must have an entry)
<plugin>/
├── .claude-plugin/plugin.json     ← manifest (ONLY file inside .claude-plugin/)
├── README.md                      ← user-facing docs
├── CHANGELOG.md                   ← version history
├── CLAUDE.md                      ← internal conventions
├── skills/<name>/SKILL.md         ← user-facing + internal skills
├── agents/<name>.md               ← subagents (optional)
└── scripts/<name>.sh              ← shell scripts (optional)
```

Components live at the plugin root, never inside `.claude-plugin/`.

## Branching & release

Two long-lived branches: `develop` (default, integration) and `main` (release).

- Feature branches → PR into `develop` (squash merge).
- Ship: PR from `develop` → `main` as a **merge commit, never squash** (squashing permanently
  diverges the branches).
- After shipping: merge `main` back into `develop` (merge commit) to keep them in sync.

Branch names: `type/short-description` (e.g. `feat/notify-setup`, `docs/refresh`).
Commits: Conventional Commits — `type(scope): description`, scope = plugin name when
plugin-specific. One logical change per commit; don't mix plugins.

## Versioning (manual — keep three places in sync)

When you change a plugin, bump the version in **all three**:
1. `<plugin>/.claude-plugin/plugin.json`
2. `.claude-plugin/marketplace.json` (the matching entry)
3. `<plugin>/CHANGELOG.md` (new entry)

`semver`: patch = fix, minor = additive feature, major = breaking. CI's version-sync check
fails if `plugin.json` and `marketplace.json` disagree.

## Validation

Run `/validate` (the repo skill) before opening a PR, or run the gates directly:

```bash
.github/scripts/validate-manifests.sh    # required manifest fields
.github/scripts/check-structure.sh        # plugin directory structure
.github/scripts/check-references.sh        # every referenced file exists
.github/scripts/check-action-pinning.sh    # Actions pinned to version/SHA, not mutable refs
.github/scripts/check-version-sync.sh      # plugin.json ↔ marketplace.json versions match
shellcheck scripts/*.sh */scripts/*.sh     # all shell scripts ShellCheck-clean
```

## Adding a new plugin

1. Create `<plugin>/` with `.claude-plugin/plugin.json`, `README.md`, `CHANGELOG.md`,
   `CLAUDE.md`, and at least one `skills/<name>/SKILL.md`.
2. Add a matching entry to `.claude-plugin/marketplace.json` (version must match `plugin.json`).
3. Follow the patterns in an existing plugin — `onboard` is the most complete reference.

## The documentation site

The GitHub Pages site under `site/` is **generated**, not hand-written. READMEs + manifests are
the canonical source; pages are rendered from them by `/walkthrough:document`. If you change a
plugin's README, regenerate its page (`/walkthrough:document <plugin>`) and commit both together —
never hand-edit `site/*.html`.

## Documentation URLs

Reference Claude Code docs at `https://code.claude.com/docs/en/*` — the canonical
home. (Older Anthropic-hosted doc links 301-redirect; always use the canonical home.)
