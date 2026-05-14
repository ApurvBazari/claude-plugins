---
name: pickup
description: Resume an in-progress greenfield session from the last checkpoint in .claude/greenfield-state.json. Use when user wants to continue a paused /greenfield:start run, asks about resuming greenfield, mentions a session was interrupted, or opens a fresh Claude Code conversation in a project that has a greenfield session in flight.
---

# Pickup Skill — Resume an In-Progress Greenfield Session

You are resuming an in-progress Greenfield workflow that was paused mid-flight. Greenfield persists its state to `.claude/greenfield-state.json` at every checkpoint, so you can pick up exactly where the previous session left off — even in a completely fresh Claude Code conversation.

---

## State migration: alpha.4 → alpha.5 (Round 4)

**MANDATORY.** Runs at the very top of `/greenfield:pickup` (before resume detection, before Step 0 stale-check, before Step 1 / Step 1.5). Non-destructive — all existing R1–R3 state preserved verbatim.

### Trigger

Read `.claude/greenfield-state.json.schemaVersion`. The values:

| schemaVersion | Round | Action |
|---|---|---|
| (absent) or `1` | R1 / R2 / R2.5 | No migration needed (legacy state pre-dates the schemaVersion field). The shim treats this as alpha.3 — runs the alpha.4 chain first, then alpha.5. |
| `"alpha.4"` | R3 | Run alpha.4 → alpha.5 migration (below). |
| `"alpha.5"` | R4+ | Already migrated. Skip. |
| Any other value | unknown | Halt with error: "Unknown schemaVersion `<value>` in greenfield-state.json. Manual inspection required." |

### Migration steps (alpha.4 → alpha.5)

When schemaVersion is `"alpha.4"`:

1. **Set safe-default mode flags** — these chose the SAFEST defaults for in-flight sessions, NOT the new-session defaults (which are Heavy + Auto-loop + Full DDD per `feedback_comprehensive_by_default.md`). Safe defaults avoid retroactively expanding completed work:
   - `mode.depth = "heavy"` — preserve comprehensive posture; existing R3-walked phases were comprehensive.
   - `mode.coupling = "hybrid"` — SAFER than auto-loop for in-flight sessions; avoids retroactively per-persona-looping completed phases. User can upgrade to auto-loop via Adjust mode.
   - `mode.domainFormat = "ddd-lite"` — lighter; user can upgrade explicitly when Step 2.7 runs.
2. **Mark new R4 phases as not-yet-run:**
   - `phaseStatus.personas = { status: "not-yet-walked", approvedAt: null, lastModified: <now>, staleReason: null }`
   - `phaseStatus.domainModel = { ... same }`
3. **Initialize empty R4 collections:**
   - `context.personas = { primary: [], secondary: [], antiPersonas: [] }`
   - `context.domainModel = { contexts: [], entities: [], valueObjects: [], domainEvents: [], crossContextRelationships: [], ubiquitousLanguage: [], antiCorruption: "" }`
   - `context.risks = []`
   - `context.phases.architecturalValidation.riskReconciliation = { summary: {}, topFollowups: [] }`
4. **Bump version:** `state.schemaVersion = "alpha.5"`.
5. **Append audit entry** to `.claude/greenfield-meta.json.audit[]`:
   ```jsonc
   {
     "at": "<iso8601-now>",
     "action": "schema-migration",
     "from": "alpha.4",
     "to": "alpha.5",
     "details": {
       "mode-defaults-set": {
         "depth": "heavy",
         "coupling": "hybrid",
         "domainFormat": "ddd-lite"
       },
       "new-phases-marked": ["personas", "domainModel"],
       "initialized-collections": ["context.personas", "context.domainModel", "context.risks", "phases.architecturalValidation.riskReconciliation"]
     }
   }
   ```
