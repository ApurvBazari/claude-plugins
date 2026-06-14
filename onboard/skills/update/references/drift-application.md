# Drift Application — Step 7 Per-Drift Procedures

Verbatim application procedures for each drift type approved in Step 6. Each section records the full apply contract for its drift type. Control flow (ordering, metadata refresh, completion) lives in SKILL.md Step 7 and Step 8.

---

## Plugin drift application (for items surfaced by Step 4b.1)

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

---

## MCP drift application (for items surfaced by Step 4b.4)

Only **additions** are applied automatically on user approval. Removals and user-edits are never written.

1. For each approved `newlySuggested` server:
   - Read the current `.mcp.json` (if absent, create it with `{"mcpServers":{}}`).
   - Merge the new server entry into `mcpServers` per the schema in `../generation/references/mcp-guide.md` § Config Shape. Preserve every other key verbatim.
   - Append the server to `.claude/onboard-mcp-snapshot.json` as well so subsequent drift checks use the new baseline.
   - If the server's catalog entry has a `plugin` field, append to the auto-install queue for Step 7's plugin section (reuse `${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh`).
2. For each `staleCandidate`: display the removal suggestion but do NOT auto-apply. If the user explicitly says "yes remove X", delete the entry from `.mcp.json` AND the snapshot.
3. For `userEdited` / `userRemoved`: no action. The findings report already informed the user.
4. If `.claude/rules/mcp-setup.md` needs regeneration (new server added needing auth), invoke `generate` with `callerExtras.regenerateOnly` scoped to `.claude/rules/mcp-setup.md`.

---

## Skill frontmatter drift application (for items surfaced by Step 4b.5)

Only **additions** are applied automatically on user approval. User-edits are never overwritten.

1. For each approved `newFieldCandidate`: read the live `SKILL.md`, add only the missing field using the archetype-inferred value (wizard defaults from `onboard-meta.json.wizardAnswers.skillTuning` still apply). Do not touch existing fields. Update `.claude/onboard-skill-snapshot.json` to include the new field in the baseline. Set `frontmatterFields.<skill>.source = "user-confirmed"`.
2. For each `userEdit`: display only — never apply. The developer's hand-edit stays. Update the snapshot to match the live file so subsequent runs stop flagging this drift (equivalent to evolve's `accept-user-edit` verb). Set `frontmatterFields.<skill>.source = "user-tweaked"`.
3. For each `missingFile`: invoke `generate` via the Skill tool with `callerExtras.regenerateOnly: [".claude/skills/<skill>/SKILL.md"]` and `callerExtras.disableSkillTuning: true`. The generator re-emits the skill using the snapshot's frontmatter values (preserving prior tweaks). Append to `generatedArtifacts` if previously dropped.

---

## Agent frontmatter drift application (for items surfaced by Step 4b.6)

Only **additions** and **legacy migrations** are applied on user approval. User-edits are never overwritten.

1. For each approved `newFieldCandidate`: read the live agent `.md`, add only the missing field using the archetype-inferred value (wizard defaults from `onboard-meta.json.wizardAnswers.agentTuning` still apply). Do not touch existing fields. Update `.claude/onboard-agent-snapshot.json` to include the new field in the baseline. Set `frontmatterFields.<agent>.source = "user-confirmed"`.
2. For each `userEdit`: display only — never apply. The developer's hand-edit stays. Update the snapshot to match the live file so subsequent runs stop flagging this drift. Set `frontmatterFields.<agent>.source = "user-tweaked"`.
3. For each `missingFile`: invoke `generate` via the Skill tool with `callerExtras.regenerateOnly: [".claude/agents/<agent>.md"]` and `callerExtras.disableAgentTuning: true`. The generator re-emits the agent using the snapshot's frontmatter values (preserving prior tweaks). Append to `generatedArtifacts` if previously dropped.
4. For each `legacyNoFrontmatter`: prompt the developer with a preview:
   > Agent `<name>` has no YAML frontmatter (pre-1.6.0 format). Apply archetype-inferred defaults (`model: sonnet`, `color: blue`, `effort: medium`) as a migration? [yes/no/skip]
   On yes: classify the agent via `generation/references/agents-guide.md` archetype rules using its name/description, compose with `wizardAnswers.agentTuning`, run the full validation pass from `generation/SKILL.md` § Agent Frontmatter Emission Step 3, and prepend a YAML frontmatter block to the live file (keeping the body intact). Update the snapshot and set `frontmatterFields.<agent>.source = "wizard-default"`. On no/skip: leave the file as-is; record `agentStatus.warnings[] = "legacy-skipped:<agent>"`.

