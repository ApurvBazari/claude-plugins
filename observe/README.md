# observe

Zero-infrastructure observability for Claude Code. Tracks tool usage, skill invocations, subagent spawns, context management, and session behavior — all locally, with no external services.

## What It Does

Hooks into Claude Code events and passively records telemetry to local NDJSON files:

- **Tool tracking** — every tool invocation with input/response sizes and MCP/skill/subagent classification
- **Session lifecycle** — start, end, compaction events with timestamps
- **Prompt metrics** — prompt length and word count (full text capture is opt-in)
- **Subagent tracking** — spawn and completion events with agent type and duration
- **Notification tracking** — attention events with type classification

## Requirements

- Python 3.7+
- Claude Code

## Installation

```bash
# From the marketplace
claude plugin install observe

# Or from a local path (for development)
claude plugin add /path/to/observe
```

Validate your installation:

```bash
bash /path/to/observe/scripts/install.sh
```

## What Data Is Collected

| Event | When | What's Recorded |
|-------|------|-----------------|
| SessionStart | Session begins | Source |
| SessionEnd | Session ends | Reason |
| UserPromptSubmit | You send a prompt | Length, word count (full text opt-in) |
| PreToolUse | Before tool runs | Tool name, input size, MCP/skill/agent flags |
| PostToolUse | After tool runs | Tool name, response size |
| Stop | Claude responds | Reason |
| SubagentStart | Agent spawns | Agent ID, type |
| SubagentStop | Agent finishes | Agent ID, type, transcript path |
| PreCompact | Context compaction | Trigger type |
| Notification | Needs attention | Type, message preview |

## Privacy

All data stays local on your machine at `~/.claude/observability/data/`.

- **Prompt text is not captured by default.** Only length and word count are recorded.
- To opt in to full prompt capture, create `~/.claude/observability/config.json`:
  ```json
  { "capture_prompts": true }
  ```
- Notification messages are truncated to 100 characters.
- No data is sent to any external service.

## Commands

| Command | Description |
|---------|-------------|
| `/observe:status` | Check data collection status |

More analytics commands are coming in future updates.

## Storage

Data is stored at `~/.claude/observability/data/` in monthly NDJSON files (`events-YYYY-MM.ndjson`).

- Estimated growth: ~12.5 MB/month with moderate usage
- Data rotation (configurable retention) coming in a future update

## Works Well With

- **notify** — pair with observe for full session awareness (analytics + notifications)
