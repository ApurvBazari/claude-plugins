# Render Contract — the shared select → assemble → self-check → write stages

This file is the **single canonical description** of the four stages every walkthrough producer runs to turn
a finished model into the house-style HTML: **select → assemble → self-check → write**. `create`, `update`,
`document`, and `render` all PERFORM these stages by following this contract — the mechanics are stated here
once so the producer SKILLs and `CONVENTIONS.md` don't restate them. Each producer keeps only its own surrounding
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
- `{{SYSMAP_ENGINE}}` — when the page has at least one system map, the engine block holding only its
  marker line (`../../create/references/page-scaffold.md`, "The engine block"); otherwise delete the slot.
  The engine itself goes in after write (see "insert the system-map engine" below). No other line of the
  page may be exactly the marker: if the page's own content has to show the marker text, write its first
  slash as `&#47;`.
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

### insert the system-map engine (after write, only when the page has a `.sysmap`)
The engine is one file, `system-map-engine.js`, in `create/references/`. Your skill names its path in its
own body, because a path variable is only replaced there. Put the file into the written page by the first
of these that works:

1. **Find the path.** Use the path your skill gave you if it is a real path with no literal `${` left in
   it. Otherwise build it from your skill's base directory: `<base>/references/system-map-engine.js` in
   `create`, `<base>/../create/references/system-map-engine.js` in `update`, `document` and `render`.
2. **Shell insert.** Run this one command, with `<ENGINE>` and `<PAGE>` replaced by the two real paths:

   ```bash
   ENGINE='<ENGINE>' PAGE='<PAGE>'; [ -r "$ENGINE" ] && awk -v f="$ENGINE" '$0=="/*@@SYSMAP-ENGINE@@*/"{n++; while((getline l < f)>0){print l; c++} close(f); next} {print} END{exit (n==1 && c>0)?0:1}' "$PAGE" > "$PAGE.tmp" && mv "$PAGE.tmp" "$PAGE" || { rm -f "$PAGE.tmp"; false; }
   ```

   It replaces the marker line with the file. It fails, and leaves the page untouched, when the shell
   cannot read the engine file or when the marker line is not there exactly once.

   The command does not say why it failed. If the engine file is readable and the page path is right, the
   marker line is the cause: it is missing, is there more than once, or is indented. Check that it is in the
   page exactly once and starts at column 0, fix the block, and run the command once more. A second marker
   line in the page's own content is fixed by the marker rule above (write its first
   slash as `&#47;`). Go to step 3 only if it fails again.

   **Never run it when either path contains a single quote (`'`). Go to step 3 instead.** In the command
   the two paths sit inside single quotes, which make every other character inert. A single quote in a
   path would end that quoting, and the rest of the path would run as shell. Do not try to escape it.
   Replace `<ENGINE>` and `<PAGE>` with the literal paths and never build either with a shell expansion
   (a variable, `$(...)`, a backtick or a glob): inside the single quotes an expansion stays plain text
   and names no file, and to make it expand you would have to leave the quotes, where nothing is inert.
   The same rule holds for any other shell command you run on the page, such as the checks below.
3. **Type it.** Only when step 2 is not possible (there is no shell, the shell cannot read the file, or a
   path contains a single quote) or has failed twice:
   read the engine file and replace the marker line with its content, character for character. Do not
   shorten, reformat or improve it.
4. **Neither works.** Delete the whole `<script id="wt-sysmap">` block. The map keeps its plain view.

**Check the result** of step 2 or 3: no line of the page is the marker any more; the line
`/* walkthrough system-map engine v1 */` and the line `/* end walkthrough system-map engine */` each
appear exactly once inside the `<script id="wt-sysmap">` block (a page's own content may show them); and
`node --check` passes on the block (self-check #20, when node is available). If the check fails,
repair the block once. If it still fails, do step 4.

**Say which path ran.** The offer message (for `render`, the value returned to the caller) carries
exactly one of these lines:

- `System map engine: inserted by shell command.`
- `System map engine: typed by the model (<why the shell could not be used>).`
- `System map engine: not included (<why>). The map shows as the plain view.`

## Inputs (programmatic entry — the `render` skill)
- **model** — a `session-model` (review fields permitted; `graphs[]` and the system-map fields permitted),
  already synthesized in context by the caller.
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
Return the written path and, when the page has a system map, the `System map engine: …` line. On empty context (no model) → redirect to `/walkthrough:create`, do not synthesize.
