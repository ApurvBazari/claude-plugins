# Changelog

## [1.1.0](https://github.com/ApurvBazari/claude-plugins/compare/forge-v1.0.0...forge-v1.1.0) (2026-04-14)


### Features

* **forge,onboard:** Plugin Integration upgrade + D1/D2 deferred items ([#11](https://github.com/ApurvBazari/claude-plugins/issues/11)) ([9e96fbb](https://github.com/ApurvBazari/claude-plugins/commit/9e96fbb74239192733874ec60d36d53d0c51cef3))
* **forge:** add forge plugin + onboard headless mode ([#7](https://github.com/ApurvBazari/claude-plugins/issues/7)) ([cae3b92](https://github.com/ApurvBazari/claude-plugins/commit/cae3b929258e4e645c1aaf42e3904e9433ebc9c8))
* **forge:** resume protocol and inline prerequisite handling ([#10](https://github.com/ApurvBazari/claude-plugins/issues/10)) ([2403130](https://github.com/ApurvBazari/claude-plugins/commit/2403130cbf1d14769a3ebee238b542123def6867))
* **onboard:** proactive worktree support via Claude Code native tools ([#12](https://github.com/ApurvBazari/claude-plugins/issues/12)) ([1571702](https://github.com/ApurvBazari/claude-plugins/commit/15717021907df8cf9ce27e83980f6264f17d1044))

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
