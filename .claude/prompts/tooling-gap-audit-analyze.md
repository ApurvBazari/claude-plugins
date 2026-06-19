# Tooling-Gap Audit — Analyze

You are auditing this repository's Claude tooling for drift against `.claude/audit-baseline.json`.

## Inputs
- The structural drift report from `onboard/scripts/audit-tooling.sh`.
- The baseline inventory `.claude/audit-baseline.json`.

## Task
Compare the live tooling surface (CLAUDE.md command references, rule path targets, hook invocations, skill/agent references) against the baseline. Enumerate each gap as a concrete, actionable finding: what drifted, where (file:line), and the suggested fix. Emit nothing when there is no drift.
