# Onboard 2.0 — Migration & Breaking Changes

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

---

## 2.0.0-alpha.6 (2026-05-15) — Round 5 schema additions

### Added
- `context-shape-v2.json`: replaced `phases.featureRoadmap` + `phases.schemaDraftReview` deferred-stub placeholders with full schemas.
- `definitions.schemaDraft` for the `drafts.{db,api,event}` sub-shape.
- `generation/SKILL.md`: deterministic `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` generation when greenfield's `phases.featureRoadmap` is populated; verbatim schema/contract file writes from `phases.schemaDraftReview.drafts.{db,api,event}.content`.
- `generation/references/sprint-contracts.md`: clarification that from R5 onward sprint-1 is deterministic; the interactive flow described applies to sprint-2..N.

### Backward compatibility
- If `featureRoadmap.skipped = true` OR `features[]` empty → onboard falls back to interactive handoff (preserves alpha.5 behavior).
- If `schemaDraftReview.skipped = true` OR `lockedAt` absent → onboard writes no schema/contract files (preserves alpha.5 behavior).

---

## 2.0.0-alpha.5 — Round 4 schema extensions

**context-shape-v2.json additions (additive — alpha.4 sessions auto-migrate via greenfield/skills/pickup/SKILL.md § State migration):**
- New top-level `mode` block: `{ depth: "heavy"|"light", coupling: "auto-loop"|"hybrid", domainFormat: "full-ddd"|"ddd-lite" }`.
- New `phases.personas` block: `{ primary: [...], secondary: [...], antiPersonas: [...] }`.
- New `phases.domainModel` block: `{ contexts, entities, valueObjects, domainEvents, crossContextRelationships, ubiquitousLanguage, antiCorruption }`.
- Extended `phases.architecturalValidation.riskReconciliation`: `{ summary, topFollowups }`.
- New top-level `risks[]` array: `[{ id, originatingPhase, text, tags[], reconciliation: { status, rationale } }, ...]`.

**dependencies-schema.json additions:**
- Phase enum extends: `personas`, `domainModel`, `risks`.
- Path pattern extends to allow `personas.*`, `domainModel.*`, `risks[]` paths.
- New optional `sourceRef: { phase, id }` field on dependency entries. Required when produced by auto-loop coupling; absent when produced by static/hybrid-collapsed Qs.

**generation/SKILL.md updates:**
- `## Round 4 — new phase blocks` section documents how generation layers R4-aware behaviors on top of alpha.4 baseline:
  - `phases.personas` → role-specific agent generation, persona-aware UI scaffolding (R6 consumer).
  - `phases.domainModel` → per-entity migration scaffolds, per-aggregate route maps, entity-ID-aware drift detection.
  - `risks[]` with open-followups → prepends `docs/risks.md` listing open follow-ups grouped by originating phase.
  - `mode.coupling == "auto-loop"` → metadata note in generated CLAUDE.md pointing at `docs/adr/*.dependencies.json` sourceRef traces.
  - `mode.depth == "light"` → gates aspirational sections (skip "Detailed architecture diagrams", "Production readiness checklist"; replace with "Prototype mode" header).
- All R4 fields optional; absence behaves as alpha.4. Generation is **layered, not gated**.

**Backwards compatibility:** alpha.4 and alpha.5 wizards/generators can read each other's state files non-destructively. alpha.4 ignores unknown keys (mode, risks, personas, domainModel). alpha.5 runs the migration shim on alpha.4 input.

---

## 2.0.0-alpha.4 — 2026-05-14 (Round 3)

**Schema additions (Round 3 of the greenfield 3.0 wizard overhaul):**

