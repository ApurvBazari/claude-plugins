# Hooks Configuration Guide

Hooks are shell commands that run automatically in response to Claude Code events. They're configured in `.claude/settings.json` (shared) or `.claude/settings.local.json` (personal).

---

## Settings File Structure

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "...", "timeout": 10000 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "...", "timeout": 10000 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "...", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

### Schema — read carefully

Each event (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `WorktreeCreate`, etc.) maps to an **array of entries**. Each entry is an object with:

- `matcher` (optional) — tool name pattern for `PreToolUse` / `PostToolUse`, or event-specific filter for others. Omit for events that don't filter (e.g., `Stop`, `SessionStart`).
- `hooks` (**required**) — an array of command objects. Each command object has:
  - `type` (required) — always `"command"` for shell hooks
  - `command` (required) — the shell string to execute
  - `timeout` (optional) — milliseconds before the hook is killed

The nested `hooks: [...]` wrapper is **required**. A flat shape like `{ "type": "command", "command": "..." }` placed directly inside the event array is **invalid** and Claude Code will refuse to load the settings file.

#### ❌ INVALID — Claude Code will reject this

```json
{
  "hooks": {
    "Stop": [
      { "type": "command", "command": "echo 'reminder'" }
    ]
  }
}
```

#### ✅ VALID — the nested form

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "echo 'reminder'" }
        ]
      }
    ]
  }
}
```

When generating a `settings.json` entry for any event, always wrap command objects inside a `hooks:` array — never place them directly in the event array.

## Hook Events

| Event | When It Fires | Common Use |
|---|---|---|
| `SessionStart` | At the start of a new Claude Code session | Inject reminders, load plugin integration context |
| `SessionEnd` | When a session terminates | Flush session state, rotate task markers, final log |
| `UserPromptSubmit` | When the user submits a prompt, before Claude processes it | Redact secrets, preflight guardrails, prompt telemetry |
| `PreToolUse` | Before a tool executes | Validation, pre-checks, feature-start detection |
| `PostToolUse` | After a tool executes | Formatting, linting, post-processing |
| `Stop` | When Claude finishes a turn | Post-turn reminders, phase-end hooks |
| `PreCompact` | Before context compaction (matcher: `manual` / `auto`) | Checkpoint session-state, flush scratch notes, warn on auto-compact |
| `SubagentStart` | When a subagent is spawned | Audit logging, subagent gating, session marker seeding |
| `TaskCreated` | When a task is created via `TaskCreate` | Enforce descriptive task subjects, sync with external trackers |
| `TaskCompleted` | When a task is marked completed | Run verification gates, emit notifications, update dashboards |
| `FileChanged` | When a watched file changes on disk (matcher: filename glob) | Drift detection, auto-regen, reload dev server |
| `ConfigChange` | When a configuration file changes during a session (matcher: source filter) | Warn on policy drift, re-read project settings, audit config provenance |
| `Elicitation` | When an MCP server requests user input during a tool call (matcher: MCP server name) | Audit MCP prompts, gate sensitive elicitations, log for compliance |
| `WorktreeCreate` | After `EnterWorktree` creates a worktree | Run `init.sh`, bootstrap worktree environment |
| `WorktreeRemove` | After `ExitWorktree(action: "remove")` deletes a worktree | Clean up worktree-specific state, log completion |

> **Matcher compatibility**: not every event accepts a `matcher` field. When generating settings entries, omit `matcher` for events that don't filter — Claude Code silently ignores matchers on unsupported events, but omitting them keeps generated JSON honest. See the Matcher Compatibility table below.

### Matcher Compatibility

| Event | Matcher semantics |
|---|---|
| `SessionStart` / `SessionEnd` / `Stop` / `UserPromptSubmit` / `SubagentStart` / `SubagentStop` / `TaskCompleted` / `WorktreeCreate` / `WorktreeRemove` | **No matcher** — omit the field. |
| `PreToolUse` / `PostToolUse` | **Tool-name matcher** (`"Write"`, `"Edit"`, `"Bash"`, `""` for all). |
| `PreCompact` | **Trigger matcher** — one of `"manual"` / `"auto"` / `""` (both). |
| `TaskCreated` | **Optional** — omit; `task_subject` regex matching is not supported today. |
| `FileChanged` | **Filename-glob matcher** — e.g., `"package.json|tsconfig.json"`. Required in practice; omitting means "watch every file" and is almost never what you want. |
| `ConfigChange` | **Source filter** — one of `user_settings` / `project_settings` / `local_settings` / `policy_settings` / `skills`, or `""` for all. |
| `Elicitation` | **MCP server name** — e.g., `"vercel"`. Omit for all servers. |
| `Notification` | **Notification-type matcher** — e.g., `"permission_prompt|idle_prompt"`. |

Generation rule: when a caller or wizard answer maps to a matcher-incompatible event, the generator MUST omit the `matcher` field (do not emit `"matcher": ""` either — leave it absent). When a matcher IS supported, prefer the narrowest pattern that satisfies the intent; omit entirely only when the hook truly applies to every invocation.

### Blocking vs Advisory Modes

Hook scripts signal intent via their exit code:

| Exit code | Effect |
|---|---|
| `0` | **Advisory** — stdout is surfaced to Claude as context; Claude continues. Use for reminders, nudges, post-action info. |
| `2` | **Blocking** (PreToolUse only) — stderr is surfaced to Claude as a tool error; Claude cannot complete the action without addressing it. Use for boundary-enforcement (pre-commit validation, safety checks). |
| Other non-zero | Non-blocking error — treated similarly to exit 0 but surfaces as a failure signal in logs. |

**Rule of thumb**: enforce at boundaries (pre-commit, pre-destructive-action) with `exit 2`. Guide in the middle (session start, feature-start reminder) with `exit 0`. Never use `exit 2` for individual edits — it creates ergonomic friction and forces devs to bypass hooks entirely.

## Matcher

The `matcher` field filters which tool triggers the hook:

- `"Write"` — Triggers when Claude writes/creates a file
- `"Edit"` — Triggers when Claude edits a file
- `"Bash"` — Triggers when Claude runs a bash command
- `""` (empty string) — Matches all tools

## Command

The `command` field is a shell command. It receives event data via stdin as JSON:

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "content": "..."
  }
}
```

