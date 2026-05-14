# Runtime Operations Q-bank — Step 8

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 8 (Runtime Operations; preceded by Step 7 security; supersedes parts of former P4.Q7 and Q3.6)
> **Modes:** Heavy ~14 Qs (Ops.Q1–Q14 + Q_RISK) / Light ~7 Qs (foundational + Q_RISK; depth Qs use defaults)
> **Coupling:** Auto-loop on the SLO Q (`loopMode: hybrid-only`, over `personas.primary`) and alert-routing Q (`loopMode: hybrid-only`, over `personas.primary`). Hybrid mode collapses both to single static prompts.
> **Source:** Q content migrated from `question-bank.md` § "Step 8: Runtime Operations" (lines 994–1619); R4 added Q_RISK + showInLight + loopOver tags + format conversion.
> **See also:** `security.q-bank.md`, `cicd.q-bank.md` (forthcoming T12), `inline-risk.q-bank.md`, design spec § Distributed Risk + § Coupling matrix.

This phase covers operational concerns: background jobs, scheduling, retries/idempotency, observability (metrics + logs + traces), SLO targets (per persona), alert routing (per persona), incident process, runbooks, feature flags, capacity planning, cost monitoring. Synthesis review fires inline after Ops.Q_RISK.

## Q-bank

### Ops.Q1 — Background job system

