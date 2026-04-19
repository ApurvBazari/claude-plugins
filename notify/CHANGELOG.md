# Changelog

## [1.1.0](https://github.com/ApurvBazari/claude-plugins/compare/notify-v1.0.2...notify-v1.1.0) (2026-04-19)


### Features

* **onboard:** detect plugin/artifact drift in onboard:update ([#33](https://github.com/ApurvBazari/claude-plugins/issues/33)) ([46a7097](https://github.com/ApurvBazari/claude-plugins/commit/46a70977dcd630c1be06ddf89f93ab685ac1f2ec))
* **onboard:** emit project-scoped custom output styles (1.7.0) ([#37](https://github.com/ApurvBazari/claude-plugins/issues/37)) ([a73bd8b](https://github.com/ApurvBazari/claude-plugins/commit/a73bd8bc775676d42f8e4b25c94db0fae7eece02))


### Bug Fixes

* address security audit findings from PR [#30](https://github.com/ApurvBazari/claude-plugins/issues/30) ([#31](https://github.com/ApurvBazari/claude-plugins/issues/31)) ([d970691](https://github.com/ApurvBazari/claude-plugins/commit/d9706915f999f44f77a900bae8ba1f5c9714a392))
* **onboard:** correct canonical hook schema in generation references ([#32](https://github.com/ApurvBazari/claude-plugins/issues/32)) ([97d91ce](https://github.com/ApurvBazari/claude-plugins/commit/97d91ce32a7b8ceb8f0130848b44a399e4477563))
* release-gate v2 sweep — close 17 findings across 1.9.1 + 1.10.0 bundles ([#41](https://github.com/ApurvBazari/claude-plugins/issues/41)) ([9b3c46f](https://github.com/ApurvBazari/claude-plugins/commit/9b3c46f0cdb3129071fcbd405afc78d24318d28c))

## [1.0.2](https://github.com/ApurvBazari/claude-plugins/compare/notify-v1.0.1...notify-v1.0.2) (2026-04-14)


### Bug Fixes

* security audit hardening from PR [#18](https://github.com/ApurvBazari/claude-plugins/issues/18) findings ([#19](https://github.com/ApurvBazari/claude-plugins/issues/19)) ([e5df20b](https://github.com/ApurvBazari/claude-plugins/commit/e5df20b64b860a33d79b070c2ccda7cf95ae7b62))

## 1.0.1

### Bug Fixes

- **Event name allowlist** (#19): `notify.sh` validates the event argument against a known allowlist (stop, notification, subagentStop) before using it in `jq` paths. Unknown events silently exit 0 so hooks never block Claude.
- **json_get path hardening** (#19): The Python fallback now passes the path via `sys.argv` instead of interpolating into a triple-quoted string literal
- **User-scoped timestamp file** (#19): Session timestamp is now per-user (`claude-notify-session-start-$UID`) to prevent symlink attacks at the predictable shared tmp path

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