- `auth` (Step 5): new live phase block in `context.phases` with 4 required enum-locked fields (`strategy`, `sessionModel`, `authzModel`, `enforcementPoint`) and 9 loose fields (provider, idps, mfa, tenantResolution, serviceAuth, lifecycle, recovery, passwordPolicy, auditLog).
- `privacy` (Step 6): new live phase block with 1 required field (`synthesisStatus` enum: `complete | n/a`) supporting the skip-cascade n/a stub, plus 11 loose fields (regulations, piiCategories, lawfulBasis, retention, deletionFlow, consentManager, dsar, processors, minimization, dataResidency, accessAudit).
- `security` (Step 7): new live phase block with 3 required fields (`sensitivityTier`, `threatModel`, `supplyChain`) and 10 loose fields covering secrets, scanning, encryption, headers, input validation, audit retention, IR pointer, pentest cadence, VDP.
- `runtimeOperations` (Step 8): new live phase block with 14 fields covering jobs, retry/idempotency, scheduling, observability (metrics/traces/logs), alerting, SLO, feature flags, maintenance mode, health checks, runbooks, incident process, on-call. No hard-required fields (all gated by upstream skip cascades).
- `dependencies` pattern: extended to include the 4 new Round 3 phase names (`auth`, `privacy`, `security`, `runtimeOperations`) plus the Round 2.5 phases (`architecturalFraming`, `architecturalValidation`) as valid alternatives in both the `phase` enum and the per-dependency `path` pattern.

**Schema break notice (hard cutover during alpha):**

- In-flight `2.0.0-alpha.3` greenfield sessions cannot be resumed under `2.0.0-alpha.4`.
- The `pickup` skill detects `schemaVersion` mismatch and presents two recovery options:
  1. Finish the session on `alpha.4` (re-checkout the older greenfield branch)
  2. Discard the session and restart on `alpha.4`
- No migration framework ships (per Round 2.5 Decision 8 — migrations only from stable).

**Removed:**

- Nothing removed; schema additions are additive.

---

## 2.0.0-alpha.3 — 2026-05-14

**Schema additions (Round 2.5 of the greenfield 3.0 wizard overhaul):**

- `architecturalFraming` (Step 2.5): new synthesis section added to context.syntheses capturing topology, deploymentShape, scaleTarget, boundaryNotes from Step 2.5 questions.
- `architecturalValidation` (Step 11): new synthesis section added to context.syntheses capturing final cross-phase sign-off from Step 11 questions.
- `dependencies` pattern (Round 2.5 solidified): cross-phase dependency assertions now include all topic names (P* phase, topic-name enum) and dependency edges; `dependencies.<phaseId>` is now fully structured and validated.

**Breaking for Round 1 alpha.1 callers:** greenfield 3.0.0-alpha.2 was the first released version using P3/P4 full shapes; 3.0.0-alpha.3 adds two new synthesis sections (`architecturalFraming`, `architecturalValidation`) and strict dependency structures. Callers on alpha.2 will need to emit these sections or accept validation warnings. See greenfield CHANGELOG for Full Foundation pass details.

**No artifact generation changes** — the 9 PRE-task deliverables (PRE-1 through PRE-9) landed on this branch as code/config updates only. `onboard:generate` accepts the new synthesis shapes and processes them cleanly. New templates are deferred to later rounds.

---

## 2.0.0-alpha.2 — 2026-05-13

**Schema additions (Round 2 of the greenfield 3.0 wizard overhaul):**

- `P3` flipped from `_status: "deferred-to-round-2"` to a live `p3Data` definition with 4 required enum-locked fields (`databaseHost`, `orm`, `migrationsTool`, `multiTenancy`) and 9 loose-string fields (`engine`, `migrationsMode`, `search`, `cache`, `cacheInvalidation`, `fileStorage`, `codegen[]`, `backup`, `compliance`).
- `P4` flipped from `_status: "deferred-to-round-2"` to a live `p4Api` definition with 3 required enum-locked fields (`style`, `versioningPolicy`, `asyncPattern`) and 6 loose-string fields (`documentation`, `rateLimit`, `pagination`, `realtime`, `webhooks`, `externalServices[]`).
- Top-level description updated to reflect that Rounds 1–2 fully specify P3, P4, P8.

