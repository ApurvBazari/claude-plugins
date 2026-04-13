# /forge:status — Project Health Check

You are running the Forge status command. This provides a quick overview of the project's state — whether a forge session is in progress, whether setup completed, and (if complete) the project's AI tooling health, pending drift, and setup metadata.

---

## Step 1: Check for in-flight session

Before checking completed setup, check for an in-progress session at `.claude/forge-state.json`.

**If it exists and `currentPhase !== "complete"`**: there's an in-progress session. Report it prominently at the top of the status output:

> **🟡 Forge session in progress** (not yet complete)
>
> **Project**: [context.appDescription or "unnamed"]
> **Started**: [createdAt]
> **Last updated**: [updatedAt] ([time delta])
> **Currently at**: [currentPhase] / [currentStep]
> **Completed steps**: [list from completedSteps]
> **Next action**: [nextAction]
> **Research mode**: [research.mode]
>
> **To continue**: run `/forge:resume`
> **To abandon and start over**: delete `.claude/forge-state.json` (irreversible — will lose all gathered context)

Then stop here — do not try to also report post-scaffold health, because the scaffold may not exist yet.

**If it exists and `currentPhase === "complete"`**: the session finished. Proceed to Step 2 to report the full post-scaffold health.

**If it doesn't exist**: proceed to Step 2 (the project may have been set up before forge had state tracking, so `forge-meta.json` alone is sufficient).

---

## Step 2: Check for Setup

Read `.claude/forge-meta.json`:

**If not found**:

> This project hasn't been set up with Forge yet.
>
> Run `/forge:init` to scaffold a new project with AI-native tooling.

Stop here.

**Note on file distinction**: `.claude/forge-meta.json` is the persistent setup metadata (stack, context, generated artifacts, plugin list) used for health checks and status reporting. `.claude/forge-state.json` is ephemeral resume state, written during an in-flight session and only relevant for `/forge:resume`. Step 1 checks `forge-state.json`; Step 2 onward checks `forge-meta.json`. If both exist with `forge-state.json.currentPhase === "complete"`, the session finished successfully and `forge-state.json` can be removed as garbage (optional — it's harmless to keep).

---

## Step 3: Parse Metadata

Extract from `forge-meta.json`:
- `version` — Forge version used
- `createdAt` — When the project was scaffolded
- `context.stack` — Tech stack details
- `context.deployTarget` — Deployment target
- `context.branchingStrategy` — Git branching strategy
- `context.autoEvolutionMode` — How tooling updates work
- `generated.tooling` — List of generated tooling files
- `generated.cicd` — List of CI/CD workflows
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

For projects where `forge-meta.json.installedPlugins` is non-empty, assess how well the Plugin Integration layer is wired:

1. **Read root `CLAUDE.md`** — look for `<!-- onboard:plugin-integration:start -->` marker. If present, record line count of the delimited region. If absent, mark Plugin Integration section as **missing**.
2. **Read `.claude/settings.json`** — inspect `hooks.SessionStart`, `hooks.PreToolUse`, `hooks.Stop` for quality-gate entries generated from `qualityGates` (script paths matching `plugin-integration-reminder.sh`, `feature-start-detector.sh`, `pre-commit-*.sh`, `post-feature-*.sh`). Record which are present.
3. **Read `forge-meta.json.generated.toolingFlags.hookStatus`** (preferred path) — onboard 2.2.0+ persists a canonical `hookStatus` telemetry object. If present, use it directly for the coverage report — it's more accurate than reconstructing the picture from `qualityGates` + `settings.json`. Fields:
   - `planned[event]` — **integer** — how many hooks onboard expected to generate for that event key (only counts `qualityGates`-derived hooks; format/lint/forge-internal hooks are out of scope)
   - `generated[event]` — **array of script basenames** (canonical shape) — list of hook scripts actually wired under that event. Use `len(generated[event])` to get the count. (Legacy tolerance: some older onboard builds emit a count integer instead of an array — detect the shape and handle both.)
   - `skipped[]` — list of `{event, skill, reason}` entries for hooks that were dropped (e.g., plugin missing, condition unsatisfied, empty critical-dirs)
   - `warnings[]` — operator-facing messages about soft issues during generation
   - `downgradeApplied` (optional) — object of `{rule, affectedEntries}` present only when autonomyLevel forced a `preCommit[].mode` downgrade. Absent or `null` means no downgrade fired.
4. **Fallback (no `hookStatus`)** — if `generated.toolingFlags.hookStatus` is absent (e.g. project was set up with onboard < 2.2.0), fall back to comparing `forge-meta.json.generated.toolingFlags.qualityGates` against the hook entries actually wired in `.claude/settings.json`. Flag drift inferentially (e.g., `qualityGates.preCommit` listed 2 entries but only 1 hook script exists → 1 missing).
5. **Check phase-recommended plugins**: derive the expected plugin set from `forge-meta.json.context` (stack, autonomyLevel, etc.) using the Step 1 match logic from `plugin-discovery/SKILL.md`. Any phase-recommended plugin NOT in `installedPlugins` is reported as "missing".
6. **Check critical dirs**: if `qualityGates.featureStart.criticalDirs` was populated, verify those directories exist on disk. If any are missing, the feature-start detector will never fire for them.
7. **Check plugin drift**: compare `forge-meta.json.generated.toolingFlags.installedPlugins` against currently-installed plugins via filesystem probe (same strategy as `/onboard:evolve` Step 0: probe `${CLAUDE_PLUGIN_ROOT}/../<plugin>` for each known plugin). Record added/removed counts for the summary.

Build a structured report block for inclusion in Step 7's summary.

---

## Step 5: Check Pending Drift

Read `.claude/forge-drift.json`:

- If entries exist: report count and categories (dependencies, configs, structure)
- If no entries or file missing: report "No pending drift"

---

## Step 6: Check Stack Freshness

Compare `webResearch.stackVersion` from metadata against current `package.json` (or equivalent manifest):
- If the framework version has been bumped since scaffold, note it
- If a major version change occurred, recommend re-running web research

---

## Step 7: Present Summary

> **Forge Status**
>
> **Project**: [appDescription]
> **Stack**: [framework] v[version] (scaffolded [date])
> **Deploy**: [target] | **Branching**: [strategy]
> **Auto-evolution**: [mode]
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
>
> **Pending Drift**: [N entries] or "None"
> [If drift exists]: Run `/forge:evolve` to apply updates.
>
> **Plugin Integration Coverage**
> | Field | Status |
> |---|---|
> | Installed plugins | [N] [comma-separated list] |
> | Covered capabilities | [N] [list] |
> | Phase-recommended missing | [list, or "none"] |
> | Plugin Integration section in CLAUDE.md | [ok ([line count] lines) / missing] |
> | Hook wiring (planned → generated) | [sum(planned) / sum(len(generated[event]))] [from hookStatus if available, else reconstructed] |
> | SessionStart reminder hook | [wired / not wired] [optional: (N skipped)] |
> | Feature-start detector hook | [wired / not wired / (no critical dirs configured)] |
> | preCommit blocking hooks | [N wired / 0 wired (autonomy=exploratory)] [optional: (M skipped, reasons: ...)] |
> | postFeature advisory hook | [wired / not wired] |
> | Critical dirs exist on disk | [all / N missing: list] |
> | Telemetry source | [hookStatus (onboard 2.2.0+) / reconstructed (legacy)] |
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
