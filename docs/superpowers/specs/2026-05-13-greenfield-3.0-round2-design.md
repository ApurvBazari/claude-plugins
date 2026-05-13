# Greenfield 3.0 Round 2 — P3/P4 Split Design

- **Branch:** `feat/greenfield-1.2`
- **Date:** 2026-05-13
- **Inherits from:** Round 1 (commits `52dd636`, `426e151`, `265262c`, `b0c21a7`); `project_greenfield_3_0_design.md` memory entry
- **Estimated files touched:** 18–20 across `greenfield/` and `onboard/`

## Summary

Split the existing greenfield 2.x "Project Details" wizard step (current Category 3, 18 questions) into two distinct 15-phase-aligned phases:

- **P3 Data Architecture** — 12 questions, 7 synthesis sections, 4 required schema fields
- **P4 API & Integration** — 10 questions, 6 synthesis sections, 3 required schema fields

Each new phase ends with an inline Phase 1.8 synthesis-review pass (already infrastructured in Round 1). The new shapes replace `_status: "deferred-to-round-2"` stubs in `onboard/skills/generate/references/context-shape-v2.json`. Asymmetric depth (P3 > P4) reflects that data covers more decision surface than API under "single-owner per topic" boundary.

## Scope

**In scope (Round 2 deliverables, per handoff):**

1. P3 + P4 wizard question banks in `greenfield/skills/context-gathering/references/question-bank.md`
2. P3 + P4 live schema fields in `onboard/skills/generate/references/context-shape-v2.json`
3. Per-phase synthesis HTML templates in `greenfield/skills/synthesis-review/references/templates/`
4. Phase-1.8 orchestrator wired to render P3 and P4 syntheses inline (no synthesis-review SKILL changes — already supports arbitrary `phaseId`)
5. Per-phase `dependencies.json.example` files showing backward dependency edges
6. Manual verification: wizard drive-through, synthesis HTML renders, `onboard:generate` accepts v2 context

**Out of scope (do NOT relitigate — locked Round 1 decisions):**

- 15-phase wizard structure
- Per-phase synthesis HTML pattern (8-section anatomy from `references/section-prompts.md`)
- Plugin lifecycle (P7.5 picks, P10 installs)
- Adaptive skipping mechanism
- Hard cutover migration policy (no v1→v2 helpers, no greenfield 2.x maintenance branch)
- Pre-commit freshness hook for `docs/architecture/`
- `onboard:generate` v1 rejection contract
- Non-GHA CI provider templates (Round 6)
- `mattpocock-skills` vendored plugin (separate concern)
- Other deferred phases (P0, P0.5, P1, P5, P6, P7, P8.5, P9, P10.5) — those are Rounds 3-6

## Locked design decisions (from this brainstorming session)

| # | Decision | Rationale |
|---|---|---|
| 1 | **Boundary: single-owner per topic.** File storage + codegen + caching → P3; real-time + webhooks + jobs → P4. Synthesis HTMLs cross-reference each other when needed. | Cleanest schema; no duplicated questions across phases; one source of truth per concern. |
| 2 | **Schema: hybrid strictness.** 3–5 required + enum-locked fields per phase (the ones other phases cross-reference); remaining fields loose strings with `"other"` escape hatch. | Data/API tooling landscape moves quarterly (unlike CI providers); closed enums for every tool would force monthly onboard releases. Keeps contradiction detection on the high-impact cross-phase fields. |
| 3 | **Dependency direction: backward-only.** P3/P4 declare only what they READ from earlier phases. Future phases (P5/P6/P7) will declare their backward deps on P3/P4 when those rounds land. | Matches Round 1 P8 precedent; avoids forward-anticipation files that bleed Round 6 work into Round 2 edits. |
| 4 | **Depth: asymmetric (P3 deeper than P4).** P3 = 12 Qs / 7 sections / 4 required. P4 = 10 Qs / 6 sections / 3 required. | P3 covers genuinely more concerns under single-owner (DB + ORM + migrations + multi-tenancy + search + caching + storage + codegen = 7–8). P4 = style + versioning + rate limits + real-time + webhooks + integrations = 5–6. Forcing symmetry would over-engineer P4. |
| 5 | **Wizard step count: 8 → 10.** Insert two new steps (P3 = Step 3, P4 = Step 4); existing Step 3 ("Project Details") becomes a residual Step 5 with 13 questions destined for later rounds. | Per locked decision #13, "Step X of N" wording bumps to "of 10" — full P-naming rename deferred until Round 6. |
| 6 | **Codegen Q3.16 lands in P3 only** (under single-owner). The question's option list includes both ORM codegen (Prisma, Drizzle generate, SQLC) AND API codegen (GraphQL codegen, OpenAPI TS, Protobuf). P4 synthesis renders a `<div class="note">See P3 §7</div>` cross-reference when the user picks GraphQL/Protobuf. | One source of truth; no duplicated codegen question. |

