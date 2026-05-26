# Retention Prompt — Save Step 9

Verbatim prompt content for `save/SKILL.md` Step 9. This is the authoritative source — do not paraphrase the option text when presenting to the user.

## Pre-conditions (caller's responsibility before presenting)

Skip the prompt entirely if:
- `.claude/handoff/settings.md` already has the `archive-retention` key in its frontmatter — the user has already made the choice on a prior save.

## AskUserQuestion (single-select, 4 options)

- **Default 10** *(Recommended)* — "Keep the most recent 10 archived handoffs (consumed + discarded + expired combined)."
- **5** — "Keep the most recent 5."
- **20** — "Keep the most recent 20."
- **Don't ask again** — "Use the default 10 and don't ask again."

## Per-option write to settings.md

The `archive-retention` key is written to `.claude/handoff/settings.md` via `merge-fm-key.sh` (which preserves sibling keys). Per-option mapping:

| Selection | Key written |
|---|---|
| Default 10 (Recommended) | `archive-retention: 10` |
| 5 | `archive-retention: 5` |
| 20 | `archive-retention: 20` |
| Don't ask again | `archive-retention: 10` |

"Default 10" and "Don't ask again" produce identical settings — the distinction is purely UX (whether the user inspected the default or just dismissed). No separate `retention-prompted` flag is written; the presence of the `archive-retention` key alone suppresses the prompt next time.

## Helper invocation

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/merge-fm-key.sh" \
  .claude/handoff/settings.md archive-retention <chosen-value>
```

The helper handles all three cases atomically:
- File missing → creates `.claude/handoff/settings.md` with the new key.
- File present, key absent → appends the key just before the closing `---`, preserving sibling keys.
- File present, key already there → replaces the value in place.

Substitute `<chosen-value>` with `10`, `5`, or `20` per the user's selection.