6. **Atomic checkpoint** — write `.claude/greenfield-state.json.tmp` then rename (atomic write).
7. **Surface notice to developer** via plain text (NOT AskUserQuestion — this is informational, no choice needed):

   ```
   ─────────────────────────────────────────
   Round 4 update applied — schema bumped to alpha.5
   ─────────────────────────────────────────
   Round 4 adds two new wizard phases:
     • Step 2.2 — Personas (new in R4)
     • Step 2.7 — Domain Modeling (new in R4)

   Mode defaults set (safe for mid-session resume):
     • depth        = heavy
     • coupling     = hybrid  (lighter than the new-session default of auto-loop)
     • domainFormat = ddd-lite (lighter than the new-session default of full-ddd)

   You can upgrade any toggle via the wizard's Adjust mode prompt.

   New phases are queued as "not-yet-walked". Resume current step normally,
   or run Personas + Domain phases retroactively via:
     /greenfield:pickup → Add R4 phases
   ─────────────────────────────────────────
   ```

8. **Surface AskUserQuestion** for the immediate-action choice:

   ```
   "How do you want to handle the new R4 phases?"
     • Add now (Recommended) — pause current step, run personas + domain phases.
        Downstream phases marked stale for post-hoc drift detection.
     • Defer — resume current step. Personas + domain will surface when user advances
        past them (or never, if past Step 3 already — they remain optional).
     • Skip — explicitly mark personas + domain as user-skipped. No back-fill,
        no drift detection. Mode toggles still apply to remaining phases.
   ```

If "Add now": jump to context-gathering Step 2.2. Original currentStep saved to `resumeAfterR4PhasesStep`. After personas + domain complete, jump back.

If "Defer": continue current step. The drift-detection check (§ Persona/entity post-hoc add detection) will surface drift opportunities later.

If "Skip": set `phaseStatus.personas.status = "user-skipped"` and `.domainModel.status = "user-skipped"`. Synthesis-review treats these as `synthesisStatus: "n/a"`. Downstream phases retain their non-looped or hybrid-only behavior.

### Idempotency

The migration MUST be idempotent. After the migration, schemaVersion is `"alpha.5"`. Re-running pickup reads `"alpha.5"` and skips the migration. The audit-log entry is appended once per migration; running pickup on a v2-state machine adds no further audit entries.

### Failure modes

- **Concurrent state writes:** if a write fails (e.g., disk full, permission denied), do NOT leave state half-migrated. Roll back by detecting the partial write and removing the `.tmp` file. Surface to user: "State migration interrupted — original alpha.4 state preserved. Fix the underlying issue and re-run /greenfield:pickup." Do NOT auto-retry.
- **Unknown schemaVersion:** halt with diagnostic, never silently treat as alpha.4.
- **Missing greenfield-state.json:** not a migration scenario — the file should exist if pickup is being invoked. If absent, defer to the existing pickup logic that handles "no in-flight session." (Step 1 below.)

### Migration: alpha.5 → alpha.6 (Round 5)

If `state.meta.schemaVersion` is less than `"3.0.0-alpha.6"`:

1. If `state.phases.featureRoadmap` is absent, inject:
   ```json
   { "skipped": true, "deferredReason": "session predates Round 5" }
   ```
2. If `state.phases.schemaDraftReview` is absent, inject the same shape.
3. Set `state.meta.schemaVersion = "3.0.0-alpha.6"`.
4. Atomic write via `.tmp + rename`.
5. Surface to user:
   > Session migrated to alpha.6. Steps 16 (Feature Roadmap) and 19 (Schema Draft Review) are now available via Adjust mode — re-enter them to populate these phases.

The migration is **additive and safe**: existing alpha.5 phase data (personas, domainModel, risks, etc.) is preserved unchanged. Onboard generation falls back to the alpha.5 interactive handoff flow when these phases remain `skipped: true`.

---

## Step 1: Locate the state file

Check for `.claude/greenfield-state.json` in the current working directory.

**If not found**:

> No in-progress Greenfield session found in this directory.
>
> - If this is a new project → run `/greenfield:start` to start.
> - If you expected a session to be in progress here → you may be in the wrong directory. Greenfield state is project-local; `cd` into the project that was in progress.

Stop.

**If found**: proceed to Step 2.

---

## Step 1.5: Check schema version

Before parsing the full state, check the `schemaVersion` field. This early check prevents incompatible state JSON from being loaded.

Read `.claude/greenfield-state.json` and extract the `schemaVersion` field at the root level.

**Expected schema version**: `"alpha.5"` (after the migration shim above has run).

