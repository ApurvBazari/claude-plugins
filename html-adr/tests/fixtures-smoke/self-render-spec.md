---
adr:
  status: proposed
  date: 2026-05-20
  decision_makers: [Apurv Bazari]
  decision: >
    Build a new `adr` plugin that renders a single authored markdown spec into a
    single self-contained interactive HTML page, using Node + the unified/remark/rehype
    ecosystem for markdown processing and vendored frontend bundles (Cytoscape + dagre,
    Mermaid, highlight.js) for view-time interactivity.
  drivers:
    - best-in-class markdown parsing (remark + GFM + frontmatter + footnotes)
    - rich ADR-shape rendering with item-level drill-in
    - single-file HTML output, offline-capable at view time
    - deterministic visual output (templates + CSS authored once via frontend-design)
    - heuristic ADR extraction with confidence + provenance shown inline
  options:
    - name: A. Python stdlib + hand-rolled GFM parser
      summary: Stdlib-only Python orchestrator with a hand-rolled markdown subset parser.
      pros:
        - Zero external runtimes beyond Python 3
        - Matches greenfield's (orphaned) precedent
      cons:
        - ~400 LOC of brittle parser we own forever
        - GFM edge cases (pipes in code spans, nested fences) will bite repeatedly
        - '"Matches orphaned plugin" is a weak precedent'
      verdict: rejected
    - name: A2. Python + markdown-it-py
      summary: Python with a real markdown library (markdown-it-py / mistune) via pip.
      pros:
        - Proper CommonMark/GFM parser, no hand-rolling
        - Stays Python (consistent with any future Python tooling)
      cons:
        - markdown-it-py's plugin ecosystem is materially smaller than remark's
        - rehype's HTML-side transformation plugins (slug/autolink/highlight) have no equivalent quality on the Python side
        - Adds pip dependency without unlocking the rich ecosystem we want
      verdict: rejected
    - name: B. Node + unified/remark/rehype
      summary: Node-based renderer using the unified ecosystem — remark for markdown AST, rehype for HTML AST + transformations. Frontend bundles vendored as before.
      pros:
        - Battle-tested CommonMark/GFM/frontmatter/footnote parsing
        - Massive plugin ecosystem (remark-gfm, remark-frontmatter, rehype-slug, rehype-autolink-headings, rehype-highlight, rehype-stringify, etc.)
        - Clean AST → AST → HTML pipeline; transformations compose
        - Node ≥20 is ubiquitous; `npm install` is a normal one-time setup step
      cons:
        - Adds Node + npm to plugin setup requirements
        - Plugin maintenance includes dependency upgrades
      verdict: chosen
    - name: C. Pandoc orchestrator + post-processor
      summary: Pandoc converts markdown to preliminary HTML; a post-processor wraps canonical sections.
      pros:
        - Smallest amount of new code
        - Pandoc handles every markdown quirk
      cons:
        - Adds pandoc as a system dependency (brew/apt install)
        - Post-processor brittle against pandoc version changes
        - Lower control over the AST than remark/rehype
      verdict: rejected
  consequences:
    positive:
      - Output HTML opens with zero network calls (all assets vendored + inlined)
      - Markdown parsing is robust (no hand-rolled parser)
      - Item-level drill-in extracts from source markdown + filesystem + git — no future-dated content
      - Visual output is deterministic (templates + CSS + pinned assets)
      - Plugin ergonomics are clean (`npm install` once, then `/adr:render <path>`)
    negative:
      - First-time install requires Node ≥20 + `npm install` (heavier than a zero-dep alternative)
      - ~700KB inlined per output file (acceptable, ~250KB gzipped)
      - Vendored frontend libraries drift behind upstream; manual quarterly refresh script
  validation:
    - v0.1 ships and the plugin's own design doc (this file) renders cleanly via `/adr:render`
    - All 6 fixtures in tests/fixtures/ produce byte-equal HTML against golden files
    - Manual browser inspection shows ADR header, section widgets, overview graph, and item-level side-panel drill all working
  links:
    - reference: greenfield-4.0.0 tag (orphaned render_adr.py + serve_adr.py)
    - reference: MADR template — https://adr.github.io/madr/
    - reference: Nygard original ADR — https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
    - reference: unified ecosystem — https://unifiedjs.com
---

# ADR plugin — interactive HTML renderer for design specs

## Context

This repository ships a Claude Code plugin marketplace with four production plugins (onboard, greenfield, notify, handoff). Brainstorming-skill design specs are written as plain markdown to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. They are dense, long, structured, and rarely re-read in full because plain markdown lacks navigation, visual hierarchy, and interactive cross-referencing between sections.

