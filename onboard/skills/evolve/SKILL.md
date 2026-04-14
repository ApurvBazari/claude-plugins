---
name: evolve
description: Apply accumulated tooling drift to Claude configuration. Use when user says their Claude tooling is out of sync, mentions drift detected by hooks, installed/removed a plugin and wants the Plugin Integration section refreshed, or asks to drain queued forge-drift.json updates.
---

# Evolve Skill — Apply Pending Drift Updates

You are applying accumulated tooling drift updates. This skill handles two drift sources: **FileChanged drift** (logged by hooks to `.claude/forge-drift.json`) and **plugin drift** (detected by comparing `forge-meta.json` against currently-installed plugins).

## Guard

Check both drift sources before deciding whether to proceed:

1. Read `.claude/forge-drift.json` in the project root. Record whether it has entries.
2. Read `.claude/forge-meta.json`. If it exists and contains `generated.toolingFlags.installedPlugins`, run the plugin drift detection from Step 0 below. Record whether plugin drift was found.

If forge-drift.json has no entries (or is missing) AND no plugin drift was detected:

> No pending drift detected. Your AI tooling is in sync with your codebase.
>
> FileChanged drift is logged automatically when dependencies, configs, or structure change. Plugin drift is detected by comparing installed plugins against forge-meta.json.

Stop and do not proceed.

If either source has drift, continue.

## Step 0: Detect Plugin Drift

Plugin drift detection follows the shared procedure in `../generation/references/plugin-drift-detection.md`. Evolve-specific parameters:

- **Baseline source** — `.claude/forge-meta.json.generated.toolingFlags.installedPlugins`. If the file is missing or this field is absent, skip Step 0 entirely (evolve requires a forge baseline; use `/onboard:update` instead for projects without forge-meta).
- **Probe list** — canonical list in `../generation/references/plugin-detection-guide.md` § Known Plugin Probe List. Also probe any plugin in `previousPlugins` that isn't in the known list (custom/third-party plugins).
- **autonomyLevel source** — `forge-meta.json.context.autonomyLevel`, falling back to `onboard-meta.json.wizardAnswers.autonomyLevel`.

Produce the `driftReport` described in `plugin-drift-detection.md` § Output Schema. If `added` and `removed` are both empty, skip to Step 1.

Present the summary to the developer per `plugin-drift-detection.md` § Presentation, then record `currentPlugins`, `added`, and `removed` for use in Step 2b.

## Step 1: Read FileChanged Drift Entries

Parse `.claude/forge-drift.json` and categorize entries:

- **Dependency changes**: new packages added, packages removed, scripts added/removed
- **Config changes**: tsconfig, eslint, prettier settings changed
- **Structural changes**: new directories with source files, removed directories

If forge-drift.json is missing or has no entries, skip this step (plugin drift alone is sufficient to proceed).

Present a summary when entries exist:

> **Pending tooling updates:**
>
> **Dependencies** ([N] changes)
> - Added: [package1], [package2]
> - Removed: [package3]
> - New scripts: [script1]
>
> **Config** ([N] changes)
> - tsconfig: strict mode enabled
> - eslint: added [rule]
>
> **Structure** ([N] changes)
> - New directory: src/services/ (3 files)
>
> I'll update your CLAUDE.md, rules, and skills to reflect these changes.

## Step 2: Apply FileChanged Updates

For each category of FileChanged drift:

### Dependency Changes
- **New packages**: Add to CLAUDE.md dependencies section. If the package is a major tool (testing framework, ORM, auth library), consider adding a corresponding rule or updating existing rules.
- **Removed packages**: Remove from CLAUDE.md. Remove any rules that reference the removed package.
- **New scripts**: Add to CLAUDE.md commands section with a description.
- **Removed scripts**: Remove from CLAUDE.md commands section.

### Config Changes
- **tsconfig changes**: Update TypeScript-related rules to match new settings.
- **ESLint changes**: Update code style rules to match new linting config.
- **Prettier changes**: Update formatting conventions in CLAUDE.md.

### Structural Changes
- **New directories**: If the directory has >5 source files and represents an architectural boundary, suggest creating a subdirectory CLAUDE.md. Ask the developer before creating it.
- **Removed directories**: Remove any subdirectory CLAUDE.md that references a deleted directory. Update path-scoped rules.

## Step 2b: Apply Plugin Integration Updates

Skip this step if no plugin drift was detected in Step 0.

Follow `references/plugin-integration-rules.md` for all content rules, capability mappings, and derivation logic.

### 2b.1: Refresh Plugin Integration Section in CLAUDE.md

Read the root CLAUDE.md. Find the `<!-- onboard:plugin-integration:start -->` and `<!-- onboard:plugin-integration:end -->` markers.

**If markers are found**: Replace the entire delimited region (inclusive of markers) with a freshly-generated Plugin Integration section built from `currentPlugins`. Follow the 6-subsection content rules and tone guidance in `references/plugin-integration-rules.md`.

**If markers are NOT found but `currentPlugins` is non-empty**: This is the first time adding plugin integration to this CLAUDE.md. Insert the section (with markers) after the last generated section (identified by maintenance headers), before any user-added trailing sections.

**If all plugins were removed** (`currentPlugins` is empty): Remove the entire delimited region including the markers. Do not leave a stub or placeholder.

### 2b.2: Refresh Quality-Gate Hooks

Read the existing `autonomyLevel` from `forge-meta.json.context.autonomyLevel` (or fall back to `onboard-meta.json.wizardAnswers.autonomyLevel`).

