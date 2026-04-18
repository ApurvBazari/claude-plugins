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
- Fetch the official Claude Code documentation at `https://code.claude.com/docs/en` using WebFetch to check for new features or changed best practices
- Also check `https://code.claude.com/docs/en/settings` for settings and hooks updates
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

Compare `.mcp.json`, the drift snapshot `.claude/onboard-mcp-snapshot.json`, and a fresh signal scan (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-mcp-signals.sh"`). Follow `../generation/references/mcp-guide.md` for emission rules — this step only classifies drift; applying is deferred to Step 7.

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

#### 4b.5: Skill Frontmatter Drift

Compare the live `SKILL.md` frontmatter for every skill in `onboard-meta.json.skillStatus.generated` against the baseline in `.claude/onboard-skill-snapshot.json`. This step only classifies — applying is deferred to Step 7.

1. **Read the inputs**:
   - `onboard-meta.json.skillStatus.generated` — list of skill names onboard authored in this project.
   - `.claude/onboard-skill-snapshot.json` — per-skill frontmatter baseline (the exact fields onboard wrote in the last run).
   - Live `.claude/skills/<skill>/SKILL.md` files on disk.

2. **For each skill in `skillStatus.generated`**: parse the YAML frontmatter from the live file and diff against the snapshot entry field-by-field.

3. **Classify per field**:
   - **user-edit** — field value in live differs from snapshot, and the skill's `frontmatterFields.<skill>.source` in `onboard-meta.json` is NOT `user-tweaked`. The developer hand-edited it after generation. Informational by default; never auto-rewrite.
   - **user-tweaked** — field value in live differs from snapshot AND `source === "user-tweaked"`. Expected drift — do not flag.
   - **missing-file** — `SKILL.md` is absent from disk but present in `skillStatus.generated` and not tagged `deletedByUser`. Offer to regenerate via `onboard:generate` with `callerExtras.regenerateOnly`.
   - **new-field** — snapshot omitted a field that the current generator would now emit (e.g., `model` was never inferred for this skill but is now part of the archetype default). Surface as a suggested addition.
   - **in-sync** — live frontmatter equals snapshot for every field. No action.

4. **Pre-existing guard**: skills in `skillStatus.existedPreOnboard` are never diffed — they predate the generator and are treated as user-owned.

Record as `skillDrift.{userEdited, missingFiles, newFieldCandidates}[]` for Step 7.

#### 4b.6: Agent Frontmatter Drift

Compare the live agent frontmatter for every agent in `onboard-meta.json.agentStatus.generated` against the baseline in `.claude/onboard-agent-snapshot.json`. This step only classifies — applying is deferred to Step 7.

1. **Read the inputs**:
   - `onboard-meta.json.agentStatus.generated` — list of agent names onboard authored in this project.
   - `.claude/onboard-agent-snapshot.json` — per-agent frontmatter baseline (the exact fields onboard wrote in the last run).
   - Live `.claude/agents/<agent>.md` files on disk.

2. **For each agent in `agentStatus.generated`**: parse the YAML frontmatter from the live file and diff against the snapshot entry field-by-field.

3. **Classify per field**:
   - **user-edit** — field value in live differs from snapshot, and the agent's `frontmatterFields.<agent>.source` in `onboard-meta.json` is NOT `user-tweaked`. The developer hand-edited it after generation. Informational by default; never auto-rewrite.
   - **user-tweaked** — field value in live differs from snapshot AND `source === "user-tweaked"`. Expected drift — do not flag.
   - **missing-file** — `<agent>.md` is absent from disk but present in `agentStatus.generated` and not tagged `deletedByUser`. Offer to regenerate via `onboard:generate` with `callerExtras.regenerateOnly`.
   - **new-field** — snapshot omitted a field that the current generator would now emit (e.g., `maxTurns` was never inferred for this agent but is now part of the archetype default). Surface as a suggested addition.
   - **legacy-no-frontmatter** — live file exists, but the frontmatter block is absent entirely (agent was generated by a pre-1.6.0 onboard version that used markdown sections instead of YAML frontmatter). Classify + prompt for migration; never auto-rewrite in `update`.
   - **in-sync** — live frontmatter equals snapshot for every field. No action.

4. **Pre-existing guard**: agents in `agentStatus.existedPreOnboard` are never diffed — they predate the generator and are treated as user-owned.

Record as `agentDrift.{userEdited, missingFiles, newFieldCandidates, legacyNoFrontmatter}[]` for Step 7.

#### 4b.7: Output Style Drift

Compare the live output-style frontmatter for every style in `onboard-meta.json.outputStyleStatus.generated` against the baseline in `.claude/onboard-output-style-snapshot.json`. This step only classifies — applying is deferred to Step 7.

1. **Read the inputs**:
   - `onboard-meta.json.outputStyleStatus.generated` — list of style filename stems onboard authored in this project.
   - `.claude/onboard-output-style-snapshot.json` — per-style frontmatter baseline (the 5 fields onboard wrote in the last run).
   - Live `.claude/output-styles/<name>.md` files on disk.

2. **For each style in `outputStyleStatus.generated`**: parse the YAML frontmatter from the live file and diff against the snapshot entry field-by-field.

3. **Scope reminder**: snapshot tracks **frontmatter only** (`name`, `description`, `keep-coding-instructions`, `archetype`, `source`). Body edits (system-prompt prose) are intentionally outside snapshot scope and never classified as drift. Developers can freely revise the body voice without triggering any state.

4. **Classify per field**:
   - **user-edit** — frontmatter field value in live differs from snapshot, and the style's `frontmatterFields.<style>.source` in `onboard-meta.json` is NOT `user-tweaked`. The developer hand-edited it after generation. Informational by default; never auto-rewrite.
   - **user-tweaked** — frontmatter field value in live differs from snapshot AND `source === "user-tweaked"`. Expected drift — do not flag.
   - **missing-file** — the `.md` file is absent from disk but present in `outputStyleStatus.generated` and not tagged `deletedByUser`. Offer to regenerate via `onboard:generate` with `callerExtras.regenerateOnly` and `callerExtras.disableOutputStyleTuning: true` (reuse snapshot values).
   - **new-field** — snapshot omitted a field that the current generator would now emit (e.g., a future release adds a new internal tracking field). Surface as a suggested addition.
   - **legacy-no-frontmatter** — live file exists, but the YAML frontmatter block is absent entirely (style was hand-authored before 1.7.0 or frontmatter was stripped). Classify + prompt for migration; never auto-rewrite in `update`.
   - **in-sync** — live frontmatter equals snapshot for every field. No action.

5. **Pre-existing guard**: styles in `outputStyleStatus.existedPreOnboard` are never diffed — they predate the generator and are treated as user-owned.

Record as `outputStyleDrift.{userEdited, missingFiles, newFieldCandidates, legacyNoFrontmatter}[]` for Step 7.

#### 4b.8: LSP Plugin Drift

Compare the fresh `detect-lsp-signals.sh` output against the `onboard-lsp-snapshot.json` baseline and the set of currently-installed marketplace plugins. Classification only — Step 7 applies.

1. **Read the inputs**:
   - `.claude/onboard-lsp-snapshot.json` — `{ recommended, accepted }`. Missing file → treat as `recommended: [], accepted: []` (pre-1.8.0 project).
   - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh" "$PROJECT_ROOT"` — fresh JSON array.
   - `claude plugin list --json` (via `install-plugins.sh`'s probe, or direct call) — current install state.

2. **Classify** per candidate plugin from the fresh scan:
   - **newLanguage** — plugin name in fresh scan but not in `snapshot.recommended`. A new language was added to the project since last onboard/evolve run. Surface as a suggested addition.
   - **uninstalled** — plugin in `snapshot.accepted` but not currently installed (user ran `claude plugin uninstall`). Informational; do NOT auto-reinstall.
   - **stillValid** — plugin in both `snapshot.accepted` and installed list. No action.
   - **staleCandidate** — plugin in `snapshot.recommended` but fresh scan no longer detects any files for that language (e.g., a language was removed). Informational — do NOT auto-suggest removal.

3. **Pre-1.8.0 projects** (snapshot missing) — surface every fresh-scan candidate as `newLanguage`. First update run acts like an initial 1.8.0 prompt.

Record as `lspDrift.{newLanguages, uninstalled, staleCandidates}[]` for Step 7. Findings report emits a "LSP Plugin Drift" section when any of these are non-empty; see Step 5 template additions below.

#### 4b.9: Built-in Skills Drift

Re-run detection against the current codebase analysis to identify which built-in Claude Code skills are relevant. Compare against the `onboard-builtin-skills-snapshot.json` baseline. Classification only — Step 7 applies.

1. **Read the inputs**:
   - `.claude/onboard-builtin-skills-snapshot.json` — `{ recommended, accepted }`. Missing file → treat as `recommended: [], accepted: []` (pre-1.9.0 project).
   - Fresh detection against the current codebase: check each extra skill's detection signal per `generation/references/built-in-skills-catalog.md`. Core skills (`/loop`, `/simplify`, `/debug`, `/pr-summary`) are always candidates.

2. **Classify** per candidate skill from the fresh detection:
   - **newSkill** — skill name in fresh candidates but not in `snapshot.recommended`. A new detection signal fired since last onboard/evolve run (e.g., `@anthropic-ai/sdk` added to dependencies → `/claude-api` detected). Surface as a suggested addition.
   - **newlyRelevant** — skill in `snapshot.recommended` but not in `snapshot.accepted` (developer previously declined), and the detection signal now has a stronger basis (e.g., file count grew from 30 to 200 → `/codebase-visualizer` crosses threshold). Surface as a suggestion, not an action.
   - **staleCandidate** — skill in `snapshot.recommended` but fresh detection no longer fires the signal (e.g., `@anthropic-ai/sdk` removed from dependencies). Informational — do NOT auto-suggest removal.
   - **in-sync** — no changes between snapshot and fresh detection. No action.

3. **Pre-1.9.0 projects** (snapshot missing) — surface every fresh candidate (core + fired extras) as `newSkill`. First update run acts like an initial 1.9.0 prompt.

Record as `builtInSkillsDrift.{newSkills, newlyRelevant, staleCandidates}[]` for Step 7. Findings report emits a "Built-in Skills Drift" section when any of these are non-empty; see Step 5 template additions below.

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
   - If the server's catalog entry has a `plugin` field, append to the auto-install queue for Step 7's plugin section (reuse `${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh`).
2. For each `staleCandidate`: display the removal suggestion but do NOT auto-apply. If the user explicitly says "yes remove X", delete the entry from `.mcp.json` AND the snapshot.
3. For `userEdited` / `userRemoved`: no action. The findings report already informed the user.
4. If `.claude/rules/mcp-setup.md` needs regeneration (new server added needing auth), invoke `generate` with `callerExtras.regenerateOnly` scoped to `.claude/rules/mcp-setup.md`.

**Skill frontmatter drift application** (for items surfaced by Step 4b.5):

Only **additions** are applied automatically on user approval. User-edits are never overwritten.

1. For each approved `newFieldCandidate`: read the live `SKILL.md`, add only the missing field using the archetype-inferred value (wizard defaults from `onboard-meta.json.wizardAnswers.skillTuning` still apply). Do not touch existing fields. Update `.claude/onboard-skill-snapshot.json` to include the new field in the baseline. Set `frontmatterFields.<skill>.source = "user-confirmed"`.
2. For each `userEdit`: display only — never apply. The developer's hand-edit stays. Update the snapshot to match the live file so subsequent runs stop flagging this drift (equivalent to evolve's `accept-user-edit` verb). Set `frontmatterFields.<skill>.source = "user-tweaked"`.
3. For each `missingFile`: invoke `generate` via the Skill tool with `callerExtras.regenerateOnly: [".claude/skills/<skill>/SKILL.md"]` and `callerExtras.disableSkillTuning: true`. The generator re-emits the skill using the snapshot's frontmatter values (preserving prior tweaks). Append to `generatedArtifacts` if previously dropped.

**Agent frontmatter drift application** (for items surfaced by Step 4b.6):

Only **additions** and **legacy migrations** are applied on user approval. User-edits are never overwritten.

1. For each approved `newFieldCandidate`: read the live agent `.md`, add only the missing field using the archetype-inferred value (wizard defaults from `onboard-meta.json.wizardAnswers.agentTuning` still apply). Do not touch existing fields. Update `.claude/onboard-agent-snapshot.json` to include the new field in the baseline. Set `frontmatterFields.<agent>.source = "user-confirmed"`.
2. For each `userEdit`: display only — never apply. The developer's hand-edit stays. Update the snapshot to match the live file so subsequent runs stop flagging this drift. Set `frontmatterFields.<agent>.source = "user-tweaked"`.
3. For each `missingFile`: invoke `generate` via the Skill tool with `callerExtras.regenerateOnly: [".claude/agents/<agent>.md"]` and `callerExtras.disableAgentTuning: true`. The generator re-emits the agent using the snapshot's frontmatter values (preserving prior tweaks). Append to `generatedArtifacts` if previously dropped.
4. For each `legacyNoFrontmatter`: prompt the developer with a preview:
   > Agent `<name>` has no YAML frontmatter (pre-1.6.0 format). Apply archetype-inferred defaults (`model: sonnet`, `color: blue`, `effort: medium`) as a migration? [yes/no/skip]
   On yes: classify the agent via `generation/references/agents-guide.md` archetype rules using its name/description, compose with `wizardAnswers.agentTuning`, run the full validation pass from `generation/SKILL.md` § Agent Frontmatter Emission Step 3, and prepend a YAML frontmatter block to the live file (keeping the body intact). Update the snapshot and set `frontmatterFields.<agent>.source = "wizard-default"`. On no/skip: leave the file as-is; record `agentStatus.warnings[] = "legacy-skipped:<agent>"`.

**Output style drift application** (for items surfaced by Step 4b.7):

Only **additions** and **legacy migrations** are applied on user approval. User-edits are never overwritten, and body prose is outside snapshot scope (no body-related apply logic).

1. For each approved `newFieldCandidate`: read the live style `.md`, add only the missing frontmatter field using the catalog default for the style's archetype. Do not touch body content. Update `.claude/onboard-output-style-snapshot.json` to include the new field in the baseline. Set `frontmatterFields.<style>.source = "user-confirmed"`.
2. For each `userEdit`: display only — never apply. The developer's hand-edit stays. Update the snapshot to match the live file so subsequent runs stop flagging this drift. Set `frontmatterFields.<style>.source = "user-tweaked"`.
3. For each `missingFile`: invoke `generate` via the Skill tool with `callerExtras.regenerateOnly: [".claude/output-styles/<name>.md"]` and `callerExtras.disableOutputStyleTuning: true`. The generator re-emits the style using the snapshot's frontmatter values and the catalog body template (preserving prior tweaks). Append to `generatedArtifacts` if previously dropped.
4. For each `legacyNoFrontmatter`: prompt the developer with a preview:
   > Output style `<name>` has no YAML frontmatter. Apply archetype-inferred defaults (matching the filename stem to the 5-archetype catalog) as a migration? [yes/no/skip]
   On yes: match the filename stem against the catalog (`onboarding-mentor`, `tutorial-guide`, `operator`, `explorer-notes`, `solo-minimal`) to determine the archetype, compose catalog-default frontmatter (`name`, `description`, `keep-coding-instructions: true`, `archetype`, `source: "wizard-default"`), and prepend a YAML frontmatter block to the live file (keeping the body intact). If the filename stem doesn't match any catalog entry, skip with warning `legacy-no-archetype-match:<style>`. Update the snapshot. On no/skip: leave the file as-is; record `outputStyleStatus.warnings[] = "legacy-skipped:<style>"`.

**LSP plugin drift application** (for items surfaced by Step 4b.8):

Only **new-language additions** are applied on user approval. Uninstalls and stale candidates are informational only — onboard never auto-reinstalls or auto-removes LSP plugins.

1. For each approved `newLanguage` candidate:
   - Invoke `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <plugin-name>`. Merge results into `lspStatus.autoInstalled[]` and `lspStatus.autoInstallFailed[]`.
   - Append the plugin to `.claude/onboard-lsp-snapshot.json` `recommended[]` AND `accepted[]`, preserving alphabetical sort.
   - Append the plugin to `lspStatus.generated[]`.
2. For `uninstalled` findings: no action. Log once: "LSP plugin `<name>` was uninstalled since last run — rerun `/onboard:evolve` if you want to reinstall."
3. For `staleCandidate` findings: no action. Log once.

**Built-in skills drift application** (for items surfaced by Step 4b.9):

Only **newSkill additions** are applied on user approval. Stale candidates and newly-relevant suggestions are informational only.

1. For each approved `newSkill` candidate:
   - Add the skill to `builtInSkillsStatus.generated[]`.
   - Find the `<!-- onboard:builtin-skills:start -->` / `<!-- onboard:builtin-skills:end -->` markers in CLAUDE.md and regenerate the content between them, including the new skill with its stack-specific example from `generation/references/built-in-skills-catalog.md`.
   - Update `.claude/onboard-builtin-skills-snapshot.json` — append to both `recommended[]` and `accepted[]`, preserving alphabetical sort.
2. For `newlyRelevant` suggestions: no action. Log once as informational.
3. For `staleCandidate` findings: no action. Log once.

**Placement migration** (handled alongside built-in skills application):
- **Standalone → Plugin Integration**: If `<!-- onboard:builtin-skills:start/end -->` markers exist as a top-level section AND `effectivePlugins` is now non-empty (e.g., plugins were installed since last run), remove the standalone region and regenerate the built-in skills content as the last subsection inside `<!-- onboard:plugin-integration:start/end -->`. Surface as a named migration action in the Step 6 upgrade offer menu.
- **Plugin Integration → standalone**: If `effectivePlugins` becomes empty (all plugins removed) and built-in skills content is inside Plugin Integration markers, migrate the content out to a standalone section before stripping the Plugin Integration markers.
- **Empty accepted list**: If `builtInSkillsStatus.generated[]` becomes empty (all skills declined), strip the `<!-- onboard:builtin-skills:start/end -->` markers and their content entirely.

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
- **If MCP drift was applied in Step 7** — refresh top-level `mcpStatus`: add newly-applied servers to `mcpStatus.generated[]`, drop removed servers. Re-run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh"` for any newly-applied server with a `plugin` field; merge results into `mcpStatus.autoInstalled[]` and `mcpStatus.autoInstallFailed[]`. Always keep `mcpStatus.existedPreOnboard` sticky — once true, it stays true for the life of the project.
- **If skill frontmatter drift was applied in Step 7** — refresh top-level `skillStatus.frontmatterFields[<skill>]` to match the applied state, including the refreshed `source` value (`user-confirmed` / `user-tweaked`). Update `.claude/onboard-skill-snapshot.json` to reflect the new baseline. Keep `skillStatus.existedPreOnboard[]` sticky.
- **If agent frontmatter drift was applied in Step 7** — refresh top-level `agentStatus.frontmatterFields[<agent>]` to match the applied state, including the refreshed `source` value (`user-confirmed` / `user-tweaked` / `wizard-default` for legacy migrations). Update `.claude/onboard-agent-snapshot.json` to reflect the new baseline. Keep `agentStatus.existedPreOnboard[]` sticky. Append `legacy-skipped:<agent>` entries to `agentStatus.warnings` for any `legacyNoFrontmatter` declined by the developer.
- **If output style drift was applied in Step 7** — refresh top-level `outputStyleStatus.frontmatterFields[<style>]` to match the applied state, including the refreshed `source` value (`user-confirmed` / `user-tweaked` / `wizard-default` for legacy migrations). Update `.claude/onboard-output-style-snapshot.json` to reflect the new baseline. Keep `outputStyleStatus.existedPreOnboard[]` sticky. Append `legacy-skipped:<style>` or `legacy-no-archetype-match:<style>` entries to `outputStyleStatus.warnings` for any `legacyNoFrontmatter` declined or unclassifiable. Preserve `outputStyleStatus.activationDefault`, `settingsLocalWritten`, and `settingsLocalWarning` from the prior state — `update` does NOT touch settings.local.json.
- **If LSP drift was applied in Step 7** — refresh top-level `lspStatus`: append newly-installed plugins to `lspStatus.accepted[]` and `lspStatus.generated[]`, merge install-script results into `lspStatus.autoInstalled[]` and `lspStatus.autoInstallFailed[]`. Update `.claude/onboard-lsp-snapshot.json` (both `recommended` and `accepted`) to reflect the new baseline. `lspStatus.skipped[]` is preserved from prior runs — never rewritten during update.
- **If built-in skills drift was applied in Step 7** — refresh top-level `builtInSkillsStatus`: append newly-accepted skills to `builtInSkillsStatus.generated[]`, update `detectionSignals` for new entries. Update `.claude/onboard-builtin-skills-snapshot.json` (both `recommended` and `accepted`) to reflect the new baseline, preserving alphabetical sort. `builtInSkillsStatus.skipped[]` is preserved from prior runs — never rewritten during update.
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
