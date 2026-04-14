# Changelog

## [1.1.0](https://github.com/ApurvBazari/claude-plugins/compare/onboard-v1.0.0...onboard-v1.1.0) (2026-04-14)


### Features

* add development tooling ecosystem for plugin authoring ([4238a32](https://github.com/ApurvBazari/claude-plugins/commit/4238a3299895101494088943015f7102681c7451))
* add development tooling ecosystem for plugin authoring ([782413d](https://github.com/ApurvBazari/claude-plugins/commit/782413d07fa7a1fed9f1cd02a7dc613fe91a94e0))
* add marketplace manifest and bump plugins to v1.0.0 ([9175afb](https://github.com/ApurvBazari/claude-plugins/commit/9175afb1559a756b6593a3cd3585e499e37567ac))
* **forge,onboard:** Plugin Integration upgrade + D1/D2 deferred items ([#11](https://github.com/ApurvBazari/claude-plugins/issues/11)) ([9e96fbb](https://github.com/ApurvBazari/claude-plugins/commit/9e96fbb74239192733874ec60d36d53d0c51cef3))
* **forge:** add forge plugin + onboard headless mode ([#7](https://github.com/ApurvBazari/claude-plugins/issues/7)) ([cae3b92](https://github.com/ApurvBazari/claude-plugins/commit/cae3b929258e4e645c1aaf42e3904e9433ebc9c8))
* **forge:** resume protocol and inline prerequisite handling ([#10](https://github.com/ApurvBazari/claude-plugins/issues/10)) ([2403130](https://github.com/ApurvBazari/claude-plugins/commit/2403130cbf1d14769a3ebee238b542123def6867))
* **onboard:** enforce TDD as the only testing approach ([#8](https://github.com/ApurvBazari/claude-plugins/issues/8)) ([af9fa0f](https://github.com/ApurvBazari/claude-plugins/commit/af9fa0ff5e57184e0288b8564d99330047d2f820))
* **onboard:** native plugin detection + generation quality fixes ([#16](https://github.com/ApurvBazari/claude-plugins/issues/16)) ([77b54ac](https://github.com/ApurvBazari/claude-plugins/commit/77b54ac06c69b515912f994074ce4ec2a857ec47))
* **onboard:** proactive worktree support via Claude Code native tools ([#12](https://github.com/ApurvBazari/claude-plugins/issues/12)) ([1571702](https://github.com/ApurvBazari/claude-plugins/commit/15717021907df8cf9ce27e83980f6264f17d1044))
* plugin ecosystem integration — cross-plugin wiring, intelligence, and foundation ([#6](https://github.com/ApurvBazari/claude-plugins/issues/6)) ([06e9f33](https://github.com/ApurvBazari/claude-plugins/commit/06e9f3312300f60a4f4abbad393539d20ab989e2))


### Bug Fixes

* address all 29 medium-priority audit items across all plugins ([0edd5f8](https://github.com/ApurvBazari/claude-plugins/commit/0edd5f83ddbb9d837a281fe1c15adbad2abb0f27))
* address remaining high-priority audit items across all plugins ([5ef654f](https://github.com/ApurvBazari/claude-plugins/commit/5ef654f935c8334b24a2c7731dd172d2822545b7))
* resolve critical bugs and high-priority issues across all plugins ([9809b4c](https://github.com/ApurvBazari/claude-plugins/commit/9809b4ce4280e4f82467b13da99d277d1cc8c7ee))
* resolve ShellCheck errors in CI validation ([ac2868f](https://github.com/ApurvBazari/claude-plugins/commit/ac2868ff05e75bdc6d25c0b01678b5e12bc99759))
* security audit hardening from PR [#18](https://github.com/ApurvBazari/claude-plugins/issues/18) findings ([#19](https://github.com/ApurvBazari/claude-plugins/issues/19)) ([e5df20b](https://github.com/ApurvBazari/claude-plugins/commit/e5df20b64b860a33d79b070c2ccda7cf95ae7b62))

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