---

## Output style drift application (for items surfaced by Step 4b.7)

Only **additions** and **legacy migrations** are applied on user approval. User-edits are never overwritten, and body prose is outside snapshot scope (no body-related apply logic).

1. For each approved `newFieldCandidate`: read the live style `.md`, add only the missing frontmatter field using the catalog default for the style's archetype. Do not touch body content. Update `.claude/onboard-output-style-snapshot.json` to include the new field in the baseline. Set `frontmatterFields.<style>.source = "user-confirmed"`.
2. For each `userEdit`: display only — never apply. The developer's hand-edit stays. Update the snapshot to match the live file so subsequent runs stop flagging this drift. Set `frontmatterFields.<style>.source = "user-tweaked"`.
3. For each `missingFile`: invoke `generate` via the Skill tool with `callerExtras.regenerateOnly: [".claude/output-styles/<name>.md"]` and `callerExtras.disableOutputStyleTuning: true`. The generator re-emits the style using the snapshot's frontmatter values and the catalog body template (preserving prior tweaks). Append to `generatedArtifacts` if previously dropped.
4. For each `legacyNoFrontmatter`: prompt the developer with a preview:
   > Output style `<name>` has no YAML frontmatter. Apply archetype-inferred defaults (matching the filename stem to the 5-archetype catalog) as a migration? [yes/no/skip]
   On yes: match the filename stem against the catalog (`onboarding-mentor`, `tutorial-guide`, `operator`, `explorer-notes`, `solo-minimal`) to determine the archetype, compose catalog-default frontmatter (`name`, `description`, `keep-coding-instructions: true`, `archetype`, `source: "wizard-default"`), and prepend a YAML frontmatter block to the live file (keeping the body intact). If the filename stem doesn't match any catalog entry, skip with warning `legacy-no-archetype-match:<style>`. Update the snapshot. On no/skip: leave the file as-is; record `outputStyleStatus.warnings[] = "legacy-skipped:<style>"`.

---

## LSP plugin drift application (for items surfaced by Step 4b.8)

Only **new-language additions** are applied on user approval. Uninstalls and stale candidates are informational only — onboard never auto-reinstalls or auto-removes LSP plugins.

1. For each approved `newLanguage` candidate:
   - Invoke `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <plugin-name>`. Merge results into `lspStatus.autoInstalled[]` and `lspStatus.autoInstallFailed[]`.
   - Append the plugin to `.claude/onboard-lsp-snapshot.json` `recommended[]` AND `accepted[]`, preserving alphabetical sort.
   - Append the plugin to `lspStatus.generated[]`.
2. For `uninstalled` findings: no action. Log once: "LSP plugin `<name>` was uninstalled since last run — rerun `/onboard:evolve` if you want to reinstall."
3. For `staleCandidate` findings: no action. Log once.

---

## Built-in skills drift application (for items surfaced by Step 4b.9)

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

---

## Artifact gap regeneration (for items surfaced by Step 4b.2)

Invoke the `generate` skill via the Skill tool with a narrow `callerExtras.regenerateOnly` payload listing the missing artifact paths. **Construct the context with top-level `version: 3`** — `generate` is v3-only as of 3.0.0 and rejects a missing/other `version`. Carry `source`, `projectPath`, and `callerExtras` (with `regenerateOnly`), plus the `wizardAnswers` recorded in `onboard-meta.json`; this is a snapshot re-emit, so no `research` object is needed. Generate honors the `regenerateOnly` scope and only writes the listed files. After regeneration, verify each file is present on disk and carries a fresh maintenance header.

> This `version: 3` + `regenerateOnly` construction is the single authoritative shape for every `onboard:generate` call made by `update` and `evolve` — the per-component missing-file steps elsewhere in this file (skills / agents / output-styles / standalone hooks / MCP) and the equivalent steps in `evolve/SKILL.md` all use it.

---

## New best-practice additions (for items surfaced by Step 4b.3)

Invoke the `generate` skill with `callerExtras.regenerateOnly` scoped to the new artifact paths. Same flow as artifact gap regeneration — the difference is only in how the candidate list was computed.
