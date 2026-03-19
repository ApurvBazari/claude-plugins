# /observe:report — Cross-Project Report

You are running the observe plugin's report command. This generates a cross-project observability report over a date range.

## Overview

Tell the developer:

> Generating observability report...

---

## Step 1: Check Data

Check if `~/.claude/observability/data/` exists and contains at least one `.ndjson` file.

If no data found:

> No observability data found yet. The observe plugin collects data passively
> during Claude Code sessions. Keep using Claude Code normally and data will
> accumulate automatically.

Stop and do not proceed.

---

## Step 2: Parse Arguments

Check if the user provided an argument:

- **Date range** (e.g., `last-7d`, `last-30d`, `2026-03-01:2026-03-15`): pass as `--range`
- **No argument**: default to `--range last-7d`

Run via Bash:

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/query.py" \
    --mode full-report --range "<range>" --format json
```

---

## Step 3: Present Results

Parse the JSON output and present as a formatted report:

> **Observability Report** (`<range>`)
>
> Sessions: **N** | Events: **N** | Avg tools/session: **N** | Compactions: **N**
> Total cost: **$X.XX** | Avg/session: **$X.XX**
>
> **Projects**
>
> | Project | Sessions |
> |---------|----------|
> | project-a | N |
> | project-b | N |
>
> **Top Tools**
>
> | Tool | Count |
> |------|-------|
> | Read | N |
> | Bash | N |
>
> **Skills**
>
> | Skill | Count |
> |-------|-------|
> | devkit:commit | N |
>
> **Subagent Types:** Explore (N), Plan (N)

If the query returns an error, show it directly.

## Key Rules

- Never modify observability data files
- Round costs to 2 decimal places
- Show "N/A" for unavailable metrics
- Default range is `last-7d` when no argument is provided
