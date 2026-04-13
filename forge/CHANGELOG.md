# Changelog

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