**For added plugins**: Derive new `qualityGates` and `phaseSkills` entries per `references/plugin-integration-rules.md` § qualityGates Derivation. Generate new hook scripts following the hook conventions from `generation/references/hooks-guide.md` § Quality-Gate Hook Templates. Add corresponding entries to `.claude/settings.json` (merge-aware — read first, never overwrite existing non-plugin-integration hooks).

**For removed plugins**: Identify hook scripts that reference removed plugins. Match by script basename against `forge-meta.json.generated.toolingFlags.hookStatus.generated` entries. Delete the hook script files. Remove corresponding entries from `.claude/settings.json`. If a `qualityGates` or `phaseSkills` entry references a removed plugin, drop it.

**Apply autonomyLevel downgrade**: If `autonomyLevel` is `always-ask`, downgrade all `preCommit[].mode` values to `"advisory"`.

**Subdirectory skill-annotation refresh**: If `added` or `removed` is non-empty, also refresh per-directory `## Skill recommendations` blocks wrapped in `<!-- onboard:skill-recommendations:start role="..." -->` / `end` markers. Follow the procedure in `../update/SKILL.md` § Subdirectory skill-annotation refresh. The `role` attribute makes this a read-role → regenerate-body operation — no scaffold-analyzer invocation needed.

**Standalone ↔ plugin reconciliation**: Apply the same reconciliation matrix that `update` uses — see `../update/SKILL.md` § Standalone ↔ plugin reconciliation for the full table. In short: when `superpowers` enters via `added`, delete `.claude/skills/tdd-workflow/SKILL.md` and `.claude/agents/tdd-test-writer.md` (plus standalone hooks that duplicate its skills); when `superpowers` leaves via `removed` and no alternate coverage exists, regenerate those standalone artifacts via `onboard:generate` with `callerExtras.regenerateOnly`. Same rules apply for any other plugin that shadowed a standalone artifact. Evolve runs this reconciliation without asking — it's acceptable because evolve is meant to drain accumulated drift automatically; users who want per-item approval should use `/onboard:update` instead.

### 2b.3: Update forge-meta.json

Update the following fields in `.claude/forge-meta.json`:

1. `generated.toolingFlags.installedPlugins` → set to `currentPlugins`
2. `generated.toolingFlags.coveredCapabilities` → recompute from `currentPlugins` using the capability mapping table in `references/plugin-integration-rules.md`
3. `generated.toolingFlags.qualityGates` → rebuilt from current state
4. `generated.toolingFlags.phaseSkills` → rebuilt from current state
5. `generated.toolingFlags.hookStatus` → update `planned`, `generated`, `skipped` to reflect new hook state

## Step 3: Show Diff

After applying all updates (both FileChanged and plugin integration), show what changed:

> **Updates applied:**
>
> - CLAUDE.md: [list specific changes — e.g., "Added `zod` to dependencies", "Refreshed Plugin Integration section (2 plugins added)"]
> - .claude/rules/typescript.md: Updated for strict mode
> - .claude/hooks/pre-commit-code-review.sh: Added (new plugin: code-review)
> - .claude/settings.json: Updated hook entries
> - .claude/forge-meta.json: Updated installedPlugins, hookStatus
>
> **Not auto-applied** (needs your input):
> - New directory src/services/ — want me to create a CLAUDE.md for it?
>
> **Note**: Subdirectory skill-annotation blocks (wrapped in `<!-- onboard:skill-recommendations:start/end -->` markers) are refreshed automatically via the role-attribute strategy. Subdirectory files that predate markered blocks are not auto-created — run `/onboard:update` to have those offered as new best-practice additions.

## Step 4: Clear Processed Entries

After updates are applied:
1. Update `lastAuditedAt` in forge-drift.json to current timestamp
2. Clear the processed entries from the `entries` array
3. Keep any entries that were NOT processed (e.g., structural changes that need developer input)
4. Plugin drift state is persisted in forge-meta.json (updated in Step 2b.3) — there is no separate "clear" action for plugin drift.

## Key Rules

1. **Read before writing** — Always read the current state of CLAUDE.md, rules, settings.json, and forge-meta.json before making changes.
2. **Surgical updates** — Only change the specific sections affected by the drift. Don't rewrite entire files.
3. **Ask for structural** — Dependency and config changes can be auto-applied. Structural changes (new CLAUDE.md files) require developer confirmation.
4. **Preserve manual edits** — If the developer has customized CLAUDE.md beyond what onboard generated, preserve those customizations. Only touch the marker-delimited Plugin Integration section.
5. **Show the diff** — Always show what was changed so the developer can verify.
6. **Plugin drift is probe-based** — It does not depend on forge-drift.json entries. It's detected by comparing forge-meta.json against filesystem state at evolve-time, following `../generation/references/plugin-drift-detection.md`.
7. **Marker-delimited surgery** — Plugin Integration section updates use the `<!-- onboard:plugin-integration:start/end -->` markers. Never touch content outside the markers.
8. **Subdirectory annotations refresh via marker + role attribute** — Plugin drift refreshes `<!-- onboard:skill-recommendations:start role="..." -->` blocks in subdirectory CLAUDE.md files without re-invoking scaffold-analyzer. Directories lacking markered blocks are not auto-created — run `/onboard:update` to surface them as new best-practice additions.
9. **Merge-aware hook updates** — When modifying `.claude/settings.json`, read first, merge plugin-integration hooks, and preserve all other hooks (format, lint, evolution, etc.).
10. **Never fabricate plugin references** — Only reference plugins confirmed to exist via filesystem probe.