The command can:
- **Exit 0** — Success, proceed normally
- **Exit non-zero** — Block the action (for PreToolUse) or signal failure
- **Output to stdout** — Message shown to Claude as feedback

## Parsing Event Data

Hook commands receive JSON via stdin. Use `jq` if available, with a `grep`/`sed` fallback:

```bash
# Preferred (requires jq)
file=$(cat - | jq -r '.tool_input.file_path')

# Fallback (no jq dependency)
file=$(cat - | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
```

When generating hooks, prefer the fallback-safe version to avoid `jq` as a hard dependency:

```bash
file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
```

## Common Hook Patterns

### Auto-Format on Write (Prettier)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md) npx prettier --write \"$file\" 2>/dev/null ;; esac; exit 0",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

### Auto-Format on Write (Black — Python)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.py) black --quiet \"$file\" 2>/dev/null ;; esac; exit 0",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

### Auto-Format on Write (gofmt — Go)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.go) gofmt -w \"$file\" 2>/dev/null ;; esac; exit 0",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

### Auto-Format on Write (rustfmt — Rust)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path') && case \"$file\" in *.rs) rustfmt \"$file\" 2>/dev/null ;; esac; exit 0",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

### Lint Check on Edit (ESLint)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path') && case \"$file\" in *.ts|*.tsx|*.js|*.jsx) npx eslint --no-error-on-unmatched-pattern \"$file\" 2>&1 | head -20 ;; esac; exit 0",
            "timeout": 15000
          }
        ]
      }
    ]
  }
}
```

### Lint Check on Edit (Ruff — Python)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path') && case \"$file\" in *.py) ruff check \"$file\" 2>&1 | head -20 ;; esac; exit 0",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

### Auto-Fix on Write (RuboCop — Ruby)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.rb) rubocop -a --fail-level fatal \"$file\" 2>/dev/null ;; esac; exit 0",
            "timeout": 15000
          }
        ]
      }
    ]
  }
}
```

