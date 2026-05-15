# Round 6 — Frontend Trio + 6 Concern Phases + 6 Gates + CI Draft Review + Renderer Refactor + Plugin Reshuffle

**Branch:** `feat/greenfield-1.5`
**Date:** 2026-05-15
**Target versions:** `greenfield@3.0.0-alpha.7` / `onboard@2.0.0-alpha.7`
**Schema bump:** alpha.6 → alpha.7 (auto-migrating; purely additive)
**Wizard step count:** 20 → 30

## Summary

Round 6 closes the 6-round wizard overhaul that began in Round 1. The wizard grows from 20 named steps to 30 by landing **9 new top-level phases + 6 inline gates + a CI Draft Review step (Step 20) + a shared renderer library (`render-common.sh`) + a plugin reshuffle (P7.5 Recommendation / P10 Install split) + a generic migration runner**. Architecturally, R6 reuses the R5 playbook: deterministic onboard generation, auto-rendered drafts surfaced through synthesis review, atomic-write file outputs, and per-phase `crossCheckWarnings`. The new wrinkle is the LLM-fallback Adjust path for CI Draft Review when the provider falls outside the vetted three (GHA / GitLab / CircleCI) — gated by a hard user acknowledgment.

## In scope (delivered)

1. **Frontend trio** — P5 Frontend Architecture (Step 22), P5.3 Design System (Step 23), P5.6 UX / Accessibility / Performance (Step 24)
2. **6 concern phases** — Search (Step 7), Caching (Step 9), Real-time (Step 10), File Uploads & CDN (Step 13), Payments (Step 15), i18n / l10n (Step 25)
3. **6 inline gates** distributed into nearest-dependency phases — transactional email + SMS (Step 11 Auth), marketing email + push notifications + product analytics (Step 24 P5.6 UX), feature gating (Step 19 CI/CD)
4. **CI Draft Review (Step 20)** — closes R5 deferred O-R5-3; auto-renders CI YAML from prior phases via 3 vetted renderer modules + LLM fallback for any other provider
5. **5 deferred R5 schema renderers** — Mongoose, Drizzle, tRPC, Hasura, Avro (closes R5 deferred O-R5-3)
6. **`render-common.sh`** — shared helper library used by all 16 renderer modules (11 schema + 5 CI)
7. **`run-migrations.sh`** — generic, table-driven migration runner with `--dry-run` and `--state-file` flags
8. **Pickup `schemaVersion` gate hardening** — accepts nested + top-level locations (R5 follow-up #1)
9. **Plugin reshuffle** — P7.5 Plugin Recommendation (Step 21) split from old P10; new P10 Plugin Install (Step 30) at end
10. **`lockedYaml` field** — captures user-edited CI YAML verbatim for onboard write-out
11. **CHECK-R6-1..6 cross-phase invariants** added to grill-spec
12. **9 new synthesis template triples** (HTML + MD + dependencies example) for the new phases
13. **Wizard step renumbering 20 → 30** across all skill files

## Out of scope (deferred to Round 7+)

- Per-locale auto-loop in i18n phase (flat in R6 — revisit in v3.1 if synthesis review consistently shows user demand)
- CI provider templates beyond top 3 + LLM fallback (Buildkite, Jenkins, AWS CodeBuild, Drone handled via fallback; promote to vetted modules over time)
- Schema renderer expansion (TypeORM, Sequelize, SQLAlchemy, gRPC, Buf protos) — long tail open
- Reverse migration support (`--dry-run` shows diff diagnostically; no auto-downgrade path)
- `mode.frontendDepth` toggle — frontend trio respects `mode.depth` uniformly; deferred indefinitely to avoid mode-flag proliferation
- Stack-derived concern-area inference (e.g., "Next.js + Vercel ⇒ auto-enable file uploads gate") — gates remain explicit per Item 8 locked decision

## Locked decisions

See `docs/superpowers/specs/2026-05-15-greenfield-3.0-round6-design.md` § Locked design decisions (6 decisions from the 2026-05-15 brainstorm: big-bang single round + R3-style subagent dispatch, top-6 concerns → phases + remaining 6 → gates, frontend splits into 3 phases, dependency-driven inline placement, CI hybrid renderer approach, `render-common.sh` bundled into R6).

## Brainstorm-to-merge narrative

R6 is the closing round of the 6-round wizard overhaul. The 2026-05-15 brainstorm locked 6 cross-cutting decisions and the per-phase inventory. The design spec (`docs/superpowers/specs/2026-05-15-greenfield-3.0-round6-design.md`) was authored the same day, followed by a Round 6 implementation plan (`docs/superpowers/plans/2026-05-15-greenfield-3.0-round6-implementation.md`) breaking the work into 57 tasks. Execution landed on `feat/greenfield-1.5` (branched from `develop` after R5 merge), with R3-style subagent dispatch parallelizing the 9 phase Q-banks, 9 synthesis template triples, 5 schema renderers, 4 CI renderers + entrypoint, render-common library, migration runner, and pickup hardening. The renderer refactor lands as a single revertable commit gated by the R5 smoke-test integration. Tasks 54-57 form the docs + release tail (this companion, CLAUDE.md updates, CHANGELOGs, version bumps).

## Commit log

60 commits on `feat/greenfield-1.5` ahead of `origin/develop` (chronological — newest first):

```
632f772 chore(release): R6 — version bumps to alpha.7 + CHANGELOGs
2edca11 docs(greenfield+onboard): R6 — CLAUDE.md updates (30-step wizard, R6 phase additions block) + overview/walkthrough
6663f2b docs(greenfield-3.0): Round 6 companion — overview + migration-notes + coupling-matrix + renderer-architecture
48283f6 test(greenfield): R6 — migration runner golden-output (alpha.3 → alpha.7)
2a19071 test(greenfield): R6 — ci-draft-smoke (4 providers: gha, gitlab, circle, fallback)
c791a1b test(greenfield): R6 — phase-smoke fixture + runner (9 new phases + CHECK-R6 invariants)
5e927a1 test(greenfield): R6 — render-common 6 helper unit tests + R5 refactor integration test
6677370 feat(onboard): R6 — i18n generation module + sprint-contracts.md R5 follow-up #2 fix
bf8f30d feat(onboard): R6 — 3 frontend generation modules + plugin split rewire + cicdAndDelivery.lockedYaml verbatim writes
a7b76f1 feat(onboard): R6 — 5 concern-phase generation modules (search/caching/realtime/file-uploads/payments) + SKILL wiring
97bc740 feat(greenfield): R6 — check skill adds 3 R6 health-check assertions
1670b07 feat(greenfield): R6 — check-r6-invariants.md (CHECK-R6-1..9) + grill-spec wiring
cc5a232 feat(greenfield): R6 — tooling-generation pass-through for 9 new phases + plugin split + cicdAndDelivery.lockedYaml
2b73ed4 feat(greenfield): R6 — plugin-discovery splits into recommendation vs install modes
628439d chore(greenfield): R6 — synthesis-review indexes 10 new templates; start counter 20 → 30
d80ce8f chore(greenfield): R6 — context-gathering progress indicator '20 → 30' + R6-9 auto-loop cap notice
d38e3f8 feat(greenfield): R6 — context-gathering inserts 9 phase steps + 6 inline gates + Step 20 CI Draft Review + plugin split + frontend re-recommendation pass
84f4d60 feat(greenfield): R6 — i18n-l10n synthesis template triple
90b6cca feat(greenfield): R6 — ux-accessibility-perf synthesis template triple (hosts 3 gates)
b2eb6aa feat(greenfield): R6 — design-system synthesis template triple
2d5d4d3 feat(greenfield): R6 — frontend-architecture synthesis template triple
0ac546d feat(greenfield): R6 — payments synthesis template triple
d9316cb feat(greenfield): R6 — file-uploads synthesis template triple
778f0b6 feat(greenfield): R6 — realtime synthesis template triple
f7ac509 feat(greenfield): R6 — caching synthesis template triple
2440d0e feat(greenfield): R6 — search synthesis template triple
5b3a80a feat(greenfield): R6 — append 3 inline gate snippets (TransEmail+SMS in auth, FeatureGating in cicd) + question-bank R6 appendix
9d71430 feat(greenfield): R6 — i18n-l10n.q-bank.md (Step 25, 11 Qs heavy)
c4aaf23 feat(greenfield): R6 — ux-accessibility-perf.q-bank.md (Step 24, P5.6, 15 Qs heavy, per-persona, hosts 3 gates)
c2d3a06 feat(greenfield): R6 — design-system.q-bank.md (Step 23, P5.3, 12 Qs heavy)
bf0ca97 feat(greenfield): R6 — frontend-architecture.q-bank.md (Step 22, P5, 13 Qs heavy, per-persona)
42365f1 feat(greenfield): R6 — payments.q-bank.md (Step 15, 14 Qs heavy, per-persona)
46745c7 feat(greenfield): R6 — file-uploads.q-bank.md (Step 13, 13 Qs heavy, per-persona)
c306406 feat(greenfield): R6 — realtime.q-bank.md (Step 10, 12 Qs heavy, per-persona)
2f82eef feat(greenfield): R6 — caching.q-bank.md (Step 9, 12 Qs heavy)
be33f17 feat(greenfield): R6 — search.q-bank.md (Step 7, flat, ~11 Heavy / ~6 Light)
e0163a1 fix(greenfield): R6 — run-migrations.sh dry-run emits valid JSON (jq -n construction)
40acba5 refactor(greenfield): R6 — pickup uses run-migrations.sh + hardens schemaVersion gate (legacy + canonical)
95a5c4c feat(greenfield): R6 — alpha-6-to-7 migration step (9 phases + 6 gates + plugin split + lockedYaml)
371557c feat(greenfield): R6 — extract alpha-5-to-6 migration step from R5 inline cascade
ad4dc6f feat(greenfield): R6 — extract alpha-3-to-4 + alpha-4-to-5 migration steps from inline pickup cascade
019f063 feat(greenfield): R6 — run-migrations.sh generic runner with --dry-run + JSON diff
945f44d feat(greenfield): R6 — ci-draft-review synthesis template triple (3-panel review)
0777080 feat(greenfield): R6 — render-ci-llm-fallback.sh (LLM fallback with banner + CHECK-R6-8 forcing ack)
70beeb6 feat(greenfield): R6 — render-ci-circleci.sh (CircleCI YAML renderer)
a80755d feat(greenfield): R6 — render-ci-gitlab.sh (GitLab CI YAML renderer)
418e393 feat(greenfield): R6 — render-ci-gha.sh (GHA YAML emission module)
4f7ddbe feat(greenfield): R6 — render-ci-drafts.sh CI renderer entrypoint with provider dispatch + LLM fallback
f2323cb feat(greenfield): R6 — render-event-avro.sh + dispatch wiring (closes R5 O-R5-3 #5)
b0078a3 feat(greenfield): R6 — render-api-hasura.sh + dispatch wiring (closes R5 O-R5-3 #4)
4412966 feat(greenfield): R6 — render-api-trpc.sh + dispatch wiring (closes R5 O-R5-3 #3)
dce3296 feat(greenfield): R6 — render-db-drizzle.sh + dispatch wiring (closes R5 O-R5-3 #2)
da485c5 feat(greenfield): R6 — render-db-mongoose.sh + dispatch wiring (closes R5 O-R5-3 #1)
4849544 refactor(greenfield): R6 — refactor R5 renderers to source render-common.sh (single revertable commit)
a3916a6 feat(greenfield): R6 — render-common.sh shared helper library (6 helpers)
a1d52a1 feat(greenfield): R6 — extend dependencies-schema phase enum + path pattern for 9 new phases
5687b44 feat(onboard): R6 — context-shape-v2 adds 9 new phase blocks + 6 inline gate slots + plugin split + cicdAndDelivery.lockedYaml
be854cb docs(greenfield-3.0): Round 6 implementation plan — 57 tasks
02e8f7d docs(greenfield-3.0): R6 design spec — self-review fixes
9830371 docs(greenfield-3.0): Round 6 design spec — Frontend trio + 6 concern phases + 6 gates + CI Draft Review + renderer refactor + plugin reshuffle
```
