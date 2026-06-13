---
name: uninstall
description: Use only when the user explicitly invokes /notify:uninstall — removes notify's hooks and config while leaving other settings intact. User-invoked only.
disable-model-invocation: true
---

# Uninstall Skill — Remove Notification Setup

You are running the notify uninstall skill. This cleanly removes all notification hooks, scripts, and config files installed by the notify plugin.

---

## Step 1: Detect Install Scope

Check both locations for notify artifacts:

1. **Global**: `~/.claude/hooks/notify.sh`, `~/.claude/notify-config.json`
2. **Project**: `$PWD/.claude/hooks/notify.sh`, `$PWD/.claude/notify-config.json`

**If found in both:**
> I found notify installed in two locations:
> - Global (`~/.claude/`)
> - This project (`$PWD/.claude/`)
>
> Which would you like to uninstall?
> 1. **Global only**
> 2. **This project only**
> 3. **Both**

**If found in one location**, proceed with that location. Set `BASE_DIR` accordingly.

**If not found in either:**
> No notify installation found. Nothing to uninstall.

Stop.

---

## Step 2: Confirm

> This will remove:
> - `$BASE_DIR/hooks/notify.sh` — the notification script
> - `$BASE_DIR/notify-config.json` — your notification preferences
> - Hook entries in `$BASE_DIR/settings.json` that reference `notify.sh`
>
> Your other hooks and settings will not be affected.
>
> Proceed with uninstall?

Wait for confirmation. If declined, stop.

---

## Step 3: Remove Hook Entries from settings.json

Read `$BASE_DIR/settings.json`. Remove only hook entries whose `command` field contains `notify.sh`. Preserve all other hooks and settings.

For each hook event (`Stop`, `Notification`, `SubagentStop`):
- If the hooks array for that event contains a notify hook, remove that specific entry
- If the hooks array becomes empty after removal, remove the empty array key
- If the `hooks` object becomes empty, remove it

Write the updated settings.json back.

---

## Step 4: Delete Notify Files

```bash
rm -f "$BASE_DIR/hooks/notify.sh"
rm -f "$BASE_DIR/notify-config.json"
```

If `$BASE_DIR/hooks/` directory is now empty, remove it:
```bash
rmdir "$BASE_DIR/hooks" 2>/dev/null || true
```

---

## Step 5: Verify

Read `$BASE_DIR/settings.json` and confirm no notify hooks remain.

> Uninstall complete. Removed:
> - [list files deleted]
> - [list hook entries removed from settings.json]
>
> Your other Claude settings are unchanged.

## Key Rules

- **Explicit confirmation required before any deletion** — Step 2 presents the full list of what will be removed and waits for the developer's response. Never delete files or hook entries without this confirmation.
- **`settings.json` removal is surgical** — only entries whose `command` field contains `notify.sh` are removed. All other hooks, settings, and keys in the file are preserved verbatim. Never overwrite the whole file.
- **Scope selection requires detection, not assumption** — Step 1 probes both global and project locations before offering scope choices. If only one scope has artifacts, proceed with that scope directly without asking. If neither has artifacts, stop immediately.
- **Empty arrays and objects are cleaned up** — after removing notify hook entries, if a hook event array becomes empty, remove the array key. If the `hooks` object itself becomes empty, remove it. Leave `settings.json` in the minimal clean state, not with dangling empty containers.
- **Hooks directory is removed only when empty** — `rmdir "$BASE_DIR/hooks"` is run only after deleting `notify.sh`. If other files exist in the directory, the `rmdir` will fail silently (via `2>/dev/null || true`) — this is correct behavior; do not force-remove.