The State migration block above will have already converted any `"alpha.4"` (or pre-versioned legacy state) up to `"alpha.5"`. By the time this step runs, the only valid values are `"alpha.5"`, or — for very old R1/R2 sessions where migration ran the alpha.3→alpha.4→alpha.5 chain — also `"alpha.5"`.

**If `schemaVersion !== "alpha.5"`**:

> ⚠️  This wizard session was saved by a different greenfield version, and the alpha.4→alpha.5 migration shim did not apply.
>
> Detected schemaVersion: [actual value or "missing"] | Expected: "alpha.5"
>
> The migration shim only handles `"alpha.4"` → `"alpha.5"`. Other unknown values halt here.
>
> **Restart with `/greenfield:start`**
>
> See `greenfield/skills/start/references/state-schema-evolution.md` for the policy.

Stop. Do not proceed to Step 2. The user must start a fresh session.

**If `schemaVersion === "alpha.5"`**: proceed to Step 2.

---

## Step 2: Parse and validate state

Read `.claude/greenfield-state.json`. Expected schema:

```json
{
  "schemaVersion": "alpha.5",
  "createdAt": "ISO-8601 timestamp",
  "updatedAt": "ISO-8601 timestamp",
  "currentPhase": "phase-1-context-gathering | phase-1.8-synthesis-review | phase-1.5-architectural-research | phase-1.7-grill-spec | phase-2-scaffold | phase-3a-plugin-discovery | phase-3b-tooling-generation | phase-4-lifecycle-setup | complete",
  "currentSynthesisPhase": "architecturalFraming | dataArchitecture | apiIntegration | auth | privacy | security | runtimeOperations | cicdAndDelivery | architecturalValidation — set only when currentPhase === 'phase-1.8-synthesis-review'; identifies which phaseId is being reviewed. Valid values in Round 2 / Round 2.5: \"architecturalFraming\", \"dataArchitecture\", \"apiIntegration\", \"cicdAndDelivery\", \"architecturalValidation\". Round 3 adds: \"auth\", \"privacy\", \"security\", \"runtimeOperations\".",
  "currentStep": "step-identifier (skill-specific)",
  "completedSteps": ["list of completed step identifiers"],
  "context": { /* partial context object, grows as wizard progresses */ },
  "researchFindings": { /* stack research results, if gathered */ },
  "parkedQuestions": [ /* deferred deep-research items */ ],
  "nextAction": "human-readable description of what happens next",
  "research": {
    "mode": "agent | main-session | training-data-only"
  },
  "phaseStatus": {
    "architecturalFraming": { "status": "not-yet-walked | in-progress | approved | stale | approved-with-noted-divergences | requires-rework", "approvedAt": "ISO-8601 or null", "lastModified": "ISO-8601", "staleReason": "null or string" },
    "dataArchitecture": { "status": "...", "approvedAt": "...", "lastModified": "...", "staleReason": "..." },
    "apiIntegration": { "status": "...", "approvedAt": "...", "lastModified": "...", "staleReason": "..." },
    "cicdAndDelivery": { "status": "...", "approvedAt": "...", "lastModified": "...", "staleReason": "..." },
    "architecturalValidation": { "status": "...", "approvedAt": "...", "lastModified": "...", "staleReason": "..." }
  }
}
```

Validate:
- `schemaVersion` field exists and equals `"alpha.5"` (handled by State migration + Step 1.5, but double-check here for safety)
- `currentPhase` is one of the known phases
- `context` is a valid object (even if partial)

**If the file is corrupt or missing required fields**:

> Found `.claude/greenfield-state.json` but it's malformed: [specific error].
>
> Options:
> 1. Show me the raw file contents so we can recover together
> 2. Delete it and start fresh with `/greenfield:start`
> 3. Restore from git history if the file is tracked

Ask the user. Do not auto-delete.

---

## Step 3: Check for terminal state

**If `currentPhase === "complete"`**:

> This Greenfield session already completed on [updatedAt]. Running `/greenfield:pickup` does nothing — there's nothing to resume.
>
> Use `/greenfield:check` to inspect the completed project, or start a new project in a different directory with `/greenfield:start`.

Stop.

---

## Step 4: Present the resume summary

Show the user what will happen:

