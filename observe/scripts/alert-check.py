#!/usr/bin/env python3
"""Pattern-based alert checker for the observe plugin.

Reads recent observe data for the current session, applies configurable
rules, and calls notify's notify.sh when patterns are detected.

Designed to run on Stop events as a lightweight check. Always exits 0.

Usage:
    python3 alert-check.py --session <sid> [--notify-script <path>]
"""

import glob
import json
import os
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

DATA_DIR = os.path.expanduser("~/.claude/observability/data")
CONFIG_PATH = os.path.expanduser("~/.claude/observability/config.json")

# Default alert thresholds
DEFAULT_ALERTS = {
    "compaction_threshold": 4,
    "session_duration_hours": 3,
    "error_rate_threshold": 5,
    "error_rate_window_minutes": 10,
    "tool_failure_rate": 0.5,
    "enabled": True,
}

# Notify script search paths
NOTIFY_SEARCH_PATHS = [
    os.path.expanduser("~/.claude/hooks/notify.sh"),
    os.path.expanduser("~/.claude/notify/scripts/notify.sh"),
]


def load_config():
    """Load alert config from observe config.json."""
    config = dict(DEFAULT_ALERTS)
    if os.path.isfile(CONFIG_PATH):
        try:
            with open(CONFIG_PATH) as f:
                data = json.load(f)
            alerts = data.get("alerts", {})
            for key in DEFAULT_ALERTS:
                if key in alerts:
                    config[key] = alerts[key]
        except (json.JSONDecodeError, OSError):
            pass
    return config


def parse_ts(ts_str):
    if not ts_str:
        return None
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def read_session_events(session_id):
    """Read events for a specific session from recent data files."""
    events = []
    # Only check last 2 months of data (current session should be recent)
    now = datetime.now(timezone.utc)
    months = [now.strftime("%Y-%m")]
    if now.day < 2:
        prev = now - timedelta(days=2)
        months.append(prev.strftime("%Y-%m"))

    for month in months:
        filepath = os.path.join(DATA_DIR, f"events-{month}.ndjson")
        if not os.path.isfile(filepath):
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
                if rec.get("sid") == session_id:
                    events.append(rec)

    events.sort(key=lambda e: e.get("ts", ""))
    return events


def find_notify_script(custom_path=None):
    """Find notify.sh script path."""
    if custom_path and os.path.isfile(custom_path):
        return custom_path
    for path in NOTIFY_SEARCH_PATHS:
        if os.path.isfile(path):
            return path
    return None


def send_alert(notify_script, message):
    """Send alert via notify.sh."""
    try:
        stdin_json = json.dumps({"message": message})
        subprocess.run(
            [notify_script, "notification"],
            input=stdin_json,
            capture_output=True,
            timeout=10,
            text=True,
        )
    except (subprocess.TimeoutExpired, OSError):
        pass


def check_alerts(events, config):
    """Check for alert-worthy patterns. Returns list of alert messages."""
    alerts = []

    if not events:
        return alerts

    # 1. High compaction frequency
    compactions = [e for e in events if e.get("event") == "PreCompact"]
    threshold = config.get("compaction_threshold", 4)
    if len(compactions) >= threshold:
        alerts.append(
            f"Context compacted {len(compactions)} times this session (threshold: {threshold}). "
            "Consider breaking work into smaller tasks."
        )

    # 2. Long session duration
    timestamps = [parse_ts(e.get("ts", "")) for e in events]
    timestamps = [t for t in timestamps if t]
    if len(timestamps) >= 2:
        duration_hours = (max(timestamps) - min(timestamps)).total_seconds() / 3600
        max_hours = config.get("session_duration_hours", 3)
        if duration_hours >= max_hours:
            alerts.append(
                f"Session has been running for {duration_hours:.1f} hours "
                f"(threshold: {max_hours}h). Consider taking a break."
            )

    # 3. Error rate spike (tool failures in recent window)
    window_minutes = config.get("error_rate_window_minutes", 10)
    error_threshold = config.get("error_rate_threshold", 5)
    if timestamps:
        now = max(timestamps)
        window_start = now - timedelta(minutes=window_minutes)
        recent_pre = Counter()
        recent_post = Counter()
        for e in events:
            ts = parse_ts(e.get("ts", ""))
            if not ts or ts < window_start:
                continue
            tn = e.get("data", {}).get("tool_name", "")
            if not tn:
                continue
            if e.get("event") == "PreToolUse":
                recent_pre[tn] += 1
            elif e.get("event") == "PostToolUse":
                recent_post[tn] += 1

        # Count tools with missing completions as failures
        failures = 0
        for tn, pre_count in recent_pre.items():
            post_count = recent_post.get(tn, 0)
            failures += max(0, pre_count - post_count)

        if failures >= error_threshold:
            alerts.append(
                f"{failures} tool failures in the last {window_minutes} minutes "
                f"(threshold: {error_threshold}). Something may be going wrong."
            )

    # 4. High tool failure rate (per-tool, session-wide)
    failure_rate_threshold = config.get("tool_failure_rate", 0.5)
    pre_counter = Counter()
    post_counter = Counter()
    for e in events:
        tn = e.get("data", {}).get("tool_name", "")
        if not tn:
            continue
        if e.get("event") == "PreToolUse":
            pre_counter[tn] += 1
        elif e.get("event") == "PostToolUse":
            post_counter[tn] += 1

    for tn, pre_count in pre_counter.items():
        if pre_count < 5:
            continue  # Need enough data
        post_count = post_counter.get(tn, 0)
        rate = post_count / pre_count if pre_count > 0 else 0
        if rate < (1 - failure_rate_threshold):
            alerts.append(
                f"Tool '{tn}' failing frequently: {post_count}/{pre_count} completions "
                f"({rate:.0%} success rate)."
            )

    return alerts


def main():
    try:
        # Parse args
        session_id = None
        notify_path = None
        args = sys.argv[1:]
        i = 0
        while i < len(args):
            if args[i] == "--session" and i + 1 < len(args):
                session_id = args[i + 1]
                i += 2
            elif args[i] == "--notify-script" and i + 1 < len(args):
                notify_path = args[i + 1]
                i += 2
            else:
                i += 1

        if not session_id:
            return

        # Load config
        config = load_config()
        if not config.get("enabled", True):
            return

        # Check data directory
        if not os.path.isdir(DATA_DIR):
            return

        # Read session events
        events = read_session_events(session_id)
        if not events:
            return

        # Check for patterns
        alerts = check_alerts(events, config)
        if not alerts:
            return

        # Find notify script
        notify_script = find_notify_script(notify_path)
        if not notify_script:
            return

        # Send first alert only (avoid notification spam)
        send_alert(notify_script, alerts[0])

    except Exception:
        pass
    finally:
        sys.exit(0)


if __name__ == "__main__":
    main()