## Architecture & data flow

```
/greenfield:init
     │
     ▼
Phase 1: Context Gathering
     │
     ├── Step 1 of 10: Vision (P0)              ─── unchanged
     ├── Step 2 of 10: Stack (P2)               ─── unchanged
     │
     ├── Step 3 of 10: Data Architecture (P3)   ─── ★ NEW
     │       ├── Q3.1 (gate) → Q3.12
     │       └── synthesis-review(phaseId: "P3") ◄── inline
     │              ├── docs/architecture/p3-data.html rendered
     │              ├── Approve/Adjust/Skip per section
     │              └── context.syntheses.P3 = { approvedAt, adjustments[] }
     │
     ├── Step 4 of 10: API & Integration (P4)   ─── ★ NEW
     │       ├── Q4.1 (gate) → Q4.10
     │       └── synthesis-review(phaseId: "P4") ◄── inline
     │
     ├── Step 5 of 10: Remaining Project Details ─── residual (13 Qs)
     ├── Step 6 of 10: Workflow                 ─── renumbered from Step 4
     ├── Step 7 of 10: CI/CD (P8)               ─── renumbered from Step 5; unchanged logic
     ├── Step 8 of 10: Plugin Discovery         ─── renumbered from Step 6
     └── Step 9 of 10: Confirmation             ─── renumbered from Step 7

     ▼
Phase 1.7: grill-spec ─── now cross-checks context.syntheses.{P3, P4, P8}
     ▼
Phase 2: Scaffold ─── unchanged
     ▼
Phase 3: onboard:generate ─── accepts new P3/P4 shapes; emits NO new artifacts
                              (Round 2 is decisions-only; no template substitution)
```

## Phase P3 — Data Architecture

### Question bank (12 questions)

| ID | Topic | Type | Condition | Writes to `context.phases.P3.*` |
|---|---|---|---|---|
| P3.Q1 | Does this app need persistent data? | choice | always | gate — if `no`, skip Q2–Q7 |
| P3.Q2 | Database engine | open w/ recommendations | Q1=yes | `engine` (loose) |
| P3.Q3 | **Database hosting model** | choice | Q1=yes | `databaseHost` (required, enum) |
| P3.Q4 | **ORM / data access layer** | choice (stack-filtered) | Q1=yes | `orm` (required, enum) |
| P3.Q5 | **Migration tool & approach** | composite (choice + mode) | Q1=yes | `migrationsTool` (required, enum) + `migrationsMode` (loose) |
| P3.Q6 | **Multi-tenancy isolation** | choice | Q1=yes | `multiTenancy` (required, enum) |
| P3.Q7 | Search & retrieval strategy | choice | Q1=yes | `search` (loose) |
| P3.Q8 | Caching layer + invalidation | composite | always | `cache` + `cacheInvalidation` (loose) |
| P3.Q9 | File / object storage | choice | `hasBackend \|\| hasFrontend` | `fileStorage` (loose) |
| P3.Q10 | Codegen tools | multi-select | applicable to stack | `codegen[]` (loose) |
| P3.Q11 | Backup & retention | choice | Q1=yes && willDeploy | `backup` (loose) |
| P3.Q12 | Data residency / compliance | choice | always | `compliance` (loose) |

**Bold rows** = the 4 required schema fields with closed enums.

### Schema sketch