> **Resuming Greenfield session**
>
> **Project**: [context.appDescription or "unnamed project"]
> **Started**: [createdAt]
> **Last updated**: [updatedAt] ([time delta, e.g., "2 hours ago"])
>
> **Progress so far**:
> - ✅ [completedSteps rendered as a checklist with friendly names]
>
> **Phase synthesis status**:
> [For each phase in phaseStatus, render one line:]
> - [phaseId]: [status emoji] [status] [if stale: "— {staleReason}"]
>
> Status legend: ✅ approved | 🔄 in-progress | ⚠️ stale | 🔁 approved-with-noted-divergences | ❌ requires-rework | — not-yet-walked
>
> [If ANY phase has status === "stale"]:
> **⚠️ Stale phases detected**: [list of stale phaseIds and their staleReasons]
> These phases reference values that changed since they were approved. When you re-enter them, I'll offer a re-walk prompt.
>
> **Next action**:
> [nextAction from state file, e.g., "Continue Phase 1 Step 3 — Project Details (Q3.4: deploy target)"]
>
> **Research mode**: [research.mode, e.g., "main-session (user approves each web call)"]
>
> Ready to continue? (yes/no)

Wait for explicit confirmation. If the user wants to review first, they can cat `.claude/greenfield-state.json` or ask you to show specific fields.

**Stale-awareness on dispatch**: if the developer is resuming to a phase Q that has a different `currentPhase` target (i.e., they are about to re-enter a wizard step that is NOT the stale phase), still mention the stale phase in the summary. Do not reroute the developer away from their resume target — the stale-check entry-guard in `synthesis-review` Step 0 will catch it when Q is actually entered.

---

## Step 4.2: Skip-cascade reversal invariant (Round 3)

When resuming a session, check for cases where a phase was previously skipped via skip-cascade but the cascade's upstream gate has since changed. If detected, prompt the developer to un-skip.

**Detection rules:**

1. **Privacy un-skip when auth.strategy changes:**
   - If `context.phaseStatus.privacy.status === "skipped"` AND `context.phases.auth.strategy !== "none"`:
     - The skip was triggered by `auth.strategy='none'`. The developer has since changed auth strategy.
     - Tell the developer (verbatim):
       > Your Auth strategy has changed from "none" to "{auth.strategy}", which un-skips the Privacy phase. Would you like to walk through Privacy now?
     - If Yes: set `currentStep: "step-6-privacy"`; clear `phaseStatus.privacy.status`; route into Step 6.
     - If No: keep skipped; emit warning that Privacy synthesis remains stub.

2. **Runtime Ops jobs un-skip when apiIntegration.asyncPattern changes:**
   - If `context.phaseStatus.runtimeOperations.jobs` was skipped (Ops.Q1-Q3) AND `context.phases.apiIntegration.asyncPattern !== "none"`:
     - The skip was triggered by `apiIntegration.asyncPattern='none'`. The developer has since added async work.
     - Apply the same un-skip prompt for Step 8 (Runtime Operations), specifically re-walking Ops.Q1-Q3.

3. **Security cannot skip when compliance is non-empty:**
   - If `context.phases.dataArchitecture.compliance` is non-empty AND `context.phaseStatus.security.status === "skipped"`:
     - The skip was previously allowed under hobby/empty-compliance. Compliance scope now non-empty forbids skipping Security.
     - Tell the developer (verbatim):
       > Compliance scope `{compliance}` requires Security to be walked. Skipping is not allowed at this tier.
     - Route into Step 7 unconditionally (no opt-out).

These invariants run at session resume time, before normal mid-step or mid-phase resume logic.

---

## Step 4.5: Granularity prompt (when resuming mid-step)

If the resume point is mid-step rather than at a clean step boundary, ask the developer how they want to re-enter. A mid-step resume is detected when:

