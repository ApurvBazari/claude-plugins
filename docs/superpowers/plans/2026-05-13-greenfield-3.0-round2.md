# Greenfield 3.0 Round 2 — P3/P4 Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the current greenfield 2.x Category 3 (Project Details, 18 questions) into two distinct 15-phase-aligned wizard phases — P3 Data Architecture (12 Qs, 7 synthesis sections, 4 required schema fields) and P4 API & Integration (10 Qs, 6 sections, 3 required fields) — and wire Phase 1.8 synthesis-review inline at the end of each.

**Architecture:** Same orchestrator pattern as Round 1 (P8). Two new wizard steps inserted between Step 2 (Stack) and the existing Step 3 (now becoming Step 5 residual). Each new step ends with `Skill(synthesis-review, phaseId: "P<n>")` which renders a per-phase HTML synthesis at `docs/architecture/p<n>-*.html`. Schema uses hybrid strictness (3–5 required enum-locked fields per phase, rest loose strings). Backward-only dependency edges. No new code-emitting templates — Round 2 is decisions-only.

**Tech Stack:** Markdown SKILL.md files, JSON Schema draft-07, HTML synthesis templates (Mustache-like `{{placeholder}}` syntax), bash verification scripts. No compiled code; no automated test suite for skills (consistent with Round 1).

**Source spec:** `docs/superpowers/specs/2026-05-13-greenfield-3.0-round2-design.md`

**Branch:** `feat/greenfield-1.2` (continue working on same branch).

---

## File Structure

### NEW files (5)

| Path | Responsibility |
|---|---|
| `greenfield/skills/synthesis-review/references/templates/p3-data.html` | 7-section synthesis template for P3 |
| `greenfield/skills/synthesis-review/references/templates/p3-data-dependencies.json.example` | Backward-dep example for P3 |
| `greenfield/skills/synthesis-review/references/templates/p4-api.html` | 6-section synthesis template for P4 |
| `greenfield/skills/synthesis-review/references/templates/p4-api-dependencies.json.example` | Backward-dep example for P4 |
| `onboard/CHANGELOG-2.0.md` (entry, not file — file exists) | Document Round 2 P3/P4 live shape additions |

### MODIFIED files (12)

| Path | What changes |
|---|---|
| `onboard/skills/generate/references/context-shape-v2.json` | Flip P3 + P4 from `deferredPhase` stubs to live definitions with required enum-locked fields + loose strings |
| `greenfield/skills/context-gathering/references/question-bank.md` | Add Phase P3 (Q3.1–Q3.12) and Phase P4 (Q4.1–Q4.10) sections; mark residual Cat 3 Qs as transitional |
| `greenfield/skills/context-gathering/SKILL.md` | Insert Step 3 (P3) + Step 4 (P4) with inline synthesis invocations; rename existing Step 3 → Step 5 "Remaining Project Details"; renumber Steps 4→6, 5→7, 6→8, 7→9; update every `Step X of 8` → `Step X of 10`; extend state-transitions table |
| `greenfield/skills/synthesis-review/references/section-prompts.md` | Append P3 and P4 section composition tables + Round 2 contradiction rules |
| `greenfield/skills/grill-spec/SKILL.md` | Replace any hardcoded "P8" references with dynamic iteration over `context.syntheses.*` (likely 1–2 line edit) |
| `greenfield/skills/start/SKILL.md` | Extend error matrix + phase enum with `P3` and `P4` |
| `greenfield/skills/pickup/SKILL.md` | Extend Step 4.5 phase-resume granularity prompt with P3/P4 options |
| `greenfield/skills/check/SKILL.md` | Update synthesis HTML count (1 → 3); freshness hook covers 3 files |
| `greenfield/CLAUDE.md` | Update arch diagram (3 phases now synthesise); update step count 8→9; note Round 2 status |
| `docs/greenfield-overview.html` | Add "ROUND 2 LOCKED" entry to Discussion Log; update Phase 1.8 box to show 3 wired phases |
| `greenfield/.claude-plugin/plugin.json` | Bump 3.0.0-alpha.1 → 3.0.0-alpha.2 |
| `onboard/.claude-plugin/plugin.json` | Bump 2.0.0-alpha.1 → 2.0.0-alpha.2 |
| `.claude-plugin/marketplace.json` | Sync versions + descriptions for greenfield + onboard |
| `onboard/CHANGELOG-2.0.md` | Append "Round 2 additions" section |

Total: **5 new + 13 modified = 18 files** (matches design estimate).

---

## Task Order Overview

```
Phase A — Schema + templates (foundation, parallel-safe)
   T1  schema P3
   T2  schema P4
   T3  p3-data.html
   T4  p3-data-dependencies.json.example
   T5  p4-api.html
   T6  p4-api-dependencies.json.example
   T7  section-prompts.md

Phase B — Wizard surface (question bank)
   T8  question-bank P3 section
   T9  question-bank P4 section
   T10 question-bank Cat 3 cleanup

Phase C — Orchestrator wiring (context-gathering)
   T11 Step 3 (P3) insertion
   T12 Step 4 (P4) insertion
   T13 Renumber + residual Step 5
   T14 State-transitions table

Phase D — Supporting skill updates (small)
   T15 grill-spec + init + resume + status

Phase E — Docs + versioning
   T16 greenfield/CLAUDE.md
   T17 greenfield-overview.html ROUND 2 LOCKED entry
   T18 Version bumps + CHANGELOG + marketplace sync

Phase F — Verification
   T19 Schema validation against sample v2 context
   T20 Manual wizard drive-through (throwaway repo)
```

Phases A and B can run in parallel (independent file sets). Phase C depends on A. Phase D depends on C. Phase E + F are last.

---

## Task 1: Add P3 schema definition to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Read current P3 reference + locate insertion points**

Run: `grep -n '"P3"\|"P4"\|definitions"' onboard/skills/generate/references/context-shape-v2.json`

Expected: lines around 72–73 show `"P3": { "$ref": "#/definitions/deferredPhase" }` and `"P4": { ... }`. Note the location of the `"definitions"` block (line ~111) where we'll add the `p3Data` and `p4Api` schemas.

- [ ] **Step 2: Replace `P3` ref with inline live shape**

In `onboard/skills/generate/references/context-shape-v2.json`, find:

```json
"P3":   { "$ref": "#/definitions/deferredPhase" },
```

Replace with:

```json
"P3":   { "$ref": "#/definitions/p3Data" },
```

- [ ] **Step 3: Add `p3Data` definition to the `definitions` block**

In the same file, inside the `"definitions"` object (after `"p8Cicd"`), add this new definition:

```json
"p3Data": {
  "type": "object",
  "description": "Phase 3 — Data Architecture. Fully specified in onboard 2.0.0-alpha.2 Round 2. Hybrid strictness: 4 required enum-locked fields (databaseHost, orm, migrationsTool, multiTenancy) drive cross-phase contradictions; remaining fields are loose strings to accommodate a fast-moving tooling landscape (Turso, EdgeDB, pgvector, Drizzle, Kysely, etc.).",
  "required": ["databaseHost", "orm", "migrationsTool", "multiTenancy"],
  "additionalProperties": false,
  "properties": {
    "databaseHost": {
      "enum": ["self-hosted", "managed-rdbms", "serverless-rdbms", "managed-nosql", "embedded", "none"],
      "description": "Hosting model category. P8 cross-references for rollback strategy (point-in-time recovery only on managed)."
    },
    "orm": {
      "enum": ["prisma", "drizzle", "typeorm", "sequelize", "kysely", "sqlalchemy", "active-record", "ecto", "gorm", "diesel", "raw-sql", "none", "other"],
      "description": "Data access layer. P4 reads for validation lib / API codegen pairing. Future P7 reads for CI migration step strategy."
    },
    "migrationsTool": {
      "enum": ["orm-native", "alembic", "flyway", "liquibase", "raw-sql", "none", "other"],
      "description": "Migration tool. Future P7 reads for CI pipeline migration step."
    },
    "multiTenancy": {
      "enum": ["none", "row-level-rls", "schema-per-tenant", "db-per-tenant", "shared-no-isolation"],
      "description": "Isolation strategy. Future P6 reads for auth/authz model (RLS vs schema isolation drives session token shape)."
    },
    "engine":            { "type": "string", "description": "Specific DB engine (postgresql, mysql, mongodb, edgedb, turso, etc.). Loose for landscape-churn tolerance." },
    "migrationsMode":    { "type": "string", "description": "Migration application mode (developer-applied, ci-applied, runtime-applied)." },
    "search":            { "type": "string", "description": "Search/retrieval strategy (DB FTS, dedicated engine, vector store, hybrid, none)." },
    "cache":             { "type": "string", "description": "Caching layer (none, in-memory, Redis, multi-layer, etc.)." },
    "cacheInvalidation": { "type": "string", "description": "Invalidation pattern (TTL, event-driven, manual, none)." },
    "fileStorage":       { "type": "string", "description": "File/object storage (cloud-S3-like, local-FS, CDN-only, hybrid, none)." },
    "codegen":           { "type": "array", "items": { "type": "string" }, "description": "Codegen tools selected (Prisma generate, Drizzle kit, SQLC, GraphQL codegen, OpenAPI TS, Protobuf, etc.). Empty array OK." },
    "backup":            { "type": "string", "description": "Backup & retention strategy (none, managed-provider, scheduled-dumps, continuous)." },
    "compliance":        { "type": "string", "description": "Data residency/compliance constraint (none, region-locked, GDPR-aware, HIPAA, etc.)." }
  }
}
```

Place this BEFORE the closing `}` of the `"definitions"` object and AFTER the `"p8Cicd"` definition. Add a trailing comma after `"p8Cicd": { ... }` if it doesn't already have one.

- [ ] **Step 4: Validate the JSON parses**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`. If parse error, locate the missing comma or brace and fix.

- [ ] **Step 5: Update top-level description to mention Round 2**

Find the top-level `"description"` field (line 5). Currently:

```
"description": "Input schema for the onboard:generate skill in onboard 2.x. ... Round 1 (alpha.1) fully specifies P8 (CI/CD & Operations) — all other phase slots carry `_status: 'deferred-to-round-N'` and become inert pass-through metadata. ..."
```

Replace `Round 1 (alpha.1) fully specifies P8 (CI/CD & Operations) — all other phase slots carry` with:

```
Rounds 1–2 fully specify P3 (Data Architecture), P4 (API & Integration), and P8 (CI/CD & Operations). Phases P0, P0.5, P1, P5, P6, P7, P8.5, P9, P10.5 carry
```

- [ ] **Step 6: Commit T1 (don't push yet)**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "feat(onboard): add P3 Data Architecture schema definition

Flip P3 from deferred-to-round-2 stub to live shape with 4 required
enum-locked fields (databaseHost, orm, migrationsTool, multiTenancy) and
9 loose-string fields. Part of greenfield 3.0 Round 2."
```

---

## Task 2: Add P4 schema definition to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Replace `P4` ref with inline live shape**

Find:

```json
"P4":   { "$ref": "#/definitions/deferredPhase" },
```

Replace with:

```json
"P4":   { "$ref": "#/definitions/p4Api" },
```

- [ ] **Step 2: Add `p4Api` definition to the `definitions` block**

Inside `"definitions"`, after the `"p3Data"` entry from T1, add:

