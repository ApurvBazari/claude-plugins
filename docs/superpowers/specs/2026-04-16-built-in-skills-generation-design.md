# Built-in Claude Code Skills in Generated CLAUDE.md

**Date:** 2026-04-16
**Status:** Approved
**Scope:** Onboard 1.9.0 — closes P1 (`/loop` + `/schedule`) and P2 (bundled Anthropic skills) audit items
**Branch:** `feat/onboard-builtin-skills`

---

## Problem

The onboard plugin generates CLAUDE.md with a Plugin Integration section documenting installed third-party plugins, but never mentions Claude Code's own built-in skills (`/loop`, `/schedule`, `/simplify`, `/debug`, `/pr-summary`, `/claude-api`, `/explain-code`, `/codebase-visualizer`, `/batch`). Developers onboarded via `/onboard:init` don't discover these capabilities.

## Solution

Add full-pipeline support for built-in skill recommendations: reference catalog, wizard Phase 5.7 with per-skill toggles, content rule #8 in Plugin Integration, standalone section fallback for plugin-less projects, snapshot file, drift detection in update/evolve, telemetry, and forge callerExtras escape hatch.

---

## Skill Classification

### Tiers

| Tier | Skill | Description | Detection signal | Pre-checked? |
|------|-------|-------------|-----------------|-------------|
| Core | `/loop` | Run a prompt on a recurring interval | Always | Yes |
| Core | `/simplify` | Review and simplify recently changed code | Always | Yes |
| Core | `/debug` | Systematic debugging of bugs and test failures | Always | Yes |
| Core | `/pr-summary` | Summarize PR changes for review | Always | Yes |
| Extra | `/schedule` | Create scheduled remote agents (cron) | CI/CD or deploy frequency detected | If signal fires |
| Extra | `/claude-api` | Build/debug Anthropic SDK integrations | `anthropic` or `@anthropic-ai/sdk` in deps | If signal fires |
| Extra | `/explain-code` | Deep code explanation with context | Complexity ≥ medium OR >200 files | If signal fires |
| Extra | `/codebase-visualizer` | Visualize codebase architecture | >200 files or monorepo | If signal fires |
| Extra | `/batch` | Batch operations across files | >50 source files | If signal fires |

### Detection Source

All detection signals are derived from the existing codebase analysis report — no new probe script needed. Fields used:

- File count → `analysisReport.structure.totalFiles` or source file count
- Complexity → `analysisReport.complexity.overall`
- CI/CD → `analysisReport.stack.ciCd` or presence of `.github/workflows/`
- Dependencies → `analysisReport.stack.dependencies` (package.json, requirements.txt, pyproject.toml, go.mod)
- Monorepo → `analysisReport.structure.monorepo` or presence of `packages/` / `apps/`

---

## Reference Catalog

**New file:** `onboard/skills/generation/references/built-in-skills-catalog.md`

For each skill:
- Name, one-line description, tier (core/extra)
- Detection signal with field references into the analysis report
- Stack-specific example templates (4 categories):

| Stack category | Matching condition | Example style |
|---|---|---|
| Frontend (React/Next/Vue) | Frontend framework in analysis | HMR, component testing, dev server examples |
| Backend (Node/Python/Go) | Backend framework or API routes | API health, migration, test watching examples |
| CLI/tooling | CLI entry point detected | Flag parsing, subcommand batch examples |
| General (fallback) | No specific stack match | Stack-neutral examples |

The generation skill picks the example matching the detected primary stack (highest file count).

---

## Wizard Phase 5.7: Built-in Skills

Slots between Phase 5.6 (LSP) and Phase 6 (Summary).

### Flow

1. Run detection against analysis report (pure data lookup, no script)
2. Build candidate list: 4 core (always) + N extras (signal-dependent, 0-5)
3. Present one `AskUserQuestion` multiSelect:

> Which built-in Claude Code skills would you like documented in your project's CLAUDE.md?
>
> - `/loop` — run a prompt on a recurring interval **(core)** **[checked]**
> - `/simplify` — review and simplify changed code **(core)** **[checked]**
> - `/debug` — systematic debugging **(core)** **[checked]**
> - `/pr-summary` — summarize PR changes **(core)** **[checked]**
> - `/schedule` — create scheduled remote agents **(detected: CI/CD present)** **[checked]**
> - `/batch` — batch operations across files **(detected: 247 source files)** **[checked]**
> - `/explain-code` — deep code explanation **[unchecked]**

