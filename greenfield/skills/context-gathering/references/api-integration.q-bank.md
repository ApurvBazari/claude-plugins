# API & Integration Q-bank — Step 4

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 4 (detailed API-surface phase; preceded by Step 3 dataArchitecture)
> **Modes:** Heavy ~10 Qs (Api.Q1–Q10 + Q_RISK) / Light ~6 Qs (foundational subset + Q_RISK; depth Qs use defaults)
> **Coupling:** Auto-loop on the CRUD-surface Q (`loopMode: always`) and async-pattern Q (`loopMode: hybrid-only`) — both over `domainModel.entities`. Hybrid mode collapses the async-pattern loop to a single static answer.
> **Source:** Q content migrated from `question-bank.md` § "Step 4: API & Integration" (lines 281–394); R4 added Q_RISK + showInLight + loopOver tags + format conversion.
> **See also:** `architectural-framing.q-bank.md`, `data-architecture.q-bank.md`, `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk + § Coupling matrix

This phase gathers API-surface decisions: whether to expose an API, style/protocol, documentation, versioning, rate limits, pagination, async patterns, real-time, webhooks, external integrations. Synthesis review fires inline after Api.Q_RISK.

## Q-bank

### Api.Q1 — API surface gate

- **type:** single-select
- **options:** ["Yes — public API", "Yes — internal/private only", "No — UI-only app", "Not sure — recommend"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (gate for the rest of Step 4 / apiIntegration)
- **R3-updates-path:** `context.phases.apiIntegration` (gate flag; if "No", skip Q2–Q9, ask Q10 only)

**Prompt:** "Does this app expose an API surface?"

**Stores to:** `apiIntegration.exposesAPI`

**Downstream effects:** Gates Q2–Q9. If "No — UI-only app", skip style/docs/versioning/rate-limits/pagination/async/realtime/webhooks but still ask Q10 (external integrations).

**Default:** `"Yes — internal/private only"`
- If `appType: "api"` → `"Yes — public API"`
- If `appType ∈ (fullstack, web-app)` AND `hasBackend` → `"Yes — internal/private only"`
- If `appType: "cli"` → `"No — UI-only app"` (CLI has no API surface by default)
- Else → `"Yes — internal/private only"` (greenfield opinion: most backend services expose at minimum an internal API)

### Api.Q2 — API style

- **type:** single-select
- **options:** ["REST", "GraphQL", "tRPC (TypeScript-only)", "gRPC", "Other RPC", "No API surface"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.apiIntegration.style`
- **loopOver:** domainModel.entities
- **loopMode:** always <!-- fires in both auto-loop and hybrid -->

**Prompt:** "For entity {entity.id}: API style?"

**Stores to:** `apiIntegration.style`

**Cross-phase:** dataArchitecture reads for codegen pairing; future authSecurity reads for auth integration pattern.

**Default:** `"REST"`
- If `stack.stack.language: "typescript"` AND `appType: "fullstack"` AND `stack.stack.framework ∈ (next, nuxt, remix)` → `"tRPC"` (greenfield opinion: tRPC eliminates the API contract layer for full-stack TypeScript)
- If `stack.stack.language: "typescript"` → `"REST"`
- If `stack.stack.language ∈ (python, go, ruby, java, kotlin)` → `"REST"` (REST is idiomatic for all of these)
- If `architecturalFraming.topology: "microservices"` AND `stack.stack.language: "go"` → `"gRPC"` (greenfield opinion: gRPC is idiomatic for Go microservice-to-service communication)
- Else → `"REST"` (greenfield opinion: REST is the most widely understood API style; switch to tRPC/GraphQL when the full-stack type sharing becomes a concrete pain point)

### Api.Q3 — API documentation tool

