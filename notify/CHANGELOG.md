# Changelog

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