### Auto-Fix on Write (Ruff — Python)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.py) ruff check --fix --quiet \"$file\" 2>/dev/null ;; esac; exit 0",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

## Generation Guidelines

1. **Only add hooks for tools that exist** — Check that prettier/eslint/black/etc. are actually installed (detected in analysis)
2. **Use PostToolUse, not PreToolUse** for formatting — Don't block writes, format after
3. **Always include timeout** — Prevent hanging hooks from blocking Claude
4. **Exit 0 on formatting hooks** — Formatting failures shouldn't block Claude's work
5. **Merge with existing settings.json** — Read the file first, merge the hooks key, write back. Never overwrite other settings.
6. **Use `.claude/settings.json`** for shared hooks (team conventions) — These get committed
7. **Guard with file extension checks** — Don't run prettier on .py files or black on .ts files
8. **Keep commands simple** — Complex logic should be in a separate script file

## Autonomy-Based Hook Selection

The developer's `autonomyLevel` determines which hooks are auto-generated:

### "Always Ask" — No auto hooks
Do not generate any hooks that run automatically. Instead, add a comment block in `settings.json` listing available hooks the developer can enable manually:

```json
{
  "_available_hooks_comment": "Uncomment hooks below to enable auto-formatting and linting. See .claude/rules/ for details.",
  "hooks": {}
}
```

### "Balanced" — Auto-format + lint check (advisory)
Generate PostToolUse hooks for auto-formatting and advisory lint checks on Write:
- Prettier, Black, gofmt, rustfmt (whichever is detected)
- Lint check on Edit (PostToolUse) — advisory only, does not block

### "Autonomous" — Auto-format + lint + pre-commit validation
Generate the full hook suite:
- Auto-format on Write (PostToolUse)
- Lint check on Edit (PostToolUse) — enforced
- Pre-commit validation if a pre-commit framework is detected

## Shared vs Personal Hooks

### Shared Hooks (`.claude/settings.json` — committed to repo)

