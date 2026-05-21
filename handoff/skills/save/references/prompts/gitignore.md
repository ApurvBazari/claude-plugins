# Gitignore Prompt — Save Step 8

Verbatim prompt content for `save/SKILL.md` Step 8. This is the authoritative source — do not paraphrase the option text when presenting to the user.

## Pre-conditions (caller's responsibility before presenting)

Skip the prompt entirely if any apply:
- `.gitignore` does not exist (the file isn't in a versioned context).
- `.gitignore` already contains the literal line `.claude/handoff/`.
- `.claude/handoff/settings.md` has `gitignore-prompt: never` in its frontmatter.

## AskUserQuestion (single-select, 3 options)

- **Add `.claude/handoff/` to .gitignore** *(Recommended)* — "I'll append it now and write a settings file so this prompt doesn't repeat."
- **Skip — I'll handle it** — "Don't touch .gitignore. Persist the choice so you don't ask again."
- **Don't ask again** — "Don't add it, and persist the choice."

## Per-option behavior

| Selection | Action |
|---|---|
| Add | Append `.claude/handoff/` to `.gitignore` on its own line (preceded by a blank line if the file doesn't end in one). Do NOT write to settings — future saves will skip via the "pattern already in .gitignore" pre-condition. |
| Skip — I'll handle it | Do not modify `.gitignore`. Write `gitignore-prompt: never` to `.claude/handoff/settings.md` via `merge-fm-key.sh`. |
| Don't ask again | Identical to "Skip — I'll handle it". The label distinction is purely UX (whether the user inspected vs dismissed); the effective behavior is the same. |

## Helper invocation for settings write

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/merge-fm-key.sh" \
  .claude/handoff/settings.md gitignore-prompt never
```

The helper handles file-missing, key-missing, and key-present cases atomically.