```jsonc
"P3": {
  "type": "object",
  "required": ["databaseHost", "orm", "migrationsTool", "multiTenancy"],
  "additionalProperties": false,
  "properties": {
    "databaseHost": {
      "enum": ["self-hosted", "managed-rdbms", "serverless-rdbms",
               "managed-nosql", "embedded", "none"]
    },
    "orm": {
      "enum": ["prisma", "drizzle", "typeorm", "sequelize", "kysely",
               "sqlalchemy", "active-record", "ecto", "gorm", "diesel",
               "raw-sql", "none", "other"]
    },
    "migrationsTool": {
      "enum": ["orm-native", "alembic", "flyway", "liquibase",
               "raw-sql", "none", "other"]
    },
    "multiTenancy": {
      "enum": ["none", "row-level-rls", "schema-per-tenant",
               "db-per-tenant", "shared-no-isolation"]
    },
    "engine":            { "type": "string" },
    "migrationsMode":    { "type": "string" },
    "search":            { "type": "string" },
    "cache":             { "type": "string" },
    "cacheInvalidation": { "type": "string" },
    "fileStorage":       { "type": "string" },
    "codegen":           { "type": "array", "items": { "type": "string" } },
    "backup":            { "type": "string" },
    "compliance":        { "type": "string" }
  }
}
```

**Rationale for the 4 required-enum picks:**

- `databaseHost` — P8 already cross-references this for rollback strategy (point-in-time recovery only available on managed DBs).
- `orm` — P4 reads it for validation library / API codegen suggestions. Future P7 reads it for CI migration step strategy.
- `migrationsTool` — Future P7 needs it for CI pipeline migration step.
- `multiTenancy` — Future P6 needs it for auth/authz model (RLS vs schema isolation drives session token shape).

Everything else stays loose: the *category-level decision* is stable; the *specific tool* (Turso, EdgeDB, Pinecone, etc.) is what churns and synthesis can render verbatim.

### Synthesis HTML — `p3-data.html` (7 sections)

| § | Section title | Captured fields | Cross-checks / notes |
|---|---|---|---|
| 1 | Database engine & host | `engine`, `databaseHost` | Assumes `P0.willDeploy = true`. Note if `databaseHost: none` && `P2.stack.database` is set. |
| 2 | Schema & migrations | `orm`, `migrationsTool`, `migrationsMode` | Assumes `P2.stack.language`. **Contradiction** if `orm: prisma` && `P2.stack.language: python`. |
| 3 | Multi-tenancy isolation | `multiTenancy` | None for Round 2 (P6 not yet captured — render "not yet captured"). |
| 4 | Search & retrieval | `search` | Note if `search` mentions vector but `engine` isn't compatible. |
| 5 | Caching | `cache`, `cacheInvalidation` | Assumes `P0.teamSize` — solo + multi-layer cache is over-engineering note. |
| 6 | File / object storage | `fileStorage` | Assumes `P0.willDeploy`. Local-FS + `willDeploy: true` triggers note. |
| 7 | Codegen, backup & compliance | `codegen[]`, `backup`, `compliance` | Note if `compliance: hipaa` && `backup` not enabled. |

### Backward dependencies — `p3-data-dependencies.json.example`

```jsonc
{
  "schemaVersion": 1,
  "phase": "P3",
  "recordedAt": "2026-05-13T16:30:00Z",
  "dependencies": [
    { "path": "P0.willDeploy",      "value": true,         "rationale": "Managed/serverless DB hosts only meaningful when deploying. Embedded DB + willDeploy=false is fine." },
    { "path": "P2.stack.database",  "value": "postgresql", "rationale": "P2 captures a rough DB hint during stack research; P3 promotes it to a concrete engine + host." },
    { "path": "P2.stack.language",  "value": "typescript", "rationale": "ORM filter — Prisma/Drizzle for TS, SQLAlchemy/Django ORM for Python, GORM for Go, etc." }
  ]
}
```

### Adaptive skipping for P3

| Condition | Effect |
|---|---|
| `appType: cli` | Skip entire P3 |
| Q1=no (no DB) | Skip Q2–Q7; still ask Q8 (in-memory cache), Q9 (FS storage), Q10 (codegen), Q12 (compliance) |
| `!hasBackend && !hasFrontend` | Skip Q9 |
| `walking-skeleton` mode | Skip Q10 (codegen — deferred until scaffolded code exists) |

