---
name: check
description: Greenfield project health check — reports in-flight session state, artifact integrity, pending drift, plugin integration coverage, and stack freshness. Use when user asks about greenfield status, wants to see if their scaffold is healthy, checks on an in-progress session, or asks whether their CI/CD and hooks are wired. Read-only — safe to auto-invoke.
---

# Check Skill — Project Health Check

You are running the Greenfield status skill. This provides a quick overview of the project's state — whether a greenfield session is in progress, whether setup completed, and (if complete) the project's AI tooling health, pending drift, and setup metadata.

---

## Step 1: Check for in-flight session

Before checking completed setup, check for an in-progress session at `.claude/greenfield-state.json`.

**If it exists and `currentPhase !== "complete"`**: there's an in-progress session. Report it prominently at the top of the status output:

> **🟡 Greenfield session in progress** (not yet complete)
>
> **Project**: [context.appDescription or "unnamed"]
> **Started**: [createdAt]
> **Last updated**: [updatedAt] ([time delta])
> **Currently at**: [currentPhase] / [currentStep]
> [if currentPhase === "phase-1.8-synthesis-review"]: **Reviewing synthesis for**: [currentSynthesisPhase, e.g., "architecturalFraming (Architectural Framing)", "dataArchitecture (Data Architecture)", "apiIntegration (API & Integration)", "cicdAndDelivery (CI/CD & Delivery)", "architecturalValidation (Architectural Validation)"]
> **Completed steps**: [list from completedSteps]
> [if context.syntheses is non-empty]: **Approved syntheses**: [keys of syntheses, e.g., "architecturalFraming (approved 2026-05-14T10:00Z)", "cicdAndDelivery (approved 2026-05-13T16:30Z)"]
> **Next action**: [nextAction]
> **Research mode**: [research.mode]
>
> **Phase Synthesis Status**
> [For each phase in phaseStatus, render one row of the table; omit phases that are "not-yet-walked" if the list would be noisy — show at least all non-"not-yet-walked" entries]:
>
> | Phase | Status | Approved at | Stale reason |
> |---|---|---|---|
> | architecturalFraming | [status] | [approvedAt or —] | [staleReason or —] |
> | dataArchitecture | [status] | [approvedAt or —] | [staleReason or —] |
> | apiIntegration | [status] | [approvedAt or —] | [staleReason or —] |
> | auth | [status] | [approvedAt or —] | [staleReason or —] |
> | privacy | [status] | [approvedAt or —] | [staleReason or —] |
> | security | [status] | [approvedAt or —] | [staleReason or —] |
> | runtimeOperations | [status] | [approvedAt or —] | [staleReason or —] |
> | cicdAndDelivery | [status] | [approvedAt or —] | [staleReason or —] |
> | architecturalValidation | [status] | [approvedAt or —] | [staleReason or —] |
>
> [if ANY phase.status === "stale"]: ⚠️ **Stale phases detected** — re-walk on next entry or use `/greenfield:pickup` to resume.
>
> **To continue**: run `/greenfield:pickup`
> **To abandon and start over**: delete `.claude/greenfield-state.json` (irreversible — will lose all gathered context)

Then stop here — do not try to also report post-scaffold health, because the scaffold may not exist yet.

**If it exists and `currentPhase === "complete"`**: the session finished. Proceed to Step 2 to report the full post-scaffold health.

**If it doesn't exist**: proceed to Step 2 (the project may have been set up before greenfield had state tracking, so `greenfield-meta.json` alone is sufficient).

---

## Step 2: Check for Setup

Read `.claude/greenfield-meta.json`:

**If not found**:

> This project hasn't been set up with Greenfield yet.
>
> Run `/greenfield:start` to scaffold a new project with AI-native tooling.

Stop here.

