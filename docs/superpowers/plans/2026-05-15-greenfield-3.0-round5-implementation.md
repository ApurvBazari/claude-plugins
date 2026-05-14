# Greenfield 3.0 Round 5 — Feature Roadmap + Schema & API Draft Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 2 new top-level wizard phases (Feature Roadmap at Step 16, Schema & API Draft Review at Step 19), ship 7 renderer scripts that auto-synthesize DB/API/Event drafts from R3+R4 discovery, wire 6 cross-phase invariants, and make onboard render `feature-list.json` + `sprint-1.json` + schema/contract files deterministically from wizard answers instead of conversationally at handoff. Bumps schema `alpha.5 → alpha.6` (auto-migrating).

**Architecture:** Mirrors R4 pattern — each new phase ships a context-shape schema block (replacing the existing `deferredPhase` stub), a Q-bank, a synthesis HTML+MD+dependencies template triplet, a wizard step in `context-gathering/SKILL.md`, and grill-spec invariants. **New mechanic:** P10.5 inverts the capture→render order — `render-schema-drafts.sh` synthesizes drafts mid-wizard, then SDR.Q3-Q8 review them inline. Renderer entrypoint dispatches to one of 6 per-language modules (`render-{db|api|event}-{language}.sh`) based on `phases.schemaDraftReview.languages.*`. Onboard generation reads `phases.featureRoadmap` → writes `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` field-by-field; reads `phases.schemaDraftReview.drafts.{db|api|event}.content` (when `lockedAt` set) → writes verbatim to canonical paths per `outputStrategy`.

**Tech Stack:** Markdown SKILL.md files, JSON Schema draft-07, HTML synthesis templates (Mustache-like `{{placeholder}}` syntax), Markdown synthesis companions, bash renderer scripts (jq + heredocs, no compiled code), shell smoke tests under `tests/round-5/`. Consistent with prior rounds.

**Source spec:** `docs/superpowers/specs/2026-05-15-greenfield-3.0-round5-design.md`

**Branch:** `feat/greenfield-1.4` (new branch for Round 5; off `develop`).

**Target versions on completion:** `greenfield@3.0.0-alpha.6` / `onboard@2.0.0-alpha.6`.

---

## File Structure

### NEW files (~23)

| Path | Responsibility |
|---|---|
| `greenfield/skills/context-gathering/references/feature-roadmap.q-bank.md` | 14 Qs (heavy) for P9 with showInLight + auto-loop flags |
| `greenfield/skills/context-gathering/references/schema-draft-review.q-bank.md` | 12 Qs (heavy) for P10.5 with auto-render hook |
| `greenfield/skills/synthesis-review/references/templates/feature-roadmap.html` | Epic→feature tree, sprint-1 callout, sizing histogram |
| `greenfield/skills/synthesis-review/references/templates/feature-roadmap.md` | Linear Markdown mirror |
| `greenfield/skills/synthesis-review/references/templates/feature-roadmap-dependencies.json.example` | Declares `docs/feature-list.json` + `sprint-1.json` outputs |
| `greenfield/skills/synthesis-review/references/templates/schema-draft-review.html` | Three-panel DB/API/Event review |
| `greenfield/skills/synthesis-review/references/templates/schema-draft-review.md` | Linear Markdown mirror |
| `greenfield/skills/synthesis-review/references/templates/schema-draft-review-dependencies.json.example` | Declares downstream paths per `outputStrategy` |
| `greenfield/skills/grill-spec/references/check-r5-invariants.md` | CHECK-R5-1 through CHECK-R5-6 |
| `greenfield/scripts/render-schema-drafts.sh` | Renderer entrypoint — dispatches to per-language modules |
| `greenfield/scripts/render-db-prisma.sh` | DB renderer: Prisma schema |
| `greenfield/scripts/render-db-sql-ddl.sh` | DB renderer: SQL DDL |
| `greenfield/scripts/render-api-openapi.sh` | API renderer: OpenAPI 3.0 |
| `greenfield/scripts/render-api-graphql.sh` | API renderer: GraphQL SDL |
| `greenfield/scripts/render-event-asyncapi.sh` | Event renderer: AsyncAPI |
| `greenfield/scripts/render-event-json-schema.sh` | Event renderer: JSON Schema |
| `tests/round-5/feature-roadmap-fixture.json` | Mock alpha.6 state for P9 smoke |
| `tests/round-5/feature-roadmap-smoke.sh` | Verifies feature-list.json + sprint-1.json render |
| `tests/round-5/migration-alpha5-fixture.json` | Mock alpha.5 state for pickup shim |
| `tests/round-5/migration-test.sh` | 8 checks: parse, version bump, skipped defaults, no collisions, prior phases preserved |
| `docs/greenfield-3.0-round5/overview.md` | Round 5 summary + brainstorm narrative |
| `docs/greenfield-3.0-round5/migration-notes.md` | User-facing alpha.5 → alpha.6 notes + rollback |
| `docs/greenfield-3.0-round5/coupling-matrix.md` | Extends R4 matrix with P9/P10.5 rows |
| `docs/superpowers/plans/2026-05-15-greenfield-3.0-round5-implementation.md` | This file |

### MODIFIED files (~20)

| Path | What changes |
|---|---|
| `onboard/skills/generate/references/context-shape-v2.json` | Replace `featureRoadmap` + `schemaDraftReview` `$ref: deferredPhase` stubs with full schemas per spec § "Schema additions" |
| `greenfield/skills/synthesis-review/references/dependencies-schema.json` | Verify `featureRoadmap` + `schemaDraftReview` already in phase-pattern (R4 prep); no enum extension needed for sourceRef (R5 features point to existing personas/domainModel sourcing) |
| `onboard/skills/generation/SKILL.md` | Read `phases.featureRoadmap` → write `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json`; read `phases.schemaDraftReview.drafts.*.content` (when locked) → write verbatim |
| `onboard/skills/generation/references/sprint-contracts.md` | One-line clarification: "From R5 onward, sprint-1 is deterministic; the flow below applies to sprint-2..N at sprint boundaries" |
| `greenfield/skills/context-gathering/SKILL.md` | Insert Step 16 (P9 featureRoadmap) + Step 19 (P10.5 schemaDraftReview); auto-render hook; renumber 17→20 (pluginRecommendation 16→17, pluginInstall 17→18, handoff 18→20) |
| `greenfield/skills/synthesis-review/SKILL.md` | Index 2 new templates (feature-roadmap, schema-draft-review) |
| `greenfield/skills/pickup/SKILL.md` | alpha.5 → alpha.6 migration shim (mirrors alpha.4 → alpha.5); Adjust-mode jump-links from P10.5 reject branch |
| `greenfield/skills/check/SKILL.md` | 3 new health-check assertions (P9 completeness, P10.5 lockedAt presence, sprint-contract presence) |
| `greenfield/skills/tooling-generation/SKILL.md` | Pass `phases.featureRoadmap` + `phases.schemaDraftReview` to `/onboard:generate` |
| `greenfield/skills/grill-spec/SKILL.md` | Wire CHECK-R5-1 through CHECK-R5-6 |
| `greenfield/skills/start/SKILL.md` | Step counter 17 → 20; no functional change (R4 toggles cover R5) |
| `greenfield/skills/context-gathering/references/question-bank.md` | No new flags; Round 5 phase reference appendix |
| `greenfield/CLAUDE.md` | Architecture diagram (20 steps), Skill Hierarchy (Step 16 P9, Step 19 P10.5), Key Patterns update |
| `onboard/CLAUDE.md` | Round 5 phase additions block (mirrors existing R4 block) |
| `docs/greenfield-overview.html` | ROUND 5 LOCKED entry in Discussion Log |
| `greenfield/.claude-plugin/plugin.json` | `3.0.0-alpha.5` → `3.0.0-alpha.6` |
| `onboard/.claude-plugin/plugin.json` | `2.0.0-alpha.5` → `2.0.0-alpha.6` |
| `.claude-plugin/marketplace.json` | Version sync (greenfield + onboard) |
| `greenfield/CHANGELOG.md` | alpha.6 entry — auto-migrating |
| `onboard/CHANGELOG-2.0.md` | alpha.6 entry — schema-extension note |

**Total: ~23 new + ~20 modified = ~43 files.** Matches design estimate.

---

## Task Order Overview

```
Phase A — Schema foundations
   T1   Replace featureRoadmap + schemaDraftReview deferred stubs in context-shape-v2.json
   T2   Verify dependencies-schema.json (R5 phases already in regex; sourceRef no-op)

Phase B — Q-bank authoring
   T3   feature-roadmap.q-bank.md (~14 Qs heavy)
   T4   schema-draft-review.q-bank.md (~12 Qs heavy)

Phase C — Renderer scripts (entrypoint + 6 modules)
   T5   render-schema-drafts.sh (entrypoint + dispatch)
   T6   render-db-prisma.sh
   T7   render-db-sql-ddl.sh
   T8   render-api-openapi.sh
   T9   render-api-graphql.sh
   T10  render-event-asyncapi.sh
   T11  render-event-json-schema.sh

   ── CHECKPOINT 1 (after Phase A+C): schema lock + renderer contract lock ──

Phase D — Synthesis templates
   T12  feature-roadmap.html + .md + dependencies.json.example
   T13  schema-draft-review.html + .md + dependencies.json.example

   ── CHECKPOINT 2 (after Phase D): template variable names match Q-bank field paths ──

Phase E — Wizard wiring
   T14  context-gathering/SKILL.md — Step 16 (P9) + Step 19 (P10.5) + auto-render hook
   T15  context-gathering/SKILL.md — renumber 17→20; progress indicator updates
   T16  synthesis-review/SKILL.md — index 2 new templates
   T17  pickup/SKILL.md — alpha.5 → alpha.6 migration shim + Adjust-mode jump-links
   T18  check/SKILL.md — 3 new health checks
   T19  tooling-generation/SKILL.md — pass-through additions
   T20  start/SKILL.md — step counter 17 → 20

Phase F — Cross-phase invariants
   T21  check-r5-invariants.md + grill-spec/SKILL.md wiring + question-bank.md reference

Phase G — Onboard generation
   T22  generation/SKILL.md — featureRoadmap → feature-list.json + sprint-1.json
   T23  generation/SKILL.md — schemaDraftReview.drafts → schema/contract files
   T24  generation/references/sprint-contracts.md — one-line clarification

Phase H — Tests
   T25  feature-roadmap-fixture.json + feature-roadmap-smoke.sh
   T26  migration-alpha5-fixture.json + migration-test.sh

Phase I — Docs + bookkeeping
   T27  docs/greenfield-3.0-round5/ — overview, migration-notes, coupling-matrix
   T28  greenfield/CLAUDE.md + onboard/CLAUDE.md updates
   T29  Version bumps + marketplace.json + CHANGELOGs + greenfield-overview.html

Phase J — Final
   T30  /validate sweep + smoke tests + PR creation
```

**Estimated total: 30 tasks.** Each task = 1 logical commit. Subagent dispatch estimated at ~60-90 invocations (implementer + spec-review + occasional fix per task, matching R4 cadence).

**Two mid-execution checkpoints (carried forward from R3/R4):**

1. **After Phase A + C (schema + renderer contract lock)** — before Q-bank field references depend on stable schema names and before templates depend on renderer output shape.
2. **After Phase D (template lock)** — before state machine wiring; verify synthesis template `{{phases.X.Y}}` paths match the Q-bank `Stores to:` paths character-for-character.

---

## Phase A — Schema foundations

### Task 1: Replace `featureRoadmap` + `schemaDraftReview` deferredPhase stubs in context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Inspect current stubs**

Run: `jq '.properties.phases.properties.featureRoadmap, .properties.phases.properties.schemaDraftReview' onboard/skills/generate/references/context-shape-v2.json`

Expected: both are `{"$ref": "#/definitions/deferredPhase"}`.

- [ ] **Step 2: Read the `deferredPhase` definition for context**

Run: `jq '.definitions.deferredPhase' onboard/skills/generate/references/context-shape-v2.json`

This tells you the existing `skipped: true / deferredReason` shape you must preserve — both new schemas remain backward-compatible by carrying `skipped` + `deferredReason` properties.

- [ ] **Step 3: Replace `featureRoadmap` stub with full schema**

In `onboard/skills/generate/references/context-shape-v2.json`, replace the line containing `"featureRoadmap": {"$ref": "#/definitions/deferredPhase"}` with the full block below (preserve trailing comma if applicable). All fields per spec § "Schema additions to `phases.featureRoadmap`":

```jsonc
"featureRoadmap": {
  "type": "object",
  "description": "Round 5 — Feature roadmap captured at Step 16. Produces docs/feature-list.json + docs/sprint-contracts/sprint-1.json deterministically.",
  "properties": {
    "horizon": {
      "type": "string",
      "enum": ["mvp-only", "3-months", "6-months", "1-year", "open-ended"]
    },
    "mvpBoundary": { "type": "string" },
    "sizingScale": {
      "type": "string",
      "enum": ["tshirt", "fibonacci", "hours", "none"],
      "default": "tshirt"
    },
    "epics": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string", "pattern": "^E[0-9]+$" },
          "title": { "type": "string" },
          "personaIds": { "type": "array", "items": { "type": "string" } },
          "sequenceAfter": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["id", "title"]
      }
    },
    "features": {
      "type": "array",
      "maxItems": 100,
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string", "pattern": "^F[0-9]{3}$" },
          "title": { "type": "string" },
          "category": {
            "type": "string",
            "enum": ["ui", "api", "data", "infra", "ops", "docs", "other"]
          },
          "epicId": { "type": ["string", "null"] },
          "personaIds": { "type": "array", "items": { "type": "string" } },
          "entityIds": { "type": "array", "items": { "type": "string" } },
          "riskIds": { "type": "array", "items": { "type": "string" } },
          "size": { "type": ["string", "number", "null"] },
          "acceptanceCriteria": { "type": "array", "items": { "type": "string" } },
          "verificationSteps": { "type": "array", "items": { "type": "string" } },
          "sprintAssignment": { "type": ["integer", "null"] }
        },
        "required": ["id", "title", "category"]
      }
    },
    "sprint1": {
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "featureIds": { "type": "array", "items": { "type": "string" } },
        "criteria": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "weight": { "type": "string", "enum": ["required", "recommended", "aspirational"] },
              "description": { "type": "string" },
              "threshold": { "type": "string" }
            },
            "required": ["name", "weight"]
          }
        },
        "completionGate": { "type": "string" }
      }
    },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" }
  }
}
```

