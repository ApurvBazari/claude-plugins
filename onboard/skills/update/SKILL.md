---
name: update
description: Update existing Claude tooling against latest best practices — re-analyzes the codebase, fetches current Claude Code documentation, presents targeted upgrade options, and applies approved changes with merge/replace choice per file. Use only when user explicitly invokes /onboard:update.
disable-model-invocation: true
---

# Update Skill — Evolve Tooling to Latest Best Practices

You are running the onboard update skill. This checks whether the project's Claude tooling is aligned with the latest best practices and offers targeted upgrades.

This is NOT a snapshot diff. It's a forward-looking check against current best practices.

---

## Prerequisites Check

### Step 1: Verify Previous Setup

Check for `.claude/onboard-meta.json`:

```
Read: .claude/onboard-meta.json
```

**If not found**:

> This project hasn't been set up with onboard yet. Run `/onboard:start` first to generate your Claude tooling.

Stop here.

**If found**, parse and display:

> Last onboard run:
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
- Fetch the official Claude Code documentation at `https://code.claude.com/docs/en` using WebFetch to check for new features or changed best practices
- Also check `https://code.claude.com/docs/en/settings` for settings and hooks updates
- Compare fetched documentation against the existing setup to identify new capabilities not yet leveraged

**Web fetch failure fallback**: If the web fetch fails (network error, timeout, or content unavailable):
- Use the built-in reference guides only (claude-md-guide.md, rules-guide.md, hooks-guide.md, skills-guide.md, agents-guide.md)
- Note in the findings output: "Live best practices check unavailable — recommendations based on built-in reference guides only"
- Continue the update process normally with plugin knowledge alone

### Step 4b: Tooling Drift Detection

Detect three classes of drift that the preceding steps don't cover. Each class feeds new sections into the findings report (Step 5).

Apply the full read-inputs, classify, and record procedure for each detector — verbatim from `references/drift-classification.md`. Each section there is authoritative; do not paraphrase the classification rules or field semantics.

#### 4b.1: Plugin Drift
Follow `references/drift-classification.md` § 4b.1. Record `driftReport.added`, `driftReport.removed`, and the derived `qualityGatesNext` / `phaseSkillsNext` / `coveredCapabilitiesNext` for Step 7.

#### 4b.2: Artifact Gaps
Follow `references/drift-classification.md` § 4b.2. Record gap candidates (missing, not `deletedByUser`) for Step 7.

#### 4b.3: New Best-Practice Additions
Follow `references/drift-classification.md` § 4b.3. Surface only items that match stack/complexity, are absent from `generatedArtifacts`, and are absent from disk under `.claude/`.

#### 4b.4: MCP Drift
Follow `references/drift-classification.md` § 4b.4. Record as `mcpDrift.{userEdited, userRemoved, newlySuggested, staleCandidate}[]` for Step 7.

#### 4b.5: Skill Frontmatter Drift
Follow `references/drift-classification.md` § 4b.5. Record as `skillDrift.{userEdited, missingFiles, newFieldCandidates}[]` for Step 7.

#### 4b.6: Agent Frontmatter Drift
Follow `references/drift-classification.md` § 4b.6. Record as `agentDrift.{userEdited, missingFiles, newFieldCandidates, legacyNoFrontmatter}[]` for Step 7.

#### 4b.7: Output Style Drift
Follow `references/drift-classification.md` § 4b.7. Record as `outputStyleDrift.{userEdited, missingFiles, newFieldCandidates, legacyNoFrontmatter}[]` for Step 7.

#### 4b.8: LSP Plugin Drift
Follow `references/drift-classification.md` § 4b.8. Record as `lspDrift.{newLanguages, uninstalled, staleCandidates}[]` for Step 7.

