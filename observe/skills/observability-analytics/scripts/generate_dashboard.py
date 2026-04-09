#!/usr/bin/env python3
"""Generate self-contained HTML dashboard from observability data.

Reads NDJSON event files, computes chart aggregations, embeds data
into an HTML template with Chart.js, and opens the result in a browser.

Usage:
    python3 generate_dashboard.py [last-7d|last-30d|last-90d|YYYY-MM-DD:YYYY-MM-DD]
"""

import glob
import json
import os
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

DATA_DIR = os.path.expanduser("~/.claude/observability/data")
COST_LOG_PATH = os.path.expanduser("~/.claude/cost-log.jsonl")
CACHE_DIR = os.path.expanduser("~/.claude/observability/cache")
TEMPLATE_PATH = Path(__file__).parent.parent / "assets" / "dashboard-template.html"


# ---------------------------------------------------------------------------
# Date range parsing (same logic as query.py, implemented locally)
# ---------------------------------------------------------------------------


def parse_date_range(range_str):
    if not range_str:
        return None
    now = datetime.now(timezone.utc)
    if range_str.startswith("last-"):
        days_str = range_str[5:].rstrip("d")
        try:
            return (now - timedelta(days=int(days_str)), now)
        except ValueError:
            return None
    if ":" in range_str:
        parts = range_str.split(":", 1)
        try:
            start = datetime.strptime(parts[0], "%Y-%m-%d").replace(tzinfo=timezone.utc)
            end = datetime.strptime(parts[1], "%Y-%m-%d").replace(tzinfo=timezone.utc) + timedelta(days=1)
            return (start, end)
        except ValueError:
            return None
    return None


def parse_ts(ts_str):
    if not ts_str:
        return None
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def month_in_range(month_str, date_range):
    if not date_range:
        return True
    try:
        ms = datetime.strptime(month_str + "-01", "%Y-%m-%d").replace(tzinfo=timezone.utc)
        me = ms.replace(year=ms.year + 1, month=1) if ms.month == 12 else ms.replace(month=ms.month + 1)
        return ms < date_range[1] and me > date_range[0]
    except ValueError:
        return True


# ---------------------------------------------------------------------------
# Data reader
# ---------------------------------------------------------------------------


def read_events(date_range=None):
    events = []
    for filepath in sorted(glob.glob(os.path.join(DATA_DIR, "events-*.ndjson"))):
        month = os.path.basename(filepath).replace("events-", "").replace(".ndjson", "")
        if date_range and not month_in_range(month, date_range):
            continue
        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if date_range:
                    dt = parse_ts(rec.get("ts", ""))
                    if dt and not (date_range[0] <= dt <= date_range[1]):
                        continue
                events.append(rec)
    return events


def read_cost_log():
    costs = {}
    if not os.path.isfile(COST_LOG_PATH):
        return costs
    try:
        with open(COST_LOG_PATH) as f:
            for line in f:
                try:
                    rec = json.loads(line.strip())
                    sid = rec.get("sid", "")
                    cost = rec.get("cost", 0)
                    if sid:
                        costs[sid] = costs.get(sid, 0) + float(cost)
                except (json.JSONDecodeError, TypeError, ValueError):
                    continue
    except OSError:
        pass
    return costs


def match_cost(session_id, cost_map):
    if not session_id or not cost_map:
        return 0
    if session_id in cost_map:
        return cost_map[session_id]
    for cost_sid, cost in cost_map.items():
        if session_id.endswith(cost_sid):
            return cost
    return 0


# ---------------------------------------------------------------------------
# Chart aggregations
# ---------------------------------------------------------------------------


def sessions_per_day(events):
    day_sessions = defaultdict(set)
    for ev in events:
        dt = parse_ts(ev.get("ts", ""))
        if dt:
            day_sessions[dt.strftime("%Y-%m-%d")].add(ev.get("sid", ""))
    days = sorted(day_sessions.keys())
    return {"labels": days, "values": [len(day_sessions[d]) for d in days]}


