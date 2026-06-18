# Phase Tracking — Durable Task Contract for onboard Entry Points

The single source of truth for how onboard's user-facing entry points (`start`, `update`,
`evolve`, `adopt`) surface their phases as durable tasks via the `TaskCreate` / `TaskUpdate`
tools — and how a half-finished run is resumed from a checkpoint. SKILL.md wiring in `start`,
`update`, `evolve`, and `adopt` follows this contract verbatim; this doc defines the labels they
cite (task subjects, the `currentPhase` anchor, the state machine, the resume procedure).

## Verified status enum — use these values only

The `TaskCreate` / `TaskUpdate` tool status field accepts **exactly** these values:

| Status | Meaning |
|---|---|
| `pending` | created, not started |
| `in_progress` | actively running |
| `completed` | finished |
| `deleted` | removed from the list (passed to `TaskUpdate` to drop a task that never ran / no longer applies) |

There is **no** `blocked`, `cancelled`, `abandoned`, or `failed` status. Every state this
contract describes maps onto one of the four values above — do not invent a fifth. The two
non-obvious mappings are the HARD GATE (§ HARD GATE) and Cancel (§ Cancel → `deleted`); both are
spelled out below precisely because the enum has no native "awaiting" or "cancelled" state.

Tasks are created with `subject`, `description`, and an optional `activeForm` (the present-tense
gerund shown while running). Tasks are updated by `taskId` + `status`. Dependency edges
(`addBlockedBy` / `addBlocks`) exist but onboard's phases are strictly sequential, so this
contract does **not** use them — the orchestrator runs one phase at a time and the ordering is
implicit in the subject's phase index.

## Ownership — only entry points create tasks

**Only the four user-facing entry-point skills create tasks**: `start`, `update`, `evolve`,
`adopt`. Each owns exactly one task list for the duration of its run.

**Internal skills create NO tasks**: `generate`, `wizard`, `research`, `generation`, `analysis`.
They run *inside* a parent phase (e.g. `wizard` and `research` run inside `start` Phase 2/3;
`generate` runs inside `start` Phase 5 plan + Phase 6 write). The parent phase's single task
already represents that work. An internal skill creating its own task would double-track the same
unit of work and desynchronize the list. The rule is absolute: **if a skill is invoked via the
`Skill` tool by another skill, it touches no tasks.**

Likewise the dispatched **agents** (`codebase-analyzer`, `config-generator`,
`feature-evaluator`) never create or update tasks. The orchestrator that dispatches them owns the
surrounding task transition (§ Transitions).

## Task list — `/onboard:start` (8 tasks, Phases 0–7)

`start` creates exactly **8** tasks up front, one per phase, all `pending`:

| Task | `subject` | `activeForm` | Phase work |
|---|---|---|---|
| 0 | `onboard:phase:0:guard` | Checking for an empty repository | Empty-Repo Guard |
| 1 | `onboard:phase:1:recon` | Reconnoitering the codebase | Recon (codebase-analyzer) |
| 2 | `onboard:phase:2:research` | Researching the codebase | Research (profile-select + research engine) |
| 3 | `onboard:phase:3:wizard` | Confirming preferences | Grounded Wizard |
| 4 | `onboard:phase:4:context` | Detecting plugins & building context | Plugin Detection & Context |
| 5 | `onboard:phase:5:plan-gate` | Planning & awaiting approval | Plan → Preview → HARD GATE |
| 6 | `onboard:phase:6:generation` | Generating tooling | Generation (config-generator write) |
| 7 | `onboard:phase:7:handoff` | Handing off | Handoff (explain artifacts, next steps) |

The subject scheme is `onboard:phase:<N>:<slug>` where `<N>` is the integer phase index and
`<slug>` is the short phase name. This scheme is **load-bearing**: the resume procedure derives
the current task from `onboard-meta.json.currentPhase` (an integer) by matching the `:<N>:`
segment, and the `onboard:phase:` prefix lets a fresh run recognize one of *its own* incomplete
lists (versus an `update`/`evolve`/`adopt` list) without parsing descriptions.

### Other entry points — distinct subject prefixes, own lists

Each entry point creates its own list with a **distinct subject prefix** so the lists never
collide and a resume probe can tell which entry point owns an incomplete run. The prefix encodes
the entry point; the phase ladder differs per skill (read each SKILL.md for the authoritative
step list — the phases below are the durable checkpoints, not every internal sub-step):