- [ ] **Step 4: Replace `schemaDraftReview` stub with full schema**

Same approach. Block per spec § "Schema additions to `phases.schemaDraftReview`":

```jsonc
"schemaDraftReview": {
  "type": "object",
  "description": "Round 5 — Schema & API Draft Review at Step 19. Auto-renders DB/API/Event drafts from R3+R4 discovery, then user reviews/locks.",
  "properties": {
    "applicableArtifacts": {
      "type": "array",
      "items": { "type": "string", "enum": ["db", "api", "event"] }
    },
    "languages": {
      "type": "object",
      "properties": {
        "db":    { "type": "string", "enum": ["prisma", "sql-ddl", "typeorm", "sqlalchemy", "none"] },
        "api":   { "type": "string", "enum": ["openapi-3.0", "graphql-sdl", "trpc", "postman", "none"] },
        "event": { "type": "string", "enum": ["asyncapi", "json-schema", "avro", "none"] }
      }
    },
    "drafts": {
      "type": "object",
      "properties": {
        "db":    { "$ref": "#/definitions/schemaDraft" },
        "api":   { "$ref": "#/definitions/schemaDraft" },
        "event": { "$ref": "#/definitions/schemaDraft" }
      }
    },
    "crossCheckWarnings": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "level": { "type": "string", "enum": ["error", "warn", "info"] },
          "message": { "type": "string" },
          "addressed": { "type": "boolean", "default": false },
          "addressedNote": { "type": "string" }
        },
        "required": ["id", "level", "message"]
      }
    },
    "outputStrategy": {
      "type": "string",
      "enum": ["project-root", "docs-drafts"],
      "default": "project-root"
    },
    "lockedAt": { "type": "string", "format": "date-time" },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string", "default": "" }
  }
}
```

- [ ] **Step 5: Add `schemaDraft` definition under `definitions`**

Insert under `definitions` (alongside `deferredPhase`):

```jsonc
"schemaDraft": {
  "type": "object",
  "properties": {
    "renderedAt": { "type": "string", "format": "date-time" },
    "sourceRefs": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "path": { "type": "string" },
          "renderedAs": { "type": "string" }
        },
        "required": ["path"]
      }
    },
    "content": { "type": "string" },
    "adjustments": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "at": { "type": "string", "format": "date-time" },
          "change": { "type": "string" },
          "rationale": { "type": "string" }
        }
      }
    },
    "approved": { "type": "boolean", "default": false },
    "skipped": { "type": "boolean", "default": false }
  }
}
```

- [ ] **Step 6: Validate JSON parses**

Run: `jq '.properties.phases.properties.featureRoadmap.properties.features.items.properties.id, .properties.phases.properties.schemaDraftReview.properties.drafts.properties.db, .definitions.schemaDraft.properties.content' onboard/skills/generate/references/context-shape-v2.json`

Expected: pattern `^F[0-9]{3}$`, `$ref` to schemaDraft, `type: string`. No `parse error`.

- [ ] **Step 7: Confirm pickup-shim default invariants**

Both phases must keep `skipped` + `deferredReason` properties so the alpha.5 → alpha.6 migration shim (Task 17) can inject `{skipped: true, deferredReason: "session predates Round 5"}` against a strict validator.

- [ ] **Step 8: Commit**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "feat(onboard): R5 — replace featureRoadmap + schemaDraftReview deferred stubs in context-shape-v2"
```

---

### Task 2: Verify `dependencies-schema.json` already covers R5 phases

**Files:**
- Modify (if needed): `greenfield/skills/synthesis-review/references/dependencies-schema.json`

- [ ] **Step 1: Confirm regex already includes R5 phases**

Run: `grep -E 'featureRoadmap|schemaDraftReview' greenfield/skills/synthesis-review/references/dependencies-schema.json`

Expected: matches present on the `phase` and `path` patterns (R4 prep already extended these). If matches absent (regression check), follow Step 2; else skip to Step 3.

- [ ] **Step 2 (conditional): Extend regex if absent**

Edit lines 16 + 34 of `greenfield/skills/synthesis-review/references/dependencies-schema.json` — add `|featureRoadmap|schemaDraftReview` to both pipe-alternation lists.

- [ ] **Step 3: sourceRef enum — confirm no change needed**

The `sourceRef.phase` enum (line ~54) is `["personas", "domainModel"]`. R5 features carry `personaIds` / `entityIds` pointing back to these phases; no new sourceRef sources are introduced by R5. No change.

- [ ] **Step 4: Commit (only if Step 2 applied)**

```bash
git add greenfield/skills/synthesis-review/references/dependencies-schema.json
git commit -m "chore(greenfield): R5 — confirm dependencies-schema covers featureRoadmap + schemaDraftReview"
```

If no change, skip the commit and move on.

---

## Phase B — Q-bank authoring

### Task 3: Author `feature-roadmap.q-bank.md`

**Files:**
- Create: `greenfield/skills/context-gathering/references/feature-roadmap.q-bank.md`

- [ ] **Step 1: Inspect personas q-bank for structure template**

Run: `head -60 greenfield/skills/context-gathering/references/personas.q-bank.md`

Mirror its format: H1 title with phase + step, frontmatter block (Round, Steps, Modes, Coupling, See also), then `## Q-bank` with `### Q1`-style headings carrying type/options/showInLight/isRiskCapture/loopOver fields plus prompt + Stores to.

- [ ] **Step 2: Write the file**

Create `greenfield/skills/context-gathering/references/feature-roadmap.q-bank.md` with the structure below. Each Q follows the spec § "Q-bank" in `2026-05-15-greenfield-3.0-round5-design.md` lines 86-161 verbatim for field labels and Stores-to paths.

Required structure (full content):

```markdown
# Feature Roadmap Q-bank — Step 16

> **Round:** 5 (Roadmap synthesis phase)
> **Steps:** 16 (after architecturalValidation at Step 15, before pluginRecommendation at Step 17)
> **Modes:** Heavy ~14 Qs + per-persona auto-loop / Light ~7 Qs (drops Q5/Q6/Q7/Q9)
> **Coupling:** Reads `personas.primary[]`, `domainModel.entities[]`, `risks[]`. Writes `phases.featureRoadmap.*`. Output drives `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` via onboard generation.
> **See also:** `personas.q-bank.md`, `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Phase 1: Feature Roadmap (P9)

This phase captures **rich features with epic grouping, persona/entity/risk back-links, acceptance criteria, verification steps, and sizing**. Output is fully deterministic — onboard's generation skill renders `feature-list.json` + `sprint-1.json` field-by-field from the answers.

## Q-bank

