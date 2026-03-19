# observe — Internal Conventions

Zero-infrastructure observability for Claude Code via passive hook-based telemetry.

## Hook Event Model

Ten events captured, all routed to a unified `collect.py` script:

| Event | When | Key Data |
|-------|------|----------|
| SessionStart | Session begins | `source` |
| SessionEnd | Session ends | `reason` |
| UserPromptSubmit | User sends a prompt | `prompt_len`, `prompt_word_count` |
| PreToolUse | Before any tool executes | `tool_name`, `input_size`, MCP/skill/subagent flags |
| PostToolUse | After any tool executes | `tool_name`, `response_size`, MCP/skill flags |
| Stop | Claude finishes a response | `reason` |
| SubagentStart | Subagent spawns | `agent_id`, `agent_type` |
| SubagentStop | Subagent finishes | `agent_id`, `agent_type`, `transcript_path` |
| PreCompact | Context compaction starts | `trigger` |
| Notification | Claude needs attention | `notification_type`, `message_preview` |

## Python Script Conventions

- **stdlib only** — `json`, `sys`, `os`, `datetime`. No external dependencies.
- **Hook scripts** use `finally: sys.exit(0)` — never block Claude Code.
- **Observer hooks** print `{}` to stdout (not silence).
- **Utility scripts** (install.sh) use `set -euo pipefail` and may exit non-zero.
- Use `sys.stdin.read()` + `json.loads()` for defensive stdin parsing.

## NDJSON Envelope Schema

Every event is stored as a single JSON line:

```json
{"ts":"2026-03-19T14:32:01.234Z","event":"PreToolUse","sid":"abc-123","cwd":"/path","project":"my-app","data":{}}
```

- `ts` — ISO 8601 UTC timestamp
- `event` — hook event name
- `sid` — session ID from Claude Code
- `cwd` — working directory
- `project` — `basename(cwd)`
- `data` — event-specific fields

## Storage Layout

```
~/.claude/observability/
├── data/
│   └── events-YYYY-MM.ndjson    ← monthly files, append-only
├── cache/                        ← dashboard HTML (future)
└── config.json                   ← runtime configuration (future)
```

Growth estimate: ~410 events/session × 200 bytes × 5 sessions/day ≈ 12.5 MB/month.

## Tool Classification

PreToolUse and PostToolUse events classify tools:

| Pattern | Detection |
|---------|-----------|
| `mcp__<server>__<tool>` | `is_mcp=true`, extract server and tool names |
| `tool_name == "Skill"` | `is_skill=true`, `skill_name` from `tool_input.skill` |
| `tool_name == "Agent"` | `is_subagent=true`, `subagent_type` from `tool_input.subagent_type` |

## Config Resolution

Config at `~/.claude/observability/config.json` (created on demand, not required):

| Key | Default | Purpose |
|-----|---------|---------|
| `enabled` | `true` | Master kill switch |
| `retention_months` | `6` | Data rotation threshold (future) |
| `capture_prompts` | `false` | Include full prompt text in events |

## Privacy Model

- All data is stored locally at `~/.claude/observability/`.
- Prompt text is **not captured by default**. Only `prompt_len` and `prompt_word_count` are recorded.
- Set `capture_prompts: true` in config.json to opt in to full prompt capture.
- Notification messages are truncated to 100 characters.
