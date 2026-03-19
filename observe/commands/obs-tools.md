# /observe:tools — Tool Usage Breakdown

You are running the observe plugin's tool analysis command. This shows per-tool usage metrics.

## Overview

Tell the developer:

> Analyzing tool usage...

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

If the user provided a tool name argument, filter to that tool. Otherwise, show all tools.

**All tools:**

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/query.py" \
    --mode tool-detail --format json
```

**Specific tool:**

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/observability-analytics/scripts/query.py" \
    --mode tool-detail --tool "<tool-name>" --format json
```

---

## Step 3: Present Results

Parse the JSON output and present as a formatted table:

> **Tool Usage**
>
> | Tool | Uses | Completions | Sessions | Avg Input | Avg Response |
> |------|------|-------------|----------|-----------|-------------|
> | Read | N | N | N | N bytes | N bytes |
> | Bash | N | N | N | N bytes | N bytes |
>
> MCP tools show additional detail: `[MCP: server/tool]`

If filtering to a specific tool and no results found:

> No usage data found for tool `<name>`. Check the tool name — it must match
> exactly (e.g., `Read`, `Bash`, `mcp__claude-in-chrome__navigate`).

## Key Rules

- Never modify observability data files
- Tool names are case-sensitive and must match exactly
- MCP tools use the full `mcp__server__tool` format
- Show sizes in bytes (no unit conversion needed at this scale)
