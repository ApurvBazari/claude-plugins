# Component Catalog — Index

Curated catalog — a floor, not a ceiling. Each entry is copy-and-fill, uses ONLY design-system tokens (never raw hex), and wires to the shared handlers in `interactivity.md`. Render only components with real content (see `authoring-guide.md`). For anything not here, compose a bespoke component per `authoring-guide.md` §"compose a new component".

Every entry below carries **When** (the session content that triggers it), an **HTML** snippet (copy-and-fill — replace `<placeholders>`), a **CSS** block (paste once into the document `<style>`; identical classes can share one paste), and a **Wiring** line naming the shared handler from `interactivity.md`. Component-unique JS, where unavoidable, is flagged as a `{{COMPONENT_JS}}` snippet to append to the shared bundle.

Each component's full recipe (When / HTML / CSS / Wiring) lives in the group file named below —
read **only** the group files for the components you actually select. Paths are relative to this
`components/` directory.

| Component | When (one line) | Recipe |
|---|---|---|
| Hero + stat grid | Always — opening title, summary, headline numbers | `layout-prose.md` |
| Prose section | A narrative-only section | `layout-prose.md` |
| Tabs + tradeoff bars | Decisions with scored trade-off axes | `decisions.md` |
| Flow / pipeline diagram | A linear staged sequence | `diagrams.md` |
| Architecture map | Non-linear services / layers | `diagrams.md` |
| Dependency graph | Module / package imports | `diagrams.md` |
| Morphing-mode diagram | One structure shown in multiple modes | `diagrams.md` |
| State / transition diagram | States with guarded or cyclic transitions (back-edges, retry loops, self-loops) | `diagrams.md` |
| Sequence / swimlane diagram | Time-ordered messages exchanged between multiple actors | `diagrams.md` |
| File tree | A handful of changed files | `files-timeline.md` |
| Filterable cards + pills | Many discrete items grouped by category | `files-timeline.md` |
| Stat / metric cards | A few headline numbers | `metrics.md` |
| Animated bar chart | Many comparable magnitudes | `metrics.md` |
| Accordion checklist | Decisions without scored axes | `decisions.md` |
| Diff panes | Before / after code or text | `decisions.md` |
| Comparison table | Options compared across criteria | `decisions.md` |
| Timeline | A chronological story of versions/milestones | `files-timeline.md` |
| Stepper / playback | A replayable ordered sequence | `files-timeline.md` |
| Callouts | A single point needing emphasis — caveat, insight, constraint | `layout-prose.md` |
| Key–value metadata grid | Label→value pairs / edge cases / open questions | `layout-prose.md` |
| Annotated code block | A code snippet shown verbatim with a filename header | `layout-prose.md` |
| Concept / mind map | A central idea branching into sub-concepts | `diagrams.md` |
| Legend | A key explaining diagram symbols / colors | `layout-prose.md` |
| Interactive explorer | A selector driving a live diagram + detail pane from one data model | `interactive.md` |
| Data-driven step timeline | Phases of parallel/sequential steps with source pills + micro-cycles | `interactive.md` |
| Annotated diff | A reviewed change — `diffHunks[]` with inline finding pins | `review.md` |
| Findings list | Review `findings[]`, severity-ranked + filterable by category | `review.md` |
| Adherence panel | `adherence` — spec items + plan steps marked met/partial/missing | `review.md` |

## Composing beyond the catalog — see `authoring-guide.md`.
