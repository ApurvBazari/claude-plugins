# Render Contract — model in, HTML out

`render` is the terminal stage every producer feeds (create/document/update synthesize then render;
lens judges then renders). It accepts a model already in context + an output path, and runs
select → assemble → self-check → write using `../create/references/` unchanged.

## Inputs
- **model** — a `session-model` (review fields permitted), already synthesized in context by the caller.
  The full model schema (including the review-field extensions `findings[]`, `diffHunks[]`, `adherence`, `files[].risk`, `verdict`) lives in `../create/references/session-model.md`.
- **outputPath** — where to write (e.g. `.claude/lens/<ts>-<slug>.html`). Caller-owned; no gitignore prompt.

## Review-specific assembly
- `findings[]` → one `DET` entry each, `SURF[id]='sheet'`, pre-rendered into `{{SHEETS}}`. Schema:
  `{kicker:"<severity> · <category>", heading:"<claim>", summary:"<detail>", where:["<location>"],
   points:["Fix: <suggestedFix>", "Status: <status>"], surface:"sheet"}`.
- `diffHunks[]` → annotated-diff; pins call `openSurface('<finding-id>')`.
- `adherence` → adherence-panel. `files[].risk` → risk coloring. `verdict` → hero chip.

## Output
Return the written path. On empty context (no model) → redirect to `/walkthrough:create`, do not synthesize.
