# Session Model — the structured shape that drives the walkthrough

Before you write a single line of HTML, you synthesize the session into this structured model. It is
the bridge between "what happened in the session" and "which components the page renders": every
field maps to one or more catalog components via the table in `authoring-guide.md` § 1. Synthesize
the model first, then walk its populated fields to choose components (omit-empty, never stub — see
`authoring-guide.md` § 2).

## Part A — Annotated schema

Each field is annotated with the component(s) it feeds. Field names are load-bearing: they are the
exact keys `authoring-guide.md` keys its mapping table off of — do not rename them.

```jsonc
{
  // --- chrome: always rendered (authoring-guide.md § 1 "always" row) ---
  "title":   "...",                  // doc <title> + hero <h1>; page-scaffold hero slot
  "summary": "...",                  // hero lede / one-paragraph plain recap under the h1

  // typeTags drive the hero chip row. Special-case: if it includes "research",
  // the page LEADS with a concept/mind map + callouts instead of a code-change layout.
  "typeTags": ["feature", "parsing"], // → hero chips; "research" → concept map + callouts

  // The document spine. Each section becomes a nav link + a <section> in the body.
  // `components` lists which catalog components that section hosts (selected from the
  // populated model fields below); an empty/omitted list = prose-only section.
  "sections": [                       // → nav links + <section> blocks (prose carries the narrative)
    { "id": "goal", "heading": "...", "prose": "...", "components": ["tabs"] }
  ],

  // nodes[] + edges[] together drive a diagram. The graph's SHAPE picks which one — run the
  // diagram-fidelity check in authoring-guide.md § 1 before defaulting to a box-and-arrow form:
  //   linear staged pipeline            → flow diagram
  //   non-linear services/layers        → architecture map
  //   module/package imports            → dependency graph (inline SVG)
  //   cyclic / guarded transitions      → state / transition diagram (nodes kind:"state"; set edge.guard)
  //   timed messages between actors     → sequence / swimlane diagram (nodes kind:"actor"; set edge.seq)
  // `kind` hints intent; nodes with a matching details[] entry are clickable (openSurface).
  "nodes": [ { "id": "...", "label": "...", "kind": "component|step|concept|state|actor" } ], // → diagram nodes
  "edges": [ { "from": "<id>", "to": "<id>", "label": "", "guard": "", "seq": 0 } ], // guard → state-edge condition; seq → sequence order

  // decisions[] → Tabs + tradeoff bars WHEN tradeoffs[] carry scored axes (bars use data-w);
  // with no scores, fall back to the Accordion checklist (one <details> per decision).
  "decisions": [
    {
      "id": "...",
      "title": "...",
      "why": "...",                   // rationale shown in the tab body / .ac-body
      "alternatives": "...",          // options weighed
      "tradeoffs": [ { "axis": "...", "score": 0 } ] // → tradeoff bars (data-w = score); omit → accordion
    }
  ],

  // files[] → file tree; a handful renders a plain tree, many that group by category
  // add filterable cards + pills (narrow by data-cat). `change` colors the row.
  "files": [ { "path": "...", "change": "added|modified|deleted", "risk": "auth|data|money|migration|concurrency|public-api|none", "note": "..." } ], // → file tree / cards

  // timeline[] → Timeline (read top-to-bottom) OR Stepper/playback (a replayable sequence).
  // `ref` links a timeline entry back to a section id for scroll-to.
  "timeline": [ { "t": "step 1", "label": "...", "ref": "<section-id>" } ],  // → timeline / stepper

  // metrics[] → a few headline numbers render as stat/metric cards;
  // many comparable magnitudes render as an animated bar chart. `kind` tags the unit.
  "metrics": [ { "label": "...", "value": "...", "kind": "count|size|delta" } ], // → stat cards / bar chart

  // openQuestions[] → callout(s) at the tail of the doc (honest unknowns / follow-ups).
  "openQuestions": [ "..." ],         // → callouts

  // details{} → the detail-surface content store. Keyed by node/card id; openSurface('<id>')
  // routes to the pane (light) or a sheet (rich). Fields are structured (not a blob):
  //   kicker, heading        short label + title (was k/h)
  //   summary                one-paragraph plain recap
  //   where[]                path:line anchors → chips/links
  //   code[]                 optional {file,lang,snippet} annotated blocks
  //   points[]               optional structured bullets
  //   related[]              cross-links → chips that call openSurface
  //   surface                OPTIONAL override "pane"|"sheet" (else inferred, see authoring-guide.md § 3)
  //   components[]           sheet-only: catalog component refs to host (e.g. "flow:inner")
  "details": {
    "<id>": {
      "kicker": "...", "heading": "...", "summary": "...",
      "where": ["path:line"], "code": [{ "file": "...", "lang": "...", "snippet": "..." }],
      "points": ["..."], "related": ["<id>"], "surface": "pane", "components": []
    }
  },

  // --- review fields (optional; populated only by lens via walkthrough:render) ---
  // Omit-empty governs all of these: a normal session walkthrough never sets them.
  "verdict": "ship|fix|block",        // → hero chip (ship=ok, fix=warn, block=danger)
  "adherence": {                      // → adherence-panel (components/review.md)
    "specItems": [ { "label": "...", "state": "met|partial|missing" } ],
    "planSteps": [ { "label": "...", "state": "followed|deviated" } ]
  },
  "findings": [                       // → findings-list + diff pins; each id also a DET sheet
    { "id": "F1", "severity": "critical|high|medium|low",  // 'info' is NOT a severity — render-only chip role for 'low' (review-model-assembly.md)
      "category": "spec-gap|plan-deviation|bug|silent-failure|security|risk|test-gap|quality",
      "location": "path:line", "claim": "...", "detail": "...",
      "suggestedFix": "...", "status": "verified|unverified-flagged" }
  ],
  "diffHunks": [                      // → annotated-diff (components/review.md)
    { "path": "...", "lines": [ { "k": "ctx|add|del", "n": 0, "text": "...", "finding": "F1" } ] }
  ]
}
```

