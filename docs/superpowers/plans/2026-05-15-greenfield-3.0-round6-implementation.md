# Greenfield 3.0 Round 6 — Frontend Trio + 6 Concern Phases + 6 Gates + CI Draft Review + Renderer Refactor + Plugin Reshuffle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the locked 6-round greenfield 3.0 wizard overhaul. Add 9 new top-level wizard phases (3 frontend split + 6 concern phases), 6 inline yes/no+vendor gates, a new CI Draft Review step (Step 20) with 3 vetted renderers + LLM fallback, extract a `render-common.sh` shared library + refactor all R5 renderers to source it, ship 5 deferred schema renderers (Mongoose/Drizzle/tRPC/Hasura/Avro), replace pickup's inline migration cascade with a generic `run-migrations.sh` runner, harden the pickup `schemaVersion` gate to accept both legacy + canonical locations, and split P10 Plugin Discovery into P7.5 Plugin Recommendation (Step 21) + P10 Plugin Install (Step 30). Wizard grows from 20 → 30 named steps. Schema bumps `alpha.6 → alpha.7` (auto-migrating).

**Architecture:** Mirrors the R5 pattern — each new phase ships a context-shape schema block, a Q-bank, a synthesis HTML+MD+dependencies template triple, a wizard step in `context-gathering/SKILL.md`, an onboard generation reference module, and grill-spec invariants. **New mechanics:** (1) CI Draft Review inverts the capture→render order like R5 P10.5 did but uses provider-dispatched per-module renderers + LLM-fallback; (2) `render-common.sh` is a shared bash library sourced by all 15 post-R6 renderer modules, with a CI lint check enforcing the import; (3) `run-migrations.sh` is a generic runner that reads sequential migration modules from `greenfield/skills/pickup/migrations/` and supports `--dry-run` with JSON diff; (4) 6 inline gates record to `phases.<parent>.concerns.<gateName> = { needed, vendor?, notes? }` rather than top-level phases. Onboard generation reads each new phase block and emits scaffold-specific files deterministically.

**Tech Stack:** Markdown SKILL.md files, JSON Schema draft-07, HTML synthesis templates (phase-rooted Handlebars `{{phase.X}}` + `{{#each}}{{this.X}}{{/each}}`), Markdown synthesis companions, bash renderer scripts (jq + heredocs + atomic temp-then-rename writes, no compiled code), shell smoke tests under `tests/round-6/`. Consistent with prior rounds.

**Source spec:** `docs/superpowers/specs/2026-05-15-greenfield-3.0-round6-design.md`

**Branch:** `feat/greenfield-1.5` (new branch for Round 6; off `develop`).

**Target versions on completion:** `greenfield@3.0.0-alpha.7` / `onboard@2.0.0-alpha.7`.

---

## File Structure

### NEW files (~70)

#### Renderer library + new schema renderers (6)

| Path | Responsibility |
|---|---|
| `greenfield/scripts/render-common.sh` | Shared helper library: `_emit_warning`, `_check_pii_encryption`, `_atomic_write`, `_render_handlebars`, `_emit_dependency`, `_validate_jq_path` |
| `greenfield/scripts/render-db-mongoose.sh` | DB renderer: Mongoose models — triggered when `dataArchitecture.engine = mongodb` |
| `greenfield/scripts/render-db-drizzle.sh` | DB renderer: Drizzle ORM — triggered when `engine in {postgres,mysql,sqlite}` AND `language=drizzle` |
| `greenfield/scripts/render-api-trpc.sh` | API renderer: tRPC router types — triggered when `apiIntegration.style = trpc` |
| `greenfield/scripts/render-api-hasura.sh` | API renderer: Hasura metadata + permissions YAML |
| `greenfield/scripts/render-event-avro.sh` | Event renderer: Apache Avro schemas |

#### CI renderer family (5)

| Path | Responsibility |
|---|---|
| `greenfield/scripts/render-ci-drafts.sh` | CI renderer entrypoint — dispatches by `phases.cicdAndDelivery.provider` |
| `greenfield/scripts/render-ci-gha.sh` | GHA renderer (existing inline GHA YAML emission ported to renderer module) |
| `greenfield/scripts/render-ci-gitlab.sh` | GitLab CI renderer (NEW) |
| `greenfield/scripts/render-ci-circleci.sh` | CircleCI renderer (NEW) |
| `greenfield/scripts/render-ci-llm-fallback.sh` | LLM-fallback renderer — used when provider ∉ {gha, gitlab, circleci}; emits banner |

#### Migration runner + step modules (5)

| Path | Responsibility |
|---|---|
| `greenfield/scripts/run-migrations.sh` | Generic migration runner: reads steps from `pickup/migrations/`, supports `--dry-run` with JSON diff |
| `greenfield/skills/pickup/migrations/alpha-3-to-4.sh` | Extracted from R4 inline cascade |
| `greenfield/skills/pickup/migrations/alpha-4-to-5.sh` | Extracted from R4 inline cascade |
| `greenfield/skills/pickup/migrations/alpha-5-to-6.sh` | Extracted from R5 inline cascade |
| `greenfield/skills/pickup/migrations/alpha-6-to-7.sh` | NEW — R6 schema migration: adds 9 phases as `{skipped: true}`, 6 gates as `{needed: null}`, splits `pluginDiscovery → pluginRecommendation + pluginInstall`, adds `cicdAndDelivery.lockedYaml = null` |

#### Q-banks (9)

| Path | Responsibility |
|---|---|
| `greenfield/skills/context-gathering/references/search.q-bank.md` | Search phase Q-bank (~11 Heavy / ~6 Light) — flat |
| `greenfield/skills/context-gathering/references/caching.q-bank.md` | Caching phase Q-bank (~12 Heavy / ~7 Light) — flat |
| `greenfield/skills/context-gathering/references/realtime.q-bank.md` | Real-time phase Q-bank (~12 Heavy / ~6 Light) — per-persona auto-loop |
| `greenfield/skills/context-gathering/references/file-uploads.q-bank.md` | File Uploads & CDN Q-bank (~13 Heavy / ~7 Light) — per-persona |
| `greenfield/skills/context-gathering/references/payments.q-bank.md` | Payments Q-bank (~14 Heavy / ~7 Light) — per-persona (customer vs admin) |
| `greenfield/skills/context-gathering/references/frontend-architecture.q-bank.md` | P5 Frontend Architecture Q-bank (~13 Heavy / ~7 Light) — per-persona |
| `greenfield/skills/context-gathering/references/design-system.q-bank.md` | P5.3 Design System Q-bank (~12 Heavy / ~6 Light) — flat |
| `greenfield/skills/context-gathering/references/ux-accessibility-perf.q-bank.md` | P5.6 UX / A11y / Performance Q-bank (~15 Heavy / ~8 Light) — per-persona |
| `greenfield/skills/context-gathering/references/i18n-l10n.q-bank.md` | i18n / l10n Q-bank (~11 Heavy / ~6 Light) — flat |

#### Synthesis template triples (10 × 3 = 30 files)

For each of the 9 new phases + the CI Draft Review step:

| Pattern | Three files per phase |
|---|---|
| `greenfield/skills/synthesis-review/references/templates/<phase>.html` | Phase-rooted Handlebars HTML synthesis |
| `greenfield/skills/synthesis-review/references/templates/<phase>.md` | Markdown mirror for plain-text review |
| `greenfield/skills/synthesis-review/references/templates/<phase>-dependencies.json.example` | Declares which `dependencies.json` entries this phase emits |

Concrete: `search`, `caching`, `realtime`, `file-uploads`, `payments`, `frontend-architecture`, `design-system`, `ux-accessibility-perf`, `i18n-l10n`, `ci-draft-review`.

#### Invariants + onboard generation modules (10)

| Path | Responsibility |
|---|---|
| `greenfield/skills/grill-spec/references/check-r6-invariants.md` | CHECK-R6-1 through CHECK-R6-9 |
| `onboard/skills/generation/references/render-search.md` | Search → `lib/search.ts` + (Postgres FTS) `prisma/migrations/0002_search_indexes.sql` |
| `onboard/skills/generation/references/render-caching.md` | Caching → `lib/cache.ts` + framework-conditional CDN headers |
| `onboard/skills/generation/references/render-realtime.md` | Real-time → `lib/realtime.ts` + `app/api/realtime/route.ts` + reconnect helper |
| `onboard/skills/generation/references/render-file-uploads.md` | File Uploads → `lib/uploads.ts` + S3/R2 IAM policy + MIME allowlist |
| `onboard/skills/generation/references/render-payments.md` | Payments → `lib/payments/<provider>.ts` + webhook handler + portal route |
| `onboard/skills/generation/references/render-frontend-architecture.md` | P5 → `package.json` deps + `lib/store.ts` / `lib/queries.ts` skeletons |
| `onboard/skills/generation/references/render-design-system.md` | P5.3 → shadcn init / MUI theme / Mantine provider + `tailwind.config.ts` tokens + `.storybook/` |
| `onboard/skills/generation/references/render-ux-accessibility-perf.md` | P5.6 → Lighthouse CI workflow + image optimizer + fonts setup + CWV budget JSON |
| `onboard/skills/generation/references/render-i18n-l10n.md` | i18n → `lib/i18n.ts` + `messages/en.json` + `next.config.ts` i18n routing |

#### Tests (~12)

| Path | Responsibility |
|---|---|
| `tests/round-6/render-common/atomic_write_test.sh` | Helper unit test: `_atomic_write` |
| `tests/round-6/render-common/emit_warning_test.sh` | Helper unit test: `_emit_warning` |
| `tests/round-6/render-common/check_pii_encryption_test.sh` | Helper unit test: `_check_pii_encryption` |
| `tests/round-6/render-common/render_handlebars_test.sh` | Helper unit test: `_render_handlebars` |
| `tests/round-6/render-common/emit_dependency_test.sh` | Helper unit test: `_emit_dependency` |
| `tests/round-6/render-common/validate_jq_path_test.sh` | Helper unit test: `_validate_jq_path` |
| `tests/round-6/r5-refactor-integration-test.sh` | Re-runs the R5 schema-draft smoke against the post-refactor renderers |
| `tests/round-6/phase-smoke-fixture.json` | Mock alpha.7 state covering all 9 new phases populated |
| `tests/round-6/phase-smoke.sh` | Smoke runner — verifies each new phase synthesis template renders + dependencies.json validates |
| `tests/round-6/ci-draft-smoke.sh` | Smokes GHA + GitLab + CircleCI + LLM-fallback renderers against a fixture |
| `tests/round-6/migrations/golden-output.sh` | Forward-runs alpha.3 fixture through all 4 migration steps + diffs against golden |
| `tests/round-6/migrations/alpha-3-fixture.json` | Synthesized alpha.3 input — golden-output input |
| `tests/round-6/migrations/alpha-7-expected.json` | Expected post-migration output — golden-output assertion target |

#### Docs (5)

| Path | Responsibility |
|---|---|
| `docs/greenfield-3.0-round6/overview.md` | Narrative summary + brainstorm trail + commit log (filled in T57) |
| `docs/greenfield-3.0-round6/migration-notes.md` | User-facing alpha.6 → alpha.7 notes; generic runner usage |
| `docs/greenfield-3.0-round6/coupling-matrix.md` | Extends R5 coupling matrix with R6 rows (9 phases + 6 gates) |
| `docs/greenfield-3.0-round6/renderer-architecture.md` | Post-refactor library + module inventory + helper API contracts |
| `docs/superpowers/plans/2026-05-15-greenfield-3.0-round6-implementation.md` | This file |

### MODIFIED files (~50)

#### Schema + dependency graph (2)

| Path | What changes |
|---|---|
| `onboard/skills/generate/references/context-shape-v2.json` | 9 new phase blocks (replacing `frontend` stub with split form; adding 8 new phases); 6 `concerns.<gate>` slots in `auth`/`uxAccessibilityPerf`/`cicdAndDelivery`; split `pluginDiscovery → pluginRecommendation + pluginInstall`; new `cicdAndDelivery.lockedYaml: string|null` field; new `cicdAndDelivery.adjustHistory[]` audit array |
| `greenfield/skills/synthesis-review/references/dependencies-schema.json` | Extend `phase` pattern to include 9 new phase names; extend `path` pattern; surface `pluginRecommendation` + `pluginInstall` |

#### R5 schema renderers (refactor to source `render-common.sh`) (6)

| Path | What changes |
|---|---|
| `greenfield/scripts/render-schema-drafts.sh` | Sources `render-common.sh`; ID dispatch unchanged but case table extended with the 5 new modules |
| `greenfield/scripts/render-db-prisma.sh` | Sources `render-common.sh`; replaces inline `_emit_warning`, `_check_pii_encryption`, atomic write logic with helper calls |
| `greenfield/scripts/render-db-sql-ddl.sh` | Same — sources + delegates helpers |
| `greenfield/scripts/render-api-openapi.sh` | Same |
| `greenfield/scripts/render-api-graphql.sh` | Same |
| `greenfield/scripts/render-event-asyncapi.sh` | Same |
| `greenfield/scripts/render-event-json-schema.sh` | Same |

#### Wizard + state (4)

| Path | What changes |
|---|---|
| `greenfield/skills/context-gathering/SKILL.md` | Insert 9 new steps + 6 inline gates inside their parent phases + CI Draft Review hook at Step 20 + plugin split (P7.5 at Step 21 / P10 at Step 30) + frontend re-recommendation pass after Step 25; renumber to 30 steps; progress indicator update |
| `greenfield/skills/synthesis-review/SKILL.md` | Index 10 new templates; document CI Draft Review's auto-render + 3-panel review |
| `greenfield/skills/start/SKILL.md` | Step counter 20 → 30 |
| `greenfield/skills/pickup/SKILL.md` | Replace inline alpha.5→alpha.6 cascade with `run-migrations.sh` invocation; harden gate to `.meta.schemaVersion // .schemaVersion // "unknown"` everywhere |

#### Plugin split + tooling (3)

| Path | What changes |
|---|---|
| `greenfield/skills/plugin-discovery/SKILL.md` | Split into recommendation-mode vs install-mode behaviour; "recommendation mode" emits suggestions to `phases.pluginRecommendation`; "install mode" reads `phases.pluginRecommendation.selected` + `frontendAddenda` and installs |
| `greenfield/skills/tooling-generation/SKILL.md` | Pass-through additions: surface all 9 new phases + `pluginRecommendation` + `pluginInstall` + `cicdAndDelivery.lockedYaml` in the onboard generate context |
| `greenfield/skills/grill-spec/SKILL.md` | Wire CHECK-R6-1 through CHECK-R6-9 |

#### Health + onboard generation (3)