## Phase P4 — API & Integration

### Question bank (10 questions)

| ID | Topic | Type | Condition | Writes to `context.phases.P4.*` |
|---|---|---|---|---|
| P4.Q1 | Does this app expose an API surface? | choice | always | gate — if `no`, skip Q2–Q9, ask Q10 only |
| P4.Q2 | **API style** | choice | Q1=yes | `style` (required, enum) |
| P4.Q3 | API documentation tool | choice | Q2 ≠ none | `documentation` (loose) |
| P4.Q4 | **Versioning policy** | choice | Q1=yes && willDeploy | `versioningPolicy` (required, enum) |
| P4.Q5 | Rate limiting strategy | choice | Q1=yes && willDeploy | `rateLimit` (loose) |
| P4.Q6 | Pagination strategy | choice | Q2 ∈ (rest, graphql) | `pagination` (loose) |
| P4.Q7 | **Async pattern (jobs/queues)** | choice | hasBackend | `asyncPattern` (required, enum) |
| P4.Q8 | Real-time delivery | choice | hasBackend && hasFrontend | `realtime` (loose) |
| P4.Q9 | Webhooks (incoming + outgoing) | composite | Q1=yes | `webhooks` (loose) |
| P4.Q10 | External services & integrations | multi-select free-text | always | `externalServices[]` (loose) |

**Bold rows** = 3 required schema fields with closed enums.

### Schema sketch

```jsonc
"P4": {
  "type": "object",
  "required": ["style", "versioningPolicy", "asyncPattern"],
  "additionalProperties": false,
  "properties": {
    "style": {
      "enum": ["rest", "graphql", "trpc", "grpc", "rpc-other", "none"]
    },
    "versioningPolicy": {
      "enum": ["url-path", "header", "query-string",
               "no-breaking-changes-policy", "none-yet"]
    },
    "asyncPattern": {
      "enum": ["none", "queue-and-worker", "scheduled-cron",
               "event-driven", "serverless-functions", "mixed"]
    },
    "documentation":    { "type": "string" },
    "rateLimit":        { "type": "string" },
    "pagination":       { "type": "string" },
    "realtime":         { "type": "string" },
    "webhooks":         { "type": "string" },
    "externalServices": { "type": "array", "items": { "type": "string" } }
  }
}
```

**Rationale for the 3 required-enum picks:**

- `style` — drives codegen library choice in P3 (GraphQL codegen pairs with `style: graphql`); drives API docs tool; future P6 reads for auth integration patterns (REST middleware vs GraphQL resolver auth).
- `versioningPolicy` — Future P7 needs for breaking-change policy + ADR template; P8 release pipeline cross-references it.
- `asyncPattern` — Future P7 reads for CI test strategy; P8 conceptually depends on it for deployment topology (separate worker process).

### Synthesis HTML — `p4-api.html` (6 sections)

| § | Section title | Captured fields | Cross-checks / contradictions |
|---|---|---|---|
| 1 | API style & documentation | `style`, `documentation` | Assumes `P2.stack.framework`. **Contradiction** if `style: trpc` && `P2.stack.language ≠ typescript`. Note if `style: graphql` && `P3.codegen[]` doesn't include graphql codegen. |
| 2 | Versioning | `versioningPolicy` | Note if `versioningPolicy: none-yet` && `P0.willDeploy: true` && `hasTeam`. |
| 3 | Surface protection (rate limits + pagination) | `rateLimit`, `pagination` | Assumes `P3.cache`. Note if `rateLimit` is set but `P3.cache: none` — rate limiting wants a fast counter store. |
| 4 | Async patterns | `asyncPattern` | **Contradiction** if `asyncPattern: queue-and-worker` && `P3.cache` doesn't include a broker-capable store. Note if `asyncPattern: serverless-functions` && `P8.cicd.provider: none`. |
| 5 | Real-time | `realtime` | Note if `realtime ≠ none` && `P0.willDeploy: false`. |
| 6 | Webhooks & external integrations | `webhooks`, `externalServices[]` | Note if `webhooks` mentions outgoing && `externalServices[]` empty. Cross-ref to P3 §7 when `externalServices[]` includes a payment vendor (PCI scope flag). |

