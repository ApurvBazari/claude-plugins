# Round 3 — Stack-Derived Default Rules for All 50 Qs

Single-source catalog. Each row lists the Q, its consumed upstream signals, and the produced default rule summary. Source of truth: `greenfield/skills/context-gathering/references/question-bank.md`.

## Auth (12 Qs)

| Q | Consumed signals | Default summary |
|---|---|---|
| Auth.Q1 | framework, deployTarget, scaleTarget | Next+Vercel→Clerk; Django/Rails→built-in; FastAPI+production→Auth0; hobby→none; fallback→Clerk |
| Auth.Q2 | strategy, deployTarget, mobile | minimal=[email+pw]; mobile target adds Apple+Google |
| Auth.Q3 | framework, topology, deployTarget | framework-default (cookie for monolith; JWT+refresh for microservices/serverless) |
| Auth.Q4 | compliance, scaleTarget, sensitivityTier | compliance non-empty → required+TOTP+passkeys; enterprise → required; else → optional |
| Auth.Q5 | engine, multiTenancy, scaleTarget | engine=postgres+multiTenancy=rls → db-rls; else RBAC; hobby → flat-roles |
| Auth.Q6 | multiTenancy | rls → claim; schema-per-tenant → subdomain; SKIP if none |
| Auth.Q7 | topology | microservices → signed-jwt; SKIP if monolith |
| Auth.Q8 | strategy, scaleTarget | hosted → provider-managed; built-in → framework-style; production → email-verify required |
| Auth.Q9 | strategy, scaleTarget | hosted → email-only; built-in+production → email+recovery-codes |
| Auth.Q10 | idps, strategy, compliance | passkey-only if all WebAuthn; HIPAA → 12 char + complexity + HIBP; SKIP if no password IdP |
| Auth.Q11 | compliance, scaleTarget | HIPAA → 7y retention; SOC2 → 1y+aggregator; PCI → 1y+separate DB; hobby → console only |
| Auth.Q12 | apiIntegration.style, topology | REST → middleware; GraphQL → directives; microservices → gateway+middleware |

## Privacy (11 Qs + Gate)

| Q | Consumed signals | Default summary |
|---|---|---|
| Privacy.Gate | auth.strategy | fires only if strategy='none'; default Yes (greenfield opinion) |
| Privacy.Q1 | compliance, externalServices, scaleTarget | pre-fill from compliance; enterprise → [GDPR, CCPA]; EU service detected → +GDPR |
| Privacy.Q2 | auth.idps, externalServices, lifecycle | from idps + processors |
| Privacy.Q3 | regulations | SKIP if no GDPR; mapping: Email→Contract, Behavioral→Consent, Health→Consent |
| Privacy.Q4 | regulations, piiCategories | HIPAA → 6y; GDPR → 2y for billing; fallback 12mo |
| Privacy.Q5 | scaleTarget, regulations | production-scale+ → soft-delete+anonymize; hobby → hard-delete |
| Privacy.Q6 | piiCategories, externalServices | SKIP if no analytics+marketing; banner+granular(essential/analytics/marketing) |
| Privacy.Q7 | regulations | SKIP if no GDPR+CCPA; format=JSON; SLA=30d GDPR / 45d CCPA |
| Privacy.Q8 | externalServices | pre-fill from all PII-touching services |
| Privacy.Q9 | regulations, piiCategories | GDPR → [anonymize-analytics, IP-truncate]; else [] |
| Privacy.Q10 | regulations, deployTarget | residency=deployTarget region; GDPR → SCC; else none |
| Privacy.Q11 | regulations, piiCategories | HIPAA → [read,update,delete,export] @ 6y; else [] |

## Security (13 Qs)

