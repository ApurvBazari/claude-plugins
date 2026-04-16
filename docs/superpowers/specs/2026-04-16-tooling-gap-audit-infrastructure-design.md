# Recurring 15-Day Tooling Gap Audit — Infrastructure Design

## Context

Our three plugins (onboard, forge, notify) generate Claude Code tooling based on a snapshot of Anthropic's feature surface. When Anthropic ships new hook events, skill frontmatter fields, agent options, MCP transports, or other capabilities, the generated tooling becomes silently stale. Part A of the tooling gap audit (`future-plans/tooling-gap-audit-and-automation.md`) was a one-time manual pass — 10 of 15 items now shipped. Part B automates that same analysis on a recurring 15-day cadence via GitHub Actions so gaps are discovered within two weeks of Anthropic shipping changes.

## Architecture: Two-Phase, Single Job

A single GHA job runs two sequential `claude-code-action` steps that share a workspace. Phase 1 (analysis) collects raw data into structured JSON. Phase 2 (report) renders that JSON into a strict-schema markdown report. A post-step shell script handles the diff-and-PR logic.

```
tooling-gap-audit.yml (cron 0 6 1,15 * * + workflow_dispatch)
runs-on: ubuntu-latest
permissions: contents: write, pull-requests: write, id-token: write

  Step 1: actions/checkout@v4 (develop)

  Step 2: claude-code-action — ANALYZE
    prompt_file: .claude/prompts/tooling-gap-audit-analyze.md
    model: claude-opus-4-6
    max_turns: 80
    Reads:  local plugins, probe list, baseline snapshot
    Fetches: 10 Anthropic doc URLs
    Writes: docs/tooling-gap-reports/.audit-data-<date>.json

  Step 3: claude-code-action — REPORT
    prompt_file: .claude/prompts/tooling-gap-audit-report.md
    model: claude-opus-4-6
    max_turns: 40
    Reads: .audit-data-<date>.json from Step 2
    Writes: <date>-gap-report.md + updated audit-baseline.json

  Step 4: .github/scripts/open-gap-audit-pr.sh
    Diffs today's report vs. previous
    Opens PR if content changed, exits 0 if unchanged
```

### Why two phases

- **Resilience**: If analysis succeeds but rendering fails, the raw JSON is preserved for debugging or manual re-run.
- **Fail-fast**: If analysis fails (WebFetch errors, max-turns exceeded), rendering never starts — no wasted turns.
- **Debuggability**: The intermediary JSON is version-controlled, so historical analysis data is inspectable.

### Why single job (not two jobs)

GHA jobs run on separate runners. Passing the intermediary JSON between jobs would require `actions/upload-artifact` + `actions/download-artifact`. A single job with sequential steps avoids this — all steps share the same filesystem.

## Prompt Contract: Analysis Phase

File: `.claude/prompts/tooling-gap-audit-analyze.md`

### Objective

Read local plugin files and live Anthropic documentation. Produce a structured JSON file capturing all known surfaces, local plugin coverage, probe list status, and identified gaps.

### Inputs

| Source | What to extract |
|---|---|
| `onboard/`, `forge/`, `notify/` (recursive) | Skills, agents, hooks, scripts, MCP configs — what surfaces each plugin uses |
| `onboard/skills/generation/references/plugin-detection-guide.md` | The 18-plugin probe list and what each referenced plugin exercises |
| `.claude/audit-baseline.json` | Previous surface snapshot for diff detection |
| 10 WebFetch URLs (see below) | Live Anthropic documentation for current surfaces |

### WebFetch URLs

1. `https://docs.anthropic.com/en/docs/claude-code/overview`
2. `https://docs.anthropic.com/en/docs/claude-code/hooks`
3. `https://docs.anthropic.com/en/docs/claude-code/skills`
4. `https://docs.anthropic.com/en/docs/claude-code/sub-agents`
5. `https://docs.anthropic.com/en/docs/claude-code/mcp`
6. `https://docs.anthropic.com/en/docs/claude-code/plugins`
7. `https://docs.anthropic.com/en/docs/claude-code/settings`
8. `https://docs.anthropic.com/en/docs/claude-code/output-styles`
9. `https://docs.anthropic.com/en/docs/claude-code/headless`
10. `https://docs.anthropic.com/en/docs/claude-code/github-actions`

### Output: `.audit-data-<date>.json`