- `currentStep` matches a sub-step within a phase (e.g., the wizard was paused at `step-5-cicd-q5-9`, `step-2.5-architectural-framing`, `step-3-data-architecture`, `step-4-api-integration`, or `step-15-arch-validation` rather than at the boundary `step-N-complete`). Also handles step IDs added in Round 2 / 2.5: `step-2.5-architectural-framing`, `step-3-data-architecture`, `step-4-api-integration`, `step-9-residual`, `step-15-arch-validation`. Round 3 adds: `step-5-auth`, `step-6-privacy`, `step-7-security`, `step-8-runtime-ops`.
- `currentPhase === "phase-1.8-synthesis-review"` AND `currentSynthesisPhase` is set AND `context.syntheses[currentSynthesisPhase].adjustments.length < <expected section count>`. Round 2 / 2.5 supports `currentSynthesisPhase` values of `"architecturalFraming"`, `"dataArchitecture"`, `"apiIntegration"`, `"cicdAndDelivery"`, and `"architecturalValidation"`. Round 3 adds `"auth"`, `"privacy"`, `"security"`, `"runtimeOperations"` — e.g., `lastAnsweredQuestionId` may be `"AF.Q2"`, `"P3.Q5"`, `"P4.Q3"`, `"AV.Q1"`, or similar.

In those cases, prompt via `AskUserQuestion`:

```
question: "Where would you like to pick up?"
options:
  - "Continue at the next question (Recommended)" — picks up exactly where the session paused
  - "Restart this step from the beginning" — re-asks everything in the current step;
    captured answers are preserved but the wizard re-walks them so you can confirm
  - "Show me what was captured" — read-only preview of `context` for the current step;
    after preview, the prompt re-appears
```

For mid-synthesis resumes (architecturalFraming, dataArchitecture, apiIntegration, auth, privacy, security, runtimeOperations, cicdAndDelivery, or architecturalValidation), also include:

```
question: "You were in the middle of reviewing the {currentSynthesisPhase} synthesis when this session was interrupted."
options:
  - "Pick up from the last unreviewed section (Recommended)"
  - "Restart this synthesis from Section 1"
  - "Skip the rest and continue to the next wizard step"
```

Default to "continue" if the developer skips. On "restart this step":

- For wizard steps: clear the step's entry from `completedSteps`, reset `currentStep` to the step's first sub-question, KEEP the captured `context` values (the wizard re-walks them as confirmations; the developer can override).
- For synthesis-review (any phase): clear `context.syntheses[currentSynthesisPhase].adjustments`, reset to Section 1 of the synthesis walk.

Checkpoint the cleared/reset state immediately before dispatching, so an abort during the restart leaves a clean resume point.

If the resume point is AT a step boundary (clean `completedSteps` membership for everything prior, ready to start the next step), skip this prompt and proceed directly to Step 5.

## Step 5: Dispatch to the correct skill at the right step

Based on `currentPhase`, load the appropriate skill and fast-forward to `currentStep`.

| currentPhase | Skill to invoke | Notes |
|---|---|---|
| `phase-1-context-gathering` | `context-gathering` skill | Skill's flow section must support entering at any step by checking `completedSteps` |
| `phase-1.8-synthesis-review` | `synthesis-review` skill | Resume the per-phase synthesis walk. Read `currentSynthesisPhase` from state to know which phaseId is in progress (Round 2 / 2.5: `"architecturalFraming"`, `"dataArchitecture"`, `"apiIntegration"`, `"cicdAndDelivery"`, `"architecturalValidation"`; Round 3 adds: `"auth"`, `"privacy"`, `"security"`, `"runtimeOperations"`). Skill re-renders the synthesis HTML if missing, then resumes the Approve/Adjust/Skip walk at the next un-decided section. |
| `phase-1.5-architectural-research` | `context-gathering` skill (new sub-section) | Resume deep-research on `parkedQuestions` |
| `phase-1.7-grill-spec` | `grill-spec` skill | Resume at the partial step within grilling (Step 2 backend-detect, Step 3 inline-walk, Step 4 conflict-resolve, Step 5 re-confirm). |
| `phase-2-scaffold` | `scaffolding` skill | Skill checks which sub-steps are complete (pre-validation, scaffold, git setup, verify) |
| `phase-3a-plugin-discovery` | `plugin-discovery` skill | Resume at catalog-match, user-selection, or install step |
| `phase-3b-tooling-generation` | `tooling-generation` skill | Resume at analysis, onboard-call, or greenfield-specific-artifacts |
| `phase-4-lifecycle-setup` | `lifecycle-setup` skill | Resume at checklist, invocation, or doc-save |

