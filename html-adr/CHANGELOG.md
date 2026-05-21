# Changelog

## 0.1.0 — 2026-05-21

Initial release.

- `/html-adr:render <path>` — render a markdown spec into single-file interactive HTML
- Auto-extracted ADR fields with confidence + provenance shown inline
- Hybrid section recognition (canonical headings + frontmatter override)
- Cytoscape overview graph + Mermaid inline + ASCII pretty-print
- Item-level drill-in side panel (file rows, pipe steps, edge cases, deps, risks, rollback steps, test bullets)
- Vendored Cytoscape 3.30.4, cytoscape-dagre 2.5.0, dagre 0.8.5, Mermaid 11.4.1, highlight.js 11.10.0
- 48 unit + e2e tests; 6 fixture golden-diff suite
- Single-file output ~3.4MB with all assets inlined (no CDN at view time)

### Known limitations (v0.2 candidates)

- Six widget templates under `templates/widgets/` (data-flow, edge-cases, dependencies-risks, rollback-path, testing, generic-prose) are committed as design artifacts but not loaded at render time — the corresponding builders in `scripts/plugins/widget-builders.mjs` emit HTML via template literals. `mermaid-block.html` is a true orphan (its builder is a one-liner). v0.2 should either wire builders to load templates or remove the unused files.
- `affected-files.html` is the only widget template loaded at runtime (via `loadTemplate` in `render-templates.mjs`).
- TOC scroll-spy navigation, overview-graph rendering slot (`{{graphSection}}`), and cross-spec-mentions plumbing through to file-row drill metadata are scaffolded but not wired end-to-end in v0.1.
