# Notification Options Reference

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

## Hook Events

| Event | Hook Type | When It Fires |
|-------|-----------|---------------|
| Task completed | `Stop` | Claude finishes a response/task |
| Needs attention | `Notification` | Claude needs user input (permission prompt, idle) |
| Subagent done | `SubagentStop` | A spawned subagent finishes its work |

## Notification Matcher Patterns

For the `Notification` hook, the `matcher` field filters which notification types trigger the hook:

| Pattern | Matches |
|---------|---------|
| `permission_prompt` | Permission requests only |
| `idle_prompt` | Idle/waiting prompts only |
| `permission_prompt\|idle_prompt` | Both (recommended default) |

## Common App Bundle IDs

Used for `-activate` to bring an app to the foreground when the notification is clicked:

| App | Bundle ID |
|-----|-----------|
| VS Code | `com.microsoft.VSCode` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Terminal | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |
| WezTerm | `com.github.wez.wezterm` |
| None | _(leave empty)_ |