### FR.Q1 — Horizon
- **type:** single-select
- **options:** ["mvp-only", "3-months", "6-months", "1-year", "open-ended"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "What's your roadmap horizon? (Single-feature MVP → broad multi-quarter scope)"
- **Stores to:** `phases.featureRoadmap.horizon`

### FR.Q2 — MVP boundary
- **type:** long-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "What separates MVP scope from post-MVP? (One paragraph — a clear boundary keeps sprint-1 honest.)"
- **Stores to:** `phases.featureRoadmap.mvpBoundary`

### FR.Q3 — Sizing scale
- **type:** single-select
- **options:** ["tshirt (S/M/L/XL)", "fibonacci", "hours", "none"]
- **default:** "tshirt"
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Sizing scale for features? (tshirt is recommended unless your team already uses fibonacci/hours.)"
- **Stores to:** `phases.featureRoadmap.sizingScale`

### FR.Q4 — Features by persona  [LOOP — per primary persona]
- **type:** repeating structured (title, category, size)
- **loopOver:** `personas.primary`
- **loopMode:** hybrid-only  <!-- collapses to flat in mode.coupling=hybrid -->
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "What does {persona.name} need to do in the system? (List features that serve this persona — wizard auto-tags personaIds[])"
- **Stores to:** `phases.featureRoadmap.features[]` (id auto-assigned F001/F002/…; personaIds[] = [currentPersona.id])

### FR.Q5 — Entity links  [PER-FEATURE]
- **type:** multi-select (per feature)
- **options:** dynamic from `domainModel.entities[].id`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Which domain entities does {feature.title} touch?"
- **Stores to:** `phases.featureRoadmap.features[*].entityIds[]`

### FR.Q6 — Risk links  [PER-FEATURE]
- **type:** multi-select (per feature)
- **options:** dynamic from `risks[].id`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Which captured risks does {feature.title} address or expose?"
- **Stores to:** `phases.featureRoadmap.features[*].riskIds[]`

### FR.Q7 — Acceptance criteria  [PER-FEATURE]
- **type:** bulleted free-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Acceptance criteria for {feature.title}? (Bulleted — each line a checkable assertion.)"
- **Stores to:** `phases.featureRoadmap.features[*].acceptanceCriteria[]`

### FR.Q8 — Verification steps  [PER-FEATURE]
- **type:** bulleted free-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Verification steps for {feature.title}? (Automatable preferred — these feed `feature-list.json` and the sprint gate.)"
- **Stores to:** `phases.featureRoadmap.features[*].verificationSteps[]`

### FR.Q9 — Epic grouping  [PER-PERSONA]
- **type:** structured (epic title + featureIds[])
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Group {persona.name}'s features into epics. (One epic per coherent theme — epic IDs auto-assigned E1/E2/…)"
- **Stores to:** `phases.featureRoadmap.epics[]` (id, title); `features[*].epicId`

### FR.Q10 — Cross-cutting features
- **type:** repeating structured (title, category, size, verificationSteps)
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Features not tied to a specific persona (ops dashboards, admin, observability, internal tooling)? Same shape as FR.Q4 but condensed."
- **Stores to:** `phases.featureRoadmap.features[]` with personaIds[] = []

### FR.Q11 — Epic sequencing
- **type:** structured (per epic: prerequisites)
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "For each epic, which epics must precede it? (Order-of-build constraints.)"
- **Stores to:** `phases.featureRoadmap.epics[*].sequenceAfter[]`

### FR.Q12 — Sprint-1 selection
- **type:** multi-select
- **options:** dynamic from captured features
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which features land in sprint-1? (Pick a focused set — size-budget warning triggers if S=1/M=3/L=5/XL=8 sum > 15.)"
- **Stores to:** `phases.featureRoadmap.sprint1.featureIds[]`; `features[*].sprintAssignment = 1`

### FR.Q13 — Sprint-1 contract
- **type:** structured (criteria[] with name/weight/description/threshold)
- **showInLight:** true
- **isRiskCapture:** false
- **defaults:** functional/quality/testing as `required`; performance/security/a11y as `recommended` when applicable
- **Prompt:** "Sprint-1 completion gate. Adopt onboard's standard criteria (functional/quality/testing required) or customize?"
- **Stores to:** `phases.featureRoadmap.sprint1.criteria[]`, `phases.featureRoadmap.sprint1.completionGate`

### FR.Q14 — Q_RISK trailer
- **type:** long-text (parseable into structured risks[])
- **showInLight:** false
- **isRiskCapture:** true
- **Prompt:** "Roadmap risks? (Scope creep on epic X, persona Y unvalidated, dependency on external vendor, etc.)"
- **Stores to:** `risks[]` with `originatingPhase: "featureRoadmap"`

## Auto-loop behavior

| Mode | FR.Q4–Q9 |
|---|---|
| `mode.coupling = auto-loop` AND `personas.skipped != true` | Loops per `personas.primary[]`. Each iteration auto-tags `personaIds[]`. |
| `mode.coupling = hybrid` | Loop collapses; static prompts list all primary personas inline; user assigns `personaIds[]` per feature. |
| `personas.skipped = true` | FR.Q4–Q9 skipped entirely; all features captured via FR.Q10. |

## Edge cases

- `personas.skipped = true` → FR.Q4-Q9 loop skipped; features captured via FR.Q10 only.
- `domainModel.deferred = true` → FR.Q5 optional; rendered with empty arrays.
- Zero `Q_RISK` answers across all phases → FR.Q6 optional; rendered with empty arrays.
- `mode.depth = light` → drops FR.Q5/Q6/Q7/Q9 (~7 effective Qs).
- `mode.depth = light` AND `mode.coupling = hybrid` → minimum-viable P9 (~5 effective prompts).
- Sprint-1 size budget exceeded (sum > 15) → "Sprint-1 has Xpts — typical is 10-15. Trim or accept?" prompt before lock (R-R5-3 mitigation).
```

- [ ] **Step 3: Verify Stores-to paths match Task 1 schema**

Run: `grep -E '^\*\*Stores to' greenfield/skills/context-gathering/references/feature-roadmap.q-bank.md | sort -u`

Cross-check every path against `phases.featureRoadmap.*` from Task 1 Step 3.

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/context-gathering/references/feature-roadmap.q-bank.md
git commit -m "feat(greenfield): R5 — feature-roadmap q-bank (14 Qs heavy / 7 light + per-persona auto-loop)"
```

---

### Task 4: Author `schema-draft-review.q-bank.md`

**Files:**
- Create: `greenfield/skills/context-gathering/references/schema-draft-review.q-bank.md`

- [ ] **Step 1: Write the file**

Mirror Task 3 structure. Content per spec § "Phase 2: Schema & API Draft Review (P10.5)" lines 292-357. Critical to capture: the AUTO-RENDER block is **not a question** — it is a wizard-side system action that runs `${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh` between SDR.Q2 and SDR.Q3.

Required content:

```markdown
# Schema & API Draft Review Q-bank — Step 19

> **Round:** 5 (Draft-review phase — the architectural inversion)
> **Steps:** 19 (after pluginInstall at Step 18, before handoff at Step 20)
> **Modes:** Heavy ~12 Qs / Light ~6 Qs (drops Adjust flows SDR.Q4/Q6/Q8)
> **Coupling:** Reads `domainModel.*`, `auth.*`, `privacy.*`, `apiIntegration.*`, `runtimeOperations.observability`. Writes `phases.schemaDraftReview.*`. Auto-renders DB/API/Event drafts mid-flow.
> **See also:** `feature-roadmap.q-bank.md`, design spec § Phase 2: Schema & API Draft Review (P10.5), `greenfield/scripts/render-schema-drafts.sh`

This phase is **architecturally inverted**: most phases capture then render. P10.5 renders first (auto-synthesizing drafts from upstream discovery), then captures the user's review decisions inline.

## Q-bank

### SDR.Q1 — Applicable artifacts
- **type:** multi-select
- **options:** ["db", "api", "event"]
- **showInLight:** true
- **isRiskCapture:** false
- **pre-checked:** db if `dataArchitecture.engine != "none"`; api if `apiIntegration.endpoints[]` non-empty OR `asyncPattern != "none"`; event if `domainModel.domainEvents[]` non-empty
- **Prompt:** "Which artifacts apply to this project? (Pre-checked from upstream answers — deselect anything not applicable.)"
- **Stores to:** `phases.schemaDraftReview.applicableArtifacts[]`

### SDR.Q2 — Language preferences
- **type:** structured (one single-select per enabled artifact)
- **options:**
  - db: ["prisma", "sql-ddl", "typeorm", "sqlalchemy", "none"]
  - api: ["openapi-3.0", "graphql-sdl", "trpc", "postman", "none"]
  - event: ["asyncapi", "json-schema", "avro", "none"]
- **defaults:** pre-filled from stack
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Output language per artifact?"
- **Stores to:** `phases.schemaDraftReview.languages.{db,api,event}`

### AUTO-RENDER  (system action — not a question)

Wizard runs `${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh <state-file>` which:
- reads context-shape-v2 state
- writes `phases.schemaDraftReview.drafts.{db,api,event}.{content,sourceRefs,renderedAt}` + `crossCheckWarnings[]`
- if render fails: surface error + halt before SDR.Q3.

For each artifact not in `applicableArtifacts[]`, the wizard sets `drafts.{artifact}.skipped = true` and skips its SDR.Q3-Q8 pair.

### SDR.Q3 — DB review
- **type:** single-select
- **options:** ["Approve", "Adjust", "Reject + regenerate"]
- **showInLight:** true
- **isRiskCapture:** false
- **skip if:** `drafts.db.skipped = true`
- **Prompt:** "Review the rendered DB schema below. Approve as-is, adjust inline, or reject and edit upstream answers?\n\n{drafts.db.content}"
- **Stores to:** `phases.schemaDraftReview.drafts.db.approved` (true on Approve)

### SDR.Q4 — DB adjust  [CONDITIONAL on SDR.Q3 = Adjust]
- **type:** long-text or structured delta (add field / rename / change type / add index)
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Describe the adjustment — wizard re-renders and re-prompts SDR.Q3."
- **Stores to:** `phases.schemaDraftReview.drafts.db.adjustments[]`

### SDR.Q5 — API review  [same pattern as Q3 for `drafts.api`]
### SDR.Q6 — API adjust  [same pattern as Q4]
### SDR.Q7 — Event review  [same pattern as Q3 for `drafts.event`]
### SDR.Q8 — Event adjust  [same pattern as Q4]

### SDR.Q9 — Cross-check resolution
- **type:** structured (per warning: addressed bool + optional note)
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Resolve cross-check warnings (per-warning prompt below). Errors must be addressed before the lock gate; warns/info are advisory."
- **Stores to:** `phases.schemaDraftReview.crossCheckWarnings[*].addressed`

### SDR.Q10 — Lock gate
- **type:** confirm
- **showInLight:** true
- **isRiskCapture:** false
- **gate:** blocked unless every enabled draft has `approved = true` AND every `level=error` warning has `addressed = true` (per CHECK-R5-4)
- **Prompt:** "Lock these drafts as canonical? Onboard will write them verbatim during tooling generation."
- **Stores to:** `phases.schemaDraftReview.lockedAt`

### SDR.Q11 — Output strategy
- **type:** single-select
- **options:** ["project-root", "docs-drafts"]
- **default:** "project-root"
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Write schema/contract files directly to project root (`prisma/schema.prisma`, `docs/api/openapi.yaml`, `docs/events/event-schemas.yaml`) or to `docs/drafts/` for manual placement?"
- **Stores to:** `phases.schemaDraftReview.outputStrategy`

### SDR.Q12 — Q_RISK trailer
- **type:** long-text
- **showInLight:** false
- **isRiskCapture:** true
- **Prompt:** "Schema/contract risks? (Schema mismatch with downstream consumers, API breaking change before v1.0, etc.)"
- **Stores to:** `risks[]` with `originatingPhase: "schemaDraftReview"`

## Edge cases

- `dataArchitecture.engine = "none"` → `drafts.db.skipped = true`; SDR.Q3/Q4 skipped.
- `apiIntegration.endpoints[]` empty AND `asyncPattern = "none"` → `drafts.api.skipped = true`; SDR.Q5/Q6 skipped.
- `domainModel.domainEvents[]` empty → `drafts.event.skipped = true`; SDR.Q7/Q8 skipped.
- **All three skipped** → entire P10.5 skipped with `phases.schemaDraftReview.skipped=true` AND `deferredReason="no applicable artifacts"`; wizard jumps Step 18 → Step 20.
- `mode.depth = light` → SDR.Q4/Q6/Q8 (Adjust) skipped; only Approve/Reject. Reject loops back to upstream phase via Adjust mode.
- Multiple databases → `drafts.db` becomes array `drafts.db[]`; SDR.Q3/Q4 fire per database. (Round 5 stretch goal — gracefully degrade to first-DB-only if state still scalar.)
- Reject + upstream change → Reject branch shows "the X part of this draft came from phase Y — adjust there?" with `/greenfield:pickup` Adjust-mode jump-link.
- Renderer failure → surface error; halt before SDR.Q3. Allow retry or skip-with-deferred-reason path.
```

- [ ] **Step 2: Cross-check Stores-to paths against Task 1 schema**

Run: `grep -E '^\*\*Stores to' greenfield/skills/context-gathering/references/schema-draft-review.q-bank.md | sort -u`

Verify each `phases.schemaDraftReview.*` path appears in Task 1 Step 4 schema.

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/context-gathering/references/schema-draft-review.q-bank.md
git commit -m "feat(greenfield): R5 — schema-draft-review q-bank (12 Qs heavy / 6 light + auto-render hook)"
```

---

## Phase C — Renderer scripts

### Task 5: Write `render-schema-drafts.sh` (entrypoint)

**Files:**
- Create: `greenfield/scripts/render-schema-drafts.sh`

- [ ] **Step 1: Check existing greenfield scripts for shebang + style precedent**

Run: `head -10 greenfield/scripts/detect-scaffold-cli.sh`

Mirror its header (shebang, `set -euo pipefail`, comment block).

- [ ] **Step 2: Write the entrypoint**

```bash
#!/usr/bin/env bash
# render-schema-drafts.sh — Round 5 (P10.5) entrypoint
#
# Reads phases.schemaDraftReview.{applicableArtifacts, languages} from the
# context-shape-v2 state file passed as $1. Dispatches to per-language
# renderer modules in this same directory. Writes drafts.{db,api,event}.*
# and crossCheckWarnings[] back to the state file atomically (.tmp + rename).
#
# Usage: render-schema-drafts.sh <state-file-path>
# Output: 0 on success; non-zero with stderr message on error.

set -euo pipefail

STATE_FILE="${1:?usage: render-schema-drafts.sh <state-file>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "$STATE_FILE" ]] || { echo "render-schema-drafts: state file not found: $STATE_FILE" >&2; exit 1; }
command -v jq >/dev/null || { echo "render-schema-drafts: jq is required" >&2; exit 2; }

TMP_OUT="${STATE_FILE}.tmp"
cp "$STATE_FILE" "$TMP_OUT"

ARTIFACTS=$(jq -r '.phases.schemaDraftReview.applicableArtifacts[]?' "$STATE_FILE" 2>/dev/null || true)
[[ -z "$ARTIFACTS" ]] && { echo "render-schema-drafts: applicableArtifacts[] empty; nothing to do" >&2; exit 0; }

WARNINGS_JSON="[]"

for ART in $ARTIFACTS; do
  LANG=$(jq -r ".phases.schemaDraftReview.languages.$ART // \"none\"" "$STATE_FILE")
  case "$ART:$LANG" in
    db:prisma)       MODULE="render-db-prisma.sh" ;;
    db:sql-ddl)      MODULE="render-db-sql-ddl.sh" ;;
    api:openapi-3.0) MODULE="render-api-openapi.sh" ;;
    api:graphql-sdl) MODULE="render-api-graphql.sh" ;;
    event:asyncapi)  MODULE="render-event-asyncapi.sh" ;;
    event:json-schema) MODULE="render-event-json-schema.sh" ;;
    *)
      # Unsupported language → surface message and skip this artifact
      echo "render-schema-drafts: language '$LANG' for artifact '$ART' not yet supported in R5. Skipping; user must re-answer SDR.Q2 with a supported language or set drafts.$ART.skipped=true." >&2
      jq ".phases.schemaDraftReview.drafts.$ART = (.phases.schemaDraftReview.drafts.$ART // {}) + {skipped: true, deferredReason: \"language '$LANG' not yet supported in R5\"}" "$TMP_OUT" > "${TMP_OUT}.x" && mv "${TMP_OUT}.x" "$TMP_OUT"
      continue
      ;;
  esac

  MODULE_PATH="${SCRIPT_DIR}/${MODULE}"
  [[ -x "$MODULE_PATH" ]] || { echo "render-schema-drafts: missing module: $MODULE_PATH" >&2; rm -f "$TMP_OUT"; exit 3; }

  RENDER_OUT=$("$MODULE_PATH" "$STATE_FILE") || {
    echo "render-schema-drafts: module '$MODULE' failed for artifact '$ART'" >&2
    rm -f "$TMP_OUT"
    exit 4
  }

  RENDERED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  CONTENT=$(echo "$RENDER_OUT" | jq -r '.content // empty')
  SOURCE_REFS=$(echo "$RENDER_OUT" | jq '.sourceRefs // []')
  MODULE_WARNINGS=$(echo "$RENDER_OUT" | jq '.crossCheckWarnings // []')

  jq --arg art "$ART" \
     --arg content "$CONTENT" \
     --arg renderedAt "$RENDERED_AT" \
     --argjson srcRefs "$SOURCE_REFS" \
     '.phases.schemaDraftReview.drafts[$art] = ((.phases.schemaDraftReview.drafts[$art] // {}) + {renderedAt: $renderedAt, sourceRefs: $srcRefs, content: $content, approved: false, skipped: false})' \
     "$TMP_OUT" > "${TMP_OUT}.x" && mv "${TMP_OUT}.x" "$TMP_OUT"

  WARNINGS_JSON=$(echo "$WARNINGS_JSON $MODULE_WARNINGS" | jq -s 'add')
done

jq --argjson w "$WARNINGS_JSON" '.phases.schemaDraftReview.crossCheckWarnings = $w' "$TMP_OUT" > "${TMP_OUT}.x" && mv "${TMP_OUT}.x" "$TMP_OUT"

mv "$TMP_OUT" "$STATE_FILE"
echo "render-schema-drafts: completed; drafts populated for [$ARTIFACTS]"
```

- [ ] **Step 3: Make executable + ShellCheck**

```bash
chmod +x greenfield/scripts/render-schema-drafts.sh
shellcheck greenfield/scripts/render-schema-drafts.sh
```

Expected: no output (clean).

- [ ] **Step 4: Sanity-run with empty state**

```bash
echo '{"phases":{"schemaDraftReview":{"applicableArtifacts":[]}}}' > /tmp/r5-empty.json
greenfield/scripts/render-schema-drafts.sh /tmp/r5-empty.json
rm /tmp/r5-empty.json
```

Expected: stderr "applicableArtifacts[] empty; nothing to do" with exit 0.

- [ ] **Step 5: Commit**

```bash
git add greenfield/scripts/render-schema-drafts.sh
git commit -m "feat(greenfield): R5 — render-schema-drafts.sh entrypoint dispatches to per-language modules"
```

---

### Task 6: Write `render-db-prisma.sh`

**Files:**
- Create: `greenfield/scripts/render-db-prisma.sh`

**Contract:**
- Input: `$1` = state file path. Reads `phases.domainModel.entities[]`, `.valueObjects[]`, `.contexts[]`, `phases.auth.roles[]`, `phases.privacy.piiFields[]`.
- Output (stdout, JSON): `{ "content": "<prisma schema as string>", "sourceRefs": [...], "crossCheckWarnings": [...] }`.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# render-db-prisma.sh — R5 P10.5 DB renderer (Prisma)
#
# Reads domain model + auth + privacy from $1 and emits a Prisma schema string
# wrapped in a JSON envelope to stdout. sourceRefs map each rendered model
# back to its origin entity. crossCheckWarnings surface aggregate-roots-without-PK,
# PII-without-encryption-hint, etc.

set -euo pipefail
STATE_FILE="${1:?usage: render-db-prisma.sh <state-file>}"

ENTITIES=$(jq '.phases.domainModel.entities // []' "$STATE_FILE")
PII=$(jq '.phases.privacy.piiFields // []' "$STATE_FILE")

# Build the prisma string
HEADER='// Generated by greenfield render-db-prisma.sh — review and edit freely after lock.
generator client {
  provider = "prisma-client-js"
}
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
'

MODELS=""
SRC_REFS="[]"
WARNINGS="[]"

ENTITY_COUNT=$(jq 'length' <<< "$ENTITIES")
for i in $(seq 0 $((ENTITY_COUNT - 1))); do
  E=$(jq ".[$i]" <<< "$ENTITIES")
  NAME=$(jq -r '.name // .id // "Unknown"' <<< "$E")
  IS_AGGREGATE_ROOT=$(jq -r '.isAggregateRoot // false' <<< "$E")
  PK_FIELD=$(jq -r '.primaryKey // ""' <<< "$E")

  # Warning: aggregate root missing PK
  if [[ "$IS_AGGREGATE_ROOT" == "true" && -z "$PK_FIELD" ]]; then
    WARN_ID="W-DB-$i-pk"
    WARNINGS=$(jq --arg id "$WARN_ID" --arg name "$NAME" '. + [{id: $id, level: "error", message: ("Aggregate root `" + $name + "` has no PK field — cannot generate schema")}]' <<< "$WARNINGS")
    [[ -z "$PK_FIELD" ]] && PK_FIELD="id"
  fi
  [[ -z "$PK_FIELD" ]] && PK_FIELD="id"

  FIELDS_BLOCK="  $PK_FIELD String @id @default(cuid())"

  ATTRS=$(jq '.attributes // []' <<< "$E")
  A_COUNT=$(jq 'length' <<< "$ATTRS")
  for j in $(seq 0 $((A_COUNT - 1))); do
    AN=$(jq -r ".[$j].name // \"f$j\"" <<< "$ATTRS")
    AT=$(jq -r ".[$j].type // \"String\"" <<< "$ATTRS")
    # Map common type strings to Prisma scalars
    case "$AT" in
      string|String|text) PT="String" ;;
      int|integer|Int)    PT="Int" ;;
      bool|boolean|Boolean) PT="Boolean" ;;
      date|datetime|DateTime) PT="DateTime" ;;
      float|number|Float) PT="Float" ;;
      *) PT="String" ;;
    esac
    [[ "$AN" == "$PK_FIELD" ]] && continue
    FIELDS_BLOCK="${FIELDS_BLOCK}
  $AN $PT"

    # PII warning hook
    PII_HIT=$(jq --arg n "$NAME.$AN" '[.[] | select(.path == $n)] | length' <<< "$PII")
    if [[ "$PII_HIT" -gt 0 ]]; then
      HAS_ENCRYPTION=$(jq --arg n "$NAME.$AN" '[.[] | select(.path == $n) | .encryption // ""] | first // ""' <<< "$PII")
      if [[ -z "$HAS_ENCRYPTION" || "$HAS_ENCRYPTION" == "\"\"" ]]; then
        WARNINGS=$(jq --arg id "W-DB-$i-$j-pii" --arg msg "Field \`$NAME.$AN\` (PII) has no encryption hint — review storage strategy" '. + [{id: $id, level: "warn", message: $msg}]' <<< "$WARNINGS")
      fi
    fi
  done

  MODELS="${MODELS}
model $NAME {
$FIELDS_BLOCK
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
"

  SRC_REFS=$(jq --arg p "phases.domainModel.entities[$i]" --arg r "model $NAME" '. + [{path: $p, renderedAs: $r}]' <<< "$SRC_REFS")
done

CONTENT="${HEADER}${MODELS}"

jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
```

