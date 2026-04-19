# notify

> Part of [`claude-plugins`](../README.md) — see also [`onboard`](../onboard/) and [`forge`](../forge/) (both can recommend notify during their setup).

Cross-platform system notifications for Claude Code. Get notified when tasks complete or Claude needs your attention. Intentionally minimal — see the root README's [notify section](../README.md#notify) for an honest comparison against richer community alternatives.

## Install

```bash
claude plugin install notify@apurvbazari-plugins
```

Then run `/notify:setup` to install the platform backend (`terminal-notifier` on macOS, `notify-send` on Linux) and configure hooks.

## Skills

All skills are invoked with the `/notify:<name>` slash syntax. `status` is auto-invocable; `setup` and `uninstall` require explicit invocation.

### `/notify:setup` *(destructive — user-invoked only)*

Installs the platform backend (`terminal-notifier` via Homebrew on macOS, or `notify-send` from `libnotify` on Linux), detects your editor + bundle ID for click-to-focus, asks whether to install global or per-project, configures hooks for the chosen events, and sends a test notification.

**When to use:** first-time install on a new machine, or when adding per-project overrides on a project that already has global notify configured.

**Edge cases:**
- **Partial completion** — if a previous setup was interrupted (no `notify-config.json` written, but hooks added to `settings.json`), re-running `/notify:setup` detects the partial state and offers to repair, replace, or roll back.
- **Existing global config + new per-project request** — setup reads global as the base and layers your per-project answers as overrides. Doesn't blow away global.
- **Permission prompts (macOS)** — first notification after `terminal-notifier` install triggers a macOS Notification permission prompt; setup warns about this before sending the test notification.

### `/notify:status`

Health check. Reports which scopes have notify installed (global / per-project / both), the current event configuration (sounds, durations, enabled flags), the resolved precedence-merged config that the hook will actually use, and sends a test notification to confirm the wiring works end-to-end.

**When to use:** after editing `notify-config.json` by hand, after changing editors, when notifications stop firing for an unclear reason, or as a sanity check before relying on notify for a long task.

### `/notify:uninstall` *(destructive — user-invoked only)*

Removes notify hooks from `settings.json`, deletes `notify-config.json`, and offers to uninstall the backend (`terminal-notifier` / `notify-send`) if no other tooling on your machine still uses it.

