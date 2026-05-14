# Greenfield Question Bank

Complete catalog of Phase 1 questions with conditions, options, and downstream effects. The wizard is an adaptive state machine — each answer updates the context object, and subsequent questions check preconditions before being asked.

> **Q-ID convention**: Question identifiers (e.g., `P3.Q1`, `P4.Q5`) intentionally retain the P-code prefix as a stable internal reference. Topic-name labels (`dataArchitecture`, `apiIntegration`, `cicdAndDelivery`) are used for everything else — schema keys, dependency paths, filenames, user-facing labels. Q-IDs are never surfaced to the user; they exist purely as durable cross-reference handles for adaptive-skipping rules, state-transitions, and tests.

## Context Object

The wizard maintains a running context that accumulates through the conversation:

```json
{
  "appType": null,
  "appDescription": null,
  "hasBackend": false,
  "hasFrontend": false,
  "isLocal": false,
  "isProduction": false,
  "hasTeam": false,
  "willDeploy": false,
  "hasDatabase": false,
  "hasAPI": false,
  "stackResearch": null
}
```

Each answer updates this context. Questions use the context to determine whether to ask or skip.

---

## Category 1: Project Vision (always asked)

### Q1.1: "What do you want to build?"
- **Type**: Open-ended
- **Condition**: Always (first question)
- **Updates**: `appDescription`, infers `appType` (web-app, api, cli, library, fullstack, mobile-backend)
- **Downstream**: Informs stack recommendation, shapes security suggestion, determines which agents to generate
- **Default**: (skip with Enter — open-ended; no meaningful default for "what do you want to build")

### Q1.2: "Who is this for? What problem does it solve?"
- **Type**: Open-ended
- **Condition**: If Q1.1 is vague or doesn't clarify target users
- **Updates**: Refines `appType`, informs security level (B2B → higher)
- **Default**: (skip with Enter — open-ended context question; any placeholder would be misleading)

---

## Category 2: Tech Stack (always asked)

### Q2.1: "Do you have a tech stack in mind, or would you like me to recommend one?"
- **Type**: Choice
- **Options**: "I know what I want" | "Recommend something" | "I have a partial idea"
- **Condition**: Always
- **Downstream**: Triggers stack-researcher agent
- **Default**: `"Recommend something"` (always — greenfield opinion: most developers benefit from an opinionated recommendation before committing)

### Q2.2: "What's your tech stack?"
- **Type**: Open-ended
- **Condition**: If Q2.1 = "I know" or "partial idea"
- **Updates**: `hasFrontend`, `hasBackend`, `hasAPI`, framework/language details
- **Downstream**: stack-researcher agent researches each technology
- **Default**: (skip with Enter — open-ended; only asked when dev explicitly says they know the stack)

**>>> RESEARCH PAUSE**: After Q2.1/Q2.2, launch the stack-researcher agent. Wait for research results before continuing.

### Q2.3: "For [framework], the current version is [X]. The official scaffold CLI is [Y]. Should I use that?"
- **Type**: Choice
- **Options**: "Use [scaffold CLI]" (recommended) | "Start from scratch" | "I have a template" | "Let's discuss"
- **Condition**: Always (after research)
- **Updates**: `scaffoldMethod`, `scaffoldCLI`
- **Default**: `"Use [scaffold CLI]"` (always — greenfield opinion: the official CLI is the lowest-friction, most up-to-date starting point; "start from scratch" only wins for unusual stacks)

---

## Step 2.5: Architectural Framing (4 questions)

Step 2.5 of the 11-step wizard. Gathers the early architectural choices that inform all detailed phases (P3–P9): service topology, deployment shape, and scale target. Synthesis review fires inline after the last question.

Writes to `context.phases.architecturalFraming.*`. See `onboard/skills/generate/references/context-shape-v2.json` § `architecturalFraming` for the schema.

### AF.Q1: "What's your service topology?"
- **Type**: Choice
- **Options**: "Monolith (single deployable unit)" | "Modular monolith (internal modules, single deploy)" | "Microservices (independent services, independent deploys)" | "Serverless (function-per-endpoint, no persistent server)"
- **Condition**: Always (gate question for the step)
- **Updates**: `context.phases.architecturalFraming.topology` (required, enum)
- **Downstream effects**: All detailed phases (P3–P9) read topology. Microservices + monolith DB contradict; serverless + ORM-native migrations produce a note; monolith is the recommended default for solo or startup projects.
- **Recommend**: Lead with monolith for solo developers (`isProduction: false` or `teamSize = solo-or-pair`); serverless for `appType: api` with `scaleTarget: startup`; microservices only for `teamSize: 5+` or when the user explicitly identifies independently-scalable domains.
- **Default**: `"Monolith"`
  - If `hasTeam: true` AND `architecturalFraming.scaleTarget: "enterprise"` → `"Modular monolith"`
  - If `appType: "api"` AND `architecturalFraming.scaleTarget: "startup"` → `"Serverless"`
  - Else → `"Monolith"` (greenfield opinion: the simplest topology that can grow; avoid premature distribution)

### AF.Q2: "What's your deployment shape?"
- **Type**: Choice
- **Options**: "Single-region (one cloud region, simplest)" | "Multi-region (active/active or active/passive across regions)" | "Edge-distributed (CDN edge workers, globally distributed)" | "On-premises (self-managed infrastructure)"
- **Condition**: NOT (`appType: cli`). If `willDeploy = false`, default to `"single-region"` and note rather than asking.
- **Updates**: `context.phases.architecturalFraming.deploymentShape` (required, enum)
- **Downstream effects**: cicdAndDelivery reads for env ladder and rollback strategy; dataArchitecture reads for DB hosting model compatibility.
- **Recommend**: Single-region unless `scaleTarget: enterprise` or user explicitly names a global user base. Edge-distributed is powerful but constrains ORM options (Prisma + serverless edge drivers; SQLAlchemy not edge-compatible).
- **Default**: `"Single-region"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Multi-region"`
  - If `architecturalFraming.topology: "serverless"` AND `appType ∈ (api, fullstack)` → `"Edge-distributed"`
  - Else → `"Single-region"` (greenfield opinion: the right default for 95% of new projects; multi-region is an operational complexity multiplier)

### AF.Q3: "What's the scale target?"
- **Type**: Choice
- **Options**: "Hobby / personal project (single user, occasional traffic)" | "Startup (public launch, growth expected, 100–10k users)" | "Production-scale (established product, sustained load, 10k–1M users)" | "Enterprise (regulated, SLA-backed, 1M+ users or organizational complexity)"
- **Condition**: Always
- **Updates**: `context.phases.architecturalFraming.scaleTarget` (required, enum)
- **Downstream effects**: dataArchitecture caching, backup, and compliance questions weight their recommendations against scale target; cicdAndDelivery env ladder and release pipeline complexity track scale; authSecurity (Round 3) uses scale to calibrate identity recommendations.
- **Recommend**: Be honest about current scale, not aspirational. Most projects starting today are `startup`; `enterprise` triggers heavier compliance cross-checks.
- **Default**: `"Startup"`
  - If `isProduction: false` AND `hasTeam: false` → `"Hobby"`
  - Else → `"Startup"` (greenfield opinion: most new public projects are in startup territory; hobby under-calibrates; enterprise over-calibrates and adds unnecessary compliance overhead)

### AF.Q4: "Do you have any hard architectural boundary requirements or constraints?"
- **Type**: Open-ended with option-prompted starting points
- **Suggested prompts**: "Domain separation you know you need (e.g., billing must be isolated from auth)?", "Regulatory constraints that force isolation (e.g., PCI data must not touch user PII)?", "Team ownership lines that need to map to service boundaries?"
- **Condition**: Always
- **Updates**: `context.phases.architecturalFraming.boundaryNotes` (loose string — whatever the user says goes in as-is; this is advisory context for later phases, not schema-validated)
- **Downstream effects**: grill-spec cross-checks `boundaryNotes` against topology when non-empty (e.g., "must isolate payments" + `topology: monolith` produces a contradiction flag); synthesis-review § Downstream Implications renders this as a note.
- **If no constraints**: capture as `""` (empty string) or `"none stated"`. Do not leave null — the schema accepts empty string; null would fail required-field presence in future tooling.
- **Default**: `""` (empty — no boundary constraints) (always — greenfield opinion: most early-stage projects have no hard constraints; capturing empty is correct rather than a forced placeholder)

**>>> SYNTHESIS PAUSE**: After AF.Q4 (or after the last applicable question if skipping fired), invoke `Skill(synthesis-review, phaseId: "architecturalFraming")`. Wait for the developer to Approve/Adjust/Skip each section before moving to Step 3: Data Architecture.

---

## Step 3: Data Architecture (12 questions)

Step 3 of the 11-step wizard. Captures data-layer decisions: DB engine + host, ORM, migrations, multi-tenancy, search, caching, file storage, codegen, backup, compliance. Synthesis review fires inline after the last question.

Writes to `context.phases.dataArchitecture.*`. See `onboard/skills/generate/references/context-shape-v2.json` § `dataArchitecture` for the schema.

### P3.Q1: "Does this app need persistent data?"
- **Type**: Choice
- **Options**: "Yes — relational" | "Yes — document/NoSQL" | "Yes — embedded (SQLite/DuckDB)" | "No persistent data" | "Not sure — recommend"
- **Condition**: Always (gate for the rest of Step 3 / dataArchitecture)
- **Updates**: gate flag; if "No persistent data", skip Q2–Q7 but still ask Q8 (in-memory cache), Q9 (FS storage), Q10 (codegen), Q12 (compliance)
- **Default**: `"Yes — relational"`
  - If `appType: "cli"` → `"No persistent data"`
  - If `appType: "library"` → `"No persistent data"`
  - If `stack.stack.framework ∈ (django, rails, laravel)` → `"Yes — relational"` (opinionated ORM stacks assume relational)
  - Else → `"Yes — relational"` (greenfield opinion: relational DBs are the right default for most applications; document stores are a deliberate choice, not a default)