A prior attempt — `greenfield/scripts/render_adr.py` + `serve_adr.py` (tagged `greenfield-4.0.0`, since orphaned) — produced an interactive ADR renderer with Cytoscape graphs, SSE updates, and approve/skip/edit actions. That tooling was wedded to the greenfield wizard's in-progress state JSON, not to a written markdown spec. When greenfield was orphaned that capability went with it.

The gap is: **no first-class way to read an authored design spec interactively in a browser.** The author writes a 30–40KB markdown doc through `/superpowers:brainstorming`; everyone (including the author next week) reads it as plain text in their editor or as a flat GitHub render. The ADR-shape of these docs — multiple options considered, a recommendation, trade-offs, consequences — is invisible in flat markdown, and the cross-section relationships (which files touched, which risks roll back to which steps) require manual scanning.

## Decision drivers

- **Best-in-class markdown parsing.** Hand-rolling a GFM-subset parser was the original plan; rejected after review because the cost of owning ~400 LOC of brittle parser outweighs every supposed benefit. The unified/remark ecosystem solves this with battle-tested CommonMark + GFM + frontmatter + footnotes support.
- **Offline-capable at view time.** Output HTML must open with zero network calls. All JS/CSS dependencies are vendored and inlined at render time. Node is a build-time dep only.
- **Single-file output.** A rendered ADR is one HTML file — checkable into git, mailable, hostable anywhere, no `/assets` sibling directory needed.
- **Item-level drill that's truthful.** Inner items (file rows, pipe steps, edge case cards) drill into a side-panel detail view fed by data we actually have at render time — source spec content, filesystem checks, git provenance, cross-spec scans. No "click for code I haven't written yet."
- **Heuristic ADR extraction with safeguards.** The author should not adopt a new authoring structure. Existing brainstorming-skill specs are the input; the renderer infers ADR fields from natural section shape and shows its work (confidence + provenance) inline so trust is verifiable.

## Considered options

### A. Python stdlib + hand-rolled GFM parser (rejected)

Stdlib-only Python orchestrator with a hand-rolled markdown subset parser (~400 LOC).

**Why rejected.** The supposed benefit was "matches greenfield precedent" — but greenfield is orphaned, so the precedent is suspect. The "no node" pattern isn't sacred; this repo already breaks "no compiled" by having Python in greenfield's history. The hand-rolled parser is real ongoing cost: every GFM edge case (pipes inside code spans, nested fences, blockquoted code, table alignment quirks) becomes a bug. Not worth owning when remark handles it.

### A2. Python + markdown-it-py (rejected)

Python with `markdown-it-py` (or `mistune`) for proper CommonMark/GFM parsing.

**Why rejected.** Viable middle ground. The markdown-it-py library itself is excellent. But the project's transformation needs aren't just "parse markdown" — they're "parse markdown, walk the AST to extract ADR fields, transform to HTML AST, attach widget metadata, inline graph data, syntax-highlight code, stringify to HTML." That AST → AST transformation is exactly what rehype's plugin library is built for, and there's no equivalent in the Python ecosystem at comparable quality. So the choice was: take Node for the rich pipeline, or take Python and rebuild rehype's transformations ad-hoc.

### B. Node + unified/remark/rehype (chosen)

Node-based renderer using the unified ecosystem.

**Pipeline:** `unified → remark-parse → remark-frontmatter → remark-gfm → [custom plugin: extract-adr] → [custom plugin: recognize-sections] → [custom plugin: build-graph] → remark-rehype → rehype-slug → rehype-autolink-headings → rehype-highlight → [custom plugin: render-templates] → rehype-stringify`.

**Pros.**
- Every stage of the AST → HTML transformation has an off-the-shelf, battle-tested package.
- The custom plugins (extract-adr, recognize-sections, build-graph, render-templates) are thin walkers over the AST, not parser rewrites.
- Node ≥20 is ubiquitous on developer machines. `npm install` once is normal.
- The frontmatter parsing (remark-frontmatter + js-yaml) handles full YAML — including the spec's own `decision: >` folded scalars and `options:` list-of-dicts — natively. No fallback scope creep.

**Cons.**
- Adds Node + npm to plugin setup. First-time install runs `npm install` (~30s, dependencies cached afterward).
- Plugin maintenance includes dependency upgrades. Mitigated by quarterly cadence.

### C. Pandoc orchestrator + Python post-processor (rejected)

Shell + Python wrapping pandoc.

**Why rejected.** Adds pandoc as a system dependency (`brew install pandoc`). Pandoc's HTML output is rigid; section-wrapping by post-processing is brittle. The unified pipeline gives more control over the same problem.

## Decision outcome

**Chose Approach B.** The unified/remark/rehype pipeline is the right primitive for an AST-transforming markdown renderer. The custom logic (extract ADR fields, recognize canonical sections, build the overview graph, render to templates) is what we own; the parsing and HTML generation are not. Node + npm is a routine setup cost that buys a battle-tested foundation we'd otherwise reimplement.

## Plugin shape and invocation surface

