# Changelog

## 1.2.0 — 2026-06-20

### Concept-coverage layer
- feat: `concept-coverage.md` — an auditable map of every concept-type the walkthrough can explain,
  routing each to its renderer (or a logged bespoke). Answers "what can we explain, and what's missing?"
  from one file.
- feat: `concepts[]` ledger on the session model — each concept a doc explains + how it renders.
- feat: the diagram-fidelity check is generalized into a universal **concept-fidelity gate** with an
  anti-force-fit invariant (a concept is never rendered by a component not registered for its type).
- feat: `completeness.md` gains a mechanical concept-coverage assertion + a coverage-note summary line.

### Five new renderers (concept map ships at zero uncovered rows)
- feat: **decision tree** (`branching-logic`) — labeled yes/no/condition edges, a tree, no cycles.
- feat: **ERD / schema** (`data-model`) — entity cards + cardinality connector chips.
- feat: **recursive tree** (`hierarchy`) — indented collapsible tree for deep parent→child structures.
- feat: **layer stack** (`layering`) — ordered vertical bands (tech / protocol / middleware stacks).
- feat: **cause→effect hypothesis ladder** (`causal-chain`) — debugging traces (symptom → ruled in/out → fix).
- New group files: `components/data.md`, `components/reasoning.md`. `update` reconstructs all five + the ledger.

All additive and inert-by-omission — sessions that don't need the new concepts render exactly as before.

## 1.1.0 — 2026-06-19

First marketplace release after 1.0.0 — consolidates the detail-surfaces, lens review-render layer, Cowork support, and grouped-adherence work. (These landed as internal 1.2.0–1.4.0 increments on the integration branch and were never published; folded into a single public minor bump.)

### Grouped adherence
- feat: the review adherence-panel (`components/review.md`) renders one sub-section per source spec/plan when the model carries `adherence.groups[]` (`{ source, kind, items[] }`), so multi-spec lens reviews show per-spec coverage at a glance. Falls back to the flat two-column layout when only `specItems[]`/`planSteps[]` are given. Populated by lens ≥ 1.1.0.

### Cowork-first-class
- `create` now resolves its output directory on first run: in a non-git folder (the Cowork knowledge-work case) it asks whether to write to a visible `walkthroughs/` folder or the hidden `.claude/walkthrough/`, and remembers the choice in `<base>/settings.md`. Git repositories are unaffected — they keep writing to `.claude/walkthrough/` with no new prompt.
- Documented Cowork compatibility: walkthrough is a pure-skill plugin (no hooks, no scripts), so it installs and runs in Claude Cowork and emits the same portable HTML deliverable. Added `cowork` / `claude-cowork` keywords and a "Works in Cowork" README section.
- No change to `update` / `document` (the location prompt is create-only) and no change to the synthesis model.

### Review render layer (for lens)
- feat: internal `render` skill (render a supplied model → HTML; reused by the lens plugin)
- feat: `components/review.md` — annotated-diff, findings-list, adherence-panel
- feat: optional review fields on session-model (`verdict`, `adherence`, `findings`, `diffHunks`) + `files[].risk` coloring
- fix: repoint render's session-model.md reference to ../create/references (broken cross-skill path).
- feat: review session-model gains optional `iteration` + `iterationDelta`; findings-list renders an iteration chip + delta subhead (populated only by lens).

### Detail surfaces
- Replaced the unstructured detail-panel blob (`DET{k,h,b}`) with a structured detail schema — `{kicker, heading, summary, where[], code[], points[], related[], surface?, components[]}` — rendered by a shared `renderSurface`.
- Added a centered native `<dialog>` **sheet** surface (~900px, token `::backdrop`, internal scroll) for rich details that host full catalog components, alongside the existing lightweight glance **pane**.
- Hybrid routing via `openSurface` + a `SURF` kind map: an explicit `surface` override wins, else the kind is inferred from content (hosted components, a code block, or long text → sheet).
- Capped-depth (3) nesting through the browser top layer: sheets and a reusable right-edge `paneDialog` stack via `showModal()` (free focus-trap, top-down Escape, `::backdrop`), with replace-topmost beyond the cap and an acyclic reference-graph requirement.
- Per-surface id-suffixing keeps hosted-component ids globally unique; new self-check gates enforce routing, sheet presence, id-uniqueness, acyclicity, and depth ≤ 3.
- Back-compat: `openD`/`openCard` remain as aliases; `update` reconstructs the structured store and upgrades pre-feature documents (flat `DET`, no `SURF`) on re-render.
- Lands entirely in the shared `create/references/` visual layer, so `create`, `update`, and `document` all inherit it.

