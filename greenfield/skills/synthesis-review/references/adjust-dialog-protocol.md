# Adjust Dialog Protocol

Used by the synthesis-review skill (Step 5) when the developer selects "Adjust" on a section. Delegates to the greenfield-owned `greenfield/skills/adjust-dialog/` skill, which runs a 5-category adversarial walk:

1. **Scope** — Is the adjusted decision correctly scoped to this phase?
2. **Assumptions** — What assumptions does this new value rest on? Are they valid given the current stack?
3. **Alternatives** — What alternatives were ruled out, and why?
4. **Risks** — What could go wrong with this choice?
5. **Dependencies** — Which other phases or fields does this change affect?

## Invocation

When a developer picks "Adjust" on a synthesis section, invoke `greenfield/skills/adjust-dialog/` via the Skill tool, passing:

- `phaseId` — the current phase (e.g., `dataArchitecture`)
- `sectionId` — the section being adjusted
- `originalValue` — the value captured before adjustment
- `adjustmentIntent` — the developer's stated reason for adjusting
- `listedPhases` — all phase IDs present in `context.phases` (for cross-phase contradiction checks)

The skill returns a final adjusted value plus a summary of the adversarial walk.

## Fallback (adjust-dialog skill unavailable)

If the Skill tool errors, run a 3-question mini-dialog inline:

1. `AskUserQuestion`: "What's wrong with the current value, in one line?" — captures the intent.
2. Compose a best-guess refinement based on the intent and the section's captured value. Then `AskUserQuestion`: "Here's a proposed adjustment: `{best_guess}`. Take it?" — give the developer three options: **Take it** / **Refine further** (loop) / **Revert to original**.
3. If "Refine further" — go back to question 1 with the new candidate. After 3 loops without convergence, force a decision (Take current / Revert).

## Recording the result

After the dialog converges:

1. Overwrite the relevant field in `context.phases[phaseId]`. Preserve the field path exactly — never rename.
2. Append to `context.syntheses[phaseId].adjustments`:

   ```json
   {
     "section": "<section_id>",
     "decision": "adjusted",
     "before": "<original>",
     "after": "<final>",
     "via": "adjust-dialog" | "inline-fallback"
   }
   ```

   If the developer ultimately rejects the adjusted answer and reverts to the original value (see synthesis-review Key Rule 7), record instead:

   ```json
   {
     "section": "<section_id>",
     "decision": "adjusted-then-reverted",
     "before": "<original>"
   }
   ```

   Valid `decision` values: `"adjusted"` | `"adjusted-then-reverted"` | `"approved"` | `"skipped"`.
   Valid `via` values: `"adjust-dialog"` | `"inline-fallback"`.

3. Update the rendered synthesis HTML in-place. The Captured-as block now reflects the adjusted value; a footnote records the original.

## Loop guards

- If a single section enters the Adjust dialog more than 3 times in one synthesis session, halt and offer to skip the section instead. Three adjustments without convergence usually means the section needs deeper revisiting in a later session.
- If adjust-dialog errors mid-call, fall back to inline immediately. Do not retry the failed skill in the same section.

## When to NOT use this dialog

- The section the developer wants to adjust is missing — surface a different error.
- The developer wants to adjust a captured value in an UPSTREAM phase (e.g., `dataArchitecture` from within a `cicdAndDelivery` synthesis review). This skill only adjusts its own phase. For upstream changes, point the developer at `/greenfield:pickup` and restarting from the relevant phase.
