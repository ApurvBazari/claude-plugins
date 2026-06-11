# Drift Classification — Step 4b Procedures

Verbatim classification procedures for each drift detector in Step 4b. Each section records the full read-inputs, classify, and record contract for its drift type. Control flow (which sections run, ordering, deferred-to-Step-7 semantics) lives in SKILL.md.

---

## 4b.1: Plugin Drift

Follow `../generation/references/plugin-drift-detection.md` for the full procedure. Summary for update:

1. **Resolve baseline** using the caller order for `update`: first `.claude/onboard-meta.json.detectedPlugins.installedPlugins`, then `.claude/onboard-meta.json.callerExtras.installedPlugins`, else empty.
2. **Probe current state** against the Known Plugin Probe List in `../generation/references/plugin-detection-guide.md`. Also probe any plugin in the baseline that isn't in the known list.
3. **Compute diff** — produce the `driftReport` object described in `plugin-drift-detection.md` § Output Schema.
4. **Note the baseline source**. If the baseline was empty, flag the findings section with "Plugin Integration not tracked before — all detected plugins offered as new additions."

Record `driftReport.added`, `driftReport.removed`, and the derived `qualityGatesNext` / `phaseSkillsNext` / `coveredCapabilitiesNext` for Step 7.

---

## 4b.2: Artifact Gaps

Re-walk `onboard-meta.json.generatedArtifacts`. For each entry:

1. Check that the file still exists on disk.
2. If missing and the entry does **not** have a `deletedByUser: true` flag, mark it as a gap candidate.
3. If missing and `deletedByUser: true` is set, skip silently — the developer opted out.

This complements the existing "maintenance header removed" detection in Step 2: Step 2 flags user-customized files, 4b.2 flags user-deleted / lost files. No overlap.

---

## 4b.3: New Best-Practice Additions

Compare the current project against the built-in generation reference guides (`../generation/references/claude-md-guide.md`, `rules-guide.md`, `hooks-guide.md`, `skills-guide.md`, `agents-guide.md`). Surface only items that:

- Appear in the reference guides as a recommended artifact for the project's stack/complexity, AND
- Are not present in `onboard-meta.json.generatedArtifacts`, AND
- Are not present on disk under `.claude/`

Keep this narrow — do not parse the live WebFetch output to infer new recommendations. The reference guides are the stable source. WebFetch continues to drive wording/pattern updates as before.

---

## 4b.4: MCP Drift

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

---

## 4b.5: Skill Frontmatter Drift

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

---

## 4b.6: Agent Frontmatter Drift

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

---

## 4b.7: Output Style Drift

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

---

## 4b.8: LSP Plugin Drift

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

---

## 4b.9: Built-in Skills Drift

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