Pass the full `context` object, `researchFindings`, `parkedQuestions`, and `completedSteps` to the skill so it has full context without re-asking questions.

**Critical contract**: every greenfield skill MUST support entering mid-flow. The skill's flow section must start by checking `completedSteps` (if provided) and skipping already-completed steps. Without this contract, resume is broken.

---

## Step 6: Continue normally

From this point on, the flow is identical to `/greenfield:start` starting from the resumed phase. The skill continues writing checkpoints to `greenfield-state.json` after each step, so if this session also gets interrupted, the user can resume again.

At the end of the workflow (all phases complete), set `currentPhase = "complete"` in the state file and proceed to the Handoff summary.

---

## Adjust mode (mid-wizard mode switch)

If the developer wants to change `mode.depth`, `mode.coupling`, or `mode.domainFormat` after the wizard has started, this protocol handles the mid-wizard switch without losing captured answers.

### Entry

Surface via `AskUserQuestion` at the top of `/greenfield:pickup` when state shows `currentPhase === "phase-1-context-gathering"` (any sub-step) OR when state shows a synthesis-review pass mid-Approve-walk. Outside those phases the wizard is past the depth/coupling/format influence horizon and adjustment becomes "Restart from Step N" — not Adjust mode.

```
"What do you want to adjust?"
  • Wizard mode (depth / coupling / domain format)
  • Resume current step  (default — no change)
  • Restart from a specific step
```

If the user picks "Wizard mode", fire a second `AskUserQuestion`:

```
"Which mode field to adjust?"
  • Depth (Heavy ↔ Light)
  • Coupling (Auto-loop ↔ Hybrid)
  • Domain format (Full DDD ↔ DDD-lite)
  • Cancel — no change
```

### Per-field side-effects

For each adjustment, the side-effects are:

**Depth: Light → Heavy**
- Queue every Q in completed phases tagged `showInLight: false` as `status: "pending-light-to-heavy"` in `greenfield-state.json.pendingQs[]`.
- On the developer's next phase advance, the wizard fires these Qs in original Q-bank order before continuing to the next phase.
- Do NOT re-fire Qs that were `showInLight: true` (already answered in Light mode).
- Update `mode.depth = "heavy"`. Audit-log: `{ action: "mode-depth-upgrade", from: "light", to: "heavy", queued: <count> }`.