A detail with `components`, `code`, or a long `summary`+`points` is inferred `sheet`; otherwise it is inferred `pane`. An explicit `surface` field overrides the inference in either direction. See `authoring-guide.md` § 3 for the full inference rule. Nesting depth and acyclicity rules for nested surfaces are spelled out in the **Nesting** note below.

**Nesting.** A sheet's hosted `components[]` may contain nodes that reference other `details{}` ids via `openSurface`, so one detail can open another. Two hard limits keep this bounded: the reference graph must be **acyclic** — a detail must never transitively open itself (an `A → B → A` chain is a build failure) — and the open depth is capped at **3** (a 4th nested open replaces the topmost surface rather than deepening). Author chains deeper than 3 are flattened at synthesis time. The self-check enforces both the acyclic and depth-≤-3 rules.

## Part B — Worked example: "Adding the HDFC SMS parser"

A complete, realistic model for a small feature session. Every field is populated with believable
data — no placeholders. This session added a parser that turns HDFC bank transaction SMS into
structured `Txn` records, with a fail-soft strategy and one-pattern-per-format design.

```jsonc
{
  "title": "Adding the HDFC SMS parser",
  "summary": "Wired up a parser that turns raw HDFC bank transaction SMS into structured Txn records. A RegexMatcher pulls the amount, merchant, and date out of the message; a TxnExtractor normalizes them into a Txn. Unrecognized messages fail soft to null instead of throwing, so a new SMS format never crashes the import pipeline.",
  "typeTags": ["feature", "parsing", "tests"],

  "sections": [
    {
      "id": "goal",
      "heading": "The goal",
      "prose": "HDFC sends debit and credit alerts as SMS. We want each recognized message to become a Txn { amount, merchant, date, direction }. Anything we do not recognize should be skipped quietly, never abort the batch.",
      "components": []
    },
    {
      "id": "pipeline",
      "heading": "How a message becomes a Txn",
      "prose": "The flow is a short linear pipeline: the raw SMS string enters, RegexMatcher tests it against the HDFC pattern and captures named groups, TxnExtractor maps those groups onto a Txn, and the record is returned to the importer.",
      "components": ["flow"]
    },
    {
      "id": "decisions",
      "heading": "Key decisions",
      "prose": "Two choices shaped the design: how to handle messages we cannot parse, and how to organize patterns as more banks are added.",
      "components": ["tabs", "bars"]
    },
    {
      "id": "changes",
      "heading": "What changed",
      "prose": "One new parser module, a wiring change in the registry, and a fixture-driven test file.",
      "components": ["filetree"]
    },
    {
      "id": "results",
      "heading": "Results",
      "prose": "Coverage of the sampled HDFC corpus and the size of the change.",
      "components": ["statcards"]
    }
  ],

  "nodes": [
    { "id": "sms",       "label": "Raw SMS string",  "kind": "step" },
    { "id": "matcher",   "label": "RegexMatcher",    "kind": "component" },
    { "id": "extractor", "label": "TxnExtractor",    "kind": "component" },
    { "id": "txn",       "label": "Txn record",      "kind": "step" }
  ],
  "edges": [
    { "from": "sms",       "to": "matcher",   "label": "test + capture" },
    { "from": "matcher",   "to": "extractor", "label": "named groups" },
    { "from": "extractor", "to": "txn",       "label": "normalize" },
    { "from": "matcher",   "to": "txn",       "label": "no match → null" }
  ],

  "decisions": [
    {
      "id": "failsoft",
      "title": "Fail soft on unrecognized SMS",
      "why": "An unknown SMS format should not abort a whole import batch. Returning null lets the importer skip the message and keep going, and surfaces the miss as a metric rather than an exception.",
      "alternatives": "Throw a ParseError and let the importer catch per-message; or log-and-rethrow at the batch boundary.",
      "tradeoffs": [
        { "axis": "robustness",      "score": 9 },
        { "axis": "debuggability",   "score": 5 },
        { "axis": "silent-data-loss", "score": 4 }
      ]
    },
    {
      "id": "pattern-per-format",
      "title": "One regex pattern per bank format",
      "why": "Each bank's SMS layout differs enough that a single mega-regex would be unreadable and brittle. A pattern-per-format registry keeps each parser small and lets us add a bank without touching existing ones.",
      "alternatives": "One unified regex with optional groups; or an LLM-based extractor with no fixed pattern.",
      "tradeoffs": [
        { "axis": "extensibility",   "score": 9 },
        { "axis": "duplication",     "score": 4 },
        { "axis": "match-precision", "score": 8 }
      ]
    }
  ],

  "files": [
    { "path": "parsers/hdfc.ts",          "change": "added",    "note": "RegexMatcher + TxnExtractor for the HDFC format" },
    { "path": "parsers/registry.ts",      "change": "modified", "note": "register hdfc parser by sender id" },
    { "path": "parsers/__tests__/hdfc.test.ts", "change": "added", "note": "12 fixtures: 9 recognized formats + 3 unparseable" }
  ],

  "timeline": [
    { "t": "step 1", "label": "Collected 40 sample HDFC SMS and grouped them into 9 formats", "ref": "goal" },
    { "t": "step 2", "label": "Wrote the RegexMatcher pattern with named capture groups",      "ref": "pipeline" },
    { "t": "step 3", "label": "Added TxnExtractor to normalize groups into a Txn",             "ref": "pipeline" },
    { "t": "step 4", "label": "Chose fail-soft and registered the parser by sender id",        "ref": "decisions" },
    { "t": "step 5", "label": "Added fixture tests and confirmed coverage",                    "ref": "results" }
  ],

  "metrics": [
    { "label": "SMS formats covered", "value": "9 / 9",  "kind": "count" },
    { "label": "Test fixtures",       "value": "12",     "kind": "count" },
    { "label": "Net lines added",     "value": "+148",   "kind": "delta" }
  ],

  "openQuestions": [
    "Should unrecognized SMS be queued for manual review instead of dropped silently, so we notice when HDFC changes its format?"
  ],

  "details": {
    "matcher": {
      "kicker": "Component", "heading": "RegexMatcher",
      "summary": "Holds the compiled HDFC pattern with named groups; test() returns the capture map on a hit or null on a miss — the null powers fail-soft downstream.",
      "where": ["parsers/hdfc.ts:24"],
      "related": ["extractor", "failsoft"]
    },
    "extractor": {
      "kicker": "Component", "heading": "TxnExtractor",
      "summary": "Maps the raw capture map onto a typed Txn: parses amount, trims merchant, converts DD/MM/YY to ISO, derives direction.",
      "where": ["parsers/hdfc.ts:58"],
      "related": ["matcher", "txn"]
    },
    "txn": {
      "kicker": "Type", "heading": "Txn record",
      "summary": "The normalized { amount, merchant, date, direction } returned to the importer. On a matcher miss this is null, which the importer skips.",
      "where": ["parsers/types.ts:7"],
      "related": ["extractor", "failsoft"]
    },
    "failsoft": {
      "kicker": "Decision", "heading": "Fail soft on unrecognized SMS",
      "summary": "A no-match returns null rather than throwing, so one unknown SMS format never aborts the batch. Misses are counted into import metrics for visibility.",
      "where": ["parsers/hdfc.ts:24"],
      "related": ["matcher", "txn"]
    }
  }
}
```

## This model is not a file

This model is synthesized in-memory before any HTML and drives component selection (see
`authoring-guide.md`). It is NOT written to disk in v1.

## Review fields (lens)

The review fields (`verdict`, `adherence`, `findings`, `diffHunks`, `files[].risk`) are optional and
populated **only** by the `lens` plugin, which assembles the model in context and hands it to
`walkthrough:render`. `create`/`document`/`update` never set them; omit-empty keeps them inert. Each
`findings[]` id maps to a `DET` sheet entry (`SURF[id]='sheet'`), and both its findings-list card and
its annotated-diff pin call `openSurface('<id>')`.
