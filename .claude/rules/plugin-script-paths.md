---
paths:
  - "onboard/**"
  - "forge/**"
  - "notify/**"
---

# Plugin Script Path Convention

When a SKILL.md, agent, or reference invokes a shell script, use the canonical path form matching the invocation context. Mixing forms causes Claude to resolve paths unpredictably relative to the source file's directory, producing exit-code-127 failures on the first attempt (2026-04-17 release-gate finding B7).

## The three contexts

| Context | Example | Form |
|---|---|---|
| In-plugin script | onboard calls its own `detect-lsp-signals.sh` | `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` |
| Cross-plugin script | onboard calls notify's `install-notifier.sh` | `${CLAUDE_PLUGIN_ROOT}/../<other-plugin>/scripts/<name>.sh` |
| Generated-artifact script (inside hooks written to user project) | Evolution hook shells out to `detect-dep-changes.sh` | `.claude/scripts/<name>.sh` (project-relative) |

## Why `${CLAUDE_PLUGIN_ROOT}`

Bare relative forms (`scripts/foo.sh`, `../scripts/foo.sh`) get resolved from the *source file's* directory when Claude executes them. For a skill at `onboard/skills/wizard/SKILL.md`, that resolves to `onboard/skills/wizard/scripts/foo.sh` — which doesn't exist. `${CLAUDE_PLUGIN_ROOT}` is populated by Claude Code to the plugin's root directory, so the path is always unambiguous.

## Canonical examples

✅ **In-plugin (onboard calling its own script):**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh" "$PROJECT_ROOT"
```

✅ **Cross-plugin (onboard calling notify's script):**

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null
bash "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/install-notifier.sh"
```

✅ **Generated hook (written to user's `.claude/scripts/`):**

```jsonc
{
  "hooks": {
    "FileChanged": [
      {
        "command": "bash .claude/scripts/detect-dep-changes.sh \"$FILE_PATH\""
      }
    ]
  }
}
```

## Anti-patterns

❌ **Bare relative — resolves unpredictably:**

```bash
bash scripts/detect-lsp-signals.sh "$PROJECT_ROOT"
```

❌ **Parent-relative — works today only by coincidence:**

```bash
bash ../scripts/detect-lsp-signals.sh "$PROJECT_ROOT"
```

❌ **Absolute paths — break across machines:**

```bash
bash /Users/alice/.claude/plugins/onboard/scripts/detect-lsp-signals.sh
```

## When `${CLAUDE_PLUGIN_ROOT}` is unset

If the variable isn't populated (unusual — only happens if running outside a plugin context), surface an error pointing to this rule. Do not silently fall back to a relative form.

## Linting

Repository-level audit — every non-generated script reference in plugin SKILL.md, agent files, or references MUST use one of the two plugin-aware forms above:

```bash
grep -rE '`(bash |ls )?\.{0,2}/?scripts/[a-z-]+\.sh' onboard/ forge/ notify/ \
  | grep -v 'CLAUDE_PLUGIN_ROOT' \
  | grep -v '\.claude/scripts/'
# Expect: no output
```