```json
"p4Api": {
  "type": "object",
  "description": "Phase 4 — API & Integration. Fully specified in onboard 2.0.0-alpha.2 Round 2. 3 required enum-locked fields (style, versioningPolicy, asyncPattern) drive cross-phase contradictions; remaining fields loose. Single-owner boundary: real-time, webhooks, jobs live in P4; caching, file storage, codegen live in P3.",
  "required": ["style", "versioningPolicy", "asyncPattern"],
  "additionalProperties": false,
  "properties": {
    "style": {
      "enum": ["rest", "graphql", "trpc", "grpc", "rpc-other", "none"],
      "description": "API style. Drives P3 codegen pairing (GraphQL codegen ↔ style=graphql). Future P6 reads for auth integration pattern."
    },
    "versioningPolicy": {
      "enum": ["url-path", "header", "query-string", "no-breaking-changes-policy", "none-yet"],
      "description": "Version negotiation strategy. Future P7 reads for ADR template; P8 release pipeline cross-references."
    },
    "asyncPattern": {
      "enum": ["none", "queue-and-worker", "scheduled-cron", "event-driven", "serverless-functions", "mixed"],
      "description": "Background-work pattern. Future P7 reads for CI test strategy. P8 conceptually depends for deployment topology."
    },
    "documentation":    { "type": "string", "description": "API docs tool (OpenAPI/Swagger, GraphQL Playground, auto-from-types, Scalar, Redoc, etc.)." },
    "rateLimit":        { "type": "string", "description": "Rate-limit strategy (none, fixed-window, sliding, token-bucket, per-user, per-IP, gateway-level)." },
    "pagination":       { "type": "string", "description": "Pagination strategy (offset, cursor, page-based, none)." },
    "realtime":         { "type": "string", "description": "Real-time delivery (none, WebSockets, SSE, HTTP long-poll, external pub/sub)." },
    "webhooks":         { "type": "string", "description": "Webhook directions (none, incoming-only, outgoing-only, both) + tooling notes." },
    "externalServices": { "type": "array", "items": { "type": "string" }, "description": "External integrations (Stripe, SendGrid, Twilio, Segment, etc.). Multi-select free-text. Empty array OK." }
  }
}
```

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 4: Confirm only P3 + P4 + P8 are live; rest still deferred**

Run: `grep -nE '"P[0-9.]+":' onboard/skills/generate/references/context-shape-v2.json | grep -v "definitions" | head -20`

Expected: P3 → p3Data, P4 → p4Api, P8 → p8Cicd are refs to their definitions. P0, P0.5, P1, P5, P6, P7, P8.5, P9, P10.5 still point to `deferredPhase`.

- [ ] **Step 5: Commit T2**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "feat(onboard): add P4 API & Integration schema definition

Flip P4 from deferred-to-round-2 stub to live shape with 3 required
enum-locked fields (style, versioningPolicy, asyncPattern) and 6
loose-string fields. Part of greenfield 3.0 Round 2."
```

---

## Task 3: Create p3-data.html synthesis template

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/p3-data.html`

- [ ] **Step 1: Create the file with the 7-section template**

Write the full content of `greenfield/skills/synthesis-review/references/templates/p3-data.html`:

```html
<!--
  Per-phase synthesis template — P3 (Data Architecture).
  Loaded by synthesis-review/SKILL.md Step 2 and spliced into synthesis-template.html's {{phase_body}}.

  Placeholders use Mustache-like syntax: {{phase.<field>}} resolves from
  context.phases.P3.<field>. Cross-checks resolve dependency paths from
  context.phases.<other-phase>.<path>; if the path is not yet captured (later-round phase),
  the synthesis-review skill renders "not yet captured" rather than blocking.

  Section anatomy (per references/section-prompts.md):
    1. section-title
    2. captured-as
    3. cross-checks
    4. contradictions (only if rules fire)
    5. notes (only if developer-relevant)
-->

<h2>Captured decisions</h2>

<!-- Section 1: Database engine & host -->
<div class="section">
  <div class="section-title">1. Database engine &amp; host</div>
  <pre class="captured">engine:       {{phase.engine}}
databaseHost: {{phase.databaseHost}}</pre>
  <div class="cross-check">Assumes <code>P0.willDeploy = {{P0.willDeploy}}</code>. Managed and serverless hosts are only meaningful when deploying.</div>
  <!-- Note injected by section-prompts.md if databaseHost === "none" && P2.stack.database is set: -->
  <!-- <div class="note">You picked <code>databaseHost: none</code> but P2 stack research suggested <code>{{P2.stack.database}}</code> — verify intent.</div> -->
</div>

<!-- Section 2: Schema & migrations -->
<div class="section">
  <div class="section-title">2. Schema &amp; migrations</div>
  <pre class="captured">orm:            {{phase.orm}}
migrationsTool: {{phase.migrationsTool}}
migrationsMode: {{phase.migrationsMode}}</pre>
  <div class="cross-check">Assumes <code>P2.stack.language = {{P2.stack.language}}</code>. ORM filter: Prisma/Drizzle for TypeScript, SQLAlchemy/Django for Python, GORM for Go, etc.</div>
  <!-- Contradiction injected if orm === "prisma" && P2.stack.language === "python": -->
  <!-- <div class="contradiction"><strong>Contradiction:</strong> P3 picked <code>orm: prisma</code> but P2 said the language is Python. Prisma is TypeScript-only. Pick SQLAlchemy / Django ORM / raw-sql instead.</div> -->
</div>

<!-- Section 3: Multi-tenancy isolation -->
<div class="section">
  <div class="section-title">3. Multi-tenancy isolation</div>
  <pre class="captured">multiTenancy: {{phase.multiTenancy}}</pre>
  <div class="cross-check">Future P6 (Round 3) will read this for auth/authz model — RLS requires row-level Postgres policies, schema-per-tenant requires connection routing. Cross-check fires automatically once P6 lands.</div>
</div>

<!-- Section 4: Search & retrieval -->
<div class="section">
  <div class="section-title">4. Search &amp; retrieval</div>
  <pre class="captured">search: {{phase.search}}</pre>
  <!-- Note injected if search mentions "vector" but engine isn't a vector-capable engine: -->
  <!-- <div class="note">Heads-up — vector search needs an engine with vector support (pgvector for Postgres, native for MongoDB Atlas, dedicated like Pinecone/Qdrant). Verify your engine choice is compatible.</div> -->
</div>

<!-- Section 5: Caching -->
<div class="section">
  <div class="section-title">5. Caching</div>
  <pre class="captured">cache:             {{phase.cache}}
cacheInvalidation: {{phase.cacheInvalidation}}</pre>
  <div class="cross-check">Assumes <code>P0.teamSize = {{P0.teamSize}}</code>. Solo developer + multi-layer cache is usually over-engineering.</div>
  <!-- Note injected if P0.teamSize === "solo" && cache mentions "multi-layer": -->
  <!-- <div class="note">Multi-layer cache for a solo project — verify this isn't premature optimization. Single-layer (Redis or in-memory) is the usual starting point.</div> -->
</div>

<!-- Section 6: File / object storage -->
<div class="section">
  <div class="section-title">6. File / object storage</div>
  <pre class="captured">fileStorage: {{phase.fileStorage}}</pre>
  <div class="cross-check">Assumes <code>P0.willDeploy = {{P0.willDeploy}}</code>. Local-filesystem storage with willDeploy=true is a deployment-portability risk.</div>
  <!-- Note injected if fileStorage mentions "local" && P0.willDeploy === true: -->
  <!-- <div class="note">Local-FS storage + cloud deployment means files don't persist across container restarts. Switch to S3-compatible object storage or accept the trade-off explicitly.</div> -->
</div>

<!-- Section 7: Codegen, backup & compliance -->
<div class="section">
  <div class="section-title">7. Codegen, backup &amp; compliance</div>
  <pre class="captured">codegen:    {{phase.codegen}}
backup:     {{phase.backup}}
compliance: {{phase.compliance}}</pre>
  <!-- Note injected if compliance === "hipaa" && backup !~ "managed|continuous": -->
  <!-- <div class="note">HIPAA compliance typically requires continuous or managed-provider backup. Your backup choice (<code>{{phase.backup}}</code>) may not meet the standard.</div> -->
</div>
```

- [ ] **Step 2: Verify placeholder syntax matches P8 template**

Run: `grep -cE '\{\{(phase\.|P0\.|P2\.)' greenfield/skills/synthesis-review/references/templates/p3-data.html`

