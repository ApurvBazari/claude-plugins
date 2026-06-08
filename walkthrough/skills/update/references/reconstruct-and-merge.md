# Reconstruct & Merge — turn an existing walkthrough back into a model, then refresh it

`update` has no persisted session model to start from: the only record of prior work is the rendered
HTML. This reference covers the two stages unique to `update` — **reconstruct** the session model
from that HTML (Part A), then **merge** it with the newly-gathered material into one coherent,
refreshed model (Part B). Once you have the merged model, hand off to the create renderer
(`authoring-guide.md` → `components/` (via `components/index.md`) → `page-scaffold.md`) unchanged.

The model shape is defined in `session-model.md`. Use its exact field names — they are load-bearing
keys for the renderer's mapping table.

## Part A — Reconstruct the model from rendered HTML

A walkthrough is a lossy *render* of a `session-model`. Most content survives (prose is inline, and
the detail-panel store is embedded verbatim). Reconstruction reads the rendered anchors — defined in
`page-scaffold.md` — back into model fields. Read the chosen `.html`, then map:

| Rendered anchor | Recover into | Notes |
|---|---|---|
| `<title>… — walkthrough</title>` | `title` | strip only the trailing ` — walkthrough` suffix (the title itself may contain an em-dash — do not split on every ` — `) |
| `<h1>…</h1>` in `#top` | `title` display | `<em>…</em>` marks the accent word — preserve which word was emphasized |
| `<div class="eyebrow">…</div>` in `#top` | *(hint only)* | the hero eyebrow is authored free text that loosely echoes the session's type/topic — use it as a hint for `typeTags`, not an authoritative source |
| Hero chip row, if rendered (the `typeTags` render per `session-model.md`) | `typeTags[]` | canonical source, but the chip markup is under-specified in the create renderer, so recovery is best-effort: read the chips if present, else infer the tags from the eyebrow text + section topics. Do NOT use the nav kicker (`{{KICKER}}`) — it is session/project metadata with no model field |
| `<p class="lede">…</p>` in `#top` | `summary` | the one-paragraph recap |
| `.hstats` → `.hstat` (`.v`, `.l`) | `metrics[]` (`value`, `label`) | hero headline numbers |
| `<section id="X">` → `.sec-label` + `<h2>` + body | `sections[]` (`id` = the `id` attr, `heading` = `<h2>`, `prose` = section copy) | one entry per non-hero `<section>`; recover only the narrative copy into `prose` — component markup inside the section (diagrams, tabs, trees) is recovered via the other rows, not flattened into `prose` |
| `<div class="nav-links"><a href="#id">label</a>…` | `sections[].id` order + nav labels | confirms the section spine |
| Diagram markup (flow / architecture / dependency / state `.statemap` / sequence `.seq`) | `nodes[]`, `edges[]` | identify by the component's class names in `components/diagrams.md`; edge direction/labels re-derived from rendered arrows/labels (best-effort). A `.statemap` SVG → `nodes[]` (`kind:"state"`) + `edges[]` with `guard` lifted from `.sm-guard` text; a `.seq` swimlane → `nodes[]` (`kind:"actor"`, one per `.seq-head`) + `edges[]` as timed messages (`.seq-msg` order → `seq`, `--c1`/`--c2` + `.rtl` → `from`/`to` lanes) |
| Tabs + tradeoff bars, or accordion `<details>` | `decisions[]` (`title`, `why`, `alternatives`, `tradeoffs[{axis, score}]`) | bar widths carry the score — read `data-w="N"` back into `score`; the tab / `.ac-body` copy is `why` / `alternatives` |
| File tree / filterable cards | `files[]` (`path`, `change`, `note`) | `change` is encoded by the row's color/badge class |
| Timeline / stepper | `timeline[]` (`t`, `label`, `ref`) | `ref` is the anchor each entry scrolls to |
| Trailing `const DET={…}` in the `<script>` | `details{}` | **highest-fidelity source** — see below |
| Trailing `const SURF={…}` in the `<script>` | `details{}[id].surface` | the `{{SURFACE_MAP}}` slot — maps each id to `'pane'`/`'sheet'`; recovers the surface kind |
| Pre-rendered `<dialog class="sheet" id="sheet-<id>">` blocks | `details{}` (sheet-kind) | the `{{SHEETS}}` slot — structured `sf-*` header + hosted components recover the rich detail; see below |

### Reconstruction notes

