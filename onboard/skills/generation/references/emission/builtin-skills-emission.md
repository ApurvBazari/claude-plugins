<!-- Extracted from ../../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Built-in Claude Code Skills — emission Step 4

Follow `../catalogs/built-in-skills-catalog.md` for the 9-skill catalog, tier classification (core vs extra), detection signals, and stack-specific example templates.

**When to run**: After emission Step 3 (LSP) and before Hooks. Runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — explicit caller list** | `callerExtras.builtInSkills` present | Use it verbatim as the accepted list. Empty array = "candidates existed but declined all" → `builtInSkillsStatus: { status: "declined", accepted: [] }`. Non-empty array → `status: "documented"` (CLAUDE.md subsection is the artifact). |
| **Path A — wizard answer** | `wizardAnswers.builtInSkills` present | Use wizard's accepted list. Same `declined` semantics if empty; `"documented"` status when non-empty. |
| **Path B — internal generation default** | wizard absent AND callerExtras list absent | Accept the full candidate list (4 core + N fired extras). Emit CLAUDE.md subsection + snapshot + telemetry `status: "documented"`. **Built-in skills' core tier always fires; this path NEVER produces an empty result.** |
| **Path SKIP — caller-disabled** | `callerExtras.disableBuiltInSkills === true` | No CLAUDE.md subsection, no snapshot. Telemetry: `builtInSkillsStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [] }`. **Telemetry IS still written.** |

**Inputs**:
- `callerExtras.disableBuiltInSkills` (optional, programmatic) — see Path SKIP above; programmatic callers may pass `true` by default for placeholder code in scaffolds
- `callerExtras.builtInSkills` (optional, programmatic) — see Path A above
- `wizardAnswers.builtInSkills` (optional) — see Path A above

**Telemetry contract**: `builtInSkillsStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | documented | skipped | declined | failed`) per the Default behavior matrix in `../../../generate/SKILL.md`. **Built-in skills is the primary user of the `"documented"` value** — its "artifact" is a CLAUDE.md subsection rather than a separate file + snapshot, so `"documented"` is semantically more accurate than `"emitted"` when the phase runs. See emission Step 4 below for the firing paths.

**Suppression**: Skip entirely when `callerExtras.disableBuiltInSkills: true` (scaffolded projects have placeholder code so detection signals are premature). When skipped, still emit a `builtInSkillsStatus` entry in meta.json:

```json
{
  "builtInSkillsStatus": {
    "planned": [],
    "generated": [],
    "skipped": [{ "skill": "*", "reason": "caller-disabled" }],
    "warnings": [],
    "detectionSignals": {}
  }
}
```

**Step 1 — Detect candidates.** Run detection against the codebase analysis report:

- **Core skills** (`/loop`, `/simplify`, `/debug`, `/pr-summary`): always candidates. No detection signal needed.
- **Extra skills**: check each signal per the catalog's "Detection signal" and "Analysis report field" columns. Record which signals fired and which did not.

Build the full candidate list: 4 core + N extras (0-5) whose signals fired. Record as `planned[]`.

**Step 2 — Resolve accepted list.** Determine which skills to generate from the candidate list:

- If `callerExtras.builtInSkills` is present → use it verbatim as the accepted list (programmatic mode). An empty array means "declined all".
- Else if `wizardAnswers.builtInSkills` is present → use it as the accepted list.
- Else (internal generation / absent field) → accept the full candidate list (all core + fired extras).

Record as `generated[]`. Skills in `planned[]` but not in `generated[]` go into `skipped[]` with `reason: "user-declined"`.

**Step 3 — Determine placement path.**

- If `effectivePlugins` is non-empty → emit as `### Built-in Claude Code skills` subsection inside `<!-- onboard:plugin-integration:start/end -->`, after the `### Output styles` subsection (content rule #7), before the Plugin Integration closing marker.
- If `effectivePlugins` is empty → emit as a standalone `## Built-in Claude Code skills` section, placed after the last onboard-generated section (identified by maintenance header), before any user-added trailing content.

In both cases, wrap the content in `<!-- onboard:builtin-skills:start -->` / `<!-- onboard:builtin-skills:end -->` markers. The markers are always present regardless of placement path — this makes all drift handlers marker-based.

**Step 4 — Compose the subsection.** For each skill in `generated[]`:

1. Look up the skill in the catalog to get the one-line description.
2. Select the stack-specific example from the catalog's four template tables (frontend / backend / CLI / general), picking the table that matches the project's primary detected stack (highest source file count). If no specific stack matches, use the general fallback.
3. Emit in this format:

```markdown
- `/skill-name` — one-line description.
  Example: project-specific example from catalog.
```

Use rich narrative voice matching the project's autonomy level (per the Tone rules). The subsection header should briefly explain what built-in skills are: "These Anthropic-provided skills are available in every Claude Code session — no plugin install required."

**Step 5 — Write drift snapshot.** Write `.claude/onboard-builtin-skills-snapshot.json`:

```json
{
  "recommended": ["/batch", "/debug", "/loop", "/pr-summary", "/schedule", "/simplify"],
  "accepted": ["/debug", "/loop", "/pr-summary", "/schedule", "/simplify"]
}
```

Plain JSON, no `_generated` header — matches LSP snapshot format. Both arrays sorted alphabetically. Add the snapshot path to `generatedArtifacts` in `onboard-meta.json`.

**Step 6 — Record telemetry.** Add `builtInSkillsStatus` to `onboard-meta.json` alongside `hookStatus`, `mcpStatus`, `skillStatus`, `agentStatus`, `outputStyleStatus`, and `lspStatus`. Use `status: "documented"` when the phase successfully wrote a CLAUDE.md subsection (the primary artifact type for emission Step 4 — no separate file), `status: "declined"` when accepted list is empty, `status: "skipped"` for SKIP-PHASE, `status: "failed"` on errors. The `"documented"` value replaces the earlier `"skipped", reason: "built-in-skills-are-user-level-no-project-artifact"` semantic that broke downstream consumers (release-gate finding B13, 2026-04-17).

```json
{
  "builtInSkillsStatus": {
    "status": "documented",
    "documentedIn": "CLAUDE.md",
    "planned": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule", "/batch"],
    "generated": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"],
    "skipped": [{ "skill": "/batch", "reason": "user-declined" }],
    "warnings": [],
    "detectionSignals": {
      "/schedule": "ci-cd-detected",
      "/batch": "source-file-count:247"
    }
  }
}
```

`detectionSignals` only records extras whose signal fired (they appear in `planned`). Core skills don't need detection entries since they're always included.

**`skipped[].reason` values**: `user-declined` | `caller-disabled` | `detection-empty`.

**Step 7 — Post-emit stdout summary.** Print a terse block listing accepted skills and the placement path (inside Plugin Integration or standalone). Keep under 4 lines.
