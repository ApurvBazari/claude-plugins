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

### AF.Q2: "What's your deployment shape?"
- **Type**: Choice
- **Options**: "Single-region (one cloud region, simplest)" | "Multi-region (active/active or active/passive across regions)" | "Edge-distributed (CDN edge workers, globally distributed)" | "On-premises (self-managed infrastructure)"
- **Condition**: NOT (`appType: cli`). If `willDeploy = false`, default to `"single-region"` and note rather than asking.
- **Updates**: `context.phases.architecturalFraming.deploymentShape` (required, enum)
- **Downstream effects**: cicdAndDelivery reads for env ladder and rollback strategy; dataArchitecture reads for DB hosting model compatibility.
- **Recommend**: Single-region unless `scaleTarget: enterprise` or user explicitly names a global user base. Edge-distributed is powerful but constrains ORM options (Prisma + serverless edge drivers; SQLAlchemy not edge-compatible).

### AF.Q3: "What's the scale target?"
- **Type**: Choice
- **Options**: "Hobby / personal project (single user, occasional traffic)" | "Startup (public launch, growth expected, 100–10k users)" | "Production-scale (established product, sustained load, 10k–1M users)" | "Enterprise (regulated, SLA-backed, 1M+ users or organizational complexity)"
- **Condition**: Always
- **Updates**: `context.phases.architecturalFraming.scaleTarget` (required, enum)
- **Downstream effects**: dataArchitecture caching, backup, and compliance questions weight their recommendations against scale target; cicdAndDelivery env ladder and release pipeline complexity track scale; authSecurity (Round 3) uses scale to calibrate identity recommendations.
- **Recommend**: Be honest about current scale, not aspirational. Most projects starting today are `startup`; `enterprise` triggers heavier compliance cross-checks.

### AF.Q4: "Do you have any hard architectural boundary requirements or constraints?"
- **Type**: Open-ended with option-prompted starting points
- **Suggested prompts**: "Domain separation you know you need (e.g., billing must be isolated from auth)?", "Regulatory constraints that force isolation (e.g., PCI data must not touch user PII)?", "Team ownership lines that need to map to service boundaries?"
- **Condition**: Always
- **Updates**: `context.phases.architecturalFraming.boundaryNotes` (loose string — whatever the user says goes in as-is; this is advisory context for later phases, not schema-validated)
- **Downstream effects**: grill-spec cross-checks `boundaryNotes` against topology when non-empty (e.g., "must isolate payments" + `topology: monolith` produces a contradiction flag); synthesis-review § Downstream Implications renders this as a note.
- **If no constraints**: capture as `""` (empty string) or `"none stated"`. Do not leave null — the schema accepts empty string; null would fail required-field presence in future tooling.

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

### P3.Q2: "Which database engine?"
- **Type**: Open with stack-informed recommendations
- **Options**: Dynamically generated (e.g., "PostgreSQL (recommended for Next.js + Prisma)" | "MySQL" | "MongoDB" | "SQLite" | "Turso/libSQL" | "PlanetScale" | "EdgeDB" | "DynamoDB" | "Custom — specify")
- **Condition**: Q1 = yes (any persistent option)
- **Updates**: `context.phases.dataArchitecture.engine` (loose string)

### P3.Q3: "What's the database hosting model?"
- **Type**: Choice
- **Options**: "Self-hosted (you manage the server)" | "Managed RDBMS (RDS, Cloud SQL, Supabase)" | "Serverless RDBMS (Neon, PlanetScale, Turso)" | "Managed NoSQL (Atlas, DynamoDB)" | "Embedded (SQLite/DuckDB)" | "None"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.databaseHost` (required, enum)
- **Cross-phase**: cicdAndDelivery reads this for rollback strategy (point-in-time recovery on managed hosts only)

### P3.Q4: "Which ORM or data-access layer?"
- **Type**: Choice (filtered by `stack.stack.language`)
- **Options**: For TypeScript: "Prisma" | "Drizzle" | "Kysely" | "TypeORM" | "Sequelize" | "Raw SQL" | "Other". For Python: "SQLAlchemy" | "Django ORM" | "Raw SQL" | "Other". For Go: "GORM" | "sqlc" | "Raw SQL" | "Other". For Ruby: "Active Record" | "Raw SQL" | "Other". For Elixir: "Ecto" | "Raw SQL" | "Other". For Rust: "Diesel" | "sqlx" | "Raw SQL" | "Other".
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.orm` (required, enum)
- **Cross-phase**: apiIntegration reads for codegen + validation library pairing