**Breaking for incomplete Round 1 callers:** greenfield 3.0.0-alpha.1 emitted `{ "_status": "deferred-to-round-2" }` for P3 and P4. Under the new strict `p3Data` / `p4Api` definitions (with `additionalProperties: false`), this shape is REJECTED. Callers must construct the new P3/P4 shapes or stay on greenfield 3.0.0-alpha.1 + onboard 2.0.0-alpha.1 as a pinned pair.

**Hard cutover policy reminder:** v1 input is still rejected outright. There is no migration helper from v1 → v2.

**No new artifact generation** — Round 2 captures decisions but does not emit new template artifacts. `onboard:generate` accepts P3/P4 data and renders standard CLAUDE.md / rules / skills / agents / hooks. The 4 GHA workflow templates from Round 1 are unchanged.

---

Onboard 2.0 is the headless-generation contract upgrade for callers built against the greenfield 3.0 wizard. **Hard cutover: there is no migration helper, no auto-upgrade, no v1 fallback path.** v1 callers must stay on onboard 1.10.0 for the lifetime of their session; v2 callers run on onboard 2.x.

This document supplements the per-release notes in `CHANGELOG.md`. CHANGELOG entries describe what changed; this file explains the *why* of the cutover and the *what* of the new contract.

---

## Why a hard cutover

Two design decisions, locked during the greenfield 3.0 design phase (see `docs/greenfield-overview.html` Discussion Log, "ROUND 1 LOCKED" entry):

