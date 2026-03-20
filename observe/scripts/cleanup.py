#!/usr/bin/env python3
"""Data retention cleanup for the observe plugin.

Deletes NDJSON event files older than the configured retention period.
Never deletes the current month's file.

Usage:
    python3 cleanup.py [--dry-run]
"""

import glob
import json
import os
import sys
from datetime import datetime, timezone

DATA_DIR = os.path.expanduser("~/.claude/observability/data")
CONFIG_PATH = os.path.expanduser("~/.claude/observability/config.json")
DEFAULT_RETENTION_MONTHS = 6


def load_retention_months():
    """Read retention_months from config, default to 6."""
    if not os.path.isfile(CONFIG_PATH):
        return DEFAULT_RETENTION_MONTHS
    try:
        with open(CONFIG_PATH) as f:
            config = json.load(f)
        return int(config.get("retention_months", DEFAULT_RETENTION_MONTHS))
    except (json.JSONDecodeError, ValueError, OSError):
        return DEFAULT_RETENTION_MONTHS


def get_cutoff_month(retention_months):
    """Calculate the oldest month to keep (YYYY-MM string)."""
    now = datetime.now(timezone.utc)
    # Go back retention_months from current month
    year = now.year
    month = now.month - retention_months
    while month < 1:
        month += 12
        year -= 1
    return f"{year:04d}-{month:02d}"


def get_data_files():
    """List all event NDJSON files with their month strings."""
    pattern = os.path.join(DATA_DIR, "events-*.ndjson")
    files = []
    for filepath in sorted(glob.glob(pattern)):
        basename = os.path.basename(filepath)
        month = basename.replace("events-", "").replace(".ndjson", "")
        try:
            # Validate it's a real YYYY-MM format
            datetime.strptime(month + "-01", "%Y-%m-%d")
            files.append((filepath, month))
        except ValueError:
            continue
    return files


def file_size_human(size_bytes):
    """Format bytes as human-readable size."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    if size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes / (1024 * 1024):.1f} MB"


def main():
    dry_run = "--dry-run" in sys.argv

    if not os.path.isdir(DATA_DIR):
        print("No observability data directory found.")
        sys.exit(0)

    retention = load_retention_months()
    cutoff = get_cutoff_month(retention)
    now_month = datetime.now(timezone.utc).strftime("%Y-%m")
    files = get_data_files()

    if not files:
        print("No event files found.")
        sys.exit(0)

    # Calculate total data size
    total_size = sum(os.path.getsize(f) for f, _ in files)
    print(f"Data directory: {DATA_DIR}")
    print(f"Total files: {len(files)}  |  Total size: {file_size_human(total_size)}")
    print(f"Retention: {retention} months  |  Cutoff: {cutoff}")
    print()

    to_delete = []
    to_keep = []
    for filepath, month in files:
        size = os.path.getsize(filepath)
        if month == now_month:
            to_keep.append((filepath, month, size, "current month"))
        elif month < cutoff:
            to_delete.append((filepath, month, size))
        else:
            to_keep.append((filepath, month, size, "within retention"))

    if not to_delete:
        print("No files older than retention period. Nothing to clean up.")
        print(f"\nKept files ({len(to_keep)}):")
        for fp, month, size, reason in to_keep:
            print(f"  {os.path.basename(fp):<30} {file_size_human(size):>10}  ({reason})")
        sys.exit(0)

    freed = sum(s for _, _, s in to_delete)
    action = "Would delete" if dry_run else "Deleting"
    print(f"{action} {len(to_delete)} file(s), freeing {file_size_human(freed)}:")
    for filepath, month, size in to_delete:
        print(f"  {os.path.basename(filepath):<30} {file_size_human(size):>10}")
        if not dry_run:
            os.remove(filepath)

    print(f"\nKept files ({len(to_keep)}):")
    for fp, month, size, reason in to_keep:
        print(f"  {os.path.basename(fp):<30} {file_size_human(size):>10}  ({reason})")

    if dry_run:
        print(f"\n(Dry run — no files were deleted. Run without --dry-run to delete.)")
    else:
        print(f"\nFreed {file_size_human(freed)}.")


if __name__ == "__main__":
    main()
