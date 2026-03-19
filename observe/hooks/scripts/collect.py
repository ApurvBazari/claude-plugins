#!/usr/bin/env python3
"""Unified telemetry collector for the observe plugin.

Reads hook event JSON from stdin, extracts metadata, appends NDJSON
to ~/.claude/observability/data/events-YYYY-MM.ndjson.

Always exits 0 and prints {} to stdout — never blocks Claude Code.
"""

import json
import os
import sys
from datetime import datetime, timezone

DATA_DIR = os.path.expanduser("~/.claude/observability/data")
CONFIG_PATH = os.path.expanduser("~/.claude/observability/config.json")


def main():
    try:
        raw = sys.stdin.read()
        stdin = json.loads(raw)

        event = stdin.get("hook_event_name", "")
        sid = stdin.get("session_id", "")
        cwd = stdin.get("cwd", "")

        if not event:
            return

        # Load config
        config = {}
        if os.path.isfile(CONFIG_PATH):
            with open(CONFIG_PATH) as f:
                config = json.load(f)

        # Check enabled flag
        if not config.get("enabled", True):
            return

        # Route to handler
        handler = HANDLERS.get(event, handle_default)
        data = handler(stdin, config)

        # Build envelope
        now = datetime.now(timezone.utc)
        envelope = {
            "ts": now.isoformat(),
            "event": event,
            "sid": sid,
            "cwd": cwd,
            "project": os.path.basename(cwd) if cwd else "",
            "data": data,
        }

        # Append NDJSON line
        os.makedirs(DATA_DIR, exist_ok=True)
        filename = f"events-{now.strftime('%Y-%m')}.ndjson"
        filepath = os.path.join(DATA_DIR, filename)
        with open(filepath, "a") as f:
            f.write(json.dumps(envelope, separators=(",", ":")) + "\n")

    except Exception:
        pass

    finally:
        try:
            sys.stdout.write("{}\n")
            sys.stdout.flush()
        except Exception:
            pass
        sys.exit(0)


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------


def handle_session_start(stdin, config):
    return {"source": stdin.get("source", "")}


def handle_session_end(stdin, config):
    return {"reason": stdin.get("reason", "")}


def handle_user_prompt(stdin, config):
    prompt = stdin.get("prompt", "") or stdin.get("message", "")
    data = {
        "prompt_len": len(prompt),
        "prompt_word_count": len(prompt.split()) if prompt else 0,
    }
    if config.get("capture_prompts", False):
        data["prompt"] = prompt
    return data


def handle_tool_use(stdin, config):
    """Shared handler for PreToolUse and PostToolUse."""
    tool_name = stdin.get("tool_name", "")
    tool_input = stdin.get("tool_input", {}) or {}

    # MCP detection: mcp__<server>__<tool>
    is_mcp = tool_name.startswith("mcp__")
    mcp_server, mcp_tool = "", ""
    if is_mcp:
        parts = tool_name.split("__", 2)
        if len(parts) >= 3:
            mcp_server, mcp_tool = parts[1], parts[2]

    # Skill / Agent detection
    is_skill = tool_name == "Skill"
    is_subagent = tool_name == "Agent"

    data = {
        "tool_name": tool_name,
        "input_size": len(json.dumps(tool_input, separators=(",", ":")))
        if tool_input
        else 0,
        "is_mcp": is_mcp,
        "is_skill": is_skill,
        "is_subagent": is_subagent,
    }

    if is_mcp:
        data["mcp_server"] = mcp_server
        data["mcp_tool"] = mcp_tool
    if is_skill:
        data["skill_name"] = tool_input.get("skill", "")
    if is_subagent:
        data["subagent_type"] = tool_input.get("subagent_type", "")

    # Capture tool_use_id if present (unconfirmed field)
    tool_use_id = stdin.get("tool_use_id", "")
    if tool_use_id:
        data["tool_use_id"] = tool_use_id

    # PostToolUse: add response_size when tool_result is present
    tool_result = stdin.get("tool_result")
    if tool_result is not None:
        try:
            data["response_size"] = len(json.dumps(tool_result, separators=(",", ":")))
        except (TypeError, ValueError):
            data["response_size"] = len(str(tool_result))

    return data


def handle_stop(stdin, config):
    return {"reason": stdin.get("reason", "")}


def handle_subagent_start(stdin, config):
    return {
        "agent_id": stdin.get("agent_id", ""),
        "agent_type": stdin.get("agent_type", ""),
    }


def handle_subagent_stop(stdin, config):
    return {
        "agent_id": stdin.get("agent_id", ""),
        "agent_type": stdin.get("agent_type", ""),
        "transcript_path": stdin.get("agent_transcript_path", ""),
    }


def handle_pre_compact(stdin, config):
    return {"trigger": stdin.get("trigger", "")}


def handle_notification(stdin, config):
    msg = stdin.get("message", "")
    return {
        "notification_type": stdin.get("notification_type", ""),
        "message_preview": msg[:100] if msg else "",
    }


def handle_default(stdin, config):
    return {}


HANDLERS = {
    "SessionStart": handle_session_start,
    "SessionEnd": handle_session_end,
    "UserPromptSubmit": handle_user_prompt,
    "PreToolUse": handle_tool_use,
    "PostToolUse": handle_tool_use,
    "Stop": handle_stop,
    "SubagentStart": handle_subagent_start,
    "SubagentStop": handle_subagent_stop,
    "PreCompact": handle_pre_compact,
    "Notification": handle_notification,
}


if __name__ == "__main__":
    main()
