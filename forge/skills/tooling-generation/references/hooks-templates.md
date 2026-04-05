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