Team-wide hooks that enforce shared conventions:
- Auto-format on Write (team's chosen formatter)
- Lint check on Edit (team's linter configuration)
- Any hooks that enforce team standards

These are committed to the repository so all team members and Claude get the same behavior.

### Personal Hooks (`.claude/settings.local.json` — gitignored)

Individual developer overrides:
- Disable a shared hook that conflicts with personal workflow
- Add personal productivity hooks
- Override timeout values for slower machines

Personal settings merge with shared settings. When both define a hook for the same matcher/event, the personal version takes precedence.

Note this distinction in the generated root CLAUDE.md so developers know where to configure hooks.

## Settings Merge Strategy

When the project already has `.claude/settings.json`:

```
1. Read existing file
2. Parse JSON
3. If "hooks" key exists:
   a. For each event (SessionStart, PreToolUse, PostToolUse, Stop):
      - Check if a hook with the same matcher already exists
      - If yes, skip (don't duplicate)
      - If no, append the new hook
4. If "hooks" key doesn't exist:
   - Add the entire hooks object
5. Preserve all other keys (permissions, etc.)
6. Write back
```

---

## Quality-Gate Hook Templates (from `callerExtras.qualityGates`)

These templates implement the Plugin Integration enforcement philosophy: boundary enforcement (blocking) at commit, advisory reminders at session-start and feature-start. Generated by onboard when `callerExtras.qualityGates` is present in headless context.

### SessionStart reminder (advisory, adaptive suppression)

Purpose: surface Plugin Integration discipline at the start of every session so it doesn't drift out of context over long conversations. Automatically suppresses to a 1-line pointer after 5 consecutive fires without brainstorming, then restores when brainstorming occurs.

**Script** (`<project>/.claude/hooks/plugin-integration-reminder.sh`):

```bash
#!/usr/bin/env bash
set -u  # no -e / -o pipefail — see skills/generation/SKILL.md § O7 § Shell options for hook scripts

# Generated by onboard — plugin integration session-start reminder
# Advisory only. Always exits 0.
# Adaptive: suppresses to 1-line pointer after 5 fires without brainstorming.

counter_file=".claude/session-state/plugin-integration-reminder-count"
state_dir=".claude/session-state"

# Ensure state directory exists
mkdir -p "$state_dir"

# Read current counter (0 if file missing)
count=0
if [ -f "$counter_file" ]; then
  count=$(cat "$counter_file" 2>/dev/null || echo 0)
  # Reset if brainstorming happened since last reminder
  if find "$state_dir" -maxdepth 1 -name 'brainstormed-*' -newer "$counter_file" -print -quit 2>/dev/null | grep -q .; then
    count=0
  fi
fi

# Emit reminder (full or abbreviated)
if [ "$count" -lt 5 ]; then
  echo "Session reminder: Starting new feature work? Begin with /superpowers:brainstorming."
  echo "See root CLAUDE.md § Plugin Integration for the full workflow."
else
  echo "See CLAUDE.md § Plugin Integration."
fi

# Increment and persist counter
count=$((count + 1))
echo "$count" > "$counter_file"
exit 0
```

**Adaptive suppression behavior**:
- **Counter file**: `.claude/session-state/plugin-integration-reminder-count` tracks consecutive fires without brainstorming
- **Threshold**: 5 — sessions 1-5 get the full 2-line reminder, session 6+ gets a 1-line pointer
- **Reset**: when any `brainstormed-*` marker file in `.claude/session-state/` is newer than the counter file, the counter resets to 0 and the full reminder resumes
- **First run**: counter file doesn't exist yet, defaults to 0, full reminder fires

**Settings entry**:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/plugin-integration-reminder.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

**Generation rules**:
- Only generate when `qualityGates.sessionStart` has at least one entry whose `condition` is satisfied (e.g., `"superpowers-installed"` + superpowers is in `installedPlugins`).
- Concatenate all qualifying `sessionStart[].message` values and truncate to **≤ 3 lines total** for the full reminder form. The abbreviated (suppressed) form emits exactly 1 line.
- Script must pass `shellcheck -x`.

### Feature-start detector (advisory, PreToolUse on Write)

Purpose: non-blocking reminder when Claude creates a new file in a domain-critical directory, nudging toward brainstorming without blocking the write.

> **Authoritative spec**: the full generation contract for this hook lives in [`skills/generation/SKILL.md` § O7 — Feature-start detector PreToolUse hook](../SKILL.md). That section contains the **8 required behavioral invariants** (MUST-include checks) + the reference implementation. Do not maintain a duplicate template here — edit SKILL.md § O7 if you need to change detector behavior.

**Minimum checklist** (full invariant list in SKILL.md § O7):

1. Parse `tool_name` + `tool_input.file_path` from stdin (jq + grep/sed fallback)
2. Exit 0 unless `tool_name == "Write"`
3. Exit 0 if the target file already exists (new files only)
4. Exit 0 if path matches `**/build/**`, `**/generated/**`, `**/.git/**`, `**/node_modules/**`, `**/.next/**`, `**/dist/**`, `**/target/**`, `**/.gradle/**`, `**/__pycache__/**` (EC10)
5. Exit 0 if `.claude/session-state/brainstormed-${CLAUDE_SESSION_ID}` marker exists (EC8)
6. Match path against critical-dir regex built from `qualityGates.featureStart[].criticalDirs`
7. Emit reminder to **stderr** referencing `/superpowers:brainstorming`
8. Always `exit 0` — never block (never `exit 2`)

**Settings entry template**:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/feature-start-detector.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

Use `${CLAUDE_PROJECT_DIR}/.claude/hooks/...` — not a bare relative path — so the hook is cwd-independent.

**Generation rules** (condensed — full set in SKILL.md § O7):
- Only generate when `qualityGates.featureStart` has at least one entry with non-empty `criticalDirs`.
- Build the `critical_regex` by regex-escaping each `criticalDirs` entry and joining with `|` inside a `()` group.
- Never use `exit 2` — this hook is **always** advisory.
- Always exclude the 9 tool-managed paths listed above (invariant #4).
- Always check the session marker (invariant #5) — do not simplify this away.
- Script must pass `shellcheck -x`.

### Pre-commit blocking hook (from `qualityGates.preCommit`)

Purpose: boundary enforcement — block commits that would ship unreviewed or unverified work. This is a blocking hook (`exit 2`) by default in `balanced` / `autonomous` autonomy, downgraded to advisory (`exit 0`) in `always-ask` autonomy.

**Script pattern** (`<project>/.claude/hooks/pre-commit-<skill-slug>.sh`):

```bash
#!/usr/bin/env bash
set -u  # no -e / -o pipefail — see skills/generation/SKILL.md § O7 § Shell options for hook scripts

# Generated by onboard — pre-commit gate for <skill>
# Mode: blocking (exit 2 on failure) — see autonomyLevel downgrade rule.

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || \
            echo "$input" | grep -o '"tool_name": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
[ "$tool_name" != "Bash" ] && exit 0

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || \
          echo "$input" | grep -o '"command": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

# Only fire on git commit commands
case "$command" in
  *"git commit"*) : ;;
  *) exit 0 ;;
esac

# Check for the gate skill's artifact (e.g., verification marker, review report)
# The specific check varies per skill — this is a placeholder.
marker=".claude/session-state/<skill-slug>-ok"
if [ ! -f "$marker" ]; then
  echo "Pre-commit gate failed: run /<skill> before committing." >&2
  echo "This enforces the Plugin Integration discipline at the commit boundary." >&2
  exit 2  # Blocking — Claude cannot proceed
fi

exit 0
```

**Settings entry**:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/pre-commit-code-review.sh", "timeout": 30000 }
        ]
      }
    ]
  }
}
```

**Generation rules**:
- Generate one script per `qualityGates.preCommit[]` entry. Name scripts `pre-commit-<skill-slug>.sh` where slug is the skill's kebab-cased identifier.
- Default mode: `blocking` (`exit 2`). Downgraded to `advisory` (`exit 0` with message to stdout instead of stderr) when caller's `autonomyLevel === "always-ask"`.
- Verify the referenced plugin is in `installedPlugins` before generating. Missing → skip + warn in `onboard-meta.json`.
- Script must pass `shellcheck -x`.

### Post-feature advisory nudge (from `qualityGates.postFeature`)

Purpose: remind developer to run `claude-md-management:revise-claude-md` at phase-end so learnings get captured while fresh.

**Script pattern** (`<project>/.claude/hooks/post-feature-<skill-slug>.sh`):

```bash
#!/usr/bin/env bash
set -u  # no -e / -o pipefail — see skills/generation/SKILL.md § O7 § Shell options for hook scripts