- **type:** single-select
- **options:** ["Redis / BullMQ", "Sidekiq (Ruby)", "Celery (Python)", "AWS SQS", "Google Cloud Tasks", "Inngest", "Temporal", "Platform-native (Vercel Cron, Railway Jobs)", "None"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `hasBackend: true` — **AUTO-SKIP if `apiIntegration.asyncPattern = 'none'`; default to `"None"` without asking**
- **R3-updates-path:** `context.phases.runtimeOperations.jobs`

**Prompt:** "What background job system will you use?"

**Stores to:** `runtimeOperations.jobs`

**Downstream effects:** Ops.Q2 (retry/idempotency) and Ops.Q3 (scheduling) both depend on this answer.

**Default:**
- If `apiIntegration.asyncPattern = 'none'` → `"None"` (**auto-skipped — not asked**; no async pattern means no job system needed)
- If `stack.stack.language: "typescript"` AND `apiIntegration.asyncPattern ≠ 'none'` → `"Redis / BullMQ"` (greenfield opinion: BullMQ is the TypeScript/Node.js ecosystem standard for reliable queue-backed job processing; Redis is available on all major hosting platforms)
- If `stack.stack.language: "python"` AND `apiIntegration.asyncPattern ≠ 'none'` → `"Celery (Python)"` (Celery is the de facto Python task queue; works with Redis or RabbitMQ as broker)
- If `stack.stack.language: "ruby"` → `"Sidekiq (Ruby)"` (Sidekiq is the idiomatic Rails background job library; battle-tested and Redis-backed)
- If `architecturalFraming.topology: "serverless"` → `"Platform-native (Vercel Cron, Railway Jobs)"` (serverless architectures cannot run persistent workers; platform-native job triggers are the correct model)
- If `apiIntegration.asyncPattern: "event-driven"` AND `apiIntegration.externalServices` includes AWS → `"AWS SQS"` (SQS integrates natively with Lambda and ECS for event-driven architectures)
- Else → `"None"` (greenfield opinion: add a job system when a specific feature requires async processing — premature job infrastructure adds operational overhead without benefit)

### Ops.Q2 — Retry and idempotency strategy

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `runtimeOperations.jobs ≠ 'None'` — **SKIP if `runtimeOperations.jobs = 'None'`**
- **R3-updates-path:** `context.phases.runtimeOperations.retryStrategy`

**Prompt:** "What retry and idempotency strategy will you apply?"

**Stores to:** `runtimeOperations.retryStrategy` (object)

**Sub-questions:**
- `semantics` (single-select): `"at-least-once (retries possible; jobs must be idempotent)"` | `"exactly-once (deduplication enforced at queue level)"`
- `retryPolicy` (single-select): `"exponential backoff (default)"` | `"linear backoff"` | `"fixed interval"` | `"no retries"`
- `maxAttempts` (integer): e.g., `3`, `5`, `10`
- `deadLetterQueue` (boolean): whether failed-after-max-attempts jobs route to a DLQ

**Default:**
- If `runtimeOperations.jobs: "Redis / BullMQ"` → `semantics: "at-least-once"`, `retryPolicy: "exponential backoff"`, `maxAttempts: 3`, `deadLetterQueue: true` (greenfield opinion: BullMQ's default exponential backoff is well-tuned; DLQ prevents silent job loss — every failed job should be inspectable)
- If `runtimeOperations.jobs: "Celery (Python)"` → `semantics: "at-least-once"`, `retryPolicy: "exponential backoff"`, `maxAttempts: 3`, `deadLetterQueue: true` (Celery's `autoretry_for` + `max_retries` maps cleanly to this; DLQ via dead-letter exchange in RabbitMQ or a separate Redis list)
- If `security.sensitivityTier: "high"` → `semantics: "exactly-once"`, `retryPolicy: "exponential backoff"`, `maxAttempts: 5`, `deadLetterQueue: true` (high-sensitivity apps (payments, health) require idempotency keys to prevent duplicate side effects from retries — charge-twice bugs are worse than charge-never)
- If `apiIntegration.externalServices` includes payment providers → `semantics: "exactly-once"`, `deadLetterQueue: true` (payment operations MUST be idempotent; at-least-once with payment APIs causes double-charges)
- Else → `semantics: "at-least-once"`, `retryPolicy: "exponential backoff"`, `maxAttempts: 3`, `deadLetterQueue: true` (greenfield opinion: at-least-once with exponential backoff is the correct baseline — simpler than exactly-once and sufficient when jobs are designed to be idempotent)

### Ops.Q3 — Scheduled task mechanism

- **type:** single-select
- **options:** ["Distributed scheduler (BullMQ repeatable jobs, Celery beat)", "Platform cron (Vercel Cron, Railway Cron, Heroku Scheduler)", "OS/container cron (crontab, Kubernetes CronJob)", "Database-driven scheduler (pg_cron)", "None"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `hasBackend: true`
- **R3-updates-path:** `context.phases.runtimeOperations.scheduling`

**Prompt:** "What scheduled task mechanism will you use?"

**Stores to:** `runtimeOperations.scheduling`

**Default:**
- If `runtimeOperations.jobs: "Redis / BullMQ"` → `"Distributed scheduler (BullMQ repeatable jobs, Celery beat)"` (greenfield opinion: use BullMQ repeatable jobs for scheduled tasks when BullMQ is already in the stack — no additional infrastructure and tasks run with retry semantics)
- If `runtimeOperations.jobs: "Celery (Python)"` → `"Distributed scheduler (BullMQ repeatable jobs, Celery beat)"` (Celery Beat is the standard scheduler; integrates with existing Celery worker fleet)
- If `architecturalFraming.topology: "serverless"` → `"Platform cron (Vercel Cron, Railway Cron, Heroku Scheduler)"` (platform cron is the only viable option for serverless — no persistent process to host a scheduler)
- If `Q3.4.deployTarget ∈ (Kubernetes, self-hosted)` → `"OS/container cron (crontab, Kubernetes CronJob)"` (Kubernetes CronJob is the idiomatic scheduler for container-native deployments)
- If `dataArchitecture.engine ∈ (postgres)` AND `runtimeOperations.jobs: "None"` → `"Database-driven scheduler (pg_cron)"` (pg_cron is a zero-infrastructure option for simple scheduled queries or maintenance tasks when no job system is in place)
- Else → `"None"` (greenfield opinion: scheduled tasks are a feature-driven addition; add scheduling when a specific recurring task is identified)

### Ops.Q4 — Metrics and uptime monitoring

- **type:** single-select
- **options:** ["Prometheus + Grafana (self-hosted)", "Datadog", "Grafana Cloud", "Platform-native (Vercel Analytics, Railway Metrics)", "None"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.runtimeOperations.metrics`

**Prompt:** "What metrics and uptime monitoring will you use?"

**Stores to:** `runtimeOperations.metrics`

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Datadog"` (greenfield opinion: Datadog's unified observability platform is the enterprise standard; deep integrations with AWS, GCP, Azure, Kubernetes)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `architecturalFraming.topology: "microservices"` → `"Prometheus + Grafana (self-hosted)"` (Prometheus + Grafana is the open-source standard for microservices metrics; Kubernetes-native with Helm charts)
- If `architecturalFraming.scaleTarget ∈ (startup, production-scale)` AND `Q3.4.deployTarget ∈ (Vercel, Railway, Render)` → `"Platform-native (Vercel Analytics, Railway Metrics)"` (greenfield opinion: platform-native metrics are zero-config for managed platforms — no additional infrastructure; graduate to Grafana Cloud when cross-service dashboards are needed)
- If `architecturalFraming.scaleTarget ∈ (startup, production-scale)` → `"Grafana Cloud"` (Grafana Cloud's free tier covers most startup workloads; hosted Prometheus + Grafana without self-hosting overhead)
- If `architecturalFraming.scaleTarget: "hobby"` → `"None"` (greenfield opinion: hobby apps don't need metrics infrastructure; rely on platform health dashboards)
- Else → `"None"` (greenfield opinion: add metrics when you have SLOs to measure against — without targets, dashboards are noise)

### Ops.Q5 — Distributed tracing and error tracking

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** (`architecturalFraming.topology: "microservices"`) OR (`architecturalFraming.scaleTarget ∈ (production-scale, enterprise)`) — **AUTO-SKIP for hobby and startup monolith; default both to `"None"` without asking**
- **R3-updates-path:** `context.phases.runtimeOperations.traces`

**Prompt:** "What distributed tracing and error tracking will you use?"

**Stores to:** `runtimeOperations.traces` (object)

**Sub-questions:**
- `tracing` (single-select): `"OpenTelemetry + Honeycomb"` | `"OpenTelemetry + Datadog APM"` | `"OpenTelemetry + Tempo (Grafana)"` | `"Sentry Performance"` | `"None"`
- `errorTracking` (single-select): `"Sentry"` | `"Datadog Error Tracking"` | `"Honeycomb"` | `"None"`

**Default:**
- If `architecturalFraming.topology: "microservices"` AND `architecturalFraming.scaleTarget: "enterprise"` → `tracing: "OpenTelemetry + Datadog APM"`, `errorTracking: "Datadog Error Tracking"` (greenfield opinion: Datadog APM integrates tracing and error tracking in one platform for enterprise microservices; OTel instrumentation keeps you vendor-neutral at the SDK level)
- If `architecturalFraming.topology: "microservices"` → `tracing: "OpenTelemetry + Honeycomb"`, `errorTracking: "Sentry"` (greenfield opinion: Honeycomb's query model is purpose-built for distributed trace exploration; Sentry handles error aggregation and alerting separately)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `runtimeOperations.metrics: "Grafana Cloud"` → `tracing: "OpenTelemetry + Tempo (Grafana)"`, `errorTracking: "Sentry"` (Tempo integrates with existing Grafana Cloud stack for unified logs + metrics + traces)
- If `architecturalFraming.scaleTarget: "production-scale"` → `tracing: "OpenTelemetry + Honeycomb"`, `errorTracking: "Sentry"` (greenfield opinion: Sentry is the community standard for error tracking; OTel + Honeycomb for distributed tracing without Datadog pricing)
- If `architecturalFraming.scaleTarget ∈ (hobby, startup)` → `tracing: "None"`, `errorTracking: "None"` (**auto-skipped for hobby/startup monolith — not asked**; distributed tracing infrastructure is overhead that doesn't pay off at this scale)
- Else → `tracing: "None"`, `errorTracking: "Sentry"` (greenfield opinion: even without distributed tracing, Sentry's error tracking catches exceptions and provides stack traces — minimum viable error observability)

### Ops.Q6 — Structured logging and log aggregation

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.runtimeOperations.logs`

**Prompt:** "What structured logging and log aggregation will you use?"

**Stores to:** `runtimeOperations.logs` (object)

**Sub-questions:**
- `format` (single-select): `"structured JSON (Winston, Pino, structlog, zerolog)"` | `"unstructured text"` | `"platform-default"`
- `aggregator` (single-select): `"Grafana Loki"` | `"Logtail / Better Stack"` | `"Datadog Logs"` | `"AWS CloudWatch Logs"` | `"Platform-native (Vercel Logs, Railway Logs)"` | `"None"`
- `retentionDays` (integer): e.g., `7`, `30`, `90`, `365`

**Default:**
- If `security.sensitivityTier: "high"` → `format: "structured JSON"`, `aggregator: "Datadog Logs"`, `retentionDays: 365` (greenfield opinion: compliance tiers require structured, searchable, long-retention logs; Datadog Logs integrates with Datadog APM for correlated trace-to-log drilling)
- If `architecturalFraming.scaleTarget: "enterprise"` → `format: "structured JSON"`, `aggregator: "Datadog Logs"`, `retentionDays: 365` (enterprise ops teams need centralized, structured logs with long retention for incident forensics and compliance audits)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `runtimeOperations.metrics: "Grafana Cloud"` → `format: "structured JSON"`, `aggregator: "Grafana Loki"`, `retentionDays: 90` (Loki integrates with Grafana Cloud for unified logs + metrics exploration; structured JSON enables efficient label-based querying)
- If `Q3.4.deployTarget ∈ (Vercel, Railway, Render, Fly.io)` → `format: "structured JSON"`, `aggregator: "Platform-native (Vercel Logs, Railway Logs)"`, `retentionDays: 30` (greenfield opinion: platform-native log ingestion is zero-config; structured JSON makes logs grep-able even in the platform UI)
- If `Q3.4.deployTarget ∈ (AWS)` → `format: "structured JSON"`, `aggregator: "AWS CloudWatch Logs"`, `retentionDays: 30` (CloudWatch Logs is AWS-native; integrates with Lambda, ECS, and EC2 without additional configuration)
- If `architecturalFraming.scaleTarget: "hobby"` → `format: "platform-default"`, `aggregator: "None"`, `retentionDays: 7` (greenfield opinion: hobby apps rely on platform stdout logs; no aggregation needed)
- Else → `format: "structured JSON"`, `aggregator: "Logtail / Better Stack"`, `retentionDays: 30` (greenfield opinion: structured JSON + Logtail is the zero-friction default for startups — Logtail's free tier covers most workloads and structured logs are machine-readable from day one)

### Ops.Q7 — Alert routing and paging setup

<!-- skipped in hybrid coupling; fires once static instead -->

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always — **Required to be non-'None' if `security.sensitivityTier = 'high'`**
- **R3-updates-path:** `context.phases.runtimeOperations.alerting`
- **loopOver:** personas.primary
- **loopMode:** hybrid-only

**Prompt (auto-loop):** "For persona {persona.id}, what alert routing applies?"

**Prompt (hybrid fallback):** "Define alert routing strategy."

**Stores to:** `runtimeOperations.alerting` (object)

**Sub-questions:**
- `channel` (single-select): `"PagerDuty"` | `"OpsGenie"` | `"Slack webhook"` | `"Discord webhook"` | `"Email (SMTP)"` | `"None"`
- `thresholdStrategy` (single-select): `"static thresholds (fixed error rate / latency limits)"` | `"anomaly-based (ML-detected spikes)"` | `"SLO burn rate alerts"` | `"none"`

**Default:**
- If `security.sensitivityTier: "high"` → `channel: "PagerDuty"`, `thresholdStrategy: "SLO burn rate alerts"` (greenfield opinion: high-tier apps require a dedicated paging system — Slack/email alerts are missed during off-hours; SLO burn rate alerts reduce noise by only paging when the error budget is actually at risk)
- If `architecturalFraming.scaleTarget: "enterprise"` → `channel: "PagerDuty"`, `thresholdStrategy: "SLO burn rate alerts"` (enterprise ops requires professional on-call tooling with escalation policies and audit trails — PagerDuty is the standard)
- If `architecturalFraming.scaleTarget: "production-scale"` → `channel: "Slack webhook"`, `thresholdStrategy: "static thresholds (fixed error rate / latency limits)"` (greenfield opinion: Slack webhooks are zero-cost and sufficient for single-team production apps; add PagerDuty when you need formal on-call rotation)
- If `architecturalFraming.scaleTarget ∈ (startup)` → `channel: "Slack webhook"`, `thresholdStrategy: "static thresholds (fixed error rate / latency limits)"` (startup teams live in Slack; webhook alerts integrate without additional tooling)
- If `architecturalFraming.scaleTarget: "hobby"` → `channel: "None"`, `thresholdStrategy: "none"` (greenfield opinion: hobby apps don't need alerting infrastructure; check dashboards reactively)
- Else → `channel: "Slack webhook"`, `thresholdStrategy: "static thresholds (fixed error rate / latency limits)"` (greenfield opinion: Slack webhook alerts are the minimum viable alerting setup — zero cost, easy to configure, and catchable by any team member)

### Ops.Q8 — SLI/SLO targets and error budget policy

<!-- skipped in hybrid coupling; fires once static instead -->

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` — **AUTO-SKIP when `architecturalFraming.scaleTarget ∉ (production-scale, enterprise)`; default to `availabilitySlo: "none"`, `errorBudgetPolicy: "none"` without asking**
- **R3-updates-path:** `context.phases.runtimeOperations.slo`
- **loopOver:** personas.primary
- **loopMode:** hybrid-only

**Prompt (auto-loop):** "For persona {persona.id}, what SLO target applies (availability, p95 latency)?"

**Prompt (hybrid fallback):** "Define top 3 SLO targets for the system."

**Stores to:** `runtimeOperations.slo` (object)

**Sub-questions:**
- `availabilitySlo` (string): e.g., `"99.9%"`, `"99.5%"`, `"none"`
- `latencyP99Target` (string): e.g., `"200ms"`, `"500ms"`, `"none"`
- `errorBudgetPolicy` (single-select): `"freeze deployments when budget exhausted"` | `"alert-only (no freeze)"` | `"none"`

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `availabilitySlo: "99.9%"`, `latencyP99Target: "200ms"`, `errorBudgetPolicy: "freeze deployments when budget exhausted"` (enterprise SLAs typically require 99.9% ("three nines") uptime; deploy freeze enforces the contract and prevents the error budget from being drained by CI regressions)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `security.sensitivityTier: "high"` → `availabilitySlo: "99.9%"`, `latencyP99Target: "300ms"`, `errorBudgetPolicy: "freeze deployments when budget exhausted"` (high-sensitivity production apps have implied uptime expectations from users — define them explicitly rather than discovering the SLA via an incident)
- If `architecturalFraming.scaleTarget: "production-scale"` → `availabilitySlo: "99.5%"`, `latencyP99Target: "500ms"`, `errorBudgetPolicy: "alert-only (no freeze)"` (greenfield opinion: 99.5% is a realistic starting SLO for most production apps — achievable without heroics and meaningful enough to drive incident response)
- If `architecturalFraming.scaleTarget ∉ (production-scale, enterprise)` → `availabilitySlo: "none"`, `latencyP99Target: "none"`, `errorBudgetPolicy: "none"` (**auto-skipped — not asked**; SLOs are overhead for hobby and startup apps without formal uptime commitments)
- Else → `availabilitySlo: "99.5%"`, `latencyP99Target: "500ms"`, `errorBudgetPolicy: "alert-only (no freeze)"` (greenfield opinion: defining explicit SLOs forces a conversation about acceptable reliability before an incident — start with 99.5% and tighten based on actual customer expectations)

### Ops.Q9 — Feature flag system

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.runtimeOperations.featureFlags`

**Prompt:** "What feature flag system will you use?"

**Stores to:** `runtimeOperations.featureFlags` (object)

**Sub-questions:**
- `provider` (single-select): `"LaunchDarkly"` | `"Unleash (self-hosted)"` | `"PostHog Feature Flags"` | `"Flagsmith"` | `"Config file (env var + code)"` | `"None"`
- `strategy` (single-select): `"gradual rollout (percentage-based)"` | `"user-targeting (segment rules)"` | `"kill switch only"` | `"none"`

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `provider: "LaunchDarkly"`, `strategy: "gradual rollout (percentage-based)"` (LaunchDarkly is the enterprise standard for feature management; supports complex targeting rules, audit logs, and enterprise SSO)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `apiIntegration.externalServices` includes PostHog → `provider: "PostHog Feature Flags"`, `strategy: "gradual rollout (percentage-based)"` (greenfield opinion: if PostHog is already in the stack for analytics, its feature flags avoid adding a second vendor)
- If `architecturalFraming.scaleTarget: "production-scale"` → `provider: "Flagsmith"`, `strategy: "gradual rollout (percentage-based)"` (Flagsmith is open-source with a generous free tier; supports gradual rollouts and segment targeting without enterprise pricing)
- If `architecturalFraming.scaleTarget ∈ (startup)` → `provider: "Config file (env var + code)"`, `strategy: "kill switch only"` (greenfield opinion: env var feature flags are the right starting point for startups — zero cost, zero infra, sufficient for kill switches and staged rollouts via re-deploys)
- If `architecturalFraming.scaleTarget: "hobby"` → `provider: "None"`, `strategy: "none"` (hobby apps don't need feature flag infrastructure)
- Else → `provider: "Config file (env var + code)"`, `strategy: "kill switch only"` (greenfield opinion: start with env var flags; migrate to a real flag service when targeting rules or percentage rollouts are needed)

### Ops.Q10 — Maintenance mode and graceful degradation

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `isProduction: true` — **SKIP for non-production / local-only projects; default both fields to `"none"`**
- **R3-updates-path:** `context.phases.runtimeOperations.maintenanceMode`

**Prompt:** "How will you handle maintenance mode and graceful degradation?"

**Stores to:** `runtimeOperations.maintenanceMode` (object)

**Sub-questions:**
- `maintenanceMode` (single-select): `"platform toggle (Vercel maintenance mode, etc.)"` | `"upstream flag in DB/KV"` | `"none"`
- `degradationStrategy` (single-select): `"circuit breaker pattern"` | `"fallback responses (cached/static)"` | `"fail-open with logging"` | `"none"`

**Default:**
- If `architecturalFraming.topology: "microservices"` → `maintenanceMode: "upstream flag in DB/KV"`, `degradationStrategy: "circuit breaker pattern"` (greenfield opinion: microservices MUST implement circuit breakers — a slow upstream service will exhaust thread pools in downstream services without them; Resilience4j, Polly, and Hystrix provide battle-tested implementations)
- If `architecturalFraming.scaleTarget: "enterprise"` → `maintenanceMode: "upstream flag in DB/KV"`, `degradationStrategy: "circuit breaker pattern"` (enterprise apps require programmatic maintenance mode that can be toggled without a deploy; circuit breakers protect against cascading failures at scale)
- If `Q3.4.deployTarget ∈ (Vercel, Railway, Render)` → `maintenanceMode: "platform toggle (Vercel maintenance mode, etc.)"`, `degradationStrategy: "fallback responses (cached/static)"` (platform-native maintenance mode is the zero-config option; static fallback pages handle the UX gracefully)
- If `architecturalFraming.scaleTarget: "production-scale"` → `maintenanceMode: "upstream flag in DB/KV"`, `degradationStrategy: "fallback responses (cached/static)"` (greenfield opinion: DB/KV flag gives you maintenance mode without a deploy; cached fallbacks keep the app usable during partial outages)
- If `isProduction: false` → `maintenanceMode: "none"`, `degradationStrategy: "none"` (**skipped for non-production — not asked**; maintenance mode and degradation strategies are production concerns)
- Else → `maintenanceMode: "upstream flag in DB/KV"`, `degradationStrategy: "fail-open with logging"` (greenfield opinion: fail-open with logging is the safest default for unknown failure modes — it keeps the app available and surfaces degradation in logs for investigation)

### Ops.Q11 — Health check endpoints

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `apiIntegration.exposesAPI: true` — **SKIP if `apiIntegration.exposesAPI ≠ true`; default all fields to `false`**
- **R3-updates-path:** `context.phases.runtimeOperations.healthChecks`

**Prompt:** "What health check endpoints will you expose?"

**Stores to:** `runtimeOperations.healthChecks` (object)

**Sub-questions:**
- `liveness` (boolean): `/health/live` or equivalent (is the process running?)
- `readiness` (boolean): `/health/ready` (is the app ready to serve traffic? checks DB, cache, etc.)
- `deepHealth` (boolean): `/health/deep` (checks all downstream dependencies; not suitable for load balancer probes)

**Default:**
- If `architecturalFraming.topology: "microservices"` → `liveness: true`, `readiness: true`, `deepHealth: true` (greenfield opinion: Kubernetes requires liveness and readiness probes — without them, Kubernetes can't distinguish a healthy pod from a deadlocked one; deep health checks power dependency monitoring)
- If `architecturalFraming.topology ∈ (serverless)` → `liveness: false`, `readiness: false`, `deepHealth: true` (serverless functions don't support liveness/readiness probes; a deep health function can be triggered by uptime monitors)
- If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `liveness: true`, `readiness: true`, `deepHealth: false` (greenfield opinion: liveness + readiness is the minimum production health check suite — needed for load balancer routing and zero-downtime deploys; deep health adds overhead to the load balancer probe path)
- If `apiIntegration.exposesAPI: false` → `liveness: false`, `readiness: false`, `deepHealth: false` (**skipped — not asked**; health checks are only relevant for API services)
- Else → `liveness: true`, `readiness: false`, `deepHealth: false` (greenfield opinion: at minimum, expose a liveness endpoint — it's one route, costs nothing, and enables basic uptime monitoring from day one)

### Ops.Q12 — Runbook storage and management

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `architecturalFraming.scaleTarget ∉ (hobby)` — **AUTO-SKIP for `architecturalFraming.scaleTarget='hobby'`; default all fields to `"none"` without asking**
- **R3-updates-path:** `context.phases.runtimeOperations.runbooks`

**Prompt:** "How will you store and manage runbooks?"

**Stores to:** `runtimeOperations.runbooks` (object)

**Sub-questions:**
- `storagePath` (single-select): `"docs/runbooks/ (in repo)"` | `"Notion / Confluence (external)"` | `"PagerDuty runbooks"` | `"none"`
- `templateStyle` (single-select): `"markdown checklist (numbered steps)"` | `"decision-tree (condition → action)"` | `"none"`
- `ownership` (single-select): `"per-service (team owns)"` | `"central ops team"` | `"none"`

**Default:**
- If `architecturalFraming.scaleTarget: "hobby"` → `storagePath: "none"`, `templateStyle: "none"`, `ownership: "none"` (**auto-skipped — not asked**; runbooks are overhead for hobby apps)
- If `architecturalFraming.scaleTarget: "enterprise"` → `storagePath: "Notion / Confluence (external)"`, `templateStyle: "decision-tree (condition → action)"`, `ownership: "per-service (team owns)"` (enterprise ops teams often have centralized knowledge-base requirements; decision-tree runbooks scale better than checklists for complex multi-step resolutions)
- If `runtimeOperations.alerting.channel ∈ (PagerDuty, OpsGenie)` → `storagePath: "PagerDuty runbooks"`, `templateStyle: "markdown checklist (numbered steps)"`, `ownership: "per-service (team owns)"` (greenfield opinion: PagerDuty/OpsGenie runbook links surface directly in incident alerts — on-call engineers see the runbook the moment they get paged, reducing MTTR)
- If `architecturalFraming.scaleTarget ∈ (startup, production-scale)` → `storagePath: "docs/runbooks/ (in repo)"`, `templateStyle: "markdown checklist (numbered steps)"`, `ownership: "per-service (team owns)"` (greenfield opinion: in-repo runbooks are version-controlled alongside the code they describe — a runbook that diverges from the codebase is worse than no runbook)
- Else → `storagePath: "docs/runbooks/ (in repo)"`, `templateStyle: "markdown checklist (numbered steps)"`, `ownership: "per-service (team owns)"` (greenfield opinion: start with in-repo runbooks — they're immediately available, version-controlled, and editable alongside code changes)

### Ops.Q13 — Incident process

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.runtimeOperations.incidentProcess`

**Prompt:** "What incident process will you follow?"

**Stores to:** `runtimeOperations.incidentProcess` (object)

**Sub-questions:**
- `severityLevels` (single-select): `"3-tier (P1/P2/P3)"` | `"4-tier (SEV0-SEV3)"` | `"simple (critical / non-critical)"` | `"none"`
- `escalationChain` (free-text): e.g., `"solo developer — self-escalate"`, `"on-call engineer → tech lead → VP Eng"`
- `postmortemTemplate` (single-select): `"blameless postmortem (5-whys, action items)"` | `"lightweight (what happened, fix, prevention)"` | `"none"`

**Cross-link:** `security.ir` captures security-specific IR posture (breach notification SLA, GDPR obligations); `runtimeOperations.incidentProcess` covers operational severity and escalation — synthesis ensures these are consistent and non-overlapping.

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `severityLevels: "4-tier (SEV0-SEV3)"`, `escalationChain: "on-call engineer → tech lead → VP Eng"`, `postmortemTemplate: "blameless postmortem (5-whys, action items)"` (enterprise incidents require a formal severity taxonomy — SEV0/SEV1 determine communication SLAs and executive escalation; blameless postmortems are the industry standard for building a learning culture)
- If `architecturalFraming.scaleTarget: "production-scale"` → `severityLevels: "3-tier (P1/P2/P3)"`, `escalationChain: "on-call engineer → tech lead"`, `postmortemTemplate: "blameless postmortem (5-whys, action items)"` (greenfield opinion: 3-tier severity is simpler than 4-tier but still meaningful — P1 (site down), P2 (degraded), P3 (minor) maps directly to paging urgency)
- If `security.sensitivityTier: "high"` → `severityLevels: "3-tier (P1/P2/P3)"`, `postmortemTemplate: "blameless postmortem (5-whys, action items)"` (high-sensitivity apps require documented postmortems as compliance artifacts — SOC 2 auditors ask for incident records)
- If `architecturalFraming.scaleTarget: "hobby"` → `severityLevels: "none"`, `escalationChain: "solo developer — self-escalate"`, `postmortemTemplate: "none"` (hobby apps don't need formal incident process; investigate and fix)
- If `architecturalFraming.scaleTarget: "startup"` → `severityLevels: "simple (critical / non-critical)"`, `escalationChain: "solo developer — self-escalate"`, `postmortemTemplate: "lightweight (what happened, fix, prevention)"` (greenfield opinion: a lightweight postmortem forces the 10-minute retrospective that prevents the same incident from recurring — the most high-ROI ops investment for a solo/startup team)
- Else → `severityLevels: "simple (critical / non-critical)"`, `escalationChain: "solo developer — self-escalate"`, `postmortemTemplate: "lightweight (what happened, fix, prevention)"` (greenfield opinion: even a simple two-tier severity + lightweight postmortem provides 80% of the incident management value at 10% of the process overhead)

### Ops.Q14 — On-call rotation system

- **type:** single-select
- **options:** ["PagerDuty", "OpsGenie", "Discord bot (manual rotation)", "None"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `architecturalFraming.scaleTarget ∉ (hobby, startup)` — **AUTO-SKIP for `architecturalFraming.scaleTarget ∈ (hobby, startup)`; default to `"None"` without asking**
- **R3-updates-path:** `context.phases.runtimeOperations.onCall`

**Prompt:** "What on-call rotation system will you use?"

**Stores to:** `runtimeOperations.onCall`

**Default:**
- If `architecturalFraming.scaleTarget ∈ (hobby, startup)` → `"None"` (**auto-skipped — not asked**; solo/startup developers don't need formal on-call rotation tooling)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"PagerDuty"` (greenfield opinion: PagerDuty is the enterprise standard for on-call rotation — escalation policies, override scheduling, and audit logs are required for formal incident management at enterprise scale)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `runtimeOperations.alerting.channel: "PagerDuty"` → `"PagerDuty"` (when PagerDuty is already the alert channel, extend it to on-call rotation — single pane of glass for incidents)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `runtimeOperations.alerting.channel: "OpsGenie"` → `"OpsGenie"` (consistent with alerting choice — avoid operating two separate on-call systems)
- If `architecturalFraming.scaleTarget: "production-scale"` → `"PagerDuty"` (greenfield opinion: formal on-call tooling prevents alert fatigue and missed pages when team size grows beyond solo — PagerDuty's escalation policies are the right foundation)
- Else → `"None"` (greenfield opinion: add on-call rotation infrastructure when the team is large enough to share the pager; premature rotation tooling creates overhead without benefit)

**After Ops.Q14**, invoke synthesis-review inline:

> Invoke `Skill(synthesis-review, phaseId: "runtimeOperations")` — renders `docs/adr/runtime-operations.html` and walks the developer through approve/adjust/skip.

---

### Ops.Q_RISK — Runtime operations risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["ops", "scaling", "team"]

**Prompt:** "What's the biggest runtime operations risk for THIS project? (e.g., 'no on-call rotation defined for first month', 'feature flags without kill-switch', 'no runbook for the noisiest alert path'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "runtimeOperations"`, id auto-assigned `R-RUNTIMEOPERATIONS-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Ops.Q1 | ✓ | ✓ | Background job gate — foundational; gates Q2 (retry) and Q3 (scheduling) |
| Ops.Q2 | ✓ | ✓ | Retry/idempotency basics — foundational; skipped when jobs = None |
| Ops.Q3 | ✓ | ✓ | Scheduling basics — foundational |
| Ops.Q4 | ✓ | ✓ | Observability strategy (metrics/uptime) — foundational |
| Ops.Q5 | ✓ | — | Distributed tracing + error tracking — depth; auto-skip for hobby/startup monolith |
| Ops.Q6 | ✓ | — | Log aggregation tools — depth; uses defaults in light |
| Ops.Q7 | ✓ | ✓ | Alert routing — foundational; `loopMode: hybrid-only` over `personas.primary` |
| Ops.Q8 | ✓ | ✓ | SLO targets — foundational; `loopMode: hybrid-only` over `personas.primary`; auto-skip for hobby/startup |
| Ops.Q9 | ✓ | — | Feature flag platform specifics — depth; uses defaults in light |
| Ops.Q10 | ✓ | — | Maintenance mode / degradation detail — depth; skipped for non-production |
| Ops.Q11 | ✓ | — | Health check endpoint detail — depth; skipped if no API |
| Ops.Q12 | ✓ | — | Runbook detail — depth; auto-skip for hobby |
| Ops.Q13 | ✓ | ✓ | Incident process basics — foundational |
| Ops.Q14 | ✓ | — | On-call rotation — depth; auto-skip for hobby/startup |
| Ops.Q_RISK | ✓ | ✓ | Always fires |
