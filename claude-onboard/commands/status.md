# /claude-onboard:status — Health Check

You are running the claude-onboard status command. This provides a quick overview of the project's Claude tooling health.

---

## Step 1: Check for Setup

Read `.claude/onboard-meta.json`:

**If not found**:

> This project hasn't been set up with claude-onboard yet.
>
> Run `/claude-onboard:init` to analyze your codebase and generate Claude tooling.

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

Do a lightweight check for obvious drift (don't run full analysis):

- Check if `package.json` dependencies have changed significantly since last run
- Check if new major directories have been created
- Check if new CLAUDE.md files were added manually
- Check if `.claude/settings.json` has been modified outside of onboard

---

## Step 5: Present Status Report

```
╔══════════════════════════════════════════╗
║        claude-onboard Status             ║
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
> Consider running `/claude-onboard:update` periodically to check against latest best practices.

### If files are missing:

> [count] generated files are missing. This may affect Claude's ability to follow your project conventions.
>
> Run `/claude-onboard:update` to regenerate missing files, or recreate them manually.

### If many files are customized:

> [count] files have been customized. This is fine — your manual edits are preserved. Just be aware that `/claude-onboard:update` will ask before modifying these files.

### If it's been a long time since last run:

> Your setup was last updated [X days/weeks/months ago]. Claude Code evolves quickly — consider running `/claude-onboard:update` to check for new best practices and features.

### If drift is detected:

> I noticed some changes in your project since the last setup:
> - [new dependencies, new directories, etc.]
>
> Run `/claude-onboard:update` to incorporate these changes into your Claude tooling.

---

## Key Preferences Summary

Also display a quick reminder of the developer's preferences:

> **Your preferences** (from initial setup):
> - Autonomy: [level]
> - Testing: [philosophy]
> - Code style: [strictness]
> - Security: [sensitivity]
> - Team size: [size]