```
adr/
├── .claude-plugin/
│   └── plugin.json                name: adr, version: 0.1.0
├── README.md
├── CLAUDE.md
├── CHANGELOG.md
├── package.json                   declares Node ≥20, unified + plugins, dev deps
├── package-lock.json
├── skills/
│   └── render/
│       └── SKILL.md               /adr:render entrypoint
├── scripts/
│   ├── render-adr.mjs             CLI orchestrator: parses argv, runs pipeline, writes output
│   ├── plugins/
│   │   ├── extract-adr.mjs        unified plugin: AST → ADRFields with confidence + provenance
│   │   ├── recognize-sections.mjs unified plugin: AST → [(SectionType, content)]
│   │   ├── build-graph.mjs        unified plugin: sections + cross-refs → Cytoscape graph data
│   │   ├── render-templates.mjs   unified plugin: applies widget templates per section
│   │   └── inline-assets.mjs      unified plugin: replaces <link>/<script> with inlined content
│   ├── git-provenance.mjs         git log / status helpers
│   ├── cross-spec-scan.mjs        grep helper: find references in sibling specs
│   └── update-vendored-assets.sh  checksum-verified bundle refresher
├── templates/
│   ├── shell.html                 page chrome: top bar, sticky TOC, overview-graph slot, body slot
│   ├── adr-header.html            status/decision/drivers/options/consequences block
│   ├── widgets/
│   │   ├── affected-files.html
│   │   ├── data-flow.html
│   │   ├── edge-cases.html
│   │   ├── dependencies-risks.html
│   │   ├── rollback-path.html
│   │   ├── testing.html
│   │   ├── generic-prose.html     fallback for unrecognized headings
│   │   ├── mermaid-block.html
│   │   └── side-panel.html        side-panel layout (item-level + section-level drill)
│   └── styles.css                 single bundled stylesheet, authored via frontend-design skill
├── assets/                        vendored, pinned, checksum-verified
│   ├── cytoscape-3.30.4.min.js
│   ├── cytoscape-dagre-2.5.0.min.js
│   ├── dagre-0.8.5.min.js
│   ├── mermaid-11.4.1.min.js
│   ├── highlight-11.10.0.min.js
│   ├── highlight-github.min.css
│   └── runtime.js                 plugin's own runtime (side panel, TOC scroll-spy, item-drill handlers)
├── tests/
│   ├── fixtures/
│   ├── golden/
│   └── *.test.mjs                 Node test runner (`node --test`)
└── docs/
    └── EXTRACTION-RULES.md        user-facing reference for ADR field extraction
```

**Marketplace registration:** add an entry to `.claude-plugin/marketplace.json` with `version: "0.1.0"` matching `plugin.json`.

**CLI form:**

```
/adr:render <path-to-spec.md> [--out <path>] [--open] [--no-overwrite]
```

- `<path-to-spec.md>` — required.
- `--out <path>` — optional. Defaults to sibling: `foo-design.md` → `foo-design.html`.
- `--open` — optional. Opens the generated HTML via `open` (macOS) / `xdg-open` (Linux).
- `--no-overwrite` — optional. Errors out if the output path exists.

**Pre-flight checks** in the skill before invoking the script:

1. `node --version` ≥ 20.
2. Source file exists and ends in `.md`.
3. `${CLAUDE_PLUGIN_ROOT}/node_modules/` exists; if missing, run `npm install` automatically (one-time, ~30s) before proceeding.
4. `assets/` directory contains all expected bundles with non-zero size.

**Top-bar chrome (rendered HTML).** The rendered HTML's top bar shows: brand mark + source spec path + meta (ADR number, date, status pill). **No action buttons** — the artifact is static and offline; there's nothing for an "Open source" or "Re-render" button to call back to.

## Rendering pipeline (data flow)

```
                                ┌─────────────────────────────────────┐
                                │ /adr:render foo-design.md           │
                                └────────────────┬────────────────────┘
                                                 │
                                                 ▼
                          ┌──────────────────────────────────────────────┐
                          │ render-adr.mjs (orchestrator)                │
                          │  validate node version + node_modules,       │
                          │  read source md as UTF-8 text                │
                          └──────────────────────────────────────────────┘
                                                 │
                                                 ▼
                          ┌──────────────────────────────────────────────┐
                          │ unified()                                    │
                          │   .use(remarkParse)                          │
                          │   .use(remarkFrontmatter, ['yaml'])          │
                          │   .use(remarkGfm)                            │
                          │   .use(extractAdr)        ← custom plugin    │
                          │   .use(recognizeSections) ← custom plugin    │
                          │   .use(buildGraph)        ← custom plugin    │
                          │   .use(remarkRehype, { allowDangerousHtml }) │
                          │   .use(rehypeSlug)                           │
                          │   .use(rehypeAutolinkHeadings)               │
                          │   .use(rehypeHighlight)                      │
                          │   .use(renderTemplates)   ← custom plugin    │
                          │   .use(inlineAssets)      ← custom plugin    │
                          │   .use(rehypeStringify)                      │
                          └──────────────────────────────────────────────┘
                                                 │
                                                 ▼
                              ┌─────────────────────────────────────┐
                              │ Augmentation passes (side channels): │
                              │   git-provenance.mjs                 │
                              │     date, authors, branch hint       │
                              │   cross-spec-scan.mjs                │
                              │     other specs in same dir → links  │
                              └─────────────────┬───────────────────┘
                                                ▼
                                ┌───────────────────────────────┐
                                │ stdout / write to --out path  │
                                │ foo-design.html (single file) │
                                └───────────────────────────────┘
```

