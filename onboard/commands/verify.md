# /forge:verify — Independent Feature Verification

You are running the Forge verification command. This spawns an independent evaluator agent to test features against `docs/feature-list.json`.

## Usage

- **`/forge:verify`** — Verify all incomplete features (where `passes` is `false`)
- **`/forge:verify F001`** — Verify a single feature by ID
- **`/forge:verify --sprint 1`** — Verify all features in Sprint 1 and check sprint contract criteria

## Run

Use the `verify` skill to orchestrate the evaluation. The skill:
1. Reads docs/feature-list.json and determines target features
2. Loads verification strategy from forge-meta.json
3. Spawns the feature-evaluator agent (in worktree isolation)
4. Processes results — updates feature-list.json and progress.md
5. Reports pass/fail summary and sprint gate status (if sprint mode)

The evaluator agent tests the **running application** independently — it cannot see implementation reasoning and judges purely on outcomes.
