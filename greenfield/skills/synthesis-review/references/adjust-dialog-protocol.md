# Adjust Dialog Protocol — Two-Stage Composition

Used by the synthesis-review skill (Step 5) when the developer selects "Adjust" on a section. Composes `superpowers:brainstorming` (exploration) and `mattpocock-skills:grill-me` (adversarial verification) into a single guided refinement flow. Has an inline fallback when either plugin is unavailable.

## The two stages

### Stage 1 — Brainstorming (exploration)

If `superpowers:brainstorming` is installed, invoke it via the Skill tool with this brief:

> A developer adjusted the **{section_name}** decision in phase {phaseId}. The original captured value was:
>
> `{original}`
>
> The developer's stated adjustment intent is:
>
> "{intent}"
>
> Help them think through alternatives, surface trade-offs, and arrive at a refined answer. Return only the final answer, plus a 2–3 sentence summary of the trade-offs considered.

Capture the brainstormed answer + trade-off summary.

If `superpowers:brainstorming` is NOT installed, skip Stage 1 entirely. Use the developer's stated intent verbatim as the candidate answer.

### Stage 2 — Grill-me (adversarial verification)

If `mattpocock-skills:grill-me` is installed, invoke it via the Skill tool with this brief:

> Stress-test this answer for the **{section_name}** decision in phase {phaseId}:
>
> `{candidate_answer}`
>
> Look for: hidden contradictions with other captured phases (we have `{listed_phases}` so far), missing dependencies, fragile assumptions. Be adversarial. Return either:
>
> - "answer holds — here's why" with reasoning, OR
> - "answer breaks — here's the specific issue" with the issue.

If grill-me says the answer holds → use the candidate as-is.

If grill-me identifies a break → present the issue to the developer via `AskUserQuestion` with three options:

- **Accept the issue and refine further** — loop back to Stage 1 with the issue as additional context
- **Override grill-me with documented rationale** — proceed with the candidate; record the override note in the adjustment
- **Revert to the original captured value** — abandon the adjustment

If `mattpocock-skills:grill-me` is NOT installed, skip Stage 2. The candidate answer goes straight to the developer for final confirmation via `AskUserQuestion`.

## Plugin detection

Use the Skill tool's standard availability behavior. Treat any of these as "not installed":

- Skill tool returns an error referencing the slash form
- The plugin's manifest is missing from the user's plugin cache
- The skill is installed but `disable-model-invocation: true` blocks programmatic invocation

Do NOT shell out to `claude plugin list --json` for detection — that's a runtime cost the skill doesn't need. The Skill tool's natural error surface is the signal.

## Inline fallback (both plugins missing)

If neither plugin is available, run a 3-question mini-dialog inline.

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
     "before": <original>,
     "after": <final>,
     "via": "brainstorming+grill-me" | "brainstorming-only" | "grill-me-only" | "inline-fallback"
   }
   ```

3. Update the rendered synthesis HTML in-place. The Captured-as block now reflects the adjusted value; a footnote records the original.

## Loop guards

- If a single section enters the Adjust dialog more than 3 times in one synthesis session, halt and offer to skip the section instead. Three adjustments without convergence usually means the section needs deeper revisiting in a later session.
- If brainstorming or grill-me errors out mid-call (network, plugin bug), fall back to inline immediately. Do not retry the failed plugin in the same section.

## When to NOT use this dialog

- The section the developer wants to adjust is missing — surface a different error.
- The developer wants to adjust a captured value in an UPSTREAM phase (e.g., P3 from within a P8 synthesis review). This skill only adjusts its own phase. For upstream changes, point the developer at `/greenfield:resume` and restarting from the relevant phase.
