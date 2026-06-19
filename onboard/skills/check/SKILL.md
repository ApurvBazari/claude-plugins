---
name: check
description: Health check for Claude tooling setup. Use when user asks about the state of their `.claude/` configuration, artifact drift, whether onboard-generated files are still intact, or wants a summary of what `/onboard:start` produced. Read-only — safe to auto-invoke.
---

# Check Skill — Health Check

You are running the onboard status skill. This provides a quick overview of the project's Claude tooling health.

---

## Step 1: Check for Setup

Read `.claude/onboard-meta.json`:

**If not found**:

> This project hasn't been set up with onboard yet — there's no `onboard-meta.json` baseline to health-check.
>
> - **No Claude tooling yet?** Run `/onboard:start` to analyze your codebase and generate it.
> - **Already have hand-crafted tooling** (foreign — not onboard-managed: a root `CLAUDE.md`, `.claude/` rules/skills/agents/output-styles, `.mcp.json`, or hooks in `.claude/settings.json`)? Run `/onboard:adopt` to bring it under management — adopt synthesizes the baseline and never modifies your files. Then `/onboard:check` and `/onboard:update` will work against it.

Stop here.

---

## Step 2: Parse Metadata

Extract from `onboard-meta.json`:
- `pluginVersion` — Version used for generation
- `lastRun` — When the setup was last run/updated
- `wizardAnswers` — Key preferences
- `generatedArtifacts` — List of generated files
- `modelRecommendation` — Recommended model
- `modelApprovedByUser` — Whether the developer approved
- `updateHistory` — Previous updates (if any)

### JSON Parse Error Handling

If `onboard-meta.json` cannot be parsed (corrupted, malformed JSON, or unreadable):

> The metadata file `.claude/onboard-meta.json` appears to be corrupted and couldn't be parsed.
>
> You can:
> 1. **Re-initialize** — Run `/onboard:start` to start fresh with a new analysis and wizard
> 2. **Continue without metadata** — I'll check artifact integrity only (file existence and headers), but skip drift detection and preference display

Wait for the developer's choice before proceeding. If they choose option 2, skip Steps 4 and 6 (drift check and preferences summary) and note the limitation in the status report.

---

## Step 3: Check Artifact Integrity

For each file in `generatedArtifacts`:

1. **Check existence** — Does the file still exist?
2. **Check maintenance header** — Is the header intact? This indicates the file hasn't been manually overridden.
3. **Check for emptiness** — Is the file non-empty?

Classify each file:
- **Intact** — Exists with maintenance header
- **Customized** — Exists but maintenance header is modified/removed (user edited it)
- **Missing** — File no longer exists
- **Empty** — File exists but is empty

---

## Step 4: Quick Drift Check

Do a lightweight check for drift against the state captured in `onboard-meta.json`. Use these concrete thresholds:

- **Dependency drift**: 3+ new dependencies added to package.json / requirements.txt / go.mod since last run
- **Structural drift**: New top-level directory created that didn't exist at last run
- **Test drift**: Test file count changed by >20% (up or down) since last run
- **CI drift**: New CI/CD pipeline file added (e.g., new GitHub Actions workflow)
- **Framework drift**: Major framework version bump detected (e.g., Next.js 14 → 15)
- **Config drift**: `.claude/settings.json` has been modified outside of onboard
- **Manual CLAUDE.md**: New CLAUDE.md files were added manually

**"Significant drift"** = 2 or more of the above detected simultaneously.

### Research staleness (read-only)

Map the drift signals above to the research dimensions they invalidate, per `../update/references/re-research.md` § Detection (drift→dimension map + depth-cap intersection against `onboard-meta.json.research.depth`). This is **read-only** — `check` never re-researches. If the intersected set is non-empty, list the stale dimensions and recommend a re-ground; if the drift would escalate to full (≥3 dims / framework bump / ≥2 new modules), say so.

**Always confirm** drift findings with the developer before recommending action — false positives are possible.

---

## Step 5: Present Status Report

```
╔══════════════════════════════════════════╗
║        onboard Status             ║
╠══════════════════════════════════════════╣
║ Plugin version:  [version]               ║
║ Last run:        [date] ([X days ago])   ║
║ Model:           [model] (approved: Y/N) ║
╠══════════════════════════════════════════╣
║ Artifacts: [total] generated             ║
║   ✓ Intact:      [count]                 ║
║   ✎ Customized:  [count]                 ║
║   ✗ Missing:     [count]                 ║
╠══════════════════════════════════════════╣
║ Health: [HEALTHY / NEEDS ATTENTION]      ║
╚══════════════════════════════════════════╝
```

### Detailed File Status

```
File                                    Status
─────────────────────────────────────────────
CLAUDE.md                               ✓ Intact
src/components/CLAUDE.md                ✎ Customized
.claude/rules/testing.md                ✓ Intact
.claude/rules/api.md                    ✗ Missing
.claude/skills/react-component/SKILL.md ✓ Intact
.claude/agents/code-reviewer.md         ✓ Intact
.claude/settings.json                   ✓ Intact
.claude/onboard-meta.json               ✓ Intact
```

---

## Step 6: Recommendations

Based on the status, provide targeted recommendations:

### If everything is healthy:

> Your Claude tooling is in good shape. No action needed.
>
> Consider running `/onboard:update` periodically to check against latest best practices.

### If files are missing:

> [count] generated files are missing. This may affect Claude's ability to follow your project conventions.
>
> Run `/onboard:update` to regenerate missing files, or recreate them manually.

### If many files are customized:

> [count] files have been customized. This is fine — your manual edits are preserved. Just be aware that `/onboard:update` will ask before modifying these files.

### If it's been a long time since last run:

> Your setup was last updated [X days/weeks/months ago]. Claude Code evolves quickly — consider running `/onboard:update` to check for new best practices and features.

### If drift is detected:

> I noticed some changes in your project since the last setup:
> - [new dependencies, new directories, etc.]
>
> Run `/onboard:update` to incorporate these changes into your Claude tooling.

### If research looks stale (dimensions invalidated):

> Recent changes may have invalidated the research dossier in: [list stale dimensions].
>
> Run `/onboard:update` to re-ground research and refresh the affected tooling (you'll approve the re-research first), or `/onboard:evolve` for a scoped auto-refresh. [If escalation would fire:] This looks like broad drift — prefer `/onboard:update` (a full re-research).

---

## Key Preferences Summary

Also display a quick reminder of the developer's preferences:

> **Your preferences** (from initial setup):
> - Autonomy: [level]
> - Testing: [philosophy]
> - Code style: [strictness]
> - Security: [sensitivity]
> - Team size: [size]

## Key Rules

- **Never write to any file** — this skill is fully read-only. All Steps are observation and reporting; no files are created, modified, or deleted.
- **Halt at Step 1 if `onboard-meta.json` is missing** — do not continue to artifact checks or drift detection without a metadata baseline. The user must run `/onboard:start` first (or `/onboard:adopt` if they have existing hand-crafted tooling to bring under management).
- **Parse error requires explicit user choice** — if `onboard-meta.json` is malformed, surface the two options (re-initialize or metadata-free check) via `AskUserQuestion` and wait. Never silently skip drift detection.
- **Drift findings are always confirmed before acting** — the check reports drift; it never auto-applies or recommends immediate edits. Direct the user to `/onboard:update` for any changes.
- **Drift thresholds are concrete, not vague** — use the exact numeric thresholds defined in Step 4 (3+ new deps, >20% test file delta, major version bump, etc.). Do not flag drift on noise below these thresholds.
