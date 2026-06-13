# review-model assembly — `review-findings` JSON → walkthrough session-model

Build the review-model (a `session-model` with the optional review fields populated) from the engine's
**reconciled** `review-findings` object, then hand it to `walkthrough:render`. The target shape is
`walkthrough/skills/create/references/session-model.md` — its § "Review fields (lens)" block is the
contract this maps onto. Reuse the standard session-model fields for the narrative; populate the review
fields below. **Omit-empty, never stub** (the same discipline create uses): a field is set only when
there is real content for it.

## Narrative spine → `sections[]` + `timeline[]` + `decisions[]`
The spec→plan→impl story is told with the **standard** session-model fields (no review extensions):
- `title` / `summary` — the review's headline + a one-paragraph plain recap of what was reviewed.
- `typeTags` — e.g. `["review", "<change-type>"]`.
- `sections[]` — the document spine (the goal, what changed, the verdict rationale). Prose carries the
  narrative; `components[]` lists which catalog components each section hosts.
- `timeline[]` — the spec → plan → implementation arc (`{t, label, ref}`; `ref` → a section id).
- `decisions[]` — the design decisions surfaced from the intent record / plan (`{title, why, alternatives, tradeoffs[]}`).
- `nodes[]`/`edges[]` — only if a diagram genuinely helps; a review usually needs none.

These reuse the existing fields verbatim — do not rename them.

## `adherence` → `{ specItems[], planSteps[] }`
Feeds the adherence-panel. **Two source paths — state both:**

1. **In-session (lens's normal path).** lens runs the engine and the render in the **same context**, so the
   **spec-adherence** finder's `specItems[]` (`{label, state: met|partial|missing}`) and the
   **plan-adherence** finder's `planSteps[]` (`{label, state: followed|deviated}`) are available directly.
   Use them verbatim — they include the `met`/`followed` items, so the panel shows full coverage, not just gaps.

2. **Headless / contract-only (e.g. vicario consuming the engine's `review-findings` JSON without the
   finders' side outputs).** Only the `findings[]` array is available — `specItems[]`/`planSteps[]` are not.
   **DERIVE** the adherence gaps from the `requirements`-dimension findings:
   - `requirements` + `label:"spec-gap"` → a `specItems[]` entry, `state` `partial` or `missing` (read the
     finding's claim/detail to pick which).
   - `requirements` + `label:"plan-deviation"` → a `planSteps[]` entry, `state: deviated`.
   - `requirements` + `label:"scope-creep"` → not an adherence item (it maps to a finding only — see below).

   In this degraded path the **met / followed** items are absent (the contract carries only gaps), so the
   panel lists only the unmet/deviated items. State this limitation in the rendered doc.

## `findings[]` → session-model `findings[]`
Each engine finding becomes one session-model `findings[]` entry. Map `dimension` + `label` → the
session-model `category` enum (`spec-gap|plan-deviation|bug|silent-failure|security|risk|test-gap|quality`):

| engine `dimension` | engine `label` | session-model `category` |
|---|---|---|
| `requirements` | `spec-gap` | `spec-gap` |
| `requirements` | `plan-deviation` | `plan-deviation` |
| `requirements` | `scope-creep` | `quality` |
| `correctness` | `bug` (or any) | `bug` |
| `silent-failure` | * | `silent-failure` |
| `security` | * | `security` |
| `risk` | * | `risk` |
| `test` | `test-gap` (or any) | `test-gap` |
| `types` | * | `quality` |
| `comment` | * | `quality` |
| `simplify` | * | `quality` |

Carry onto each entry:
- `id` — the engine's run-stable `F<n>` (unique within this one review document; cross-run matching uses the reconcile fingerprint, not the id).
- `severity` — verbatim (`critical|high|medium|low`; the engine never emits `info` — `info` is a
  render-only chip role, see the chip map below).
- `location` — `"<file>:<line>"` from the finding's `file`/`line` (omit if the finding has none).
- `claim`, `detail`, `suggestedFix` — verbatim from the finding (omit-empty per field).
- `status` — the reconcile **verification** status: `verified` (verifier confirmed) or `unverified-flagged`
  (verify errored mid-way, kept and flagged). This is the session-model `status` enum — distinct from the verifier's
  own per-vote `status` (that status only reports whether verification *ran cleanly* vs *errored*;
  refuted findings are dropped before assembly, so only these two values ever reach the model).
- `iteration` — the reconcile **fixed/open/new** label (`fixed|still-open|new`, plus `possibly-resolved`
  for a low-confidence match — reconcile's full label is `possibly-resolved — verify`; strip the ` — verify` suffix (the suffix is markdown-only) to get the bare enum value) → the session-model `iteration` field (rendered as the iteration chip).
  **Omit on a first review** (no prior state). The aggregate counts → the model's top-level
  `iterationDelta` (also omitted on a first review).

Each finding id → a `DET` sheet (`SURF[id]='sheet'`), per walkthrough's `render-contract.md` § Review-specific
assembly: `{kicker:"<severity> · <category>", heading:"<claim>", summary:"<detail>",
where:["<location>"], points:["Fix: <suggestedFix>", "Status: <verification-status>"], surface:"sheet"}`
(iteration is the structured `iteration` field/chip, not a sheet point).

## `files[].risk` → from risk-classify `files[]`
The **risk-classify** finder's `files[]` (`{path, change, risk, note?}`) populates the session-model
`files[]` with `risk` set (`auth|data|money|migration|concurrency|public-api|none`). `change` colors the
row; `risk` drives risk coloring in the file tree / cards. In the headless path, `files[]` may be absent —
omit the risk coloring then.

## `diffHunks[]` → annotated hunks
The annotated diff hunks (`{path, lines:[{k:"ctx|add|del", n, text, finding}]}`). Set each annotated
line's `finding` to the **owning finding id**, so the diff pin calls `openSurface('<finding-id>')` and
routes to that finding's sheet.

## `verdict` → DERIVED from `recommendedEscalation`
The engine's top-level `recommendedEscalation` (`minor|moderate|major|critical`) derives the hero verdict
chip:

| `recommendedEscalation` | `verdict` |
|---|---|
| `critical` | `block` |
| `major` | `block` |
| `moderate` | `fix` |
| `minor` (or none) | `ship` |

(`verdict` renders as the hero chip: `ship`=ok, `fix`=warn, `block`=danger — per session-model § review fields.)

## severity → chip role
For the findings cards/pins (the `.chip` status role on each finding):

| `severity` | chip role |
|---|---|
| `critical` | `danger` |
| `high` | `danger` |
| `medium` | `warn` |
| `low` | `info` |

`info` is a **render-only** chip role — it never appears as a finding `severity` in the engine contract;
it exists only here, as the chip styling for `low`.
