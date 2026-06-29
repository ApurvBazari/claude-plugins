---
name: render-review
description: Internal pure-render entrypoint — given a review-findings object (plus optional prior findings, a diff ref, and intent), reconcile in-memory, assemble the review-model, and render the interactive HTML via walkthrough:render. Writes ONLY the output HTML; no lens state, no recompute, no task list. Invoked by an orchestrator (e.g. matali) that owns persistence + the gate.
user-invocable: false
---

# Render Review — Pure HTML Render of a review-findings Object

You are invoked by an **orchestrator** (not a human). You take a review-findings object that has
ALREADY been computed (by `lens:engine`), render it to a self-contained interactive HTML review
document, and return the written path. You are **stateless and write-once**: the only file you create
is the caller's `outputPath`. You never write `review-state.json`, never create a task list, and never
re-run finders.

## Your inputs (supplied in context by the caller)
- `findings` — the current `review-findings` object (required).
- `priorFindings` — a prior-run `review-findings` object (optional; enables reconcile).
- `diffRef` — a git ref/range to read for annotated diff hunks (optional).
- `spec` / `plan` / `adherence` — intent for the adherence matrix (optional).
- `outputPath` — the absolute path to write the HTML (required; create the dir if absent).

## Step 1: Reconcile (compute-only, in memory)
If `priorFindings` is supplied, reconcile `findings` against it per `../review/references/reconcile.md`
**§ Orchestrator mode** — fingerprint by dimension + normalized claim + stable context, label each
finding `fixed | still-open | new | possibly-resolved`, and compute `delta {fixed,new,stillOpen}` +
`severityTrend`. Write NOTHING. If `priorFindings` is absent, skip — this is a clean first pass (no
iteration labels, no trend).

## Step 2: Assemble the review-model
Build the review-model per `../review/references/review-model-assembly.md`: narrative spine +
`adherence` (from the `adherence` block / `requirements`-dimension findings) + `findings[]` (each with
`iteration`, `status`, `location`, `claim`, `detail`, `suggestedFix`) + `files[].risk` + `diffHunks[]`
(read `diffRef` if supplied; omit the panel if unavailable) + derived `verdict` (from
`recommendedEscalation`). Apply omit-empty; never stub.

## Step 3: Render
If `walkthrough` is installed, invoke `walkthrough:render` with the assembled model in context and the
caller's `outputPath`. Otherwise emit a markdown report per `../review/references/markdown-fallback.md`
to `outputPath` with a `.md` extension.

## Step 4: Return
Confirm the artifact exists and is non-empty, then return `{ renderedPath: <path>, delta?, severityTrend? }`
(or the line `wrote: <path>`). On any failure, return `skipped: <one-line reason>` — never partial state,
never an exception that blocks the caller.

## Key Rules
- **Write-once.** The only file you create is `outputPath`. No `review-state.json`, no task list.
- **No recompute.** You render the findings you were given; you never re-run finders or re-judge.
- **Degrade, never block (R10).** Missing walkthrough → markdown fallback; missing diff → omit hunks;
  any failure → `skipped:`.
- **Reuse, don't fork.** Reconcile + assembly logic live in `../review/references/`; cite them, do not
  reimplement.
