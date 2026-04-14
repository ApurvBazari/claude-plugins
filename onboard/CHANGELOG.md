# Changelog

## 1.1.0

Native plugin detection for standalone mode.

- **Self-detected plugin integration**: `/onboard:init` now probes for installed Claude Code plugins and generates the full Plugin Integration section, quality-gate hooks, per-directory skill annotations, and plugin-aware agent skipping — previously only available via forge headless mode
- **Phase 2.5 in init flow**: New plugin detection step between Wizard and Generation that probes the filesystem, shows detection results, and passes them to the generation phase
- **Unified effective plugin resolution**: Generation skill resolves plugins from either `callerExtras` (headless) or self-detection (standalone), producing identical output regardless of entry point
- **Detection results in onboard-meta.json**: Records `detectedPlugins`, `coveredCapabilities`, `qualityGates`, `phaseSkills`, and `pluginSource` for downstream consumption by `/onboard:evolve` and `/onboard:update`
- **Shared plugin probe reference**: Canonical probe list in `generation/references/plugin-detection-guide.md` — single source of truth shared by generation and evolve skills

## 1.0.1

Bug fixes and coverage improvements for generation quality.

- **Standalone quality-gate hooks**: Generate SessionStart, preCommit, featureStart, and postFeature hooks in standalone `/onboard:init` mode (previously only generated in headless/forge mode). Hook selection driven by profile (minimal=none, standard=SessionStart, comprehensive=all four) and autonomy level (determines blocking vs advisory mode).
- **Architecture-aware subdirectory CLAUDE.md**: Recognized architecture patterns (Clean Architecture, MVVM/MVC/MVP, Hexagonal, backend layered) are automatic candidates for subdirectory CLAUDE.md files, regardless of file-share thresholds. Profile-aware threshold scaling: comprehensive halves thresholds, minimal doubles them.
- **Dynamic version in generated artifacts**: Maintenance headers and onboard-meta.json now read the version from `plugin.json` at generation time instead of using hardcoded examples.

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
