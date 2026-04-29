# Spec Decision Tree

The categories `forge:grill-spec` walks during the inline fallback path. The external `mattpocock-skills:grill-me` skill, when installed, drives its own decision tree — this file is consulted only by the inline path (see `references/inline-grill-fallback.md`).

## Categories (in order)

| # | Category | Skip if | Question count |
|---|---|---|---|
| 1 | Scope sanity | `featureDecomposition.sprints[0].features.length === 0` | 1 |
| 2 | Stack alignment | none — always ask | 1 |
| 3 | Feature conflicts | no conflict patterns trigger | 0–3 (one per detected conflict) |
| 4 | Missing dependencies | no patterns trigger | 0–N (one per detected gap) |
| 5 | Security alignment | `securitySensitivity === "baseline"` AND `deployTarget === "local"` | 0–1 |

The categories are evaluated in order. For each, check the "Skip if" condition first; only ask the question if the condition is `false`. Apply each answer back to `forge-state.json.context` before moving to the next category.

## Total interaction budget

The default timebox is 5 minutes for the full walk. If only categories 1 and 2 apply (small CLI project), expect ~1 minute. If all categories trigger with multiple conflicts (large production project), expect closer to 10. Surface an "extend or finish" prompt at the 10-minute mark per `SKILL.md § Step 6 timebox`.

## Routing back to Phase 1.5

Several categories can detect issues that warrant deeper architectural research rather than a quick answer. When that happens:

1. The category's question offers "Park for Phase 1.5 deep research" as an option.
2. If selected, append an entry to `forge-state.json.parkedQuestions[]` with `{ category, question, placeholder, why }`.
3. After all categories complete, grill-spec Step 4 detects new parked items and asks the user whether to route back to Phase 1.5 *now* or proceed to Phase 2 with placeholders.

This keeps Phase 1.5's research sub-phase reusable — grill-spec doesn't duplicate its logic.

## When to extend the tree

Add a new category when:

- Multiple real forge runs have surfaced the same class of contradiction in a sprint review.
- The contradiction is detectable from `forge-state.json.context` alone (no extra tool calls needed).
- The fix is one of: spec mutation, feature removal, route-to-1.5.

Avoid extending the tree when:

- The contradiction is project-specific (better caught later by the running app).
- Detection requires reading the scaffolded code (that's onboard's job, post-Phase-2).
- The category would always trigger (it's a universal rule, not a conditional gate).

## What this tree intentionally does NOT cover

- **Code-level architecture decisions** (folder structure, design patterns) — that's the Generator's job in implementation sessions, per the Planner Scope Principle in `forge/skills/context-gathering/SKILL.md`.
- **Tech-stack version pinning** — that's `forge/agents/stack-researcher.md`'s job during Phase 1 Step 2.
- **Test coverage targets** — that's a sprint-contract concern, not a pre-scaffold concern.
- **Performance benchmarks** — same; sprint-contract territory.

The tree is a *consistency check*, not a *deep design review*. Keep it small.
