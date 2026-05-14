# Dialog Protocol — Adjust Dialog Orchestration Contract

This document is the orchestration contract for the `adjust-dialog` skill. It defines the precise input/output shape, decision and via enums, field-level diff schema, composition guidance, and loop guards. Callers (`synthesis-review`, `grill-spec`) must read this before invoking.

## Invocation

Invoke via the Skill tool as `greenfield/skills/adjust-dialog/`.

### Required inputs (all five must be present)

| Field | Type | Description |
|---|---|---|
| `phaseId` | string | Phase being reviewed. E.g., `"dataArchitecture"`, `"cicdAndDelivery"` |
| `sectionId` | string | The specific section or field being adjusted. E.g., `"databaseHost"`, `"migrationsTool"` |
| `originalValue` | string or object | The value currently captured in `context.phases[phaseId]` before adjustment |
| `adjustmentIntent` | string | The developer's stated reason for wanting to adjust, as captured by the Approve/Adjust/Skip walk |
| `listedPhases` | string[] | All phase IDs present in `context.phases`. Used for cross-phase dependency checks in Category 5 |

If any field is missing, the skill halts and returns an error. The caller must not invoke with partial inputs.

## Return value

The skill always returns a structured JSON object. The caller owns all state writes — the skill never writes to `greenfield-state.json`, `context.phases`, or any synthesis HTML.

```json
{
  "adjustedValue": "<final value agreed upon by the developer>",
  "decision": "<see decision enum below>",
  "via": "adjust-dialog",
  "diff": {
    "before": "<originalValue>",
    "after": "<adjustedValue>",
    "field": "<sectionId>"
  },
  "categoryFindings": [
    {
      "category": "Scope",
      "probe": "<exact question asked>",
      "response": "<developer's response, summarized>",
      "conclusion": "<one-line factual summary>"
    },
    {
      "category": "Assumptions",
      "probe": "...",
      "response": "...",
      "conclusion": "..."
    },
    {
      "category": "Alternatives",
      "probe": "...",
      "response": "...",
      "conclusion": "..."
    },
    {
      "category": "Risks",
      "probe": "...",
      "response": "...",
      "conclusion": "..."
    },
    {
      "category": "Dependencies",
      "probe": "...",
      "response": "...",
      "conclusion": "..."
    }
  ]
}
```

### `categoryFindings` shape

- Exactly 5 entries, one per category, in order: Scope, Assumptions, Alternatives, Risks, Dependencies.
- If a category's probe was skipped (per probe-selection rules), still include an entry with `probe: "skipped — not applicable"` and `response: ""` and `conclusion: "n/a"`.
- If a follow-up was asked within a category, include the most informative probe + response pair (not both — keep the record readable).

## Decision enum

| Value | When to use |
|---|---|
| `"adjusted"` | Developer accepted a new value that differs from `originalValue`. `diff.after !== diff.before`. |
| `"adjusted-then-reverted"` | Developer walked the five categories but ultimately chose to revert to `originalValue`. `diff.after === diff.before`. |
| `"adjusted-with-noted-divergence"` | Developer accepted a new value but noted a reservation (e.g., accepted a risk with a "we'll fix this in sprint 2" caveat). The reservation text is appended to the Risks category `conclusion`. |

There is no `"no-change"` decision — if the developer didn't want to change anything, they would have picked Approve, not Adjust. If the walk produces no change (reverted), use `"adjusted-then-reverted"`.

## Via enum

| Value | When used |
|---|---|
| `"adjust-dialog"` | This skill ran successfully and the developer walked all five categories. |
| `"inline-fallback"` | Caller fell back to synthesis-review's built-in 3-question mini-dialog because this skill was unavailable. Set by the caller, not this skill. |

The `via` field in the return value from this skill is always `"adjust-dialog"`. The caller sets `"inline-fallback"` on its own adjustment records when it couldn't invoke this skill.

## Field-level diff capture