**When to use:** decommissioning notify, switching to a richer alternative (see [the root README's notify section](../README.md#notify) for community options), or troubleshooting a broken setup by starting clean.

**Side effects:**
- Removes hook entries that match notify's command line; **does not** touch unrelated hooks in the same `settings.json`.
- Asks before uninstalling the backend — won't auto-remove `terminal-notifier` if other tools depend on it.
- Per-project uninstall does not affect global config, and vice versa — they're independent scopes.

## Hook event model

Three notification events, each independently configurable:

| Event | When | Default |
|---|---|---|
| `stop` | Claude finishes a response | Enabled · `Hero` sound · `minDurationSeconds: 30` |
| `notification` | Claude needs user attention | Enabled · `Glass` sound · `minDurationSeconds: 0` |
| `subagentStop` | A subagent finishes work | Disabled (too noisy) |

Notification content is extracted from Claude's actual last message — not generic static text. Each notification carries a contextual subtitle (`repo / branch`) so you know which project the alert is from when several Claude sessions are running.

## Example

`/notify:setup` on macOS, then a Stop hook firing in two scenarios — one suppressed by the duration filter, one delivered:

```
> /notify:setup

Detecting platform … macOS
Checking for terminal-notifier … installing via Homebrew
Editor detected: VS Code (com.microsoft.VSCode)

Where should notifications be installed?
  (a) Global — fire in every Claude Code session
  (b) This project only

> a

Configuring three events:
  stop          enabled   sound: Hero    minDurationSeconds: 30
  notification  enabled   sound: Glass   minDurationSeconds: 0
  subagentStop  disabled  (too noisy by default)

Writing notify-config.json to ~/.claude/
Adding hooks to ~/.claude/settings.json (Stop, Notification)
Sending test notification … ✓

Setup complete. Edit ~/.claude/notify-config.json anytime — changes take effect immediately.

# ── short task: "fix typo in README" ────────
[Stop hook fires]
[notify.sh: elapsed 4s < 30s threshold → silently skip]
(no notification — duration filter suppressed)

# ── long task: 12-minute refactor ───────────
[Stop hook fires]
[notify.sh: elapsed 743s ≥ 30s → notify]

  ┌──────────────────────────────────────┐
  │ Claude Code                          │
  │ feedback-saas / feat/onboarding-flow │
  │ Refactored auth middleware …         │
  └──────────────────────────────────────┘

  Sound: Hero · Click brings VS Code to front
```

## Install scopes

Notifications can be installed globally or per-project:

| Scope | Path | When hooks fire |
|---|---|---|
| **Global** (default) | `~/.claude/` | Every Claude Code session |
| **Per-project** | `<project>/.claude/` | Only when running in that project directory |

Both scopes can coexist — per-project hooks add to global, they don't replace.

## Configuration

Settings live in `notify-config.json` within the chosen scope directory. Edit the file directly — changes take effect immediately, no need to re-run `/notify:setup`. The only setting that requires re-running setup is the `Notification` matcher (which is in `settings.json`, not `notify-config.json`).

### Precedence (project-local inherits + overrides global)

When both `~/.claude/notify-config.json` and `<project>/.claude/notify-config.json` exist:

1. The project-local config **inherits all keys from the global config**.
2. Keys explicitly set in the project-local config **override** the global value.
3. Keys absent from the project-local config **fall back** to the global value.

Example — global has `events.stop.sound = "Glass"` and `events.stop.minDurationSeconds = 5`. Project-local sets only `events.stop.message = "Build complete"`. The merged behaviour at runtime is `{ sound: "Glass", minDurationSeconds: 5, message: "Build complete" }`.

This precedence is applied at notify-setup time when project-local is being written; the runtime hook (`notify.sh`) reads only the project-local file when present, falling back to global only when no project-local file exists at all.

## Customisation

Per event you can configure:

- **Fallback message** — shown when contextual content can't be extracted from Claude's response
- **Sound** — Hero, Glass, Ping, Purr, Pop, Submarine, and more (macOS); urgency level (Linux)
- **App to activate** — VS Code, Cursor, Terminal, iTerm2, or none (macOS click-to-focus)
- **Enabled / disabled** — toggle any event without re-running setup
- **`minDurationSeconds` (duration filter)** — suppress this event if the elapsed time since last activity is below the threshold. Tracks last activity in a temp file (`$TMPDIR/claude-notify-session-start`). Useful when you want notifications only for substantive work — set `30` on `stop` and short typo fixes won't notify; long refactors will. Leave `0` on `notification` so attention prompts always fire.

## Platform support

| Platform | Backend | Sound | Click-to-focus | Duration filter |
|---|---|---|---|---|
| macOS | `terminal-notifier` | 14 system sounds | Yes (bundle ID) | Yes |
| Linux | `notify-send` (libnotify) | Urgency levels only | No | Yes |

## Troubleshooting

- **No notifications appearing (macOS)** — Open System Settings → Notifications → terminal-notifier, ensure notifications are allowed. Check that Do Not Disturb / Focus mode is off.
- **Wrong app activates on click** — Edit `notify-config.json`, update the `activate` bundle ID for the affected event, then run `/notify:setup` to re-apply.
- **Notification sound not playing (macOS)** — Verify the sound name is valid: `terminal-notifier -title Test -message Test -sound <SoundName>`. See `/System/Library/Sounds/` for available names.
- **Setup partially completed** — Re-run `/notify:setup`. It detects existing config and offers to update or replace.
- **Permissions issues** — If `terminal-notifier` was installed but notifications don't appear, try `brew reinstall terminal-notifier`, then open it once from Finder to trigger the macOS permission prompt.

## Prerequisites

**macOS:**
- [Homebrew](https://brew.sh) (for installing `terminal-notifier`)
- `jq` (recommended, installed during setup) or `python3` (fallback for JSON parsing)

**Linux:**
- `notify-send` (from `libnotify`, available on most distributions)
- `jq` (recommended) or `python3` (fallback)

**Both platforms:** Claude Code, `git` (used to build the `repo / branch` subtitle).

## Internals

For the hook event model, JSON parsing pattern, script safety rules, and detection logic used by `/onboard:init` to probe whether notify is already configured, see [`notify/CLAUDE.md`](./CLAUDE.md).

## License

[MIT](../LICENSE)
