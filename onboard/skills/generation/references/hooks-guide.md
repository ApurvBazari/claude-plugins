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
| `PreToolUse` | Before a tool executes | Validation, pre-checks |
| `PostToolUse` | After a tool executes | Formatting, linting, post-processing |

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
   a. For each event (PreToolUse, PostToolUse):
      - Check if a hook with the same matcher already exists
      - If yes, skip (don't duplicate)
      - If no, append the new hook
4. If "hooks" key doesn't exist:
   - Add the entire hooks object
5. Preserve all other keys (permissions, etc.)
6. Write back
```