**Pipeline invariants:**

- **Pure functional plugins.** Each custom plugin is a unified plugin (a function that takes options and returns a transformer over the tree). Plugins do not mutate ambient state; they annotate the AST with `node.data` fields the next stage reads.
- **AST is ground truth.** No plugin re-parses raw markdown. Once `remarkParse` produces the mdast, every downstream stage walks it.
- **`extractAdr` and `recognizeSections` consume disjoint heading sets.** `extractAdr` looks at H2s matching CONTEXT/RECOMMENDATION/ARCH_DECISION_ALT (for ADR-header content). `recognizeSections` looks at H2s matching the widget canonical names (AFFECTED_FILES/DATA_FLOW/etc.). A heading can't be both.
- **Frontmatter override applies inside `extractAdr` after auto-extraction.** Auto-extracted result is preserved in `node.data.extractionLog` so the rendered HTML can show "auto-extracted X; overridden to Y".
- **`inlineAssets` is the last transformation.** It replaces `<link rel="stylesheet" href="..." />` and `<script src="..." />` with inlined `<style>` / `<script>` blocks read from `assets/`. This is what guarantees single-file portable output.

## Section widget catalog

The hybrid rule: detect canonical sections by heading name; allow per-section override via `sections_override` in frontmatter.

```
# Heading match table (case-insensitive, regex-anchored)

AFFECTED_FILES      ^(affected files?|files changed|files affected)$
DATA_FLOW           ^(data flow|flow|pipeline|how (it|this) works)$
EDGE_CASES          ^edge cases?$
DEPS_RISKS          ^(dependencies( & risks)?|risks?|threats?)$
ROLLBACK            ^rollback( path)?$
TESTING             ^(testing|tests|test plan)$
ARCH_DECISION_ALT   ^(approach|option|alternative)\s*[a-c1-3]\b   # consumed by extractAdr
CONTEXT             ^(context|background|goal|problem|why)$        # consumed by extractAdr
RECOMMENDATION      ^(recommendation|decision|chosen approach|outcome)$  # consumed by extractAdr
GENERIC_PROSE       fallback for any other heading
```

Each widget has three behaviors: how it renders the section as a whole; how the **section card click** opens the side panel; how individual **inner items** drill into their own side-panel detail.

### AFFECTED_FILES widget

**Input shape:** unordered list of file paths, optionally with status markers (`new`, `modified`, `deleted`, or no marker).

**Rendered as:** card with file count badge; each row shows monospace path + a status pill (`new` green, `modified` amber, `deleted` red, default neutral gray "touched"). Paths ending `/` get a folder icon; files get a file icon by extension.

**Section card click → side panel shows:** section heading match (regex), confidence, full source text, count of files by status.

**Inner item (file row) click → side panel shows:**
- Full file path
- Status pill with reasoning (which marker was detected, or "no marker — defaulted to touched")
- Filesystem existence check: `✓ exists at this path` or `✗ not yet on disk` (extractor calls `fs.access` at render time)
- `git log -n 5 --format='%h %cs %s' <path>` output if the file is tracked
- Cross-spec scan: other specs in `docs/superpowers/specs/` that mention this file path (relative-link rendering)
- Source-spec line where the file is mentioned (link to anchored line in the rendered output)

### DATA_FLOW widget

**Input shape:** ASCII flow diagram in a code fence, or ordered list of steps.

**Rendered as:** pretty `<pre>` for ASCII with a "view as graph" toggle (Cytoscape-rendered draggable nodes); horizontal pill pipeline for ordered lists.

**Section card click → side panel shows:** section heading match, confidence, full source text, step count.

**Inner item (pipe step) click → side panel shows:**
- Step name
- Context paragraph from source spec (paragraph immediately preceding or following the step list, if any)
- If the step text matches a known filename pattern (e.g., `render-adr.mjs`): filesystem existence + `git log` + cross-spec mentions, same as AFFECTED_FILES inner drill
- If the step text matches an inline-code phrase: a syntax-highlighted view of that code fragment

### EDGE_CASES widget

