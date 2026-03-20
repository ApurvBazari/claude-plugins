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

## Step 3: Data Health

Run via Bash to get storage info:

```
python3 -c "
import glob, os, json
data_dir = os.path.expanduser('~/.claude/observability/data')
config_path = os.path.expanduser('~/.claude/observability/config.json')
files = sorted(glob.glob(os.path.join(data_dir, 'events-*.ndjson')))
total = sum(os.path.getsize(f) for f in files)
retention = 6
if os.path.isfile(config_path):
    try:
        retention = json.load(open(config_path)).get('retention_months', 6)
    except Exception: pass
size = f'{total / (1024*1024):.1f} MB' if total >= 1024*1024 else f'{total / 1024:.1f} KB'
print(json.dumps({'files': len(files), 'size': size, 'retention_months': retention}))
"
```

---

## Step 4: Present Results

Parse the JSON outputs and present as a formatted summary:

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
>
> **Data health:** `<files>` files, `<size>` total, `<retention_months>`-month retention
>
> To clean up old data: `python3 <plugin_root>/scripts/cleanup.py --dry-run`

If the query returns an error message, show it directly.

## Key Rules

- Never modify observability data files
- Round costs to 2 decimal places
- Show "N/A" for unavailable metrics (e.g., cost when no cost-log match)
- If query.py fails or returns unexpected output, show the raw error and suggest checking data
