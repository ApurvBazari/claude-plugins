# notify — Internal Conventions

macOS system notifications for Claude Code via `terminal-notifier`.

## Hook Event Model

Three notification events, each independently configurable:

| Event | When | Default |
|-------|------|---------|
| `stop` | Claude finishes a response | Enabled, "Hero" sound |
| `notification` | Claude needs user attention | Enabled, "Glass" sound |
| `subagentStop` | A subagent finishes work | Disabled (too noisy) |

## Config Resolution

- Config stored in `notify-config.json` (plugin-local, not `.claude/`)
- Wizard creates/updates this file during `/notify:setup`
- Changes take effect immediately — no restart needed
- Both global (`~/.claude/`) and per-project (`<project>/.claude/`) scopes supported

## Script Safety

- `notify.sh` is a hook script — it MUST always `exit 0`
- Never block Claude execution, even on notification failure
- `terminal-notifier` absence should fail silently

## JSON Parsing Pattern

All scripts use the `json_get()` helper:
1. Try `jq` first (preferred)
2. Fall back to `python3 -c` with inline JSON parsing
3. Return empty string on failure — never crash

This pattern avoids hard dependencies on either tool.

## Git Context for Subtitle

Notifications show repo + branch context:
- `git rev-parse --show-toplevel` → repo name via `basename`
- `git rev-parse --abbrev-ref HEAD` → branch name
- Falls back to `basename "$PWD"` if not in a git repo

## Message Handling

- Extract contextual text from stdin JSON (`.last_assistant_message` or `.message`)
- Sanitize: replace newlines with spaces
- Truncate to 80 characters + "..."
- Fall back to configured default message if extraction fails

## Installation Scopes

- **Global** (`~/.claude/settings.json`): hooks fire in every project
- **Per-project** (`<project>/.claude/settings.json`): hooks fire only in that project
- Per-project extends/overrides global — both can coexist
- The wizard detects the running editor (VS Code, Cursor, Windsurf, iTerm2) for bundle ID
