# Markdown fallback — the render path when walkthrough is NOT installed

lens's happy path is `walkthrough:render` (interactive HTML). When the **walkthrough is not
installed**, lens renders the **same review-model** to a self-contained markdown report instead — same
content (verdict, adherence, findings, risk, hunks), plainer form. This fallback is what keeps lens
independently installable: walkthrough is an enhancer, never a dependency.

Detect at runtime: if `walkthrough:render` is unavailable (the walkthrough plugin isn't installed), take
this path and **announce the degrade** to the user.

## Output path
`<configured-path>/<YYYY-MM-DD-HHMM>-<slug>.md` (default `.claude/lens/`). Same naming as the HTML, `.md`
extension. On a name collision, suffix `-2`, `-3`, … (mirror walkthrough's collision rule).

## Structure
Render the reconciled review-model as this document, in order:

### 1. Degrade notice (top line)
A one-line notice stating the doc was rendered as markdown **because the walkthrough is not
installed** — e.g.:

> _Rendered as markdown because the walkthrough is not installed — install it for the interactive HTML review._

### 2. Verdict header
A header carrying the derived verdict (`Verdict: ship | fix | block`) and the iteration delta when this is
a re-review (e.g. `2 fixed · 1 new · 3 still-open`).

```markdown
# Review — <title>

**Verdict: fix**  ·  2 fixed · 1 new · 3 still-open

<one-paragraph summary of what was reviewed>
```

### 3. Narrative

Render the model's narrative spine as prose so the markdown carries the same story as the HTML: each
`sections[]` entry as `### <section title>` + its prose; `decisions[]` under a `## Decisions` heading
(`**<title>** — <why>`, list alternatives/tradeoffs); `timeline[]` as a `## Timeline` ordered list
(`<t> — <label>`). Omit any of these that the model doesn't carry (omit-empty).

### 4. Adherence
A table of spec items + plan steps with their states. In the in-session path this includes met/followed
items (full coverage); in the headless/contract-only path only the gaps appear (note the limitation — see
`review-model-assembly.md` § adherence).

When the adherence model carries `groups[]` (the multi-spec case — N>1), render **one `###` sub-section per spec/plan**
(heading = the group `source`), each with its own items table, so per-spec coverage is scannable
("spec-A: 4/5 met"). With a single spec/plan, render the one combined table below. The markdown fallback
groups natively regardless of the walkthrough version — grouping is lens-controlled here.

```markdown
## Adherence

| Item | Kind | State |
|---|---|---|
| Persist gitignore choice to settings.md | spec | met |
| Offer markdown fallback when walkthrough absent | spec | partial |
| Dispatch finders in parallel | plan | followed |
| ... | plan | deviated |
```

### 5. Findings, grouped by severity
Group findings under `## Critical` / `## High` / `## Medium` / `## Low` headings (highest first). Each
finding shows its location, claim, suggestedFix, the **verification status** (`verified` |
`unverified-flagged`), and the **fixed/open/new** iteration label (`fixed` | `still-open` | `new` |
`possibly-resolved — verify`). Refuted findings (dropped by the verifier) are NOT listed in the findings
sections — optionally note the count in the verdict header or summary line (e.g. "1 candidate refuted and
dropped"), matching the HTML render which only narrates them, never lists them.

```markdown
## High

- **<title>** — `<file>:<line>`  ·  _still-open_ · verified
  - Claim: <claim>
  - Detail: <detail>
  - Fix: <suggestedFix>
```

A `fixed` finding still appears (struck or under a `Fixed since last review` note) so the iteration delta
is visible, not just disappeared.

### 6. The change, annotated (diff hunks)

Render `diffHunks[]` as plain fenced diffs — **only the finding-bearing hunks plus minimal surrounding
context**, never the whole patch (the same finding-scoped subset the HTML annotated-diff shows). Where the HTML
would place a pin, append an inline marker `← F<id>` on the line **whose `diffHunks[].lines[].finding` is set** — the same line the HTML annotated-diff pins — so placement is model-driven, not a judgment call.

````markdown
```diff
  function render(model) {
-   if (!model) return;
+   if (!model) throw new Error("no model");   ← F2
  }
```
````

Omit this section if `diffHunks[]` is absent.

### 7. Risk table
One row per changed file with its risk class (from risk-classify `files[]`). Omit if `files[]` is absent
(headless path).

```markdown
## Risk

| File | Change | Risk |
|---|---|---|
| lens/skills/review/SKILL.md | modified | public-api |
| lens/README.md | modified | none |
```

## Parity with the HTML
Same content as the interactive document — narrative, adherence, findings, the annotated diff hunks, and
risk — just a plainer, self-contained markdown form. No HTML, no JS, no diagrams.