### Backward dependencies — `p4-api-dependencies.json.example`

```jsonc
{
  "schemaVersion": 1,
  "phase": "P4",
  "recordedAt": "2026-05-13T16:30:00Z",
  "dependencies": [
    { "path": "P3.orm",              "value": "prisma",       "rationale": "API codegen tool (GraphQL codegen, OpenAPI TS) and validation library pairing both track with the ORM choice." },
    { "path": "P2.stack.framework",  "value": "next.js",      "rationale": "API style options + library availability depend on the framework (FastAPI ⊂ Python, Express ⊂ Node, Rails ⊂ Ruby). Filter wizard options." },
    { "path": "P3.databaseHost",     "value": "managed-rdbms","rationale": "Rate-limit counter store choice + async-queue persistence both depend on whether the DB supports atomic increments / persistent queues." }
  ]
}
```

### Adaptive skipping for P4

| Condition | Effect |
|---|---|
| `appType: cli` | Skip entire P4 |
| `!hasBackend && !hasFrontend` | Skip entire P4 |
| Q1=no (no API) | Skip Q2–Q9; still ask Q10 |
| `!willDeploy` | Skip Q4 (versioning), Q5 (rate limit) |

## Migration of existing Cat 3 questions

| Current Q | Topic | Destination | New ID |
|---|---|---|---|
| Q3.2 | Database choice | **P3** (split into engine + host) | P3.Q2 + P3.Q3 |
| Q3.5 | External APIs | **P4** | P4.Q10 |
| Q3.7 | API design approach | **P4** | P4.Q2 |
| Q3.8 | API docs | **P4** | P4.Q3 |
| Q3.16 | Codegen tools | **P3** | P3.Q10 |
| Q3.17 | File storage | **P3** | P3.Q9 |
| Q3.18 | Background jobs | **P4** | P4.Q7 |
| Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 | Misc | **Residual Step 5** (13 Qs, destined for later rounds) | unchanged |

## Orchestrator wiring

### `context-gathering/SKILL.md` edits

1. **Insert Step 3 section** (~120 lines) documenting P3.Q1–Q3.12 with conditions, schema writes to `context.phases.P3.*`. Closes with `Skill(synthesis-review, phaseId: "P3")` invocation.
2. **Insert Step 4 section** (~100 lines) — same pattern for P4. Closes with `phaseId: "P4"` invocation.
3. **Edit existing Step 3 → become Step 5 "Remaining Project Details"** — strip the 7 re-homed questions, leave the 13 residual. Update section title + step number.
4. **Renumber Steps 4 → 6, 5 → 7, 6 → 8, 7 → 9, giving 10 total**. Update every "Step X of 8" literal to "Step X of 10".
5. **Update the state-machine transitions table** (around line 470). Add rows for `step-3-data-architecture` and `step-4-api-integration` (including synthesis-review return transitions).

### `greenfield-state.json` additions

```jsonc
{
  "currentPhase": "phase-1.8-synthesis-review",
  "currentSynthesisPhase": "P3",      // ← can now be "P3" | "P4" | "P8"
  "completedSteps": [
    "step-1-vision", "step-2-stack",
    "step-3-data-architecture",       // ← new
    "step-4-api-integration"          // ← new
    // later step IDs renamed: "step-5-cicd" → "step-7-cicd", etc.
  ]
}
```

### `synthesis-review/SKILL.md` — minimal edits

The skill already supports arbitrary `phaseId`. Round 2 only adds:
- `references/section-prompts.md` — append P3 and P4 section composition tables (~40 new lines)

### `grill-spec/SKILL.md` — minor

Grep for hardcoded "P8" references; replace with iteration over `context.syntheses.*` if any aren't already dynamic. Expected: 1–2 line change or zero.

## File inventory

### NEW files (8)

```
greenfield/skills/synthesis-review/references/templates/
  p3-data.html                              (NEW — 7-section template)
  p3-data-dependencies.json.example         (NEW — backward deps)
  p4-api.html                               (NEW — 6-section template)
  p4-api-dependencies.json.example          (NEW — backward deps)

docs/superpowers/specs/
  2026-05-13-greenfield-3.0-round2-design.md   (THIS doc)
```