### P3.Q2: "Which database engine?"
- **Type**: Open with stack-informed recommendations
- **Options**: Dynamically generated (e.g., "PostgreSQL (recommended for Next.js + Prisma)" | "MySQL" | "MongoDB" | "SQLite" | "Turso/libSQL" | "PlanetScale" | "EdgeDB" | "DynamoDB" | "Custom — specify")
- **Condition**: Q1 = yes (any persistent option)
- **Updates**: `context.phases.dataArchitecture.engine` (loose string)
- **Default**: `"PostgreSQL"`
  - If `stack.stack.framework: "django"` → `"PostgreSQL"` (Django's primary target; migration tooling is most tested against Postgres)
  - If `stack.stack.framework: "rails"` → `"PostgreSQL"`
  - If `architecturalFraming.topology: "serverless"` AND `architecturalFraming.deploymentShape: "edge-distributed"` → `"Turso/libSQL"` (edge-compatible embedded)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"SQLite"` (zero-infra overhead for single-user apps)
  - Else → `"PostgreSQL"` (greenfield opinion: Postgres is the most capable open-source RDBMS with the widest ecosystem support)

### P3.Q3: "What's the database hosting model?"
- **Type**: Choice
- **Options**: "Self-hosted (you manage the server)" | "Managed RDBMS (RDS, Cloud SQL, Supabase)" | "Serverless RDBMS (Neon, PlanetScale, Turso)" | "Managed NoSQL (Atlas, DynamoDB)" | "Embedded (SQLite/DuckDB)" | "None"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.databaseHost` (required, enum)
- **Cross-phase**: cicdAndDelivery reads this for rollback strategy (point-in-time recovery on managed hosts only)
- **Default**: `"Managed RDBMS"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Embedded"` (SQLite; no infra cost)
  - If `architecturalFraming.topology: "serverless"` → `"Serverless RDBMS"` (connection-pool compatible)
  - If `architecturalFraming.deploymentShape: "on-prem"` → `"Self-hosted"`
  - Else → `"Managed RDBMS"` (greenfield opinion: managed hosting removes operational burden while providing PITR and backups out of the box)

### P3.Q4: "Which ORM or data-access layer?"
- **Type**: Choice (filtered by `stack.stack.language`)
- **Options**: For TypeScript: "Prisma" | "Drizzle" | "Kysely" | "TypeORM" | "Sequelize" | "Raw SQL" | "Other". For Python: "SQLAlchemy" | "Django ORM" | "Raw SQL" | "Other". For Go: "GORM" | "sqlc" | "Raw SQL" | "Other". For Ruby: "Active Record" | "Raw SQL" | "Other". For Elixir: "Ecto" | "Raw SQL" | "Other". For Rust: "Diesel" | "sqlx" | "Raw SQL" | "Other".
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.orm` (required, enum)
- **Cross-phase**: apiIntegration reads for codegen + validation library pairing
- **Default**: `"Prisma"` (for TypeScript projects)
  - If `stack.stack.language: "typescript"` AND `architecturalFraming.topology: "serverless"` → `"Drizzle"` (edge-compatible, no Prisma query engine overhead)
  - If `stack.stack.language: "typescript"` → `"Prisma"` (greenfield opinion: best DX, codegen, and migration tooling for TS)
  - If `stack.stack.language: "python"` AND `stack.stack.framework: "django"` → `"Django ORM"`
  - If `stack.stack.language: "python"` → `"SQLAlchemy"`
  - If `stack.stack.language: "go"` → `"sqlc"` (greenfield opinion: type-safe SQL generation without runtime magic)
  - If `stack.stack.language: "ruby"` → `"Active Record"`
  - If `stack.stack.language: "elixir"` → `"Ecto"`
  - If `stack.stack.language: "rust"` → `"sqlx"` (async-native, no derive macro overhead)
  - Else → `"Raw SQL"` (safe fallback when language is unknown)

### P3.Q5: "Migration tool & application mode?"
- **Type**: Composite (choice + choice)
- **Sub-questions**:
  - Tool: "ORM-native (Prisma migrate, Drizzle kit, etc.)" | "Alembic" | "Flyway" | "Liquibase" | "Raw SQL files" | "None — manual schema" | "Other"
  - Mode: "Developer-applied (dev runs migrations locally)" | "CI-applied (pipeline runs before deploy)" | "Runtime-applied (app applies on boot)"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.migrationsTool` (required, enum) + `migrationsMode` (loose)
- **Default**: Tool: `"ORM-native"`, Mode: `"CI-applied"`
  - If `dataArchitecture.orm: "prisma"` → Tool: `"ORM-native"` (Prisma migrate), Mode: `"CI-applied"`
  - If `dataArchitecture.orm: "drizzle"` → Tool: `"ORM-native"` (Drizzle kit), Mode: `"CI-applied"`
  - If `stack.stack.language: "python"` AND `stack.stack.framework ≠ "django"` → Tool: `"Alembic"`, Mode: `"CI-applied"`
  - If `stack.stack.language: "python"` AND `stack.stack.framework: "django"` → Tool: `"ORM-native"` (Django migrations), Mode: `"CI-applied"`
  - If `architecturalFraming.scaleTarget: "hobby"` → Mode: `"Developer-applied"` (no CI)
  - Else → Tool: `"ORM-native"`, Mode: `"CI-applied"` (greenfield opinion: ORM-native tools stay in sync with schema changes automatically)

### P3.Q6: "Multi-tenancy isolation strategy?"
- **Type**: Choice
- **Options**: "None — single-tenant" | "Row-level (tenant_id columns + RLS)" | "Schema-per-tenant" | "DB-per-tenant" | "Shared (no isolation — review carefully)"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.multiTenancy` (required, enum)
- **Cross-phase**: Future P6 reads for auth/authz model
- **Default**: `"None — single-tenant"`
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` AND `appType ∈ (fullstack, web-app)` → `"Row-level"` (greenfield opinion: row-level is the right starting point for SaaS apps at scale)
  - Else → `"None — single-tenant"` (greenfield opinion: most new projects are single-tenant; multi-tenancy is a deliberate architectural choice)

### P3.Q7: "Search and retrieval strategy?"
- **Type**: Choice
- **Options**: "DB full-text only (Postgres tsvector, MySQL FT)" | "Dedicated engine (Elasticsearch, Meilisearch, Typesense)" | "Vector store (pgvector, Pinecone, Qdrant, Weaviate)" | "Hybrid (FTS + vector)" | "None — no search"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.search` (loose)
- **Default**: `"None — no search"`
  - If `appType ∈ (fullstack, web-app)` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` → `"DB full-text only"` (greenfield opinion: Postgres full-text is sufficient for most apps at launch; add a dedicated engine when query performance demands it)
  - Else → `"None — no search"` (greenfield opinion: search is a feature, not a default infrastructure component)

### P3.Q8: "Caching layer + invalidation pattern?"
- **Type**: Composite (multi-select + choice)
- **Sub-questions**:
  - Layers (multi-select; pad with "None / Skip" if zero matches): "In-memory (app-local)" | "Redis / KeyDB" | "Memcached" | "DB query cache" | "CDN edge"
  - Invalidation: "TTL only" | "Event-driven (invalidate on write)" | "Manual" | "None — no caching"
- **Condition**: Always (even no-DB apps can cache)
- **Updates**: `context.phases.dataArchitecture.cache` (loose) + `cacheInvalidation` (loose)
- **Default**: Layers: `"None — no caching"`, Invalidation: `"None — no caching"`
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → Layers: `"Redis / KeyDB"`, Invalidation: `"Event-driven"`
  - If `architecturalFraming.scaleTarget: "startup"` → Layers: `"In-memory (app-local)"`, Invalidation: `"TTL only"`
  - Else → `"None — no caching"` (greenfield opinion: premature caching adds complexity without benefit; add when profiling shows it's needed)

### P3.Q9: "File / object storage strategy?"
- **Type**: Choice
- **Options**: "Cloud storage (S3 / R2 / Blob / GCS)" | "Local filesystem" | "CDN for static assets" | "Both cloud + CDN" | "No file handling"
- **Condition**: `hasBackend || hasFrontend`
- **Updates**: `context.phases.dataArchitecture.fileStorage` (loose)
- **Default**: `"No file handling"`
  - If `appType ∈ (fullstack, web-app)` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` → `"Cloud storage (S3 / R2 / Blob / GCS)"` (greenfield opinion: local filesystem doesn't survive horizontal scale or container restarts)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Local filesystem"` (acceptable for single-user projects)
  - Else → `"No file handling"` (greenfield opinion: file handling is a feature, not a default)

### P3.Q10: "Codegen tools?"
- **Type**: Multi-select
- **Options**: "Prisma generate" | "Drizzle Kit" | "sqlc" | "GraphQL codegen" | "OpenAPI TypeScript" | "Protocol Buffers" | "None"
- **Condition**: Applicable to stack (skip if Q1=no AND no API)
- **Updates**: `context.phases.dataArchitecture.codegen` (loose array)
- **Note**: Even though codegen spans ORM (Prisma) and API (GraphQL/OpenAPI), it lives in dataArchitecture only per the single-owner boundary. apiIntegration synthesis cross-references this question when style=graphql.
- **Default**: `["None"]`
  - If `dataArchitecture.orm: "prisma"` → `["Prisma generate"]`
  - If `dataArchitecture.orm: "drizzle"` → `["Drizzle Kit"]`
  - If `stack.stack.language: "go"` AND `dataArchitecture.orm: "sqlc"` → `["sqlc"]`
  - If `apiIntegration.style: "graphql"` → append `"GraphQL codegen"` to ORM-derived defaults
  - If `apiIntegration.style: "rest"` AND `stack.stack.language: "typescript"` → append `"OpenAPI TypeScript"` to ORM-derived defaults
  - Else → `["None"]`

### P3.Q11: "Backup & retention?"
- **Type**: Choice
- **Options**: "None — accept loss risk" | "Managed-provider auto-backup (most cloud DBs)" | "Scheduled dumps (custom cron)" | "Continuous (point-in-time recovery)"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.dataArchitecture.backup` (loose)
- **Default**: `"Managed-provider auto-backup"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"None — accept loss risk"` (greenfield opinion: hobby projects rarely need formal backup; simplicity wins)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Continuous (point-in-time recovery)"`
  - If `dataArchitecture.databaseHost: "embedded"` → `"Scheduled dumps (custom cron)"` (SQLite has no managed backup)
  - Else → `"Managed-provider auto-backup"` (greenfield opinion: delegate backup to the hosting provider; it's free with most managed DBs and requires zero configuration)

### P3.Q12: "Data residency / compliance constraints?"
- **Type**: Choice
- **Options**: "None" | "Region-locked (specify in follow-up)" | "GDPR-aware (EU users)" | "HIPAA" | "PCI-DSS" | "SOC 2"
- **Condition**: Always
- **Updates**: `context.phases.dataArchitecture.compliance` (loose)
- **Default**: `"None"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"SOC 2"` (enterprise implies organizational compliance requirements)
  - Else → `"None"` (greenfield opinion: compliance is a product requirement, not a technical default; don't add overhead without a real driver)

**>>> SYNTHESIS PAUSE**: After P3.Q12 (or after earlier final-question if Q1=no), invoke `Skill(synthesis-review, phaseId: "dataArchitecture")`. Wait for the developer to Approve/Adjust/Skip each section before moving to Step 4: API & Integration.

---

## Step 4: API & Integration (10 questions)

Step 4 of the 11-step wizard. Captures API surface decisions: style, documentation, versioning, rate limits, pagination, async patterns, real-time, webhooks, external integrations.

Writes to `context.phases.apiIntegration.*`. See `onboard/skills/generate/references/context-shape-v2.json` § `apiIntegration` for the schema.

### P4.Q1: "Does this app expose an API surface?"
- **Type**: Choice
- **Options**: "Yes — public API" | "Yes — internal/private only" | "No — UI-only app" | "Not sure — recommend"
- **Condition**: Always (gate for the rest of Step 4 / apiIntegration)
- **Updates**: gate flag; if "No", skip Q2–Q9, ask Q10 only
- **Default**: `"Yes — internal/private only"`
  - If `appType: "api"` → `"Yes — public API"`
  - If `appType ∈ (fullstack, web-app)` AND `hasBackend` → `"Yes — internal/private only"`
  - If `appType: "cli"` → `"No — UI-only app"` (CLI has no API surface by default)
  - Else → `"Yes — internal/private only"` (greenfield opinion: most backend services expose at minimum an internal API)

### P4.Q2: "API style?"
- **Type**: Choice
- **Options**: "REST" | "GraphQL" | "tRPC (TypeScript-only)" | "gRPC" | "Other RPC" | "No API surface"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.apiIntegration.style` (required, enum)
- **Cross-phase**: dataArchitecture reads for codegen pairing; future authSecurity reads for auth integration pattern
- **Default**: `"REST"`
  - If `stack.stack.language: "typescript"` AND `appType: "fullstack"` AND `stack.stack.framework ∈ (next, nuxt, remix)` → `"tRPC"` (greenfield opinion: tRPC eliminates the API contract layer for full-stack TypeScript)
  - If `stack.stack.language: "typescript"` → `"REST"`
  - If `stack.stack.language ∈ (python, go, ruby, java, kotlin)` → `"REST"` (REST is idiomatic for all of these)
  - If `architecturalFraming.topology: "microservices"` AND `stack.stack.language: "go"` → `"gRPC"` (greenfield opinion: gRPC is idiomatic for Go microservice-to-service communication)
  - Else → `"REST"` (greenfield opinion: REST is the most widely understood API style; switch to tRPC/GraphQL when the full-stack type sharing becomes a concrete pain point)

### P4.Q3: "API documentation tool?"
- **Type**: Choice
- **Options**: "OpenAPI / Swagger" | "GraphQL Playground / Apollo Studio" | "Auto-from-types (TS-RPC, etc.)" | "Manual (Markdown / Notion)" | "No docs"
- **Condition**: Q2 ≠ none
- **Updates**: `context.phases.apiIntegration.documentation` (loose)
- **Default**: `"OpenAPI / Swagger"`
  - If `apiIntegration.style: "graphql"` → `"GraphQL Playground / Apollo Studio"`
  - If `apiIntegration.style: "trpc"` → `"Auto-from-types (TS-RPC, etc.)"` (tRPC generates types automatically)
  - If `apiIntegration.style: "grpc"` → `"Auto-from-types (TS-RPC, etc.)"` (protobuf generates docs)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"No docs"` (greenfield opinion: hobby projects don't need formal API documentation)
  - Else → `"OpenAPI / Swagger"` (greenfield opinion: OpenAPI is the industry standard for REST; Swagger UI is zero-overhead to add)

### P4.Q4: "Versioning policy?"
- **Type**: Choice
- **Options**: "URL path (/v1/, /v2/)" | "Header (Accept-Version)" | "Query string (?v=1)" | "No-breaking-changes policy (additive only)" | "None yet — figure it out later"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.apiIntegration.versioningPolicy` (required, enum)
- **Cross-phase**: Future P7 reads for breaking-change policy
- **Default**: `"URL path (/v1/, /v2/)"`
  - If `apiIntegration.style: "trpc"` → `"No-breaking-changes policy (additive only)"` (tRPC versioning is handled at the type level)
  - If `apiIntegration.style: "graphql"` → `"No-breaking-changes policy (additive only)"` (GraphQL schema evolution is additive by convention)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"None yet — figure it out later"`
  - Else → `"URL path (/v1/, /v2/)"` (greenfield opinion: URL path versioning is the most explicit and easiest for clients to debug)

### P4.Q5: "Rate limiting strategy?"
- **Type**: Choice
- **Options**: "None" | "Fixed window (Redis-backed)" | "Sliding window" | "Token bucket" | "Per-user / per-API-key" | "Per-IP" | "Gateway-level (Cloudflare, AWS API Gateway)"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.apiIntegration.rateLimit` (loose)
- **Default**: `"None"`
  - If `apiIntegration.style: "public API"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Per-user / per-API-key"` (greenfield opinion: public APIs need per-key rate limits to prevent abuse)
  - If `architecturalFraming.deploymentShape ∈ (edge-distributed)` → `"Gateway-level (Cloudflare, AWS API Gateway)"` (edge deployments have gateway-level rate limiting built in)
  - If `architecturalFraming.scaleTarget: "startup"` AND `dataArchitecture.cache ∈ (redis)` → `"Fixed window (Redis-backed)"`
  - Else → `"None"` (greenfield opinion: add rate limiting when you have a real abuse concern, not by default)

### P4.Q6: "Pagination strategy?"
- **Type**: Choice
- **Options**: "Offset (LIMIT/OFFSET)" | "Cursor (timestamp or ID-based)" | "Page-based (page=N&size=M)" | "Both offset + cursor (REST: cursor; GraphQL: Relay)" | "None — return all"
- **Condition**: Q2 ∈ (rest, graphql)
- **Updates**: `context.phases.apiIntegration.pagination` (loose)
- **Default**: `"Cursor (timestamp or ID-based)"`
  - If `apiIntegration.style: "graphql"` → `"Both offset + cursor (REST: cursor; GraphQL: Relay)"` (Relay cursor pagination is GraphQL convention)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Offset (LIMIT/OFFSET)"` (simplest; fine for small datasets)
  - Else → `"Cursor (timestamp or ID-based)"` (greenfield opinion: cursor pagination is stable under inserts/deletes and scales better than offset)

### P4.Q7: "Async pattern for background work?"
- **Type**: Choice
- **Options**: "None — all sync" | "Queue + worker (BullMQ, Celery, Sidekiq)" | "Scheduled cron jobs" | "Event-driven (pub/sub)" | "Serverless functions (Lambda, Cloud Functions)" | "Mixed"
- **Condition**: `hasBackend`
- **Updates**: `context.phases.apiIntegration.asyncPattern` (required, enum)
- **Cross-phase**: Future P7 reads for CI test strategy
- **Default**: `"None — all sync"`
  - If `architecturalFraming.topology: "serverless"` → `"Serverless functions (Lambda, Cloud Functions)"`
  - If `architecturalFraming.topology: "microservices"` → `"Event-driven (pub/sub)"` (greenfield opinion: microservices communicate via events, not direct calls)
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` AND `stack.stack.language: "typescript"` → `"Queue + worker (BullMQ, Celery, Sidekiq)"` (BullMQ for Node.js)
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` AND `stack.stack.language: "python"` → `"Queue + worker (BullMQ, Celery, Sidekiq)"` (Celery for Python)
  - Else → `"None — all sync"` (greenfield opinion: async patterns add operational complexity; add them when a specific feature requires it)

### P4.Q8: "Real-time delivery?"
- **Type**: Choice
- **Options**: "None" | "WebSockets" | "Server-Sent Events (SSE)" | "HTTP long-polling" | "External pub/sub (Pusher, Ably, Liveblocks)"
- **Condition**: `hasBackend && hasFrontend`
- **Updates**: `context.phases.apiIntegration.realtime` (loose)
- **Default**: `"None"`
  - If `appType: "fullstack"` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` AND `architecturalFraming.topology ∈ (monolith, modular-monolith)` → `"Server-Sent Events (SSE)"` (greenfield opinion: SSE is simpler than WebSockets for unidirectional real-time; add WebSockets when bidirectional is required)
  - If `architecturalFraming.topology: "serverless"` → `"External pub/sub (Pusher, Ably, Liveblocks)"` (serverless can't hold long-lived WebSocket connections)
  - Else → `"None"` (greenfield opinion: real-time is a feature that should be added when users need it, not by default)

### P4.Q9: "Webhooks — incoming and outgoing?"
- **Type**: Composite (choice + multi-select)
- **Sub-questions**:
  - Direction: "None" | "Incoming only (we receive)" | "Outgoing only (we send)" | "Both"
  - Tooling (multi-select; pad with "None / Skip" if zero matches): "Signature verification" | "Retry queue" | "Dead-letter handling" | "Webhook registry UI"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.apiIntegration.webhooks` (loose)
- **Default**: Direction: `"None"`, Tooling: `[]`
  - If `apiIntegration.externalServices` includes payment providers (Stripe, Paddle) → Direction: `"Incoming only (we receive)"`, Tooling: `["Signature verification"]` (payment providers send webhooks; signature verification is mandatory)
  - Else → Direction: `"None"` (greenfield opinion: webhooks are an integration feature; add them when a specific integration requires it)

### P4.Q10: "External services and integrations?"
- **Type**: Multi-select free-text
- **Options**: "Payments (Stripe, Paddle, Lemon Squeezy)" | "Email (Resend, SendGrid, Postmark)" | "SMS (Twilio)" | "Analytics (Segment, Mixpanel, PostHog)" | "Search (Algolia)" | "Storage (S3-compatible)" | "AI / LLM (OpenAI, Anthropic, etc.)" | "Other — specify"
- **Condition**: Always (even no-API apps integrate with services)
- **Updates**: `context.phases.apiIntegration.externalServices` (loose array)
- **Default**: `[]` (no external services) (always — greenfield opinion: integrations are product decisions; no default is appropriate here. Use Enter to indicate no integrations planned)

**>>> SYNTHESIS PAUSE**: After P4.Q10, invoke `Skill(synthesis-review, phaseId: "apiIntegration")`. Wait for the developer to Approve/Adjust/Skip each section before moving to the remaining Project Details step.

---

## Step 5: Auth (12 questions)

> **Round 3 (alpha.4):** Auth is the 5th major synthesis phase. Strategy is set first because it gates the rest of the phase's question flow. Synthesis output: `docs/adr/auth.html` + `.md`.

### Auth.Q1: "How do you want to handle authentication?"
- **Type**: Choice
- **Options**: "None — no auth in scope" | "Hosted (Clerk, Auth0, Supabase Auth, Firebase Auth, Cognito)" | "Self-hosted OSS (Keycloak, Authentik, Ory)" | "Built-in (framework session/JWT)"
- **Condition**: Always
- **Updates**: `auth.strategy`, `auth.provider` (follow-up if hosted/self-hosted-oss)
- **Downstream**: Auth.Q2–Auth.Q12 all consume `auth.strategy`; Privacy phase reads `auth.strategy` for the skip-cascade gate; Security phase reads `auth.strategy` for threat surface sizing
- **Skip-cascade**: `none` → fires single-Q gate to Privacy ("Do you collect any user data?"). Yes → reduced Privacy; No → Privacy synthesisStatus='n/a' stub.
- **Default**:
  - If `stack.stack.framework='next'` AND `Q3.4.deployTarget='vercel'` → `"Hosted (Clerk)"` (greenfield opinion: Clerk is the idiomatic choice for Next on Vercel — drop-in middleware, edge-compatible session tokens, and the richest Next.js SDK on the market)
  - If `stack.stack.framework='django'` → `"Built-in (framework session/JWT)"` (Django auth is first-class and battle-tested; adding a third-party layer without a specific reason adds complexity)
  - If `stack.stack.framework='rails'` → `"Built-in (framework session/JWT)"` (Devise is idiomatic for Rails; the ecosystem assumes it)
  - If `stack.stack.framework∈{fastapi,express,nestjs}` AND `architecturalFraming.scaleTarget∈{production-scale,enterprise}` → `"Hosted (Auth0)"` (greenfield opinion: managed auth eliminates security footguns at production scale — password storage, MFA, session fixation, token rotation are all off your plate)
  - If `architecturalFraming.scaleTarget='hobby'` → `"None — no auth in scope"` (hobby apps rarely need auth at launch; it can be added later)
  - Else → `"Hosted (Clerk)"` (greenfield opinion: third-party hosted auth eliminates password/session/MFA security pitfalls and reduces meaningful implementation effort; Clerk has the best DX across the hosted providers)

### Auth.Q2: "Which identity providers should users sign in with?"
- **Type**: Multi-select
- **Options**: "Email + password" | "Google" | "GitHub" | "Apple" | "Microsoft / Azure AD" | "SAML SSO (enterprise IdP)" | "Magic link (passwordless email)" | "Passkeys / WebAuthn" | "Phone / SMS OTP" | "Anonymous / guest" | "None — no IdPs yet"
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.idps[]`
- **Downstream**: Auth.Q10 (password policy) is skipped if `"Email + password"` not in `auth.idps[]`; Privacy.Q2 (PII inventory) auto-includes email when any IdP is selected; Security phase reads `auth.idps[]` for attack-surface sizing
- **Default**:
  - If `architecturalFraming.scaleTarget='enterprise'` → `["Email + password", "SAML SSO (enterprise IdP)"]` (enterprise apps must support org-wide SSO for IT policy compliance)
  - If `stack.stack.framework='next'` AND `auth.strategy` includes `"Hosted (Clerk)"` → `["Email + password", "Google"]` (Clerk's most common starter combination; Google OAuth covers the majority of consumer sign-in patterns)
  - If `appType='mobile'` OR `architecturalFraming.deploymentShape='mobile'` → `["Email + password", "Google", "Apple"]` (Apple requires Sign In with Apple for iOS apps that offer any social login; Google covers Android; email+pw for fallback)
  - If `architecturalFraming.scaleTarget='hobby'` → `["Email + password"]` (minimal IdP overhead for early-stage projects)
  - If `auth.strategy='Built-in (framework session/JWT)'` → `["Email + password"]` (built-in auth providers typically only natively manage email+pw; social providers require explicit OAuth library additions)
  - Else → `["Email + password", "Google"]` (greenfield opinion: Google OAuth is low-friction to add and covers a large share of real-world users; email+pw as fallback ensures universal accessibility)

### Auth.Q3: "What session model should the app use?"
- **Type**: Choice + Object
- **Options**: "Cookie-based sessions (server-managed)" | "JWT (stateless, client-holds-token)" | "Hybrid (short-lived JWT + cookie-backed refresh token)" | "Provider-managed (hosted auth handles it)"
- **Sub-fields** (object, shown after main choice):
  - `accessTokenTtl`: e.g., `"15m"` — access token or session lifetime
  - `refreshTokenStrategy`: `"rotating"` | `"absolute"` | `"none"`
  - `storage`: `"httpOnly-cookie"` | `"localStorage"` | `"sessionStorage"` | `"provider-managed"`
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.sessionModel` (object)
- **Downstream**: Security phase reads `auth.sessionModel.storage` for XSS risk scoring; Auth.Q12 (enforcement point) is influenced by session model (stateless JWT shifts enforcement to the request boundary)
- **Default**:
  - If `auth.strategy` includes `"Hosted"` → `"Provider-managed (hosted auth handles it)"` — `storage: "httpOnly-cookie"`, `refreshTokenStrategy: "rotating"` (hosted providers manage session complexity; defer to their defaults unless you have a specific override need)
  - If `architecturalFraming.topology='serverless'` → `"JWT (stateless, client-holds-token)"` — `accessTokenTtl: "15m"`, `refreshTokenStrategy: "rotating"`, `storage: "httpOnly-cookie"` (serverless functions can't maintain server-side session stores; JWT enables stateless validation at the edge)
  - If `stack.stack.framework='django'` → `"Cookie-based sessions (server-managed)"` — `storage: "httpOnly-cookie"`, `refreshTokenStrategy: "absolute"` (Django's session engine is mature and handles cookie management correctly out of the box)
  - If `stack.stack.framework='rails'` → `"Cookie-based sessions (server-managed)"` — `storage: "httpOnly-cookie"`, `refreshTokenStrategy: "absolute"` (Rails' signed/encrypted cookie session store is battle-tested)
  - If `architecturalFraming.topology='microservices'` → `"Hybrid (short-lived JWT + cookie-backed refresh token)"` — `accessTokenTtl: "5m"`, `refreshTokenStrategy: "rotating"` (services validate JWTs independently without a shared session store; short TTL limits blast radius on token compromise)
  - Else → `"Hybrid (short-lived JWT + cookie-backed refresh token)"` — `accessTokenTtl: "15m"`, `refreshTokenStrategy: "rotating"`, `storage: "httpOnly-cookie"` (greenfield opinion: hybrid is the safest default — short-lived access tokens limit exposure, httpOnly cookie storage prevents XSS token theft, rotating refresh tokens detect replay attacks)

### Auth.Q4: "What MFA approach do you want?"
- **Type**: Object
- **Sub-fields**:
  - `enforcement`: `"required"` | `"optional-encouraged"` | `"optional-silent"` | `"not-yet"`
  - `methods` (multi-select): `"TOTP (Authenticator app)"` | `"SMS OTP"` | `"Email OTP"` | `"Passkeys / WebAuthn"` | `"Recovery codes"` | `"None"`
  - `gracePeriod`: days before MFA is enforced after sign-up (only relevant when `enforcement='required'`)
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.mfa` (object)
- **Downstream**: Security phase reads `auth.mfa.enforcement` for security-posture scoring; Privacy phase reads `auth.mfa.methods` to flag if SMS OTP implies phone PII collection
- **Default**:
  - If `dataArchitecture.compliance∈{HIPAA,SOC2,PCI-DSS}` → `enforcement: "required"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]`, `gracePeriod: 7` (compliance mandates MFA; TOTP is preferred over SMS for HIPAA/SOC2 because SMS is vulnerable to SIM-swap attacks)
  - If `architecturalFraming.scaleTarget='enterprise'` → `enforcement: "required"`, `methods: ["TOTP (Authenticator app)", "Passkeys / WebAuthn", "Recovery codes"]`, `gracePeriod: 14` (enterprise orgs typically mandate MFA by policy; offer passkeys alongside TOTP for phishing-resistant option)
  - If `architecturalFraming.scaleTarget='production-scale'` → `enforcement: "optional-encouraged"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]` (offer MFA as a strong default for user accounts but don't block onboarding)
  - If `architecturalFraming.scaleTarget='hobby'` → `enforcement: "not-yet"`, `methods: ["None"]` (hobby apps don't justify the MFA implementation and UX cost at launch)
  - Else → `enforcement: "optional-encouraged"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]` (greenfield opinion: offer MFA as an option from day one — retrofitting it later requires migrating active sessions and rebuilding enrollment flows; TOTP + recovery codes is the minimum viable secure combination)

### Auth.Q5: "What authorization model does the app need?"
- **Type**: Choice
- **Options**: "Flat roles (admin / user / guest)" | "RBAC — Role-Based Access Control (roles have permission sets)" | "ABAC — Attribute-Based Access Control (policies on user+resource attributes)" | "DB-level RLS (Postgres Row-Level Security)" | "Hybrid (RBAC + RLS)" | "None — no authorization needed"
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.authzModel`
- **Downstream**: Auth.Q6 (tenant resolution) interacts with authz model when multi-tenant; Security phase reads `auth.authzModel` for privilege-escalation threat surface
- **Note**: `"DB-level RLS"` option only shown when `dataArchitecture.engine` includes PostgreSQL/Supabase
- **Default**:
  - If `dataArchitecture.multiTenancy∈{row-level,schema-per-tenant}` AND `dataArchitecture.engine` includes `postgresql` OR `supabase` → `"Hybrid (RBAC + RLS)"` (multi-tenant apps need both role-level permission checks and row-level data isolation; RLS without RBAC leaves horizontal privilege escalation vectors open)
  - If `architecturalFraming.scaleTarget='enterprise'` → `"RBAC — Role-Based Access Control"` (enterprise apps always have multiple distinct permission groups; flat roles break down quickly)
  - If `dataArchitecture.engine` includes `postgresql` OR `supabase` AND `dataArchitecture.multiTenancy='row-level'` → `"DB-level RLS"` (Postgres RLS is the most reliable enforcement point for row-level isolation; defense-in-depth even if app-layer checks are bypassed)
  - If `appType∈{fullstack,web-app}` AND `architecturalFraming.scaleTarget∈{startup,production-scale}` → `"RBAC — Role-Based Access Control"` (most SaaS apps need at minimum admin/member/viewer roles; RBAC is straightforward to implement and reason about)
  - If `architecturalFraming.scaleTarget='hobby'` → `"Flat roles (admin / user / guest)"` (hobby apps rarely need fine-grained permissions; two roles are easier to maintain)
  - Else → `"RBAC — Role-Based Access Control"` (greenfield opinion: flat roles collapse into RBAC as soon as a third role is needed; start with RBAC now to avoid a painful refactor when the product grows)

### Auth.Q6: "How should the app resolve tenant identity from a request?"
- **Type**: Choice
- **Options**: "Subdomain (tenant.app.com)" | "Path prefix (/org/slug/...)" | "JWT claim (tenant_id in token)" | "Custom header (X-Tenant-ID)" | "Hybrid (subdomain + claim)"
- **Condition**: `dataArchitecture.multiTenancy ≠ "None — single-tenant"` — **SKIP this question entirely if `dataArchitecture.multiTenancy = "None — single-tenant"`**
- **Updates**: `auth.tenantResolution`
- **Downstream**: Security phase reads `auth.tenantResolution` for tenant-boundary cross-contamination risk; scaffolding generates middleware templates based on resolution strategy
- **Default**:
  - If `architecturalFraming.scaleTarget='enterprise'` AND `dataArchitecture.multiTenancy='schema-per-tenant'` → `"Subdomain (tenant.app.com)"` (enterprise customers expect their own subdomain; it also enables per-tenant TLS certificates and CDN rules)
  - If `apiIntegration.style='trpc'` OR `apiIntegration.style='graphql'` → `"JWT claim (tenant_id in token)"` (tRPC and GraphQL context objects make JWT-claim extraction ergonomic; subdomain routing requires framework-level middleware that's heavier to set up in these stacks)
  - If `architecturalFraming.topology='microservices'` → `"Custom header (X-Tenant-ID)"` (service mesh / API gateway can propagate a canonical tenant header; each service doesn't need to re-parse JWTs or inspect hostnames)
  - If `dataArchitecture.multiTenancy='row-level'` → `"JWT claim (tenant_id in token)"` (RLS policies reference the tenant claim set in the request context; extracting it from the JWT is the lowest-overhead path)
  - Else → `"Subdomain (tenant.app.com)"` (greenfield opinion: subdomain-per-tenant is the most explicit isolation signal — it's visible in browser URLs, easy to audit in logs, and makes tenant-boundary violations obvious rather than subtle)

### Auth.Q7: "How should services authenticate to each other?"
- **Type**: Choice
- **Options**: "API keys (long-lived, secret-manager stored)" | "mTLS (mutual TLS client certificates)" | "Signed JWTs (short-lived service tokens)" | "OIDC workload identity (cloud-native)" | "None — services are co-located / same process"
- **Condition**: `architecturalFraming.topology = "microservices"` — **SKIP this question entirely if `architecturalFraming.topology ≠ "microservices"`**
- **Updates**: `auth.serviceAuth`
- **Downstream**: Security phase reads `auth.serviceAuth` for internal trust boundary threat model; Runtime Operations phase reads `auth.serviceAuth` for secret rotation frequency recommendations
- **Default**:
  - If `Q3.4.deployTarget` includes `"kubernetes"` OR `architecturalFraming.deploymentShape` includes `"k8s"` → `"OIDC workload identity (cloud-native)"` (Kubernetes workload identity via SPIFFE/SPIRE or cloud-provider IAM eliminates long-lived credentials entirely — it's the most secure option for k8s-hosted microservices)
  - If `architecturalFraming.scaleTarget='enterprise'` → `"mTLS (mutual TLS client certificates)"` (enterprise security policies often mandate mTLS for service-to-service; it's the standard in zero-trust network architectures)
  - If `architecturalFraming.scaleTarget='production-scale'` AND `apiIntegration.style='grpc'` → `"mTLS (mutual TLS client certificates)"` (gRPC already terminates TLS; adding mutual auth is incremental effort with significant security gain)
  - If `architecturalFraming.scaleTarget∈{startup,production-scale}` → `"Signed JWTs (short-lived service tokens)"` (short-lived JWTs are easier to implement than mTLS, limit blast radius on compromise, and are trivially rotated — a solid production default without the PKI overhead of mTLS)
  - If `architecturalFraming.scaleTarget='hobby'` → `"API keys (long-lived, secret-manager stored)"` (simple and sufficient for internal hobby-scale services; secret-manager storage mitigates the long-lived risk)
  - Else → `"Signed JWTs (short-lived service tokens)"` (greenfield opinion: short-lived signed JWTs are the best balance of security and implementation effort for most microservice topologies; they're auditable, revocable via expiry, and require no shared-secret synchronization)

### Auth.Q8: "How should account lifecycle events be handled?"
- **Type**: Object
- **Sub-fields**:
  - `signupFlow`: `"open"` | `"invite-only"` | `"waitlist"` | `"admin-approved"`
  - `emailVerification`: `"required-before-use"` | `"required-within-grace-period"` | `"optional"` | `"n/a-no-email-idp"`
  - `passwordReset`: `"email-link"` | `"email-otp"` | `"admin-only"` | `"n/a-no-password-idp"`
  - `accountDeletion`: `"self-serve-immediate"` | `"self-serve-soft-delete"` | `"admin-initiated-only"` | `"support-ticket"`
  - `accountSuspension`: `"supported"` | `"not-needed"`
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.lifecycle` (object)
- **Downstream**: Privacy phase reads `auth.lifecycle.accountDeletion` for right-to-erasure flow design; Security phase reads `auth.lifecycle.signupFlow` for account-enumeration attack surface
- **Default**:
  - If `architecturalFraming.scaleTarget='enterprise'` → `signupFlow: "invite-only"`, `emailVerification: "required-before-use"`, `passwordReset: "email-link"`, `accountDeletion: "admin-initiated-only"`, `accountSuspension: "supported"` (enterprise apps are provisioned via admin workflows, not self-serve signup; account deletion is a compliance event that requires admin oversight)
  - If `dataArchitecture.compliance∈{GDPR-aware,HIPAA}` → `accountDeletion: "self-serve-soft-delete"` (GDPR right-to-erasure requires user-initiated deletion; soft-delete + anonymization is preferred over hard-delete because it preserves audit trail integrity)
  - If `architecturalFraming.scaleTarget='hobby'` → `signupFlow: "open"`, `emailVerification: "optional"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-immediate"`, `accountSuspension: "not-needed"` (hobby apps prioritize zero-friction onboarding over security theater)
  - If `appType∈{fullstack,web-app}` AND `architecturalFraming.scaleTarget='startup'` → `signupFlow: "open"`, `emailVerification: "required-within-grace-period"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-soft-delete"`, `accountSuspension: "supported"` (startup apps need frictionless onboarding but should verify email within 72h to prevent spam accounts; soft-delete preserves data for potential account recovery within a grace window)
  - Else → `signupFlow: "open"`, `emailVerification: "required-before-use"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-soft-delete"`, `accountSuspension: "supported"` (greenfield opinion: require email verification before granting access — it's a low-friction fraud signal; soft-delete is safer than hard-delete because deletion is often a misclick that users regret within 24 hours)

### Auth.Q9: "What account recovery options should be available?"
- **Type**: Choice
- **Options**: "Email link only" | "Email + phone (SMS)" | "Email + recovery codes" | "SSO-mediated (org admin resets via IdP)" | "Recovery codes only (high-security)" | "None — no recovery path"
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.recovery`
- **Downstream**: Privacy phase auto-flags phone number as a PII category if `auth.recovery` includes phone/SMS; Security phase uses recovery method to assess account-takeover surface area
- **Default**:
  - If `architecturalFraming.scaleTarget='enterprise'` AND `auth.idps[]` includes `"SAML SSO (enterprise IdP)"` → `"SSO-mediated (org admin resets via IdP)"` (enterprise accounts are managed by the org's IT admin; self-serve email recovery bypasses organizational access control policies)
  - If `dataArchitecture.compliance∈{HIPAA,SOC2}` → `"Email + recovery codes"` (high-assurance recovery avoids SMS (SIM-swap risk) while still offering a fallback path; recovery codes are audit-logged events)
  - If `auth.mfa.methods` includes `"SMS OTP"` → `"Email + phone (SMS)"` (if SMS is already in scope for MFA, phone recovery is marginal incremental cost and improves recovery success rate)
  - If `architecturalFraming.scaleTarget='hobby'` → `"Email link only"` (simplest path; phone recovery adds Twilio cost and a second PII surface for hobby projects)
  - If `auth.idps[]` includes `"Passkeys / WebAuthn"` → `"Email + recovery codes"` (passkeys make device-loss recovery critical; recovery codes are the standard FIDO2 complement)
  - Else → `"Email + recovery codes"` (greenfield opinion: email link covers the common case; recovery codes provide a fallback when email access is also lost — e.g., device-reset scenarios. Adding phone recovery should be an explicit opt-in because it introduces phone PII obligations)

### Auth.Q10: "What password policy should be enforced?"
- **Type**: Object
- **Sub-fields**:
  - `minLength`: integer (minimum password length)
  - `complexity`: `"none"` | `"lowercase+uppercase"` | `"letters+numbers"` | `"letters+numbers+symbols"`
  - `breachCheck`: `"hibp-on-signup"` | `"hibp-on-change"` | `"hibp-both"` | `"none"`
  - `maxAge`: days before forced password rotation, or `"none"` (most modern guidance discourages rotation unless breached)
  - `history`: number of previous passwords to block re-use, or `"none"`
- **Condition**: `auth.idps[]` includes `"Email + password"` — **SKIP this question entirely if `"Email + password"` is not in `auth.idps[]`**
- **Updates**: `auth.passwordPolicy` (object)
- **Downstream**: Security phase reads `auth.passwordPolicy.breachCheck` for authentication security score; synthesized ADR notes HIBP API dependency
- **Default**:
  - If `dataArchitecture.compliance∈{HIPAA,SOC2,PCI-DSS}` → `minLength: 12`, `complexity: "letters+numbers+symbols"`, `breachCheck: "hibp-both"`, `maxAge: 90`, `history: 12` (NIST 800-63B + PCI-DSS v4 mandate minimum 12 characters; breached-password checks are explicitly recommended; history prevents cycling; 90-day rotation is still required by PCI-DSS v4 for privileged accounts)
  - If `architecturalFraming.scaleTarget='enterprise'` → `minLength: 12`, `complexity: "letters+numbers"`, `breachCheck: "hibp-both"`, `maxAge: "none"`, `history: 5` (NIST SP 800-63B guidance: long passwords beat complexity rules; breach checks are more effective than rotation; history prevents the "Password1!" / "Password2!" pattern)
  - If `auth.strategy` includes `"Hosted"` → `minLength: 8`, `complexity: "none"`, `breachCheck: "hibp-on-signup"`, `maxAge: "none"`, `history: "none"` (hosted providers typically enforce their own password policies; defer to provider defaults; override only for compliance reasons)
  - If `architecturalFraming.scaleTarget='hobby'` → `minLength: 8`, `complexity: "none"`, `breachCheck: "none"`, `maxAge: "none"`, `history: "none"` (hobby apps prioritize frictionless login; full policy adds complexity without meaningful benefit at hobby scale)
  - Else → `minLength: 12`, `complexity: "letters+numbers"`, `breachCheck: "hibp-on-signup"`, `maxAge: "none"`, `history: 5` (greenfield opinion: 12-char minimum aligns with NIST 800-63B; HIBP check on signup blocks the top-10K most-breached passwords at zero UX cost; no forced rotation — NIST guidance shows rotation leads to predictable increment patterns, not stronger passwords)

### Auth.Q11: "What should the auth audit log capture, and for how long?"
- **Type**: Object
- **Sub-fields**:
  - `events` (multi-select): `"login-success"` | `"login-failure"` | `"logout"` | `"password-change"` | `"mfa-enrollment"` | `"mfa-challenge"` | `"token-refresh"` | `"account-created"` | `"account-deleted"` | `"role-change"` | `"permission-escalation"` | `"api-key-issued"` | `"api-key-revoked"` | `"admin-impersonation"` | `"None"`
  - `retention`: `"30d"` | `"90d"` | `"1y"` | `"3y"` | `"7y"` | `"indefinite"` | `"none"`
  - `storage`: `"app-db"` | `"separate-audit-db"` | `"log-aggregator (Datadog, Splunk)"` | `"provider-managed"`
  - `immutable`: `boolean` — whether audit records are append-only / tamper-evident
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.auditLog` (object)
- **Downstream**: Security phase cross-references `auth.auditLog.retention` for compliance gap analysis; Runtime Operations phase reads `auth.auditLog.storage` for log pipeline configuration
- **Default**:
  - If `dataArchitecture.compliance` includes `"HIPAA"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","mfa-challenge","role-change","permission-escalation","admin-impersonation"]`, `retention: "7y"`, `storage: "separate-audit-db"`, `immutable: true` (HIPAA §164.312(b) requires audit controls; 6-year retention minimum rounded to 7y; tamper-evidence is a reasonable safeguard)
  - If `dataArchitecture.compliance` includes `"SOC2"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","role-change","permission-escalation","api-key-issued","api-key-revoked"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: true` (SOC 2 CC6.x controls require access monitoring; 1y covers typical audit periods; log aggregator enables alerting and anomaly detection)
  - If `dataArchitecture.compliance` includes `"PCI-DSS"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","mfa-challenge","role-change","permission-escalation","api-key-issued","api-key-revoked"]`, `retention: "1y"`, `storage: "separate-audit-db"`, `immutable: true` (PCI DSS Req 10 mandates comprehensive logging of all cardholder data access and authentication events; 12-month active retention required)
  - If `architecturalFraming.scaleTarget='enterprise'` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","mfa-challenge","role-change","permission-escalation","admin-impersonation","api-key-issued","api-key-revoked"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: true` (enterprise audit requirements even without formal compliance programs; log aggregator integrates with SIEM)
  - If `architecturalFraming.scaleTarget='hobby'` → `events: ["login-failure","account-created","account-deleted"]`, `retention: "30d"`, `storage: "app-db"`, `immutable: false` (minimal logging for hobby apps — login failures help debug auth issues; 30d is sufficient; no overhead of separate storage)
  - Else → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","role-change","account-created","account-deleted"]`, `retention: "90d"`, `storage: "app-db"`, `immutable: false` (greenfield opinion: capture the eight highest-signal events as a baseline — login failures and role changes catch most account-takeover and insider threat patterns; 90d is long enough to investigate incidents without the cost of year-long retention)

### Auth.Q12: "Where should authentication and authorization be enforced?"
- **Type**: Multi-select
- **Options**: "Middleware (global request interceptor)" | "Route guards (per-route decorator/handler)" | "DB-level RLS (Postgres policy)" | "API gateway (upstream enforcement before app)" | "Service mesh (sidecar policy)" | "None — enforced inside handlers"
- **Condition**: `auth.strategy ≠ "None — no auth in scope"`
- **Updates**: `auth.enforcementPoint[]`
- **Downstream**: Security phase reads `auth.enforcementPoint[]` for defense-in-depth analysis; scaffolding generates middleware stubs / RLS policy templates based on selected points
- **Default**:
  - If `architecturalFraming.topology='microservices'` AND `architecturalFraming.scaleTarget='enterprise'` → `["API gateway (upstream enforcement before app)", "Middleware (global request interceptor)", "Service mesh (sidecar policy)"]` (enterprise microservices require layered enforcement: gateway blocks unauthenticated traffic at the perimeter, middleware enforces per-service policies, sidecar handles lateral movement between services)
  - If `architecturalFraming.topology='microservices'` → `["API gateway (upstream enforcement before app)", "Middleware (global request interceptor)"]` (gateway handles perimeter auth; each service still validates tokens independently — defense-in-depth without the sidecar overhead at startup scale)
  - If `dataArchitecture.multiTenancy∈{row-level,schema-per-tenant}` AND `dataArchitecture.engine` includes `postgresql` → `["Middleware (global request interceptor)", "DB-level RLS (Postgres policy)"]` (middleware checks token validity, RLS enforces tenant isolation at the data layer — belt-and-suspenders for multi-tenant data integrity)
  - If `auth.sessionModel.storage='httpOnly-cookie'` AND `architecturalFraming.topology∈{monolith,modular-monolith}` → `["Middleware (global request interceptor)", "Route guards (per-route decorator/handler)"]` (monolith with cookie sessions: global middleware handles cookie validation and injects user context, route guards enforce per-endpoint permission rules)
  - If `architecturalFraming.topology='serverless'` → `["Middleware (global request interceptor)", "API gateway (upstream enforcement before app)"]` (serverless functions can't maintain long-lived middleware processes; API gateway offloads cold-start auth overhead; function-level middleware validates the gateway-issued token)
  - Else → `["Middleware (global request interceptor)", "Route guards (per-route decorator/handler)"]` (greenfield opinion: middleware + route guards is the most universal combination — middleware handles token extraction and session injection globally, route guards handle permission checks at the resource level. DB-level RLS should be added as a second layer whenever the DB engine supports it)

**>>> SYNTHESIS PAUSE**: After Auth.Q12, invoke `Skill(synthesis-review, phaseId: "auth")`. Wait for the developer to Approve/Adjust/Skip each section before moving to Step 6: Privacy.

---

## Step 6: Privacy (11 questions + Gate)

> **Round 3 (alpha.4):** Privacy classifies the data captured in dataArchitecture and feeds Security + Runtime Operations. When `auth.strategy='none'`, the wizard fires a single-Q Gate first. If "No data collected", Privacy synthesisStatus='n/a' and Q1-Q11 are skipped. Synthesis output: `docs/adr/privacy.html` + `.md`.

### Privacy.Gate: "Do you collect any user data at all (emails, IPs, behavioral analytics, contact form submissions)?"
- **Type**: Choice
- **Options**: "Yes" | "No"
- **Condition**: `auth.strategy = 'none'` (fires only in skip-cascade case)
- **Updates**: `privacy.synthesisStatus` (`'complete'` if Yes; `'n/a'` if No)
- **Skip-cascade**: If "No" → Privacy.Q1-Q11 all skipped; synthesis renders stub-only template; phaseStatus.privacy.status='skipped' (for un-skip detection in `pickup`)
- **Default**: `"Yes"` (greenfield opinion: even no-auth apps usually collect minimal telemetry, IPs, or contact-form submissions — answer carefully)

### Privacy.Q1: "Which regulatory frameworks apply to your data handling?"
- **Type**: Multi-select
- **Options**: "GDPR (EU / EEA)" | "UK-GDPR" | "CCPA / CPRA (California)" | "LGPD (Brazil)" | "PIPEDA (Canada)" | "HIPAA (US health data)" | "COPPA (under-13 users)" | "None — no regulatory scope yet"
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.regulations[]`
- **Downstream**: Privacy.Q3 (lawful basis) fires only if GDPR/UK-GDPR in this list; Privacy.Q7 (DSAR) fires only if GDPR or CCPA present; Privacy.Q11 (access audit) is mandatory if HIPAA present; Security phase reads `privacy.regulations[]` for compliance threat surface
- **Default**:
  - If `dataArchitecture.compliance∈{GDPR-aware}` → pre-fill `["GDPR (EU / EEA)"]` (propagated from dataArchitecture phase — extend if additional jurisdictions apply)
  - If `dataArchitecture.compliance∈{HIPAA}` → pre-fill `["HIPAA (US health data)"]` (propagated from dataArchitecture compliance selection)
  - If `dataArchitecture.compliance∈{SOC2,PCI-DSS}` AND `architecturalFraming.scaleTarget∈{production-scale,enterprise}` → pre-fill `["GDPR (EU / EEA)", "CCPA / CPRA (California)"]` (greenfield opinion: production apps serving international users should at minimum address GDPR and CCPA — they cover the two largest regulatory jurisdictions with highest enforcement activity)
  - If `architecturalFraming.scaleTarget='enterprise'` AND `dataArchitecture.compliance` not set → `["GDPR (EU / EEA)", "CCPA / CPRA (California)"]` (enterprise deployments almost always span EU and US users; assume both unless geographic scope is explicitly US-only)
  - If `architecturalFraming.scaleTarget='hobby'` → `["None — no regulatory scope yet"]` (hobby apps rarely need formal compliance; revisit before launching to real users)
  - Else → `["GDPR (EU / EEA)"]` (greenfield opinion: GDPR is the highest-bar regulation and a superset of many others — building to GDPR now avoids costly retrofits if the product expands into Europe)

### Privacy.Q2: "What categories of PII does the app collect or process?"
- **Type**: Multi-select
- **Options**: "Email address" | "Full name" | "Physical address" | "Phone number" | "Precise location (GPS)" | "Approximate location (IP-derived)" | "Payment card data" | "Bank account details" | "Health / medical data" | "Biometric data" | "Behavioral analytics (clicks, sessions, heatmaps)" | "Device fingerprint / user agent" | "Government ID / SSN" | "None — no PII collected"
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.piiCategories[]`
- **Downstream**: Privacy.Q4 (retention) scopes per-category defaults; Privacy.Q8 (processors) cross-refs which categories are shared; Security phase reads `privacy.piiCategories[]` for data-breach impact scoring
- **Default**:
  - If `auth.idps[]` includes `"Email + password"` OR any social IdP → auto-include `"Email address"` (any email-based IdP or social login collects at minimum the user's email)
  - If `auth.idps[]` includes `"Phone / SMS OTP"` OR `auth.recovery` includes phone → auto-include `"Phone number"` (SMS-based flows require phone number collection and storage)
  - If `apiIntegration.externalServices` includes any payment processor (Stripe, Braintree, etc.) → auto-include `"Payment card data"` (tokenized or not, payment flows process card data — may be processor-scoped but PII inventory must acknowledge it)
  - If `dataArchitecture.compliance∈{HIPAA}` → auto-include `"Health / medical data"` (HIPAA scope implies health data collection by definition)
  - If `architecturalFraming.scaleTarget∈{startup,production-scale,enterprise}` → auto-include `"Behavioral analytics (clicks, sessions, heatmaps)"` (production apps almost always instrument some form of behavioral analytics for product decisions)
  - Else → `["Email address", "Approximate location (IP-derived)"]` (greenfield opinion: most web apps collect at minimum an email for auth and IP address for logging — acknowledge both even if no explicit location feature is planned)

### Privacy.Q3: "What is the lawful basis for processing each PII category?"
- **Type**: Object (one entry per PII category from Privacy.Q2)
- **Sub-fields** (per category):
  - `basis`: `"consent"` | `"contract"` | `"legitimate interest"` | `"vital interest"` | `"legal obligation"` | `"public task"`
  - `notes`: free-text rationale (optional but recommended for audit trail)
- **Condition**: `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` — **SKIP this question entirely if neither GDPR nor UK-GDPR is in `privacy.regulations[]`**
- **Updates**: `privacy.lawfulBasis` (object keyed by PII category)
- **Downstream**: Synthesis renders lawful-basis table in `docs/adr/privacy.html`; Security phase flags if `"consent"` is basis for sensitive categories (biometric, health) — revocable consent requires consent-withdrawal flows
- **Default**:
  - If `auth.strategy ≠ 'none'` AND category is `"Email address"` → `basis: "contract"` (email is required to fulfill the user account contract — login, password reset, transactional notifications)
  - If category is `"Behavioral analytics (clicks, sessions, heatmaps)"` → `basis: "consent"` (analytics is not necessary for contract fulfillment; GDPR Article 6 requires explicit consent for non-essential processing)
  - If category is `"Payment card data"` AND `apiIntegration.externalServices` includes payment processor → `basis: "contract"` (payment processing is necessary to fulfill the purchase contract)
  - If category is `"Health / medical data"` → `basis: "consent"` (GDPR Article 9 special category — explicit consent is the safest and most common basis for health data unless you are a healthcare provider with legal obligation)
  - If category is `"Approximate location (IP-derived)"` → `basis: "legitimate interest"` (IP-based geolocation for fraud detection and rate-limiting passes the legitimate-interest balancing test for most apps)
  - Else → `basis: "legitimate interest"` (greenfield opinion: legitimate interest is a reasonable starting basis for many processing activities, but it requires a documented balancing test — replace with `contract` where the data is strictly necessary to provide the service)

### Privacy.Q4: "What data retention periods apply per PII category?"
- **Type**: Object (one entry per PII category from Privacy.Q2)
- **Sub-fields** (per category):
  - `period`: e.g., `"90d"` | `"1y"` | `"3y"` | `"7y"` | `"duration-of-account"` | `"indefinite"` | `"session-only"`
  - `deletionTrigger`: `"account-deletion"` | `"user-request"` | `"expiry"` | `"regulatory-mandate"` | `"manual-review"`
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.retention` (object keyed by PII category)
- **Downstream**: Privacy.Q5 (deletion flow) uses retention periods to scope deletion logic; Security phase reads retention to flag long-lived sensitive data as elevated breach risk
- **Default**:
  - If `privacy.regulations[]` includes `"HIPAA"` AND category is `"Health / medical data"` → `period: "7y"`, `deletionTrigger: "regulatory-mandate"` (HIPAA requires 6-year minimum record retention from date of creation or date last in effect; rounded to 7y for safety)
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `period: "duration-of-account"`, `deletionTrigger: "account-deletion"` (GDPR data minimization principle: retain only as long as necessary; account-duration is the most defensible default for account-linked data)
  - If category is `"Payment card data"` → `period: "7y"`, `deletionTrigger: "regulatory-mandate"` (financial records typically require 7-year retention for tax/audit compliance; card data itself should be tokenized and not stored raw)
  - If category is `"Behavioral analytics (clicks, sessions, heatmaps)"` → `period: "90d"`, `deletionTrigger: "expiry"` (analytics data loses product value after 90d for most apps; longer retention inflates breach impact without proportionate benefit)
  - If category is `"Approximate location (IP-derived)"` → `period: "90d"`, `deletionTrigger: "expiry"` (IP logs are primarily useful for fraud investigation; 90d covers most incident response windows)
  - Else → `period: "duration-of-account"`, `deletionTrigger: "account-deletion"` (greenfield opinion: account-linked data should expire when the account is deleted — this is the simplest policy to implement correctly and satisfies most regulators' data minimization requirements)

### Privacy.Q5: "How should the app handle user data deletion requests?"
- **Type**: Choice
- **Options**: "Hard delete (immediate, irreversible purge)" | "Soft delete + anonymization (nullify PII fields, retain record shell)" | "Soft delete with grace window (restore possible within N days)" | "Deletion request workflow (user submits request, admin processes within SLA)" | "No deletion flow — data retained per retention schedule only"
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.deletionFlow`
- **Downstream**: Synthesis generates deletion flow ADR section; Security phase reads deletion approach for breach-notification readiness scoring
- **Default**:
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` OR `"CCPA / CPRA (California)"` → `"Soft delete + anonymization (nullify PII fields, retain record shell)"` (GDPR Article 17 right to erasure; CCPA right to deletion — soft delete + anonymization satisfies erasure obligations while preserving referential integrity for financial/audit records)
  - If `auth.lifecycle.accountDeletion='self-serve-immediate'` → `"Hard delete (immediate, irreversible purge)"` (if account deletion is self-serve and immediate, data deletion should follow the same model for consistency)
  - If `auth.lifecycle.accountDeletion='self-serve-soft-delete'` → `"Soft delete with grace window (restore possible within N days)"` (align with the account deletion model; grace window allows accidental-deletion recovery before purge)
  - If `architecturalFraming.scaleTarget='enterprise'` → `"Deletion request workflow (user submits request, admin processes within SLA)"` (enterprise apps often need deletion to be a controlled event with approvals, especially when financial records or contractual data is involved)
  - If `architecturalFraming.scaleTarget='hobby'` → `"Hard delete (immediate, irreversible purge)"` (simplest implementation; hobby apps rarely have audit-trail requirements that mandate soft-delete)
  - Else → `"Soft delete + anonymization (nullify PII fields, retain record shell)"` (greenfield opinion: soft delete + anonymization is the safest default — it satisfies regulatory erasure obligations, preserves aggregate analytics, and avoids foreign-key integrity failures that hard delete causes in relational schemas)

### Privacy.Q6: "What consent management approach should the app use?"
- **Type**: Object
- **Sub-fields**:
  - `mechanism`: `"cookie-banner (IAB TCF)"` | `"custom-consent-modal"` | `"settings-page-only"` | `"implied-consent (privacy-policy link)"` | `"none"`
  - `granularity`: `"all-or-nothing"` | `"by-category (analytics / marketing / functional)"` | `"per-vendor"`
  - `storage`: `"cookie"` | `"db-per-user"` | `"local-storage"` | `"none"`
  - `withdrawalFlow`: `"settings-toggle"` | `"support-email"` | `"none"`
- **Condition**: `privacy.piiCategories[]` includes `"Behavioral analytics"` OR `apiIntegration.externalServices` includes any marketing/ads tool — **SKIP this question entirely if neither condition is met**
- **Updates**: `privacy.consentManager` (object)
- **Downstream**: Synthesis generates cookie-policy section in `docs/adr/privacy.html`; scaffolding suggests consent-library (e.g., Cookiebot, Osano) if IAB TCF selected
- **Default**:
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `mechanism: "cookie-banner (IAB TCF)"`, `granularity: "by-category (analytics / marketing / functional)"`, `storage: "db-per-user"`, `withdrawalFlow: "settings-toggle"` (GDPR requires prior consent for non-essential cookies; IAB TCF is the industry standard; per-category granularity is required; withdrawal must be as easy as giving consent)
  - If `privacy.regulations[]` includes `"CCPA / CPRA (California)"` AND NOT GDPR → `mechanism: "custom-consent-modal"`, `granularity: "all-or-nothing"`, `storage: "cookie"`, `withdrawalFlow: "settings-toggle"` (CCPA opt-out model vs GDPR opt-in; simpler implementation but must offer "Do Not Sell My Personal Information" link)
  - If `architecturalFraming.scaleTarget='hobby'` → `mechanism: "implied-consent (privacy-policy link)"`, `granularity: "all-or-nothing"`, `storage: "none"`, `withdrawalFlow: "none"` (hobby apps outside EU/CA can use implied consent with a privacy policy link; revisit if you plan to serve EU users)
  - If `architecturalFraming.scaleTarget='enterprise'` → `mechanism: "cookie-banner (IAB TCF)"`, `granularity: "per-vendor"`, `storage: "db-per-user"`, `withdrawalFlow: "settings-toggle"` (enterprise apps must demonstrate consent auditability; per-vendor granularity is required for GDPR DPA relationships)
  - Else → `mechanism: "custom-consent-modal"`, `granularity: "by-category (analytics / marketing / functional)"`, `storage: "db-per-user"`, `withdrawalFlow: "settings-toggle"` (greenfield opinion: a custom modal gives you design control while implementing category-level consent; storing consent in the DB (not just a cookie) ensures consent records survive cookie clearing and can be exported in DSAR responses)

### Privacy.Q7: "What data subject access request (DSAR) / data export flow is needed?"
- **Type**: Object
- **Sub-fields**:
  - `flow`: `"self-serve-portal"` | `"email-request-to-support"` | `"in-app-download"` | `"none"`
  - `format`: `"JSON"` | `"CSV"` | `"PDF"` | `"multiple-formats"`
  - `sla`: `"30d"` | `"45d"` | `"72h-breach-only"` | `"best-effort"` | `"none"`
  - `scope`: `"all-data"` | `"user-generated-data-only"` | `"account-data-only"`
- **Condition**: `privacy.regulations[]` includes `"GDPR (EU / EEA)"`, `"UK-GDPR"`, OR `"CCPA / CPRA (California)"` — **SKIP this question entirely if none of these regulations are in `privacy.regulations[]`**
- **Updates**: `privacy.dsar` (object)
- **Downstream**: Synthesis generates DSAR process ADR section; scaffolding suggests data-export service patterns if `flow='in-app-download'`
- **Default**:
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `flow: "in-app-download"`, `format: "JSON"`, `sla: "30d"`, `scope: "all-data"` (GDPR Article 15 right of access + Article 20 data portability: 30-day SLA is legally mandated; machine-readable format required for portability; all personal data in scope)
  - If `privacy.regulations[]` includes `"CCPA / CPRA (California)"` AND NOT GDPR → `flow: "email-request-to-support"`, `format: "CSV"`, `sla: "45d"`, `scope: "all-data"` (CCPA allows 45-day response; email-based flow is compliant for smaller apps; CSV is acceptable format)
  - If `architecturalFraming.scaleTarget='enterprise'` → `flow: "self-serve-portal"`, `format: "multiple-formats"`, `sla: "30d"`, `scope: "all-data"` (enterprise apps should offer self-serve DSAR to reduce support load; multiple formats for accessibility; 30d as conservative default)
  - If `architecturalFraming.scaleTarget='hobby'` AND regulations require DSAR → `flow: "email-request-to-support"`, `format: "JSON"`, `sla: "30d"`, `scope: "user-generated-data-only"` (hobby apps can comply with email-based DSAR workflow; limit export scope to reduce implementation burden)
  - Else → `flow: "in-app-download"`, `format: "JSON"`, `sla: "30d"`, `scope: "all-data"` (greenfield opinion: in-app self-serve download scales better than email-based DSAR as user count grows; JSON is the most interoperable format for data portability)

### Privacy.Q8: "Which third-party services receive or process user PII?"
- **Type**: Multi-select (cross-reference `apiIntegration.externalServices`)
- **Options**: Derived from `apiIntegration.externalServices` list + common additions: "Analytics provider (Mixpanel, Amplitude, PostHog)" | "Error tracker (Sentry, Datadog)" | "Email provider (SendGrid, Resend, Postmark)" | "Payment processor (Stripe, Braintree)" | "CRM (HubSpot, Salesforce)" | "Marketing / ads platform (Meta, Google Ads)" | "Customer support (Intercom, Zendesk)" | "Cloud infrastructure provider (AWS, GCP, Azure)" | "None — no third-party PII sharing"
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.processors[]`
- **Downstream**: Synthesis generates third-party processor table in `docs/adr/privacy.html`; Privacy.Q10 (cross-border transfer) uses processors list to identify data residency implications; Security phase reads processors list for supply-chain risk
- **Default**:
  - If `apiIntegration.externalServices` includes analytics tools → auto-include relevant analytics processor (processors list is pre-filled from `apiIntegration.externalServices` — review and confirm rather than start from scratch)
  - If `apiIntegration.externalServices` includes payment services → auto-include payment processor entry
  - If `auth.strategy` includes `"Hosted"` (Clerk, Auth0, etc.) → auto-include the auth provider as a processor (hosted auth providers process user credentials and PII as data processors — DPA is required)
  - If `architecturalFraming.scaleTarget∈{startup,production-scale,enterprise}` → auto-include `"Cloud infrastructure provider (AWS, GCP, Azure)"` (your cloud provider is a data processor for all data you store with them — DPA/BAA required for HIPAA)
  - If `auth.strategy='self-hosted-oss'` → auto-include self-hosted auth system as internal processor (greenfield opinion: self-hosted OSS auth (Keycloak, Authentik, Ory) processes user credentials internally — document it in the processor inventory to maintain a complete data-flow map)
  - Else → pre-fill from `apiIntegration.externalServices` where PII handling is likely; prompt user to confirm and add any omitted processors (greenfield opinion: every integration that touches user data needs a DPA — start with your cloud provider and auth system at minimum)

### Privacy.Q9: "What data minimization and anonymization practices will be applied?"
- **Type**: Multi-select
- **Options**: "IP truncation before storage (last octet removed)" | "Anonymize analytics events after 90 days" | "Hash or tokenize PII in logs" | "Pseudonymize user IDs in analytics pipelines" | "Aggregate-only reporting (no individual-level data retained)" | "Differential privacy for exported aggregates" | "None — no minimization techniques applied"
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.minimization`
- **Downstream**: Security phase reads minimization list for breach-impact scoring (minimized data = lower severity); Synthesis notes minimization practices in `docs/adr/privacy.html`
- **Default**:
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `["IP truncation before storage (last octet removed)", "Anonymize analytics events after 90 days", "Pseudonymize user IDs in analytics pipelines"]` (GDPR Article 5(1)(c) data minimization principle; IP truncation means truncated IPs are no longer personal data under GDPR recital 26; anonymization after 90d removes GDPR obligations from historical analytics)
  - If `privacy.piiCategories[]` includes `"Health / medical data"` OR `"Biometric data"` → `["Hash or tokenize PII in logs", "Pseudonymize user IDs in analytics pipelines"]` (sensitive special-category data should never appear in plaintext in logs; tokenization limits blast radius on log exfiltration)
  - If `architecturalFraming.scaleTarget∈{production-scale,enterprise}` → `["IP truncation before storage (last octet removed)", "Pseudonymize user IDs in analytics pipelines", "Hash or tokenize PII in logs"]` (production apps should minimize PII surface area as a defense-in-depth measure — breach impact is directly proportional to the PII retained)
  - If `architecturalFraming.scaleTarget='hobby'` → `["IP truncation before storage (last octet removed)"]` (IP truncation is low-effort, high-value — implement it even for hobby apps since it's one line of middleware)
  - Else → `["IP truncation before storage (last octet removed)", "Anonymize analytics events after 90 days"]` (greenfield opinion: IP truncation and analytics anonymization are the two highest-ROI minimization techniques — minimal engineering effort, significant reduction in GDPR and breach-severity exposure)

### Privacy.Q10: "What cross-border data transfer mechanisms and residency constraints apply?"
- **Type**: Object
- **Sub-fields**:
  - `residencyConstraints`: `"EU-only"` | `"US-only"` | `"country-specific (specify)"` | `"no-constraints"` | `"unknown"`
  - `transferMechanisms` (multi-select): `"EU adequacy decision"` | `"Standard Contractual Clauses (SCC)"` | `"Binding Corporate Rules (BCR)"` | `"Data Processing Agreement (DPA)"` | `"None — no cross-border transfers"` | `"Unknown — needs legal review"`
  - `primaryRegion`: cloud region (e.g., `"eu-west-1"`, `"us-east-1"`) — derived from `architecturalFraming`
- **Condition**: Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **Updates**: `privacy.dataResidency` (object)
- **Downstream**: Synthesis generates cross-border transfer section in `docs/adr/privacy.html`; scaffolding recommends cloud region configuration matching residency constraints; Privacy.Q8 processors list feeds SCC applicability
- **Default**:
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` AND `privacy.processors[]` includes US-based services → `residencyConstraints: "EU-only"`, `transferMechanisms: ["Standard Contractual Clauses (SCC)", "Data Processing Agreement (DPA)"]` (post-Schrems II, SCCs are the primary transfer mechanism for EU→US data flows; DPA is required for each processor)
  - If `privacy.regulations[]` includes `"HIPAA"` → `residencyConstraints: "US-only"`, `transferMechanisms: ["Data Processing Agreement (DPA)"]`, `primaryRegion: "us-east-1"` (HIPAA PHI should remain within US jurisdiction; BAA (which is a form of DPA) required for all processors handling PHI)
  - If `architecturalFraming.scaleTarget='enterprise'` AND `privacy.regulations[]` not empty → `residencyConstraints: "country-specific (specify)"`, `transferMechanisms: ["Standard Contractual Clauses (SCC)", "Data Processing Agreement (DPA)", "Binding Corporate Rules (BCR)"]` (enterprise deployments often have contractual or regulatory data residency requirements — get specific requirements from legal/compliance before choosing region)
  - If `architecturalFraming.scaleTarget='hobby'` → `residencyConstraints: "no-constraints"`, `transferMechanisms: ["None — no cross-border transfers"]` (hobby apps rarely have cross-border data transfer obligations; revisit before serving EU users)
  - If `auth.strategy='self-hosted-oss'` AND `privacy.regulations[]` includes GDPR → `residencyConstraints: "EU-only"`, `transferMechanisms: ["Data Processing Agreement (DPA)"]` (self-hosted auth keeps credentials on your infrastructure — ensure your cloud region is EU-based and your cloud provider has an EU DPA)
  - Else → `residencyConstraints: "no-constraints"`, `transferMechanisms: ["Data Processing Agreement (DPA)"]` (greenfield opinion: even without strict residency constraints, sign DPAs with every processor that handles user data — it's a lightweight compliance requirement that becomes mandatory as soon as any EU users sign up)

### Privacy.Q11: "Should the app maintain a PII access audit log (who accessed what data, when)?"
- **Type**: Object
- **Sub-fields**:
  - `enabled`: `true` | `false`
  - `events` (multi-select): `"user-record-read"` | `"user-record-update"` | `"user-record-export"` | `"admin-lookup"` | `"bulk-export"` | `"deletion-request"` | `"consent-change"`
  - `retention`: `"90d"` | `"1y"` | `"6y"` | `"7y"` | `"indefinite"`
  - `storage`: `"app-db"` | `"separate-audit-db"` | `"log-aggregator (Datadog, Splunk)"` | `"immutable-object-store (S3 Object Lock)"`
  - `immutable`: `boolean`
- **Condition**: Mandatory if `privacy.regulations[]` includes `"HIPAA"` — **SKIP this question (default to `enabled: false`) if `privacy.piiCategories[]` contains only non-sensitive categories AND `privacy.regulations[]` does not include HIPAA, GDPR, or CCPA**
- **Updates**: `privacy.accessAudit` (object)
- **Downstream**: Security phase reads `privacy.accessAudit.enabled` for insider-threat mitigation score; auth audit log cross-reference ensures no coverage gap between `auth.auditLog` (authentication events) and `privacy.accessAudit` (data access events)
- **Default**:
  - If `privacy.regulations[]` includes `"HIPAA"` → `enabled: true`, `events: ["user-record-read","user-record-update","user-record-export","admin-lookup","bulk-export","deletion-request"]`, `retention: "7y"`, `storage: "separate-audit-db"`, `immutable: true` (HIPAA §164.312(b) audit control standard: access to PHI must be logged; 6-year minimum rounded to 7y; tamper-evidence is required for audit defensibility; separate DB ensures log integrity if app DB is compromised)
  - If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `enabled: true`, `events: ["user-record-read","admin-lookup","user-record-export","deletion-request","consent-change"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: false` (GDPR accountability principle requires ability to demonstrate lawful processing; access logs support data breach response and DSAR fulfillment audit trails)
  - If `privacy.piiCategories[]` includes `"Health / medical data"` OR `"Biometric data"` → `enabled: true`, `events: ["user-record-read","admin-lookup","bulk-export","user-record-export"]`, `retention: "1y"`, `storage: "separate-audit-db"`, `immutable: true` (special-category data access should always be logged — insider threat risk is highest for sensitive categories)
  - If `architecturalFraming.scaleTarget='enterprise'` → `enabled: true`, `events: ["user-record-read","user-record-update","admin-lookup","bulk-export","deletion-request","consent-change"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: false` (enterprise apps should log all PII access for compliance audits and insider-threat detection)
  - If `architecturalFraming.scaleTarget='hobby'` → `enabled: false` (hobby apps do not need PII access audit logs; the overhead outweighs the benefit at hobby scale — revisit if the product grows or serves regulated users)
  - Else → `enabled: true`, `events: ["admin-lookup","bulk-export","deletion-request"]`, `retention: "90d"`, `storage: "app-db"`, `immutable: false` (greenfield opinion: log at minimum admin lookups and bulk exports — these are the highest-risk access patterns for PII misuse. 90d covers most incident response windows without long-term storage cost)

**After Privacy.Q11**, invoke synthesis-review inline:

> Invoke `Skill(synthesis-review, phaseId: "privacy")` — renders `docs/adr/privacy.html` and walks the developer through approve/adjust/skip. If `privacy.synthesisStatus='n/a'`, the n/a stub template is used.

---

## Category 3 (residual): Remaining Project Details

> **Round 2 note (2026-05-13):** Several Cat 3 questions have been moved to Step 3 (Data Architecture) and Step 4 (API & Integration). The 13 questions below stay here as a residual step until later rounds re-home them:
> - **Moved to Step 3 (dataArchitecture):** Q3.2 (DB) → P3.Q2+Q3, Q3.16 (codegen) → P3.Q10, Q3.17 (file storage) → P3.Q9
> - **Moved to Step 4 (apiIntegration):** Q3.5 (external APIs) → P4.Q10, Q3.7 (API style) → P4.Q2, Q3.8 (API docs) → P4.Q3, Q3.18 (bg jobs) → P4.Q7
> - **Staying here (Cat 3 residual):** Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 — destined for Rounds 3–6.

This category becomes wizard Step 5 of 11 in Round 2.

### Q3.1: "What's the scale of this project?"
- **Type**: Choice
- **Options**: "Side project / learning" | "Production app (solo)" | "Production app (small team, 2-5)" | "Production app (larger team, 5+)"
- **Condition**: Always
- **Updates**: `isProduction`, `hasTeam`, `teamSize`
- **Downstream**: Agent count, rule strictness, PR template complexity
- **Default**: `"Production app (solo)"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Side project / learning"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Production app (larger team, 5+)"`
  - Else → `"Production app (solo)"` (greenfield opinion: most developers using greenfield are building something real, not just learning)

### Q3.3: "How do you want to handle authentication?"
- **Type**: Choice
- **Options**: "No auth" | "Third-party (Auth0, Clerk, etc.)" | "Built-in (session/JWT)" | "Skip for now"
- **Condition**: `hasFrontend || hasAPI`
- **Updates**: `authStrategy`
- **Default**: `"Third-party (Auth0, Clerk, etc.)"`
  - If `appType: "api"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Built-in (session/JWT)"` (greenfield opinion: API services often need fine-grained JWT control that third-party providers don't expose)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"No auth"` (hobby projects often have a single user)
  - If `stack.stack.framework: "django"` → `"Built-in (session/JWT)"` (Django's auth system is first-class)
  - If `stack.stack.framework: "rails"` → `"Built-in (session/JWT)"` (Devise is idiomatic Rails)
  - Else → `"Third-party (Auth0, Clerk, etc.)"` (greenfield opinion: third-party auth eliminates security footguns around password hashing, session management, and MFA)

### Q3.4: "Where do you want to deploy?"
- **Type**: Choice (research-informed)
- **Options**: Dynamically generated from stack research (e.g., "Vercel — best for Next.js" | "AWS" | "Self-hosted" | "Not deploying")
- **Condition**: Always
- **Updates**: `willDeploy`, `deployTarget`
- **Critical skip**: If "Not deploying" → `willDeploy = false`, skip ALL Category 5 questions
- **Default**: (stack-derived from research — no fixed default)
  - If `stack.stack.framework: "next"` → `"Vercel"` (greenfield opinion: Vercel is Next.js's native platform with zero-config deployments)
  - If `stack.stack.framework: "nuxt"` → `"Vercel"` or `"Netlify"`
  - If `stack.stack.language: "python"` AND `stack.stack.framework: "fastapi"` → `"Railway"` or `"Fly.io"` (container-native platforms for Python APIs)
  - If `stack.stack.language: "python"` AND `stack.stack.framework: "django"` → `"Railway"` or `"Heroku"`
  - If `stack.stack.language: "go"` → `"Fly.io"` (small binaries, fast cold starts)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"AWS"` (greenfield opinion: AWS for enterprise compliance + ecosystem)
  - Else → show research-informed options with no preselection

### Q3.6: "What's your monitoring and observability strategy?"
- **Type**: Multi-select
- **Options**: "Logging framework" | "Error tracking (Sentry, etc.)" | "Analytics" | "Uptime monitoring" | "Not needed yet"
- **Condition**: `isProduction`
- **Updates**: `monitoring`
- **Default**: `["Error tracking (Sentry, etc.)", "Logging framework"]`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `["Logging framework", "Error tracking (Sentry, etc.)", "Analytics", "Uptime monitoring"]`
  - If `architecturalFraming.scaleTarget: "hobby"` → `["Not needed yet"]`
  - Else → `["Error tracking (Sentry, etc.)", "Logging framework"]` (greenfield opinion: Sentry + structured logging is the minimum viable observability stack; it catches 80% of production issues)

### Q3.9: "How do you want to manage environment variables and secrets?"
- **Type**: Choice
- **Options**: "Standard .env files" | "Platform-managed (Vercel env, AWS SM)" | "Vault/Doppler" | "Recommend based on deploy target"
- **Condition**: Always
- **Updates**: `envStrategy`
- **Default**: `"Platform-managed (Vercel env, AWS SM)"`
  - If `Q3.4.deployTarget: "vercel"` → `"Platform-managed (Vercel env, AWS SM)"`
  - If `Q3.4.deployTarget: "aws"` → `"Platform-managed (Vercel env, AWS SM)"` (AWS Secrets Manager)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Standard .env files"` (greenfield opinion: .env is fine for hobby projects with no secrets rotation requirements)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Vault/Doppler"` (greenfield opinion: enterprise secrets need rotation, audit logs, and access control)
  - Else → `"Platform-managed (Vercel env, AWS SM)"` (greenfield opinion: platform-managed secrets are zero-overhead and work out of the box)

### Q3.10: "Do you want Docker for local development or deployment?"
- **Type**: Choice
- **Options**: "Docker + compose for local dev" | "Docker for deployment only" | "Both" | "No Docker"
- **Condition**: Always (recommend based on stack + deploy)
- **Updates**: `dockerStrategy`
- **Default**: `"No Docker"`
  - If `architecturalFraming.topology: "microservices"` → `"Both"` (greenfield opinion: microservices require container orchestration; Docker Compose for local, containers for prod)
  - If `stack.stack.language ∈ (go, rust)` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` → `"Docker for deployment only"` (single binaries; local dev is just `go run` / `cargo run`)
  - If `dataArchitecture.databaseHost ∈ (self-hosted)` → `"Docker + compose for local dev"` (self-hosted DB needs Compose for local parity)
  - Else → `"No Docker"` (greenfield opinion: managed platform deployments handle containers for you; adding Docker locally adds complexity without benefit for most stacks)

### Q3.11: "How do you want to manage dependencies?"
- **Type**: Choice
- **Options**: "Automated updates (auto-merge minor/patch)" | "Automated PRs (I review)" | "Manual"
- **Condition**: Always
- **Updates**: `depManagement`
- **Default**: `"Automated PRs (I review)"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Manual"` (greenfield opinion: hobby projects don't need automated dep management overhead)
  - Else → `"Automated PRs (I review)"` (greenfield opinion: Renovate/Dependabot PRs give security patches without auto-merging untested updates)

### Q3.12: "What level of accessibility compliance do you need?"
- **Type**: Choice
- **Options**: "WCAG 2.1 AA" | "WCAG 2.1 AAA" | "Basic best practices" | "Not a priority"
- **Condition**: `hasFrontend`
- **Updates**: `a11yLevel`
- **Default**: `"Basic best practices"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"WCAG 2.1 AA"` (greenfield opinion: enterprise products face legal a11y requirements in most jurisdictions)
  - If `dataArchitecture.compliance ∈ (HIPAA, SOC 2)` → `"WCAG 2.1 AA"` (regulated industries require AA compliance)
  - Else → `"Basic best practices"` (greenfield opinion: semantic HTML + ARIA labels are achievable without a full AA audit; upgrade to AA when user base demands it)

### Q3.13: "Do you have performance targets or budgets?"
- **Type**: Choice
- **Options**: "Core Web Vitals targets" | "Bundle size budget" | "Both" | "General best practices" | "Not a concern"
- **Condition**: `hasFrontend`
- **Updates**: `perfTargets`
- **Default**: `"General best practices"`
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Both"` (greenfield opinion: at scale, performance regressions have direct revenue impact)
  - If `architecturalFraming.scaleTarget: "startup"` → `"Core Web Vitals targets"` (SEO and UX depend on CWV)
  - Else → `"General best practices"` (greenfield opinion: enforce sensible defaults via linting; formal budgets add overhead that isn't worth it until launch)

### Q3.14: "Does this app need multi-language support (i18n)?"
- **Type**: Choice
- **Options**: "Yes — from day one" | "Not now, but plan for it" | "No — single language"
- **Condition**: `hasFrontend`
- **Updates**: `i18n`
- **Default**: `"No — single language"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Not now, but plan for it"` (greenfield opinion: enterprise products inevitably need i18n; structure strings in i18n-friendly patterns even if not translating yet)
  - Else → `"No — single language"` (greenfield opinion: retrofitting i18n is painful but manageable; adding it day one for a product that may never ship internationally is premature)

### Q3.15: "Is this a monorepo or single package?"
- **Type**: Choice
- **Options**: "Single package" | "Monorepo" (follow-up: which packages?) | "Not sure — recommend"
- **Condition**: Always
- **Updates**: `isMonorepo`, `monorepoPackages`
- **Default**: `"Single package"`
  - If `architecturalFraming.topology: "microservices"` → `"Monorepo"` (greenfield opinion: monorepos are the right default for microservices — shared types, unified CI, easier cross-service refactoring)
  - If `appType: "fullstack"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Monorepo"` (shared types between frontend + backend)
  - Else → `"Single package"` (greenfield opinion: monorepos add tooling complexity; start single-package and split when the pain of shared-code duplication becomes real)

### Q3.F1: "What's your styling approach?" (frontend only)
- **Type**: Choice
- **Options**: "Tailwind CSS" | "CSS Modules" | "styled-components / Emotion" | "Vanilla CSS / SASS" | "Component library" | "Recommend"
- **Condition**: `hasFrontend`
- **Updates**: `stylingApproach`
- **Default**: `"Tailwind CSS"`
  - If `stack.stack.framework ∈ (next, remix, nuxt, sveltekit)` → `"Tailwind CSS"` (greenfield opinion: Tailwind is the idiomatic choice for modern full-stack frameworks; co-located styles, no class naming overhead)
  - If `stack.stack.framework: "angular"` → `"CSS Modules"` (Angular's encapsulated styles map naturally to CSS Modules)
  - Else → `"Tailwind CSS"` (greenfield opinion: Tailwind dominates the modern frontend ecosystem with best-in-class DX)

### Q3.F2: "Do you need a component library?" (frontend only)
- **Type**: Choice
- **Options**: "shadcn/ui" | "MUI" | "Headless UI / Radix" | "Build custom" | "Recommend"
- **Condition**: `hasFrontend`
- **Updates**: `componentLibrary`
- **Default**: `"shadcn/ui"`
  - If `stylingApproach: "tailwind"` AND `stack.stack.framework ∈ (next, remix, nuxt)` → `"shadcn/ui"` (greenfield opinion: shadcn/ui is the highest-quality Tailwind-native component set; copy-paste model means no version lock-in)
  - If `stylingApproach: "tailwind"` → `"Headless UI / Radix"` (Headless UI for accessible unstyled components when shadcn isn't available)
  - If `stack.stack.framework: "angular"` → `"MUI"` (MUI's Angular integration is the most mature)
  - Else → `"shadcn/ui"` (greenfield opinion: shadcn/ui is the current community default for accessible, composable React components)

---

## Category 4: Workflow (adaptive)

### Q4.1: "What branching strategy works for you?"
- **Type**: Choice (recommendation based on team size)
- **Options**: "[Recommended]" | "Gitflow-lite (main + develop)" | "Trunk-based" | "Explain options"
- **Condition**: Always
- **Updates**: `branchingStrategy`
- **Default**: `"Gitflow-lite (main + develop)"`
  - If `hasTeam: false` → `"Trunk-based"` (greenfield opinion: solo developers ship faster on trunk; branch hygiene is overhead without team collaboration benefits)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Gitflow-lite (main + develop)"` (greenfield opinion: enterprise teams need release branch isolation)
  - Else → `"Gitflow-lite (main + develop)"` (greenfield opinion: main + develop gives a clean separation between stable and in-progress without the overhead of full Gitflow)

### Q4.2: "How do you approach testing?"
- **Type**: Choice
- **Options**: "TDD — tests first" | "Test alongside features" | "Test after — when stable" | "Minimal — critical paths only"
- **Condition**: Always
- **Updates**: `testingPhilosophy`
- **Default**: `"Test alongside features"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Minimal — critical paths only"` (greenfield opinion: hobby projects benefit from fast iteration over comprehensive tests)
  - If `dataArchitecture.compliance ∈ (HIPAA, PCI-DSS, SOC 2)` → `"TDD — tests first"` (regulated industries require test coverage as a compliance artifact)
  - Else → `"Test alongside features"` (greenfield opinion: writing tests alongside features produces better coverage than TDD (which front-loads effort) without the instability of testing-after-the-fact)

### Q4.3: "How much autonomy should Claude have?"
- **Type**: Choice
- **Options**: "Always ask — check before changes" | "Balanced — routine decisions autonomous, big ones ask" | "Autonomous — make decisions, I review"
- **Condition**: Always
- **Updates**: `autonomyLevel`
- **Default**: `"Balanced — routine decisions autonomous, big ones ask"` (always — greenfield opinion: balanced mode is the right starting point for most developers; pure autonomous mode risks unreviewed architectural drift)

### Q4.4: "How strict should code style enforcement be?"
- **Type**: Choice
- **Options**: "Relaxed — guidelines" | "Moderate — standard conventions" | "Strict — enforced everywhere"
- **Condition**: Always
- **Updates**: `codeStyleStrictness`
- **Default**: `"Moderate — standard conventions"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Relaxed — guidelines"` (greenfield opinion: strict enforcement adds friction without team-coordination value for solo hobby projects)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Strict — enforced everywhere"` (greenfield opinion: enterprise codebases need enforced consistency across large teams)
  - Else → `"Moderate — standard conventions"` (greenfield opinion: moderate enforcement covers ESLint + Prettier without blocking every commit)

### Q4.5: "How security-sensitive is this project?"
- **Type**: Choice
- **Options**: "Standard" | "Elevated — handles PII/payments" | "High — compliance (SOC2, HIPAA)"
- **Condition**: Always
- **Updates**: `securitySensitivity`
- **Default**: `"Standard"`
  - If `apiIntegration.externalServices` includes payment providers → `"Elevated — handles PII/payments"`
  - If `dataArchitecture.compliance ∈ (HIPAA, PCI-DSS, SOC 2)` → `"High — compliance (SOC2, HIPAA)"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Elevated — handles PII/payments"` (greenfield opinion: enterprise products typically handle employee/customer PII)
  - Else → `"Standard"` (greenfield opinion: standard security practices cover most projects; elevated = adding SAST scans and secret rotation)

### Q4.6: "How do you want to handle releases?"
- **Type**: Choice
- **Options**: "Semantic versioning + changelog" | "Git tags only" | "Continuous deployment" | "Not relevant"
- **Condition**: `isProduction`
- **Updates**: `releaseStrategy`
- **Default**: `"Semantic versioning + changelog"`
  - If `apiIntegration.style: "public API"` → `"Semantic versioning + changelog"` (greenfield opinion: public APIs must communicate breaking changes through versioning + changelog)
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Git tags only"` (greenfield opinion: hobby projects don't need a formal release process)
  - If `cicdAndDelivery.cicd.deployCadence: "continuous"` → `"Continuous deployment"` (greenfield opinion: continuous cadence implies continuous deployment; don't create a release bottleneck)
  - Else → `"Semantic versioning + changelog"` (greenfield opinion: semver + changelog gives clients predictability and documents intent)

### Q4.7: "How should features be independently verified?"
- **Type**: Choice (informed by stack research)
- **Options**: Dynamically generated based on stack:
  - "Browser automation (Playwright MCP)" — if frontend project
  - "API testing (curl/HTTP requests)" — if API/backend project
  - "CLI execution (run commands, check output)" — if CLI project
  - "Test runner ([detected framework])" — if test framework detected
  - "Combination (recommended for fullstack)" — adapts per feature category
- **Condition**: Always (every project needs verification)
- **Updates**: `verificationStrategy`
- **Downstream**: Configures the feature-evaluator agent's testing approach
- **Default**: `"Combination (recommended for fullstack)"`
  - If `appType: "cli"` → `"CLI execution (run commands, check output)"`
  - If `appType: "api"` AND `!hasFrontend` → `"API testing (curl/HTTP requests)"`
  - If `hasFrontend` AND `!hasBackend` → `"Browser automation (Playwright MCP)"`
  - If `appType: "library"` → `"Test runner ([detected framework])"` (libraries are verified via unit tests, not browser automation)
  - Else → `"Combination (recommended for fullstack)"` (greenfield opinion: fullstack projects need both browser automation for UX flows and API testing for backend logic)

---

## Category 5: CI/CD & Auto-Evolution (conditional: `willDeploy`)

### Q5.1: "When tooling drift is detected, what should the CI pipeline do?"
- **Type**: Choice
- **Options**: "Create a PR with fixes" | "Comment on the commit" | "Create a GitHub issue"
- **Condition**: `willDeploy`
- **Updates**: `ciAuditAction`
- **Default**: `"Create a PR with fixes"` (always — greenfield opinion: automated PRs are actionable; comments and issues require follow-up effort that often gets deferred)

### Q5.2: "Should AI tooling update automatically when code changes?"
- **Type**: Choice
- **Options**: "Auto-update in real-time" | "Log changes, I'll run /greenfield:evolve" | "Just notify me"
- **Condition**: Always (even local projects have local hooks)
- **Updates**: `autoEvolutionMode`
- **Default**: `"Log changes, I'll run /greenfield:evolve"`
  - If `hasTeam: false` → `"Log changes, I'll run /greenfield:evolve"` (greenfield opinion: solo developers prefer explicit control over what gets committed)
  - If `hasTeam: true` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Just notify me"` (greenfield opinion: team projects need human review before tooling changes are applied)
  - Else → `"Log changes, I'll run /greenfield:evolve"` (greenfield opinion: logged changes give the developer a diff to review before applying; auto-update can surprise)

### Q5.3: "Should PRs get AI review automatically?"
- **Type**: Choice
- **Options**: "Auto-review every PR" | "Only when I comment @claude" | "Auto with skip label"
- **Condition**: `willDeploy && hasTeam`
- **Updates**: `prReviewTrigger` AND `phases.cicdAndDelivery._v1_carryover.prReviewTrigger`
- **Default**: `"Only when I comment @claude"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Auto-review every PR"` (greenfield opinion: enterprise teams benefit from consistent automated review)
  - Else → `"Only when I comment @claude"` (greenfield opinion: auto-review every PR can create noise; opt-in keeps signal high)

### Q5.4: "Which CI provider will you use?"
- **Type**: Choice
- **Options**: "GitHub Actions" | "GitLab CI" | "CircleCI" | "BuildKite" | "Jenkins" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.provider`
- **Note**: Round 1 only emits GitHub Actions workflow templates. Non-GHA values are captured but produce a note in synthesis review; non-GHA template support lands in Round 6.
- **Default**: `"GitHub Actions"` (always — greenfield opinion: GitHub Actions is the de facto standard for new projects; zero-overhead integration with GitHub repos, generous free tier)

### Q5.5: "When should CI run?"
- **Type**: Multi-select
- **Options**: "Push to main" | "Every PR" | "Scheduled" | "Manual dispatch" | "On tag"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.triggers[]`
- **Default**: `["Every PR", "Push to main"]`
  - If `architecturalFraming.scaleTarget: "hobby"` → `["Push to main"]` (greenfield opinion: hobby projects don't need PR-level CI; push-to-main is enough)
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `["Every PR", "Push to main", "Scheduled"]` (greenfield opinion: scheduled runs catch dependency-injection or external API failures that only appear after time passes)
  - Else → `["Every PR", "Push to main"]` (greenfield opinion: these two triggers catch the most issues for the least noise)

### Q5.6: "Which checks must pass before a PR can merge?"
- **Type**: Multi-select
- **Options**: "Lint" | "Typecheck" | "Unit tests" | "Integration tests" | "E2E tests" | "Security scan" | "Coverage" | "Build"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.requiredPreMergeChecks[]`
- **Recommend**: Default selection adapts to stack — Node/TS projects get lint+typecheck+unit+build; Python adds ruff in place of lint+typecheck.
- **Default**: `["Lint", "Typecheck", "Unit tests", "Build"]` (for TypeScript)
  - If `stack.stack.language: "typescript"` → `["Lint", "Typecheck", "Unit tests", "Build"]`
  - If `stack.stack.language: "python"` → `["Lint", "Unit tests", "Build"]` (ruff covers lint+typecheck in Python)
  - If `stack.stack.language: "go"` → `["Lint", "Unit tests", "Build"]` (go vet + staticcheck cover typecheck)
  - If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → add `"Integration tests"` and `"Security scan"` to the above
  - If `appType: "fullstack"` → add `"E2E tests"` to the above

### Q5.7: "Coverage threshold — what value blocks merges, if any?"
- **Type**: Composite (numeric + choice + boolean)
- **Sub-questions**:
  - Threshold (numeric 0–100, or `null` for no threshold)
  - Scope: "Global" | "Per-package" | "Per-file"
  - Blocking: yes/no — should coverage drops block PRs?
- **Condition**: `willDeploy && (Q5.6 selection includes "Coverage")`
- **Updates**: `phases.cicdAndDelivery.cicd.coverage.{threshold,scope,blocking}`
- **Default**: Threshold: `80`, Scope: `"Global"`, Blocking: `true`
  - If `architecturalFraming.scaleTarget: "hobby"` → Threshold: `null`, Blocking: `false`
  - If `architecturalFraming.scaleTarget: "enterprise"` → Threshold: `90`, Scope: `"Per-package"`, Blocking: `true`
  - Else → Threshold: `80`, Scope: `"Global"`, Blocking: `true` (greenfield opinion: 80% global coverage is the industry standard baseline; blocking keeps the floor from eroding)

### Q5.8: "Environment ladder — what environments will you deploy to?"
- **Type**: Choice
- **Options**: "Single (prod only)" | "Preview + prod" | "Staging + prod" | "Dev + staging + prod" | "Custom"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.envLadder[]`
- **Recommend**: Default to "Preview + prod" for SaaS; "Single" for hobby projects; "Staging + prod" for B2B with paying customers.
- **Default**: `"Preview + prod"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Single (prod only)"` (greenfield opinion: hobby projects don't need staging environments)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Dev + staging + prod"` (greenfield opinion: enterprise requires environment isolation for compliance and release gates)
  - If `architecturalFraming.scaleTarget: "startup"` AND `Q3.4.deployTarget: "vercel"` → `"Preview + prod"` (Vercel's preview deployments are automatic per-PR)
  - If `architecturalFraming.scaleTarget: "production-scale"` → `"Staging + prod"` (greenfield opinion: staging for regression testing before hitting real users)
  - Else → `"Preview + prod"` (greenfield opinion: preview deployments give per-PR validation without the operational overhead of a persistent staging environment)

### Q5.9: "How does deployment happen?"
- **Type**: Choice
- **Options**: "Auto on merge" | "Manual button" | "Scheduled window" | "Tag-triggered" | "None — I'll deploy by hand"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.autoDeploy`
- **Default**: `"Auto on merge"`
  - If `architecturalFraming.scaleTarget: "hobby"` → `"Auto on merge"` (greenfield opinion: hobby projects benefit from zero-friction deployments)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Manual button"` (greenfield opinion: enterprise deployments need a human sign-off before production traffic is affected)
  - If `releaseStrategy: "Semantic versioning + changelog"` → `"Tag-triggered"` (greenfield opinion: semver releases should be triggered by a signed tag, not every merge)
  - Else → `"Auto on merge"` (greenfield opinion: continuous delivery reduces batch size and makes problems easier to diagnose)

### Q5.10: "Deploy cadence — how often will you ship?"
- **Type**: Choice
- **Options**: "Continuous (multiple per day)" | "Daily" | "Weekly" | "On-demand only" | "Not deploying"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.deployCadence`
- **Default**: `"On-demand only"`
  - If `cicdAndDelivery.cicd.autoDeploy: "Auto on merge"` → `"Continuous (multiple per day)"` (greenfield opinion: auto-on-merge implies continuous cadence)
  - If `architecturalFraming.scaleTarget: "enterprise"` → `"Weekly"` (greenfield opinion: enterprise change management processes typically gate weekly release cycles)
  - If `architecturalFraming.scaleTarget: "startup"` → `"Daily"` (greenfield opinion: startups ship often to learn faster)
  - Else → `"On-demand only"` (greenfield opinion: explicit deploy decisions give the developer control without committing to a schedule)

### Q5.11: "Rollback strategy?"
- **Type**: Composite (choice + boolean)
- **Sub-questions**:
  - Strategy: "Redeploy previous SHA" | "Blue-green" | "Canary" | "None"
  - Automation: yes/no — automated on failure detection?
- **Condition**: `willDeploy && Q5.9 !== "None"`
- **Updates**: `phases.cicdAndDelivery.cicd.rollback.{strategy,automation}`
- **Default**: Strategy: `"Redeploy previous SHA"`, Automation: `false`
  - If `architecturalFraming.scaleTarget: "enterprise"` → Strategy: `"Blue-green"`, Automation: `true` (greenfield opinion: blue-green with automated cutover is the gold standard for zero-downtime enterprise rollback)
  - If `architecturalFraming.scaleTarget: "production-scale"` → Strategy: `"Canary"`, Automation: `false` (greenfield opinion: canary rollouts detect issues in a small traffic slice before full promotion)
  - Else → Strategy: `"Redeploy previous SHA"`, Automation: `false` (greenfield opinion: SHA redeploy is the simplest rollback; automation adds alert-integration complexity that's only worth it at scale)

### Q5.12: "How are CI secrets managed?"
- **Type**: Composite (choice + choice)
- **Sub-questions**:
  - Manager: "Provider-stored (GitHub/GitLab secrets)" | "OIDC to cloud" | "Vault" | "1Password" | "Doppler" | "Manual env files"
  - Rotation: "Manual only" | "Scheduled" | "On incident only"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.secrets.{manager,rotation}`
- **Default**: Manager: `"Provider-stored (GitHub/GitLab secrets)"`, Rotation: `"Manual only"`
  - If `architecturalFraming.scaleTarget: "enterprise"` → Manager: `"Vault"`, Rotation: `"Scheduled"` (greenfield opinion: enterprise requires audit trails and automated rotation)
  - If `Q3.4.deployTarget: "aws"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → Manager: `"OIDC to cloud"` (greenfield opinion: OIDC eliminates long-lived credentials entirely)
  - Else → Manager: `"Provider-stored (GitHub/GitLab secrets)"`, Rotation: `"Manual only"` (greenfield opinion: GitHub/GitLab secrets are encrypted at rest and sufficient for most projects)

### Q5.13: "Where should CI notifications go?"
- **Type**: Composite (multi-select + multi-select)
- **Sub-questions**:
  - Channels (multi-select): "Slack" | "Discord" | "Email" | "GitHub checks only"
  - Events (multi-select): "Build failure" | "Deploy success" | "Deploy failure" | "Security alert"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.notifications.{channels[],events[]}`
- **Note**: Solo developer + Slack channel selection triggers a warning in synthesis review.
- **Default**: Channels: `["GitHub checks only"]`, Events: `["Build failure", "Deploy failure"]`
  - If `hasTeam: true` → Channels: `["Slack"]`, Events: `["Build failure", "Deploy failure", "Deploy success"]`
  - If `architecturalFraming.scaleTarget: "enterprise"` → add `"Security alert"` to Events
  - Else → Channels: `["GitHub checks only"]`, Events: `["Build failure", "Deploy failure"]` (greenfield opinion: GitHub checks are zero-config and sufficient for solo developers; Slack adds setup overhead)

### Q5.14: "Build matrix?"
- **Type**: Composite (multi-select + choice + choice)
- **Sub-questions**:
  - OS targets (multi-select): "ubuntu-latest" | "macos-latest" | "windows-latest"
  - Language versions: "Single (current LTS)" | "Multi (current LTS + previous)"
  - Parallelization: "Auto (CI provider decides)" | "Off (serial)" | numeric value
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.buildMatrix.{os[],languageVersions,parallelization}`
- **Recommend**: Most projects → single ubuntu-latest. Cross-platform tools → multi-OS. Libraries → multi-version.
- **Default**: OS: `["ubuntu-latest"]`, Language versions: `"Single (current LTS)"`, Parallelization: `"Auto (CI provider decides)"`
  - If `appType: "library"` OR `appType: "cli"` → Language versions: `"Multi (current LTS + previous)"` (greenfield opinion: libraries and CLIs must not silently break on older runtimes)
  - If `appType: "cli"` AND `stack.stack.language ∈ (go, rust)` → OS: `["ubuntu-latest", "macos-latest", "windows-latest"]` (cross-platform CLIs must be tested on all target OSes)
  - Else → OS: `["ubuntu-latest"]`, Language versions: `"Single (current LTS)"` (greenfield opinion: ubuntu-latest + current LTS covers 95% of deployment targets)

### Q5.15: "Caching strategy?"
- **Type**: Composite (booleans + choice)
- **Sub-questions**:
  - Deps: cache dependency installs (yes/no)
  - Build: cache build outputs (yes/no)
  - Docker layers: cache Docker layers (yes/no)
  - Remote backend: "Turbo Remote Cache" | "BuildKite Cache" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.caching.{deps,build,dockerLayers,remote}`
- **Default**: Deps: `true`, Build: `false`, Docker layers: `false`, Remote: `"None"`
  - If `isMonorepo: true` → Remote: `"Turbo Remote Cache"`, Build: `true` (greenfield opinion: monorepos with Turborepo benefit enormously from remote caching)
  - If `dockerStrategy ∈ (both, deployment-only)` → Docker layers: `true`
  - Else → Deps: `true`, Build: `false`, Docker layers: `false`, Remote: `"None"` (greenfield opinion: caching deps is a 1-2 min win for free; caching build outputs is only worth it for slow builds)

### Q5.16: "CI time budget?"
- **Type**: Composite (numeric + optional numeric)
- **Sub-questions**:
  - Per-pipeline target minutes
  - Blocking threshold minutes (optional — pipelines exceeding this fail; null means no block)
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.timeBudget.{perPipelineMinutes,blockingThresholdMinutes}`
- **Default**: Per-pipeline: `10`, Blocking threshold: `null`
  - If `architecturalFraming.scaleTarget: "hobby"` → Per-pipeline: `5`, Blocking threshold: `null`
  - If `architecturalFraming.scaleTarget: "enterprise"` → Per-pipeline: `15`, Blocking threshold: `20`
  - Else → Per-pipeline: `10`, Blocking threshold: `null` (greenfield opinion: 10 minutes is the standard target for fast-feedback CI; blocking thresholds add enforcement only when time budgets are a formal team requirement)

### Q5.17: "Release pipeline?"
- **Type**: Composite (boolean + choice + choice)
- **Sub-questions**:
  - Separate from main CI: yes/no
  - Triggered by: "Tag" | "Manual" | "Schedule"
  - Convention: "release-please" | "semantic-release" | "Manual" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.releasePipeline.{separate,triggeredBy,convention}`
- **Note**: `release-please` and `semantic-release` are Node-centric. Mismatches with `stack.stack.framework` (non-Node stacks) trigger a synthesis warning.
- **Default**: Separate: `false`, Triggered by: `"Tag"`, Convention: `"None"`
  - If `releaseStrategy: "Semantic versioning + changelog"` AND `stack.stack.language: "typescript"` → Convention: `"release-please"`, Triggered by: `"Tag"` (greenfield opinion: release-please automates changelog generation from conventional commits)
  - If `releaseStrategy: "Continuous deployment"` → Separate: `false`, Convention: `"None"` (no separate release pipeline needed for CD)
  - If `architecturalFraming.scaleTarget: "enterprise"` → Separate: `true`, Triggered by: `"Manual"` (greenfield opinion: enterprise release pipelines need a dedicated, manually-triggered process with approval gates)
  - Else → Separate: `false`, Triggered by: `"Tag"`, Convention: `"None"` (greenfield opinion: tag-triggered releases are explicit without requiring a separate pipeline)

---

## Step 11: Architectural Validation (1–2 questions)

Step 11 of the 11-step wizard. Final cross-phase sign-off pass — reads from all approved phase syntheses to detect contradictions and drift since the early framing decisions were captured at Step 2.5. Only 1–2 questions; most of the value is in the synthesis HTML that renders the cross-validation report for developer review.

This step fires ALWAYS — after Step 10 (Architectural Research, conditional) completes or is skipped.

Writes to `context.phases.architecturalValidation.*`. See `onboard/skills/generate/references/context-shape-v2.json` § `architecturalValidation` for the schema.

**Pre-question cross-validation** (Claude runs automatically before asking AV.Q1): Claude reads `context.syntheses.*` and `context.phases.*` and produces a short contradiction report:
- Framing → Data Architecture compatibility checks
- Framing → API & Integration compatibility checks
- Framing → CI/CD compatibility checks
- Data ↔ API cross-checks
- Any synthesis entirely bypassed (not Approve/Adjust/Skip'd at all)

Present the findings to the developer before asking the sign-off question.

### AV.Q1: "Review the cross-phase validation report. What is your sign-off status?"
- **Type**: Single-select choice
- **Options**:
  - "Approved — everything looks consistent" → `signOffStatus: "approved"`
  - "Approved with noted divergences — proceed, I've noted the exceptions" → `signOffStatus: "approved-with-noted-divergences"` (triggers AV.Q2)
  - "Requires rework — I want to fix contradictions before scaffolding" → `signOffStatus: "requires-rework"` (routes back; triggers AV.Q2 for rework scope note)
- **Condition**: Always (this is the gate question for Step 11)
- **Updates**: `context.phases.architecturalValidation.signOffStatus` (required, enum)
- **Downstream effects**: grill-spec reads `signOffStatus` — `requires-rework` blocks Phase 2 and routes back to the relevant wizard step; `approved-with-noted-divergences` passes through with a pre-scaffold awareness note.
- **Default**: `"Approved — everything looks consistent"` (always — the pre-question cross-validation runs first; if Claude's analysis found no contradictions, the default approval is appropriate. If contradictions exist, Claude should surface them and let the developer decide — do not default to approved when contradictions are present)

### AV.Q2: "What's the final note for future maintainers about the divergences or rework needed?"
- **Type**: Open-ended (free text)
- **Condition**: ONLY if `AV.Q1 === "approved-with-noted-divergences"` OR `AV.Q1 === "requires-rework"`. Skip entirely if `approved`.
- **Updates**: `context.phases.architecturalValidation.finalNotes` (loose string — developer writes whatever is relevant; captured verbatim)
- **Prompt examples**:
  - For divergences: "Note what was changed from the original framing and why — future sessions need this context."
  - For rework: "Describe what needs to be revisited so the next session can resume at the right step."
- **Default**: (skip with Enter — open-ended; no placeholder is appropriate for rework notes)

**>>> SYNTHESIS PAUSE**: After AV.Q1 (and AV.Q2 if applicable), invoke `Skill(synthesis-review, phaseId: "architecturalValidation")`. The synthesis renders `docs/adr/architectural-validation.html` with the full cross-phase validation report, divergence table, and sign-off status. Wait for the developer to Approve/Adjust/Skip each section before proceeding to Phase 1.7 (grill-spec).

---

## Category 6: Plugin Discovery (always, end of wizard)

### Q6.1: Interactive plugin checklist
- **Type**: Multi-select checklist
- **Options**: Dynamically generated from catalog matching (see plugin-catalog.md)
- **Condition**: Always
- **Updates**: `pluginsToInstall`
- **Default**: Auto-matched plugins pre-checked, unmatched unchecked (always — the plugin-discovery skill drives the matching logic; there is no fixed default, but catalog-matched plugins are pre-selected as a convenience)

### Q6.2: "Want me to search for additional plugins?"
- **Type**: Yes/No
- **Condition**: After Q6.1
- **Updates**: If yes, triggers web search → additional matches added to checklist
- **Default**: `"No"` (always — greenfield opinion: the catalog covers the most common plugins; web search is an escape hatch for specialized needs, not the default path)

---

## Category 7: Confirmation (always)

### Q7.1: Full summary → confirm or revise
- **Type**: Confirm/Revise
- **Condition**: Always (final question)
- **Presents**: All gathered context as structured summary
- **Options**: "Looks good — let's go" | "I want to change..."
- **Default**: `"Looks good — let's go"` (always — at this point the developer has reviewed and approved each synthesis section; Enter to confirm is the expected path for developers who are satisfied with the wizard output)

---

## Adaptive Skipping Rules

| Developer says | Questions skipped |
|---|---|
| CLI tool (appType = cli) | Q3.3, Q3.4 deploy*, Q3.6, Step 3 (dataArchitecture) entire phase, Step 4 (apiIntegration) entire phase, Q3.12-Q3.14, Q3.F1, Q3.F2, Q5.1, Q5.3 |
| Side project, not deploying | Q5.1, Q5.3, Q3.6, Q3.11 (auto deps), P3.Q11 (backup), P4.Q4 (versioning), P4.Q5 (rate limit) |
| API-only backend | Q3.F1, Q3.F2, Q3.12-Q3.14, P4.Q8 (real-time) |
| Solo developer | Q5.3 (PR review), Q5.13 (notifications warning) |
| No database (P3.Q1 = no) | P3.Q2–Q7 |
| No API layer (P4.Q1 = no) | P4.Q2–Q9 |

*When `willDeploy = false`, the entire Category 5 (CI/CD) except Q5.2 is skipped.