### Representation fidelity + completeness gates
- New first-class catalog diagrams — **state / transition** (cyclic + guarded transitions) and **sequence / swimlane** (timed multi-actor messages) — so the two most common "no catalog entry fits" cases no longer depend on the bespoke escape hatch firing.
- Diagram-fidelity gate in `select`: a `nodes[]`+`edges[]` graph with cycles / back-edges / self-loops / guard labels routes to a state diagram, and an ordered multi-actor message exchange to a sequence diagram, instead of being force-fit into a flow / architecture map (which silently drops the cycle, guards, and lanes). Backed by a new self-check row.
- Completeness critic now derives the salient-item checklist from the source *before* comparing it to the model (so dropped detail can't be reclassified as "intentionally omitted" by the same pass), checks detail **depth** not just presence, and treats every in-session `path:line` as non-droppable — enforced by a new self-check row that no in-session code anchor is silently dropped.
- `update` reconstructs the two new diagram types; all changes land in the shared visual layer, so `create`, `update`, and `document` inherit them.

## 1.0.0 — 2026-06-05
- First stable release. Commits to a stable skill set (`create` / `update` / `document`), house style, and component-authoring API; breaking changes from here bump the major version.
- Consolidates the previously unreleased 0.3.0 and 0.4.0 cycles (the `document` skill, interactive explorer + data-timeline components, the `.chip` primitive, CSS-counter section kickers, and the shared self-check + completeness pre-write gates) into the first marketplace-stable version. See the 0.3.0 / 0.4.0 entries below for details.

## 0.4.0 — 2026-06-05

### Visual layer
- Auto-number section kickers via a CSS counter on `.sec-label` — authors write only the label text; the rendered `01 —`, `02 —`, etc. are generated automatically.
- New `.chip` primitive with five semantic status roles (`ok`, `info`, `warn`, `danger`, `neutral`) for inline status badges inside any component.

### Navigation
- Deterministic nav-link generation from the synthesized section list — nav entries are derived directly from `sections[]`, eliminating hand-rolled duplication.

### Component catalog
- New catalog group `components/interactive.md` with two entries: an interactive explorer (selector-driven diagram + detail pane) and a data-driven step timeline.

### Pre-write gates (shared by all three skills)
- Shared structural self-check (`self-check.md`): verifies self-containment, token usage, ASCII-only CSS, nav↔id alignment, and DET key integrity before write.
- Shared completeness gate (`completeness.md`): a salient-item coverage critic runs after synthesis; a passive coverage note appears in the offer step.

### `create` skill
- Proliferation guard: when a same-subject/slug file already exists in `.claude/walkthrough/`, `create` now prompts with three options (update-in-place / new versioned file / overwrite) instead of silently appending `-2` / `-3` to the filename.
- New intent trigger: "walk me through it" (and "walk me through this/that") now triggers `create` alongside the existing "visualize this session" / "session recap" patterns.

### `update` skill
- Reconstruct stage strips a legacy `NN —` hard-coded kicker prefix when rebuilding section labels, ensuring compatibility with the new CSS counter.

## 0.3.0
- Add `/walkthrough:document` — render any **subject** (a plugin, the marketplace, or any path) as a
  self-contained interactive HTML document in the same house style. Reuses `create`'s visual layer
  (design-system, interactivity, page-scaffold, components) unchanged and brings a generic
  `subject-model` plus plugin/marketplace adapters. README + manifest are the canonical source.
  Powers the repo's GitHub Pages site.

## 0.2.0
- Restructure the component catalog: the 678-line `components.md` is split into a slim
  `components/index.md` (a name→recipe routing table, always read) plus five role-grouped recipe
  files (`diagrams`, `decisions`, `files-timeline`, `metrics`, `layout-prose`). The renderer reads
  the index always and loads only the group files for components it actually uses. Recipes are
  byte-identical; rendered output is unchanged.
- Remove the `collect-git-context.sh` helper and its smoke test — walkthrough is now script-free.
  Walkthroughs synthesize from the session transcript (plus direct file reads for real `path:line`
  citations), not repository state: git context was redundant with the conversation for the plugin's
  purpose (brainstorming, spec / ADR / tech-guideline walkthroughs) and went stale once work was
  committed. The nav kicker now draws on session metadata (date · type · scope) instead of branch/commit.
- Add `/walkthrough:update` — refresh an existing walkthrough HTML in place. Reconstructs the prior
  content from the chosen document (the embedded `DET` detail store is the high-fidelity source),
  folds in explicitly-named spec/source files, and overwrites the same file as one coherent
  document. Always confirms the target before overwriting; user- and intent-invokable; reuses
  `create`'s references unchanged for rendering. No new file, no backup, no update chrome.

## 0.1.0
- Initial release. `/walkthrough:create` renders the current session as a self-contained
  interactive HTML document in a fixed house style (dark + warm-light themes). On-demand;
  user- and intent-invokable. Output to `.claude/walkthrough/`.