- [ ] **Step 2: chmod + ShellCheck**

```bash
chmod +x greenfield/scripts/render-db-prisma.sh
shellcheck greenfield/scripts/render-db-prisma.sh
```

- [ ] **Step 3: Smoke-test with minimal fixture**

```bash
cat > /tmp/r5-prisma-fixture.json <<'EOF'
{
  "phases": {
    "domainModel": {
      "entities": [
        {"id": "Audit", "name": "Audit", "isAggregateRoot": true, "primaryKey": "id",
         "attributes": [{"name": "action", "type": "string"}, {"name": "createdAt", "type": "datetime"}]}
      ]
    },
    "privacy": {"piiFields": []}
  }
}
EOF
greenfield/scripts/render-db-prisma.sh /tmp/r5-prisma-fixture.json | jq -r '.content'
rm /tmp/r5-prisma-fixture.json
```

Expected: stdout shows valid-shaped Prisma schema with `model Audit { ... }`.

- [ ] **Step 4: Commit**

```bash
git add greenfield/scripts/render-db-prisma.sh
git commit -m "feat(greenfield): R5 — render-db-prisma.sh (Prisma DB renderer with PII/PK warnings)"
```

---

### Task 7: Write `render-db-sql-ddl.sh`

**Files:**
- Create: `greenfield/scripts/render-db-sql-ddl.sh`

**Contract:** Same inputs as Task 6, emits SQL DDL (`CREATE TABLE` per entity) instead of Prisma. Same warning categories.

- [ ] **Step 1: Write the script**

Mirror Task 6 structure, replacing the model template with:

```sql
CREATE TABLE "<TableName>" (
  <pk> SERIAL PRIMARY KEY,
  <fields...>
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Type mapping: string/text → VARCHAR(255), int/integer → INTEGER, bool/boolean → BOOLEAN, date/datetime → TIMESTAMP, float/number → DOUBLE PRECISION. Snake-case the table name from the entity name. Emit the same `sourceRefs` and `crossCheckWarnings` shape as Task 6. Header: `-- Generated by greenfield render-db-sql-ddl.sh — review and edit freely after lock.`

- [ ] **Step 2: chmod + ShellCheck + smoke**

```bash
chmod +x greenfield/scripts/render-db-sql-ddl.sh
shellcheck greenfield/scripts/render-db-sql-ddl.sh
greenfield/scripts/render-db-sql-ddl.sh /tmp/r5-prisma-fixture.json  # reuse fixture from T6
```

Expected: stdout shows `CREATE TABLE "audit"` with fields.

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-db-sql-ddl.sh
git commit -m "feat(greenfield): R5 — render-db-sql-ddl.sh (SQL DDL DB renderer)"
```

---

### Task 8: Write `render-api-openapi.sh`

**Files:**
- Create: `greenfield/scripts/render-api-openapi.sh`

**Contract:**
- Input: `$1` = state file. Reads `phases.apiIntegration.endpoints[]`, `.asyncPattern`, `phases.auth.scopes[]`, `phases.domainModel.entities[]`, `phases.privacy.piiFields[]`.
- Output: OpenAPI 3.0 YAML as string in `{content, sourceRefs, crossCheckWarnings}` envelope.

**Warnings:** `error` if PII field exposed in response without redaction; `warn` if auth scope unused; `warn` if entity has no endpoint.

- [ ] **Step 1: Write the script**

Skeleton (full implementation: ~120 lines):

```bash
#!/usr/bin/env bash
# render-api-openapi.sh — R5 P10.5 API renderer (OpenAPI 3.0)
set -euo pipefail
STATE_FILE="${1:?usage: render-api-openapi.sh <state-file>}"

ENDPOINTS=$(jq '.phases.apiIntegration.endpoints // []' "$STATE_FILE")
SCOPES=$(jq -r '.phases.auth.scopes // [] | .[] | .name // .' "$STATE_FILE")
ENTITIES=$(jq '.phases.domainModel.entities // []' "$STATE_FILE")
PII=$(jq '.phases.privacy.piiFields // []' "$STATE_FILE")

HEADER='openapi: 3.0.0
info:
  title: API
  version: 0.1.0
  description: Generated by greenfield render-api-openapi.sh — review and edit freely after lock.
paths:'

PATHS=""
SRC_REFS="[]"
WARNINGS="[]"
USED_SCOPES=()

EC=$(jq 'length' <<< "$ENDPOINTS")
for i in $(seq 0 $((EC - 1))); do
  EP=$(jq ".[$i]" <<< "$ENDPOINTS")
  METHOD=$(jq -r '.method // "GET" | ascii_downcase' <<< "$EP")
  PATH_VAL=$(jq -r '.path // "/" ' <<< "$EP")
  ENTITY=$(jq -r '.entity // ""' <<< "$EP")
  SCOPE=$(jq -r '.scope // ""' <<< "$EP")
  [[ -n "$SCOPE" ]] && USED_SCOPES+=("$SCOPE")

  PATHS="${PATHS}
  ${PATH_VAL}:
    ${METHOD}:
      summary: ${METHOD^^} ${PATH_VAL}
      responses:
        '200':
          description: Success"
  [[ -n "$SCOPE" ]] && PATHS="${PATHS}
      security:
        - bearerAuth: [${SCOPE}]"

  SRC_REFS=$(jq --arg p "phases.apiIntegration.endpoints[$i]" --arg r "${METHOD^^} ${PATH_VAL}" '. + [{path: $p, renderedAs: $r}]' <<< "$SRC_REFS")

  # PII-in-response warning
  if [[ -n "$ENTITY" ]]; then
    PII_FIELDS_IN_ENTITY=$(jq --arg e "$ENTITY" '[.[] | select(.path | startswith($e + "."))] | length' <<< "$PII")
    if [[ "$PII_FIELDS_IN_ENTITY" -gt 0 ]]; then
      WARNINGS=$(jq --arg id "W-API-$i-pii" --arg msg "Endpoint \`${METHOD^^} ${PATH_VAL}\` exposes PII fields from \`$ENTITY\` in response without redaction note" '. + [{id: $id, level: "error", message: $msg}]' <<< "$WARNINGS")
    fi
  fi
done

# Unused scope warning
for S in $SCOPES; do
  USED=0
  for U in "${USED_SCOPES[@]:-}"; do [[ "$U" == "$S" ]] && USED=1 && break; done
  [[ "$USED" -eq 0 ]] && WARNINGS=$(jq --arg id "W-API-scope-$S" --arg msg "Auth scope \`$S\` is not used by any endpoint" '. + [{id: $id, level: "warn", message: $msg}]' <<< "$WARNINGS")
done

# Entity-without-endpoint warning
ENT_COUNT=$(jq 'length' <<< "$ENTITIES")
for k in $(seq 0 $((ENT_COUNT - 1))); do
  EN=$(jq -r ".[$k].name // .[$k].id" <<< "$ENTITIES")
  HAS_EP=$(jq --arg n "$EN" '[.[] | select(.entity == $n)] | length' <<< "$ENDPOINTS")
  [[ "$HAS_EP" == "0" ]] && WARNINGS=$(jq --arg id "W-API-noep-$k" --arg msg "Entity \`$EN\` has no API endpoint — intentional?" '. + [{id: $id, level: "warn", message: $msg}]' <<< "$WARNINGS")
done

CONTENT="${HEADER}${PATHS}
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
"

jq -n --arg content "$CONTENT" --argjson srcRefs "$SRC_REFS" --argjson warnings "$WARNINGS" \
  '{content: $content, sourceRefs: $srcRefs, crossCheckWarnings: $warnings}'
```

- [ ] **Step 2: chmod + ShellCheck + smoke**

```bash
chmod +x greenfield/scripts/render-api-openapi.sh
shellcheck greenfield/scripts/render-api-openapi.sh
cat > /tmp/r5-openapi-fixture.json <<'EOF'
{"phases":{"apiIntegration":{"endpoints":[{"method":"GET","path":"/audits","entity":"Audit","scope":"read:audit"}],"asyncPattern":"none"},"auth":{"scopes":[{"name":"read:audit"}]},"domainModel":{"entities":[{"id":"Audit","name":"Audit"}]},"privacy":{"piiFields":[]}}}
EOF
greenfield/scripts/render-api-openapi.sh /tmp/r5-openapi-fixture.json | jq -r '.content'
rm /tmp/r5-openapi-fixture.json
```

Expected: openapi 3.0 yaml with `/audits:` path + `get:` method.

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-api-openapi.sh
git commit -m "feat(greenfield): R5 — render-api-openapi.sh (OpenAPI 3.0 API renderer with PII/scope/entity warnings)"
```

---

### Task 9: Write `render-api-graphql.sh`

**Files:**
- Create: `greenfield/scripts/render-api-graphql.sh`

**Contract:** Same inputs as Task 8, emits GraphQL SDL (`type Query { ... }`, `type Mutation { ... }`, type defs per entity).

- [ ] **Step 1: Write the script**

Mirror Task 8 envelope. Body translation:
- Each entity → `type <Name> { id: ID! ...attributes }`
- GET endpoints → `Query` fields (`audits: [Audit!]!`, `audit(id: ID!): Audit`)
- POST/PUT/PATCH/DELETE → `Mutation` fields
- Same warning categories as Task 8

- [ ] **Step 2: chmod + ShellCheck + smoke**

```bash
chmod +x greenfield/scripts/render-api-graphql.sh
shellcheck greenfield/scripts/render-api-graphql.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-api-graphql.sh
git commit -m "feat(greenfield): R5 — render-api-graphql.sh (GraphQL SDL API renderer)"
```

---

### Task 10: Write `render-event-asyncapi.sh`

**Files:**
- Create: `greenfield/scripts/render-event-asyncapi.sh`

**Contract:**
- Input: `$1` = state file. Reads `phases.domainModel.domainEvents[]`, `phases.runtimeOperations.observability`.
- Output: AsyncAPI 2.6 YAML.

**Warnings:** `info` if event has no consumer; `warn` if event missing payload schema.

- [ ] **Step 1: Write the script**

Same envelope. Body:

```yaml
asyncapi: 2.6.0
info:
  title: Domain Events
  version: 0.1.0
channels:
  <event.name>:
    subscribe:
      message:
        payload:
          type: object
          properties: <from event.payload // empty>
```

- [ ] **Step 2: chmod + ShellCheck + smoke**

```bash
chmod +x greenfield/scripts/render-event-asyncapi.sh
shellcheck greenfield/scripts/render-event-asyncapi.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-event-asyncapi.sh
git commit -m "feat(greenfield): R5 — render-event-asyncapi.sh (AsyncAPI event renderer)"
```

---

### Task 11: Write `render-event-json-schema.sh`

**Files:**
- Create: `greenfield/scripts/render-event-json-schema.sh`

**Contract:** Same inputs as Task 10, emits a JSON object with one JSON Schema per event keyed by event name:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "events": {
    "<event.name>": { "type": "object", "properties": { ... } }
  }
}
```

- [ ] **Step 1: Write the script**

Mirror Task 10 structure.

- [ ] **Step 2: chmod + ShellCheck + smoke**

```bash
chmod +x greenfield/scripts/render-event-json-schema.sh
shellcheck greenfield/scripts/render-event-json-schema.sh
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/scripts/render-event-json-schema.sh
git commit -m "feat(greenfield): R5 — render-event-json-schema.sh (JSON Schema event renderer)"
```

---

## CHECKPOINT 1 — Schema + Renderer Contract Lock

Before continuing into templates and wizard wiring, verify:

