# Changelog

## [1.1.0](https://github.com/ApurvBazari/claude-plugins/compare/forge-v1.0.0...forge-v1.1.0) (2026-04-19)


### Features

* **onboard:** built-in Claude Code skill recommendations (1.9.0) ([#39](https://github.com/ApurvBazari/claude-plugins/issues/39)) ([770cdc7](https://github.com/ApurvBazari/claude-plugins/commit/770cdc7b70144a93f395edc293c06d88e5585a12))
* **onboard:** emit extended agent frontmatter (1.6.0) ([#36](https://github.com/ApurvBazari/claude-plugins/issues/36)) ([5dd316d](https://github.com/ApurvBazari/claude-plugins/commit/5dd316d0174cef9b967929deb7f30451772e4997))
* **onboard:** emit project-scoped custom output styles (1.7.0) ([#37](https://github.com/ApurvBazari/claude-plugins/issues/37)) ([a73bd8b](https://github.com/ApurvBazari/claude-plugins/commit/a73bd8bc775676d42f8e4b25c94db0fae7eece02))
* **onboard:** expand hook coverage to 14+ events and 4 execution types ([#34](https://github.com/ApurvBazari/claude-plugins/issues/34)) ([1cce41f](https://github.com/ApurvBazari/claude-plugins/commit/1cce41f3b13ac74701339ac586e3dba5a8fc14ae))
* **onboard:** generate .mcp.json from detected stack signals ([#35](https://github.com/ApurvBazari/claude-plugins/issues/35)) ([e1a269e](https://github.com/ApurvBazari/claude-plugins/commit/e1a269e856c1710b5d95a881f73f257f105766b4))
* **onboard:** LSP plugin recommendations (1.8.0) ([#38](https://github.com/ApurvBazari/claude-plugins/issues/38)) ([9a8d183](https://github.com/ApurvBazari/claude-plugins/commit/9a8d1830e2ad1cc054d528238148794438d5a357))


### Bug Fixes

* address security audit findings from PR [#30](https://github.com/ApurvBazari/claude-plugins/issues/30) ([#31](https://github.com/ApurvBazari/claude-plugins/issues/31)) ([d970691](https://github.com/ApurvBazari/claude-plugins/commit/d9706915f999f44f77a900bae8ba1f5c9714a392))
* **forge:** sanitise free-text wizard answers before onboard dispatch ([#45](https://github.com/ApurvBazari/claude-plugins/issues/45)) ([bf49466](https://github.com/ApurvBazari/claude-plugins/commit/bf4946601799c59f3b4fb311e8d792d3df7df965))
* release-43 security hardening + bot-scope expansion (9 findings, 13 commits) ([#44](https://github.com/ApurvBazari/claude-plugins/issues/44)) ([a048d39](https://github.com/ApurvBazari/claude-plugins/commit/a048d39242e7fa52c5fd64d65f1893cd6d7a351f))
* release-gate v2 sweep — close 17 findings across 1.9.1 + 1.10.0 bundles ([#41](https://github.com/ApurvBazari/claude-plugins/issues/41)) ([9b3c46f](https://github.com/ApurvBazari/claude-plugins/commit/9b3c46f0cdb3129071fcbd405afc78d24318d28c))

## 1.0.0

Initial release.

- 4-phase project scaffolder: Context Gathering, Scaffold, AI Tooling, Lifecycle Setup
- Interactive context-gathering wizard with 33 adaptive questions (developers answer 8-22 depending on stack and project type)
- Scaffolding with `full` mode (external CLI) and `walking-skeleton` mode for stacks without mature CLIs
- Delegates all tooling generation to onboard's headless mode (`/onboard:generate`)
- Generates `init.sh` environment bootstrap + `docs/feature-list.json` feature decomposition
- Phase 4 lifecycle setup via `engineering` plugin (ADRs, testing strategy, deploy checklists, system designs, runbooks) — graceful skip if absent
- Resume protocol: `.claude/forge-state.json` checkpoint at every step, cross-session resume via `/forge:resume`
- Stack research via `stack-researcher` agent with main-session fallback
- Sibling project detection for version consistency across related projects
- Plugin discovery: curated catalog + web search, capability mapping for plugin-aware generation
- Quality-gate hooks: SessionStart reminders, feature-start detection, pre-commit blocking, post-feature advisory
- Plugin Integration Coverage reporting in `/forge:status`
