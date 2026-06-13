# Engine pipeline — stages in depth

The engine runs five stages and **returns** a `review-findings` object (per
`../../../schemas/review-findings.schema.json`). It writes nothing and never prompts; the caller owns all
I/O and any gate. Stages: SCOPE → INTENT → ANALYZE → VERIFY+DEDUP → RANK+ASSEMBLE.

## 1. Diff-target resolution (SCOPE)

Default scope = **working tree** + **this branch's commits vs the merge-base with the default branch**.
A caller `[target]` arg overrides the default entirely.

Exact commands:

```bash
# working tree (unstaged + staged)
git diff
git diff --staged

# branch commits vs the merge-base with the default branch
DEFAULT_BRANCH="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
MERGE_BASE="$(git merge-base "$DEFAULT_BRANCH" HEAD)"
git diff "$MERGE_BASE"..HEAD
```

The union of the working-tree diff and the `<merge-base>...HEAD` diff is the review scope. A caller
`[target]` arg (a ref, a range, or a pathspec) replaces this computation — use it verbatim.

**Empty diff / no repo.** If `git rev-parse --is-inside-work-tree` fails (no repo) or the resolved diff is
empty, the engine returns immediately:

```json
{ "findings": [], "recommendedEscalation": "minor", "degraded": false }
```

No error, no prompt — an empty review is a valid result.

## 2. Intent-source priority ladder (INTENT)

Build the **intent record** (the list of spec items + plan steps the diff is judged against) from the
first available source, in priority order:

1. **explicit args** — an intent/spec passed by the caller wins outright.
2. **latest `docs/superpowers/specs/*`** — the most recent spec file.
3. **the plan** — `docs/superpowers/plans/*` (the latest), when no spec is present.
4. **the transcript** — reconstruct intent from the session conversation.

If **none** of (1)–(3) is found and intent must be reconstructed from the transcript, set
`degraded: true` on the result and note the reconstruction in `summary`. Reconstructed intent is lower
fidelity, so adherence findings derived from it are flagged accordingly.

## 3. Parallel dispatch (ANALYZE)

Dispatch the **5 built-in finders concurrently** — one Task call per finder, all in a single batch — per
`superpowers:dispatching-parallel-agents`:

| Finder | Dimension | Extra structured output |
|---|---|---|
| `spec-adherence` | `requirements` | `specItems[]` (`{label,state}`) |
| `plan-adherence` | `requirements` | `planSteps[]` (`{label,state}`) |
| `correctness` | `correctness` | — |
| `risk-classify` | `risk` | — |
| `test-gaps` | `test` | — |

Each finder returns its `findings[]` (every finding `verified:false` — the VERIFY stage owns the flip).
`spec-adherence` and `plan-adherence` additionally return `specItems[]` / `planSteps[]` for the downstream
adherence panel.

After the built-ins, run the **finder registry** (see `finder-registry.md`): the **adapter tier** (the 5
read-only adapters, dispatched only when their source plugin is installed, skipped silently otherwise) and
the **project tier** (custom finders from `.claude/lens/settings.md`). Read-only is **enforced at the
dispatch boundary** for every tier. Tag every candidate with its `dimension` per the
producer→dimension map.

## 4. Dedup key (VERIFY+DEDUP)

The hybrid tap means several finders (built-in + adapter + project) can surface the **same** issue. Dedup
candidates by the key:

```
(file, line, title)
```

When two candidates collapse to one key, keep the **highest-severity** instance and **merge `source`**
(record both producers, e.g. `"correctness+feature-dev:code-reviewer"`) so provenance isn't lost. Dedup
runs before verify so the skeptic isn't asked to refute the same claim twice.

## 5. Verify + vote aggregation (VERIFY)

Each surviving candidate goes to the `verifier` agent — the adversarial skeptic. The verifier emits **one
vote per finding**:

```json
{ "id": "F1", "refuted": false, "reason": "<concrete evidence>", "status": "verified" }
```

The **engine** aggregates the vote(s) into `votes{total,couldNotRefute,refuted}` and resolves `verified`:

- `refuted:false` + `status:"verified"` → finding survives, `verified:true`.
- `status:"unverified-flagged"` (verify errored mid-way) → finding **kept**, `verified:false` (flagged,
  never dropped).
- `refuted:true` → finding **dropped** from the surviving set.

`votes.total` = the number of skeptics run for that finding. v1 runs a single verifier vote per finding,
so `total` is `1` and `couldNotRefute`/`refuted` are `1`/`0` (kept) or `0`/`1` (refuted).
**v1 resolution is unanimous-drop** (any `refuted:true` drops the finding). The `votes{}` *shape* matches
vicario's, but the multi-skeptic *resolution rule* is NOT yet wired: vicario keeps a finding unless a strict
majority refuted (`refuted <= total/2`), whereas lens v1 drops on a single refute.
Wiring multi-skeptic voting (and vicario's majority rule) is deferred.

## 6. Severity ranking + escalation (RANK)

`recommendedEscalation` = the **max surviving severity**, mapped:

| Max surviving severity | recommendedEscalation |
|---|---|
| `critical` | `critical` |
| `high` | `major` |
| `medium` | `moderate` |
| `low` | `minor` |

No surviving findings → `minor`.

## 7. Stable ids (ASSEMBLE)

Finders emit **local** ids (`F1`, `F2`, … within their own output). During dedup/assemble the engine
assigns **within-run-stable** `F<n>` ids across the merged set, so two finders' `F1`s don't collide and
the renderer can wire each diff pin to its sheet within a single document. These ids are NOT stable across
runs (a new finding renumbers the set positionally) — cross-run identity is the reconcile **fingerprint**,
never the id (see `../../review/references/reconcile.md`).

## 8. Huge-diff rule

No silent truncation. On a diff too large to review whole:

- **Chunk by file**; cap fan-out (don't dispatch unbounded parallel finders).
- **Review highest-risk files first** (changed-test-less code, security-adjacent paths, large hunks).
- On truncation, set `degraded: true` and **LOG coverage in `summary`** — e.g.
  `"reviewed 40/120 files, prioritized by risk"`. The unreviewed remainder is named, never silently
  dropped.