Every return value includes a `diff` object, regardless of whether the value changed:

```json
{
  "before": "<originalValue>",
  "after": "<adjustedValue>",
  "field": "<sectionId>"
}
```

- When `decision === "adjusted"`: `after` is the new value.
- When `decision === "adjusted-then-reverted"`: `after === before` (no net change, but the walk is still recorded).
- When `decision === "adjusted-with-noted-divergence"`: `after` is the new value; the reservation is in `categoryFindings[3].conclusion`.

**Purpose of this field (PRE-5 / T9)**: The `diff` object is the primary input for stale-flag propagation in a later task (T9, PRE-5). Downstream phases that have an approved synthesis record containing `{ "path": "<sectionId>", "value": "<before>" }` in their `dependencies.json` will need to be flagged as potentially stale when `after !== before`. For T8, the diff is recorded but not acted upon — T9 handles the staleness check.

## Composition guidance

### How many probes per category

| Decision complexity | Probes per category |
|---|---|
| High-stakes (framework, DB engine, auth strategy, topology) | 2-3 |
| Mid-stakes (tool choice, integration strategy, schema decision) | 1-2 |
| Low-stakes (config value, naming, secondary tool) | 1 |
| Developer stated clear intent covering this territory | Skip or 1 |

### Ordering within a category

When using 2 probes in a category, use the broader question first, then the narrowing question second. For example, in Scope: ask "What's the blast radius?" before "Which earlier phases need revisiting?" — the broad question frames the narrowing one.

### Cross-category chaining

Some responses in one category naturally set up a probe in another:
- A Scope response that reveals a new phase dependency → extend the Dependencies category to cover that phase
- An Assumptions response that reveals a risk → make sure the Risks category addresses it explicitly
- An Alternatives response that surfaces a concern about the chosen value → make the Risks category address that concern

Cross-category chaining is encouraged when it makes the dialog feel like a coherent conversation. Do not manufacture connections that aren't there.

## Loop guards

### Per-category re-entry limit

If the developer says "Refine further" at Step 4 (after the five-category walk), the skill re-enters the most relevant category. Maximum one re-entry per category per session.

- First re-entry: allowed. Re-run that single category with a different probe.
- Second re-entry attempt on the same category: halt the loop. Ask the developer:

> We've revisited `{category}` twice without convergence. Would you like to: **Continue with current proposed value** / **Revert to original** / **Mark as needs-offline-research** (skip this section for now)?

"Mark as needs-offline-research" records `decision: "adjusted-then-reverted"` with a `conclusion` note of `"developer deferred — needs offline research"`.

### Maximum total refinement rounds

If the developer has requested "Refine further" three or more times in a single adjust-dialog invocation, surface the extension prompt:

> We've been refining this for several rounds. To avoid the session derailing, would you like to: **Commit to the current proposed value** / **Revert to the original value** / **Take a break** (save state and resume later via `/greenfield:pickup`)?

### Mid-session skill error

If this skill errors mid-walk (e.g., context too large, tool call failure), the caller must fall back to the inline 3-question pattern defined in `synthesis-review/references/adjust-dialog-protocol.md § Fallback`. The partially completed walk is discarded — do not attempt to reconstruct it from partial state.

## Caller responsibilities

This skill returns a value. The caller must:

1. Write `adjustedValue` back into `context.phases[phaseId]` at the field path identified by `sectionId`.
2. Append the adjustment record to `context.syntheses[phaseId].adjustments` using the schema in `synthesis-review/references/adjust-dialog-protocol.md § Recording the result`.
3. Update the rendered synthesis HTML in-place: the Captured-as block reflects the adjusted value; a footnote records the original.
4. Preserve the full `categoryFindings` array in the adjustment record or in a sidecar if the schema allows it — this is the audit trail.

The caller must NOT silently accept an adjusted value without presenting it to the developer at least once. Key Rule 3 in the `SKILL.md` Guard: "Never auto-adjust."