```json
{
  "meta": {
    "date": "<ISO-DATE>",
    "model": "claude-opus-4-6",
    "urlsFetched": ["<urls that succeeded>"],
    "urlsFailed": ["<urls that 404d or timed out>"]
  },
  "surfaces": {
    "hookEvents": ["<alphabetically sorted list>"],
    "hookTypes": ["agent", "command", "http", "prompt"],
    "skillFrontmatter": ["<alphabetically sorted list>"],
    "agentFrontmatter": ["<alphabetically sorted list>"],
    "mcpTransports": ["<alphabetically sorted list>"],
    "otherSurfaces": ["<alphabetically sorted list>"]
  },
  "localCoverage": {
    "onboard": {
      "hookEvents": ["<events this plugin handles or generates>"],
      "hookTypes": ["<types this plugin generates>"],
      "skillFrontmatter": ["<fields this plugin emits>"],
      "agentFrontmatter": ["<fields this plugin emits>"],
      "mcpTransports": ["<transports this plugin supports>"],
      "otherSurfaces": ["<other surfaces used>"]
    },
    "forge": { "...same structure..." },
    "notify": { "...same structure..." }
  },
  "probeList": {
    "plugins": [
      {
        "name": "<plugin-name>",
        "status": "active | possibly-deprecated",
        "surfacesUsed": ["<surfaces this plugin exercises>"]
      }
    ],
    "flagged": {
      "possiblyDeprecated": ["<plugin names>"],
      "newlyDiscovered": []
    }
  },
  "gaps": [
    {
      "id": "GAP-001",
      "surface": "<category.specific-item>",
      "affectedPlugin": "<onboard | forge | notify>",
      "priority": "P0 | P1 | P2",
      "size": "XS | S | M | L",
      "rationale": "<why this is a gap>",
      "baselineComparison": "new | existing | closed"
    }
  ],
  "baselineDiff": {
    "addedSurfaces": ["<surfaces found in live docs but not in baseline>"],
    "removedSurfaces": ["<surfaces in baseline but not in live docs>"],
    "unchanged": true
  }
}
```

### Analysis Rules

1. Read ALL local plugin files before WebFetching — builds context and reduces turns.
2. If a WebFetch URL 404s or times out, log it in `meta.urlsFailed` and continue. Never abort.
3. Compare live surfaces against `.claude/audit-baseline.json` to detect additions/removals.
4. For probe list plugins: flag "possibly-deprecated" only if the plugin's docs URL 404s or shows no recent activity.
5. Priority: P0 = generated tooling is visibly stale (core job broken), P1 = feature parity (ship-able, not blocking), P2 = polish/nice-to-have.
6. Size: XS = <1 hour, S = half-day, M = 1-2 days, L = 3+ days.
7. Sort all arrays alphabetically for deterministic, diffable output.
8. Write the JSON file atomically — complete the full analysis before writing to disk.

## Prompt Contract: Report Phase

File: `.claude/prompts/tooling-gap-audit-report.md`

### Objective

Read the structured JSON intermediary and render a strict-schema markdown report. Update the baseline snapshot if surfaces changed.

### Input

`docs/tooling-gap-reports/.audit-data-<date>.json` (from analysis phase)

### Output: `<date>-gap-report.md`

Exact section order:

```
# Tooling Gap Audit — <date>

## Summary
2-3 sentences: key findings, what changed since last run.

## Anthropic Surface Snapshot
| Category | Surfaces | Count | Source |
|---|---|---|---|
| Hook events | SessionStart, Stop, ... | 26 | [hooks docs](url) |
| Hook types | command, prompt, agent, http | 4 | [hooks docs](url) |
| Skill frontmatter | name, description, ... | 13 | [skills docs](url) |
| Agent frontmatter | tools, model, ... | 9 | [sub-agents docs](url) |
| MCP transports | stdio, sse, http | 3 | [mcp docs](url) |
| Other | output-styles, lsp, ... | N | [various](url) |

## Local Plugin Coverage
| Surface | onboard | forge | notify |
|---|---|---|---|
| Hook: SessionStart | Y | - | N |
Legend: Y = uses, N = gap (should use), - = N/A

## Referenced Plugin Patterns
| Plugin | Status | Surfaces exercised |
|---|---|---|
| superpowers | active | skills (12), agents (8), hooks (3) |

### Flagged
- Possibly deprecated: (list or "none")

## Gap List

### P0 — Core-job-critical
| ID | Gap | Plugin | Size | Rationale |
|---|---|---|---|---|

### P1 — Feature parity
| ID | Gap | Plugin | Size | Rationale |
|---|---|---|---|---|

### P2 — Polish
| ID | Gap | Plugin | Size | Rationale |
|---|---|---|---|---|

## Baseline Changes
- Added: (list or "none")
- Removed: (list or "none")
```

### Report Rules

1. Read `.audit-data-<date>.json` first. Do NOT re-fetch any URLs.
2. Follow the exact section order and table formats above.
3. If `baselineDiff.unchanged == true`, state "No surface changes since last run" in Summary and Baseline Changes.
4. Update `.claude/audit-baseline.json` if `addedSurfaces` or `removedSurfaces` is non-empty.
5. Sort all table rows alphabetically within sections for deterministic, diffable output.

## Baseline Snapshot

File: `.claude/audit-baseline.json`

Seeded manually on first commit with the current known surfaces (from the Part A research). Updated automatically by the report phase when surfaces change. Diffed by the analysis phase on each run.

