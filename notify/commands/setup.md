# /notify:setup — Notification Setup

You are running the notify setup command. This installs and configures system notifications for Claude Code. Supports macOS (`terminal-notifier`) and Linux (`notify-send`).

## Overview

Tell the developer:

> Starting **notify** setup — I'll check dependencies, walk you through notification preferences, and configure hooks so you get native system notifications when Claude completes tasks or needs your attention.

---

## Dry-Run Mode

If the user includes "dry-run" or "--dry-run" in their command arguments:
- Run all steps normally (dependency check, scope selection, customization)
- At Step 6 (Generate Artifacts), instead of writing files, **display** what would be written:
  - Show the `notify.sh` script content
  - Show the hook entries that would be merged into `settings.json`
  - Show the `notify-config.json` content
- Skip Step 7 (Test) and Step 8 (Handoff)
- End with: "Dry run complete — no files were written. Re-run without `--dry-run` to apply."

## Step 1: Detect Platform & Check Dependencies

Run `uname -s` to detect the platform.

**macOS (Darwin):**
Run `which terminal-notifier` via Bash.
- If installed: `terminal-notifier is installed. Good to go.`
- If missing: offer to install via `scripts/install-notifier.sh`. If Homebrew is also missing, show install instructions and stop.

**Linux:**
Run `which notify-send` via Bash.
- If installed: `notify-send is available. Good to go.`
- If missing: show installation instructions from `scripts/install-notifier.sh` output (distro-specific `apt`/`dnf`/`pacman` commands) and stop.

Note: On Linux, sounds are not supported (mapped to urgency levels) and click-to-focus (`activate`) is not available. Inform the developer of these differences.

---

## Step 2: Choose Install Scope

Ask the developer to choose an install scope:

> Where should notifications be configured?
>
> 1. **Global** (default) — Notifications for all projects (`~/.claude/`)
> 2. **This project only** — Notifications scoped to this project directory (`$PWD/.claude/`)

If the developer picks "Global" (or accepts the default), set:
- `BASE_DIR` = the absolute path of `$HOME/.claude`

If the developer picks "This project only", set:
- `BASE_DIR` = the absolute path of `$PWD/.claude`

Resolve `BASE_DIR` to a fully expanded absolute path (no `~` or relative segments).

Show confirmation:
> Installing to: `<resolved BASE_DIR>` (<global|this project only>)

All subsequent steps use `$BASE_DIR` for file paths.

---

## Step 2.5: Check for Hook Conflicts

Read `$BASE_DIR/settings.json` if it exists. Check for any existing hooks on `Stop`, `Notification`, or `SubagentStop` events that are NOT from notify (i.e., their `command` does not contain `notify.sh`).

**If conflicting hooks found:**
> I found existing hooks on these events that aren't from notify:
>
> | Event | Command (truncated) |
> |-------|-------------------|
> | Stop | `<first 60 chars of command>` |
> | Notification | `<first 60 chars of command>` |
>
> Notify hooks will be **added alongside** these — they won't be replaced. Both will fire on the same events.
>
> Is that okay, or would you like to review your existing hooks first?

If the developer wants to review, show the full hook entries and let them decide. If they confirm, proceed.

**If no conflicts**, proceed silently.

---

## Step 3: Detect Existing Configuration

Check for existing notification hooks:

1. Read `$BASE_DIR/settings.json` — look for hooks with `Stop`, `Notification`, or `SubagentStop` events that reference `notify.sh`
2. Check if `$BASE_DIR/hooks/notify.sh` exists
3. Check if `$BASE_DIR/notify-config.json` exists

**If existing config found:**
> I found an existing notification setup:
> - [list what was found]
>
> Would you like to:
> 1. **Update** — Reconfigure with new preferences
> 2. **Replace** — Start fresh with new settings
> 3. **Cancel** — Keep the current setup

If "Cancel", stop. If "Update" or "Replace", continue (Replace removes old config first).

**If no existing config**, proceed directly.

---

## Step 4: Present Defaults & Offer Customization

Present the default configuration:

> Here are the default notification settings:
>
> | Event | Message | Sound | Activate App |
> |-------|---------|-------|-------------|
> | Task completed | "Task completed" | Hero | VS Code |
> | Needs attention | "Needs your attention" | Glass | VS Code |
> | Subagent done | *(off by default)* | — | — |
>
> The "Needs attention" event uses a **matcher** (`permission_prompt|idle_prompt`) to filter which Notification events trigger it. You can customize this during setup or edit `notify-config.json` later.
>
> Would you like to:
> 1. **Use these defaults** — Set up immediately
> 2. **Customize** — Walk through preferences for each event

