# Caching Q-bank — Step 9

> **Round:** 6 (Concern phase — after API Integration)
> **Steps:** 9 (after apiIntegration at Step 8, before realtime at Step 10)
> **Modes:** Heavy ~12 Qs / Light ~7 Qs
> **Coupling:** Reads `architecturalFraming.frontendFramework`, `dataArchitecture.engine`. Writes `phases.caching.*`. Drives `lib/cache.ts` + framework-conditional CDN headers.
> **See also:** `data-architecture.q-bank.md`, `api-integration.q-bank.md`

## Q-bank

### C.Q1 — Caching layers
- **type:** multi-select
- **options:** ["cdn", "edge", "app", "db-query", "browser"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which caching layers? (cdn = edge POPs; edge = compute-near-user; app = in-process LRU; db-query = query result cache; browser = HTTP cache headers.)"
- **Stores to:** `phases.caching.layers[]`

### C.Q2 — CDN provider
- **type:** single-select
- **options:** ["cloudflare", "fastly", "vercel-edge", "cloudfront", "akamai", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "CDN provider? (Cloudflare/Fastly/Vercel-Edge are managed; CloudFront is AWS-native; Akamai is enterprise; none = no CDN.)"
- **Stores to:** `phases.caching.cdnProvider`

### C.Q3 — Invalidation strategy
- **type:** single-select
- **options:** ["ttl", "tag-based", "manual", "hybrid"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Cache invalidation strategy? (ttl = time-bound; tag-based = surgical purge; manual = explicit; hybrid = ttl + tag.)"
- **Stores to:** `phases.caching.invalidationStrategy`

### C.Q4 — Stale-while-revalidate
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Use stale-while-revalidate? (serve stale while refreshing in background — reduces user-visible latency.)"
- **Stores to:** `phases.caching.staleWhileRevalidate`

### C.Q5 — Key design
- **type:** long-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Cache key design? (one paragraph: per-user / per-tenant / global; collision avoidance; key length budget.)"
- **Stores to:** `phases.caching.keyDesign`

### C.Q6 — Multi-tenant isolation
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Multi-tenant cache isolation? (separate namespaces per tenant or shared with key prefixes.)"
- **Stores to:** `phases.caching.multiTenantIsolation`

### C.Q7 — Hit-rate observability
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Track hit rates? (instrument cache hit/miss for each layer.)"
- **Stores to:** `phases.caching.observability.hitRates`

### C.Q8 — Alert on hit-rate drop
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Alert on hit-rate drop? (paging on cache-effectiveness regression.)"
- **Stores to:** `phases.caching.observability.alertOnDrop`

### C.Q9 — Stampede protection
- **type:** single-select
- **options:** ["lock", "request-coalescing", "swr", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Stampede protection? (lock = single-flight; request-coalescing = dedupe in-flight; swr = stale-while-revalidate; none = accept thundering herd.)"
- **Stores to:** `phases.caching.stampedeProtection`

### C.Q10 — Default TTL
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Default TTL? (e.g., '60s', '5m', '1h' — applied when no per-key TTL is set.)"
- **Stores to:** `phases.caching.defaultTtl` (free-form — flag the schema gap)

### C.Q11 — Warmup on deploy
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Warm cache on deploy? (pre-fetch frequently-accessed keys to avoid cold-start cliff.)"
- **Stores to:** `phases.caching.warmupOnDeploy` (free-form — flag the schema gap)

### C.Q_RISK — Caching risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Prompt:** "Caching risks? (e.g., 'stale data leak between tenants', 'cache stampede on deploy', 'invalidation drift across regions')"
- **Stores to:** `phases.caching.qRisks[]` + appends to top-level `risks[]` with `phase: "caching"`
