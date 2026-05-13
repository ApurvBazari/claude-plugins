# Greenfield Question Bank

Complete catalog of Phase 1 questions with conditions, options, and downstream effects. The wizard is an adaptive state machine — each answer updates the context object, and subsequent questions check preconditions before being asked.

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

### Q1.2: "Who is this for? What problem does it solve?"
- **Type**: Open-ended
- **Condition**: If Q1.1 is vague or doesn't clarify target users
- **Updates**: Refines `appType`, informs security level (B2B → higher)

---

## Category 2: Tech Stack (always asked)

### Q2.1: "Do you have a tech stack in mind, or would you like me to recommend one?"
- **Type**: Choice
- **Options**: "I know what I want" | "Recommend something" | "I have a partial idea"
- **Condition**: Always
- **Downstream**: Triggers stack-researcher agent

### Q2.2: "What's your tech stack?"
- **Type**: Open-ended
- **Condition**: If Q2.1 = "I know" or "partial idea"
- **Updates**: `hasFrontend`, `hasBackend`, `hasAPI`, framework/language details
- **Downstream**: stack-researcher agent researches each technology

**>>> RESEARCH PAUSE**: After Q2.1/Q2.2, launch the stack-researcher agent. Wait for research results before continuing.

### Q2.3: "For [framework], the current version is [X]. The official scaffold CLI is [Y]. Should I use that?"
- **Type**: Choice
- **Options**: "Use [scaffold CLI]" (recommended) | "Start from scratch" | "I have a template" | "Let's discuss"
- **Condition**: Always (after research)
- **Updates**: `scaffoldMethod`, `scaffoldCLI`

---

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

## Category 3: Project Details (adaptive)

### Q3.1: "What's the scale of this project?"
- **Type**: Choice
- **Options**: "Side project / learning" | "Production app (solo)" | "Production app (small team, 2-5)" | "Production app (larger team, 5+)"
- **Condition**: Always
- **Updates**: `isProduction`, `hasTeam`, `teamSize`
- **Downstream**: Agent count, rule strictness, PR template complexity

### Q3.2: "Do you need a database?"
- **Type**: Choice
- **Options**: "PostgreSQL" | "MySQL" | "SQLite" | "MongoDB" | "Not sure — recommend" | "No database"
- **Condition**: If project involves data persistence (inferred from Q1)
- **Updates**: `hasDatabase`, `databaseType`

### Q3.3: "How do you want to handle authentication?"
- **Type**: Choice
- **Options**: "No auth" | "Third-party (Auth0, Clerk, etc.)" | "Built-in (session/JWT)" | "Skip for now"
- **Condition**: `hasFrontend || hasAPI`
- **Updates**: `authStrategy`

### Q3.4: "Where do you want to deploy?"
- **Type**: Choice (research-informed)
- **Options**: Dynamically generated from stack research (e.g., "Vercel — best for Next.js" | "AWS" | "Self-hosted" | "Not deploying")
- **Condition**: Always
- **Updates**: `willDeploy`, `deployTarget`
- **Critical skip**: If "Not deploying" → `willDeploy = false`, skip ALL Category 5 questions

### Q3.5: "Any specific APIs or services you'll integrate with?"
- **Type**: Open-ended
- **Condition**: `hasFrontend || hasBackend`
- **Updates**: `externalAPIs`

### Q3.6: "What's your monitoring and observability strategy?"
- **Type**: Multi-select
- **Options**: "Logging framework" | "Error tracking (Sentry, etc.)" | "Analytics" | "Uptime monitoring" | "Not needed yet"
- **Condition**: `isProduction`
- **Updates**: `monitoring`

### Q3.7: "What's your API design approach?"
- **Type**: Choice
- **Options**: "REST" | "GraphQL" | "tRPC / RPC" | "No API layer" | "Not sure — recommend"
- **Condition**: `hasBackend || hasAPI`
- **Updates**: `apiStyle`, `hasAPI`

### Q3.8: "Do you want auto-generated API documentation?"
- **Type**: Choice
- **Options**: "OpenAPI/Swagger" | "GraphQL playground" | "Auto from types" | "Manual" | "No docs"
- **Condition**: Q3.7 ≠ "No API layer"
- **Updates**: `apiDocsTool`