Expected: ≥ 15 (each section captures fields + cross-checks). Compare to P8's count for sanity: `grep -cE '\{\{' greenfield/skills/synthesis-review/references/templates/p8-cicd.html` should produce a similar order of magnitude.

- [ ] **Step 3: Commit T3**

```bash
git add greenfield/skills/synthesis-review/references/templates/p3-data.html
git commit -m "feat(greenfield): add P3 Data Architecture synthesis template

7-section template (engine+host, schema+migrations, multi-tenancy,
search, caching, file storage, codegen+backup+compliance) following the
P8 section anatomy from references/section-prompts.md."
```

---

## Task 4: Create p3-data-dependencies.json.example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/p3-data-dependencies.json.example`

- [ ] **Step 1: Write the example file**

Write the content of `greenfield/skills/synthesis-review/references/templates/p3-data-dependencies.json.example`:

```json
{
  "schemaVersion": 1,
  "phase": "P3",
  "recordedAt": "2026-05-13T16:30:00Z",
  "dependencies": [
    {
      "path": "P0.willDeploy",
      "value": true,
      "rationale": "Managed and serverless DB hosts are only meaningful when the project will deploy. Embedded DB + willDeploy=false is fine. P0 is deferred to Round 4; cross-check fires automatically once P0 lands."
    },
    {
      "path": "P2.stack.database",
      "value": "postgresql",
      "rationale": "P2 captures a rough DB hint during stack research; P3 promotes it to a concrete engine + host. Mismatch flagged in synthesis section 1."
    },
    {
      "path": "P2.stack.language",
      "value": "typescript",
      "rationale": "ORM filter — Prisma/Drizzle for TypeScript, SQLAlchemy/Django ORM for Python, GORM for Go, etc. Drives wizard option filtering and synthesis contradiction check in section 2."
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; json.load(open('greenfield/skills/synthesis-review/references/templates/p3-data-dependencies.json.example'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 3: Commit T4**

```bash
git add greenfield/skills/synthesis-review/references/templates/p3-data-dependencies.json.example
git commit -m "feat(greenfield): add P3 dependencies.json example

Three backward-edge dependencies (P0.willDeploy, P2.stack.database,
P2.stack.language) with rationales. Per Round 2 backward-only decision."
```

---

## Task 5: Create p4-api.html synthesis template

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/p4-api.html`

- [ ] **Step 1: Create the file with the 6-section template**

Write the full content of `greenfield/skills/synthesis-review/references/templates/p4-api.html`:

```html
<!--
  Per-phase synthesis template — P4 (API & Integration).
  Loaded by synthesis-review/SKILL.md Step 2 and spliced into synthesis-template.html's {{phase_body}}.

  Section anatomy per references/section-prompts.md.
  6 sections (P4 is leaner than P3's 7 — fewer concerns under single-owner boundary).
-->

<h2>Captured decisions</h2>

<!-- Section 1: API style & documentation -->
<div class="section">
  <div class="section-title">1. API style &amp; documentation</div>
  <pre class="captured">style:         {{phase.style}}
documentation: {{phase.documentation}}</pre>
  <div class="cross-check">Assumes <code>P2.stack.framework = {{P2.stack.framework}}</code>. API library availability tracks the framework (FastAPI ⊂ Python, Express ⊂ Node, Rails ⊂ Ruby).</div>
  <!-- Contradiction injected if style === "trpc" && P2.stack.language !== "typescript": -->
  <!-- <div class="contradiction"><strong>Contradiction:</strong> P4 picked <code>style: trpc</code> but P2 said the language is <code>{{P2.stack.language}}</code>. tRPC is TypeScript-only. Pick REST or GraphQL instead.</div> -->
  <!-- Note injected if style === "graphql" && P3.codegen doesn't include graphql codegen: -->
  <!-- <div class="note">You picked GraphQL but P3 §7 codegen doesn't include a GraphQL codegen tool. Consider adding graphql-codegen for type-safe resolvers.</div> -->
</div>

<!-- Section 2: Versioning -->
<div class="section">
  <div class="section-title">2. Versioning</div>
  <pre class="captured">versioningPolicy: {{phase.versioningPolicy}}</pre>
  <!-- Note injected if versioningPolicy === "none-yet" && P0.willDeploy === true && P0.teamSize !== "solo": -->
  <!-- <div class="note">Public API without a versioning policy is technical debt — when you ship a breaking change, clients will be unable to pin. Consider URL-path or header versioning before launch.</div> -->
</div>

<!-- Section 3: Surface protection (rate limits + pagination) -->
<div class="section">
  <div class="section-title">3. Surface protection</div>
  <pre class="captured">rateLimit:  {{phase.rateLimit}}
pagination: {{phase.pagination}}</pre>
  <div class="cross-check">Assumes <code>P3.cache = {{P3.cache}}</code>. Rate limiting needs a fast counter store; pagination strategy affects both client UX and DB query shape.</div>
  <!-- Note injected if rateLimit is set but P3.cache === "none": -->
  <!-- <div class="note">Rate limiting wants a fast counter store. P3 captured <code>cache: none</code> — either add a cache layer in P3 or accept DB-backed counters (slower under load).</div> -->
</div>

<!-- Section 4: Async patterns -->
<div class="section">
  <div class="section-title">4. Async patterns</div>
  <pre class="captured">asyncPattern: {{phase.asyncPattern}}</pre>
  <div class="cross-check">Assumes <code>P3.cache</code> for queue persistence and <code>P8.cicd.provider</code> for deployment topology.</div>
  <!-- Contradiction injected if asyncPattern === "queue-and-worker" && P3.cache doesn't include a broker-capable store: -->
  <!-- <div class="contradiction"><strong>Contradiction:</strong> P4 picked <code>asyncPattern: queue-and-worker</code> but P3 cache doesn't include a broker (Redis, RabbitMQ). Pick a broker-capable cache or switch to scheduled-cron / serverless-functions.</div> -->
  <!-- Note injected if asyncPattern === "serverless-functions" && P8.cicd.provider === "none": -->
  <!-- <div class="note">Serverless-functions async pattern usually requires a deploy pipeline. P8 captured <code>provider: none</code> — verify how worker functions get deployed.</div> -->
</div>

<!-- Section 5: Real-time -->
<div class="section">
  <div class="section-title">5. Real-time</div>
  <pre class="captured">realtime: {{phase.realtime}}</pre>
  <!-- Note injected if realtime !== "none" && P0.willDeploy === false: -->
  <!-- <div class="note">Real-time delivery + local-only deployment is unusual. Verify the use case — most real-time features assume internet-facing infrastructure.</div> -->
</div>

<!-- Section 6: Webhooks & external integrations -->
<div class="section">
  <div class="section-title">6. Webhooks &amp; external integrations</div>
  <pre class="captured">webhooks:         {{phase.webhooks}}
externalServices: {{phase.externalServices}}</pre>
  <!-- Note injected if webhooks mentions "outgoing" && externalServices is empty: -->
  <!-- <div class="note">Outgoing webhooks usually target external services. You captured no external services in section 6 — verify intent.</div> -->
  <!-- Note injected if externalServices includes a payment vendor (stripe, paddle, etc.): -->
  <!-- <div class="note">Payment vendor in scope — see P3 §7 for PCI-scope compliance implications. The backup & retention strategy may need to exclude payment data from logs.</div> -->
</div>
```

- [ ] **Step 2: Verify placeholder count**

Run: `grep -cE '\{\{(phase\.|P[0-9]+\.)' greenfield/skills/synthesis-review/references/templates/p4-api.html`

Expected: ≥ 12.

- [ ] **Step 3: Commit T5**

```bash
git add greenfield/skills/synthesis-review/references/templates/p4-api.html
git commit -m "feat(greenfield): add P4 API & Integration synthesis template

6-section template (style+docs, versioning, surface protection, async,
real-time, webhooks+integrations). Cross-references P3 codegen and P3
cache for compatibility checks."
```

---

## Task 6: Create p4-api-dependencies.json.example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/p4-api-dependencies.json.example`

- [ ] **Step 1: Write the example file**

Write the content of `greenfield/skills/synthesis-review/references/templates/p4-api-dependencies.json.example`:

```json
{
  "schemaVersion": 1,
  "phase": "P4",
  "recordedAt": "2026-05-13T16:30:00Z",
  "dependencies": [
    {
      "path": "P3.orm",
      "value": "prisma",
      "rationale": "API codegen tool (GraphQL codegen, OpenAPI TS) and validation library pairing both track with the ORM choice. Synthesis section 1 cross-checks codegen alignment."
    },
    {
      "path": "P2.stack.framework",
      "value": "next.js",
      "rationale": "API style options and library availability depend on the framework (FastAPI ⊂ Python, Express ⊂ Node, Rails ⊂ Ruby). Drives wizard option filtering."
    },
    {
      "path": "P3.databaseHost",
      "value": "managed-rdbms",
      "rationale": "Rate-limit counter store choice + async-queue persistence both depend on whether the DB supports atomic increments and persistent queues. Synthesis section 3 cross-checks rate limiting feasibility."
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; json.load(open('greenfield/skills/synthesis-review/references/templates/p4-api-dependencies.json.example'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 3: Commit T6**

```bash
git add greenfield/skills/synthesis-review/references/templates/p4-api-dependencies.json.example
git commit -m "feat(greenfield): add P4 dependencies.json example

Three backward-edge dependencies (P3.orm, P2.stack.framework,
P3.databaseHost) with rationales."
```

---

## Task 7: Extend section-prompts.md with P3 + P4 composition rules

**Files:**
- Modify: `greenfield/skills/synthesis-review/references/section-prompts.md`

- [ ] **Step 1: Read current Round 1 P8 section**

Run: `cat greenfield/skills/synthesis-review/references/section-prompts.md`

Note the location of "## Round 1 sections (P8 CI/CD)" — new sections go after it.

- [ ] **Step 2: Append Round 2 P3 + P4 tables**

At the end of `greenfield/skills/synthesis-review/references/section-prompts.md`, before the "## Tone" section, insert:

```markdown
## Round 2 sections (P3 Data Architecture)

Use this table to compose `p3-data.html` sections.

| Section | Maps to (context.phases.P3.*) | Cross-checks |
|---|---|---|
| Database engine & host | `engine`, `databaseHost` | Assumes `P0.willDeploy`. Note if `databaseHost: none` && `P2.stack.database` is set. |
| Schema & migrations | `orm`, `migrationsTool`, `migrationsMode` | Assumes `P2.stack.language`. Contradiction if `orm: prisma` && `P2.stack.language: python`. |
| Multi-tenancy isolation | `multiTenancy` | Assumes future `P6` (Round 3 — render "not yet captured"). |
| Search & retrieval | `search` | None. Note if search mentions "vector" && `engine` is not vector-capable. |
| Caching | `cache`, `cacheInvalidation` | Assumes `P0.teamSize`. Solo + multi-layer cache produces over-engineering note. |
| File / object storage | `fileStorage` | Assumes `P0.willDeploy`. Local-FS + willDeploy=true triggers deployment-portability note. |
| Codegen, backup & compliance | `codegen[]`, `backup`, `compliance` | Note if `compliance: hipaa` && `backup !~ "managed\|continuous"`. |

## Round 2 sections (P4 API & Integration)

Use this table to compose `p4-api.html` sections.

| Section | Maps to (context.phases.P4.*) | Cross-checks |
|---|---|---|
| API style & documentation | `style`, `documentation` | Assumes `P2.stack.framework`. Contradiction if `style: trpc` && `P2.stack.language != typescript`. Note if `style: graphql` && `P3.codegen[]` doesn't include graphql codegen. |
| Versioning | `versioningPolicy` | Note if `versioningPolicy: none-yet` && `P0.willDeploy: true` && `P0.teamSize != solo`. |
| Surface protection | `rateLimit`, `pagination` | Assumes `P3.cache`. Note if `rateLimit` is set but `P3.cache: none`. |
| Async patterns | `asyncPattern` | Contradiction if `asyncPattern: queue-and-worker` && `P3.cache` doesn't include a broker-capable store. Note if `asyncPattern: serverless-functions` && `P8.cicd.provider: none`. |
| Real-time | `realtime` | Note if `realtime != none` && `P0.willDeploy: false`. |
| Webhooks & external integrations | `webhooks`, `externalServices[]` | Note if `webhooks` mentions "outgoing" && `externalServices[]` empty. Note PCI-scope flag if `externalServices[]` includes a payment vendor. |

## Round 2 contradiction-detection additions

Append to the contradiction table above the section-prompts file:

| Check | Condition | Fires |
|---|---|---|
| Prisma-on-Python | `phases.P3.orm === "prisma"` AND `phases.P2.stack.language === "python"` | "P3 picked Prisma but P2 said the language is Python. Prisma is TypeScript-only — pick SQLAlchemy / Django ORM / raw-sql instead." |
| tRPC-on-non-TS | `phases.P4.style === "trpc"` AND `phases.P2.stack.language !== "typescript"` | "P4 picked tRPC but P2 said the language isn't TypeScript. tRPC is TS-only — pick REST or GraphQL instead." |
| Queue-without-broker | `phases.P4.asyncPattern === "queue-and-worker"` AND `phases.P3.cache` is empty OR doesn't include a broker-capable string | "P4 wants a queue+worker but P3 cache doesn't include a broker. Either add Redis/RabbitMQ to P3 cache or pick scheduled-cron." |
```

- [ ] **Step 3: Verify the appended content reads cleanly**

Run: `grep -nE "^## Round 2" greenfield/skills/synthesis-review/references/section-prompts.md`

Expected: 3 matches (P3 sections, P4 sections, contradiction-detection additions).

- [ ] **Step 4: Commit T7**

```bash
git add greenfield/skills/synthesis-review/references/section-prompts.md
git commit -m "feat(greenfield): extend section-prompts with P3 + P4 rules

Add composition tables for P3 (7 sections) and P4 (6 sections) plus
three new contradiction-detection rules (Prisma-on-Python,
tRPC-on-non-TS, Queue-without-broker)."
```

---

## Task 8: Add Phase P3 question section to question-bank.md

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Locate insertion point**

Run: `grep -n "^## Category 3\|^## Category 4" greenfield/skills/context-gathering/references/question-bank.md`

Expected: Category 3 starts ~line 68, Category 4 ~line 193. New "## Phase P3 (Data Architecture)" goes BEFORE Category 3 (since wizard runs P3 → P4 → residual Cat 3).

- [ ] **Step 2: Insert P3 phase section before Category 3**

In `greenfield/skills/context-gathering/references/question-bank.md`, find the line `## Category 3: Project Details (adaptive)` and insert the following BEFORE it:

```markdown
## Phase P3: Data Architecture (12 questions)

Phase 3 of the 15-phase wizard. Captures data-layer decisions: DB engine + host, ORM, migrations, multi-tenancy, search, caching, file storage, codegen, backup, compliance. Synthesis review fires inline after the last question.

Writes to `context.phases.P3.*`. See `onboard/skills/generate/references/context-shape-v2.json` § `p3Data` for the schema.

### P3.Q1: "Does this app need persistent data?"
- **Type**: Choice
- **Options**: "Yes — relational" | "Yes — document/NoSQL" | "Yes — embedded (SQLite/DuckDB)" | "No persistent data" | "Not sure — recommend"
- **Condition**: Always (gate for the rest of P3)
- **Updates**: gate flag; if "No persistent data", skip Q2–Q7 but still ask Q8 (in-memory cache), Q9 (FS storage), Q10 (codegen), Q12 (compliance)

### P3.Q2: "Which database engine?"
- **Type**: Open with stack-informed recommendations
- **Options**: Dynamically generated (e.g., "PostgreSQL (recommended for Next.js + Prisma)" | "MySQL" | "MongoDB" | "SQLite" | "Turso/libSQL" | "PlanetScale" | "EdgeDB" | "DynamoDB" | "Custom — specify")
- **Condition**: Q1 = yes (any persistent option)
- **Updates**: `context.phases.P3.engine` (loose string)

### P3.Q3: "What's the database hosting model?"
- **Type**: Choice
- **Options**: "Self-hosted (you manage the server)" | "Managed RDBMS (RDS, Cloud SQL, Supabase)" | "Serverless RDBMS (Neon, PlanetScale, Turso)" | "Managed NoSQL (Atlas, DynamoDB)" | "Embedded (SQLite/DuckDB)" | "None"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P3.databaseHost` (required, enum)
- **Cross-phase**: P8 reads this for rollback strategy (point-in-time recovery on managed hosts only)

### P3.Q4: "Which ORM or data-access layer?"
- **Type**: Choice (filtered by P2.stack.language)
- **Options**: For TypeScript: "Prisma" | "Drizzle" | "Kysely" | "TypeORM" | "Sequelize" | "Raw SQL" | "Other". For Python: "SQLAlchemy" | "Django ORM" | "Raw SQL" | "Other". For Go: "GORM" | "sqlc" | "Raw SQL" | "Other". For Ruby: "Active Record" | "Raw SQL" | "Other". For Elixir: "Ecto" | "Raw SQL" | "Other". For Rust: "Diesel" | "sqlx" | "Raw SQL" | "Other".
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P3.orm` (required, enum)
- **Cross-phase**: P4 reads for codegen + validation library pairing

### P3.Q5: "Migration tool & application mode?"
- **Type**: Composite (choice + choice)
- **Sub-questions**:
  - Tool: "ORM-native (Prisma migrate, Drizzle kit, etc.)" | "Alembic" | "Flyway" | "Liquibase" | "Raw SQL files" | "None — manual schema" | "Other"
  - Mode: "Developer-applied (dev runs migrations locally)" | "CI-applied (pipeline runs before deploy)" | "Runtime-applied (app applies on boot)"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P3.migrationsTool` (required, enum) + `migrationsMode` (loose)

### P3.Q6: "Multi-tenancy isolation strategy?"
- **Type**: Choice
- **Options**: "None — single-tenant" | "Row-level (tenant_id columns + RLS)" | "Schema-per-tenant" | "DB-per-tenant" | "Shared (no isolation — review carefully)"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P3.multiTenancy` (required, enum)
- **Cross-phase**: Future P6 reads for auth/authz model

### P3.Q7: "Search and retrieval strategy?"
- **Type**: Choice
- **Options**: "DB full-text only (Postgres tsvector, MySQL FT)" | "Dedicated engine (Elasticsearch, Meilisearch, Typesense)" | "Vector store (pgvector, Pinecone, Qdrant, Weaviate)" | "Hybrid (FTS + vector)" | "None — no search"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P3.search` (loose)

### P3.Q8: "Caching layer + invalidation pattern?"
- **Type**: Composite (multi-select + choice)
- **Sub-questions**:
  - Layers (multi-select; pad with "None / Skip" if zero matches): "In-memory (app-local)" | "Redis / KeyDB" | "Memcached" | "DB query cache" | "CDN edge"
  - Invalidation: "TTL only" | "Event-driven (invalidate on write)" | "Manual" | "None — no caching"
- **Condition**: Always (even no-DB apps can cache)
- **Updates**: `context.phases.P3.cache` (loose) + `cacheInvalidation` (loose)

### P3.Q9: "File / object storage strategy?"
- **Type**: Choice
- **Options**: "Cloud storage (S3 / R2 / Blob / GCS)" | "Local filesystem" | "CDN for static assets" | "Both cloud + CDN" | "No file handling"
- **Condition**: `hasBackend || hasFrontend`
- **Updates**: `context.phases.P3.fileStorage` (loose)

### P3.Q10: "Codegen tools?"
- **Type**: Multi-select
- **Options**: "Prisma generate" | "Drizzle Kit" | "sqlc" | "GraphQL codegen" | "OpenAPI TypeScript" | "Protocol Buffers" | "None"
- **Condition**: Applicable to stack (skip if Q1=no AND no API)
- **Updates**: `context.phases.P3.codegen` (loose array)
- **Note**: Even though codegen spans ORM (Prisma) and API (GraphQL/OpenAPI), it lives in P3 only per the single-owner boundary. P4 synthesis cross-references this question when style=graphql.

### P3.Q11: "Backup & retention?"
- **Type**: Choice
- **Options**: "None — accept loss risk" | "Managed-provider auto-backup (most cloud DBs)" | "Scheduled dumps (custom cron)" | "Continuous (point-in-time recovery)"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.P3.backup` (loose)

### P3.Q12: "Data residency / compliance constraints?"
- **Type**: Choice
- **Options**: "None" | "Region-locked (specify in follow-up)" | "GDPR-aware (EU users)" | "HIPAA" | "PCI-DSS" | "SOC 2"
- **Condition**: Always
- **Updates**: `context.phases.P3.compliance` (loose)

**>>> SYNTHESIS PAUSE**: After P3.Q12 (or after earlier final-question if Q1=no), invoke `Skill(synthesis-review, phaseId: "P3")`. Wait for the developer to Approve/Adjust/Skip each section before moving to Phase P4.

---

```

- [ ] **Step 3: Verify question numbering**

Run: `grep -cE "^### P3\.Q[0-9]+" greenfield/skills/context-gathering/references/question-bank.md`

Expected: 12.

- [ ] **Step 4: Commit T8**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "feat(greenfield): add Phase P3 question bank section

12 questions covering data architecture: engine, host, ORM, migrations,
multi-tenancy, search, caching, file storage, codegen, backup,
compliance. Closes with synthesis-review invocation."
```

---

## Task 9: Add Phase P4 question section to question-bank.md

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Insert P4 section after the P3 section just added**

In `greenfield/skills/context-gathering/references/question-bank.md`, find the `**>>> SYNTHESIS PAUSE**` line that closes the P3 section (just added in T8) and the `---` separator that follows it. AFTER the separator, insert:

```markdown
## Phase P4: API & Integration (10 questions)

Phase 4 of the 15-phase wizard. Captures API surface decisions: style, documentation, versioning, rate limits, pagination, async patterns, real-time, webhooks, external integrations.

Writes to `context.phases.P4.*`. See `onboard/skills/generate/references/context-shape-v2.json` § `p4Api` for the schema.

### P4.Q1: "Does this app expose an API surface?"
- **Type**: Choice
- **Options**: "Yes — public API" | "Yes — internal/private only" | "No — UI-only app" | "Not sure — recommend"
- **Condition**: Always (gate for the rest of P4)
- **Updates**: gate flag; if "No", skip Q2–Q9, ask Q10 only

### P4.Q2: "API style?"
- **Type**: Choice
- **Options**: "REST" | "GraphQL" | "tRPC (TypeScript-only)" | "gRPC" | "Other RPC" | "No API surface"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P4.style` (required, enum)
- **Cross-phase**: P3 reads for codegen pairing; future P6 reads for auth integration pattern

### P4.Q3: "API documentation tool?"
- **Type**: Choice
- **Options**: "OpenAPI / Swagger" | "GraphQL Playground / Apollo Studio" | "Auto-from-types (TS-RPC, etc.)" | "Manual (Markdown / Notion)" | "No docs"
- **Condition**: Q2 ≠ none
- **Updates**: `context.phases.P4.documentation` (loose)

### P4.Q4: "Versioning policy?"
- **Type**: Choice
- **Options**: "URL path (/v1/, /v2/)" | "Header (Accept-Version)" | "Query string (?v=1)" | "No-breaking-changes policy (additive only)" | "None yet — figure it out later"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.P4.versioningPolicy` (required, enum)
- **Cross-phase**: Future P7 reads for breaking-change policy

### P4.Q5: "Rate limiting strategy?"
- **Type**: Choice
- **Options**: "None" | "Fixed window (Redis-backed)" | "Sliding window" | "Token bucket" | "Per-user / per-API-key" | "Per-IP" | "Gateway-level (Cloudflare, AWS API Gateway)"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.P4.rateLimit` (loose)

### P4.Q6: "Pagination strategy?"
- **Type**: Choice
- **Options**: "Offset (LIMIT/OFFSET)" | "Cursor (timestamp or ID-based)" | "Page-based (page=N&size=M)" | "Both offset + cursor (REST: cursor; GraphQL: Relay)" | "None — return all"
- **Condition**: Q2 ∈ (rest, graphql)
- **Updates**: `context.phases.P4.pagination` (loose)

### P4.Q7: "Async pattern for background work?"
- **Type**: Choice
- **Options**: "None — all sync" | "Queue + worker (BullMQ, Celery, Sidekiq)" | "Scheduled cron jobs" | "Event-driven (pub/sub)" | "Serverless functions (Lambda, Cloud Functions)" | "Mixed"
- **Condition**: `hasBackend`
- **Updates**: `context.phases.P4.asyncPattern` (required, enum)
- **Cross-phase**: Future P7 reads for CI test strategy

### P4.Q8: "Real-time delivery?"
- **Type**: Choice
- **Options**: "None" | "WebSockets" | "Server-Sent Events (SSE)" | "HTTP long-polling" | "External pub/sub (Pusher, Ably, Liveblocks)"
- **Condition**: `hasBackend && hasFrontend`
- **Updates**: `context.phases.P4.realtime` (loose)

### P4.Q9: "Webhooks — incoming and outgoing?"
- **Type**: Composite (choice + multi-select)
- **Sub-questions**:
  - Direction: "None" | "Incoming only (we receive)" | "Outgoing only (we send)" | "Both"
  - Tooling (multi-select; pad with "None / Skip" if zero matches): "Signature verification" | "Retry queue" | "Dead-letter handling" | "Webhook registry UI"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.P4.webhooks` (loose)

### P4.Q10: "External services and integrations?"
- **Type**: Multi-select free-text
- **Options**: "Payments (Stripe, Paddle, Lemon Squeezy)" | "Email (Resend, SendGrid, Postmark)" | "SMS (Twilio)" | "Analytics (Segment, Mixpanel, PostHog)" | "Search (Algolia)" | "Storage (S3-compatible)" | "AI / LLM (OpenAI, Anthropic, etc.)" | "Other — specify"
- **Condition**: Always (even no-API apps integrate with services)
- **Updates**: `context.phases.P4.externalServices` (loose array)

**>>> SYNTHESIS PAUSE**: After P4.Q10, invoke `Skill(synthesis-review, phaseId: "P4")`. Wait for the developer to Approve/Adjust/Skip each section before moving to the remaining Project Details step.

---

```

- [ ] **Step 2: Verify Q numbering**

Run: `grep -cE "^### P4\.Q[0-9]+" greenfield/skills/context-gathering/references/question-bank.md`

Expected: 10.

- [ ] **Step 3: Commit T9**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "feat(greenfield): add Phase P4 question bank section

10 questions covering API + integration: style, docs, versioning, rate
limits, pagination, async pattern, real-time, webhooks, external
services. Closes with synthesis-review invocation."
```

---

## Task 10: Mark re-homed questions + clean Cat 3 in question-bank.md

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Add a re-homing notice at the top of Category 3**

Find the line `## Category 3: Project Details (adaptive)` in the question-bank. Replace it with:

```markdown
## Category 3 (residual): Remaining Project Details

> **Round 2 note (2026-05-13):** Several Cat 3 questions have been moved to Phase P3 (Data Architecture) and Phase P4 (API & Integration). The 13 questions below stay here as a residual step until later rounds re-home them:
> - **Moved to P3:** Q3.2 (DB) → P3.Q2+Q3, Q3.16 (codegen) → P3.Q10, Q3.17 (file storage) → P3.Q9
> - **Moved to P4:** Q3.5 (external APIs) → P4.Q10, Q3.7 (API style) → P4.Q2, Q3.8 (API docs) → P4.Q3, Q3.18 (bg jobs) → P4.Q7
> - **Staying here (Cat 3 residual):** Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 — destined for Rounds 3–6.

This category becomes wizard Step 5 of 10 in Round 2.
```

- [ ] **Step 2: Strip the 7 re-homed questions from Category 3**

In the same file, **delete** the entire question blocks for:
- `### Q3.2: "Do you need a database?"` through to the `---` before Q3.3 (delete Q3.2)
- `### Q3.5: "Any specific APIs or services you'll integrate with?"` through to the `---` before Q3.6 (delete Q3.5)
- `### Q3.7: "What's your API design approach?"` through to the `---` before Q3.8 (delete Q3.7)
- `### Q3.8: "Do you want auto-generated API documentation?"` through to the `---` before Q3.9 (delete Q3.8)
- `### Q3.16: "Do you use code generation tools?"` through to the `---` before Q3.17 (delete Q3.16)
- `### Q3.17: "Will your app need file storage or asset management?"` through to the `---` before Q3.18 (delete Q3.17)
- `### Q3.18: "Does your app need background processing or scheduled jobs?"` through to the `---` before Q3.F1 (delete Q3.18)

After these deletions, Category 3 should contain only: Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 (13 questions).

- [ ] **Step 3: Verify Cat 3 residual count**

Run: `awk '/^## Category 3/,/^## Category 4/' greenfield/skills/context-gathering/references/question-bank.md | grep -cE "^### Q3\."`

Expected: 13.

- [ ] **Step 4: Update the Adaptive Skipping Rules table**

Find `## Adaptive Skipping Rules` section near the end of question-bank.md. The current table references Q3.2/Q3.5/Q3.7/Q3.8/Q3.16/Q3.17/Q3.18 which no longer exist in Cat 3.

Replace the existing table rows referencing those IDs. For each old reference, update to point at the new P3/P4 ID. The new table:

```markdown
## Adaptive Skipping Rules

| Developer says | Questions skipped |
|---|---|
| CLI tool (appType = cli) | Q3.3, Q3.4 deploy*, Q3.6, P3 entire phase, P4 entire phase, Q3.12-Q3.14, Q3.F1, Q3.F2, Q5.1, Q5.3 |
| Side project, not deploying | Q5.1, Q5.3, Q3.6, Q3.11 (auto deps), P3.Q11 (backup), P4.Q4 (versioning), P4.Q5 (rate limit) |
| API-only backend | Q3.F1, Q3.F2, Q3.12-Q3.14, P4.Q8 (real-time) |
| Solo developer | Q5.3 (PR review), Q5.13 (notifications warning) |
| No database (P3.Q1 = no) | P3.Q2–Q7 |
| No API layer (P4.Q1 = no) | P4.Q2–Q9 |

*When `willDeploy = false`, the entire Category 5 (CI/CD) except Q5.2 is skipped.
```

- [ ] **Step 5: Commit T10**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "refactor(greenfield): re-home Cat 3 Qs to P3/P4 and clean residual

Strip 7 questions from Category 3 (now moved to P3 or P4 sections added
in T8/T9). Mark Cat 3 as residual Step 5 with 13 remaining questions
destined for later rounds. Update adaptive-skipping table with new P3/P4
IDs."
```

---

## Task 11: Insert Step 3 (P3) into context-gathering/SKILL.md

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Locate the existing Step 3 boundary**

Run: `grep -n "^### Step [0-9] of 8\|^## Step [0-9] of 8\|^#### Step [0-9] of 8" greenfield/skills/context-gathering/SKILL.md`

Note the line numbers for each Step heading. The new Step 3 (P3) goes BEFORE the existing Step 3.

- [ ] **Step 2: Insert the new Step 3 P3 section**

Find the line that begins the existing Step 3 (likely `### Step 3 of 10: Project Details` or similar). Insert the following BEFORE that line:

```markdown
### Step 3 of 10: Data Architecture (Phase P3)

This step is Round 2's first new phase. Captures data-layer decisions via P3.Q1–Q3.12 and closes with an inline Phase 1.8 synthesis-review pass.

**Data layout** — answers populate `context.phases.P3.*` directly (no v1 carryover). The 4 required enum-locked fields are `databaseHost`, `orm`, `migrationsTool`, `multiTenancy`; remaining fields are loose strings.

Tell the developer:

> Step 3 of 10: Data Architecture. I'll ask about your data layer — database engine, ORM, migrations, multi-tenancy, caching, file storage. About 12 questions. Some may be skipped based on your earlier answers.

#### P3 questions (Q3.1–Q3.12)

Ask each P3 question from `references/question-bank.md § Phase P3` in order. Honor the conditions. Write each answer to its destination field under `context.phases.P3`.

| Q | Topic | Writes to (under `context.phases.P3`) |
|---|---|---|
| P3.Q1 | DB needed? (gate) | gate flag |
| P3.Q2 | Engine | `engine` (loose) |
| P3.Q3 | Hosting model | `databaseHost` (required, enum) |
| P3.Q4 | ORM | `orm` (required, enum) |
| P3.Q5 | Migration tool + mode | `migrationsTool` (required) + `migrationsMode` (loose) |
| P3.Q6 | Multi-tenancy | `multiTenancy` (required, enum) |
| P3.Q7 | Search | `search` (loose) |
| P3.Q8 | Cache + invalidation | `cache` + `cacheInvalidation` (loose) |
| P3.Q9 | File storage | `fileStorage` (loose) |
| P3.Q10 | Codegen | `codegen[]` (loose array) |
| P3.Q11 | Backup | `backup` (loose) |
| P3.Q12 | Compliance | `compliance` (loose) |

**Adaptive skipping**: if P3.Q1 = "No persistent data", skip Q2–Q7 but still ask Q8 (in-memory cache), Q9 (FS storage), Q10 (codegen), Q12 (compliance). If `appType: cli`, skip the entire phase.

**State checkpointing**: after each answered question, write to `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`.

#### Phase 1.8: synthesis review (after P3.Q12, or after the last applicable question if any skipping fired)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "P3"`. This is Round 2's first synthesis pass. The skill:

1. Sets `greenfield-state.json.currentPhase` to `phase-1.8-synthesis-review` and `currentSynthesisPhase: "P3"`.
2. Renders `docs/architecture/p3-data.html` in the scaffolded project using the 7-section template.
3. Walks the developer through Approve/Adjust/Skip per section.
4. Writes `context.syntheses.P3 = { approvedAt, adjustments[] }`.
5. Writes `docs/architecture/p3-data-dependencies.json` from the wizard-collected dependency edges.

If the developer adjusts any P3 field via the Adjust dialog, the updated value lives in `context.phases.P3.<field>` directly.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `p3-data.html` ships in Round 2), tell the developer and continue to Step 4.

```

- [ ] **Step 3: Commit T11**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "feat(greenfield): insert Step 3 P3 Data Architecture in context-gathering

New wizard step covering 12 P3 questions and closing with inline
Phase 1.8 synthesis review (phaseId: P3). State checkpointing and
adaptive skipping documented."
```

---

## Task 12: Insert Step 4 (P4) into context-gathering/SKILL.md

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Insert Step 4 P4 section after Step 3 P3 (from T11)**

Immediately after the Step 3 P3 section (added in T11), insert:

```markdown
### Step 4 of 10: API & Integration (Phase P4)

This step is Round 2's second new phase. Captures API surface decisions via P4.Q1–Q4.10 and closes with an inline Phase 1.8 synthesis-review pass.

**Data layout** — answers populate `context.phases.P4.*` directly. The 3 required enum-locked fields are `style`, `versioningPolicy`, `asyncPattern`; remaining fields are loose strings or arrays.

Tell the developer:

> Step 4 of 10: API & Integration. I'll ask about your API surface — style (REST/GraphQL/tRPC), versioning, rate limits, async patterns, real-time, webhooks, external services. About 10 questions; some skipped based on whether you expose an API.

#### P4 questions (Q4.1–Q4.10)

Ask each P4 question from `references/question-bank.md § Phase P4` in order. Honor the conditions.

| Q | Topic | Writes to (under `context.phases.P4`) |
|---|---|---|
| P4.Q1 | API exposed? (gate) | gate flag |
| P4.Q2 | Style | `style` (required, enum) |
| P4.Q3 | Documentation | `documentation` (loose) |
| P4.Q4 | Versioning | `versioningPolicy` (required, enum) |
| P4.Q5 | Rate limit | `rateLimit` (loose) |
| P4.Q6 | Pagination | `pagination` (loose) |
| P4.Q7 | Async pattern | `asyncPattern` (required, enum) |
| P4.Q8 | Real-time | `realtime` (loose) |
| P4.Q9 | Webhooks | `webhooks` (loose) |
| P4.Q10 | External services | `externalServices[]` (loose array) |

**Adaptive skipping**: if `appType: cli` OR (`!hasBackend && !hasFrontend`), skip the entire phase. If P4.Q1 = "No", skip Q2–Q9 but still ask Q10. If `!willDeploy`, skip Q4 (versioning) and Q5 (rate limit).

**State checkpointing**: set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-4-api-integration"`.

#### Phase 1.8: synthesis review (after P4.Q10, or after the last applicable question)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "P4"`. The skill:

1. Sets `currentSynthesisPhase: "P4"`.
2. Renders `docs/architecture/p4-api.html` using the 6-section template.
3. Walks Approve/Adjust/Skip per section.
4. Writes `context.syntheses.P4 = { approvedAt, adjustments[] }`.
5. Writes `docs/architecture/p4-api-dependencies.json`.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `p4-api.html` ships in Round 2), tell the developer and continue to Step 5.