**Depth: Heavy → Light**
- Existing Heavy-only answers (`showInLight: false`) are PRESERVED in state but flagged `{ "may not appear in synthesis rendering": true }` in the per-phase `phases.<id>` block.
- Synthesis re-render hides those fields (template's `showInLight` guard in T19 sourceRef rendering — same gate applies to plain field renders).
- Do NOT delete answers — only hide. Re-upgrade to Heavy un-hides without re-asking.
- Update `mode.depth = "light"`. Audit-log: `{ action: "mode-depth-downgrade", from: "heavy", to: "light", hidden: <count> }`.

**Coupling: Auto-loop → Hybrid**
- Existing per-persona / per-entity answers from previous auto-loop fires are PRESERVED. They keep their `sourceRef` entries — the synthesis rendering already handles them.
- For all subsequent looped Qs in remaining phases, the runtime applies the new rule: only `loopMode: always` Qs loop; `loopMode: hybrid-only` Qs fire static once with the hybrid-fallback prompt.
- Update `mode.coupling = "hybrid"`. Audit-log: `{ action: "mode-coupling-loosen", from: "auto-loop", to: "hybrid" }`.

**Coupling: Hybrid → Auto-loop**
- Existing static answers for `loopMode: hybrid-only` Qs in completed phases get flagged for re-ask. For each, surface `AskUserQuestion`:
  ```
  "{phaseId}.{Q-ID} was answered statically under Hybrid coupling. Re-ask per persona/entity now?"
    • Yes, re-ask  • Keep static answer  • Skip phase reconciliation
  ```
- "Keep static" propagates as-is (synthesis renders as static; no `sourceRef`).
- "Yes, re-ask" queues per-iteration fires in `pendingQs[]`; user types per-persona/per-entity values on next pickup advance.
- Update `mode.coupling = "auto-loop"`. Audit-log: `{ action: "mode-coupling-tighten", from: "hybrid", to: "auto-loop", restated: <count>, kept_static: <count> }`.

**Domain format: DDD-lite → Full DDD**
- Re-fire Step 2.7 from Q6 onward (Value Objects, Domain Events, Anti-Corruption — the three mode-gated Qs). Q1–Q5 + Q8–Q9 answers preserved.
- Wizard surfaces a one-time prompt: "Round 4 mode-gated Domain Qs (Q6 value objects, Q7 domain events, Q10 anti-corruption) need to be filled in. Continue?" — Yes / Defer (re-flag the phase as `in-progress` and surface next pickup).
- Update `mode.domainFormat = "full-ddd"`. Audit-log: `{ action: "mode-domain-upgrade", from: "ddd-lite", to: "full-ddd" }`.

**Domain format: Full DDD → DDD-lite**
- Existing Full DDD answers for Q6/Q7/Q10 PRESERVED. Flagged `{ "may not appear in synthesis rendering": true }` for those three fields.
- Synthesis re-renders the three sections as `(deferred — DDD-lite mode)` per the T14 template gating.
- Update `mode.domainFormat = "ddd-lite"`. Audit-log: `{ action: "mode-domain-downgrade", from: "full-ddd", to: "ddd-lite", hidden: 3 }`.

### Common post-conditions

- Checkpoint state immediately (atomic `.tmp` + rename).
- Append audit entry to `.claude/greenfield-meta.json.audit[]` with timestamp.
- Surface confirmation echo: "Mode adjusted: depth=<X>, coupling=<Y>, domainFormat=<Z>. <N> Qs queued for re-ask, <M> answers hidden in synthesis. Continuing from <step>."
- If pendingQs[] is non-empty after adjustment, the wizard's next prompt is the first queued Q (not the original currentStep). State machine resumes original step after pending queue drains.

### P10.5 Reject branch — Adjust-mode jump-links

When the wizard reaches Step 19 (Schema & API Draft Review) and the user chooses Reject on SDR.Q3 (DB), SDR.Q5 (API), or SDR.Q7 (Event), the rejected draft came from upstream discovery phases. Surface the appropriate jump-link:

| Rejected | Likely upstream cause | Adjust-mode target |
|---|---|---|
| DB schema | Domain entity shape mismatch, missing PII encryption hints | Step 2.7 (domainModel) and/or Step 6 (privacy) |
| API contract | Endpoint shape, missing auth scope, asyncPattern divergence | Step 4 (apiIntegration) and/or Step 5 (auth) |
| Event schemas | Missing or wrong domainEvents on entities | Step 2.7 (domainModel) |

Prompt:
> The <db|api|event> part of this draft came from your earlier <phase> answers. Re-enter <Step N> via Adjust mode to fix the upstream values? When you return to Step 19, the renderer re-runs from the updated state.

If the user accepts, set `state.adjustModeTarget = "<phase>"` and `state.returnTo = "step-19"`, then transfer control to the relevant `Step X` block in `context-gathering/SKILL.md` running in Adjust mode. After the user re-completes that phase, the wizard returns to Step 19 and re-invokes `${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh` to regenerate the affected draft(s).

---

## Persona/entity post-hoc add detection (Round 4)

Every time `/greenfield:pickup` runs, before resuming the current step, integrity-check the downstream auto-loop answers against the current persona + entity counts.

### Why

A developer might (a) add or remove a persona in Step 2.2 via Adjust mode, or (b) add or remove an entity in Step 2.7. Downstream phases (Step 3 dataArchitecture, Step 4 apiIntegration, Step 5 auth, Step 6 privacy, Step 7 security, Step 8 runtimeOps) that have already auto-looped will now be stale — they iterated over the OLD persona/entity set.

### Algorithm

For each downstream phase D where `phaseStatus[D].status ∈ ("approved", "approved-with-noted-divergences", "in-progress")`:

1. Read `D.metadata.loopedOver` — the array recorded at the time of the phase's loop fire. Each entry: `{ collection: "personas.primary" | "domainModel.entities", iteratedIds: ["P1", "P2", ...] }`.
2. Read current `personas.primary[]` IDs and `domainModel.entities[]` IDs.
3. Compute diff:
   - `addedIds` = current − iterated (new personas/entities added after the phase looped)
   - `removedIds` = iterated − current (personas/entities deleted after the phase looped)
4. If `addedIds` or `removedIds` is non-empty, the phase is **drift-stale**.

### Surface to developer

For each drift-stale phase, surface:

```
"Phase {D} looped over {iterated.length} {collection-noun}, but {current.length} now exist.

  Added since loop:    {addedIds}  ({addedIds.length})
  Removed since loop:  {removedIds}  ({removedIds.length})

What now?
  • Add follow-up Qs for added IDs   — queue per-ID Qs in pendingQs[]; original iterated answers preserved.
  • Detach answers for removed IDs   — strip those entries from phase state; synthesis re-renders without them.
  • Add AND detach (Recommended)     — both above in one step.
  • Defer                             — mark phase {D} stale (synthesis re-renders with "drift notice"); reconcile later."
```

### Side-effects

- **Add follow-up:** for each `addedId`, queue the phase's looped Qs (those with `loopOver: {collection}`) in `pendingQs[]` with iteration context `{ persona|entity: addedId }`. Next pickup advance fires them in order.
- **Detach removed:** delete the per-iteration answers from `phases.<D>` state. Re-write synthesis HTML (preserves Approved status if all other content unchanged; sets `phaseStatus[D].lastModified` to now).
- **Mark stale:** `phaseStatus[D].status = "stale"`, `staleReason = "personas+entities post-hoc adjusted: added=N, removed=M"`. Synthesis-review Step 0 entry-guard catches this on next phase entry.

### Skipping

If `mode.coupling === "hybrid"` AND the phase only has `loopMode: hybrid-only` Qs, no auto-loop happened — skip drift check for that phase.

If `phaseStatus[D].status === "not-yet-walked"`, the phase will fire fresh with current counts; no drift to detect.

---

## Error handling

- **State file not found**: see Step 1 — instruct the user to run `/greenfield:start` or check their directory.
- **State file corrupt**: see Step 2 — offer recovery paths, never auto-delete.
- **Skill fails to resume mid-flow**: if a skill doesn't properly skip completed steps and asks the user something they already answered, apologize and continue; do NOT re-write answers to the state file. Log the issue for future skill improvements.
- **User aborts during resume**: leave the state file as-is. A subsequent `/greenfield:pickup` should work.

---

## Design notes

- **Why a separate skill?** `/greenfield:start` is already long and complex. Resuming is a distinct user intent ("I was already working on this, continue where I left off") that deserves its own entry point.
- **Why not auto-resume in `/greenfield:start`?** `/greenfield:start` DOES check for an existing state file and offers resume — this skill is the direct entry point for users who know they want to resume (faster than going through init's guard checks).
- **Why JSON, not YAML?** The wizard updates state frequently; JSON parse/stringify is universal and fast. YAML adds no value here.
- **Why per-project state?** Greenfield state is tied to a specific scaffold. If you had global state, you couldn't work on two projects concurrently.

## Key Rules

- **Schema version check is a hard gate** — if `schemaVersion` is missing or not `"alpha.5"` after the State migration shim runs, halt immediately with the "restart with `/greenfield:start`" message. Never attempt to parse or resume an incompatible state file. The alpha.4 → alpha.5 migration shim handles the previous version transparently — see § State migration.
- **Never auto-delete the state file** — if the file is corrupt or malformed, offer recovery paths (show contents, delete manually, restore from git). Only the developer may delete it.
- **`completedSteps` is the authoritative skip list** — every dispatched skill MUST check `completedSteps` at entry and skip already-completed steps. Never re-ask a question whose answer is already in `context`; if a skill doesn't honor this, apologize and continue rather than re-writing captured state.
- **Stale phases are surfaced, not auto-resolved** — if any `phaseStatus` entry is `"stale"`, report it in Step 4's summary. Do not reroute the developer away from their intended resume target; the stale entry-guard in `synthesis-review` Step 0 handles re-walk when the phase is actually entered.
- **Explicit confirmation before dispatch** — always wait for the developer's "yes/continue" in Step 4 before calling any downstream skill. Do not auto-proceed after rendering the resume summary.