**Input shape:** unordered list where each top-level bullet is a case; optional nested bullet for handling.

**Rendered as:** 2-column card grid. Severity inferred by keywords (`must`/`fail` → red; `should`/`warn` → amber; default → blue). Severity shown with confidence indicator.

**Section card click → side panel shows:** section heading match, confidence, full source text, case count by severity.

**Inner item (case card) click → side panel shows:**
- Case title + full handling prose
- Severity reasoning: which keyword in the case title triggered the severity color, or "no severity keyword — defaulted to blue"
- Related items in this spec: ROLLBACK steps or TESTING bullets whose text shares ≥2 significant keywords with the case (keyword overlap heuristic, surfaced as "may be related" not "definitely related")
- Anchored link back to the case's source line

### DEPS_RISKS widget

**Input shape:** unordered list, possibly grouped under sub-headings (`### External` / `### Internal`).

**Rendered as:** chip-list of mentioned packages/services; risks render as warning callouts below.

**Section card click → side panel shows:** section heading match, confidence, full source text, dep + risk count.

**Inner item (dep chip) click → side panel shows:**
- Package name + version pin (parsed from the chip text, e.g., `cytoscape@3.30.4`)
- Auto-resolved upstream URL (npmjs.com if `^[a-z][a-z0-9-]*$` or `@scope/name`; pypi.org if mentioned alongside Python context; github.com if a `<user>/<repo>` form is detected)
- The paragraph in source spec where this dep is first mentioned

**Inner item (risk callout) click → side panel shows:**
- Full risk prose + any nested mitigation bullet
- Cross-link to ROLLBACK steps in this spec whose text references the risk's mitigation strategy (keyword overlap)
- Cross-link to EDGE_CASES whose handling matches the mitigation

### ROLLBACK widget

**Input shape:** ordered list of steps.

**Rendered as:** numbered step list inside a serious red-tinted card. Git commits / branches / file paths in step content become inline code chips.

**Section card click → side panel shows:** section heading match, confidence, full source text, step count.

**Inner item (rollback step) click → side panel shows:**
- Full step prose
- Inline code chips broken out as a list (each command / file / branch is a row)
- If a referenced file is mentioned: filesystem existence check + cross-spec mentions
- "Returns to state: X" sentence if explicitly present in the step

### TESTING widget

**Input shape:** unordered list, often grouped by type.

**Rendered as:** checklist-style with category icons inferred from grouping sub-headings.

**Section card click → side panel shows:** section heading match, confidence, full source text, test count by category.

**Inner item (test bullet) click → side panel shows:**
- Full test description
- Category (parsed from sub-heading)
- If the bullet mentions a fixture path (e.g., `tests/fixtures/foo.md`): filesystem existence check
- If the bullet mentions a test file (e.g., `test_render.test.mjs`): filesystem existence + line where the bullet's keyword appears

### GENERIC_PROSE widget (fallback)

For any H2 that doesn't match a canonical type.

**Rendered as:** plain card with full markdown rendering.

**Section card click → side panel shows:** "non-canonical heading — fell to GENERIC_PROSE" + suggestion to add `sections_override`.

