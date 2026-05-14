# Round 5 — Migration Notes (alpha.5 → alpha.6)

## What's new

Two new wizard steps add deterministic delivery-artifact generation to the greenfield flow:

- **Step 16 — Feature Roadmap** (`featureRoadmap` phase). Captures epics + features + sprint-1 contract. Auto-loops per primary persona. Produces `docs/feature-list.json` and `docs/sprint-contracts/sprint-1.json`.

- **Step 19 — Schema & API Draft Review** (`schemaDraftReview` phase). Auto-renders DB, API, and Event drafts from your earlier discovery answers (domain model, auth, privacy, API integration). Walk through Approve/Adjust/Reject per draft. Locked content is written verbatim to your project tree (`prisma/schema.prisma`, `docs/api/openapi.yaml`, etc.) by onboard generation.

## In-flight session migration

Sessions started on alpha.5 (greenfield 3.0.0-alpha.5) auto-migrate to alpha.6 on the next `/greenfield:pickup`:

1. Pickup detects `meta.schemaVersion < "3.0.0-alpha.6"`.
2. Injects `{skipped: true, deferredReason: "session predates Round 5"}` for both new phases.
3. Bumps `meta.schemaVersion` to `"3.0.0-alpha.6"`.
4. Surfaces a notice to the user: "Session migrated. Steps 16 + 19 are available via Adjust mode."

The migration is **additive and safe** — existing alpha.5 phase data (personas, domainModel, risks, etc.) is preserved unchanged. Onboard generation falls back to the alpha.5 interactive handoff flow when these phases stay `skipped: true`.

## Breaking changes

**None.** The bump is purely additive.

- Pre-R5 (alpha.5) projects continue to work — onboard's interactive handoff flow remains the fallback for `feature-list.json` and `sprint-1.json` when `phases.featureRoadmap.skipped = true`.
- Pre-R5 projects do NOT receive schema/contract files (onboard writes nothing when `phases.schemaDraftReview.skipped = true`).
- All R4 phases and mechanics remain unchanged.

## Rollback path

If alpha.6 needs reverting:

1. **Revert the R5 PR** on `develop` (single revert commit).
2. **Bump versions back** in `greenfield/.claude-plugin/plugin.json` (alpha.6 → alpha.5), `onboard/.claude-plugin/plugin.json` (same), and `.claude-plugin/marketplace.json`.
3. **Migration shim is bidirectional-safe.** alpha.6 sessions calling alpha.5 pickup gracefully drop unknown `featureRoadmap` + `schemaDraftReview` fields (other phases preserved). User re-runs handoff conversationally for `feature-list.json` + `sprint-1.json` (the pre-R5 flow).
4. **`tests/round-5/` scripts** stay in place — no harm at rest. Can be removed in a follow-up cleanup commit if desired.

## Risks captured

| ID | Risk | Mitigation |
|---|---|---|
| R-R5-1 | Auto-render output quality varies across stacks (Prisma vs SQL DDL vs GraphQL); Prisma is best, others may be rougher | Clear "this is a draft, edit freely" framing in SDR.Q3-Q8; Round 6 follow-up to expand template coverage |
| R-R5-2 | Per-persona feature loop can produce near-duplicate features | P10.5-style cross-check warning during P9 synthesis (deferred to Round 6) |
| R-R5-3 | User picks too many features for sprint-1 in FR.Q12 | Size-budget warning at sum > 15pts (S=1, M=3, L=5, XL=8) |
| R-R5-4 | P10.5 reject + upstream change loop confusing | Reject branch shows explicit jump-link to upstream phase via `/greenfield:pickup` Adjust mode |
| R-R5-5 | Renderer failure mid-flow leaves wizard in indeterminate state | Atomic write via `.tmp + rename` in render-schema-drafts.sh; on failure, user sees error + retry/skip before state mutation |