# Generated by onboard — post-feature nudge for <skill>
# Advisory only. Always exits 0.

echo "Phase ending. Consider running /claude-md-management:revise-claude-md to capture learnings."
exit 0
```

**Settings entry**: attaches to `Stop` event (fires when Claude finishes a turn).

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-feature-revise-claude-md.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

**Generation rules**:
- Mode is always `advisory` for `postFeature` — never block on phase-end nudges.
- Verify plugin installed before generating.
- Script must pass `shellcheck -x`.

---

## Utility Hook Templates (non-telemetry)

These hooks are generated alongside quality-gate hooks but are **NOT** tracked in `hookStatus` telemetry. They serve infrastructure purposes rather than Plugin Integration discipline enforcement.

### WorktreeCreate hook (init.sh auto-runner)

Purpose: automatically bootstrap the development environment when entering a worktree via `EnterWorktree`. Runs `init.sh` if it exists, ensuring the worktree has dependencies installed and dev server config ready.

**Script** (`<project>/.claude/hooks/worktree-init.sh`):

```bash
#!/usr/bin/env bash
set -u  # no -e / -o pipefail — hook script convention

# Generated by onboard — auto-run init.sh on worktree creation
# Advisory only. Always exits 0. Non-blocking.

if [ -f "init.sh" ]; then
  echo "[onboard] Running init.sh in new worktree..."
  bash init.sh 2>&1 || echo "[onboard] Warning: init.sh exited with errors (non-fatal)" >&2