### Q3.9: "How do you want to manage environment variables and secrets?"
- **Type**: Choice
- **Options**: "Standard .env files" | "Platform-managed (Vercel env, AWS SM)" | "Vault/Doppler" | "Recommend based on deploy target"
- **Condition**: Always
- **Updates**: `envStrategy`

### Q3.10: "Do you want Docker for local development or deployment?"
- **Type**: Choice
- **Options**: "Docker + compose for local dev" | "Docker for deployment only" | "Both" | "No Docker"
- **Condition**: Always (recommend based on stack + deploy)
- **Updates**: `dockerStrategy`

### Q3.11: "How do you want to manage dependencies?"
- **Type**: Choice
- **Options**: "Automated updates (auto-merge minor/patch)" | "Automated PRs (I review)" | "Manual"
- **Condition**: Always
- **Updates**: `depManagement`

### Q3.12: "What level of accessibility compliance do you need?"
- **Type**: Choice
- **Options**: "WCAG 2.1 AA" | "WCAG 2.1 AAA" | "Basic best practices" | "Not a priority"
- **Condition**: `hasFrontend`
- **Updates**: `a11yLevel`

### Q3.13: "Do you have performance targets or budgets?"
- **Type**: Choice
- **Options**: "Core Web Vitals targets" | "Bundle size budget" | "Both" | "General best practices" | "Not a concern"
- **Condition**: `hasFrontend`
- **Updates**: `perfTargets`

### Q3.14: "Does this app need multi-language support (i18n)?"
- **Type**: Choice
- **Options**: "Yes — from day one" | "Not now, but plan for it" | "No — single language"
- **Condition**: `hasFrontend`
- **Updates**: `i18n`

### Q3.15: "Is this a monorepo or single package?"
- **Type**: Choice
- **Options**: "Single package" | "Monorepo" (follow-up: which packages?) | "Not sure — recommend"
- **Condition**: Always
- **Updates**: `isMonorepo`, `monorepoPackages`

### Q3.16: "Do you use code generation tools?"
- **Type**: Multi-select
- **Options**: "Prisma generate" | "GraphQL codegen" | "OpenAPI TypeScript" | "Protocol Buffers" | "None"
- **Condition**: Applicable to stack
- **Updates**: `codegenTools`

### Q3.17: "Will your app need file storage or asset management?"
- **Type**: Choice
- **Options**: "Cloud storage (S3, Blob, R2)" | "Local filesystem" | "CDN for static assets" | "Both cloud + CDN" | "No file handling"
- **Condition**: `hasBackend || hasFrontend`
- **Updates**: `storageStrategy`

### Q3.18: "Does your app need background processing or scheduled jobs?"
- **Type**: Choice
- **Options**: "Queue system (BullMQ, Celery, etc.)" | "Cron/scheduled jobs" | "Both" | "Not needed"
- **Condition**: `hasBackend`
- **Updates**: `backgroundJobs`

### Q3.F1: "What's your styling approach?" (frontend only)
- **Type**: Choice
- **Options**: "Tailwind CSS" | "CSS Modules" | "styled-components / Emotion" | "Vanilla CSS / SASS" | "Component library" | "Recommend"
- **Condition**: `hasFrontend`
- **Updates**: `stylingApproach`

### Q3.F2: "Do you need a component library?" (frontend only)
- **Type**: Choice
- **Options**: "shadcn/ui" | "MUI" | "Headless UI / Radix" | "Build custom" | "Recommend"
- **Condition**: `hasFrontend`
- **Updates**: `componentLibrary`

---

## Category 4: Workflow (adaptive)

### Q4.1: "What branching strategy works for you?"
- **Type**: Choice (recommendation based on team size)
- **Options**: "[Recommended]" | "Gitflow-lite (main + develop)" | "Trunk-based" | "Explain options"
- **Condition**: Always
- **Updates**: `branchingStrategy`

### Q4.2: "How do you approach testing?"
- **Type**: Choice
- **Options**: "TDD — tests first" | "Test alongside features" | "Test after — when stable" | "Minimal — critical paths only"
- **Condition**: Always
- **Updates**: `testingPhilosophy`

### Q4.3: "How much autonomy should Claude have?"
- **Type**: Choice
- **Options**: "Always ask — check before changes" | "Balanced — routine decisions autonomous, big ones ask" | "Autonomous — make decisions, I review"
- **Condition**: Always
- **Updates**: `autonomyLevel`

