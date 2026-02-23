# /claude-onboard:update — Evolve Tooling to Latest Best Practices

You are running the claude-onboard update command. This checks whether the project's Claude tooling is aligned with the latest best practices and offers targeted upgrades.

This is NOT a snapshot diff. It's a forward-looking check against current best practices.

---

## Prerequisites Check

### Step 1: Verify Previous Setup

Check for `.claude/onboard-meta.json`:

```
Read: .claude/onboard-meta.json
```

**If not found**:

> This project hasn't been set up with claude-onboard yet. Run `/claude-onboard:init` first to generate your Claude tooling.

Stop here.

**If found**, parse and display:

> Last claude-onboard run:
> - **Date**: [lastRun]
> - **Plugin version**: [pluginVersion]
> - **Artifacts generated**: [count]
> - **Model**: [modelRecommendation]

---

## Analysis Phase

### Step 2: Read All Existing Artifacts

Read every file listed in `onboard-meta.json`'s `generatedArtifacts` array. For each:
- Check if file still exists
- Check if maintenance header is intact (indicates no manual override)
- If maintenance header is missing or modified, flag as "user-customized" — extra caution needed

Also read any Claude config files that may have been added manually after the initial run.

### Step 3: Re-analyze the Codebase

Run a fresh analysis (same as init Phase 1):
- Run the three analysis scripts
- Perform deep codebase exploration

Compare the fresh analysis against what was captured in onboard-meta.json to detect drift:
- New languages or frameworks added?
- Dependencies added or removed?
- Project structure changed?
- New CI/CD pipelines?
- Test setup changed?

### Step 4: Check Latest Best Practices

Check two knowledge sources:

**Plugin knowledge** (built-in):
- Review the generation skill's reference guides for any patterns the existing artifacts don't follow
- Check if the existing artifacts use deprecated patterns

**Live web fetch** (latest):
- Fetch the latest Claude Code documentation for any new features or changed best practices
- Check for new Claude Code capabilities that the existing setup doesn't leverage

**Web fetch failure fallback**: If the web fetch fails (network error, timeout, or content unavailable):
- Use the built-in reference guides only (claude-md-guide.md, rules-guide.md, hooks-guide.md, skills-guide.md, agents-guide.md)
- Note in the findings output: "Live best practices check unavailable — recommendations based on built-in reference guides only"
- Continue the update process normally with plugin knowledge alone

---

## Findings Report

### Step 5: Present Findings

Organize findings into categories:

> **Update Report for [project name]**
>
> ### Codebase Changes Detected
> - [List changes since last run: new deps, structure changes, etc.]
>
> ### Best Practice Gaps
> - [Patterns in existing artifacts that could be improved]
> - [New Claude Code features not yet leveraged]
>
> ### New Artifacts Recommended
> - [New rules, skills, or agents that would be valuable based on codebase changes]
>
> ### Deprecated Patterns
> - [Anything in current setup that's outdated]
>
> ### Health Status
> - [Files still intact vs. missing]
> - [User-customized files (maintenance header removed/changed)]

---

## Upgrade Offers

### Step 6: Offer Targeted Upgrades

For each finding, offer a specific action:

> I can make the following updates:
>
> 1. **Update CLAUDE.md** — Add new commands discovered, update tech stack section
> 2. **Add .claude/rules/security.md** — Your project now has auth code that wasn't there before
> 3. **Update .claude/skills/react-component/SKILL.md** — New patterns detected in recent components
> 4. **[etc.]**
>
> Which updates would you like me to apply? (all / specific numbers / none)

### User-Customized Files

For files where the maintenance header was modified or removed:

> ⚠ These files appear to have manual customizations:
> - `CLAUDE.md` — Manual edits detected
> - `.claude/rules/testing.md` — Maintenance header removed
>
> I can:
> - **Merge** — Add new content while preserving your changes
> - **Replace** — Overwrite with fresh generation (your changes will be lost)
> - **Skip** — Leave these files as-is
>
> What would you prefer for each?

---

## Apply Updates

### Step 7: Execute Chosen Updates

For each approved update:
1. Read the existing file
2. Apply changes (merge or replace based on user choice)
3. Ensure maintenance header is present on all updated files
4. Update the date in maintenance headers

### Step 8: Update Metadata

Update `.claude/onboard-meta.json`:
- Update `lastRun` timestamp
- Update `pluginVersion`
- Update `generatedArtifacts` list (add any new files)
- Preserve `wizardAnswers` (don't re-ask wizard questions during update)
- Add an `updateHistory` array entry:

```json
{
  "updateHistory": [
    {
      "date": "2026-02-22T10:00:00Z",
      "pluginVersion": "0.1.0",
      "changes": ["Updated CLAUDE.md", "Added security rules", "Updated component skill"]
    }
  ]
}
```

---

## Completion

### Step 9: Summary

> Update complete! Changes applied:
> - [List each change made]
>
> Files unchanged:
> - [List files that were up-to-date or skipped]
>
> Run `/claude-onboard:status` to verify the health of your setup.
