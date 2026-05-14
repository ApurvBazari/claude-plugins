# Changelog

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
