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

> This project hasn't been set up with onboard yet. Run `/onboard:init` first to generate your Claude tooling.

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
- Fetch the official Claude Code documentation at `https://docs.anthropic.com/en/docs/claude-code` using WebFetch to check for new features or changed best practices
- Also check `https://docs.anthropic.com/en/docs/claude-code/settings` for settings and hooks updates
- Compare fetched documentation against the existing setup to identify new capabilities not yet leveraged

**Web fetch failure fallback**: If the web fetch fails (network error, timeout, or content unavailable):
- Use the built-in reference guides only (claude-md-guide.md, rules-guide.md, hooks-guide.md, skills-guide.md, agents-guide.md)
- Note in the findings output: "Live best practices check unavailable — recommendations based on built-in reference guides only"
- Continue the update process normally with plugin knowledge alone

### Step 4b: Tooling Drift Detection

Detect three classes of drift that the preceding steps don't cover. Each class feeds new sections into the findings report (Step 5).

#### 4b.1: Plugin Drift

Follow `../generation/references/plugin-drift-detection.md` for the full procedure. Summary for update:

1. **Resolve baseline** using the caller order for `update`: first `.claude/onboard-meta.json.detectedPlugins.installedPlugins`, then `.claude/onboard-meta.json.callerExtras.installedPlugins`, then `.claude/forge-meta.json.generated.toolingFlags.installedPlugins`, else empty.
2. **Probe current state** against the Known Plugin Probe List in `../generation/references/plugin-detection-guide.md`. Also probe any plugin in the baseline that isn't in the known list.
3. **Compute diff** — produce the `driftReport` object described in `plugin-drift-detection.md` § Output Schema.
4. **Note the baseline source**. If the baseline was empty, flag the findings section with "Plugin Integration not tracked before — all detected plugins offered as new additions."

Record `driftReport.added`, `driftReport.removed`, and the derived `qualityGatesNext` / `phaseSkillsNext` / `coveredCapabilitiesNext` for Step 7.

#### 4b.2: Artifact Gaps

Re-walk `onboard-meta.json.generatedArtifacts`. For each entry:

1. Check that the file still exists on disk.
2. If missing and the entry does **not** have a `deletedByUser: true` flag, mark it as a gap candidate.
3. If missing and `deletedByUser: true` is set, skip silently — the developer opted out.

This complements the existing "maintenance header removed" detection in Step 2: Step 2 flags user-customized files, 4b.2 flags user-deleted / lost files. No overlap.

#### 4b.3: New Best-Practice Additions

Compare the current project against the built-in generation reference guides (`../generation/references/claude-md-guide.md`, `rules-guide.md`, `hooks-guide.md`, `skills-guide.md`, `agents-guide.md`). Surface only items that:

- Appear in the reference guides as a recommended artifact for the project's stack/complexity, AND
- Are not present in `onboard-meta.json.generatedArtifacts`, AND
- Are not present on disk under `.claude/`

Keep this narrow — do not parse the live WebFetch output to infer new recommendations. The reference guides are the stable source. WebFetch continues to drive wording/pattern updates as before.

#### 4b.4: MCP Drift

Compare `.mcp.json`, the drift snapshot `.claude/onboard-mcp-snapshot.json`, and a fresh signal scan (`../scripts/detect-mcp-signals.sh`). Follow `../generation/references/mcp-guide.md` for emission rules — this step only classifies drift; applying is deferred to Step 7.

1. **Read the three sources**:
   - `.mcp.json` at project root (if absent and `mcpStatus.existedPreOnboard` is false, record `mcpDrift.status: "file-missing"`)
   - `.claude/onboard-mcp-snapshot.json` (if absent, treat snapshot as empty)
   - Fresh candidate list from `detect-mcp-signals.sh`
2. **Classify each server**:
   - **user-edited** — present in `.mcp.json` but mismatched against snapshot (fields differ or entry was added by user). Never propose changes; inform only.
   - **user-removed** — in snapshot but missing from `.mcp.json`. Inform only ("you removed X"); never re-add without explicit user instruction.
   - **newly-suggested** — in the fresh candidate list but neither in snapshot nor `.mcp.json`. Surface as a suggested addition.
   - **stale-candidate** — in snapshot/`.mcp.json` but the underlying signal no longer fires (e.g., `vercel.json` was deleted). Surface as a suggested removal.
   - **in-sync** — present in all three and unchanged. No action.
3. **Pre-existing guard** — if `mcpStatus.existedPreOnboard: true`, onboard treats the whole file as user-owned. Suggest only additions (`newly-suggested`), never removals or edits.

