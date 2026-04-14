# notify

Cross-platform system notifications for Claude Code. Get notified when tasks complete or Claude needs your attention.

## What It Does

Configures Claude Code hooks to send native system notifications — macOS via `terminal-notifier`, Linux via `notify-send`:

- **Task completed** — notified with a truncated summary of Claude's response
- **Needs attention** — notified when Claude needs your input (permission prompts, idle)
- **Subagent done** — optionally notified when subagents finish (off by default)

Notifications show contextual messages extracted from Claude's actual response, not generic static text. Each notification also displays the current repository and branch as a subtitle (e.g., `📦 my-app  🔀 feature/auth`). Clicking a notification brings your editor (VS Code, Cursor, etc.) to the foreground.

## Example

Running `/notify:setup` on macOS:

```
> /notify:setup

Claude: Detected platform: macOS
        Checking for terminal-notifier... found (/opt/homebrew/bin/terminal-notifier)
        Detected editor: VS Code (com.microsoft.VSCode)

        Where should notifications be installed?
        (a) Global — fire in every Claude Code session
        (b) This project only — fire only in my-app/

You: (a) Global

Claude: Configure notification preferences:

        Stop event (task completed):
          Sound: Hero       Activate: VS Code    Enabled: yes

        Notification event (needs attention):
          Sound: Glass      Activate: VS Code    Enabled: yes

        SubagentStop event (subagent done):
          Sound: Ping       Activate: VS Code    Enabled: no

        Use these defaults, or customize?

You: Defaults are fine

Claude: Writing notify-config.json to ~/.claude/
        Adding hooks to ~/.claude/settings.json (Stop, Notification)
        Sending test notification...

        ✓ Notification sent — you should see it on screen now.

        Setup complete. Notifications will fire in all Claude Code sessions.
        Edit ~/.claude/notify-config.json to adjust settings anytime.
```

**What you see:**

A native macOS notification appears with:
- **Title**: `Claude Code`
- **Subtitle**: `my-app` `main`
- **Message**: `Test notification — setup is working!`
- **Sound**: Hero chime

Clicking the notification brings VS Code to the foreground.

## Requirements

**macOS:**
- [Homebrew](https://brew.sh) (for installing `terminal-notifier`)
- `jq` (recommended, installed during setup) or `python3` (fallback for JSON parsing)

**Linux:**
- `notify-send` (from `libnotify`, available on most distributions)
- `jq` (recommended) or `python3` (fallback for JSON parsing)

**Both platforms:** Claude Code

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

## Skills

All skills are invoked with the `/notify:<name>` slash syntax. `status` is auto-invocable; `setup` and `uninstall` require explicit invocation.

| Skill | Description |
|---------|-------------|
| `/notify:setup` | Install and configure notifications |
| `/notify:status` | Health check and test notifications |
| `/notify:uninstall` | Remove hooks and clean up configuration |

## Configuration

Settings are stored in `notify-config.json` within the chosen scope directory (`~/.claude/` for global, `<project>/.claude/` for per-project). Edit `notify-config.json` — changes take effect immediately, no need to re-run setup. The only setting that requires re-running setup is the Notification `matcher` (stored in `settings.json`).

## Troubleshooting

- **No notifications appearing** — Open System Settings > Notifications > terminal-notifier and ensure notifications are allowed. Also check that "Do Not Disturb" / Focus mode is off.
- **Wrong app activates on click** — Edit `notify-config.json` and update the `activate` bundle ID for the affected event. Run `/notify:setup` to re-apply.
- **Notification sound not playing** — Verify the sound name is valid by running: `terminal-notifier -title "Test" -message "Test" -sound "<SoundName>"`. See macOS `/System/Library/Sounds/` for available names.
- **Setup partially completed** — Re-run `/notify:setup`. It detects existing config and offers to update or replace.
- **Permissions issues** — If `terminal-notifier` was installed but notifications don't appear, try removing and re-adding it: `brew reinstall terminal-notifier`, then open it once from Finder to trigger the macOS permission prompt.
## Customization

During setup, you can customize per event:
- **Fallback message** — shown when contextual information can't be extracted from Claude's response
- **Sound** — Hero, Glass, Ping, Purr, Pop, Submarine, and more
- **App to activate** — VS Code, Cursor, Terminal, iTerm2, or none
- **Enabled/disabled** — toggle any event on/off without re-running setup

## Works Well With

- **forge** — When forge scaffolds a new project, it can recommend and configure notify as part of plugin discovery
- **onboard** — After onboard generates your Claude tooling, add notify to get alerted when tasks complete or need attention

## License

MIT