| Q | Consumed signals | Default summary |
|---|---|---|
| Sec.Q1 | compliance, externalServices, piiCategories, scaleTarget | compliance non-empty → LOCKED High; payments → Elevated; piiCategories non-empty → Elevated; enterprise → Elevated; else Standard |
| Sec.Q2 | deployTarget, scaleTarget, sensitivityTier | Vercel/AWS → platform-managed; Vault if sensitivityTier≠standard; rotation: quarterly High, annual else |
| Sec.Q3 | sensitivityTier, externalServices | Standard → [deps]; Elevated → [+SAST]; High → [+DAST,container]; cadence: weekly |
| Sec.Q4 | sensitivityTier | Standard → none; Elevated → STRIDE-lite; High → Formal |
| Sec.Q5 | sensitivityTier, piiCategories | Standard → DB-default; Elevated+PII → +per-column; High → +app-managed |
| Sec.Q6 | topology, sensitivityTier | TLS always; microservices → mTLS; Elevated+ → HSTS preload |
| Sec.Q7 | apiIntegration.style, sensitivityTier | CORS=allowlist; CSP=strict for Elevated+; X-Frame-Options=DENY |
| Sec.Q8 | language, apiIntegration.style | boundaries-only; TS → Zod; Python → pydantic; framework-native fallback |
| Sec.Q9 | compliance, sensitivityTier | SKIP for Standard; HIPAA → 6y+hash-chain; PCI → 7y; else 1y |
| Sec.Q10 | sensitivityTier | runbookStyle=md; SLA: High=1h, Elevated=4h, Standard=24h |
| Sec.Q11 | scaleTarget, sensitivityTier | AUTO-SKIP for hobby+Standard; Elevated→annual; High→quarterly |
| Sec.Q12 | scaleTarget, sensitivityTier | AUTO-SKIP for hobby; Elevated→none; High→private |
| Sec.Q13 | sensitivityTier, compliance | always lockfile; Elevated+ → signed-commits; High → +SBOM; SOC2 → +provenance |

## Runtime Operations (14 Qs)

| Q | Consumed signals | Default summary |
|---|---|---|
| Ops.Q1 | asyncPattern, framework, deployTarget, scaleTarget | SKIP if asyncPattern=none; Next+Vercel→Inngest; Ruby→Sidekiq; Python→Celery; AWS→SQS; hobby→none |
| Ops.Q2 | jobs | SKIP if none; at-least-once+exp-backoff-3x+DLQ |
| Ops.Q3 | deployTarget, topology | Vercel→VercelCron; k8s→CronJob; AWS→EventBridge; else GH Actions cron |
| Ops.Q4 | scaleTarget, deployTarget | hobby/startup→platform-native; enterprise→DataDog; production+self-host→Prometheus+Grafana |
| Ops.Q5 | topology, scaleTarget | SKIP unless microservices OR production-scale+; enterprise→DataDog APM; production→Honeycomb |
| Ops.Q6 | deployTarget, scaleTarget | Vercel→platform; AWS→CloudWatch; k8s→Loki; retention 30d hobby, 1y production+ |
| Ops.Q7 | sensitivityTier, scaleTarget | High → forced ≠ none (Slack minimum); enterprise→PagerDuty; startup+ →Slack webhook |
| Ops.Q8 | scaleTarget | SKIP if not production-scale+; metrics=[availability, latencyP99, error-rate]; budget 99.9%/99.95% |
| Ops.Q9 | scaleTarget | hobby→config-file; startup→PostHog; enterprise→LaunchDarkly |
| Ops.Q10 | isProduction | SKIP if not production; DB-flag+branded-page |
| Ops.Q11 | apiIntegration.exposesAPI, deploymentShape | SKIP if no API; k8s→all three probes; serverless→liveness only |
| Ops.Q12 | scaleTarget | SKIP for hobby; docs/runbooks/+incident-checklist-md |
| Ops.Q13 | isProduction, scaleTarget | SKIP if hobby; SEV1/SEV2/SEV3+escalation+postmortem |
| Ops.Q14 | scaleTarget, sensitivityTier | AUTO-SKIP for hobby+startup; enterprise→PagerDuty; AWS→OpsGenie |

---

**Total: 50 Qs across 4 phases** (12 + 12 + 13 + 14 — note Privacy includes 11 Qs + 1 Gate).

**Maintenance:** When Q-bank entries are edited, update this catalog in the same commit. The catalog is the cross-Q audit view; question-bank.md remains the per-Q source of truth.
