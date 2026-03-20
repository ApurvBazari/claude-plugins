# Notification Options Reference

## Platform Support

| Platform | Backend | Sound Control | Click-to-Focus |
|----------|---------|---------------|----------------|
| macOS | `terminal-notifier` | Full (14 sounds) | Yes (bundle ID) |
| Linux | `notify-send` (libnotify) | No (urgency levels only) | No |

## macOS Sounds

Available sounds for `terminal-notifier -sound`:

| Sound | Description |
|-------|-------------|
| Hero | Confident, triumphant — good for task completion |
| Glass | Gentle chime — good for attention prompts |
| Ping | Neutral short ping |
| Purr | Soft vibration-like sound |
| Pop | Quick bubble pop |
| Submarine | Deep sonar ping |
| Morse | Morse code beep |
| Sosumi | Classic Mac alert |
| Tink | Light tap |
| Blow | Wind-like sound |
| Bottle | Hollow bottle sound |
| Frog | Frog croak |
| Funk | Funky alert |
| Basso | Deep bass tone |

**Defaults**: Hero (task completed), Glass (needs attention), Ping (subagent)

## Linux Urgency Levels

On Linux, the `sound` config is mapped to notification urgency:

| Urgency | Mapped from sounds | Behavior |
|---------|-------------------|----------|
| `critical` | Glass, Basso, Sosumi, Funk | Persistent notification, may play system sound |
| `normal` | All other sounds | Standard notification |

Note: Linux notification behavior depends on the desktop environment and notification daemon. Custom sounds are not supported via `notify-send`.

## Hook Events

| Event | Hook Type | When It Fires |
|-------|-----------|---------------|
| Task completed | `Stop` | Claude finishes a response/task |
| Needs attention | `Notification` | Claude needs user input (permission prompt, idle) |
| Subagent done | `SubagentStop` | A spawned subagent finishes its work |

## Duration Filtering

Each event supports a `minDurationSeconds` field that suppresses notifications for fast responses:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `minDurationSeconds` | int | `0` (disabled) | Minimum elapsed seconds before notification fires |

When set, the `stop` and `subagentStop` events check how long has passed since the last activity. If the elapsed time is less than the threshold, the notification is silently skipped.

**Recommended values:**
- `0` — Always notify (default)
- `10` — Skip trivial responses, notify for real work
- `30` — Only notify for substantial tasks
- `60` — Only notify for long-running operations

Example config:
```json
{
  "events": {
    "stop": {
      "enabled": true,
      "message": "Task completed",
      "sound": "Hero",
      "minDurationSeconds": 30
    }
  }
}
```

## Notification Matcher Patterns

For the `Notification` hook, the `matcher` field filters which notification types trigger the hook:

| Pattern | Matches |
|---------|---------|
| `permission_prompt` | Permission requests only |
| `idle_prompt` | Idle/waiting prompts only |
| `permission_prompt\|idle_prompt` | Both (recommended default) |

## Common App Bundle IDs (macOS only)

Used for `-activate` to bring an app to the foreground when the notification is clicked:

| App | Bundle ID |
|-----|-----------|
| VS Code | `com.microsoft.VSCode` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Terminal | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |
| WezTerm | `com.github.wez.wezterm` |
| None | _(leave empty)_ |

Note: The `activate` field is ignored on Linux since `notify-send` does not support click-to-focus.
