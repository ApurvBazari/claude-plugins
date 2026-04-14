---
name: resume
description: Resume an in-progress forge session from the last checkpoint in .claude/forge-state.json. Use when user wants to continue a paused /forge:init run, asks about resuming forge, mentions a session was interrupted, or opens a fresh Claude Code conversation in a project that has a forge session in flight.
---

# Resume Skill — Resume an In-Progress Forge Session

You are resuming an in-progress Forge workflow that was paused mid-flight. Forge persists its state to `.claude/forge-state.json` at every checkpoint, so you can pick up exactly where the previous session left off — even in a completely fresh Claude Code conversation.

---

## Step 1: Locate the state file

Check for `.claude/forge-state.json` in the current working directory.

**If not found**:

> No in-progress Forge session found in this directory.
>
> - If this is a new project → run `/forge:init` to start.
> - If you expected a session to be in progress here → you may be in the wrong directory. Forge state is project-local; `cd` into the project that was in progress.

Stop.

**If found**: proceed to Step 2.

---

## Step 2: Parse and validate state

Read `.claude/forge-state.json`. Expected schema:

```json
{
  "version": 1,
  "createdAt": "ISO-8601 timestamp",
  "updatedAt": "ISO-8601 timestamp",
  "currentPhase": "phase-1-context-gathering | phase-1.5-architectural-research | phase-2-scaffold | phase-3a-plugin-discovery | phase-3b-tooling-generation | phase-4-lifecycle-setup | complete",
  "currentStep": "step-identifier (skill-specific)",
  "completedSteps": ["list of completed step identifiers"],
  "context": { /* partial context object, grows as wizard progresses */ },
  "researchFindings": { /* stack research results, if gathered */ },
  "parkedQuestions": [ /* deferred deep-research items */ ],
  "nextAction": "human-readable description of what happens next",
  "research": {
    "mode": "agent | main-session | training-data-only"
  }
}
```

Validate:
- `version` field exists and equals `1` (future versions will need migration logic)
- `currentPhase` is one of the known phases
- `context` is a valid object (even if partial)

**If the file is corrupt or missing required fields**:

> Found `.claude/forge-state.json` but it's malformed: [specific error].
>
> Options:
> 1. Show me the raw file contents so we can recover together
> 2. Delete it and start fresh with `/forge:init`
> 3. Restore from git history if the file is tracked

Ask the user. Do not auto-delete.

---

## Step 3: Check for terminal state

**If `currentPhase === "complete"`**:

> This Forge session already completed on [updatedAt]. Running `/forge:resume` does nothing — there's nothing to resume.
>
> Use `/forge:status` to inspect the completed project, or start a new project in a different directory with `/forge:init`.

Stop.

---

## Step 4: Present the resume summary

Show the user what will happen:

> **Resuming Forge session**
>
> **Project**: [context.appDescription or "unnamed project"]
> **Started**: [createdAt]
> **Last updated**: [updatedAt] ([time delta, e.g., "2 hours ago"])
>
> **Progress so far**:
> - ✅ [completedSteps rendered as a checklist with friendly names]
>
> **Next action**:
> [nextAction from state file, e.g., "Continue Phase 1 Step 3 — Project Details (Q3.4: deploy target)"]
>
> **Research mode**: [research.mode, e.g., "main-session (user approves each web call)"]
>
> Ready to continue? (yes/no)

Wait for explicit confirmation. If the user wants to review first, they can cat `.claude/forge-state.json` or ask you to show specific fields.

---

## Step 5: Dispatch to the correct skill at the right step

Based on `currentPhase`, load the appropriate skill and fast-forward to `currentStep`.

| currentPhase | Skill to invoke | Notes |
|---|---|---|
| `phase-1-context-gathering` | `context-gathering` skill | Skill's flow section must support entering at any step by checking `completedSteps` |
| `phase-1.5-architectural-research` | `context-gathering` skill (new sub-section) | Resume deep-research on `parkedQuestions` |
| `phase-2-scaffold` | `scaffolding` skill | Skill checks which sub-steps are complete (pre-validation, scaffold, git setup, verify) |
| `phase-3a-plugin-discovery` | `plugin-discovery` skill | Resume at catalog-match, user-selection, or install step |
| `phase-3b-tooling-generation` | `tooling-generation` skill | Resume at analysis, onboard-call, or forge-specific-artifacts |
| `phase-4-lifecycle-setup` | `lifecycle-setup` skill | Resume at checklist, invocation, or doc-save |

Pass the full `context` object, `researchFindings`, `parkedQuestions`, and `completedSteps` to the skill so it has full context without re-asking questions.

**Critical contract**: every forge skill MUST support entering mid-flow. The skill's flow section must start by checking `completedSteps` (if provided) and skipping already-completed steps. Without this contract, resume is broken.

---

## Step 6: Continue normally

From this point on, the flow is identical to `/forge:init` starting from the resumed phase. The skill continues writing checkpoints to `forge-state.json` after each step, so if this session also gets interrupted, the user can resume again.

At the end of the workflow (all phases complete), set `currentPhase = "complete"` in the state file and proceed to the Handoff summary.

---

## Error handling

- **State file not found**: see Step 1 — instruct the user to run `/forge:init` or check their directory.
- **State file corrupt**: see Step 2 — offer recovery paths, never auto-delete.
- **Skill fails to resume mid-flow**: if a skill doesn't properly skip completed steps and asks the user something they already answered, apologize and continue; do NOT re-write answers to the state file. Log the issue for future skill improvements.
- **User aborts during resume**: leave the state file as-is. A subsequent `/forge:resume` should work.

---

## Design notes

- **Why a separate skill?** `/forge:init` is already long and complex. Resuming is a distinct user intent ("I was already working on this, continue where I left off") that deserves its own entry point.
- **Why not auto-resume in `/forge:init`?** `/forge:init` DOES check for an existing state file and offers resume — this skill is the direct entry point for users who know they want to resume (faster than going through init's guard checks).
- **Why JSON, not YAML?** The wizard updates state frequently; JSON parse/stringify is universal and fast. YAML adds no value here.
- **Why per-project state?** Forge state is tied to a specific scaffold. If you had global state, you couldn't work on two projects concurrently.
