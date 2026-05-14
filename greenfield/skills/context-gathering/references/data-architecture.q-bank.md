# Data Architecture Q-bank — Step 3

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 3 (detailed data-layer phase; preceded by Step 2.5 architecturalFraming and Step 2.7 domainModel)
> **Modes:** Heavy ~12 Qs (Data.Q1–Q12 + Q_RISK) / Light ~7 Qs (Q1–Q5 + Q11 + Q12 + Q_RISK; Q6–Q10 use defaults)
> **Coupling:** Auto-loop on Data.Q5 (migrations per entity) and Data.Q8 (caching per access pattern), both `loopMode: always` — fires in BOTH auto-loop and hybrid coupling modes.
> **Source:** Q content migrated from `question-bank.md` § "Step 3: Data Architecture" (lines 129–279); R4 added Q_RISK + showInLight + loopOver tags + format conversion.
> **See also:** `architectural-framing.q-bank.md`, `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk + § Coupling matrix

This phase gathers data-layer decisions: persistence choice, engine, hosting model, ORM, migrations, multi-tenancy, search, caching, file storage, codegen, backup, compliance. Synthesis review fires inline after Data.Q_RISK (or after the last applicable Q if Q1=No).

## Q-bank

### Data.Q1 — Persistent data need

- **type:** single-select
- **options:** ["Yes — relational", "Yes — document/NoSQL", "Yes — embedded (SQLite/DuckDB)", "No persistent data", "Not sure — recommend"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (gate for the rest of Step 3 / dataArchitecture)
- **R3-updates-path:** `context.phases.dataArchitecture` (gate flag; if "No persistent data", skip Q2–Q7 but still ask Q8, Q9, Q10, Q12)

**Prompt:** "Does this app need persistent data?"

**Stores to:** `dataArchitecture.persistenceChoice`

**Downstream effects:** Gates Q2–Q7. If "No persistent data", skip engine/host/ORM/migrations/multi-tenancy/search but still ask Q8 (in-memory cache), Q9 (file storage), Q10 (codegen), Q12 (compliance).

**Default:** `"Yes — relational"`
- If `appType: "cli"` → `"No persistent data"`
- If `appType: "library"` → `"No persistent data"`
- If `stack.stack.framework ∈ (django, rails, laravel)` → `"Yes — relational"` (opinionated ORM stacks assume relational)
- Else → `"Yes — relational"` (greenfield opinion: relational DBs are the right default for most applications; document stores are a deliberate choice, not a default)

### Data.Q2 — Database engine

- **type:** single-select
- **options:** ["PostgreSQL", "MySQL", "MongoDB", "SQLite", "Turso/libSQL", "PlanetScale", "EdgeDB", "DynamoDB", "Custom — specify"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes (any persistent option)
- **R3-updates-path:** `context.phases.dataArchitecture.engine`

**Prompt:** "Which database engine?"

**Stores to:** `dataArchitecture.engine`

**Options (with descriptions):**
- Options are dynamically enriched with stack-informed recommendations (e.g., "PostgreSQL (recommended for Next.js + Prisma)")

**Downstream effects:** ORM filtering in Q4, migration tool filtering in Q5, hosting model compatibility in Q3, codegen options in Q10.

**Recommend:** Lead with PostgreSQL for most stacks. Turso/libSQL for serverless edge. SQLite for hobby. Let the stack-researcher agent supply the enriched option label.

**Default:** `"PostgreSQL"`
- If `stack.stack.framework: "django"` → `"PostgreSQL"` (Django's primary target; migration tooling is most tested against Postgres)
- If `stack.stack.framework: "rails"` → `"PostgreSQL"`
- If `architecturalFraming.topology: "serverless"` AND `architecturalFraming.deploymentShape: "edge-distributed"` → `"Turso/libSQL"` (edge-compatible embedded)
- If `architecturalFraming.scaleTarget: "hobby"` → `"SQLite"` (zero-infra overhead for single-user apps)
- Else → `"PostgreSQL"` (greenfield opinion: Postgres is the most capable open-source RDBMS with the widest ecosystem support)

### Data.Q3 — Database hosting model

- **type:** single-select
- **options:** ["Self-hosted (you manage the server)", "Managed RDBMS (RDS, Cloud SQL, Supabase)", "Serverless RDBMS (Neon, PlanetScale, Turso)", "Managed NoSQL (Atlas, DynamoDB)", "Embedded (SQLite/DuckDB)", "None"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.dataArchitecture.databaseHost`

