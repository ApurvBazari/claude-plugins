---
name: adjust-dialog
description: Greenfield-internal adversarial walk for synthesis-review Adjust path. 5-category structured probe (Scope, Assumptions, Alternatives, Risks, Dependencies). Invoked when a developer picks "Adjust" on a synthesis section. Not user-invocable.
user-invocable: false
---

# Adjust Dialog Skill — Adversarial Walk for Synthesis Adjustments

You are running the adjust-dialog skill, a greenfield-internal structured probe that deepens developer thinking before a synthesis adjustment is committed. It runs five adversarial categories in sequence — Scope, Assumptions, Alternatives, Risks, Dependencies — and returns a final adjusted value plus a decision record.

## Guard

This skill requires five inputs from the caller. Halt immediately if any are missing:

- `phaseId` — the current phase being reviewed (e.g., `"dataArchitecture"`)
- `sectionId` — the specific section within the phase being adjusted (e.g., `"databaseHost"`)
- `originalValue` — the value currently captured before adjustment
- `adjustmentIntent` — the developer's stated reason for wanting to adjust
- `listedPhases` — array of all phase IDs present in `context.phases` (for cross-phase dependency checks)

If any are missing, halt with:

> `adjust-dialog` called with missing inputs. Required: `phaseId`, `sectionId`, `originalValue`, `adjustmentIntent`, `listedPhases`. Do NOT invoke this skill standalone — it is driven by `synthesis-review` or `grill-spec`.

## Overview

The adjust-dialog walk produces three things:

1. A proposed `adjustedValue` built from the developer's responses across all five categories
2. A `decision` record (`"adjusted"` | `"adjusted-then-reverted"` | `"adjusted-with-noted-divergence"`)
3. A `categoryFindings` array capturing each category's probe, response, and conclusion

The walk is advisory — it does NOT write to context. The caller (synthesis-review or grill-spec) owns state. This skill returns a structured result and hands back control.

Return format:

```json
{
  "adjustedValue": "<final value, string or object>",
  "decision": "adjusted",
  "via": "adjust-dialog",
  "diff": { "before": "<originalValue>", "after": "<adjustedValue>", "field": "<sectionId>" },
  "categoryFindings": [
    { "category": "Scope", "probe": "<question asked>", "response": "<developer answer>", "conclusion": "<one-line summary>" },
    { "category": "Assumptions", "probe": "...", "response": "...", "conclusion": "..." },
    { "category": "Alternatives", "probe": "...", "response": "...", "conclusion": "..." },
    { "category": "Risks", "probe": "...", "response": "...", "conclusion": "..." },
    { "category": "Dependencies", "probe": "...", "response": "...", "conclusion": "..." }
  ]
}
```

## Step 1: Load the category probe banks

Read all five probe bank references:

- `references/scope-questions.md`
- `references/assumptions-questions.md`
- `references/alternatives-questions.md`
- `references/risks-questions.md`
- `references/dependencies-questions.md`

Also read `references/dialog-protocol.md` for the orchestration contract, composition guidance, and loop-guard rules.

## Step 2: Compose the dialog

Before asking anything, determine which probes to use for this specific call:

1. For each of the five categories, select 1-3 probes from the probe bank. Selection criteria:
   - **High-stakes decisions** (framework choice, database engine, auth strategy, deployment architecture) → pick 2-3 probes per category
   - **Low-stakes or narrow decisions** (a config value, a naming choice, a secondary tool) → pick 1 probe per category
   - **Developer expressed clear intent** in `adjustmentIntent` → skip probes whose territory is already covered by the stated intent; pick probes that challenge the intent from a different angle

2. The probe banks provide sample questions and trigger conditions. Use them as guidance, not rote scripts. Adapt phrasing to fit `phaseId`, `sectionId`, and `originalValue` — make it feel like a conversation, not a form.

3. Never ask a probe that is nonsensical given the `originalValue`. (E.g., skip "What made Drizzle less attractive?" if the original value is a numeric threshold, not an ORM choice.)

## Step 3: Walk the developer through each category

Run categories in order: Scope → Assumptions → Alternatives → Risks → Dependencies.

For each category:

1. Present the category name and one sentence on why it matters for this particular adjustment. For example: "**Scope** — let's check the blast radius of this change before we commit to it."
2. Ask the selected probe(s) via `AskUserQuestion`. One probe per turn — do not batch multiple probes into one question.
3. Capture the developer's response.
4. Based on the response, compose a one-line `conclusion` for this category. The conclusion is not evaluative — it's a factual summary of what the developer said.
5. If the response reveals a concern that warrants a follow-up within the same category, ask one follow-up. Maximum one follow-up per category — do not drill infinitely.

After all five categories, briefly summarize what emerged:

> **Walk complete.** Here's what came out of the five categories:
>
> - Scope: [conclusion]
> - Assumptions: [conclusion]
> - Alternatives: [conclusion]
> - Risks: [conclusion]
> - Dependencies: [conclusion]

## Step 4: Synthesize the adjusted answer

Based on the five-category walk, propose an adjusted value. Derive it from the developer's stated intent and responses — do not invent a value they didn't signal.

Present the proposal:

> Based on this walk, the adjusted value for `{sectionId}` is: **{proposed_adjusted_value}**
>
> Original was: `{originalValue}` · Adjustment intent was: "{adjustmentIntent}"
>
> Does this land? (**Take it** / **Refine further** / **Revert to original**)

Use `AskUserQuestion` with three options.

- **Take it** → `decision: "adjusted"`, `adjustedValue = proposed_adjusted_value`. Continue to Step 5.
- **Refine further** → return to Step 3 (re-enter the most relevant category — usually Assumptions or Scope). Maximum one re-entry per category per session. See loop guards in `dialog-protocol.md`.
- **Revert to original** → `decision: "adjusted-then-reverted"`, `adjustedValue = originalValue`. Continue to Step 5.

If the developer takes the value but notes a reservation (e.g., "take it, but the risk with RLS concerns me"), capture that as `decision: "adjusted-with-noted-divergence"` with the reservation text appended to the Risks conclusion.

## Step 5: Record and return

Compose the final return value:

```json
{
  "adjustedValue": "<final value>",
  "decision": "<adjusted | adjusted-then-reverted | adjusted-with-noted-divergence>",
  "via": "adjust-dialog",
  "diff": {
    "before": "<originalValue>",
    "after": "<adjustedValue>",
    "field": "<sectionId>"
  },
  "categoryFindings": [
    { "category": "Scope", "probe": "<question asked>", "response": "<summary>", "conclusion": "<one-line>" },
    { "category": "Assumptions", "probe": "...", "response": "...", "conclusion": "..." },
    { "category": "Alternatives", "probe": "...", "response": "...", "conclusion": "..." },
    { "category": "Risks", "probe": "...", "response": "...", "conclusion": "..." },
    { "category": "Dependencies", "probe": "...", "response": "...", "conclusion": "..." }
  ]
}
```

If `decision === "adjusted-then-reverted"`, set `diff.after = originalValue` (no actual change).

Return this object to the caller. The caller (synthesis-review or grill-spec) owns all state writes.

## Key Rules

1. **Never auto-adjust** — always return to the developer with a proposed value and require explicit confirmation. Never silently accept or apply the walk's findings without the developer's sign-off at Step 4.
2. **Caller owns state** — this skill returns a value and record. It does NOT write to `context.phases`, `greenfield-state.json`, or any synthesis HTML. That is the caller's responsibility.
3. **Preserve developer veto** — if the developer chooses "Revert to original", return `adjustedValue = originalValue` and `decision: "adjusted-then-reverted"`. Never overwrite the original silently.
4. **Field-level diff capture is mandatory** — every return value must include `diff: { before, after, field }`. If the value didn't change, `after === before`. This feeds PRE-5 stale-flag propagation.
5. **Loop guards apply** — never re-enter the same category more than once per session. If refinement loops exceed one re-entry, surface an "extend or finish" choice. See `dialog-protocol.md § Loop guards`.
6. **Probe selection is judgment, not rote** — the probe banks are guidance. Adapt, shorten, or skip a probe if it doesn't fit the specific `sectionId` + `originalValue` combination.
7. **One question per turn** — mirrors the context-gathering discipline. Never ask multiple probes in one message.
8. **Not user-invocable** — if invoked outside of the Skill tool (e.g., typed directly), halt with the Guard error above.