```bash
# Schema validates and includes both R5 phase blocks
jq '.properties.phases.properties.featureRoadmap.properties.features.maxItems, .properties.phases.properties.schemaDraftReview.properties.drafts.properties.db' onboard/skills/generate/references/context-shape-v2.json
# Expected: 100 and a $ref to schemaDraft

# All 7 renderer scripts exist, are executable, ShellCheck-clean
for s in render-schema-drafts.sh render-db-prisma.sh render-db-sql-ddl.sh render-api-openapi.sh render-api-graphql.sh render-event-asyncapi.sh render-event-json-schema.sh; do
  test -x "greenfield/scripts/$s" && shellcheck "greenfield/scripts/$s" && echo "✓ $s"
done
```

Expected: all 7 lines marked ✓; no ShellCheck output.

If any failure → fix and re-commit before moving to Phase D.

---

## Phase D — Synthesis templates

### Task 12: Author `feature-roadmap.html` + `feature-roadmap.md` + dependencies example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/feature-roadmap.html`
- Create: `greenfield/skills/synthesis-review/references/templates/feature-roadmap.md`
- Create: `greenfield/skills/synthesis-review/references/templates/feature-roadmap-dependencies.json.example`

- [ ] **Step 1: Inspect existing template structure**

Run: `ls greenfield/skills/synthesis-review/references/templates/ && head -40 greenfield/skills/synthesis-review/references/templates/personas.html`

Note: section structure (`<h2>`, `<h3>`), Mustache-like `{{phases.X.Y}}` placeholders, badge-style chips for IDs.

- [ ] **Step 2: Write `feature-roadmap.html`**

Six sections rendered as `<section data-phase="featureRoadmap">`:
1. **Horizon & MVP boundary banner** — `{{phases.featureRoadmap.horizon}}` + `{{phases.featureRoadmap.mvpBoundary}}`
2. **Epic tree** — iterate `{{#phases.featureRoadmap.epics}}` → list features grouped by `epicId`
3. **Feature table** — id, title, category, size, personaIds chips, entityIds chips, riskIds chips, sprintAssignment
4. **Sprint-1 callout block** — `{{phases.featureRoadmap.sprint1.name}}`, featureIds[], criteria table
5. **Sizing histogram** — count of S/M/L/XL or fibonacci buckets
6. **Cross-cutting features** — features with empty `personaIds[]`

Use simple HTML (no JS framework). Match the style of `personas.html` exactly — same head/header pattern, same CSS class names, same `<details><summary>` for collapsibles.

- [ ] **Step 3: Write `feature-roadmap.md`**

Linear Markdown version of the same 6 sections — no `<details>`, no chips, just headings + tables. Mustache placeholders as in HTML.

- [ ] **Step 4: Write `feature-roadmap-dependencies.json.example`**

Per the schema at `greenfield/skills/synthesis-review/references/dependencies-schema.json`:

```json
{
  "schemaVersion": 1,
  "phase": "featureRoadmap",
  "recordedAt": "2026-05-15T00:00:00Z",
  "dependencies": [
    {
      "path": "personas.primary[0].id",
      "value": "P1",
      "rationale": "Persona ID referenced by features[].personaIds[] in the auto-loop output."
    },
    {
      "path": "domainModel.entities[0].id",
      "value": "E_audit",
      "rationale": "Entity ID referenced by features[].entityIds[]."
    },
    {
      "path": "risks[0].id",
      "value": "R-DA-1",
      "rationale": "Risk ID referenced by features[].riskIds[]."
    }
  ]
}
```

- [ ] **Step 5: Verify Mustache paths match Q-bank Stores-to**

```bash
grep -oE '\{\{phases\.featureRoadmap\.[a-zA-Z0-9_.\[\]]+\}\}' greenfield/skills/synthesis-review/references/templates/feature-roadmap.html | sort -u
```

Cross-check every path against `Stores to:` lines in `feature-roadmap.q-bank.md`. Any mismatch — fix.

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/feature-roadmap.html \
        greenfield/skills/synthesis-review/references/templates/feature-roadmap.md \
        greenfield/skills/synthesis-review/references/templates/feature-roadmap-dependencies.json.example
git commit -m "feat(greenfield): R5 — feature-roadmap synthesis templates (HTML + MD + dependencies example)"
```

---

### Task 13: Author `schema-draft-review.html` + `schema-draft-review.md` + dependencies example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/schema-draft-review.html`
- Create: `greenfield/skills/synthesis-review/references/templates/schema-draft-review.md`
- Create: `greenfield/skills/synthesis-review/references/templates/schema-draft-review-dependencies.json.example`

- [ ] **Step 1: Write the HTML**

Three-panel layout (three `<section>` blocks side-by-side via CSS grid or stacked):

```html
<section class="panel" data-artifact="db">
  <h2>DB Schema — {{phases.schemaDraftReview.languages.db}}</h2>
  <pre>{{phases.schemaDraftReview.drafts.db.content}}</pre>
  <details><summary>Source refs</summary>
    {{#phases.schemaDraftReview.drafts.db.sourceRefs}}
    <span class="chip">{{path}} → {{renderedAs}}</span>
    {{/phases.schemaDraftReview.drafts.db.sourceRefs}}
  </details>
  <div class="lock-state">Approved: {{phases.schemaDraftReview.drafts.db.approved}}</div>
</section>
```

Same panel block × 3 (api, event). Above the panels: lock-state banner showing `{{phases.schemaDraftReview.lockedAt}}` + count of unaddressed errors. Inline cross-check warnings list at bottom.

- [ ] **Step 2: Write the Markdown mirror**

Linear: `## DB Schema`, ```` ```<lang> ```` content fence, source refs list, then `## API Contract`, then `## Event Schemas`, then `## Cross-Check Warnings`.

- [ ] **Step 3: Write the dependencies example**

```json
{
  "schemaVersion": 1,
  "phase": "schemaDraftReview",
  "recordedAt": "2026-05-15T00:00:00Z",
  "dependencies": [
    {
      "path": "domainModel.entities[0].id",
      "value": "E_audit",
      "rationale": "Entity rendered into DB schema model + API endpoint shape."
    },
    {
      "path": "apiIntegration.endpoints[0].path",
      "value": "/audits",
      "rationale": "API endpoint rendered into OpenAPI path."
    },
    {
      "path": "auth.scopes[0].name",
      "value": "read:audit",
      "rationale": "Auth scope rendered into security: block."
    }
  ]
}
```

- [ ] **Step 4: Verify Mustache paths**

```bash
grep -oE '\{\{phases\.schemaDraftReview\.[a-zA-Z0-9_.\[\]]+\}\}' greenfield/skills/synthesis-review/references/templates/schema-draft-review.html | sort -u
```

Cross-check every path against schema in Task 1 Step 4.

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/schema-draft-review.html \
        greenfield/skills/synthesis-review/references/templates/schema-draft-review.md \
        greenfield/skills/synthesis-review/references/templates/schema-draft-review-dependencies.json.example
git commit -m "feat(greenfield): R5 — schema-draft-review synthesis templates (3-panel HTML + linear MD)"
```

---

## CHECKPOINT 2 — Template + Q-bank field alignment

Before wiring the state machine, run:

```bash
# Every Mustache path in templates must resolve to a Stores-to in the Q-bank
for tmpl in feature-roadmap.html schema-draft-review.html; do
  echo "=== $tmpl ==="
  grep -oE '\{\{phases\.[a-zA-Z0-9_.\[\]]+\}\}' "greenfield/skills/synthesis-review/references/templates/$tmpl" | sort -u
done
```

Manually cross-check each path against `Stores to:` in the corresponding `*.q-bank.md` file. Any mismatch — fix before continuing.

---

## Phase E — Wizard wiring

### Task 14: Insert Step 16 (P9) + Step 19 (P10.5) + auto-render hook into `context-gathering/SKILL.md`

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Find the insertion points**

Run: `grep -n "## Step" greenfield/skills/context-gathering/SKILL.md | head -30`

Locate:
- Existing Step 15 (architecturalValidation) — Step 16 P9 inserts after this.
- Existing Step 16 (pluginRecommendation, will become 17) — record current line for renumbering in Task 15.

- [ ] **Step 2: Insert Step 16 — Feature Roadmap**

After Step 15's closing prose, add a new `## Step 16: Feature Roadmap (featureRoadmap)` section following the pattern of Step 8 (data-architecture) — but with these specifics:
- Reference `references/feature-roadmap.q-bank.md` for the Q-bank
- State machine walks FR.Q1 → FR.Q14 in order
- Auto-loop branch: when `state.mode.coupling = "auto-loop"` AND `state.phases.personas.skipped != true`, iterate FR.Q4-Q9 per `state.phases.personas.primary[]`
- After all Qs answered, invoke `synthesis-review` skill with template `feature-roadmap`
- Checkpoint after FR.Q14 (atomic write to `greenfield-state.json`)
- Skip branch: if user defers, set `phases.featureRoadmap.skipped = true` + `deferredReason`; jump to Step 17

- [ ] **Step 3: Insert Step 19 — Schema & API Draft Review**

After Step 18 (pluginInstall, renumbered from 17 in Task 15), add a new `## Step 19: Schema & API Draft Review (schemaDraftReview)` section. Mechanics:
- Walks SDR.Q1 → SDR.Q2
- **AUTO-RENDER hook** (system action between Q2 and Q3): invoke `bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh" "$STATE_FILE"`. On non-zero exit: surface stderr to user, set `state.lastError`, halt before Q3 with retry/skip prompt.
- Walks SDR.Q3-Q8 per draft (skip if `drafts.{X}.skipped = true`)
- Walks SDR.Q9-Q12
- Lock-gate enforcement: SDR.Q10 blocked unless every enabled draft `.approved = true` AND every `level=error` warning `.addressed = true`.
- After lock: invoke `synthesis-review` with template `schema-draft-review`

Reference the script via the canonical form per `.claude/rules/plugin-script-paths.md`: always `${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh`.

- [ ] **Step 4: Verify the auto-render hook reference uses canonical path form**

Run: `grep -E 'render-schema-drafts' greenfield/skills/context-gathering/SKILL.md`

Expected: every reference uses `"${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh"`. No bare `scripts/...` or absolute paths.

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "feat(greenfield): R5 — wire Step 16 (featureRoadmap) + Step 19 (schemaDraftReview) into context-gathering state machine"
```

---

### Task 15: Renumber existing wizard steps 17→20 + update progress indicator

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Renumber pluginRecommendation 16 → 17**

Find/replace in `context-gathering/SKILL.md`:
- `## Step 16: Plugin Recommendation` → `## Step 17: Plugin Recommendation`
- `Step 16 of 17` → `Step 17 of 20`
- All cross-refs to "Step 16" that refer to plugin discovery → "Step 17"

- [ ] **Step 2: Renumber pluginInstall 17 → 18**

- `## Step 17: Plugin Install` → `## Step 18: Plugin Install`
- `Step 17 of 17` → `Step 18 of 20`

- [ ] **Step 3: Renumber handoff 18 → 20**

(P10.5 occupies Step 19.) Renumber the final handoff step to `Step 20 of 20`.

- [ ] **Step 4: Update every "Step X of 17" → "Step X of 20"**

Run: `grep -n "Step .* of 17" greenfield/skills/context-gathering/SKILL.md`

Update each occurrence to `Step X of 20`.

- [ ] **Step 5: Update intra-skill cross-references**

If `synthesis-review/SKILL.md`, `pickup/SKILL.md`, `check/SKILL.md` reference step numbers — leave those for their respective tasks (T16/T17/T18 handle them). Just fix within context-gathering for now.

- [ ] **Step 6: Verify**

```bash
grep -E "Step 1[6-9]|Step 20" greenfield/skills/context-gathering/SKILL.md
```

Expected: Step 16 = Feature Roadmap, Step 17 = Plugin Recommendation, Step 18 = Plugin Install, Step 19 = Schema & API Draft Review, Step 20 = Handoff.

- [ ] **Step 7: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "refactor(greenfield): R5 — renumber wizard steps 17→20 (P10.5 at 19; handoff at 20)"
```

---

### Task 16: Update `synthesis-review/SKILL.md` — index 2 new templates

**Files:**
- Modify: `greenfield/skills/synthesis-review/SKILL.md`

- [ ] **Step 1: Find the template index**

Run: `grep -n "templates/" greenfield/skills/synthesis-review/SKILL.md | head -20`

Locate the per-phase template index table (most likely under a `## Templates` or `## Per-phase index` section).

- [ ] **Step 2: Add 2 rows**

| Phase key | Template HTML | MD companion | Dependencies example |
|---|---|---|---|
| `featureRoadmap` | `templates/feature-roadmap.html` | `templates/feature-roadmap.md` | `templates/feature-roadmap-dependencies.json.example` |
| `schemaDraftReview` | `templates/schema-draft-review.html` | `templates/schema-draft-review.md` | `templates/schema-draft-review-dependencies.json.example` |

- [ ] **Step 3: If a `## Step N: Per-phase render` table lists wizard step numbers, add entries**

| Step | Phase | Template |
|---|---|---|
| 16 | featureRoadmap | `feature-roadmap` |
| 19 | schemaDraftReview | `schema-draft-review` |

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/synthesis-review/SKILL.md
git commit -m "feat(greenfield): R5 — index feature-roadmap + schema-draft-review templates in synthesis-review"
```

---

### Task 17: Add alpha.5 → alpha.6 migration shim + Adjust-mode jump-links in `pickup/SKILL.md`

**Files:**
- Modify: `greenfield/skills/pickup/SKILL.md`

- [ ] **Step 1: Find existing migration shim (alpha.4 → alpha.5)**

Run: `grep -n "alpha.5\|alpha.4\|schemaVersion" greenfield/skills/pickup/SKILL.md`

Locate the R4 migration block — Task 17 mirrors it for R5.

- [ ] **Step 2: Add the alpha.5 → alpha.6 shim**

Insert a new step (or extend the existing migration logic block) with:

```markdown
### Migration: alpha.5 → alpha.6

If `state.meta.schemaVersion` is less than `"3.0.0-alpha.6"`:

1. If `phases.featureRoadmap` is absent, inject:
   ```json
   { "skipped": true, "deferredReason": "session predates Round 5" }
   ```
