#!/usr/bin/env python3
"""Query engine for the observe plugin.

Reads NDJSON event data from ~/.claude/observability/data/ and produces
analytics in 6 modes: session-summary, full-report, tool-detail,
skill-usage, quality-signals, export-csv.

Usage:
    python3 query.py --mode <mode> [options]

Options:
    --session SID       Filter to specific session ID
    --project NAME      Filter to specific project
    --range RANGE       Date range: last-7d, last-30d, YYYY-MM-DD:YYYY-MM-DD
    --tool NAME         Filter to specific tool (for tool-detail)
    --format FMT        Output format: text (default) or json
"""

import argparse
import csv
import glob
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

DATA_DIR = os.path.expanduser("~/.claude/observability/data")
COST_LOG_PATH = os.path.expanduser("~/.claude/cost-log.jsonl")


# ---------------------------------------------------------------------------
# Date range parsing
# ---------------------------------------------------------------------------


def parse_date_range(range_str):
    """Parse range string into (start_dt, end_dt) in UTC.

    Supports: last-7d, last-30d, last-90d, YYYY-MM-DD:YYYY-MM-DD
    Returns None if range_str is None.
    """
    if not range_str:
        return None
    now = datetime.now(timezone.utc)
    if range_str.startswith("last-"):
        days_str = range_str[5:]
        if days_str.endswith("d"):
            days_str = days_str[:-1]
        try:
            days = int(days_str)
        except ValueError:
            return None
        return (now - timedelta(days=days), now)
    if ":" in range_str:
        parts = range_str.split(":", 1)
        try:
            start = datetime.strptime(parts[0], "%Y-%m-%d").replace(
                tzinfo=timezone.utc
            )
            end = datetime.strptime(parts[1], "%Y-%m-%d").replace(
                tzinfo=timezone.utc
            ) + timedelta(days=1)
            return (start, end)
        except ValueError:
            return None
    return None


def month_in_range(month_str, date_range):
    """Check if YYYY-MM overlaps with (start_dt, end_dt)."""
    if not date_range:
        return True
    try:
        month_start = datetime.strptime(month_str + "-01", "%Y-%m-%d").replace(
            tzinfo=timezone.utc
        )
        # Month end: next month
        if month_start.month == 12:
            month_end = month_start.replace(year=month_start.year + 1, month=1)
        else:
            month_end = month_start.replace(month=month_start.month + 1)
        return month_start < date_range[1] and month_end > date_range[0]
    except ValueError:
        return True


def parse_ts(ts_str):
    """Parse ISO 8601 timestamp to datetime. Returns None on failure."""
    if not ts_str:
        return None
    try:
        # Handle both +00:00 and Z suffixes
        ts_str = ts_str.replace("Z", "+00:00")
        return datetime.fromisoformat(ts_str)
    except (ValueError, AttributeError):
        return None


def ts_in_range(ts_str, date_range):
    """Check if timestamp string falls within date range."""
    if not date_range:
        return True
    dt = parse_ts(ts_str)
    if not dt:
        return True  # include records with unparseable timestamps
    return date_range[0] <= dt <= date_range[1]


# ---------------------------------------------------------------------------
# Data readers
# ---------------------------------------------------------------------------


def read_events(data_dir=DATA_DIR, date_range=None, project=None, session=None):
    """Read and filter NDJSON events. Yields dicts."""
    pattern = os.path.join(data_dir, "events-*.ndjson")
    for filepath in sorted(glob.glob(pattern)):
        # Filename-level filter
        basename = os.path.basename(filepath)
        month = basename.replace("events-", "").replace(".ndjson", "")
        if date_range and not month_in_range(month, date_range):
            continue
        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if project and record.get("project") != project:
                    continue
                if session and record.get("sid") != session:
                    continue
                if date_range and not ts_in_range(record.get("ts", ""), date_range):
                    continue
                yield record