### P3.Q5: "Migration tool & application mode?"
- **Type**: Composite (choice + choice)
- **Sub-questions**:
  - Tool: "ORM-native (Prisma migrate, Drizzle kit, etc.)" | "Alembic" | "Flyway" | "Liquibase" | "Raw SQL files" | "None — manual schema" | "Other"
  - Mode: "Developer-applied (dev runs migrations locally)" | "CI-applied (pipeline runs before deploy)" | "Runtime-applied (app applies on boot)"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.migrationsTool` (required, enum) + `migrationsMode` (loose)

### P3.Q6: "Multi-tenancy isolation strategy?"
- **Type**: Choice
- **Options**: "None — single-tenant" | "Row-level (tenant_id columns + RLS)" | "Schema-per-tenant" | "DB-per-tenant" | "Shared (no isolation — review carefully)"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.multiTenancy` (required, enum)
- **Cross-phase**: Future P6 reads for auth/authz model

### P3.Q7: "Search and retrieval strategy?"
- **Type**: Choice
- **Options**: "DB full-text only (Postgres tsvector, MySQL FT)" | "Dedicated engine (Elasticsearch, Meilisearch, Typesense)" | "Vector store (pgvector, Pinecone, Qdrant, Weaviate)" | "Hybrid (FTS + vector)" | "None — no search"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.dataArchitecture.search` (loose)

### P3.Q8: "Caching layer + invalidation pattern?"
- **Type**: Composite (multi-select + choice)
- **Sub-questions**:
  - Layers (multi-select; pad with "None / Skip" if zero matches): "In-memory (app-local)" | "Redis / KeyDB" | "Memcached" | "DB query cache" | "CDN edge"
  - Invalidation: "TTL only" | "Event-driven (invalidate on write)" | "Manual" | "None — no caching"
- **Condition**: Always (even no-DB apps can cache)
- **Updates**: `context.phases.dataArchitecture.cache` (loose) + `cacheInvalidation` (loose)

### P3.Q9: "File / object storage strategy?"
- **Type**: Choice
- **Options**: "Cloud storage (S3 / R2 / Blob / GCS)" | "Local filesystem" | "CDN for static assets" | "Both cloud + CDN" | "No file handling"
- **Condition**: `hasBackend || hasFrontend`
- **Updates**: `context.phases.dataArchitecture.fileStorage` (loose)

### P3.Q10: "Codegen tools?"
- **Type**: Multi-select
- **Options**: "Prisma generate" | "Drizzle Kit" | "sqlc" | "GraphQL codegen" | "OpenAPI TypeScript" | "Protocol Buffers" | "None"
- **Condition**: Applicable to stack (skip if Q1=no AND no API)
- **Updates**: `context.phases.dataArchitecture.codegen` (loose array)
- **Note**: Even though codegen spans ORM (Prisma) and API (GraphQL/OpenAPI), it lives in dataArchitecture only per the single-owner boundary. apiIntegration synthesis cross-references this question when style=graphql.

### P3.Q11: "Backup & retention?"
- **Type**: Choice
- **Options**: "None — accept loss risk" | "Managed-provider auto-backup (most cloud DBs)" | "Scheduled dumps (custom cron)" | "Continuous (point-in-time recovery)"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.dataArchitecture.backup` (loose)

### P3.Q12: "Data residency / compliance constraints?"
- **Type**: Choice
- **Options**: "None" | "Region-locked (specify in follow-up)" | "GDPR-aware (EU users)" | "HIPAA" | "PCI-DSS" | "SOC 2"
- **Condition**: Always
- **Updates**: `context.phases.dataArchitecture.compliance` (loose)

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