---

## Step 5: Customization (if requested)

If the developer chooses "Customize", use the `wizard` skill to walk through each event's preferences. The wizard will return the final configuration.

If "Use defaults", use these values (omit `activate` on Linux):

```json
{
  "version": "1.0.0",
  "events": {
    "stop": {
      "enabled": true,
      "message": "Task completed",
      "sound": "Hero",
      "activate": "com.microsoft.VSCode",
      "minDurationSeconds": 0
    },
    "notification": {
      "enabled": true,
      "matcher": "permission_prompt|idle_prompt",
      "message": "Needs your attention",
      "sound": "Glass",
      "activate": "com.microsoft.VSCode"
    },
    "subagentStop": {
      "enabled": false,
      "message": "Subagent task completed",
      "sound": "Ping",
      "activate": "com.microsoft.VSCode"
    }
  }
}
```

---

## Step 6: Generate Artifacts

Generate the following files based on the configuration:

### 6a: Write `$BASE_DIR/hooks/notify.sh`

Create the directory and copy the notification script from the plugin's source, then make it executable:

```bash
mkdir -p $BASE_DIR/hooks
cp "${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh" "$BASE_DIR/hooks/notify.sh"
chmod +x "$BASE_DIR/hooks/notify.sh"
```

The script supports both macOS (`terminal-notifier`) and Linux (`notify-send`), auto-detects the platform, reads config from `notify-config.json` at runtime, and supports duration-based filtering via `minDurationSeconds`.

### 6b: Merge hooks into `$BASE_DIR/settings.json`

Read the existing `$BASE_DIR/settings.json` (create if it doesn't exist). Merge hook entries into the `hooks` object **non-destructively** — preserve all existing keys and hooks.

**Always register all three events.** The hook command only passes the event name — all preferences (enabled, sound, message fallback, activate) are read from `notify-config.json` at runtime. Use the fully resolved absolute `$BASE_DIR` path in all command strings (no `~`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$BASE_DIR/hooks/notify.sh stop",
            "timeout": 10
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "$BASE_DIR/hooks/notify.sh notification",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$BASE_DIR/hooks/notify.sh subagentStop",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

The `matcher` stays in `settings.json` (Claude Code evaluates it before invoking the hook). All other preferences come from `notify-config.json` at runtime.

### 6c: Write `$BASE_DIR/notify-config.json`

Write the full configuration JSON. The `message` field in each event is the **fallback message** — it's used only when contextual information can't be extracted from Claude's response. Normally, notifications show a truncated version of Claude's actual response.

---

## Step 7: Test

Run a test notification by piping mock JSON through the new script:

```bash
echo '{"last_assistant_message":"Setup complete — notifications are working!"}' | $BASE_DIR/hooks/notify.sh stop
```

Ask the developer if they saw the notification.

**If yes:**
> Setup complete! You'll now get native system notifications when Claude finishes tasks or needs your attention.

**If no (macOS):**
> Let's troubleshoot:
> 1. Check System Settings > Notifications > terminal-notifier — make sure notifications are allowed
> 2. Try running manually: `terminal-notifier -title "Test" -message "Hello" -sound "Glass"`
> 3. Run `/notify:status` for a full health check

**If no (Linux):**
> Let's troubleshoot:
> 1. Make sure a notification daemon is running (e.g., `dunst`, `mako`, or your desktop environment's built-in)
> 2. Try running manually: `notify-send "Test" "Hello"`
> 3. If running in SSH/headless, notifications require a display server
> 4. Run `/notify:status` for a full health check

---

## Step 8: Handoff

> **What was set up:**
> - `$BASE_DIR/hooks/notify.sh` — The notification script
> - `$BASE_DIR/settings.json` — Hooks that trigger notifications on Claude events
> - `$BASE_DIR/notify-config.json` — Your preferences (edit this to change settings)
>
> **Scope:** <global | this project only (`$BASE_DIR`)>
>
> **To change settings later:**
> - Edit `$BASE_DIR/notify-config.json` — changes take effect immediately (no need to re-run setup)
> - Toggle events on/off by setting `"enabled": true/false` in the config
> - The only setting that requires re-running setup is the Notification `matcher` (stored in `settings.json`)
> - Run `/notify:status` to check everything is working

If the scope is per-project, add:
> **Note:** These hooks only fire when Claude Code is running inside this project directory. Global hooks (if any) still apply alongside project-level hooks.

**Scope migration**: To move notifications from global to per-project (or vice versa), run `/notify:setup` again with the new scope. Then run `/notify:uninstall` against the old scope to clean up the previous configuration.
