# lens programmatic API — the single declared surface

What `lens:engine` takes and returns, what `lens:render-review` consumes, and **who owns each field** —
stated once, here. A programmatic caller (matali, vicario, any orchestrator) reads this file instead of
reconciling the same shapes out of eight SKILL and reference files.

## Precedence — this doc declares, the skills govern

This doc **declares** the surface — names, shapes, owners. The SKILL and reference sections cited below
**govern** it: they are the runtime. **If the two disagree, the procedure wins and this doc is the bug** —
repair the declaration here, never the behavior there.

That precedence is what makes a declaration doc safe in a repo where prose *is* the runtime: nothing here
changes what the engine does, so a stale line here can never silently change behavior. In exchange, the
procedure files point at this file rather than restating a shape — a shape restated in two places is a
surface that has already begun to fork.

## Ownership map

| Surface | Owner (who SETS it) | Declared here | Procedure lives at |
|---|---|---|---|
| `lens:engine` inputs — `target`, `taskIds?`, `injectedIntent?`, `injectedFinders?`, `finders` | the **caller** | § lens:engine — inputs | `../SKILL.md` · `./pipeline.md` §1–§3 |
| `lens:engine` returns — `findings[]`, `recommendedEscalation`, `degraded`, `summary?`, `emptyScope?`, `adherence?` | **`lens:engine`** | § lens:engine — returns | `../SKILL.md` Steps 1–5 · `./pipeline.md` §4–§8 |
| `delta`, `severityTrend` | **reconcile (compute-only)** — never the engine | § Downstream additions (NOT engine returns) | `../../review/references/reconcile.md` § Orchestrator mode |
| `lens:render-review` inputs — `findings`, `priorFindings?`, `diffRef?`, `spec?`/`plan?`/`adherence?`, `outputPath` | the **caller** | § lens:render-review — inputs and returns | `../../render-review/SKILL.md` |
| the rendered artifact + `renderedPath` | **`lens:render-review`** (write-once, `outputPath` only) | § lens:render-review — inputs and returns | `../../render-review/SKILL.md` |
| prior-run state (`.claude/lens/review-state.json`) | **the caller** — standalone `/lens:review`, or the orchestrator in compute-only mode | — | `../../review/references/reconcile.md` § Write-back |
| the per-finding shape + the closed `dimension` enum | **the schema** | — | `../../../schemas/review-findings.schema.json` |

## lens:engine — inputs

Every input arrives through the one Skill-tool invocation channel, and **every one is optional**: handed
none, the engine reviews the default scope, runs task-silent, and selects intent diff-correlated. A missing
or empty arg is "not provided"; an arg delivered as a JSON string rather than an array is parsed
defensively before the emptiness check (`./pipeline.md` §2 rule 0, §3).

| Input | Shape | Notes |
|---|---|---|
| `target` | string — a ref, a range, or a pathspec | The **canonical** name for the diff-scope override; used verbatim in place of the default scope. Historical alias: `scope` — the same channel under the older spelling, still used by `./pipeline.md` §2/§3 and by matali's call site. Both spellings are in use and nothing is renamed; a caller may hand either. |
| `taskIds` | `{ scope, intent, analyze, verify }` | Harness task ids for the four engine stages, handed only by the standalone `/lens:review` path. **Absent ⇒ the engine is task-silent** — it takes no task action at all, which is the compute-only/orchestrator path. |
| `injectedIntent` | `Array<{ role: "spec" \| "plan", name: string, content: string }>` | The **frozen matali contract**, and the highest-priority intent source. `content` is the full spec/plan markdown used verbatim; `name` is the provenance tag carried as `sourceSpec`/`sourcePlan`; `role` selects the adherence fan-out. Governed by `./pipeline.md` §2 rule 0. |
| `injectedFinders` | `Array<{ agent, dimension, label?, readonly: true }>` | **The canonical project-finder path** for a programmatic caller. `agent` resolves through the Agent-tool registry and **may be plugin-qualified** (e.g. `matali:principles-finder`), so the finder ships in the caller's own plugin. Dispatched identically to the file-registered project tier — read-only enforced at the boundary, normalized, deduped, adversarially verified. Governed by `./pipeline.md` §3 and `./finder-registry.md` Tier 3. |
| `finders` | project-tier finder entries (`agent`, `dimension`, `label?`, `readonly: true`) | The **file-based** project registry, read from `.claude/lens/settings.md`. Same dispatch and same read-only enforcement as `injectedFinders`; the only difference is where the entry came from. |

## lens:engine — returns

One object, schema-valid against `../../../schemas/review-findings.schema.json` — **six fields, and nothing
else**. The engine writes no file and asks no question; the caller owns all I/O and any gate.

