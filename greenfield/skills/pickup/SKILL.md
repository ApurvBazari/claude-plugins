---
name: pickup
description: Resume an in-progress greenfield session from the last checkpoint in .claude/greenfield-state.json. Use when user wants to continue a paused /greenfield:start run, asks about resuming greenfield, mentions a session was interrupted, or opens a fresh Claude Code conversation in a project that has a greenfield session in flight.
---

# Pickup Skill — Resume an In-Progress Greenfield Session

You are resuming an in-progress Greenfield workflow that was paused mid-flight. Greenfield persists its state to `.claude/greenfield-state.json` at every checkpoint, so you can pick up exactly where the previous session left off — even in a completely fresh Claude Code conversation.

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

**Expected schema version**: `1`

**If `schemaVersion` is missing or does not equal `1`**:

> ⚠️  This wizard session was saved by a different greenfield version.
>
> Detected schemaVersion: [actual value or "missing"] | Expected: 1
>
> During alpha (3.0.0-alpha.X), schema changes are not migrated.
>
> **Restart with `/greenfield:start`**
>
> See `greenfield/skills/start/references/state-schema-evolution.md` for the policy.

Stop. Do not proceed to Step 2. The user must start a fresh session.

**If `schemaVersion === 1`**: proceed to Step 2.

---

## Step 2: Parse and validate state

Read `.claude/greenfield-state.json`. Expected schema:

```json
{
  "schemaVersion": 1,
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
- `schemaVersion` field exists and equals `1` (handled by Step 1.5, but double-check here for safety)
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

- **Schema version check is a hard gate** — if `schemaVersion` is missing or not `1`, halt immediately with the "restart with `/greenfield:start`" message. Never attempt to parse or resume an incompatible state file.
- **Never auto-delete the state file** — if the file is corrupt or malformed, offer recovery paths (show contents, delete manually, restore from git). Only the developer may delete it.
- **`completedSteps` is the authoritative skip list** — every dispatched skill MUST check `completedSteps` at entry and skip already-completed steps. Never re-ask a question whose answer is already in `context`; if a skill doesn't honor this, apologize and continue rather than re-writing captured state.
- **Stale phases are surfaced, not auto-resolved** — if any `phaseStatus` entry is `"stale"`, report it in Step 4's summary. Do not reroute the developer away from their intended resume target; the stale entry-guard in `synthesis-review` Step 0 handles re-walk when the phase is actually entered.
- **Explicit confirmation before dispatch** — always wait for the developer's "yes/continue" in Step 4 before calling any downstream skill. Do not auto-proceed after rendering the resume summary.
