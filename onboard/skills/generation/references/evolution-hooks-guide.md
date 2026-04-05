# Auto-Evolution Hook Templates

Patterns for configuring FileChanged and SessionStart hooks that keep AI tooling in sync with the codebase.

## Hook Architecture

```
FileChanged hooks (command-type, fast, no AI)
  ├── detect-dep-changes.sh     → logs to forge-drift.json
  ├── detect-config-changes.sh  → logs to forge-drift.json
  └── detect-structure-changes.sh → logs to forge-drift.json

SessionStart hook (prompt-type, AI-powered)
  └── reads forge-drift.json, summarizes changes
```

## Settings.json Hook Entries

### FileChanged Hooks

```json
{
  "hooks": {
    "FileChanged": [
      {
        "matcher": "package.json|pyproject.toml|Cargo.toml|go.mod|Gemfile",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/scripts/detect-dep-changes.sh \"$FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "tsconfig*.json|.eslintrc*|prettier.config*|.prettierrc*|biome.json|ruff.toml",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/scripts/detect-config-changes.sh \"$FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "**",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/scripts/detect-structure-changes.sh \"$FILE_PATH\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check if .claude/forge-drift.json exists and has entries since the last session. If drift is detected, briefly summarize what changed and suggest the developer run /forge:evolve to update tooling. If no drift, say nothing."
          }
        ]
      }
    ]
  }
}
```

### Auto-Update Variant

For `autoEvolutionMode: "auto-update"`, replace the FileChanged hooks with versions that directly update tooling:

```json
{
  "type": "command",
  "command": "bash .claude/scripts/detect-dep-changes.sh \"$FILE_PATH\" --auto-update"
}
```

The `--auto-update` flag tells the script to update CLAUDE.md and rules directly instead of just logging to the drift file.

## Drift File Format

`.claude/forge-drift.json`:

```json
{
  "lastAuditedAt": "2026-04-05T10:00:00Z",
  "entries": [
    {
      "timestamp": "2026-04-05T14:23:00Z",
      "file": "package.json",
      "type": "dependency",
      "changes": [
        { "action": "added", "name": "zod", "version": "^3.24.0" },
        { "action": "removed", "name": "joi" }
      ]
    },
    {
      "timestamp": "2026-04-05T15:10:00Z",
      "file": "tsconfig.json",
      "type": "config",
      "changes": [
        { "key": "compilerOptions.strict", "from": "false", "to": "true" }
      ]
    },
    {
      "timestamp": "2026-04-05T16:30:00Z",
      "file": "src/services/",
      "type": "structure",
      "changes": [
        { "action": "new-directory", "path": "src/services/", "fileCount": 3 }
      ]
    }
  ]
}
```

## Merging with Existing Hooks

When adding Forge hooks to settings.json:

1. Read existing `.claude/settings.json`
2. Parse the `hooks` object
3. For each event type (FileChanged, SessionStart):
   - If the event type doesn't exist, add it
   - If it exists, append Forge's hook entries to the existing array
   - Never replace existing entries (onboard may have format/lint hooks)
4. Write back the merged settings

Example merge scenario:
```
BEFORE (from onboard):
  hooks.PostToolUse = [{ formatter hook }, { linter hook }]

AFTER (forge adds):
  hooks.PostToolUse = [{ formatter hook }, { linter hook }]  ← preserved
  hooks.FileChanged = [{ dep hook }, { config hook }, { structure hook }]  ← added
  hooks.SessionStart = [{ drift summary hook }]  ← added
```

## Agent Team Quality Hooks

**Conditional**: Only generate these when the project is production-scale with a team (`isProduction && hasTeam`) or when agent teams are explicitly enabled.

### TaskCreated Hook

Enforce descriptive task subjects to maintain clarity in the shared task list:

```json
{
  "TaskCreated": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash -c 'INPUT=$(cat); SUBJECT=$(echo \"$INPUT\" | python3 -c \"import json,sys; print(json.load(sys.stdin).get('\\''task_subject'\\'' ,'\\'''\\''))\" 2>/dev/null || echo \"\"); if [ ${#SUBJECT} -lt 10 ]; then echo \"Task subject too vague (${#SUBJECT} chars). Use a descriptive subject like: [Build login API endpoint with JWT validation]\" >&2; exit 2; fi; exit 0'"
        }
      ]
    }
  ]
}
```

Exit code 2 blocks task creation and feeds the error message back to Claude.

### TaskCompleted Hook

Require tests to pass before a task can be marked complete:

```json
{
  "TaskCompleted": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "[TEST_COMMAND] 2>&1 || { echo 'Tests must pass before completing a task. Fix failing tests first.' >&2; exit 2; }"
        }
      ]
    }
  ]
}
```

Replace `[TEST_COMMAND]` with the project's actual test command:
- Node.js: `npm test` or `npx vitest run`
- Python: `pytest`
- Go: `go test ./...`
- Rust: `cargo test`

Exit code 2 prevents task completion and sends the test failure output back to the teammate.

### TeammateIdle Hook (Optional)

Keep teammates working if there are still pending tasks:

```json
{
  "TeammateIdle": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash -c 'PENDING=$(cat .claude/tasks/*/?.json 2>/dev/null | python3 -c \"import json,sys; tasks=[json.loads(l) for l in sys.stdin if l.strip()]; print(sum(1 for t in tasks if t.get('\\''status'\\'')=='\\''pending'\\'' ))\" 2>/dev/null || echo 0); if [ \"$PENDING\" -gt 0 ]; then echo \"$PENDING tasks still pending. Check the task list for unclaimed work.\" >&2; exit 2; fi; exit 0'"
        }
      ]
    }
  ]
}
```

Exit code 2 prevents the teammate from going idle and sends feedback to keep working.
