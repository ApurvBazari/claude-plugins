# /observe:dashboard — Interactive Dashboard

You are running the observe plugin's dashboard command. This generates a self-contained HTML dashboard with Chart.js visualizations and opens it in the browser.

## Overview

Tell the developer:

> Generating observability dashboard...

---

## Step 1: Check Data

Check if `~/.claude/observability/data/` exists and contains at least one `.ndjson` file.

If no data found:

> No observability data found yet. The observe plugin collects data passively
> during Claude Code sessions. Keep using Claude Code normally and data will
> accumulate automatically.

Stop and do not proceed.

---

## Step 2: Generate Dashboard

Parse the optional range argument. If none provided, default to `last-30d`.

Valid range formats: `last-7d`, `last-30d`, `last-90d`, or `YYYY-MM-DD:YYYY-MM-DD`.

Run via Bash:

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/generate_dashboard.py" "<range>"
```

---

## Step 3: Report Result

If the script succeeds (prints the output path):

> Dashboard generated and opened in your browser.
>
> File: `~/.claude/observability/cache/dashboard-latest.html`
>
> The dashboard includes:
> - Sessions over time
> - Tool usage distribution (top 15)
> - Error rate trend
> - Compactions per session
> - Project comparison
> - Skill usage table
>
> Re-run `/observe:dashboard` with a different range to update (e.g., `/observe:dashboard last-7d`).

If the script fails:

> Dashboard generation failed. Check the error output above.
> Common issues:
> - No events in the specified date range — try a wider range
> - Template file missing — verify the observe plugin is installed correctly

## Key Rules

- Never modify observability data files
- Default range is `last-30d` when no argument is provided
- The dashboard is a static HTML file — it does not auto-refresh
- Each generation overwrites the previous dashboard file