### P4.Q2: "API style?"
- **Type**: Choice
- **Options**: "REST" | "GraphQL" | "tRPC (TypeScript-only)" | "gRPC" | "Other RPC" | "No API surface"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.apiIntegration.style` (required, enum)
- **Cross-phase**: dataArchitecture reads for codegen pairing; future authSecurity reads for auth integration pattern

### P4.Q3: "API documentation tool?"
- **Type**: Choice
- **Options**: "OpenAPI / Swagger" | "GraphQL Playground / Apollo Studio" | "Auto-from-types (TS-RPC, etc.)" | "Manual (Markdown / Notion)" | "No docs"
- **Condition**: Q2 ≠ none
- **Updates**: `context.phases.apiIntegration.documentation` (loose)

### P4.Q4: "Versioning policy?"
- **Type**: Choice
- **Options**: "URL path (/v1/, /v2/)" | "Header (Accept-Version)" | "Query string (?v=1)" | "No-breaking-changes policy (additive only)" | "None yet — figure it out later"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.apiIntegration.versioningPolicy` (required, enum)
- **Cross-phase**: Future P7 reads for breaking-change policy

### P4.Q5: "Rate limiting strategy?"
- **Type**: Choice
- **Options**: "None" | "Fixed window (Redis-backed)" | "Sliding window" | "Token bucket" | "Per-user / per-API-key" | "Per-IP" | "Gateway-level (Cloudflare, AWS API Gateway)"
- **Condition**: Q1 = yes && `willDeploy`
- **Updates**: `context.phases.apiIntegration.rateLimit` (loose)

### P4.Q6: "Pagination strategy?"
- **Type**: Choice
- **Options**: "Offset (LIMIT/OFFSET)" | "Cursor (timestamp or ID-based)" | "Page-based (page=N&size=M)" | "Both offset + cursor (REST: cursor; GraphQL: Relay)" | "None — return all"
- **Condition**: Q2 ∈ (rest, graphql)
- **Updates**: `context.phases.apiIntegration.pagination` (loose)

### P4.Q7: "Async pattern for background work?"
- **Type**: Choice
- **Options**: "None — all sync" | "Queue + worker (BullMQ, Celery, Sidekiq)" | "Scheduled cron jobs" | "Event-driven (pub/sub)" | "Serverless functions (Lambda, Cloud Functions)" | "Mixed"
- **Condition**: `hasBackend`
- **Updates**: `context.phases.apiIntegration.asyncPattern` (required, enum)
- **Cross-phase**: Future P7 reads for CI test strategy

### P4.Q8: "Real-time delivery?"
- **Type**: Choice
- **Options**: "None" | "WebSockets" | "Server-Sent Events (SSE)" | "HTTP long-polling" | "External pub/sub (Pusher, Ably, Liveblocks)"
- **Condition**: `hasBackend && hasFrontend`
- **Updates**: `context.phases.apiIntegration.realtime` (loose)

### P4.Q9: "Webhooks — incoming and outgoing?"
- **Type**: Composite (choice + multi-select)
- **Sub-questions**:
  - Direction: "None" | "Incoming only (we receive)" | "Outgoing only (we send)" | "Both"
  - Tooling (multi-select; pad with "None / Skip" if zero matches): "Signature verification" | "Retry queue" | "Dead-letter handling" | "Webhook registry UI"
- **Condition**: Q1 = yes
- **Updates**: `context.phases.apiIntegration.webhooks` (loose)

### P4.Q10: "External services and integrations?"
- **Type**: Multi-select free-text
- **Options**: "Payments (Stripe, Paddle, Lemon Squeezy)" | "Email (Resend, SendGrid, Postmark)" | "SMS (Twilio)" | "Analytics (Segment, Mixpanel, PostHog)" | "Search (Algolia)" | "Storage (S3-compatible)" | "AI / LLM (OpenAI, Anthropic, etc.)" | "Other — specify"
- **Condition**: Always (even no-API apps integrate with services)
- **Updates**: `context.phases.apiIntegration.externalServices` (loose array)

