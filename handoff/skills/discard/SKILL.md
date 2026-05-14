---
name: discard
description: Archive the active handoff without acting on it. Use when the user explicitly wants to discard a saved handoff — same effect as picking Discard in the resume flow, but invokable directly from anywhere.
disable-model-invocation: true
---

# Discard Skill — Archive the Active Handoff

You are invoked explicitly by `/handoff:discard`. Archive the active handoff (`.claude/handoff.md`) so it stops surfacing at SessionStart. This skill is destructive in the soft sense — the file is archived (renamed), not deleted, so it remains recoverable.

## Step 1: Check for an active handoff

Look for `.claude/handoff.md`. If it does not exist:

> No active handoff in this project. Nothing to clear.

Stop. Do not prompt; do not modify anything.

## Step 2: Confirm before archiving

Read the frontmatter `saved-at` field. Show it to the user and confirm via AskUserQuestion (single-select, 2 options):

- **Yes, archive** *(Recommended if you don't want this handoff anymore)* — "Move `.claude/handoff.md` to `.claude/handoff.discarded-<ts>.md`. The next SessionStart will not surface anything."
- **No, keep it** — "Do nothing. The handoff stays in place."

If **No**: exit silently. Do not modify the file.

## Step 3: Archive the handoff

On **Yes**:

```bash
ts="$(date +%Y%m%dT%H%M%S)"
mv .claude/handoff.md ".claude/handoff.discarded-${ts}.md"
```

Confirm to the user (one line):

> Handoff archived to `.claude/handoff.discarded-<ts>.md`. Cleared.

## Key Rules

- **Always confirm before archiving** — `disable-model-invocation: true` means only the user can trigger this, but a confirm step still prevents fat-finger mistakes.
- **Archive, never delete.** The renamed file is recoverable; user can `mv .claude/handoff.discarded-<ts>.md .claude/handoff.md` to restore.
- **No-op when nothing is saved.** Do not create or modify state if there's no active handoff.
- **AskUserQuestion guard**: 2-option static list. No dynamic single-option risk.
