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

PR: https://github.com/ApurvBazari/claude-plugins/pull/53
Branch: `feat/greenfield-1.4` (off `develop`)
Total commits: 27 (24 new files + 19 modified = 43 files touched)

```
693ec71 chore(release): R5 — version bumps to alpha.6 + CHANGELOGs + Discussion Log entry
57c9ed8 docs(greenfield+onboard): R5 — CLAUDE.md updates (20-step wizard, R5 phase additions block)
710b002 docs(greenfield-3.0): Round 5 companion docs — overview + migration-notes + coupling-matrix
e499674 test(greenfield): R5 — feature-roadmap fixture + smoke + alpha.5→alpha.6 migration test
843590d feat(onboard): R5 — deterministic feature-list.json + sprint-1.json + schema/contract file outputs from featureRoadmap + schemaDraftReview phases
3fd80a2 feat(greenfield): R5 — CHECK-R5-1..6 invariants + grill-spec wiring + question-bank reference
45bbfdc fix(greenfield): R5 — correct step labels (Feature Roadmap + Schema & API Draft Review)
e97cf9a chore(greenfield): R5 — bump start skill wizard step count to 20
d569ad1 feat(greenfield): R5 — pass featureRoadmap + schemaDraftReview to onboard generation
aee2578 feat(greenfield): R5 — add 3 health-check assertions (featureRoadmap, schemaDraftReview, sprint-1 contract)
43ce41c feat(greenfield): R5 — pickup alpha.5→alpha.6 migration shim + P10.5 Reject Adjust-mode jump-links
3a89f91 feat(greenfield): R5 — index feature-roadmap + schema-draft-review templates in synthesis-review
2c33d0d feat(greenfield): R5 — wire Step 16 (featureRoadmap) + Step 19 (schemaDraftReview); renumber wizard 17→20
5be27f7 feat(greenfield): R5 — schema-draft-review synthesis templates (3-panel HTML + linear MD)
7a31642 fix(greenfield): R5 — align feature-roadmap templates to phase-rooted Handlebars convention
a247acd feat(greenfield): R5 — feature-roadmap synthesis templates (HTML + MD + dependencies example)
9096549 fix(greenfield): R5 — PII encryption check uses jq -r (raw output)
627a6ca feat(greenfield): R5 — render-event-json-schema.sh (JSON Schema event renderer)
ed4f815 feat(greenfield): R5 — render-event-asyncapi.sh (AsyncAPI 2.6 event renderer)
b96914b feat(greenfield): R5 — render-api-graphql.sh (GraphQL SDL API renderer)
c9d6429 feat(greenfield): R5 — render-api-openapi.sh (OpenAPI 3.0 API renderer with PII/scope/entity warnings)
cdbfc37 feat(greenfield): R5 — render-db-sql-ddl.sh (SQL DDL DB renderer)
697fb78 feat(greenfield): R5 — render-db-prisma.sh (Prisma DB renderer with PII/PK warnings)
646df64 feat(greenfield): R5 — render-schema-drafts.sh entrypoint dispatches to per-language modules
b897ae9 feat(greenfield): R5 — schema-draft-review q-bank (12 Qs heavy / 6 light + auto-render hook)
befb784 feat(greenfield): R5 — feature-roadmap q-bank (14 Qs heavy / 7 light + per-persona auto-loop)
d7d91a6 feat(onboard): R5 — replace featureRoadmap + schemaDraftReview deferred stubs in context-shape-v2
```
