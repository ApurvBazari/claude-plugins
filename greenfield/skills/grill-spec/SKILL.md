---
name: grill-spec
description: Greenfield Phase 1.7 — pre-scaffold validation gate. Walks every spec decision branch and resolves contradictions before any scaffold runs. Internal building block invoked by greenfield init.
user-invocable: false
---

# Grill Spec Skill — Pre-Scaffold Validation Gate

You are running Greenfield's pre-scaffold validation gate. This is Phase 1.7 — it sits between context-gathering (Phase 1, optionally 1.5) and scaffolding (Phase 2). The gate exists because once Phase 2 starts writing files, undoing a wrong stack or feature decision is expensive. Five minutes of grilling here saves an afternoon of re-scaffolding later.

## Guard

Read `.claude/greenfield-state.json`. The skill MUST refuse to run if any of these hold:

- File missing → tell the developer to start with `/greenfield:start`, do not proceed.
- `currentPhase` is not in `{"phase-1-context-gathering", "phase-1.5-architectural-research"}` and `completedSteps` does not yet contain `"step-9-confirmation"` → the wizard hasn't finished. Refuse and direct them to complete Phase 1.
- `completedSteps` already contains `"phase-1.7-grill-spec"` or `"phase-1.7-grill-spec-skipped"` → the gate has already run. Skip silently and return control to `greenfield:start`.

If `wantsValidationGate` is `false` in the gathered context AND `isProduction` is `false`, write `"phase-1.7-grill-spec-skipped"` to `completedSteps`, set `currentPhase: "phase-2-scaffold"`, and return immediately. Don't ask the user — they signalled "no gate" already.

## Overview

> **Phase 1.7: Pre-scaffold validation**
>
> Before I scaffold, I'll walk through your spec one more time and surface any contradictions, scope risks, or missing pieces. This typically takes 3–5 minutes. You can skip if you're confident the spec is solid.

## Step 1: Preview the spec

Read the gathered context from `greenfield-state.json.context`. Compose a one-line summary:

> **Spec preview**: [appType] · [stack.framework]@[stack.version] · DB: [database.type or "none"] · Auth: [auth.strategy or "none"] · Deploy: [deployTarget] · Features: [N] across [M] sprints

Then ask via `AskUserQuestion` (single-select, NOT multiSelect — only one outcome):

```
question: "Run pre-scaffold validation? (~5 min)"
options:
  - "Yes, grill me (Recommended)" — Walks every decision branch and surfaces contradictions before scaffolding
  - "Skip — spec is solid" — Marks Phase 1.7 as skipped and proceeds straight to Phase 2
```

Apply the AskUserQuestion single-option guard from `.claude/rules/ask-user-question-guard.md`: this list always has 2 options so no padding is needed.

If the user picks "Skip", write `"phase-1.7-grill-spec-skipped"` to `completedSteps`, set `currentPhase: "phase-2-scaffold"`, atomic write, return.

## Step 2: Run the grilling walk

The grilling runs via the greenfield-owned `greenfield/skills/adjust-dialog/` skill (5-category adversarial walk: Scope, Assumptions, Alternatives, Risks, Dependencies). Invoke it via the Skill tool with the gathered context as input.

- If the Skill tool returns successfully: the dialog runs all 5 categories, then yields back. Skip Step 3 and continue to Step 4.
- If the Skill tool errors (skill not yet installed in this session / call failure): log a one-line note to the user — *"Using built-in grill (adjust-dialog skill unavailable)"* — then load `references/inline-grill-fallback.md` and follow it through Step 3.

Never crash the greenfield run if the skill is unavailable — the inline fallback is the floor.

## Step 3: Walk the decision tree (inline path only)

If running the inline fallback, load `references/spec-decision-tree.md` and iterate the categories listed there:

1. **Scope** — are these features the right MVP for sprint 1?
2. **Stack alignment** — does the chosen stack actually solve the user's problem?
3. **Feature conflicts** — do any two features contradict each other?
4. **Missing dependencies** — are there obvious gaps (e.g., auth without password reset)?
5. **Security/compliance** — does the deploy target match the security sensitivity?

For each category, read the relevant spec slice from `greenfield-state.json.context`, ask the developer one focused question, capture the answer, and apply any spec changes back.

**One question per message** (mirrors `context-gathering` discipline).

Skip categories whose preconditions don't apply. For example, "auth gaps" is silent for a CLI tool with `auth.strategy === null`. Use the AskUserQuestion single-option guard when a category has only one applicable sub-question.

