---
name: check
description: Read-only inspector for saved handoffs. Reports whether .claude/handoff/active.md exists, its age, saved-at SHA/branch, progress past the save point (commits/branch changes), snooze status, and current settings. Use when the user asks about handoff state, why a handoff isn't surfacing, or wants a quick sanity check before relying on the resume flow.
---

# Check Skill — Handoff Health Check

You are running a read-only health check for the handoff plugin in the current project. No files are modified.

## Step 1: Check for an active handoff

Look for `.claude/handoff/active.md`. Two paths:

### No file present

Report:

> **No active handoff** in this project.
>
> - Save one with `/handoff:save` or by saying "save handoff" / "pick this up later".
> - Settings file: `<exists | absent>` at `.claude/handoff/settings.md`.

If `.claude/handoff/settings.md` exists, mention it; otherwise note "no settings file → defaults apply".

### File present

Parse the frontmatter and compute progress signals.

## Step 2: Compute progress signals

Run the helper and source its output:

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/compute-progress.sh" "$(pwd)")"
# Exports: days_old, current_branch, commits_past, cwd_match,
#          snooze_remaining, archive_count, retention_value
```

The helper handles frontmatter parsing, snooze-hours override from
`.claude/handoff/settings.md`, archive counting, and cross-platform date
parsing. It always exits 0 — if a value cannot be computed, it emits
`unknown`, and the Step 3 report still renders.

Also read `stale-commit-threshold` and `stale-day-threshold` from
`.claude/handoff/settings.md` for the Step 3 report — the helper does
not surface these because they are configuration, not computed signals.

## Step 3: Report

Present a structured report (markdown table, single block):

> **Handoff status — `.claude/handoff/active.md` is active**
>
> | Field | Value |
> |---|---|
> | Saved at | `<saved-at>` (`<days-old>` days ago) |
> | Saved-at SHA | `<short-sha>` |
> | Saved-at branch | `<branch>` |
> | Saved-from cwd | `<path>` |
> | Current cwd | `<pwd>` (`<match|mismatch>`) |
> | Current branch | `<branch>` |
> | Commits past saved-at | `<n>` |
> | Snooze | `<status>` |
> | Settings file | `<exists|absent>` |
> | Archive retention | `<value>` (default 10) |
> | Archive count | `<n>` files in `.claude/handoff/archive/` |
>
> **Will surface at next SessionStart?** `<yes | no — reason>`

The bottom line answers the most useful question. Logic:

- **No** if snooze is active: "snoozed for `<n>h` more"
- **No** if file moved to expired/consumed/discarded: shouldn't happen if we're in this branch, but defensive
- **Yes, with `progress-made` tag** if `commits_past >= stale-commit-threshold` or branch changed
- **Yes** otherwise

## Step 4: Show the directive (truncated)

After the table, show the first 12 lines of the directive body so the user can recognize it without re-reading the file:

```bash
sed -n '/^---/,/^---/!p' .claude/handoff/active.md | head -12
```

If the body is longer than 12 lines, append "*(truncated — run `cat .claude/handoff/active.md` for the full directive)*".

## Step 5: Show settings (if file exists)

If `.claude/handoff/settings.md` exists, display its frontmatter values as a small table:

> **Settings** (`.claude/handoff/settings.md`):
>
> | Key | Value |
> |---|---|
> | stale-commit-threshold | `<value>` (default 3) |
> | stale-day-threshold | `<value>` (default 90) |
> | deferral-snooze-hours | `<value>` (default 24) |
> | gitignore-prompt | `<value>` (default ask) |
> | archive-retention | `<value>` (default 10) |

If absent, end with "No settings file — defaults apply".

## Key Rules

- **Read-only.** Never modify any file. No state changes from this skill.
- **Frontmatter is authoritative** — if a field is missing in `.claude/handoff/active.md`, surface as `unknown`; do not infer.
- **Cwd mismatch is informational, not fatal** — surface it but don't refuse to report.
- **Git failures are graceful** — `commits_past`, `current_branch` may be `unknown`; the report still renders.
