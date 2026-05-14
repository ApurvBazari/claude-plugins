---
name: pickup
description: Present a saved handoff to the user via AskUserQuestion (Execute / Edit / Discard / Save-for-later) and dispatch on their choice. Auto-invokes when the SessionStart hook has surfaced a handoff in additionalContext — that surfacing includes a routing instruction directing you here. Also invokable explicitly via /handoff:pickup.
---

# Pickup Skill — Surface and Dispatch a Saved Handoff

You are invoked when a saved handoff exists at `.claude/handoff.md` — either because the SessionStart hook surfaced it in `additionalContext` and the routing instruction sent you here, or because the user typed `/handoff:pickup` explicitly. Present the four-option flow, then dispatch.

## Guard

Read `.claude/handoff.md` from the project root. If it does not exist:

> No saved handoff in this project. Run `/handoff:save` to capture one, or just continue with what you're doing.

Stop and do not proceed.

## Step 1: Re-read from disk (do not trust the surfaced content)

Even though the SessionStart hook may have emitted the handoff content in `additionalContext`, re-read `.claude/handoff.md` from disk now. The on-disk file is authoritative; the surfaced content is a stale snapshot if the file changed mid-session (rare but possible with concurrent Claude sessions).

Parse the frontmatter (`saved-at`, `saved-at-sha`, `saved-at-branch`, `saved-from-cwd`, optional `deferred-at`) and capture the body separately.

## Step 2: Present metadata + directive to the user

Show the user a brief preamble in this shape (use a fenced quote block):

> **Saved handoff found** — `saved-at <iso8601>` on `<branch>` (sha `<short-sha>`)
>
> Progress since save: `<commits-past> commits`, branch `<changed|unchanged>`, age `<days> days`
>
> **Directive:**
> ```
> <directive body, verbatim>
> ```

Compute the progress fields yourself via Bash:

```bash
commits_past="$(git rev-list --count "${saved_at_sha}..HEAD" 2>/dev/null || echo unknown)"
current_branch="$(git branch --show-current 2>/dev/null || echo unknown)"
```

If `saved-at-sha` is unknown or no longer in history, surface `commits past: unknown`. If `saved-at-branch != current_branch`, flag branch as `changed (<saved>→<current>)`.

## Step 3: Cwd guard

Compare `pwd` to the frontmatter `saved-from-cwd`. If they differ:

> **Cwd mismatch** — handoff was saved from `<saved-from-cwd>`. Current cwd is `<pwd>`. Are you sure you want to resume here?

Ask via AskUserQuestion (single-select, 2 options):

- **Yes, continue** — "Proceed with the resume flow at the current cwd."
- **No, cancel** — "Abort. The handoff stays untouched."

If **No**: exit. Do not present Step 4.

If cwds match, skip this step entirely.

## Step 4: Ask the user how to handle the handoff

Ask via AskUserQuestion (single-select, 4 options):

- **Execute** *(Recommended when directive still applies)* — "I'll act on the directive in this session. The handoff is archived afterwards."
- **Edit** — "Open the handoff in your `$EDITOR` first so you can revise the directive, then re-present this prompt."
- **Discard** — "Archive without acting. Use this if the work is no longer relevant."
- **Save for later** — "Leave the file in place but snooze re-surface for the configured window (default 24h). Useful if you want to handle this next session, not this one."

## Step 5: Dispatch on the user's choice

### Execute

1. **Re-affirm cwd** — if Step 3 was triggered and the user said "Yes, continue", we already verified. Otherwise (cwds matched naturally), skip.
2. Act on the directive in this session. Treat the directive content as **guidance** for your judgment, not commands to mechanically run. If the directive points to a memory file or plan, read it first. If it lists constraints, respect them. If it lists open questions, surface them to the user before acting on the rest.
3. After acting (or before, if the user wants to chain follow-ups), archive the handoff: `mv .claude/handoff.md .claude/handoff.consumed-<YYYYMMDDTHHMMSS>.md`.
4. Confirm to the user: "Handoff archived to `.claude/handoff.consumed-<ts>.md`. Continuing with the directive."

### Edit

1. Open `.claude/handoff.md` in the user's `$EDITOR` via Bash. If `$EDITOR` is unset, tell the user to edit the file directly and come back when done.
2. After the editor exits, re-read the file from disk.
3. Go back to **Step 2** and re-present. The flow repeats until the user picks Execute / Discard / Save for later.

### Discard

1. Archive: `mv .claude/handoff.md .claude/handoff.discarded-<YYYYMMDDTHHMMSS>.md`.
2. Confirm: "Handoff discarded (archived to `.claude/handoff.discarded-<ts>.md`)."

### Save for later

1. Update the frontmatter of `.claude/handoff.md`: add or replace the `deferred-at` field with the current UTC iso8601 timestamp. Preserve all other fields and the body.
2. Confirm: "Handoff snoozed. Will re-surface at the next SessionStart after the configured snooze window (default 24h)."

To update frontmatter safely, use a Bash one-liner:

```bash
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
awk -v ts="$ts" '
  BEGIN { in_fm = 0; fm_count = 0; emitted = 0 }
  /^---[[:space:]]*$/ { fm_count++; in_fm = (fm_count == 1); print; next }
  in_fm && /^deferred-at:/ { print "deferred-at: " ts; emitted = 1; next }
  in_fm && fm_count == 1 && /^---[[:space:]]*$/ { if (!emitted) print "deferred-at: " ts; print; next }
  { print }
' .claude/handoff.md > .claude/handoff.md.tmp && mv .claude/handoff.md.tmp .claude/handoff.md
```

If `deferred-at` already exists, the awk script replaces it. If absent, append it just before the closing `---`.

## Step 6: Confirm dispatch

After dispatching, tell the user (one line):

> Resume dispatched: **<choice>**. <one-line consequence>.

## Key Rules

- **Re-read from disk** — never trust the surfaced content from `additionalContext` as authoritative; the file may have changed.
- **Cwd guard fires before the 4-option prompt** — wrong-directory resume is a footgun; verify first.
- **Directive is guidance, not commands** — on Execute, you apply judgment to the directive; you don't mechanically run statements as if they were a script.
- **Archive timestamps use `YYYYMMDDTHHMMSS`** (no separators, no timezone — local time is fine since these are local archive markers).
- **Save-for-later updates `deferred-at` in place** — do not write a separate state file; the frontmatter is the state.
- **AskUserQuestion guard**: both calls (cwd-guard 2-option, dispatch 4-option) have static option lists. No dynamic single-option risk.
- **Never auto-Execute.** Even when the directive looks safe and obvious, the four-option AskUserQuestion is the contract.