| Entry point | Subject prefix | Phase ladder (durable tasks) |
|---|---|---|
| `start` | `onboard:phase:` | 0 guard · 1 recon · 2 research · 3 wizard · 4 context · 5 plan-gate · 6 generation · 7 handoff |
| `update` | `onboard:update:phase:` | 0 verify-baseline · 1 read-artifacts · 2 reanalyze · 3 best-practices+drift · 4 present+preview · 5 approve-gate · 6 apply · 7 summary |
| `evolve` | `onboard:evolve:phase:` | 0 detect-drift · 1 apply-updates · 2 show-diff · 3 clear-entries |
| `adopt` | `onboard:adopt:phase:` | 0 detect-classify · 1 recon+research · 2 wizard · 3 synthesize · 4 preview-gate · 5 write+handoff |

The subject within each is `<prefix><N>:<slug>` (e.g. `onboard:update:phase:5:approve-gate`,
`onboard:adopt:phase:4:preview-gate`). The state machine, gate mapping, and resume procedure in
this contract apply uniformly to all four — `start` is the worked example; the others differ only
in their ladder and their gate phase (the gate task for `update` is `5:approve-gate`, for `adopt`
`4:preview-gate`; `evolve` has no hard gate — it presents a diff after applying, per its SKILL.md).

> **Routing note.** When `update` or `start` routes into `adopt` (the missing-baseline / existing-config
> branch), `adopt` owns its own `onboard:adopt:phase:` list for the adopt run and marks it
> complete on handoff; control then returns to the caller, which continues its own list. The two
> lists coexist; neither entry point touches the other's tasks.

## Transitions — the state machine

The orchestrator (the entry-point skill) drives every transition. The shape is identical for all
phases:

```
        create list (all pending)
                 │
                 ▼
   ┌──────────── per phase, in order ────────────┐
   │                                              │
   │   TaskUpdate(phase N → in_progress)          │  ← BEFORE the phase's work begins,
   │                 │                            │    and BEFORE dispatching any agent
   │                 ▼                            │    (codebase-analyzer / config-generator)
   │        [run the phase's work]                │    or invoking any internal Skill
   │                 │                            │
   │                 ▼                            │
   │   write checkpoint artifact (if any)         │  ← see § Resume table
   │   update onboard-meta.json.currentPhase = N  │
   │                 │                            │
   │                 ▼                            │
   │   TaskUpdate(phase N → completed)            │  ← AFTER the phase's work succeeds
   │                                              │
   └──────────────────────────────────────────────┘
                 │
                 ▼  (after phase 7)
   onboard-meta.json.currentPhase = "done"
```

Rules:

1. **Mark `in_progress` before the work, `completed` after.** A phase that dispatches an agent
   (`codebase-analyzer` in recon, `config-generator` in generation) marks its task `in_progress`
   *before* the `Agent(...)` dispatch and `completed` *after* the agent returns successfully.
   The agent itself never touches the task.
2. **One phase `in_progress` at a time.** Because phases are sequential, at most one task is
   `in_progress`. This invariant is what lets the resume probe trust `currentPhase`.
3. **`currentPhase` is updated as part of completing a phase** (see § Resume) — the meta write and
   the `TaskUpdate(... → completed)` happen together so the anchor and the list never disagree by
   more than the in-flight phase.
4. **Subagents never touch tasks.** `codebase-analyzer`, `config-generator`, `feature-evaluator`,
   and every internally-dispatched `Skill` are task-blind. Only the entry-point orchestrator
   mutates the list.

## HARD GATE — start Phase 5 (and update Phase 5 / adopt Phase 4)

`start` Phase 5 is `Plan → Preview → HARD GATE`: the plan + preview are assembled, rendered, and
then the run halts awaiting the user's decision. The enum has no "awaiting" status, so the
mapping is:

- **While awaiting the user's decision** at the gate, the Phase-5 task (`onboard:phase:5:plan-gate`)
  stays **`in_progress`**. It is *not* marked `completed` — nothing has been written yet, and the
  run is genuinely still in that phase. `in_progress` is the truthful state of "we are here,
  waiting on you."
- **Approve** → the user accepted the plan → mark Phase 5 `completed`, then proceed to Phase 6
  Generation (the only phase that writes artifacts).
- **Adjust** → the user wants changes → keep Phase 5 `in_progress`, re-plan, re-render, re-gate.
  No status change; the gate loops.
- **Cancel** → the user declined → see § Cancel below.

The same mapping applies to `update`'s approve-gate (`onboard:update:phase:5:approve-gate`) and
`adopt`'s preview-gate (`onboard:adopt:phase:4:preview-gate`). `evolve` has no hard gate.