### MODIFIED files (10–12)

```
onboard/skills/generate/references/context-shape-v2.json
  ← flip P3 + P4 from deferredPhase to live shapes; add p3Data + p4Api definitions

greenfield/skills/context-gathering/SKILL.md
  ← insert Step 3 (P3) + Step 4 (P4); renumber Steps 4→6, 5→7, 6→8, 7→9;
    update Step X of 8 → Step X of 10; update state transitions table

greenfield/skills/context-gathering/references/question-bank.md
  ← add Phase P3 (Q3.1–Q3.12) and Phase P4 (Q4.1–Q4.10) sections;
    annotate moved questions; mark residual Cat 3 Qs as transitional

greenfield/skills/synthesis-review/references/section-prompts.md
  ← append P3 and P4 section composition tables + Round 2 contradiction rules

greenfield/skills/grill-spec/SKILL.md
  ← (likely no-op; grep for "P8" hardcodes and replace with dynamic iteration if any)

greenfield/skills/init/SKILL.md
  ← update error matrix + enum for new phase IDs (P3, P4) in resume flow

greenfield/skills/resume/SKILL.md
  ← extend Step 4.5 phase-resume granularity prompt with P3/P4 options

greenfield/skills/status/SKILL.md
  ← update synthesis HTML count (was 1, now 3); freshness hook covers 3 files

greenfield/CLAUDE.md
  ← update arch diagram (3 phases run synthesis now); update Step count (8→9);
    update Round 2 status note

docs/greenfield-overview.html
  ← add "ROUND 2 LOCKED" entry to Discussion Log; update phase 1.8 box to
    reflect 3 wired phases (P3, P4, P8)

greenfield/.claude-plugin/plugin.json
  ← version bump 3.0.0-alpha.1 → 3.0.0-alpha.2 (or .beta.1 if user prefers)

.claude-plugin/marketplace.json
  ← version + description sync for greenfield

onboard/.claude-plugin/plugin.json
  ← version bump 2.0.0-alpha.1 → 2.0.0-alpha.2 (P3/P4 live shape additions)

onboard/CHANGELOG-2.0.md
  ← document Round 2 schema additions
```

Total: **~18–20 files** as predicted by the asymmetric Approach C estimate.

## Verification approach

Per handoff: "drive the wizard manually through P3 and P4 in a throwaway repo, confirm synthesis HTML renders, confirm `onboard:generate` accepts the v2 context."

### Verification steps

1. **Throwaway-repo manual wizard run** — fresh directory, `/greenfield:init` → walk Steps 1–4 with realistic answers (Next.js + Postgres + Prisma + REST API). Confirm:
   - Step 3 of 10 wording is correct
   - P3 questions appear in the documented order with correct conditions
   - At end of Step 3, synthesis-review fires for P3
   - `docs/architecture/p3-data.html` is created and renders the 7 sections with captured values
   - Approve/Adjust/Skip flow works on at least 2 sections per phase
   - Step 4 of 10 wording is correct; P4 flow works analogously
   - `docs/architecture/p4-api.html` is created
   - Step 5 of 10 ("Remaining Project Details") appears with the 13 residual Qs

