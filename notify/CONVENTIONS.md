# notify — Internal Conventions

System notifications for Claude Code on macOS (`terminal-notifier`) and Linux (`notify-send`).

## Platform Support

| Platform | Backend | Sound | Click-to-Focus | Cooldown |
|----------|---------|-------|----------------|-----------------|
| macOS | `terminal-notifier` | 14 system sounds | Yes (bundle ID) | Yes |
| Linux | `notify-send` (libnotify) | Urgency levels only | No | Yes |

## Hook Event Model

Three notification events, each independently configurable:

| Event | When | Default |
|-------|------|---------|
| `stop` | Claude finishes a response | Enabled, "Hero" sound |
| `notification` | Claude needs user attention | Enabled, "Glass" sound |
| `subagentStop` | A subagent finishes work | Disabled (too noisy) |

## Notification Cooldown

Each `stop`/`subagentStop` event supports `minDurationSeconds` as a **leading-edge cooldown** — at most one notification per `N` seconds:
- When a notification fires, the cooldown clock is stamped (a temp file keyed per session: `$TMPDIR/claude-notify-session-<id>`, or `claude-notify-uid-<uid>` when no session id is present)
- A subsequent `stop`/`subagentStop` within `N` seconds of the last fired notification is silently skipped; suppressed events do NOT refresh the clock (leading-edge — see spec 2026-07-02 §6a)
- `notification` events are never cooldown-*filtered* (attention prompts always fire) — but a fired `notification` still *refreshes* the shared per-session clock, so it can debounce a `stop`/`subagentStop` that lands within `N` seconds. "At most one notification per `N` seconds" counts every fired alert, whatever its event type
- Default `0` means no cooldown

## Config Resolution

- Config stored in `notify-config.json` under the chosen scope directory — global under `~/.claude/`, per-project under `<project>/.claude/`
- Wizard creates/updates this file during `/notify:setup`
- Changes take effect immediately — no restart needed

### Scope resolution

Each installed copy of `notify.sh` reads the `notify-config.json` in its own scope folder (`BASE_DIR` = the script's folder's parent): the global copy reads `~/.claude/notify-config.json`, a project copy reads `<project>/.claude/notify-config.json`. There is no cross-scope key merge. Claude Code runs hooks from every settings file, so when both scopes are installed both hooks fire and you get two notifications per event.

### onboard

onboard never wires notify itself. It probes whether the plugin is installed (`${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh`) and delegates to `/notify:setup`; `.github/scripts/check-notify-delegation.sh` guards this. Keep `scripts/notify.sh` at that path.

## Script Safety

- `notify.sh` is a hook script — it MUST always `exit 0`
- Never block Claude execution, even on notification failure: setup writes every hook entry with `"async": true`
- Print nothing to stdout — an async hook's JSON stdout is delivered to Claude on the next turn. Notifier output goes to `/dev/null`
- Missing notification backend (terminal-notifier or notify-send) should fail silently
- No inline programs (`python3 -c`, `bash -c`) and no package launchers in `notify.sh`

## JSON Parsing Pattern

`notify.sh` parses JSON with `jq` only, through `json_fields()`: one `jq` call per document (the hook input once, the config once) that prints every needed value NUL-terminated, read back with `read -d ''`. `null` becomes an empty string; booleans and numbers become their text (`false`, `30`).

`jq` is recommended, not required. Without it the script skips parsing: it uses the per-event defaults and the fallback message, keys the cooldown per user, and still exits 0. `/notify:setup` and `/notify:check` report a missing `jq`.

## Git Context for Subtitle

Notifications show repo + branch context:
- `git rev-parse --show-toplevel` → repo name via `basename`
- `git rev-parse --abbrev-ref HEAD` → branch name
- Falls back to `basename "$PWD"` if not in a git repo

## Message Handling

- Extract contextual text from stdin JSON (`.last_assistant_message` or `.message`)
- `showMessage: false` (per event, else top level; default `true`) replaces that text with the fallback message
- Sanitize: replace newlines with spaces
- Truncate to 80 characters + "..."
- Fall back to configured default message if extraction fails

## Installation Scopes

- **Global** (`~/.claude/settings.json`): hooks fire in every project
- **Per-project** (`<project>/.claude/settings.json`): hooks fire only in that project
- Both can coexist; each fires its own hooks with its own config (see Scope resolution)
- The wizard detects the running editor (VS Code, Cursor, Windsurf) for bundle ID (macOS only)

## Skills

User-facing skills (show in `/notify:` autocomplete):

- `setup/SKILL.md` — install + configure notifications (`disable-model-invocation: true`)
- `check/SKILL.md` — health check (auto-invocable)
- `uninstall/SKILL.md` — remove hooks + config (`disable-model-invocation: true`)

Internal building blocks (`user-invocable: false`):

- `wizard/SKILL.md` — preference wizard invoked by setup for customization