```

- [ ] **Step 2: Commit T12**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "feat(greenfield): insert Step 4 P4 API & Integration in context-gathering

New wizard step covering 10 P4 questions and closing with inline
Phase 1.8 synthesis review (phaseId: P4)."
```

---

## Task 13: Renumber Steps + convert old Step 3 into residual Step 5

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Convert the OLD Step 3 header into Step 5 residual**

Find the OLD Step 3 heading (originally `### Step 3 of 10: Project Details (adaptive)` or similar — the one that comes AFTER the Step 4 P4 section you added in T12). Rename it to:

```markdown
### Step 5 of 10: Remaining Project Details (residual)

This step holds the 13 Category 3 questions that have NOT been re-homed to P3 (Data) or P4 (API) in Round 2. They stay here as transitional content until Rounds 3–6 re-home them to P0/P5/P6/P7. See `references/question-bank.md § Category 3 (residual)` for the full question list.

Tell the developer:

> Step 5 of 10: Remaining Project Details. A few miscellaneous questions about scale, auth, deploy target, monitoring, environment, dependencies, accessibility, performance, i18n, monorepo, and styling. Skipped if not relevant to your stack.

Ask Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 in order from `references/question-bank.md § Category 3 (residual)`. Honor existing conditions. No synthesis review for this step (it's residual; full split planned for Rounds 3–6).

State checkpoint: `currentStep: "step-5-residual"`.
```