def tool_distribution(events):
    counter = Counter()
    for ev in events:
        if ev.get("event") == "PreToolUse":
            counter[ev.get("data", {}).get("tool_name", "unknown")] += 1
    top = counter.most_common(15)
    return {"labels": [t for t, _ in top], "values": [c for _, c in top]}


def error_rate_trend(events):
    day_pre = defaultdict(int)
    day_post = defaultdict(int)
    for ev in events:
        dt = parse_ts(ev.get("ts", ""))
        if not dt:
            continue
        day = dt.strftime("%Y-%m-%d")
        if ev.get("event") == "PreToolUse":
            day_pre[day] += 1
        elif ev.get("event") == "PostToolUse":
            day_post[day] += 1
    all_days = sorted(set(day_pre.keys()) | set(day_post.keys()))
    rates = []
    for d in all_days:
        pre = day_pre.get(d, 0)
        post = day_post.get(d, 0)
        if pre > 0:
            # Approximate: completions < invocations suggests failures
            rate = max(0, (pre - post) / pre) if pre > post else 0
            rates.append(round(rate * 100, 1))
        else:
            rates.append(0)
    return {"labels": all_days, "values": rates}


def compactions_per_session(events):
    session_compactions = defaultdict(int)
    session_dates = {}
    for ev in events:
        sid = ev.get("sid", "")
        if ev.get("event") == "PreCompact":
            session_compactions[sid] += 1
        dt = parse_ts(ev.get("ts", ""))
        if dt and sid not in session_dates:
            session_dates[sid] = dt.strftime("%Y-%m-%d")
    # Only include sessions with compactions
    sids = [s for s in session_compactions if session_compactions[s] > 0]
    sids.sort(key=lambda s: session_dates.get(s, ""))
    return {
        "labels": [s[:12] for s in sids],
        "values": [session_compactions[s] for s in sids],
        "dates": [session_dates.get(s, "") for s in sids],
    }


def project_comparison(events):
    proj_sessions = defaultdict(set)
    proj_tools = defaultdict(int)
    for ev in events:
        proj = ev.get("project", "")
        if not proj:
            continue
        proj_sessions[proj].add(ev.get("sid", ""))
        if ev.get("event") == "PreToolUse":
            proj_tools[proj] += 1
    projects = sorted(proj_sessions.keys())
    return {
        "labels": projects,
        "sessions": [len(proj_sessions[p]) for p in projects],
        "tools": [proj_tools.get(p, 0) for p in projects],
    }


def skill_usage_table(events):
    counter = Counter()
    for ev in events:
        if ev.get("event") == "PreToolUse" and ev.get("data", {}).get("is_skill"):
            counter[ev.get("data", {}).get("skill_name", "unknown")] += 1
    return [{"skill": s, "count": c} for s, c in counter.most_common()]


def compute_summary(events, costs):
    sids = set(ev.get("sid", "") for ev in events)
    total_tools = sum(1 for ev in events if ev.get("event") == "PreToolUse")
    total_cost = sum(match_cost(sid, costs) for sid in sids)
    return {
        "total_sessions": len(sids),
        "total_events": len(events),
        "total_tools": total_tools,
        "total_cost": round(total_cost, 2),
    }


def quality_signals_summary(events):
    """Compute quality signal counts by type for dashboard display."""
    sessions = defaultdict(list)
    for ev in events:
        sessions[ev.get("sid", "unknown")].append(ev)

    signal_counts = Counter()
    for sid, evts in sessions.items():
        evts.sort(key=lambda e: e.get("ts", ""))
        compactions = [e for e in evts if e.get("event") == "PreCompact"]
        if len(compactions) > 3:
            signal_counts["high_compaction"] += 1

        timestamps = [parse_ts(e.get("ts", "")) for e in evts]
        timestamps = [t for t in timestamps if t]
        if len(timestamps) >= 2:
            dur = (max(timestamps) - min(timestamps)).total_seconds()
            pre = [e for e in evts if e.get("event") == "PreToolUse"]
            if dur > 7200 and len(pre) > 50:
                signal_counts["long_session"] += 1

        pre_c = Counter()
        post_c = Counter()
        for e in evts:
            tn = e.get("data", {}).get("tool_name", "")
            if e.get("event") == "PreToolUse":
                pre_c[tn] += 1
            elif e.get("event") == "PostToolUse":
                post_c[tn] += 1
        for tn, cnt in pre_c.items():
            if cnt >= 3 and (post_c.get(tn, 0) / cnt) < 0.7:
                signal_counts["low_completion"] += 1

    labels = list(signal_counts.keys()) if signal_counts else ["No issues"]
    values = list(signal_counts.values()) if signal_counts else [0]
    return {"labels": labels, "values": values, "total": sum(signal_counts.values())}


