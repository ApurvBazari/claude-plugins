# Changelog

## 3.1.0 — 2026-05-16

### Added

- Visual companion for Phase 1 — clickable browser-based architecture map drives phase ordering as a dependency-aware tech tree instead of a linear 30-step wizard. New `visual-companion` skill, tiny Python stdlib HTTP server (`serve-companion.py`), and 18-phase dependency graph (`phase-graph.json`).
- Step 0 mini-wizard (6 Qs: app type, scale, personas, deploy, team size, stack hint) in `start/SKILL.md` — seeds the map's hideIf pruning and dependency activation.
- Single-phase entry mode for `context-gathering/SKILL.md` — runs one phase's Q-bank + synthesis-review, then returns control to the visual companion's wait-for-intent loop.
- Resume support in `pickup/SKILL.md` — respawns the companion's HTTP server (new port if needed), re-resolves the status map, re-enters the loop.
- `check/SKILL.md` reports visual-companion state — server pid/port liveness, approved/required count, current AVAILABLE phases, in-progress phase.
- Manual end-to-end smoke checklist (`tests/visual-companion/e2e-manual.md`) — 16-step sign-off script for the 3.1.0 gate.

### Changed

- Phase 1's primary entry point is now `visual-companion`. Legacy linear 30-step wizard remains as the fallback path (triggers automatically when Python 3 is missing or a local port can't be bound).
- New state files in `.claude/`: `greenfield-ui-state.json` (derived from greenfield-state.json + phase-graph.json), `greenfield-ui-intent.json` (transient click), `greenfield-ui-port.txt`, `greenfield-ui-server.pid`.

### Compatibility

- Backward-compatible: projects scaffolded with 3.0.x are not affected — the new state files are Phase-1-only and don't exist in completed projects.
- Env var rollback: set `GREENFIELD_VISUAL_COMPANION=0` to force the linear wizard regardless of Python availability.
- New prerequisite: Python 3 stdlib (no pip install required). Greenfield falls through to the linear wizard if missing — no breakage, just a notice.

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

## 3.0.0-alpha.6 (2026-05-15) — Round 5

### Added
- Step 16 — Feature Roadmap phase (`featureRoadmap`): 14 Qs heavy / 7 light, per-persona auto-loop (FR.Q4-Q9), deterministic `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` generation via onboard.
- Step 19 — Schema & API Draft Review phase (`schemaDraftReview`): 12 Qs, auto-renders DB/API/Event drafts from R3+R4 discovery via `scripts/render-schema-drafts.sh` mid-flow, then user reviews/locks. Onboard writes locked drafts verbatim to canonical paths per `outputStrategy`.
- 7 renderer scripts: `render-schema-drafts.sh` (entrypoint) + 6 per-language modules (Prisma, SQL DDL, OpenAPI 3.0, GraphQL SDL, AsyncAPI, JSON Schema).
- 6 cross-phase invariants: CHECK-R5-1 through CHECK-R5-6 (`grill-spec/references/check-r5-invariants.md`).
- Synthesis templates: `feature-roadmap.html`/`md`, `schema-draft-review.html`/`md` + dependencies examples.
- Smoke tests: `tests/round-5/feature-roadmap-smoke.sh` (10 checks) + `tests/round-5/migration-test.sh` (8 checks).
- Pickup migration shim: alpha.5 → alpha.6 (auto-migrating, additive).
- 3 health checks in `check/SKILL.md` (featureRoadmap completeness, schemaDraftReview lockedAt presence, sprint-1 contract presence).

### Changed
- Wizard step count 17 → 20.
- `tooling-generation/SKILL.md` passes `phases.featureRoadmap` + `phases.schemaDraftReview` to onboard.
- `start/SKILL.md`, `context-gathering/SKILL.md`, `synthesis-review/SKILL.md`, `pickup/SKILL.md`, `check/SKILL.md`, `grill-spec/SKILL.md`, `CLAUDE.md` updated for R5.

### Migration
- Auto-migrating via `/greenfield:pickup`. No manual action required.
- Sessions predating alpha.6 get `{skipped: true, deferredReason}` defaults on featureRoadmap + schemaDraftReview. Re-enter Steps 16/19 via Adjust mode to populate.

### Rollback
- Single revert commit on `develop` reverts the R5 PR. alpha.6 sessions calling alpha.5 pickup gracefully drop unknown R5 fields.

## 3.0.0-alpha.5 — Round 4 (Personas + Domain + Distributed Risk)

**New phases:**
- Step 2.2 — Personas (16 Qs heavy / 4 light)
- Step 2.7 — Domain Modeling (11 Qs Full DDD / ~8 DDD-lite / ~6 Light)

