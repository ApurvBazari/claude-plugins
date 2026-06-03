# Authoring Guide — choosing and composing components

Once the session model is synthesized, this guide is how you turn it into a page: which catalog
component each model field calls for, when to render nothing, how to compose a bespoke component
when the catalog has no fit, and the self-contained rules every document must obey. Components come
from the `components/` recipes, indexed in `components/index.md`; tokens and signature patterns from `design-system.md`; shared handlers from
`interactivity.md`; the chrome and slots from `page-scaffold.md`.

## 1. Model → component mapping

Map each populated field of the session model to a component. A single field can drive more than
one component; pick the row that matches the field's *shape*.

| session-model field present | render |
|---|---|
| `decisions[]` with tradeoffs | tabs + bars; else accordion |
| `nodes[]` + `edges[]` | flow / architecture / dependency diagram |
| `files[]` | file tree (+ filterable cards if many) |
| `metrics[]` | stat cards / animated bar chart |
| `timeline[]` | timeline; stepper if a replayable sequence |
| `typeTags` includes `research` | concept map + callouts |
| always | hero, prose sections, detail panel, theme toggle (chrome from page-scaffold) |

Notes on the choices:

- **`decisions[]`** — use **Tabs + tradeoff bars** when each decision weighed options against scored
  axes (the bars need `data-w` magnitudes; tabs swap via `setTab`). With no scores, fall back to the
  **Accordion checklist**: one `<details>` per decision with a verdict badge and rationale in `.ac-body`.
- **`nodes[]` + `edges[]`** — choose by topology: a linear staged pipeline → **Flow diagram**; a
  non-linear system of services/layers → **Architecture map**; module/package import relationships →
  **Dependency graph** (inline SVG). All three open node detail via `openD`.
- **`files[]`** — a handful → **File tree** (`white-space:pre`, clickable `.fl` rows). Many files
  that group into categories → add **Filterable cards + pills** so the reader can narrow by `data-cat`.
- **`metrics[]`** — a few headline numbers → **Stat / metric cards**. Many comparable magnitudes →
  **Animated bar chart** (bars grow on reveal).
- **`timeline[]`** — a chronology to read top-to-bottom → **Timeline**. A sequence the reader should
  replay step-by-step → **Stepper / playback**.
- **`typeTags` includes `research`** — the session explored a topic rather than changing code → lead
  with a **Concept / mind map** and punctuate with **Callouts** for the key insights.
- **always** — the **Hero + stat grid** opens, **Prose sections** carry the narrative, the **detail
  panel** (`openD`/`openCard` open it, `closeD` and Escape close it) and **theme toggle** (`tgl`) are
  part of the page-scaffold chrome and are always present.

## 2. Omit empty, never stub

A component renders only if its model field has **real content**. A thin session may legitimately be
just the hero + a summary prose section + one component — that is a complete, honest walkthrough.

- No `files[]` → no file tree. No `decisions[]` → no tabs and no accordion. No `nodes[]`/`edges[]` →
  no diagram. The field's absence is the signal to skip the component entirely.
- Never emit an empty placeholder ("No files changed"), a component populated with dummy data, or a
  diagram with invented nodes. A missing component is correct; a fabricated one is a defect.
- Drop the matching CSS and JS too: only the used components' blocks go into `{{COMPONENT_CSS}}` and
  `{{COMPONENT_JS}}`, and `{{DETAIL_DATA}}` carries only the `DET` ids actually referenced (emit
  `const DET={};` when nothing wires a detail panel). Unused shared handlers are harmless no-ops, so
  the shared `{{INTERACTIVITY_JS}}` bundle always ships whole.

## 3. Compose a new component (the escape hatch)

When the session has content that no catalog entry fits, build a bespoke component. The bar: it must
look like it shipped with the catalog. Build it ONLY from design-system primitives and reuse the
existing interaction conventions — do not invent a parallel design language.

**Build from primitives:**

- **Surfaces** — `--bg-card` for the resting panel, `--bg-elevated` for raised/inner nodes (and
  `--bg-inset` for wells, `--bg-card-hover` for the hovered/active surface).
- **Border tiers** — `--border` at rest, `--border-active` for focus, `--border-strong` for emphasis;
  `--border-active`/`--accent` for the selected state.
- **The 6-color + `-soft` palette** — `--accent`, `--blue`, `--green`, `--amber`, `--rose`, `--purple`
  for foreground; their `*-soft` companions (`--accent-soft`, `--blue-soft`, …) for tinted fills.
- **Type roles** — `--serif` for display headings and italic `<em>` accents, `--sans` for body,
  `--mono` for eyebrows, labels, pills, code, and trees.
- **Motion + rhythm** — every transition uses `var(--ease)`; follow the spacing rhythm of the catalog
  (≈`12px`/`10px` radii, `~1rem`–`1.5rem` padding, `.6rem`–`.8rem` gaps).

**Reuse interaction conventions** (wire to the shared handlers in `interactivity.md`, never to new ones):

- **Detail panel** — open it from a node with `data-d="<id>"` + `onclick="openD('<id>')"` (add a
  matching `DET` key `{k,h,b}`), or from a card with `data-t`/`data-desc` + `onclick="openCard(this)"`.
- **Scroll reveal** — give the section/element `class="vis"`-eligible markup so the shared
  IntersectionObserver adds `.vis`; the hero starts pre-set with `class="vis"`.
- **Animated widths** — use the double-`requestAnimationFrame` reset-then-grow pattern; reuse the
  shared `animate(scope)` by giving bars `.fil` + `data-w`, or ship a scoped reveal in `{{COMPONENT_JS}}`.
- **Filtering** — `data-f` on pills + a `Set` of active values, hiding non-matching cards (the `tog`
  pattern with `data-cat`).
- **Collapse** — native `<details>`/`<summary>` (as the accordion does); no custom show/hide JS.

**Looks-native checklist:**

- [ ] Tokens only — no raw hex anywhere; every color/space/curve resolves to a `var(--…)`.
- [ ] Reuses a signature active/hover pattern — accent border plus
      `box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow)`.
- [ ] Keyboard-reachable and labelled — interactive nodes are focusable (button/`tabindex`) and carry
      an `aria-label`; SVG roots use `role="img"` + `aria-label`.
- [ ] Self-contained — all CSS/JS/SVG inline, no external assets (see §4).
- [ ] JS namespaced and guarded — guard every element lookup, add no new globals beyond a clearly
      scoped `{{COMPONENT_JS}}` block; missing elements must never throw.

## 4. Self-contained rules

Every walkthrough is a single `.html` file that works offline by double-click. Therefore:

- All CSS, JS, and SVG are **inline**. The ONLY permitted external resource is the Google Fonts
  `@import` from `design-system.md` (and even that degrades cleanly to the system fallback offline).
- No `<script src>` and no external stylesheet `<link>`.
- No `<img>` — use **inline SVG** for every graphic, icon, and diagram (this is why the dependency
  graph, mind map, and mode diagram are hand-laid SVG).
- No `alert`, `confirm`, or `prompt` — surface detail through the side panel (`openD`/`openCard`),
  never a modal dialog.