**Inner items: no drill** (we don't know the shape). Hover affordances are removed for GENERIC_PROSE inner content — visually flat to signal "no drill available here".

### MERMAID_BLOCK widget

Triggers on any ` ```mermaid ` fence anywhere in the doc.

**Rendered as:** client-side render via Mermaid 11.4. On parse error, the widget renders as `<pre>` with source + a red error badge + the error message inline.

**No drill** — the Mermaid diagram is the content; there's nothing meaningfully deeper to show.

**Closed-list policy.** Any heading not in the canonical regex table falls to GENERIC_PROSE. The plugin does NOT do fuzzy matching or NLP synonym detection — silent-misclassification risk outweighs convenience. Authors who want `## Threat Model` rendered as DEPS_RISKS add `sections_override: {"Threat Model": "DEPS_RISKS"}` to frontmatter.

## ADR extraction rules (per-field)

For each ADR field, the exact rule used by `extract-adr.mjs`. Earlier rules win.

**`title`** — (1) first H1; (2) filename without date prefix and `-design.md` suffix, title-cased. Confidence: always `high`.

**`date`** — (1) `YYYY-MM-DD` prefix on filename; (2) frontmatter `adr.date`; (3) `git log --diff-filter=A --reverse --format=%cs -- <path> | head -1`; (4) current date. Confidence: `high` (1–3), `low` (4).

**`decision_makers`** — (1) frontmatter `adr.decision_makers`; (2) `git log --format=%an -- <path> | sort -u`; (3) field omitted. Confidence: `high` (1–2).

**`status`** — (1) frontmatter `adr.status`; (2) inline `**Status:** <value>` or `> Status: <value>` at top; (3) branch hint — `main`/`master` → `accepted`, other branches → `proposed`; (4) `git status` shows uncommitted modifications → `draft`. Confidence: `high` (1–2), `medium` (3), `low` (4).

**`context`** — (1) body under first H2 matching `/^(context|background|goal|problem|why)/i`; (2) all prose between H1 and first H2 of any kind; (3) field omitted. Confidence: `high` (1), `medium` (2).

**`decision_drivers`** — (1) frontmatter `adr.drivers`; (2) bullets under any H3 matching `/^(drivers?|constraints?|requirements?|must.?haves?|forces)/i`; (3) sentences in context matching `/\b(must|need to|cannot|required to)\b/i` (surfaced behind an "inferred" expander, not authoritative); (4) empty list. Confidence: `high` (1–2), `low` (3).

**`considered_options`** — H2/H3 headings matching `/^(approach|option|alternative)\s*[a-c1-3]\b/i` or `/^[A-C]\s*[—-]\s*/`. For each option:

- `pros[]` = bullets under sub-heading `/^pros?$/i`, OR bullets prefixed `+ `, OR bullets after `**Pros:**` lead-in.
- `cons[]` = same pattern for `^cons?$`, `- ` prefix, `**Cons:**` / `**Trade-offs:**`.
- `summary` = first paragraph in the option's content before any sub-heading.
- `verdict` = `chosen` if heading contains `(Recommended)`/`(Chosen)`; `rejected` if `(Rejected)`/`(Not chosen)`; else `null`.

If fewer than 2 options are detected, the field is `n/a` and triggers the "no alternatives detected" degradation path (see below). Confidence: `medium-high` (≥2 options with pros/cons), `medium` (≥2 with summary only), `low` (ambiguous headings).

**`decision_outcome`** — (1) frontmatter `adr.decision`; (2) option with `verdict == "chosen"` — outcome string is `"Chose {name}: {summary}"`; (3) body under H2 matching `/^(recommendation|decision|chosen approach|outcome|verdict)/i`; (4) first sentence matching `/^(we (will|chose|recommend|are going with)|the (chosen|recommended) (approach|option))\b/im`. Confidence: `high` (1–3), `medium` (4).

**`consequences`** — Shape `{positive: [...], negative: [...]}`. (1) frontmatter `adr.consequences`; (2) bullets under sub-heading `/^(positive|pros?|benefits)$/i` inside Consequences H2 → `positive`; same for `/^(negative|cons?|drawbacks|trade-?offs)$/i` → `negative`; (3) single ungrouped bullet list classified by sentiment heuristic; (4) EDGE_CASES severity-red items as last-resort fallback. Confidence: `high` (1–2), `medium` (3), `low` (4).

**`links`** — All markdown links + bare references to other ADR filenames in the same directory resolved to relative URLs. Confidence: `high`.

**Conflict resolution.** Frontmatter always wins. Otherwise lower-numbered rules win. Every extraction decision is recorded in `<script id="extraction-log" type="application/json">…</script>` for audit.

**No-alternatives degradation.** If `considered_options` has fewer than 2 entries, the renderer omits the ADR header at the top and renders the doc as a plain interactive design spec with a banner: "This spec doesn't contain a multi-option decision. Rendered as a design doc rather than an ADR. To force ADR rendering, add an `adr:` frontmatter block."

## Error handling

| Failure | Behavior |
|---|---|
| Node version < 20 | Hard fail with `node --version` output + minimum required |
| `node_modules/` missing | Auto-run `npm install` once; surface progress; proceed if exit 0; fail with stderr otherwise |
| Plugin assets missing / zero-byte | Hard fail with exact path |
| Source markdown unreadable | Hard fail with path + what was tried |
| Frontmatter YAML malformed | Hard fail with line + column of YAML error (from js-yaml's `YAMLException`) |
| remark parse error (rare — unsupported CommonMark extension) | Render anyway; banner names the unsupported feature + line; offending block renders as `<pre>` |
| Mermaid syntax error | Widget-local: `<pre>` + red error badge inside the widget; page renders normally |
| `buildGraph` cross-ref unresolved | Graph node rendered with strikethrough label + "missing" tooltip |
| `extractAdr` finds <2 options | Skip ADR header, render as plain spec, info banner |
| Extraction field has zero matches at every rule level | Field omitted (never fabricated) |
| `git log` unavailable | Date falls through to today's date (`low` confidence); decision_makers field omitted |
| Item-level drill data fetch fails (e.g., `fs.access` on a file the spec mentioned but doesn't exist) | Side panel shows the explicit failure mode (`✗ file not found at <path>`) — not a crash |

Every error path emits a structured warning to stderr AND appends to the `extraction-log` JSON block in the output HTML. No silent failures.

## Edge cases

1. **Spec has 0 H2 sections (only H1 + prose).** Empty section list. `extractAdr` still extracts context from the body. Graph is empty; overview-graph slot hidden via CSS `:empty` selector. Clean "intro-only" HTML page.

2. **Heading uses non-canonical spelling** (e.g., `## File Impact`). Falls to `GENERIC_PROSE`. Banner suggests `sections_override`.

3. **Frontmatter override conflicts with auto-extraction.** Frontmatter wins. Auto result preserved in `extraction-log`. Small "⚠ overridden" badge appears next to that field in the rendered ADR header.

4. **Same H2 heading appears twice.** First match wins for canonical types. Second occurrence renders as GENERIC_PROSE. Warning to stderr.

5. **Mermaid block uses unsupported syntax.** Mermaid.js client parser catches it; widget shows error badge. Rest of page unaffected.

6. **Source spec is on `develop` branch, status auto-detected as `proposed`.** Correct per rules. Author overrides via frontmatter when the decision is accepted but not yet merged.

7. **Output path already exists.** Overwrites by default. `--no-overwrite` is the explicit opt-in.

8. **`> 1 MB` markdown input.** Not explicitly guarded. Pipeline is O(n); should render in <1s for normal spec sizes.

9. **Item-level drill references a file that doesn't exist on disk yet** (common for greenfield specs). Side panel shows `✗ not yet on disk` rather than failing — that's accurate information, not an error.

## Rollback path

1. Remove the plugin entry from `.claude-plugin/marketplace.json`.
2. Mark `adr/` orphaned with `adr/.orphaned_at $(date +%s)` (matches the existing `greenfield/.orphaned_at` precedent).
3. Generated `*.html` files keep working — every asset inlined. Optional cleanup: `find docs/superpowers/specs -name '*.html' -delete`.
4. No persistent state to unwind: no config files in `~/.claude/`, no hooks installed, no MCP servers, no background processes. The plugin is purely functional.
5. `node_modules/` inside the plugin directory can be deleted with `rm -rf adr/node_modules` — no cleanup beyond that.

**Risk callouts:**

- **Heuristic extraction may misread non-standard specs.** Mitigated by: confidence + provenance shown inline; "no alternatives" degradation path; frontmatter override always available.
- **Vendored JS bundles drift behind upstream.** Mitigated by `scripts/update-vendored-assets.sh` — a checksum-verified bundle refresher. Cadence: quarterly.
- **`~700KB` inlined per output file.** Mitigated by acceptable gzip ratio (~250KB). If it bites later, `--external-assets` flag emits a sibling `foo-design.assets/` dir.
- **Node + npm install adds friction for first-time users.** Mitigated by: pre-flight check auto-runs `npm install` once; clear progress output; idempotent on subsequent runs.

## Testing

**Framework:** Node's built-in test runner — `node --test 'tests/**/*.test.mjs'`. No extra test framework dep. (Vitest is a reasonable alternative if richer DX becomes needed; ship without it for v0.1.)

**Assertion lib:** Node's built-in `node:assert/strict`.

**Pyramid:**

```
                      ┌─────────────────────────────┐
                      │ Manual dogfood              │
                      │  (this spec rendered &      │
                      │   opened in browser)        │
                      └─────────────────────────────┘
              ┌─────────────────────────────────────────────┐
              │ End-to-end: fixture spec → golden HTML diff │
              │ (6 fixtures covering each major branch)     │
              └─────────────────────────────────────────────┘
   ┌─────────────────────────────────────────────────────────────┐
   │ Unit: each unified plugin tested as a pure AST transform    │
   │   extract-adr · recognize-sections · build-graph ·          │
   │   render-templates · inline-assets · cross-spec-scan        │
   └─────────────────────────────────────────────────────────────┘
```

**Unit layer.** One `*.test.mjs` per plugin. Each test constructs a small mdast AST inline (no markdown parsing in the test), applies the plugin's transformer, asserts on the resulting AST or annotations.

- `extract-adr` — each rule from above gets ≥2 tests: happy path that fires the rule + "should not fire" that proves no over-trigger. Confidence labels are part of the assertion.
- `recognize-sections` — every canonical match + GENERIC_PROSE fallback + frontmatter override.
- `build-graph` — node count, edge count, cross-ref resolution (resolved + unresolved).
- `render-templates` — each widget template applied to a synthetic section node produces the expected HTML structure (DOM-level assertion via `parse5` or string contains).
- `inline-assets` — verifies CDN `<link>` / `<script>` tags get replaced with inlined content.
- `cross-spec-scan` — fixture directory of mini-specs, assert which references resolve.

**End-to-end layer (golden tests).**

```
tests/fixtures/
├── well-formed-spec.md            3 options, full pros/cons, all canonical sections
├── no-alternatives-spec.md        pure implementation spec → ADR header omitted, banner shown
├── frontmatter-override.md        auto-extract overridden; tests conflict path
├── malformed-mermaid.md           mermaid widget shows error badge, page renders
├── minimal-h1-only.md             intro-only render
└── ascii-flow-detection.md        ASCII diagram with → │ ┌─┐ └─┘ in Data Flow
```

Byte-equal diff after normalization (strip `extraction-log` script block, whitespace inside `<script>` / `<style>` tags, and graph-data line numbers). On diff, the test writes `.actual.html` alongside the golden for visual inspection. Update via `UPDATE_GOLDEN=1 node --test`.

**What we don't test.**

- Cytoscape / Mermaid / dagre / highlight.js behavior — upstream libraries.
- `open` / `xdg-open` — mocked via `child_process` stub.
- Network/CDN — assets are vendored. No network at test, render, or view time.

**Manual dogfood (the final gate before merge).** One shell command in the PR description:

```bash
node adr/scripts/render-adr.mjs \
  docs/superpowers/specs/2026-05-20-adr-renderer-plugin-design.md \
  --open
```

…rendering this spec into HTML and viewing it. The spec exercises ADR header extraction (4 options including A2, recommendation, decision drivers), every canonical widget at least once, the auto-built overview graph, the item-level drill for every widget, and ASCII flow diagrams. If the plugin renders its own design doc convincingly with full item-level interactivity, that's the strongest possible signal it works.

**CI integration.** The repo's `/validate` skill adds:

- `shellcheck adr/scripts/update-vendored-assets.sh`
- `cd adr && npm test` (runs `node --test`)
- `cd adr && npm run lint` if ESLint is configured (defer for v0.1; add when warranted)
- Reference-integrity: every file in `adr/templates/` and `adr/assets/` must be referenced from at least one `adr/scripts/**/*.mjs`.

## Visual design

`templates/styles.css`, `templates/shell.html`, `templates/adr-header.html`, and every widget template in `templates/widgets/` are authored using the `superpowers:frontend-design` skill during v0.1 implementation, not hand-rolled with generic conventions. The rendered output must avoid generic-AI aesthetics: opinionated typography scale, deliberate spacing rhythm, distinctive color treatment for status badges and severity indicators, considered empty-state handling, and a coherent visual identity that signals "this is a designed artifact, not a generated dump". The frontend-design pass is a gating concern for v0.1 — manual dogfood inspection at PR time includes a visual-quality acceptance check, not just "the HTML rendered without errors".

## Visual consistency

The rendered HTML output is **visually identical for every spec** — same layout, same color palette, same typography, same widget chrome. Only the content varies. Concretely:

- **Templates are static files** on disk. Same on every render.
- **`styles.css` is one file** compiled into the output. Authored once during v0.1; never recomputed.
- **Vendored JS assets are pinned by version + SHA256 checksum.** Only `update-vendored-assets.sh` modifies them, on a quarterly cadence with team review.
- **Pipeline is deterministic.** Same input markdown → byte-equal output (modulo the timestamp in `extraction-log`, which is normalized out of golden tests and isn't visually rendered).

What varies per spec:
- Number / content of section cards (driven by which canonical sections the spec has)
- Graph nodes / edges (driven by sections + cross-refs)
- Field values in the ADR header (driven by extraction)
- Item-level side-panel content (driven by source spec + filesystem + git state)

What does NOT vary per spec:
- Color palette, typography, spacing rhythm
- Card layouts, widget chrome, side-panel design
- Status badge styles, severity colors, button affordances
- Graph node styling, edge styling, dagre layout algorithm
- Top-bar chrome (brand + source path + meta — no action buttons)

**Future theme knob.** Per-spec visual themes (e.g., a more compact "minimal" theme for short specs, a fuller "editorial" theme for big ones) are explicitly deferred to v0.2. The v0.1 design assumes one visual identity.

## Open follow-ups (post-v0.1)

Explicitly out of scope for v0.1, captured for the implementation plan's "future work" section:

- **`theme:` frontmatter knob** — per-spec visual themes. v0.2 candidate.
- **Live-watch server** — `/adr:watch` skill that pushes updates as the source file changes. v0.2 if manual-render workflow proves friction.
- **PostToolUse hook** — auto-rebuild HTML when Claude edits a spec under `docs/superpowers/specs/`. Opt-in via plugin setting.
- **Multiple specs → site mode** — render a directory of specs as a navigable site with cross-spec graph. v0.3 candidate.
- **`--external-assets` flag** — emit sibling `foo-design.assets/` dir instead of inlining 700KB per output. Add when file size becomes a real complaint.
- **Item-level drill enrichment** — once implementation files exist, the side panels for DATA_FLOW pipe steps could include the actual function docstring / signature / line range. Currently deferred because v0.1 renders specs before implementation lands.
- **TypeScript** — scripts could be `.mts` with type-checking via `tsc --noEmit`. Defer until a real maintenance need emerges.
