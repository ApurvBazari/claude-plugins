# notify — Internal Conventions

Cross-platform system notifications for Claude Code. macOS via `terminal-notifier`, Linux via `notify-send`.

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
- `notification` events are never cooldown-filtered (attention prompts always fire)
- Default `0` means no cooldown

## Config Resolution

- Config stored in `notify-config.json` under the chosen scope directory — global under `~/.claude/`, per-project under `<project>/.claude/`
- Wizard creates/updates this file during `/notify:setup`
- Changes take effect immediately — no restart needed
- At runtime, `notify.sh` reads the project-local `notify-config.json` when present, else the global one

### Precedence (project-local inherits + overrides global)

When both `~/.claude/notify-config.json` and `<project>/.claude/notify-config.json` exist:

1. The **project-local config inherits all keys from the global config**.
2. Keys explicitly set in the project-local config **override** the global value.
3. Keys absent from the project-local config **fall back** to the global value.

Example: global has `events.stop.sound = "Glass"` and `events.stop.minDurationSeconds = 5`. Project-local sets only `events.stop.message = "Build complete"`. The merged behavior at runtime is `{ sound: "Glass", minDurationSeconds: 5, message: "Build complete" }`.

This precedence is applied at notify setup time (when project-local is being written) — `/onboard:start` § Step 3.5.2 reads global as the base and layers project-local override on top, persisting the merged result. Runtime hook (`notify.sh`) reads only the project-local file when present, falling back to global only when no project-local file exists at all.

### Detection (used by /onboard:start before offering project-local setup)

To probe whether global notify is already configured **strictly** (both required to count as configured):
- `~/.claude/notify-config.json` exists.
- `~/.claude/settings.json` has a hook entry whose command references **both** `notify.sh` AND `notify-config.json` (single match — both strings present).

If both probes pass, /onboard:start informs the user that global covers them and skips the project-local offer entirely. If only one passes (`globalPartial`), it offers project-local with a hint to repair the global setup.

## Script Safety

- `notify.sh` is a hook script — it MUST always `exit 0`
- Never block Claude execution, even on notification failure
- Missing notification backend (terminal-notifier or notify-send) should fail silently

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
- The wizard detects the running editor (VS Code, Cursor, Windsurf) for bundle ID (macOS only)

## Skills

User-facing skills (show in `/notify:` autocomplete):

- `setup/SKILL.md` — install + configure notifications (`disable-model-invocation: true`)
- `check/SKILL.md` — health check (auto-invocable)
- `uninstall/SKILL.md` — remove hooks + config (`disable-model-invocation: true`)

Internal building blocks (`user-invocable: false`):

- `wizard/SKILL.md` — preference wizard invoked by setup for customization
