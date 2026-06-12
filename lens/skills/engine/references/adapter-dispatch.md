# Adapter dispatch — normalizing foreign producers into the finding shape

The adapter tier (tier 2 of `finder-registry.md`) taps external review agents that emit **prose in their
own taxonomies**, not the `review-findings` finding shape the built-in finders emit. This doc is how the
engine normalizes them. Two parts: a generic **wrapper-prompt** applied to every adapter, and a
**per-adapter map** for each of the 5.

Normalization is **best-effort**: an adapter whose output still can't be mapped is dropped, `degraded:true`
is set, and the missing dimension is named in `summary` (per `engine/SKILL.md` Step 3 + Step 4).

## Part 1 — the forcing wrapper-prompt (every adapter)

Prepend this contract to every adapter dispatch:

> You are running as a **read-only, findings-only** lens adapter. Do NOT edit, write, stage, or commit —
> emit findings only. Return your result as the **review-findings finding shape**: a `findings[]` array
> where each item has `id` (local `F<n>`), `title`, `severity` (`critical|high|medium|low` — **no `info`**),
> `dimension` (the fixed value for this adapter, below), `verified:false`, and — where you can confirm them
> by reading the file — `file`, `line`, `claim`, `detail`, `suggestedFix`. Put your tool's native category
> in `label`. Map your native severity onto the four-value scale (below). Emit only findings you can back
> with real source.

The engine still validates each item before fan-in (drop + `degraded` on a non-conforming item) — the
wrapper raises the hit rate; it does not replace validation.
An adapter that ships its own Output Format section may not fully honor this wrapper; the validation belt
(drop + `degraded`) is the backstop for exactly those cases. `type-design-analyzer` (qualitative ratings,
no per-finding structure) is the expected lowest-yield adapter — it leans hardest on the fallback.

## Part 2 — per-adapter maps

**Dimension assignments are owned by `finder-registry.md`'s adapter table** — this doc specifies only how to fill the remaining finding fields (severity scale, `label`, `file`/`line`). If they ever disagree, finder-registry wins.

### `silent-failure-hunter` → `dimension: silent-failure`
Native output: prose findings about swallowed errors / inadequate fallbacks. Map each reported failure to
one finding; `label` = its category (e.g. `swallowed-error`, `empty-catch`); `severity` from its
risk language (data-loss/security → `high`/`critical`; cosmetic → `low`); `file`/`line` from the cited
locus (confirm by reading).

### `type-design-analyzer` → `dimension: types`
Native output: qualitative ratings + prose on encapsulation/invariants/enforcement. Emit a finding only for
a **concrete weakness** tied to a type at a real `file`/`line` (skip the numeric ratings); `label` =
`type-design`; `severity` from the weakness impact (a leaked invariant on a public type → `high`).

### `comment-analyzer` → `dimension: comment`
Native output: prose on inaccurate/rotted/missing comments. One finding per inaccurate or misleading comment
at its `file`/`line`; `label` = `comment-rot` / `inaccurate-comment`; `severity` usually `low`/`medium`
(higher when the comment actively misleads about behavior).

### `pr-test-analyzer` → `dimension: test`
**Scope: brittle/overfit + behavioral-delta ONLY** — lens's built-in `test-gaps` owns missing tests, so the
wrapper additionally instructs this adapter to **skip pure missing-coverage findings**. `label` =
`brittle-test` / `overfit-test`; `severity` from how likely the test misleads (a green test that asserts the
wrong behavior → `high`).

### `feature-dev:code-reviewer` → `dimension: correctness`
Native output: structured review findings already close to the shape. Tool allowlist is read-only (no
constraint needed beyond the wrapper). `label` = `2nd-opinion`; keep its severity if it maps cleanly, else
map down to the four-value scale. Used as a capability-locked **2nd opinion** — its findings dedup against
the built-in `correctness` finder by `(file, line, title)`.

## After normalization
Normalized findings re-enter the pipeline exactly like built-in findings: deduped by `(file, line, title)`
(merging `source`), adversarially verified by the `verifier`, and ranked. There is no separate path.
