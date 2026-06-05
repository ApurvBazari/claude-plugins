# Changelog

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
