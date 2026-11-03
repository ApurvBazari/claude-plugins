# notify

Desktop notifications for Claude Code on macOS and Linux: know when a task finishes or Claude needs you, without watching the terminal.

**Works in:** Claude Code on macOS and Linux ✓ · Cowork ✗ · claude.ai chat ✗ — notify works by adding hooks to Claude Code's own `settings.json` and running a notifier on your computer.

## Install

From Anthropic's plugin directory: open **Customize → Plugins** on claude.ai, or run `/plugin directory` in Claude Code. A plugin added on claude.ai reaches Claude Code through account sync.

From this repository's marketplace:

```bash
claude plugin marketplace add ApurvBazari/claude-plugins
claude plugin install notify@apurvbazari-plugins
```

Then run `/notify:setup` in Claude Code. Nothing happens until you do.

## What it does

- Sends a desktop notification when Claude finishes a response, when Claude needs your permission or input, and (if you turn it on) when a subagent finishes.
- Shows which project it came from (`repo / branch`) and a short excerpt of Claude's reply. You can hide the excerpt.
- Holds back rapid repeats with an optional cooldown (`minDurationSeconds`), so a burst of replies notifies once.
- Runs in the background: the hooks are async, so a notification never delays Claude.

## Commands

| Command | What it does |
|---|---|
| `/notify:setup` | Destructive, user-invoked only. Checks the notifier, asks where to install (all projects or this one), walks through preferences, writes the hook entries and config, and sends a test notification. |
| `/notify:check` | Read-only health check: notifier, `jq`, installed script, hook entries, current settings. Claude may run it when you ask whether notifications work. Sends a test notification only if you say yes. |
| `/notify:uninstall` | Destructive, user-invoked only. Removes notify's hook entries, `notify.sh` and `notify-config.json` from one scope. Leaves your other settings alone. |

## What it reads, writes, and sends