def read_cost_log():
    """Read ~/.claude/cost-log.jsonl, return dict keyed by sid."""
    costs = {}
    if not os.path.isfile(COST_LOG_PATH):
        return costs
    try:
        with open(COST_LOG_PATH) as f:
            for line in f:
                try:
                    record = json.loads(line.strip())
                    sid = record.get("sid", "")
                    cost = record.get("cost", 0)
                    if sid:
                        costs[sid] = costs.get(sid, 0) + float(cost)
                except (json.JSONDecodeError, KeyError, TypeError, ValueError):
                    continue
    except OSError:
        pass
    return costs


def match_cost(session_id, cost_map):
    """Match full session_id to short cost-log sid."""
    if not session_id or not cost_map:
        return None
    # Exact match first
    if session_id in cost_map:
        return cost_map[session_id]
    # Suffix match (cost-log uses short numeric sids)
    for cost_sid, cost in cost_map.items():
        if session_id.endswith(cost_sid):
            return cost
    return None


# ---------------------------------------------------------------------------
# Mode: session-summary
# ---------------------------------------------------------------------------


def session_summary(events, costs):
    """Summarize a single session (or the most recent if multiple)."""
    sessions = defaultdict(list)
    for ev in events:
        sessions[ev.get("sid", "unknown")].append(ev)

    if not sessions:
        return {"error": "No events found"}

    # Pick the most recent session (by last event timestamp)
    def last_ts(evts):
        timestamps = [parse_ts(e.get("ts", "")) for e in evts]
        timestamps = [t for t in timestamps if t]
        return max(timestamps) if timestamps else datetime.min.replace(tzinfo=timezone.utc)

    sid = max(sessions.keys(), key=lambda s: last_ts(sessions[s]))
    evts = sessions[sid]

    # Timestamps
    timestamps = [parse_ts(e.get("ts", "")) for e in evts]
    timestamps = [t for t in timestamps if t]
    start_ts = min(timestamps) if timestamps else None
    end_ts = max(timestamps) if timestamps else None
    duration_s = (end_ts - start_ts).total_seconds() if start_ts and end_ts else 0

    # Tool counts
    tool_events = [e for e in evts if e.get("event") in ("PreToolUse", "PostToolUse")]
    pre_tools = [e for e in evts if e.get("event") == "PreToolUse"]
    tool_names = [e.get("data", {}).get("tool_name", "") for e in pre_tools]
    tool_counter = Counter(tool_names)
    top_tools = tool_counter.most_common(5)

    # Skills
    skill_events = [
        e for e in pre_tools if e.get("data", {}).get("is_skill")
    ]
    skill_names = [e.get("data", {}).get("skill_name", "") for e in skill_events]

    # Subagents
    agent_starts = [e for e in evts if e.get("event") == "SubagentStart"]
    agent_stops = [e for e in evts if e.get("event") == "SubagentStop"]

    # Compactions
    compactions = [e for e in evts if e.get("event") == "PreCompact"]

    # Prompts
    prompts = [e for e in evts if e.get("event") == "UserPromptSubmit"]
    prompt_lengths = [e.get("data", {}).get("prompt_len", 0) for e in prompts]
    avg_prompt_len = (
        sum(prompt_lengths) / len(prompt_lengths) if prompt_lengths else 0
    )

    # Cost
    cost = match_cost(sid, costs)

    return {
        "session_id": sid,
        "start": start_ts.isoformat() if start_ts else "N/A",
        "end": end_ts.isoformat() if end_ts else "N/A",
        "duration_seconds": round(duration_s),
        "duration_human": format_duration(duration_s),
        "total_events": len(evts),
        "tool_uses": len(pre_tools),
        "unique_tools": len(tool_counter),
        "top_tools": [{"tool": t, "count": c} for t, c in top_tools],
        "skills_invoked": len(skill_events),
        "skill_names": list(set(skill_names)),
        "subagents_spawned": len(agent_starts),
        "subagents_completed": len(agent_stops),
        "compactions": len(compactions),
        "prompts": len(prompts),
        "avg_prompt_length": round(avg_prompt_len),
        "cost": round(cost, 2) if cost is not None else "N/A",
    }


