# Wizard Skill — Notification Preferences

You are guiding a developer through customizing their Claude Code notification preferences. This wizard configures which events trigger macOS notifications, what sounds play, and which app activates on click.

## Conversation Style

- **Conversational, not interrogative** — Acknowledge each answer before moving on.
- **Show defaults** — Always present the current default and let the developer confirm or change.
- **Group questions per event** — Ask 2-3 related questions together for each event, not one at a time.
- **Be concise** — Each exchange should be brief.

## Reference Data

See `references/notification-options.md` for available sounds, hook events, matcher patterns, and app bundle IDs.

## Wizard Flow

### Step 0: Detect Editor

Before presenting event defaults, detect the user's editor for the "Activate" default. Check for running processes:

```bash
ps aux | grep -i -E 'Cursor|Code|Windsurf' | grep -v grep | head -1
```

Map to bundle IDs:
- "Cursor" → `com.todesktop.230313mzl4w4u92`
- "Code" (VS Code) → `com.microsoft.VSCode`
- "Windsurf" → `com.codeium.windsurf`
- If none detected, default to `com.microsoft.VSCode` and ask the user to confirm.

Use the detected editor as the default "Activate" value for all events below.

Walk through each of the three hook events. For each event, ask as a group:

### Event 1: Task Completed (Stop hook)

Present:
> **Task Completed** — fires when Claude finishes a response.
>
> Current defaults:
> - Message: "Task completed"
> - Sound: Hero
> - Activate: <detected editor>
>
> Would you like to keep these defaults, or customize the message, sound, or app?

If the developer wants to customize, present sound options from the reference and ask which app to activate.

### Event 2: Needs Attention (Notification hook)

Present:
> **Needs Attention** — fires when Claude needs your input (permission prompts, idle).
>
> Current defaults:
> - Message: "Needs your attention"
> - Sound: Glass
> - Activate: VS Code
> - Matcher: permission_prompt|idle_prompt
>
> Would you like to keep these defaults, or customize?

### Event 3: Subagent Done (SubagentStop hook)

Present:
> **Subagent Done** — fires when a spawned subagent finishes.
>
> This is **off by default** since subagents fire frequently and can be noisy.
>
> Would you like to enable notifications for subagent completion?

If enabled, ask for message, sound, and app preferences.

## Output

After all three events are configured, compile the settings into the notify-config.json format:

```json
{
  "version": "0.1.0",
  "events": {
    "stop": {
      "enabled": true,
      "message": "...",
      "sound": "...",
      "activate": "..."
    },
    "notification": {
      "enabled": true,
      "matcher": "...",
      "message": "...",
      "sound": "...",
      "activate": "..."
    },
    "subagentStop": {
      "enabled": false,
      "message": "...",
      "sound": "...",
      "activate": "..."
    }
  }
}
```

Present a summary table before confirming:

> Here are your notification settings:
>
> | Event | Enabled | Message | Sound | App |
> |-------|---------|---------|-------|-----|
> | Task completed | ... | ... | ... | ... |
> | Needs attention | ... | ... | ... | ... |
> | Subagent done | ... | ... | ... | ... |
>
> Look good?

Wait for confirmation before returning to the setup command.

## Key Rules

1. **Always show defaults** — Never assume. Let the developer see what they're getting.
2. **Respect "keep defaults"** — If they say defaults are fine, move on immediately.
3. **3 exchanges max** — The wizard should complete in at most 3 back-and-forth exchanges (one per event, or fewer if defaults are accepted).
