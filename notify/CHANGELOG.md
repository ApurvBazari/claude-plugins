# Changelog

## 2.1.0 — 2026-10-31

### Changed
- **Notifications no longer hold Claude up.** `/notify:setup` now writes all three hook entries with `"async": true`, so Claude keeps working while the notification is sent. Re-run `/notify:setup` and choose **Update** to convert an existing install; `/notify:check` warns about entries without `async`, and `/notify:uninstall` removes both kinds.
- **`jq` only, no `python3`.** `notify.sh` dropped its inline `python3 -c` JSON fallback. It parses the hook input once and the config once (one `jq` call each, instead of about eleven). Without `jq` it still fires, using the built-in per-event defaults and the fallback message. Setup and check now report a missing `jq` (a warning, never a stop).
- A config key an event leaves out now falls back to that event's own default (for example `Hero` for `stop`) instead of a generic `Ping` / "Notification".
- `notify.sh` prints nothing to stdout; notifier output goes to `/dev/null`.
- Plain description: macOS and Linux, not "cross-platform".

### Added
- **Listing icon and display name.** A 512 px PNG icon for Anthropic's plugin directory, drawn from what notify does (its SVG source sits beside it in the assets folder), and the display name "Notify".
- **`showMessage`** in `notify-config.json` (top level, or per event; default `true`). Set it to `false` to keep Claude's text out of notifications — useful when your screen is shared or notifications show on a lock screen. The wizard asks about it.
- `/notify:check` compares the installed `notify.sh` with the plugin's copy and warns when it is out of date. The installed script is a copy; re-run `/notify:setup` → **Update** after updating the plugin.
- `LICENSE` file inside the plugin folder; `author.url`, `homepage`, `documentationUrl`, `supportUrl` and `privacyPolicyUrl` in `plugin.json`.

### Fixed
- Notification text no longer ends with a stray trailing space.

### Docs
- README: what notify reads, writes, runs and changes in your Claude settings; where it works (Claude Code only); the community alternatives moved here from the root README. Absolute links, so the README reads correctly as a directory listing.
- `CONVENTIONS.md`: scope resolution now matches the code (each installed copy reads the config in its own scope; both scopes installed means two notifications), and the stale onboard detection probe is replaced by the delegation rule.
- Description shortened to under 120 characters, as the repo's manifest rule requires. `CONVENTIONS.md` now describes how onboard really checks for notify (`claude plugin list --json`), not the old sibling-folder probe.

### Tests
- `test_json_get_bool.sh` (python3-fallback booleans) is replaced by `test_config_parse.sh`: `enabled: false` is still honoured (N1), the no-`jq` path fires on defaults without parsing the input, stdout stays empty, and `notify.sh` contains no `python3`. New `test_show_message.sh`. The harness now puts `jq` on the curated `PATH` (opt out with `NT_NO_JQ=1`) and no longer links `python3`.

## 2.0.3 — 2026-09-15

### Changed
- **Plugin-root `CLAUDE.md` renamed to `CONVENTIONS.md`.** Claude Code never loads a `CLAUDE.md` at a plugin root as project context, so the file was inert weight in the shipped payload and `claude plugin validate --strict` flagged it on every plugin. The content is unchanged — it is the internal conventions doc for developing this plugin — it just no longer claims a filename the runtime reserves for project context. `notify` now passes `claude plugin validate --strict` clean.

## 2.0.2 — 2026-07-06
- fix: normalize the `json_get` python3 fallback booleans to lowercase — on jq-less machines `enabled: false` was ignored (an `enabled:false` event, incl. the default-off `subagentStop`, still fired). (N1)
- fix: key the notification cooldown timestamp per session, not per user — concurrent Claude sessions no longer reset each other's cooldown clock. (N2)
- fix: an explicit `"none"` `sound`/`activate` now omits the flag, so a user can turn off sound or click-to-focus. (N3)
- fix: `/notify:check` now platform-detects the notifier backend (`notify-send` on Linux), honoring the documented Linux support. (N4)
- fix: quote `$BASE_DIR` in the generated hook commands (paths with spaces); dedupe notify hooks on setup re-run; refuse to overwrite a malformed `settings.json`. (N8)
- docs: `minDurationSeconds` is documented honestly as a leading-edge **notification cooldown** ("at most one notification per N seconds"), not response-duration filtering; the default is `0` everywhere. (N7, fork §6a)
- docs: remove the never-implemented config precedence-merge, the uninstall backend-removal offer, and the "merged config" check claim. (N5/N6)
- chore: delete dead `test-notification.sh`; single-source repeated platform/sound prose; add `tests/notify/` coverage for N1–N3 + the cooldown contract + version sync. (N9)

## 2.0.1 — 2026-06-11
- fix: use ${CLAUDE_PLUGIN_ROOT} for the install-notifier.sh path (exit-127 guard); SK-04 setup/uninstall descriptions.
- fix: hook-standard `set -uo pipefail` on notify.sh; remove dead exit-code check in test-notification.sh.
- fix: guard a non-numeric `minDurationSeconds` before the arithmetic duration test — under `set -u` a malformed config value was evaluated as a variable in arithmetic context, aborting the hook and silently dropping the notification. Adds `tests/notify/` with a regression case.

## [2.0.0](https://github.com/ApurvBazari/claude-plugins/compare/notify-v1.1.0...notify-v2.0.0) (2026-05-26)


### ⚠ BREAKING CHANGES

* mattpocock-skills is no longer distributed via this marketplace. Users with the plugin installed keep it; uninstall is user-side. Future installs must use upstream mattpocock/skills directly.

### Miscellaneous Chores

* remove greenfield plugin + merge develop to main ([#58](https://github.com/ApurvBazari/claude-plugins/issues/58)) ([5d64f0d](https://github.com/ApurvBazari/claude-plugins/commit/5d64f0d359aebfafc83d8bf1ae95cc23cbb1d2f9))

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