4. Record as `wizardAnswers.builtInSkills` (string array of accepted skill names, e.g., `["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"]`)

### Mode Behaviors

- **Quick Mode:** Accept all detected candidates (core + fired extras). Skip the prompt.
- **Preset path:** Pre-filled per preset profile (Minimal: core only; Standard: core + fired extras; Comprehensive: all 9).
- **Headless:** Read `callerExtras.builtInSkills` (explicit list) or `callerExtras.disableBuiltInSkills` (skip entirely).
- **Exchange budget:** One `AskUserQuestion` call max. If exchange count is at 6, accept all detected — Quick Mode semantics.

### Output Schema Addition

```json
{
  "builtInSkills": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"]
}
```

An empty array means "candidates existed but developer declined all". An absent field means "Quick Mode / headless — full detected list is the implicit accept".

---

## Generation — Content Rule #8 + Phase 7d

### Content Rule #8

Added to the Plugin Integration section spec as the 8th content rule:

8. **Built-in Claude Code skills** (always — these are Anthropic-provided, not plugin-dependent): Add a `### Built-in Claude Code skills` subsection. For each skill in `builtInSkillsStatus.generated[]`, emit: skill name, one-line description, and a project-specific example from the catalog (matched to detected stack). Use the same narrative voice as other Plugin Integration subsections — answer "when would you use this on your project?" not just list names.

### Two Placement Paths

