# Verify Skill — Independent Feature Evaluation

You are orchestrating an independent verification of features against the project's feature list. This implements the evaluator layer from Anthropic's harness design — a separate agent that judges purely on outcomes, not implementation reasoning.

## Guard

Read `docs/feature-list.json` in the project root. If not found:

> No feature list found. Run `/forge:init` first to scaffold a project with feature tracking.
>
> Or create `docs/feature-list.json` manually following the format in the Forge documentation.

Stop and do not proceed.

## Step 1: Determine Mode

Parse the command arguments:

- **`/forge:verify`** (no args) — verify all features where `passes` is `false`
- **`/forge:verify F001`** — verify a single feature by ID
- **`/forge:verify --sprint 1`** — verify all features in Sprint 1 and check sprint contract

Read `docs/feature-list.json` and identify the target features based on the mode.

Report to the developer:

> **Verification mode**: [all incomplete / feature F001 / Sprint 1]
> **Features to test**: [N]
> **Strategy**: [verificationStrategy from forge-meta.json]
>
> Starting independent evaluation...

## Step 2: Load Verification Context

Read `.claude/forge-meta.json` to get the `verificationStrategy` (browser-automation, api-testing, cli-execution, test-runner, or combination).

If sprint mode, also read `docs/sprint-contracts/sprint-N.json` for the negotiated criteria.

## Step 3: Spawn Feature Evaluator

Spawn the `feature-evaluator` agent with:
- The list of target feature IDs
- The verification strategy
- The sprint contract (if sprint mode)

The agent runs in worktree isolation (`isolation: worktree`) — it gets a read-only copy of the project and cannot modify source code. It tests the running application and reports results.

Wait for the agent to complete and return its verification report.

## Step 4: Process Results

Parse the evaluator's report. For each feature:

### If PASS:
- Update `docs/feature-list.json`: set `passes` to `true` for that feature
- Log in `docs/progress.md`: "F001: [description] — VERIFIED PASSING"

### If FAIL:
- Do NOT update `passes` — it stays `false`
- Log in `docs/progress.md`: "F001: [description] — FAILED: [reason]"
- Present the failure details to the developer

## Step 5: Sprint Gate Check (if sprint mode)

If running in sprint mode, evaluate the sprint contract criteria from the evaluator's report:

- If ALL required criteria are MET:
  > **Sprint [N] gate: PASSED**
  > All [N] features verified. All contract criteria met.
  > Sprint [N] is complete. Ready to begin Sprint [N+1].

- If any required criteria are NOT MET:
  > **Sprint [N] gate: NOT PASSED**
  > [N] criteria failing:
  > - [criterion]: [reason]
  >
  > Fix the failing features/criteria and run `/forge:verify --sprint [N]` again.

## Step 6: Write Report to File

Write the evaluator's full report to `docs/verification-reports/`:

```bash
mkdir -p docs/verification-reports
```

File naming: `[mode]-[date].md` (e.g., `sprint-1-2026-04-05.md`, `feature-F001-2026-04-05.md`, `all-incomplete-2026-04-05.md`)

This creates an auditable trail of verification runs across sessions. Previous reports can be compared to see if scores are trending up or stalling.

## Step 7: Refine vs Pivot Guidance

The evaluator's report includes a strategic recommendation (REFINE or PIVOT). Present this to the developer:

If **REFINE**:
> The evaluator recommends **continuing the current approach**. Scores are trending well and failures are specific, fixable issues. Focus on:
> [list specific failures to fix]

If **PIVOT**:
> The evaluator recommends **reconsidering the approach**. Scores are stalled or declining, and failures appear systemic. Consider:
> - Trying a different architectural pattern for [area]
> - Revisiting the design decisions for [component]
> - Discussing the approach before continuing

This implements the GAN-inspired iteration loop: build → evaluate → decide (refine/pivot) → build again.

## Step 8: Summary

Present the overall results:

> **Verification Complete**
>
> | Feature | Status | Notes |
> |---|---|---|
> | F001: [description] | PASS | [brief evidence] |
> | F002: [description] | FAIL | [brief reason] |
>
> **Results**: [N] passed, [N] failed out of [N] tested
> **Trend**: [improving/stalled/declining] vs previous run
> **Recommendation**: [REFINE/PIVOT] — [rationale]
> [Sprint contract status if applicable]
>
> Report saved to: docs/verification-reports/[filename].md
> Updated: docs/feature-list.json, docs/progress.md

## Key Rules

1. **Never self-evaluate** — Always spawn the feature-evaluator agent. Never test features yourself in the main session.
2. **Update feature-list.json only on PASS** — Failed features stay as `passes: false`.
3. **Honest reporting** — Show failures prominently. Don't bury bad news in summary stats.
4. **Sprint gates are hard** — If a required criterion fails, the sprint is NOT complete. No exceptions.
5. **Log everything** — Every verification run is logged to docs/progress.md and docs/verification-reports/ for cross-session context.
6. **Write reports to files** — Always persist the full report to `docs/verification-reports/` for auditability and trend comparison.
