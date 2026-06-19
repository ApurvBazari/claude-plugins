---
name: start
description: Use ONLY when the user explicitly runs /onboard:start. The full interactive onboarding wizard that sets up tailored Claude Code tooling for a project. Never auto-invoke.
disable-model-invocation: true
---

# Start Skill — Interactive Onboarding Wizard

You are running the onboard start skill. This is a guided, multi-phase process that analyzes a developer's codebase and generates complete Claude tooling infrastructure.

## Overview

Tell the developer:

> Starting **onboard** — I'll analyze your codebase, walk you through some questions about your project and workflow, then generate a complete Claude Code setup tailored to your project.
>
> This runs in these phases:
> - **Phase 0 — Empty-repo guard**: if there's no source code yet, I route to a minimal stub instead of the full flow
> - **Phase 1 — Recon**: I scan your codebase (read-only, native tools)
> - **Phase 2 — Research**: you pick a depth/scope profile (Minimal / Standard / Comprehensive), then focused specialists investigate per dimension and I verify their findings, writing a research dossier + architecture map + risk register + glossary
> - **Phase 3 — Grounded Wizard**: I show you what research inferred; you confirm or override
> - **Phase 4 — Plugin detection & context**: I detect installed plugins and assemble the generation context
> - **Phase 5 — Plan → Preview → gate**: I show a full preview behind a hard Approve / Adjust / Cancel gate; nothing is written until you approve
> - **Phase 6 — Generation**: I create all Claude tooling artifacts
> - **Phase 7 — Handoff**: I explain everything that was generated

---

## Phase 0: Empty-Repo Guard

Runs **before** Phase 1 Recon. Detects repositories with no source code and routes them to a minimal, canonical-shape stub instead of running the full analysis + wizard. Closes 2026-04-17 release-gate findings B14, B15, B16.

### Step: Detect empty repository

Count source-code files (exclude `.git/`, dotfiles, `README*`, `LICENSE*`, `.gitignore`):

```bash
SRC_COUNT=$(find . -type f \
  -not -path './.git/*' \
  -not -name '.*' \
  -not -name 'README*' \
  -not -name 'LICENSE*' \
  | wc -l | tr -d ' ')
```

- `SRC_COUNT > 0` → source code exists → **skip Phase 0 entirely**, fall through to Phase 1 Recon. Most common case.
- `SRC_COUNT == 0` → empty repo → proceed to the prior-stub check below.

### Step: Detect prior stub (auto-promote)

If `.claude/onboard-meta.json` already exists AND `jq -r '.mode // empty'` returns `"stub-empty-repo"` AND `SRC_COUNT > 0`: auto-promote. Skip Phase 0 entirely; run Phase 1 Recon → Phase 3 Wizard → Phase 6 Generation. Full generation overwrites the stub artifacts. Append an `updateHistory` entry to the new `onboard-meta.json` noting the `"stub → full"` promotion.

If prior stub exists AND `SRC_COUNT == 0` (user ran start twice on empty dir): default to no-op — inform the developer a stub already exists, skip re-write.

### Step: Present the 3-option menu

For empty repos without a prior stub, use `AskUserQuestion` (single-select, header: `"Empty repo"`):

> This repository has no source code yet. How would you like to proceed?
>
> - **Abort** — stop here. Add source code first, then re-run `/onboard:start`.
> - **Placeholder only** — write a minimal CLAUDE.md placeholder (no `.claude/` directory). Useful if you want to set up Claude context before the code exists but don't want a formal tooling setup.
> - **Generate canonical stub** (default) — create CLAUDE.md, `.claude/settings.json`, and `.claude/onboard-meta.json` in canonical schema with stub-mode markers. Re-run `/onboard:start` later to upgrade to full tooling.

Default: **Generate canonical stub**.

**Single-option guard** (per `.claude/rules/ask-user-question-guard.md`): the menu has 3 options → no guard needed.

### Step: Execute the selected path

- **Abort** → stop the skill. No files written.
- **Placeholder only** → write CLAUDE.md with the placeholder content from the stub procedure (below) but SKIP the `.claude/` directory. Return minimal handoff. Do not proceed to further phases.
- **Generate canonical stub** (default) → follow `references/empty-repo-stub-procedure.md`. It prescribes: the 3 files, the canonical `onboard-meta.json` schema with all 7 generation-phase status keys set to `status: "skipped"` + `reason: "stub-mode-no-code"`, dynamic `pluginVersion` resolution (no hardcoded literals), and the 3-file atomic write order.