| Field | Required | Shape |
|---|---|---|
| `findings[]` | required | The surviving findings. Per finding, required: `id`, `title`, `severity`, `dimension`, `verified` (the schema owns the optional rest). |
| `recommendedEscalation` | required | `minor \| moderate \| major \| critical` — the max surviving severity. |
| `degraded` | required | Bool. True whenever coverage was partial; the gap is named in `summary`. |
| `summary` | optional | Prose. Names every degrade reason and every skipped doc/finder. |
| `emptyScope` | optional | `true` **only** on empty-diff/no-repo. The sole discriminator between *nothing to review* and *a review that found nothing* — key on it, never on an empty `findings[]`. |
| `adherence` | optional | `{ specItems, planSteps }` — omit-empty; present only when the adherence finders ran. Lets a caller render the full met/partial/missing matrix without re-deriving it. |

Anything a consumer needs beyond these six is either computed downstream (§ Downstream additions) or is
not part of the contract at all (§ Known consumer assumptions).

## Downstream additions (NOT engine returns)

Two optional fields exist in `review-findings.schema.json` that a *downstream* stage — not the engine —
sets:

| Field | Shape | Set by |
|---|---|---|
| `delta` | `{ fixed, new, stillOpen }` — the iteration delta vs the prior run | reconcile, in compute-only mode |
| `severityTrend` | `improving \| same \| regressed` | reconcile, in compute-only mode |

**Not an engine return.** Both are **never set by the engine** — the schema says so on each field's
`$comment`, and the engine's Step 5 return carries neither. They appear only once a caller supplies prior
state: `lens:render-review` runs that reconcile in memory when handed `priorFindings` and surfaces them on
its own return. Procedure: `../../review/references/reconcile.md` § Orchestrator mode.

## lens:render-review — inputs and returns

A pure, stateless, write-once render of an already-computed object. It never re-runs finders and never
re-judges.

| Input | Required | Meaning |
|---|---|---|
| `findings` | required | The current `review-findings` object, already computed by `lens:engine`. |
| `priorFindings` | optional | A prior-run `review-findings` object. Supplying it is what enables reconcile. |
| `diffRef` | optional | A git ref/range to read for the annotated diff hunks; unavailable ⇒ the panel is omitted. |
| `spec` / `plan` / `adherence` | optional | Intent for the adherence matrix. |
| `outputPath` | required | Absolute path for the artifact — the **only** file this skill writes. |

**Returns** `{ renderedPath, delta?, severityTrend? }`, or the line `wrote: <path>`. On **any** failure:
`skipped: <one-line reason>` — never partial state, never an exception that blocks the caller.

**Empty scope.** When the supplied `findings` carries `emptyScope: true`, render-review returns the
literal `skipped: nothing to review` and writes **no artifact** — an empty scope has nothing to render, and
a zero-finding artifact would misreport it as a clean review.

## Known consumer assumptions (not part of the contract)

One live consumer reads a field lens does not declare. It is recorded here so it is not mistaken for
contract:

- **An `agents` finder roster.** matali reads `agents` off the engine return — its `review` skill (lines
  186 and 216 of that skill's `SKILL.md`, in the matali repo) forwards it verbatim into
  `derived.execution.P5`, and matali's plugin `CLAUDE.md` (line 52) states that lens "now returns its finder
  roster in `agents`". **lens declares no such field**: not in `../../../schemas/review-findings.schema.json`,
  not in `../SKILL.md`, not in § lens:engine — returns above. It is **not part of the contract** — a
  consumer must default it to `[]` and degrade quietly when it is absent. Documented as a divergence, not
  promoted to a return.

## Where the procedure lives

| Procedure | File |
|---|---|
| Engine stages (SCOPE → INTENT → ANALYZE → VERIFY → return), optional progress tracking, key rules | `../SKILL.md` |
| Stage detail: scope resolution, intent precedence, the `<untrusted-user-input>` fence, dedup key, vote aggregation, ranking, the huge-diff + fan-out caps | `./pipeline.md` |
| The 3 finder tiers, per-tier read-only enforcement, normalization into the finding shape | `./finder-registry.md` |
| Reconcile: fingerprints, iteration labels, `delta`, `severityTrend`, orchestrator (compute-only) mode, write-back | `../../review/references/reconcile.md` |
| Render: reconcile-in-memory, review-model assembly, the walkthrough handoff and markdown fallback, write-once | `../../render-review/SKILL.md` |
| The per-finding shape and the closed `dimension` enum | `../../../schemas/review-findings.schema.json` |

None of those files should restate a shape declared above. One that does has re-forked the surface this
file exists to keep single.