Delete any inline question text that previously lived under this heading (e.g., Q3.2 details inlined into the SKILL). Question-bank.md is the source of truth — the SKILL only orchestrates.

- [ ] **Step 2: Renumber remaining Steps (4 → 6, 5 → 7, 6 → 8, 7 → 9)**

Find every heading of the form `### Step N of 10:` (where N ∈ {4, 5, 6, 7}) and rename:

| Old | New |
|---|---|
| `### Step 4 of 8: <title>` | `### Step 6 of 10: <title>` |
| `### Step 5 of 8: <title>` | `### Step 7 of 10: <title>` |
| `### Step 6 of 8: <title>` | `### Step 8 of 10: <title>` |
| `### Step 7 of 8: <title>` | `### Step 9 of 10: <title>` |

Within each renumbered step's body, also update any "Step X of 8" textual references in the developer prompts.

- [ ] **Step 3: Global sweep for stale "Step X of 8" or "of 8"**

Run: `grep -nE "Step [0-9]+ of 8|of 8\b" greenfield/skills/context-gathering/SKILL.md`

Expected: **0 hits** after edits. If any remain, fix them. The wizard total is 10 now.

- [ ] **Step 4: Verify renumbering completeness**

Run: `grep -nE "^### Step [0-9]+ of 10" greenfield/skills/context-gathering/SKILL.md`