| Path | What changes |
|---|---|
| `greenfield/skills/check/SKILL.md` | 3 new assertions: frontend trio completeness (when not skipped), 6 concern-phase completeness (when not skipped), `pluginRecommendation` + `pluginInstall` both populated (when neither skipped) |
| `onboard/skills/generation/SKILL.md` | Wire 9 deterministic generation references; replace single `pluginDiscovery` read with two-phase recommendation+install read; surface `cicdAndDelivery.lockedYaml` write path |
| `onboard/skills/generation/references/sprint-contracts.md` | One-line update removing the stale "First sprint contract (negotiated or auto-generated)" wording; adds pointer to `phases.featureRoadmap.sprint1` (closes R5 follow-up #2) |

#### Q-bank index (1)

| Path | What changes |
|---|---|
| `greenfield/skills/context-gathering/references/question-bank.md` | Append 6 inline-gate Q snippets inside `auth.q-bank.md` (transactional email, SMS), `ux-accessibility-perf.q-bank.md` (marketing email, push, analytics), `cicd.q-bank.md` (feature gating); also append Round 6 phase reference appendix listing all 9 new Q-banks |

#### CI/CD Q-bank (1)

| Path | What changes |
|---|---|
| `greenfield/skills/context-gathering/references/cicd.q-bank.md` | Append feature gating inline gate Q (yes/no + vendor); also note CI Draft Review hook at Step 20 |

#### Auth + UX Q-banks (modified to host gates — 2)

| Path | What changes |
|---|---|
| `greenfield/skills/context-gathering/references/auth.q-bank.md` | Append `Gate.TransEmail` + `Gate.SMS` Q snippets |
| `greenfield/skills/context-gathering/references/ux-accessibility-perf.q-bank.md` | Hosts `Gate.MktEmail` + `Gate.Push` + `Gate.Analytics` snippets at the end of the Q-bank (intra-phase, written in T28) |

#### CLAUDE.md + documentation (5)

| Path | What changes |
|---|---|
| `greenfield/CLAUDE.md` | 30-step wizard architecture diagram; Skill Hierarchy enumerates new steps; Key Patterns adds R6 paragraph (concern phases, CI Draft Review, render-common, plugin split, migration runner) |
| `onboard/CLAUDE.md` | Mirror R6 phase additions block (9 new phases, plugin split, lockedYaml) |
| `docs/greenfield-overview.html` | Discussion Log entry: **ROUND 6 LOCKED** (closes the 6-round plan) |
| `docs/greenfield-walkthrough.html` | Promote 9 new phases + CI Draft Review + plugin split from "Planned" to "Shipped" status badges |
| `greenfield/CHANGELOG.md` | Alpha.7 entry — auto-migrating, 9 phases, 6 gates, CI Draft Review, render-common, migration runner, plugin split |
| `onboard/CHANGELOG-2.0.md` | Alpha.7 entry — schema additions (9 phase blocks, gate slots, plugin split, lockedYaml) |

#### Release bookkeeping (3)

| Path | What changes |
|---|---|
| `greenfield/.claude-plugin/plugin.json` | `3.0.0-alpha.6` → `3.0.0-alpha.7` |
| `onboard/.claude-plugin/plugin.json` | `2.0.0-alpha.6` → `2.0.0-alpha.7` |
| `.claude-plugin/marketplace.json` | Version sync (greenfield + onboard) |

**Total: ~70 new + ~50 modified = ~120 files.** Matches design estimate of ~100-130.

---

## Task Order Overview

```
Phase A — Schema foundations
   T1   context-shape-v2.json — 9 phase blocks + 6 concerns slots + plugin split + cicdAndDelivery.lockedYaml
   T2   dependencies-schema.json — extend phase enum + path pattern

Phase B — render-common.sh + R5 refactor
   T3   render-common.sh (helper library: 6 helpers)
   T4   Refactor 6 R5 renderers to source render-common.sh (single revertable commit)

   ── CHECKPOINT 1 (after Phase A + B): schema lock + R5-renderer compatibility ──
       Verify: R5 smoke tests still pass post-refactor (re-run feature-roadmap-smoke
       + migration-test). If any regression, revert T4 and surface before continuing.

Phase C — New schema renderers (R5 O-R5-3 closure)
   T5   render-db-mongoose.sh
   T6   render-db-drizzle.sh
   T7   render-api-trpc.sh
   T8   render-api-hasura.sh
   T9   render-event-avro.sh

Phase D — CI renderer family
   T10  render-ci-drafts.sh (entrypoint)
   T11  render-ci-gha.sh (port existing GHA logic to module form)
   T12  render-ci-gitlab.sh (NEW)
   T13  render-ci-circleci.sh (NEW)
   T14  render-ci-llm-fallback.sh (NEW + LLM banner)
   T15  ci-draft-review template triple (HTML + MD + dependencies.json.example)

Phase E — Migration runner + pickup gate hardening
   T16  run-migrations.sh (generic runner + --dry-run)
   T17  pickup/migrations/alpha-3-to-4.sh + alpha-4-to-5.sh (extracted)
   T18  pickup/migrations/alpha-5-to-6.sh (extracted from R5 inline)
   T19  pickup/migrations/alpha-6-to-7.sh (NEW R6 migration)
   T20  pickup/SKILL.md — runner integration + schemaVersion gate hardening

   ── CHECKPOINT 2 (after Phase D + E): renderer contract lock + migration runner ──
       Verify: every renderer (15 modules post-T4+T5-T14) sources render-common.sh;
       run-migrations.sh forward-walks an alpha.3 fixture to alpha.7 cleanly;
       --dry-run emits valid JSON diff.

Phase F — Q-banks for 9 new phases + 6 inline gates
   T21  search.q-bank.md
   T22  caching.q-bank.md
   T23  realtime.q-bank.md
   T24  file-uploads.q-bank.md
   T25  payments.q-bank.md
   T26  frontend-architecture.q-bank.md
   T27  design-system.q-bank.md
   T28  ux-accessibility-perf.q-bank.md  (hosts 3 inline gates: marketing email, push, analytics)
   T29  i18n-l10n.q-bank.md
   T30  Append 3 inline-gate Q snippets to existing Q-banks (auth → transactional email + SMS; cicd → feature gating)

Phase G — Synthesis template triples (9 new phases + CI Draft Review)
   T31  search template triple
   T32  caching template triple
   T33  realtime template triple
   T34  file-uploads template triple
   T35  payments template triple
   T36  frontend-architecture template triple
   T37  design-system template triple
   T38  ux-accessibility-perf template triple
   T39  i18n-l10n template triple

   ── CHECKPOINT 3 (after Phase F + G): template <-> Q-bank path consistency ──
       Verify: synthesis template `{{phase.X}}` paths match the Q-bank `Stores to:`
       paths character-for-character; gate `concerns.<gate>` paths match across
       templates + invariants.

Phase H — Wizard wiring
   T40  context-gathering/SKILL.md — insert 9 phase steps + 6 inline gates + CI Draft Review hook + re-recommendation pass
   T41  context-gathering/SKILL.md — renumber to 30 steps + progress indicator update
   T42  synthesis-review/SKILL.md (index 10 new templates) + start/SKILL.md (counter 20 → 30)

Phase I — Plugin reshuffle
   T43  plugin-discovery/SKILL.md — recommendation vs install mode toggle
   T44  tooling-generation/SKILL.md — pass-through additions (9 phases + plugin split + lockedYaml)

Phase J — Cross-phase invariants + health checks
   T45  check-r6-invariants.md (CHECK-R6-1..9) + grill-spec/SKILL.md wiring
   T46  check/SKILL.md — 3 new health-check assertions

Phase K — Onboard generation
   T47  generation references for 5 concern phases (search, caching, realtime, file-uploads, payments) + generation/SKILL.md wiring
   T48  generation references for 3 frontend phases (P5, P5.3, P5.6) + generation/SKILL.md wiring + plugin split rewire
   T49  generation reference for i18n + generation/SKILL.md wiring + sprint-contracts.md one-line fix

Phase L — Tests
   T50  render-common test fixtures (6 helper unit tests) + R5 refactor integration test
   T51  Per-new-phase smoke fixture + smoke runner (9 phases)
   T52  CI Draft Review smokes (4 providers)
   T53  Migration runner golden-output test (alpha.3 → alpha.7 walk)

Phase M — Docs
   T54  docs/greenfield-3.0-round6/ companion (overview + migration-notes + coupling-matrix + renderer-architecture)
   T55  greenfield/CLAUDE.md + onboard/CLAUDE.md + greenfield-overview.html + greenfield-walkthrough.html updates

Phase N — Release + final
   T56  Version bumps + marketplace.json + CHANGELOGs (greenfield + onboard)
   T57  /validate sweep + smoke pass + branch push + PR creation + memory update
```

**Estimated total: 57 tasks.** Each task = 1 logical commit. Subagent dispatch estimated at ~70–110 invocations (implementer + spec-review + occasional fix per task, matching R5 cadence at ~2x volume).

**Three mid-execution checkpoints (one more than R5 — R6 has more moving parts):**

1. **After Phase A + B (schema lock + R5-renderer compatibility)** — gate the rest of execution on R5 smoke tests still passing post-`render-common.sh` extraction. If the refactor regresses anything, revert T4 (it's a single commit by design) and continue with the inline pattern.
2. **After Phase D + E (renderer contract lock + migration runner)** — every new renderer wired, runner walks alpha.3 → alpha.7 cleanly. Anything downstream (Q-banks, templates) depends on these contracts being stable.
3. **After Phase F + G (template ↔ Q-bank path consistency)** — synthesis templates reference field paths verbatim from Q-bank `Stores to:` lines. R5 commit `7a31642` taught us this is where divergence creeps in.

---

## Phase A — Schema foundations

### Task 1: Replace `frontend`/`pluginRecommendation`/`pluginInstall` stubs and add 8 new phase blocks in `context-shape-v2.json`

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Inspect current state**

Run: `jq '.properties.phases.properties | keys' onboard/skills/generate/references/context-shape-v2.json`

Expected output should include `frontend` (a `$ref: deferredPhase` stub), `pluginRecommendation` (Round 1 shape `{pluginRecommendations: []}`), `pluginInstall` (Round 1 shape `{installedPlugins: []}`). It must NOT include `search`, `caching`, `realtime`, `fileUploads`, `payments`, `designSystem`, `uxAccessibilityPerf`, `i18nL10n`, `frontendArchitecture` (these are added by this task).

- [ ] **Step 2: Replace the `frontend` $ref with the new `frontendArchitecture` full schema**

Locate `"frontend": {"$ref": "#/definitions/deferredPhase"}` and replace with `"frontendArchitecture": { ... }`. Rename the property; do NOT keep `frontend`. Block:

```jsonc
"frontendArchitecture": {
  "type": "object",
  "description": "Round 6 — P5 Frontend Architecture (Step 22). Per-persona auto-loop in auto-loop mode.",
  "properties": {
    "frameworkConfirmed": { "type": "string", "description": "Cross-refs phases.architecturalFraming.frontendFramework — must match (CHECK-R6-4)." },
    "stateManagement": { "type": "string", "enum": ["builtin-only", "redux", "zustand", "jotai", "mobx", "recoil", "valtio", "none"] },
    "routingStrategy": { "type": "string", "enum": ["app-router", "pages-router", "react-router", "tanstack-router", "remix", "vue-router", "none"] },
    "dataFetching": { "type": "string", "enum": ["fetch", "tanstack-query", "swr", "rtk-query", "apollo", "urql", "trpc-client", "none"] },
    "formHandling": { "type": "string", "enum": ["react-hook-form", "formik", "tanstack-form", "uncontrolled", "none"] },
    "animationLibrary": { "type": "string", "enum": ["framer-motion", "react-spring", "auto-animate", "css-only", "none"] },
    "errorBoundaries": { "type": "string", "enum": ["per-route", "per-feature", "global-only", "none"] },
    "codeSplitting": { "type": "string", "enum": ["route-level", "component-lazy", "manual", "none"] },
    "bundler": { "type": "string", "enum": ["turbopack", "vite", "webpack", "rspack", "esbuild", "rollup", "parcel", "none"] },
    "devServer": { "type": "string" },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" },
    "loopIterations": { "type": "integer", "default": 0 }
  }
}
```

- [ ] **Step 3: Add the 8 remaining new-phase blocks**

After `frontendArchitecture`, before `architecturalValidation`, insert:

```jsonc
"search": {
  "type": "object",
  "description": "Round 6 — Search phase (Step 7). Flat. References dataArchitecture.entities[] (CHECK-R6-2).",
  "properties": {
    "searchType": { "type": "string", "enum": ["fts", "vector", "hybrid", "none"] },
    "engine": { "type": "string", "enum": ["postgres-fts", "meilisearch", "typesense", "elasticsearch", "opensearch", "pgvector", "pinecone", "weaviate", "none"] },
    "indexScope": { "type": "array", "items": { "type": "string" } },
    "updateStrategy": { "type": "string", "enum": ["realtime", "batch", "hybrid"] },
    "queryPatterns": { "type": "array", "items": { "enum": ["filters", "facets", "autocomplete", "semantic", "ranking", "spelling"] } },
    "ranking": { "type": "string" },
    "abTesting": { "type": "boolean", "default": false },
    "security": { "type": "object", "properties": { "rls": { "type": "boolean" }, "queryAuth": { "type": "boolean" } } },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" }
  }
},
"caching": {
  "type": "object",
  "description": "Round 6 — Caching phase (Step 9). Flat.",
  "properties": {
    "layers": { "type": "array", "items": { "enum": ["cdn", "edge", "app", "db-query", "browser"] } },
    "cdnProvider": { "type": "string", "enum": ["cloudflare", "fastly", "vercel-edge", "cloudfront", "akamai", "none"] },
    "invalidationStrategy": { "type": "string", "enum": ["ttl", "tag-based", "manual", "hybrid"] },
    "staleWhileRevalidate": { "type": "boolean", "default": false },
    "keyDesign": { "type": "string" },
    "multiTenantIsolation": { "type": "boolean", "default": false },
    "observability": { "type": "object", "properties": { "hitRates": { "type": "boolean" }, "alertOnDrop": { "type": "boolean" } } },
    "stampedeProtection": { "type": "string", "enum": ["lock", "request-coalescing", "swr", "none"] },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" }
  }
},
"realtime": {
  "type": "object",
  "description": "Round 6 — Real-time phase (Step 10). Per-persona auto-loop.",
  "properties": {
    "transport": { "type": "string", "enum": ["sse", "websocket", "long-poll", "push", "none"] },
    "useCases": { "type": "array", "items": { "enum": ["notifications", "presence", "collaboration", "live-data", "chat", "telemetry"] } },
    "backend": { "type": "string", "enum": ["redis-pubsub", "dedicated-service", "channels", "broker", "none"] },
    "clientLib": { "type": "string", "enum": ["pusher", "ably", "soketi", "centrifugo", "native", "none"] },
    "scaling": { "type": "object", "properties": { "stickySessions": { "type": "boolean" }, "horizontal": { "type": "boolean" } } },
    "reconnectStrategy": { "type": "string", "enum": ["exponential-backoff", "fixed-interval", "manual", "none"] },
    "messageOrdering": { "type": "string", "enum": ["per-channel", "global", "best-effort"] },
    "dedup": { "type": "boolean", "default": false },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" },
    "loopIterations": { "type": "integer", "default": 0 }
  }
},
"fileUploads": {
  "type": "object",
  "description": "Round 6 — File Uploads & CDN phase (Step 13). Per-persona auto-loop.",
  "properties": {
    "storageBackend": { "type": "string", "enum": ["s3", "r2", "gcs", "azure-blob", "local", "none"] },
    "uploadFlow": { "type": "string", "enum": ["signed-url", "direct", "server-proxied", "multipart-resumable"] },
    "cdnProvider": { "type": "string" },
    "imageTransforms": { "type": "string", "enum": ["imgix", "cloudinary", "native", "none"] },
    "maxFileSize": { "type": "string" },
    "mimeAllowlist": { "type": "array", "items": { "type": "string" } },
    "virusScanning": { "type": "boolean", "default": false },
    "piiHandling": { "type": "string", "enum": ["encrypted-at-rest", "field-level-encryption", "kms-keys", "none"] },
    "retentionPolicy": { "type": "string" },
    "multiTenantIsolation": { "type": "boolean", "default": false },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" },
    "loopIterations": { "type": "integer", "default": 0 }
  }
},
"payments": {
  "type": "object",
  "description": "Round 6 — Payments phase (Step 15). Per-persona auto-loop (customer-facing vs admin).",
  "properties": {
    "provider": { "type": "string", "enum": ["stripe", "lemon-squeezy", "paddle", "razorpay", "braintree", "none"] },
    "billingModel": { "type": "string", "enum": ["one-time", "subscription", "usage-based", "marketplace", "hybrid"] },
    "customerPortal": { "type": "boolean", "default": false },
    "taxHandling": { "type": "string", "enum": ["provider-managed", "self-managed", "none"] },
    "dunning": { "type": "string", "enum": ["provider", "custom", "none"] },
    "webhookStrategy": { "type": "string", "enum": ["per-event", "fanout", "queue", "none"] },
    "fraudPrevention": { "type": "string", "enum": ["provider-builtin", "sift", "stripe-radar", "custom", "none"] },
    "refundFlow": { "type": "string", "enum": ["self-serve", "admin-approval", "manual", "none"] },
    "currencyLocale": { "type": "array", "items": { "type": "string" } },
    "compliance": { "type": "object", "properties": { "pciScope": { "type": "string", "enum": ["saq-a", "saq-a-ep", "saq-d", "none"] }, "sca": { "type": "boolean" }, "regulatory": { "type": "array", "items": { "type": "string" } } } },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" },
    "loopIterations": { "type": "integer", "default": 0 }
  }
},
"designSystem": {
  "type": "object",
  "description": "Round 6 — P5.3 Design System phase (Step 23). Flat.",
  "properties": {
    "componentLibrary": { "type": "string", "enum": ["shadcn", "mui", "mantine", "chakra", "ant", "headless-ui", "custom", "none"] },
    "themingApproach": { "type": "string", "enum": ["css-variables", "tokens", "css-in-js", "tailwind-config", "multiple-themes"] },
    "primitivesStrategy": { "type": "string", "enum": ["radix", "react-aria", "ariakit", "headless-ui", "custom", "none"] },
    "variantSystem": { "type": "string", "enum": ["cva", "tv", "stitches", "panda-recipes", "none"] },
    "iconSystem": { "type": "string", "enum": ["lucide", "heroicons", "phosphor", "tabler", "iconify", "custom", "none"] },
    "typographyScale": { "type": "string" },
    "colorSystem": { "type": "string" },
    "spacingTokens": { "type": "string" },
    "designToolIntegration": { "type": "string", "enum": ["figma", "penpot", "sketch", "none"] },
    "storybookAdopted": { "type": "boolean", "default": false },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" }
  }
},
"uxAccessibilityPerf": {
  "type": "object",
  "description": "Round 6 — P5.6 UX/A11y/Performance phase (Step 24). Per-persona auto-loop. Hosts 3 inline gates (marketing email, push notifications, product analytics).",
  "properties": {
    "surfacesByPersona": { "type": "object", "description": "Map of personaId → array of surface names (web-app, mobile-web, native, admin-dashboard)" },
    "responsivenessStrategy": { "type": "string", "enum": ["mobile-first", "desktop-first", "adaptive", "responsive"] },
    "breakpointSystem": { "type": "string" },
    "a11yTarget": { "type": "string", "enum": ["wcag-a", "wcag-aa", "wcag-aaa", "none"] },
    "keyboardNavigation": { "type": "string", "enum": ["full", "partial", "none"] },
    "screenReaderTesting": { "type": "string", "enum": ["axe", "manual", "lighthouse", "none"] },
    "performanceBudgets": { "type": "object", "properties": { "lcp": { "type": "number" }, "inp": { "type": "number" }, "cls": { "type": "number" } } },
    "imageOptimization": { "type": "string", "enum": ["next-image", "imgix", "cloudinary", "native", "none"] },
    "fontLoading": { "type": "string", "enum": ["next-font", "font-display-swap", "preload", "none"] },
    "stateUx": { "type": "object", "properties": { "error": { "type": "string" }, "empty": { "type": "string" }, "loading": { "type": "string" } } },
    "offlineSupport": { "type": "boolean", "default": false },
    "concerns": {
      "type": "object",
      "properties": {
        "marketingEmail":     { "$ref": "#/definitions/inlineGate" },
        "pushNotifications":  { "$ref": "#/definitions/inlineGate" },
        "productAnalytics":   { "$ref": "#/definitions/inlineGate" }
      }
    },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" },
    "loopIterations": { "type": "integer", "default": 0 }
  }
},
"i18nL10n": {
  "type": "object",
  "description": "Round 6 — i18n / l10n phase (Step 25). Flat. Locales array drives translation strategy.",
  "properties": {
    "targetLocales": { "type": "array", "items": { "type": "string" } },
    "translationSource": { "type": "string", "enum": ["manual", "ai-assisted", "hybrid", "none"] },
    "library": { "type": "string", "enum": ["next-intl", "react-i18next", "formatjs", "lingui", "native-intl", "none"] },
    "fileFormat": { "type": "string", "enum": ["json", "po", "xliff", "yaml"] },
    "rtlSupport": { "type": "boolean", "default": false },
    "dateNumberFormatting": { "type": "string", "enum": ["intl-api", "library-helper", "custom"] },
    "pluralRules": { "type": "boolean", "default": false },
    "contentTranslationFlow": { "type": "string" },
    "delivery": { "type": "string", "enum": ["bundled", "cdn", "lazy"] },
    "textType": { "type": "string", "enum": ["static", "dynamic", "hybrid"] },
    "seoHreflang": { "type": "boolean", "default": false },
    "qRisks": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" }
  }
}
```

- [ ] **Step 4: Add 6 inline gate slots inside existing parent phases**

Add `concerns` to `auth` (already exists in `properties` — extend it):

```jsonc
// inside auth.properties
"concerns": {
  "type": "object",
  "properties": {
    "transactionalEmail": { "$ref": "#/definitions/inlineGate" },
    "sms":                 { "$ref": "#/definitions/inlineGate" }
  }
}
```

Add `concerns.featureGating` inside `cicdAndDelivery` (the `cicdAndDelivery` definition lives under `definitions` since it's `$ref`'d — locate `.definitions.cicdAndDelivery.properties` and add):

```jsonc
"concerns": {
  "type": "object",
  "properties": {
    "featureGating": { "$ref": "#/definitions/inlineGate" }
  }
},
"lockedYaml": {
  "type": ["string", "null"],
  "description": "Round 6 — Locked CI YAML emitted by render-ci-drafts.sh after Step 20 Approve. Onboard writes verbatim at scaffold time."
},
"adjustHistory": {
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "at": { "type": "string", "format": "date-time" },
      "instruction": { "type": "string" },
      "renderedYaml": { "type": "string" }
    },
    "required": ["at", "instruction", "renderedYaml"]
  },
  "description": "R-R6-10 mitigation — audit trail of each Adjust call."
}
```

(`uxAccessibilityPerf.concerns` was already added in Step 3.)

- [ ] **Step 5: Add `inlineGate` definition under `definitions`**

```jsonc
"inlineGate": {
  "type": "object",
  "properties": {
    "needed": { "type": ["boolean", "null"], "description": "null = unanswered; true/false = answered" },
    "vendor": { "type": ["string", "null"] },
    "notes":  { "type": "string", "default": "" }
  }
}
```

- [ ] **Step 6: Replace `pluginRecommendation` Round-1 stub with R6 split shape**

```jsonc
"pluginRecommendation": {
  "type": "object",
  "description": "Round 6 — P7.5 Plugin Recommendation (Step 21). Reads auth/privacy/security/runtimeOperations/cicdAndDelivery/concerns.featureGating. Does NOT install.",
  "properties": {
    "suggested": { "type": "array", "items": { "type": "string" } },
    "selected":  { "type": "array", "items": { "type": "string" } },
    "rationale": { "type": "string" },
    "frontendAddenda": { "type": "array", "items": { "type": "string" }, "description": "Added by re-recommendation pass after Step 25 i18n." }
  }
}
```

- [ ] **Step 7: Replace `pluginInstall` Round-1 stub with R6 install-result shape**

```jsonc
"pluginInstall": {
  "type": "object",
  "description": "Round 6 — P10 Plugin Install (Step 30). Reads pluginRecommendation.selected ∪ frontendAddenda; actually runs /plugin marketplace install.",
  "properties": {
    "installed": { "type": "array", "items": { "type": "string" } },
    "failed":    { "type": "array", "items": { "type": "object", "properties": { "id": { "type": "string" }, "reason": { "type": "string" } }, "required": ["id", "reason"] } },
    "skipped":   { "type": "array", "items": { "type": "string" } }
  }
}
```

- [ ] **Step 8: Update top-level `required` and the `$schema`/`title`/`description`**

If `properties.phases.required` exists and includes `frontend`, replace with `frontendArchitecture`. If `description` mentions "Round 5 schema", update to "Round 6 schema (alpha.7)". Bump any `$id` version suffix if present.

- [ ] **Step 9: Validate**

```bash
jq empty onboard/skills/generate/references/context-shape-v2.json
jq '.properties.phases.properties | keys' onboard/skills/generate/references/context-shape-v2.json | grep -E 'search|caching|realtime|fileUploads|payments|frontendArchitecture|designSystem|uxAccessibilityPerf|i18nL10n'
jq '.definitions.inlineGate' onboard/skills/generate/references/context-shape-v2.json
```

Expected: jq empty exits 0; key listing prints all 9 new phase names; `inlineGate` definition prints.

- [ ] **Step 10: Commit**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "feat(onboard): R6 — context-shape-v2 adds 9 new phase blocks + 6 inline gate slots + plugin split + cicdAndDelivery.lockedYaml"
```

---

### Task 2: Extend `dependencies-schema.json` phase enum + path pattern

**Files:**
- Modify: `greenfield/skills/synthesis-review/references/dependencies-schema.json`

- [ ] **Step 1: Inspect current pattern**

Run: `jq '.properties.phase.pattern, .properties.dependencies.items.properties.path.pattern' greenfield/skills/synthesis-review/references/dependencies-schema.json`

Expected: both patterns enumerate R1–R5 phase names. Need to add: `search`, `caching`, `realtime`, `fileUploads`, `payments`, `frontendArchitecture`, `designSystem`, `uxAccessibilityPerf`, `i18nL10n` (and the existing `frontend` legacy alias can be removed since we renamed it).

- [ ] **Step 2: Patch `.properties.phase.pattern`**

Replace with (note: alphabetized for readability):

```jsonc
"pattern": "^(apiIntegration|architecturalFraming|architecturalValidation|auth|authSecurity|caching|cicdAndDelivery|dataArchitecture|designSystem|domainModel|featureRoadmap|fileUploads|frontendArchitecture|i18nL10n|payments|personas|pluginInstall|pluginRecommendation|privacy|realtime|risks|runtimeOperations|schemaDraftReview|search|security|stack|uxAccessibilityPerf|vision|workflow)$"
```

- [ ] **Step 3: Patch `.properties.dependencies.items.properties.path.pattern`**

Same prefix pattern as above + the existing `(\\.[\\w\\[\\]\\?='*\\.]+)+$` tail suffix. Result:

```jsonc
"pattern": "^(apiIntegration|architecturalFraming|architecturalValidation|auth|authSecurity|caching|cicdAndDelivery|dataArchitecture|designSystem|domainModel|featureRoadmap|fileUploads|frontendArchitecture|i18nL10n|payments|personas|pluginInstall|pluginRecommendation|privacy|realtime|risks|runtimeOperations|schemaDraftReview|search|security|stack|uxAccessibilityPerf|vision|workflow)(\\.[\\w\\[\\]\\?='*\\.]+)+$"
```

- [ ] **Step 4: Validate**

```bash
jq empty greenfield/skills/synthesis-review/references/dependencies-schema.json
# Test a sample new path validates against the regex:
echo '{"schemaVersion":1,"phase":"search","dependencies":[{"path":"dataArchitecture.entities[0].id","value":"E001"}]}' | jq -r '.phase' | grep -E '^(search|caching|realtime|fileUploads|payments|frontendArchitecture|designSystem|uxAccessibilityPerf|i18nL10n)$'
```

Expected: jq empty exits 0; grep prints `search`.

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/synthesis-review/references/dependencies-schema.json
git commit -m "feat(greenfield): R6 — extend dependencies-schema phase enum + path pattern for 9 new phases"
```

---

## Phase B — render-common.sh + R5 refactor

### Task 3: Author `greenfield/scripts/render-common.sh` (shared helper library)

**Files:**
- Create: `greenfield/scripts/render-common.sh`

- [ ] **Step 1: Write the file**

```bash
cat > greenfield/scripts/render-common.sh <<'COMMONSH'
#!/usr/bin/env bash
# render-common.sh — R6 shared helper library
#
# Sourced by every renderer module in greenfield/scripts/render-*.sh.
# Provides 6 helpers replacing duplicated logic from R5.
#
# Helpers exit non-zero on failure; callers are expected to use `set -euo pipefail`.
# All helpers are pure shell — no external state beyond their args + stdin.

set -euo pipefail

# Guard against double-sourcing.
[[ "${__RENDER_COMMON_SH_SOURCED:-}" == "1" ]] && return 0
readonly __RENDER_COMMON_SH_SOURCED=1

command -v jq >/dev/null || { echo "render-common: jq is required" >&2; exit 2; }

# _emit_warning <level> <code> <message>
#   Appends a warning object to the JSON array passed via the $WARNINGS variable
#   in the caller's scope. Caller pattern:
#     WARNINGS=$(_emit_warning "warn" "W-DB-pk" "Aggregate root has no PK" "$WARNINGS")
_emit_warning() {
  local level="$1" code="$2" message="$3" warnings_json="${4:-[]}"
  jq --arg id "$code" --arg lvl "$level" --arg msg "$message" \
    '. + [{id: $id, level: $lvl, message: $msg, addressed: false}]' <<< "$warnings_json"
}

# _check_pii_encryption <entity-attr-path> <pii-array> <warnings-json>
#   Looks up entity.attribute in the privacy.piiFields[] array. If matched and
#   no encryption hint declared, returns a `warn`-level warning appended to
#   the warnings JSON. No-op if path not in PII list.
_check_pii_encryption() {
  local path="$1" pii_array="$2" warnings_json="${3:-[]}"
  local hit
  hit=$(jq --arg p "$path" '[.[] | select(.path == $p)] | length' <<< "$pii_array")
  if [[ "$hit" -gt 0 ]]; then
    local enc
    enc=$(jq -r --arg p "$path" '[.[] | select(.path == $p) | .encryption // ""] | first // ""' <<< "$pii_array")
    if [[ -z "$enc" ]]; then
      local code msg
      code="W-PII-$(echo "$path" | tr '.' '-')"
      msg="Field \`$path\` (PII) has no encryption hint — review storage strategy"
      _emit_warning "warn" "$code" "$msg" "$warnings_json"
      return 0
    fi
  fi
  echo "$warnings_json"
}

# _atomic_write <target-path> <content-string>
#   Writes content to <target-path>.tmp then atomically renames over <target-path>.
#   Ensures readers never see a partial write. Exits non-zero on failure.
_atomic_write() {
  local target="$1" content="$2"
  local tmp="${target}.tmp.$$"
  printf '%s' "$content" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$target"
}

# _render_handlebars <template-string> <data-json>
#   Minimal Handlebars-flavored substitution: {{phase.field}}, {{#each list}}{{this.field}}{{/each}}.
#   data-json is the rooted phase block (e.g., contents of .phases.search).
#   For complex iteration, callers should pre-flatten or use jq directly.
_render_handlebars() {
  local tpl="$1" data="$2"
  local out="$tpl"
  # Simple {{field}} or {{nested.field}} substitution
  while [[ "$out" =~ \{\{([a-zA-Z_][a-zA-Z0-9_.]*)\}\} ]]; do
    local key="${BASH_REMATCH[1]}"
    local val
    val=$(jq -r --arg k "$key" 'getpath($k | split(".")) // ""' <<< "$data" 2>/dev/null || echo "")
    out="${out//\{\{${key}\}\}/$val}"
  done
  echo "$out"
}

# _emit_dependency <phase> <path> <value-json> <rationale>
#   Appends a dependency record to a dependencies.json file at $DEPS_PATH.
#   The caller is responsible for setting DEPS_PATH before calling.
_emit_dependency() {
  local phase="$1" path="$2" value="$3" rationale="$4"
  : "${DEPS_PATH:?DEPS_PATH must be set}"
  if [[ ! -f "$DEPS_PATH" ]]; then
    printf '%s\n' "{\"schemaVersion\":1,\"phase\":\"$phase\",\"dependencies\":[]}" > "$DEPS_PATH"
  fi
  local tmp="${DEPS_PATH}.tmp.$$"
  jq --arg p "$path" --argjson v "$value" --arg r "$rationale" \
    '.dependencies += [{path: $p, value: $v, rationale: $r}]' \
    "$DEPS_PATH" > "$tmp" && mv "$tmp" "$DEPS_PATH"
}

# _validate_jq_path <state-file> <jq-path> <required-bool>
#   Reads a jq path from the state file. Exits non-zero with a clear message if
#   `required` is "true" and the path is empty/null. Otherwise prints the value.
_validate_jq_path() {
  local state_file="$1" path="$2" required="${3:-false}"
  local val
  val=$(jq -r "$path" "$state_file" 2>/dev/null || echo "")
  if [[ "$required" == "true" && ( -z "$val" || "$val" == "null" ) ]]; then
    echo "render-common: required path missing: $path" >&2
    exit 3
  fi
  echo "$val"
}

# Marker so callers can verify the library was sourced rather than re-implementing inline.
export __RENDER_COMMON_API_VERSION=1
COMMONSH
chmod +x greenfield/scripts/render-common.sh
```

- [ ] **Step 2: Lint**

```bash
shellcheck greenfield/scripts/render-common.sh
```

Expected: silent (exit 0). If shellcheck flags `SC1091` for the source guard — that's a known false positive on guarded-source-once patterns; suppress with a directive comment at the top: `# shellcheck disable=SC2034,SC1091`.

- [ ] **Step 3: Smoke each helper inline**

```bash
# Source the library and exercise each helper
source greenfield/scripts/render-common.sh

# _emit_warning
W=$(_emit_warning "warn" "W-test" "test msg" "[]")
echo "$W" | jq -e '.[0].id == "W-test"' || { echo "FAIL: _emit_warning"; exit 1; }

# _atomic_write
TMP=$(mktemp)
_atomic_write "$TMP" "hello"
[[ "$(cat "$TMP")" == "hello" ]] || { echo "FAIL: _atomic_write"; exit 1; }
rm -f "$TMP"

# _render_handlebars
T=$(_render_handlebars 'Hello {{name}}' '{"name":"world"}')
[[ "$T" == "Hello world" ]] || { echo "FAIL: _render_handlebars"; exit 1; }

echo "render-common smoke OK"
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/scripts/render-common.sh
git commit -m "feat(greenfield): R6 — render-common.sh shared helper library (6 helpers)"
```

---

### Task 4: Refactor 6 R5 renderers to source `render-common.sh`

**Files:**
- Modify: `greenfield/scripts/render-db-prisma.sh`
- Modify: `greenfield/scripts/render-db-sql-ddl.sh`
- Modify: `greenfield/scripts/render-api-openapi.sh`
- Modify: `greenfield/scripts/render-api-graphql.sh`
- Modify: `greenfield/scripts/render-event-asyncapi.sh`
- Modify: `greenfield/scripts/render-event-json-schema.sh`
- Modify: `greenfield/scripts/render-schema-drafts.sh`

This refactor lands as a single revertable commit (per spec § `render-common.sh` shared library / Refactor commit boundary).

- [ ] **Step 1: For each R5 renderer, replace inline warning logic with `_emit_warning`**

For each of the 6 R5 renderer scripts (`render-db-prisma.sh`, `render-db-sql-ddl.sh`, `render-api-openapi.sh`, `render-api-graphql.sh`, `render-event-asyncapi.sh`, `render-event-json-schema.sh`):

(a) Add this near the top, after `set -euo pipefail`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"
```

(b) Replace each inline jq-warning append (the pattern is `WARNINGS=$(jq --arg id "$WARN_ID" --arg msg "$MSG" '. + [{id: $id, level: "warn", message: $msg}]' <<< "$WARNINGS")`) with:

```bash
WARNINGS=$(_emit_warning "warn" "$WARN_ID" "$MSG" "$WARNINGS")
```

(c) Replace each inline PII-encryption check (the duplicated `_check_pii_encryption` jq pattern that lives in `render-db-prisma.sh` and `render-api-openapi.sh` from R5 commit `9096549`) with:

```bash
WARNINGS=$(_check_pii_encryption "${NAME}.${AN}" "$PII" "$WARNINGS")
```

- [ ] **Step 2: Replace inline atomic writes with `_atomic_write`**

In `render-schema-drafts.sh` (the entrypoint), replace the temp-file rename block at the end:

Before:
```bash
mv "$TMP_OUT" "$STATE_FILE"
```

After:
```bash
_atomic_write "$STATE_FILE" "$(cat "$TMP_OUT")"
rm -f "$TMP_OUT"
```

(Note: the existing `mv "$TMP_OUT" "$STATE_FILE"` IS already an atomic rename — this swap is for consistency with the new helper. Keep the original line if reverting; this is a stylistic refactor only.)

- [ ] **Step 3: Verify shellcheck still clean**

```bash
shellcheck greenfield/scripts/render-*.sh
```

Expected: silent. If `SC1091` (source not followable), prepend the file with `# shellcheck source=render-common.sh` directive directly above the `source` line.

- [ ] **Step 4: Re-run R5 smoke tests (CHECKPOINT 1)**

```bash
bash tests/round-5/feature-roadmap-smoke.sh
bash tests/round-5/migration-test.sh
```

Expected: both pass with the same green output as before T4. If any regression, **revert this single commit** (revert is non-destructive — leaves T1-T3 intact) and continue with the inline pattern. Surface the regression as a fix-subagent dispatch.

- [ ] **Step 5: CI lint check — every renderer sources the library**

```bash
MISSING=$(grep -L 'source.*render-common' greenfield/scripts/render-*.sh | grep -v render-common.sh || true)
if [[ -n "$MISSING" ]]; then
  echo "FAIL: renderers missing source line: $MISSING"
  exit 1
fi
echo "OK: all renderers source render-common.sh"
```

Expected: prints `OK:`; exit 0.

- [ ] **Step 6: Commit**

```bash
git add greenfield/scripts/render-*.sh
git commit -m "refactor(greenfield): R6 — refactor R5 renderers to source render-common.sh (single revertable commit)"
```

---

## Phase C — New schema renderers (R5 O-R5-3 closure)

### Task 5: `greenfield/scripts/render-db-mongoose.sh`

**Files:**
- Create: `greenfield/scripts/render-db-mongoose.sh`

- [ ] **Step 1: Write the renderer**

```bash
cat > greenfield/scripts/render-db-mongoose.sh <<'MONGOOSE'
#!/usr/bin/env bash
# render-db-mongoose.sh — R6 DB renderer (Mongoose)
# Triggered when dataArchitecture.engine = mongodb. Sources render-common.sh.
# Emits a JSON envelope { content, sourceRefs, crossCheckWarnings } to stdout.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-db-mongoose.sh <state-file>}"
ENTITIES=$(_validate_jq_path "$STATE_FILE" '.phases.domainModel.entities // []' false)
PII=$(_validate_jq_path "$STATE_FILE" '.phases.privacy.piiFields // []' false)

HEADER='// Generated by greenfield render-db-mongoose.sh — review and edit freely after lock.
import mongoose, { Schema, Document } from "mongoose";
'

MODELS=""
SRC_REFS="[]"
WARNINGS="[]"

ENTITY_COUNT=$(jq 'length' <<< "$ENTITIES")
for i in $(seq 0 $((ENTITY_COUNT - 1))); do
  E=$(jq ".[$i]" <<< "$ENTITIES")
  NAME=$(jq -r '.name // .id // "Unknown"' <<< "$E")

  ATTRS=$(jq '.attributes // []' <<< "$E")
  A_COUNT=$(jq 'length' <<< "$ATTRS")
  FIELDS_BLOCK=""
  for j in $(seq 0 $((A_COUNT - 1))); do
    AN=$(jq -r ".[$j].name // \"f${j}\"" <<< "$ATTRS")
    AT=$(jq -r ".[$j].type // \"String\"" <<< "$ATTRS")
    case "$AT" in
      string|String|text)     MT="String" ;;
      int|integer|Int)        MT="Number" ;;
      bool|boolean|Boolean)   MT="Boolean" ;;
      date|datetime|DateTime) MT="Date" ;;
      float|number|Float)     MT="Number" ;;
      *)                      MT="String" ;;
    esac
    FIELDS_BLOCK="${FIELDS_BLOCK}
  ${AN}: { type: ${MT} },"
    WARNINGS=$(_check_pii_encryption "${NAME}.${AN}" "$PII" "$WARNINGS")
  done

  MODELS="${MODELS}
interface I${NAME} extends Document {}
const ${NAME}Schema = new Schema<I${NAME}>({${FIELDS_BLOCK}
}, { timestamps: true });
export const ${NAME} = mongoose.model<I${NAME}>('${NAME}', ${NAME}Schema);
"
  SRC_REFS=$(jq --arg n "$NAME" '. + [{path: ("domainModel.entities[name=" + $n + "]"), renderedAs: ("Mongoose model " + $n)}]' <<< "$SRC_REFS")
done

CONTENT="${HEADER}${MODELS}"
jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
MONGOOSE
chmod +x greenfield/scripts/render-db-mongoose.sh
```

- [ ] **Step 2: Lint + smoke**

```bash
shellcheck greenfield/scripts/render-db-mongoose.sh

# Smoke against minimal fixture
TMP=$(mktemp)
cat > "$TMP" <<'EOF'
{ "phases": {
    "domainModel": { "entities": [ { "name": "User", "attributes": [ {"name":"email","type":"string"} ] } ] },
    "privacy": { "piiFields": [{"path":"User.email","encryption":"at-rest"}] }
  }
}
EOF
OUT=$(bash greenfield/scripts/render-db-mongoose.sh "$TMP")
echo "$OUT" | jq -e '.content | contains("UserSchema")' || { echo "FAIL"; exit 1; }
echo "$OUT" | jq -e '.crossCheckWarnings | length == 0' || { echo "FAIL: unexpected warning"; exit 1; }
rm -f "$TMP"
echo "render-db-mongoose smoke OK"
```

Expected: shellcheck silent; smoke prints `OK`.

- [ ] **Step 3: Wire into `render-schema-drafts.sh` dispatch table**

Edit `greenfield/scripts/render-schema-drafts.sh`. Locate the `case "$ART:$LANG"` block. Add:

```bash
db:mongoose) MODULE="render-db-mongoose.sh" ;;
```

(Insert before the `*)` fallback case.)

- [ ] **Step 4: Commit**

```bash
git add greenfield/scripts/render-db-mongoose.sh greenfield/scripts/render-schema-drafts.sh
git commit -m "feat(greenfield): R6 — render-db-mongoose.sh + dispatch wiring (closes R5 O-R5-3 #1)"
```

---

### Task 6: `greenfield/scripts/render-db-drizzle.sh`

**Files:**
- Create: `greenfield/scripts/render-db-drizzle.sh`

- [ ] **Step 1: Write the renderer (Drizzle ORM TS schemas)**

Same skeleton as T5; type mapping table for Drizzle:

```bash
cat > greenfield/scripts/render-db-drizzle.sh <<'DRIZZLE'
#!/usr/bin/env bash
# render-db-drizzle.sh — R6 DB renderer (Drizzle ORM)
# Triggered when dataArchitecture.engine in {postgres,mysql,sqlite} AND language=drizzle.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-db-drizzle.sh <state-file>}"
ENTITIES=$(_validate_jq_path "$STATE_FILE" '.phases.domainModel.entities // []' false)
PII=$(_validate_jq_path "$STATE_FILE" '.phases.privacy.piiFields // []' false)
ENGINE=$(_validate_jq_path "$STATE_FILE" '.phases.dataArchitecture.engine // "postgres"' false)

case "$ENGINE" in
  postgres|postgresql) DRIZZLE_PKG="drizzle-orm/pg-core"; INT_TYPE="integer"; TEXT_TYPE="text"; TIMESTAMP_TYPE="timestamp" ;;
  mysql)               DRIZZLE_PKG="drizzle-orm/mysql-core"; INT_TYPE="int"; TEXT_TYPE="varchar"; TIMESTAMP_TYPE="datetime" ;;
  sqlite)              DRIZZLE_PKG="drizzle-orm/sqlite-core"; INT_TYPE="integer"; TEXT_TYPE="text"; TIMESTAMP_TYPE="integer" ;;
  *)                   DRIZZLE_PKG="drizzle-orm/pg-core"; INT_TYPE="integer"; TEXT_TYPE="text"; TIMESTAMP_TYPE="timestamp" ;;
esac

HEADER="// Generated by greenfield render-db-drizzle.sh — review and edit freely after lock.
import { pgTable, integer, text, boolean, timestamp } from '${DRIZZLE_PKG}';
"

MODELS=""
SRC_REFS="[]"
WARNINGS="[]"

ENTITY_COUNT=$(jq 'length' <<< "$ENTITIES")
for i in $(seq 0 $((ENTITY_COUNT - 1))); do
  E=$(jq ".[$i]" <<< "$ENTITIES")
  NAME=$(jq -r '.name // .id // "Unknown"' <<< "$E")
  TABLE_NAME=$(echo "$NAME" | tr 'A-Z' 'a-z')

  ATTRS=$(jq '.attributes // []' <<< "$E")
  A_COUNT=$(jq 'length' <<< "$ATTRS")
  FIELDS_BLOCK="  id: ${INT_TYPE}('id').primaryKey(),"
  for j in $(seq 0 $((A_COUNT - 1))); do
    AN=$(jq -r ".[$j].name // \"f${j}\"" <<< "$ATTRS")
    AT=$(jq -r ".[$j].type // \"String\"" <<< "$ATTRS")
    case "$AT" in
      string|String|text)     DT="text('${AN}')" ;;
      int|integer|Int)        DT="integer('${AN}')" ;;
      bool|boolean|Boolean)   DT="boolean('${AN}')" ;;
      date|datetime|DateTime) DT="timestamp('${AN}')" ;;
      *)                      DT="text('${AN}')" ;;
    esac
    FIELDS_BLOCK="${FIELDS_BLOCK}
  ${AN}: ${DT},"
    WARNINGS=$(_check_pii_encryption "${NAME}.${AN}" "$PII" "$WARNINGS")
  done

  MODELS="${MODELS}
export const ${TABLE_NAME} = pgTable('${TABLE_NAME}', {
${FIELDS_BLOCK}
});
"
  SRC_REFS=$(jq --arg n "$NAME" '. + [{path: ("domainModel.entities[name=" + $n + "]"), renderedAs: ("Drizzle table " + $n)}]' <<< "$SRC_REFS")
done

CONTENT="${HEADER}${MODELS}"
jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
DRIZZLE
chmod +x greenfield/scripts/render-db-drizzle.sh
```

- [ ] **Step 2: Lint + smoke + dispatch wire-up**

Same shape as T5. Lint:

```bash
shellcheck greenfield/scripts/render-db-drizzle.sh
```

Add dispatch line to `render-schema-drafts.sh`:

```bash
db:drizzle) MODULE="render-db-drizzle.sh" ;;
```

Smoke against fixture (use a Postgres-engine fixture, language=drizzle).

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-db-drizzle.sh greenfield/scripts/render-schema-drafts.sh
git commit -m "feat(greenfield): R6 — render-db-drizzle.sh + dispatch wiring (closes R5 O-R5-3 #2)"
```

---

### Task 7: `greenfield/scripts/render-api-trpc.sh`

**Files:**
- Create: `greenfield/scripts/render-api-trpc.sh`

- [ ] **Step 1: Write the renderer**

Renders tRPC router type definitions from `apiIntegration.endpoints[]`:

```bash
cat > greenfield/scripts/render-api-trpc.sh <<'TRPC'
#!/usr/bin/env bash
# render-api-trpc.sh — R6 API renderer (tRPC router types)
# Triggered when apiIntegration.style = trpc.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-api-trpc.sh <state-file>}"
ENDPOINTS=$(_validate_jq_path "$STATE_FILE" '.phases.apiIntegration.endpoints // []' false)

HEADER='// Generated by greenfield render-api-trpc.sh — review and edit freely after lock.
import { z } from "zod";
import { router, publicProcedure } from "./trpc";

export const appRouter = router({'

PROCS=""
SRC_REFS="[]"
WARNINGS="[]"

E_COUNT=$(jq 'length' <<< "$ENDPOINTS")
for i in $(seq 0 $((E_COUNT - 1))); do
  EP=$(jq ".[$i]" <<< "$ENDPOINTS")
  NAME=$(jq -r '.name // .id // ("op" + (.path // "" | gsub("/"; "_")))' <<< "$EP")
  TYPE=$(jq -r '.type // "query"' <<< "$EP")
  KIND=$([[ "$TYPE" == "mutation" ]] && echo "mutation" || echo "query")

  PROCS="${PROCS}
  ${NAME}: publicProcedure.input(z.object({})).${KIND}(({ input }) => {
    // implement
    return {};
  }),"
  SRC_REFS=$(jq --arg n "$NAME" '. + [{path: ("apiIntegration.endpoints[name=" + $n + "]"), renderedAs: ("tRPC " + "'"$KIND"'" + " " + $n)}]' <<< "$SRC_REFS")
done

[[ "$E_COUNT" -eq 0 ]] && WARNINGS=$(_emit_warning "info" "I-TRPC-empty" "No apiIntegration.endpoints[] — emitting empty router" "$WARNINGS")

CONTENT="${HEADER}${PROCS}
});

export type AppRouter = typeof appRouter;"

jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
TRPC
chmod +x greenfield/scripts/render-api-trpc.sh
```

- [ ] **Step 2: Lint + smoke + dispatch wire-up**

```bash
shellcheck greenfield/scripts/render-api-trpc.sh
```

Add `api:trpc) MODULE="render-api-trpc.sh" ;;` to `render-schema-drafts.sh` dispatch.

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-api-trpc.sh greenfield/scripts/render-schema-drafts.sh
git commit -m "feat(greenfield): R6 — render-api-trpc.sh + dispatch wiring (closes R5 O-R5-3 #3)"
```

---

### Task 8: `greenfield/scripts/render-api-hasura.sh`

**Files:**
- Create: `greenfield/scripts/render-api-hasura.sh`

- [ ] **Step 1: Write the renderer (Hasura metadata YAML)**

```bash
cat > greenfield/scripts/render-api-hasura.sh <<'HASURA'
#!/usr/bin/env bash
# render-api-hasura.sh — R6 API renderer (Hasura metadata + permissions YAML)
# Triggered when apiIntegration.style = hasura.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-api-hasura.sh <state-file>}"
ENTITIES=$(_validate_jq_path "$STATE_FILE" '.phases.domainModel.entities // []' false)
ROLES=$(_validate_jq_path "$STATE_FILE" '.phases.auth.roles // ["public","authenticated"]' false)

YAML="# Generated by greenfield render-api-hasura.sh — review and edit freely after lock.
version: 3
tables:
"
SRC_REFS="[]"
WARNINGS="[]"

E_COUNT=$(jq 'length' <<< "$ENTITIES")
for i in $(seq 0 $((E_COUNT - 1))); do
  E=$(jq ".[$i]" <<< "$ENTITIES")
  NAME=$(jq -r '.name // .id // "Unknown"' <<< "$E")
  TABLE_NAME=$(echo "$NAME" | tr 'A-Z' 'a-z')

  YAML="${YAML}  - table:
      schema: public
      name: ${TABLE_NAME}
    select_permissions:
"
  R_COUNT=$(jq 'length' <<< "$ROLES")
  for j in $(seq 0 $((R_COUNT - 1))); do
    ROLE=$(jq -r ".[$j]" <<< "$ROLES")
    YAML="${YAML}      - role: ${ROLE}
        permission:
          columns: '*'
          filter: {}
"
  done
  SRC_REFS=$(jq --arg n "$NAME" '. + [{path: ("domainModel.entities[name=" + $n + "]"), renderedAs: ("Hasura table " + $n)}]' <<< "$SRC_REFS")
done

jq -n --arg content "$YAML" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
HASURA
chmod +x greenfield/scripts/render-api-hasura.sh
```

- [ ] **Step 2: Lint + smoke + dispatch wire-up**

```bash
shellcheck greenfield/scripts/render-api-hasura.sh
```

Add `api:hasura) MODULE="render-api-hasura.sh" ;;` to dispatch.

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-api-hasura.sh greenfield/scripts/render-schema-drafts.sh
git commit -m "feat(greenfield): R6 — render-api-hasura.sh + dispatch wiring (closes R5 O-R5-3 #4)"
```

---

### Task 9: `greenfield/scripts/render-event-avro.sh`

**Files:**
- Create: `greenfield/scripts/render-event-avro.sh`

- [ ] **Step 1: Write the renderer (Avro schemas)**

```bash
cat > greenfield/scripts/render-event-avro.sh <<'AVRO'
#!/usr/bin/env bash
# render-event-avro.sh — R6 Event renderer (Apache Avro)
# Triggered when apiIntegration.asyncPattern in {kafka,kinesis} AND language=avro.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-event-avro.sh <state-file>}"
EVENTS=$(_validate_jq_path "$STATE_FILE" '.phases.domainModel.domainEvents // []' false)

SCHEMAS_ARRAY="["
SRC_REFS="[]"
WARNINGS="[]"

E_COUNT=$(jq 'length' <<< "$EVENTS")
for i in $(seq 0 $((E_COUNT - 1))); do
  EV=$(jq ".[$i]" <<< "$EVENTS")
  NAME=$(jq -r '.name // .id // ("Event" + ('"$i"'+1|tostring))' <<< "$EV")
  PAYLOAD=$(jq '.payload // []' <<< "$EV")

  FIELDS_JSON="["
  P_COUNT=$(jq 'length' <<< "$PAYLOAD")
  for j in $(seq 0 $((P_COUNT - 1))); do
    FN=$(jq -r ".[$j].name // \"f${j}\"" <<< "$PAYLOAD")
    FT=$(jq -r ".[$j].type // \"string\"" <<< "$PAYLOAD")
    case "$FT" in
      int|integer)    AT="int" ;;
      long)           AT="long" ;;
      bool|boolean)   AT="boolean" ;;
      float)          AT="float" ;;
      double|number)  AT="double" ;;
      bytes)          AT="bytes" ;;
      *)              AT="string" ;;
    esac
    [[ "$j" -gt 0 ]] && FIELDS_JSON="${FIELDS_JSON},"
    FIELDS_JSON="${FIELDS_JSON}{\"name\":\"${FN}\",\"type\":\"${AT}\"}"
  done
  FIELDS_JSON="${FIELDS_JSON}]"

  [[ "$i" -gt 0 ]] && SCHEMAS_ARRAY="${SCHEMAS_ARRAY},"
  SCHEMAS_ARRAY="${SCHEMAS_ARRAY}
  {\"type\":\"record\",\"name\":\"${NAME}\",\"namespace\":\"com.app.events\",\"fields\":${FIELDS_JSON}}"
  SRC_REFS=$(jq --arg n "$NAME" '. + [{path: ("domainModel.domainEvents[name=" + $n + "]"), renderedAs: ("Avro record " + $n)}]' <<< "$SRC_REFS")
done

SCHEMAS_ARRAY="${SCHEMAS_ARRAY}
]"