### Q4.4: "How strict should code style enforcement be?"
- **Type**: Choice
- **Options**: "Relaxed — guidelines" | "Moderate — standard conventions" | "Strict — enforced everywhere"
- **Condition**: Always
- **Updates**: `codeStyleStrictness`

### Q4.5: "How security-sensitive is this project?"
- **Type**: Choice
- **Options**: "Standard" | "Elevated — handles PII/payments" | "High — compliance (SOC2, HIPAA)"
- **Condition**: Always
- **Updates**: `securitySensitivity`

### Q4.6: "How do you want to handle releases?"
- **Type**: Choice
- **Options**: "Semantic versioning + changelog" | "Git tags only" | "Continuous deployment" | "Not relevant"
- **Condition**: `isProduction`
- **Updates**: `releaseStrategy`

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

---

## Category 5: CI/CD & Auto-Evolution (conditional: `willDeploy`)

### Q5.1: "When tooling drift is detected, what should the CI pipeline do?"
- **Type**: Choice
- **Options**: "Create a PR with fixes" | "Comment on the commit" | "Create a GitHub issue"
- **Condition**: `willDeploy`
- **Updates**: `ciAuditAction`

### Q5.2: "Should AI tooling update automatically when code changes?"
- **Type**: Choice
- **Options**: "Auto-update in real-time" | "Log changes, I'll run /greenfield:evolve" | "Just notify me"
- **Condition**: Always (even local projects have local hooks)
- **Updates**: `autoEvolutionMode`

### Q5.3: "Should PRs get AI review automatically?"
- **Type**: Choice
- **Options**: "Auto-review every PR" | "Only when I comment @claude" | "Auto with skip label"
- **Condition**: `willDeploy && hasTeam`
- **Updates**: `prReviewTrigger` AND `phases.P8._v1_carryover.prReviewTrigger`

### Q5.4: "Which CI provider will you use?"
- **Type**: Choice
- **Options**: "GitHub Actions" | "GitLab CI" | "CircleCI" | "BuildKite" | "Jenkins" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.provider`
- **Note**: Round 1 only emits GitHub Actions workflow templates. Non-GHA values are captured but produce a note in synthesis review; non-GHA template support lands in Round 6.

### Q5.5: "When should CI run?"
- **Type**: Multi-select
- **Options**: "Push to main" | "Every PR" | "Scheduled" | "Manual dispatch" | "On tag"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.triggers[]`

### Q5.6: "Which checks must pass before a PR can merge?"
- **Type**: Multi-select
- **Options**: "Lint" | "Typecheck" | "Unit tests" | "Integration tests" | "E2E tests" | "Security scan" | "Coverage" | "Build"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.requiredPreMergeChecks[]`
- **Recommend**: Default selection adapts to stack — Node/TS projects get lint+typecheck+unit+build; Python adds ruff in place of lint+typecheck.

### Q5.7: "Coverage threshold — what value blocks merges, if any?"
- **Type**: Composite (numeric + choice + boolean)
- **Sub-questions**:
  - Threshold (numeric 0–100, or `null` for no threshold)
  - Scope: "Global" | "Per-package" | "Per-file"
  - Blocking: yes/no — should coverage drops block PRs?
- **Condition**: `willDeploy && (Q5.6 selection includes "Coverage")`
- **Updates**: `phases.P8.cicd.coverage.{threshold,scope,blocking}`

### Q5.8: "Environment ladder — what environments will you deploy to?"
- **Type**: Choice
- **Options**: "Single (prod only)" | "Preview + prod" | "Staging + prod" | "Dev + staging + prod" | "Custom"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.envLadder[]`
- **Recommend**: Default to "Preview + prod" for SaaS; "Single" for hobby projects; "Staging + prod" for B2B with paying customers.

### Q5.9: "How does deployment happen?"
- **Type**: Choice
- **Options**: "Auto on merge" | "Manual button" | "Scheduled window" | "Tag-triggered" | "None — I'll deploy by hand"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.autoDeploy`

### Q5.10: "Deploy cadence — how often will you ship?"
- **Type**: Choice
- **Options**: "Continuous (multiple per day)" | "Daily" | "Weekly" | "On-demand only" | "Not deploying"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.deployCadence`

### Q5.11: "Rollback strategy?"
- **Type**: Composite (choice + boolean)
- **Sub-questions**:
  - Strategy: "Redeploy previous SHA" | "Blue-green" | "Canary" | "None"
  - Automation: yes/no — automated on failure detection?