```json
{
  "lastUpdated": "2026-04-16",
  "surfaces": {
    "hookEvents": [
      "ConfigChange", "CwdChanged", "Elicitation", "ElicitationResult",
      "FileChanged", "InstructionsLoaded", "Notification",
      "PermissionDenied", "PermissionRequest", "PostCompact",
      "PostToolUse", "PostToolUseFailure", "PreCompact", "PreToolUse",
      "SessionEnd", "SessionStart", "Stop", "StopFailure",
      "SubagentStart", "SubagentStop", "TaskCompleted", "TaskCreated",
      "TeammateIdle", "UserPromptSubmit", "WorktreeCreate", "WorktreeRemove"
    ],
    "hookTypes": ["agent", "command", "http", "prompt"],
    "skillFrontmatter": [
      "agent", "allowed-tools", "context", "description",
      "disable-model-invocation", "effort", "hooks", "model",
      "name", "paths", "shell", "user-invocable"
    ],
    "agentFrontmatter": [
      "background", "color", "disallowedTools", "effort",
      "isolation", "maxTurns", "model", "permissionMode", "tools"
    ],
    "mcpTransports": ["http", "sse", "stdio"],
    "otherSurfaces": [
      "headless-mode", "lsp-plugins", "output-styles",
      "plugin-settings", "status-line"
    ]
  }
}
```

## Shell Script: `open-gap-audit-pr.sh`

File: `.github/scripts/open-gap-audit-pr.sh`

### Behavior

1. Find today's report (`<date>-gap-report.md`) in `docs/tooling-gap-reports/`.
2. Find the most recent prior report (by filename sort, excluding today's).
3. If no prior report exists, open a PR (first-ever report).
4. Strip date-dependent lines (`^# Tooling Gap Audit — `) from both files.
5. Diff the stripped content. If identical, exit 0 silently.
6. If different, open PR against `develop` with title `chore(audit): tooling gap report <date>`.
7. PR body includes the Summary section extracted from the report.
8. Same-day collision: if `<date>-gap-report.md` already exists and differs, use `<date>-2-gap-report.md`.
9. Always exit 0 — never fail the workflow for PR-creation issues.

### Conventions

- `#!/usr/bin/env bash` + `set -euo pipefail` (utility script, not hook)
- ShellCheck-clean, POSIX-compatible
- Uses `gh pr create` with `GH_TOKEN` env var
- Uses `jq` for JSON if needed (installed on ubuntu-latest)

## Docs Landing Directory

```
docs/tooling-gap-reports/
  README.md         — one-page explainer (cadence, how to read, how to act)
  .gitkeep          — placeholder for first commit
```

README.md covers:
- What this directory contains
- Cadence: 1st and 15th of each month, 06:00 UTC
- How to read each report section
- How to act on a gap: create branch `feat/<plugin>-<what>`, implement, PR against develop, tick checkbox in `future-plans/tooling-gap-audit-and-automation.md`

## Files Created

| File | Purpose |
|---|---|
| `.claude/prompts/tooling-gap-audit-analyze.md` | Analysis prompt contract |
| `.claude/prompts/tooling-gap-audit-report.md` | Report rendering prompt contract |
| `.claude/audit-baseline.json` | Surface snapshot for diff detection |
| `.github/workflows/tooling-gap-audit.yml` | Cron + dispatch workflow |
| `.github/scripts/open-gap-audit-pr.sh` | Diff + PR logic |
| `docs/tooling-gap-reports/README.md` | Landing directory explainer |
| `docs/tooling-gap-reports/.gitkeep` | Directory placeholder |

No existing files modified. Entirely additive.

## Edge Cases

1. **WebFetch failure on all URLs**: Analysis still completes using local plugin data + baseline. Report marks all URLs as failed in Summary. Gaps are identified based on baseline only (no new surfaces detected).

2. **Max turns exceeded in analysis**: Phase 2 never starts. The workflow shows a failed step. No partial report written — the analysis JSON either exists (complete) or doesn't.

3. **Same-day double run**: The shell script detects an existing report for today and either: (a) skips if content is identical, or (b) writes with `-2` suffix if different. PR title includes the suffix.

4. **Baseline drift without a report**: If someone manually edits `audit-baseline.json`, the next analysis run will compare against the edited baseline. The diff will reflect the manual changes. This is intentional — manual baseline edits are a valid way to acknowledge known surfaces.

5. **New plugin added to repo**: The analysis reads all directories. If a 4th plugin appears, it's automatically included in `localCoverage`. No prompt contract change needed.

6. **Probe list plugin deprecated**: The analysis flags it in `probeList.flagged.possiblyDeprecated`. The report includes it in the Flagged subsection. No automatic removal — a human decides whether to update `plugin-detection-guide.md`.

## Verification

1. **Manual `workflow_dispatch`**: Trigger the workflow manually, confirm:
   - Analysis phase writes `.audit-data-<date>.json` with valid JSON
   - Report phase writes `<date>-gap-report.md` matching the strict schema
   - Baseline is updated if surfaces changed
   - Shell script opens PR against `develop` (first run = always opens)

2. **No-change cycle**: Re-run `workflow_dispatch` immediately. Confirm:
   - Analysis JSON is regenerated (may differ slightly in meta)
   - Report content is identical to previous (same gaps, same surfaces)
   - Shell script exits 0 silently, no new PR opened

3. **Cron observation**: After manual validation, let one cron cycle run (1st or 15th). Confirm it behaves identically to `workflow_dispatch`.

## Rollback

All files are new additions. Rollback = delete the branch / revert the merge commit. No existing behavior affected.
