# ADR field extraction rules

This is the user-facing reference for how `/html-adr:render` infers ADR fields from your authored markdown. The plugin's behavior is heuristic — this doc tells you which signals it looks at and how to override when extraction is wrong.

## Quick reference

| Field | First-wins rule chain | Override |
|---|---|---|
| Title | First H1, else filename | n/a |
| Date | YYYY-MM-DD filename prefix → frontmatter `adr.date` → git first-add → today | `adr.date` |
| Status | Frontmatter `adr.status` → `**Status:**` paragraph or `> Status:` blockquote → branch hint → git dirty → "proposed" | `adr.status` |
| Authors | Frontmatter `adr.decision_makers` → `git log` authors → omitted | `adr.decision_makers` |
| Context | H2 matching `^(context|background|goal|problem|why)` → prose between H1 and first H2 | n/a |
| Drivers | Frontmatter `adr.drivers` → H3 matching `^(drivers?|constraints?|requirements?)` | `adr.drivers` |
| Considered options | H2/H3 matching `^(approach|option|alternative)\s*[a-c1-3]\b` or `^[A-C]\s*[—-]\s*` | `adr.options` |
| Per-option pros/cons | Sub-headings `^pros?$`/`^cons?$` → `+`/`-` bullet prefix → `**Pros:**` lead-in | `adr.options[].{pros,cons}` |
| Verdict | Heading suffix `(Recommended)`/`(Chosen)`/`(Rejected)` | `adr.options[].verdict` |
| Decision outcome | Frontmatter `adr.decision` → chosen option → H2 matching `^(recommendation|decision|outcome)` → first "we will..." sentence | `adr.decision` |
| Consequences | Frontmatter `adr.consequences` → sub-headings under `## Consequences` (`Positive`/`Negative`) → keyword classification of single ungrouped list | `adr.consequences` |
| Links | All `[text](url)` + bare sibling-spec filename references | n/a |

## Frontmatter shape

```yaml
---
adr:
  status: accepted               # proposed | accepted | rejected | deprecated | superseded
  date: 2026-05-20
  decision_makers: [Apurv, Other]
  decision: "One-sentence decision"
  drivers: [driver-1, driver-2]
  options:
    - name: A
      summary: "..."
      pros: ["..."]
      cons: ["..."]
      verdict: chosen           # chosen | rejected | null
  consequences:
    positive: ["..."]
    negative: ["..."]
sections_override:
  "Threat Model": DEPS_RISKS    # remap a non-canonical heading to a canonical widget
---
```

## No-alternatives degradation

If fewer than 2 options are detected (no frontmatter `adr.options`, no `^Approach A/B` headings), the rendered HTML omits the ADR header entirely and shows a banner:

> This spec doesn't contain a multi-option decision. Rendered as a design doc rather than an ADR. To force ADR rendering, add an `adr:` frontmatter block.

## Confidence and provenance

Every extracted field carries `confidence` (`high`/`medium`/`low`) and `provenance` (which rule fired). The rendered HTML shows the confidence as a small colored dot next to each field label. Hover for the provenance.

## Supported markdown features

- CommonMark (headings, paragraphs, emphasis, lists, code blocks, blockquotes, links, images)
- GFM (tables, strikethrough, task lists, autolinks, GFM table alignment)
- YAML frontmatter
- ` ```mermaid ` fenced blocks (rendered via Mermaid.js client-side)
- ASCII diagrams in `` ``` `` fences are detected and pretty-rendered (no auto-graph promotion in v0.1)

## Unsupported

- Footnotes (lands as plain prose; not consumed)
- Math (LaTeX/KaTeX)
- MDX
- Custom directives

If you use one of these, the offending block renders as `<pre>` with a warning banner naming the feature + line.
