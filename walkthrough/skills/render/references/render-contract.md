# Render Contract — the shared select → assemble → self-check → write stages

This file is the **single canonical description** of the four stages every walkthrough producer runs to turn
a finished model into the house-style HTML: **select → assemble → self-check → write**. `create`, `update`,
`document`, and `render` all PERFORM these stages by following this contract — the mechanics are stated here
once so the producer SKILLs and `CLAUDE.md` don't restate them. Each producer keeps only its own surrounding
steps inline (scope/gather/synthesize, reconstruct/merge, subject-gather, programmatic entry) and defers the
shared middle-and-end here.

`render` is the documented **terminal stage**: it is the same select → assemble → self-check → write that
every producer ends on. The user-facing producers PERFORM those stages by following this contract — they do
**not** invoke the `render` skill. The `render` SKILL is the programmatic entry for external callers (e.g.
`lens`) that arrive with a model already synthesized in context and want only the terminal stages.

## The shared stages

### select
Map the finished model to components via `../../create/references/authoring-guide.md`, then look each chosen
component up in `../../create/references/components/index.md` to find its group recipe. Apply "omit empty,
never stub"; where no catalog entry fits, compose a bespoke component per the authoring-guide recipe +
looks-native checklist.

### assemble
Copy `../../create/references/page-scaffold.md` **verbatim** — it is the base-CSS home (the base/chrome CSS
is materialized there once) — then fill its slots from the components you selected:
- `{{COMPONENT_CSS}}` / `{{COMPONENT_JS}}` — the CSS and JS for **only** the selected components, copied
  from their `../../create/references/components/<group>.md` recipes.
- `{{HERO}}` / `{{SECTIONS}}` — the hero block and one `<section>` per model section, holding the chosen
  component markup.
- `{{INTERACTIVITY_JS}}` — the shared behaviour bundle from `../../create/references/interactivity.md`, verbatim.
- `{{DATA_JSON}}` — the inert `#wt-data` island = `JSON.stringify({DET, SURF})`, with the one post-pass:
  replace `</` with `<\/` so no value can close the data block early. Pane-kind ids go to `DET`; sheet-kind
  ids are pre-rendered as `<dialog>`s in `{{SHEETS}}` (see § Review-specific assembly for the lens case).
- `{{NAV_LINKS}}` — generated deterministically from `sections[]` (one `<a href="#id">` per section, the id
  reused verbatim from the section; first link `class="on"`), never hand-written or hand-matched.
Keep it self-contained: tokens only, all CSS/JS/SVG inline, no `<script src>`, no `<img>`, only the one
Google Fonts `@import`.

### self-check
Run `../../create/references/self-check.md` against the assembled HTML (self-contained, tokens, ASCII CSS,
nav↔id bijection, DET keys, the executed `node --check` + `#wt-data` JSON-island validation). Fix any
failure and re-check — never write a document that fails the self-check.

### write
Write the assembled HTML to the caller-resolved output path, creating the directory if missing. Each producer
owns its own path resolution and post-write offer around this stage (create/document compute a timestamped
`<base>` path; update overwrites in place; render writes to the caller-supplied path).

## Inputs (programmatic entry — the `render` skill)
- **model** — a `session-model` (review fields permitted), already synthesized in context by the caller.
  The full model schema (including the review-field extensions `findings[]`, `diffHunks[]`, `adherence`, `files[].risk`, `verdict`) lives in `../../create/references/session-model.md`.
- **outputPath** — where to write (e.g. `.claude/lens/<ts>-<slug>.html`). Caller-owned; no gitignore prompt.

## Review-specific assembly
- `findings[]` → one pre-rendered dialog each in `{{SHEETS}}` (`SURF[id]='sheet'`); NOT in `DET`. Schema:
  `{kicker:"<severity> · <category>", heading:"<claim>", summary:"<detail>", where:["<location>"],
   points:["Fix: <suggestedFix>", "Status: <status>"], surface:"sheet"}`.
- `diffHunks[]` → annotated-diff; pins call `openSurface('<finding-id>')`.
- `adherence` → adherence-panel. `files[].risk` → risk coloring. `verdict` → hero chip.
- `findings[].iteration` (`fixed|still-open|new|possibly-resolved`; omit on a first review) → a second
  `.chip` on each findings-list card (`data-iter`; role fixed=ok, still-open/possibly-resolved=warn,
  new=info; static semantic hook; no JS reads data-iter — role set from the map at assemble time).
  `iterationDelta` → the findings-section delta subhead. Sheet `points` stay `["Fix: …",
  "Status: …"]` — iteration is the chip, not a point.

## Output
Return the written path. On empty context (no model) → redirect to `/walkthrough:create`, do not synthesize.
