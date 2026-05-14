# Greenfield 3.0 Round 6 — Frontend Trio + 6 Concern Phases + 6 Gates + CI Draft Review + Renderer Refactor + Plugin Reshuffle

- **Branch:** `feat/greenfield-1.5` (proposed; new branch for Round 6, off `develop`)
- **Date:** 2026-05-15
- **Inherits from:** Rounds 1+2+2.5+3+4+5 (shipped at `greenfield@3.0.0-alpha.6` / `onboard@2.0.0-alpha.6`); `project_greenfield_3_0_design.md` memory; Round 5 design doc `2026-05-15-greenfield-3.0-round5-design.md`
- **Estimated files touched:** ~100–130 unique files (~70 new + ~50 modified) across `greenfield/`, `onboard/`, `tests/round-6/`, `docs/greenfield-3.0-round6/`, root `marketplace.json`
- **Target versions on completion:** `greenfield@3.0.0-alpha.7`, `onboard@2.0.0-alpha.7`
- **Execution model:** Big-bang single round, R3-style subagent dispatch (~50–70 implementer tasks + occasional fix subagents)
- **Schema bump posture:** Additive — alpha.6 sessions auto-migrate via `/greenfield:pickup` shim (continues R4/R5 pattern)
- **Wizard step count:** 20 → 30 named steps

## Summary

Round 6 is the final round of the locked 6-round greenfield 3.0 wizard overhaul. It closes three remaining gaps:

