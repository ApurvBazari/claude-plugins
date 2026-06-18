---
name: adopt
description: Bring a repo's existing hand-crafted Claude tooling under onboard management — synthesizes an onboard baseline (retrofit-mode meta + snapshots) WITHOUT modifying any hand-crafted file, so /onboard:update works afterward. Use only when the user explicitly invokes /onboard:adopt, or when start/update route here.
disable-model-invocation: true
---

# Adopt Skill — Retrofit Foreign Claude Tooling

You are running the onboard adopt skill. It brings a project's **pre-existing, hand-crafted** Claude tooling under onboard management by synthesizing a baseline — `onboard-meta.json` (`mode:"retrofit"`) plus snapshots — so `/onboard:update` can manage it. **Adopt never modifies a hand-crafted file.** It writes only the baseline; all modernization is deferred to `/onboard:update`, per-item approved.

This skill may be entered three ways: directly (`/onboard:adopt`), from `/onboard:start`'s existing-config branch (the **Adopt** option), or from `/onboard:update`'s missing-meta guard (offer adopt → continue into drift detection). When entered from update, after A6 hand back control to update's drift detection.

## Overview

Tell the developer:

> Adopting your existing Claude tooling — I'll catalog what you already have, research your codebase to ground the baseline, confirm a few preferences, then show you a full preview before writing anything. **I won't touch your hand-crafted files** — I only record a baseline so `/onboard:update` can manage them going forward.

## Step 0: Initialize Phase Tracking

Runs **first**, before Step A1. This wires the durable phase-task list that the rest of the flow transitions for in-session visibility.

First, read the contract: `../start/references/phase-tracking.md` (the cross-skill source of truth — `start` is its worked example). It defines the task subjects, the `pending → in_progress → completed` (plus `deleted`) state machine, and the HARD GATE mapping. Follow it verbatim — do not re-derive its rules here. `adopt` operates on a project that already has hand-crafted tooling and writes its own `onboard-meta.json` only at the end (Step A6), so the task list here is **in-session progress visibility**; the durable record lives in the on-disk artifacts the contract describes (the baseline meta + snapshots written at A6).

Create the **6** `adopt` phase tasks via `TaskCreate`, all `status: "pending"`, one per ladder phase, using the `onboard:adopt:phase:` subject prefix from the contract's § Other entry points table:

| Subject | `activeForm` |
|---|---|
| `onboard:adopt:phase:0:detect-classify` | Detecting & classifying the existing surface |
| `onboard:adopt:phase:1:recon-research` | Reconnoitering & researching |
| `onboard:adopt:phase:2:wizard` | Confirming preferences |
| `onboard:adopt:phase:3:synthesize` | Synthesizing the baseline |
| `onboard:adopt:phase:4:preview-gate` | Previewing & awaiting approval |
| `onboard:adopt:phase:5:write-handoff` | Writing the baseline & handing off |

