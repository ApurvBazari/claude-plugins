# Tooling Gap Reports

Automated gap analysis comparing Anthropic's current Claude Code feature surface against what onboard, forge, and notify actually generate. Runs on the 1st and 15th of each month via GitHub Actions.

## Cadence

- **Schedule**: 1st and 15th of each month, 06:00 UTC
- **Workflow**: `.github/workflows/tooling-gap-audit.yml`
- **Manual trigger**: `workflow_dispatch` from the Actions tab

## Report Files

Each run produces two files:

| File | Purpose |
|---|---|
| `<YYYY-MM-DD>-gap-report.md` | Human-readable gap report |
| `.audit-data-<YYYY-MM-DD>.json` | Machine-readable intermediary (version-controlled for debugging) |

## How to Read a Report

### Summary

2-3 sentences covering key findings and what changed since the last run.

### Anthropic Surface Snapshot

What Anthropic's docs say exists today, sourced from 10 live documentation URLs. If a URL failed during fetching, it's noted in the intermediary JSON's `meta.urlsFailed` array.

### Local Plugin Coverage

Which surfaces each plugin already handles:

| Symbol | Meaning |
|---|---|
| `Y` | Plugin uses or generates this surface |
| `N` | Gap — Anthropic supports it, plugin should handle it but doesn't |
| `-` | Not applicable for this plugin's scope |

### Referenced Plugin Patterns

What surfaces the probe-list plugins (from `plugin-detection-guide.md`) exercise. Includes a Flagged subsection for plugins that may be deprecated.

### Gap List

Gaps sorted into three priority tiers:

| Priority | Definition |
|---|---|
| **P0** | Generated tooling is visibly broken or stale. Fix before next release. |
| **P1** | Feature parity gap. Plugin works but misses a shipped capability. |
| **P2** | Polish / nice-to-have. |

Size estimates:

| Size | Effort |
|---|---|
| XS | < 1 hour |
| S | Half-day |
| M | 1-2 days |
| L | 3+ days |

### Baseline Changes

Surfaces added or removed from Anthropic's documentation since the last run.

## How to Act on a Gap

1. Pick a gap from the P0 or P1 table
2. Create a branch: `feat/<plugin>-<short-description>` (e.g., `feat/onboard-elicitation-hook`)
3. Implement the change against `develop`
4. Open a PR referencing the gap ID (e.g., "Closes GAP-042")
5. Tick the checkbox in `future-plans/tooling-gap-audit-and-automation.md` if the gap maps to an existing item
6. After merge, the gap disappears from the next audit cycle automatically

## Baseline

`.claude/audit-baseline.json` tracks the last known surface snapshot. Updated automatically by the report phase when surfaces change. To manually acknowledge a surface removal (Anthropic deprecated something), edit the baseline directly — the diff will reflect on the next run.
