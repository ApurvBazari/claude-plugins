# Wizard Skill — Notification Preferences

You are guiding a developer through customizing their Claude Code notification preferences. This wizard configures which events trigger notifications, what sounds play, duration filtering, and which app activates on click. Works on macOS (terminal-notifier) and Linux (notify-send).

## Conversation Style

- **Conversational, not interrogative** — Acknowledge each answer before moving on.
- **Show defaults** — Always present the current default and let the developer confirm or change.
- **Group questions per event** — Ask 2-3 related questions together for each event, not one at a time.
- **Be concise** — Each exchange should be brief.

## Reference Data

See `references/notification-options.md` for available sounds, hook events, matcher patterns, and app bundle IDs.

## Wizard Flow

### Step 0: Detect Platform & Editor

Detect the platform first:

```bash
uname -s
```

- `Darwin` → macOS (uses `terminal-notifier` with sounds and app activation)
- `Linux` → Linux (uses `notify-send` with urgency levels, no custom sounds or app activation)

On macOS, detect the user's editor for the "Activate" default. Check for running processes:

```bash
ps aux | grep -i -E 'Cursor|Code|Windsurf' | grep -v grep | head -1
```

Map to bundle IDs:
- "Cursor" → `com.todesktop.230313mzl4w4u92`
- "Code" (VS Code) → `com.microsoft.VSCode`
- "Windsurf" → `com.codeium.windsurf`
- If none detected, default to `com.microsoft.VSCode` and ask the user to confirm.

On Linux, skip the editor/bundle-ID detection and `activate` config — `notify-send` does not support click-to-focus.

Use the detected editor as the default "Activate" value for all events below (macOS only).

Walk through each of the three hook events. For each event, ask as a group:

### Event 1: Task Completed (Stop hook)

Present:
> **Task Completed** — fires when Claude finishes a response.
>
> Notifications show a truncated version of Claude's actual response. The "message" below is a **fallback** — it only appears when contextual information can't be extracted.
>
> Current defaults:
> - Fallback message: "Task completed"
> - Sound: Hero
> - Activate: <detected editor>
>
> Would you like to keep these defaults, or customize the fallback message, sound, or app?

If the developer wants to customize, present sound options from the reference and ask which app to activate.

When the developer specifies a custom app, validate the bundle ID exists on their system:

```bash
mdfind "kMDItemCFBundleIdentifier == '<bundle-id>'" | head -1
```

If no result is returned, warn:
> That bundle ID wasn't found on your system. Double-check the ID, or proceed and update it later in `notify-config.json`.

### Duration Filtering

After configuring Event 1, ask about duration filtering:

> **Duration filtering** — suppress notifications for fast responses.
>
> If set, the `stop` notification only fires when Claude has been working for at least this many seconds. This prevents notification spam for quick follow-up questions.
>
> Recommended: `30` seconds (skips trivial responses, notifies for real work).
> Set to `0` to always notify (default).
>
> What minimum duration would you like? (0/10/30/60, or a custom value)

Apply the chosen `minDurationSeconds` to the `stop` event. The `notification` event should keep `minDurationSeconds: 0` since attention prompts should always fire immediately.

### Event 2: Needs Attention (Notification hook)

Present:
> **Needs Attention** — fires when Claude needs your input (permission prompts, idle).
>
> The notification message comes from Claude's notification payload. The "message" below is a **fallback** for when that payload is unavailable.
>
> Current defaults:
> - Fallback message: "Needs your attention"
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

When the developer specifies a custom sound, validate it exists:

```bash
ls /System/Library/Sounds/ | sed 's/\.aiff$//' | grep -ix '<sound-name>'
```

If no match is found, warn:
> That sound name wasn't found in macOS system sounds. Available sounds include: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink. Proceed anyway?

## Output

After all three events are configured, compile the settings into the notify-config.json format:

```json
{
  "version": "1.0.0",
  "events": {
    "stop": {
      "enabled": true,
      "message": "...",
      "sound": "...",
      "activate": "...",
      "minDurationSeconds": 30
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

Note: On Linux, omit the `activate` field from each event (not supported by `notify-send`).

Present a summary table before confirming:

> Here are your notification settings:
>
> | Event | Enabled | Message | Sound | Min Duration | App |
> |-------|---------|---------|-------|-------------|-----|
> | Task completed | ... | ... | ... | ...s | ... |
> | Needs attention | ... | ... | ... | — | ... |
> | Subagent done | ... | ... | ... | — | ... |
>
> Look good?

On Linux, replace the "App" column with "Urgency" and show the mapped urgency level instead.

Wait for confirmation before returning to the setup command.

## Key Rules

1. **Always show defaults** — Never assume. Let the developer see what they're getting.
2. **Respect "keep defaults"** — If they say defaults are fine, move on immediately.
3. **4 exchanges max** — The wizard should complete in at most 4 back-and-forth exchanges (events + duration, or fewer if defaults are accepted).
4. **Platform-aware** — On Linux, skip sound selection (show urgency mapping), skip `activate` config, skip `mdfind` validation. On macOS, full customization.