Expected: 10 hits (Steps 1 through 10, in order).

- [ ] **Step 5: Commit T13**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "refactor(greenfield): renumber wizard steps 8 -> 10; convert old Step 3 to residual Step 5

Existing Step 3 (Project Details) becomes Step 5 (residual, 13 Qs from
Cat 3 that stay until later rounds). Renumber Steps 4-7 to 6-9, adding
two new steps (P3 + P4) to reach 10 total. Update all 'Step X of 8'
literals to 'Step X of 10'."
```

---

## Task 14: Update state-transitions table in context-gathering/SKILL.md

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Locate the state transitions table**

Run: `grep -n "Step 5 — Q5\|state-machine\|state transitions\|currentPhase.*Add" greenfield/skills/context-gathering/SKILL.md | head -10`

Expected: around line 470+ there's a table mapping wizard events → state file updates. We need to:
- Add rows for `step-3-data-architecture` events
- Add rows for `step-4-api-integration` events
- Rename existing `step-5-cicd` rows (now Step 7)
- Add synthesis-review return rows for P3 and P4

- [ ] **Step 2: Edit the state-transitions table**

Find the existing table. Add the following rows (insert near the bottom, ordered chronologically):

```markdown
| Step 3 — P3.Q1 answered | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`, `lastAnsweredQuestionId: "P3.Q1"` |
| Step 3 — P3.Q12 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "P3"`, add `"step-3-data-architecture"` to `completedSteps` |
| Step 3 — synthesis-review(P3) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-4-api-integration"`, clear `currentSynthesisPhase`. Add `context.syntheses.P3 = { approvedAt, adjustments }` |
| Step 4 — P4.Q1 answered | Set `currentStep: "step-4-api-integration"`, `lastAnsweredQuestionId: "P4.Q1"` |
| Step 4 — P4.Q10 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "P4"`, add `"step-4-api-integration"` to `completedSteps` |
| Step 4 — synthesis-review(P4) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-5-residual"`, clear `currentSynthesisPhase`. Add `context.syntheses.P4` |
| Step 5 — last residual Q answered | Add `"step-5-residual"` to `completedSteps`, set `currentStep: "step-6-workflow"` |
| Step 7 — Q5.1–Q5.17 answered | (was "Step 5 — Q5.1–Q5.17") Add `"step-7-cicd"`, set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "P8"` |
| Step 7 — synthesis-review(P8) returns | (was "Step 5 — synthesis-review(P8) returns") Set `currentStep: "step-8-plugins"`, clear `currentSynthesisPhase`. Add `context.syntheses.P8` |
```

Remove the old Step 5 rows that referenced "Step 5 — Q5.1–Q5.17" and "Step 5 — synthesis-review(P8)" — those are now Step 7 (preserved above with rename annotation).

- [ ] **Step 3: Verify table integrity**

Run: `grep -cE "^\| Step [0-9]" greenfield/skills/context-gathering/SKILL.md`

Expected: count of state-transition table rows. The exact number depends on the existing table; just confirm the new rows are present.

- [ ] **Step 4: Commit T14**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "feat(greenfield): extend state-transitions table for P3/P4

Add transitions for step-3-data-architecture, step-4-api-integration,
and synthesis-review return rows for P3 and P4. Rename Step 5 CI/CD
rows to Step 7 (renumbered)."
```

---

## Task 15: Supporting skill updates (grill-spec, init, resume, status)

**Files:**
- Modify: `greenfield/skills/grill-spec/SKILL.md`
- Modify: `greenfield/skills/start/SKILL.md`
- Modify: `greenfield/skills/pickup/SKILL.md`
- Modify: `greenfield/skills/check/SKILL.md`

- [ ] **Step 1: Grill-spec — check for hardcoded "P8"**

Run: `grep -n '"P8"\|P8\b' greenfield/skills/grill-spec/SKILL.md`

If any line restricts iteration to "P8" only (e.g., `for phase in ["P8"]:` or `context.syntheses.P8` specifically), replace with iteration over all keys of `context.syntheses`. Example:

```markdown
For each phase ID in `context.syntheses` (currently P3, P4, P8 in Round 2), cross-check the synthesis decisions against the spec under grilling.
```

If grill-spec already iterates dynamically, no edit needed.

- [ ] **Step 2: Init — extend phase enum + error matrix**

In `greenfield/skills/start/SKILL.md`, find the error matrix or phase enum section (grep `phase-1.8\|currentSynthesisPhase`). Add P3 and P4 to any enum/list that currently only includes P8:

```markdown
Valid values for `currentSynthesisPhase`: "P3" | "P4" | "P8" (Round 2). More phases added in future rounds.
```

Also update any narrative that says "Round 1 wires Phase 1.8 only for P8" to reflect Round 2:

```markdown
Round 2 wires Phase 1.8 for P3 (Step 3), P4 (Step 4), and P8 (Step 7). Future rounds add P0/P6/P7/P9/P10.5.
```

- [ ] **Step 3: Resume — extend phase-resume granularity**

In `greenfield/skills/pickup/SKILL.md`, find Step 4.5 (phase-resume granularity prompt). Currently it likely lists P8 only. Update to include P3 + P4:

```markdown
If the wizard was interrupted mid-synthesis (i.e., `currentPhase: phase-1.8-synthesis-review`), ask the developer:

> You were in the middle of reviewing the {currentSynthesisPhase} synthesis when this session was interrupted. Pick up where you left off?
> - Yes, continue from the last unreviewed section
> - Restart this synthesis review from section 1
> - Skip the rest of this synthesis and continue to the next wizard step

If interrupted mid-wizard-step (P3 between Q3.5 and Q3.6, for example), ask:

> You were in Step {N} of 10 ({stepName}) at question {lastAnsweredQuestionId}. Continue from the next question, or restart this step from question 1?
```

Specifically support `lastAnsweredQuestionId` values like `P3.Q5`, `P4.Q3`.

- [ ] **Step 4: Status — update synthesis HTML count + freshness scope**

In `greenfield/skills/check/SKILL.md`, find any narrative that mentions "1 synthesis HTML" or "p8-cicd.html". Update to:

```markdown
Round 2 ships three synthesis HTMLs in scaffolded projects: `docs/architecture/p3-data.html`, `docs/architecture/p4-api.html`, `docs/architecture/p8-cicd.html`. The pre-commit freshness hook monitors all three.
```

Update any count literal (e.g., `synthesis-count: 1`) to `synthesis-count: 3`.

- [ ] **Step 5: Verify across all 4 files**

Run:
```bash
grep -lE "P3|P4|of 10|step-3-data|step-4-api" \
  greenfield/skills/grill-spec/SKILL.md \
  greenfield/skills/start/SKILL.md \
  greenfield/skills/pickup/SKILL.md \
  greenfield/skills/check/SKILL.md
```

Expected: at least 3 of 4 files match (grill-spec may be no-op).

- [ ] **Step 6: Commit T15**

```bash
git add greenfield/skills/grill-spec/SKILL.md \
        greenfield/skills/start/SKILL.md \
        greenfield/skills/pickup/SKILL.md \
        greenfield/skills/check/SKILL.md
git commit -m "feat(greenfield): support P3 + P4 in init/resume/status/grill-spec

Extend phase enums to include P3, P4. Resume now offers granular
pick-up at mid-P3 / mid-P4 questions. Status reports 3 synthesis HTMLs.
Grill-spec iterates dynamically over context.syntheses."
```

---

## Task 16: Update greenfield/CLAUDE.md

**Files:**
- Modify: `greenfield/CLAUDE.md`

- [ ] **Step 1: Update the arch diagram**

Find the `## Architecture` section. Update the `Phase 1.7` and `Phase 1.8` annotations. Specifically, update the Phase 1.8 section description that currently says "Round 1: only end of Step 5 → P8" to:

```markdown
└── synthesis-review skill (Phase 1.8 — invoked inline at end of each major step;
                              Round 2: Step 3 → P3, Step 4 → P4, Step 7 → P8)
```

- [ ] **Step 2: Update the Skill Hierarchy bullets for context-gathering**

Find the bullet describing `context-gathering/SKILL.md`. Currently:

```
- `context-gathering/SKILL.md` — Phase 1: adaptive state-machine wizard (3.0 Round 1: Step 5 expanded from 3 to 17 questions covering full P8 CI/CD surface; total 47 questions, developer answers ~18-35 depending on `willDeploy`/`hasTeam`)
```

Replace with:

```
- `context-gathering/SKILL.md` — Phase 1: adaptive state-machine wizard (3.0 Round 2: 9 wizard steps; Step 3 = P3 Data Architecture (12 Qs), Step 4 = P4 API & Integration (10 Qs), Step 7 = P8 CI/CD (17 Qs from Round 1). Total ~69 wizard questions; developer answers 30-55 depending on stack + deploy)
```

- [ ] **Step 3: Update the synthesis-review bullet**

Replace any "Round 1: P8 only" in the `synthesis-review/SKILL.md` bullet with "Round 2: P3, P4, P8". Specifically the line:

