# notify

macOS system notifications for Claude Code. Get notified when tasks complete or Claude needs your attention.

## What It Does

Configures Claude Code hooks to send native macOS notifications via `terminal-notifier`:

- **Task completed** — notified when Claude finishes a response
- **Needs attention** — notified when Claude needs your input (permission prompts, idle)
- **Subagent done** — optionally notified when subagents finish (off by default)

Clicking a notification brings your editor (VS Code, Cursor, etc.) to the foreground.

## Requirements

- macOS
- [Homebrew](https://brew.sh) (for installing terminal-notifier)
- Claude Code

## Installation

```bash
# From the marketplace
claude plugin install notify

# Or from a local path (for development)
claude plugin add /path/to/notify
```

Then run:

```
/notify:setup
```

The setup command will:
1. Install `terminal-notifier` if needed
2. Let you choose an install scope (global or per-project)
3. Let you choose default or custom notification preferences
4. Configure hooks in the chosen scope's `settings.json`
5. Send a test notification to verify everything works

## Install Scopes

Notifications can be installed globally or per-project:

| Scope | Path | When hooks fire |
|-------|------|-----------------|
| **Global** (default) | `~/.claude/` | Every Claude Code session |
| **Per-project** | `<project>/.claude/` | Only when running in that project directory |

Both scopes can coexist — per-project hooks add to global hooks, they don't replace them. This lets you set up global defaults and override or extend them for specific projects (e.g., a different sound for a particular repo).

## Commands

| Command | Description |
|---------|-------------|
| `/notify:setup` | Install and configure notifications |
| `/notify:status` | Health check and test notifications |

## Configuration

Settings are stored in `notify-config.json` within the chosen scope directory (`~/.claude/` for global, `<project>/.claude/` for per-project). Edit directly and re-run `/notify:setup` to apply changes.

## Troubleshooting

- **No notifications appearing** — Open System Settings > Notifications > terminal-notifier and ensure notifications are allowed. Also check that "Do Not Disturb" / Focus mode is off.
- **Wrong app activates on click** — Edit `notify-config.json` and update the `activate` bundle ID for the affected event. Run `/notify:setup` to re-apply.
- **Notification sound not playing** — Verify the sound name is valid by running: `terminal-notifier -title "Test" -message "Test" -sound "<SoundName>"`. See macOS `/System/Library/Sounds/` for available names.
- **Setup partially completed** — Re-run `/notify:setup`. It detects existing config and offers to update or replace.
- **Permissions issues** — If `terminal-notifier` was installed but notifications don't appear, try removing and re-adding it: `brew reinstall terminal-notifier`, then open it once from Finder to trigger the macOS permission prompt.

## Works Well With

- **devkit** — The ship pipeline (`/devkit:ship`) can trigger notifications on completion. When both plugins are installed, you get notified when your quality gates pass and code is committed.

## Customization

During setup, you can customize per event:
- **Message text** — what the notification says
- **Sound** — Hero, Glass, Ping, Purr, Pop, Submarine, and more
- **App to activate** — VS Code, Cursor, Terminal, iTerm2, or none