1. **Frontend/UX expansion** — the original P5 stub becomes a three-phase split (Architecture, Design System, UX/A11y/Performance) to match the rigor R3 applied to auth (4-way split).
2. **12 never-asked concern areas** — split into 6 full phases (caching, payments, real-time, search, i18n+l10n, file uploads & CDN — the ones that materially shape data/API/infra/frontend) and 6 inline yes/no+vendor gates (transactional email, SMS, marketing email, push notifications, product analytics, feature gating — vendor-pick decisions that don't ripple architecturally).
3. **Non-GHA CI providers** — extends R5's auto-render + Approve/Adjust/Reject pattern to CI YAML, with 3 vetted per-provider renderers (GHA + GitLab + CircleCI) and an LLM fallback for the long tail (Azure, Bitbucket, Buildkite, Jenkins, etc.).

R6 also bundles four tech-debt items flagged during R5:

- **`render-common.sh` shared library extraction** — consolidates helpers duplicated across R5's 6 schema renderers + R6's 9 new renderers (15 modules post-R6)
- **Generic migration runner** — replaces inline linear-unwind logic in pickup with a self-contained migration framework
- **Pickup `schemaVersion` gate hardening** — accepts both nested (`state.meta.schemaVersion`, canonical since alpha.6) and top-level (legacy) locations
- **Extra schema renderers** — Mongoose, Drizzle, tRPC, Hasura, Avro (R5 deferred per O-R5-3)

The wizard grows from 20 steps to **30 named steps**. Schema bumps `alpha.6 → alpha.7`; in-flight alpha.6 sessions auto-migrate on `/greenfield:pickup` via the new generic migration runner.

Architecturally, R6 follows the playbook R5 established: deterministic generation paths in onboard for every new phase, auto-rendered drafts surfaced through synthesis review with Approve/Adjust/Reject, and atomic-write file outputs. The new departure is the LLM-fallback Adjust path — used for CI Draft Review when the provider falls outside the vetted three, with a hard-required user acknowledgment gate.

After R6 ships, greenfield 3.0 is feature-complete for the 6-round overhaul; v3.1+ work shifts to extension (more renderer languages, more CI providers, additional concern domains) rather than structural expansion.

## Scope

### In scope (Round 6 deliverables)

#### Frontend trio (3 new phases)

1. **P5 Frontend Architecture** at Step 22 (~13 Qs heavy / ~7 light) — framework confirmation (cross-refs `phases.architecturalFraming.frontendFramework`), state management, routing strategy, data fetching library, form handling, animation library, error boundaries, code-splitting strategy, build/bundler, dev server, Q_RISK trailer. Per-persona auto-loop in `auto-loop` mode.
2. **P5.3 Design System** at Step 23 (~12 Qs heavy / ~6 light) — component library (build vs adopt), theming approach (CSS vars / tokens / multiple themes), primitives strategy, variant system, icon system, typography scale, color system, spacing tokens, design tool integration (Figma/Penpot), Storybook adoption, Q_RISK trailer. Flat (single design system spans all surfaces).
3. **P5.6 UX / Accessibility / Performance** at Step 24 (~15 Qs heavy / ~8 light) — per-persona surface mapping (web app, mobile web, native, admin dashboard), responsiveness strategy, breakpoint system, a11y target (WCAG A/AA/AAA), keyboard navigation strategy, screen-reader testing approach, performance budgets (Core Web Vitals: LCP, INP, CLS), image optimization, font loading strategy, error/empty/loading states UX, offline support, Q_RISK trailer. Per-persona auto-loop in `auto-loop` mode. Hosts 3 inline gates (marketing email, push notifications, product analytics).

#### 6 concern phases

4. **Search** at Step 7 (~11 Qs heavy / ~6 light) — placement after Data Architecture (consumes entity model). Topics: search type (FTS vs vector vs hybrid vs none), engine (Postgres FTS / Meilisearch / Typesense / Elasticsearch / pgvector / Pinecone / Weaviate), index scope, update strategy (real-time vs batch), query patterns (filters / facets / autocomplete / semantic), ranking, A/B testing, security (RLS, query auth). Flat.
5. **Caching** at Step 9 (~12 Qs heavy / ~7 light) — placement after API Integration. Topics: caching layers (CDN / edge / app / DB query / browser), CDN provider, cache invalidation strategy (TTL / tag-based / manual), stale-while-revalidate, cache key design, multi-tenant cache isolation, observability (hit rates), cache stampede protection. Flat.
6. **Real-time** at Step 10 (~12 Qs heavy / ~6 light) — placement after Caching. Topics: transport (SSE / WebSocket / long-poll / push), use cases (notifications / presence / collaboration / live data), backend (Redis pub-sub / dedicated service / channels), client lib (Pusher / Ably / Soketi / native), scaling (sticky sessions / horizontal), reconnect strategy, message ordering & dedup. Per-persona auto-loop.
7. **File Uploads & CDN** at Step 13 (~13 Qs heavy / ~7 light) — placement after Privacy (PII classification needed). Topics: storage backend (S3 / R2 / GCS / Azure Blob), upload flow (signed URLs / direct / server-proxied), CDN provider, image transforms (Imgix / Cloudinary / native), max file size, MIME validation, virus scanning, PII handling, retention policy, multi-tenant isolation. Per-persona auto-loop.
8. **Payments** at Step 15 (~14 Qs heavy / ~7 light) — placement after Security (PCI/compliance scope needed). Topics: provider (Stripe / Lemon Squeezy / Paddle / Razorpay), billing model (one-time / subscription / usage-based / marketplace), customer portal, tax handling, dunning, webhook strategy, fraud prevention, refund flow, currency/locale, compliance (PCI scope, SCA, regulatory). Per-persona auto-loop (customer-facing vs admin).
9. **i18n / l10n** at Step 25 (~11 Qs heavy / ~6 light) — placement after P5.6 UX (frontend concern). Topics: target locales, translation source (manual / AI-assisted / hybrid), library (next-intl / react-i18next / formatjs / native Intl), translation file format (JSON / PO / XLIFF), RTL support, date/number/currency formatting per locale, plural rules, content translation flow, CDN vs bundled, dynamic vs static text, SEO (hreflang). Flat.

#### 6 inline gates (each: 1 yes/no Q + optional vendor-pick when "yes")

10. **Transactional email** gate in Step 11 Auth (vendors: Resend / Postmark / SES / SendGrid) — password reset, magic links, verification emails
11. **SMS** gate in Step 11 Auth (vendors: Twilio / Vonage / MessageBird) — 2FA, OTP, account alerts
12. **Marketing email** gate in Step 24 P5.6 UX (vendors: Customer.io / Loops / Resend Audiences / Mailchimp) — drip campaigns, broadcasts
13. **Push notifications** gate in Step 24 P5.6 UX (vendors: FCM / OneSignal / Pusher Beams) — mobile/web push
14. **Product analytics** gate in Step 24 P5.6 UX (vendors: PostHog / Mixpanel / Amplitude / Plausible) — funnels, retention
15. **Feature gating** gate in Step 19 CI/CD (vendors: PostHog feature flags / LaunchDarkly / Flagsmith / GrowthBook) — release pipeline integration

Each gate records to `phases.<parent>.concerns.<gateName> = { needed: boolean, vendor?: string, notes?: string }`.

#### CI Draft Review (new Step 20)

16. **CI Draft Review** synthesis step — mirrors R5 P10.5 Schema Draft Review. Fires after Step 19 CI/CD captures answers. Auto-renders provider-appropriate YAML mid-flow; surfaces 3-panel synthesis HTML (Inputs / Decisions log / Rendered YAML); user Approves / Adjusts (LLM edits inline) / Rejects (returns to Step 19).
17. **CI renderer entrypoint** `greenfield/scripts/render-ci-drafts.sh` — dispatches by `phases.cicdAndDelivery.provider` to per-provider module
18. **Per-provider CI renderers** — `render-ci-gha.sh` (existing GHA logic ported to module form), `render-ci-gitlab.sh` (NEW), `render-ci-circleci.sh` (NEW)
19. **LLM-fallback CI renderer** `render-ci-llm-fallback.sh` — used when `provider` falls outside {gha, gitlab, circleci}. Emits draft with a `"⚠ LLM draft — review carefully"` banner in Panel 3.
20. **3-file synthesis template triple** — `templates/ci-draft-review.html`, `ci-draft-review.md`, `ci-draft-review-dependencies.json.example`

#### P7.5 / P10 Plugin Reshuffle

21. **P7.5 Plugin Recommendation** at Step 21 (split from current single P10) — fires after CI/CD + CI Draft Review so plugin recommendations are informed by infra + testing + observability context. Calls `plugin-discovery` skill in "recommendation mode". Writes `phases.pluginRecommendation = {suggested, selected, rationale}`. Does NOT install.
22. **P10 Plugin Install** at Step 30 (split half — actual install retained at end) — fires just before scaffold handoff. Reads `phases.pluginRecommendation.selected`, calls `plugin-discovery` skill in "install mode". Writes `phases.pluginInstall = {installed, failed, skipped}`.
23. **Re-recommendation pass** after Step 25 i18n/l10n — re-invokes plugin-discovery with frontend + i18n context; if new suggestions surface (Storybook from P5.3, i18n library plugins from Step 25, etc.), prompts user via single `AskUserQuestion` to add to install set. Records to `phases.pluginRecommendation.frontendAddenda`. Placed after Step 25 (the last frontend-context phase) so both P5.3 design-system and P5.6 UX picks AND i18n library picks inform the addendum pass.

#### Renderer refactor + tech debt

24. **`render-common.sh` shared library** — extracts 6 helpers shared across all renderers (`_emit_warning`, `_check_pii_encryption`, `_atomic_write`, `_render_handlebars`, `_emit_dependency`, `_validate_jq_path`)
25. **R5 renderer refactor** — all 6 R5 schema renderers (`render-db-prisma.sh`, `render-db-sql-ddl.sh`, `render-api-openapi.sh`, `render-api-graphql.sh`, `render-event-asyncapi.sh`, `render-event-json-schema.sh`) refactored to source `render-common.sh`. CI lint check (`grep -L 'source.*render-common' scripts/render-*.sh`) blocks merge if any module misses the source.
26. **5 new schema renderers** (closes R5 O-R5-3) — `render-db-mongoose.sh`, `render-db-drizzle.sh`, `render-api-trpc.sh`, `render-api-hasura.sh`, `render-event-avro.sh`. Each sources `render-common.sh`. Triggered when `schemaDraftReview.language` matches the new language.

#### Migration runner + pickup gate hardening

27. **Generic migration runner** `greenfield/scripts/run-migrations.sh` — reads migration steps from `greenfield/skills/pickup/migrations/`, applies sequentially based on `state.meta.schemaVersion` → target. Supports `--dry-run` flag with JSON diff output.
28. **Migration step modules** under `greenfield/skills/pickup/migrations/`:
    - `alpha-3-to-4.sh` (extracted from inline R4 logic)
    - `alpha-4-to-5.sh` (extracted from inline R4 logic)
    - `alpha-5-to-6.sh` (extracted from inline R5 logic)
    - `alpha-6-to-7.sh` (NEW — R6 schema migration)
29. **Pickup `SKILL.md` refactor** — calls `run-migrations.sh` instead of inline cascade; gate logic updated to read `.meta.schemaVersion // .schemaVersion // "unknown"` for both legacy + canonical detection.

#### Onboard generation hooks

30. **9 deterministic generation modules** in `onboard/skills/generation/references/` — one per new R6 phase. Each reads its phase block, emits configured files in the scaffolded project. Backward-compat: `{skipped: true}` ⇒ no-op (mirrors R5 pattern).
31. **Schema updates** in `onboard/skills/generate/references/context-shape-v2.json` — 9 new phase blocks, 6 new `concerns.*` slots in their parent phases, split of `pluginDiscovery` into `pluginRecommendation` + `pluginInstall`, new `phases.cicdAndDelivery.lockedYaml` field.
32. **`dependencies-schema.json` updates** — extend phase enum to include the 9 new phases + 2 plugin sub-phases; extend path pattern.

#### Validation + cross-phase invariants

33. **CHECK-R6-1 through CHECK-R6-9** invariants in `greenfield/skills/grill-spec/references/check-r6-invariants.md` (see § Cross-phase invariants for full list)
34. **3 new health-check assertions** in `greenfield/skills/check/SKILL.md` — frontend trio completeness when not skipped, 6 concern-phase completeness when not skipped, pluginRecommendation/pluginInstall both populated when neither is skipped.

#### Tests

35. **Render-common test fixtures** in `tests/round-6/render-common/` — one test per helper (atomic_write, pii_encryption, etc.) plus an integration test that re-runs R5 smoke tests post-refactor
36. **Per-phase smoke tests** in `tests/round-6/` — fixture JSON + smoke script for each new phase + the CI Draft Review flow + the migration runner
37. **Migration runner test** — golden-output fixtures for each alpha-N-to-N+1 step

#### Documentation

38. **Companion docs directory** `docs/greenfield-3.0-round6/` containing `overview.md`, `migration-notes.md`, `coupling-matrix.md` (extends R5 matrix with R6 rows), `renderer-architecture.md` (the post-refactor library + module inventory)
39. **Updates** to `greenfield/CLAUDE.md` (30-step wizard, R6 phase additions block) and `onboard/CLAUDE.md` (mirrors greenfield)
40. **Discussion Log entry** in `docs/greenfield-overview.html` — ROUND 6 LOCKED (closes the 6-round plan)
41. **`greenfield-walkthrough.html` updates** — promotes all R6 phases from "Planned" status to "Shipped"
42. **CHANGELOG entries** in both plugins calling out the alpha.6 → alpha.7 schema bump (auto-migrating)
43. **Version bumps** — `greenfield@3.0.0-alpha.7`, `onboard@2.0.0-alpha.7`, mirrored in `marketplace.json`
44. **`onboard/skills/generation/SKILL.md` doc fix** — one-line update to § Extended Generation removing the stale "First sprint contract (negotiated or auto-generated)" wording (now superseded by R5's deterministic path); adds a pointer to `phases.featureRoadmap.sprint1`. (Closes R5 adjacent issue #2.)

### Out of scope (do NOT relitigate — locked elsewhere or deferred to Round 7+)

- Round 7+ is post-3.0 — no more locked rounds in the 6-round overhaul plan
- New CI provider templates beyond GHA + GitLab + CircleCI + LLM-fallback (Buildkite, Jenkins, AWS CodeBuild, Drone, etc.) — defer to v3.1
- Additional schema renderers beyond Mongoose/Drizzle/tRPC/Hasura/Avro (e.g., TypeORM, Sequelize, SQLAlchemy, gRPC, Buf protos) — defer to v3.1
- Mid-wizard "skip the rest of this phase" granularity finer than the existing `{skipped: true}` per-phase flag — defer
- New `mode.frontendDepth` toggle to scale the frontend trio Q-bank — explicitly rejected; existing `mode.depth` (Heavy/Light) applies uniformly
- Per-locale Q-bank loop in i18n phase — explicitly rejected; flat phase with locale array
- Stack-derived concern-area inference (e.g., "Next.js + Vercel ⇒ auto-enable file uploads gate") — defer; gates remain explicit per Item 8 locked decision
- New CI/CD synthesis review for non-YAML outputs (e.g., Dockerfile, terraform) — defer to v3.1
- Reverse migration (alpha.7 → alpha.6 downgrade) — `--dry-run` shows the diff diagnostically, but no auto-downgrade path. Recovery is via git revert.

## Locked design decisions

These came from the 2026-05-15 brainstorm and are not relitigated below.

| # | Decision | Source |
|---|---|---|
| 1 | Round 6 ships as a **big-bang single round** matching R3/R4/R5 pattern; R3-style subagent dispatch | Q1: scope shape |
| 2 | **Top 6 concern areas become full phases**; remaining 6 become inline gates | Q2: concern-area split |
| 3 | Frontend splits into **3 phases** (P5 Architecture, P5.3 Design System, P5.6 UX/A11y/Performance) — matches R3's auth-split rigor | Q3: P5 structure |
| 4 | **Dependency-driven inline placement** for all 9 new phases — each inserts where its inputs become available; gates distribute into nearest dependency phase | Q4: phase placement |
| 5 | CI takes **hybrid approach**: 3 vetted renderer modules (GHA + GitLab + CircleCI) + LLM fallback for any other provider; new CI Draft Review step mirrors R5 P10.5 | Q5: CI providers |
| 6 | `render-common.sh` extraction is **bundled into R6** (not deferred) so the 9 new renderers and the R5 6 existing renderers all share helpers from day one | Q5 follow-on |

## Wizard step ordering (post-R6, 30 named steps)

```
 1   Project Vision                                     (existing — R1)
 2   Tech Stack                                         (existing — R1)
 3   Personas                                           (existing — R4)
 4   Architectural Framing                              (existing — R2.5)
 5   Domain Modeling                                    (existing — R4)
 6   Data Architecture                                  (existing — R2)
 7   Search                                             (NEW R6 — concern phase)
 8   API & Integration                                  (existing — R2)
 9   Caching                                            (NEW R6 — concern phase)
10   Real-time                                          (NEW R6 — concern phase)
11   Auth                                               (existing — R3)         [+ inline gates: transactional email, SMS]
12   Privacy                                            (existing — R3)
13   File Uploads & CDN                                 (NEW R6 — concern phase)
14   Security                                           (existing — R3)
15   Payments                                           (NEW R6 — concern phase)
16   Runtime Operations                                 (existing — R3)
17   Residual Project Details                           (existing — R1)
18   Workflow Preferences                               (existing — R1)
19   CI/CD & Auto-Evolution                             (existing — R1)         [+ inline gate: feature gating]
20   CI Draft Review                                    (NEW R6 — auto-render + review)
21   P7.5 Plugin Recommendation                         (NEW R6 — split from old P10)
22   P5 Frontend Architecture                           (NEW R6 — frontend phase)
23   P5.3 Design System                                 (NEW R6 — frontend phase)
24   P5.6 UX / Accessibility / Performance              (NEW R6 — frontend phase) [+ inline gates: marketing email, push, analytics]
25   i18n / l10n                                        (NEW R6 — concern phase)
26   Feature Decomposition (Harness Prep)               (existing — R1)
27   Architectural Validation                           (existing — R2.5)
28   Feature Roadmap                                    (existing — R5)
29   Schema & API Draft Review                          (existing — R5)
30   P10 Plugin Install                                 (NEW R6 — split half of old P10)
```

**Existing sub-step interludes retained but not top-level numbered:**

- **Pain Points** (current Step 9.5) — fires as the closing Q-trio inside the parent phase whose Q-bank ends adjacent to it; remains a self-contained ask, just not bumped to a top-level step number
- **Confirmation** (current Step 13) — absorbed into the per-phase synthesis-review (added by R3+). Each phase's synthesis review Approve gate replaces the old monolithic confirmation
- **Phase 1.5 Architectural Research** (current Step 14) — retained as a conditional sub-phase that fires only if parked questions accumulated; runs between Step 25 i18n and Step 26 Feature Decomposition in the new ordering

These three are explicitly preserved (no behavior dropped); they simply don't show up in the 30-step top-level count because they're conditional or absorbed.

**Inline gate placement rationale:**

| Gate | Step | Why |
|---|---|---|
| Transactional email | 11 Auth | Password reset, magic links, verification emails are auth-flow concerns |
| SMS | 11 Auth | 2FA / OTP is an auth concern |
| Feature gating | 19 CI/CD | Release pipeline gating; ties into deploy strategy |
| Marketing email | 24 P5.6 UX | Consent UX + unsubscribe flow is a frontend surface concern |
| Push notifications | 24 P5.6 UX | Permission UX + opt-in surface is a frontend concern |
| Product analytics | 24 P5.6 UX | Event instrumentation is a per-surface frontend concern |

## Phase content / Q-bank shape

Q counts and auto-loop decisions per new phase:

| Step | Phase | Heavy Qs | Light Qs | Auto-loop | Onboard output |
|------|-------|----------|----------|-----------|----------------|
| 7 | Search | 11 | 6 | flat | `lib/search.ts` config + (if Postgres FTS) `prisma/migrations/0002_search_indexes.sql` |
| 9 | Caching | 12 | 7 | flat | `lib/cache.ts` skeleton + framework-conditional CDN headers (e.g., `next.config.ts` Cache-Control rules) |
| 10 | Real-time | 12 | 6 | per-persona | `lib/realtime.ts` (channels schema) + `app/api/realtime/route.ts` skeleton + reconnect helper |
| 13 | File Uploads & CDN | 13 | 7 | per-persona | `lib/uploads.ts` (signed URL flow) + S3/R2 IAM policy snippet + MIME allowlist constant |
| 15 | Payments | 14 | 7 | per-persona | `lib/payments/<provider>.ts` (Stripe/Lemon/Paddle) + webhook handler + customer portal route + ENV samples |
| 22 | P5 Frontend Arch | 13 | 7 | per-persona | `package.json` deps + `lib/store.ts` / `lib/queries.ts` skeletons |
| 23 | P5.3 Design System | 12 | 6 | flat | shadcn init (or MUI theme / Mantine provider) + `tailwind.config.ts` theme tokens + `.storybook/` if chosen |
| 24 | P5.6 UX/A11y/Perf | 15 | 8 | per-persona | Lighthouse CI workflow + `next.config.ts` image optimizer + fonts setup + Core Web Vitals budget JSON |
| 25 | i18n/l10n | 11 | 6 | flat | `lib/i18n.ts` + `messages/en.json` skeleton + `next.config.ts` i18n routing config |
| **Totals** | | **113** | **60** | | |

Plus ~9 gate Qs (6 yes/no + vendor follow-up averaging 1.5 Qs).

Auto-loop iteration cap (R-R6-9 mitigation): concern phases that auto-loop per persona cap at `min(personas.length, 4)` iterations. User can override via mode flag at wizard entry.

## CI Draft Review architecture

Architecture parallel to R5's P10.5 Schema Draft Review:

```
greenfield/scripts/
├── render-ci-drafts.sh           ENTRYPOINT — dispatches by provider
├── render-ci-gha.sh              GHA renderer (existing template ported to module)
├── render-ci-gitlab.sh           GitLab CI renderer (NEW)
├── render-ci-circleci.sh         CircleCI renderer (NEW)
└── render-ci-llm-fallback.sh     LLM fallback (NEW)
```

**Flow:**

1. After Step 19 CI/CD captures answers, wizard fires `render-ci-drafts.sh` mid-flow.
2. Entrypoint reads `phases.cicdAndDelivery.provider` and dispatches to per-provider module.
3. Module reads cross-phase signal (framework from stack, deploy target from runtime ops, secrets from auth/payments, test/lint/typecheck flags from `cicdAndDelivery`) and emits canonical YAML to a temp path.
4. Step 20 synthesis review HTML shows 3-panel layout (Inputs / Decisions log / Rendered YAML).
5. User picks Approve / Adjust / Reject.
   - **Approve:** locked YAML stored at `phases.cicdAndDelivery.lockedYaml`; onboard writes verbatim at scaffold time.
   - **Adjust:** LLM edits rendered YAML inline per user's natural-language correction; re-renders Panel 3 with the edit; loops until user Approves or Rejects.
   - **Reject:** wizard returns to Step 19 to re-answer.

**LLM-fallback banner:** when provider is outside `{gha, gitlab, circleci}`, Panel 3 displays a `"⚠ LLM draft — review carefully"` banner and CHECK-R6-8 hard-requires `addressed=true` before Approve unlocks.

**Cross-check warnings emitted during render:**

| Level | Condition |
|---|---|
| `warn` | Stage enabled but no matching tool in stack (e.g., type-check stage with no TypeScript) |
| `info` | Secret declared but no consumer found in any phase |
| `error` | Deploy target requires secret not declared in auth/runtime-ops |
| `warn` | Matrix size exceeds typical CI free-tier limits |
| `error` (LLM-fallback only) | YAML lint failure pre-write |

## `render-common.sh` shared library

Extracts helpers shared across all 15 post-R6 renderer modules (6 R5 schema renderers + 4 CI renderers + 5 new schema renderers).

| Helper | Purpose | Replaces |
|---|---|---|
| `_emit_warning <level> <code> <message>` | Append cross-check warning to state | Inline `jq` updates in each renderer |
| `_check_pii_encryption <entity>` | PII-encryption-required warning | Duplicated jq logic in render-db-prisma + render-api-openapi (R5 bug 9096549) |
| `_atomic_write <target> <content>` | temp + rename atomic write | Inline temp file logic in each renderer (R5 risk R-R5-5) |
| `_render_handlebars <template> <data>` | Phase-rooted Handlebars rendering | Each renderer re-implementing template substitution |
| `_emit_dependency <phase> <path> <value> <rationale>` | Append to `dependencies.json` | Manual `jq +=` in each renderer |
| `_validate_jq_path <path> <required>` | Safe `jq -r` with required-path failure | Ad-hoc `jq` calls (R5 fix 9096549) |

All 15 modules required to `source` the library; CI lint check enforces:

```bash
grep -L 'source.*render-common' greenfield/scripts/render-*.sh
```

If any file is listed (missing source), the lint fails.

**Refactor commit boundary:** the R5 renderer refactor lands as a single commit (`refactor(greenfield): R6 — extract render-common.sh + refactor R5 renderers`) so it can be reverted independently if a regression surfaces. Integration test (re-run R5 smoke tests) gates this commit.

## Extra schema renderers (R5 O-R5-3 closure)

R5 deferred these per O-R5-3; R6 ships them so `schemaDraftReview.language` covers a complete set:

| Module | Trigger | Output |
|---|---|---|
| `render-db-mongoose.sh` | `dataArchitecture.engine = mongodb` | Mongoose schema models (TS) |
| `render-db-drizzle.sh` | `dataArchitecture.engine in {postgres,mysql,sqlite}` AND `language=drizzle` | Drizzle ORM TS schemas |
| `render-api-trpc.sh` | `apiIntegration.style = trpc` | tRPC router type definitions |
| `render-api-hasura.sh` | `apiIntegration.style = hasura` | Hasura metadata + permissions YAML |
| `render-event-avro.sh` | `apiIntegration.asyncPattern in {kafka,kinesis}` AND `language=avro` | Apache Avro schemas |

Each sources `render-common.sh` and follows the same shape as the R5 modules.

## Plugin reshuffle mechanics

### P7.5 Plugin Recommendation (Step 21)

- **Reads:** `phases.{auth, privacy, security, runtimeOperations, cicdAndDelivery, concerns.featureGating}`
- **Action:** `plugin-discovery` skill in "recommendation mode" — outputs `{suggested: [...], rationale: "..."}`. User selects via `AskUserQuestion` (multi-select) which to keep.
- **Writes:** `phases.pluginRecommendation = {suggested, selected, rationale}`
- **Does NOT install** — only records intent.

### P10 Plugin Install (Step 30)

- **Reads:** `phases.pluginRecommendation.selected` ∪ `phases.pluginRecommendation.frontendAddenda`
- **Action:** `plugin-discovery` skill in "install mode" — actually runs `/plugin marketplace install` for each
- **Writes:** `phases.pluginInstall = {installed: [...], failed: [...], skipped: [...]}`
- **Surfaces install results** before scaffold handoff.

### Re-recommendation pass (R-R6-6 mitigation)

After Step 24 P5.6 UX completes, wizard re-invokes `plugin-discovery` with frontend context. If new suggestions surface (e.g., Storybook now in scope ⇒ recommend Storybook integration plugin), prompts user via single `AskUserQuestion`: "Add these to your install set?". Records to `phases.pluginRecommendation.frontendAddenda`.

### Schema migration: plugin split

| alpha.6 state | alpha.7 state |
|---|---|
| `phases.pluginDiscovery = { suggested, selected, installed }` | `phases.pluginRecommendation = { suggested, selected, frontendAddenda: [], rationale: "" }` + `phases.pluginInstall = { installed: [], failed: [], skipped: [] }` |

For new sessions (no pre-existing `phases.pluginDiscovery`), `phases.pluginInstall.installed` initializes to `[]`. For migrating alpha.6 sessions, the shim copies the existing `phases.pluginDiscovery.installed` array verbatim — preserving the install record for resumed sessions instead of resetting it.

## Generic migration runner

Architecture:

```
greenfield/scripts/
└── run-migrations.sh                Generic runner

greenfield/skills/pickup/migrations/
├── alpha-3-to-4.sh                  Self-contained: stdin JSON → stdout JSON
├── alpha-4-to-5.sh
├── alpha-5-to-6.sh                  (extracted from R5 inline logic)
└── alpha-6-to-7.sh                  NEW R6
```

**Runner protocol:**

```bash
# Apply migrations from current to target
run-migrations.sh --from alpha.6 --to alpha.7 --state-file .claude/greenfield-state.json

# Dry-run: emit JSON diff without applying
run-migrations.sh --from alpha.6 --to alpha.7 --state-file .claude/greenfield-state.json --dry-run
```

Each migration step:

- Reads JSON from stdin
- Writes migrated JSON to stdout
- Exits non-zero on failure (preserves original state)
- Is idempotent (running twice produces same output)

**Pickup integration:** `pickup/SKILL.md` Step 1 reads state, detects schemaVersion (`.meta.schemaVersion // .schemaVersion // "unknown"`), if non-target invokes runner with `--dry-run` first, shows diff to user, requires explicit approval, then runs without `--dry-run` and writes via atomic rename.

**Test fixtures:** each migration step has a golden-output fixture in `tests/round-6/migrations/`. CI lint runs all 4 migrations forward sequentially against a synthesized alpha.3 fixture and verifies final output matches expected alpha.7 state.

## Pickup `schemaVersion` gate hardening

R5 follow-up #1: current pickup hard-gates on top-level `schemaVersion === "alpha.5"` (R4-era format). R5's alpha.6 shim uses nested `state.meta.schemaVersion`. R6 rewrites all gates to:

```bash
SCHEMA_VERSION=$(jq -r '.meta.schemaVersion // .schemaVersion // "unknown"' "$STATE_FILE")
```

Canonical location: `state.meta.schemaVersion` (since alpha.6). Legacy top-level field tolerated for migration. Documented in pickup `SKILL.md § Schema Version Detection`.

The two affected hard-gates in pickup `SKILL.md` (Step 1.5 + Step 2) and Key Rules § Schema Version both update to this pattern.

## Cross-phase invariants

| ID | Invariant | Failure mode |
|---|---|---|
| CHECK-R6-1 | Each `concerns.<gate>` recorded as either `needed: false` or `{needed: true, vendor: <string>}` — vendor required when needed | `error` — blocks lock |
| CHECK-R6-2 | Caching + Real-time + Search each reference at least one entity from `phases.dataArchitecture.entities[]` when not skipped | `warn` — "why does this phase exist if it doesn't touch your data?" |
| CHECK-R6-3 | Payments phase populated ⟹ Privacy phase declares `pii.financial = true` | `error` — consistency violation |
| CHECK-R6-4 | P5 Frontend's `frameworkConfirmed` matches `phases.architecturalFraming.frontendFramework` | `error` — stack divergence |
| CHECK-R6-5 | P5.6 UX `surfacesByPersona` maps every persona ID to ≥1 surface | `error` — incomplete coverage |
| CHECK-R6-6 | i18n locales array non-empty ⟹ all synthesis docs commit to translated copy strategy | `warn` — flag for follow-up |
| CHECK-R6-7 | P7.5 Plugin Recommendation includes at least one suggestion from every "needed" gate's vendor list when an integration plugin exists in the marketplace | `info` — non-blocking suggestion |
| CHECK-R6-8 | CI Draft Review with `provider in {azure, bitbucket, buildkite, jenkins, ...}` (i.e., LLM-fallback) requires `addressed=true` | `error` — blocks Approve |
| CHECK-R6-9 | Concern phases that auto-loop per persona cap iterations at `min(personas.length, 4)`; iteration count records to `phases.<phase>.loopIterations` | `error` — blocks if exceeded |

## Risk register

| ID | Risk | Mitigation |
|---|---|---|
| R-R6-1 | 30-step wizard length → mid-wizard abandonment | Per-step "skip phase" option recorded as `{skipped: true}`; Heavy/Light mode toggles already in place |
| R-R6-2 | 113 new Heavy Qs bloat the bank; hurt consistency | CHECK-R6-1..9 cross-phase invariants run at every synthesis review boundary |
| R-R6-3 | LLM-fallback CI YAML may fail to parse or run | YAML-lint pre-write; CHECK-R6-8 requires `addressed=true` for LLM-fallback drafts; explicit banner |
| R-R6-4 | `render-common.sh` refactor breaks R5 renderers | Test fixtures per helper + integration test re-runs R5 smoke tests post-refactor; refactor lands as a separate revertable commit |
| R-R6-5 | Generic migration runner introduces a bug not caught by previous linear pattern | `--dry-run` mode + JSON diff shown to user; explicit approval before atomic write; golden-output test fixtures for all 4 migration steps |
| R-R6-6 | P7.5 recommendation at Step 21 misses context from later P5 phases (Storybook, i18n libs) | Re-recommendation pass after P5.6 UX (see § Plugin reshuffle) |
| R-R6-7 | 9 new phases × persona/entity ID validation = many broken-ref opportunities | Single validation report at generation boundary listing all unresolved IDs; fails generation if any |
| R-R6-8 | Renderer proliferation tech debt resurfaces: 15 modules post-R6 may diverge again | All modules required to source `render-common.sh`; CI lint check `grep -L 'source.*render-common' scripts/render-*.sh` blocks merge |
| R-R6-9 | Concern-phase auto-loop per persona creates feature-explosion in P9 Feature Roadmap (many small features per persona × per concern) | Cap per-persona auto-loop iterations at `min(personas.length, 4)` for concern phases; raise via mode override |
| R-R6-10 | Adjust path LLM edits to CI YAML produce silent regressions across iterations | Diff display in Panel 3 between iterations; `phases.cicdAndDelivery.adjustHistory[]` records each Adjust call for audit |
| R-R6-11 | Plugin install at Step 30 fails for some plugins; user already past commitment | `pluginInstall.failed[]` surfaced before scaffold; user can choose to scaffold anyway with manual-install instructions or abort |

## Migration shim (alpha.6 → alpha.7)

Generic migration runner orchestrates; the step module handles the data:

`greenfield/skills/pickup/migrations/alpha-6-to-7.sh`:

1. For each of the 9 new phases (`search`, `caching`, `realtime`, `fileUploads`, `payments`, `frontendArchitecture`, `designSystem`, `uxAccessibilityPerf`, `i18nL10n`):
   - If absent from `phases.*`, insert with `{skipped: true, deferredReason: "Round 6 phase added 2026-05-15; pre-R6 sessions skip"}`
2. For each of the 6 inline gates, write `{needed: null, vendor: null}` to the nested path inside its parent phase (null distinguishes "unanswered" from "no"):
   - `phases.auth.concerns.transactionalEmail`
   - `phases.auth.concerns.sms`
   - `phases.uxAccessibilityPerf.concerns.marketingEmail`
   - `phases.uxAccessibilityPerf.concerns.pushNotifications`
   - `phases.uxAccessibilityPerf.concerns.productAnalytics`
   - `phases.cicdAndDelivery.concerns.featureGating`
3. Split `phases.pluginDiscovery`:
   - Copy `suggested`/`selected`/`rationale` → `phases.pluginRecommendation`
   - Copy `installed`/`failed`/`skipped` → `phases.pluginInstall` (preserves resume state)
   - Add `phases.pluginRecommendation.frontendAddenda = []`
   - Delete `phases.pluginDiscovery`
4. Add `phases.cicdAndDelivery.lockedYaml = null`
5. Update `state.meta.schemaVersion = "alpha.7"`
6. Append migration entry to `state.meta.migrations[]`

User sees the diff via `--dry-run` and must explicitly approve before atomic write.

## Validation strategy

- **R3-style subagent dispatch:** ~50–70 implementer tasks across the 9 phases + tech debt items + tests + docs. Each implementer task owns a discrete deliverable (e.g., "implement Search Q-bank", "implement render-ci-gha.sh module").
- **Per-task spec quality + quality-review subagent sweep:** as in R3+R5. Quality reviewer verifies the implementer matches spec, no invented field names, no aspirational sections.
- **Cross-cutting reconciliation commits:** mid-execution checkpoint commits when invented field names / wrong field paths surface (lesson from R3 commit `dea9d2c` and R5 commit `7a31642`).
- **Final smoke pass:**
  - All 9 new phase smoke tests pass
  - Render-common test fixtures pass
  - All 4 migration steps pass golden-output test
  - CI Draft Review smoke for each renderer (GHA, GitLab, CircleCI, LLM-fallback stub)
  - R5 smoke tests (feature-roadmap, schema-draft, alpha-5-to-6 migration) still pass post-refactor
  - All CHECK-R6-1..9 invariants verified against synthesized fixtures
  - `shellcheck` clean on all new scripts
  - `jq empty` passes on all new JSON files

## Rollback path

If alpha.7 needs reverting:

1. `git revert <merge-commit>` on `develop` reverts code
2. Released alpha.7 plugin versions on the marketplace stay published (alpha policy) — no recall
3. In-flight alpha.7 sessions can't auto-downgrade; user can manually edit `state.meta.schemaVersion = "alpha.6"` and re-walk affected phases, or accept the partial state
4. The 9 new phases are isolated — removing them doesn't affect R1-R5 phases
5. `render-common.sh` refactor lands as a separate revertable commit; reverting it leaves the R5 + R6 renderers using the previous inline logic (each renderer's helper functions inlined back via the revert)

## Adjacent issues flagged (not fix in R6)

| Where | Issue | Suggested action |
|---|---|---|
| Per-locale loop in i18n phase | Currently flat; could be useful for projects with locale-specific UX guidance | v3.1 candidate; revisit if i18n synthesis review consistently shows users wanting per-locale rules |
| CI provider templates beyond top 3 + LLM | Long tail (Buildkite, Jenkins, AWS CodeBuild, Drone) handled via LLM-fallback in R6; could promote popular ones to vetted modules over time | v3.1 candidate; gated by user demand telemetry |
| Schema renderer expansion (TypeORM, Sequelize, SQLAlchemy, gRPC, Buf protos) | R5 + R6 cover the major lanes; long tail is open | v3.1 candidate |
| Reverse migration support | `--dry-run` shows diff diagnostically but no auto-downgrade | v3.1 candidate; requires significant per-step inverse logic |
| `mode.frontendDepth` toggle | Frontend trio respects `mode.depth` (Heavy/Light) uniformly; some users may want differential depth | Defer indefinitely; would proliferate mode flags |

## Companion docs (to be written during execution)

- `docs/greenfield-3.0-round6/overview.md` — narrative companion (this spec is the formal record)
- `docs/greenfield-3.0-round6/migration-notes.md` — alpha.6 → alpha.7 migration details + generic runner usage
- `docs/greenfield-3.0-round6/coupling-matrix.md` — extends R5 coupling matrix with R6 rows
- `docs/greenfield-3.0-round6/renderer-architecture.md` — post-refactor library + module inventory + helper API contracts

## Next step

Invoke `superpowers:writing-plans` to produce the per-task implementation plan (target: ~50–70 tasks for R3-style subagent dispatch).
