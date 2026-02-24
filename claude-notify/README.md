# claude-notify

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

Add this plugin to your Claude Code plugins, then run:

```
/claude-notify:setup
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
| `/claude-notify:setup` | Install and configure notifications |
| `/claude-notify:notify-status` | Health check and test notifications |

## Configuration

Settings are stored in `notify-config.json` within the chosen scope directory (`~/.claude/` for global, `<project>/.claude/` for per-project). Edit directly and re-run `/claude-notify:setup` to apply changes.

## Customization

During setup, you can customize per event:
- **Message text** — what the notification says
- **Sound** — Hero, Glass, Ping, Purr, Pop, Submarine, and more
- **App to activate** — VS Code, Cursor, Terminal, iTerm2, or none