| | |
|---|---|
| **Reads** | The hook input Claude Code passes on each event: the session id, the first 80 characters of Claude's last message (or the text of an attention prompt) and the subagent type. Your `notify-config.json`. The repository name and branch (`git rev-parse`) for the subtitle. |
| **Writes** | During setup, in the scope you choose (`~/.claude/` or `<project>/.claude/`): `hooks/notify.sh` (a copy of the plugin's script), three hook entries merged into `settings.json`, and `notify-config.json`. On each notification: a one-line cooldown timestamp in your temp folder (`$TMPDIR/claude-notify-…`). |
| **Runs** | `terminal-notifier` (macOS) or `notify-send` (Linux), plus `jq`, `git` and standard shell tools. Setup also runs `uname`, `ps` (to spot your editor for click-to-focus), `mdfind` and `ls /System/Library/Sounds` (to check a bundle ID or sound name). |
| **Installs** | Only after you say yes: `brew install terminal-notifier` on macOS. On Linux it prints the install command for your distribution. It never installs `jq`. |
| **Network** | None. notify sends nothing anywhere. (Homebrew downloads `terminal-notifier` if you accept the install.) |
| **Changes to your Claude settings** | Adds three hook entries (Stop, Notification, SubagentStop) to the `settings.json` of the scope you pick. It changes no permissions. `/notify:uninstall` removes them. |
| **Shown on screen** | The excerpt of Claude's reply appears in your OS notifications and their history. If your screen is shared or notifications show on your lock screen, set `"showMessage": false` and only the fallback text is shown. |

The installed `notify.sh` is a copy. It doesn't change when the plugin updates: after updating notify, run `/notify:setup` and choose **Update**. `/notify:check` tells you when the copy is out of date.

## Where it works

| Surface | Works? | Why |
|---|---|---|
| Claude Code (terminal, IDE, desktop Code tab) on macOS or Linux | ✓ | notify wires Claude Code's own hooks and runs a local notifier |
| Cowork | ✗ | Not supported: notify relies on hooks in Claude Code's `settings.json` and a notifier on your computer |
| claude.ai chat | ✗ | Chat has no hooks and no access to your computer |
| Windows | ✗ | No Windows notifier; see [Platform support](#platform-support) for WSL |

## Events

| Event | When | Default |
|---|---|---|
| `stop` | Claude finishes a response | On · `Hero` sound · no cooldown |
| `notification` | Claude needs your permission or input | On · `Glass` sound · never held back by the cooldown |
| `subagentStop` | A subagent finishes | Off (too noisy) |

The `notification` event fires on `permission_prompt|idle_prompt` by default. That matcher lives in `settings.json`; change it by re-running `/notify:setup`.

## Command details

### `/notify:setup`

- **Before writing anything** it shows hooks from other tools on the same events (notify's are added alongside, never replacing them) and asks what to do if notify is already installed: **Update**, **Replace** or **Cancel**. Update replaces the old hook entries and re-copies `notify.sh`.
- **`jq`.** Setup tells you if `jq` is missing. notify still fires without it, but can't read your settings or Claude's reply, so every notification uses the defaults and a generic message.
- **Dry run.** `/notify:setup --dry-run` shows the script, hook entries and config it would write, and writes nothing.
- **Scopes.** Global hooks fire in every project; project hooks fire only in that project. If you install both, both fire and you get two notifications per event. To move scopes, run setup with the new scope, then `/notify:uninstall` on the old one.

### `/notify:check`

Reports each installed scope, warns about hook entries from notify before 2.1.0 (not async) and an outdated `notify.sh`, and shows your settings. Run it after editing `notify-config.json` by hand or when notifications stop.

### `/notify:uninstall`

Removes entries whose command contains `notify.sh` from that scope's `settings.json`, then deletes `hooks/notify.sh` and `notify-config.json`. `terminal-notifier`, `notify-send` and `jq` stay installed. Each scope is removed on its own.

## Example

`/notify:setup` on macOS with a 30-second cooldown on `stop`, then two replies close together:

```
> /notify:setup

Detecting platform … macOS
terminal-notifier … not found. Install it with Homebrew? (yes)
jq … found
Editor detected: VS Code (com.microsoft.VSCode)

Where should notifications be configured?
  1. Global — every project (~/.claude/)
  2. This project only

> 1

  stop          on    sound: Hero    cooldown: 30s
  notification  on    sound: Glass
  subagentStop  off
  Claude's text in notifications: shown

Copying notify.sh to ~/.claude/hooks/
Adding 3 async hooks to ~/.claude/settings.json
Writing ~/.claude/notify-config.json
Sending test notification … ✓

# first reply finishes → notification
  ┌──────────────────────────────────────┐
  │ Claude Code                          │
  │ feedback-saas / feat/onboarding-flow │
  │ Refactored auth middleware …         │
  └──────────────────────────────────────┘

# second reply 8 seconds later → held back (8s < 30s cooldown)
```

## Configuration

Settings live in `notify-config.json` in the scope folder. Edit it directly; changes apply on the next event. Each installed copy of `notify.sh` reads the config in its own scope — there is no merge between global and project.

| Key | Where | Default | Meaning |
|---|---|---|---|
| `enabled` | per event | on (`subagentStop` off) | Turn an event on or off |
| `message` | per event | "Task completed" etc. | Fallback text: used when Claude's text isn't available or is hidden |
| `sound` | per event | `Hero` / `Glass` / `Ping` | macOS sound name, or `none`. On Linux it maps to urgency |
| `activate` | per event | your editor | macOS app brought forward on click, or `none` |
| `minDurationSeconds` | per event | `0` | Cooldown: after a `stop`/`subagentStop` notification fires, hold further ones for this many seconds. Tracked per session |
| `showMessage` | top level or per event | `true` | `false` hides Claude's text; only `message` is shown. A per-event value wins |

## Platform support

| Platform | Backend | Sound | Click-to-focus | Cooldown |
|---|---|---|---|---|
| macOS | `terminal-notifier` | 14 system sounds | Yes (bundle ID) | Yes |
| Linux | `notify-send` (libnotify) | Urgency levels only | No | Yes |

**WSL.** `notify-send` reaches the Linux desktop only if a notification daemon is running. For Windows toasts, use a Windows notifier or one of the alternatives below.

## Troubleshooting

- **No notifications (macOS)** — System Settings → Notifications → terminal-notifier: allow notifications, and check Focus / Do Not Disturb. The first notification after installing `terminal-notifier` may trigger the macOS permission prompt; if nothing appears, open it once from Finder or run `brew reinstall terminal-notifier`.
- **Generic text instead of Claude's reply** — `jq` is missing, or `showMessage` is `false`. Run `/notify:check`.
- **Wrong app comes forward on click** — change `activate` for that event in `notify-config.json`.
- **Sound doesn't play (macOS)** — test the name: `terminal-notifier -title Test -message Test -sound <Name>`. Names are in `/System/Library/Sounds/`.
- **Two notifications per event** — notify is installed both globally and in this project. Uninstall one scope.
- **Setup was interrupted** — re-run `/notify:setup`; it finds the partial install and offers Update or Replace.

## Prerequisites

- **macOS:** [Homebrew](https://brew.sh) to install `terminal-notifier`, or install it yourself.
- **Linux:** `notify-send` (package `libnotify-bin`, `libnotify`) and a running notification daemon.
- **Both:** `jq` (recommended; macOS 15 and later include it), `git` for the `repo / branch` subtitle, Bash.

## Alternatives

notify is deliberately small: a hook script, a cooldown and a subtitle. If you need Windows support, webhooks (Slack, Discord, Telegram) or more event types, these community projects do more:

- [`777genius/claude-notifications-go`](https://github.com/777genius/claude-notifications-go) — Windows and webhooks, one Go binary
- [`cfngc4594/agent-notify`](https://github.com/cfngc4594/agent-notify) — Claude Code, Cursor and Codex from one config
- [`dazuiba/CCNotify`](https://github.com/dazuiba/CCNotify) and [`mylee04/code-notify`](https://github.com/mylee04/code-notify) — focused macOS options

## More

- Documentation: [apurvbazari.github.io/claude-plugins/notify](https://apurvbazari.github.io/claude-plugins/notify/)
- Internals (event model, parsing, script safety): [`CONVENTIONS.md`](https://github.com/ApurvBazari/claude-plugins/blob/main/notify/CONVENTIONS.md)
- Issues: [github.com/ApurvBazari/claude-plugins/issues](https://github.com/ApurvBazari/claude-plugins/issues)
- Other plugins in this collection: [ApurvBazari/claude-plugins](https://github.com/ApurvBazari/claude-plugins)

## License

MIT — see [LICENSE](https://github.com/ApurvBazari/claude-plugins/blob/main/notify/LICENSE).
