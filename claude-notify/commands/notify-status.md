# /claude-notify:notify-status — Health Check

You are running a health check for the claude-notify plugin. Verify that all components are installed and configured correctly.

## Checks

Run through each check and report the result:

### 1. terminal-notifier

Run `which terminal-notifier` via Bash.

- **Pass**: `terminal-notifier` found at [path]
- **Fail**: `terminal-notifier` is not installed. Run `/claude-notify:setup` to install it.

### 2. Notification Script

Check if `~/.claude/hooks/notify.sh` exists and is executable.

- **Pass**: `notify.sh` exists and is executable
- **Fail**: `notify.sh` is missing or not executable. Run `/claude-notify:setup` to create it.

### 3. Hook Configuration

Read `~/.claude/settings.json` and check for notification hooks (Stop, Notification, SubagentStop events referencing `notify.sh`).

- **Pass**: Found hooks for [list events]
- **Fail**: No notification hooks found in settings.json. Run `/claude-notify:setup` to configure them.

### 4. Config File

Read `~/.claude/notify-config.json` and display current settings.

- **Pass**: Config found. Display as a table:

> **Current notification settings:**
>
> | Event | Enabled | Message | Sound | App |
> |-------|---------|---------|-------|-----|
> | Task completed | ... | ... | ... | ... |
> | Needs attention | ... | ... | ... | ... |
> | Subagent done | ... | ... | ... | ... |

- **Fail**: Config file not found. Settings may have been configured manually.

### Summary

Present a summary:

> **Health Check Results:**
> | Component | Status |
> |-----------|--------|
> | terminal-notifier | Pass/Fail |
> | notify.sh | Pass/Fail |
> | Hook config | Pass/Fail |
> | notify-config.json | Pass/Fail |

If all pass:
> Everything looks good! Would you like me to send a test notification?

If any fail:
> Some components need attention. Run `/claude-notify:setup` to fix the issues above.

### Test Notification

If the developer requests a test, run:

```bash
~/.claude/hooks/notify.sh "Claude Code" "Health check — notifications working!" "Glass" "<activate-from-config>"
```

Report whether it succeeded.