**Prompt:** "What's the database hosting model?"

**Stores to:** `dataArchitecture.databaseHost`

**Downstream effects:** cicdAndDelivery reads this for rollback strategy (point-in-time recovery on managed hosts only).

**Default:** `"Managed RDBMS"`
- If `architecturalFraming.scaleTarget: "hobby"` → `"Embedded"` (SQLite; no infra cost)
- If `architecturalFraming.topology: "serverless"` → `"Serverless RDBMS"` (connection-pool compatible)
- If `architecturalFraming.deploymentShape: "on-prem"` → `"Self-hosted"`
- Else → `"Managed RDBMS"` (greenfield opinion: managed hosting removes operational burden while providing PITR and backups out of the box)

### Data.Q4 — ORM or data-access layer

- **type:** single-select
- **options:** ["Prisma", "Drizzle", "Kysely", "TypeORM", "Sequelize", "SQLAlchemy", "Django ORM", "GORM", "sqlc", "Active Record", "Ecto", "Diesel", "sqlx", "Raw SQL", "Other"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.dataArchitecture.orm`

**Prompt:** "Which ORM or data-access layer?"

**Stores to:** `dataArchitecture.orm`

**Options (filtered by `stack.stack.language`):**
- TypeScript: "Prisma" | "Drizzle" | "Kysely" | "TypeORM" | "Sequelize" | "Raw SQL" | "Other"
- Python: "SQLAlchemy" | "Django ORM" | "Raw SQL" | "Other"
- Go: "GORM" | "sqlc" | "Raw SQL" | "Other"
- Ruby: "Active Record" | "Raw SQL" | "Other"
- Elixir: "Ecto" | "Raw SQL" | "Other"
- Rust: "Diesel" | "sqlx" | "Raw SQL" | "Other"

**Downstream effects:** apiIntegration reads for codegen + validation library pairing.

**Default:** `"Prisma"` (for TypeScript projects)
- If `stack.stack.language: "typescript"` AND `architecturalFraming.topology: "serverless"` → `"Drizzle"` (edge-compatible, no Prisma query engine overhead)
- If `stack.stack.language: "typescript"` → `"Prisma"` (greenfield opinion: best DX, codegen, and migration tooling for TS)
- If `stack.stack.language: "python"` AND `stack.stack.framework: "django"` → `"Django ORM"`
- If `stack.stack.language: "python"` → `"SQLAlchemy"`
- If `stack.stack.language: "go"` → `"sqlc"` (greenfield opinion: type-safe SQL generation without runtime magic)
- If `stack.stack.language: "ruby"` → `"Active Record"`
- If `stack.stack.language: "elixir"` → `"Ecto"`
- If `stack.stack.language: "rust"` → `"sqlx"` (async-native, no derive macro overhead)
- Else → `"Raw SQL"` (safe fallback when language is unknown)

### Data.Q5 — Migration tool and application mode

- **type:** single-select
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.dataArchitecture.migrationsTool` (also writes `migrationsMode`)
- **loopOver:** domainModel.entities
- **loopMode:** always <!-- fires in both auto-loop and hybrid -->

**Prompt:** "For entity {entity.id} ({entity.contextId}): Migration tool & application mode?"

**Stores to:** `dataArchitecture.migrationsTool` + `dataArchitecture.migrationsMode`

**Sub-questions:**
- Tool: "ORM-native (Prisma migrate, Drizzle kit, etc.)" | "Alembic" | "Flyway" | "Liquibase" | "Raw SQL files" | "None — manual schema" | "Other"
- Mode: "Developer-applied (dev runs migrations locally)" | "CI-applied (pipeline runs before deploy)" | "Runtime-applied (app applies on boot)"

**Downstream effects:** cicdAndDelivery reads migrationsTool and migrationsMode for pipeline step generation. Runtime-applied mode constrains zero-downtime deployment options.

**Recommend:** ORM-native tool for TS/Python/Ruby stacks where ORM is already chosen. CI-applied mode for all production-grade projects. Developer-applied only for hobby. Never Runtime-applied unless the user explicitly requires it (creates deployment coupling).

**Default:** Tool: `"ORM-native"`, Mode: `"CI-applied"`
- If `dataArchitecture.orm: "prisma"` → Tool: `"ORM-native"` (Prisma migrate), Mode: `"CI-applied"`
- If `dataArchitecture.orm: "drizzle"` → Tool: `"ORM-native"` (Drizzle kit), Mode: `"CI-applied"`
- If `stack.stack.language: "python"` AND `stack.stack.framework ≠ "django"` → Tool: `"Alembic"`, Mode: `"CI-applied"`
- If `stack.stack.language: "python"` AND `stack.stack.framework: "django"` → Tool: `"ORM-native"` (Django migrations), Mode: `"CI-applied"`
- If `architecturalFraming.scaleTarget: "hobby"` → Mode: `"Developer-applied"` (no CI)
- Else → Tool: `"ORM-native"`, Mode: `"CI-applied"` (greenfield opinion: ORM-native tools stay in sync with schema changes automatically)

### Data.Q6 — Multi-tenancy isolation strategy

- **type:** single-select
- **options:** ["None — single-tenant", "Row-level (tenant_id columns + RLS)", "Schema-per-tenant", "DB-per-tenant", "Shared (no isolation — review carefully)"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.dataArchitecture.multiTenancy`

**Prompt:** "Multi-tenancy isolation strategy?"

**Stores to:** `dataArchitecture.multiTenancy`

**Downstream effects:** Future P6 auth/authz model reads this for permission scoping; row-level isolation requires RLS policies in the DB and middleware guard in API layer.

**Default:** `"None — single-tenant"`
- If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` AND `appType ∈ (fullstack, web-app)` → `"Row-level"` (greenfield opinion: row-level is the right starting point for SaaS apps at scale)
- Else → `"None — single-tenant"` (greenfield opinion: most new projects are single-tenant; multi-tenancy is a deliberate architectural choice)

### Data.Q7 — Search and retrieval strategy

- **type:** single-select
- **options:** ["DB full-text only (Postgres tsvector, MySQL FT)", "Dedicated engine (Elasticsearch, Meilisearch, Typesense)", "Vector store (pgvector, Pinecone, Qdrant, Weaviate)", "Hybrid (FTS + vector)", "None — no search"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.dataArchitecture.search`

**Prompt:** "Search and retrieval strategy?"

**Stores to:** `dataArchitecture.search`

**Downstream effects:** Dedicated search engines require an additional infrastructure component in runtimeOperations; vector stores unlock AI/semantic retrieval features but add cost and operational complexity.

**Recommend:** DB full-text for most apps at launch; graduate to dedicated engine when query latency or ranking quality becomes a bottleneck. Vector store only when the app explicitly has semantic search or RAG requirements.

**Default:** `"None — no search"`
- If `appType ∈ (fullstack, web-app)` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` → `"DB full-text only"` (greenfield opinion: Postgres full-text is sufficient for most apps at launch; add a dedicated engine when query performance demands it)
- Else → `"None — no search"` (greenfield opinion: search is a feature, not a default infrastructure component)

### Data.Q8 — Caching layer and invalidation pattern

- **type:** multi-select
- **options:** ["In-memory (app-local)", "Redis / KeyDB", "Memcached", "DB query cache", "CDN edge", "None — no caching"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (even no-DB apps can cache)
- **R3-updates-path:** `context.phases.dataArchitecture.cache` (also writes `cacheInvalidation`)
- **loopOver:** domainModel.entities
- **loopMode:** always <!-- fires in both auto-loop and hybrid -->

**Prompt:** "For entity {entity.id} ({entity.contextId}): Caching layer + invalidation pattern?"

**Stores to:** `dataArchitecture.cache` + `dataArchitecture.cacheInvalidation`

**Sub-questions:**
- Layers (multi-select; pad with "None / Skip" if zero matches): "In-memory (app-local)" | "Redis / KeyDB" | "Memcached" | "DB query cache" | "CDN edge"
- Invalidation: "TTL only" | "Event-driven (invalidate on write)" | "Manual" | "None — no caching"

**Downstream effects:** Redis requires an additional runtime component in runtimeOperations; event-driven invalidation couples to the message/event system in apiIntegration.

**Recommend:** No cache as default for new projects. In-memory + TTL for startup when read latency starts mattering. Redis + event-driven for production-scale. CDN only for static or semi-static content.

**Default:** Layers: `"None — no caching"`, Invalidation: `"None — no caching"`
- If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → Layers: `"Redis / KeyDB"`, Invalidation: `"Event-driven"`
- If `architecturalFraming.scaleTarget: "startup"` → Layers: `"In-memory (app-local)"`, Invalidation: `"TTL only"`
- Else → `"None — no caching"` (greenfield opinion: premature caching adds complexity without benefit; add when profiling shows it's needed)

### Data.Q9 — File and object storage strategy

- **type:** single-select
- **options:** ["Cloud storage (S3 / R2 / Blob / GCS)", "Local filesystem", "CDN for static assets", "Both cloud + CDN", "No file handling"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `hasBackend || hasFrontend`
- **R3-updates-path:** `context.phases.dataArchitecture.fileStorage`

**Prompt:** "File / object storage strategy?"

**Stores to:** `dataArchitecture.fileStorage`

**Downstream effects:** Cloud storage requires credentials + bucket setup in runtimeOperations; CDN integration may affect frontend routing in the scaffold.

**Recommend:** Cloud storage (S3/R2) for any app that allows user uploads and scales past a single server. Local filesystem only for hobby. No file handling is the correct default if the app doesn't have user-generated content.

**Default:** `"No file handling"`
- If `appType ∈ (fullstack, web-app)` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` → `"Cloud storage (S3 / R2 / Blob / GCS)"` (greenfield opinion: local filesystem doesn't survive horizontal scale or container restarts)
- If `architecturalFraming.scaleTarget: "hobby"` → `"Local filesystem"` (acceptable for single-user projects)
- Else → `"No file handling"` (greenfield opinion: file handling is a feature, not a default)

### Data.Q10 — Codegen tools

- **type:** multi-select
- **options:** ["Prisma generate", "Drizzle Kit", "sqlc", "GraphQL codegen", "OpenAPI TypeScript", "Protocol Buffers", "None"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Applicable to stack (skip if Q1=No AND no API)
- **R3-updates-path:** `context.phases.dataArchitecture.codegen`

**Prompt:** "Codegen tools?"

**Stores to:** `dataArchitecture.codegen`

**Downstream effects:** apiIntegration synthesis cross-references this when style=graphql or style=rest. Codegen tools affect the CI build step order (codegen must run before type-check).

**Note:** Even though codegen spans ORM (Prisma) and API (GraphQL/OpenAPI), it lives in dataArchitecture only per the single-owner boundary. apiIntegration synthesis cross-references this question when style=graphql.

**Default:** `["None"]`
- If `dataArchitecture.orm: "prisma"` → `["Prisma generate"]`
- If `dataArchitecture.orm: "drizzle"` → `["Drizzle Kit"]`
- If `stack.stack.language: "go"` AND `dataArchitecture.orm: "sqlc"` → `["sqlc"]`
- If `apiIntegration.style: "graphql"` → append `"GraphQL codegen"` to ORM-derived defaults
- If `apiIntegration.style: "rest"` AND `stack.stack.language: "typescript"` → append `"OpenAPI TypeScript"` to ORM-derived defaults
- Else → `["None"]`

### Data.Q11 — Backup and retention

- **type:** single-select
- **options:** ["None — accept loss risk", "Managed-provider auto-backup (most cloud DBs)", "Scheduled dumps (custom cron)", "Continuous (point-in-time recovery)"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes AND `willDeploy`
- **R3-updates-path:** `context.phases.dataArchitecture.backup`

**Prompt:** "Backup & retention?"

**Stores to:** `dataArchitecture.backup`

**Downstream effects:** Continuous PITR constrains hosting model to managed providers (Q3); scheduled dumps require a cron job in runtimeOperations.

**Recommend:** Managed-provider auto-backup for most projects — it's free with most managed DBs and zero configuration. Upgrade to PITR for enterprise. Never "None" for production data.

**Default:** `"Managed-provider auto-backup"`
- If `architecturalFraming.scaleTarget: "hobby"` → `"None — accept loss risk"` (greenfield opinion: hobby projects rarely need formal backup; simplicity wins)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Continuous (point-in-time recovery)"`
- If `dataArchitecture.databaseHost: "embedded"` → `"Scheduled dumps (custom cron)"` (SQLite has no managed backup)
- Else → `"Managed-provider auto-backup"` (greenfield opinion: delegate backup to the hosting provider; it's free with most managed DBs and requires zero configuration)

### Data.Q12 — Data residency and compliance constraints

- **type:** single-select
- **options:** ["None", "Region-locked (specify in follow-up)", "GDPR-aware (EU users)", "HIPAA", "PCI-DSS", "SOC 2"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.dataArchitecture.compliance`

**Prompt:** "Data residency / compliance constraints?"

**Stores to:** `dataArchitecture.compliance`

**Downstream effects:** Non-None compliance triggers cross-checks in grill-spec (topology + hosting model compatibility), synthesis-review § Compliance section, and may constrain deployment region in cicdAndDelivery.

**Recommend:** Be accurate about actual compliance requirements — don't add overhead without a real driver. Enterprise almost always implies SOC 2 at minimum.

**Default:** `"None"`
- If `architecturalFraming.scaleTarget: "enterprise"` → `"SOC 2"` (enterprise implies organizational compliance requirements)
- Else → `"None"` (greenfield opinion: compliance is a product requirement, not a technical default; don't add overhead without a real driver)

### Data.Q_RISK — Data architecture risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["scaling", "dataloss", "vendor-lock", "performance"]

**Prompt:** "What's the biggest data architecture risk for THIS project? (e.g., 'Single Postgres for OLTP+analytics will need split by Y2', 'serverless edge driver locks us into one host', 'no PITR but customer data is regulated'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "dataArchitecture"`, id auto-assigned `R-DATAARCHITECTURE-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Data.Q1 | ✓ | ✓ | Persistence gate — fundamental |
| Data.Q2 | ✓ | ✓ | Engine — fundamental |
| Data.Q3 | ✓ | ✓ | Hosting — fundamental |
| Data.Q4 | ✓ | ✓ | ORM — fundamental |
| Data.Q5 | ✓ | ✓ | Migrations — fundamental (loops per entity) |
| Data.Q6 | ✓ | — | Multi-tenancy — depth, uses default in light |
| Data.Q7 | ✓ | — | Search — depth, uses default in light |
| Data.Q8 | ✓ | — | Caching — depth (loops per entity) |
| Data.Q9 | ✓ | — | File storage — depth |
| Data.Q10 | ✓ | — | Codegen — depth |
| Data.Q11 | ✓ | ✓ | Backup — fundamental |
| Data.Q12 | ✓ | ✓ | Compliance — fundamental |
| Data.Q_RISK | ✓ | ✓ | Always fires |
