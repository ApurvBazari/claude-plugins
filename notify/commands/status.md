# /notify:status — Health Check

You are running a health check for the notify plugin. Verify that all components are installed and configured correctly.

## Scope Detection

Before running checks, detect which scopes have notifications installed:

1. Check if `$HOME/.claude/hooks/notify.sh` exists → **Global** scope found
2. Check if `$PWD/.claude/hooks/notify.sh` exists → **Project** scope found (label as "Project: `$PWD/.claude`")

If both exist, run checks for each scope separately, labeled accordingly. If neither exists, report that no installation was found.

---

## Checks

Run through each check per discovered scope. The terminal-notifier check is shared (run once).

### 1. terminal-notifier (shared)

Run `which terminal-notifier` via Bash.

- **Pass**: `terminal-notifier` found at [path]
- **Fail**: `terminal-notifier` is not installed. Run `/notify:setup` to install it.

### 2. Notification Script

For each discovered scope (`$SCOPE_DIR` = the base directory):

Check if `$SCOPE_DIR/hooks/notify.sh` exists and is executable.

- **Pass**: `notify.sh` exists and is executable
- **Fail**: `notify.sh` is missing or not executable. Run `/notify:setup` to create it.

### 3. Hook Configuration

Read `$SCOPE_DIR/settings.json` and check for notification hooks (Stop, Notification, SubagentStop events referencing `notify.sh`).

- **Pass**: Found hooks for [list events]
- **Fail**: No notification hooks found in settings.json. Run `/notify:setup` to configure them.

### 4. Config File

Read `$SCOPE_DIR/notify-config.json` and display current settings.

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

Present a summary. When both scopes are active, include a Scope column:

**Single scope:**
> **Health Check Results:**
> | Component | Status |
> |-----------|--------|
> | terminal-notifier | Pass/Fail |
> | notify.sh | Pass/Fail |
> | Hook config | Pass/Fail |
> | notify-config.json | Pass/Fail |

**Both scopes active:**
> **Health Check Results:**
> | Component | Scope | Status |
> |-----------|-------|--------|
> | terminal-notifier | Shared | Pass/Fail |
> | notify.sh | Global | Pass/Fail |
> | notify.sh | Project | Pass/Fail |
> | Hook config | Global | Pass/Fail |
> | Hook config | Project | Pass/Fail |
> | notify-config.json | Global | Pass/Fail |
> | notify-config.json | Project | Pass/Fail |

If all pass:
> Everything looks good! Would you like me to send a test notification?

If any fail:
> Some components need attention. Run `/notify:setup` to fix the issues above.

### Test Notification

If the developer requests a test:

**Single scope:** Run the test against that scope's notify.sh:
```bash
$SCOPE_DIR/hooks/notify.sh "Claude Code" "Health check — notifications working!" "Glass" "<activate-from-config>"
```

**Both scopes active:** Ask which scope to test:
> Both global and project-level notifications are configured. Which would you like to test?
> 1. **Global** (`$HOME/.claude`)
> 2. **Project** (`$PWD/.claude`)
> 3. **Both**

Then run the test for the chosen scope(s).

Report whether it succeeded.