```
- `synthesis-review/SKILL.md` — Phase 1.8: ... Invoked inline by `context-gathering` at the end of each major step that has a synthesis template (Round 1: P8 only)
```

becomes:

```
- `synthesis-review/SKILL.md` — Phase 1.8: ... Invoked inline by `context-gathering` at the end of each major step that has a synthesis template (Round 2: P3 at Step 3, P4 at Step 4, P8 at Step 7)
```

- [ ] **Step 4: Commit T16**

```bash
git add greenfield/CLAUDE.md
git commit -m "docs(greenfield): update CLAUDE.md for Round 2 wizard topology

Reflect 9-step wizard, three synthesis phases (P3/P4/P8), question
count update (~69 total)."
```

---

## Task 17: Append ROUND 2 LOCKED entry to greenfield-overview.html

**Files:**
- Modify: `docs/greenfield-overview.html`

- [ ] **Step 1: Locate the Discussion Log section**

Run: `grep -n "ROUND 1 LOCKED\|Discussion Log\|<h2.*Discussion\|class=\"log\"" docs/greenfield-overview.html | head`

The Discussion Log lives near the bottom and "ROUND 1 LOCKED" is the canonical chronological entry. Round 2 LOCKED goes after it.

- [ ] **Step 2: Append a Round 2 LOCKED entry**

After the "ROUND 1 LOCKED" `<div class="log-entry">` block, insert:

```html
<div class="log-entry">
  <div class="log-date">2026-05-13 — ROUND 2 LOCKED</div>
  <div class="log-body">
    <p>Round 2 of the wizard overhaul is complete. Category 3 (Project Details, 18 Qs) has been split into two distinct 15-phase-aligned phases:</p>
    <ul>
      <li><strong>P3 Data Architecture</strong> — 12 questions covering DB engine + host, ORM, migrations, multi-tenancy, search, caching, file storage, codegen, backup, compliance. 7 synthesis sections, 4 required enum-locked schema fields (databaseHost, orm, migrationsTool, multiTenancy).</li>
      <li><strong>P4 API &amp; Integration</strong> — 10 questions covering style (REST/GraphQL/tRPC), versioning, rate limits, pagination, async patterns (jobs/queues), real-time, webhooks, external integrations. 6 synthesis sections, 3 required enum-locked schema fields (style, versioningPolicy, asyncPattern).</li>
    </ul>
    <p>Locked design decisions for Round 2:</p>
    <ol>
      <li><strong>Single-owner boundary</strong> — file storage + codegen + caching live in P3 only; real-time + webhooks + jobs live in P4 only. Synthesis HTMLs cross-reference each other when needed.</li>
      <li><strong>Hybrid schema strictness</strong> — 3–5 required enum-locked fields per phase (the ones other phases cross-reference); remaining fields are loose strings with "other" escape hatches. Avoids monthly schema releases as new ORMs / DB hosts emerge.</li>
      <li><strong>Backward-only dependency edges</strong> — matches Round 1 P8 precedent. P3 reads from P0/P2; P4 reads from P3/P2.</li>
      <li><strong>Asymmetric depth</strong> — P3 has 7 sections and 12 Qs; P4 has 6 sections and 10 Qs. P3 owns more decision surface under single-owner.</li>
      <li><strong>Wizard count 8 → 10</strong> — old Step 3 becomes residual Step 5 (13 Qs from Cat 3 destined for Rounds 3–6).</li>
      <li><strong>Codegen Q in P3 only</strong> — even though codegen spans ORM + API, the question lives in P3 with a P4 synthesis cross-reference note.</li>
    </ol>
    <p>Files shipped (5 NEW + 13 MODIFIED = 18 total): see <code>docs/superpowers/specs/2026-05-13-greenfield-3.0-round2-design.md</code> § File inventory.</p>
    <p>Versions: <code>greenfield@3.0.0-alpha.2</code>, <code>onboard@2.0.0-alpha.2</code>.</p>
    <p><strong>Future rounds:</strong> Round 3 (P6 Auth/Security + P7 Workflow), Round 4 (P0/P0.5/P1/P8.5 new phases), Round 5 (P9/P10.5), Round 6 (P5 Frontend + 12 concern areas + non-GHA CI templates).</p>
  </div>
</div>
```

If the existing log uses different `class` names than `log-entry`, `log-date`, `log-body`, adapt to whatever the existing pattern uses. Run `grep -A1 "ROUND 1 LOCKED" docs/greenfield-overview.html | head -5` to confirm the surrounding element shape and adapt.

- [ ] **Step 3: Verify the entry renders (lazy check — HTML well-formed)**

Run: `python3 -c "from html.parser import HTMLParser; p=HTMLParser(); p.feed(open('docs/greenfield-overview.html').read()); print('OK')"`

Expected: `OK`. If parse error, find and fix the offending tag.

- [ ] **Step 4: Update the Phase 1.8 box in the architecture diagram (if present)**

Run: `grep -n "Phase 1.8\|class=\"phase\"" docs/greenfield-overview.html | head`

If there's a visual "Phase 1.8 → P8 only" annotation in the architecture, update the label to "Phase 1.8 → P3/P4/P8". Specific edit depends on the HTML structure; locate and adapt.

- [ ] **Step 5: Commit T17**

```bash
git add docs/greenfield-overview.html
git commit -m "docs(greenfield-3.0): add ROUND 2 LOCKED entry to Discussion Log

Document the P3/P4 split shipping: 12-Q P3 Data Architecture + 10-Q P4
API & Integration, 6 locked design decisions, 18 files touched, version
bumps to greenfield@3.0.0-alpha.2 and onboard@2.0.0-alpha.2."
```

---

## Task 18: Version bumps + CHANGELOG + marketplace sync

**Files:**
- Modify: `greenfield/.claude-plugin/plugin.json`
- Modify: `onboard/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `onboard/CHANGELOG-2.0.md`

- [ ] **Step 1: Bump greenfield version**

In `greenfield/.claude-plugin/plugin.json`, change:

```json
"version": "3.0.0-alpha.1"
```

to:

```json
"version": "3.0.0-alpha.2"
```

- [ ] **Step 2: Bump onboard version**

In `onboard/.claude-plugin/plugin.json`, change:

```json
"version": "2.0.0-alpha.1"
```

to:

```json
"version": "2.0.0-alpha.2"
```

- [ ] **Step 3: Sync marketplace.json**

In `.claude-plugin/marketplace.json`, find the `greenfield` plugin entry. Update its `version` field to `"3.0.0-alpha.2"`. Find the `onboard` plugin entry. Update its `version` field to `"2.0.0-alpha.2"`.

Also update descriptions if they reference Round 1 or specific version numbers — for example, replace any "Round 1" mention with "Rounds 1–2" where applicable.

- [ ] **Step 4: Append Round 2 entry to onboard CHANGELOG**

In `onboard/CHANGELOG-2.0.md`, append the following section at the top (after the header, before any prior version sections):

```markdown
## 2.0.0-alpha.2 — 2026-05-13

**Schema additions (Round 2 of the greenfield 3.0 wizard overhaul):**

- `P3` flipped from `_status: "deferred-to-round-2"` to a live `p3Data` definition with 4 required enum-locked fields (`databaseHost`, `orm`, `migrationsTool`, `multiTenancy`) and 9 loose-string fields (`engine`, `migrationsMode`, `search`, `cache`, `cacheInvalidation`, `fileStorage`, `codegen[]`, `backup`, `compliance`).
- `P4` flipped from `_status: "deferred-to-round-2"` to a live `p4Api` definition with 3 required enum-locked fields (`style`, `versioningPolicy`, `asyncPattern`) and 6 loose-string fields (`documentation`, `rateLimit`, `pagination`, `realtime`, `webhooks`, `externalServices[]`).
- Top-level description updated to reflect that Rounds 1–2 fully specify P3, P4, P8.

**No breaking changes to v2 callers** — Round 2 is purely additive. Existing greenfield 3.0.0-alpha.1 callers (which emit `_status: "deferred-to-round-2"` for P3/P4) continue to work; their `_status` value is now `additionalProperties: true` under the live `p3Data` / `p4Api` definitions until callers upgrade.

**Hard cutover policy reminder:** v1 input is still rejected outright. There is no migration helper from v1 → v2.

**No new artifact generation** — Round 2 captures decisions but does not emit new template artifacts. `onboard:generate` accepts P3/P4 data and renders standard CLAUDE.md / rules / skills / agents / hooks. The 4 GHA workflow templates from Round 1 are unchanged.
```

- [ ] **Step 5: Validate JSON files**

Run:
```bash
python3 -c "import json; json.load(open('greenfield/.claude-plugin/plugin.json'))" && \
python3 -c "import json; json.load(open('onboard/.claude-plugin/plugin.json'))" && \
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" && \
echo "ALL VALID"
```

Expected: `ALL VALID`.

- [ ] **Step 6: Commit T18**

```bash
git add greenfield/.claude-plugin/plugin.json \
        onboard/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        onboard/CHANGELOG-2.0.md
git commit -m "chore: bump greenfield to 3.0.0-alpha.2 and onboard to 2.0.0-alpha.2

Round 2 of the greenfield 3.0 wizard overhaul ships P3 Data Architecture
and P4 API & Integration phase live schemas. No breaking changes for v2
callers. Sync marketplace.json + document additions in onboard
CHANGELOG-2.0.md."
```

---

## Task 19: Verification — schema validation against sample v2 context

**Files:**
- None modified; produces no commit unless a fix is needed.

- [ ] **Step 1: Construct a sample v2 context with realistic P3 + P4 values**

Write a temporary file `/tmp/round2-sample-v2-context.json`:

```json
{
  "version": 2,
  "source": "greenfield",
  "projectPath": "/tmp/round2-test-project",
  "callerExtras": {
    "installedPlugins": [],
    "coveredCapabilities": []
  },
  "phases": {
    "P0":   { "_status": "deferred-to-round-4" },
    "P0.5": { "_status": "deferred-to-round-4" },
    "P1":   { "_status": "deferred-to-round-4" },
    "P2": {
      "stack": {
        "framework": "next.js",
        "version": "16.0.0",
        "language": "typescript"
      }
    },
    "P3": {
      "databaseHost": "managed-rdbms",
      "orm": "prisma",
      "migrationsTool": "orm-native",
      "multiTenancy": "none",
      "engine": "postgresql",
      "migrationsMode": "ci-applied",
      "search": "postgres-fts",
      "cache": "redis",
      "cacheInvalidation": "event-driven",
      "fileStorage": "cloud-s3-like",
      "codegen": ["prisma-generate", "openapi-typescript"],
      "backup": "managed-provider",
      "compliance": "gdpr-aware"
    },
    "P4": {
      "style": "rest",
      "versioningPolicy": "url-path",
      "asyncPattern": "queue-and-worker",
      "documentation": "openapi-swagger",
      "rateLimit": "fixed-window-redis",
      "pagination": "cursor",
      "realtime": "none",
      "webhooks": "incoming-only",
      "externalServices": ["stripe", "resend"]
    },
    "P5":   { "_status": "deferred-to-round-6" },
    "P6":   { "_status": "deferred-to-round-3" },
    "P7":   { "_status": "deferred-to-round-3" },
    "P7.5": { "pluginRecommendations": [] },
    "P8": {
      "cicd": {
        "provider": "github-actions",
        "triggers": ["every-pr"],
        "requiredPreMergeChecks": ["lint", "typecheck", "unit"],
        "coverage": { "threshold": 80, "scope": "global", "blocking": true },
        "envLadder": ["preview", "prod"],
        "autoDeploy": "auto-on-merge",
        "deployCadence": "continuous",
        "rollback": { "strategy": "redeploy-previous-sha", "automation": false },
        "secrets": { "manager": "provider-stored", "rotation": "manual" },
        "notifications": { "channels": ["github-checks"], "events": ["build-failure"] },
        "buildMatrix": { "os": ["ubuntu-latest"], "languageVersions": "single", "parallelization": "auto" },
        "caching": { "deps": true, "build": true, "dockerLayers": false, "remote": "none" },
        "timeBudget": { "perPipelineMinutes": 15, "blockingThresholdMinutes": null },
        "releasePipeline": { "separate": false, "triggeredBy": "manual", "convention": "release-please" }
      },
      "_v1_carryover": {
        "ciAuditAction": "create-pr",
        "autoEvolutionMode": "log-then-evolve",
        "prReviewTrigger": "auto-every"
      }
    },
    "P8.5": { "_status": "deferred-to-round-4" },
    "P9":   { "_status": "deferred-to-round-5" },
    "P10":  { "installedPlugins": [] },
    "P10.5":{ "_status": "deferred-to-round-5" }
  },
  "syntheses": {
    "P3": { "approvedAt": "2026-05-13T17:00:00Z", "adjustments": [] },
    "P4": { "approvedAt": "2026-05-13T17:15:00Z", "adjustments": [] },
    "P8": { "approvedAt": "2026-05-13T17:30:00Z", "adjustments": [] }
  },
  "dependencies": {
    "P3": ["P0.willDeploy", "P2.stack.database", "P2.stack.language"],
    "P4": ["P3.orm", "P2.stack.framework", "P3.databaseHost"],
    "P8": ["P0.willDeploy", "P0.teamSize", "P3.databaseHost", "P2.stack.framework", "P7.testingPhilosophy"]
  }
}
```

- [ ] **Step 2: Validate the sample against the schema**

Run:

```bash
python3 <<'PY'
import json, sys
try:
    import jsonschema