2. **Schema validation** — feed a hand-crafted v2 context JSON with realistic P3/P4 values into `onboard:generate` (via the Skill tool). Confirm:
   - Schema validates (no `additionalProperties: false` violations)
   - `_status: "deferred-to-round-2"` is rejected for P3/P4 (they're no longer deferred)
   - `_status: "deferred-to-round-N"` still works for other phases
   - `onboard:generate` produces the standard scaffold output and doesn't error on the new P3/P4 keys

3. **Cross-check firing** — set up a context where `style: trpc` && `P2.stack.language: python`. Confirm P4 synthesis renders the contradiction `<div class="contradiction">` for §1.

4. **Adaptive skipping** — second wizard run with `appType: cli`. Confirm P3 and P4 are both skipped cleanly; Step 5 starts immediately.

### Verification NOT in scope

- Automated test suite — none for skills (consistent with Round 1).
- Cross-platform (Linux) — only macOS verified, same as Round 1.
- non-GHA scaffold output — Round 6.

## Edge cases

1. **Wizard interrupted mid-P3** — `/greenfield:resume` Step 4.5 granularity prompt asks "pick up at next P3 question / restart P3 from Q1". State file `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`, `lastAnsweredQuestionId: "P3.Q5"`. Resume reads `lastAnsweredQuestionId` and offers both options.

2. **User picks `databaseHost: none` but later answers Q9 `fileStorage: cloud`** — both valid (file storage doesn't require a DB). No contradiction. Synthesis §1 shows `databaseHost: none`; §6 shows `fileStorage: cloud-s3-like`.

3. **GraphQL codegen picked in P3.Q10 but P4.Q2 = `rest`** — synthesis P3 §7 shows the codegen choice; P4 §1 renders a `<div class="note">P3 §7 includes GraphQL codegen but you picked REST in §1 — verify intent.</div>` This is a note (not a contradiction) because the user might genuinely want both.

4. **Walking-skeleton mode + `hasBackend: true`** — P3 still runs (data decisions matter before code exists). Q10 (codegen) gets skipped because there's no scaffolded code yet to codegen against. Captured as `codegen: []` empty array.

5. **P3 synthesis dependency on P0.willDeploy when P0 is still deferred (current state)** — synthesis renders "Assumes `P0.willDeploy = (not yet captured)`". Cross-check fires automatically once Round 4 lands P0 fields. Round 2 ships with this annotation, exactly as P8 does for P3.databaseHost in Round 1.

6. **User edits `docs/architecture/p3-data.html` by hand** — pre-commit freshness hook (already shipped Round 1) detects manual edits and prompts to re-run synthesis. Documented in `synthesis-review/SKILL.md` anti-patterns.

## Rollback path

If Round 2 needs to be reverted:

1. Delete the 4 new files in `greenfield/skills/synthesis-review/references/templates/` (`p3-*.html`, `p3-*.json.example`, `p4-*.html`, `p4-*.json.example`).
2. Revert `context-shape-v2.json` — change `P3` and `P4` definitions back to `{ "$ref": "#/definitions/deferredPhase" }`.
3. Revert `context-gathering/SKILL.md` — remove inserted Step 3/Step 4 sections; restore original Step 3 (merge re-homed questions back); renumber Step 5→3, 6→4, 7→5, 8→6, 9→7.
4. Revert `question-bank.md` — remove P3/P4 sections; restore the original 7 re-homed Qs in Cat 3 location.
5. Revert version bumps in `plugin.json` + `marketplace.json` + `CHANGELOG-2.0.md`.

No state migration needed. In-flight greenfield 3.0.0-alpha.2 sessions break (per hard cutover policy, same as Round 1); user re-runs `/greenfield:init`.

Estimated revert effort: single commit, ~30 minutes.

## Risks

- **Schema enum churn** — if a new ORM or DB host category emerges between Round 2 and Round 3, the required enum fields need updates. Mitigated by Hybrid choice (only 4 enums in P3, 3 in P4); category-level enums move slower than tool-level.
- **Step renumbering edge** — any reference to `Step 4 of 8` anywhere (tests, docs, error messages) becomes stale. Mitigated by global grep before commit.
- **Grill-spec P8 hardcoding** — if any logic in grill-spec assumes only P8 syntheses exist, expanding to P3/P4 could trigger latent errors. Mitigated by verification step 3 (cross-check firing).

## Out of scope — explicit deferrals

- Forward-impact dependency edges in P3/P4 (deferred to Round 3 P6/P7 when those phases need to declare backward edges on P3/P4 fields)
- Synthesis HTML re-rendering when an upstream phase changes after synthesis was approved (Round 1 pattern; freshness hook already handles this — no Round 2 change)
- non-GHA CI provider templates for any P3/P4-related generated artifact (Round 6; Round 2 emits no new generated artifacts anyway)
- v1 → v2 migration of in-flight greenfield 2.x sessions (locked: hard cutover forever)
- Round 3 work (P6 Auth, P7 Workflow split) — referenced only as "future cross-check fires when X lands"
- Renaming `Step X of 10` to canonical `Phase P<n>` labels (locked: deferred to Round 6)

---

**Next:** implementation plan via `writing-plans` skill once this design is approved.
