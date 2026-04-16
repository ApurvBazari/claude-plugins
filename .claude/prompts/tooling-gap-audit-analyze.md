# Tooling Gap Audit — Analysis Phase

You are running a tooling gap analysis for the `claude-plugins` repository. This repo contains three Claude Code plugins — onboard (codebase analyzer + tooling generator), forge (project scaffolder), and notify (system notifications) — all built with markdown, shell scripts, and JSON (no compiled code).

Your job: compare what Anthropic currently ships in Claude Code against what these plugins actually generate. Produce a structured JSON intermediary that the report phase will render into a human-readable gap report.

## Step 1: Derive Today's Date

Run this command via Bash:

```bash
date -u +%Y-%m-%d
```

Store the result as `DATE`. Use it for all file path references below.

## Step 2: Read Local Plugin Files

Read ALL of the following before any WebFetch. Build a complete picture of what surfaces each plugin uses.

**Plugin directories** (read recursively — all SKILL.md, agents/*.md, scripts/*.sh, .claude-plugin/plugin.json, CLAUDE.md, CHANGELOG.md):
- `onboard/`
- `forge/`
- `notify/`

**Probe list** (the canonical list of referenced plugins and what they exercise):
- `onboard/skills/generation/references/plugin-detection-guide.md`

**Baseline snapshot** (previous known surfaces for diff detection):
- `.claude/audit-baseline.json`

For each plugin, identify:
- Which hook events it handles or generates
- Which hook types it supports (command, prompt, agent, http)
- Which skill frontmatter fields it emits
- Which agent frontmatter fields it emits
- Which MCP transports it supports
- Which other surfaces it uses (output styles, LSP, headless mode, etc.)

## Step 3: Fetch Live Anthropic Documentation

Fetch each URL below using WebFetch. Extract all Claude Code feature surfaces mentioned — hook events, hook types, frontmatter fields, MCP transports, settings, and any new capabilities.

If a URL returns a 404, times out, or fails for any reason: log it in `urlsFailed` and continue. Never abort the analysis because of a fetch failure.

1. `https://code.claude.com/docs/en/overview`
2. `https://code.claude.com/docs/en/hooks`
3. `https://code.claude.com/docs/en/skills`
4. `https://code.claude.com/docs/en/sub-agents`
5. `https://code.claude.com/docs/en/mcp`
6. `https://code.claude.com/docs/en/plugins`
7. `https://code.claude.com/docs/en/settings`
8. `https://code.claude.com/docs/en/output-styles`
9. `https://code.claude.com/docs/en/headless`
10. `https://code.claude.com/docs/en/github-actions`

## Step 4: Analyze

With all data collected, perform the gap analysis:

1. **Build the surfaces object**: compile all surfaces found in the live docs. Sort every array alphabetically.
2. **Build the localCoverage object**: for each plugin, list which surfaces it currently handles. Use empty arrays (not null) for surface categories a plugin doesn't touch.
3. **Build the probeList object**: for each plugin in the probe list, check whether it's still documented/active. Flag any that appear deprecated (docs URL 404s or shows no recent activity). Note: do NOT attempt to install or verify probe-list plugins — only assess their status from documentation.
4. **Identify gaps**: for each surface in the Anthropic snapshot that a local plugin should handle but doesn't, create a gap entry.
5. **Compute baselineDiff**: compare the live surfaces against `.claude/audit-baseline.json`. Identify surfaces added (in live docs but not in baseline) and removed (in baseline but not in live docs). Set `unchanged: true` only if both addedSurfaces and removedSurfaces are empty.

### Priority Classification

- **P0** — Generated tooling is visibly stale or broken for this surface. The plugin's core job is degraded.
- **P1** — Feature parity gap. The plugin works but misses a shipped capability that users would expect.
- **P2** — Polish or nice-to-have. Low user-facing impact.

### Size Classification

- **XS** — Less than 1 hour of implementation work
- **S** — Half-day of work
- **M** — 1-2 days of work
- **L** — 3+ days of work

## Step 5: Write the JSON Intermediary

Write the complete JSON to this path:

```
docs/tooling-gap-reports/.audit-data-<DATE>.json
```

Use the Write tool. The JSON must be valid and complete before writing — do not write partial results.

### Output Schema

```json
{
  "meta": {
    "date": "<YYYY-MM-DD>",
    "model": "<model used for this analysis>",
    "urlsFetched": ["<URLs that returned successfully>"],
    "urlsFailed": ["<URLs that 404d, timed out, or failed>"]
  },
  "surfaces": {
    "hookEvents": ["<alphabetically sorted list of all hook events>"],
    "hookTypes": ["<alphabetically sorted list of all hook types>"],
    "skillFrontmatter": ["<alphabetically sorted list of all skill frontmatter fields>"],
    "agentFrontmatter": ["<alphabetically sorted list of all agent frontmatter fields>"],
    "mcpTransports": ["<alphabetically sorted list of all MCP transports>"],
    "otherSurfaces": ["<alphabetically sorted list of other surfaces>"]
  },
  "localCoverage": {
    "onboard": {
      "hookEvents": [],
      "hookTypes": [],
      "skillFrontmatter": [],
      "agentFrontmatter": [],
      "mcpTransports": [],
      "otherSurfaces": []
    },
    "forge": {
      "hookEvents": [],
      "hookTypes": [],
      "skillFrontmatter": [],
      "agentFrontmatter": [],
      "mcpTransports": [],
      "otherSurfaces": []
    },
    "notify": {
      "hookEvents": [],
      "hookTypes": [],
      "skillFrontmatter": [],
      "agentFrontmatter": [],
      "mcpTransports": [],
      "otherSurfaces": []
    }
  },
  "probeList": {
    "plugins": [
      {
        "name": "<plugin-name>",
        "status": "active | possibly-deprecated",
        "surfacesUsed": ["<list of surfaces this plugin exercises>"]
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
      "rationale": "<why this is a gap and what's affected>",
      "baselineComparison": "new | existing | closed"
    }
  ],
  "baselineDiff": {
    "addedSurfaces": ["<surfaces in live docs but not in baseline>"],
    "removedSurfaces": ["<surfaces in baseline but not in live docs>"],
    "unchanged": false
  }
}
```

## Rules

1. Read ALL local plugin files before any WebFetch. This builds context and reduces turns.
2. If a WebFetch URL fails, log it and continue. Never abort.
3. Sort all arrays alphabetically for deterministic, diffable output.
4. Use empty arrays for missing categories, never null.
5. Gap IDs are sequential: GAP-001, GAP-002, etc.
6. `baselineComparison` for each gap: "new" if the surface was just added to Anthropic docs, "existing" if it was already in the baseline, "closed" if a previously-gapped surface is now covered.
7. If ALL WebFetch URLs fail, produce the JSON using baseline data only. Set `baselineDiff.unchanged: true` (conservative assumption when live data is unavailable).
8. Write the JSON file atomically — complete the full analysis before writing. Do not write partial results.
