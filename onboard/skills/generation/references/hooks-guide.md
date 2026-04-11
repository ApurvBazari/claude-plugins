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

### SessionStart reminder (advisory, ≤ 3 lines)

Purpose: surface Plugin Integration discipline at the start of every session so it doesn't drift out of context over long conversations.

**Script** (`<project>/.claude/hooks/plugin-integration-reminder.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Generated by onboard — plugin integration session-start reminder
# Advisory only. Always exits 0.

echo "Session reminder: Starting new feature work? Begin with /superpowers:brainstorming."
echo "See root CLAUDE.md § Plugin Integration for the full workflow."
exit 0
```

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
- Concatenate all qualifying `sessionStart[].message` values and truncate to **≤ 3 lines total** regardless of how many entries exist.
- Script must pass `shellcheck -x`.

### Feature-start detector (advisory, PreToolUse on Write)

Purpose: non-blocking reminder when Claude creates a new file in a domain-critical directory, nudging toward brainstorming without blocking the write.

**Script** (`<project>/.claude/hooks/feature-start-detector.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Generated by onboard — feature-start detector
# Advisory only. Always exits 0. Non-blocking.

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || \
            echo "$input" | grep -o '"tool_name": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
[ "$tool_name" != "Write" ] && exit 0

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || \
            echo "$input" | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
[ -z "$file_path" ] && exit 0

# Only fire on new file creation
[ -f "$file_path" ] && exit 0

# Skip generated / build / git paths
case "$file_path" in
  */build/*|*/generated/*|*/.git/*) exit 0 ;;
esac

# Critical-dir match — regex generated from qualityGates.featureStart[].criticalDirs
critical_regex='(domain/parser/|ui/compose/|data/db/)'
if ! echo "$file_path" | grep -Eq "$critical_regex"; then
  exit 0
fi

# Skip if brainstorming already fired in this session
marker=".claude/session-state/brainstormed-${CLAUDE_SESSION_ID:-unknown}"
[ -f "$marker" ] && exit 0

echo "Reminder: creating $file_path in a domain-critical directory."
echo "Consider /superpowers:brainstorming and the relevant feature-dev skill first."
exit 0
```

**Settings entry**:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/feature-start-detector.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

**Generation rules**:
- Only generate when `qualityGates.featureStart` has at least one entry with non-empty `criticalDirs`.
- Build the `critical_regex` by regex-escaping each `criticalDirs` entry and joining with `|` inside a `()` group.
- Never use `exit 2` — this hook is **always** advisory.
- Always exclude `**/build/**`, `**/generated/**`, `**/.git/**` to avoid firing on generated files.
- Script must pass `shellcheck -x`.

### Pre-commit blocking hook (from `qualityGates.preCommit`)

Purpose: boundary enforcement — block commits that would ship unreviewed or unverified work. This is a blocking hook (`exit 2`) by default in `balanced` / `autonomous` autonomy, downgraded to advisory (`exit 0`) in `always-ask` autonomy.

**Script pattern** (`<project>/.claude/hooks/pre-commit-<skill-slug>.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

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
set -euo pipefail

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