Record the classification as `mcpDrift.{userEdited, userRemoved, newlySuggested, staleCandidate}[]` for Step 7.

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
> _Baseline source: [onboard-meta / forge-meta / none]_
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
> **Core tooling:**
> 1. **Update CLAUDE.md** — Add new commands discovered, update tech stack section
> 2. **Add .claude/rules/security.md** — Your project now has auth code that wasn't there before
> 3. **Update .claude/skills/react-component/SKILL.md** — New patterns detected in recent components
>
> **Enriched capabilities** (if not already set up):
> 4. **Add CI/CD pipelines** — Generate GitHub Actions for testing, deployment, and PR review
> 5. **Add harness artifacts** — progress.md, HARNESS-GUIDE.md for multi-session development
> 6. **Add evolution hooks** — Auto-detect when deps/configs/structure change
> 7. **Add sprint contracts** — Quality gates for feature development
> 8. **Add feature verification** — Independent evaluator agent + /onboard:verify
>
> **Plugin drift** (from Step 4b.1):
> 9. **Wire in `feature-dev`** — Refresh Plugin Integration + add `preCommit` hooks
> 10. **Remove `hookify`** — Strip CLAUDE.md references + delete obsolete hook scripts
>
> **Artifact gaps** (from Step 4b.2):
> 11. **Regenerate `.claude/rules/security.md`** — File was listed in generatedArtifacts but is missing from disk
>
> **New best-practice additions** (from Step 4b.3):
> 12. **Create `.claude/rules/observability.md`** — Reference guides recommend this for your stack
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

**Merge strategy for CLAUDE.md and markdown artifacts:**
- **User-added sections** — preserve in place, do not modify or reorder
- **Generated sections** (identified by maintenance header) — update content in-place, keep same position
- **New sections** — append after the last generated section, before any user-added trailing sections
- **Deleted sections** — do not re-add sections the user explicitly removed (check onboard-meta.json for previously generated sections)

**Plugin drift application** (for items surfaced by Step 4b.1):

Follow `../evolve/references/plugin-integration-rules.md` for content rules and `../generation/references/hooks-guide.md` § Quality-Gate Hook Templates for hook scripts — the same sources evolve Step 2b uses. Do not reimplement logic here.

For each approved **addition**:
1. Refresh the `<!-- onboard:plugin-integration:start -->` / `end` region in the root CLAUDE.md. If markers are absent but `currentPlugins` is non-empty, insert the delimited region after the last generated section (same path as evolve Step 2b.1 first-time-add).
2. Derive new `qualityGates` / `phaseSkills` entries from `driftReport.qualityGatesNext` / `phaseSkillsNext`. Generate hook scripts and merge entries into `.claude/settings.json` merge-aware (read first, preserve all non-plugin-integration hooks).
3. Apply autonomyLevel downgrade to `preCommit[].mode` if `wizardAnswers.autonomyLevel` is `always-ask`.

For each approved **removal**:
1. Identify hook scripts that reference the removed plugin by matching basenames against `onboard-meta.json.hookStatus.generated`. Delete those files. Remove their entries from `.claude/settings.json`.
2. Drop any `qualityGates` / `phaseSkills` entries referencing the removed plugin.
3. If all plugins were removed (`currentPlugins` is empty), strip the entire marker-delimited Plugin Integration region from CLAUDE.md — markers included, no placeholder.

**Subdirectory skill-annotation refresh** (runs when `driftReport.added` or `driftReport.removed` is non-empty):

Per-directory `## Skill recommendations` blocks are wrapped in `<!-- onboard:skill-recommendations:start role="..." -->` / `end` markers (see `../generation/SKILL.md` § Per-Directory Skill Annotations). The `role` attribute encodes the directory's classified role (`parser`, `api`, `tests`, etc.), so refresh does not require re-running scaffold-analyzer.

1. Enumerate all subdirectory `CLAUDE.md` files under the project root (glob `**/CLAUDE.md` excluding the root).
2. For each file containing the start/end markers:
   - Read the `role` attribute from the start marker.
   - Regenerate the block body using the new `driftReport.currentPlugins` + `effectiveCoveredCapabilities` per the derivation rules in `../generation/SKILL.md` § Per-Directory Skill Annotations.
   - Replace the delimited region (inclusive of markers) with the regenerated block. Preserve all file content outside the markers verbatim.
3. **Block removal**: if `currentPlugins` is now empty, OR the role no longer has any matching plugin capability, remove the entire marker-delimited region (markers included) — do not leave a stub.
4. **Block creation on empty baseline**: if markers are absent but `currentPlugins` is non-empty AND the file has a role hint (e.g., a prior generation comment or the file sits under a path that matches a known role from `../skills/analysis/references/tech-stack-patterns.md` § Subdirectory CLAUDE.md), skip auto-creation in this release. Surface a note in the findings report: "Subdirectory `<path>` could benefit from a Skill recommendations block — create during the next full regeneration."
5. Record refreshed files in `updateHistory[*].changes` as `"Refreshed skill annotations in src/parser/CLAUDE.md"`.

This reconciliation is non-blocking. If a subdirectory file fails to parse (e.g., corrupted markers), log a warning to `onboard-meta.json.warnings[]` and skip that file — never abort the whole update.

**Standalone ↔ plugin reconciliation** (runs once per update, after all add/remove items are applied):

Each of these standalone artifacts is only appropriate when the corresponding plugin is absent. On plugin drift, reconcile them:

