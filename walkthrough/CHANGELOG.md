# Changelog

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
