# /onboard:status — Health Check

You are running the onboard status command. This provides a quick overview of the project's Claude tooling health.

---

## Step 1: Check for Setup

Read `.claude/onboard-meta.json`:

**If not found**:

> This project hasn't been set up with onboard yet.
>
> Run `/onboard:init` to analyze your codebase and generate Claude tooling.

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
> 1. **Re-initialize** — Run `/onboard:init` to start fresh with a new analysis and wizard
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

---

## Key Preferences Summary

Also display a quick reminder of the developer's preferences:

> **Your preferences** (from initial setup):
> - Autonomy: [level]
> - Testing: [philosophy]
> - Code style: [strictness]
> - Security: [sensitivity]
> - Team size: [size]