**>>> SYNTHESIS PAUSE**: After P4.Q10, invoke `Skill(synthesis-review, phaseId: "apiIntegration")`. Wait for the developer to Approve/Adjust/Skip each section before moving to the remaining Project Details step.

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

### Q3.6: "What's your monitoring and observability strategy?"
- **Type**: Multi-select
- **Options**: "Logging framework" | "Error tracking (Sentry, etc.)" | "Analytics" | "Uptime monitoring" | "Not needed yet"
- **Condition**: `isProduction`
- **Updates**: `monitoring`

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
- **Updates**: `prReviewTrigger` AND `phases.cicdAndDelivery._v1_carryover.prReviewTrigger`

### Q5.4: "Which CI provider will you use?"
- **Type**: Choice
- **Options**: "GitHub Actions" | "GitLab CI" | "CircleCI" | "BuildKite" | "Jenkins" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.provider`
- **Note**: Round 1 only emits GitHub Actions workflow templates. Non-GHA values are captured but produce a note in synthesis review; non-GHA template support lands in Round 6.

### Q5.5: "When should CI run?"
- **Type**: Multi-select
- **Options**: "Push to main" | "Every PR" | "Scheduled" | "Manual dispatch" | "On tag"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.triggers[]`

### Q5.6: "Which checks must pass before a PR can merge?"
- **Type**: Multi-select
- **Options**: "Lint" | "Typecheck" | "Unit tests" | "Integration tests" | "E2E tests" | "Security scan" | "Coverage" | "Build"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.requiredPreMergeChecks[]`
- **Recommend**: Default selection adapts to stack — Node/TS projects get lint+typecheck+unit+build; Python adds ruff in place of lint+typecheck.

### Q5.7: "Coverage threshold — what value blocks merges, if any?"
- **Type**: Composite (numeric + choice + boolean)
- **Sub-questions**:
  - Threshold (numeric 0–100, or `null` for no threshold)
  - Scope: "Global" | "Per-package" | "Per-file"
  - Blocking: yes/no — should coverage drops block PRs?
- **Condition**: `willDeploy && (Q5.6 selection includes "Coverage")`
- **Updates**: `phases.cicdAndDelivery.cicd.coverage.{threshold,scope,blocking}`

### Q5.8: "Environment ladder — what environments will you deploy to?"
- **Type**: Choice
- **Options**: "Single (prod only)" | "Preview + prod" | "Staging + prod" | "Dev + staging + prod" | "Custom"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.envLadder[]`
- **Recommend**: Default to "Preview + prod" for SaaS; "Single" for hobby projects; "Staging + prod" for B2B with paying customers.

### Q5.9: "How does deployment happen?"
- **Type**: Choice
- **Options**: "Auto on merge" | "Manual button" | "Scheduled window" | "Tag-triggered" | "None — I'll deploy by hand"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.autoDeploy`

### Q5.10: "Deploy cadence — how often will you ship?"
- **Type**: Choice
- **Options**: "Continuous (multiple per day)" | "Daily" | "Weekly" | "On-demand only" | "Not deploying"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.deployCadence`

### Q5.11: "Rollback strategy?"
- **Type**: Composite (choice + boolean)
- **Sub-questions**:
  - Strategy: "Redeploy previous SHA" | "Blue-green" | "Canary" | "None"
  - Automation: yes/no — automated on failure detection?
- **Condition**: `willDeploy && Q5.9 !== "None"`
- **Updates**: `phases.cicdAndDelivery.cicd.rollback.{strategy,automation}`

### Q5.12: "How are CI secrets managed?"
- **Type**: Composite (choice + choice)
- **Sub-questions**:
  - Manager: "Provider-stored (GitHub/GitLab secrets)" | "OIDC to cloud" | "Vault" | "1Password" | "Doppler" | "Manual env files"
  - Rotation: "Manual only" | "Scheduled" | "On incident only"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.secrets.{manager,rotation}`

### Q5.13: "Where should CI notifications go?"
- **Type**: Composite (multi-select + multi-select)
- **Sub-questions**:
  - Channels (multi-select): "Slack" | "Discord" | "Email" | "GitHub checks only"
  - Events (multi-select): "Build failure" | "Deploy success" | "Deploy failure" | "Security alert"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.notifications.{channels[],events[]}`