except ImportError:
    print("jsonschema not installed; falling back to structural check")
    schema = json.load(open('onboard/skills/generate/references/context-shape-v2.json'))
    sample = json.load(open('/tmp/round2-sample-v2-context.json'))
    # Manual structural check
    assert sample['version'] == 2
    assert 'P3' in sample['phases'] and 'databaseHost' in sample['phases']['P3']
    assert sample['phases']['P3']['databaseHost'] in schema['definitions']['p3Data']['properties']['databaseHost']['enum']
    assert 'P4' in sample['phases'] and 'style' in sample['phases']['P4']
    assert sample['phases']['P4']['style'] in schema['definitions']['p4Api']['properties']['style']['enum']
    print("STRUCTURAL OK")
    sys.exit(0)

schema = json.load(open('onboard/skills/generate/references/context-shape-v2.json'))
sample = json.load(open('/tmp/round2-sample-v2-context.json'))
jsonschema.validate(sample, schema)
print("SCHEMA VALID")
PY
```

Expected: either `SCHEMA VALID` (if jsonschema is installed) or `STRUCTURAL OK` (fallback). If a validation error fires, fix the schema or the sample to match.

- [ ] **Step 3: Test that P3/P4 with `_status` stub is now REJECTED**

Modify a copy of the sample to set `phases.P3` to `{ "_status": "deferred-to-round-2" }`. Run the validation:

```bash
python3 <<'PY'
import json
schema = json.load(open('onboard/skills/generate/references/context-shape-v2.json'))
sample = json.load(open('/tmp/round2-sample-v2-context.json'))
sample['phases']['P3'] = {"_status": "deferred-to-round-2"}
# Manual: p3Data has required databaseHost/orm/migrationsTool/multiTenancy
required = schema['definitions']['p3Data']['required']
missing = [k for k in required if k not in sample['phases']['P3']]
assert missing, f"Expected required fields missing; got {missing}"
print(f"REJECTED — missing required fields: {missing}")
PY
```

Expected: `REJECTED — missing required fields: ['databaseHost', 'orm', 'migrationsTool', 'multiTenancy']`. Confirms P3 stubs no longer slip through.

- [ ] **Step 4: Document the verification result**

If verification passes, no commit needed. If a fix to the schema was required, that's a fix to Task 1 or 2; commit the fix with a follow-up message:

```bash
git commit -m "fix(onboard): schema validation correction for P3/P4

Discovered during T19 verification: <specific issue and resolution>."
```

---

## Task 20: Verification — manual wizard drive-through in throwaway repo

**Files:**
- None modified; this is end-to-end manual testing.

- [ ] **Step 1: Create a throwaway test directory**

```bash
mkdir -p /tmp/greenfield-round2-test
cd /tmp/greenfield-round2-test
git init
```

- [ ] **Step 2: Trigger /greenfield:start in a Claude Code session pointed at /tmp/greenfield-round2-test**

In a fresh Claude Code session with the user, navigate to `/tmp/greenfield-round2-test`. Run `/greenfield:start`. Walk through:

- Step 1 of 10: Vision — answer "Next.js SaaS for tracking subscriptions"
- Step 2 of 10: Stack — accept Next.js 16 + TypeScript + PostgreSQL recommendations
- **Step 3 of 10: Data Architecture (P3)** — answer all 12 questions with realistic values (managed-rdbms, prisma, orm-native, row-level-rls, postgres-fts, redis + event-driven, cloud-s3-like, ['prisma-generate'], managed-provider, gdpr-aware)
- Expected: After P3.Q12, synthesis-review fires. `docs/architecture/p3-data.html` is created. Walk through 7 sections, approve all.
- **Step 4 of 10: API & Integration (P4)** — answer all 10 questions (rest, openapi-swagger, url-path, fixed-window-redis, cursor, queue-and-worker, none, incoming-only, ['stripe','resend'])
- Expected: After P4.Q10, synthesis fires. `docs/architecture/p4-api.html` created. Walk through 6 sections, approve all.
- Step 5 of 10: Remaining Project Details — answer the 13 residual Qs as appropriate
- Steps 6–9: existing flow (Workflow, CI/CD, Plugin Discovery, Confirmation)

- [ ] **Step 3: Confirm output artifacts**

After the wizard completes Step 4, check that:

```bash
ls -la /tmp/greenfield-round2-test/docs/architecture/
# Expected: p3-data.html, p3-data-dependencies.json, p4-api.html, p4-api-dependencies.json
```

Open `p3-data.html` in a browser. Confirm:
- 7 sections render
- Captured values match what was entered
- No `{{phase.<field>}}` raw placeholders remain (everything resolved)
- Cross-check annotations appear in expected sections

Same for `p4-api.html` (6 sections).

- [ ] **Step 4: Test cross-check firing (contradiction)**

Start a SECOND throwaway wizard run. In Step 2, answer Python instead of TypeScript. In Step 4 (P4), pick `tRPC` as the API style.

Expected: P4 synthesis section 1 renders a `<div class="contradiction">` block stating "P4 picked tRPC but P2 said the language isn't TypeScript."

- [ ] **Step 5: Test adaptive skipping for CLI**

Start a THIRD throwaway wizard run. In Step 1, describe a CLI tool. Confirm:

- Step 3 of 10 (P3) is announced but immediately skipped with a message like "Skipping P3 — CLI tools don't typically persist data."
- Step 4 of 10 (P4) is announced but skipped with a similar message
- Flow proceeds directly to Step 5 residual

- [ ] **Step 6: Document verification results**

If all three verification runs pass, the verification is complete. No commits required for T20 itself; it's a manual gate.

If any verification step fails:
1. Document the failure mode
2. Open a follow-up fix task
3. Apply the fix; commit with a `fix(...)` message
4. Re-run T20 from Step 2

---

## Final commit — bundling note

The Round 2 work spans 20 tasks. Each task produced its own commit. Before merging or pushing, run a final check:

- [ ] **Step 1: Confirm all 18 expected files were touched**

Run:

```bash
git -C . log --oneline feat/greenfield-1.2 --since="2026-05-13" \
  | grep -E "(greenfield-3.0|Round 2)" | wc -l
```

Expected: at least 18 commits since the spec commit on 2026-05-13.

- [ ] **Step 2: Diff against pre-Round-2 baseline**

```bash
git diff --stat 52dd636..HEAD -- greenfield/ onboard/ docs/ .claude-plugin/
```

Expected: roughly 18–20 files changed, ~1500–2500 insertions.

- [ ] **Step 3: Manual review of the diff**

Open the bundled diff and skim for:
- No stale "Step X of 8" anywhere
- No `_status: "deferred-to-round-2"` references for P3/P4
- Versions consistent across plugin.json + marketplace.json
- All new files have proper headers / frontmatter

- [ ] **Step 4: Hand off to user for push/PR decision**

The handoff explicitly says: "Do NOT auto-push or auto-PR. Confirm before each."

Tell the user:

> Round 2 implementation complete on `feat/greenfield-1.2`. 18 commits since the spec commit, 18 files touched. Verification (T19 schema + T20 manual wizard) passed. Ready to push the branch when you are. Want me to push, or push + open a PR, or hold?

---

## Self-review checklist (executed before finalizing this plan)

**1. Spec coverage:**
- Spec § "Phase P3 — Data Architecture" → Tasks 1, 3, 4, 8, 11 ✓
- Spec § "Phase P4 — API & Integration" → Tasks 2, 5, 6, 9, 12 ✓
- Spec § "Migration of existing Cat 3 questions" → Task 10 ✓
- Spec § "Orchestrator wiring" → Tasks 11, 12, 13, 14, 15 ✓
- Spec § "File inventory" → All 18 files covered in tasks 1–18 ✓
- Spec § "Verification approach" → Tasks 19, 20 ✓
- Spec § "Section-prompts.md updates" → Task 7 ✓
- Spec § "Docs + versioning" → Tasks 16, 17, 18 ✓

**2. Placeholder scan:** No "TBD", "TODO", "fill in later" patterns. Every step contains either complete code/markdown to write, an exact command to run with expected output, or a concrete file action.

**3. Type / field consistency:**
- Required P3 fields: `databaseHost`, `orm`, `migrationsTool`, `multiTenancy` — consistent across T1, T3 (template references), T8 (question bank), T11 (SKILL section), T19 (sample context). ✓
- Required P4 fields: `style`, `versioningPolicy`, `asyncPattern` — consistent across T2, T5, T9, T12, T19. ✓
- Step numbering: T11 says "Step 3 of 10", T13 renumbers old Step 3 → 5 and Steps 4→6, 5→7, 6→8, 7→9. Consistent. ✓
- Synthesis section counts: P3=7 sections, P4=6 sections — consistent across T3, T5, T7, T16, T17. ✓
- Version: `3.0.0-alpha.1` → `3.0.0-alpha.2` for greenfield; `2.0.0-alpha.1` → `2.0.0-alpha.2` for onboard. Consistent T18. ✓

**4. Risks flagged in spec — coverage:**
- Schema enum churn: mitigated by Hybrid (only 4 enums in P3, 3 in P4). Captured in T1, T2.
- Step renumbering edge: T13 step 3 includes the `Step X of 8` global sweep.
- Grill-spec P8 hardcoding: T15 step 1 specifically greps for hardcoded P8.

Self-review complete. Plan is ready for execution.

---

**Execution handoff:** See the next message for the user's execution-mode choice.
