---
name: grill-spec
description: Forge Phase 1.7 — pre-scaffold validation gate. Walks every spec decision branch and resolves contradictions before any scaffold runs. Internal building block invoked by forge init.
user-invocable: false
---

# Grill Spec Skill — Pre-Scaffold Validation Gate

You are running Forge's pre-scaffold validation gate. This is Phase 1.7 — it sits between context-gathering (Phase 1, optionally 1.5) and scaffolding (Phase 2). The gate exists because once Phase 2 starts writing files, undoing a wrong stack or feature decision is expensive. Five minutes of grilling here saves an afternoon of re-scaffolding later.

## Guard

Read `.claude/forge-state.json`. The skill MUST refuse to run if any of these hold:

- File missing → tell the developer to start with `/forge:init`, do not proceed.
- `currentPhase` is not in `{"phase-1-context-gathering", "phase-1.5-architectural-research"}` and `completedSteps` does not yet contain `"step-7-confirmation"` → the wizard hasn't finished. Refuse and direct them to complete Phase 1.
- `completedSteps` already contains `"phase-1.7-grill-spec"` or `"phase-1.7-grill-spec-skipped"` → the gate has already run. Skip silently and return control to `forge:init`.

If `wantsValidationGate` is `false` in the gathered context AND `isProduction` is `false`, write `"phase-1.7-grill-spec-skipped"` to `completedSteps`, set `currentPhase: "phase-2-scaffold"`, and return immediately. Don't ask the user — they signalled "no gate" already.

## Overview

> **Phase 1.7: Pre-scaffold validation**
>
> Before I scaffold, I'll walk through your spec one more time and surface any contradictions, scope risks, or missing pieces. This typically takes 3–5 minutes. You can skip if you're confident the spec is solid.

## Step 1: Preview the spec

Read the gathered context from `forge-state.json.context`. Compose a one-line summary:

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

## Step 2: Detect grilling backend

The grilling can run via the external `mattpocock-skills:grill-me` skill (full version) or fall back to an inline minimal pattern. Both produce the same hardened spec.

Try invoking `mattpocock-skills:grill-me` via the Skill tool with the gathered context as input. Wrap the call in error handling:

- If the Skill tool returns successfully: the external skill runs the full grill, then yields back. Skip Step 3 and continue to Step 4.
- If the Skill tool errors (skill not installed / different slash form / call failure): log a one-line note to the user — *"Using built-in grill (recommend installing `mattpocock-skills` for the full version)"* — then load `references/inline-grill-fallback.md` and follow it through Step 3.

Never crash the forge run if the external skill is unavailable — the inline fallback is the floor.

## Step 3: Walk the decision tree (inline path only)

If running the inline fallback, load `references/spec-decision-tree.md` and iterate the categories listed there:

1. **Scope** — are these features the right MVP for sprint 1?
2. **Stack alignment** — does the chosen stack actually solve the user's problem?
3. **Feature conflicts** — do any two features contradict each other?
4. **Missing dependencies** — are there obvious gaps (e.g., auth without password reset)?
5. **Security/compliance** — does the deploy target match the security sensitivity?

For each category, read the relevant spec slice from `forge-state.json.context`, ask the developer one focused question, capture the answer, and apply any spec changes back.

**One question per message** (mirrors `context-gathering` discipline).

Skip categories whose preconditions don't apply. For example, "auth gaps" is silent for a CLI tool with `auth.strategy === null`. Use the AskUserQuestion single-option guard when a category has only one applicable sub-question.

## Step 4: Conflict resolution

After grilling completes (either path), scan the new context against the original. If any answer contradicts a Phase-1 wizard answer, surface the conflict explicitly:

> **Conflict detected**: Phase 1 said `auth.strategy = "none"` but Step 3 of grilling identified that feature `password-reset` requires authentication.
>
> 1. Add auth (recommend) — update `auth.strategy` to a default for the stack
> 2. Drop the feature — remove `password-reset` from feature decomposition
> 3. Re-research — return to Phase 1.5 to think this through more carefully

Never silently apply a contradicting change. Always force the developer to resolve.

If a conflict involves a stack-level choice (framework, language, runtime), and the user picks "Re-research", set `currentPhase: "phase-1.5-architectural-research"` and add the conflict to `parkedQuestions[]` so context-gathering's Step 8 picks it up.

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

Write to `.claude/forge-state.json` atomically (`.tmp` then rename):

- Append `"phase-1.7-grill-spec"` to `completedSteps`
- Set `currentPhase: "phase-2-scaffold"`
- Update `currentStep: "pre-validation"` (handoff to scaffolding skill)
- Update `context` with all hardened fields
- Bump `updatedAt`

If the user skipped at any point, append `"phase-1.7-grill-spec-skipped"` instead. Both forms are recognised by `forge:resume`.

## Key Rules

1. **One question per message** — don't overwhelm.
2. **External-skill failure is non-fatal** — always have the inline fallback ready.
3. **Never silently apply contradicting changes** — Step 4 conflict resolution is mandatory.
4. **Skip path is first-class** — `"phase-1.7-grill-spec-skipped"` is a real state, not an error.
5. **Single-option AskUserQuestion lists** — apply the guard from `.claude/rules/ask-user-question-guard.md`. For dynamic option lists (Step 3 categories), check `len(options) >= 2` before invoking; convert to yes/no single-select otherwise.
6. **Atomic writes only** — `.tmp` then rename; never write `forge-state.json` directly.
7. **Timebox** — 5 minutes default. If grilling exceeds 10 minutes without convergence, surface an "extend or finish" prompt.
8. **Resume-aware** — Guard rejects re-entry if Phase 1.7 already completed; `forge:resume` picks up at the partial step otherwise.