2. If `phases.schemaDraftReview` is absent, inject the same shape.
3. Set `state.meta.schemaVersion = "3.0.0-alpha.6"`.
4. Atomic write via `.tmp + rename`.
5. Surface to user:
   > "Session migrated to alpha.6. Steps 16 (Feature Roadmap) and 19 (Schema Draft Review) are now available via Adjust mode — re-enter them to populate these phases."
```

- [ ] **Step 3: Add Adjust-mode jump-links from P10.5 Reject branch**

Find the existing "Adjust mode" section. Add:

```markdown
### Adjust-mode jump-links from P10.5 Reject

When SDR.Q3/Q5/Q7 Reject branch fires, the wizard shows:
> "The {db|api|event} part of this draft came from {phase}. Re-enter that phase via Adjust mode? (`/greenfield:pickup` → step <N>)"

Mapping:
- DB Reject → domainModel (Step 2.7) or privacy (Step 6) — pickup prompts which.
- API Reject → apiIntegration (Step 4) or auth (Step 5) — pickup prompts which.
- Event Reject → domainModel (Step 2.7) — domain events live there.

After upstream phase is re-answered, return to Step 19 and re-run AUTO-RENDER.
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/pickup/SKILL.md
git commit -m "feat(greenfield): R5 — pickup alpha.5→alpha.6 migration shim + P10.5 Adjust-mode jump-links"
```

---

### Task 18: Add 3 new health-check assertions to `check/SKILL.md`

**Files:**
- Modify: `greenfield/skills/check/SKILL.md`

- [ ] **Step 1: Find existing check assertions**

Run: `grep -n "^## \|assertion\|completeness" greenfield/skills/check/SKILL.md | head -20`

Locate the check-list section.

- [ ] **Step 2: Add 3 new assertions**

```markdown
### Check R5-1: featureRoadmap completeness (when not skipped)

If `phases.featureRoadmap.skipped != true`:
- `phases.featureRoadmap.horizon` must be set
- `phases.featureRoadmap.features[]` must be non-empty
- `phases.featureRoadmap.sprint1.featureIds[]` must be non-empty
- `phases.featureRoadmap.sprint1.criteria[]` must include at least one entry with `weight = required`

Failure mode: report missing fields; do not block (advisory).

### Check R5-2: schemaDraftReview lockedAt presence (when not skipped)

If `phases.schemaDraftReview.skipped != true`:
- `phases.schemaDraftReview.lockedAt` must be set (ISO-8601 timestamp)
- For every enabled draft (`drafts.X.skipped != true`), `drafts.X.approved` must be `true`

Failure mode: report unlocked phase; advise running `/greenfield:pickup` to Step 19.

### Check R5-3: sprint-1 contract presence (post-R5 projects)

If `docs/sprint-contracts/` exists, verify `docs/sprint-contracts/sprint-1.json` exists and parses as JSON.

Failure mode: report missing file; advise re-running tooling generation.
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/check/SKILL.md
git commit -m "feat(greenfield): R5 — add 3 new health checks (featureRoadmap, schemaDraftReview, sprint-1 contract)"
```

---

### Task 19: Update `tooling-generation/SKILL.md` — pass new phase blocks to onboard

**Files:**
- Modify: `greenfield/skills/tooling-generation/SKILL.md`

- [ ] **Step 1: Find the existing pass-through**

Run: `grep -n "personas\|domainModel\|phases\." greenfield/skills/tooling-generation/SKILL.md`

Locate where R4 phases are passed to `onboard:generate`.

- [ ] **Step 2: Add featureRoadmap + schemaDraftReview to the pass-through**

Add the two new phase keys alongside `personas`, `domainModel`, etc. in the context-construction step. If there's a list of phase keys forwarded to onboard, append `featureRoadmap` and `schemaDraftReview`.

If the SKILL.md documents a per-phase forwarding section, add:

```markdown
### featureRoadmap

Forwarded to onboard generation. Onboard reads:
- `phases.featureRoadmap.features[]` → writes `docs/feature-list.json`
- `phases.featureRoadmap.sprint1` → writes `docs/sprint-contracts/sprint-1.json`

If `phases.featureRoadmap.skipped = true`, onboard falls back to interactive handoff (preserves alpha.5 behavior).

### schemaDraftReview

Forwarded to onboard generation. Onboard reads `drafts.{db,api,event}.content` (when `lockedAt` set + `approved=true`) and writes verbatim to canonical paths per `outputStrategy`:
- `prisma/schema.prisma` or `sql/migrations/0001_init.sql`
- `docs/api/openapi.yaml` or `schema.graphql`
- `docs/events/event-schemas.yaml` or `.json`

`outputStrategy = "docs-drafts"` writes all three under `docs/drafts/` for manual placement.
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/tooling-generation/SKILL.md
git commit -m "feat(greenfield): R5 — pass featureRoadmap + schemaDraftReview to onboard generation"
```

---

### Task 20: Update `start/SKILL.md` — bump step counter

**Files:**
- Modify: `greenfield/skills/start/SKILL.md`

- [ ] **Step 1: Find the step counter references**

Run: `grep -n "Step .* of \|17 wizard steps\|15 steps\|20 steps" greenfield/skills/start/SKILL.md`

- [ ] **Step 2: Update to 20**

Replace `17 wizard steps` / `17 steps` → `20 wizard steps`. No functional change — Round 4 mode toggles (depth/coupling/domainFormat) cover R5; no new toggles needed.

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/start/SKILL.md
git commit -m "chore(greenfield): R5 — bump start skill wizard step count to 20"
```

---

## Phase F — Cross-phase invariants

### Task 21: Author CHECK-R5-1 through CHECK-R5-6 + wire grill-spec + question-bank reference

**Files:**
- Create: `greenfield/skills/grill-spec/references/check-r5-invariants.md`
- Modify: `greenfield/skills/grill-spec/SKILL.md`
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Author `check-r5-invariants.md`**

Mirror the R4 file structure at `greenfield/skills/grill-spec/references/check-r4-invariants.md`. One section per invariant, header per spec § "Cross-phase invariants" (lines 511-520). Each section has: ID heading, Invariant statement, Severity, Phases involved, Detection logic (in pseudo-code / jq expression), and Failure prompt.

Full content (6 invariants):

```markdown
# Round 5 Cross-Phase Invariants

> **Wired into:** `grill-spec/SKILL.md` (5-category adversarial walk)
> **Severity legend:** `error` = blocks scaffold; `warn` = surfaces in grill-spec output, user can override

## CHECK-R5-1: Roadmap referential integrity

**Invariant:** All `featureRoadmap.features[].personaIds[]` resolve to existing `personas.primary[].id` ∪ `personas.secondary[].id`; all `entityIds[]` resolve to `domainModel.entities[].id`; all `riskIds[]` resolve to `risks[].id`.

**Severity:** error
**Phases involved:** featureRoadmap × personas × domainModel × risks

**Detection (jq):**
\`\`\`
jq -e '
  (.phases.personas.primary + (.phases.personas.secondary // [])) as $p
  | [$p[].id] as $pids
  | [.phases.domainModel.entities[].id // empty] as $eids
  | [.risks[].id // empty] as $rids
  | [.phases.featureRoadmap.features[] |
      ((.personaIds // [])[] | select(. as $x | $pids | index($x) | not)) //
      ((.entityIds // [])[] | select(. as $x | $eids | index($x) | not)) //
      ((.riskIds // [])[] | select(. as $x | $rids | index($x) | not))
    ] | length == 0
'
\`\`\`

**Failure prompt:** "Feature {feature.id} references {personaId/entityId/riskId} which does not exist. Fix the reference or remove."

## CHECK-R5-2: Sprint/epic referential integrity

**Invariant:** All `featureRoadmap.sprint1.featureIds[]` resolve to `featureRoadmap.features[].id`; all `features[].epicId` (when set) resolves to `epics[].id`; epic IDs unique.

**Severity:** error
**Phases:** featureRoadmap (intra-phase)

**Detection:** unique epics + sprint-1 featureIds subset of features[].id.

## CHECK-R5-3: P10.5 applicableArtifacts consistent with upstream

**Invariant:**
- `applicableArtifacts` includes `db` ⇔ `dataArchitecture.engine != "none"`
- `applicableArtifacts` includes `api` ⇔ `apiIntegration.endpoints[]` non-empty OR `asyncPattern != "none"`
- `applicableArtifacts` includes `event` ⇔ `domainModel.domainEvents[]` non-empty

**Severity:** warn
**Phases:** schemaDraftReview × dataArchitecture × apiIntegration × domainModel

## CHECK-R5-4: P10.5 lock gate

**Invariant:** When `schemaDraftReview.lockedAt` is set, every enabled draft has `approved=true` AND every `level=error` warning has `addressed=true`.

**Severity:** error
**Phases:** schemaDraftReview (intra-phase)

## CHECK-R5-5: P9 sizing consistency

**Invariant:** `featureRoadmap.sizingScale` consistent with feature `size` field. `tshirt` requires S/M/L/XL on every feature; `none` requires no `size`; `fibonacci`/`hours` require numeric.

**Severity:** warn
**Phases:** featureRoadmap (intra-phase)

## CHECK-R5-6: P9 render budget

**Invariant:** `featureRoadmap.features[].length` ≤ 100.

**Severity:** warn — surfaces "consolidate features" prompt if breached
**Phases:** featureRoadmap (intra-phase)
```

- [ ] **Step 2: Wire into `grill-spec/SKILL.md`**

Run: `grep -n "check-r4-invariants\|CHECK-R" greenfield/skills/grill-spec/SKILL.md`

Locate where R4 invariants are referenced. Add similarly:

```markdown
- **Round 5 invariants:** `references/check-r5-invariants.md` — CHECK-R5-1 through CHECK-R5-6
```

In the appropriate adversarial-walk category (roadmap-integrity / schema-coherence).

- [ ] **Step 3: Add R5 flag-reference note to `question-bank.md`**

Round 5 doesn't introduce new flags (reuses `loopOver`, `loopMode`, `showInLight`, `isRiskCapture`). Add a one-line appendix note:

```markdown
## Round 5 reference

Round 5 phases (featureRoadmap, schemaDraftReview) reuse existing Q-bank flags from Rounds 2.5–4: `showInLight`, `loopOver`, `loopMode`, `isRiskCapture`. No new flags introduced. See `feature-roadmap.q-bank.md` and `schema-draft-review.q-bank.md` for specifics.
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/grill-spec/references/check-r5-invariants.md \
        greenfield/skills/grill-spec/SKILL.md \
        greenfield/skills/context-gathering/references/question-bank.md
git commit -m "feat(greenfield): R5 — CHECK-R5-1..6 invariants + grill-spec wiring + question-bank reference"
```

---

## Phase G — Onboard generation

### Task 22: `generation/SKILL.md` — featureRoadmap → feature-list.json + sprint-1.json

**Files:**
- Modify: `onboard/skills/generation/SKILL.md`

- [ ] **Step 1: Find where feature-list.json is currently produced**

Run: `grep -n "feature-list.json\|sprint-1\|sprint-contracts" onboard/skills/generation/SKILL.md`

The existing behavior is interactive — onboard prompts during handoff. R5 makes it deterministic.

- [ ] **Step 2: Add deterministic-mode block**

Insert before the existing interactive fallback:

```markdown
### Round 5 — feature-list.json + sprint-1.json (deterministic)

If `context.phases.featureRoadmap.skipped != true` AND `context.phases.featureRoadmap.features[]` non-empty:

1. **Generate `docs/feature-list.json`:**

   Direct field-by-field map from `phases.featureRoadmap.features[]`:
   \`\`\`json
   {
     "schemaVersion": 1,
     "generatedAt": "<ISO8601>",
     "features": [
       {
         "id": "<features[].id>",
         "title": "<features[].title>",
         "category": "<features[].category>",
         "epicId": "<features[].epicId>",
         "personaIds": "<features[].personaIds>",
         "entityIds": "<features[].entityIds>",
         "riskIds": "<features[].riskIds>",
         "size": "<features[].size>",
         "acceptanceCriteria": "<features[].acceptanceCriteria>",
         "verificationSteps": "<features[].verificationSteps>",
         "sprintAssignment": "<features[].sprintAssignment>"
       }
     ],
     "epics": "<phases.featureRoadmap.epics[]>"
   }
   \`\`\`

2. **Generate `docs/sprint-contracts/sprint-1.json`:**

   \`\`\`json
   {
     "sprint": 1,
     "name": "<phases.featureRoadmap.sprint1.name>",
     "negotiatedAt": "<ISO8601 — generation timestamp>",
     "features": "<phases.featureRoadmap.sprint1.featureIds>",
     "criteria": "<phases.featureRoadmap.sprint1.criteria>",
     "completionGate": "<phases.featureRoadmap.sprint1.completionGate>"
   }
   \`\`\`

If `featureRoadmap.skipped = true` OR `features[]` empty → fall back to the existing interactive handoff flow below (alpha.5 backward-compat).

**Sprint-2..N contracts:** unchanged from pre-R5 — interactively negotiated at sprint boundaries per `references/sprint-contracts.md`.
```

- [ ] **Step 3: Commit**

```bash
git add onboard/skills/generation/SKILL.md
git commit -m "feat(onboard): R5 — deterministic feature-list.json + sprint-1.json from phases.featureRoadmap"
```

---

### Task 23: `generation/SKILL.md` — schemaDraftReview.drafts → schema/contract files

**Files:**
- Modify: `onboard/skills/generation/SKILL.md`

- [ ] **Step 1: Add the deterministic-output block**

Append to the same SKILL.md (or in a sibling subsection):

```markdown
### Round 5 — schema/contract files (deterministic)

If `context.phases.schemaDraftReview.skipped != true` AND `context.phases.schemaDraftReview.lockedAt` is set:

For each artifact in `["db", "api", "event"]`:
- if `drafts.{artifact}.approved = true` AND `drafts.{artifact}.skipped != true`:
  - resolve output path from `phases.schemaDraftReview.languages.{artifact}` AND `outputStrategy`:

  | artifact | language | outputStrategy=project-root | outputStrategy=docs-drafts |
  |---|---|---|---|
  | db | prisma | `prisma/schema.prisma` | `docs/drafts/schema.prisma` |
  | db | sql-ddl | `sql/migrations/0001_init.sql` | `docs/drafts/schema.sql` |
  | api | openapi-3.0 | `docs/api/openapi.yaml` | `docs/drafts/openapi.yaml` |
  | api | graphql-sdl | `schema.graphql` | `docs/drafts/schema.graphql` |
  | event | asyncapi | `docs/events/event-schemas.yaml` | `docs/drafts/event-schemas.yaml` |
  | event | json-schema | `docs/events/event-schemas.json` | `docs/drafts/event-schemas.json` |

  - write `drafts.{artifact}.content` **verbatim** to the resolved path. No transformation.
  - mkdir -p the parent directory if absent.

If `schemaDraftReview.skipped = true` OR `lockedAt` absent → do nothing (no fallback flow; pre-R5 projects don't ship these files).
```