### Cancel → `deleted` (no "cancelled" status exists)

When the user selects **Cancel** at the HARD GATE, nothing has been written (the gate precedes
the only write phase). The remaining phase tasks never ran. Since there is no `cancelled` status:

- Mark the gate task itself **and every later phase task** `deleted` via `TaskUpdate`. For
  `start` that is tasks **5, 6, and 7** (`onboard:phase:5:plan-gate`, `:6:generation`,
  `:7:handoff`). For `update`: 5, 6, 7. For `adopt`: 4, 5.
- Leave the already-`completed` earlier tasks (0–4 for start) as `completed` — they really did run.
- Do **not** set `currentPhase = "done"`. A cancelled run did not complete; leave `currentPhase`
  at the gate phase's index (e.g. `5`). The combination "gate-phase tasks `deleted` + `currentPhase`
  still at the gate index" is the signature the Cancel-resume guard keys on (§ Cancel-resume guard).

`deleted` here means "this unit of work was abandoned and produced nothing," which is exactly the
right durable record: the list shows phases 0–4 completed and 5+ removed, with no artifacts on disk.

## Resume — R2 checkpoint procedure

onboard runs can be interrupted (closed terminal, crash, `/clear`). On a **fresh** entry, the
orchestrator checks whether a prior incomplete run can be resumed from a checkpoint.

### The anchor: `onboard-meta.json.currentPhase`

`currentPhase` is a top-level integer field on `onboard-meta.json`:

- An **integer 0–7** — the highest phase that has *completed* its checkpoint write for `start`
  (each entry point uses its own 0..N range). The run was interrupted at or after phase
  `currentPhase + 1`.
- The string **`"done"`** — the run finished all phases. No resume.
- **Absent** — no run has progressed far enough to write a checkpoint (or the meta predates this
  feature). Treat as a clean start; no resume offer.

`currentPhase` is the *single* anchor. The task list corroborates it but the integer is
authoritative — if the list and the anchor disagree, trust `currentPhase` (it is written
atomically with the phase-complete transition; § Transitions rule 3).

### Phase → checkpoint-artifact map

A phase is *resumable* only if it wrote a durable artifact that later phases consume. These
already exist (this feature does not add new artifacts — it reuses the ones below):

| Phase | Checkpoint artifact(s) on disk | Consumed by |
|---|---|---|
| 0 guard | (none — guard is a branch, not a write) | — |
| 1 recon | (none — recon report stays in conversation context, not on disk) | Phase 2+ |
| 2 research | `.claude/onboard-research.json` dossier + `docs/` architecture / risk-register / glossary | Phase 3 wizard, Phase 6 generation |
| 3 wizard | (none — `wizardAnswers` live in conversation context) | Phase 4+ |
| 4 context | the assembled v3 context block + plugin probe (in context; reconstructable) | Phase 5/6 |
| 5 plan-gate | (none written — plan mode writes nothing; the gate precedes any write) | — |
| 6 generation | `.claude/onboard-meta.json` + snapshots + the generated artifacts | `update` / `evolve` |
| 7 handoff | (none — narration only) | — |

The durable, re-hydratable checkpoints are **Phase 2 (research dossier on disk)** and **Phase 6
(meta + snapshots + artifacts)**. Phases that keep their output only in conversation context
(recon, wizard, the assembled context) are *not* independently resumable from disk — see the
resume granularity note below.

### Resume vs Restart decision

On fresh entry, if **all** of these hold:

1. `onboard-meta.json` exists and `currentPhase` is an integer (not `"done"`, not absent), AND
2. an incomplete, **non-cancelled** task list with the matching entry-point prefix is present
   (some tasks `pending`/`in_progress`, none of the gate-or-later tasks `deleted` — see § Cancel-resume guard), AND
3. `onboard-meta.json`'s `_generated.version` is a v3 semver — its major version (the segment
   before the first `.`) is `3` (e.g. `"3.0.0"`). A pre-v3 meta is not resumable under this
   contract; fall through to the entry point's normal existing-config flow. (Do NOT check a
   top-level integer `version` — no such field is written to `onboard-meta.json`; the integer
   `version: 3` is an in-memory context marker only.), AND
4. the checkpoint artifact for `currentPhase` is **present on disk** (e.g. if `currentPhase ≥ 2`,
   `.claude/onboard-research.json` exists),

then offer the user **Resume** or **Restart** (single-select `AskUserQuestion`, two fixed options —
the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply):