After either stub path completes, run a minimal handoff (see the stub procedure's § Post-write handoff section) and return — do NOT continue to Phase 1 Recon. The stub paths never reach Step 0 below, so no task list is created for a stub run.

---

## Step 0: Initialize Phase Tracking

Runs **after** the Phase 0 guard (a stub/abort/placeholder run returns above and never reaches here) and **before** Phase 1 Recon. This wires the durable phase-task list that the rest of the flow transitions.

First, read the contract: `references/phase-tracking.md`. It is the single source of truth for the task subjects, the `pending → in_progress → completed` (plus `deleted`) state machine, the HARD GATE mapping, Cancel semantics, and the **on-disk resume procedure** (§ Resume). Follow it verbatim — do not re-derive its rules here.

### Step: Resume probe (durable on-disk artifacts)

Before creating a fresh task list, probe for a prior interrupted run. The cross-session anchor is the set of **durable on-disk artifacts** — NOT the task list (the harness task list may be session-scoped and is not guaranteed to survive a new session, so it is in-session visibility only). Probe the two artifacts in order, exactly per `references/phase-tracking.md` § Resume:

```bash
META=".claude/onboard-meta.json"
DOSSIER=".claude/onboard-research.json"
CURRENT_PHASE=$([ -f "$META" ] && jq -r '.currentPhase // empty' "$META" || echo "")
META_MAJOR=$([ -f "$META" ] && jq -r '._generated.version // empty' "$META" | cut -d. -f1 || echo "")
```

Branch:

1. **Probe 1 — generation-era meta.** If `onboard-meta.json` exists AND has a `currentPhase` (integer or `"done"`) AND `META_MAJOR == "3"` (the segment before the first `.` of `_generated.version`) AND the run's task list — if it still exists this session — is **not** cancelled (no gate-or-later task `deleted`; § Cancel-resume guard):
   - if `currentPhase == "done"` → the prior run already finished. Do **not** offer resume; route to the existing-config flow (this mirrors the Phase 1 "existing config" branch — Adopt / Update / Start fresh).
   - else (integer `currentPhase`, i.e. `6`) → offer **Resume** (finish from Phase `currentPhase + 1` = Phase 7 Handoff) or **Restart**, via the fixed-two-option `AskUserQuestion` below.
2. **Probe 2 — research dossier, no meta.** Else if `.claude/onboard-research.json` exists but `onboard-meta.json` does **not** (and any task list present is non-cancelled) → research completed, generation never ran. Offer **Resume into Phase 3** (the wizard re-confirms from the dossier's `research.wizardInferences` — this is NOT skipping the wizard; continue forward through context → plan-gate → generation) or **Restart**, via the same prompt.
3. **Probe 3 — neither.** Else → fresh start. Skip the prompt; proceed to create a fresh list below.

For probes 1 (integer case) and 2, present the offer via `AskUserQuestion` (single-select, header `"Resume?"`, **two fixed options**):

- **Resume (Recommended)** — "Continue the interrupted run." Rehydrate from the checkpoint artifact(s): for probe 2 read `.claude/onboard-research.json` and re-derive context, re-create the task list with already-completed phases marked `completed` and the rest `pending`, and continue from the resume target (Phase 7 for probe 1, Phase 3 for probe 2). For probe 1, re-create the list with 0–6 `completed` and 7 `pending`.
- **Restart** — "Discard the interrupted run and start fresh from Phase 0." Mark any leftover incomplete tasks `deleted`, then fall through to create a fresh list below. (Generation is merge-aware, so a restart that re-reaches Phase 6 will not clobber user edits.)

**Guard Usage:** both options are **fixed** (not built from a dynamic list that could collapse to one), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does **not** apply. On **Resume**, skip the fresh-list creation below and jump to the resume target phase. On **Restart** (or probe 3), continue here.

### Step: Create the phase-task list

Create the **8** phase tasks via `TaskCreate`, all `status: "pending"`, one per phase, exactly per the contract's § Task list — `/onboard:start` table (subjects, `activeForm`):

| Subject | `activeForm` |
|---|---|
| `empty-repo-check` | Checking for an empty repository |
| `recon` | Reconnoitering the codebase |
| `research` | Researching the codebase |
| `wizard` | Confirming preferences |
| `build-context` | Detecting plugins & building context |
| `plan-gate` | Planning & awaiting approval |
| `generation` | Generating tooling |
| `handoff` | Handing off |

Phase 0 (`empty-repo-check`) already ran above — the moment the list exists, mark it `in_progress` then `completed` (the empty-repo branch was taken or skipped; either way the guard work is done). The remaining tasks (1–7) stay `pending` until their phase boundary below.

Only this orchestrator touches the list. The dispatched agents (`codebase-analyzer`, `config-generator`) and every internally-invoked `Skill` (`research`, `wizard`, `generate`) are task-blind — the orchestrator owns every transition (per the contract's § Ownership).

---

## Phase 1: Recon (Automated Analysis)

> **Phase transition (per `references/phase-tracking.md`):** `TaskUpdate(recon → in_progress)` now, **before** the recon work begins and **before** dispatching the `codebase-analyzer` agent. Mark it `TaskUpdate(... → completed)` only after the analysis summary is confirmed at the end of this phase.

### Step: Check for Existing Claude Config

Before running analysis, check if the project already has Claude configuration:

```
Glob for: CLAUDE.md, .claude/**, .claude/settings.json
```

**If substantial Claude config exists** (root CLAUDE.md with >20 lines, or .claude/ directory with rules/skills/agents):

> I see this project already has Claude tooling set up:
> - [list what was found]

Ask via `AskUserQuestion` (single-select, header `"Existing config"`):

- **Adopt (Recommended)** — "Bring the existing tooling under onboard management without changing it, so `/onboard:update` works. Runs `/onboard:adopt`."
- **Update** — "Check the existing setup against latest best practices (`/onboard:update`)."
- **Start fresh** — "Replace the existing setup with a newly generated one (existing files will be overwritten)."
- **Cancel** — "Keep everything as-is."

Dispatch on the choice:
- **Adopt** → run the `adopt` skill (`Skill(onboard:adopt)`); when it returns, this start invocation is done (adopt owns the baseline). Do not continue into analysis/generation.
- **Update** → redirect the developer to run `/onboard:update`. Stop.
- **Start fresh** → continue to the analysis step below; note that existing files will be overwritten at generation.
- **Cancel** → stop.

**Guard Usage:** four fixed options (≥2), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

**If minimal or no Claude config exists**, proceed directly to analysis.

### Step: Run Analysis

Spawn the `codebase-analyzer` agent to perform deep analysis. The agent will:
- Perform script-free recon (native Glob/Grep/Read + git one-liners) per `../../agents/codebase-analyzer.md`
- Perform deep exploration of key configuration files
- Check testing setup, CI/CD, conventions
- Produce a structured analysis report

**Data handoff**: The analyzer agent's full structured report remains in the conversational context. Do not write it to a file — it will be passed to the config-generator agent via the conversation in Phase 6 Generation. The analyzer also returns `reconHints = {detectedRoots, structureFacts}` — keep it in context for the Phase 2 Research step.

While waiting, inform the developer:

> Analyzing your codebase... This reads your project structure, detects your tech stack, and assesses complexity. Nothing is modified.

### Step: Present Analysis Summary

Once analysis completes, present a concise summary to the developer:

> Here's what I found:
>
> **Project type**: [type]
> **Languages**: [languages with file counts]
> **Key frameworks**: [frameworks with versions]
> **Testing**: [testing setup]
> **CI/CD**: [pipeline if detected]
> **Complexity**: [category] ([score]/100 — [file count] source files, [LOC] lines)
>
> Does this look accurate? Anything I missed or got wrong?

Wait for confirmation. Incorporate any corrections before proceeding.

> **Phase complete:** once the analysis summary is confirmed, `TaskUpdate(recon → completed)`.

---

## Phase 2: Research

> **Phase transition (per `references/phase-tracking.md`):** `TaskUpdate(research → in_progress)` now, **before** the profile-select prompt and **before** invoking `Skill(onboard:research)`. The research skill is task-blind — it never touches the list. Mark it `TaskUpdate(... → completed)` after the research engine returns the validated dossier.

### Step: profile-select

After the recon summary is confirmed, ask the developer to pick a profile using `AskUserQuestion` (single-select, header: `"Profile"`). The profile sets **both** the research depth (the deep-research step below) and the generation scope.

| Label | Description |
|---|---|
| `Minimal` | Solo / prototype / fast. Recon-only research (no specialists), relaxed style, 1 agent, format-only hooks. |
| `Standard (Recommended)` | Small teams / active projects. Core-4 research + verify, balanced autonomy, 3 agents, lint + SessionStart hooks. |
| `Comprehensive` | Larger / regulated. Full 7-specialist research + verify, strict style, all quality-gate hooks. |

Map the choice to `depth`: `Minimal → "minimal"`, `Standard → "standard"`, `Comprehensive → "comprehensive"`. Record it as `selectedPreset` for the grounded wizard + generation scope (per `../wizard/references/workflow-presets.md`). There is **no Custom profile** — the grounded wizard (Phase 3) lets the developer override every field individually.

### Step: Deep Research

Dispatch the research engine with the chosen depth and the recon hints:

```
Skill(
  skill: "onboard:research",
  args: <stringified { projectPath: <cwd>, depth: <from the profile-select step>, reconHints: <from Phase 1 Recon> }>
)
```

The engine fans out read-only specialists per dimension, adversarially verifies their claims, synthesizes the research dossier, **asks where the four human-readable artifacts should land** (committed / local / none), writes `.claude/onboard-research.json` (+ the four `docs/onboard/` files per that choice), and returns the validated `research-dossier` object.

Keep the returned dossier in conversation context: Phase 3 (Grounded Wizard) reads `research.wizardInferences`, and the Phase 4 build-v3-context step embeds the whole `research` object in the v3 context.

Inform the developer before dispatching:

> Researching your codebase in depth — focused specialists per dimension, with their findings verified against your code, producing a research dossier plus an architecture map, risk register, and glossary. This is read-only.

For `minimal` depth the engine dispatches no specialists and returns a minimal dossier quickly (the fast/cheap path).

> **Phase complete:** after the research engine returns the validated dossier, `TaskUpdate(research → completed)`.

---

## Phase 3: Grounded Wizard

> **Phase transition (per `references/phase-tracking.md`):** `TaskUpdate(wizard → in_progress)` now, **before** invoking the `wizard` skill (which is task-blind). Mark it `TaskUpdate(... → completed)` after the wizard answers are gathered and the summary below is shown.

Use the `wizard` skill to run the **grounded confirm/override surface**. It reads `research.wizardInferences` from the Phase 2 Research dossier and presents confirm/override cards (workflow fields), cold asks (`autonomyLevel` + intent + pain points), and tuning/detection cards — ~2–3 exchanges. There is no preset selection here (done in the Phase 2 profile-select step) and no Custom path.

After all questions are answered, present a summary:

> Here's a summary of everything I've gathered:
>
> **Project**: [description]
> **Model**: [model-id] ([source])
> **Team**: [size]
> **Primary work**: [tasks]
> **Workflow**: [review process, branching, deploy frequency]
> **[Stack-specific]**: [relevant details]
> **Pain points**: [time sinks, error-prone areas, automation wishes]
> **Preferences**: [testing, style, security, autonomy]
>
> Next I'll show you a full preview of what I'll build before anything is written.

> **Phase complete:** after the wizard answers are gathered and the summary above is shown, `TaskUpdate(wizard → completed)`.

---

---

## Phase 4: Plugin Detection & Context

> **Phase transition (per `references/phase-tracking.md`):** `TaskUpdate(build-context → in_progress)` now, **before** the plugin-detection probes and the build-v3-context step. Mark it `TaskUpdate(... → completed)` after the context builder's validation passes.

### Step: plugin-detection

Before generation, detect installed Claude Code plugins to enrich the output with plugin-aware features (Plugin Integration section, per-directory skill annotations, plugin-aware agent skipping, quality-gate hooks referencing plugin skills).

#### Probe Filesystem — canonical deep probe

Follow the canonical procedure in `../generation/references/plugins/plugin-detection-guide.md` § Known Plugin Probe List. The probe walks **both** locations to catch sibling installs AND marketplace-installed plugins:

1. `${CLAUDE_PLUGIN_ROOT}/../<plugin-name>/` (dev monorepo siblings)
2. `~/.claude/plugins/cache/*/<plugin-name>/[version/]` (marketplace installs, where `<version>` is often the literal string `"unknown"`)

Build `installedPlugins` from successful probes across the full catalog. Do not stop on a single miss — continue through every plugin in the catalog.

**Fallback when `CLAUDE_PLUGIN_ROOT` is unset**: the marketplace-cache probe still runs (keys off `$HOME`). Only fall back to "no plugins detected" when BOTH probe locations yield zero hits across the catalog.

#### Step: probe-plugin-surfaces

For each entry in `installedPlugins`, run the surface-probe procedure in `../generation/references/plugins/plugin-surface-probe.md` to classify the plugin as `command-or-skill`, `hooks-only`, or `agent-only`. The resulting `pluginSurfaces` map feeds the Plugin Integration template to prevent fabricated slash refs (e.g., `/security-guidance:security-review` for a hooks-only plugin — release-gate finding G.3, 2026-04-17).

#### Derive coveredCapabilities, qualityGates, phaseSkills

Apply the derivation rules in `../generation/references/plugins/plugin-detection-guide.md`:
- `coveredCapabilities` — combine per-plugin capabilities, deduplicated
- `qualityGates` — filter defaults by `installedPlugins`, then downgrade `preCommit[].mode` per `wizardAnswers.autonomyLevel`
- `phaseSkills` — filter defaults by `installedPlugins`; remove empty phases

#### Present Detection Results

If plugins were detected:

> **Detected Claude Code plugins:**
> - **[plugin name]** ([capabilities])
> - ...
>
> These will be integrated into your generated CLAUDE.md and quality-gate hooks.

If no plugins were detected:

> No Claude Code plugins detected. I'll generate standalone tooling.
> You can install plugins later and re-run `/onboard:start` to integrate them.

---

### Step: build-v3-context

Follow the canonical procedure in `references/onboard-context-builder.md` to assemble the single context object that Phase 6 Generation dispatches to `Skill(onboard:generate)`. The builder is the **single source of truth** for start context construction — every profile path (Minimal / Standard / Comprehensive) invokes it. Do not maintain profile-specific context builders; that was the drift that caused release-gate findings B1, B5, B6, B8, B10, B12, B13 (2026-04-17 sweep).

Inputs already in conversation context:

- Phase 1 Recon analysis report
- Phase 2 research dossier (the `research` object)
- Phase 3 wizard output (canonical `wizardAnswers` shape per `../wizard/SKILL.md` § Output § Canonical shape invariant)
- Phase 4 plugin detection results (`installedPlugins`, `coveredCapabilities`, `pluginSurfaces`)
- Project root path (current working directory)

The builder emits a context object per the canonical schema. Key invariants:

- the builder emits **v3** (`version: 3`) and embeds the `research` object — see `references/onboard-context-builder.md`.
- All 7 callerExtras generation-phase flags populated explicitly (`disableMCP`, `disableLSP`, `disableBuiltInSkills`, `disableSkillTuning`, `disableAgentTuning`, `disableOutputStyleTuning`, `allowHttpHooks`) — start-path defaults are `false` for all (the generation phases run fully; interactive confirmation runs).
- `callerExtras.installedPlugins` and `pluginSurfaces` populated from the Phase 4 plugin-detection probes.
- Every wizardAnswers field populated (including defaults for skipped fields per `../wizard/SKILL.md` § Skip Behavior).

Run the builder's validation step before proceeding to Phase 6 Generation. If validation fails, refuse to dispatch — surface the error to the user with the offending field name.

> **Phase complete:** after the context builder's validation passes, `TaskUpdate(build-context → completed)`.

---

---

## Phase 5: Plan → Preview → Gate

> **Phase transition (per `references/phase-tracking.md` § HARD GATE):** `TaskUpdate(plan-gate → in_progress)` now, **before** the plan step. This task is the gate: it **stays `in_progress` for the entire phase** — through plan, preview, render, and *while awaiting the user's decision* (the enum has no "awaiting" state; `in_progress` is the truthful "we are here, waiting on you"). Its `completed`/`deleted` transition is driven by the gate decision in the gate step below — do **not** mark it `completed` at plan or preview.

### Step: plan (plan mode)

Dispatch generation in plan mode — it computes what it will write without writing:

```
Skill(onboard:generate, {mode:"plan", context})   // context from the Phase 4 build-v3-context step
```

The skill returns a `generationManifest` (validated vs `../../schemas/generation-manifest.json`): `changes[]` (path, action, purpose, outline, tier, origin) + `decisions` + `warnings`. **Nothing is written.** Keep the manifest in context.

If plan mode fails or the manifest fails validation, do NOT proceed — surface the error; let the developer retry or cancel.

### Step: preview (assemble the preview model)

Build `previewModel` from the research dossier (Phase 2 Research) + the manifest (the plan step above) per `../research/references/render-adapter.md` § previewModel: `flow:"start"`; `research` = architecture map + top risks + glossary from the dossier (null if research was minimal/empty); `changes`/`decisions`/`warnings` from the manifest.

### Step: gate (render + hard gate — review before implementation)

This is the review-before-implementation gate. **Nothing has been written yet.**

1. **Render.** Map `previewModel` → a walkthrough `session-model` per `../research/references/render-adapter.md`, then invoke `walkthrough:render` with `{ model, outputPath: ".claude/walkthrough/<YYYY-MM-DD-HHMM>-onboard-plan.html" }`.
   - **walkthrough absent** (render skill unavailable) → offer install via AskUserQuestion (single-select, header `"Walkthrough"`): **Install now (Recommended)** ("render this preview as an interactive page") / **Skip — markdown preview**.
     - Install now → `claude plugin install walkthrough@apurvbazari-plugins` via Bash; re-probe; success → render as above; failure → markdown fallback.
     - Skip / failure → **markdown gate**: present `previewModel` inline as markdown (Overview · What I learned · What I'll build grouped by tier with each artifact's purpose+outline · Key decisions · Risks). Optionally also write `.claude/onboard-plan.md`.
   - **`walkthrough:render` present but fails at runtime** → don't abort the gate; announce the degrade and fall through to the **markdown gate** above. (Invoking the skill is itself the presence test: an uninstalled skill surfaces as *absent* above; a runtime render error lands here.)
   - This degrades the HTML render only — never the gate.
2. **Gate.** AskUserQuestion (single-select, header `"Generate?"`). Map each decision to a task transition per `references/phase-tracking.md` § HARD GATE (the gate task was left `in_progress` at the Phase 5 transition above):
   - **Approve & generate (Recommended)** → the user accepted → `TaskUpdate(plan-gate → completed)`, then proceed to Phase 6 Generation (write mode).
   - **Adjust** → the user wants changes → **no status change** (the gate task stays `in_progress`); return to the Phase 3 wizard summary to revise answers/profile, then re-run the Phase 4 build-v3-context step → Phase 5 plan → preview → gate. The gate loops.
   - **Cancel** → the user declined → nothing was written (the gate precedes the only write phase). Per § Cancel → `deleted`: mark the gate task **and every later phase task** `deleted` — `TaskUpdate(plan-gate → deleted)`, `TaskUpdate(generation → deleted)`, `TaskUpdate(handoff → deleted)`. Leave the already-`completed` tasks 0–4 as `completed` (they really ran). Then stop. Write nothing. Print: "Cancelled — no files were created."
3. Only **Approve** advances to Phase 6 Generation. Until then, nothing is written to disk.

**Guard Usage:** the install offer and the gate both use fixed-option single-selects (≥2 options), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

---

## Phase 6: Generation (via Skill(onboard:generate))

> **Phase transition (per `references/phase-tracking.md`):** `TaskUpdate(generation → in_progress)` now (only reached on **Approve** at the gate), **before** dispatching `Skill(onboard:generate)` / the `config-generator` agent — both are task-blind. Mark it `TaskUpdate(... → completed)` after generation returns and the file list is reported (the report-results step). The ecosystem-plugin-install step below still runs inside Phase 6.

### Step: model-resolution (no separate prompt)

The model has already been chosen by this point — either because the developer tuned it in the grounded wizard (`wizardAnswers.skillTuning?.defaultModel`), or implicitly via the profile default (Minimal/Standard/Comprehensive use `claude-opus-4-7[1m]` per `../wizard/references/workflow-presets.md` § Exchange target (uniform across profiles)).

**Do NOT** ask "Which model would you like to use?" here. That used to be a separate post-summary question in earlier versions of this skill (`SKILL.md`) — the duplicate prompt was findings A4 in the 2026-04-16 release-gate test.

Resolve the model from the wizard answers as follows:

```
chosenModel = wizardAnswers.skillTuning?.defaultModel
            ?? wizardAnswers.model
            ?? presetDefaultModel(wizardAnswers.selectedPreset)
            ?? "claude-opus-4-7[1m]"
```

The profile-default fallback is documented in `../wizard/references/workflow-presets.md`. The final fallback (`claude-opus-4-7[1m]`) covers any path where the wizard answers don't include a model (e.g., a future bug or the grounded wizard skipping the model-tuning card).

The wizard's summary already shows the chosen model — the developer has already seen and confirmed it. If they wanted to change it, they would have done so in the summary tweak step (or by editing `.claude/settings.json` after start).

The model choice is written into `context.modelChoice` by the Phase 4 build-v3-context builder.

### Step: dispatch to Skill(onboard:generate)

**Invoke `Skill(onboard:generate)` with the context object built in the Phase 4 build-v3-context step.** One contract, one validator, one agent-dispatch boundary.

```
Skill(onboard:generate, {mode:"write", context})   // context from the Phase 4 build-v3-context step — the same object the Phase 5 plan step planned from
```

By this point the developer has approved the plan at the Phase 5 gate; write mode honors that plan (same artifact set + decisions).

The generate skill then:

1. Validates the context (see `../generate/SKILL.md` § Validation)
2. Dispatches `Agent(config-generator)` with `dispatchedAsAgent: true`
3. Runs the full generation pipeline (emission Step 1 MCP, Step 2 Output Styles, Step 3 LSP, Step 4 Built-in Skills) per `../generation/SKILL.md`
4. Runs pre-exit self-audit verifying all 7 generation-phase telemetry keys are present. The self-audit also covers the v3 research telemetry block:
   - **Research self-audit:** if `metadata.research.consumed === true`, verify the block is coherent — `.claude/onboard-research.json` exists; `claimsVerified`, `claimsDropped`, `specialistsRun`, `artifactLocation`, `artifactsWritten` are present; `artifactsWritten` paths match the on-disk docs for the recorded `artifactLocation`; and `htmlRendered` is non-null **iff** the `walkthrough` plugin was present at render time (null is correct when absent or `location:"none"`). If `consumed === false` (research-absent / stub mode), record the research key as `status:"skipped"` with a reason (mirrors the existing skipped-key convention). Surface any incoherence as a self-audit warning.
5. Returns a structured JSON response with `filesWritten`, `telemetry`, `auditPassed`, `warnings`

**Do NOT** call `Agent(config-generator)` directly from this skill — that breaks the contract boundary and bypasses the shared validation. Always dispatch via the Skill tool.

**Do NOT** call Write / Edit from this skill — the dispatched agent owns all writes (hard-fail safety net: config-generator checks `dispatchedAsAgent === true` and refuses to write if absent).

Before dispatching, inform the developer:

> Generating your Claude tooling... This will create the following artifacts:
> - Root CLAUDE.md
> - [Subdirectory CLAUDE.md files if applicable]
> - Path-scoped rules
> - Skills
> - Agents
> - Hook configuration
> - MCP servers (if stack signals detected)
> - Output style
> - LSP plugin integration (if source files detected)
> - Setup metadata

### Step: report-results

After generation completes, list every file that was created:

> Generation complete! Here's what was created:
>
> | File | Purpose |
> |---|---|
> | `CLAUDE.md` | Root project context (X lines) |
> | `src/components/CLAUDE.md` | Component conventions |
> | `.claude/rules/testing.md` | Testing rules for *.test.* files |
> | `.claude/rules/api.md` | API endpoint rules |
> | `.claude/skills/react-component/SKILL.md` | React component creation skill |
> | `.claude/agents/code-reviewer.md` | Code review agent |
> | `.claude/agents/test-writer.md` | Test generation agent |
> | `.claude/settings.json` | Hook configuration (auto-format, lint) |
> | `.claude/onboard-meta.json` | Setup metadata |

> **Phase complete:** after generation returns and the file list above is reported, `TaskUpdate(generation → completed)`. The ecosystem-plugin-install step below is an optional tail of Phase 6 — it does not get its own task.

> **Set the `currentPhase` anchor (orchestrator-owned, per `references/phase-tracking.md` § Resume).** Generation (Phase 6) is the first thing to write `.claude/onboard-meta.json`, so this is the first point a `currentPhase` can exist. After Phase 6 returns successfully, the **orchestrator** (not the config-generator agent — do not change its emission logic) updates the just-written meta to set a top-level `currentPhase: 6`:
>
> ```bash
> META=".claude/onboard-meta.json"
> tmp=$(mktemp) && jq '.currentPhase = 6' "$META" > "$tmp" && mv "$tmp" "$META"
> ```
>
> This marks the run as generation-era for cross-session resume (probe 1). It is flipped to `"done"` at Phase 7 completion below. A merge-aware re-run of Phase 6 (recovery from an interrupted write) simply re-applies `= 6`.

---

### Step: ecosystem-plugin-install

If the wizard answers include `ecosystemPlugins`, set up the requested plugins.

#### Resolve Requested Ecosystem Plugins

For each plugin the developer selected in the wizard (`ecosystemPlugins.notify`, etc.), verify it's installed. If it's missing, **offer inline install** — do not skip silently, because the developer explicitly asked for it.

For each requested plugin, probe the filesystem:

```bash
# Check if notify is available
ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null
```

Characteristic files per plugin:
- `notify` → `scripts/notify.sh`

**If the probe finds the file**, the plugin is installed — proceed to the notify delegation sub-step below (for notify).

**If the probe returns nothing**, the plugin is missing. Tell the developer:

> You selected the **<plugin>** plugin during the wizard, but it's not installed yet.
>
> Install it now? (runs: `claude plugin install <plugin>`)

Use AskUserQuestion with two options:
- **Install now (Recommended)** — run the install command via Bash, then continue
- **Skip setup** — don't configure this plugin; continue with the rest of the flow

**If the developer installs:**
1. Run `claude plugin install <plugin>` via the Bash tool.
2. Re-run the detection probe to verify.
3. **On success** — proceed to the corresponding setup step. If the plugin's slash commands/scripts aren't immediately available, note: "Plugin installed, but its scripts may not be on disk yet until you restart the session. If setup fails, restart Claude Code and rerun `/onboard:start`."
4. **On install failure** — surface the underlying error verbatim. Then emit the explicit skip message below and continue with the next requested plugin.

**If the developer skips or install fails**, emit a clear skip message (never silent):

> Skipping **<plugin>** setup. You can install it later with `claude plugin install <plugin>` and run its setup command directly (`/notify:setup`, etc.).

Then continue to the next requested plugin. Repeat for each entry in `ecosystemPlugins`.

**Edge case** — if a plugin was NOT requested in the wizard (`ecosystemPlugins.<plugin>` is `false` or absent), skip it entirely. Do not probe, do not prompt. This step only acts on what the developer explicitly asked for.

#### Set Up Notify (if requested and available)

If `ecosystemPlugins.notify` is `true` and notify is installed, **delegate configuration to the notify plugin** — `/notify:setup` owns notify wiring and already handles global-vs-per-project scope and detects any pre-existing global config. onboard does **not** copy `notify.sh`, write a `notify-config.json`, run `install-notifier.sh`, or merge notify hooks into this project's `settings.json` — doing so would duplicate (and silently diverge from) whatever `/notify:setup` manages.

Tell the developer:

> The **notify** plugin is installed. Run `/notify:setup` to turn on system notifications — it lets you pick global (all projects) or this-project-only scope and skips anything already configured globally.

If notify was just installed in this step and its scripts aren't on disk yet, the same `/notify:setup` instruction applies once the session is restarted.

#### Report Ecosystem Setup

> **Ecosystem plugins:**
> - [list each requested plugin and whether it's installed / was just installed / skipped]
>
> To finish configuring:
> - Notify: run `/notify:setup`

If no plugins were requested or available, skip this report entirely.

---

---

## Phase 7: Handoff (Education & Handoff)

> **Phase transition (per `references/phase-tracking.md`):** `TaskUpdate(handoff → in_progress)` now, **before** the handoff narration below. Mark it `TaskUpdate(... → completed)` after the Closing step — that completes the last phase of the run.

### Step: Explain Key Artifacts

Briefly explain the most important generated artifacts:

> **What to know about your new setup:**
>
> **CLAUDE.md** — This is your main project context file. Claude reads it every session to understand your project. Review it and tweak anything that doesn't feel right.
>
> **Path-scoped rules** — These activate automatically when Claude works on matching files. For example, your testing rules apply whenever Claude touches test files.
>
> **Skills** — These give Claude expertise for specific tasks in your project. Try asking Claude to [relevant task based on generated skills].
>
> **Agents** — Specialized Claude personas. Try running your [agent name] agent on a recent change.
>
> **Hooks** — Auto-formatting and linting happen in the background. You don't need to think about these.

### Step: Quick Start Suggestions

Based on what was generated, suggest what to try first:

> **Try these first:**
> 1. Open a file in your project and notice how Claude now has context about your conventions
> 2. [Stack-specific suggestion, e.g., "Ask Claude to create a new React component and see how it follows your patterns"]
> 3. [Pain-point based suggestion, e.g., "Ask Claude to write tests for a module you mentioned is error-prone"]

### Step: Next Steps

> **Next steps:**
> - Review `CLAUDE.md` and adjust anything that doesn't match your preferences
> - Review the research artifacts in `docs/onboard/` (or `.claude/onboard-research.json` if you chose local/none) — the dossier, architecture map, risk register, and glossary.
> - Run `/onboard:check` anytime to check the health of your setup
> - Run `/onboard:update` periodically to align with latest Claude best practices
> - All generated files have maintenance headers — Claude will let you know when they need updating

If ecosystem plugins were set up, add:
> - Run `/notify:check` to verify notifications are working

### Step: Closing

> Your project is now set up for AI-assisted development with Claude Code. Happy coding!

> **Phase complete:** after the closing line, `TaskUpdate(handoff → completed)`. All 8 phase tasks are now `completed` — the run is done.

> **Finalize the `currentPhase` anchor (orchestrator-owned, per `references/phase-tracking.md` § Resume).** Now that handoff completed, the orchestrator flips the meta's `currentPhase` from `6` to the string `"done"`:
>
> ```bash
> META=".claude/onboard-meta.json"
> tmp=$(mktemp) && jq '.currentPhase = "done"' "$META" > "$tmp" && mv "$tmp" "$META"
> ```
>
> A `"done"` meta is **not** resumable (probe 1 routes it to the existing-config flow on a future run, not a Resume offer).

## Key Rules

- **Never dispatch `config-generator` directly** — always go through `Skill(onboard:generate)`. Direct dispatch bypasses the shared validation contract and the `dispatchedAsAgent` safety net.
- **Empty-repo guard always runs first** — Phase 0 fires before Phase 1 Recon, even if the user explicitly says "just analyze". A zero-source-count repo must hit the 3-option menu, not the wizard.
- **Settings.json is always merge-aware** — never overwrite `.claude/settings.json` outright. Read it first, merge hooks, then write. The file may already contain hooks from other sources.
- **Notify is delegated to `/notify:setup`, never wired per-repo** — onboard ensures the notify plugin is installed (if requested) and points the developer at `/notify:setup`; it never copies `notify.sh`, writes a project `notify-config.json`, runs `install-notifier.sh`, or merges notify hooks. `/notify:setup` owns scope selection and global-config detection.
- **Halt and surface on context builder validation failure** — if the Phase 4 build-v3-context validation fails, refuse to dispatch and show the offending field. Never attempt generation with an incomplete or malformed context object.
- **The orchestrator owns every phase-task transition** — per `references/phase-tracking.md`, Step 0 creates the 8 bare-slug phase tasks (`empty-repo-check` … `handoff`); each phase marks its own task `in_progress` before its work (and before any agent/Skill dispatch) and `completed` after. Subagents (`codebase-analyzer`, `config-generator`) and internal skills (`research`, `wizard`, `generate`) are task-blind. The enum is exactly `pending`/`in_progress`/`completed`/`deleted` — no "blocked"/"cancelled". The Phase 5 gate stays `in_progress` while awaiting the decision; Approve → `completed`, Adjust → loop (no change), Cancel → mark tasks 5/6/7 `deleted`.
- **The resume anchor is on-disk artifacts, not the task list** — Step 0's resume probe (per `references/phase-tracking.md` § Resume) keys on durable files: `onboard-meta.json` with an integer `currentPhase` (probe 1, generation-era) → research dossier with no meta (probe 2, post-research) → neither (clean start). The harness task list is in-session visibility only. `currentPhase` is **orchestrator-owned and written from Phase 6 onward only** (the meta's first existence): set `= 6` after Phase 6 returns, then `= "done"` at Phase 7 completion. Phases 0–5 write no `currentPhase` (no meta exists) — their durable progress is the research dossier. Do **not** move these writes into the config-generator agent; the orchestrator updates the meta after generation returns. Absent `currentPhase` ⇒ no resume offered (back-compat).