- [ ] **Step 2: Commit**

```bash
git add onboard/skills/generation/SKILL.md
git commit -m "feat(onboard): R5 — deterministic schema/contract file writes from phases.schemaDraftReview"
```

---

### Task 24: Add one-line clarification to `sprint-contracts.md`

**Files:**
- Modify: `onboard/skills/generation/references/sprint-contracts.md`

- [ ] **Step 1: Find the existing "first sprint contract" text**

Run: `grep -n "sprint-1\|first sprint\|Phase 3 of Greenfield" onboard/skills/generation/references/sprint-contracts.md`

- [ ] **Step 2: Insert the clarification**

Near the top, after the intro paragraph:

```markdown
> **From R5 (greenfield@3.0.0-alpha.6) onward:** sprint-1 is generated **deterministically** from `phases.featureRoadmap.sprint1`. The interactive negotiation flow described below applies to **sprint-2..N at sprint boundaries**, not to sprint-1.
```

- [ ] **Step 3: Commit**

```bash
git add onboard/skills/generation/references/sprint-contracts.md
git commit -m "docs(onboard): R5 — clarify sprint-1 is deterministic from R5; flow below is sprint-2..N"
```

---

## Phase H — Tests

### Task 25: Author `feature-roadmap-fixture.json` + `feature-roadmap-smoke.sh`

**Files:**
- Create: `tests/round-5/feature-roadmap-fixture.json`
- Create: `tests/round-5/feature-roadmap-smoke.sh`

- [ ] **Step 1: Confirm tests directory exists**

Run: `ls tests/round-4/ 2>&1 | head -10` — confirm R4 left a `tests/round-4/` directory. If `tests/` exists but `tests/round-5/` doesn't: `mkdir -p tests/round-5`.

- [ ] **Step 2: Author the fixture**

`tests/round-5/feature-roadmap-fixture.json` — minimal valid alpha.6 state with:
- 2 primary personas (P1, P2)
- 2 entities (E_user, E_audit)
- 1 risk (R-DA-1)
- 5 features (F001-F005) — mix of persona-tagged + cross-cutting, mix of sizes
- 1 epic (E1)
- sprint-1 with 3 featureIds + 3 criteria (functional/quality/testing all required)

```json
{
  "meta": { "schemaVersion": "3.0.0-alpha.6" },
  "mode": { "depth": "heavy", "coupling": "auto-loop", "domainFormat": "ddd-lite" },
  "phases": {
    "personas": { "primary": [{"id":"P1","name":"Sara"},{"id":"P2","name":"Carl"}] },
    "domainModel": {
      "entities": [
        {"id":"E_user","name":"User","isAggregateRoot":true,"primaryKey":"id","attributes":[{"name":"email","type":"string"}]},
        {"id":"E_audit","name":"Audit","isAggregateRoot":true,"primaryKey":"id","attributes":[{"name":"action","type":"string"}]}
      ]
    },
    "featureRoadmap": {
      "horizon": "3-months",
      "mvpBoundary": "Authenticated user CRUD + audit log only.",
      "sizingScale": "tshirt",
      "epics": [{"id":"E1","title":"Identity Core"}],
      "features": [
        {"id":"F001","title":"User signup","category":"api","epicId":"E1","personaIds":["P1"],"entityIds":["E_user"],"riskIds":["R-DA-1"],"size":"M","acceptanceCriteria":["Email valid"],"verificationSteps":["POST /signup returns 201"],"sprintAssignment":1},
        {"id":"F002","title":"User login","category":"api","epicId":"E1","personaIds":["P1"],"entityIds":["E_user"],"riskIds":[],"size":"S","acceptanceCriteria":["JWT issued"],"verificationSteps":["POST /login returns 200 + token"],"sprintAssignment":1},
        {"id":"F003","title":"Audit log view","category":"ui","epicId":null,"personaIds":["P2"],"entityIds":["E_audit"],"riskIds":[],"size":"L","acceptanceCriteria":["Filterable"],"verificationSteps":["GET /audits returns 200"],"sprintAssignment":1},
        {"id":"F004","title":"Admin dashboard","category":"ui","epicId":null,"personaIds":[],"entityIds":[],"riskIds":[],"size":"L","acceptanceCriteria":[],"verificationSteps":[],"sprintAssignment":null},
        {"id":"F005","title":"Observability hooks","category":"ops","epicId":null,"personaIds":[],"entityIds":[],"riskIds":[],"size":"M","acceptanceCriteria":[],"verificationSteps":[],"sprintAssignment":null}
      ],
      "sprint1": {
        "name": "Sprint 1 — Identity Core MVP",
        "featureIds": ["F001","F002","F003"],
        "criteria": [
          {"name":"functional","weight":"required","description":"All sprint features pass acceptance","threshold":"100%"},
          {"name":"quality","weight":"required","description":"No P1 bugs","threshold":"0 P1"},
          {"name":"testing","weight":"required","description":"Verification steps automated","threshold":"100% scripted"}
        ],
        "completionGate": "ALL required criteria must pass"
      },
      "skipped": false,
      "deferredReason": ""
    }
  },
  "risks": [{"id":"R-DA-1","title":"Schema migration risk","originatingPhase":"dataArchitecture"}]
}
```

- [ ] **Step 3: Author the smoke script**

`tests/round-5/feature-roadmap-smoke.sh`:

```bash
#!/usr/bin/env bash
# feature-roadmap-smoke.sh — verifies onboard generation reads the fixture and would
# emit a valid feature-list.json + sprint-1.json field-for-field.
# This is a structural smoke test (no actual onboard invocation) — it asserts the
# fixture itself is internally consistent and that all required fields are present.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/feature-roadmap-fixture.json"
FAIL=0

check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then echo "✓ $name"; else echo "✗ $name"; FAIL=1; fi; }

check "fixture parses as JSON" jq empty "$FIXTURE"
check "schemaVersion is alpha.6" jq -e '.meta.schemaVersion == "3.0.0-alpha.6"' "$FIXTURE"
check "5 features present" jq -e '.phases.featureRoadmap.features | length == 5' "$FIXTURE"
check "feature IDs zero-padded F001-F005" jq -e '[.phases.featureRoadmap.features[].id] == ["F001","F002","F003","F004","F005"]' "$FIXTURE"
check "sprint1 has 3 features" jq -e '.phases.featureRoadmap.sprint1.featureIds | length == 3' "$FIXTURE"
check "sprint1 featureIds subset of features[].id" jq -e '. as $r | [$r.phases.featureRoadmap.sprint1.featureIds[]] | all(. as $f | $r.phases.featureRoadmap.features | any(.id == $f))' "$FIXTURE"
check "all personaIds resolve" jq -e '. as $r | $r.phases.featureRoadmap.features | map(.personaIds // []) | add | unique | all(. as $p | $r.phases.personas.primary | any(.id == $p))' "$FIXTURE"
check "all entityIds resolve" jq -e '. as $r | $r.phases.featureRoadmap.features | map(.entityIds // []) | add | unique | all(. as $e | $r.phases.domainModel.entities | any(.id == $e))' "$FIXTURE"
check "all riskIds resolve" jq -e '. as $r | $r.phases.featureRoadmap.features | map(.riskIds // []) | add | unique | all(. as $i | $r.risks | any(.id == $i))' "$FIXTURE"
check "sprint1 criteria has functional+quality+testing as required" jq -e '[.phases.featureRoadmap.sprint1.criteria[] | select(.weight == "required") | .name] | sort == ["functional","quality","testing"]' "$FIXTURE"

exit $FAIL
```

- [ ] **Step 4: chmod + run**

```bash
chmod +x tests/round-5/feature-roadmap-smoke.sh
shellcheck tests/round-5/feature-roadmap-smoke.sh
tests/round-5/feature-roadmap-smoke.sh
```

Expected: 10 ✓ lines, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/round-5/feature-roadmap-fixture.json tests/round-5/feature-roadmap-smoke.sh
git commit -m "test(greenfield): R5 — feature-roadmap fixture + smoke script (10 structural checks)"
```

---

### Task 26: Author `migration-alpha5-fixture.json` + `migration-test.sh`

**Files:**
- Create: `tests/round-5/migration-alpha5-fixture.json`
- Create: `tests/round-5/migration-test.sh`

- [ ] **Step 1: Author the fixture (alpha.5 state)**

`tests/round-5/migration-alpha5-fixture.json` — minimal valid alpha.5 state WITHOUT featureRoadmap or schemaDraftReview blocks:

```json
{
  "meta": { "schemaVersion": "3.0.0-alpha.5" },
  "mode": { "depth": "heavy", "coupling": "auto-loop", "domainFormat": "ddd-lite" },
  "phases": {
    "personas": { "primary": [{"id":"P1","name":"Sara"}] },
    "domainModel": { "entities": [] },
    "architecturalFraming": { "topology": "monolith" }
  },
  "risks": []
}
```

- [ ] **Step 2: Author the migration test script**

`tests/round-5/migration-test.sh` — simulates the pickup-shim migration logic in-script (since pickup is a SKILL.md not a CLI):

```bash
#!/usr/bin/env bash
# migration-test.sh — applies the alpha.5 → alpha.6 pickup shim logic to the
# fixture and asserts the 8 required invariants.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/migration-alpha5-fixture.json"
TMP=$(mktemp)
FAIL=0

# Apply the shim inline (mirrors pickup/SKILL.md logic for Task 17)
jq '
  if .meta.schemaVersion < "3.0.0-alpha.6" then
    (if .phases.featureRoadmap == null then .phases.featureRoadmap = {skipped: true, deferredReason: "session predates Round 5"} else . end)
    | (if .phases.schemaDraftReview == null then .phases.schemaDraftReview = {skipped: true, deferredReason: "session predates Round 5"} else . end)
    | .meta.schemaVersion = "3.0.0-alpha.6"
  else . end
' "$FIXTURE" > "$TMP"

check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then echo "✓ $name"; else echo "✗ $name"; FAIL=1; fi; }

check "migrated JSON parses" jq empty "$TMP"
check "schemaVersion bumped to alpha.6" jq -e '.meta.schemaVersion == "3.0.0-alpha.6"' "$TMP"
check "featureRoadmap.skipped = true" jq -e '.phases.featureRoadmap.skipped == true' "$TMP"
check "schemaDraftReview.skipped = true" jq -e '.phases.schemaDraftReview.skipped == true' "$TMP"
check "featureRoadmap has deferredReason" jq -e '.phases.featureRoadmap.deferredReason | startswith("session predates")' "$TMP"
check "no field collisions with alpha.5 (personas preserved)" jq -e '.phases.personas.primary[0].name == "Sara"' "$TMP"
check "mode block preserved" jq -e '.mode.coupling == "auto-loop"' "$TMP"
check "risks[] preserved" jq -e '.risks | type == "array"' "$TMP"

rm -f "$TMP"
exit $FAIL
```

- [ ] **Step 3: chmod + run**

```bash
chmod +x tests/round-5/migration-test.sh
shellcheck tests/round-5/migration-test.sh
tests/round-5/migration-test.sh
```

Expected: 8 ✓ lines, exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/round-5/migration-alpha5-fixture.json tests/round-5/migration-test.sh
git commit -m "test(greenfield): R5 — alpha.5→alpha.6 migration fixture + test (8 invariant checks)"
```

---

## Phase I — Docs + bookkeeping

### Task 27: Companion docs — overview, migration-notes, coupling-matrix

**Files:**
- Create: `docs/greenfield-3.0-round5/overview.md`
- Create: `docs/greenfield-3.0-round5/migration-notes.md`
- Create: `docs/greenfield-3.0-round5/coupling-matrix.md`

- [ ] **Step 1: Check R4 companion docs for style**

Run: `ls docs/greenfield-3.0-round4/ && head -30 docs/greenfield-3.0-round4/overview.md`

Mirror format.

- [ ] **Step 2: Author `overview.md`**

Sections: Summary, Scope (in/out), Locked decisions table, Brainstorm-to-merge narrative, Commit log placeholder (`<filled-by-final-task>`).

- [ ] **Step 3: Author `migration-notes.md`**

User-facing alpha.5 → alpha.6 notes:
- What's new (Steps 16 + 19; auto-render mechanic)
- How to migrate in-flight sessions (`/greenfield:pickup` auto-applies the shim)
- Rollback path (3-tier — verbatim from spec § Rollback path)
- Breaking changes: **none** (purely additive)

- [ ] **Step 4: Author `coupling-matrix.md`**

Extends R4 coupling matrix at `docs/greenfield-3.0-round4/coupling-matrix.md` with 2 new rows:

| Phase | Reads from | Writes to | Auto-loop |
|---|---|---|---|
| featureRoadmap | personas.primary, domainModel.entities, risks | featureRoadmap.* + downstream docs/feature-list.json + sprint-1.json | per primary persona (FR.Q4-Q9 in `auto-loop` mode) |
| schemaDraftReview | domainModel, auth, privacy, apiIntegration | schemaDraftReview.drafts.{db,api,event} + canonical schema/contract files | per draft artifact (DB / API / Event) |

- [ ] **Step 5: Commit**

```bash
git add docs/greenfield-3.0-round5/
git commit -m "docs(greenfield-3.0): Round 5 companion docs — overview, migration-notes, coupling-matrix"
```

---

### Task 28: Update `greenfield/CLAUDE.md` + `onboard/CLAUDE.md`

**Files:**
- Modify: `greenfield/CLAUDE.md`
- Modify: `onboard/CLAUDE.md`

