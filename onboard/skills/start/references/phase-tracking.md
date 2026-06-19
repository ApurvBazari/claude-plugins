# Phase Tracking — Durable Task Contract for onboard Entry Points

The single source of truth for how onboard's user-facing entry points (`start`, `update`,
`evolve`, `adopt`) surface their phases as durable tasks via the `TaskCreate` / `TaskUpdate`
tools — and how a half-finished run is resumed from a checkpoint. SKILL.md wiring in `start`,
`update`, `evolve`, and `adopt` follows this contract verbatim; this doc defines the labels they
cite (task subjects, the `currentPhase` generation-era marker, the durable on-disk resume anchor,
the state machine, the resume procedure).

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
| 0 | `empty-repo-check` | Checking for an empty repository | Empty-Repo Guard |
| 1 | `recon` | Reconnoitering the codebase | Recon (codebase-analyzer) |
| 2 | `research` | Researching the codebase | Research (profile-select + research engine) |
| 3 | `wizard` | Confirming preferences | Grounded Wizard |
| 4 | `build-context` | Detecting plugins & building context | Plugin Detection & Context |
| 5 | `plan-gate` | Planning & awaiting approval | Plan → Preview → HARD GATE |
| 6 | `generation` | Generating tooling | Generation (config-generator write) |
| 7 | `handoff` | Handing off | Handoff (explain artifacts, next steps) |

The subject is a **short, human-readable label** for the phase — for `start`, the bare phase
slug (`plan-gate`, `recon`, …). It is a *display value*: **nothing in the machinery parses the
subject string**. `TaskUpdate` addresses tasks by their `taskId` (returned at creation), the
cross-session resume decision keys on durable on-disk artifacts (§ Resume), and the Cancel guard
keys on task *status* — locating the gate task by its slug (`plan-gate`). Phase **order** is
defined by this table's row order and the `## Phase N` step headers in SKILL.md, **not** by an
index embedded in the subject. The task list is **not** the cross-session resume anchor (the
harness task list may be session-scoped and is not guaranteed to survive a new session) — the
durable on-disk artifacts in § Resume are. The list corroborates and visualizes; the artifacts
decide.

### Other entry points — own lists, entry-point-prefixed subjects

Each entry point creates its own list. `start` (the primary, highest-traffic path) uses **bare
slugs** for the cleanest labels; the three secondary entry points **prefix the slug with the
entry-point name** (`update:`, `evolve:`, `adopt:`). This asymmetry is **intentional** — the
secondary lists can coexist with a `start`/`adopt` list (the routing note below), so the prefix
keeps a combined list legible at a glance (`wizard` vs `adopt:wizard`) and keeps each secondary
task self-identifying. Like every subject here it is a **readability aid, not a parsed key** —
nothing in the machinery reads it; a list is recognizable as a given entry point's by its
slug-*set* (and, for the secondary three, its prefix). The phase ladder differs per skill (read
each SKILL.md for the authoritative step list — the phases below are the durable checkpoints, not
every internal sub-step):

| Entry point | Subject form | Phase ladder (durable tasks) |
|---|---|---|
| `start` | bare slug (no prefix) | 0 empty-repo-check · 1 recon · 2 research · 3 wizard · 4 build-context · 5 plan-gate · 6 generation · 7 handoff |
| `update` | `update:<slug>` | 0 verify-baseline · 1 read-artifacts · 2 reanalyze · 3 best-practices+drift · 4 present+preview · 5 approve-gate · 6 apply · 7 summary |
| `evolve` | `evolve:<slug>` | 0 detect-drift · 1 apply-updates · 2 show-diff · 3 clear-entries |
| `adopt` | `adopt:<slug>` | 0 detect-classify · 1 recon+research · 2 wizard · 3 synthesize · 4 preview-gate · 5 write+handoff |

The gate task is identified by its slug: `plan-gate` for `start`, `update:approve-gate` for
`update`, `adopt:preview-gate` for `adopt` (`evolve` has no hard gate — it presents a diff after
applying, per its SKILL.md). The state machine, gate mapping, and resume procedure in this
contract apply uniformly to all four — `start` is the worked example; the others differ only in
their ladder and their gate phase.

