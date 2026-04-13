# Changelog

## 2.2.0 — 2026-04-11

- Add Plugin Integration section generation in root CLAUDE.md with section markers
  (`<!-- onboard:plugin-integration:start -->`) so the section can be safely regenerated
  by `/onboard:update` without clobbering user edits elsewhere in the file
- Add per-directory skill annotations in subdirectory CLAUDE.md files, mapping directory
  role (`domain`, `parser`, `data-layer`, `compose-ui`, etc.) to installed-plugin capability
- Add quality-gate hook generation from `callerExtras.qualityGates`:
  - SessionStart reminder hook (advisory, ≤ 3 lines, condition-gated on plugin availability)
  - PreToolUse feature-start detector (new files in critical dirs, session-marker aware,
    excludes `**/build/**`, `**/generated/**`, `**/.git/**`)
  - preCommit blocking hooks (exit 2 + stderr, autonomyLevel-downgraded to advisory
    in always-ask mode)
  - postFeature advisory nudge toward `claude-md-management:revise-claude-md`
- Add `allowPluginReferences` flag for rules/skills plugin cross-references
- Extend `callerExtras` schema in `/onboard:generate` with `qualityGates`, `phaseSkills`,
  `allowPluginReferences` fields (backward compatible — absent fields preserve pre-upgrade
  behavior including the skip of the Plugin Integration section entirely)
- Extend `references/hooks-guide.md` with SessionStart + Stop events, blocking vs advisory
  mode semantics, and 4 new hook template sections (SessionStart reminder, feature-start
  detector, pre-commit blocker, post-feature advisory)
- Extend `references/claude-md-guide.md` with Skill recommendations block pattern and
  4 directory-role example annotations

## 2.1.0

- Enforce TDD as the only testing approach — remove `minimal`, `write-after`, and
  `comprehensive` testing philosophies
- Harness refinements: ACI (Agent-Computer Interface) design guide, ground truth
  verification patterns, lifecycle documentation
- Migrate universally useful features from forge to onboard (harness, evolution hooks,
  sprint contracts) so they're available to any `/onboard:init` consumer, not just
  forge-scaffolded projects
- Plugin-aware agent generation via `callerExtras.coveredCapabilities` — skip generating
  agents whose capability is already covered by an installed plugin (prevents shadowing)
- Agent team support with quality hooks (TaskCreated, TaskCompleted) and
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` setting

## 2.0.0

- Add headless generation mode (`/onboard:generate`) for programmatic consumers like forge
- Restructure skill hierarchy: analysis, wizard, generation, verify, evolve
- Split codebase analyzer agent from config generator agent to enforce read-only analysis
  before any writes
- Add `/onboard:update` and `/onboard:evolve` commands for post-init tooling maintenance
- Add `/onboard:verify` command for independent feature verification via feature-evaluator agent

## 1.0.0

- Initial release
- Interactive wizard with adaptive Q&A and preset profiles (Minimal / Standard /
  Comprehensive / Custom)
- Codebase analyzer agent (read-only) with `analyze-structure.sh`, `detect-stack.sh`,
  `measure-complexity.sh` scripts
- Config generator agent producing root + subdirectory CLAUDE.md files, path-scoped rules,
  project-specific skills, agents, PostToolUse hooks, and PR templates
- Enriched mode: CI/CD pipelines, harness artifacts, auto-evolution hooks, sprint contract
  infrastructure