- [ ] **Step 1: Update greenfield/CLAUDE.md architecture diagram**

In the ASCII flow block, add:
- `Step 16: Feature Roadmap (featureRoadmap phase — Round 5 insert; 14 Qs heavy / 7 light + per-persona auto-loop)`
- `Step 19: Schema & API Draft Review (schemaDraftReview phase — Round 5 insert; 12 Qs + auto-render mid-flow)`

Update the synthesis-review list to include:
- `Step 16 → featureRoadmap`
- `Step 19 → schemaDraftReview`

- [ ] **Step 2: Update greenfield/CLAUDE.md Skill Hierarchy**

In the `context-gathering/SKILL.md` bullet that enumerates wizard steps, update count `17 → 20` and add:
- `Step 16 = Feature Roadmap / featureRoadmap (14 Qs heavy / 7 Qs light)`
- `Step 19 = Schema & API Draft Review / schemaDraftReview (12 Qs / 6 light + auto-render hook)`

Renumber `Step 16 (pluginRecommendation) → Step 17`, `Step 17 (pluginInstall) → Step 18`, `Step 18 (handoff) → Step 20`.

In `synthesis-review/SKILL.md` bullet, add `featureRoadmap.html/md, schema-draft-review.html/md` to template list.

- [ ] **Step 3: Update greenfield/CLAUDE.md Key Patterns**

Add: `Round 5 deterministic outputs:` paragraph explaining feature-list.json + sprint-1.json + schema/contract files are now produced deterministically rather than conversationally.

- [ ] **Step 4: Update onboard/CLAUDE.md — Round 5 phase additions block**

Find R4 block: `grep -n "Round 4" onboard/CLAUDE.md`

Add an analogous Round 5 block listing:
- `phases.featureRoadmap` → `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json`
- `phases.schemaDraftReview` → schema/contract files per `outputStrategy`

- [ ] **Step 5: Commit**

```bash
git add greenfield/CLAUDE.md onboard/CLAUDE.md
git commit -m "docs(greenfield+onboard): R5 — CLAUDE.md updates (20-step wizard, R5 phase additions block)"
```

---

### Task 29: Version bumps + marketplace + CHANGELOGs + Discussion Log

**Files:**
- Modify: `greenfield/.claude-plugin/plugin.json`
- Modify: `onboard/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `greenfield/CHANGELOG.md`
- Modify: `onboard/CHANGELOG-2.0.md`
- Modify: `docs/greenfield-overview.html`

- [ ] **Step 1: Bump versions**

```bash
jq '.version = "3.0.0-alpha.6"' greenfield/.claude-plugin/plugin.json > /tmp/g.json && mv /tmp/g.json greenfield/.claude-plugin/plugin.json
jq '.version = "2.0.0-alpha.6"' onboard/.claude-plugin/plugin.json > /tmp/o.json && mv /tmp/o.json onboard/.claude-plugin/plugin.json
```

- [ ] **Step 2: Update marketplace.json**

```bash
grep -n "alpha.5\|version" .claude-plugin/marketplace.json
```

Update both greenfield's and onboard's `version` field to `3.0.0-alpha.6` / `2.0.0-alpha.6` respectively.

- [ ] **Step 3: Add CHANGELOG entries**

`greenfield/CHANGELOG.md`:

```markdown
## 3.0.0-alpha.6 (2026-05-15) — Round 5

### Added
- Step 16 — Feature Roadmap phase (featureRoadmap): 14 Qs heavy / 7 light, per-persona auto-loop, deterministic `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` generation.
- Step 19 — Schema & API Draft Review phase (schemaDraftReview): 12 Qs, auto-renders DB/API/Event drafts from R3+R4 discovery via `scripts/render-schema-drafts.sh`, then user reviews/locks. Onboard writes locked drafts verbatim to canonical paths.
- 7 renderer scripts: `render-schema-drafts.sh` (entrypoint) + 6 per-language modules (Prisma, SQL DDL, OpenAPI 3.0, GraphQL SDL, AsyncAPI, JSON Schema).
- 6 cross-phase invariants (CHECK-R5-1 through CHECK-R5-6).
- Synthesis templates: `feature-roadmap.html/md`, `schema-draft-review.html/md` + dependencies examples.
- Smoke tests: `tests/round-5/feature-roadmap-smoke.sh`, `tests/round-5/migration-test.sh`.
- Pickup migration shim: alpha.5 → alpha.6 (auto-migrating, additive).

### Changed
- Wizard step count 17 → 20.
- `tooling-generation/SKILL.md` passes `phases.featureRoadmap` + `phases.schemaDraftReview` to onboard.

### Migration
- Auto-migrating via `/greenfield:pickup`. No manual action required.
- Sessions predating alpha.6 get `{skipped: true, deferredReason}` defaults on featureRoadmap + schemaDraftReview. Re-enter Steps 16/19 via Adjust mode to populate.

### Rollback
- Single revert commit on develop reverts the R5 PR. alpha.6 sessions calling alpha.5 pickup gracefully drop unknown R5 fields.
```

`onboard/CHANGELOG-2.0.md`:

```markdown
## 2.0.0-alpha.6 (2026-05-15) — Round 5 schema additions

### Added
- `context-shape-v2.json`: replaced `phases.featureRoadmap` + `phases.schemaDraftReview` deferred-stub placeholders with full schemas.
- `definitions.schemaDraft` for the drafts.{db,api,event} sub-shape.
- `generation/SKILL.md`: deterministic `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` generation when greenfield's `phases.featureRoadmap` is populated; verbatim schema/contract file writes from `phases.schemaDraftReview.drafts.{db,api,event}.content`.
- `generation/references/sprint-contracts.md`: clarification that from R5 onward sprint-1 is deterministic; the interactive flow described applies to sprint-2..N.

### Backward compatibility
- If `featureRoadmap.skipped = true` OR `features[]` empty → onboard falls back to interactive handoff (preserves alpha.5 behavior).
- If `schemaDraftReview.skipped = true` OR `lockedAt` absent → onboard writes no schema/contract files (preserves alpha.5 behavior).
```

- [ ] **Step 4: Add Discussion Log entry to `docs/greenfield-overview.html`**

Find the Discussion Log section (`grep -n "ROUND 4 LOCKED\|Discussion Log" docs/greenfield-overview.html`). Add a `ROUND 5 LOCKED` entry mirroring the R4 entry's format:

```html
<details>
  <summary><strong>2026-05-15 — ROUND 5 LOCKED</strong> (Feature Roadmap + Schema & API Draft Review)</summary>
  <p>Round 5 closes the loop between discovery (Rounds 1–4) and delivery artifacts. Two new top-level phases: Feature Roadmap (P9 at Step 16) and Schema & API Draft Review (P10.5 at Step 19). Wizard grows from 17 → 20 steps. Schema bumps alpha.5 → alpha.6 (auto-migrating). Bundled <code>feat/greenfield-1.4</code> branch, R3-style subagent dispatch (~30 tasks).</p>
</details>
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/.claude-plugin/plugin.json onboard/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        greenfield/CHANGELOG.md onboard/CHANGELOG-2.0.md \
        docs/greenfield-overview.html
git commit -m "chore(release): R5 — version bumps to alpha.6 + CHANGELOGs + Discussion Log entry"
```

---

## Phase J — Final

### Task 30: Validate sweep + smoke + branch finalization

**Files:**
- (none modified — verification + branch push)

- [ ] **Step 1: Run /validate**

In the Claude Code interface, invoke `/validate`. Expected: all 4 plugins pass (onboard, greenfield, notify, handoff).

If invoking from bash: ensure the validation skill's shellcheck + JSON validation passes:

```bash
# Manifest JSON valid
jq empty greenfield/.claude-plugin/plugin.json onboard/.claude-plugin/plugin.json .claude-plugin/marketplace.json

# Context shape valid
jq empty onboard/skills/generate/references/context-shape-v2.json

# All new renderer scripts ShellCheck-clean
shellcheck greenfield/scripts/render-*.sh
shellcheck tests/round-5/*.sh
```

Expected: all silent (exit 0).

- [ ] **Step 2: Re-run smoke tests**

```bash
tests/round-5/feature-roadmap-smoke.sh
tests/round-5/migration-test.sh
```

Expected: all ✓, exit 0.

- [ ] **Step 3: Verify file counts match estimate**

```bash
# Count new files in feature branch vs develop
git diff develop --name-status | grep '^A' | wc -l
# Expected: ~23 new files

git diff develop --name-status | grep '^M' | wc -l
# Expected: ~20 modified files
```

- [ ] **Step 4: Verify no leftover TODO / TBD / placeholder strings**

```bash
git diff develop -- greenfield/ onboard/ tests/round-5/ docs/greenfield-3.0-round5/ | grep -E 'TODO|TBD|FIXME|XXX|placeholder' | head -10
```

Expected: no output. If matches → fix and amend.

- [ ] **Step 5: Push branch + open PR**

```bash
git push -u origin feat/greenfield-1.4

gh pr create --title "feat(greenfield)!: 3.0.0-alpha.6 — Round 5 (Feature Roadmap + Schema/API Draft Review)" \
  --body "$(cat <<'EOF'
## Summary

Round 5 closes the loop between discovery (Rounds 1–4) and delivery artifacts. Two new top-level wizard phases:
- **Step 16 — Feature Roadmap (P9)**: 14 Qs heavy / 7 light + per-persona auto-loop; produces `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` deterministically.
- **Step 19 — Schema & API Draft Review (P10.5)**: 12 Qs; auto-renders DB/API/Event drafts from R3+R4 discovery via 7 new renderer scripts; user reviews/locks; onboard writes verbatim to canonical paths.

**Wizard step count:** 17 → 20.
**Schema bump:** `alpha.5 → alpha.6` (auto-migrating via pickup shim).
**Source spec:** `docs/superpowers/specs/2026-05-15-greenfield-3.0-round5-design.md`
**Plan:** `docs/superpowers/plans/2026-05-15-greenfield-3.0-round5-implementation.md`

## Test plan

- [ ] `/validate` passes on all 4 plugins
- [ ] `tests/round-5/feature-roadmap-smoke.sh` — 10 structural checks pass
- [ ] `tests/round-5/migration-test.sh` — 8 migration invariants pass
- [ ] Manual: trigger Step 16 in a fresh wizard run; verify feature-roadmap.html renders
- [ ] Manual: trigger Step 19 in a fresh wizard run; verify renderer dispatches per language; verify schema-draft-review.html renders
- [ ] Manual: verify CHECK-R5-1 through CHECK-R5-4 hard-fail when expected
- [ ] Manual: invoke `/greenfield:pickup` on an alpha.5 fixture; verify migration shim fires

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: Update memory + companion overview commit log**

After PR creation, update `~/.claude/projects/-Users-apurvbazari-Desktop-projects-claude-plugins/memory/project_greenfield_3_0_design.md` with R5 status + PR number.

Update `docs/greenfield-3.0-round5/overview.md` with the final commit log:

```bash
git log --oneline feat/greenfield-1.4 ^develop | head -40
```

Paste into the commit log placeholder, then amend the docs commit if needed.

---

## Self-Review Checklist

Run these before handing off to subagent dispatch:

**1. Spec coverage scan:**
- [ ] Each item in spec § In scope deliverables (20 items) maps to at least one task:
  - Items 1, 2 (Q-banks) → T3, T4
  - Item 3 (renderer entrypoint) → T5
  - Item 4 (cross-check warnings) → embedded in T6-T11
  - Item 5 (6 synthesis template files) → T12, T13
  - Item 6 (schema additions) → T1
  - Item 7 (dependencies-schema) → T2
  - Item 8 (onboard generation logic) → T22, T23
  - Item 9 (CHECK-R5-*) → T21
  - Item 10 (pickup migration shim) → T17
  - Item 11 (wizard renumbering) → T14, T15
  - Item 12 (health checks) → T18
  - Item 13 (smoke tests) → T25, T26
  - Item 14 (companion docs) → T27
  - Item 15 (CLAUDE.md updates) → T28
  - Item 16 (Q-bank flag reuse) → noted in T3, T4
  - Item 17 (sprint-contracts.md clarification) → T24
  - Item 18 (Discussion Log) → T29
  - Item 19 (CHANGELOG entries) → T29
  - Item 20 (version bumps) → T29

**2. Placeholder scan:**
- [ ] No "TBD" / "TODO" / "fill in later" in task bodies (Step 4 of T30 enforces)
- [ ] Every renderer script (T5-T11) has a concrete content block — Tasks 9/10/11 are slightly terser but pattern-clear from T6/T8

**3. Type consistency:**
- [ ] Schema property names (`phases.featureRoadmap.*`, `phases.schemaDraftReview.*`) match across T1, T3, T4, T22, T23
- [ ] Renderer envelope keys (`content`, `sourceRefs`, `crossCheckWarnings`) consistent across T5-T11
- [ ] Feature ID pattern `^F[0-9]{3}$` consistent across T1, T3, T22, T25
- [ ] Epic ID pattern `^E[0-9]+$` consistent across T1, T3, T25

**4. Mid-execution checkpoints documented:**
- [ ] Checkpoint 1 (after Phase A + C) — verifies schema + renderer contract
- [ ] Checkpoint 2 (after Phase D) — verifies template paths match Q-bank Stores-to

**5. Rollback path:** documented in T27 migration-notes.md + T29 CHANGELOG entries.

---

## Notes for executor

- **R3-style subagent dispatch:** dispatch one fresh subagent per task. After each task, review the commit before moving on. ~60-90 subagent invocations across 30 tasks (implementer + occasional review/fix).
- **Branch hygiene:** All work lands on `feat/greenfield-1.4` off `develop`. One commit per task. Squash on merge.
- **Renderer modules T9/T10/T11 are terser** than T6/T8 — they follow the same envelope contract and warning categories. If executing inline, extract the common envelope-emitting block into a shared helper after T11 (not required; just an optimization).
- **Schema additions are purely additive** — no breaking changes for alpha.5 consumers. The pickup shim (T17) lifts old state forward automatically.
- **Tests in `tests/round-5/`** are structural smoke (no actual onboard invocation). They verify the fixture state is internally consistent and the migration logic is deterministic. Manual end-to-end verification is in the PR test plan.
