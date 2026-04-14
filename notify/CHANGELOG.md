# Changelog

## [1.1.0](https://github.com/ApurvBazari/claude-plugins/compare/notify-v1.0.0...notify-v1.1.0) (2026-04-14)


### Features

* add development tooling ecosystem for plugin authoring ([4238a32](https://github.com/ApurvBazari/claude-plugins/commit/4238a3299895101494088943015f7102681c7451))
* add development tooling ecosystem for plugin authoring ([782413d](https://github.com/ApurvBazari/claude-plugins/commit/782413d07fa7a1fed9f1cd02a7dc613fe91a94e0))
* add marketplace manifest and bump plugins to v1.0.0 ([9175afb](https://github.com/ApurvBazari/claude-plugins/commit/9175afb1559a756b6593a3cd3585e499e37567ac))
* **forge,onboard:** Plugin Integration upgrade + D1/D2 deferred items ([#11](https://github.com/ApurvBazari/claude-plugins/issues/11)) ([9e96fbb](https://github.com/ApurvBazari/claude-plugins/commit/9e96fbb74239192733874ec60d36d53d0c51cef3))
* **notify:** dynamic contextual notifications with repo/branch subtitle ([e4a1770](https://github.com/ApurvBazari/claude-plugins/commit/e4a17703e75a5fab898f897152ab37e07c28799e))
* **notify:** dynamic contextual notifications with repo/branch subtitle ([8236002](https://github.com/ApurvBazari/claude-plugins/commit/8236002065f20fd6c2f47e50786a28126e72cfab))
* plugin ecosystem integration — cross-plugin wiring, intelligence, and foundation ([#6](https://github.com/ApurvBazari/claude-plugins/issues/6)) ([06e9f33](https://github.com/ApurvBazari/claude-plugins/commit/06e9f3312300f60a4f4abbad393539d20ab989e2))


### Bug Fixes

* address all 29 medium-priority audit items across all plugins ([0edd5f8](https://github.com/ApurvBazari/claude-plugins/commit/0edd5f83ddbb9d837a281fe1c15adbad2abb0f27))
* address remaining high-priority audit items across all plugins ([5ef654f](https://github.com/ApurvBazari/claude-plugins/commit/5ef654f935c8334b24a2c7731dd172d2822545b7))
* resolve critical bugs and high-priority issues across all plugins ([9809b4c](https://github.com/ApurvBazari/claude-plugins/commit/9809b4ce4280e4f82467b13da99d277d1cc8c7ee))
* resolve ShellCheck errors in CI validation ([ac2868f](https://github.com/ApurvBazari/claude-plugins/commit/ac2868ff05e75bdc6d25c0b01678b5e12bc99759))
* security audit hardening from PR [#18](https://github.com/ApurvBazari/claude-plugins/issues/18) findings ([#19](https://github.com/ApurvBazari/claude-plugins/issues/19)) ([e5df20b](https://github.com/ApurvBazari/claude-plugins/commit/e5df20b64b860a33d79b070c2ccda7cf95ae7b62))

## 1.0.0

Initial release.

- Cross-platform system notifications: macOS via `terminal-notifier`, Linux via `notify-send`
- Three notification events: stop (task completed), notification (needs attention), subagentStop (subagent done)
- Duration filtering (`minDurationSeconds`) to suppress notifications for fast responses
- `/notify:setup` interactive wizard with editor auto-detection, sound/urgency customization
- `/notify:status` health check and test notifications
- `/notify:uninstall` for clean removal of hooks and config
- Global and per-project install scopes (coexist)
- Contextual message extraction from Claude's actual response (not generic text)
- Repo + branch subtitle display on each notification
- Hook conflict detection during setup
- Dry-run/preview mode during setup
- Scope migration support (global to per-project and vice versa)