# ---------------------------------------------------------------------------
# Mode: full-report
# ---------------------------------------------------------------------------


def full_report(events, costs):
    """Cross-project report over a date range."""
    sessions = defaultdict(list)
    for ev in events:
        sessions[ev.get("sid", "unknown")].append(ev)

    if not sessions:
        return {"error": "No events found"}

    # Per-project stats
    project_sessions = defaultdict(set)
    for sid, evts in sessions.items():
        projects = set(e.get("project", "") for e in evts if e.get("project"))
        for p in projects:
            project_sessions[p].add(sid)

    # Tool distribution
    all_pre_tools = []
    for evts in sessions.values():
        all_pre_tools.extend(
            e for e in evts if e.get("event") == "PreToolUse"
        )
    tool_counter = Counter(
        e.get("data", {}).get("tool_name", "") for e in all_pre_tools
    )
    top_tools = tool_counter.most_common(10)

    # Skills
    skill_counter = Counter()
    for e in all_pre_tools:
        if e.get("data", {}).get("is_skill"):
            skill_counter[e.get("data", {}).get("skill_name", "")] += 1

    # Subagents
    agent_type_counter = Counter()
    for evts in sessions.values():
        for e in evts:
            if e.get("event") == "SubagentStart":
                agent_type_counter[e.get("data", {}).get("agent_type", "")] += 1

    # Compactions
    total_compactions = sum(
        1
        for evts in sessions.values()
        for e in evts
        if e.get("event") == "PreCompact"
    )

    # Cost
    total_cost = 0
    sessions_with_cost = 0
    for sid in sessions:
        c = match_cost(sid, costs)
        if c is not None:
            total_cost += c
            sessions_with_cost += 1

    # Tools per session
    tools_per_session = []
    for evts in sessions.values():
        count = sum(1 for e in evts if e.get("event") == "PreToolUse")
        tools_per_session.append(count)
    avg_tools = (
        sum(tools_per_session) / len(tools_per_session) if tools_per_session else 0
    )

    return {
        "total_sessions": len(sessions),
        "total_events": sum(len(evts) for evts in sessions.values()),
        "projects": {
            p: len(sids) for p, sids in sorted(project_sessions.items())
        },
        "avg_tools_per_session": round(avg_tools, 1),
        "top_tools": [{"tool": t, "count": c} for t, c in top_tools],
        "skills": [{"skill": s, "count": c} for s, c in skill_counter.most_common()],
        "subagent_types": dict(agent_type_counter.most_common()),
        "total_compactions": total_compactions,
        "cost_total": round(total_cost, 2) if sessions_with_cost else "N/A",
        "cost_avg_per_session": (
            round(total_cost / sessions_with_cost, 2) if sessions_with_cost else "N/A"
        ),
    }


# ---------------------------------------------------------------------------
# Mode: tool-detail
# ---------------------------------------------------------------------------


def tool_detail(events, tool_filter=None):
    """Per-tool usage breakdown."""
    tool_stats = defaultdict(
        lambda: {
            "pre_count": 0,
            "post_count": 0,
            "input_sizes": [],
            "response_sizes": [],
            "sessions": set(),
            "is_mcp": False,
            "mcp_server": "",
            "mcp_tool": "",
        }
    )

    for ev in events:
        data = ev.get("data", {})
        if ev.get("event") not in ("PreToolUse", "PostToolUse"):
            continue
        tn = data.get("tool_name", "")
        if not tn:
            continue
        if tool_filter and tn != tool_filter:
            continue

        stats = tool_stats[tn]
        stats["sessions"].add(ev.get("sid", ""))

        if ev.get("event") == "PreToolUse":
            stats["pre_count"] += 1
            if data.get("input_size"):
                stats["input_sizes"].append(data["input_size"])
        else:
            stats["post_count"] += 1
            if data.get("response_size"):
                stats["response_sizes"].append(data["response_size"])

        if data.get("is_mcp"):
            stats["is_mcp"] = True
            stats["mcp_server"] = data.get("mcp_server", "")
            stats["mcp_tool"] = data.get("mcp_tool", "")

    if not tool_stats:
        return {"error": "No tool events found"}

    result = []
    for tn, stats in sorted(tool_stats.items(), key=lambda x: -x[1]["pre_count"]):
        entry = {
            "tool": tn,
            "invocations": stats["pre_count"],
            "completions": stats["post_count"],
            "sessions": len(stats["sessions"]),
            "avg_input_size": (
                round(sum(stats["input_sizes"]) / len(stats["input_sizes"]))
                if stats["input_sizes"]
                else 0
            ),
            "avg_response_size": (
                round(sum(stats["response_sizes"]) / len(stats["response_sizes"]))
                if stats["response_sizes"]
                else 0
            ),
        }
        if stats["is_mcp"]:
            entry["mcp_server"] = stats["mcp_server"]
            entry["mcp_tool"] = stats["mcp_tool"]
        result.append(entry)

    return {"tools": result}


