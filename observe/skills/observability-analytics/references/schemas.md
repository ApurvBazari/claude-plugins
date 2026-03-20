# Observability Data Schemas

Reference documentation for all data formats used by the observe plugin.

## NDJSON Envelope

Every event is stored as a single JSON line in `~/.claude/observability/data/events-YYYY-MM.ndjson`:

```json
{"ts":"2026-03-19T14:32:01.234Z","event":"PreToolUse","sid":"abc-123","cwd":"/path/to/project","project":"my-app","data":{}}
```

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string | ISO 8601 UTC timestamp |
| `event` | string | Hook event name (see Event Types below) |
| `sid` | string | Session ID from Claude Code |
| `cwd` | string | Working directory at event time |
| `project` | string | `basename(cwd)` — project directory name |
| `data` | object | Event-specific fields (see below) |

## Event Types

### SessionStart

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | How session started (if available) |

### SessionEnd

| Field | Type | Description |
|-------|------|-------------|
| `reason` | string | Why session ended |

### UserPromptSubmit

| Field | Type | Description |
|-------|------|-------------|
| `prompt_len` | int | Character count of prompt |
| `prompt_word_count` | int | Word count of prompt |
| `prompt` | string | Full prompt text (only when `capture_prompts: true` in config) |

### PreToolUse / PostToolUse

| Field | Type | Description |
|-------|------|-------------|
| `tool_name` | string | Tool identifier (e.g., `Read`, `Bash`, `mcp__server__tool`) |
| `input_size` | int | Byte count of serialized tool input |
| `is_mcp` | bool | Whether tool is an MCP tool |
| `is_skill` | bool | Whether tool is a Skill invocation |
| `is_subagent` | bool | Whether tool is an Agent spawn |
| `mcp_server` | string | MCP server name (only when `is_mcp`) |
| `mcp_tool` | string | MCP tool name (only when `is_mcp`) |
| `skill_name` | string | Skill identifier (only when `is_skill`) |
| `subagent_type` | string | Agent type (only when `is_subagent`) |
| `tool_use_id` | string | Tool use correlation ID (if present in stdin) |
| `response_size` | int | Byte count of tool result (PostToolUse only) |

### Stop

| Field | Type | Description |
|-------|------|-------------|
| `reason` | string | Why Claude stopped |

### SubagentStart

| Field | Type | Description |
|-------|------|-------------|
| `agent_id` | string | Unique agent identifier |
| `agent_type` | string | Agent type (e.g., `Explore`, `Plan`, `general-purpose`) |

### SubagentStop

| Field | Type | Description |
|-------|------|-------------|
| `agent_id` | string | Unique agent identifier |
| `agent_type` | string | Agent type |
| `transcript_path` | string | Path to agent transcript file |

### PreCompact

| Field | Type | Description |
|-------|------|-------------|
| `trigger` | string | What triggered compaction (if available) |

### Notification

| Field | Type | Description |
|-------|------|-------------|
| `notification_type` | string | Notification category |
| `message_preview` | string | First 100 characters of notification message |

## Config Schema

File: `~/.claude/observability/config.json` (optional, created on demand)

```json
{
  "enabled": true,
  "retention_months": 6,
  "capture_prompts": false
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Master kill switch for data collection |
| `retention_months` | int | `6` | How many months of data to keep |
| `capture_prompts` | bool | `false` | Whether to store full prompt text |
| `alerts` | object | see below | Pattern-based alert configuration |

### Alerts Config

Nested under `alerts` in config.json:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Enable/disable observe-driven alerts |
| `compaction_threshold` | int | `4` | Alert after N compactions in one session |
| `session_duration_hours` | int | `3` | Alert after N hours in one session |
| `error_rate_threshold` | int | `5` | Alert after N tool failures in window |
| `error_rate_window_minutes` | int | `10` | Window for error rate calculation |
| `tool_failure_rate` | float | `0.5` | Alert if tool fails >50% of invocations |

## Cost Log Format

File: `~/.claude/cost-log.jsonl` (managed by Claude Code, read-only)

```json
{"sid":"6703","date":"2026-03-16","cost":1.50}
```

| Field | Type | Description |
|-------|------|-------------|
| `sid` | string | Short numeric session identifier |
| `date` | string | Date in YYYY-MM-DD format |
| `cost` | number | Session cost in USD |

**Note:** The `sid` in cost-log.jsonl is a short numeric value (e.g., `"6703"`), not the full session UUID used in event data. The query engine matches via suffix matching.

## Query Engine CLI

```
python3 query.py --mode <mode> [options]

Modes:
  session-summary    Summary of a single session
  full-report        Cross-project report over a date range
  tool-detail        Per-tool usage breakdown
  skill-usage        Per-skill invocation analysis
  quality-signals    Error patterns, context waste, workflow issues
  pipeline-summary   Devkit ship pipeline run detection and history
  export-csv         Filtered data export

Options:
  --session SID      Filter to specific session ID
  --project NAME     Filter to specific project
  --range RANGE      Date range: last-7d, last-30d, YYYY-MM-DD:YYYY-MM-DD
  --tool NAME        Tool name filter (for tool-detail mode)
  --format FMT       Output format: text (default) or json
```
