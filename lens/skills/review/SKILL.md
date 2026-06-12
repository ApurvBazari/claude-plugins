---
name: review
description: Review the current session's changes against their spec and plan, adversarially verify the findings, and render an interactive review document. Use when the user wants to review what was just built before it ships, runs /lens:review, or asks to "review my changes / review this before I commit". Reviews Claude's own work; read-only.
---

# Review — Intent-Grounded Review of the Current Session

You are invoked via `/lens:review [target]`. Run the engine, then render. You are **read-only**:
never commit, edit, or block — produce the artifact; the human decides.

## Step 1: First-run setup (guard)
If `.claude/lens/settings.md` is absent, run `references/setup.md`: ask via AskUserQuestion (1) gitignore
the `.claude/lens/` dir? (offer "artifacts only — track the registry" so teams can share finders) and
(2) the default output path; persist to `settings.md`. On later runs, just read settings.

## Step 2: Run the engine
Invoke `lens:engine` (Skill tool), passing the target + the project finders registered in settings. It
returns a `review-findings` object in context.

## Step 3: Reconcile (state-aware)
Read `.claude/lens/review-state.json` for this target (if present). Match each engine finding to a prior
one by **fingerprint** per `references/reconcile.md` (dimension + normalized claim + nearest *stable*
context — never the raw line number); label **fixed / still-open / new** and flag low-confidence
matches *"possibly-resolved — verify"*. **Compute** the severity trend and the updated state map **in
memory** here — the write-back to `review-state.json` is deferred to Step 5 (after a successful render).

## Step 4: Render (lens-render)
Build the review-model from the **reconciled** findings per `references/review-model-assembly.md`
(narrative + `adherence` from `requirements` findings + `findings[]` with the fixed/open/new iteration label (carried in each finding's detail/points per review-model-assembly.md) +
verdict trend + `files[].risk` + `diffHunks[]` + derived `verdict`). If `walkthrough` is installed,
invoke `walkthrough:render` with the model in context and output path
`<configured-path>/<YYYY-MM-DD-HHMM>-<slug>.html` (default `.claude/lens/`). Otherwise emit a markdown
report per `references/markdown-fallback.md`.

## Step 5: Write state, then report
**Write-back (after a successful render only).** Now that Step 4 produced an artifact, write the state map
computed in Step 3 back to `.claude/lens/review-state.json` — the single state write. On a render failure,
**skip the write** so the state never advances without an artifact (no stale `fixed` labels next run).
Then tell the user the path + the one-line `verdict` + the iteration delta (e.g. "2 fixed · 1 new"); offer
to open (never auto-open).

## Key Rules
- **Read-only (except `review-state.json`).** Never commit, edit, stage, or block; the only write is the state file + the rendered doc.
- **Engine owns judgment; review owns rendering + state.** Keep the boundary clean — this skill adds no findings, the engine holds no state.
- **State-aware.** Re-running reconciles vs `review-state.json` (fixed/open/new); never re-flag a finding as new just because lines moved.
- **walkthrough optional.** Markdown fallback when absent (announce the degrade).