> **Routing note.** When `update` or `start` routes into `adopt` (the missing-baseline / existing-config
> branch), `adopt` owns its own `adopt:` list for the adopt run and marks it
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
   │   write checkpoint artifact (if any)         │  ← see § Resume table (the durable
   │                 │                            │    on-disk anchor: research dossier
   │                 ▼                            │    at Phase 2, meta at Phase 6)
   │   TaskUpdate(phase N → completed)            │  ← AFTER the phase's work succeeds
   │                                              │
   └──────────────────────────────────────────────┘
                 │
                 ▼  (after Phase 6 returns — meta now exists)
   set onboard-meta.json.currentPhase = 6
                 │
                 ▼  (after Phase 7 handoff completes)
   set onboard-meta.json.currentPhase = "done"
```

`onboard-meta.json` does **not** exist during Phases 0–5 of a normal run — it is first written by
generation at Phase 6. So `currentPhase` cannot be (and is not) written per-phase for Phases 0–5;
their durable progress is anchored by the **checkpoint artifacts** in § Resume (chiefly the Phase-2
research dossier), not by the meta. `currentPhase` is the **generation-era marker**, written by the
orchestrator *after* Phase 6 returns (`= 6`) and again at Phase 7 completion (`= "done"`).

Rules:

1. **Mark `in_progress` before the work, `completed` after.** A phase that dispatches an agent
   (`codebase-analyzer` in recon, `config-generator` in generation) marks its task `in_progress`
   *before* the `Agent(...)` dispatch and `completed` *after* the agent returns successfully.
   The agent itself never touches the task.
2. **One phase `in_progress` at a time.** Because phases are sequential, at most one task is
   `in_progress`.
3. **`currentPhase` is written from Phase 6 onward only** (see § Resume) — the orchestrator sets it
   to `6` after generation returns and `"done"` after handoff. It is *not* the Phases 0–5 anchor
   (no meta exists yet there); those phases are anchored by their on-disk checkpoint artifacts.
4. **Subagents never touch tasks.** `codebase-analyzer`, `config-generator`, `feature-evaluator`,
   and every internally-dispatched `Skill` are task-blind. Only the entry-point orchestrator
   mutates the list. The orchestrator (not generation) also owns the post-Phase-6 `currentPhase`
   writes — do not change generation's emission logic to write it.

## HARD GATE — start Phase 5 (and update Phase 5 / adopt Phase 4)

`start` Phase 5 is `Plan → Preview → HARD GATE`: the plan + preview are assembled, rendered, and
then the run halts awaiting the user's decision. The enum has no "awaiting" status, so the
mapping is:

- **While awaiting the user's decision** at the gate, the Phase-5 task (`plan-gate`)
  stays **`in_progress`**. It is *not* marked `completed` — nothing has been written yet, and the
  run is genuinely still in that phase. `in_progress` is the truthful state of "we are here,
  waiting on you."
- **Approve** → the user accepted the plan → mark Phase 5 `completed`, then proceed to Phase 6
  Generation (the only phase that writes artifacts).
- **Adjust** → the user wants changes → keep Phase 5 `in_progress`, re-plan, re-render, re-gate.
  No status change; the gate loops.
- **Cancel** → the user declined → see § Cancel below.

The same mapping applies to `update`'s approve-gate (`update:approve-gate`) and
`adopt`'s preview-gate (`adopt:preview-gate`). `evolve` has no hard gate.

### Cancel → `deleted` (no "cancelled" status exists)

When the user selects **Cancel** at the HARD GATE, nothing has been written (the gate precedes
the only write phase). The remaining phase tasks never ran. Since there is no `cancelled` status:

- Mark the gate task itself **and every later phase task** `deleted` via `TaskUpdate`. For
  `start` that is tasks **5, 6, and 7** (`plan-gate`, `generation`,
  `handoff`). For `update`: 5, 6, 7. For `adopt`: 4, 5.
- Leave the already-`completed` earlier tasks (0–4 for start) as `completed` — they really did run.
- Do **not** write `currentPhase` at all. The Phase-5 gate precedes Phase 6, so on a cancelled run
  `onboard-meta.json` was never created (or, on a re-run over an earlier completed setup, is left
  untouched) — there is no `currentPhase` to set or clear. The Cancel signature the resume guard
  keys on is the **`deleted` gate-or-later tasks**, not a meta value (§ Cancel-resume guard).

`deleted` here means "this unit of work was abandoned and produced nothing," which is exactly the
right durable record: the list shows phases 0–4 completed and 5+ removed, with no artifacts on disk.

## Resume — R2 checkpoint procedure

onboard runs can be interrupted (closed terminal, crash, `/clear`), possibly across sessions. On a
**fresh** entry, the orchestrator checks whether a prior incomplete run can be resumed from a
checkpoint.

### The anchor: durable on-disk artifacts (not the task list, not currentPhase-for-Phases-0–5)

The cross-session resume anchor is the set of **durable on-disk artifacts** a prior run left
behind, probed at the start of a fresh run. It is *not* the harness task list — that list may be
session-scoped and is not guaranteed to survive a new session, so it cannot be the cross-session
anchor (it remains the in-session progress display; § Task list). The two durable artifacts that
matter are:

| Probe (in order) | On disk | What it proves | Resume target |
|---|---|---|---|
| 1 | `.claude/onboard-meta.json` with an integer `currentPhase` (and a v3 `_generated.version`) | a generation-era run reached at least Phase 6 | from `currentPhase + 1`, or "already complete" if `currentPhase == "done"` |
| 2 | `.claude/onboard-research.json` (the Phase-2 dossier) but **no** meta | research completed; generation did not | into Phase 3 (re-confirm the wizard from the dossier; not skipping it) |
| 3 | neither | no prior run got far enough to checkpoint | none — clean start |

`currentPhase` is a top-level field on `onboard-meta.json`, **written only from Phase 6 onward**
(meta's first existence): the orchestrator sets it to the integer `6` after generation returns and
to the string `"done"` at Phase 7 handoff completion. It is the **generation-era marker** — it
distinguishes "generation ran, finish the handoff / it's done" from "generation never ran." It is
*absent* during Phases 0–5 (no meta exists), and **absent ⇒ no resume offered from probe 1**
(back-compat: a pre-feature meta with no `currentPhase` is treated as a completed prior run, not a
resumable one). The Phases 0–5 anchor is probe 2, the research dossier.

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

These artifacts **are the anchor** — a phase's progress is durable iff it wrote a row above. The
two re-hydratable checkpoints are **Phase 2 (research dossier on disk)** and **Phase 6 (meta +
snapshots + artifacts)**. Phases that keep their output only in conversation context (recon,
wizard, the assembled context) are *not* independently resumable from disk — see the resume
granularity note below.

### Resume vs Restart decision — the on-disk probe

On fresh entry, probe the two durable artifacts in order and branch (this is the table at the top
of § The anchor, made operational):

**Probe 1 — generation-era meta.** If **all** of these hold:

1. `.claude/onboard-meta.json` exists AND has an integer `currentPhase` (or `currentPhase == "done"`), AND
2. its `_generated.version` is a v3 semver — major version (the segment before the first `.`) is
   `3` (e.g. `"3.0.0"`). A pre-v3 meta is not resumable under this contract; fall through to the
   entry point's normal existing-config flow. (Do NOT check a top-level integer `version` — no such
   field is written to `onboard-meta.json`; the integer `version: 3` is an in-memory context marker
   only.), AND
3. the run's task list, if still present this session, is **not cancelled** (none of the
   gate-or-later tasks `deleted` — see § Cancel-resume guard; if the list is gone, this clause is
   vacuously satisfied — the meta+currentPhase is the durable witness),

then:
- if `currentPhase == "done"` → the prior run finished; do **not** offer resume — report it's
  already complete and route to the entry point's existing-config flow (update / start-fresh).
- else (integer `currentPhase`, i.e. `6`) → offer **Resume** (finish from Phase `currentPhase + 1`
  — Phase 7 handoff) or **Restart**.

**Probe 2 — research dossier, no meta.** Else if `.claude/onboard-research.json` exists but
`.claude/onboard-meta.json` does **not** (and any task list present is non-cancelled) → research
completed but generation never ran. Offer **Resume into Phase 3** (the wizard re-confirms from the
dossier's `research.wizardInferences` — this is **not** skipping the wizard) → continue forward
through context → plan-gate → generation, **or Restart**.

**Probe 3 — neither.** Else (no meta, no dossier) → fresh start; **no** resume offer.

When a resume is offered (probe 1 integer case, or probe 2), ask via single-select
`AskUserQuestion` with **two fixed options** — Resume / Restart. Because both options are fixed
(not built from a dynamic list that could collapse to one), the single-option guard in
`.claude/rules/ask-user-question-guard.md` does **not** apply:

- **Resume (Recommended)** — "Continue the interrupted run." Rehydrate from the checkpoint
  artifact(s) (read the dossier, re-derive context), re-create the task list reflecting completed
  phases as `completed` and the rest `pending`, and continue from the resume target above (Phase 7
  for probe 1, Phase 3 for probe 2).
- **Restart** — "Discard the interrupted run and start fresh from Phase 0." Mark any leftover
  incomplete tasks `deleted`, create a fresh list, begin at Phase 0. (Generation is merge-aware,
  so a restart that re-reaches Phase 6 will not clobber user edits — see below.)

If neither probe matches (no dossier, no meta-with-currentPhase) — or the meta says
`currentPhase == "done"` — do **not** offer resume; proceed as a clean start (or, for a `"done"`
meta, the entry point's existing-config flow).

### Resume granularity — what "continue" means in practice

Because recon/wizard/context keep their output in conversation context (not on disk), a resume
that lands *after* those phases but whose conversation context is gone (new session) must
re-derive them. The two resumable cases map onto the two probes:

- **Probe 2 (dossier on disk, no meta)** → the expensive research is preserved; rehydrate
  `research` from `.claude/onboard-research.json`, then **re-run** the cheap in-context phases
  (recon is read-only and fast; the wizard re-confirms from the rehydrated
  `research.wizardInferences`; context rebuilds deterministically), continuing forward through
  plan-gate → generation. Resume's value here is preserving the expensive research, **not** skipping
  the wizard.
- **Probe 1 (meta with integer `currentPhase == 6`)** → generation already wrote
  `onboard-meta.json` + artifacts. Resuming means finishing Phase 7 Handoff (or, if generation was
  interrupted mid-write, re-running Phase 6 — see next).

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

Concretely, when the task list is still present this session, the resume probe treats it as
**"no in-progress run"** (→ clean start, no Resume/Restart prompt) when **any** of:

- the gate task (`plan-gate` for start) is `deleted`, OR
- one or more of the post-gate tasks (6, 7 for start) are `deleted`, OR
- there is no incomplete task list at all owned by this entry point (recognized by its
  slug-set — and, for the secondary three, its prefix).

This is the non-cancelled clause of probe 1/probe 2, restated as a guard. A Cancel at the gate
happens **before** Phase 6, so it writes **no** `onboard-meta.json` (probe 1 finds nothing) and
leaves **no** new dossier beyond what Phase 2 already wrote. The only ambiguous case is "Cancel
after a prior research run left a dossier on disk": the dossier alone would make probe 2 look
resumable, but the **`deleted` gate-or-later tasks** are the in-session signal that the user
deliberately abandoned this run — honor them and treat it as a clean start. (Across sessions, where
the list is gone, a lone dossier with no meta is genuinely indistinguishable from an interrupted
research run and is correctly offered as a probe-2 resume — Restart is always available.)

## Key rules

1. **Four owners only** — `start`, `update`, `evolve`, `adopt` create tasks; every internal skill
   (`generate`, `wizard`, `research`, `generation`, `analysis`) and every agent creates none.
2. **Real enum only** — `pending` / `in_progress` / `completed` / `deleted`. The gate "awaiting"
   maps to `in_progress`; Cancel maps to `deleted` on gate-and-later tasks. Never invent a status.
3. **`in_progress` before work (and before any agent dispatch), `completed` after.** One phase
   `in_progress` at a time. Subagents stay task-blind.
4. **Durable on-disk artifacts are the cross-session resume anchor** — probed in order:
   `onboard-meta.json` with an integer `currentPhase` (probe 1, generation-era), then
   `onboard-research.json` with no meta (probe 2, post-research), then neither (clean start). The
   task list is **in-session visibility only**, not the cross-session anchor (it may be
   session-scoped).
5. **`currentPhase` is the generation-era marker, written from Phase 6 onward only** — the
   orchestrator (not generation) sets it to `6` after Phase 6 returns and `"done"` at Phase 7
   completion. It does **not** exist during Phases 0–5 (no meta yet); absent ⇒ no probe-1 resume
   (back-compat). Probe 1 also requires `_generated.version` major == `3` (starts with `"3."` — do
   NOT check a top-level integer `version` field, which is never written) and a non-cancelled list
   if one is present.
6. **Generation is re-runnable, not recoverable** — interrupted Phase 6 is fixed by re-running the
   merge-aware phase, never by partial-file surgery.
7. **Cancelled (gate-or-later `deleted`) lists never offer resume** — they are a clean start.
