# /claude-notify:setup — Notification Setup

You are running the claude-notify setup command. This installs and configures macOS system notifications for Claude Code using `terminal-notifier`.

## Overview

Tell the developer:

> Starting **claude-notify** setup — I'll check dependencies, walk you through notification preferences, and configure hooks so you get native macOS notifications when Claude completes tasks or needs your attention.

---

## Step 1: Dependency Check

Run `which terminal-notifier` via Bash.

**If installed:**
> `terminal-notifier` is installed. Good to go.

**If missing:**
> `terminal-notifier` is not installed. It's a lightweight macOS utility that sends native notifications from the command line.
>
> Would you like me to install it via Homebrew? (`brew install terminal-notifier`)

If yes, run `scripts/install-notifier.sh`. If Homebrew is also missing, show the install instructions and stop.

If the developer declines, explain that the plugin requires `terminal-notifier` and stop.

---

## Step 2: Detect Existing Configuration

Check for existing notification hooks:

1. Read `~/.claude/settings.json` — look for hooks with `Stop`, `Notification`, or `SubagentStop` events that reference `notify.sh`
2. Check if `~/.claude/hooks/notify.sh` exists
3. Check if `~/.claude/notify-config.json` exists

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

## Step 3: Present Defaults & Offer Customization

Present the default configuration:

> Here are the default notification settings:
>
> | Event | Message | Sound | Activate App |
> |-------|---------|-------|-------------|
> | Task completed | "Task completed" | Hero | VS Code |
> | Needs attention | "Needs your attention" | Glass | VS Code |
> | Subagent done | *(off by default)* | — | — |
>
> Would you like to:
> 1. **Use these defaults** — Set up immediately
> 2. **Customize** — Walk through preferences for each event

---

## Step 4: Customization (if requested)

If the developer chooses "Customize", use the `wizard` skill to walk through each event's preferences. The wizard will return the final configuration.

If "Use defaults", use these values:

```json
{
  "version": "0.1.0",
  "events": {
    "stop": {
      "enabled": true,
      "message": "Task completed",
      "sound": "Hero",
      "activate": "com.microsoft.VSCode"
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

## Step 5: Generate Artifacts

Generate the following files based on the configuration:

### 5a: Write `~/.claude/hooks/notify.sh`

Write the notification script and make it executable (`chmod +x`):

```bash
#!/bin/bash
TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"
SOUND="${3:-Ping}"
ACTIVATE="${4:-com.microsoft.VSCode}"
terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -activate "$ACTIVATE"
```

### 5b: Merge hooks into `~/.claude/settings.json`

Read the existing `~/.claude/settings.json` (create if it doesn't exist). Merge hook entries into the `hooks` object **non-destructively** — preserve all existing keys and hooks.

For each **enabled** event, add a hook entry:

**Stop event:**
```json
{
  "type": "command",
  "event": "Stop",
  "command": "~/.claude/hooks/notify.sh 'Claude Code' 'Task completed' 'Hero' 'com.microsoft.VSCode'"
}
```

**Notification event** (with matcher):
```json
{
  "type": "command",
  "event": "Notification",
  "command": "~/.claude/hooks/notify.sh 'Claude Code' 'Needs your attention' 'Glass' 'com.microsoft.VSCode'",
  "matcher": "permission_prompt|idle_prompt"
}
```

**SubagentStop event** (only if enabled):
```json
{
  "type": "command",
  "event": "SubagentStop",
  "command": "~/.claude/hooks/notify.sh 'Claude Code' 'Subagent task completed' 'Ping' 'com.microsoft.VSCode'"
}
```

Use the message, sound, and activate values from the developer's configuration. Replace `~` with the actual home directory path in the command strings.

### 5c: Write `~/.claude/notify-config.json`

Write the full configuration JSON for future reference and editing.

---

## Step 6: Test

Run a test notification:

```bash
~/.claude/hooks/notify.sh "Claude Code" "Setup complete — notifications are working!" "Glass" "<activate-app>"
```

Ask the developer if they saw the notification.

**If yes:**
> Setup complete! You'll now get native macOS notifications when Claude finishes tasks or needs your attention.

**If no:**
> Let's troubleshoot:
> 1. Check System Settings > Notifications > terminal-notifier — make sure notifications are allowed
> 2. Try running manually: `terminal-notifier -title "Test" -message "Hello" -sound "Glass"`
> 3. Run `/claude-notify:notify-status` for a full health check

---

## Step 7: Handoff

> **What was set up:**
> - `~/.claude/hooks/notify.sh` — The notification script
> - `~/.claude/settings.json` — Hooks that trigger notifications on Claude events
> - `~/.claude/notify-config.json` — Your preferences (edit this to change settings)
>
> **To change settings later:**
> - Edit `~/.claude/notify-config.json` directly and re-run `/claude-notify:setup`
> - Run `/claude-notify:notify-status` to check everything is working