- **Section kicker.** Read each `.sec-label` as the section label. A pre-0.4.0 document bakes the
  number into the text (`01 — flow`); strip a leading `NN[ —-]` so the CSS counter does not
  double-number after re-render. Store only the label.

### The `DET` store + `SURF` map + sheet dialogs are the reliable path for `details{}`

The detail data is embedded verbatim in the page `<script>` and body. Parse it directly rather than
re-deriving from prose. Reverse the `details → DET/SURF/{{SHEETS}}` transform documented in
`page-scaffold.md` + `authoring-guide.md` § 3:

- **`const SURF={ "<id>": "pane"|"sheet" }`** (the `{{SURFACE_MAP}}` slot) — read first; it tells you
  which shell each id used, and re-creates the model's `surface` field.
- **Pane-kind** (`SURF[id]!=='sheet'`) — read `DET[id]` from the structured
  `const DET={ "<id>": {k,h,summary,where,code,points,related} }` literal (the `{{DETAIL_DATA}}` slot):
  `kicker`=`k`, `heading`=`h`, and `summary`/`where[]`/`code[]`/`points[]`/`related[]` map back to the
  same-named fields verbatim (arrays stay arrays).
- **Sheet-kind** (`SURF[id]==='sheet'`) — the detail is NOT in `DET`; read its pre-rendered
  `<dialog class="sheet" id="sheet-<id>">`: `sf-kicker`→`kicker`, `sf-h`→`heading`, `sf-summary`→`summary`,
  `sf-where`(`sf-loc` chips)→`where[]`, `sf-code`→`code[]`, `sf-points`→`points[]`, `sf-related`→`related[]`,
  and recover the hosted catalog components into `components[]` (strip the per-surface id-suffix, e.g.
  `xpTabs-rich` → `xpTabs`). Set `surface:'sheet'`.
- **Nesting** — a hosted component's nodes wired `onclick="openSurface('<id>')"` re-create the
  cross-detail references; preserve them so the refreshed model keeps the same nesting (still bounded
  acyclic + depth ≤ 3 per `session-model.md`).

### Back-compat: a pre-feature doc (flat `DET`, no `SURF`)

A walkthrough rendered BEFORE detail surfaces has the OLD flat `const DET={ "<id>": {k,h,b} }`, no
`SURF`, and no sheet dialogs. Detect this shape — `DET` records carry a `b` field and there is no
`const SURF=` — and reconstruct EVERY detail as **pane-kind**: `kicker`=`k`, `heading`=`h`, and lift the
`b` body HTML into `summary` (pull the `<code>path:line</code>` anchor out into `where[]` and trailing
cross-links into `related[]`, as the old transform did). No sheets; every `surface` defaults to pane. So
`update` on a pre-feature walkthrough still works — it transparently upgrades the flat details into the
structured schema on re-render.

### What is re-derived, not recovered (accept it)

Stable ids beyond `sections[].id` / `details{}` keys, the *full* `alternatives` list behind a decision
(only what was rendered survives), and precise `edges[]` semantics are reconstructed heuristically. Do
not fabricate structure that is not visible — if a field cannot be recovered, leave it empty and let
the merge fill it from the new material.

### Degraded input

If the file is hand-edited, minified, or missing the `DET` store, reconstruct what is parseable and
tell the user the fidelity is partial. Never invent decisions, files, or metrics that are not in the
HTML.

## Part B — Merge into one coherent, refreshed model

Goal: ONE up-to-date document, not the old model with new material stapled on. Combine the
reconstructed prior model with the newly-gathered material (the named files + conversation framing),
field by field:

- **Revise** — when new material supersedes prior content (a decision reversed, a file changed, a
  metric updated), rewrite that entry to the current state. Do not keep the stale version beside it.
- **Merge** — when new material overlaps an existing section/decision, fold it in; keep one entry.
- **Add** — genuinely new material becomes new `sections[]` / `decisions[]` / `nodes[]` / `files[]`.
- **Preserve identity** — keep existing `sections[].id` and `details{}` keys stable across the refresh
  so the document does not silently restructure each update (anchors, nav links, and the detail panel
  stay consistent). Only change an id when its meaning genuinely changed.
- **Omit empty, never stub** — unchanged-but-still-relevant content stays as-is; nothing becomes a
  placeholder or an "N/A" row.

The result is a normal `session-model` (same schema), indistinguishable from one `create` would
synthesize fresh — it simply happens to incorporate reconstructed history. Hand it to the renderer
unchanged.