# ---------------------------------------------------------------------------
# Mode: skill-usage
# ---------------------------------------------------------------------------


def skill_usage(events):
    """Per-skill invocation analysis."""
    skill_stats = defaultdict(lambda: {"count": 0, "sessions": set()})

    for ev in events:
        if ev.get("event") != "PreToolUse":
            continue
        data = ev.get("data", {})
        if not data.get("is_skill"):
            continue
        name = data.get("skill_name", "unknown")
        skill_stats[name]["count"] += 1
        skill_stats[name]["sessions"].add(ev.get("sid", ""))

    if not skill_stats:
        return {"error": "No skill invocations found"}

    return {
        "skills": [
            {
                "skill": name,
                "invocations": stats["count"],
                "sessions": len(stats["sessions"]),
            }
            for name, stats in sorted(
                skill_stats.items(), key=lambda x: -x[1]["count"]
            )
        ]
    }


# ---------------------------------------------------------------------------
# Mode: quality-signals
# ---------------------------------------------------------------------------


def quality_signals(events):
    """Detect workflow quality issues."""
    sessions = defaultdict(list)
    for ev in events:
        sessions[ev.get("sid", "unknown")].append(ev)

    signals = []

    for sid, evts in sessions.items():
        # Sort by timestamp
        evts.sort(key=lambda e: e.get("ts", ""))

        # High compaction frequency
        compactions = [e for e in evts if e.get("event") == "PreCompact"]
        if len(compactions) > 3:
            signals.append(
                {
                    "type": "high_compaction",
                    "session": sid,
                    "count": len(compactions),
                    "message": f"Session had {len(compactions)} compactions (threshold: 3)",
                }
            )

        # Long sessions
        timestamps = [parse_ts(e.get("ts", "")) for e in evts]
        timestamps = [t for t in timestamps if t]
        if len(timestamps) >= 2:
            duration = (max(timestamps) - min(timestamps)).total_seconds()
            pre_tools = [e for e in evts if e.get("event") == "PreToolUse"]
            if duration > 7200 and len(pre_tools) > 50:
                signals.append(
                    {
                        "type": "long_session",
                        "session": sid,
                        "duration_hours": round(duration / 3600, 1),
                        "tool_count": len(pre_tools),
                        "message": f"Session lasted {round(duration / 3600, 1)}h with {len(pre_tools)} tool uses",
                    }
                )

        # High tool-to-prompt ratio
        prompts = [e for e in evts if e.get("event") == "UserPromptSubmit"]
        pre_tools = [e for e in evts if e.get("event") == "PreToolUse"]
        if len(prompts) > 0 and len(pre_tools) / len(prompts) > 50:
            signals.append(
                {
                    "type": "high_tool_ratio",
                    "session": sid,
                    "tools": len(pre_tools),
                    "prompts": len(prompts),
                    "ratio": round(len(pre_tools) / len(prompts), 1),
                    "message": f"{len(pre_tools)} tools / {len(prompts)} prompts = {round(len(pre_tools) / len(prompts), 1)}x ratio",
                }
            )

        # Error-retry cycles: same tool invoked 3+ times within 60s
        tool_timestamps = defaultdict(list)
        for e in evts:
            if e.get("event") == "PreToolUse":
                tn = e.get("data", {}).get("tool_name", "")
                ts = parse_ts(e.get("ts", ""))
                if tn and ts:
                    tool_timestamps[tn].append(ts)

        for tn, ts_list in tool_timestamps.items():
            if len(ts_list) < 3:
                continue
            ts_list.sort()
            # Sliding window: check for 3+ invocations within 60s
            for i in range(len(ts_list) - 2):
                window = (ts_list[i + 2] - ts_list[i]).total_seconds()
                if window <= 60:
                    # Count how many fit in this 60s window
                    burst = 2
                    for j in range(i + 3, len(ts_list)):
                        if (ts_list[j] - ts_list[i]).total_seconds() <= 60:
                            burst += 1
                        else:
                            break
                    signals.append(
                        {
                            "type": "error_retry_cycle",
                            "session": sid,
                            "tool": tn,
                            "count": burst + 1,
                            "window_seconds": round(window),
                            "message": f"'{tn}' invoked {burst + 1} times within {round(window)}s — possible retry loop",
                        }
                    )
                    break  # One signal per tool per session

        # Low tool completion rate within session
        pre_counter = Counter()
        post_counter = Counter()
        for e in evts:
            tn = e.get("data", {}).get("tool_name", "")
            if not tn:
                continue
            if e.get("event") == "PreToolUse":
                pre_counter[tn] += 1
            elif e.get("event") == "PostToolUse":
                post_counter[tn] += 1

        for tn, pre_count in pre_counter.items():
            if pre_count < 3:
                continue  # Need enough data to be meaningful
            post_count = post_counter.get(tn, 0)
            completion_rate = post_count / pre_count if pre_count > 0 else 0
            if completion_rate < 0.7:
                signals.append(
                    {
                        "type": "low_completion_rate",
                        "session": sid,
                        "tool": tn,
                        "invocations": pre_count,
                        "completions": post_count,
                        "rate": round(completion_rate * 100, 1),
                        "message": f"'{tn}' completed {post_count}/{pre_count} times ({round(completion_rate * 100, 1)}% rate)",
                    }
                )

    # Rarely-used skills (across all sessions)
    skill_counter = Counter()
    for evts in sessions.values():
        for e in evts:
            if e.get("event") == "PreToolUse" and e.get("data", {}).get("is_skill"):
                skill_counter[e.get("data", {}).get("skill_name", "")] += 1

    for skill, count in skill_counter.items():
        if count < 2 and skill:
            signals.append(
                {
                    "type": "rarely_used_skill",
                    "skill": skill,
                    "count": count,
                    "message": f"Skill '{skill}' used only {count} time(s)",
                }
            )

    return {
        "signal_count": len(signals),
        "signals": signals,
    }