**New mechanics:**
- Wizard mode toggles at Step 1.1: `mode.depth` (heavy/light), `mode.coupling` (auto-loop/hybrid), `mode.domainFormat` (full-ddd/ddd-lite). Comprehensive-by-default Recommended posture.
- Auto-loop: every downstream architectural phase iterates per persona AND per entity in auto-loop mode; critical-only loops (`loopMode: always`) fire in both auto-loop and hybrid; `loopMode: hybrid-only` Qs collapse to single static prompts under hybrid coupling.
- Inline risk capture: every architectural phase + personas + domain grows one final `Q_RISK`; risks collect to shared top-level `risks[]` array (10 risk-capture Qs total).
- Risk Reconciliation: new front section in `architectural-validation.html` (Step 15). Buckets risks by reconciliation status (mitigated / partial / accepted-explicit / open-followup / out-of-scope / user-declared-none). Top follow-ups emit `feature-list.json` risk-followup cards.
- Adjust mode in `/greenfield:pickup` — mid-wizard mode switch with per-field side-effects (queue showInLight=false Qs on Light→Heavy upgrade; preserve+hide on Heavy→Light downgrade; re-ask `hybrid-only` Qs on Hybrid→Auto-loop upgrade; etc.).
- Persona/entity post-hoc add detection — `/greenfield:pickup` compares current persona/entity counts against per-phase `loopedOver` metadata and surfaces drift.

**Schema:**
- alpha.4 → alpha.5 is the first **non-hard-cutover** schema bump (additive + auto-migrating).
- `/greenfield:pickup` auto-migrates alpha.4 state on first run: sets safe defaults (`heavy + hybrid + ddd-lite`), initializes new collections (`personas`, `domainModel`, `risks[]`, `architecturalValidation.riskReconciliation`), bumps version.
- All R4 fields are optional in onboard 2.0 alpha.5+ — absent blocks mean alpha.4 behavior.

**Cross-phase invariants:**
- CHECK-R4-1 through CHECK-R4-8 added to grill-spec (4 hard-fail, 3 warn, 1 suggestion).

**Migrations:**
- Q1.2 ("Who is this for?") demoted to pointer; `vision.users[]` preserved as legacy field with conversion prompt at Step 2.2 entry for alpha.4 sessions.

**Wizard step count:** 15 → 17 (Steps 2.2 + 2.7 added; renumbering uses `.X` notation, no global renumber).

**New files:** see `docs/greenfield-3.0-round4/overview.md § Files added / modified`.

## [3.0.0-alpha.3] (2026-05-14)

### Schema breakage

- **phaseStatus map** (PRE-5): `currentPhase` tracking changes from string to phase-status object with `status: "in-progress" | "complete" | "skipped"` and optional metadata
- **architecturalFraming and architecturalValidation completedSteps** (PRE-2): two new step identifiers added; clients expecting a fixed set will fail
- **defaults-driven flow markers** (PRE-6): new context fields like `autoResume: boolean` drive conditional phase skips; old state JSONs lack these fields

**Impact**: Users with in-flight greenfield-state.json from alpha.2 will need to restart with `/greenfield:start`. No automatic migration during alpha.

See [state-schema-evolution.md](greenfield/skills/start/references/state-schema-evolution.md) for the policy: alpha hard-cutover, stable migrations, and version check on resume.

## [2.0.0] (2026-05-04)

### Breaking changes

* **rename:** plugin renamed from `forge` to `greenfield`. The `forge` name was already taken in `anthropics/claude-plugins-community` by an unrelated plugin, blocking publication. `greenfield` is the standard term for new-from-scratch projects and is unique in the community marketplace.
* **slash commands:** `/forge:init`, `/forge:resume`, `/forge:status` are now `/greenfield:init`, `/greenfield:resume`, `/greenfield:status`.
* **state files:** `.claude/forge-state.json` → `.claude/greenfield-state.json`, `.claude/forge-meta.json` → `.claude/greenfield-meta.json`. If you have an in-flight session, run `mv .claude/forge-state.json .claude/greenfield-state.json` (and likewise for forge-meta.json) before invoking `/greenfield:resume`.
* **schema:** `forge-meta.schema.json` → `greenfield-meta.schema.json`; the `$id` URL has changed.

### Features

* **grill-spec:** new Phase 1.7 pre-scaffold validation gate sits between context-gathering and scaffolding. Walks 5 spec categories (scope, stack alignment, feature conflicts, missing dependencies, security) to catch contradictions before any code is written. Uses `mattpocock-skills:grill-me` when installed; falls back to an inline minimal pattern otherwise — never crashes the run if the external skill is absent.
* **plugin-discovery catalog:** three new entries — `mattpocock-skills:grill-me` (Universal · plan-validation), `forrestchang:andrej-karpathy-skills` (Universal · coding-discipline), `mattpocock-skills:grill-with-docs` (workflow-conditional, gated on `hasDocsDiscipline`).
* **context flags:** two new context fields — `wantsValidationGate` (defaults `true` for `isProduction: true`, drives Phase 1.7 run/skip) and `hasDocsDiscipline` (routes to grill-with-docs).
* **capability mappings:** three new entries in the `coveredCapabilities` map so `onboard:generate` skips agent generation when grill-me, grill-with-docs, or andrej-karpathy-skills is installed. Includes a disambiguation note distinguishing `superpowers:planning` (generative) from `grill-me:plan-validation` (critical).

