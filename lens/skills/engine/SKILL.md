---
name: engine
description: Internal data-only review engine — scope a diff, build an intent record from spec+plan, run parallel finders + the read-only adapter registry, dedup, adversarially verify, severity-rank, and RETURN review-findings JSON. Writes nothing, never prompts. Invoked by lens:review and (later) consumable by vicario. Not user-invocable.
user-invocable: false
---

# Engine — the data-only review core

Produce a `review-findings` object (per `../../schemas/review-findings.schema.json`) and RETURN it to
the caller. Write no files; ask no questions. Read `references/pipeline.md` + `references/finder-registry.md`.

## Step 1: Scope
Resolve the target (default: working tree + branch commits vs the merge-base with the default branch;
caller arg overrides). No repo / empty diff → return `{findings:[],recommendedEscalation:"minor",degraded:false}`.

## Step 2: Intent
Build the intent record: explicit args > latest `docs/superpowers/specs/*` > the plan > transcript.
None found → reconstruct from the transcript and set `degraded:true`.

## Step 3: Analyze
Dispatch the built-in finder agents concurrently (`spec-adherence`, `plan-adherence`, `correctness`,
`risk-classify`, `test-gaps`). Then run the **finder registry** per `references/finder-registry.md`:
the **adapter tier** (the 5 read-only adapters, when installed) + the **project tier** (custom finders
registered in `.claude/lens/settings.md`). Read-only ENFORCED at the boundary.
Tag every candidate with its `dimension` per the producer->dimension map.

If any dispatched finder/adapter returns null, errors, or yields no parseable output, record the failed producer and set `degraded:true` (a partial review is not a complete one). Name the missing dimension(s) in `summary`.

## Step 4: Verify + dedup + rank
Dedup by (file, line, title). Send each survivor to the `verifier` agent (refute-by-default for bug
claims; keep `requirements` gaps; verify-error -> `verified:false` flagged, never dropped). Aggregate
the verifier's per-finding vote(s) into `votes{total,couldNotRefute,refuted}` and set `verified`
accordingly; drop refuted findings. Compute `recommendedEscalation` = max surviving severity.

## Step 5: Return
Return the schema-valid `review-findings` JSON. No file write, no prompt.

## Key Rules
- **Data only.** Return JSON; never write a file or prompt — the caller owns I/O and any gate.
- **Schema-valid.** Output must validate against `review-findings.schema.json` (the vicario contract).
- **Read-only adapters.** Enforce findings-only at the adapter boundary; skip absent providers silently.
- **Nothing dropped silently.** Verify-errors surface as `verified:false`. Set `degraded:true` whenever coverage is partial — a finder/adapter returned null or errored, intent was reconstructed, or a huge diff was truncated — and name the gap in `summary`.