**Note on file distinction**: `.claude/greenfield-meta.json` is the persistent setup metadata (stack, context, generated artifacts, plugin list) used for health checks and status reporting. `.claude/greenfield-state.json` is ephemeral resume state, written during an in-flight session and only relevant for `/greenfield:pickup`. Step 1 checks `greenfield-state.json`; Step 2 onward checks `greenfield-meta.json`. If both exist with `greenfield-state.json.currentPhase === "complete"`, the session finished successfully and `greenfield-state.json` can be removed as garbage (optional — it's harmless to keep).

---

## Step 3: Parse Metadata

Extract from `greenfield-meta.json`:
- `version` — Greenfield version used
- `createdAt` — When the project was scaffolded
- `context.stack` — Tech stack details
- `context.deployTarget` — Deployment target
- `context.branchingStrategy` — Git branching strategy
- `context.autoEvolutionMode` — How tooling updates work
- `generated.toolingFlags.tooling` — List of generated tooling files (formerly `generated.tooling` before the L5 alignment in the 2026-04-16 release-gate sweep)
- `generated.toolingFlags.cicd` — List of CI/CD workflows (formerly `generated.cicd`)
- `generated.toolingFlags.harness` — List of harness artifacts (init.sh, docs/feature-list.json, docs/progress.md)
- `webResearch.stackVersion` — Framework version at scaffold time

---

## Step 4: Check Artifact Integrity

Verify all generated artifacts still exist and are non-empty:

1. **CLAUDE.md** — exists, non-empty, contains maintenance header
2. **Path-scoped rules** — each `.claude/rules/*.md` file exists
3. **Skills** — each `.claude/skills/*/SKILL.md` file exists
4. **Agents** — each `.claude/agents/*.md` file exists
5. **Hooks** — `.claude/settings.json` exists, contains expected hook entries
6. **CI/CD** — `.github/workflows/*.yml` files exist (if deploying)
7. **Audit scripts** — `.github/scripts/audit-tooling.sh` exists (if deploying)
8. **Drift scripts** — `.claude/scripts/detect-*.sh` files exist

Report any missing or empty files.

---

## Step 4.5: Check Plugin Integration Coverage

For projects where `greenfield-meta.json.installedPlugins` is non-empty, assess how well the Plugin Integration layer is wired:

1. **Read root `CLAUDE.md`** — look for `<!-- onboard:plugin-integration:start -->` marker. If present, record line count of the delimited region. If absent, mark Plugin Integration section as **missing**.
2. **Read `.claude/settings.json`** — inspect `hooks.SessionStart`, `hooks.PreToolUse`, `hooks.Stop` for quality-gate entries generated from `qualityGates` (script paths matching `plugin-integration-reminder.sh`, `feature-start-detector.sh`, `pre-commit-*.sh`, `post-feature-*.sh`). Record which are present.
3. **Read `greenfield-meta.json.generated.toolingFlags.hookStatus`** — onboard persists a canonical `hookStatus` telemetry object. Use it directly for the coverage report. Fields:
   - `planned[event]` — **integer** — how many hooks onboard expected to generate for that event key (only counts `qualityGates`-derived hooks; format/lint/greenfield-internal hooks are out of scope)
   - `generated[event]` — **array of script basenames** — list of hook scripts actually wired under that event. Use `len(generated[event])` to get the count.
   - `skipped[]` — list of `{event, skill, reason}` entries for hooks that were dropped (e.g., plugin missing, condition unsatisfied, empty critical-dirs)
   - `warnings[]` — operator-facing messages about soft issues during generation
   - `downgradeApplied` (optional) — object of `{rule, affectedEntries}` present only when autonomyLevel forced a `preCommit[].mode` downgrade. Absent or `null` means no downgrade fired.
4. **Check phase-recommended plugins**: derive the expected plugin set from `greenfield-meta.json.context` (stack, autonomyLevel, etc.) using the Step 1 match logic from `plugin-discovery/SKILL.md`. Any phase-recommended plugin NOT in `installedPlugins` is reported as "missing".
6. **Check critical dirs**: if `qualityGates.featureStart.criticalDirs` was populated, verify those directories exist on disk. If any are missing, the feature-start detector will never fire for them.
7. **Check plugin drift**: compare `greenfield-meta.json.generated.toolingFlags.installedPlugins` against currently-installed plugins via filesystem probe (same strategy as `/onboard:evolve` Step 0: probe `${CLAUDE_PLUGIN_ROOT}/../<plugin>` for each known plugin). Record added/removed counts for the summary.

Build a structured report block for inclusion in Step 7's summary.

---

## Step 5: Check Pending Drift

Read `.claude/greenfield-drift.json`:

- If entries exist: report count and categories (dependencies, configs, structure)
- If no entries or file missing: report "No pending drift"

---

## Step 6: Check Stack Freshness

Compare `webResearch.stackVersion` from metadata against current `package.json` (or equivalent manifest):
- If the framework version has been bumped since scaffold, note it
- If a major version change occurred, recommend re-running web research

---

## Step 7: Present Summary

> **Greenfield Status**
>
> **Project**: [appDescription]
> **Stack**: [framework] v[version] (scaffolded [date])
> **Deploy**: [target] | **Branching**: [strategy]
> **Auto-evolution**: [mode]
>
> **Phase Synthesis Status**
> | Phase | Status | Approved at | Stale reason |
> |---|---|---|---|
> | architecturalFraming | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | dataArchitecture | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | apiIntegration | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | auth | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | privacy | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | security | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | runtimeOperations | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | cicdAndDelivery | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
> | architecturalValidation | [status from phaseStatus or —] | [approvedAt or —] | [staleReason or —] |
>
> [If any phase has status "stale"]: ⚠️ **Stale phases** — use `/greenfield:pickup` to re-walk them.
> [If phaseStatus is absent from state file (pre-T9 session)]: phaseStatus not tracked (pre-3.0.0-alpha.3 session — re-run synthesis to populate).
>
> **Tooling Health**
> | Artifact | Status |
> |---|---|
> | CLAUDE.md | [ok / missing / empty] |
> | Rules ([N]) | [ok / N missing] |
> | Skills ([N]) | [ok / N missing] |
> | Agents ([N]) | [ok / N missing] |
> | Hooks | [ok / missing entries] |
> | CI/CD | [ok / N/A (local project)] |
> | Synthesis records (`docs/adr/*.html`) | [N found (expected 9: architectural-framing.html, data-architecture.html, api-integration.html, auth.html, privacy.html, security.html, runtime-operations.html, cicd-and-delivery.html, architectural-validation.html) / none / docs/adr/ missing] |
> | Freshness hook (`.git/hooks/pre-commit` marker `# greenfield:synthesis-freshness`) | [installed / not installed — covers all 9 synthesis HTMLs] |
>
> **Pending Drift**: [N entries] or "None"
> [If drift exists]: Run `/greenfield:evolve` to apply updates.
>
> **Plugin Integration Coverage**
> | Field | Status |
> |---|---|
> | Installed plugins | [N] [comma-separated list] |
> | Covered capabilities | [N] [list] |
> | Phase-recommended missing | [list, or "none"] |
> | Plugin Integration section in CLAUDE.md | [ok ([line count] lines) / missing] |
> | Hook wiring (planned → generated) | [sum(planned) / sum(len(generated[event]))] |
> | SessionStart reminder hook | [wired / not wired] [optional: (N skipped)] |
> | Feature-start detector hook | [wired / not wired / (no critical dirs configured)] |
> | preCommit blocking hooks | [N wired / 0 wired (autonomy=exploratory)] [optional: (M skipped, reasons: ...)] |
> | postFeature advisory hook | [wired / not wired] |
> | Critical dirs exist on disk | [all / N missing: list] |
> | Telemetry source | hookStatus |
>
> [If `hookStatus.skipped` is non-empty — list each skipped entry]:
> **Hooks skipped during generation**:
> - [event]: [skill] — [reason]
> - ...
>
> [If `hookStatus.warnings` is non-empty — list each warning]:
> **Warnings**:
> - [warning text]
> - ...
>
> [If `hookStatus.downgradeApplied` is present and non-null — list the rule + affected entries]:
> **Mode downgrades applied**:
> - Rule: [hookStatus.downgradeApplied.rule]
> - Affected entries: [hookStatus.downgradeApplied.affectedEntries joined with ", "]
>
> [If installedPlugins differs from currently-installed plugins (filesystem probe)]:
> Plugin drift detected: [N added, M removed] since last generation.
> Run `/onboard:evolve` to update Plugin Integration section and quality-gate hooks.
>
> [If Plugin Integration section is missing but installedPlugins is non-empty]:
> Plugin Integration section is stale or missing. Run `/onboard:evolve` for a lightweight refresh, or `/onboard:update` for a full re-analysis.
>
> [If Phase 4 was skipped due to engineering plugin absence]:
> Phase 4 skipped: engineering plugin not installed. Install from `knowledge-work-plugins` marketplace if you want lifecycle docs:
> ```
> claude marketplace add knowledge-work-plugins
> claude plugin install engineering
> ```

## Key Rules

- **Never write any file** — this skill is fully read-only. All Steps are observation and reporting only.
- **In-progress session check always runs first** — Step 1 fires before Step 2 (greenfield-meta check). If `greenfield-state.json` exists and `currentPhase !== "complete"`, report the in-progress state and stop; do not also try to report post-scaffold health.
- **Phase synthesis status comes from `phaseStatus` in `greenfield-state.json`** — when reporting the Phase Synthesis Status table, read the `phaseStatus` map directly. If the field is absent (pre-T9 session), report "not tracked" rather than fabricating status values.
- **Plugin drift is detected via filesystem probe, not config alone** — compare `installedPlugins` from `greenfield-meta.json` against a live probe of `${CLAUDE_PLUGIN_ROOT}/../<plugin>` for each known plugin. Discrepancies are reported; the check skill never applies drift changes.
- **`hookStatus` is read from `greenfield-meta.json.generated.toolingFlags.hookStatus`** — use the `planned` / `generated` / `skipped` / `warnings` fields directly for the Plugin Integration Coverage report. Do not recompute hook counts from settings.json; the telemetry object is the authoritative source.

---

## Round 4 Checks

Run these assertions when a Round 4 session is detected (i.e., `greenfield-state.json` exists and its `context.mode` field is present — specifically one or more of `mode.depth`, `mode.coupling`, `mode.domainFormat` — OR any of `phaseStatus.personas` / `phaseStatus.domainModel` is non-absent). Report failures inline in Step 7's summary.

- [ ] If `.claude/greenfield-state.json.mode` is set, verify the block exists with all three fields (`mode.depth`, `mode.coupling`, `mode.domainFormat`). Missing fields = state-shape inconsistency (alpha.4→alpha.5 migration may have been interrupted).
- [ ] If `personas.skipped !== true` AND `phaseStatus.personas.status === "approved"`, verify `docs/adr/personas.html` exists in the scaffolded project. If missing, flag "Personas synthesis not generated despite phase approval — re-run synthesis-review for personas."
- [ ] If `domainModel.deferred !== true` AND `phaseStatus.domainModel.status === "approved"`, verify `docs/adr/domain-model.html` exists. If missing, flag "Domain-model synthesis not generated."
- [ ] If at least one phase has been completed (any `phaseStatus.<id>.status === "approved"`), verify `docs/adr/risks.dependencies.json` exists. The expected risks count is `risks[].length >= number of completed phases that captured a Q_RISK`.
- [ ] If `mode.coupling === "auto-loop"`, verify at least one downstream synthesis HTML in `docs/adr/` contains `sourceRef` annotations (search for the string `source-ref` or `sourceRef` in any `.html` file). If none found, auto-loop ran but didn't trace provenance — flag "Auto-loop coupling chosen but no sourceRef entries found in synthesis outputs."

---

## Round 5 Checks

Run these assertions when a Round 5 session is detected (i.e., `greenfield-state.json` exists and `context.phases.featureRoadmap` or `context.phases.schemaDraftReview` is present, OR the scaffolded project contains a `docs/sprint-contracts/` directory). Report failures inline in Step 7's summary.

### Check R5-1: featureRoadmap completeness (when not skipped)

**Phase:** featureRoadmap
**Severity:** advisory (informational; does not block)

If `context.phases.featureRoadmap.skipped != true`:
- `context.phases.featureRoadmap.horizon` must be set (non-empty string from the enum mvp-only/3-months/6-months/1-year/open-ended)
- `context.phases.featureRoadmap.features[]` must be non-empty
- `context.phases.featureRoadmap.sprint1.featureIds[]` must be non-empty
- `context.phases.featureRoadmap.sprint1.criteria[]` must include at least one entry with `weight = "required"`

If any field is missing, report:
> featureRoadmap is partially populated. Missing: <field list>. Run `/greenfield:pickup` to revisit Step 16, or skip with a deferredReason.

### Check R5-2: schemaDraftReview lockedAt presence (when not skipped)

**Phase:** schemaDraftReview
**Severity:** advisory

If `context.phases.schemaDraftReview.skipped != true`:
- `context.phases.schemaDraftReview.lockedAt` must be set (ISO-8601 timestamp string)
- For every enabled draft (where `drafts.{db|api|event}.skipped != true`), `drafts.{X}.approved` must be `true`

If any draft is unlocked, report:
> Schema/contract drafts are unlocked. Missing approval on: <artifact list>. Run `/greenfield:pickup` to revisit Step 19.

### Check R5-3: sprint-1 contract presence (post-R5 projects)

**Phase:** post-generation
**Severity:** advisory

If `docs/sprint-contracts/` exists in the scaffolded project:
- `docs/sprint-contracts/sprint-1.json` must exist and parse as valid JSON
- The file must contain `sprint: 1`, `name`, `features`, `criteria[]`, and `completionGate`

If missing or malformed, report:
> Sprint-1 contract file missing or invalid. This is expected for pre-R5 scaffolded projects; for post-R5 projects, re-run `/onboard:generate` to regenerate.

---

## Round 6 Checks

### Round 6 health checks (R6 — alpha.7)

| Assertion | Failure mode |
|---|---|
| Frontend trio completeness — when none of `frontendArchitecture/designSystem/uxAccessibilityPerf` are skipped, all three are populated with required fields | Surface "frontend trio incomplete — missing X" |
| 6 concern-phase completeness — when not skipped, each of `search/caching/realtime/fileUploads/payments/i18nL10n` has the required top-level fields | Surface "concern phase X incomplete" |
| `pluginRecommendation` + `pluginInstall` both populated when neither is skipped | Surface "plugin split incomplete — recommendation captured but install not run" |

Implementation jq snippets (use against `$STATE_FILE = .claude/greenfield-state.json`):

```bash
# Frontend trio
jq -e '
  (.phases.frontendArchitecture.skipped // false) or (.phases.frontendArchitecture.frameworkConfirmed != null)
  and ((.phases.designSystem.skipped // false) or (.phases.designSystem.componentLibrary != null))
  and ((.phases.uxAccessibilityPerf.skipped // false) or (.phases.uxAccessibilityPerf.a11yTarget != null))
' "$STATE_FILE"

# Concern phases
jq -e '
  ["search","caching","realtime","fileUploads","payments","i18nL10n"]
  | all(. as $p | ((.phases[$p].skipped // false) or (.phases[$p] | length > 1)))
' "$STATE_FILE"

# Plugin split
jq -e '
  ((.phases.pluginRecommendation.skipped // false) or (.phases.pluginRecommendation.selected // [] | length >= 0))
  and ((.phases.pluginInstall.skipped // false) or (.phases.pluginInstall.installed != null))
' "$STATE_FILE"
```