- **type:** single-select
- **options:** ["OpenAPI / Swagger", "GraphQL Playground / Apollo Studio", "Auto-from-types (TS-RPC, etc.)", "Manual (Markdown / Notion)", "No docs"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q2 ≠ none
- **R3-updates-path:** `context.phases.apiIntegration.documentation`

**Prompt:** "API documentation tool?"

**Stores to:** `apiIntegration.documentation`

**Default:** `"OpenAPI / Swagger"`
- If `apiIntegration.style: "graphql"` → `"GraphQL Playground / Apollo Studio"`
- If `apiIntegration.style: "trpc"` → `"Auto-from-types (TS-RPC, etc.)"` (tRPC generates types automatically)
- If `apiIntegration.style: "grpc"` → `"Auto-from-types (TS-RPC, etc.)"` (protobuf generates docs)
- If `architecturalFraming.scaleTarget: "hobby"` → `"No docs"` (greenfield opinion: hobby projects don't need formal API documentation)
- Else → `"OpenAPI / Swagger"` (greenfield opinion: OpenAPI is the industry standard for REST; Swagger UI is zero-overhead to add)

### Api.Q4 — Versioning policy

- **type:** single-select
- **options:** ["URL path (/v1/, /v2/)", "Header (Accept-Version)", "Query string (?v=1)", "No-breaking-changes policy (additive only)", "None yet — figure it out later"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Q1 = yes AND `willDeploy`
- **R3-updates-path:** `context.phases.apiIntegration.versioningPolicy`

**Prompt:** "Versioning policy?"

**Stores to:** `apiIntegration.versioningPolicy`

**Cross-phase:** Future P7 reads for breaking-change policy.

**Default:** `"URL path (/v1/, /v2/)"`
- If `apiIntegration.style: "trpc"` → `"No-breaking-changes policy (additive only)"` (tRPC versioning is handled at the type level)
- If `apiIntegration.style: "graphql"` → `"No-breaking-changes policy (additive only)"` (GraphQL schema evolution is additive by convention)
- If `architecturalFraming.scaleTarget: "hobby"` → `"None yet — figure it out later"`
- Else → `"URL path (/v1/, /v2/)"` (greenfield opinion: URL path versioning is the most explicit and easiest for clients to debug)

### Api.Q5 — Rate limiting strategy

- **type:** single-select
- **options:** ["None", "Fixed window (Redis-backed)", "Sliding window", "Token bucket", "Per-user / per-API-key", "Per-IP", "Gateway-level (Cloudflare, AWS API Gateway)"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Q1 = yes AND `willDeploy`
- **R3-updates-path:** `context.phases.apiIntegration.rateLimit`

**Prompt:** "Rate limiting strategy?"

**Stores to:** `apiIntegration.rateLimit`

**Default:** `"None"`
- If `apiIntegration.style: "public API"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Per-user / per-API-key"` (greenfield opinion: public APIs need per-key rate limits to prevent abuse)
- If `architecturalFraming.deploymentShape ∈ (edge-distributed)` → `"Gateway-level (Cloudflare, AWS API Gateway)"` (edge deployments have gateway-level rate limiting built in)
- If `architecturalFraming.scaleTarget: "startup"` AND `dataArchitecture.cache ∈ (redis)` → `"Fixed window (Redis-backed)"`
- Else → `"None"` (greenfield opinion: add rate limiting when you have a real abuse concern, not by default)

### Api.Q6 — Pagination strategy

- **type:** single-select
- **options:** ["Offset (LIMIT/OFFSET)", "Cursor (timestamp or ID-based)", "Page-based (page=N&size=M)", "Both offset + cursor (REST: cursor; GraphQL: Relay)", "None — return all"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Q2 ∈ (rest, graphql)
- **R3-updates-path:** `context.phases.apiIntegration.pagination`

**Prompt:** "Pagination strategy?"

**Stores to:** `apiIntegration.pagination`

**Default:** `"Cursor (timestamp or ID-based)"`
- If `apiIntegration.style: "graphql"` → `"Both offset + cursor (REST: cursor; GraphQL: Relay)"` (Relay cursor pagination is GraphQL convention)
- If `architecturalFraming.scaleTarget: "hobby"` → `"Offset (LIMIT/OFFSET)"` (simplest; fine for small datasets)
- Else → `"Cursor (timestamp or ID-based)"` (greenfield opinion: cursor pagination is stable under inserts/deletes and scales better than offset)

### Api.Q7 — Async background work

- **type:** single-select
- **options:** ["Yes", "No"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `apiIntegration.exposesAPI = true`
- **R3-updates-path:** `context.phases.apiIntegration.asyncPattern`
- **loopOver:** domainModel.entities
- **loopMode:** hybrid-only <!-- skipped in hybrid coupling; fires once static instead -->

**Prompt:** "For entity {entity.id} async pattern: Does this app have async background work?"

**Stores to:** `apiIntegration.asyncPattern`

**Note:** Full background job configuration (queue tech, retries, idempotency, scheduling) moved to Step 8 Runtime Operations (Ops.Q1–Q3). This Q is now a single yes/no gate.

**Default:** `"Yes"` if `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` else `"No"`

### Api.Q8 — Real-time delivery

- **type:** single-select
- **options:** ["None", "WebSockets", "Server-Sent Events (SSE)", "HTTP long-polling", "External pub/sub (Pusher, Ably, Liveblocks)"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `hasBackend && hasFrontend`
- **R3-updates-path:** `context.phases.apiIntegration.realtime`

**Prompt:** "Real-time delivery?"

**Stores to:** `apiIntegration.realtime`

**Default:** `"None"`
- If `appType: "fullstack"` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale, enterprise)` AND `architecturalFraming.topology ∈ (monolith, modular-monolith)` → `"Server-Sent Events (SSE)"` (greenfield opinion: SSE is simpler than WebSockets for unidirectional real-time; add WebSockets when bidirectional is required)
- If `architecturalFraming.topology: "serverless"` → `"External pub/sub (Pusher, Ably, Liveblocks)"` (serverless can't hold long-lived WebSocket connections)
- Else → `"None"` (greenfield opinion: real-time is a feature that should be added when users need it, not by default)

### Api.Q9 — Webhooks

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Q1 = yes
- **R3-updates-path:** `context.phases.apiIntegration.webhooks`

**Prompt:** "Webhooks — incoming and outgoing?"

**Stores to:** `apiIntegration.webhooks`

**Sub-questions:**
- Direction (single-select): "None" | "Incoming only (we receive)" | "Outgoing only (we send)" | "Both"
- Tooling (multi-select; pad with "None / Skip" if zero matches): "Signature verification" | "Retry queue" | "Dead-letter handling" | "Webhook registry UI"

**Default:** Direction: `"None"`, Tooling: `[]`
- If `apiIntegration.externalServices` includes payment providers (Stripe, Paddle) → Direction: `"Incoming only (we receive)"`, Tooling: `["Signature verification"]` (payment providers send webhooks; signature verification is mandatory)
- Else → Direction: `"None"` (greenfield opinion: webhooks are an integration feature; add them when a specific integration requires it)

### Api.Q10 — External services and integrations

- **type:** multi-select
- **options:** ["Payments (Stripe, Paddle, Lemon Squeezy)", "Email (Resend, SendGrid, Postmark)", "SMS (Twilio)", "Analytics (Segment, Mixpanel, PostHog)", "Search (Algolia)", "Storage (S3-compatible)", "AI / LLM (OpenAI, Anthropic, etc.)", "Other — specify"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (even no-API apps integrate with services)
- **R3-updates-path:** `context.phases.apiIntegration.externalServices`

**Prompt:** "External services and integrations?"

**Stores to:** `apiIntegration.externalServices`

**Default:** `[]` (no external services)
- Always — greenfield opinion: integrations are product decisions; no default is appropriate here. Use Enter to indicate no integrations planned.

### Api.Q_RISK — API integration risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["performance", "vendor-lock", "compliance", "rate-limit"]

**Prompt:** "What's the biggest API integration risk for THIS project? (e.g., 'sync REST chosen but two callers really need async', 'vendor SDK ties us to one cloud', 'rate limit assumptions break under burst traffic'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "apiIntegration"`, id auto-assigned `R-APIINTEGRATION-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Api.Q1 | ✓ | ✓ | API gate — fundamental |
| Api.Q2 | ✓ | ✓ | API style — fundamental (loops per entity; CRUD-surface Q, always mode) |
| Api.Q3 | ✓ | ✓ | Documentation — fundamental |
| Api.Q4 | ✓ | ✓ | Versioning — fundamental |
| Api.Q5 | ✓ | — | Rate limiting — depth, uses default in light |
| Api.Q6 | ✓ | — | Pagination — depth, uses default in light |
| Api.Q7 | ✓ | ✓ | Async gate — fundamental (loops per entity; async-pattern Q, hybrid mode) |
| Api.Q8 | ✓ | — | Real-time — depth, uses default in light |
| Api.Q9 | ✓ | — | Webhooks — depth, uses default in light |
| Api.Q10 | ✓ | ✓ | External integrations — fundamental (Condition: Always) |
| Api.Q_RISK | ✓ | ✓ | Always fires |