## Step 4: Conflict resolution

After grilling completes (either path), scan the new context against the original AND against every per-phase synthesis record present in `context.syntheses` — iterate dynamically over all keys (Round 2 / 2.5 ships architecturalFraming, dataArchitecture, apiIntegration, cicdAndDelivery, and architecturalValidation; future rounds will add more). If any answer contradicts a Phase-1 wizard answer or an approved synthesis section, surface the conflict explicitly.

**Note on architecturalValidation**: when `context.syntheses.architecturalValidation` is present, grill-spec should read its `signOffStatus`. If `signOffStatus === "requires-rework"`, refuse to proceed to Phase 2 and route back to the relevant wizard step. If `signOffStatus === "approved-with-noted-divergences"`, surface the `divergences[]` list as a pre-scaffold awareness note (non-blocking).

**Architectural Framing cross-checks** (run whenever `context.syntheses.architecturalFraming` is present):
- If grilling changes `auth.strategy` from `"none"` to any value AND `architecturalFraming.topology === "serverless"`: note that serverless functions often use JWT/JWKS rather than session-based auth — verify the auth strategy is compatible with stateless function invocations.
- If grilling reveals `boundaryNotes` contains isolation language AND `architecturalFraming.topology === "monolith"`: surface the Architectural Framing contradiction check (§ Step 2.5 isolation-without-microservices rule) and route to Phase 1.5 if the user wants to revisit topology.
- If grilling changes any stack-level decision that affects topology (e.g., moving from a monorepo to microservices, adding a queue broker): flag that `architecturalFraming.topology` may need to be re-reviewed and offer to route back to Step 2.5.

> **Conflict detected**: Phase 1 said `auth.strategy = "none"` but Step 3 of grilling identified that feature `password-reset` requires authentication.
>
> 1. Add auth (recommend) — update `auth.strategy` to a default for the stack
> 2. Drop the feature — remove `password-reset` from feature decomposition
> 3. Re-research — return to Phase 1.5 to think this through more carefully

Never silently apply a contradicting change. Always force the developer to resolve.

If a conflict involves a stack-level choice (framework, language, runtime), and the user picks "Re-research", set `currentPhase: "phase-1.5-architectural-research"` and add the conflict to `parkedQuestions[]` so context-gathering's Step 8 picks it up.

## Round 3 cross-phase consistency checks

After Steps 5–8 complete and before scaffold begins, validate these invariants. If any fail, present the contradiction to the developer and offer Adjust loop. Each check uses the topic-name field paths from the v2 context shape.

### CHECK-R3-1: Compliance scope coverage
`dataArchitecture.compliance ⊆ privacy.regulations` — every entry in `context.phases.dataArchitecture.compliance` must appear in `context.phases.privacy.regulations`.

> **Violation message:** "Data Architecture declared compliance scope `{missingEntries}`, but Privacy regulations does not include them. Either extend privacy.regulations or remove from dataArchitecture.compliance."

### CHECK-R3-2: Auth required for sensitive compliance
If `context.phases.dataArchitecture.compliance` contains any of `["HIPAA", "PCI-DSS", "SOC 2"]`, then `context.phases.auth.strategy` MUST NOT be `"none"`.

> **Violation message:** "HIPAA/PCI/SOC2 compliance requires user authentication. The current auth.strategy='none' is incompatible. Choose an auth strategy or remove the compliance scope."

### CHECK-R3-3: Security tier matches compliance
If `context.phases.dataArchitecture.compliance` is non-empty, then `context.phases.security.sensitivityTier` MUST be `"elevated"` or `"high"`.

> **Violation message:** "Compliance scope `{compliance}` requires sensitivity tier 'elevated' or 'high'. Current tier='standard'."

### CHECK-R3-4: Alerting required for high sensitivity
If `context.phases.security.sensitivityTier === "high"`, then `context.phases.runtimeOperations.alerting.tool` MUST NOT be `"none"` (or undefined).

> **Violation message:** "High sensitivity tier requires non-trivial alerting (PagerDuty, OpsGenie, or webhook). Current alerting.tool='none'."

---

These 4 checks are evaluated alongside the existing grill-spec pass. They surface as Adjust prompts during the pre-scaffold validation gate.

## Round 4 invariants (CHECK-R4-*)

Run after Step 15.2 (cross-phase invariant check). See `references/check-r4-invariants.md` for full predicate definitions, source phases, and fail messages.

