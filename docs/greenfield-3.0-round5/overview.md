# Round 5 — Feature Roadmap + Schema & API Draft Review

**Branch:** `feat/greenfield-1.4`
**Date:** 2026-05-15
**Target versions:** `greenfield@3.0.0-alpha.6` / `onboard@2.0.0-alpha.6`
**Schema bump:** alpha.5 → alpha.6 (auto-migrating; purely additive)
**Wizard step count:** 17 → 20

## Summary

Round 5 closes the loop between **discovery** (Rounds 1–4 captured stack, architecture, data, API, auth, privacy, security, runtime ops, CI/CD, personas, domain, risks) and **delivery artifacts** (`docs/feature-list.json`, `docs/sprint-contracts/sprint-1.json`, `prisma/schema.prisma` / `docs/api/openapi.yaml` / `docs/events/event-schemas.yaml`).

Two new top-level wizard phases land:
- **Step 16 — Feature Roadmap (P9)**: captures epics + features (with persona/entity/risk back-links + acceptance criteria + verification + sizing) + a sprint-1 contract. Auto-loops per primary persona in `auto-loop` mode. Generates `feature-list.json` and `sprint-1.json` mechanically.
- **Step 19 — Schema & API Draft Review (P10.5)**: architecturally inverted — onboard auto-renders DB/API/Event drafts from R3+R4 discovery mid-flow, then the wizard surfaces them for human Approve/Adjust/Reject per draft. Locked content is written verbatim by onboard generation.

## In scope (delivered)

1. Feature Roadmap Q-bank — 14 Qs heavy / 7 light + per-persona auto-loop (FR.Q4-Q9)
2. Schema & API Draft Review Q-bank — 12 Qs heavy / 6 light + mid-flow auto-render hook
3. Renderer entrypoint + 6 per-language modules (Prisma, SQL DDL, OpenAPI 3.0, GraphQL SDL, AsyncAPI, JSON Schema)
4. 2 synthesis template triples (HTML + MD + dependencies example) for the new phases
5. CHECK-R5-1 through CHECK-R5-6 cross-phase invariants
6. Onboard generation: deterministic `feature-list.json` + `sprint-1.json` from `phases.featureRoadmap`; verbatim schema/contract writes from `phases.schemaDraftReview.drafts`
7. Pickup migration shim: alpha.5 → alpha.6 (auto-migrating with `skipped: true` defaults)
8. 2 smoke-test artifacts under `tests/round-5/`
9. Wizard step renumbering 17 → 20 across all skill files

## Out of scope (deferred to Round 6)

- Frontend / UX expansion (P5)
- 12 never-asked concern areas
- Non-GHA CI provider templates
- Sprint-2..N deterministic contract generation (these remain interactive at sprint boundaries)
- Render templates beyond Prisma/SQL-DDL/OpenAPI/GraphQL/AsyncAPI/JSON-Schema (e.g., Mongoose, Drizzle, tRPC, Hasura, Avro)
- New `mode.featureLoop` toggle (explicitly rejected — reuse `mode.coupling`)

## Brainstorm-to-merge narrative

R5 was the "check-in pause" round per the original 6-round plan: after R5, the wizard is feature-complete enough to step back and assess before the R6 Frontend/UX expansion.

Key locked decisions (from 2026-05-15 brainstorm):
1. Two phases (FeatureRoadmap + SchemaDraftReview) — semantics re-examined in light of R4 outputs
2. P9 fully deterministic — feature-list.json + sprint-1.json generated mechanically, not conversationally
3. Feature shape rich + fully linked — features carry epicId, personaIds, entityIds, riskIds, acceptanceCriteria, verificationSteps, size, sprintAssignment
4. P10.5 auto-renders all three drafts from R3+R4 discovery, then user reviews/adjusts inline
5. P9 follows R4 auto-loop precedent (per-persona in auto-loop mode, flat in hybrid mode)
6. Single bundled `feat/greenfield-1.4` branch, R3-style subagent dispatch

## Commit log

<filled-by-final-task>