- **Condition**: `willDeploy && Q5.9 !== "None"`
- **Updates**: `phases.P8.cicd.rollback.{strategy,automation}`

### Q5.12: "How are CI secrets managed?"
- **Type**: Composite (choice + choice)
- **Sub-questions**:
  - Manager: "Provider-stored (GitHub/GitLab secrets)" | "OIDC to cloud" | "Vault" | "1Password" | "Doppler" | "Manual env files"
  - Rotation: "Manual only" | "Scheduled" | "On incident only"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.secrets.{manager,rotation}`

### Q5.13: "Where should CI notifications go?"
- **Type**: Composite (multi-select + multi-select)
- **Sub-questions**:
  - Channels (multi-select): "Slack" | "Discord" | "Email" | "GitHub checks only"
  - Events (multi-select): "Build failure" | "Deploy success" | "Deploy failure" | "Security alert"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.notifications.{channels[],events[]}`
- **Note**: Solo developer + Slack channel selection triggers a warning in synthesis review.

### Q5.14: "Build matrix?"
- **Type**: Composite (multi-select + choice + choice)
- **Sub-questions**:
  - OS targets (multi-select): "ubuntu-latest" | "macos-latest" | "windows-latest"
  - Language versions: "Single (current LTS)" | "Multi (current LTS + previous)"
  - Parallelization: "Auto (CI provider decides)" | "Off (serial)" | numeric value
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.buildMatrix.{os[],languageVersions,parallelization}`
- **Recommend**: Most projects → single ubuntu-latest. Cross-platform tools → multi-OS. Libraries → multi-version.

### Q5.15: "Caching strategy?"
- **Type**: Composite (booleans + choice)
- **Sub-questions**:
  - Deps: cache dependency installs (yes/no)
  - Build: cache build outputs (yes/no)
  - Docker layers: cache Docker layers (yes/no)
  - Remote backend: "Turbo Remote Cache" | "BuildKite Cache" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.caching.{deps,build,dockerLayers,remote}`

### Q5.16: "CI time budget?"
- **Type**: Composite (numeric + optional numeric)
- **Sub-questions**:
  - Per-pipeline target minutes
  - Blocking threshold minutes (optional — pipelines exceeding this fail; null means no block)
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.timeBudget.{perPipelineMinutes,blockingThresholdMinutes}`

### Q5.17: "Release pipeline?"
- **Type**: Composite (boolean + choice + choice)
- **Sub-questions**:
  - Separate from main CI: yes/no
  - Triggered by: "Tag" | "Manual" | "Schedule"
  - Convention: "release-please" | "semantic-release" | "Manual" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.P8.cicd.releasePipeline.{separate,triggeredBy,convention}`
- **Note**: `release-please` and `semantic-release` are Node-centric. Mismatches with `P2.stack.framework` (non-Node stacks) trigger a synthesis warning.

---

## Category 6: Plugin Discovery (always, end of wizard)

### Q6.1: Interactive plugin checklist
- **Type**: Multi-select checklist
- **Options**: Dynamically generated from catalog matching (see plugin-catalog.md)
- **Condition**: Always
- **Updates**: `pluginsToInstall`

### Q6.2: "Want me to search for additional plugins?"
- **Type**: Yes/No
- **Condition**: After Q6.1
- **Updates**: If yes, triggers web search → additional matches added to checklist

---

## Category 7: Confirmation (always)

### Q7.1: Full summary → confirm or revise
- **Type**: Confirm/Revise
- **Condition**: Always (final question)
- **Presents**: All gathered context as structured summary
- **Options**: "Looks good — let's go" | "I want to change..."

---

## Adaptive Skipping Rules

| Developer says | Questions skipped |
|---|---|
| CLI tool (appType = cli) | Q3.3, Q3.4 deploy*, Q3.6-Q3.8, Q3.12-Q3.14, Q3.17, Q3.F1, Q3.F2, Q5.1, Q5.3 |
| Side project, not deploying | Q5.1, Q5.3, Q3.6, Q3.11 (auto deps) |
| API-only backend | Q3.F1, Q3.F2, Q3.12-Q3.14 |
| Solo developer | Q5.3 (PR review) |
| No database | Q3.2 follow-ups, Q3.16 (Prisma) |
| No API layer | Q3.8 |

*When `willDeploy = false`, the entire Category 5 (CI/CD) except Q5.2 is skipped.
