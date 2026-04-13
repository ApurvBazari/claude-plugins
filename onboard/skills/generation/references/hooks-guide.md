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
        "command": "...",
        "timeout": 10000
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "command": "...",
        "timeout": 10000
      }
    ]
  }
}
```

## Hook Events

| Event | When It Fires | Common Use |
|---|---|---|
| `SessionStart` | At the start of a new Claude Code session | Inject reminders, load plugin integration context |
| `PreToolUse` | Before a tool executes | Validation, pre-checks, feature-start detection |
| `PostToolUse` | After a tool executes | Formatting, linting, post-processing |
| `Stop` | When Claude finishes a turn | Post-turn reminders, phase-end hooks |
| `WorktreeCreate` | After `EnterWorktree` creates a worktree | Run `init.sh`, bootstrap worktree environment |
| `WorktreeRemove` | After `ExitWorktree(action: "remove")` deletes a worktree | Clean up worktree-specific state, log completion |

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
        "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md) npx prettier --write \"$file\" 2>/dev/null ;; esac; exit 0",
        "timeout": 10000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.py) black --quiet \"$file\" 2>/dev/null ;; esac; exit 0",
        "timeout": 10000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.go) gofmt -w \"$file\" 2>/dev/null ;; esac; exit 0",
        "timeout": 10000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path') && case \"$file\" in *.rs) rustfmt \"$file\" 2>/dev/null ;; esac; exit 0",
        "timeout": 10000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path') && case \"$file\" in *.ts|*.tsx|*.js|*.jsx) npx eslint --no-error-on-unmatched-pattern \"$file\" 2>&1 | head -20 ;; esac; exit 0",
        "timeout": 15000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path') && case \"$file\" in *.py) ruff check \"$file\" 2>&1 | head -20 ;; esac; exit 0",
        "timeout": 10000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.rb) rubocop -a --fail-level fatal \"$file\" 2>/dev/null ;; esac; exit 0",
        "timeout": 15000
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
        "command": "file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || cat - | grep -o '\"file_path\": *\"[^\"]*\"' | head -1 | sed 's/.*: *\"//;s/\"//') && case \"$file\" in *.py) ruff check --fix --quiet \"$file\" 2>/dev/null ;; esac; exit 0",
        "timeout": 10000
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
