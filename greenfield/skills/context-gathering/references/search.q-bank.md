# Search Q-bank — Step 7

> **Round:** 6 (Concern phase — between Data Architecture and API Integration)
> **Steps:** 7 (after dataArchitecture at Step 6, before apiIntegration at Step 8)
> **Modes:** Heavy ~11 Qs / Light ~6 Qs (drops S.Q5/S.Q6/S.Q8/S.Q10/S.Q11)
> **Coupling:** Reads `dataArchitecture.entities[]`. Writes `phases.search.*`. Output drives `lib/search.ts` + (Postgres FTS) `prisma/migrations/0002_search_indexes.sql`.
> **See also:** `data-architecture.q-bank.md`, design spec § Phase content / Q-bank shape

## Q-bank

### S.Q1 — Search type
- **type:** single-select
- **options:** ["fts", "vector", "hybrid", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Does the app need search? (FTS = keyword; vector = semantic; hybrid = both; none = skip the phase.)"
- **Stores to:** `phases.search.searchType`

### S.Q2 — Engine
- **type:** single-select
- **options:** ["postgres-fts", "meilisearch", "typesense", "elasticsearch", "opensearch", "pgvector", "pinecone", "weaviate", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which engine? (postgres-fts requires no new infra; meilisearch/typesense are managed; pgvector for hybrid stays in Postgres.)"
- **Stores to:** `phases.search.engine`

### S.Q3 — Index scope
- **type:** multi-select (dynamic from `dataArchitecture.entities[].id`)
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which entities are indexed?"
- **Stores to:** `phases.search.indexScope[]`

### S.Q4 — Update strategy
- **type:** single-select
- **options:** ["realtime", "batch", "hybrid"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Index update strategy? (realtime = write-through; batch = cron job; hybrid = critical-realtime + bulk-batch.)"
- **Stores to:** `phases.search.updateStrategy`

### S.Q5 — Query patterns
- **type:** multi-select
- **options:** ["filters", "facets", "autocomplete", "semantic", "ranking", "spelling"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Query patterns supported?"
- **Stores to:** `phases.search.queryPatterns[]`

### S.Q6 — Ranking
- **type:** long-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Ranking signals? (recency, popularity, custom score? — one paragraph.)"
- **Stores to:** `phases.search.ranking`

### S.Q7 — A/B testing
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "A/B test ranking strategies in production?"
- **Stores to:** `phases.search.abTesting`

### S.Q8 — RLS
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Search results respect row-level security?"
- **Stores to:** `phases.search.security.rls`

### S.Q9 — Query auth
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Search queries require authenticated user?"
- **Stores to:** `phases.search.security.queryAuth`

### S.Q10 — Index refresh interval
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "If batch: refresh interval? (e.g., 'every 5 min', 'nightly')"
- **Stores to:** `phases.search.refreshInterval` (free-form)

### S.Q_RISK — Search risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Prompt:** "Search-related risks? (e.g., 'index drift between source-of-truth and search index', 'vector embedding cost spikes')"
- **Stores to:** `phases.search.qRisks[]` + appends to top-level `risks[]` with `phase: "search"`