- **Resume (Recommended)** — "Continue the interrupted run from Phase `<currentPhase + 1>`."
  Rehydrate from the checkpoint artifact(s) (read the dossier, re-derive context), re-create the
  task list reflecting completed phases as `completed` and the rest `pending`, and continue from
  `currentPhase + 1`.
- **Restart** — "Discard the interrupted run and start fresh from Phase 0." Mark any leftover
  incomplete tasks `deleted`, create a fresh list, begin at Phase 0. (Generation is merge-aware,
  so a restart that re-reaches Phase 6 will not clobber user edits — see below.)

If **any** of (1)–(4) fail, do **not** offer resume — proceed as a clean start (or the entry
point's existing-config flow if `onboard-meta.json` exists from a *completed* prior run, i.e.
`currentPhase === "done"`).

### Resume granularity — what "continue from currentPhase" means in practice

Because recon/wizard/context keep their output in conversation context (not on disk), a resume
that lands *after* those phases but whose conversation context is gone (new session) must
re-derive them. In practice:

- **`currentPhase` 0 or 1** → effectively restart (nothing durable was checkpointed yet).
- **`currentPhase` 2–5** → the research dossier is on disk; rehydrate `research` from it, then
  **re-run** the cheap in-context phases (recon is read-only and fast; wizard re-confirms from the
  rehydrated `research.wizardInferences`; context rebuilds deterministically). Resume's value here
  is preserving the expensive research, not skipping the wizard.
- **`currentPhase` 6** → generation already wrote `onboard-meta.json` + artifacts. Resuming means
  finishing Phase 7 Handoff (or, if generation was interrupted mid-write, re-running Phase 6 — see
  next).

### Generation (Phase 6) is re-runnable — no partial-file recovery

Phase 6 generation uses **merge-aware writes** (read settings.json first, never overwrite; honor
the customization floor; marker surgery for managed sections — per the generation skill). A Phase 6
that was interrupted mid-write is recovered by simply **re-running Phase 6**: the merge-aware
emission reconciles whatever partial artifacts exist with the intended output. This contract does
**NOT** attempt partial-file recovery, byte-level rollback, or write-journaling — those are out of
scope. The recovery primitive is "re-run the idempotent, merge-aware phase," full stop.

## Cancel-resume guard (edge case)

A task list whose **gate-or-later tasks are `deleted`** (the Cancel signature from § Cancel) must
**not** trigger a resume offer. Such a list represents a run the user deliberately abandoned at the
gate — there is nothing to resume (nothing was written), and re-offering it would be confusing.

Concretely, on fresh entry the resume probe treats a list as **"no in-progress run"** (→ clean
start, no Resume/Restart prompt) when **any** of:

- the gate task (`onboard:phase:5:plan-gate` for start) is `deleted`, OR
- one or more of the post-gate tasks (6, 7 for start) are `deleted`, OR
- there is no incomplete task list at all with the entry-point prefix.

This is condition (2) of the Resume-vs-Restart test, restated as a guard. The Cancel path
deliberately leaves `currentPhase` at the gate index (not `"done"`), so the *anchor* alone would
otherwise look resumable — the `deleted`-tasks check is what distinguishes "interrupted mid-run"
(resumable) from "user cancelled at the gate" (clean start). Both share an integer `currentPhase`;
only the cancelled one has `deleted` gate-or-later tasks.

## Key rules

1. **Four owners only** — `start`, `update`, `evolve`, `adopt` create tasks; every internal skill
   (`generate`, `wizard`, `research`, `generation`, `analysis`) and every agent creates none.
2. **Real enum only** — `pending` / `in_progress` / `completed` / `deleted`. The gate "awaiting"
   maps to `in_progress`; Cancel maps to `deleted` on gate-and-later tasks. Never invent a status.
3. **`in_progress` before work (and before any agent dispatch), `completed` after.** One phase
   `in_progress` at a time. Subagents stay task-blind.
4. **`currentPhase` (int 0–N or `"done"`) is the resume anchor**, written atomically with each
   phase-complete transition; the task list corroborates but the integer is authoritative.
5. **Resume requires all four conditions** — integer `currentPhase`, a non-cancelled incomplete
   list, `_generated.version` major == `3` (i.e. `onboard-meta.json`'s `_generated.version`
   starts with `"3."` — do NOT check a top-level integer `version` field, which is never
   written), and the checkpoint artifact present on disk. Otherwise clean start.
6. **Generation is re-runnable, not recoverable** — interrupted Phase 6 is fixed by re-running the
   merge-aware phase, never by partial-file surgery.
7. **Cancelled (gate-or-later `deleted`) lists never offer resume** — they are a clean start.
