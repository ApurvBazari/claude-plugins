# Changelog

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