#### 4b.9: Built-in Skills Drift
Follow `references/drift-classification.md` § 4b.9. Record as `builtInSkillsDrift.{newSkills, newlyRelevant, staleCandidates}[]` for Step 7.

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
> ### Enriched Capabilities Check
> - **CI/CD Pipelines**: [present and current / outdated / missing — offer to generate]
> - **Harness Artifacts**: [present and healthy / stale progress file / missing — offer to generate]
> - **Evolution Hooks**: [present / missing — offer to add drift detection]
> - **Sprint Contracts**: [active sprint / no contracts — offer to create]
> - **Feature Verification**: [evaluator available / not set up — offer to enable]
> - **Agent Teams**: [configured / not applicable]
>
> ### Plugin Drift (from Step 4b.1)
> _Baseline source: [onboard-meta / none]_
> - **Newly installed since baseline**: [plugin names, or "none"]
> - **Removed since baseline**: [plugin names, or "none"]
> - Impact: refresh Plugin Integration section in CLAUDE.md, add/remove quality-gate hook scripts, update `phaseSkills`.
>
> ### Artifact Gaps (from Step 4b.2)
> - [List each generatedArtifacts entry that is missing from disk and not marked `deletedByUser`]
> - Impact: offer to regenerate via `onboard:generate`.
>
> ### New Best-Practice Additions (from Step 4b.3)
> - [List recommended artifacts from the built-in reference guides that this project doesn't have yet]
> - Impact: create the artifact with a maintenance header.
>
> ### MCP Drift (from Step 4b.4)
> - **Newly suggested** (signal now fires): [list or "none"]
> - **Stale candidates** (signal no longer fires): [list or "none"]
> - **User edits detected**: [list or "none"] — informational only; onboard never rewrites your `.mcp.json`
> - **User removals detected**: [list or "none"] — informational only
> - Impact: additions can be applied on approval; removals require explicit user instruction.
>
> ### Skill Frontmatter Drift (from Step 4b.5)
> - **User edits detected**: [skill:field pairs or "none"] — informational only; onboard never rewrites hand-edited frontmatter
> - **Missing files**: [list or "none"] — tracked skills absent from disk (regenerate via `onboard:generate`)
> - **New field candidates**: [list or "none"] — fields the current archetype table would emit that the snapshot omits
> - Impact: missing-file regeneration and new-field additions can be applied on approval; user-edits are preserved.
>
> ### Agent Frontmatter Drift (from Step 4b.6)
> - **User edits detected**: [agent:field pairs or "none"] — informational only; onboard never rewrites hand-edited frontmatter
> - **Missing files**: [list or "none"] — tracked agents absent from disk (regenerate via `onboard:generate`)
> - **New field candidates**: [list or "none"] — fields the current archetype table would emit that the snapshot omits
> - **Legacy agents (no YAML frontmatter)**: [list or "none"] — pre-1.6.0 agents using markdown-sections format. Migration adds archetype-inferred frontmatter.
> - Impact: missing-file regeneration, new-field additions, and legacy migration can be applied on approval; user-edits are preserved.
>
> ### Output Style Drift (from Step 4b.7)
> - **User edits detected**: [style:field pairs or "none"] — informational only; onboard never rewrites hand-edited frontmatter. Body edits are outside snapshot scope and never flagged.
> - **Missing files**: [list or "none"] — tracked styles absent from disk (regenerate via `onboard:generate` with `disableOutputStyleTuning: true`)
> - **New field candidates**: [list or "none"] — fields the current generator would emit that the snapshot omits
> - **Legacy styles (no YAML frontmatter)**: [list or "none"] — styles hand-authored without frontmatter. Migration adds archetype-inferred frontmatter using catalog defaults.
> - Impact: missing-file regeneration, new-field additions, and legacy migration can be applied on approval; user-edits and body prose are preserved.
>
> ### LSP Plugin Drift (from Step 4b.8)
> - **New languages detected**: [list or "none"] — languages added to the project since last onboard/evolve run. Each comes with the matching marketplace plugin.
> - **Uninstalled by developer**: [list or "none"] — previously-accepted LSP plugins that are no longer installed. Informational only; onboard never auto-reinstalls.
> - **Stale candidates**: [list or "none"] — languages no longer present in the project. Informational only.
> - Impact: newLanguages can be offered for install on approval; uninstalls and stale candidates are informational.
>
> ### Built-in Skills Drift (from Step 4b.9)
> - **New skills detected**: [list or "none"] — built-in skills newly relevant to the project (e.g., `/claude-api` after adding `@anthropic-ai/sdk`).
> - **Newly relevant**: [list or "none"] — previously declined skills with stronger signals now. Informational only; offered as a suggestion.
> - **Stale candidates**: [list or "none"] — skills whose detection signals no longer fire. Informational only.
> - Impact: new skills can be added to CLAUDE.md on approval.
>
> ### Deprecated Patterns
> - [Anything in current setup that's outdated]
>
> ### Health Status
> - [Files still intact vs. missing]
> - [User-customized files (maintenance header removed/changed)]

---

## Upgrade Offers

### Step 6: Offer Targeted Upgrades (AskUserQuestion)

Accumulate every detected drift item into a list of offer-objects. Do **not** number them manually — they get rendered as `AskUserQuestion` options programmatically. Each offer has:

```jsonc
{
  "id": "regenerate-security-rule",   // stable id, used in pending-updates snapshot
  "label": "Regenerate .claude/rules/security.md",
  "description": "File was listed in generatedArtifacts but is missing from disk",
  "group": "artifact-gaps",            // see grouping below
  "autoChecked": false                  // true for new-language LSP / built-in skills, see below
}
```

Group offers into these categories (each becomes one `multiSelect: true` question inside the AskUserQuestion call):

| Group | What goes here |
|---|---|
| `artifact-gaps` | Files in `generatedArtifacts` missing from disk; user-customized files that need merge/replace decision |
| `user-edit-detections` | Files where the maintenance header was modified or other edits detected |
| `new-dependencies-or-languages` | New dep additions (e.g., `@anthropic-ai/sdk`), new languages (Rust → `rust-analyzer-lsp`), built-in skills newly relevant. **LSP plugins for newly detected languages are `autoChecked: true` by default**, matching wizard Phase 5.6 pre-check behavior. |
| `best-practice-suggestions` | Reference guide recommendations (e.g., `observability.md` rule for the detected stack) |
| `enriched-capabilities` | CI/CD, harness, evolution, sprint contracts, verification |
| `plugin-drift` | Wire-in / remove offers from Step 4b.1 |

### Combined AskUserQuestion call

Issue a **single AskUserQuestion call** containing the pre-question + up to 3 offer-group multi-select questions (4 max per call). If there are more than 3 active groups, fold the lowest-priority groups into a second AskUserQuestion call within the same exchange.

**Question 1 — Pre-question** (single-select, header: `"Approach"`):

| Label | Effect |
|---|---|
| `Review and pick` | Default. Proceed to per-group multiSelect questions in this same call. |
| `Apply all` | Skip per-group selection, apply every offer accumulated. |
| `Apply later` | Write `.claude/onboard-pending-updates.json` snapshot of all offers (with their `id` and metadata) and exit. The next `/onboard:update` re-presents pending items + any newly detected drift. |
| `Skip / dismiss` | Discard offers, do not remind again this session. (Re-running `/onboard:update` re-detects from scratch.) |

**Questions 2–4 — Offer-group multi-selects** (each `multiSelect: true`, headers: `"ArtifactGaps"`, `"UserEdits"`, `"NewDeps"`, etc. — pick the 3 most populous groups for the first call). Only render groups that have ≥1 offer; skip empty groups.

For each option, set the `description` to the offer's `description` field. Mark `autoChecked: true` offers (e.g., new-language LSP) as pre-selected so the developer just clicks Submit unless they want to opt out.

**Single-option guard** (per `.claude/rules/ask-user-question-guard.md`): when a group has exactly 1 offer, **pad that group** with an explicit `None / Skip` option (label: `"None / Skip"`, description: `"Do not apply anything from this group"`). This keeps the batched single-call envelope intact. Do NOT fall back to sequential single-select calls — that breaks the M2 contract (one AskUserQuestion per update exchange) and was the failure mode observed in release-gate finding F1 (2026-04-17). When the user selects `None / Skip` in a padded group, treat it as empty-array-equivalent: skip every offer in that group, do not apply, and record `status: "declined", reason: "user-skipped-padded-group"` in `updateHistory`.

### "Apply later" snapshot — `.claude/onboard-pending-updates.json`

Written when the developer picks "Apply later" in the pre-question:

```jsonc
{
  "savedAt": "2026-04-17T14:32:00Z",
  "pendingOffers": [
    {
      "id": "regenerate-security-rule",
      "label": "Regenerate .claude/rules/security.md",
      "description": "File was listed in generatedArtifacts but is missing from disk",
      "group": "artifact-gaps",
      "autoChecked": false
    }
    // ... one entry per offer
  ]
}
```

Next `/onboard:update`:
1. If `.claude/onboard-pending-updates.json` exists, read it. Re-validate each offer against current state (e.g., the missing file may have been restored manually).
2. Merge still-applicable pending offers into the freshly detected drift list. Dedupe by `id`.
3. Present the combined list via the same Step 6 AskUserQuestion call.
4. After "Apply all" or per-group selection lands, delete `.claude/onboard-pending-updates.json` (snapshot has served its purpose).

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

**Merge strategy for CLAUDE.md and markdown artifacts:**
- **User-added sections** — preserve in place, do not modify or reorder
- **Generated sections** (identified by maintenance header) — update content in-place, keep same position
- **New sections** — append after the last generated section, before any user-added trailing sections
- **Deleted sections** — do not re-add sections the user explicitly removed (check onboard-meta.json for previously generated sections)

Apply the full application procedure for each approved drift type — verbatim from `references/drift-application.md`. Each section there is authoritative; do not paraphrase the step-by-step instructions, guard rules, or snapshot update contracts.

- **Plugin drift** (4b.1): Follow `references/drift-application.md` § Plugin drift application (additions, removals, subdirectory skill-annotation refresh, standalone ↔ plugin reconciliation — including pre-item-approval guard before any deletion).
- **MCP drift** (4b.4): Follow `references/drift-application.md` § MCP drift application.
- **Skill frontmatter drift** (4b.5): Follow `references/drift-application.md` § Skill frontmatter drift application.
- **Agent frontmatter drift** (4b.6): Follow `references/drift-application.md` § Agent frontmatter drift application.
- **Output style drift** (4b.7): Follow `references/drift-application.md` § Output style drift application.
- **LSP plugin drift** (4b.8): Follow `references/drift-application.md` § LSP plugin drift application.
- **Built-in skills drift** (4b.9): Follow `references/drift-application.md` § Built-in skills drift application (including placement migration).
- **Artifact gap regeneration** (4b.2): Follow `references/drift-application.md` § Artifact gap regeneration.
- **New best-practice additions** (4b.3): Follow `references/drift-application.md` § New best-practice additions.

### Step 8: Update Metadata

Update `.claude/onboard-meta.json`:
- Update `lastRun` timestamp
- Update `pluginVersion`
- Update `generatedArtifacts` list (add any new files, drop any whose deletion was explicitly approved)
- Preserve `wizardAnswers` (don't re-ask wizard questions during update)
- **If plugin drift was applied in Step 7** — refresh `detectedPlugins.installedPlugins` to `driftReport.currentPlugins`, and recompute `detectedPlugins.coveredCapabilities`, `detectedPlugins.qualityGates`, `detectedPlugins.phaseSkills` per `../generation/references/plugin-detection-guide.md`. Update the top-level `hookStatus` to reflect added/removed hook scripts.
- **If MCP drift was applied in Step 7** — refresh top-level `mcpStatus`: add newly-applied servers to `mcpStatus.generated[]`, drop removed servers. Re-run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh"` for any newly-applied server with a `plugin` field; merge results into `mcpStatus.autoInstalled[]` and `mcpStatus.autoInstallFailed[]`. Always keep `mcpStatus.existedPreOnboard` sticky — once true, it stays true for the life of the project.
- **If skill frontmatter drift was applied in Step 7** — refresh top-level `skillStatus.frontmatterFields[<skill>]` to match the applied state, including the refreshed `source` value (`user-confirmed` / `user-tweaked`). Update `.claude/onboard-skill-snapshot.json` to reflect the new baseline. Keep `skillStatus.existedPreOnboard[]` sticky.
- **If agent frontmatter drift was applied in Step 7** — refresh top-level `agentStatus.frontmatterFields[<agent>]` to match the applied state, including the refreshed `source` value (`user-confirmed` / `user-tweaked` / `wizard-default` for legacy migrations). Update `.claude/onboard-agent-snapshot.json` to reflect the new baseline. Keep `agentStatus.existedPreOnboard[]` sticky. Append `legacy-skipped:<agent>` entries to `agentStatus.warnings` for any `legacyNoFrontmatter` declined by the developer.
- **If output style drift was applied in Step 7** — refresh top-level `outputStyleStatus.frontmatterFields[<style>]` to match the applied state, including the refreshed `source` value (`user-confirmed` / `user-tweaked` / `wizard-default` for legacy migrations). Update `.claude/onboard-output-style-snapshot.json` to reflect the new baseline. Keep `outputStyleStatus.existedPreOnboard[]` sticky. Append `legacy-skipped:<style>` or `legacy-no-archetype-match:<style>` entries to `outputStyleStatus.warnings` for any `legacyNoFrontmatter` declined or unclassifiable. Preserve `outputStyleStatus.activationDefault`, `settingsLocalWritten`, and `settingsLocalWarning` from the prior state — `update` does NOT touch settings.local.json.
- **If LSP drift was applied in Step 7** — refresh top-level `lspStatus`: append newly-installed plugins to `lspStatus.accepted[]` and `lspStatus.generated[]`, merge install-script results into `lspStatus.autoInstalled[]` and `lspStatus.autoInstallFailed[]`. Update `.claude/onboard-lsp-snapshot.json` (both `recommended` and `accepted`) to reflect the new baseline. `lspStatus.skipped[]` is preserved from prior runs — never rewritten during update.
- **If built-in skills drift was applied in Step 7** — refresh top-level `builtInSkillsStatus`: append newly-accepted skills to `builtInSkillsStatus.generated[]`, update `detectionSignals` for new entries. Update `.claude/onboard-builtin-skills-snapshot.json` (both `recommended` and `accepted`) to reflect the new baseline, preserving alphabetical sort. `builtInSkillsStatus.skipped[]` is preserved from prior runs — never rewritten during update.
- Add an `updateHistory` array entry:

```json
{
  "updateHistory": [
    {
      "date": "2026-04-15T10:00:00Z",
      "pluginVersion": "1.2.0",
      "changes": ["Updated CLAUDE.md", "Added security rules", "Wired in feature-dev (plugin drift)", "Regenerated missing .claude/rules/security.md"]
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
> Run `/onboard:check` to verify the health of your setup.

## Key Rules

- **Require `onboard-meta.json` before any work** — if the file is missing, halt at Step 1 with a message to run `/onboard:start`. Never run fresh analysis or apply updates without a baseline.
- **All upgrades require explicit approval** — never apply a detected drift item without the developer selecting it in the Step 6 `AskUserQuestion` call. "Apply later" is a valid answer; "Apply all" still requires the pre-question selection, not a silent auto-apply.
- **Never overwrite user-customized files without per-item choice** — files with a modified or absent maintenance header are flagged and require a merge/replace/skip decision before any change is made.
- **User-edits in frontmatter are display-only, never rewritten** — for skill, agent, and output-style frontmatter drift, `userEdit` items are shown for awareness only. Onboard updates the snapshot to accept the edit but never overwrites the hand-edited value.