else
  echo "[onboard] No init.sh found — skipping worktree bootstrap."
fi
exit 0
```

**Settings entry**:

```json
{
  "hooks": {
    "WorktreeCreate": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/worktree-init.sh", "timeout": 30000 }
        ]
      }
    ]
  }
}
```

**Generation rules**:
- Generate when `enableHarness` is true in the generation context (harness projects typically have or will have `init.sh`).
- The script includes an existence check (`[ -f "init.sh" ]`) so it's safe to generate even if `init.sh` doesn't exist yet at generation time.
- Timeout is 30000ms (30s) — `init.sh` may install dependencies which can take time.
- This is a **utility hook** — it does **NOT** appear in `hookStatus.planned` or `hookStatus.generated`. It is outside the quality-gate telemetry scope.
- Always exits 0 — never blocks worktree creation.
- Uses `${CLAUDE_PROJECT_DIR}` for cwd-independence.
- Script must pass `shellcheck -x`.

---

## Advanced Event Templates

Templates for the 9 extended events Claude Code exposes beyond the core format/lint and quality-gate suite. All are **advisory only** — none use `exit 2`. Each is conditionally emitted by the generation skill based on wizard answers (`wizardAnswers.advancedHookEvents`) or the inference rules below.

All scripts follow the shared conventions already documented:
- `#!/usr/bin/env bash` + `set -u` (never `set -euo pipefail` — see `generation/SKILL.md` § Shell options for hook scripts)
- `shellcheck -x` must pass
- Explicit `timeout` on every settings entry
- Never `exit 2` — all events in this section are advisory

### SessionEnd — session terminates

**Payload**: common fields only (no matcher support). Useful for final state flush or log rotation.
**Matcher**: not supported — omit.
**Inference trigger**: always emit (safe stub with no side effects by default).

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — session-end cleanup hook
# Advisory only. Always exits 0.

input=$(cat 2>/dev/null || true)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || \
             printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[ -z "$session_id" ] && session_id="unknown"

state_dir=".claude/session-state"
[ -d "$state_dir" ] || exit 0

# Rotate current-task marker into per-session history (no-op if missing)
if [ -f "$state_dir/current-task" ]; then
  mv "$state_dir/current-task" "$state_dir/last-task-$session_id" 2>/dev/null || true
fi
exit 0
```

**Settings entry**:

```jsonc
{
  "hooks": {
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh", "timeout": 5000 }] }
    ]
  }
}
```

### UserPromptSubmit — user submits a prompt

**Payload**: includes `prompt` (the text the user submitted).
**Matcher**: not supported — omit.
**Inference trigger**: emit when `wizardAnswers.securitySensitivity === "high"` OR `hookify` plugin in `installedPlugins`.
**Caution**: this fires on every prompt. Keep the command fast (<200ms) or latency becomes noticeable.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/user-prompt-preflight.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — user-prompt preflight (secret scan, advisory)
# Advisory only. Always exits 0. Never blocks the prompt.

input=$(cat 2>/dev/null || true)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || \
         printf '%s' "$input" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[ -z "$prompt" ] && exit 0

# Surface a warning if the prompt looks like it contains a secret literal.
# Patterns are intentionally loose — false positives are fine, missed secrets are not.
case "$prompt" in
  *"AKIA"*|*"ghp_"*|*"sk-"*|*"Bearer "*)
    echo "[onboard] Heads up: your prompt looks like it contains a secret literal. Consider redacting before continuing." >&2
    ;;
esac
exit 0
```

**Settings entry**:

```jsonc
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/user-prompt-preflight.sh", "timeout": 2000 }] }
    ]
  }
}
```

### PreCompact — before context compaction