# ---------------------------------------------------------------------------
# Mode: pipeline-summary
# ---------------------------------------------------------------------------

DEVKIT_SKILLS = {"devkit:test", "devkit:lint", "devkit:check", "devkit:review", "devkit:commit"}
PIPELINE_GAP_SECONDS = 300  # 5 minutes — max gap between steps in one pipeline run


def pipeline_summary(events):
    """Detect and summarize devkit ship pipeline runs from skill invocation patterns."""
    sessions = defaultdict(list)
    for ev in events:
        sessions[ev.get("sid", "unknown")].append(ev)

    pipelines = []

    for sid, evts in sessions.items():
        evts.sort(key=lambda e: e.get("ts", ""))

        # Collect devkit skill invocations with timestamps
        devkit_events = []
        for e in evts:
            data = e.get("data", {})
            if not data.get("is_skill"):
                continue
            skill_name = data.get("skill_name", "")
            if skill_name in DEVKIT_SKILLS:
                ts = parse_ts(e.get("ts", ""))
                if ts:
                    devkit_events.append({
                        "skill": skill_name,
                        "ts": ts,
                        "event_type": e.get("event", ""),
                    })

        if len(devkit_events) < 2:
            continue

        # Group into pipeline runs by temporal proximity
        runs = []
        current_run = [devkit_events[0]]

        for i in range(1, len(devkit_events)):
            gap = (devkit_events[i]["ts"] - devkit_events[i - 1]["ts"]).total_seconds()
            if gap <= PIPELINE_GAP_SECONDS:
                current_run.append(devkit_events[i])
            else:
                if len(current_run) >= 2:
                    runs.append(current_run)
                current_run = [devkit_events[i]]

        if len(current_run) >= 2:
            runs.append(current_run)

        # Build pipeline summaries
        for run in runs:
            # Deduplicate: group Pre+Post pairs per skill into steps
            steps = []
            seen_skills = set()
            for ev_item in run:
                skill = ev_item["skill"]
                if skill not in seen_skills:
                    seen_skills.add(skill)
                    # Find matching Pre/Post pair for duration
                    pre_ts = None
                    post_ts = None
                    for r in run:
                        if r["skill"] == skill:
                            if r["event_type"] == "PreToolUse" and pre_ts is None:
                                pre_ts = r["ts"]
                            elif r["event_type"] == "PostToolUse" and post_ts is None:
                                post_ts = r["ts"]
                    duration = None
                    if pre_ts and post_ts:
                        duration = round((post_ts - pre_ts).total_seconds(), 1)
                    steps.append({
                        "skill": skill.replace("devkit:", ""),
                        "duration_seconds": duration,
                    })

            start_ts = run[0]["ts"]
            end_ts = run[-1]["ts"]
            total_duration = round((end_ts - start_ts).total_seconds(), 1)

            # Infer result: if commit step present, likely succeeded
            step_names = [s["skill"] for s in steps]
            has_commit = "commit" in step_names
            result = "completed" if has_commit else "incomplete"

            project = ""
            for e in evts:
                if e.get("project"):
                    project = e["project"]
                    break

            pipelines.append({
                "session": sid,
                "project": project,
                "date": start_ts.strftime("%Y-%m-%d %H:%M"),
                "steps": steps,
                "step_names": step_names,
                "total_duration_seconds": total_duration,
                "total_duration_human": format_duration(total_duration),
                "result": result,
            })

    # Sort by date descending
    pipelines.sort(key=lambda p: p["date"], reverse=True)

    # Compute summary stats
    total = len(pipelines)
    completed = sum(1 for p in pipelines if p["result"] == "completed")
    avg_duration = (
        round(sum(p["total_duration_seconds"] for p in pipelines) / total, 1)
        if total > 0
        else 0
    )

    # Step frequency
    step_counter = Counter()
    step_durations = defaultdict(list)
    for p in pipelines:
        for s in p["steps"]:
            step_counter[s["skill"]] += 1
            if s["duration_seconds"] is not None:
                step_durations[s["skill"]].append(s["duration_seconds"])

    step_stats = []
    for step, count in step_counter.most_common():
        durs = step_durations.get(step, [])
        avg_dur = round(sum(durs) / len(durs), 1) if durs else None
        step_stats.append({"step": step, "count": count, "avg_duration": avg_dur})

    return {
        "total_pipelines": total,
        "completed": completed,
        "incomplete": total - completed,
        "avg_duration_seconds": avg_duration,
        "avg_duration_human": format_duration(avg_duration),
        "step_stats": step_stats,
        "pipelines": pipelines[:20],  # Last 20 runs
    }


