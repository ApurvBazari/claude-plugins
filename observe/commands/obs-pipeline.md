# /observe:pipeline — Devkit Pipeline History

You are running the observe plugin's pipeline history command. This shows devkit ship pipeline runs detected from observability data.

## Overview

Tell the developer:

> Analyzing devkit pipeline history from observability data...

---

## Step 1: Check Data

Check if `~/.claude/observability/data/` exists and contains at least one `.ndjson` file.

If no data found:

> No observability data found yet. The observe plugin collects data passively
> during Claude Code sessions. Run `/devkit:ship` a few times with observe
> installed, then try again.

Stop and do not proceed.

---

## Step 2: Parse Arguments

Check if the user provided arguments:

- `--last N` → pass `--range last-Nd` to query (default: `last-30d`)
- `--project NAME` → pass `--project NAME` to query
- A date range like `last-7d` or `2026-03-01:2026-03-20` → pass directly as `--range`

---

## Step 3: Run Query

Run via Bash:

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/query.py" \
    --mode pipeline-summary [--range <range>] [--project <name>] --format json
```

---

## Step 4: Present Results

Parse the JSON output and present as a formatted summary:

> **Pipeline History**
>
> | Metric | Value |
> |--------|-------|
> | Total runs | `<total_pipelines>` |
> | Completed | `<completed>` |
> | Incomplete | `<incomplete>` |
> | Avg duration | `<avg_duration_human>` |
>
> **Step Performance:**
>
> | Step | Runs | Avg Duration |
> |------|------|-------------|
> | test | N | Xs |
> | lint | N | Xs |
> | ... | ... | ... |
>
> **Recent Pipelines:**
>
> | Date | Steps | Duration | Result |
> |------|-------|----------|--------|
> | ... | test → lint → check → commit | Xm Ys | completed |
> | ... | ... | ... | ... |

If no pipelines found:

> No devkit pipeline runs detected in the specified range. Pipeline detection
> works by identifying sequences of `devkit:*` skill invocations (test, lint,
> check, review, commit) within the same session.
>
> Make sure both observe and devkit plugins are installed, then run `/devkit:ship`.

---

## Step 5: Offer Deeper Analysis

If pipelines were found, offer:

> Want to see more? I can:
> - Run **`/observe:tools`** for detailed tool usage across all sessions
> - Run **`/observe:report`** for a full cross-project report
> - Spawn the **Usage Analyst** agent for deep pattern analysis

## Key Rules

- Never modify observability data files
- Round durations to whole seconds for display
- Show "N/A" for unavailable metrics
- If query.py fails or returns unexpected output, show the raw error
- Pipeline detection is heuristic — note this if results look unexpected