**Payload**: common fields plus matcher trigger (`manual` / `auto`).
**Matcher**: supported — `"manual"`, `"auto"`, or `""` for both. Prefer scoping to `"auto"` so manual compactions stay silent.
**Inference trigger**: emit when `wizardAnswers.autonomyLevel ∈ {balanced, autonomous}` AND analyzer reports >500 source files (large-context projects where auto-compact fires more often).

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-compact-checkpoint.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — pre-compact state checkpoint
# Advisory only. Always exits 0. Runs before Claude drops context.

state_dir=".claude/session-state"
mkdir -p "$state_dir"

stamp=$(date -u +'%Y%m%dT%H%M%SZ')
echo "$stamp" > "$state_dir/last-compact-at" 2>/dev/null || true

# Surface a one-line reminder so the compacted summary doesn't lose the thread
echo "[onboard] Compaction incoming — if mid-feature, re-state the goal in your next message." >&2
exit 0
```

**Settings entry**:

```jsonc
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "auto",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-compact-checkpoint.sh", "timeout": 3000 }]
      }
    ]
  }
}
```

### SubagentStart — subagent is spawned

**Payload**: includes `agent_id`, `agent_type`.
**Matcher**: not supported — omit.
**Inference trigger**: emit only when agent-team mode is enabled (`enriched.enableTeams === true`). Mirrors the existing `SubagentStop` path.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/subagent-start-audit.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — subagent audit log
# Advisory only. Always exits 0.

input=$(cat 2>/dev/null || true)
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")
agent_type=$(printf '%s' "$input" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")

log_dir=".claude/session-state"
mkdir -p "$log_dir"
printf '%s\t%s\t%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$agent_id" "$agent_type" \
  >> "$log_dir/subagent-audit.log" 2>/dev/null || true
exit 0
```

**Settings entry**:

```jsonc
{
  "hooks": {
    "SubagentStart": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/subagent-start-audit.sh", "timeout": 2000 }] }
    ]
  }
}
```

### TaskCreated — task is created via TaskCreate

**Payload**: includes `task_id`, `task_subject`, optional `task_description`, `teammate_name`, `team_name`.
**Matcher**: not meaningfully supported — omit.
**Inference trigger**: emit when agent-team mode is enabled. This replaces the prior inline template that lived in `evolution-hooks-guide.md`.
**Blocking note**: exit 2 from this event does prevent the task from being created. Keep the generated template advisory by default; switch to blocking only when the caller's `qualityGates.taskCreated[].mode === "blocking"`.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/task-created-check.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — task-created advisory gate
# Advisory only (exits 0). Swap to exit 2 when caller requests blocking mode.

input=$(cat 2>/dev/null || true)
subject=$(printf '%s' "$input" | jq -r '.task_subject // empty' 2>/dev/null || echo "")
[ -z "$subject" ] && exit 0

# Warn on vague subjects but don't block
if [ "${#subject}" -lt 10 ]; then
  echo "[onboard] Task subject looks short (${#subject} chars). Prefer descriptive subjects like 'Add JWT validation to /api/login'." >&2
fi
exit 0
```

**Settings entry**:

```jsonc
{
  "hooks": {
    "TaskCreated": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/task-created-check.sh", "timeout": 3000 }] }
    ]
  }
}
```

### TaskCompleted — task is marked completed

**Payload**: common fields only (no matcher support today).
**Matcher**: not supported — omit.
**Inference trigger**: emit when agent-team mode is enabled. This replaces the prior inline template in `evolution-hooks-guide.md`.
**Blocking note**: exit 2 prevents task completion. Default is advisory; generation should honor caller's `qualityGates.taskCompleted[].mode` when present.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/task-completed-verify.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — task-completed verification
# Advisory only by default. Replace the test command placeholder during generation.

test_cmd="${CLAUDE_TEST_COMMAND:-}"
[ -z "$test_cmd" ] && exit 0  # No test command detected during analysis; skip.

if ! eval "$test_cmd" >/dev/null 2>&1; then
  echo "[onboard] Tests failing at task completion. Fix before marking complete." >&2
fi
exit 0
```

