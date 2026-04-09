# Changelog

## 1.1.0

- Add Linux support via `notify-send` (libnotify)
- Add duration filtering (`minDurationSeconds`) to suppress notifications for fast responses
- Add `/notify:uninstall` command for clean removal
- Add hook conflict detection during setup
- Add editor auto-detection for macOS app activation (VS Code, Cursor, Windsurf, iTerm2)
- Add dry-run/preview mode during setup
- Add scope migration support (global ↔ per-project)
- Improve sound and bundle ID validation during setup

## 1.0.0

- Initial release
- macOS notifications via `terminal-notifier`
- Three notification events: stop, notification, subagentStop
- `/notify:setup` interactive wizard
- `/notify:status` health check
- Global and per-project install scopes
- Contextual message extraction from Claude responses
- Repo + branch subtitle display