| ID | Severity | Phase deps |
|---|---|---|
| CHECK-R4-1 | hard-fail | personas |
| CHECK-R4-2 | hard-fail | domainModel + dataArchitecture |
| CHECK-R4-3 | hard-fail | personas + auto-loop downstream phases |
| CHECK-R4-4 | hard-fail | risks (any) + architecturalValidation |
| CHECK-R4-5 | warn | domainModel + auth |
| CHECK-R4-6 | warn | domainModel |
| CHECK-R4-7 | warn | personas |
| CHECK-R4-8 | suggestion | mode (any) |

If any **hard-fail** invariant fails, block Step 15.3 final sign-off. User must either fix the cause (preferred — fix Q-bank answer, re-run the affected phase) or explicitly override with `--force` (logged to `greenfield-meta.json.audit[]` with reason).

**Warn** invariants surface in the validation report but do not block. **Suggestion** invariants surface as informational notes only.

## Round 5 invariants (CHECK-R5-*)

Run after the Round 4 pass when `context.phases.featureRoadmap` and/or `context.phases.schemaDraftReview` are present. See `references/check-r5-invariants.md` for full predicate definitions, source phases, and fail messages. CHECK-R5-1 / CHECK-R5-2 / CHECK-R5-6 belong to the **roadmap-integrity** category; CHECK-R5-3 / CHECK-R5-4 / CHECK-R5-5 belong to the **schema-coherence** category of the adversarial walk.

| ID | Severity | Phase deps |
|---|---|---|
| CHECK-R5-1 | error | featureRoadmap + personas + domainModel + risks |
| CHECK-R5-2 | error | featureRoadmap (intra-phase) |
| CHECK-R5-3 | warn | schemaDraftReview + dataArchitecture + apiIntegration + domainModel |
| CHECK-R5-4 | error | schemaDraftReview (intra-phase) |
| CHECK-R5-5 | warn | featureRoadmap (intra-phase) |
| CHECK-R5-6 | warn | featureRoadmap (intra-phase) |

If any **error** invariant fails, block scaffold. User must either fix the cause (fix Q-bank answer, re-run the affected phase) or explicitly override with `--force` (logged to `greenfield-meta.json.audit[]` with reason). **Warn** invariants surface in the validation report but do not block.

## References

- **Round 3 invariants:** inlined above (CHECK-R3-1 through CHECK-R3-4) — compliance × privacy × auth × security × runtimeOperations cross-checks.
- **Round 4 invariants:** `references/check-r4-invariants.md` — CHECK-R4-1 through CHECK-R4-8 covering personas + domainModel + risk reconciliation cross-phase consistency.
- **Round 5 invariants:** `references/check-r5-invariants.md` — CHECK-R5-1 through CHECK-R5-6 covering featureRoadmap + schemaDraftReview cross-phase consistency.

## Step 5: Re-confirmation

Present a diff of changed spec fields:

> **Spec changes from grilling**:
> - `auth.strategy`: `null` → `"jwt"`
> - `featureDecomposition.sprints[0].features`: added `password-reset`
> - `wantsValidationGate`: confirmed
>
> Ready to scaffold?

Wait for explicit confirmation before continuing.

## Step 6: Checkpoint

Write to `.claude/greenfield-state.json` atomically (`.tmp` then rename):

- Append `"phase-1.7-grill-spec"` to `completedSteps`
- Set `currentPhase: "phase-2-scaffold"`
- Update `currentStep: "pre-validation"` (handoff to scaffolding skill)
- Update `context` with all hardened fields
- Bump `updatedAt`

If the user skipped at any point, append `"phase-1.7-grill-spec-skipped"` instead. Both forms are recognised by `greenfield:pickup`.

## Key Rules

1. **One question per message** — don't overwhelm.
2. **External-skill failure is non-fatal** — always have the inline fallback ready.
3. **Never silently apply contradicting changes** — Step 4 conflict resolution is mandatory.
4. **Skip path is first-class** — `"phase-1.7-grill-spec-skipped"` is a real state, not an error.
5. **Single-option AskUserQuestion lists** — apply the guard from `.claude/rules/ask-user-question-guard.md`. For dynamic option lists (Step 3 categories), check `len(options) >= 2` before invoking; convert to yes/no single-select otherwise.
6. **Atomic writes only** — `.tmp` then rename; never write `greenfield-state.json` directly.
7. **Timebox** — 5 minutes default. If grilling exceeds 10 minutes without convergence, surface an "extend or finish" prompt.
8. **Resume-aware** — Guard rejects re-entry if Phase 1.7 already completed; `greenfield:pickup` picks up at the partial step otherwise.