# ---------------------------------------------------------------------------
# Mode: export-csv
# ---------------------------------------------------------------------------


def export_csv(events, output=sys.stdout):
    """Write filtered events as CSV."""
    writer = csv.writer(output)
    writer.writerow(
        ["ts", "event", "sid", "project", "tool_name", "is_mcp", "is_skill", "skill_name"]
    )
    for ev in events:
        data = ev.get("data", {})
        writer.writerow(
            [
                ev.get("ts", ""),
                ev.get("event", ""),
                ev.get("sid", ""),
                ev.get("project", ""),
                data.get("tool_name", ""),
                data.get("is_mcp", ""),
                data.get("is_skill", ""),
                data.get("skill_name", ""),
            ]
        )


# ---------------------------------------------------------------------------
# Text formatting
# ---------------------------------------------------------------------------


def format_duration(seconds):
    """Format seconds into human-readable duration."""
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds // 60)}m {int(seconds % 60)}s"
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    return f"{hours}h {minutes}m"


def format_text(data, mode):
    """Format structured data as human-readable text."""
    if "error" in data:
        return data["error"]

    lines = []

    if mode == "session-summary":
        lines.append(f"Session: {data['session_id']}")
        lines.append(f"Duration: {data['duration_human']}")
        lines.append(f"Period: {data['start']} → {data['end']}")
        lines.append("")
        lines.append(f"{'Metric':<25} {'Value':>10}")
        lines.append("-" * 36)
        lines.append(f"{'Total events':<25} {data['total_events']:>10}")
        lines.append(f"{'Tool uses':<25} {data['tool_uses']:>10}")
        lines.append(f"{'Unique tools':<25} {data['unique_tools']:>10}")
        lines.append(f"{'Skills invoked':<25} {data['skills_invoked']:>10}")
        lines.append(f"{'Subagents spawned':<25} {data['subagents_spawned']:>10}")
        lines.append(f"{'Compactions':<25} {data['compactions']:>10}")
        lines.append(f"{'Prompts':<25} {data['prompts']:>10}")
        lines.append(f"{'Avg prompt length':<25} {data['avg_prompt_length']:>10}")
        lines.append(f"{'Est. cost':<25} {'$' + str(data['cost']) if data['cost'] != 'N/A' else 'N/A':>10}")
        if data["top_tools"]:
            lines.append("")
            lines.append("Top tools:")
            for t in data["top_tools"]:
                lines.append(f"  {t['tool']:<30} {t['count']:>5}x")
        if data["skill_names"]:
            lines.append("")
            lines.append("Skills used: " + ", ".join(data["skill_names"]))

    elif mode == "full-report":
        lines.append(f"Sessions: {data['total_sessions']}  |  Events: {data['total_events']}  |  Avg tools/session: {data['avg_tools_per_session']}")
        cost_str = f"${data['cost_total']}" if data["cost_total"] != "N/A" else "N/A"
        avg_cost_str = f"${data['cost_avg_per_session']}" if data["cost_avg_per_session"] != "N/A" else "N/A"
        lines.append(f"Total cost: {cost_str}  |  Avg/session: {avg_cost_str}  |  Compactions: {data['total_compactions']}")
        if data["projects"]:
            lines.append("")
            lines.append(f"{'Project':<30} {'Sessions':>10}")
            lines.append("-" * 41)
            for p, c in data["projects"].items():
                lines.append(f"{p:<30} {c:>10}")
        if data["top_tools"]:
            lines.append("")
            lines.append(f"{'Tool':<30} {'Count':>10}")
            lines.append("-" * 41)
            for t in data["top_tools"]:
                lines.append(f"{t['tool']:<30} {t['count']:>10}")
        if data["skills"]:
            lines.append("")
            lines.append(f"{'Skill':<30} {'Count':>10}")
            lines.append("-" * 41)
            for s in data["skills"]:
                lines.append(f"{s['skill']:<30} {s['count']:>10}")
        if data["subagent_types"]:
            lines.append("")
            lines.append("Subagent types: " + ", ".join(f"{t}({c})" for t, c in data["subagent_types"].items()))

    elif mode == "tool-detail":
        lines.append(f"{'Tool':<30} {'Uses':>6} {'Done':>6} {'Sess':>6} {'AvgIn':>8} {'AvgOut':>8}")
        lines.append("-" * 66)
        for t in data["tools"]:
            mcp = f" [MCP: {t.get('mcp_server','')}/{t.get('mcp_tool','')}]" if t.get("mcp_server") else ""
            lines.append(
                f"{t['tool']:<30} {t['invocations']:>6} {t['completions']:>6} "
                f"{t['sessions']:>6} {t['avg_input_size']:>8} {t['avg_response_size']:>8}{mcp}"
            )

    elif mode == "skill-usage":
        lines.append(f"{'Skill':<40} {'Uses':>8} {'Sessions':>10}")
        lines.append("-" * 59)
        for s in data["skills"]:
            lines.append(f"{s['skill']:<40} {s['invocations']:>8} {s['sessions']:>10}")

    elif mode == "quality-signals":
        lines.append(f"Found {data['signal_count']} quality signal(s)")
        if data["signals"]:
            lines.append("")
            for s in data["signals"]:
                lines.append(f"  [{s['type']}] {s['message']}")

    elif mode == "pipeline-summary":
        lines.append(f"Pipelines: {data['total_pipelines']}  |  Completed: {data['completed']}  |  Incomplete: {data['incomplete']}  |  Avg duration: {data['avg_duration_human']}")
        if data["step_stats"]:
            lines.append("")
            lines.append(f"{'Step':<15} {'Count':>7} {'Avg Duration':>14}")
            lines.append("-" * 38)
            for s in data["step_stats"]:
                dur_str = format_duration(s["avg_duration"]) if s["avg_duration"] is not None else "N/A"
                lines.append(f"{s['step']:<15} {s['count']:>7} {dur_str:>14}")
        if data["pipelines"]:
            lines.append("")
            lines.append(f"{'Date':<18} {'Steps':<30} {'Duration':>10} {'Result':>12}")
            lines.append("-" * 72)
            for p in data["pipelines"]:
                steps_str = " → ".join(p["step_names"])
                lines.append(f"{p['date']:<18} {steps_str:<30} {p['total_duration_human']:>10} {p['result']:>12}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Observe plugin query engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--mode",
        required=True,
        choices=[
            "session-summary",
            "full-report",
            "tool-detail",
            "skill-usage",
            "quality-signals",
            "pipeline-summary",
            "export-csv",
        ],
        help="Analysis mode",
    )
    parser.add_argument("--session", help="Filter to session ID")
    parser.add_argument("--project", help="Filter to project name")
    parser.add_argument(
        "--range", dest="date_range", help="Date range: last-7d, last-30d, YYYY-MM-DD:YYYY-MM-DD"
    )
    parser.add_argument("--tool", help="Tool name filter (for tool-detail)")
    parser.add_argument(
        "--format", dest="fmt", default="text", choices=["text", "json"], help="Output format"
    )
    args = parser.parse_args()

    # Check data directory
    if not os.path.isdir(DATA_DIR):
        print("No observability data found.")
        print(f"Expected data at: {DATA_DIR}")
        sys.exit(0)

    date_range = parse_date_range(args.date_range)

    # Read events
    events = list(
        read_events(
            data_dir=DATA_DIR,
            date_range=date_range,
            project=args.project,
            session=args.session,
        )
    )

    if not events and args.mode != "export-csv":
        print("No events match the specified filters.")
        sys.exit(0)

    # Read cost log
    costs = read_cost_log()

    # Dispatch to mode
    if args.mode == "session-summary":
        result = session_summary(events, costs)
    elif args.mode == "full-report":
        result = full_report(events, costs)
    elif args.mode == "tool-detail":
        result = tool_detail(events, tool_filter=args.tool)
    elif args.mode == "skill-usage":
        result = skill_usage(events)
    elif args.mode == "quality-signals":
        result = quality_signals(events)
    elif args.mode == "pipeline-summary":
        result = pipeline_summary(events)
    elif args.mode == "export-csv":
        export_csv(events)
        return

    # Output
    if args.fmt == "json":
        print(json.dumps(result, indent=2, default=str))
    else:
        print(format_text(result, args.mode))


if __name__ == "__main__":
    main()
