# Changelog

## [1.2.0](https://github.com/ApurvBazari/claude-plugins/compare/onboard-v1.1.0...onboard-v1.2.0) (2026-04-14)


### Features

* **onboard:** native plugin detection + generation quality fixes ([#16](https://github.com/ApurvBazari/claude-plugins/issues/16)) ([77b54ac](https://github.com/ApurvBazari/claude-plugins/commit/77b54ac06c69b515912f994074ce4ec2a857ec47))


### Bug Fixes

* security audit hardening from PR [#18](https://github.com/ApurvBazari/claude-plugins/issues/18) findings ([#19](https://github.com/ApurvBazari/claude-plugins/issues/19)) ([e5df20b](https://github.com/ApurvBazari/claude-plugins/commit/e5df20b64b860a33d79b070c2ccda7cf95ae7b62))

## 1.1.0

### Features

- **Native plugin detection** (#16): `/onboard:init` now probes for installed Claude Code plugins and generates the full Plugin Integration section, quality-gate hooks, per-directory skill annotations, and plugin-aware agent skipping — previously only available via forge headless mode
- **Architecture-aware subdirectory CLAUDE.md** (#16): Recognized architecture patterns (Clean Architecture, MVVM, Hexagonal, etc.) are automatic candidates for subdirectory CLAUDE.md, with profile-scaled file-share thresholds
- **Standalone quality-gate hooks** (#16): Generate SessionStart, preCommit, featureStart, postFeature hooks in standalone mode driven by profile + autonomy level
- **Dynamic version resolution** (#16): Maintenance headers now read the current version from `plugin.json` instead of using hardcoded examples

### Bug Fixes

- **Hardened Python string interpolation** in detection scripts (#19): All `python3 -c "..."` blocks in `detect-*.sh` scripts now pass paths via `sys.argv` instead of interpolating into Python source

## 1.0.0

Initial release.

- Interactive wizard with adaptive Q&A and preset profiles (Minimal / Standard / Comprehensive / Custom)
- Codebase analyzer agent (read-only) with `analyze-structure.sh`, `detect-stack.sh`, `measure-complexity.sh` scripts
- Config generator agent producing root + subdirectory CLAUDE.md files, path-scoped rules, project-specific skills, agents, hooks, and PR templates
- Headless generation mode (`/onboard:generate`) for programmatic consumers like forge
- Plugin-aware agent generation via `coveredCapabilities` — skips generating agents whose capability is already covered by an installed plugin
- Quality-gate hook generation: SessionStart reminders, feature-start detector, pre-commit blocking, post-feature advisory
- Adaptive SessionStart reminder suppression (counter-based, resets on brainstorming)
- Enriched mode: CI/CD pipelines, harness artifacts, auto-evolution hooks, sprint contracts
- `/onboard:update` for aligning with latest best practices
- `/onboard:evolve` for applying pending drift updates
- `/onboard:verify` for independent feature verification via feature-evaluator agent
- Supports Node.js/TypeScript, Python, Go, Rust, Ruby, monorepos, and mixed-language projects