### Migration

Existing v1.x projects scaffolded by `forge` continue to work — the only file-name dependencies are the two state/meta artifacts above. Cross-plugin integration with `onboard` is unchanged: `greenfield` still calls `Skill(onboard:generate)` with the same `callerExtras` shape.

## [1.1.0](https://github.com/ApurvBazari/claude-plugins/compare/forge-v1.0.0...forge-v1.1.0) (2026-04-19)


### Features

* **onboard:** built-in Claude Code skill recommendations (1.9.0) ([#39](https://github.com/ApurvBazari/claude-plugins/issues/39)) ([770cdc7](https://github.com/ApurvBazari/claude-plugins/commit/770cdc7b70144a93f395edc293c06d88e5585a12))
* **onboard:** emit extended agent frontmatter (1.6.0) ([#36](https://github.com/ApurvBazari/claude-plugins/issues/36)) ([5dd316d](https://github.com/ApurvBazari/claude-plugins/commit/5dd316d0174cef9b967929deb7f30451772e4997))
* **onboard:** emit project-scoped custom output styles (1.7.0) ([#37](https://github.com/ApurvBazari/claude-plugins/issues/37)) ([a73bd8b](https://github.com/ApurvBazari/claude-plugins/commit/a73bd8bc775676d42f8e4b25c94db0fae7eece02))
* **onboard:** expand hook coverage to 14+ events and 4 execution types ([#34](https://github.com/ApurvBazari/claude-plugins/issues/34)) ([1cce41f](https://github.com/ApurvBazari/claude-plugins/commit/1cce41f3b13ac74701339ac586e3dba5a8fc14ae))
* **onboard:** generate .mcp.json from detected stack signals ([#35](https://github.com/ApurvBazari/claude-plugins/issues/35)) ([e1a269e](https://github.com/ApurvBazari/claude-plugins/commit/e1a269e856c1710b5d95a881f73f257f105766b4))
* **onboard:** LSP plugin recommendations (1.8.0) ([#38](https://github.com/ApurvBazari/claude-plugins/issues/38)) ([9a8d183](https://github.com/ApurvBazari/claude-plugins/commit/9a8d1830e2ad1cc054d528238148794438d5a357))


### Bug Fixes

* address security audit findings from PR [#30](https://github.com/ApurvBazari/claude-plugins/issues/30) ([#31](https://github.com/ApurvBazari/claude-plugins/issues/31)) ([d970691](https://github.com/ApurvBazari/claude-plugins/commit/d9706915f999f44f77a900bae8ba1f5c9714a392))
* **forge:** sanitise free-text wizard answers before onboard dispatch ([#45](https://github.com/ApurvBazari/claude-plugins/issues/45)) ([bf49466](https://github.com/ApurvBazari/claude-plugins/commit/bf4946601799c59f3b4fb311e8d792d3df7df965))
* release-43 security hardening + bot-scope expansion (9 findings, 13 commits) ([#44](https://github.com/ApurvBazari/claude-plugins/issues/44)) ([a048d39](https://github.com/ApurvBazari/claude-plugins/commit/a048d39242e7fa52c5fd64d65f1893cd6d7a351f))
* release-gate v2 sweep — close 17 findings across 1.9.1 + 1.10.0 bundles ([#41](https://github.com/ApurvBazari/claude-plugins/issues/41)) ([9b3c46f](https://github.com/ApurvBazari/claude-plugins/commit/9b3c46f0cdb3129071fcbd405afc78d24318d28c))

## 1.0.0

Initial release.

- 4-phase project scaffolder: Context Gathering, Scaffold, AI Tooling, Lifecycle Setup
- Interactive context-gathering wizard with 33 adaptive questions (developers answer 8-22 depending on stack and project type)
- Scaffolding with `full` mode (external CLI) and `walking-skeleton` mode for stacks without mature CLIs
- Delegates all tooling generation to onboard's headless mode (`/onboard:generate`)
- Generates `init.sh` environment bootstrap + `docs/feature-list.json` feature decomposition
- Phase 4 lifecycle setup via `engineering` plugin (ADRs, testing strategy, deploy checklists, system designs, runbooks) — graceful skip if absent
- Resume protocol: `.claude/forge-state.json` checkpoint at every step, cross-session resume via `/forge:resume`
- Stack research via `stack-researcher` agent with main-session fallback
- Sibling project detection for version consistency across related projects
- Plugin discovery: curated catalog + web search, capability mapping for plugin-aware generation
- Quality-gate hooks: SessionStart reminders, feature-start detection, pre-commit blocking, post-feature advisory
- Plugin Integration Coverage reporting in `/forge:status`