**Settings entry**:

```jsonc
{
  "hooks": {
    "TaskCompleted": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/task-completed-verify.sh", "timeout": 60000 }] }
    ]
  }
}
```

Generation note: substitute `${CLAUDE_TEST_COMMAND}` with the actual test command discovered during analysis (`npm test`, `pytest`, `go test ./...`, `cargo test`, etc.) before writing the script. Fall through to advisory if no command was detected.

### FileChanged — watched file changes on disk

**Payload**: includes `file_path` (the changed file).
**Matcher**: filename glob — required in practice. Use `|`-separated patterns; `**` for recursion.
**Inference trigger**: emit when `enriched.enableEvolution === true`. Existing drift-detection integration in `evolution-hooks-guide.md` consumes this; keep that guide authoritative for the drift scripts, this section only covers the generic advisory template.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/file-changed-notice.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — file-changed advisory
# Advisory only. Always exits 0.

input=$(cat 2>/dev/null || true)
file_path=$(printf '%s' "$input" | jq -r '.file_path // empty' 2>/dev/null || \
            printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[ -z "$file_path" ] && exit 0

echo "[onboard] Watched file changed: $file_path" >&2
exit 0
```

**Settings entry** (scope with a concrete glob — this example watches lockfiles):

```jsonc
{
  "hooks": {
    "FileChanged": [
      {
        "matcher": "package-lock.json|pnpm-lock.yaml|yarn.lock|poetry.lock|Cargo.lock|go.sum",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/file-changed-notice.sh", "timeout": 3000 }]
      }
    ]
  }
}
```

### ConfigChange — configuration file changes during a session

**Payload**: common fields; the matcher selects the source.
**Matcher**: one of `user_settings` / `project_settings` / `local_settings` / `policy_settings` / `skills`, or `""` for all.
**Inference trigger**: emit when `.claude/rules/` or `.claude/settings.json` is under version control (analyzer signal: `versionControlledClaude === true`). Useful for warning when policy settings drift mid-session.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/config-change-warn.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — config change warning
# Advisory only. Always exits 0.

echo "[onboard] Claude config changed this session. If behavior looks off, reopen the session to reload cleanly." >&2
exit 0
```

**Settings entry** (scoped to project settings only — the most actionable source):

```jsonc
{
  "hooks": {
    "ConfigChange": [
      {
        "matcher": "project_settings",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/config-change-warn.sh", "timeout": 2000 }]
      }
    ]
  }
}
```

### Elicitation — MCP server requests user input

**Payload**: common fields plus the MCP server name in the matcher position.
**Matcher**: MCP server name (e.g., `"vercel"`), or `""` for all servers.
**Inference trigger**: emit when `.mcp.json` is present OR the analyzer flags any MCP servers in the stack. Use the matcher to scope to sensitive MCP servers only.

**Script** (`${CLAUDE_PROJECT_DIR}/.claude/hooks/elicitation-audit.sh`):

```bash
#!/usr/bin/env bash
set -u

# Generated by onboard — MCP elicitation audit log
# Advisory only. Always exits 0.

log_dir=".claude/session-state"
mkdir -p "$log_dir"
printf '%s\tmcp-elicitation\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  >> "$log_dir/mcp-elicitation.log" 2>/dev/null || true
exit 0
```

**Settings entry** (scope to specific MCP servers by listing them; omit the matcher for all servers):

```jsonc
{
  "hooks": {
    "Elicitation": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/elicitation-audit.sh", "timeout": 2000 }] }
    ]
  }
}
```

### Cross-reference

- The legacy `FileChanged` drift pipeline (`detect-dep-changes.sh`, `detect-config-changes.sh`, `detect-structure-changes.sh`) stays in `references/evolution-hooks-guide.md`. That guide now cross-references this section for the base advisory template; the drift-specific scripts are unchanged.
- Team-mode `TaskCreated` / `TaskCompleted` behavior likewise lives in `references/agent-teams-guide.md` for team-composition concerns; this section owns the event-level generation contract.