def activity_heatmap(events):
    """Count events per hour-of-day for an activity heatmap."""
    hour_counts = [0] * 24
    for ev in events:
        dt = parse_ts(ev.get("ts", ""))
        if dt:
            hour_counts[dt.hour] += 1
    labels = [f"{h:02d}:00" for h in range(24)]
    return {"labels": labels, "values": hour_counts}


def week_over_week(events):
    """Compare this week vs last week metrics."""
    now = datetime.now(timezone.utc)
    week_start = now - timedelta(days=now.weekday())  # Monday
    last_week_start = week_start - timedelta(days=7)

    this_week = {"sessions": set(), "tools": 0, "compactions": 0}
    last_week = {"sessions": set(), "tools": 0, "compactions": 0}

    for ev in events:
        dt = parse_ts(ev.get("ts", ""))
        if not dt:
            continue
        if dt >= week_start:
            bucket = this_week
        elif dt >= last_week_start:
            bucket = last_week
        else:
            continue
        bucket["sessions"].add(ev.get("sid", ""))
        if ev.get("event") == "PreToolUse":
            bucket["tools"] += 1
        elif ev.get("event") == "PreCompact":
            bucket["compactions"] += 1

    return {
        "labels": ["Sessions", "Tool Uses", "Compactions"],
        "this_week": [len(this_week["sessions"]), this_week["tools"], this_week["compactions"]],
        "last_week": [len(last_week["sessions"]), last_week["tools"], last_week["compactions"]],
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    range_arg = sys.argv[1] if len(sys.argv) > 1 else "last-30d"

    if not os.path.isdir(DATA_DIR):
        print("No observability data found.", file=sys.stderr)
        print(f"Expected data at: {DATA_DIR}", file=sys.stderr)
        sys.exit(1)

    date_range = parse_date_range(range_arg)
    events = read_events(date_range)

    if not events:
        print("No events in the specified range.", file=sys.stderr)
        sys.exit(1)

    costs = read_cost_log()

    chart_data = {
        "sessions_per_day": sessions_per_day(events),
        "tool_distribution": tool_distribution(events),
        "error_rate_trend": error_rate_trend(events),
        "compactions_per_session": compactions_per_session(events),
        "project_comparison": project_comparison(events),
        "skill_usage": skill_usage_table(events),
        "quality_signals": quality_signals_summary(events),
        "activity_heatmap": activity_heatmap(events),
        "week_over_week": week_over_week(events),
        "summary": compute_summary(events, costs),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "range": range_arg,
    }

    # Load template
    if not TEMPLATE_PATH.is_file():
        print(f"Template not found: {TEMPLATE_PATH}", file=sys.stderr)
        sys.exit(1)

    template = TEMPLATE_PATH.read_text()
    html = template.replace(
        "/*__EMBEDDED_DATA__*/null", json.dumps(chart_data, indent=2)
    )

    # Write output
    os.makedirs(CACHE_DIR, exist_ok=True)
    output_path = os.path.join(CACHE_DIR, "dashboard-latest.html")
    with open(output_path, "w") as f:
        f.write(html)

    print(f"Dashboard generated: {output_path}")

    # Open in browser (macOS)
    try:
        subprocess.run(["open", output_path], check=False)
    except FileNotFoundError:
        # Not on macOS or `open` not available
        print("Open the file manually in your browser.")


if __name__ == "__main__":
    main()