- **Note**: Solo developer + Slack channel selection triggers a warning in synthesis review.

### Q5.14: "Build matrix?"
- **Type**: Composite (multi-select + choice + choice)
- **Sub-questions**:
  - OS targets (multi-select): "ubuntu-latest" | "macos-latest" | "windows-latest"
  - Language versions: "Single (current LTS)" | "Multi (current LTS + previous)"
  - Parallelization: "Auto (CI provider decides)" | "Off (serial)" | numeric value
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.buildMatrix.{os[],languageVersions,parallelization}`
- **Recommend**: Most projects → single ubuntu-latest. Cross-platform tools → multi-OS. Libraries → multi-version.

### Q5.15: "Caching strategy?"
- **Type**: Composite (booleans + choice)
- **Sub-questions**:
  - Deps: cache dependency installs (yes/no)
  - Build: cache build outputs (yes/no)
  - Docker layers: cache Docker layers (yes/no)
  - Remote backend: "Turbo Remote Cache" | "BuildKite Cache" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.caching.{deps,build,dockerLayers,remote}`

### Q5.16: "CI time budget?"
- **Type**: Composite (numeric + optional numeric)
- **Sub-questions**:
  - Per-pipeline target minutes
  - Blocking threshold minutes (optional — pipelines exceeding this fail; null means no block)
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.timeBudget.{perPipelineMinutes,blockingThresholdMinutes}`

### Q5.17: "Release pipeline?"
- **Type**: Composite (boolean + choice + choice)
- **Sub-questions**:
  - Separate from main CI: yes/no
  - Triggered by: "Tag" | "Manual" | "Schedule"
  - Convention: "release-please" | "semantic-release" | "Manual" | "None"
- **Condition**: `willDeploy`
- **Updates**: `phases.cicdAndDelivery.cicd.releasePipeline.{separate,triggeredBy,convention}`
- **Note**: `release-please` and `semantic-release` are Node-centric. Mismatches with `stack.stack.framework` (non-Node stacks) trigger a synthesis warning.

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

### AV.Q2: "What's the final note for future maintainers about the divergences or rework needed?"
- **Type**: Open-ended (free text)
- **Condition**: ONLY if `AV.Q1 === "approved-with-noted-divergences"` OR `AV.Q1 === "requires-rework"`. Skip entirely if `approved`.
- **Updates**: `context.phases.architecturalValidation.finalNotes` (loose string — developer writes whatever is relevant; captured verbatim)
- **Prompt examples**:
  - For divergences: "Note what was changed from the original framing and why — future sessions need this context."
  - For rework: "Describe what needs to be revisited so the next session can resume at the right step."

**>>> SYNTHESIS PAUSE**: After AV.Q1 (and AV.Q2 if applicable), invoke `Skill(synthesis-review, phaseId: "architecturalValidation")`. The synthesis renders `docs/architecture/architectural-validation.html` with the full cross-phase validation report, divergence table, and sign-off status. Wait for the developer to Approve/Adjust/Skip each section before proceeding to Phase 1.7 (grill-spec).

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
| CLI tool (appType = cli) | Q3.3, Q3.4 deploy*, Q3.6, Step 3 (dataArchitecture) entire phase, Step 4 (apiIntegration) entire phase, Q3.12-Q3.14, Q3.F1, Q3.F2, Q5.1, Q5.3 |
| Side project, not deploying | Q5.1, Q5.3, Q3.6, Q3.11 (auto deps), P3.Q11 (backup), P4.Q4 (versioning), P4.Q5 (rate limit) |
| API-only backend | Q3.F1, Q3.F2, Q3.12-Q3.14, P4.Q8 (real-time) |
| Solo developer | Q5.3 (PR review), Q5.13 (notifications warning) |
| No database (P3.Q1 = no) | P3.Q2–Q7 |
| No API layer (P4.Q1 = no) | P4.Q2–Q9 |

*When `willDeploy = false`, the entire Category 5 (CI/CD) except Q5.2 is skipped.