| Artifact | Present when | Action on add | Action on remove |
|---|---|---|---|
| `.claude/skills/tdd-workflow/SKILL.md` | `superpowers` NOT installed | If `superpowers` in `driftReport.added`: delete this file (it would shadow `superpowers:test-driven-development`). Drop the entry from `generatedArtifacts`. | If `superpowers` in `driftReport.removed` AND file is absent: invoke `generate` with `callerExtras.regenerateOnly` scoped to this path. |
| `.claude/agents/tdd-test-writer.md` | `superpowers` NOT installed | If `superpowers` in `driftReport.added`: delete file, drop from `generatedArtifacts`. | If `superpowers` in `driftReport.removed`: regenerate via `generate`. |
| Standalone preCommit / sessionStart hooks (no plugin refs) | Any profile generates them in absence of plugin qualityGates | If any plugin that provides `qualityGates` coverage is in `driftReport.added` (e.g., `code-review`, `superpowers`): delete the standalone hook scripts whose basenames match `onboard-meta.json.hookStatus.generated` AND whose content carries no plugin references. Their replacements are the plugin-referencing hooks added above. | If a plugin providing coverage is in `driftReport.removed` AND `currentPlugins` has no alternate coverage: invoke `generate` to regenerate the standalone hooks per the profile + autonomyLevel matrix in `../generation/SKILL.md` § Standalone Quality-Gate Hooks. |

Before deleting any standalone artifact, present it in the findings report as a sub-item of the plugin-add approval ("Adding superpowers will remove the now-redundant standalone TDD skill at `.claude/skills/tdd-workflow/SKILL.md` — OK?"). Never auto-delete without per-item approval.

**MCP drift application** (for items surfaced by Step 4b.4):

Only **additions** are applied automatically on user approval. Removals and user-edits are never written.

1. For each approved `newlySuggested` server:
   - Read the current `.mcp.json` (if absent, create it with `{"mcpServers":{}}`).
   - Merge the new server entry into `mcpServers` per the schema in `../generation/references/mcp-guide.md` § Config Shape. Preserve every other key verbatim.
   - Append the server to `.claude/onboard-mcp-snapshot.json` as well so subsequent drift checks use the new baseline.
   - If the server's catalog entry has a `plugin` field, append to the auto-install queue for Step 7's plugin section (reuse `scripts/install-mcp-plugins.sh`).
2. For each `staleCandidate`: display the removal suggestion but do NOT auto-apply. If the user explicitly says "yes remove X", delete the entry from `.mcp.json` AND the snapshot.
3. For `userEdited` / `userRemoved`: no action. The findings report already informed the user.
4. If `.claude/rules/mcp-setup.md` needs regeneration (new server added needing auth), invoke `generate` with `callerExtras.regenerateOnly` scoped to `.claude/rules/mcp-setup.md`.

**Artifact gap regeneration** (for items surfaced by Step 4b.2):

Invoke the `generate` skill via the Skill tool with a narrow `callerExtras.regenerateOnly` payload listing the missing artifact paths. Generate honors this scope and only writes the listed files. After regeneration, verify each file is present on disk and carries a fresh maintenance header.

**New best-practice additions** (for items surfaced by Step 4b.3):

Invoke the `generate` skill with `callerExtras.regenerateOnly` scoped to the new artifact paths. Same flow as artifact gap regeneration — the difference is only in how the candidate list was computed.

### Step 8: Update Metadata

Update `.claude/onboard-meta.json`:
- Update `lastRun` timestamp
- Update `pluginVersion`
- Update `generatedArtifacts` list (add any new files, drop any whose deletion was explicitly approved)
- Preserve `wizardAnswers` (don't re-ask wizard questions during update)
- **If plugin drift was applied in Step 7** — refresh `detectedPlugins.installedPlugins` to `driftReport.currentPlugins`, and recompute `detectedPlugins.coveredCapabilities`, `detectedPlugins.qualityGates`, `detectedPlugins.phaseSkills` per `../generation/references/plugin-detection-guide.md`. Update the top-level `hookStatus` to reflect added/removed hook scripts.
- **If MCP drift was applied in Step 7** — refresh top-level `mcpStatus`: add newly-applied servers to `mcpStatus.generated[]`, drop removed servers. Re-run `scripts/install-mcp-plugins.sh` for any newly-applied server with a `plugin` field; merge results into `mcpStatus.autoInstalled[]` and `mcpStatus.autoInstallFailed[]`. Always keep `mcpStatus.existedPreOnboard` sticky — once true, it stays true for the life of the project.
- **Forge-meta mirror (scoped)** — If the project also maintains `.claude/forge-meta.json`, update ONLY these fields to match: `generated.toolingFlags.installedPlugins`, `generated.toolingFlags.coveredCapabilities`, `generated.toolingFlags.qualityGates`, `generated.toolingFlags.phaseSkills`, `generated.toolingFlags.hookStatus`. Read-modify-write the file: preserve every other key (`context.*`, `scaffold.*`, `lastRun`, `pluginVersion`, any caller-specific fields) verbatim. Never rewrite the whole file; never touch `context.autonomyLevel` or any other non-toolingFlags subtree — forge owns those. If `forge-meta.json` is absent, skip this step silently.
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
> Run `/onboard:status` to verify the health of your setup.
