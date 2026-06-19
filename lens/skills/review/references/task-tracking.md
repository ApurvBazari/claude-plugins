# Review Task-List Tracking — the in-session progress contract

`/lens:review` surfaces its progress as a harness task list (the same mechanism `/onboard:start` uses).
This file is the single source of truth for that list: its stages, the status enum, and the rules
`review` and `engine` both follow. It is **in-session visibility only** — lens keeps no durable
run-progress and never resumes a review across sessions (a review is single-shot).

## The task list

One task per stage, created up front as `pending` by `review` (the entry point). Subjects are bare slugs
(lens has one entry point, so no prefix). `setup` is created **only on the first review in a repo** (when
`.claude/lens/settings.md` is absent).

| # | Subject | `activeForm` | Owner |
|---|---|---|---|
| 0 | `setup` | Configuring lens (first run) | review — first run only |
| 1 | `scope` | Scoping the diff | engine |
| 2 | `intent` | Building the intent record | engine |
| 3 | `analyze` | Running finders | engine |
| 4 | `verify` | Verifying findings | engine |
| 5 | `reconcile` | Reconciling vs prior review | review |
| 6 | `render` | Rendering the review | review |
| 7 | `report` | Reporting | review |

## Status enum

Exactly four values: `pending` → `in_progress` → `completed`, plus `deleted`. There is **no `failed`**
status. One task is `in_progress` at a time. A run that aborts before a stage runs marks that stage's task
`deleted` — never left `in_progress`. A stage that **ran but produced no artifact** (e.g. a render failure)
is also marked `deleted` — not `completed` — since there is no `failed` status; the run still terminates
every task, leaving none `in_progress` (see Rule 6).

## Rules

1. **Standalone only.** Only the standalone `/lens:review` path creates and transitions tasks. In
   **orchestrator / compute-only mode** `review` creates no tasks and passes no `taskIds`, so the engine
   stays silent — lens remains embeddable.
2. **Subjects are display-only.** Nothing parses the subject string; `TaskUpdate` keys on the `taskId`
   returned at creation. Stage order comes from this table and the SKILL step headers, not from any index
   in the subject.
3. **The engine participates only via handed-in IDs.** `review` owns `setup`/`reconcile`/`render`/`report`;
   it passes `taskIds = { scope, intent, analyze, verify }` to `engine`, which flips exactly those
   handed-in IDs. Handed **no** `taskIds`, the engine takes no task action — byte-identical to its data-only
   contract. The engine never creates tasks.
4. **Finder and verifier subagents are task-blind.** They emit findings only and never touch the task list
   (consistent with lens's read-only finder contract).
5. **One task per stage, never per finder.** The parallel fan-out is the single `analyze` task regardless
   of how many finders run.
6. **Every run terminates every task.** No task may end a run `in_progress`. On the render-failure path
   (`review` SKILL Step 5), `render` is marked `deleted` (it ran but produced no artifact) and `report` is
   marked `completed` (telling the user the render failed *is* the report) — so even when the state write is
   skipped, the task list still reaches a fully-terminal state with no `failed` status.
