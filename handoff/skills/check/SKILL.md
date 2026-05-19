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

Read frontmatter fields: `saved-at`, `saved-at-sha`, `saved-at-branch`, `saved-from-cwd`, optional `deferred-at`.

Compute via Bash:

```bash
# Age
saved_epoch=$(date -d "$saved_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$saved_at" +%s 2>/dev/null || echo 0)
now_epoch=$(date +%s)
days_old=$(( (now_epoch - saved_epoch) / 86400 ))

# Git progress
current_branch=$(git branch --show-current 2>/dev/null || echo unknown)
commits_past=$(git rev-list --count "${saved_at_sha}..HEAD" 2>/dev/null || echo unknown)

# Cwd match
cwd_match="match"
[[ "$saved_from_cwd" != "$(pwd)" ]] && cwd_match="mismatch"

# Snooze status (only meaningful if deferred-at present)
snooze_remaining="not snoozed"
if [[ -n "$deferred_at" ]]; then
  deferred_epoch=$(date -d "$deferred_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$deferred_at" +%s 2>/dev/null || echo 0)
  snooze_hours=24  # read from settings if present
  end_epoch=$((deferred_epoch + snooze_hours * 3600))
  if [[ "$now_epoch" -lt "$end_epoch" ]]; then
    remaining=$(( (end_epoch - now_epoch) / 3600 ))
    snooze_remaining="snoozed (${remaining}h remaining)"
  else
    snooze_remaining="snooze expired — will surface at next SessionStart"
  fi
fi

# Archive stats
archive_count="$(find .claude/handoff/archive -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
retention_value="$(awk '/^archive-retention:/ { sub(/^archive-retention:[[:space:]]*/, ""); gsub(/^["'\''"]|["'\''"]$/, ""); print; exit }' .claude/handoff/settings.md 2>/dev/null)"
[[ -z "$retention_value" ]] && retention_value=10
```

Read `.claude/handoff/settings.md` if it exists; override `snooze_hours` from `deferral-snooze-hours` if set. Also read `stale-commit-threshold` and `stale-day-threshold` for the report.

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