- **With plugins** (`effectivePlugins` non-empty): Emit as `### Built-in Claude Code skills` inside `<!-- onboard:plugin-integration:start/end -->` markers. Last subsection, after Output styles (#7), before the closing marker.
- **Without plugins** (`effectivePlugins` empty): Emit as a standalone `## Built-in Claude Code skills` section with its own `<!-- onboard:builtin-skills:start/end -->` markers, placed after the last onboard-generated section (identified by maintenance header), before any user-added trailing content — same insertion rule as first-time Plugin Integration creation.

**Marker invariant:** The `<!-- onboard:builtin-skills:start/end -->` markers are always present in CLAUDE.md regardless of placement path. When plugins exist, they live inside `<!-- onboard:plugin-integration:start/end -->`. When plugins are absent, they live as a top-level section. All drift handlers are marker-based — they find the markers, read the current placement context, and regenerate.

### Phase 7d: Built-in Skills Emission

Runs after Phase 7c (LSP):

1. Resolve accepted skills from `wizardAnswers.builtInSkills` or `callerExtras.builtInSkills`. If `callerExtras.disableBuiltInSkills: true`, skip entirely and record `builtInSkillsStatus.skipped`.
2. For each accepted skill, pick the stack-specific example from `built-in-skills-catalog.md`.
3. Emit the subsection (inside Plugin Integration or standalone, per placement path).
4. Write `.claude/onboard-builtin-skills-snapshot.json`.
5. Record `builtInSkillsStatus` in `onboard-meta.json`.

---

## Snapshot File

**Path:** `.claude/onboard-builtin-skills-snapshot.json`

```json
{
  "recommended": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule", "/batch"],
  "accepted": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"]
}
```

Plain JSON, no `_generated` header — matches LSP snapshot format exactly. Both arrays sorted alphabetically.

- `recommended` — all candidates detection produced (core + fired extras)
- `accepted` — what the developer chose in Phase 5.7

---

## Telemetry

**Key:** `builtInSkillsStatus` in `onboard-meta.json`

```json
{
  "builtInSkillsStatus": {
    "planned": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule", "/batch"],
    "generated": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"],
    "skipped": ["/batch"],
    "warnings": [],
    "detectionSignals": {
      "/schedule": "ci-cd-detected",
      "/batch": "source-file-count:247"
    }
  }
}
```

---

## Drift Detection & Application

### Update Step 4b.9: Built-in Skills Drift

Re-run detection against the current codebase state. Compare against snapshot:

| Classification | Condition | Action |
|---|---|---|
| `newSkill` | Detection fires for a skill not in `snapshot.recommended` | Offer to add |
| `newlyRelevant` | Skill was in `recommended` but not `accepted`, now has stronger signal | Surface as suggestion |
| `staleCandidate` | Skill in `recommended` but detection signal no longer fires | Informational only |
| `in-sync` | No change from snapshot | No action |

Record as `builtInSkillsDrift.{newSkills, newlyRelevant, staleCandidates}[]` for Step 7.

### Update Step 7 Application

Only `newSkill` additions applied on user approval:
1. Add skill to `builtInSkillsStatus.generated[]`.
2. Regenerate the CLAUDE.md built-in skills subsection by finding `<!-- onboard:builtin-skills:start/end -->` markers and rewriting the content between them.
3. Update `.claude/onboard-builtin-skills-snapshot.json` — append to both `recommended` and `accepted`.

**Placement migration** (handled in Step 7 alongside application):
- **Standalone → Plugin Integration**: If `<!-- onboard:builtin-skills:start/end -->` markers exist as a top-level section AND `effectivePlugins` is now non-empty, remove the standalone region and regenerate the built-in skills content as the last subsection inside `<!-- onboard:plugin-integration:start/end -->`. Surface as a named migration action in the Step 6 upgrade offer menu.
- **Plugin Integration → standalone**: If `effectivePlugins` becomes empty and all plugins are removed, migrate the built-in skills content out to a standalone section before stripping the Plugin Integration markers.
- **Empty accepted list**: If `builtInSkillsStatus.generated[]` becomes empty (all skills declined), strip the `<!-- onboard:builtin-skills:start/end -->` markers and their content entirely. No snapshot file written.

Stale candidates and `newlyRelevant` are informational only.

### Update Step 8 Metadata Refresh Addition

Add to the Step 8 metadata refresh bullets:

**If built-in skills drift was applied in Step 7** — refresh top-level `builtInSkillsStatus`: append newly-accepted skills to `builtInSkillsStatus.generated[]`, update `detectionSignals` for new entries. Update `.claude/onboard-builtin-skills-snapshot.json` (both `recommended` and `accepted`) to reflect the new baseline. `builtInSkillsStatus.skipped[]` is preserved from prior runs — never rewritten during update.

### Update Findings Report Template Addition

```
> ### Built-in Skills Drift (from Step 4b.9)
> - **New skills detected**: [list or "none"] — built-in skills newly relevant to the project
> - **Newly relevant**: [list or "none"] — previously declined skills with stronger signals now
> - **Stale candidates**: [list or "none"] — skills whose detection signals no longer fire
> - Impact: new skills can be added to CLAUDE.md on approval.
```

### Evolve Step 2h: Apply Built-in Skills Drift

Same classification as update 4b.9. Auto-apply rules (bounded by opt-in posture):

- **newSkill** → **re-prompt** (not silent-add). Batch all `newSkill` entries into **one `AskUserQuestion` multiSelect** (same format as wizard Phase 5.7), not one prompt per skill. Consistent with evolve Step 2g's batched LSP pattern.
- **staleCandidate** → no action. Log once.
- **newlyRelevant** → no action (developer already declined). Log once as a suggestion.

**Placement migration**: Same rules as update Step 7 — handle Standalone ↔ Plugin Integration migration based on current `effectivePlugins` state.

Update `onboard-meta.json.builtInSkillsStatus` to reflect changes. The Step 2b.3 forge-meta mirror path picks up the refreshed `builtInSkillsStatus`.

### Evolve Guard Pre-check Addition

Add built-in skills snapshot check to the guard condition (line 17 — append to the compound AND chain):

```
AND no built-in skills drift was detected (Step 2h pre-check against
`.claude/onboard-builtin-skills-snapshot.json`)
```

Also update the guard's user-facing explanatory message (lines 19-22) to mention the built-in skills snapshot check alongside existing snapshot mentions.

### Evolve Step 3 Show Diff Addition

Add a built-in skills entry to the Step 3 Show Diff block so applied changes are visible:

```
- Built-in skills: added `/claude-api` to CLAUDE.md subsection
```

---

## CallerExtras & Forge Integration

### Escape Hatches

- `callerExtras.disableBuiltInSkills: true` → skip Phase 7d entirely, record `builtInSkillsStatus.skipped = [{ reason: "caller-disabled" }]`
- `callerExtras.builtInSkills: ["/loop", "/debug"]` → headless skill list, skip wizard Phase 5.7

### Forge Default

`disableBuiltInSkills: true` in forge's Step 1 callerExtras template. Rationale: scaffolded projects have placeholder code, so detection signals are premature (same reasoning as LSP).

Forge handoff message includes: "Run `/onboard:evolve` after adding source files to get built-in skill recommendations."

### Forge `toolingFlags` Mirror

Item 11: `generated.toolingFlags.builtInSkillsStatus` → mirror `onboard-meta.json.builtInSkillsStatus` verbatim. If `onboard-meta.json` has no `builtInSkillsStatus` yet (older project predating onboard 1.9.0), skip this field silently — do not invent an empty object.

---

## Files Touched

| File | Change type | Description |
|------|------------|-------------|
| `onboard/skills/generation/references/built-in-skills-catalog.md` | **New** | 9-skill catalog with tiers, detection signals, stack-specific examples |
| `onboard/skills/wizard/SKILL.md` | Modify | Phase 5.7 section + output schema update + annotation paragraph |
| `onboard/skills/generation/SKILL.md` | Modify | Content rule #8, Phase 7d emission, standalone section path, checklist |
| `onboard/skills/generation/references/claude-md-guide.md` | Modify | Built-in Skills Reference section (after LSP Support Reference) |
| `onboard/skills/generate/SKILL.md` | Modify | `builtInSkills` in wizardAnswers schema + `disableBuiltInSkills`/`builtInSkills` in callerExtras schema |
| `onboard/skills/update/SKILL.md` | Modify | Step 4b.9, findings report, Step 6 menu, Step 7 application (incl. migration), Step 8 metadata refresh |
| `onboard/skills/evolve/SKILL.md` | Modify | Guard condition + message, Step 2h, Step 2b.3 mirror item 11, Step 3 Show Diff entry |
| `forge/skills/tooling-generation/SKILL.md` | Modify | `disableBuiltInSkills: true` in callerExtras, `builtInSkillsStatus` inside toolingFlags JSON, handoff message |
| `onboard/CLAUDE.md` | Modify | Add `built-in-skills-catalog.md` to Reference Organization list |
| `onboard/.claude-plugin/plugin.json` | Modify | Version bump → 1.9.0 |
| `.claude-plugin/marketplace.json` | Modify | Version sync → 1.9.0 |

**No new scripts.** Detection uses existing analysis report data.
**No forge code changes beyond callerExtras + toolingFlags + handoff.**

---

## Verification

1. **Wizard flow:** Run `/onboard:init` on a test project with CI/CD and >50 files. Confirm Phase 5.7 presents the multiSelect with core skills pre-checked and relevant extras checked.
2. **Generation (with plugins):** Confirm `### Built-in Claude Code skills` subsection appears inside Plugin Integration with stack-specific examples.
3. **Generation (without plugins):** Run on a project with no plugins installed. Confirm standalone `## Built-in Claude Code skills` section appears with its own markers.
4. **Snapshot:** Confirm `.claude/onboard-builtin-skills-snapshot.json` is written with correct recommended/accepted arrays.
5. **Telemetry:** Confirm `builtInSkillsStatus` in `onboard-meta.json` with correct planned/generated/skipped/detectionSignals.
6. **Quick Mode:** Confirm Phase 5.7 is skipped and all detected candidates are accepted.
7. **Headless mode:** Pass `callerExtras.builtInSkills: ["/loop"]` and confirm only `/loop` appears in output.
8. **Disable escape hatch:** Pass `callerExtras.disableBuiltInSkills: true` and confirm Phase 7d is skipped with correct telemetry.
9. **Update drift:** Add a dependency on `@anthropic-ai/sdk` to a previously-onboarded project. Run `/onboard:update`. Confirm Step 4b.9 flags `/claude-api` as `newSkill`.
10. **Evolve drift:** Same setup. Run `/onboard:evolve`. Confirm Step 2h re-prompts for `/claude-api` (not silent-add).
11. **Pre-existing fixture safety:** Onboard a project, hand-edit the built-in skills subsection in CLAUDE.md, run `/onboard:update`. Confirm the edit is classified as `userEdited` and not overwritten.

---

## Edge Cases

1. **All extras decline:** Developer unchecks all extras but keeps core. `accepted` = 4 core skills, `skipped` = extras. Subsection still emits with 4 entries.
2. **All skills decline:** Developer unchecks everything. `builtInSkills = []`. No subsection emitted. `builtInSkillsStatus.generated = []`, `skipped = [all]`. No snapshot file written (nothing to track).
3. **Plugin Integration regeneration:** When `/onboard:update` refreshes Plugin Integration, built-in skills subsection is regenerated alongside other content rules using the same `builtInSkillsStatus.generated` data.
4. **Standalone → Plugin Integration migration:** Project starts with no plugins (standalone section), later installs plugins and runs `/onboard:update`. The standalone `<!-- onboard:builtin-skills:start/end -->` markers are removed and the subsection moves inside Plugin Integration markers.
5. **Exchange budget exhaustion:** If wizard reaches exchange 6 before Phase 5.7, accept all detected candidates (Quick Mode semantics).
