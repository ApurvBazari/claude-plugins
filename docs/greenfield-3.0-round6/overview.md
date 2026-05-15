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

`<filled-by-T57>`
