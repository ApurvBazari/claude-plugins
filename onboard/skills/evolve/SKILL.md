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

Read `.claude/forge-meta.json`. If the file is missing or does not contain `generated.toolingFlags.installedPlugins`, skip this step entirely — plugin drift detection requires a forge baseline.

1. Extract `previousPlugins` from `generated.toolingFlags.installedPlugins`.
2. Probe the filesystem for currently-installed plugins. For each plugin in the known probe list (see `references/plugin-integration-rules.md` § Known Plugin Probe List), check:

   ```bash
   ls "${CLAUDE_PLUGIN_ROOT}/../<plugin-name>" 2>/dev/null
   ```

   Also probe any plugin in `previousPlugins` that isn't in the known list (custom/third-party plugins).

3. Build `currentPlugins` from successful probes.
4. Compute diff:
   - `added` = plugins in `currentPlugins` but not in `previousPlugins`
   - `removed` = plugins in `previousPlugins` but not in `currentPlugins`
5. If `added` and `removed` are both empty, no plugin drift — skip to Step 1.
6. Present the plugin drift summary:

> **Plugin drift detected:**
>
> **Added**: [comma-separated list, or "none"]
> **Removed**: [comma-separated list, or "none"]
>
> I'll update the Plugin Integration section in CLAUDE.md and refresh quality-gate hooks to match.

Record `currentPlugins`, `added`, and `removed` for use in Step 2b.

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
> **Note**: Subdirectory CLAUDE.md files may have stale skill annotations after plugin changes. Run `/onboard:update` for a thorough refresh that includes per-directory annotations.

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
6. **Plugin drift is probe-based** — It does not depend on forge-drift.json entries. It's detected by comparing forge-meta.json against filesystem state at evolve-time.
7. **Marker-delimited surgery** — Plugin Integration section updates use the `<!-- onboard:plugin-integration:start/end -->` markers. Never touch content outside the markers.
8. **No subdirectory annotation updates** — Plugin drift does not refresh subdirectory CLAUDE.md skill annotations (those require directory-role knowledge from scaffold-analyzer). Note the stale risk in Step 3 and suggest `/onboard:update`.
9. **Merge-aware hook updates** — When modifying `.claude/settings.json`, read first, merge plugin-integration hooks, and preserve all other hooks (format, lint, evolution, etc.).
10. **Never fabricate plugin references** — Only reference plugins confirmed to exist via filesystem probe.