# Validate the assembled JSON is well-formed
echo "$SCHEMAS_ARRAY" | jq empty 2>/dev/null || WARNINGS=$(_emit_warning "error" "E-AVRO-JSON" "Assembled Avro schema array failed jq validation" "$WARNINGS")

CONTENT="// Generated by greenfield render-event-avro.sh — review and edit freely after lock.
${SCHEMAS_ARRAY}"

jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
AVRO
chmod +x greenfield/scripts/render-event-avro.sh
```

- [ ] **Step 2: Lint + smoke + dispatch wire-up**

```bash
shellcheck greenfield/scripts/render-event-avro.sh
```

Add `event:avro) MODULE="render-event-avro.sh" ;;` to dispatch.

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-event-avro.sh greenfield/scripts/render-schema-drafts.sh
git commit -m "feat(greenfield): R6 — render-event-avro.sh + dispatch wiring (closes R5 O-R5-3 #5)"
```

---

## Phase D — CI renderer family

### Task 10: `greenfield/scripts/render-ci-drafts.sh` (entrypoint)

**Files:**
- Create: `greenfield/scripts/render-ci-drafts.sh`

- [ ] **Step 1: Write the entrypoint**

```bash
cat > greenfield/scripts/render-ci-drafts.sh <<'CIENTRY'
#!/usr/bin/env bash
# render-ci-drafts.sh — R6 (Step 20) CI Draft Review entrypoint
#
# Reads phases.cicdAndDelivery.provider from the state file and dispatches to
# per-provider modules. Writes phases.cicdAndDelivery.draftYaml + draftWarnings
# atomically. Used by the wizard Step 20 synthesis-review to produce Panel 3.
#
# Approve writes the YAML to phases.cicdAndDelivery.lockedYaml; this script
# does NOT lock — that is the wizard's job after user Approve.
#
# Usage: render-ci-drafts.sh <state-file-path>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-drafts.sh <state-file>}"
[[ -f "$STATE_FILE" ]] || { echo "render-ci-drafts: state file not found: $STATE_FILE" >&2; exit 1; }

PROVIDER=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.provider // "gha"' true)

case "$PROVIDER" in
  gha|github-actions) MODULE="render-ci-gha.sh"; FALLBACK=false ;;
  gitlab|gitlab-ci)   MODULE="render-ci-gitlab.sh"; FALLBACK=false ;;
  circle|circleci)    MODULE="render-ci-circleci.sh"; FALLBACK=false ;;
  *)                  MODULE="render-ci-llm-fallback.sh"; FALLBACK=true ;;
esac

MODULE_PATH="${SCRIPT_DIR}/${MODULE}"
[[ -x "$MODULE_PATH" ]] || { echo "render-ci-drafts: missing module: $MODULE_PATH" >&2; exit 3; }

RENDER_OUT=$("$MODULE_PATH" "$STATE_FILE") || {
  echo "render-ci-drafts: module '$MODULE' failed for provider '$PROVIDER'" >&2
  exit 4
}

RENDERED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DRAFT_YAML=$(echo "$RENDER_OUT" | jq -r '.content // empty')
WARNINGS=$(echo "$RENDER_OUT" | jq '.crossCheckWarnings // []')
SOURCE_REFS=$(echo "$RENDER_OUT" | jq '.sourceRefs // []')

TMP="${STATE_FILE}.tmp.$$"
jq --arg yaml "$DRAFT_YAML" \
   --arg ts "$RENDERED_AT" \
   --argjson warnings "$WARNINGS" \
   --argjson srcRefs "$SOURCE_REFS" \
   --argjson fallback "$FALLBACK" \
   --arg provider "$PROVIDER" \
   '.phases.cicdAndDelivery.draftYaml = $yaml
    | .phases.cicdAndDelivery.draftRenderedAt = $ts
    | .phases.cicdAndDelivery.draftSourceRefs = $srcRefs
    | .phases.cicdAndDelivery.draftWarnings = $warnings
    | .phases.cicdAndDelivery.draftFallback = $fallback
    | .phases.cicdAndDelivery.draftProvider = $provider' \
   "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

echo "render-ci-drafts: completed for provider '$PROVIDER' (fallback=$FALLBACK)"
CIENTRY
chmod +x greenfield/scripts/render-ci-drafts.sh
```

- [ ] **Step 2: Lint**

```bash
shellcheck greenfield/scripts/render-ci-drafts.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-ci-drafts.sh
git commit -m "feat(greenfield): R6 — render-ci-drafts.sh CI renderer entrypoint with provider dispatch + LLM fallback"
```

---

### Task 11: `greenfield/scripts/render-ci-gha.sh`

**Files:**
- Create: `greenfield/scripts/render-ci-gha.sh`

Ports the existing inline GHA YAML emission (currently in `tooling-generation/SKILL.md` or `onboard/skills/generation/references/ci-cd-templates.md`) into a renderer module shape.

- [ ] **Step 1: Inspect current GHA YAML source**

```bash
grep -rln "name: CI\|on:\n  push:\|jobs:" onboard/skills/generation/references/ci-cd-templates.md greenfield/scripts/ 2>/dev/null | head -5
```

If a canonical GHA template lives in `onboard/skills/generation/references/ci-cd-templates.md`, port the YAML emission directly. Otherwise build it from the cicdAndDelivery spec:

- `.phases.cicdAndDelivery.cicd.stages[]` → job array (lint, typecheck, test, build, deploy)
- `.phases.cicdAndDelivery.cicd.matrix` → strategy.matrix
- `.phases.cicdAndDelivery.cicd.runners` → runs-on
- `.phases.cicdAndDelivery.cicd.deploy.environment` → environment

- [ ] **Step 2: Write the renderer**

```bash
cat > greenfield/scripts/render-ci-gha.sh <<'GHA'
#!/usr/bin/env bash
# render-ci-gha.sh — R6 CI renderer (GitHub Actions YAML)
# Reads phases.cicdAndDelivery and emits .github/workflows/ci.yml content.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-gha.sh <state-file>}"
CI=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery // {}' true)
FRAMEWORK=$(_validate_jq_path "$STATE_FILE" '.phases.architecturalFraming.frontendFramework // ""' false)
HAS_TS=$(_validate_jq_path "$STATE_FILE" '.phases.stack.language // "" | contains("typescript") | tostring' false)

STAGES=$(jq -r '.cicd.stages // ["lint","test","build"] | join(",")' <<< "$CI")
RUNNERS=$(jq -r '.cicd.runners // "ubuntu-latest"' <<< "$CI")
NODE_V=$(jq -r '.stack.nodeVersion // "20"' <<< "$CI")
DEPLOY_ENV=$(jq -r '.cicd.deploy.environment // ""' <<< "$CI")

WARNINGS="[]"

# Cross-checks
if [[ "$HAS_TS" != "true" ]] && jq -e '.cicd.stages // [] | index("typecheck")' <<< "$CI" >/dev/null 2>&1; then
  WARNINGS=$(_emit_warning "warn" "W-CI-GHA-typecheck" "Stage 'typecheck' enabled but stack.language does not include typescript" "$WARNINGS")
fi

YAML="# Generated by greenfield render-ci-gha.sh — review and edit freely after Approve.
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  build:
    runs-on: ${RUNNERS}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '${NODE_V}'
          cache: 'npm'
      - run: npm ci
"

IFS=',' read -ra STAGE_LIST <<< "$STAGES"
for stage in "${STAGE_LIST[@]}"; do
  case "$stage" in
    lint)      YAML="${YAML}      - run: npm run lint
" ;;
    typecheck) YAML="${YAML}      - run: npm run typecheck
" ;;
    test)      YAML="${YAML}      - run: npm test
" ;;
    build)     YAML="${YAML}      - run: npm run build
" ;;
  esac
done

if [[ -n "$DEPLOY_ENV" && "$DEPLOY_ENV" != "null" ]]; then
  YAML="${YAML}
  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ${RUNNERS}
    environment: ${DEPLOY_ENV}
    steps:
      - uses: actions/checkout@v4
      - run: echo \"Deploy step — configure per project (Vercel, AWS, etc.)\"
"
fi

SRC_REFS=$(jq -n '[{"path":"cicdAndDelivery.cicd","renderedAs":"GHA workflow"}]')
jq -n --arg content "$YAML" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
GHA
chmod +x greenfield/scripts/render-ci-gha.sh
```

- [ ] **Step 3: Lint**

```bash
shellcheck greenfield/scripts/render-ci-gha.sh
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/scripts/render-ci-gha.sh
git commit -m "feat(greenfield): R6 — render-ci-gha.sh (GHA YAML emission module)"
```

---

### Task 12: `greenfield/scripts/render-ci-gitlab.sh` (NEW)

**Files:**
- Create: `greenfield/scripts/render-ci-gitlab.sh`

- [ ] **Step 1: Write the GitLab CI renderer**

```bash
cat > greenfield/scripts/render-ci-gitlab.sh <<'GITLAB'
#!/usr/bin/env bash
# render-ci-gitlab.sh — R6 CI renderer (GitLab CI YAML)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-gitlab.sh <state-file>}"
CI=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery // {}' true)
NODE_V=$(jq -r '.stack.nodeVersion // "20"' <<< "$CI")
STAGES=$(jq -r '.cicd.stages // ["lint","test","build"] | join(" ")' <<< "$CI")
DEPLOY_ENV=$(jq -r '.cicd.deploy.environment // ""' <<< "$CI")

WARNINGS="[]"

YAML="# Generated by greenfield render-ci-gitlab.sh — review and edit freely after Approve.
image: node:${NODE_V}

stages:
"
for s in $STAGES; do YAML="${YAML}  - ${s}
"; done

cache="
cache:
  paths:
    - node_modules/
"

before="
before_script:
  - npm ci
"

YAML="${YAML}${cache}${before}"

for stage in $STAGES; do
  case "$stage" in
    lint)      cmd="npm run lint" ;;
    typecheck) cmd="npm run typecheck" ;;
    test)      cmd="npm test" ;;
    build)     cmd="npm run build" ;;
    *)         cmd="echo skip-${stage}" ;;
  esac
  YAML="${YAML}
${stage}:
  stage: ${stage}
  script:
    - ${cmd}
"
done

if [[ -n "$DEPLOY_ENV" && "$DEPLOY_ENV" != "null" ]]; then
  YAML="${YAML}
deploy:
  stage: deploy
  only:
    - main
  script:
    - echo \"Deploy to ${DEPLOY_ENV} — configure per project\"
  environment:
    name: ${DEPLOY_ENV}
"
fi

SRC_REFS=$(jq -n '[{"path":"cicdAndDelivery.cicd","renderedAs":"GitLab CI workflow"}]')
jq -n --arg content "$YAML" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
GITLAB
chmod +x greenfield/scripts/render-ci-gitlab.sh
```

- [ ] **Step 2: Lint**

```bash
shellcheck greenfield/scripts/render-ci-gitlab.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-ci-gitlab.sh
git commit -m "feat(greenfield): R6 — render-ci-gitlab.sh (GitLab CI YAML renderer)"
```

---

### Task 13: `greenfield/scripts/render-ci-circleci.sh` (NEW)

**Files:**
- Create: `greenfield/scripts/render-ci-circleci.sh`

- [ ] **Step 1: Write the CircleCI renderer**

```bash
cat > greenfield/scripts/render-ci-circleci.sh <<'CIRCLE'
#!/usr/bin/env bash
# render-ci-circleci.sh — R6 CI renderer (CircleCI config.yml)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-circleci.sh <state-file>}"
CI=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery // {}' true)
NODE_V=$(jq -r '.stack.nodeVersion // "20"' <<< "$CI")
STAGES=$(jq -r '.cicd.stages // ["lint","test","build"] | join(" ")' <<< "$CI")
DEPLOY_ENV=$(jq -r '.cicd.deploy.environment // ""' <<< "$CI")

WARNINGS="[]"

YAML="# Generated by greenfield render-ci-circleci.sh — review and edit freely after Approve.
version: 2.1

orbs:
  node: circleci/node@5

jobs:
  build:
    docker:
      - image: cimg/node:${NODE_V}
    steps:
      - checkout
      - node/install-packages
"
for stage in $STAGES; do
  case "$stage" in
    lint)      cmd="npm run lint" ;;
    typecheck) cmd="npm run typecheck" ;;
    test)      cmd="npm test" ;;
    build)     cmd="npm run build" ;;
    *)         cmd="echo skip-${stage}" ;;
  esac
  YAML="${YAML}      - run:
          name: ${stage}
          command: ${cmd}
"
done

YAML="${YAML}
workflows:
  ci:
    jobs:
      - build
"

if [[ -n "$DEPLOY_ENV" && "$DEPLOY_ENV" != "null" ]]; then
  YAML="${YAML}      - deploy:
          requires:
            - build
          filters:
            branches:
              only: main

  deploy:
    docker:
      - image: cimg/node:${NODE_V}
    environment:
      DEPLOY_ENV: ${DEPLOY_ENV}
    steps:
      - checkout
      - run: echo \"Deploy to \$DEPLOY_ENV — configure per project\"
"
fi

SRC_REFS=$(jq -n '[{"path":"cicdAndDelivery.cicd","renderedAs":"CircleCI workflow"}]')
jq -n --arg content "$YAML" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
CIRCLE
chmod +x greenfield/scripts/render-ci-circleci.sh
```

- [ ] **Step 2: Lint**

```bash
shellcheck greenfield/scripts/render-ci-circleci.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-ci-circleci.sh
git commit -m "feat(greenfield): R6 — render-ci-circleci.sh (CircleCI YAML renderer)"
```

---

### Task 14: `greenfield/scripts/render-ci-llm-fallback.sh` (NEW)

**Files:**
- Create: `greenfield/scripts/render-ci-llm-fallback.sh`

This renderer emits a stub with a hard `⚠ LLM draft — review carefully` banner; the wizard's Adjust path is the user-facing LLM edit loop. The shell module's job is to produce a syntactically reasonable starting YAML for the user to iterate on.

- [ ] **Step 1: Write the fallback renderer**

```bash
cat > greenfield/scripts/render-ci-llm-fallback.sh <<'LLMFB'
#!/usr/bin/env bash
# render-ci-llm-fallback.sh — R6 CI renderer (LLM fallback)
# Emits a starter stub when provider falls outside {gha, gitlab, circleci}.
# The Adjust loop in the wizard is the LLM-edit mechanism; this script only
# produces the initial structure + a hard banner forcing CHECK-R6-8 user ack.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=render-common.sh
source "${SCRIPT_DIR}/render-common.sh"

STATE_FILE="${1:?usage: render-ci-llm-fallback.sh <state-file>}"
PROVIDER=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.provider // "unknown"' true)
STAGES=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.cicd.stages // ["lint","test","build"]' false)
DEPLOY=$(_validate_jq_path "$STATE_FILE" '.phases.cicdAndDelivery.cicd.deploy.environment // ""' false)

WARNINGS="[]"
WARNINGS=$(_emit_warning "warn" "W-CI-LLM-fallback" "Provider '$PROVIDER' has no vetted renderer. Output is an LLM-fallback starter — review carefully and Adjust before Approve." "$WARNINGS")

STAGE_LIST=$(jq -r 'join(", ")' <<< "$STAGES")

CONTENT="# ⚠ LLM draft — review carefully
# Provider: ${PROVIDER}
# This is a starter stub. The wizard's Adjust path uses an LLM to edit this
# YAML based on your natural-language corrections. Cross-check before Approve.
#
# Detected stages: ${STAGE_LIST}
# Deploy target: ${DEPLOY:-none}

# ------------------------------------------------------------------------------
# TODO: Replace this stub with provider-specific YAML.
# Look up '${PROVIDER}' documentation for the canonical pipeline syntax.
# Map the detected stages onto your provider's job/step concept.
# ------------------------------------------------------------------------------

pipeline:
  stages: [${STAGE_LIST}]
  on_main_branch_deploy: '${DEPLOY:-none}'

# Reference: Each stage should run a matching script:
#   lint       → npm run lint
#   typecheck  → npm run typecheck
#   test       → npm test
#   build      → npm run build
#   deploy     → echo \"Deploy step — configure per project\"
"

# Pre-write YAML-lint stub: a real lint would call yq/yamllint; we surface
# any obviously broken structure here as an error-level warning.
if ! echo "$CONTENT" | grep -q "^pipeline:"; then
  WARNINGS=$(_emit_warning "error" "E-CI-LLM-lint" "LLM fallback YAML did not include the required 'pipeline:' root key" "$WARNINGS")
fi

SRC_REFS=$(jq -n --arg p "$PROVIDER" '[{"path":"cicdAndDelivery.provider","renderedAs":("LLM-fallback starter for " + $p)}]')
jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
LLMFB
chmod +x greenfield/scripts/render-ci-llm-fallback.sh
```

- [ ] **Step 2: Lint**

```bash
shellcheck greenfield/scripts/render-ci-llm-fallback.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-ci-llm-fallback.sh
git commit -m "feat(greenfield): R6 — render-ci-llm-fallback.sh (LLM fallback with banner + CHECK-R6-8 forcing ack)"
```

---