Only this orchestrator touches the list. Every internal skill it later invokes (`onboard:research`, `onboard:wizard`) and the dispatched `codebase-analyzer` agent are **task-blind** per the contract's § Ownership — they run inside the parent phase's task. (Adopt never invokes `generate`.) **Routing note (per the contract's § Routing):** when `adopt` was entered from `/onboard:update`'s missing-baseline guard, this `onboard:adopt:phase:` list is adopt's own; adopt marks it complete on handoff (A6) and control returns to the caller, which continues its own `onboard:update:phase:` list. The two lists coexist — this adopt list never touches update's tasks and vice versa.

## Step A1: Detect & classify the existing surface

> **Phase transition (per `../start/references/phase-tracking.md`):** `TaskUpdate(onboard:adopt:phase:0:detect-classify → in_progress)` now, **before** the detect/classify work below. If a redirect guard fires (no tooling → `/onboard:start`; meta already present → `/onboard:update`), leave this task `in_progress` and stop — the run halts there. Otherwise mark it `TaskUpdate(... → completed)` after the catalog is presented to the developer at the end of this step.

Follow `references/detection-and-classification.md`. Enumerate the tooling surface (native Glob/Read, read-only), classify each artifact, and apply the redirect guards:
- no CLAUDE.md and no `.claude/` tooling → redirect to `/onboard:start`, stop.
- `.claude/onboard-meta.json` already present → redirect to `/onboard:update`, stop.

Present a short catalog to the developer:

> I found this existing tooling:
> - [category counts, e.g. "1 CLAUDE.md, 3 rules, 2 skills, 1 agent, .mcp.json, 2 hooks"]
>
> None of these will be modified. I'll research your codebase next.

> **Phase complete:** after the catalog above is presented (and no redirect guard fired), `TaskUpdate(onboard:adopt:phase:0:detect-classify → completed)`.

## Step A2: Recon + Research (Full depth)

> **Phase transition (per `../start/references/phase-tracking.md`):** `TaskUpdate(onboard:adopt:phase:1:recon-research → in_progress)` now, **before** dispatching the `codebase-analyzer` agent and **before** invoking `Skill(onboard:research)` (both task-blind). Mark it `TaskUpdate(... → completed)` after the research engine returns the validated dossier.

1. **Recon** — spawn the `codebase-analyzer` agent (per `../../agents/codebase-analyzer.md`), exactly as `start` Phase 1 (Recon). Keep its report + `reconHints` in context.
2. **Research** — dispatch the research engine at **Full depth**:

```
Skill(onboard:research, args: <stringified { projectPath: <cwd>, depth: "comprehensive", reconHints: <from recon> }>)
```

The engine fans out specialists, verifies, synthesizes the dossier, asks the artifact location, writes `.claude/onboard-research.json` (+ docs per that choice), and returns the validated `research-dossier`. Keep it in context — A3 reads `research.wizardInferences`; A4 embeds the `research` telemetry; A5 renders it.

> Researching your codebase in depth to ground the baseline — read-only.

> **Phase complete:** after the research engine returns the validated dossier, `TaskUpdate(onboard:adopt:phase:1:recon-research → completed)`.

## Step A3: Grounded wizard

> **Phase transition (per `../start/references/phase-tracking.md`):** `TaskUpdate(onboard:adopt:phase:2:wizard → in_progress)` now, **before** invoking the `wizard` skill (task-blind). Mark it `TaskUpdate(... → completed)` after the wizard returns the canonical `wizardAnswers` + `wizardStatus`.

Run the `wizard` skill (the grounded confirm/override surface), seeded by `research.wizardInferences`, exactly as `start` Step 2. `autonomyLevel` is asked cold (never inferred). Returns the canonical `wizardAnswers` + `wizardStatus`.

## Step A4: Catalog → synthesize baseline (in context, writes nothing)

> **Phase transition (per `../start/references/phase-tracking.md`):** `TaskUpdate(onboard:adopt:phase:3:synthesize → in_progress)` now, **before** building the record-set / meta / snapshots in context. Mark it `TaskUpdate(... → completed)` after the baseline objects are assembled in context (nothing is written yet — that is Phase 5).

Follow `references/baseline-synthesis.md` § A4. Build, in context:
- the **record-set** — one `changes[]` entry per detected artifact (`action:"record"`, `origin:"adopted"`);
- the **`onboard-meta.json`** object (`mode:"retrofit"`, `artifactProvenance` all-adopted, per-category `status:"adopted"` blocks, the `research` telemetry block, `wizardAnswers`/`wizardStatus`, `detectedPlugins`);
- the **snapshots** (current state as the baseline).

Nothing is written in this step.

> **Phase complete:** after the record-set, meta object, and snapshots are assembled in context (still nothing written), `TaskUpdate(onboard:adopt:phase:3:synthesize → completed)`.

## Step A5: Assemble previewModel + hard gate

> **Phase transition (per `../start/references/phase-tracking.md` § HARD GATE):** `TaskUpdate(onboard:adopt:phase:4:preview-gate → in_progress)` now, **before** assembling/rendering the preview. This task is the gate: it **stays `in_progress` for the entire phase** — through previewModel assembly, render, and *while awaiting the user's Adopt? decision* (the enum has no "awaiting" state; `in_progress` is the truthful "we are here, waiting on you"). Its `completed`/`deleted` transition is driven by the gate decision in sub-step 2 below — do **not** mark it `completed` at preview or render. The internally-invoked `walkthrough:render` is task-blind.

Assemble `previewModel` per `../research/references/render-adapter.md § previewModel` with:
- `flow: "adopt"`;
- `research` = architecture map + top risks + glossary from the A2 dossier (null only if research returned a minimal/empty dossier);
- `changes` = the A4 record-set;
- `decisions` = `{ model: <resolved>, autonomy: wizardAnswers.autonomyLevel, profile: "retrofit", hooks: [...detected hook events], mcp: [...detected servers], lsp: [...detected plugins], pluginIntegration: [...detectedPlugins] }`;
- `warnings` = e.g. "N artifacts have no maintenance header — they'll be offered for modernization on your next `/onboard:update`."

Then render + hard-gate exactly like `start` Phase 5 (Plan → Preview → Gate):

1. **Render.** Map `previewModel` → a walkthrough `session-model` per the render-adapter, then invoke `walkthrough:render` with `{ model, outputPath: ".claude/walkthrough/<YYYY-MM-DD-HHMM>-onboard-adopt.html" }`.
   - **walkthrough absent** → offer install via AskUserQuestion (single-select, header `"Walkthrough"`): **Install now (Recommended)** / **Skip — markdown preview**. Install now → `claude plugin install walkthrough@apurvbazari-plugins` via Bash; re-probe; success → render; failure → markdown fallback.
   - **Skip / failure / runtime render error** → **markdown gate**: present `previewModel` inline as markdown (Overview · What I learned · What I'll record grouped by tier · Key decisions · Risks). Optionally also write `.claude/onboard-adopt-plan.md`.
   - This degrades the HTML render only — never the gate.
2. **Gate.** AskUserQuestion (single-select, header `"Adopt?"`). Map each decision to a task transition per `../start/references/phase-tracking.md` § HARD GATE (the gate task was left `in_progress` at the Step A5 transition above):
   - **Approve & adopt (Recommended)** → the user accepted → `TaskUpdate(onboard:adopt:phase:4:preview-gate → completed)`, then proceed to Step A6 (write baseline).
   - **Adjust** → the user wants changes → **no status change** (the gate task stays `in_progress`); return to Step A3 (revise wizard answers), then re-run A4 → A5. The gate loops.
   - **Cancel** → the user declined → nothing was written (the gate precedes the only write step). Per § Cancel → `deleted`, mark the gate task **and every later phase task** `deleted`: `TaskUpdate(onboard:adopt:phase:4:preview-gate → deleted)`, `TaskUpdate(onboard:adopt:phase:5:write-handoff → deleted)`. Leave the already-`completed` tasks 0–3 as `completed` (they really ran). Then stop. Write nothing. Print: "Cancelled — no baseline was written; your tooling is untouched."
3. Only **Approve** advances to A6.

**Guard Usage:** the install offer and the gate both use fixed-option single-selects (≥2 options), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

## Step A6: Write baseline only + handoff

> **Phase transition (per `../start/references/phase-tracking.md`):** `TaskUpdate(onboard:adopt:phase:5:write-handoff → in_progress)` now (only reached on **Approve** at the A5 gate), **before** the baseline write below. Mark it `TaskUpdate(... → completed)` after the baseline is written and the handoff is shown (or, when entered from update, after control is handed back) — that completes the last phase of the adopt run; all 6 `adopt` tasks are now `completed`.

Follow `references/baseline-synthesis.md` § A6: write the snapshots + `onboard-meta.json`, then patch `onboard-research.json`'s `artifacts.html` to the A5 render path (or leave null on markdown fallback). **Touch no hand-crafted artifact.**

Then hand off:

> Adopted. I recorded a baseline (`.claude/onboard-meta.json` `mode:"retrofit"` + snapshots) for your existing tooling — **nothing you wrote was changed**.
>
> - Run `/onboard:update` to align your adopted tooling with the latest best practices. Adopted files are offered for modernization (e.g. adding maintenance headers) per-item — you approve each change.
> - Run `/onboard:check` for a health summary.

**If adopt was entered from `/onboard:update`'s guard:** do not print the standalone closing — instead fall straight into update's drift detection (update Step 2 onward), now that a baseline exists.

> **Phase complete:** after the baseline is written and the handoff is shown (or control is handed back to update), `TaskUpdate(onboard:adopt:phase:5:write-handoff → completed)`. All 6 phase tasks are now `completed` — the adopt run is done. **Routing reminder:** completing this list does **not** touch the caller's `onboard:update:phase:` list when adopt was entered from update's guard; that list belongs to update, which resumes its own transitions.

## Key Rules

- **Own the phase-task list end to end** — per `../start/references/phase-tracking.md`, Step 0 creates the 6 `onboard:adopt:phase:N:*` tasks; each phase marks its own task `in_progress` before its work (and before any agent/Skill dispatch) and `completed` after. The `codebase-analyzer` agent and the `research`/`wizard` skills are **task-blind** — they run inside the parent phase's task. The enum is exactly `pending`/`in_progress`/`completed`/`deleted` — no "blocked"/"cancelled". The Phase 4 preview-gate stays `in_progress` while awaiting the Adopt? decision; Approve → `completed` then write; Adjust → loop (no change); Cancel → mark tasks 4/5 `deleted`. The list is **in-session visibility only** — the durable record is the baseline meta + snapshots written at A6. When adopt was entered from `/onboard:update`'s guard, the two lists coexist; adopt never touches update's `onboard:update:phase:` tasks.
- **Never modify a hand-crafted file** — adopt's only writes are the 6 snapshots + `onboard-meta.json` + the `onboard-research.json` html patch (see `references/baseline-synthesis.md` § A6). Reading, cataloging, snapshotting — never editing.
- **Everything is `origin:"adopted"`** — Managed stance; `artifactProvenance` is all-adopted. The `"user"` value is reserved for future stances, not produced here.
- **`action:"record"` only** — the record-set never proposes creating or modifying artifacts; modernization is a later `/onboard:update`.
- **Redirect, don't overwrite** — meta already present → `/onboard:update`; no tooling at all → `/onboard:start`. Adopt is only for foreign tooling.
- **The gate is hard** — Approve writes the baseline; Adjust re-plans; Cancel writes nothing. The HTML render may degrade to markdown, but the gate is never skipped.
- **Does not call `generate`** — adopt synthesizes and writes its own baseline; it never invokes the generation pipeline (that is what keeps hand-crafted files safe).
