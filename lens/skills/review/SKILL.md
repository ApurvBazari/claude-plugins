---
name: review
description: Review the current session's changes against their spec and plan, adversarially verify the findings, and render an interactive review document. Use when the user wants to review what was just built before it ships, runs /lens:review, or asks to "review my changes / review this before I commit". Reviews Claude's own work; read-only.
---

# Review — Intent-Grounded Review of the Current Session

You are invoked via `/lens:review [target]`. Run the engine, then render. You are **read-only**:
never commit, edit, or block — produce the artifact; the human decides.

## Step 0: Create the task list (standalone only)
Create the in-session progress task list per `references/task-tracking.md` — one `TaskCreate` per stage,
all `status:"pending"`: `scope`, `intent`, `analyze`, `verify`, `reconcile`, `render`, `report`, plus
`setup` **only** when `.claude/lens/settings.md` is absent. Keep each returned `taskId`. As the pipeline
runs, mark each **review-owned** task (`setup`, `reconcile`, `render`, `report`) `in_progress` when its
step begins and `completed` when it ends; the four **engine-owned** tasks (`scope`, `intent`, `analyze`,
`verify`) are transitioned by the engine via the `taskIds` you hand it in Step 2. In **orchestrator /
compute-only mode** (see below) **skip this step entirely — create no tasks and pass no `taskIds`.**

## Step 1: First-run setup (guard)
If `.claude/lens/settings.md` is absent, run `references/setup.md`: ask via AskUserQuestion (1) gitignore
the `.claude/lens/` dir? (offer "artifacts only — track the registry" so teams can share finders) and
(2) the default output path; persist to `settings.md`. On later runs, just read settings.

## Step 2: Run the engine
Invoke `lens:engine` (Skill tool), passing the target + the project finders registered in settings + (on
the standalone path) `taskIds = { scope, intent, analyze, verify }` so the engine transitions those four
stages as it runs. It returns a `review-findings` object in context.

## Step 3: Reconcile (state-aware)
Read `.claude/lens/review-state.json` for this target (if present). Match each engine finding to a prior
one by **fingerprint** per `references/reconcile.md` (dimension + normalized claim + nearest *stable*
context — never the raw line number); label **fixed / still-open / new** and flag low-confidence
matches *"possibly-resolved — verify"*. **Compute** the severity trend and the updated state map **in
memory** here — the write-back to `review-state.json` is deferred to Step 5 (after a successful render). (v1.1 `acknowledged`/won't-fix carry-forward is **not yet wired** — no input path in v1.)

## Step 4: Render (lens-render)
Build the review-model from the **reconciled** findings per `references/review-model-assembly.md`
(narrative + `adherence` from `requirements` findings + `findings[]` each with its `iteration` field (fixed/open/new → iteration chip) + the `iterationDelta` +
severity trend + `files[].risk` + `diffHunks[]` + derived `verdict`). If `walkthrough` is installed,
invoke `walkthrough:render` with the model in context and output path
`<configured-path>/<YYYY-MM-DD-HHMM>-<slug>.html` (default `.claude/lens/`). Otherwise emit a markdown
report per `references/markdown-fallback.md`.

## Step 5: Write state, then report
**Write-back (after a successful render only).** Now that Step 4 produced an artifact, write the state map
computed in Step 3 back to `.claude/lens/review-state.json` — the single state write. On a render failure,
**skip the write** so the state never advances without an artifact (no stale `fixed` labels next run).
Then tell the user the path + the one-line `verdict` + the iteration delta (e.g. "2 fixed · 1 new"); offer
to open (never auto-open).

## Orchestrator mode (compute-only)
When invoked by an **orchestrator** (not `/lens:review`), run Steps 2–3 only, then **return** the
reconciled `{findings, delta, severityTrend}` object in context and **skip Step 4 (render) and Step 5
(state write)** — the orchestrator persists and renders at its own gate (see `references/reconcile.md`
§ Orchestrator mode). In this mode **create no task list and pass no `taskIds`** (the orchestrator owns its
own progress display) — so the engine runs task-silent, exactly as its data-only contract specifies.
Standalone `/lens:review` runs all steps unchanged.

## Key Rules
- **Read-only (except `review-state.json`).** Never commit, edit, stage, or block; the only write is the state file + the rendered doc.
- **Engine owns judgment; review owns rendering + state.** Keep the boundary clean — this skill adds no findings, the engine holds no state.
- **State-aware.** Re-running reconciles vs `review-state.json` (fixed/open/new); never re-flag a finding as new just because lines moved.
- **walkthrough optional.** Markdown fallback when absent (announce the degrade).
- **Compute-only when orchestrated.** An orchestrator caller gets the reconciled object returned and lens writes nothing; only standalone `/lens:review` writes `review-state.json` (after render).
- **In-session task list (standalone only).** `/lens:review` surfaces progress via a `TaskCreate` list per `references/task-tracking.md`; orchestrator/compute-only mode creates none. Subjects are display-only; finder subagents are task-blind.