### Task 15: `ci-draft-review` synthesis template triple

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/ci-draft-review.html`
- Create: `greenfield/skills/synthesis-review/references/templates/ci-draft-review.md`
- Create: `greenfield/skills/synthesis-review/references/templates/ci-draft-review-dependencies.json.example`

- [ ] **Step 1: Author the HTML template (3 panels: Inputs / Decisions / Rendered YAML)**

```bash
cat > greenfield/skills/synthesis-review/references/templates/ci-draft-review.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>CI Draft Review — {{cicdAndDelivery.draftProvider}}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 1200px; margin: 2rem auto; padding: 0 1rem; }
    h1 { font-size: 1.5rem; }
    .grid { display: grid; grid-template-columns: 1fr 1fr 1.5fr; gap: 1rem; }
    .panel { border: 1px solid #ddd; padding: 1rem; border-radius: 4px; }
    .panel h2 { margin-top: 0; font-size: 1.1rem; }
    .warn-banner { background: #ffe9a3; border: 1px solid #c9941a; padding: 0.75rem; border-radius: 4px; margin: 1rem 0; }
    pre { background: #f6f8fa; padding: 0.75rem; overflow-x: auto; font-size: 0.85rem; }
    .warning { font-size: 0.9rem; padding: 0.5rem; border-radius: 3px; margin: 0.25rem 0; }
    .warning.error { background: #fee; border-left: 3px solid #d22; }
    .warning.warn  { background: #fff8e6; border-left: 3px solid #cc8800; }
    .warning.info  { background: #e8f4fa; border-left: 3px solid #2185d0; }
  </style>
</head>
<body>
  <h1>CI Draft Review — Step 20</h1>

  {{#if cicdAndDelivery.draftFallback}}
  <div class="warn-banner">
    ⚠ <strong>LLM draft — review carefully.</strong>
    Provider `{{cicdAndDelivery.draftProvider}}` has no vetted renderer module; this YAML was produced by the LLM-fallback path.
    CHECK-R6-8 requires you to mark warnings as <code>addressed=true</code> before Approve unlocks.
  </div>
  {{/if}}

  <div class="grid">
    <div class="panel">
      <h2>Panel 1 — Inputs</h2>
      <p><strong>Provider:</strong> {{cicdAndDelivery.draftProvider}}</p>
      <p><strong>Stages:</strong> {{cicdAndDelivery.cicd.stages}}</p>
      <p><strong>Runners:</strong> {{cicdAndDelivery.cicd.runners}}</p>
      <p><strong>Deploy:</strong> {{cicdAndDelivery.cicd.deploy.environment}}</p>
      <p><strong>Framework:</strong> {{architecturalFraming.frontendFramework}}</p>
      <p><strong>Stack:</strong> {{stack.language}}</p>
    </div>

    <div class="panel">
      <h2>Panel 2 — Decisions log</h2>
      <ul>
        {{#each cicdAndDelivery.adjustHistory}}
        <li><strong>{{this.at}}</strong>: {{this.instruction}}</li>
        {{/each}}
      </ul>
      <h3>Cross-check warnings</h3>
      {{#each cicdAndDelivery.draftWarnings}}
      <div class="warning {{this.level}}">
        [{{this.level}}] {{this.id}}: {{this.message}}
        {{#if this.addressed}}<em>(addressed)</em>{{/if}}
      </div>
      {{/each}}
    </div>

    <div class="panel">
      <h2>Panel 3 — Rendered YAML</h2>
      <pre>{{cicdAndDelivery.draftYaml}}</pre>
      <p><em>Rendered at: {{cicdAndDelivery.draftRenderedAt}}</em></p>
    </div>
  </div>

  <h2>Approve / Adjust / Reject</h2>
  <p>Pick one:</p>
  <ul>
    <li><strong>Approve:</strong> writes the YAML to <code>cicdAndDelivery.lockedYaml</code>; onboard generates verbatim at scaffold time.</li>
    <li><strong>Adjust:</strong> describe a correction in natural language; the LLM edits the YAML inline and re-renders Panel 3.</li>
    <li><strong>Reject:</strong> returns to Step 19 CI/CD to re-answer questions.</li>
  </ul>
</body>
</html>
HTML
```

- [ ] **Step 2: Author the Markdown mirror**

```bash
cat > greenfield/skills/synthesis-review/references/templates/ci-draft-review.md <<'MD'
# CI Draft Review — {{cicdAndDelivery.draftProvider}}

{{#if cicdAndDelivery.draftFallback}}
> ⚠ **LLM draft — review carefully.** Provider `{{cicdAndDelivery.draftProvider}}` has no vetted renderer module. CHECK-R6-8 requires every warning marked `addressed=true` before Approve.
{{/if}}

## Panel 1 — Inputs

- **Provider:** {{cicdAndDelivery.draftProvider}}
- **Stages:** {{cicdAndDelivery.cicd.stages}}
- **Runners:** {{cicdAndDelivery.cicd.runners}}
- **Deploy:** {{cicdAndDelivery.cicd.deploy.environment}}
- **Framework:** {{architecturalFraming.frontendFramework}}
- **Stack:** {{stack.language}}

## Panel 2 — Decisions log

{{#each cicdAndDelivery.adjustHistory}}
- **{{this.at}}**: {{this.instruction}}
{{/each}}

### Cross-check warnings

{{#each cicdAndDelivery.draftWarnings}}
- [{{this.level}}] **{{this.id}}**: {{this.message}}{{#if this.addressed}} _(addressed)_{{/if}}
{{/each}}

## Panel 3 — Rendered YAML

```yaml
{{cicdAndDelivery.draftYaml}}
```

_Rendered at: {{cicdAndDelivery.draftRenderedAt}}_

## Approve / Adjust / Reject

- **Approve:** writes the YAML to `cicdAndDelivery.lockedYaml`; onboard generates verbatim at scaffold time.
- **Adjust:** describe a correction in natural language; the LLM edits the YAML inline and re-renders Panel 3.
- **Reject:** returns to Step 19 CI/CD to re-answer questions.
MD
```

- [ ] **Step 3: Author the dependencies example**

```bash
cat > greenfield/skills/synthesis-review/references/templates/ci-draft-review-dependencies.json.example <<'DEPS'
{
  "schemaVersion": 1,
  "phase": "cicdAndDelivery",
  "recordedAt": "2026-05-15T00:00:00Z",
  "dependencies": [
    {
      "path": "stack.language",
      "value": "typescript",
      "rationale": "CI stages typecheck/lint depend on language detection"
    },
    {
      "path": "architecturalFraming.frontendFramework",
      "value": "next",
      "rationale": "Framework-specific build commands depend on framework choice"
    },
    {
      "path": "cicdAndDelivery.provider",
      "value": "gha",
      "rationale": "Provider selection determines renderer dispatch"
    }
  ]
}
DEPS
```

- [ ] **Step 4: Validate**

```bash
jq empty greenfield/skills/synthesis-review/references/templates/ci-draft-review-dependencies.json.example
grep -c '{{cicdAndDelivery' greenfield/skills/synthesis-review/references/templates/ci-draft-review.html
# Expected: ≥10
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/ci-draft-review.*
git commit -m "feat(greenfield): R6 — ci-draft-review synthesis template triple (3-panel review)"
```

---

## Phase E — Migration runner + pickup gate hardening

### Task 16: `greenfield/scripts/run-migrations.sh` (generic runner)

**Files:**
- Create: `greenfield/scripts/run-migrations.sh`

- [ ] **Step 1: Write the generic runner**

```bash
cat > greenfield/scripts/run-migrations.sh <<'RUNMIG'
#!/usr/bin/env bash
# run-migrations.sh — R6 generic migration runner
#
# Reads migration step modules from greenfield/skills/pickup/migrations/ and
# applies them sequentially from --from to --to. Supports --dry-run with JSON
# diff output. Each step reads JSON from stdin, writes migrated JSON to stdout,
# exits non-zero on failure (preserves original state).
#
# Usage:
#   run-migrations.sh --from alpha.6 --to alpha.7 --state-file .claude/greenfield-state.json
#   run-migrations.sh --from alpha.6 --to alpha.7 --state-file <path> --dry-run

set -euo pipefail

FROM=""
TO=""
STATE_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)       FROM="$2"; shift 2 ;;
    --to)         TO="$2"; shift 2 ;;
    --state-file) STATE_FILE="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    *)            echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${FROM:?--from is required}"
: "${TO:?--to is required}"
: "${STATE_FILE:?--state-file is required}"
[[ -f "$STATE_FILE" ]] || { echo "run-migrations: state file not found: $STATE_FILE" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve the pickup migrations directory relative to the script
MIG_DIR="$(cd "${SCRIPT_DIR}/../skills/pickup/migrations" && pwd)" || {
  echo "run-migrations: cannot resolve migrations directory" >&2; exit 3;
}

# Build the ordered chain from FROM to TO
declare -a CHAIN
case "$FROM:$TO" in
  alpha.3:alpha.7) CHAIN=("alpha-3-to-4" "alpha-4-to-5" "alpha-5-to-6" "alpha-6-to-7") ;;
  alpha.4:alpha.7) CHAIN=("alpha-4-to-5" "alpha-5-to-6" "alpha-6-to-7") ;;
  alpha.5:alpha.7) CHAIN=("alpha-5-to-6" "alpha-6-to-7") ;;
  alpha.6:alpha.7) CHAIN=("alpha-6-to-7") ;;
  alpha.3:alpha.6) CHAIN=("alpha-3-to-4" "alpha-4-to-5" "alpha-5-to-6") ;;
  alpha.4:alpha.6) CHAIN=("alpha-4-to-5" "alpha-5-to-6") ;;
  alpha.5:alpha.6) CHAIN=("alpha-5-to-6") ;;
  alpha.3:alpha.5) CHAIN=("alpha-3-to-4" "alpha-4-to-5") ;;
  alpha.4:alpha.5) CHAIN=("alpha-4-to-5") ;;
  alpha.3:alpha.4) CHAIN=("alpha-3-to-4") ;;
  *)               echo "run-migrations: no chain from $FROM to $TO" >&2; exit 4 ;;
esac

CURRENT=$(cat "$STATE_FILE")
ORIGINAL="$CURRENT"

for step in "${CHAIN[@]}"; do
  STEP_SCRIPT="${MIG_DIR}/${step}.sh"
  [[ -x "$STEP_SCRIPT" ]] || { echo "run-migrations: missing step: $STEP_SCRIPT" >&2; exit 5; }
  NEXT=$(echo "$CURRENT" | "$STEP_SCRIPT") || {
    echo "run-migrations: step '$step' failed; state unchanged" >&2
    exit 6
  }
  echo "$NEXT" | jq empty 2>/dev/null || {
    echo "run-migrations: step '$step' emitted invalid JSON; state unchanged" >&2
    exit 7
  }
  CURRENT="$NEXT"
done

if [[ "$DRY_RUN" == "true" ]]; then
  # Emit a JSON diff (paths that changed). Best effort — uses jq to compare.
  echo "$ORIGINAL" > /tmp/.migration-before.$$
  echo "$CURRENT"  > /tmp/.migration-after.$$
  echo "{"
  echo "  \"from\": \"$FROM\","
  echo "  \"to\":   \"$TO\","
  echo "  \"steps\": [$(printf '"%s",' "${CHAIN[@]}" | sed 's/,$//')]"
  echo ","
  echo "  \"diff\": $(diff <(echo "$ORIGINAL" | jq -S .) <(echo "$CURRENT" | jq -S .) | jq -Rs . 2>/dev/null || echo '""')"
  echo "}"
  rm -f /tmp/.migration-before.$$ /tmp/.migration-after.$$
  exit 0
fi

# Atomic write
TMP="${STATE_FILE}.tmp.$$"
echo "$CURRENT" > "$TMP" && mv "$TMP" "$STATE_FILE"
echo "run-migrations: applied chain [${CHAIN[*]}] to $STATE_FILE"
RUNMIG
chmod +x greenfield/scripts/run-migrations.sh
```

- [ ] **Step 2: Lint + verify chain table**

```bash
shellcheck greenfield/scripts/run-migrations.sh
grep -c 'CHAIN=(' greenfield/scripts/run-migrations.sh
# Expected: ≥10 (one per from:to pair plus the declare)
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/run-migrations.sh
git commit -m "feat(greenfield): R6 — run-migrations.sh generic runner with --dry-run + JSON diff"
```

---

### Task 17: Extract `alpha-3-to-4.sh` + `alpha-4-to-5.sh` from R4 inline cascade

**Files:**
- Create: `greenfield/skills/pickup/migrations/alpha-3-to-4.sh`
- Create: `greenfield/skills/pickup/migrations/alpha-4-to-5.sh`

- [ ] **Step 1: Locate the R4 inline cascade in `pickup/SKILL.md`**

```bash
grep -n "alpha\.4\|alpha\.5\|schemaVersion" greenfield/skills/pickup/SKILL.md | head -30
```

The inline shim lives around lines 27-100 (per current pickup/SKILL.md state). Extract the bash-equivalent logic for each step.

- [ ] **Step 2: Author `alpha-3-to-4.sh`**

```bash
mkdir -p greenfield/skills/pickup/migrations
cat > greenfield/skills/pickup/migrations/alpha-3-to-4.sh <<'A3'
#!/usr/bin/env bash
# alpha-3-to-4.sh — R6 extracted migration: alpha.3 (or unversioned) -> alpha.4
#
# Protocol: reads JSON from stdin, writes migrated JSON to stdout.
# Idempotent: re-running produces the same output.
# Exits non-zero on failure.

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-3-to-4: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Pre-R3 schemas predate the schemaVersion field. Bump to alpha.4 baseline.
# The R3 schema introduced auth/privacy/security/runtimeOperations phases.
# This migration only stamps the version; it does NOT retroactively populate
# R3 phases (those are user-walked, not auto-inferred).
echo "$INPUT" | jq --arg ts "$NOW" '
  .schemaVersion = "alpha.4"
  | .meta = (.meta // {})
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.3", to: "alpha.4"}]
'
A3
chmod +x greenfield/skills/pickup/migrations/alpha-3-to-4.sh
```

- [ ] **Step 3: Author `alpha-4-to-5.sh`**

```bash
cat > greenfield/skills/pickup/migrations/alpha-4-to-5.sh <<'A4'
#!/usr/bin/env bash
# alpha-4-to-5.sh — R6 extracted migration: alpha.4 -> alpha.5
#
# Mirrors the R4 inline logic in pickup/SKILL.md (the "State migration: alpha.4
# → alpha.5" section). Initializes Round 4 collections (personas, domainModel,
# risks) with safe defaults; sets mode flags to mid-session-safe values.

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-4-to-5: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$INPUT" | jq --arg ts "$NOW" '
  .schemaVersion = "alpha.5"
  | .mode = (.mode // {})
  | .mode.depth = (.mode.depth // "heavy")
  | .mode.coupling = (.mode.coupling // "hybrid")
  | .mode.domainFormat = (.mode.domainFormat // "ddd-lite")
  | .phaseStatus = (.phaseStatus // {})
  | .phaseStatus.personas = (.phaseStatus.personas // {status: "not-yet-walked", approvedAt: null, lastModified: $ts, staleReason: null})
  | .phaseStatus.domainModel = (.phaseStatus.domainModel // {status: "not-yet-walked", approvedAt: null, lastModified: $ts, staleReason: null})
  | .context = (.context // {})
  | .context.personas = (.context.personas // {primary: [], secondary: [], antiPersonas: []})
  | .context.domainModel = (.context.domainModel // {contexts: [], entities: [], valueObjects: [], domainEvents: [], crossContextRelationships: [], ubiquitousLanguage: [], antiCorruption: ""})
  | .context.risks = (.context.risks // [])
  | .context.phases = (.context.phases // {})
  | .context.phases.architecturalValidation = (.context.phases.architecturalValidation // {})
  | .context.phases.architecturalValidation.riskReconciliation = (.context.phases.architecturalValidation.riskReconciliation // {summary: {}, topFollowups: []})
  | .meta = (.meta // {})
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.4", to: "alpha.5"}]
'
A4
chmod +x greenfield/skills/pickup/migrations/alpha-4-to-5.sh
```

- [ ] **Step 4: Lint + smoke**

```bash
shellcheck greenfield/skills/pickup/migrations/alpha-{3,4}-to-*.sh

# Smoke: alpha.3 → alpha.4 → alpha.5 chain
echo '{}' | bash greenfield/skills/pickup/migrations/alpha-3-to-4.sh | bash greenfield/skills/pickup/migrations/alpha-4-to-5.sh | jq -e '.schemaVersion == "alpha.5"' || { echo "FAIL"; exit 1; }
echo "Chain smoke OK"
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/pickup/migrations/alpha-3-to-4.sh greenfield/skills/pickup/migrations/alpha-4-to-5.sh
git commit -m "feat(greenfield): R6 — extract alpha-3-to-4 + alpha-4-to-5 migration steps from inline pickup cascade"
```

---

### Task 18: Extract `alpha-5-to-6.sh` from R5 inline cascade

**Files:**
- Create: `greenfield/skills/pickup/migrations/alpha-5-to-6.sh`

- [ ] **Step 1: Locate the R5 inline shim**

```bash
grep -n "alpha.5 → alpha.6\|alpha-5-to-6\|state.meta.schemaVersion" greenfield/skills/pickup/SKILL.md
```

The shim lives around lines 114-128 of `pickup/SKILL.md` (per inspection). Port to a step module.

- [ ] **Step 2: Author the step**

```bash
cat > greenfield/skills/pickup/migrations/alpha-5-to-6.sh <<'A5'
#!/usr/bin/env bash
# alpha-5-to-6.sh — R6 extracted migration: alpha.5 -> alpha.6
#
# Initializes Round 5 phase blocks (featureRoadmap, schemaDraftReview) as
# {skipped: true} so onboard falls back to interactive handoff for sessions
# that predate alpha.6. Moves schemaVersion from top-level to .meta.

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-5-to-6: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REASON="Round 5 phase added 2026-05-15; pre-R5 sessions skip"

echo "$INPUT" | jq --arg ts "$NOW" --arg reason "$REASON" '
  .meta = (.meta // {})
  | .meta.schemaVersion = "alpha.6"
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.5", to: "alpha.6"}]
  | del(.schemaVersion)
  | .phases = (.phases // {})
  | .phases.featureRoadmap = (.phases.featureRoadmap // {skipped: true, deferredReason: $reason})
  | .phases.schemaDraftReview = (.phases.schemaDraftReview // {skipped: true, deferredReason: $reason})
'
A5
chmod +x greenfield/skills/pickup/migrations/alpha-5-to-6.sh
```

- [ ] **Step 3: Lint + smoke**

```bash
shellcheck greenfield/skills/pickup/migrations/alpha-5-to-6.sh

# Smoke: build the alpha.5 input, run the step, check alpha.6 output
echo '{"schemaVersion":"alpha.5","phases":{}}' | bash greenfield/skills/pickup/migrations/alpha-5-to-6.sh \
  | jq -e '.meta.schemaVersion == "alpha.6" and .phases.featureRoadmap.skipped == true' || { echo "FAIL"; exit 1; }
echo "alpha-5-to-6 smoke OK"
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/pickup/migrations/alpha-5-to-6.sh
git commit -m "feat(greenfield): R6 — extract alpha-5-to-6 migration step from R5 inline cascade"
```

---

### Task 19: Author `alpha-6-to-7.sh` (NEW R6 migration)

**Files:**
- Create: `greenfield/skills/pickup/migrations/alpha-6-to-7.sh`

This is the centerpiece R6 migration — handles 9 new phase defaults + 6 inline gate nulls + plugin split + lockedYaml + version bump.

- [ ] **Step 1: Author the step**

```bash
cat > greenfield/skills/pickup/migrations/alpha-6-to-7.sh <<'A6'
#!/usr/bin/env bash
# alpha-6-to-7.sh — R6 NEW migration: alpha.6 -> alpha.7
#
# 1. For each of the 9 new phases, insert {skipped: true} default.
# 2. For each of the 6 inline gates, write {needed: null, vendor: null}.
# 3. Split phases.pluginDiscovery -> phases.pluginRecommendation + phases.pluginInstall
#    (preserves resume state — copies installed[] forward, not resetting).
# 4. Add phases.cicdAndDelivery.lockedYaml = null + adjustHistory = [].
# 5. Update meta.schemaVersion = "alpha.7".

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-6-to-7: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REASON_R6="Round 6 phase added 2026-05-15; pre-R6 sessions skip"

echo "$INPUT" | jq --arg ts "$NOW" --arg reason "$REASON_R6" '
  # 1. Nine new phases default-skipped
  .phases = (.phases // {})
  | .phases.search                = (.phases.search                // {skipped: true, deferredReason: $reason})
  | .phases.caching               = (.phases.caching               // {skipped: true, deferredReason: $reason})
  | .phases.realtime              = (.phases.realtime              // {skipped: true, deferredReason: $reason})
  | .phases.fileUploads           = (.phases.fileUploads           // {skipped: true, deferredReason: $reason})
  | .phases.payments              = (.phases.payments              // {skipped: true, deferredReason: $reason})
  | .phases.frontendArchitecture  = (.phases.frontendArchitecture  // {skipped: true, deferredReason: $reason})
  | .phases.designSystem          = (.phases.designSystem          // {skipped: true, deferredReason: $reason})
  | .phases.uxAccessibilityPerf   = (.phases.uxAccessibilityPerf   // {skipped: true, deferredReason: $reason})
  | .phases.i18nL10n              = (.phases.i18nL10n              // {skipped: true, deferredReason: $reason})

  # If the legacy "frontend" stub exists, drop it (we renamed to frontendArchitecture)
  | (if .phases.frontend then del(.phases.frontend) else . end)

  # 2. Six inline gates default to {needed: null, vendor: null}
  | .phases.auth = (.phases.auth // {})
  | .phases.auth.concerns = (.phases.auth.concerns // {})
  | .phases.auth.concerns.transactionalEmail = (.phases.auth.concerns.transactionalEmail // {needed: null, vendor: null})
  | .phases.auth.concerns.sms                = (.phases.auth.concerns.sms                // {needed: null, vendor: null})

  | .phases.uxAccessibilityPerf.concerns = (.phases.uxAccessibilityPerf.concerns // {})
  | .phases.uxAccessibilityPerf.concerns.marketingEmail    = (.phases.uxAccessibilityPerf.concerns.marketingEmail    // {needed: null, vendor: null})
  | .phases.uxAccessibilityPerf.concerns.pushNotifications = (.phases.uxAccessibilityPerf.concerns.pushNotifications // {needed: null, vendor: null})
  | .phases.uxAccessibilityPerf.concerns.productAnalytics  = (.phases.uxAccessibilityPerf.concerns.productAnalytics  // {needed: null, vendor: null})

  | .phases.cicdAndDelivery = (.phases.cicdAndDelivery // {})
  | .phases.cicdAndDelivery.concerns = (.phases.cicdAndDelivery.concerns // {})
  | .phases.cicdAndDelivery.concerns.featureGating = (.phases.cicdAndDelivery.concerns.featureGating // {needed: null, vendor: null})

  # 3. Split pluginDiscovery -> pluginRecommendation + pluginInstall
  | (if .phases.pluginDiscovery then
       .phases.pluginRecommendation = {
         suggested: (.phases.pluginDiscovery.suggested // []),
         selected:  (.phases.pluginDiscovery.selected  // []),
         rationale: (.phases.pluginDiscovery.rationale // ""),
         frontendAddenda: []
       }
       | .phases.pluginInstall = {
           installed: (.phases.pluginDiscovery.installed // []),
           failed:    (.phases.pluginDiscovery.failed    // []),
           skipped:   (.phases.pluginDiscovery.skipped   // [])
         }
       | del(.phases.pluginDiscovery)
     else
       # Fresh state — initialize empty
       .phases.pluginRecommendation = (.phases.pluginRecommendation // {suggested: [], selected: [], rationale: "", frontendAddenda: []})
       | .phases.pluginInstall      = (.phases.pluginInstall      // {installed: [], failed: [], skipped: []})
     end)

  # 4. cicdAndDelivery.lockedYaml + adjustHistory
  | .phases.cicdAndDelivery.lockedYaml = (.phases.cicdAndDelivery.lockedYaml // null)
  | .phases.cicdAndDelivery.adjustHistory = (.phases.cicdAndDelivery.adjustHistory // [])

  # 5. Version bump + migration audit
  | .meta = (.meta // {})
  | .meta.schemaVersion = "alpha.7"
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.6", to: "alpha.7"}]
'
A6
chmod +x greenfield/skills/pickup/migrations/alpha-6-to-7.sh
```

- [ ] **Step 2: Lint + smoke**

```bash
shellcheck greenfield/skills/pickup/migrations/alpha-6-to-7.sh

# Smoke: alpha.6 input with pluginDiscovery -> verify split + 9 phases + 6 gates + lockedYaml
echo '{"meta":{"schemaVersion":"alpha.6"},"phases":{"pluginDiscovery":{"installed":["foo"],"suggested":["bar"]}}}' | \
  bash greenfield/skills/pickup/migrations/alpha-6-to-7.sh | jq -e '
    .meta.schemaVersion == "alpha.7"
    and (.phases.pluginRecommendation.suggested == ["bar"])
    and (.phases.pluginInstall.installed == ["foo"])
    and (.phases.pluginDiscovery == null)
    and (.phases.search.skipped == true)
    and (.phases.auth.concerns.sms.needed == null)
    and (.phases.cicdAndDelivery.lockedYaml == null)
  ' || { echo "FAIL"; exit 1; }
echo "alpha-6-to-7 smoke OK"
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/pickup/migrations/alpha-6-to-7.sh
git commit -m "feat(greenfield): R6 — alpha-6-to-7 migration step (9 phases + 6 gates + plugin split + lockedYaml)"
```

---

### Task 20: Refactor `pickup/SKILL.md` — use runner + harden `schemaVersion` gate

**Files:**
- Modify: `greenfield/skills/pickup/SKILL.md`

- [ ] **Step 1: Replace the inline migration cascade**

Locate the existing § State migration sections (lines ~12-130 of `pickup/SKILL.md`). Replace the entire cascade with this block:

````markdown
## State migration: invoke `run-migrations.sh`

**MANDATORY.** Runs at the very top of `/greenfield:pickup` (before resume detection, before Step 0 stale-check, before Step 1 / Step 1.5).

### Detect schemaVersion (legacy + canonical locations)

```bash
SCHEMA_VERSION=$(jq -r '.meta.schemaVersion // .schemaVersion // "unknown"' .claude/greenfield-state.json)
```

| Detected value | Action |
|---|---|
| `unknown` or `1` | Pre-R3 legacy state — invoke `run-migrations.sh --from alpha.3 --to alpha.7` |
| `"alpha.4"`      | R3 state — invoke `--from alpha.4 --to alpha.7` |
| `"alpha.5"`      | R4 state — invoke `--from alpha.5 --to alpha.7` |
| `"alpha.6"`      | R5 state — invoke `--from alpha.6 --to alpha.7` |
| `"alpha.7"`      | Already migrated; skip migration block |
| Any other value  | Halt with diagnostic — manual inspection required |

### Migration protocol (dry-run + approval + atomic write)

1. Invoke runner with `--dry-run` first; show the JSON diff to the user:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-migrations.sh" \
     --from "$SCHEMA_VERSION" --to alpha.7 \
     --state-file .claude/greenfield-state.json --dry-run > /tmp/migration-dry-run.json
   ```

2. Display the diff to the user via the synthesis-review skill (or plain stdout if synthesis-review isn't available). Ask via `AskUserQuestion`:
   - **Apply migration (Recommended)** — atomic write proceeds
   - **Inspect first** — surface the dry-run JSON in `.claude/migration-dry-run.json`; halt
   - **Cancel** — abort pickup

3. On Apply: invoke without `--dry-run`. Runner handles atomic temp + rename internally.

4. Append migration entry to `.claude/greenfield-meta.json.audit[]` (one entry per chain hop applied).
````

- [ ] **Step 2: Harden the schemaVersion gates throughout**

Find every gate that hard-codes `schemaVersion === "alpha.5"` or `"alpha.4"` in `pickup/SKILL.md` (Step 1.5, Step 2, Key Rules § Schema Version). Replace each with the unified detection:

```bash
SCHEMA_VERSION=$(jq -r '.meta.schemaVersion // .schemaVersion // "unknown"' "$STATE_FILE")
[[ "$SCHEMA_VERSION" == "alpha.7" ]] || { echo "Halt: schemaVersion is '$SCHEMA_VERSION'; expected 'alpha.7' (R6 + post-migration)" >&2; exit 2; }
```

The accepted set is `alpha.7` only (post-migration). Pre-alpha.7 values trigger the migration above before this gate runs.

Update § Schema Version Detection / Key Rules § Schema Version with the canonical pattern:

```markdown
- **Schema version detection accepts both legacy and canonical locations:**
  - Canonical (alpha.6+): `state.meta.schemaVersion`
  - Legacy (alpha.5 and below): `state.schemaVersion`
  - Detection: `jq -r '.meta.schemaVersion // .schemaVersion // "unknown"'`
```

- [ ] **Step 3: Remove the now-obsolete inline alpha.5→alpha.6 logic**

Delete the existing § Migration: alpha.5 → alpha.6 (Round 5) section (currently lines ~114-128). The logic now lives in `migrations/alpha-5-to-6.sh`.

- [ ] **Step 4: Validate**

```bash
# Ensure inline jq cascade is gone — no remaining alpha-N-to-M inline migration code
grep -E 'alpha\.[3-6]\s*->\s*alpha\.[4-7]|state\.schemaVersion\s*=\s*"alpha' greenfield/skills/pickup/SKILL.md | head -5
# Expected: empty
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/pickup/SKILL.md
git commit -m "refactor(greenfield): R6 — pickup uses run-migrations.sh + hardens schemaVersion gate (legacy + canonical)"
```

---

## Phase F — Q-banks for 9 new phases + 6 inline gates

> **Reference for ALL Q-bank tasks T21-T29:** Follow the structural pattern of `greenfield/skills/context-gathering/references/feature-roadmap.q-bank.md` (R5). Each Q-bank must have:
>
> - Header with `Round:`, `Steps:`, `Modes:` (Heavy/Light Q counts), `Coupling:` (reads/writes paths), `See also:` cross-references.
> - One ### entry per question: `type`, `options` (for enums), `showInLight` (bool), `isRiskCapture` (bool), `loopOver`+`loopMode` (for per-persona phases), `Prompt`, `Stores to: phases.<phase>.<field>`.
> - Trailing `Q_RISK` entry for inline risk capture (`isRiskCapture: true`, stores to `phases.<phase>.qRisks[]`).
>
> All `Stores to:` paths must match the field names in T1's context-shape-v2.json additions exactly.

### Task 21: `search.q-bank.md` (Step 7, flat, ~11 Heavy / ~6 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/search.q-bank.md`

- [ ] **Step 1: Author the file**

```bash
cat > greenfield/skills/context-gathering/references/search.q-bank.md <<'SEARCHQB'
# Search Q-bank — Step 7

> **Round:** 6 (Concern phase — between Data Architecture and API Integration)
> **Steps:** 7 (after dataArchitecture at Step 6, before apiIntegration at Step 8)
> **Modes:** Heavy ~11 Qs / Light ~6 Qs (drops S.Q5/S.Q6/S.Q8/S.Q10/S.Q11)
> **Coupling:** Reads `dataArchitecture.entities[]`. Writes `phases.search.*`. Output drives `lib/search.ts` + (Postgres FTS) `prisma/migrations/0002_search_indexes.sql`.
> **See also:** `data-architecture.q-bank.md`, design spec § Phase content / Q-bank shape

## Q-bank

### S.Q1 — Search type
- **type:** single-select
- **options:** ["fts", "vector", "hybrid", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Does the app need search? (FTS = keyword; vector = semantic; hybrid = both; none = skip the phase.)"
- **Stores to:** `phases.search.searchType`

### S.Q2 — Engine
- **type:** single-select
- **options:** ["postgres-fts", "meilisearch", "typesense", "elasticsearch", "opensearch", "pgvector", "pinecone", "weaviate", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which engine? (postgres-fts requires no new infra; meilisearch/typesense are managed; pgvector for hybrid stays in Postgres.)"
- **Stores to:** `phases.search.engine`

### S.Q3 — Index scope
- **type:** multi-select (dynamic from `dataArchitecture.entities[].id`)
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which entities are indexed?"
- **Stores to:** `phases.search.indexScope[]`

### S.Q4 — Update strategy
- **type:** single-select
- **options:** ["realtime", "batch", "hybrid"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Index update strategy? (realtime = write-through; batch = cron job; hybrid = critical-realtime + bulk-batch.)"
- **Stores to:** `phases.search.updateStrategy`

### S.Q5 — Query patterns
- **type:** multi-select
- **options:** ["filters", "facets", "autocomplete", "semantic", "ranking", "spelling"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Query patterns supported?"
- **Stores to:** `phases.search.queryPatterns[]`

### S.Q6 — Ranking
- **type:** long-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Ranking signals? (recency, popularity, custom score? — one paragraph.)"
- **Stores to:** `phases.search.ranking`

### S.Q7 — A/B testing
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "A/B test ranking strategies in production?"
- **Stores to:** `phases.search.abTesting`

### S.Q8 — RLS
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Search results respect row-level security?"
- **Stores to:** `phases.search.security.rls`

### S.Q9 — Query auth
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Search queries require authenticated user?"
- **Stores to:** `phases.search.security.queryAuth`

### S.Q10 — Index refresh interval
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "If batch: refresh interval? (e.g., 'every 5 min', 'nightly')"
- **Stores to:** `phases.search.refreshInterval` (free-form)

### S.Q_RISK — Search risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Prompt:** "Search-related risks? (e.g., 'index drift between source-of-truth and search index', 'vector embedding cost spikes')"
- **Stores to:** `phases.search.qRisks[]` + appends to top-level `risks[]` with `phase: "search"`
SEARCHQB
```

- [ ] **Step 2: Validate field paths**

```bash
grep -E '^- \*\*Stores to:' greenfield/skills/context-gathering/references/search.q-bank.md | sort -u | head -20
# Expected: all paths start with phases.search.
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/context-gathering/references/search.q-bank.md
git commit -m "feat(greenfield): R6 — search.q-bank.md (Step 7, 11 Qs heavy)"
```

---

### Task 22: `caching.q-bank.md` (Step 9, flat, ~12 Heavy / ~7 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/caching.q-bank.md`

- [ ] **Step 1: Author the file**

Follow T21's structural pattern. Header:

```markdown
# Caching Q-bank — Step 9

> **Round:** 6 (Concern phase — after API Integration)
> **Steps:** 9 (after apiIntegration at Step 8, before realtime at Step 10)
> **Modes:** Heavy ~12 Qs / Light ~7 Qs
> **Coupling:** Reads `architecturalFraming.frontendFramework`, `dataArchitecture.engine`. Writes `phases.caching.*`. Drives `lib/cache.ts` + framework-conditional CDN headers.
```

Questions (each with type, options, showInLight, isRiskCapture, prompt, Stores to):

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| C.Q1 | multi-select | `["cdn", "edge", "app", "db-query", "browser"]` | true | `phases.caching.layers[]` |
| C.Q2 | single-select | `["cloudflare", "fastly", "vercel-edge", "cloudfront", "akamai", "none"]` | true | `phases.caching.cdnProvider` |
| C.Q3 | single-select | `["ttl", "tag-based", "manual", "hybrid"]` | true | `phases.caching.invalidationStrategy` |
| C.Q4 | yes/no | — | true | `phases.caching.staleWhileRevalidate` |
| C.Q5 | long-text | — | false | `phases.caching.keyDesign` |
| C.Q6 | yes/no | — | false | `phases.caching.multiTenantIsolation` |
| C.Q7 | yes/no | — | true | `phases.caching.observability.hitRates` |
| C.Q8 | yes/no | — | false | `phases.caching.observability.alertOnDrop` |
| C.Q9 | single-select | `["lock", "request-coalescing", "swr", "none"]` | true | `phases.caching.stampedeProtection` |
| C.Q10 | short-text | — | false | `phases.caching.defaultTtl` (free-form) |
| C.Q11 | yes/no | — | true | `phases.caching.warmupOnDeploy` |
| C.Q_RISK | bulleted free-text | — | true | `phases.caching.qRisks[]` |

Use the same per-question structure as T21 — render each as a `### ID` block with all 6 fields populated.

- [ ] **Step 2: Commit**

```bash
git add greenfield/skills/context-gathering/references/caching.q-bank.md
git commit -m "feat(greenfield): R6 — caching.q-bank.md (Step 9, 12 Qs heavy)"
```

---

### Task 23: `realtime.q-bank.md` (Step 10, per-persona, ~12 Heavy / ~6 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/realtime.q-bank.md`

Header notes: `Auto-loop: per-persona (loopOver: personas.primary, loopMode: per-persona)`. CHECK-R6-9 caps iterations at `min(personas.length, 4)`.

Questions table:

| ID | type | options | showInLight | loopOver | Stores to |
|---|---|---|---|---|---|
| RT.Q1 | single-select | `["sse", "websocket", "long-poll", "push", "none"]` | true | — | `phases.realtime.transport` |
| RT.Q2 | multi-select | `["notifications", "presence", "collaboration", "live-data", "chat", "telemetry"]` | true | `personas.primary` | `phases.realtime.useCases[]` (per-persona — flattens to union) |
| RT.Q3 | single-select | `["redis-pubsub", "dedicated-service", "channels", "broker", "none"]` | true | — | `phases.realtime.backend` |
| RT.Q4 | single-select | `["pusher", "ably", "soketi", "centrifugo", "native", "none"]` | false | — | `phases.realtime.clientLib` |
| RT.Q5 | yes/no | — | false | — | `phases.realtime.scaling.stickySessions` |
| RT.Q6 | yes/no | — | true | — | `phases.realtime.scaling.horizontal` |
| RT.Q7 | single-select | `["exponential-backoff", "fixed-interval", "manual", "none"]` | true | — | `phases.realtime.reconnectStrategy` |
| RT.Q8 | single-select | `["per-channel", "global", "best-effort"]` | false | — | `phases.realtime.messageOrdering` |
| RT.Q9 | yes/no | — | false | — | `phases.realtime.dedup` |
| RT.Q10 | short-text | — | false | — | `phases.realtime.heartbeatInterval` (free-form) |
| RT.Q11 | yes/no | — | true | — | `phases.realtime.gracefulDegradation` |
| RT.Q_RISK | bulleted free-text | — | true | — | `phases.realtime.qRisks[]` |

- [ ] **Step 1: Author the file using T21's structural pattern**

- [ ] **Step 2: Commit**

```bash
git add greenfield/skills/context-gathering/references/realtime.q-bank.md
git commit -m "feat(greenfield): R6 — realtime.q-bank.md (Step 10, 12 Qs heavy, per-persona)"
```

---

### Task 24: `file-uploads.q-bank.md` (Step 13, per-persona, ~13 Heavy / ~7 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/file-uploads.q-bank.md`

Header: `Coupling: Reads personas.primary[], privacy.piiFields[]. Writes phases.fileUploads.*. Drives lib/uploads.ts + S3/R2 IAM policy + MIME allowlist.`

Questions:

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| FU.Q1 | single-select | `["s3", "r2", "gcs", "azure-blob", "local", "none"]` | true | `phases.fileUploads.storageBackend` |
| FU.Q2 | single-select | `["signed-url", "direct", "server-proxied", "multipart-resumable"]` | true | `phases.fileUploads.uploadFlow` |
| FU.Q3 | short-text | — | false | `phases.fileUploads.cdnProvider` |
| FU.Q4 | single-select | `["imgix", "cloudinary", "native", "none"]` | false | `phases.fileUploads.imageTransforms` |
| FU.Q5 | short-text | — | true | `phases.fileUploads.maxFileSize` |
| FU.Q6 | multi-select free-text | — | true | `phases.fileUploads.mimeAllowlist[]` |
| FU.Q7 | yes/no | — | true | `phases.fileUploads.virusScanning` |
| FU.Q8 | single-select | `["encrypted-at-rest", "field-level-encryption", "kms-keys", "none"]` | true | `phases.fileUploads.piiHandling` |
| FU.Q9 | short-text | — | false | `phases.fileUploads.retentionPolicy` |
| FU.Q10 | yes/no | — | false | `phases.fileUploads.multiTenantIsolation` |
| FU.Q11 | per-persona | upload-surface description | true (loopOver: `personas.primary`) | `phases.fileUploads.uploadSurfacesByPersona` |
| FU.Q12 | yes/no | — | false | `phases.fileUploads.signedUrlExpiry` (default 5min) |
| FU.Q13 | yes/no | — | false | `phases.fileUploads.allowOverwrite` |
| FU.Q_RISK | bulleted free-text | — | true | `phases.fileUploads.qRisks[]` |

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/context-gathering/references/file-uploads.q-bank.md
git commit -m "feat(greenfield): R6 — file-uploads.q-bank.md (Step 13, 13 Qs heavy, per-persona)"
```

---

### Task 25: `payments.q-bank.md` (Step 15, per-persona customer/admin, ~14 Heavy / ~7 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/payments.q-bank.md`

Header: `Coupling: Reads personas.primary[], privacy (PCI scope), security. Writes phases.payments.*. CHECK-R6-3: payments populated ⟹ privacy.pii.financial=true.`

Questions:

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| P.Q1 | single-select | `["stripe", "lemon-squeezy", "paddle", "razorpay", "braintree", "none"]` | true | `phases.payments.provider` |
| P.Q2 | single-select | `["one-time", "subscription", "usage-based", "marketplace", "hybrid"]` | true | `phases.payments.billingModel` |
| P.Q3 | yes/no | — | true | `phases.payments.customerPortal` |
| P.Q4 | single-select | `["provider-managed", "self-managed", "none"]` | true | `phases.payments.taxHandling` |
| P.Q5 | single-select | `["provider", "custom", "none"]` | false | `phases.payments.dunning` |
| P.Q6 | single-select | `["per-event", "fanout", "queue", "none"]` | false | `phases.payments.webhookStrategy` |
| P.Q7 | single-select | `["provider-builtin", "sift", "stripe-radar", "custom", "none"]` | false | `phases.payments.fraudPrevention` |
| P.Q8 | single-select | `["self-serve", "admin-approval", "manual", "none"]` | true | `phases.payments.refundFlow` |
| P.Q9 | multi-select (locales) | — | false | `phases.payments.currencyLocale[]` |
| P.Q10 | single-select | `["saq-a", "saq-a-ep", "saq-d", "none"]` | true | `phases.payments.compliance.pciScope` |
| P.Q11 | yes/no | — | true | `phases.payments.compliance.sca` |
| P.Q12 | multi-select free-text | — | false | `phases.payments.compliance.regulatory[]` |
| P.Q13 | per-persona surface (customer vs admin) | — | true (loopOver: `personas.primary`) | `phases.payments.surfacesByPersona` |
| P.Q14 | short-text | — | false | `phases.payments.trialDuration` |
| P.Q_RISK | bulleted free-text | — | true | `phases.payments.qRisks[]` |

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/context-gathering/references/payments.q-bank.md
git commit -m "feat(greenfield): R6 — payments.q-bank.md (Step 15, 14 Qs heavy, per-persona)"
```

---

### Task 26: `frontend-architecture.q-bank.md` (Step 22, P5, per-persona, ~13 Heavy / ~7 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/frontend-architecture.q-bank.md`

Header: `Coupling: Reads architecturalFraming.frontendFramework (CHECK-R6-4 = match), personas.primary[]. Writes phases.frontendArchitecture.*. Drives package.json deps + lib/store.ts + lib/queries.ts.`

Questions:

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| FA.Q1 | confirm (cross-ref) | reads `architecturalFraming.frontendFramework`; user confirms | true | `phases.frontendArchitecture.frameworkConfirmed` |
| FA.Q2 | single-select | `["builtin-only", "redux", "zustand", "jotai", "mobx", "recoil", "valtio", "none"]` | true | `phases.frontendArchitecture.stateManagement` |
| FA.Q3 | single-select | `["app-router", "pages-router", "react-router", "tanstack-router", "remix", "vue-router", "none"]` | true | `phases.frontendArchitecture.routingStrategy` |
| FA.Q4 | single-select | `["fetch", "tanstack-query", "swr", "rtk-query", "apollo", "urql", "trpc-client", "none"]` | true | `phases.frontendArchitecture.dataFetching` |
| FA.Q5 | single-select | `["react-hook-form", "formik", "tanstack-form", "uncontrolled", "none"]` | false | `phases.frontendArchitecture.formHandling` |
| FA.Q6 | single-select | `["framer-motion", "react-spring", "auto-animate", "css-only", "none"]` | false | `phases.frontendArchitecture.animationLibrary` |
| FA.Q7 | single-select | `["per-route", "per-feature", "global-only", "none"]` | false | `phases.frontendArchitecture.errorBoundaries` |
| FA.Q8 | single-select | `["route-level", "component-lazy", "manual", "none"]` | false | `phases.frontendArchitecture.codeSplitting` |
| FA.Q9 | single-select | `["turbopack", "vite", "webpack", "rspack", "esbuild", "rollup", "parcel", "none"]` | true | `phases.frontendArchitecture.bundler` |
| FA.Q10 | short-text | — | false | `phases.frontendArchitecture.devServer` |
| FA.Q11 | yes/no | — | false | `phases.frontendArchitecture.ssr` (free-form) |
| FA.Q12 | yes/no | — | false | `phases.frontendArchitecture.staticGeneration` |
| FA.Q13 | per-persona feature surfaces | — | true | `phases.frontendArchitecture.featureSurfacesByPersona` |
| FA.Q_RISK | bulleted free-text | — | true | `phases.frontendArchitecture.qRisks[]` |

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/context-gathering/references/frontend-architecture.q-bank.md
git commit -m "feat(greenfield): R6 — frontend-architecture.q-bank.md (Step 22, P5, 13 Qs heavy, per-persona)"
```

---

### Task 27: `design-system.q-bank.md` (Step 23, P5.3, flat, ~12 Heavy / ~6 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/design-system.q-bank.md`

Header: `Coupling: Reads frontendArchitecture.frameworkConfirmed. Writes phases.designSystem.*. Drives shadcn init / MUI theme / Mantine provider + tailwind.config.ts tokens.`

Questions:

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| DS.Q1 | single-select | `["shadcn", "mui", "mantine", "chakra", "ant", "headless-ui", "custom", "none"]` | true | `phases.designSystem.componentLibrary` |
| DS.Q2 | single-select | `["css-variables", "tokens", "css-in-js", "tailwind-config", "multiple-themes"]` | true | `phases.designSystem.themingApproach` |
| DS.Q3 | single-select | `["radix", "react-aria", "ariakit", "headless-ui", "custom", "none"]` | false | `phases.designSystem.primitivesStrategy` |
| DS.Q4 | single-select | `["cva", "tv", "stitches", "panda-recipes", "none"]` | false | `phases.designSystem.variantSystem` |
| DS.Q5 | single-select | `["lucide", "heroicons", "phosphor", "tabler", "iconify", "custom", "none"]` | true | `phases.designSystem.iconSystem` |
| DS.Q6 | short-text | — | false | `phases.designSystem.typographyScale` |
| DS.Q7 | short-text | — | true | `phases.designSystem.colorSystem` |
| DS.Q8 | short-text | — | false | `phases.designSystem.spacingTokens` |
| DS.Q9 | single-select | `["figma", "penpot", "sketch", "none"]` | false | `phases.designSystem.designToolIntegration` |
| DS.Q10 | yes/no | — | true | `phases.designSystem.storybookAdopted` |
| DS.Q11 | yes/no | — | false | `phases.designSystem.darkModeSupported` (free-form, stored in `phases.designSystem.darkMode`) |
| DS.Q12 | short-text | — | false | `phases.designSystem.brandGuidelinesLink` |
| DS.Q_RISK | bulleted free-text | — | true | `phases.designSystem.qRisks[]` |

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/context-gathering/references/design-system.q-bank.md
git commit -m "feat(greenfield): R6 — design-system.q-bank.md (Step 23, P5.3, 12 Qs heavy)"
```

---

### Task 28: `ux-accessibility-perf.q-bank.md` (Step 24, P5.6, per-persona, ~15 Heavy / ~8 Light) — HOSTS 3 INLINE GATES

**Files:**
- Create: `greenfield/skills/context-gathering/references/ux-accessibility-perf.q-bank.md`

Header: `Coupling: Reads personas.primary[], frontendArchitecture.frameworkConfirmed. Writes phases.uxAccessibilityPerf.* + phases.uxAccessibilityPerf.concerns.{marketingEmail,pushNotifications,productAnalytics}. CHECK-R6-5: surfacesByPersona maps every personaId to ≥1 surface.`

Questions:

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| UX.Q1 | per-persona surfaces multi-select | `["web-app", "mobile-web", "native", "admin-dashboard"]` | true | `phases.uxAccessibilityPerf.surfacesByPersona[<personaId>]` |
| UX.Q2 | single-select | `["mobile-first", "desktop-first", "adaptive", "responsive"]` | true | `phases.uxAccessibilityPerf.responsivenessStrategy` |
| UX.Q3 | short-text | — | false | `phases.uxAccessibilityPerf.breakpointSystem` |
| UX.Q4 | single-select | `["wcag-a", "wcag-aa", "wcag-aaa", "none"]` | true | `phases.uxAccessibilityPerf.a11yTarget` |
| UX.Q5 | single-select | `["full", "partial", "none"]` | true | `phases.uxAccessibilityPerf.keyboardNavigation` |
| UX.Q6 | single-select | `["axe", "manual", "lighthouse", "none"]` | false | `phases.uxAccessibilityPerf.screenReaderTesting` |
| UX.Q7 | numeric | LCP seconds | true | `phases.uxAccessibilityPerf.performanceBudgets.lcp` |
| UX.Q8 | numeric | INP ms | false | `phases.uxAccessibilityPerf.performanceBudgets.inp` |
| UX.Q9 | numeric | CLS | false | `phases.uxAccessibilityPerf.performanceBudgets.cls` |
| UX.Q10 | single-select | `["next-image", "imgix", "cloudinary", "native", "none"]` | true | `phases.uxAccessibilityPerf.imageOptimization` |
| UX.Q11 | single-select | `["next-font", "font-display-swap", "preload", "none"]` | false | `phases.uxAccessibilityPerf.fontLoading` |
| UX.Q12 | short-text | error UX | true | `phases.uxAccessibilityPerf.stateUx.error` |
| UX.Q13 | short-text | empty UX | false | `phases.uxAccessibilityPerf.stateUx.empty` |
| UX.Q14 | short-text | loading UX | false | `phases.uxAccessibilityPerf.stateUx.loading` |
| UX.Q15 | yes/no | — | true | `phases.uxAccessibilityPerf.offlineSupport` |

**Inline gates** (this is the host phase for 3 of the 6 inline gates):

### Gate.MktEmail — Marketing email gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["customer-io", "loops", "resend-audiences", "mailchimp"]`
- **showInLight:** true
- **Prompt:** "Will you send marketing email (drip campaigns, broadcasts)? If yes, which vendor?"
- **Stores to:** `phases.uxAccessibilityPerf.concerns.marketingEmail = {needed, vendor?}`

### Gate.Push — Push notifications gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["fcm", "onesignal", "pusher-beams"]`
- **showInLight:** true
- **Prompt:** "Will you send push notifications (mobile/web)? If yes, which vendor?"
- **Stores to:** `phases.uxAccessibilityPerf.concerns.pushNotifications = {needed, vendor?}`

### Gate.Analytics — Product analytics gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["posthog", "mixpanel", "amplitude", "plausible"]`
- **showInLight:** true
- **Prompt:** "Will you instrument product analytics (funnels, retention)? If yes, which vendor?"
- **Stores to:** `phases.uxAccessibilityPerf.concerns.productAnalytics = {needed, vendor?}`

### UX.Q_RISK — UX/A11y/Perf risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Stores to:** `phases.uxAccessibilityPerf.qRisks[]` + appends to `risks[]`

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/context-gathering/references/ux-accessibility-perf.q-bank.md
git commit -m "feat(greenfield): R6 — ux-accessibility-perf.q-bank.md (Step 24, P5.6, 15 Qs heavy, per-persona, hosts 3 gates)"
```

---

### Task 29: `i18n-l10n.q-bank.md` (Step 25, flat, ~11 Heavy / ~6 Light)

**Files:**
- Create: `greenfield/skills/context-gathering/references/i18n-l10n.q-bank.md`

Header: `Coupling: Reads frontendArchitecture.frameworkConfirmed. Writes phases.i18nL10n.*. Drives lib/i18n.ts + messages/en.json + next.config.ts i18n routing.`

Questions:

| ID | type | options | showInLight | Stores to |
|---|---|---|---|---|
| I.Q1 | multi-select free-text (locale codes) | — | true | `phases.i18nL10n.targetLocales[]` |
| I.Q2 | single-select | `["manual", "ai-assisted", "hybrid", "none"]` | true | `phases.i18nL10n.translationSource` |
| I.Q3 | single-select | `["next-intl", "react-i18next", "formatjs", "lingui", "native-intl", "none"]` | true | `phases.i18nL10n.library` |
| I.Q4 | single-select | `["json", "po", "xliff", "yaml"]` | false | `phases.i18nL10n.fileFormat` |
| I.Q5 | yes/no | — | true | `phases.i18nL10n.rtlSupport` |
| I.Q6 | single-select | `["intl-api", "library-helper", "custom"]` | false | `phases.i18nL10n.dateNumberFormatting` |
| I.Q7 | yes/no | — | false | `phases.i18nL10n.pluralRules` |
| I.Q8 | short-text | — | false | `phases.i18nL10n.contentTranslationFlow` |
| I.Q9 | single-select | `["bundled", "cdn", "lazy"]` | false | `phases.i18nL10n.delivery` |
| I.Q10 | single-select | `["static", "dynamic", "hybrid"]` | false | `phases.i18nL10n.textType` |
| I.Q11 | yes/no | — | true | `phases.i18nL10n.seoHreflang` |
| I.Q_RISK | bulleted free-text | — | true | `phases.i18nL10n.qRisks[]` |

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/context-gathering/references/i18n-l10n.q-bank.md
git commit -m "feat(greenfield): R6 — i18n-l10n.q-bank.md (Step 25, 11 Qs heavy)"
```

---

### Task 30: Append 3 inline-gate Q snippets to existing Q-banks (auth + cicd)

**Files:**
- Modify: `greenfield/skills/context-gathering/references/auth.q-bank.md`
- Modify: `greenfield/skills/context-gathering/references/cicd.q-bank.md`

Note: T28 already added 3 gates (marketing email, push, analytics) to `ux-accessibility-perf.q-bank.md` as part of authoring that file. This task adds the remaining 3 inline gates to their host Q-banks.

- [ ] **Step 1: Append `Gate.TransEmail` + `Gate.SMS` to `auth.q-bank.md`**

Find the end of `auth.q-bank.md` (after the existing A.Q_RISK entry if present, or after the last A.QN). Append:

```markdown

## Inline gates (R6)

### Gate.TransEmail — Transactional email gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["resend", "postmark", "ses", "sendgrid"]`
- **showInLight:** true
- **Prompt:** "Will the app send transactional emails (password reset, magic links, verification)? If yes, which vendor?"
- **Stores to:** `phases.auth.concerns.transactionalEmail = {needed, vendor?}`

### Gate.SMS — SMS gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["twilio", "vonage", "messagebird"]`
- **showInLight:** true
- **Prompt:** "Will the app send SMS (2FA, OTP, account alerts)? If yes, which vendor?"
- **Stores to:** `phases.auth.concerns.sms = {needed, vendor?}`
```

- [ ] **Step 2: Append `Gate.FeatureGating` to `cicd.q-bank.md`**

Find the end of `cicd.q-bank.md`. Append:

```markdown

## Inline gates (R6)

### Gate.FeatureGating — Feature gating gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["posthog-flags", "launchdarkly", "flagsmith", "growthbook"]`
- **showInLight:** true
- **Prompt:** "Will the release pipeline integrate feature flags / gating? If yes, which vendor?"
- **Stores to:** `phases.cicdAndDelivery.concerns.featureGating = {needed, vendor?}`

## CI Draft Review hook (R6 Step 20)

After this Q-bank completes (Step 19 CI/CD), the wizard fires `${CLAUDE_PLUGIN_ROOT}/scripts/render-ci-drafts.sh` mid-flow. The output populates `phases.cicdAndDelivery.draftYaml` and the wizard advances to Step 20 CI Draft Review (synthesis-review skill renders the 3-panel HTML at `templates/ci-draft-review.html`).
```

- [ ] **Step 3: Update `question-bank.md` appendix**

Find the existing Round 4/5 phase reference appendix in `question-bank.md`. Append a Round 6 appendix listing the 9 new Q-banks + 6 gate locations:

```markdown
## Round 6 — 9 new phase Q-banks + 6 inline gates

| Phase | Q-bank file | Step | Host (gates only) |
|---|---|---|---|
| search | `search.q-bank.md` | 7 | — |
| caching | `caching.q-bank.md` | 9 | — |
| realtime | `realtime.q-bank.md` | 10 | — |
| fileUploads | `file-uploads.q-bank.md` | 13 | — |
| payments | `payments.q-bank.md` | 15 | — |
| frontendArchitecture | `frontend-architecture.q-bank.md` | 22 | — |
| designSystem | `design-system.q-bank.md` | 23 | — |
| uxAccessibilityPerf | `ux-accessibility-perf.q-bank.md` | 24 | hosts marketingEmail, pushNotifications, productAnalytics |
| i18nL10n | `i18n-l10n.q-bank.md` | 25 | — |
| _gate_ transactionalEmail | (in auth.q-bank.md) | 11 | auth |
| _gate_ sms | (in auth.q-bank.md) | 11 | auth |
| _gate_ featureGating | (in cicd.q-bank.md) | 19 | cicdAndDelivery |
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/context-gathering/references/auth.q-bank.md \
        greenfield/skills/context-gathering/references/cicd.q-bank.md \
        greenfield/skills/context-gathering/references/question-bank.md
git commit -m "feat(greenfield): R6 — append 3 inline gate snippets (TransEmail+SMS in auth, FeatureGating in cicd) + question-bank R6 appendix"
```

---

## Phase G — Synthesis template triples (9 new phases)

> **Reference for ALL template tasks T31-T39:** Follow the structural pattern of `greenfield/skills/synthesis-review/references/templates/feature-roadmap.html` (R5). Each template triple comprises:
>
> - `<phase>.html` — phase-rooted Handlebars HTML synthesis with sectioned panels.
> - `<phase>.md` — Markdown mirror with identical placeholder spans.
> - `<phase>-dependencies.json.example` — declares cross-phase reads as `{path, value, rationale}` records.
>
> All `{{phase.X.Y}}` placeholders must match Q-bank `Stores to:` paths character-for-character (CHECKPOINT 3 verifies this).

### Task 31: `search` template triple

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/search.html`
- Create: `greenfield/skills/synthesis-review/references/templates/search.md`
- Create: `greenfield/skills/synthesis-review/references/templates/search-dependencies.json.example`

- [ ] **Step 1: Author `search.html`**

Sections: Overview (searchType, engine), Index Scope (indexScope[]), Update Strategy (updateStrategy, refreshInterval), Query Patterns (queryPatterns[], ranking, abTesting), Security (rls, queryAuth), Risks (qRisks[]).

Use phase-rooted Handlebars: `{{search.searchType}}`, `{{#each search.indexScope}}<li>{{this}}</li>{{/each}}`, etc.

```html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Search Synthesis</title></head>
<body>
  <h1>Search — {{search.searchType}} via {{search.engine}}</h1>
  <h2>Index scope</h2>
  <ul>{{#each search.indexScope}}<li>{{this}}</li>{{/each}}</ul>
  <h2>Update strategy</h2>
  <p>{{search.updateStrategy}}</p>
  <h2>Query patterns</h2>
  <ul>{{#each search.queryPatterns}}<li>{{this}}</li>{{/each}}</ul>
  <h2>Ranking</h2>
  <p>{{search.ranking}}</p>
  <h2>Security</h2>
  <ul>
    <li>RLS: {{search.security.rls}}</li>
    <li>Query auth: {{search.security.queryAuth}}</li>
  </ul>
  <h2>Risks</h2>
  <ul>{{#each search.qRisks}}<li>{{this}}</li>{{/each}}</ul>
</body>
</html>
```

- [ ] **Step 2: Author `search.md` (markdown mirror)**

Same content, markdown formatted.

- [ ] **Step 3: Author `search-dependencies.json.example`**

```json
{
  "schemaVersion": 1,
  "phase": "search",
  "recordedAt": "2026-05-15T00:00:00Z",
  "dependencies": [
    { "path": "dataArchitecture.entities", "value": [], "rationale": "Index scope cross-refs entities; search results respect entity-level RLS" },
    { "path": "dataArchitecture.engine", "value": "", "rationale": "Engine choice for FTS depends on db engine (Postgres FTS available when engine=postgres)" }
  ]
}
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/search.*
git commit -m "feat(greenfield): R6 — search synthesis template triple"
```

---

### Task 32: `caching` template triple

**Files:** Same pattern as T31 — caching.html / caching.md / caching-dependencies.json.example.

Sections:
- Layers (`caching.layers[]`) + CDN provider
- Invalidation (`invalidationStrategy`, `staleWhileRevalidate`, `keyDesign`)
- Multi-tenant (`multiTenantIsolation`)
- Observability (`observability.hitRates`, `observability.alertOnDrop`)
- Stampede protection (`stampedeProtection`)
- Risks (`qRisks[]`)

Dependencies: reads `architecturalFraming.frontendFramework` (framework-conditional CDN headers), `dataArchitecture.engine` (DB query cache integration).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/caching.*
git commit -m "feat(greenfield): R6 — caching synthesis template triple"
```

---

### Task 33: `realtime` template triple

**Files:** realtime.html / realtime.md / realtime-dependencies.json.example.

Sections:
- Transport + use cases (per-persona section — `{{#each realtime.useCases}}`)
- Backend + client lib
- Scaling (`scaling.stickySessions`, `scaling.horizontal`)
- Reconnect (`reconnectStrategy`, `messageOrdering`, `dedup`)
- Risks

Dependencies: reads `personas.primary[]` (per-persona use cases), `runtimeOperations.observability` (uptime tracking ties into pub-sub backend).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/realtime.*
git commit -m "feat(greenfield): R6 — realtime synthesis template triple"
```

---

### Task 34: `file-uploads` template triple

**Files:** file-uploads.html / file-uploads.md / file-uploads-dependencies.json.example.

Sections:
- Storage backend + upload flow + CDN
- Image transforms
- Limits (`maxFileSize`, `mimeAllowlist[]`)
- Security (`virusScanning`, `piiHandling`, `retentionPolicy`, `multiTenantIsolation`)
- Surfaces by persona (per-persona)
- Risks

Dependencies: reads `personas.primary[]` (per-persona upload surfaces), `privacy.piiFields[]` (drives `piiHandling`).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/file-uploads.*
git commit -m "feat(greenfield): R6 — file-uploads synthesis template triple"
```

---

### Task 35: `payments` template triple

**Files:** payments.html / payments.md / payments-dependencies.json.example.

Sections:
- Provider + billing model
- Customer experience (`customerPortal`, `refundFlow`)
- Operations (`taxHandling`, `dunning`, `webhookStrategy`, `fraudPrevention`)
- Compliance (`compliance.pciScope`, `compliance.sca`, `compliance.regulatory[]`)
- Currency/locales
- Surfaces by persona
- Risks

Dependencies: reads `personas.primary[]`, `privacy.pii.financial` (CHECK-R6-3 — must be true if payments populated), `security` (PCI scope ties to security model).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/payments.*
git commit -m "feat(greenfield): R6 — payments synthesis template triple"
```

---

### Task 36: `frontend-architecture` template triple

**Files:** frontend-architecture.html / frontend-architecture.md / frontend-architecture-dependencies.json.example.

Sections:
- Framework confirmation (`frameworkConfirmed`)
- State + routing + data fetching
- Forms + animation + error boundaries
- Code splitting + bundler + dev server
- Feature surfaces by persona
- Risks

Dependencies: reads `architecturalFraming.frontendFramework` (CHECK-R6-4 must match).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/frontend-architecture.*
git commit -m "feat(greenfield): R6 — frontend-architecture synthesis template triple"
```

---

### Task 37: `design-system` template triple

**Files:** design-system.html / design-system.md / design-system-dependencies.json.example.

Sections:
- Component library + theming
- Primitives + variant system + icon system
- Typography + color + spacing
- Design tool integration + Storybook adoption
- Brand guidelines + dark mode
- Risks

Dependencies: reads `frontendArchitecture.frameworkConfirmed` (component library compatibility).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/design-system.*
git commit -m "feat(greenfield): R6 — design-system synthesis template triple"
```

---

### Task 38: `ux-accessibility-perf` template triple (HOSTS 3 INLINE GATES)

**Files:** ux-accessibility-perf.html / ux-accessibility-perf.md / ux-accessibility-perf-dependencies.json.example.

Sections:
- Surfaces by persona (per-persona — `{{#each uxAccessibilityPerf.surfacesByPersona}}{{@key}}: {{this}}{{/each}}`)
- Responsiveness + breakpoints
- Accessibility (`a11yTarget`, `keyboardNavigation`, `screenReaderTesting`)
- Performance budgets (LCP/INP/CLS — `uxAccessibilityPerf.performanceBudgets.*`)
- Asset optimization (`imageOptimization`, `fontLoading`)
- State UX (`stateUx.error`, `stateUx.empty`, `stateUx.loading`)
- Offline support
- **Inline gates panel:** marketing email + push + product analytics (`{{uxAccessibilityPerf.concerns.marketingEmail.needed}}` + `vendor` if needed)
- Risks

Dependencies: reads `personas.primary[]` (per-persona surfaces), `frontendArchitecture.frameworkConfirmed` (image optimizer + font loading per framework).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/ux-accessibility-perf.*
git commit -m "feat(greenfield): R6 — ux-accessibility-perf synthesis template triple (hosts 3 gates)"
```

---

### Task 39: `i18n-l10n` template triple

**Files:** i18n-l10n.html / i18n-l10n.md / i18n-l10n-dependencies.json.example.

Sections:
- Target locales (`targetLocales[]`)
- Translation flow (`translationSource`, `library`, `fileFormat`)
- Format (`rtlSupport`, `dateNumberFormatting`, `pluralRules`)
- Delivery (`delivery`, `textType`)
- SEO (`seoHreflang`)
- Content flow (`contentTranslationFlow`)
- Risks

Dependencies: reads `frontendArchitecture.frameworkConfirmed` (Next.js vs Vue → different routing config).

- [ ] **Step 1: Author + commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/i18n-l10n.*
git commit -m "feat(greenfield): R6 — i18n-l10n synthesis template triple"
```

---

### CHECKPOINT 3 — template ↔ Q-bank path consistency

Before proceeding to Phase H, run this check:

```bash
# For every new template, extract every {{phase.X.Y}} reference and verify it
# matches a Stores to: path in the corresponding Q-bank.

for phase in search caching realtime file-uploads payments frontend-architecture design-system ux-accessibility-perf i18n-l10n; do
  TPL="greenfield/skills/synthesis-review/references/templates/${phase}.html"
  # Map phase name to phase key in context-shape (kebab-to-camel)
  case "$phase" in
    file-uploads) KEY="fileUploads" ;;
    frontend-architecture) KEY="frontendArchitecture" ;;
    design-system) KEY="designSystem" ;;
    ux-accessibility-perf) KEY="uxAccessibilityPerf" ;;
    i18n-l10n) KEY="i18nL10n" ;;
    *) KEY="$phase" ;;
  esac
  echo "=== $phase (key=$KEY) ==="
  grep -oE "\{\{${KEY}\.[a-zA-Z][a-zA-Z0-9.]*\}\}" "$TPL" | sort -u | head -20
done
```

Cross-check the printed paths against the Q-bank `Stores to:` lines for each phase. Any divergence → fix the template inline before proceeding (R5 commit `7a31642` lesson: mismatched paths produce silently-empty synthesis sections).

---

## Phase H — Wizard wiring

### Task 40: `context-gathering/SKILL.md` — insert 9 phase steps + 6 inline gates + CI Draft Review hook + re-recommendation pass

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Inspect current step structure**

```bash
grep -n "^## Step\|^### Step" greenfield/skills/context-gathering/SKILL.md | head -30
```

The current file (alpha.6) has 20 named steps. R6 adds 10 more steps (9 new phases + Step 20 CI Draft Review) and renumbers existing later steps.

- [ ] **Step 2: Insert Step 7 (Search) after Step 6 (Data Architecture)**

Locate `## Step 6: Data Architecture` (or `### Step 6` — whichever the file uses). Immediately after that step's content, insert:

````markdown
## Step 7: Search

**Wizard progress: Step 7 of 30 — Search**

Reads the data architecture entities. Captures search intent (FTS / vector / hybrid / none) and surfaces query patterns + security posture.

1. Check `phases.dataArchitecture.engine`. If `"none"`, ask the user: "No persistent data engine — Search phase doesn't apply. Skip?" → on Yes, write `phases.search = {skipped: true, deferredReason: "no data engine"}` and advance to Step 8.
2. Load `${CLAUDE_PLUGIN_ROOT}/skills/context-gathering/references/search.q-bank.md`.
3. Walk S.Q1 → S.Q11 → S.Q_RISK. Apply `mode.depth` gating via `showInLight`.
4. After Q-bank completes, invoke `synthesis-review` with `phase: "search"`.
5. Approve/Adjust/Skip path identical to R5 phases.
6. Checkpoint state via atomic write.
````

- [ ] **Step 3: Insert Step 9 (Caching) after Step 8 (API & Integration)**

Same shape — load `caching.q-bank.md`, walk C.Q1–C.Q12 + C.Q_RISK, invoke synthesis-review.

- [ ] **Step 4: Insert Step 10 (Real-time) after Step 9 (Caching)**

Per-persona auto-loop wrapper:

```markdown
4. For each persona in `personas.primary` (capped at `min(personas.length, 4)` per CHECK-R6-9):
   - Walk RT.Q2 (per-persona-scoped) capturing useCases for that persona
   - Flatten union into `phases.realtime.useCases[]` after loop
5. Record `phases.realtime.loopIterations` = count of persona iterations executed.
```

- [ ] **Step 5: Insert inline gates in Step 11 (Auth)**

Locate Step 11 Auth. Inside the Auth Q-bank walk, after the existing auth questions and before synthesis-review:

```markdown
### Inline gates (R6 — fired inline)

Walk `Gate.TransEmail` and `Gate.SMS` from `auth.q-bank.md`. Use the AskUserQuestion single-option guard pattern when only the gate's vendor list collapses to one option.

Write:
- `phases.auth.concerns.transactionalEmail = {needed: <bool>, vendor: <string|null>}`
- `phases.auth.concerns.sms = {needed: <bool>, vendor: <string|null>}`
```

- [ ] **Step 6: Insert Step 13 (File Uploads & CDN) after Step 12 (Privacy)**

Per-persona auto-loop on FU.Q11. After the Q-bank walk: `phases.fileUploads.loopIterations` count.

- [ ] **Step 7: Insert Step 15 (Payments) after Step 14 (Security)**

Per-persona auto-loop on P.Q13 (customer-facing vs admin). Add CHECK-R6-3 gating check at the end:

```markdown
6. CHECK-R6-3 enforcement: if `phases.payments.provider != "none"`, verify `phases.privacy.pii.financial == true`. If not, surface via AskUserQuestion: "Payments captured but privacy.pii.financial is not flagged — fix?" → on Yes, jump back to Step 12 Privacy.
```

- [ ] **Step 8: Insert inline gate in Step 19 (CI/CD)**

After CI/CD Q-bank walk, before the CI Draft Review hook:

```markdown
### Inline gate (R6)

Walk `Gate.FeatureGating` from `cicd.q-bank.md`. Write `phases.cicdAndDelivery.concerns.featureGating = {needed, vendor?}`.
```

- [ ] **Step 9: Insert Step 20 (CI Draft Review) — auto-render + synthesis-review hook**

After Step 19 CI/CD captures answers, before Step 21:

````markdown
## Step 20: CI Draft Review

**Wizard progress: Step 20 of 30 — CI Draft Review**

Auto-renders CI YAML mid-flow; user reviews via 3-panel synthesis HTML; Approve / Adjust / Reject.

1. Fire the renderer entrypoint:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-ci-drafts.sh" .claude/greenfield-state.json
   ```

2. The entrypoint dispatches by `phases.cicdAndDelivery.provider`. After it completes, state contains `phases.cicdAndDelivery.{draftYaml, draftWarnings, draftFallback, draftRenderedAt, draftSourceRefs, draftProvider}`.
3. Invoke `synthesis-review` with `phase: "cicdAndDelivery"`, `template: "ci-draft-review"`. The 3-panel HTML (Inputs / Decisions / Rendered YAML) renders.
4. Ask via `AskUserQuestion`:
   - **Approve** — copy `draftYaml` to `phases.cicdAndDelivery.lockedYaml`; advance to Step 21.
   - **Adjust** — capture natural-language instruction; LLM edits the YAML inline; append to `phases.cicdAndDelivery.adjustHistory[]`; re-render Panel 3; loop until Approve or Reject.
   - **Reject** — clear `phases.cicdAndDelivery.lockedYaml = null`; jump back to Step 19 to re-answer the CI/CD Q-bank.
5. **LLM-fallback gate (CHECK-R6-8):** if `phases.cicdAndDelivery.draftFallback == true`, do NOT unlock Approve until every warning in `draftWarnings[]` has `addressed = true`. Use AskUserQuestion to walk each warning with "Address" / "Skip" options.
6. On Approve: checkpoint atomic write; advance to Step 21.
````

- [ ] **Step 10: Insert Step 21 (P7.5 Plugin Recommendation) — split from old P10**

````markdown
## Step 21: P7.5 Plugin Recommendation

**Wizard progress: Step 21 of 30 — Plugin Recommendation**

Reads phases.{auth, privacy, security, runtimeOperations, cicdAndDelivery, cicdAndDelivery.concerns.featureGating, fileUploads, payments, search, caching, realtime}. Calls plugin-discovery skill in **recommendation mode**.

1. Invoke `plugin-discovery` skill via the Skill tool with `mode: "recommendation"`. The skill emits `{suggested: [...], rationale: "..."}`.
2. AskUserQuestion (multi-select with single-option-guard if `suggested.length == 1`): "Which suggested plugins do you want to track for install at Step 30?"
3. Write `phases.pluginRecommendation = {suggested, selected: <user pick>, rationale, frontendAddenda: []}`.
4. **Does NOT install** — only records intent. Actual install happens at Step 30.
5. Invoke `synthesis-review` with `phase: "pluginRecommendation"`.
````

- [ ] **Step 11: Insert Step 22 (P5 Frontend Architecture), Step 23 (P5.3 Design System), Step 24 (P5.6 UX/A11y/Perf), Step 25 (i18n)**

Step 22 — Frontend Architecture (per-persona auto-loop FA.Q13).

Step 23 — Design System (flat; load `design-system.q-bank.md`; synthesis-review).

Step 24 — UX/A11y/Perf (per-persona auto-loop UX.Q1 surfacesByPersona + 3 inline gates inline before synthesis-review):

```markdown
### Inline gates (R6 — inside Step 24)

Walk `Gate.MktEmail`, `Gate.Push`, `Gate.Analytics` from `ux-accessibility-perf.q-bank.md`.
Write to `phases.uxAccessibilityPerf.concerns.{marketingEmail, pushNotifications, productAnalytics}` per gate.
```

Step 25 — i18n / l10n (flat; load `i18n-l10n.q-bank.md`).

- [ ] **Step 12: Insert frontend re-recommendation pass after Step 25**

````markdown
### Re-recommendation pass (R-R6-6 mitigation, fires after Step 25)

After i18n completes, re-invoke `plugin-discovery` with frontend + i18n context (Storybook from P5.3, i18n library from Step 25, etc.).

1. Invoke `plugin-discovery` skill with `mode: "recommendation"` again (same as Step 21).
2. Compare new suggestion set against `phases.pluginRecommendation.suggested`. If new entries surface, AskUserQuestion: "Add these to your install set?"
3. Write the user's picks to `phases.pluginRecommendation.frontendAddenda[]`.
4. If no new entries, skip silently.
````

- [ ] **Step 13: Insert Step 30 (P10 Plugin Install) — split from old P10**

````markdown
## Step 30: P10 Plugin Install

**Wizard progress: Step 30 of 30 — Plugin Install**

Reads `phases.pluginRecommendation.selected` ∪ `phases.pluginRecommendation.frontendAddenda`. Calls plugin-discovery skill in **install mode**.

1. Invoke `plugin-discovery` skill via the Skill tool with `mode: "install"`. The skill runs `/plugin marketplace install <id>` for each entry.
2. Capture install results: `phases.pluginInstall = {installed: [...], failed: [{id, reason}], skipped: [...]}`.
3. If `failed[]` non-empty: AskUserQuestion: "Some plugins failed to install. Scaffold anyway with manual-install instructions, or abort?" → on Scaffold: proceed; on Abort: halt with diagnostic.
4. Invoke `synthesis-review` with `phase: "pluginInstall"`.
````

- [ ] **Step 14: Update the Context Object initialization block**

In the `## Adaptive State Machine` section's Context Object JSON, add the new phase keys to the initial object so adaptive checks have a place to test:

```jsonc
{
  // existing keys
  "hasSearch": false,
  "hasCaching": false,
  "hasRealtime": false,
  "hasFileUploads": false,
  "hasPayments": false,
  "hasFrontendTrio": false,
  "hasI18n": false,
  "defaultsAccepted": {}
}
```

- [ ] **Step 15: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "feat(greenfield): R6 — context-gathering inserts 9 phase steps + 6 inline gates + Step 20 CI Draft Review + plugin split + frontend re-recommendation pass"
```

---

### Task 41: `context-gathering/SKILL.md` — renumber to 30 steps + progress indicator update

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Replace the Progress Indicator template**

Find the `## Progress Indicator Protocol` section. Replace the count and naming:

```markdown
> **Wizard progress: Step [X] of 30 — [step name]**
> Completed: [list of step names from completedSteps]
> Up next: [name of the next step, if known]
```

(Changed `of 20` to `of 30`.)

- [ ] **Step 2: Verify all 30 step headings are present and correctly numbered**

```bash
grep -E "^## Step [0-9]+:" greenfield/skills/context-gathering/SKILL.md | head -35
```

Expected: 30 distinct steps numbered 1–30 with names matching the spec § Wizard step ordering table.

- [ ] **Step 3: Update CHECK-R6-9 enforcement notice in the auto-loop section**

```markdown
**Per-persona auto-loop cap (CHECK-R6-9):** concern phases that auto-loop per persona cap iterations at `min(personas.length, 4)`. Record iteration count to `phases.<phase>.loopIterations`. The 4-cap default can be overridden via `mode.autoLoopCap` set at Step 1.1.
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "chore(greenfield): R6 — context-gathering progress indicator '20 → 30' + R6-9 auto-loop cap notice"
```

---

### Task 42: `synthesis-review/SKILL.md` + `start/SKILL.md` updates

**Files:**
- Modify: `greenfield/skills/synthesis-review/SKILL.md`
- Modify: `greenfield/skills/start/SKILL.md`

- [ ] **Step 1: Update `synthesis-review/SKILL.md` template index**

Find the section listing available templates. Append:

```markdown
### Round 6 templates (R6 — 9 new phases + CI Draft Review)

| Phase | Template path | Step |
|---|---|---|
| search | `templates/search.{html,md}` | 7 |
| caching | `templates/caching.{html,md}` | 9 |
| realtime | `templates/realtime.{html,md}` | 10 |
| fileUploads | `templates/file-uploads.{html,md}` | 13 |
| payments | `templates/payments.{html,md}` | 15 |
| frontendArchitecture | `templates/frontend-architecture.{html,md}` | 22 |
| designSystem | `templates/design-system.{html,md}` | 23 |
| uxAccessibilityPerf | `templates/ux-accessibility-perf.{html,md}` | 24 |
| i18nL10n | `templates/i18n-l10n.{html,md}` | 25 |
| cicdAndDelivery (CI Draft Review) | `templates/ci-draft-review.{html,md}` | 20 |
```

- [ ] **Step 2: Document the CI Draft Review 3-panel review flow**

Add a section to `synthesis-review/SKILL.md`:

```markdown
### CI Draft Review (Step 20) — 3-panel auto-render flow

The CI Draft Review fires after `render-ci-drafts.sh` populates `phases.cicdAndDelivery.draftYaml`. Unlike other synthesis reviews (which render after Q-bank capture only), this review's three panels show:

- Panel 1 — Inputs: stage list, runners, deploy target, framework, stack.
- Panel 2 — Decisions log: each `adjustHistory[]` entry + cross-check warnings (`draftWarnings[]`) with `addressed` flags.
- Panel 3 — Rendered YAML: the actual rendered YAML output from the per-provider renderer.

**LLM-fallback gate:** when `draftFallback == true`, Approve is disabled until every warning in `draftWarnings[]` has `addressed = true` (CHECK-R6-8 enforces this hard).
```

- [ ] **Step 3: Update `start/SKILL.md` step counter**

Find the step counter / progress text in `start/SKILL.md`. Replace any `20` with `30`. Typical lines:

```bash
grep -n "20 steps\|of 20\|Step .* of 20" greenfield/skills/start/SKILL.md | head
```

Update each occurrence to reference 30 steps.

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/synthesis-review/SKILL.md greenfield/skills/start/SKILL.md
git commit -m "chore(greenfield): R6 — synthesis-review indexes 10 new templates; start counter 20 → 30"
```

---

## Phase I — Plugin reshuffle

### Task 43: `plugin-discovery/SKILL.md` — recommendation mode vs install mode

**Files:**
- Modify: `greenfield/skills/plugin-discovery/SKILL.md`

- [ ] **Step 1: Inspect current shape**

```bash
head -50 greenfield/skills/plugin-discovery/SKILL.md
```

Currently (alpha.6) plugin-discovery does both recommendation and install in one pass. R6 splits these into two invocation modes.

- [ ] **Step 2: Add mode parameter handling at the top**

After the YAML frontmatter, before the existing instructions:

````markdown
## Invocation mode

This skill operates in two modes determined by the caller:

| Mode | Purpose | Reads | Writes |
|---|---|---|---|
| `recommendation` | Suggest plugins; user picks; no install | `phases.{auth, privacy, security, runtimeOperations, cicdAndDelivery, search, caching, realtime, fileUploads, payments, frontendArchitecture, designSystem, uxAccessibilityPerf, i18nL10n}` | `phases.pluginRecommendation.{suggested, selected, rationale}` |
| `install` | Read picks; actually run `/plugin marketplace install` | `phases.pluginRecommendation.{selected, frontendAddenda}` | `phases.pluginInstall.{installed, failed, skipped}` |

The wizard caller passes mode via the Skill tool input (the conversational caller pattern). When invoking:

```
plugin-discovery (mode=recommendation)
plugin-discovery (mode=install)
```

If mode is omitted, default to `recommendation` (read-only behavior — safest default).
````

- [ ] **Step 3: Restructure the existing instructions into two branches**

Wrap the existing "scan catalog → match capabilities → install" logic in:

```markdown
### Mode: recommendation

[scan catalog + match capabilities — no install]
1. Read `references/plugin-catalog.md` + state phases listed above.
2. Match phases to plugin capabilities (e.g., auth.strategy=hosted + provider=clerk → suggest `vercel:auth` or `clerk:nextjs` plugin).
3. Compile `{suggested: [...], rationale: "..."}` and return to caller.
4. Caller writes `phases.pluginRecommendation`.

### Mode: install

[read pluginRecommendation → invoke /plugin marketplace install per entry]
1. Read `phases.pluginRecommendation.selected ∪ frontendAddenda`.
2. For each entry, run `/plugin marketplace install <id>`. Capture stdout + exit code.
3. Build `{installed: [...], failed: [{id, reason}], skipped: [...]}`.
4. Return to caller; caller writes `phases.pluginInstall`.
```

- [ ] **Step 4: Update plugin-catalog.md if it currently mixes recommend+install metadata**

```bash
grep -c "install command\|/plugin marketplace install" greenfield/skills/plugin-discovery/references/plugin-catalog.md
```

If the catalog includes install commands but the recommendation pass should ignore them: leave them in place but note in plugin-discovery/SKILL.md that recommendation mode ignores `installCommand` fields.

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/plugin-discovery/SKILL.md
git commit -m "feat(greenfield): R6 — plugin-discovery splits into recommendation vs install modes"
```

---

### Task 44: `tooling-generation/SKILL.md` — pass-through additions (9 phases + plugin split + lockedYaml)

**Files:**
- Modify: `greenfield/skills/tooling-generation/SKILL.md`

- [ ] **Step 1: Locate the onboard context construction**

```bash
grep -n "phases\.\|onboard:generate\|Skill" greenfield/skills/tooling-generation/SKILL.md | head -20
```

Find where the wizard assembles the v2 context object to pass to `onboard:generate`.

- [ ] **Step 2: Add the 9 new phase keys**

In the context-construction section, append:

```markdown
- `phases.search` — populated when Step 7 runs (skipped: true otherwise)
- `phases.caching` — Step 9
- `phases.realtime` — Step 10
- `phases.fileUploads` — Step 13
- `phases.payments` — Step 15
- `phases.frontendArchitecture` — Step 22 (replaces deprecated `phases.frontend`)
- `phases.designSystem` — Step 23
- `phases.uxAccessibilityPerf` — Step 24
- `phases.i18nL10n` — Step 25
```

- [ ] **Step 3: Replace `phases.pluginDiscovery` with the two-phase split**

```markdown
- `phases.pluginRecommendation` (R6 split) — suggested + selected + rationale + frontendAddenda
- `phases.pluginInstall` (R6 split) — installed + failed + skipped
```

- [ ] **Step 4: Surface `phases.cicdAndDelivery.lockedYaml` as an explicit pass-through**

```markdown
- `phases.cicdAndDelivery.lockedYaml` — when set, onboard writes verbatim to `.github/workflows/ci.yml` (or `.gitlab-ci.yml` / `.circleci/config.yml` depending on `draftProvider`)
- `phases.cicdAndDelivery.adjustHistory` — included in the generation context for audit/observability; onboard ignores at write time
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/tooling-generation/SKILL.md
git commit -m "feat(greenfield): R6 — tooling-generation pass-through for 9 new phases + plugin split + cicdAndDelivery.lockedYaml"
```

---

## Phase J — Cross-phase invariants + health checks

### Task 45: `check-r6-invariants.md` + grill-spec wiring

**Files:**
- Create: `greenfield/skills/grill-spec/references/check-r6-invariants.md`
- Modify: `greenfield/skills/grill-spec/SKILL.md`

- [ ] **Step 1: Author `check-r6-invariants.md` following R5 pattern**

```bash
cat > greenfield/skills/grill-spec/references/check-r6-invariants.md <<'R6INV'
# Round 6 Cross-Phase Invariants

> **Wired into:** `grill-spec/SKILL.md` (5-category adversarial walk)
> **Severity legend:** `error` = blocks scaffold; `warn` = surfaces in grill-spec output, user can override; `info` = non-blocking suggestion
> **See also:** `check-r4-invariants.md` (R4), `check-r5-invariants.md` (R5), design spec § Cross-phase invariants

This file defines the 9 invariants introduced in Round 6 covering the 3-frontend split + 6 concern phases + 6 inline gates + CI Draft Review + auto-loop cap.

## CHECK-R6-1: Gate vendor required when needed

**Invariant:** For each `phases.<parent>.concerns.<gate>`, `needed: false` ⟹ no vendor required; `needed: true` ⟹ `vendor` is a non-empty string.

**Severity:** error
**Phases involved:** auth, uxAccessibilityPerf, cicdAndDelivery

**Detection (jq):**
```bash
jq -e '
  [ (.phases.auth.concerns // {}),
    (.phases.uxAccessibilityPerf.concerns // {}),
    (.phases.cicdAndDelivery.concerns // {}) ]
  | map(to_entries[]) | flatten
  | all(.value.needed != true or ((.value.vendor // "") | length > 0))
' "$STATE_FILE"
```

**Failure prompt:** "Gate `<gate>` marked needed=true but has no vendor selected. Fix or set needed=false."

## CHECK-R6-2: Concern phases reference at least one entity

**Invariant:** Each of `phases.{search, caching, realtime}` not marked `skipped: true` references at least one entity from `phases.dataArchitecture.entities[]`.

**Severity:** warn
**Phases involved:** search × caching × realtime × dataArchitecture

**Detection:** For each of the 3 phases, check it has a path indexing into dataArchitecture (e.g., `search.indexScope[]` non-empty when `engine != "none"`).

**Failure prompt:** "Phase `<phase>` is active but doesn't touch any entity from dataArchitecture. Confirm scope or mark skipped."

## CHECK-R6-3: Payments ⟹ privacy.pii.financial

**Invariant:** `phases.payments.provider != "none"` AND `phases.payments.skipped != true` ⟹ `phases.privacy.pii.financial == true`.

**Severity:** error
**Phases involved:** payments × privacy

**Detection (jq):**
```bash
jq -e '
  (.phases.payments.skipped != true and (.phases.payments.provider // "none") != "none")
  | if . then (.phases.privacy.pii.financial == true) else true end
' "$STATE_FILE"
```

**Failure prompt:** "Payments captured but Privacy phase did not flag financial PII. Re-run Step 12 Privacy to declare `pii.financial = true` for PCI consistency."

## CHECK-R6-4: P5 frameworkConfirmed matches architecturalFraming

**Invariant:** `phases.frontendArchitecture.frameworkConfirmed == phases.architecturalFraming.frontendFramework` (when frontendArchitecture is not skipped).

**Severity:** error
**Phases involved:** frontendArchitecture × architecturalFraming

**Detection (jq):**
```bash
jq -e '
  (.phases.frontendArchitecture.skipped != true)
  | if . then (.phases.frontendArchitecture.frameworkConfirmed == .phases.architecturalFraming.frontendFramework) else true end
' "$STATE_FILE"
```

**Failure prompt:** "Frontend Architecture confirmed `<X>` but architecturalFraming declared `<Y>`. Update one or the other to resolve stack divergence."

## CHECK-R6-5: P5.6 surfacesByPersona covers every persona

**Invariant:** Every persona ID in `phases.personas.primary[].id ∪ phases.personas.secondary[].id` appears as a key in `phases.uxAccessibilityPerf.surfacesByPersona` AND maps to a non-empty array.

**Severity:** error
**Phases involved:** uxAccessibilityPerf × personas

**Detection:**
```bash
jq -e '
  (.phases.uxAccessibilityPerf.skipped != true)
  | if . then
      ((.phases.personas.primary // []) + (.phases.personas.secondary // []) | [.[].id]) as $pids
      | $pids | all(. as $id | (.phases.uxAccessibilityPerf.surfacesByPersona[$id] // []) | length > 0)
    else true end
' "$STATE_FILE"
```

**Failure prompt:** "Persona `<id>` has no UX surface mapping. Re-run Step 24 UX/A11y/Perf to define surfaces for this persona."

## CHECK-R6-6: i18n locales ⟹ translation strategy committed

**Invariant:** `phases.i18nL10n.targetLocales[]` non-empty ⟹ all synthesis docs that reference user-facing copy commit to a translation strategy (`translationSource != "none"`, `library != "none"`).

**Severity:** warn
**Phases involved:** i18nL10n × any phase with user-facing copy

**Failure prompt:** "i18n declares locales but no translation strategy. Set `translationSource` and `library` in Step 25."

## CHECK-R6-7: Plugin recommendation covers each needed gate's vendor

**Invariant:** For every `concerns.<gate>` with `needed: true`, if the marketplace has an integration plugin for `vendor`, `phases.pluginRecommendation.suggested` includes it.

**Severity:** info
**Phases involved:** pluginRecommendation × all gates

**Detection:** Best-effort string match between `concerns.<gate>.vendor` and `pluginRecommendation.suggested[]`. Non-blocking — surfaces as a suggestion.

## CHECK-R6-8: LLM-fallback CI requires addressed warnings

**Invariant:** When `phases.cicdAndDelivery.draftFallback == true` AND `lockedYaml != null`, every `draftWarnings[]` entry has `addressed == true`.

**Severity:** error
**Phases involved:** cicdAndDelivery

**Detection (jq):**
```bash
jq -e '
  (.phases.cicdAndDelivery.draftFallback // false)
  | if . then
      (.phases.cicdAndDelivery.lockedYaml // null) == null
      or ((.phases.cicdAndDelivery.draftWarnings // []) | all(.addressed == true))
    else true end
' "$STATE_FILE"
```

**Failure prompt:** "CI Draft Review used the LLM-fallback path. Approve is blocked until every warning is marked addressed. Re-enter Step 20 to resolve."

## CHECK-R6-9: Auto-loop iteration cap

**Invariant:** For each concern phase that auto-loops per persona (`realtime`, `fileUploads`, `payments`, `frontendArchitecture`, `uxAccessibilityPerf`), `loopIterations <= min(personas.length, 4)`.

**Severity:** error
**Phases involved:** any auto-looping phase × personas

**Detection (jq):**
```bash
jq -e '
  ((.phases.personas.primary // []) | length) as $plen
  | (if $plen > 4 then 4 else $plen end) as $cap
  | [ .phases.realtime.loopIterations // 0,
      .phases.fileUploads.loopIterations // 0,
      .phases.payments.loopIterations // 0,
      .phases.frontendArchitecture.loopIterations // 0,
      .phases.uxAccessibilityPerf.loopIterations // 0 ]
  | all(. <= $cap)
' "$STATE_FILE"
```

**Failure prompt:** "Phase `<phase>` recorded `loopIterations=<N>` but cap is `<cap>`. State corrupted; manual inspection required."
R6INV
```

- [ ] **Step 2: Wire into `grill-spec/SKILL.md`**

Find the section that lists check-* references. Append:

```markdown
- `references/check-r6-invariants.md` — R6 invariants (CHECK-R6-1 through CHECK-R6-9): inline gate vendor coherence, concern-phase entity coverage, payments⇒financial-PII, P5 framework match, P5.6 persona surface coverage, i18n translation strategy, plugin recommendation coverage, LLM-fallback CI gate, auto-loop cap.
```

Also in the walk order: include R6 invariants after R5.

- [ ] **Step 3: Validate**

```bash
shellcheck -s bash - <<< "$(grep -A2 '```bash' greenfield/skills/grill-spec/references/check-r6-invariants.md | grep -v '^---' | grep -v '^```')" 2>&1 | head
# Expected: no shellcheck errors on the embedded jq snippets
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/grill-spec/references/check-r6-invariants.md greenfield/skills/grill-spec/SKILL.md
git commit -m "feat(greenfield): R6 — check-r6-invariants.md (CHECK-R6-1..9) + grill-spec wiring"
```

---

### Task 46: `check/SKILL.md` — 3 new health-check assertions

**Files:**
- Modify: `greenfield/skills/check/SKILL.md`

- [ ] **Step 1: Find existing R5 health-check section**

```bash
grep -n "R5\|alpha\.6\|feature-roadmap\|schemaDraftReview\|lockedAt" greenfield/skills/check/SKILL.md | head
```

- [ ] **Step 2: Add 3 R6 health-check assertions**

Append after the R5 block:

```markdown
### Round 6 health checks (R6 — alpha.7)

| Assertion | Failure mode |
|---|---|
| Frontend trio completeness — when none of `frontendArchitecture/designSystem/uxAccessibilityPerf` are skipped, all three are populated with required fields | Surface "frontend trio incomplete — missing X" |
| 6 concern-phase completeness — when not skipped, each of `search/caching/realtime/fileUploads/payments/i18nL10n` has the required top-level fields | Surface "concern phase X incomplete" |
| `pluginRecommendation` + `pluginInstall` both populated when neither is skipped | Surface "plugin split incomplete — recommendation captured but install not run" |
```

Implementation jq snippets:

```bash
# Frontend trio
jq -e '
  (.phases.frontendArchitecture.skipped // false) or (.phases.frontendArchitecture.frameworkConfirmed != null)
  and ((.phases.designSystem.skipped // false) or (.phases.designSystem.componentLibrary != null))
  and ((.phases.uxAccessibilityPerf.skipped // false) or (.phases.uxAccessibilityPerf.a11yTarget != null))
' "$STATE_FILE"

# Concern phases
jq -e '
  ["search","caching","realtime","fileUploads","payments","i18nL10n"]
  | all(. as $p | ((.phases[$p].skipped // false) or (.phases[$p] | length > 1)))
' "$STATE_FILE"

# Plugin split
jq -e '
  ((.phases.pluginRecommendation.skipped // false) or (.phases.pluginRecommendation.selected // [] | length >= 0))
  and ((.phases.pluginInstall.skipped // false) or (.phases.pluginInstall.installed != null))
' "$STATE_FILE"
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/check/SKILL.md
git commit -m "feat(greenfield): R6 — check skill adds 3 R6 health-check assertions"
```

---

## Phase K — Onboard generation

### Task 47: 5 concern-phase generation modules + generation/SKILL.md wiring

**Files:**
- Create: `onboard/skills/generation/references/render-search.md`
- Create: `onboard/skills/generation/references/render-caching.md`
- Create: `onboard/skills/generation/references/render-realtime.md`
- Create: `onboard/skills/generation/references/render-file-uploads.md`
- Create: `onboard/skills/generation/references/render-payments.md`
- Modify: `onboard/skills/generation/SKILL.md`

- [ ] **Step 1: Author `render-search.md`**

```bash
cat > onboard/skills/generation/references/render-search.md <<'RS'
# Render module: `phases.search` → search infrastructure

## When to render

- `phases.search.skipped == true` → SKIP this module (no-op).
- `phases.search.engine == "none"` → SKIP.
- Else → render the artifacts below.

## Output paths

| File | Condition | Content |
|---|---|---|
| `lib/search.ts` | always (when not skipped) | TS client for the chosen engine |
| `prisma/migrations/0002_search_indexes.sql` | `engine == "postgres-fts"` | GIN indexes for entities in `indexScope[]` |
| `lib/search/.gitkeep` | always | placeholder for engine-specific helpers |

## lib/search.ts template

```typescript
// Search client for ${phases.search.engine}
// Scope: ${phases.search.indexScope.join(", ")}
// Update strategy: ${phases.search.updateStrategy}

export async function search(query: string, options?: SearchOptions) {
  // Engine-specific implementation
  return { results: [], total: 0 };
}

export type SearchOptions = {
  filters?: Record<string, unknown>;
  facets?: string[];
  limit?: number;
  offset?: number;
};
```

When engine is `meilisearch`, `typesense`, `elasticsearch`, `pgvector`, `pinecone`, `weaviate`: emit the corresponding client init code (use the established engine SDK). Cross-reference `phases.search.queryPatterns[]` to include autocomplete / facets / ranking helpers.

## Postgres FTS migration template

When `engine == "postgres-fts"`:

```sql
-- Generated by onboard render-search.md from phases.search
-- Index scope: ${phases.search.indexScope.join(", ")}
${phases.search.indexScope.map(entity => `
CREATE INDEX IF NOT EXISTS idx_${entity}_search
  ON ${entity}
  USING gin(to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, '')));
`).join("\n")}
```

## Backward compatibility

- `phases.search.skipped == true` → no files written; no error.
- `phases.search.engine == "none"` → same as skipped.
RS
```

- [ ] **Step 2: Author `render-caching.md`, `render-realtime.md`, `render-file-uploads.md`, `render-payments.md` using the same shape**

Each file follows the structure:
- "## When to render" — skip conditions
- "## Output paths" — table of files
- Template snippets — TS skeleton + config snippet
- "## Backward compatibility" — skip behavior

Specific outputs:

**render-caching.md:** Output paths: `lib/cache.ts`, `next.config.ts` (if framework=next.js — patch Cache-Control headers), `lib/cache/.gitkeep`.

**render-realtime.md:** Output paths: `lib/realtime.ts`, `app/api/realtime/route.ts` (Next.js App Router) or `pages/api/realtime.ts` (Pages Router), `lib/realtime/reconnect.ts`.

**render-file-uploads.md:** Output paths: `lib/uploads.ts`, `lib/uploads/iam-policy.json` (S3/R2 IAM template), `lib/uploads/mime-allowlist.ts`.

**render-payments.md:** Output paths: `lib/payments/<provider>.ts`, `app/api/webhooks/<provider>/route.ts`, `app/(payments)/portal/page.tsx`, `.env.example` updates with `STRIPE_*` / `PADDLE_*` / etc. ENV samples.

- [ ] **Step 3: Wire into `onboard/skills/generation/SKILL.md`**

Locate the section that enumerates phase render modules. Append:

```markdown
### Round 6 phase renderers

| Phase | Render module | Output domain |
|---|---|---|
| search | `references/render-search.md` | `lib/search.ts` + FTS migration |
| caching | `references/render-caching.md` | `lib/cache.ts` + CDN headers |
| realtime | `references/render-realtime.md` | `lib/realtime.ts` + realtime API route |
| fileUploads | `references/render-file-uploads.md` | `lib/uploads.ts` + IAM policy |
| payments | `references/render-payments.md` | `lib/payments/<provider>.ts` + webhook + portal |
```

In the per-phase generation loop, add: for each of `search`, `caching`, `realtime`, `fileUploads`, `payments`, if `phases.<phase>.skipped != true`, dispatch to `references/render-<phase>.md`. Backward-compat: skipped ⇒ no-op.

- [ ] **Step 4: Commit**

```bash
git add onboard/skills/generation/references/render-{search,caching,realtime,file-uploads,payments}.md \
        onboard/skills/generation/SKILL.md
git commit -m "feat(onboard): R6 — 5 concern-phase generation modules (search/caching/realtime/file-uploads/payments) + SKILL wiring"
```

---

### Task 48: 3 frontend-phase generation modules + plugin split rewire

**Files:**
- Create: `onboard/skills/generation/references/render-frontend-architecture.md`
- Create: `onboard/skills/generation/references/render-design-system.md`
- Create: `onboard/skills/generation/references/render-ux-accessibility-perf.md`
- Modify: `onboard/skills/generation/SKILL.md`

- [ ] **Step 1: Author `render-frontend-architecture.md`**

Output paths: `package.json` (add deps per stateManagement/dataFetching/formHandling choices), `lib/store.ts` (state mgmt skeleton), `lib/queries.ts` (data fetching client init), `app/error.tsx` (if errorBoundaries != "none").

Skip when `phases.frontendArchitecture.skipped == true`.

- [ ] **Step 2: Author `render-design-system.md`**

Output paths: depends on `componentLibrary`:
- `shadcn` → run `npx shadcn-ui@latest init` semantics (or emit `components.json` config)
- `mui` → patch `app/layout.tsx` to wrap with `ThemeProvider` + `tailwind.config.ts` tokens
- `mantine` → `app/layout.tsx` `MantineProvider` wrapper
- `tailwind.config.ts` updates with `typographyScale`, `colorSystem`, `spacingTokens` if not "none"
- `.storybook/main.ts` + `.storybook/preview.ts` when `storybookAdopted == true`

Skip when `phases.designSystem.skipped == true`.

- [ ] **Step 3: Author `render-ux-accessibility-perf.md`**

Output paths: `.github/workflows/lighthouse-ci.yml` (only when CI provider is GHA), `lighthouse.config.js` (CWV budget JSON encoded), `next.config.ts` patch for image optimization, fonts setup snippet (`app/layout.tsx` font import).

For the 3 inline gates: emit `lib/email/marketing-${vendor}.ts` when `concerns.marketingEmail.needed`, `lib/push/${vendor}.ts` when `concerns.pushNotifications.needed`, `lib/analytics/${vendor}.ts` when `concerns.productAnalytics.needed`.

Skip when `phases.uxAccessibilityPerf.skipped == true`.

- [ ] **Step 4: Rewire plugin split inside `onboard/skills/generation/SKILL.md`**

Find any `phases.pluginDiscovery` reference. Replace with the two-phase split:
- For "recommendation" context (read-only metadata): use `phases.pluginRecommendation.{suggested, selected, rationale, frontendAddenda}`.
- For "install" results (used to populate `installedPlugins` in greenfield-meta.json or onboard's generation output): use `phases.pluginInstall.installed`.

Also surface `phases.cicdAndDelivery.lockedYaml`: in the section that writes `.github/workflows/ci.yml` (or equivalent provider path), check for `lockedYaml != null` first — if set, write the locked YAML verbatim instead of regenerating from the legacy logic.

- [ ] **Step 5: Wire into the generation/SKILL.md per-phase loop**

Append to the Round 6 phase renderers table from T47:

```markdown
| frontendArchitecture | `references/render-frontend-architecture.md` | package.json deps + lib skeletons |
| designSystem | `references/render-design-system.md` | shadcn init / theme provider / tailwind tokens |
| uxAccessibilityPerf | `references/render-ux-accessibility-perf.md` | Lighthouse CI + image optimizer + per-gate libs |
```

- [ ] **Step 6: Commit**

```bash
git add onboard/skills/generation/references/render-{frontend-architecture,design-system,ux-accessibility-perf}.md \
        onboard/skills/generation/SKILL.md
git commit -m "feat(onboard): R6 — 3 frontend generation modules + plugin split rewire + cicdAndDelivery.lockedYaml verbatim writes"
```

---

### Task 49: i18n generation module + sprint-contracts.md fix

**Files:**
- Create: `onboard/skills/generation/references/render-i18n-l10n.md`
- Modify: `onboard/skills/generation/SKILL.md`
- Modify: `onboard/skills/generation/references/sprint-contracts.md`

- [ ] **Step 1: Author `render-i18n-l10n.md`**

Output paths:
- `lib/i18n.ts` — library init (next-intl / react-i18next / etc.)
- `messages/<locale>.json` per locale in `targetLocales[]` (en.json as default; each locale gets a skeleton)
- `next.config.ts` patch with `i18n: { locales, defaultLocale }`
- `app/[locale]/layout.tsx` when `delivery == "lazy"` (Next.js dynamic routing)

Skip when `phases.i18nL10n.skipped == true` OR `targetLocales[]` empty.

- [ ] **Step 2: Wire into `onboard/skills/generation/SKILL.md`**

Append to Round 6 phase renderers table:

```markdown
| i18nL10n | `references/render-i18n-l10n.md` | lib/i18n.ts + messages/* + routing config |
```

- [ ] **Step 3: Fix `sprint-contracts.md` (closes R5 follow-up #2)**

Open `onboard/skills/generation/references/sprint-contracts.md`. Find the stale line:

```bash
grep -n "First sprint contract (negotiated or auto-generated)\|sprint contract.*negotiated" onboard/skills/generation/references/sprint-contracts.md
```

Replace with:

```markdown
First sprint contract is **deterministic from R5 onward**: greenfield writes `docs/sprint-contracts/sprint-1.json` directly from `phases.featureRoadmap.sprint1` (see R5 design § Deterministic outputs). The interactive flow described below applies to **sprint 2 onward** at sprint boundaries.
```

- [ ] **Step 4: Commit**

```bash
git add onboard/skills/generation/references/render-i18n-l10n.md \
        onboard/skills/generation/SKILL.md \
        onboard/skills/generation/references/sprint-contracts.md
git commit -m "feat(onboard): R6 — i18n generation module + sprint-contracts.md R5 follow-up #2 fix"
```

---

## Phase L — Tests

### Task 50: Render-common test fixtures (6 helper unit tests) + R5 refactor integration test

**Files:**
- Create: `tests/round-6/render-common/atomic_write_test.sh`
- Create: `tests/round-6/render-common/emit_warning_test.sh`
- Create: `tests/round-6/render-common/check_pii_encryption_test.sh`
- Create: `tests/round-6/render-common/render_handlebars_test.sh`
- Create: `tests/round-6/render-common/emit_dependency_test.sh`
- Create: `tests/round-6/render-common/validate_jq_path_test.sh`
- Create: `tests/round-6/r5-refactor-integration-test.sh`

- [ ] **Step 1: Author one test per helper**

Each test sources `render-common.sh`, exercises the helper, asserts via `jq -e` or `[[ ... ]]`, prints `OK` or `FAIL`.

Example `atomic_write_test.sh`:

```bash
cat > tests/round-6/render-common/atomic_write_test.sh <<'AW'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

TMP=$(mktemp)
_atomic_write "$TMP" "hello world"
[[ "$(cat "$TMP")" == "hello world" ]] || { echo "FAIL: content mismatch"; exit 1; }
[[ ! -f "${TMP}.tmp" ]] || { echo "FAIL: tmp file leaked"; exit 1; }

# Verify tmp-then-rename atomicity: concurrent reader sees either old or new, never partial
echo "initial" > "$TMP"
_atomic_write "$TMP" "updated"
[[ "$(cat "$TMP")" == "updated" ]] || { echo "FAIL: atomic update"; exit 1; }

rm -f "$TMP"
echo "atomic_write: OK"
AW
chmod +x tests/round-6/render-common/atomic_write_test.sh
```

`emit_warning_test.sh`: asserts the appended JSON has correct structure (`id`, `level`, `message`, `addressed: false`).

`check_pii_encryption_test.sh`: gives a PII array with one encrypted and one un-encrypted entry; asserts the un-encrypted entry triggers a warning while the encrypted one doesn't.

`render_handlebars_test.sh`: asserts simple `{{key}}` substitution; asserts nested `{{a.b}}` substitution; asserts missing keys produce empty string (not literal `{{key}}`).

`emit_dependency_test.sh`: sets `DEPS_PATH`, calls `_emit_dependency`, verifies the file contains a valid dependencies record matching `dependencies-schema.json`.

`validate_jq_path_test.sh`: tests both branches — `required=true` with missing path exits non-zero; `required=false` with missing path prints empty string.

- [ ] **Step 2: Author `r5-refactor-integration-test.sh`**

Re-runs R5 smoke tests against the post-refactor renderers (CHECKPOINT 1 verification):

```bash
cat > tests/round-6/r5-refactor-integration-test.sh <<'R5IT'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Running R5 smoke tests against post-R6-refactor renderers..."
bash "${ROOT}/tests/round-5/feature-roadmap-smoke.sh"
bash "${ROOT}/tests/round-5/migration-test.sh"

# Verify every renderer module sources render-common
MISSING=$(grep -L 'source.*render-common' "${ROOT}"/greenfield/scripts/render-*.sh | grep -v render-common.sh || true)
if [[ -n "$MISSING" ]]; then
  echo "FAIL: renderers missing render-common.sh source: $MISSING"
  exit 1
fi
echo "R5-refactor integration: OK"
R5IT
chmod +x tests/round-6/r5-refactor-integration-test.sh
```

- [ ] **Step 3: Smoke + lint all new test scripts**

```bash
shellcheck tests/round-6/render-common/*.sh tests/round-6/r5-refactor-integration-test.sh
for t in tests/round-6/render-common/*.sh; do bash "$t"; done
bash tests/round-6/r5-refactor-integration-test.sh
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add tests/round-6/render-common/ tests/round-6/r5-refactor-integration-test.sh
git commit -m "test(greenfield): R6 — render-common 6 helper unit tests + R5 refactor integration test"
```

---

### Task 51: Per-new-phase smoke fixture + smoke runner (9 phases)

**Files:**
- Create: `tests/round-6/phase-smoke-fixture.json`
- Create: `tests/round-6/phase-smoke.sh`

- [ ] **Step 1: Author `phase-smoke-fixture.json` — alpha.7 state with all 9 new phases populated**

```bash
cat > tests/round-6/phase-smoke-fixture.json <<'FIX'
{
  "meta": { "schemaVersion": "alpha.7" },
  "phases": {
    "stack": { "language": "typescript", "nodeVersion": "20" },
    "architecturalFraming": { "frontendFramework": "next", "topology": "monolith" },
    "personas": { "primary": [{ "id": "P1", "name": "Casual user" }, { "id": "P2", "name": "Power user" }] },
    "dataArchitecture": { "engine": "postgres", "entities": [{ "id": "E001", "name": "User" }, { "id": "E002", "name": "Post" }] },
    "privacy": { "piiFields": [{ "path": "User.email", "encryption": "at-rest" }], "pii": { "financial": true } },
    "auth": { "strategy": "hosted", "concerns": { "transactionalEmail": { "needed": true, "vendor": "resend" }, "sms": { "needed": false, "vendor": null } } },
    "search": { "searchType": "fts", "engine": "postgres-fts", "indexScope": ["User", "Post"], "updateStrategy": "realtime", "qRisks": [] },
    "caching": { "layers": ["cdn", "app"], "cdnProvider": "cloudflare", "invalidationStrategy": "tag-based", "staleWhileRevalidate": true, "qRisks": [] },
    "realtime": { "transport": "sse", "useCases": ["notifications"], "backend": "redis-pubsub", "loopIterations": 2, "qRisks": [] },
    "fileUploads": { "storageBackend": "s3", "uploadFlow": "signed-url", "mimeAllowlist": ["image/png", "image/jpeg"], "piiHandling": "encrypted-at-rest", "loopIterations": 2, "qRisks": [] },
    "payments": { "provider": "stripe", "billingModel": "subscription", "customerPortal": true, "compliance": { "pciScope": "saq-a", "sca": true }, "loopIterations": 2, "qRisks": [] },
    "frontendArchitecture": { "frameworkConfirmed": "next", "stateManagement": "zustand", "dataFetching": "tanstack-query", "loopIterations": 2, "qRisks": [] },
    "designSystem": { "componentLibrary": "shadcn", "themingApproach": "css-variables", "iconSystem": "lucide", "storybookAdopted": true, "qRisks": [] },
    "uxAccessibilityPerf": { "surfacesByPersona": { "P1": ["web-app"], "P2": ["web-app", "admin-dashboard"] }, "a11yTarget": "wcag-aa", "performanceBudgets": { "lcp": 2.5, "inp": 200, "cls": 0.1 }, "concerns": { "marketingEmail": { "needed": true, "vendor": "customer-io" }, "pushNotifications": { "needed": false, "vendor": null }, "productAnalytics": { "needed": true, "vendor": "posthog" } }, "loopIterations": 2, "qRisks": [] },
    "i18nL10n": { "targetLocales": ["en", "es", "fr"], "translationSource": "ai-assisted", "library": "next-intl", "fileFormat": "json", "rtlSupport": false, "qRisks": [] },
    "cicdAndDelivery": { "provider": "gha", "cicd": { "stages": ["lint", "typecheck", "test", "build"], "runners": "ubuntu-latest" }, "concerns": { "featureGating": { "needed": true, "vendor": "posthog-flags" } }, "lockedYaml": null, "adjustHistory": [] },
    "pluginRecommendation": { "suggested": ["vercel:auth", "vercel:ai-sdk"], "selected": ["vercel:auth"], "rationale": "Smoke fixture", "frontendAddenda": [] },
    "pluginInstall": { "installed": [], "failed": [], "skipped": [] }
  },
  "risks": []
}
FIX
```

- [ ] **Step 2: Author `phase-smoke.sh`**

```bash
cat > tests/round-6/phase-smoke.sh <<'PSS'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIX="${SCRIPT_DIR}/phase-smoke-fixture.json"

echo "## Phase smoke — verifying fixture parses + all 9 phases present"

jq empty "$FIX" || { echo "FAIL: fixture not valid JSON"; exit 1; }

for p in search caching realtime fileUploads payments frontendArchitecture designSystem uxAccessibilityPerf i18nL10n; do
  jq -e --arg p "$p" '.phases[$p] != null' "$FIX" >/dev/null || { echo "FAIL: phase $p missing"; exit 1; }
  echo "  phase $p: present"
done

echo "## Gate coherence — CHECK-R6-1"
jq -e '
  [ (.phases.auth.concerns // {}),
    (.phases.uxAccessibilityPerf.concerns // {}),
    (.phases.cicdAndDelivery.concerns // {}) ]
  | map(to_entries[]) | flatten
  | all(.value.needed != true or ((.value.vendor // "") | length > 0))
' "$FIX" || { echo "FAIL: CHECK-R6-1 gate vendor coherence"; exit 1; }

echo "## P5 framework match — CHECK-R6-4"
jq -e '.phases.frontendArchitecture.frameworkConfirmed == .phases.architecturalFraming.frontendFramework' "$FIX" || { echo "FAIL"; exit 1; }

echo "## P5.6 persona coverage — CHECK-R6-5"
jq -e '
  ((.phases.personas.primary // []) + (.phases.personas.secondary // []) | [.[].id]) as $pids
  | $pids | all(. as $id | (.phases.uxAccessibilityPerf.surfacesByPersona[$id] // []) | length > 0)
' "$FIX" || { echo "FAIL"; exit 1; }

echo "## Synthesis template variable presence (sample 3 phases)"
for phase in search caching realtime; do
  TPL="${ROOT}/greenfield/skills/synthesis-review/references/templates/${phase}.html"
  case "$phase" in
    file-uploads|fileUploads) KEY="fileUploads" ;;
    *)                        KEY="$phase" ;;
  esac
  COUNT=$(grep -c "{{${KEY}\." "$TPL" || echo 0)
  [[ "$COUNT" -ge 1 ]] || { echo "FAIL: template $phase has no $KEY placeholders"; exit 1; }
  echo "  template $phase: $COUNT placeholders"
done

echo
echo "phase-smoke: 10/10 OK"
PSS
chmod +x tests/round-6/phase-smoke.sh
```

- [ ] **Step 3: Run smoke**

```bash
bash tests/round-6/phase-smoke.sh
```

Expected: `phase-smoke: 10/10 OK`.

- [ ] **Step 4: Commit**

```bash
git add tests/round-6/phase-smoke-fixture.json tests/round-6/phase-smoke.sh
git commit -m "test(greenfield): R6 — phase-smoke fixture + runner (9 new phases + CHECK-R6 invariants)"
```

---

### Task 52: CI Draft Review smokes (4 providers)

**Files:**
- Create: `tests/round-6/ci-draft-smoke.sh`

- [ ] **Step 1: Author the CI Draft smoke**

```bash
cat > tests/round-6/ci-draft-smoke.sh <<'CIS'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

mk_fixture() {
  local provider="$1"
  local tmp
  tmp=$(mktemp)
  cat > "$tmp" <<EOF
{
  "meta": { "schemaVersion": "alpha.7" },
  "phases": {
    "stack": { "language": "typescript", "nodeVersion": "20" },
    "architecturalFraming": { "frontendFramework": "next" },
    "cicdAndDelivery": {
      "provider": "${provider}",
      "cicd": { "stages": ["lint", "test", "build"], "runners": "ubuntu-latest", "deploy": { "environment": "production" } },
      "adjustHistory": []
    }
  }
}
EOF
  echo "$tmp"
}

PROVIDERS=("gha" "gitlab" "circle" "buildkite")

for p in "${PROVIDERS[@]}"; do
  FIX=$(mk_fixture "$p")
  bash "${ROOT}/greenfield/scripts/render-ci-drafts.sh" "$FIX"
  YAML=$(jq -r '.phases.cicdAndDelivery.draftYaml' "$FIX")
  FALLBACK=$(jq -r '.phases.cicdAndDelivery.draftFallback' "$FIX")

  if [[ -z "$YAML" || "$YAML" == "null" ]]; then
    echo "FAIL: $p produced no YAML"; exit 1
  fi

  case "$p" in
    gha)
      echo "$YAML" | grep -q "name: CI" || { echo "FAIL: gha missing 'name: CI'"; exit 1; }
      [[ "$FALLBACK" == "false" ]] || { echo "FAIL: gha shouldn't be fallback"; exit 1; }
      ;;
    gitlab)
      echo "$YAML" | grep -q "image:" || { echo "FAIL: gitlab missing 'image:'"; exit 1; }
      [[ "$FALLBACK" == "false" ]] || { echo "FAIL: gitlab shouldn't be fallback"; exit 1; }
      ;;
    circle)
      echo "$YAML" | grep -q "version: 2.1" || { echo "FAIL: circle missing 'version: 2.1'"; exit 1; }
      [[ "$FALLBACK" == "false" ]] || { echo "FAIL: circle shouldn't be fallback"; exit 1; }
      ;;
    buildkite)
      echo "$YAML" | grep -q "LLM draft" || { echo "FAIL: buildkite missing LLM banner"; exit 1; }
      [[ "$FALLBACK" == "true" ]] || { echo "FAIL: buildkite should be fallback"; exit 1; }
      ;;
  esac
  echo "  provider $p: OK (fallback=$FALLBACK)"
  rm -f "$FIX"
done

echo
echo "ci-draft-smoke: 4/4 OK"
CIS
chmod +x tests/round-6/ci-draft-smoke.sh
```

- [ ] **Step 2: Run**

```bash
bash tests/round-6/ci-draft-smoke.sh
```

Expected: `ci-draft-smoke: 4/4 OK`.

- [ ] **Step 3: Commit**

```bash
git add tests/round-6/ci-draft-smoke.sh
git commit -m "test(greenfield): R6 — ci-draft-smoke (4 providers: gha, gitlab, circle, fallback)"
```

---

### Task 53: Migration runner golden-output test (alpha.3 → alpha.7)

**Files:**
- Create: `tests/round-6/migrations/alpha-3-fixture.json`
- Create: `tests/round-6/migrations/alpha-7-expected.json`
- Create: `tests/round-6/migrations/golden-output.sh`

- [ ] **Step 1: Author alpha.3 fixture (pre-version-field legacy state)**

```bash
mkdir -p tests/round-6/migrations
cat > tests/round-6/migrations/alpha-3-fixture.json <<'A3FIX'
{
  "phases": {
    "vision": { "appType": "saas" },
    "stack": { "language": "typescript" },
    "auth": { "strategy": "hosted" },
    "pluginDiscovery": { "installed": ["foo"], "suggested": ["bar"], "selected": ["bar"] }
  }
}
A3FIX
```

- [ ] **Step 2: Author expected alpha.7 output (post-migration)**

Run the chain manually to capture the canonical expected state, then commit:

```bash
echo "$(cat tests/round-6/migrations/alpha-3-fixture.json)" \
  | bash greenfield/skills/pickup/migrations/alpha-3-to-4.sh \
  | bash greenfield/skills/pickup/migrations/alpha-4-to-5.sh \
  | bash greenfield/skills/pickup/migrations/alpha-5-to-6.sh \
  | bash greenfield/skills/pickup/migrations/alpha-6-to-7.sh \
  | jq -S . > tests/round-6/migrations/alpha-7-expected.json
```

Manually inspect `tests/round-6/migrations/alpha-7-expected.json` to confirm it has:
- `meta.schemaVersion == "alpha.7"`
- 4 migrations entries in `meta.migrations[]`
- 9 R6 phases inserted with `skipped: true`
- 6 inline gates as `{needed: null}`
- `pluginRecommendation` + `pluginInstall` (no `pluginDiscovery`)
- `cicdAndDelivery.lockedYaml = null`

- [ ] **Step 3: Author the golden-output runner**

```bash
cat > tests/round-6/migrations/golden-output.sh <<'GO'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

FIX="${SCRIPT_DIR}/alpha-3-fixture.json"
EXP="${SCRIPT_DIR}/alpha-7-expected.json"

ACTUAL=$(cat "$FIX" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-3-to-4.sh" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-4-to-5.sh" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-5-to-6.sh" \
  | bash "${ROOT}/greenfield/skills/pickup/migrations/alpha-6-to-7.sh" \
  | jq -S . )

EXPECTED=$(jq -S . "$EXP")

# Compare ignoring the dynamic timestamps in meta.migrations[].at
A_NORM=$(echo "$ACTUAL" | jq 'del(.meta.migrations[].at)')
E_NORM=$(echo "$EXPECTED" | jq 'del(.meta.migrations[].at)')

if [[ "$A_NORM" != "$E_NORM" ]]; then
  echo "FAIL: actual vs expected diff:"
  diff <(echo "$A_NORM") <(echo "$E_NORM") | head -40
  exit 1
fi

# Sanity: 4 migrations applied
COUNT=$(echo "$ACTUAL" | jq '.meta.migrations | length')
[[ "$COUNT" == "4" ]] || { echo "FAIL: expected 4 migrations, got $COUNT"; exit 1; }

# Sanity: pluginDiscovery gone, replaced by split
echo "$ACTUAL" | jq -e '.phases.pluginDiscovery == null and .phases.pluginRecommendation != null and .phases.pluginInstall != null' || { echo "FAIL: plugin split"; exit 1; }

# Sanity: 9 R6 phases present
for p in search caching realtime fileUploads payments frontendArchitecture designSystem uxAccessibilityPerf i18nL10n; do
  echo "$ACTUAL" | jq -e --arg p "$p" '.phases[$p].skipped == true' >/dev/null || { echo "FAIL: $p missing or not skipped"; exit 1; }
done

# Sanity: alpha.7
echo "$ACTUAL" | jq -e '.meta.schemaVersion == "alpha.7"' || { echo "FAIL: schemaVersion"; exit 1; }

# Sanity: previously installed plugins preserved through the split
echo "$ACTUAL" | jq -e '.phases.pluginInstall.installed == ["foo"]' || { echo "FAIL: pluginInstall preservation"; exit 1; }

echo "golden-output: forward walk OK; all sanity checks pass"
GO
chmod +x tests/round-6/migrations/golden-output.sh
```

- [ ] **Step 4: Run**

```bash
bash tests/round-6/migrations/golden-output.sh
```

Expected: `golden-output: forward walk OK; all sanity checks pass`.

- [ ] **Step 5: Test --dry-run path**

```bash
bash greenfield/scripts/run-migrations.sh --from alpha.3 --to alpha.7 \
  --state-file tests/round-6/migrations/alpha-3-fixture.json --dry-run | jq -e '.from == "alpha.3" and .to == "alpha.7" and (.steps | length) == 4'
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add tests/round-6/migrations/
git commit -m "test(greenfield): R6 — migration runner golden-output test (alpha.3 → alpha.7 chain)"
```

---

## Phase M — Docs

### Task 54: `docs/greenfield-3.0-round6/` companion (4 files)

**Files:**
- Create: `docs/greenfield-3.0-round6/overview.md`
- Create: `docs/greenfield-3.0-round6/migration-notes.md`
- Create: `docs/greenfield-3.0-round6/coupling-matrix.md`
- Create: `docs/greenfield-3.0-round6/renderer-architecture.md`

Note: `docs/` is gitignored per the R5 pattern. Use `git add -f` for these files when committing (matches the R5 commit pattern).

- [ ] **Step 1: Author `overview.md`**

Sections: Summary, Scope (in/out), Locked decisions table, Brainstorm-to-merge narrative, Commit log placeholder (`<filled-by-final-task-T57>`).

Use the R5 `docs/greenfield-3.0-round5/overview.md` as a template — same sections, R6-specific content.

- [ ] **Step 2: Author `migration-notes.md`**

User-facing alpha.6 → alpha.7 notes:
- What's new (9 new phases + 6 gates + CI Draft Review + plugin split + lockedYaml + render-common refactor + 5 new schema renderers + migration runner)
- How to migrate in-flight sessions (`/greenfield:pickup` invokes `run-migrations.sh` with `--dry-run` then prompts)
- Generic runner usage examples (`run-migrations.sh --from alpha.6 --to alpha.7 --state-file <path> [--dry-run]`)
- Rollback path (verbatim from spec § Rollback path)
- Breaking changes: **none** (purely additive)

- [ ] **Step 3: Author `coupling-matrix.md`**

Extends R5 matrix with R6 rows. New rows:

| Phase | Reads from | Writes to | Auto-loop |
|---|---|---|---|
| search | dataArchitecture.entities, dataArchitecture.engine | phases.search.* + lib/search.ts + (FTS) prisma migration | flat |
| caching | architecturalFraming.frontendFramework, dataArchitecture.engine | phases.caching.* + lib/cache.ts + CDN headers | flat |
| realtime | personas.primary, runtimeOperations.observability | phases.realtime.* + lib/realtime.ts + realtime API route | per-persona |
| fileUploads | personas.primary, privacy.piiFields | phases.fileUploads.* + lib/uploads.ts + IAM policy | per-persona |
| payments | personas.primary, privacy.pii.financial, security | phases.payments.* + lib/payments/<provider>.ts + webhook + portal | per-persona (customer vs admin) |
| frontendArchitecture | architecturalFraming.frontendFramework, personas.primary | phases.frontendArchitecture.* + package.json deps + lib skeletons | per-persona |
| designSystem | frontendArchitecture.frameworkConfirmed | phases.designSystem.* + shadcn/mui/mantine init + tailwind tokens | flat |
| uxAccessibilityPerf | personas.primary, frontendArchitecture.frameworkConfirmed | phases.uxAccessibilityPerf.* + 3 gates + Lighthouse CI + image optimizer | per-persona |
| i18nL10n | frontendArchitecture.frameworkConfirmed | phases.i18nL10n.* + lib/i18n.ts + messages/* + routing config | flat |
| cicdAndDelivery (CI Draft Review) | stack.language, architecturalFraming.frontendFramework, cicdAndDelivery.cicd, auth, payments | phases.cicdAndDelivery.{draftYaml, lockedYaml, adjustHistory, draftWarnings} | Approve / Adjust / Reject |

Plus a "Inline gates" subsection listing the 6 gates + parent phase + vendor enum.

- [ ] **Step 4: Author `renderer-architecture.md`**

Post-refactor inventory of all 15 renderer modules + the entrypoint dispatch + the shared library:

```markdown
# Renderer architecture (post-R6)

## Module inventory

### Schema renderers (11 total — 6 R5 + 5 R6)

| Module | Triggered when | Library |
|---|---|---|
| render-db-prisma.sh | engine in {postgres,mysql,sqlite} AND language=prisma | render-common.sh |
| render-db-sql-ddl.sh | engine in {postgres,mysql,sqlite} AND language=sql-ddl | render-common.sh |
| render-db-mongoose.sh | engine=mongodb | render-common.sh |
| render-db-drizzle.sh | engine in {postgres,mysql,sqlite} AND language=drizzle | render-common.sh |
| render-api-openapi.sh | style=rest AND language=openapi-3.0 | render-common.sh |
| render-api-graphql.sh | style=graphql AND language=graphql-sdl | render-common.sh |
| render-api-trpc.sh | style=trpc | render-common.sh |
| render-api-hasura.sh | style=hasura | render-common.sh |
| render-event-asyncapi.sh | asyncPattern in {kafka,sns,rabbit} AND language=asyncapi | render-common.sh |
| render-event-json-schema.sh | asyncPattern != none AND language=json-schema | render-common.sh |
| render-event-avro.sh | asyncPattern in {kafka,kinesis} AND language=avro | render-common.sh |

### CI renderers (4 modules + 1 entrypoint)

| Module | Triggered when | Library |
|---|---|---|
| render-ci-drafts.sh (entry) | Step 20 wizard hook | render-common.sh |
| render-ci-gha.sh | provider in {gha, github-actions} | render-common.sh |
| render-ci-gitlab.sh | provider in {gitlab, gitlab-ci} | render-common.sh |
| render-ci-circleci.sh | provider in {circle, circleci} | render-common.sh |
| render-ci-llm-fallback.sh | any other provider | render-common.sh |

## render-common.sh helper API

| Helper | Signature | Purpose |
|---|---|---|
| `_emit_warning <level> <code> <message> <warnings-json>` | returns updated JSON to stdout | append cross-check warning |
| `_check_pii_encryption <path> <pii-array> <warnings-json>` | returns updated JSON | warn if PII has no encryption hint |
| `_atomic_write <target-path> <content>` | side-effect | tmp-then-rename atomic write |
| `_render_handlebars <template> <data-json>` | returns rendered string | minimal `{{key}}` substitution |
| `_emit_dependency <phase> <path> <value> <rationale>` | side-effect (writes to $DEPS_PATH) | append to dependencies.json |
| `_validate_jq_path <state-file> <path> <required>` | returns value or exits non-zero | safe jq read with required-path gate |

## Renderer envelope contract

Every renderer module (schema + CI) returns JSON on stdout:

```json
{ "content": "<rendered text>", "sourceRefs": [{"path": "...", "renderedAs": "..."}], "crossCheckWarnings": [{"id": "...", "level": "warn|error|info", "message": "..."}] }
```

Entrypoints dispatch by `(artifact, language)` (schema) or `provider` (CI) and atomically write back to the state file.
```

- [ ] **Step 5: Commit**

```bash
git add -f docs/greenfield-3.0-round6/
git commit -m "docs(greenfield-3.0): Round 6 companion — overview + migration-notes + coupling-matrix + renderer-architecture"
```

---

### Task 55: `greenfield/CLAUDE.md` + `onboard/CLAUDE.md` + HTML overview/walkthrough updates

**Files:**
- Modify: `greenfield/CLAUDE.md`
- Modify: `onboard/CLAUDE.md`
- Modify: `docs/greenfield-overview.html`
- Modify: `docs/greenfield-walkthrough.html`

- [ ] **Step 1: Update `greenfield/CLAUDE.md` architecture diagram**

Find the ASCII flow block in `greenfield/CLAUDE.md`. Add R6 step entries:

```
│                            ├── Step 7: Search (search phase — Round 6 insert; 11 Qs heavy / 6 light, flat)
│                            ├── Step 9: Caching (caching phase — Round 6 insert; 12 Qs heavy / 7 light, flat)
│                            ├── Step 10: Real-time (realtime phase — Round 6 insert; 12 Qs heavy / 6 light, per-persona)
│                            ├── Step 13: File Uploads & CDN (fileUploads phase — Round 6 insert; 13 Qs heavy / 7 light, per-persona)
│                            ├── Step 15: Payments (payments phase — Round 6 insert; 14 Qs heavy / 7 light, per-persona)
│                            ├── Step 20: CI Draft Review (auto-render via render-ci-drafts.sh; Approve/Adjust/Reject)
│                            ├── Step 21: P7.5 Plugin Recommendation (split from old P10; recommendation mode)
│                            ├── Step 22: P5 Frontend Architecture (frontendArchitecture phase — Round 6 insert)
│                            ├── Step 23: P5.3 Design System (designSystem phase — Round 6 insert)
│                            ├── Step 24: P5.6 UX/A11y/Perf (uxAccessibilityPerf phase — Round 6 insert; hosts 3 inline gates)
│                            ├── Step 25: i18n/l10n (i18nL10n phase — Round 6 insert)
│                            ├── (Re-recommendation pass after Step 25)
│                            ├── Step 30: P10 Plugin Install (split from old P10; install mode)
```

- [ ] **Step 2: Update `greenfield/CLAUDE.md` Skill Hierarchy**

In the `context-gathering/SKILL.md` bullet that enumerates wizard steps, update count `20 → 30` and add R6 step descriptions inline (one line per new step, matching the spec § Wizard step ordering names + Q counts).

In the synthesis-review bullet, append:
```
Round 6 templates added: search.{html,md}, caching.{html,md}, realtime.{html,md}, file-uploads.{html,md}, payments.{html,md}, frontend-architecture.{html,md}, design-system.{html,md}, ux-accessibility-perf.{html,md}, i18n-l10n.{html,md}, ci-draft-review.{html,md}.
```

- [ ] **Step 3: Update `greenfield/CLAUDE.md` Key Patterns**

Add a Round 6 paragraph:

```markdown
- **Round 6 concern phases + inline gates:** 6 concern areas (search, caching, realtime, fileUploads, payments, i18nL10n) get full phases with Q-banks + synthesis review. 6 remaining concerns (transactional email, SMS, marketing email, push notifications, product analytics, feature gating) record as `phases.<parent>.concerns.<gate> = {needed: bool, vendor?: string}` — flat yes/no + vendor pick inside their host phase.
- **Round 6 CI Draft Review:** Step 20 auto-renders CI YAML via `scripts/render-ci-drafts.sh` (dispatches by `phases.cicdAndDelivery.provider` to one of GHA / GitLab / CircleCI vetted renderers or `render-ci-llm-fallback.sh`). User reviews via 3-panel synthesis HTML; Approve writes to `phases.cicdAndDelivery.lockedYaml` for onboard verbatim write at scaffold time.
- **Round 6 render-common.sh:** All 15 renderer modules (11 schema + 4 CI) source `scripts/render-common.sh` for shared helpers (`_emit_warning`, `_check_pii_encryption`, `_atomic_write`, `_render_handlebars`, `_emit_dependency`, `_validate_jq_path`). CI lint enforces the source line via `grep -L 'source.*render-common' scripts/render-*.sh`.
- **Round 6 generic migration runner:** `/greenfield:pickup` invokes `scripts/run-migrations.sh --from <X> --to alpha.7 --state-file <path>` which reads sequential step modules from `skills/pickup/migrations/alpha-N-to-M.sh`. Supports `--dry-run` with JSON diff output. SchemaVersion detection accepts both legacy (`state.schemaVersion`) and canonical (`state.meta.schemaVersion`) locations.
- **Round 6 plugin split:** P10 Plugin Discovery becomes P7.5 Plugin Recommendation (Step 21 — recommendation mode, no install) + P10 Plugin Install (Step 30 — install mode). Re-recommendation pass after Step 25 i18n captures Storybook/i18n-library plugins surfaced after the original Step 21.
```

- [ ] **Step 4: Update `onboard/CLAUDE.md` Round 6 block**

Find any existing Round 4 / Round 5 phase additions block. Add an analogous Round 6 block:

```markdown
## Round 6 phase renderers (onboard-side)

| Phase | Render module | Outputs |
|---|---|---|
| search | `skills/generation/references/render-search.md` | `lib/search.ts` + FTS migration |
| caching | `skills/generation/references/render-caching.md` | `lib/cache.ts` + CDN headers |
| realtime | `skills/generation/references/render-realtime.md` | `lib/realtime.ts` + API route |
| fileUploads | `skills/generation/references/render-file-uploads.md` | `lib/uploads.ts` + IAM policy |
| payments | `skills/generation/references/render-payments.md` | `lib/payments/<provider>.ts` + webhook + portal |
| frontendArchitecture | `skills/generation/references/render-frontend-architecture.md` | package.json deps + lib skeletons |
| designSystem | `skills/generation/references/render-design-system.md` | shadcn/mui/mantine init + tailwind tokens |
| uxAccessibilityPerf | `skills/generation/references/render-ux-accessibility-perf.md` | Lighthouse CI + image optimizer + per-gate libs |
| i18nL10n | `skills/generation/references/render-i18n-l10n.md` | `lib/i18n.ts` + messages + routing config |

Plus: `phases.cicdAndDelivery.lockedYaml` when non-null is written verbatim to `.github/workflows/ci.yml` / `.gitlab-ci.yml` / `.circleci/config.yml` per provider.

Plugin split: `phases.pluginRecommendation` + `phases.pluginInstall` replace the legacy `phases.pluginDiscovery`.
```

- [ ] **Step 5: Update `docs/greenfield-overview.html` Discussion Log**

Find the Discussion Log section. Add a `ROUND 6 LOCKED` entry mirroring the R4/R5 entries:

```html
<details>
  <summary><strong>2026-05-15 — ROUND 6 LOCKED</strong> (Frontend trio + 6 concern phases + 6 gates + CI Draft Review + render-common refactor + plugin reshuffle)</summary>
  <p>Round 6 closes the 6-round greenfield 3.0 wizard overhaul. Adds 9 new top-level phases (3-frontend split + 6 concern phases) and 6 inline yes/no+vendor gates. Wizard grows from 20 → 30 named steps. New Step 20 CI Draft Review auto-renders provider-appropriate YAML (GHA + GitLab + CircleCI + LLM fallback) with 3-panel synthesis review. <code>render-common.sh</code> extracts shared helpers across all 15 renderer modules. Generic migration runner replaces inline cascade in <code>/greenfield:pickup</code>. P10 Plugin Discovery splits into P7.5 Plugin Recommendation (Step 21) + P10 Plugin Install (Step 30). Schema bumps alpha.6 → alpha.7 (auto-migrating). Bundled <code>feat/greenfield-1.5</code> branch, R3-style subagent dispatch (~57 tasks).</p>
</details>
```

- [ ] **Step 6: Update `docs/greenfield-walkthrough.html`**

```bash
grep -n "Planned\|status-planned\|frontend\|Search\|Caching\|Real-time" docs/greenfield-walkthrough.html | head -30
```

For each R6 phase mention currently labeled "Planned" status, promote to "Shipped". If the walkthrough doesn't have these entries yet, add them as Shipped entries in the appropriate phase sections.

- [ ] **Step 7: Commit**

```bash
git add greenfield/CLAUDE.md onboard/CLAUDE.md docs/greenfield-overview.html docs/greenfield-walkthrough.html
git commit -m "docs(greenfield+onboard): R6 — CLAUDE.md updates (30-step wizard, R6 phase additions block) + overview/walkthrough"
```

---

## Phase N — Release + final

### Task 56: Version bumps + marketplace.json + CHANGELOGs

**Files:**
- Modify: `greenfield/.claude-plugin/plugin.json`
- Modify: `onboard/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `greenfield/CHANGELOG.md`
- Modify: `onboard/CHANGELOG-2.0.md`

- [ ] **Step 1: Bump versions**

```bash
jq '.version = "3.0.0-alpha.7"' greenfield/.claude-plugin/plugin.json > /tmp/g.json && mv /tmp/g.json greenfield/.claude-plugin/plugin.json
jq '.version = "2.0.0-alpha.7"' onboard/.claude-plugin/plugin.json > /tmp/o.json && mv /tmp/o.json onboard/.claude-plugin/plugin.json
```

- [ ] **Step 2: Update `marketplace.json`**

```bash
grep -n "alpha.6\|version" .claude-plugin/marketplace.json
```

Update both greenfield's and onboard's `version` field to `3.0.0-alpha.7` / `2.0.0-alpha.7` respectively.

- [ ] **Step 3: Add `greenfield/CHANGELOG.md` entry**

````markdown
## 3.0.0-alpha.7 (2026-05-15) — Round 6

### Added
- 9 new top-level wizard phases (wizard 20 → 30 steps):
  - Step 7 — Search (`search`): 11 Qs heavy / 6 light, flat
  - Step 9 — Caching (`caching`): 12 Qs heavy / 7 light, flat
  - Step 10 — Real-time (`realtime`): 12 Qs heavy / 6 light, per-persona
  - Step 13 — File Uploads & CDN (`fileUploads`): 13 Qs heavy / 7 light, per-persona
  - Step 15 — Payments (`payments`): 14 Qs heavy / 7 light, per-persona
  - Step 22 — P5 Frontend Architecture (`frontendArchitecture`): 13 Qs heavy / 7 light, per-persona
  - Step 23 — P5.3 Design System (`designSystem`): 12 Qs heavy / 6 light, flat
  - Step 24 — P5.6 UX/A11y/Perf (`uxAccessibilityPerf`): 15 Qs heavy / 8 light, per-persona, hosts 3 inline gates
  - Step 25 — i18n/l10n (`i18nL10n`): 11 Qs heavy / 6 light, flat
- 6 inline gates recording `{needed, vendor?}` to `phases.<parent>.concerns.<gate>`:
  - `auth.concerns.transactionalEmail` (vendors: resend / postmark / ses / sendgrid)
  - `auth.concerns.sms` (vendors: twilio / vonage / messagebird)
  - `uxAccessibilityPerf.concerns.marketingEmail` (customer-io / loops / resend-audiences / mailchimp)
  - `uxAccessibilityPerf.concerns.pushNotifications` (fcm / onesignal / pusher-beams)
  - `uxAccessibilityPerf.concerns.productAnalytics` (posthog / mixpanel / amplitude / plausible)
  - `cicdAndDelivery.concerns.featureGating` (posthog-flags / launchdarkly / flagsmith / growthbook)
- Step 20 CI Draft Review with provider-dispatch renderer:
  - `scripts/render-ci-drafts.sh` (entrypoint)
  - `scripts/render-ci-gha.sh`, `render-ci-gitlab.sh`, `render-ci-circleci.sh` (vetted)
  - `scripts/render-ci-llm-fallback.sh` (LLM fallback with banner + CHECK-R6-8 hard ack gate)
- `scripts/render-common.sh` shared helper library (6 helpers) sourced by all 15 renderer modules
- 5 deferred R5 schema renderers shipped (closes R5 O-R5-3): `render-db-mongoose.sh`, `render-db-drizzle.sh`, `render-api-trpc.sh`, `render-api-hasura.sh`, `render-event-avro.sh`
- Generic migration runner `scripts/run-migrations.sh` + 4 step modules under `skills/pickup/migrations/`
- 9 cross-phase invariants (CHECK-R6-1 through CHECK-R6-9)
- Plugin split: P7.5 Plugin Recommendation (Step 21, recommendation mode, no install) + P10 Plugin Install (Step 30, install mode); re-recommendation pass after Step 25
- 10 synthesis template triples: 9 phase templates + ci-draft-review
- 3 new health-check assertions in `/greenfield:check`
- Pickup migration shim: alpha.6 → alpha.7 (auto-migrating, additive)
- Smoke tests: `tests/round-6/phase-smoke.sh` (9 phases + R6 invariants), `tests/round-6/ci-draft-smoke.sh` (4 providers), `tests/round-6/render-common/*.sh` (6 helpers), `tests/round-6/migrations/golden-output.sh` (alpha.3 → alpha.7 chain)

### Changed
- Wizard step count 20 → 30
- `pickup/SKILL.md`: inline migration cascade replaced by `run-migrations.sh` invocation; schemaVersion detection now `jq -r '.meta.schemaVersion // .schemaVersion // "unknown"'` (canonical + legacy)
- All 6 R5 renderer modules refactored to source `render-common.sh` (single revertable commit per R-R6-4 mitigation)
- `plugin-discovery/SKILL.md`: split into recommendation vs install modes
- `tooling-generation/SKILL.md`: pass-through additions for 9 new phases + plugin split + `cicdAndDelivery.lockedYaml`

### Migration
- Auto-migrating via `/greenfield:pickup`. The pickup skill invokes `run-migrations.sh` with `--dry-run` first, shows the JSON diff via `AskUserQuestion`, requires explicit approval, then applies atomically.
- Sessions predating alpha.7 get `{skipped: true, deferredReason}` defaults on the 9 new phases and `{needed: null, vendor: null}` defaults on the 6 inline gates. Re-enter the relevant Steps via Adjust mode to populate.
- `phases.pluginDiscovery` is migrated to `phases.pluginRecommendation` + `phases.pluginInstall`; `installed[]` preserved across the split.

### Rollback
- Single revert commit on develop reverts the R6 PR.
- The `render-common.sh` refactor (T4) lands as a separately revertable commit; reverting it leaves the R5 renderers using their pre-R6 inline helper logic.
- alpha.7 sessions calling alpha.6 pickup gracefully drop unknown R6 fields (the legacy pickup ignores unknown top-level phase keys).
- `--dry-run` mode of the migration runner can be used diagnostically; no auto-downgrade path is shipped (recover via git revert).
````

- [ ] **Step 4: Add `onboard/CHANGELOG-2.0.md` entry**

````markdown
## 2.0.0-alpha.7 (2026-05-15) — Round 6 schema additions

### Added
- `context-shape-v2.json`: 9 new phase blocks (`search`, `caching`, `realtime`, `fileUploads`, `payments`, `frontendArchitecture`, `designSystem`, `uxAccessibilityPerf`, `i18nL10n`); replaces the legacy `frontend` $ref stub with the full `frontendArchitecture` block.
- `inlineGate` definition + 6 `concerns.<gate>` slots inside `auth`, `uxAccessibilityPerf`, and `cicdAndDelivery`.
- `phases.cicdAndDelivery.lockedYaml: string|null` + `phases.cicdAndDelivery.adjustHistory[]` audit array.
- `phases.pluginRecommendation` (suggested + selected + rationale + frontendAddenda) + `phases.pluginInstall` (installed + failed + skipped); replaces the legacy `phases.pluginDiscovery`.
- 9 new generation reference modules under `skills/generation/references/render-<phase>.md` (one per R6 phase).
- `generation/SKILL.md`: deterministic per-phase rendering for the 9 new phases; verbatim `cicdAndDelivery.lockedYaml` write at scaffold time.
- `generation/references/sprint-contracts.md`: corrected the stale "First sprint contract (negotiated or auto-generated)" wording (closes R5 follow-up #2).

### Backward compatibility
- Any new phase with `skipped: true` ⇒ generation module emits nothing (mirrors R5 pattern).
- If `cicdAndDelivery.lockedYaml == null` ⇒ generation falls back to the existing CI templates path (alpha.6 behavior).
- Legacy `phases.pluginDiscovery` consumers continue to work for one minor version via the migration shim — onboard reads from `phases.pluginRecommendation` + `phases.pluginInstall` first, falls back to `pluginDiscovery` if both absent.
````

- [ ] **Step 5: Commit**

```bash
git add greenfield/.claude-plugin/plugin.json onboard/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        greenfield/CHANGELOG.md onboard/CHANGELOG-2.0.md
git commit -m "chore(release): R6 — version bumps to alpha.7 + CHANGELOGs"
```

---

### Task 57: Validate sweep + smoke + branch push + PR + memory update

**Files:**
- (none modified — verification + branch push + PR)

- [ ] **Step 1: Run `/validate`**

In the Claude Code interface, invoke `/validate`. Expected: all 4 plugins pass (onboard, greenfield, notify, handoff).

If invoking from bash: ensure the validation skill's shellcheck + JSON validation passes:

```bash
# Manifest JSON valid
jq empty greenfield/.claude-plugin/plugin.json onboard/.claude-plugin/plugin.json .claude-plugin/marketplace.json

# Context shape valid
jq empty onboard/skills/generate/references/context-shape-v2.json

# Dependencies-schema valid
jq empty greenfield/skills/synthesis-review/references/dependencies-schema.json

# All renderer scripts ShellCheck-clean
shellcheck greenfield/scripts/render-*.sh
shellcheck greenfield/scripts/run-migrations.sh
shellcheck greenfield/skills/pickup/migrations/*.sh
shellcheck tests/round-6/render-common/*.sh tests/round-6/*.sh tests/round-6/migrations/*.sh

# Render-common is sourced by every renderer
MISSING=$(grep -L 'source.*render-common' greenfield/scripts/render-*.sh | grep -v render-common.sh || true)
[[ -z "$MISSING" ]] || { echo "FAIL: $MISSING"; exit 1; }
```

Expected: all silent (exit 0); no MISSING list.

- [ ] **Step 2: Re-run all smoke tests (full sweep)**

```bash
# R5 still passing post-refactor
bash tests/round-5/feature-roadmap-smoke.sh
bash tests/round-5/migration-test.sh

# R6 new smoke
bash tests/round-6/r5-refactor-integration-test.sh
for t in tests/round-6/render-common/*.sh; do bash "$t"; done
bash tests/round-6/phase-smoke.sh
bash tests/round-6/ci-draft-smoke.sh
bash tests/round-6/migrations/golden-output.sh
```

Expected: all ✓, exit 0 across the board.

- [ ] **Step 3: Verify file counts**

```bash
# Count new files
git diff develop --name-status | grep '^A' | wc -l
# Expected: ~70 new files

git diff develop --name-status | grep '^M' | wc -l
# Expected: ~50 modified files

# Total
git diff develop --name-status | wc -l
# Expected: ~120 files total — matches design estimate
```

- [ ] **Step 4: Verify no leftover TODO / TBD / placeholder strings**

```bash
git diff develop -- greenfield/ onboard/ tests/round-6/ docs/greenfield-3.0-round6/ | grep -E '^\+.*(TODO|TBD|FIXME|XXX|fill in later)' | head -10
```

Expected: no output. If matches → fix and amend.

- [ ] **Step 5: Verify every gate vendor enum is consistent**

```bash
# Compare Q-bank vendors with context-shape inlineGate-using slots
grep -E "vendors:.*\[" greenfield/skills/context-gathering/references/*.q-bank.md
```

Expected: lists match those documented in spec § 6 inline gates.

- [ ] **Step 6: Push branch + open PR**

```bash
git push -u origin feat/greenfield-1.5

gh pr create --title "feat(greenfield)!: 3.0.0-alpha.7 — Round 6 (Frontend trio + 6 concern phases + 6 gates + CI Draft Review + render-common refactor + plugin reshuffle)" \
  --body "$(cat <<'EOF'
## Summary

Round 6 closes the locked 6-round greenfield 3.0 wizard overhaul.

- **9 new top-level wizard phases**: 3-way frontend split (P5 Architecture / P5.3 Design System / P5.6 UX/A11y/Perf) + 6 concern phases (search, caching, realtime, fileUploads, payments, i18nL10n)
- **6 inline gates**: transactionalEmail / SMS (in Auth Step 11), marketingEmail / pushNotifications / productAnalytics (in UX Step 24), featureGating (in CI/CD Step 19) — each `{needed, vendor?}`
- **New Step 20 CI Draft Review**: auto-renders provider-appropriate YAML via dispatched per-provider modules (GHA + GitLab + CircleCI vetted; LLM fallback for the long tail with CHECK-R6-8 ack gate)
- **`render-common.sh` shared library**: extracts 6 helpers across all 15 renderer modules (11 schema + 4 CI); CI lint enforces source
- **5 deferred schema renderers shipped**: render-db-mongoose, render-db-drizzle, render-api-trpc, render-api-hasura, render-event-avro
- **Generic migration runner**: replaces inline pickup cascade; supports `--dry-run` + JSON diff
- **Plugin reshuffle**: P10 → P7.5 Recommendation (Step 21) + P10 Install (Step 30); re-recommendation pass after Step 25 i18n
- **9 cross-phase invariants** (CHECK-R6-1 through CHECK-R6-9) wired into grill-spec

**Wizard step count:** 20 → 30.
**Schema bump:** `alpha.6 → alpha.7` (auto-migrating via pickup → `run-migrations.sh`).
**Source spec:** `docs/superpowers/specs/2026-05-15-greenfield-3.0-round6-design.md`
**Plan:** `docs/superpowers/plans/2026-05-15-greenfield-3.0-round6-implementation.md`

## Test plan

- [ ] `/validate` passes on all 4 plugins
- [ ] `tests/round-6/phase-smoke.sh` — 9 phases + R6 invariants pass
- [ ] `tests/round-6/ci-draft-smoke.sh` — 4 providers (gha, gitlab, circle, fallback) emit valid YAML
- [ ] `tests/round-6/render-common/*.sh` — 6 helper unit tests pass
- [ ] `tests/round-6/r5-refactor-integration-test.sh` — R5 smoke still green post-`render-common.sh` extraction
- [ ] `tests/round-6/migrations/golden-output.sh` — alpha.3 → alpha.7 chain walks cleanly and matches golden
- [ ] Manual: trigger Step 20 CI Draft Review with each of the 4 providers; verify 3-panel review renders + Approve writes lockedYaml + Adjust appends to adjustHistory
- [ ] Manual: invoke `/greenfield:pickup` on an alpha.6 fixture; verify `run-migrations.sh --dry-run` surfaces the diff and `--no-dry-run` writes atomically
- [ ] Manual: verify CHECK-R6-1 through CHECK-R6-9 hard-fail when expected
- [ ] Manual: trigger Step 7/9/10/13/15/22/23/24/25 individually in a fresh wizard run; verify each synthesis template renders

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7: Update memory + companion overview commit log**

After PR creation, update `~/.claude/projects/-Users-apurvbazari-Desktop-projects-claude-plugins/memory/project_greenfield_3_0_design.md` with the R6 status + PR number + commit count + key surprises.

Update `docs/greenfield-3.0-round6/overview.md` commit log placeholder:

```bash
git log --oneline feat/greenfield-1.5 ^develop | head -60
```

Paste into the commit log placeholder, then amend the docs commit if needed (force-add since `docs/` is gitignored).

---

## Self-Review Checklist

Run these before handing off to subagent dispatch:

**1. Spec coverage scan:**

Each of the 44 in-scope deliverables in spec § Scope maps to at least one task. Mapping:

- Items 1–3 (Frontend trio P5/P5.3/P5.6) → T26 (Q-bank), T27 (Q-bank), T28 (Q-bank), T36 (template), T37 (template), T38 (template), T48 (generation)
- Items 4–9 (6 concern phases) → T21, T22, T23, T24, T25, T29 (Q-banks); T31, T32, T33, T34, T35, T39 (templates); T47, T49 (generation)
- Items 10–15 (6 inline gates) → T28 (3 in ux-accessibility-perf.q-bank.md), T30 (3 in auth + cicd)
- Item 16 (CI Draft Review synthesis step) → T15 (template) + T40 (wizard wiring)
- Item 17 (CI renderer entrypoint) → T10
- Item 18 (3 vetted CI renderers) → T11 (GHA), T12 (GitLab), T13 (CircleCI)
- Item 19 (LLM-fallback CI renderer) → T14
- Item 20 (CI synthesis template triple) → T15
- Items 21–23 (Plugin reshuffle) → T40 (wizard Step 21 + 30 + re-recommendation), T43 (plugin-discovery split)
- Item 24 (render-common shared library) → T3
- Item 25 (R5 renderer refactor) → T4
- Item 26 (5 new schema renderers) → T5, T6, T7, T8, T9
- Item 27 (generic migration runner) → T16
- Item 28 (4 migration step modules) → T17, T18, T19
- Item 29 (pickup SKILL.md refactor) → T20
- Item 30 (9 deterministic generation modules) → T47, T48, T49
- Item 31 (schema updates in context-shape-v2.json) → T1
- Item 32 (dependencies-schema.json updates) → T2
- Items 33 (CHECK-R6-1..9 invariants) → T45
- Item 34 (3 new health-check assertions) → T46
- Item 35 (render-common test fixtures) → T50
- Item 36 (per-phase smoke tests) → T51, T52
- Item 37 (migration runner test) → T53
- Item 38 (companion docs) → T54
- Item 39 (CLAUDE.md updates) → T55
- Item 40 (Discussion Log entry) → T55
- Item 41 (greenfield-walkthrough.html updates) → T55
- Item 42 (CHANGELOG entries) → T56
- Item 43 (version bumps) → T56
- Item 44 (sprint-contracts.md doc fix) → T49

✅ All 44 deliverables covered.

**2. Placeholder scan:**

- ✅ No "TBD" / "TODO" / "fill in later" / "implement later" in task bodies (T57 Step 4 enforces).
- ✅ Every renderer script (T3, T5–T14, T16) has a concrete content heredoc — no skeleton placeholders.
- ✅ Every Q-bank task (T21–T29) lists field names with concrete options/enums; T22, T23, T24, T25, T26, T27, T28, T29 use a structural table pointing back to T21's full-detail example, which is acceptable for the R3-style implementer template.

**3. Type consistency:**

- ✅ Schema property names (`phases.search.*`, `phases.caching.*`, etc.) match across T1 (schema), T21–T29 (Q-banks `Stores to:`), T31–T39 (template Handlebars), T45 (invariant jq paths), T47–T49 (generation references).
- ✅ Renderer envelope keys (`content`, `sourceRefs`, `crossCheckWarnings`) consistent across T3 (library helpers) and T5–T14 (renderer modules).
- ✅ Inline gate field names (`needed`, `vendor`, `notes`) consistent across T1 (`inlineGate` definition), T19 (alpha-6-to-7 migration), T28 + T30 (Q-bank snippets), T45 (CHECK-R6-1).
- ✅ Migration step protocol (stdin JSON → stdout JSON) consistent across T16 (runner) and T17, T18, T19 (step modules).

**4. Mid-execution checkpoints documented:**

- ✅ Checkpoint 1 (after Phase A + B) — R5 smoke tests + render-common compatibility.
- ✅ Checkpoint 2 (after Phase D + E) — renderer contract + migration runner.
- ✅ Checkpoint 3 (after Phase F + G) — template ↔ Q-bank path consistency.

**5. Rollback path:**

Documented in T54 migration-notes.md, T55 CLAUDE.md Key Patterns, T56 CHANGELOG entries (both plugins). Three-tier:
1. `git revert <merge-commit>` on develop reverts code
2. `render-common.sh` refactor (T4) is a separately revertable commit per R-R6-4 mitigation
3. `--dry-run` mode of the migration runner enables diagnostic comparison; no auto-downgrade

**6. R6-specific risks mitigated by plan structure:**

- R-R6-1 (30-step wizard length): per-step skip option preserved; mode toggles already in place (no new mitigation needed in plan).
- R-R6-2 (113 new Heavy Qs): T45 wires CHECK-R6-1..9 invariants at synthesis review boundary.
- R-R6-3 (LLM-fallback YAML may fail): T14 includes YAML-lint stub check + emits banner; T45 CHECK-R6-8 hard-requires `addressed=true`.
- R-R6-4 (render-common refactor breaks R5 renderers): T4 lands as single revertable commit; CHECKPOINT 1 re-runs R5 smoke; T50 integration test.
- R-R6-5 (migration runner bug not caught by linear pattern): T16 `--dry-run` mode + explicit approval before atomic write; T53 golden-output test fixtures.
- R-R6-6 (P7.5 misses context from later P5 phases): T40 frontend re-recommendation pass after Step 25.
- R-R6-7 (broken-ref opportunities): CHECKPOINT 3 + T45 invariants.
- R-R6-8 (renderer proliferation): T4 + CI lint check enforced in T57.
- R-R6-9 (auto-loop feature-explosion): T41 documents the cap; T45 CHECK-R6-9 enforces.
- R-R6-10 (LLM Adjust silent regressions): `adjustHistory[]` audit array added in T1; T15 template displays diff.
- R-R6-11 (plugin install fails at Step 30): T40 Step 30 surfaces `failed[]` before scaffold + provides abort/proceed AskUserQuestion.

---

## Notes for executor

- **R3/R5-style subagent dispatch:** dispatch one fresh subagent per task. After each task, review the commit before moving on. ~70-110 subagent invocations across 57 tasks (implementer + occasional review/fix). Cross-cutting reconciliation commits may be needed mid-execution if field-name divergences surface (R3 lesson, see `dea9d2c`; R5 lesson, see `7a31642`).
- **Branch hygiene:** All work lands on `feat/greenfield-1.5` off `develop`. One commit per task. Squash on merge.
- **Schema additions are purely additive** — no breaking changes for alpha.6 consumers. The pickup runner + alpha-6-to-7 step (T19) lifts old state forward automatically.
- **The render-common.sh refactor (T4)** must remain a single commit to preserve the revert path. If the refactor batch fails review, revert and continue with the inline pattern; do NOT amend other tasks' commits to absorb the refactor.
- **The CI Draft Review (T10–T15, Step 20)** mirrors R5 P10.5's auto-render mechanic but adds three new wrinkles: per-provider dispatch, LLM-fallback path, and the `adjustHistory[]` audit array. Implementers must respect the `lockedYaml` write-only-on-Approve contract (do NOT write `lockedYaml` before user picks Approve).
- **`docs/` is gitignored** — every commit touching `docs/superpowers/plans/`, `docs/greenfield-3.0-round6/`, or other under-docs files must use `git add -f` (R5 pattern). T54 + T57 explicitly call this out.
- **Tests in `tests/round-6/`** are structural smoke (no live onboard invocation). They verify the fixture state is internally consistent, the migration logic is deterministic, the renderer modules emit valid envelopes, and the CHECK-R6 invariants hold against synthesized state. Manual end-to-end verification is in the T57 PR test plan.
- **Generation references (T47–T49)** are markdown files documenting the per-phase render rules — they're consumed by `onboard:generate` to drive deterministic file emission. They're not executable scripts; their contracts are read by the generation skill at runtime.
- **`/greenfield:pickup` schemaVersion gate hardening (T20)** is the only behavior change that can affect alpha.4 / alpha.5 / alpha.6 sessions — verify the dry-run gate before atomic write step is wired in cleanly (R-R6-5 mitigation).
