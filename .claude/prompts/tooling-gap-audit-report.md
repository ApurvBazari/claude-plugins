# Tooling Gap Audit — Report Phase

You are the rendering engine for a tooling gap audit. The analysis phase has already collected all data into a structured JSON file. Your job: read that JSON and produce a strict-schema markdown report. Do NOT re-fetch any URLs or re-analyze any plugin files.

## Step 1: Locate the Intermediary JSON

Run this command via Bash to find the most recently written analysis file:

```bash
find docs/tooling-gap-reports -name '.audit-data-*.json' 2>/dev/null | sort | tail -1
```

Read that file. Extract the date from the filename (the `YYYY-MM-DD` portion between `.audit-data-` and `.json`). Store it as `DATE`.

If no file is found, derive today's date by running `date -u +%Y-%m-%d` via Bash. Then write a minimal error report:

```markdown
# Tooling Gap Audit — Error

Analysis phase did not produce an intermediary JSON file. Check the workflow logs for the analyze step.
```

Save it as `docs/tooling-gap-reports/<DATE>-gap-report.md` and stop.

## Step 2: Validate JSON Structure

Confirm the JSON contains all required top-level keys: `meta`, `surfaces`, `localCoverage`, `probeList`, `gaps`, `baselineDiff`.

If any key is missing, write an error report noting which keys are missing and stop.

## Step 3: Render the Markdown Report

Write the report to:

```
docs/tooling-gap-reports/<DATE>-gap-report.md
```

Use the exact section order and table formats below. Do not add, remove, or reorder sections.

### Section 1: Title

```markdown
# Tooling Gap Audit — <DATE>
```

### Section 2: Summary

```markdown
## Summary
```

Write 2-3 sentences covering:
- Key findings (how many gaps at each priority level)
- What changed since the last run (reference `baselineDiff`)
- Any notable URL fetch failures from `meta.urlsFailed`

### Section 3: Anthropic Surface Snapshot

```markdown
## Anthropic Surface Snapshot

| Category | Surfaces | Count | Source |
|---|---|---|---|
| Hook events | <comma-separated list> | <N> | [hooks docs](<url>) |
| Hook types | <comma-separated list> | <N> | [hooks docs](<url>) |
| Skill frontmatter | <comma-separated list> | <N> | [skills docs](<url>) |
| Agent frontmatter | <comma-separated list> | <N> | [sub-agents docs](<url>) |
| MCP transports | <comma-separated list> | <N> | [mcp docs](<url>) |
| Other surfaces | <comma-separated list> | <N> | various |
```

Sort entries within each cell alphabetically. Use the first successful URL from `meta.urlsFetched` that matches the category as the source link.

### Section 4: Local Plugin Coverage

```markdown
## Local Plugin Coverage

| Surface | onboard | forge | notify |
|---|---|---|---|
| Hook: <EventName> | Y | - | N |
| ...one row per surface item... |
```

Legend (include after the table):
- `Y` — plugin uses or generates this surface
- `N` — gap (Anthropic supports it, plugin should handle it but doesn't)
- `-` — not applicable for this plugin's scope

Sort rows alphabetically within each surface category. Group by category with a blank row between groups.

### Section 5: Referenced Plugin Patterns

```markdown
## Referenced Plugin Patterns

| Plugin | Status | Surfaces exercised |
|---|---|---|
| <name> | active | skills (<N>), agents (<N>), hooks (<N>) |
```

Sort by plugin name alphabetically.

Include a Flagged subsection:

```markdown
### Flagged

- **Possibly deprecated**: <comma-separated list, or "none this cycle">
```

### Section 6: Gap List

```markdown
## Gap List

### P0 — Core-job-critical

| ID | Gap | Plugin | Size | Rationale |
|---|---|---|---|---|
| GAP-001 | <surface description> | onboard | M | <why this matters> |

### P1 — Feature parity

| ID | Gap | Plugin | Size | Rationale |
|---|---|---|---|---|

### P2 — Polish

| ID | Gap | Plugin | Size | Rationale |
|---|---|---|---|---|
```

If a priority tier has no gaps, render the table header followed by a single row:

```markdown
| — | None identified this cycle | — | — | — |
```

Sort gaps within each tier by ID.

### Section 7: Baseline Changes

```markdown
## Baseline Changes

- **Added**: <comma-separated list of new surfaces, or "none">
- **Removed**: <comma-separated list of removed surfaces, or "none">
```

## Step 4: Update Baseline (Conditional)

Read `.claude/audit-baseline.json`.

If `baselineDiff.addedSurfaces` is non-empty OR `baselineDiff.removedSurfaces` is non-empty:

1. Merge `addedSurfaces` into the appropriate surface arrays in the baseline
2. Remove `removedSurfaces` from the appropriate surface arrays
3. Update `lastUpdated` to `DATE`
4. Keep all arrays alphabetically sorted
5. Write the updated baseline back to `.claude/audit-baseline.json`

If `baselineDiff.unchanged` is `true`: do not touch the baseline file.

## Rules

1. Do NOT re-fetch any URLs. All data comes from the intermediary JSON.
2. Follow the exact section order and table formats above. No additions, removals, or reordering.
3. Sort all table rows and list items alphabetically for deterministic, diffable output.
4. If `baselineDiff.unchanged` is `true`, state "No surface changes since last run" in both the Summary and Baseline Changes sections.
5. Empty gap tiers render with the "None identified this cycle" placeholder row, not as empty tables.