1. **Greenfield 3.0's 15-phase wizard produces fundamentally different output shape** — per-phase nested data (`phases.P0..P10.5`), per-phase synthesis records (`syntheses.P*`), cross-phase dependency assertions. Trying to map this into v1's flat `enriched.*` shape was leaky and inflexible (lost the synthesis records, couldn't represent deferred phases, blurred caller-extras vs wizard-data provenance).
2. **No active v1 callers exist** — the only consumer of `onboard:generate` v1 was greenfield 2.x, and the greenfield 3.0 cutover (which this onboard release ships alongside) breaks compat with greenfield 2.x in-flight sessions anyway. There is no in-flight call surface to preserve.

The combined effect: a v1→v2 migration helper would have ~0 users, would have to encode brittle field-by-field mappings, and would slow down the v2 contract iteration. Hard cutover ships cleaner, ships faster, and matches the broader greenfield 3.0 "break compat, no maintenance branch" stance (locked Items 9, 10, 12).

---

## Breaking-change matrix

| Change | v1 callers | Round 1 ships (2.0.0-alpha.1) | Round-N follow-up |
|---|---|---|---|
| Top-level `version: 2` required | **Must stay on onboard 1.10.0** | Yes — schema enforces | — |
| Flat `wizardAnswers.*`, `enriched.*` fields → `phases.P*.{...}` nesting | Stay on 1.10.0 | Yes (P2, P7.5, P8, P10 lifted into phases) | Other phases lifted as each round lands |
| `cicd.*` field set (16 fields) | N/A — new in v2 | Yes — full spec under `phases.P8.cicd` | — |
| Deferred phase stubs (`_status: deferred-to-round-N`) | N/A | Yes — accepted as inert pass-through | Stub bodies fill in per round |
| `callerExtras.installedPlugins` / `coveredCapabilities` | Same shape, top-level | Same shape, top-level (no change) | — |
| `syntheses.P*` synthesis approval records | N/A | Yes — generate consults; missing for spec'd phase = warning | Layout stays as more phases gain syntheses |
| `dependencies.P*` cross-phase deps | N/A | Yes — pass-through metadata | Used by visualize-graph.sh in user projects |
| Migration helper script (`onboard:migrate-context`) | N/A | **No — never ships in any release** | — |
| GitHub Actions CI/CD templates driven by P8 | N/A | Yes (4 GHA templates: app-ci, tooling-audit, pr-review, deploy) | Non-GHA providers in Round 6 |
| Sprint contracts consume `P8.envLadder` for `deploymentTargets` | N/A | Yes — generate renders v2-aware sprint contracts | — |
| Slack/Discord/email evolution hooks driven by `P8.notifications` | N/A | Yes — see `references/evolution-wiring.md` | — |

---

## Detection & rejection contract

Onboard 2.x checks the input's top-level `version` field as the first action of `onboard:generate`:

```
if input.version === 2:
  → v2 path (validates v2 schema, dispatches with new prompt shape)
else if input.version === 1 OR input.version is missing OR input.version is anything else:
  → REJECT with the following error:

  Headless generation aborted: this is onboard 2.x which requires v2 contexts
  (top-level `version: 2`). v1 callers must use onboard 1.10.0:

    claude plugin install onboard@1.10.0

  See CHANGELOG-2.0.md for the breaking-change matrix and the v2 schema at
  references/context-shape-v2.json. There is no migration helper — v2 callers
  must construct v2 contexts directly. Greenfield 3.0+ is the canonical caller.
```

No silent fallback. No partial v1 acceptance. Rejection is the only response to non-v2 input.

---

## What ships in Round 1 (onboard 2.0.0-alpha.1)

- ✅ Schema validation for v2 input (top-level `version: 2`, required `phases.P8`)
- ✅ Hard-rejection of v1 input
- ✅ Full P8 (CI/CD) consumption: 16 fields drive workflow generation, sprint contracts, evolution wiring
- ✅ GitHub Actions workflow templates (4 .yml.tmpl files in `references/cicd-templates/github-actions/`)
- ✅ Sprint-contracts template driven by `P8.envLadder` (`references/sprint-contracts-template.json`)
- ✅ Evolution-wiring guide for `P8.notifications` → hook mapping (`references/evolution-wiring.md`)
- ✅ Pass-through for `_status: deferred-to-round-N` phase stubs
- ⏳ Other CI providers (GitLab, CircleCI, BuildKite, Jenkins) — `provider` field accepted but generates a note + skips CI/CD generation. Templates land in Round 6.
- ⏳ Other phase consumption (P0, P0.5, P1, P3, P4, P5, P6, P7, P8.5, P9, P10.5) — accepted as deferred stubs; consumption arrives as each greenfield round lands.

---

## Caller checklist (for direct v2 callers)

If you're building a non-greenfield caller against onboard 2.x:

1. Construct a context object matching `references/context-shape-v2.json` (draft-07 JSON Schema).
2. Set `version: 2` at the root. Set `source`, `projectPath`, `callerExtras`, `phases.P8`.
3. For phases your caller doesn't yet collect data for, emit `{ "_status": "deferred-to-round-?" }`.
4. If your caller approves syntheses, emit them under `syntheses.<phaseId>`. Missing syntheses for fully-specified phases produce a warning, not an error.
5. Dispatch `onboard:generate` via the Skill tool. Parse the structured JSON response per `generate/SKILL.md § Step 5`.

If you're staying on the v1 contract, **do not upgrade to onboard 2.x**. Pin to onboard 1.10.0 and continue. No bridge will be built later.

---

## Future onboard 2.x changes (non-binding roadmap)

- **2.0.0** (stable, post-Round-1 acceptance): no schema changes; expanded test coverage; minor template polish.
- **2.0.0-alpha.2** (this release): consumes `phases.P3` + `phases.P4` from greenfield 3.0.0-alpha.2 wizard sections. Future 2.x releases will add P6, P7 (Round 3) and later phases.
- **2.2.0** (Round 3 sync): consumes `phases.P6.{auth,security,privacy}` + `phases.P7.workflow`.
- **2.3.0+** (Rounds 4-6 sync): consumes Personas, Domain Modeling, Risk Identification, Feature Roadmap, Schema/API Draft, Frontend/UX expansion + 12 concern areas.

These are the locked greenfield rounds — onboard 2.x's job is to consume them as they land. No further schema-breaking changes are planned for 2.x; the v2 root shape (with deferred phase stubs) is stable.
