# /observe:status — Quick Session Summary

You are running the observe plugin's session status command. This shows a summary of the most recent (or specified) Claude Code session.

## Overview

Tell the developer:

> Analyzing session observability data...

---

## Step 1: Check Data

Check if `~/.claude/observability/data/` exists and contains at least one `.ndjson` file.

If no data found:

> No observability data found yet. The observe plugin collects data passively
> during Claude Code sessions. Keep using Claude Code normally and data will
> accumulate automatically.

Stop and do not proceed.

---

## Step 2: Run Query

If the user provided a session ID argument, include it. Otherwise, query the most recent session.

Run via Bash:

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/query.py" \
    --mode session-summary --format json
```

If a session ID argument was provided:

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/query.py" \
    --mode session-summary --session "<session-id>" --format json
```

---

## Step 3: Present Results

Parse the JSON output and present as a formatted summary:

> **Session Summary**
>
> | Metric | Value |
> |--------|-------|
> | Session | `<session_id>` |
> | Duration | `<duration_human>` |
> | Tools used | `<tool_uses>` (`<unique_tools>` unique) |
> | Skills invoked | `<skills_invoked>` |
> | Subagents spawned | `<subagents_spawned>` |
> | Compactions | `<compactions>` |
> | Prompts | `<prompts>` (avg `<avg_prompt_length>` chars) |
> | Est. cost | `$<cost>` |
>
> **Top tools:** `<tool1>` (Nx), `<tool2>` (Nx), ...
>
> **Skills used:** `<skill1>`, `<skill2>`, ...

If the query returns an error message, show it directly.

## Key Rules

- Never modify observability data files
- Round costs to 2 decimal places
- Show "N/A" for unavailable metrics (e.g., cost when no cost-log match)
- If query.py fails or returns unexpected output, show the raw error and suggest checking data
