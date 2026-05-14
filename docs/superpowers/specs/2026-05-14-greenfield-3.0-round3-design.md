# Greenfield 3.0 Round 3 — Auth + Privacy + Security + Runtime Operations Design

- **Branch:** `feat/greenfield-1.2`
- **Date:** 2026-05-14
- **Inherits from:** Rounds 1+2+2.5 (shipped at `greenfield@3.0.0-alpha.3` / `onboard@2.0.0-alpha.3`); `project_greenfield_3_0_design.md` memory entry; ROUND 2.5 LOCKED Discussion Log entry
- **Estimated files touched:** ~40 unique files (~24 new + ~15 modified) across `greenfield/`, `onboard/`, root marketplace, and root CLAUDE.md
- **Target versions on completion:** `greenfield@3.0.0-alpha.4`, `onboard@2.0.0-alpha.4`

## Summary

Round 3 inserts four new wizard phases — **Auth**, **Privacy**, **Security**, **Runtime Operations** — between the existing Step 4 (API & Integration) and Step 5 (Cat 3 residual). It is the first round to *split* the original P6 (Auth/Security/Privacy) ladder rung into three independent phases — each with its own synthesis review, dependency sidecar, and stale-flag domain. P7 (originally "Workflow expansion" in the locked plan) is realized as a single **Runtime Operations** phase covering background jobs, observability, alerting, feature flags, and incident process.

Round 3 is heavy on content authoring but light on infrastructure work: every cross-cutting mechanism it relies on (topic naming, stale-flag traversal, MD+HTML companions, `docs/adr/` output, stack-derived defaults, adjust-dialog, hard schema cutover) was built in Round 2.5. The round's job is to define 50 new questions, 4 synthesis template pairs, 4 dependency sidecars, and the schema sections that make all of this addressable.

Five residual questions migrate from Cat 3 / Cat 4 into the new phases. The wizard grows from 11 steps to 15 steps. Schema bumps `alpha.3 → alpha.4`; in-flight `alpha.3` sessions break per the hard-cutover policy.

## Scope

**In scope (Round 3 deliverables):**

1. Author **Auth** phase (12 Qs) — strategy, IdPs, session model, MFA, authz, tenant resolution, service-to-service auth, lifecycle, recovery, password policy, audit log, enforcement point
2. Author **Privacy** phase (11 Qs) — regulatory scope, PII inventory, lawful basis, retention, deletion flow, consent management, DSAR, processors, minimization, data residency, PII access audit
3. Author **Security** phase (13 Qs) — sensitivity tier, secret mgmt, vuln scanning, threat model, encryption at rest/in transit, security headers, input validation, audit retention, IR, pentest cadence, VDP, supply chain
4. Author **Runtime Operations** phase (14 Qs) — jobs, retry/idempotency, scheduling, metrics, traces, logs, alerting, SLO, feature flags, maintenance mode, health checks, runbooks, incident process, on-call
5. 4 synthesis template HTML+MD pairs in `greenfield/skills/synthesis-review/references/templates/`
6. 4 `<topic>-dependencies.json.example` sidecars
7. Schema additions in `onboard/skills/generate/references/context-shape-v2.json` for `auth`, `privacy`, `security`, `runtimeOperations`
8. Migration of `Q3.3` (auth), `Q3.6` (monitoring), `Q3.9` (secrets), `Q4.5` (security sensitivity) out of Cat 3/Cat 4 residual; reduction of `P4.Q7` (async bg jobs) to a 1-line pointer
9. State-machine extensions in `context-gathering/SKILL.md` for 4 new steps
10. 4 new cross-phase consistency checks in `grill-spec/SKILL.md` (compliance scope, sensitivity tier, alerting requirement, auth+privacy coherence)
11. 4 new skip-cascade rules driven by `auth.strategy`, `architecturalFraming.scaleTarget`, `apiIntegration.asyncPattern`, `dataArchitecture.compliance`
12. Wizard step renumbering (11 → 15); update `start/pickup/check` skill SKILL.md files
13. Architecture diagram updates in `greenfield/CLAUDE.md` and `onboard/CLAUDE.md`
14. ROUND 3 LOCKED entry in `docs/greenfield-overview.html` Discussion Log
15. Stack-derived default rules for all 50 new Qs in `defaults-derivation.md`
16. Version bumps: `greenfield@3.0.0-alpha.4`, `onboard@2.0.0-alpha.4`, mirrored in `marketplace.json`
17. CHANGELOG entry calling out the alpha.3 → alpha.4 schema break

**Out of scope (do NOT relitigate — locked elsewhere):**

- Frontend phase (P5) — Round 6
- Personas (P0.5), Domain Modeling (P1), Risk ID (P8.5) — Round 4
- Feature Roadmap (P9), Schema & API Draft Review (P10.5) — Round 5
- 12 never-asked concern areas — Round 6
- Non-GHA CI provider templates — Round 6
- State JSON migration framework — post-GA per Decision 8
- Splitting Cat 3 residual or Cat 4 dev-workflow into formal phases with synthesis — Round 6+
- Replacement for any mattpocock-skills (removed in Round 2.5 PRE-3)
- New Architectural Framing questions — `dataArchitecture.compliance` already feeds the new phases adequately

## Locked design decisions

These 5 decisions came out of the 2026-05-14 brainstorming session. They drive every Round 3 deliverable.

| # | Item | Decision |
|---|---|---|
| 1 | P6 shape | **Three separate phases** (Auth + Privacy + Security), each with own synthesis, dependency sidecar, schema section, and stale-flag domain. Maximum granularity — devs can Adjust auth without re-walking privacy. |
| 2 | P7 scope | **Runtime Operations only** — jobs, observability, alerting, feature flags, runbooks, incident process. Cat 4 dev workflow (branching, testing, releases, verification) stays where it is. |
| 3 | Phase depth | **Heavy** — 11-14 Qs per phase, ~50 Qs total. Aligns with "time is not a constraint; surprises in scaffold are the primary failure mode." |
| 4 | Internal ordering | **Auth → Privacy → Security → Runtime Operations.** Each consumes only earlier-phase outputs. Auth defines the user model, Privacy classifies the data, Security inherits classification + threat surface, Runtime Ops layers service-to-service auth + observability on top. |
| 5 | Topic names | `auth` / `privacy` / `security` / `runtimeOperations`. Synthesis files: `auth.html/.md`, `privacy.html/.md`, `security.html/.md`, `runtime-operations.html/.md`. Step labels: "Auth", "Privacy", "Security", "Runtime Operations". |

Plus migration map (Decision 5 secondary):

- `Q3.3` (auth) → `Auth.Q1` (expanded to 12 Qs)
- `Q3.6` (monitoring) → split across `Ops.Q4` (metrics + uptime), `Ops.Q5` (traces + error tracking), `Ops.Q6` (logs). Product analytics part of original Q3.6 defers to Round 6 (frontend) where it belongs.
- `Q3.9` (env vars / secrets) → `Sec.Q2` (expanded with rotation cadence)
- `Q4.5` (security sensitivity) → `Sec.Q1` (expanded with tiers)
- `P4.Q7` (async bg jobs) → pointer Q; full detail in `Ops.Q1-Q3`

## Architecture & data flow (post-Round-3)

```
/greenfield:start
     │
     ▼
Phase 1: Context Gathering
     │
     ├── Step 1 of 15:    Vision
     ├── Step 2 of 15:    Stack
     ├── Step 2.5 of 15:  Architectural Framing
     ├── Step 3 of 15:    Data Architecture
     ├── Step 4 of 15:    API & Integration
     │
     ├── Step 5 of 15:    Auth                                ─── ★ NEW
     │       ├── Q1-Q12 (12 Qs)
     │       └── synthesis-review(phaseId: "auth")
     │              └── outputs:
     │                    docs/adr/auth.md
     │                    docs/adr/auth.html
     │                    docs/adr/auth-dependencies.json
     │
     ├── Step 6 of 15:    Privacy                             ─── ★ NEW
     │       ├── Q1-Q11 (11 Qs)
     │       ├── skip-cascade gate: if auth.strategy=None AND no-data-collected
     │       │   → synthesisStatus: "n/a" stub
     │       └── synthesis-review(phaseId: "privacy")
     │              └── outputs:
     │                    docs/adr/privacy.md
     │                    docs/adr/privacy.html
     │                    docs/adr/privacy-dependencies.json
     │
     ├── Step 7 of 15:    Security                            ─── ★ NEW
     │       ├── Q1-Q13 (13 Qs)
     │       └── synthesis-review(phaseId: "security")
     │              └── outputs:
     │                    docs/adr/security.md
     │                    docs/adr/security.html
     │                    docs/adr/security-dependencies.json
     │
     ├── Step 8 of 15:    Runtime Operations                  ─── ★ NEW
     │       ├── Q1-Q14 (14 Qs)
     │       └── synthesis-review(phaseId: "runtimeOperations")
     │              └── outputs:
     │                    docs/adr/runtime-operations.md
     │                    docs/adr/runtime-operations.html
     │                    docs/adr/runtime-operations-dependencies.json
     │
     ├── Step 9 of 15:    Cat 3 residual (10 Qs, slimmed) — was Step 5
     ├── Step 9.5 of 15:  Pain Points (always ask) — was Step 5.5
     ├── Step 10 of 15:   Cat 4 Workflow (6 Qs, slimmed) — was Step 6
     ├── Step 11 of 15:   CI/CD & Delivery — was Step 7
     ├── Step 12 of 15:   Feature Decomposition (Harness Preparation) — was Step 8
     ├── Step 13 of 15:   Confirmation — was Step 9
     ├── Step 14 of 15:   Phase 1.5 Architectural Research (conditional) — was Step 10
     └── Step 15 of 15:   Architectural Validation — was Step 11
```

**Dependency chain** (left-to-right; phase N may only reference outputs from phases 1..N-1):

```
architecturalFraming ─┬─► dataArchitecture ─┬─► apiIntegration ─┬─► auth ─► privacy ─► security ─► runtimeOperations
                      │                     │                   │                                  ▲
                      └─────────────────────┴───────────────────┴──────────────────────────────────┘
                                                       (runtimeOperations also reads framing/data/api directly)
```

## Per-phase Q outlines

Stack-derived defaults per Round 2.5 PRE-6 pattern. Heavy depth produces ~50 Qs total; with defaults + skip cascades, the developer answers ~30-40 explicitly.

### Step 5 — Auth (12 Qs)

| # | Question | Drives | Notes |
|---|---|---|---|
| Auth.Q1 | **Strategy** (supersedes Q3.3): None / Hosted (Clerk, Auth0, Supabase Auth, Firebase Auth, Cognito) / Self-hosted OSS (Keycloak, Authentik, Ory) / Built-in (framework session/JWT) | `auth.strategy`, downstream skips | Default stack-derived; gates the rest of the phase |
| Auth.Q2 | **Identity providers**: email+pw, Google, GitHub, Apple, SAML SSO, magic links, passkeys/WebAuthn | `auth.idps[]` | Multi-select; mobile targets add Apple+Google by default |
| Auth.Q3 | **Session model**: cookie / JWT / hybrid; refresh token strategy | `auth.sessionModel` | Default by framework + topology |
| Auth.Q4 | **MFA**: required / optional / not yet; TOTP / SMS / passkeys | `auth.mfa` | Tier-locked High if `compliance` non-empty |
| Auth.Q5 | **Authorization model**: flat roles / RBAC / ABAC / DB-level RLS | `auth.authzModel` | RLS option gated by `dataArchitecture.engine` |
| Auth.Q6 | **Tenant resolution** (conditional `dataArchitecture.multiTenancy ≠ none`): subdomain / path / claim / header | `auth.tenantResolution` | Skipped if not multi-tenant |
| Auth.Q7 | **Service-to-service auth** (conditional `architecturalFraming.topology = microservices`): API keys / mTLS / signed JWTs | `auth.serviceAuth` | Skipped for monolith |
| Auth.Q8 | **Account lifecycle**: signup flow, email verification, password reset, account deletion | `auth.lifecycle` | Sub-object Q |
| Auth.Q9 | **Account recovery**: email-only / phone / recovery codes / SSO-mediated | `auth.recovery` | |
| Auth.Q10 | **Password policy**: length, complexity, breach check (HIBP), or passkey-only | `auth.passwordPolicy` | Skipped if no password IdP selected |
| Auth.Q11 | **Auth audit log**: events captured, retention window | `auth.auditLog` | Default retention by compliance tier |
| Auth.Q12 | **Enforcement point**: middleware / route guards / DB RLS / API gateway | `auth.enforcementPoint[]` | Multi-select |

### Step 6 — Privacy (11 Qs)

| # | Question | Drives | Notes |
|---|---|---|---|
| Privacy.Q1 | **Regulatory scope**: GDPR, CCPA, LGPD, PIPEDA, HIPAA, none | `privacy.regulations[]` | Pre-filled from `dataArchitecture.compliance`; user can extend |
| Privacy.Q2 | **PII inventory**: email, name, address, phone, location, payment, health, biometric, behavioral | `privacy.piiCategories[]` | Multi-select |
| Privacy.Q3 | **Lawful basis** (per category): consent / contract / legitimate interest / vital interest | `privacy.lawfulBasis` | Required only if GDPR/UK-GDPR in scope |
| Privacy.Q4 | **Retention policy**: per-category retention windows | `privacy.retention` | Default by category × compliance |
| Privacy.Q5 | **Right-to-erasure flow**: hard delete / soft delete + anonymize / deletion request workflow | `privacy.deletionFlow` | |
| Privacy.Q6 | **Consent management**: banner needed?, granular categories (essential/analytics/marketing), storage mechanism | `privacy.consentManager` | Skipped if no analytics + no marketing |
| Privacy.Q7 | **DSAR / data export**: flow, format (JSON/CSV), SLA | `privacy.dsar` | Required if GDPR/CCPA |
| Privacy.Q8 | **Third-party PII sharing** (cross-ref `apiIntegration.externalServices`): processors list, DPA tracking expectation | `privacy.processors[]` | Pre-filled from external services list |
| Privacy.Q9 | **Data minimization**: anonymization in analytics, IP truncation | `privacy.minimization` | |
| Privacy.Q10 | **Cross-border transfer**: residency, transfer mechanisms (SCC, adequacy) | `privacy.dataResidency` | |
| Privacy.Q11 | **PII access audit log**: who/when/what | `privacy.accessAudit` | Mandatory if HIPAA |

Skip-cascade: if `auth.strategy = None` AND user confirms "no data collected" via single gate Q, Q2-Q11 collapse → `synthesisStatus: "n/a"` stub.

### Step 7 — Security (13 Qs)

| # | Question | Drives | Notes |
|---|---|---|---|
| Sec.Q1 | **Sensitivity tier** (supersedes Q4.5): Standard / Elevated (PII/payments) / High (SOC2/HIPAA/PCI/ISO27001) | `security.sensitivityTier` | Locked to High if `compliance` non-empty |
| Sec.Q2 | **Secret management** (supersedes Q3.9): .env / platform-managed / Vault-Doppler / cloud KMS; rotation cadence | `security.secrets` | |
| Sec.Q3 | **Vulnerability scanning**: deps (Dependabot/Snyk), SAST (Semgrep/CodeQL), DAST (ZAP), container scan; cadence | `security.scanning` | Multi-select |
| Sec.Q4 | **Threat model approach**: STRIDE-lite checklist / formal session / none | `security.threatModel` | |
| Sec.Q5 | **Encryption at rest**: DB-default / per-column for PII / app-managed | `security.encryptionAtRest` | |
| Sec.Q6 | **Encryption in transit**: TLS everywhere / mTLS for s2s / HSTS posture | `security.encryptionInTransit` | mTLS auto-suggested if microservices |
| Sec.Q7 | **Security headers**: CORS, CSP, X-Frame-Options defaults | `security.headers` | |
| Sec.Q8 | **Input validation policy**: boundaries-only / everywhere; library choice | `security.inputValidation` | |
| Sec.Q9 | **Audit log retention**: window, tamper-evidence (hash chain, write-once storage) | `security.auditRetention` | Required if compliance tier ≠ Standard |
| Sec.Q10 | **Incident response**: runbook style, notification SLA (cross-ref `runtimeOperations.incidentProcess`) | `security.ir` | Pointer; full detail in Ops |
| Sec.Q11 | **Pentest / audit cadence** (conditional `scaleTarget ∈ {production-scale, enterprise}` OR `sensitivityTier ≠ Standard`): annual / quarterly / continuous | `security.pentestCadence` | Auto-skipped for hobby tier |
| Sec.Q12 | **Bug bounty / VDP**: public, private, none | `security.vdp` | Auto-skipped for hobby |
| Sec.Q13 | **Supply-chain posture**: lockfile pinning, signed commits, SBOM generation, provenance attestation | `security.supplyChain` | |

Note: rate limiting is captured in `apiIntegration.rateLimit` (P4.Q5) — not duplicated here.

### Step 8 — Runtime Operations (14 Qs)

| # | Question | Drives | Notes |
|---|---|---|---|
| Ops.Q1 | **Background job system** (supersedes P4.Q7 detail): Redis/BullMQ, Sidekiq, Celery, SQS, Cloud Tasks, Inngest, Temporal, none | `runtimeOperations.jobs` | Skipped if `apiIntegration.asyncPatternPattern = none` |
| Ops.Q2 | **Retry / idempotency**: at-least-once vs exactly-once, retry policy, dead-letter queue | `runtimeOperations.retryStrategy` | |
| Ops.Q3 | **Scheduled tasks**: distributed scheduler / platform cron (Vercel Cron, GH Actions, k8s CronJob) | `runtimeOperations.scheduling` | |
| Ops.Q4 | **Metrics**: Prometheus / DataDog / Grafana Cloud / platform-native / none | `runtimeOperations.metrics` | |
| Ops.Q5 | **Traces**: OTel + backend (Honeycomb, DataDog APM, Tempo) / none | `runtimeOperations.traces` | |
| Ops.Q6 | **Logs** (supersedes Q3.6 detail): structured JSON; aggregator (Loki, Logtail, DataDog, CloudWatch); retention | `runtimeOperations.logs` | |
| Ops.Q7 | **Alerting & paging**: PagerDuty / OpsGenie / Slack/Discord webhooks / none; threshold strategy | `runtimeOperations.alerting` | Required ≠ none if `security.sensitivityTier = High` |
| Ops.Q8 | **SLI / SLO** (conditional `scaleTarget ∈ {production-scale, enterprise}`): which metrics, error budget policy | `runtimeOperations.slo` | Auto-skipped otherwise |
| Ops.Q9 | **Feature flags**: LaunchDarkly / Unleash / PostHog / Flagsmith / none; flag lifecycle | `runtimeOperations.featureFlags` | |
| Ops.Q10 | **Maintenance mode / graceful degradation**: DB-flag, env, CDN rule; user UX | `runtimeOperations.maintenanceMode` | |
| Ops.Q11 | **Health checks**: liveness, readiness, deep health; expected by platform | `runtimeOperations.healthChecks` | Platform-derived default |
| Ops.Q12 | **Runbooks**: storage path (`docs/runbooks/`), template style, ownership | `runtimeOperations.runbooks` | |
| Ops.Q13 | **Incident process**: severity levels, escalation chain, postmortem template | `runtimeOperations.incidentProcess` | |
| Ops.Q14 | **On-call rotation**: tool (PagerDuty schedule, OpsGenie schedule, Discord bot, none) | `runtimeOperations.onCall` | |

## Skip-cascade rules

Introduced in Round 3. All cascades respect the Round 2.5 stale-flag mechanism — un-skipping a phase later flags downstream-affected phases stale.

1. **`auth.strategy = "None"`** → wizard prompts single gate Q ("Do you collect *any* user data?"). If No → Privacy collapses to `synthesisStatus: "n/a"` stub. Security still runs but Sec.Q11/Q12 (pentest/VDP) auto-skip.
2. **`architecturalFraming.scaleTarget = "hobby"`** → Sec.Q11, Sec.Q12 auto-skip. Ops.Q8 (SLO) auto-skips. Runbook detail collapses to minimal template.
3. **`apiIntegration.asyncPattern = "No"`** → Ops.Q1-Q3 collapse to "No background work confirmed" with the chance to opt back in.
4. **`dataArchitecture.compliance` includes HIPAA/PCI/SOC2** → **no skips allowed** in Security; `sensitivityTier` locked to `High`; Auth.Q11 (audit log) retention pre-set.

## Cross-phase consistency checks (grill-spec additions)

Added in Round 3 to grill-spec's pre-scaffold validation gate:

1. `dataArchitecture.compliance ⊆ privacy.regulations` — every compliance entry must appear in Privacy regulations
2. `dataArchitecture.compliance` contains HIPAA/PCI/SOC2 → `auth.strategy ≠ None`
3. `security.sensitivityTier ≥ Elevated` when `dataArchitecture.compliance` non-empty
4. `runtimeOperations.alerting ≠ None` when `security.sensitivityTier = High`

The 5-category adjust-dialog walk (scope, assumptions, alternatives, risks, deps) stays unchanged — Round 3 inherits it intact.

## Schema additions (onboard 2.0)

Schema file: `onboard/skills/generate/references/context-shape-v2.json`. Four new top-level phase blocks under `context.phases.*`, each following the established Round 2 pattern (`description`, `required`, `properties`).

```jsonc
{
  "phases": {
    "auth": {
      "type": "object",
      "description": "Identity and access control decisions",
      "properties": {
        "strategy": { "enum": ["none", "hosted", "self-hosted-oss", "built-in"] },
        "provider": { "type": "string" },
        "idps": { "type": "array", "items": { "type": "string" } },
        "sessionModel": { "enum": ["cookie", "jwt", "hybrid"] },
        "mfa": { "type": "object" },
        "authzModel": { "enum": ["flat-roles", "rbac", "abac", "db-rls"] },
        "tenantResolution": { "type": "string" },
        "serviceAuth": { "enum": ["api-keys", "mtls", "signed-jwt", "none", "n/a"] },
        "lifecycle": { "type": "object" },
        "recovery": { "type": "string" },
        "passwordPolicy": { "type": "object" },
        "auditLog": { "type": "object" },
        "enforcementPoint": { "type": "array" }
      }
    },
    "privacy": {
      "type": "object",
      "description": "Privacy, consent, and data-rights decisions",
      "properties": {
        "synthesisStatus": { "enum": ["complete", "n/a"] },
        "regulations": { "type": "array" },
        "piiCategories": { "type": "array" },
        "lawfulBasis": { "type": "object" },
        "retention": { "type": "object" },
        "deletionFlow": { "type": "string" },
        "consentManager": { "type": "object" },
        "dsar": { "type": "object" },
        "processors": { "type": "array" },
        "minimization": { "type": "object" },
        "dataResidency": { "type": "object" },
        "accessAudit": { "type": "object" }
      }
    },
    "security": {
      "type": "object",
      "description": "Application security posture and operational controls",
      "properties": {
        "sensitivityTier": { "enum": ["standard", "elevated", "high"] },
        "secrets": { "type": "object" },
        "scanning": { "type": "object" },
        "threatModel": { "enum": ["none", "stride-lite", "formal"] },
        "encryptionAtRest": { "type": "object" },
        "encryptionInTransit": { "type": "object" },
        "headers": { "type": "object" },
        "inputValidation": { "type": "object" },
        "auditRetention": { "type": "object" },
        "ir": { "type": "object" },
        "pentestCadence": { "enum": ["none", "annual", "quarterly", "continuous"] },
        "vdp": { "enum": ["none", "private", "public"] },
        "supplyChain": { "type": "object" }
      }
    },
    "runtimeOperations": {
      "type": "object",
      "description": "Background jobs, observability, alerting, feature flags, and incident process",
      "properties": {
        "jobs": { "type": "object" },
        "retryStrategy": { "type": "object" },
        "scheduling": { "type": "object" },
        "metrics": { "type": "object" },
        "traces": { "type": "object" },
        "logs": { "type": "object" },
        "alerting": { "type": "object" },
        "slo": { "type": "object" },
        "featureFlags": { "type": "object" },
        "maintenanceMode": { "type": "object" },
        "healthChecks": { "type": "object" },
        "runbooks": { "type": "object" },
        "incidentProcess": { "type": "object" },
        "onCall": { "type": "object" }
      }
    }
  }
}
```

`phases.description` updated to reflect Round 3. `context-shape-v2.json` schema bump: `2.0.0-alpha.3 → 2.0.0-alpha.4`. Hard cutover per Decision 8.

## File deliverables

**New (~24 files):**

```
greenfield/skills/synthesis-review/references/templates/
  auth.html                                       NEW   synthesis template
  auth.md                                         NEW   MD companion
  auth-dependencies.json.example                  NEW   sidecar example
  privacy.html                                    NEW
  privacy.md                                      NEW
  privacy-dependencies.json.example               NEW
  security.html                                   NEW
  security.md                                     NEW
  security-dependencies.json.example              NEW
  runtime-operations.html                         NEW
  runtime-operations.md                           NEW
  runtime-operations-dependencies.json.example    NEW

docs/superpowers/specs/
  2026-05-14-greenfield-3.0-round3-design.md      NEW (this doc)

docs/greenfield-3.0-round3/
  implementation-plan.md                          NEW
  phase-q-derivation-rules.md                     NEW  Stack-derived default rules for 50 Qs
```

**Modified (~15 files):**

```
greenfield/.claude-plugin/plugin.json             version → 3.0.0-alpha.4
onboard/.claude-plugin/plugin.json                version → 2.0.0-alpha.4
.claude-plugin/marketplace.json                   mirror both versions

onboard/skills/generate/references/
  context-shape-v2.json                           + 4 phase schemas
  (phases.description updated)

greenfield/skills/context-gathering/SKILL.md      + 4 new state-machine entries; wizard step count 11 → 15
greenfield/skills/context-gathering/references/
  question-bank.md                                + 50 Q entries; migrate Q3.3/Q3.6/Q3.9/Q4.5;
                                                  reduce P4.Q7 to pointer

greenfield/skills/synthesis-review/SKILL.md       + 4 new phases in step list
greenfield/skills/synthesis-review/references/
  section-prompts.md                              + 4 phase-prompt blocks
  defaults-derivation.md                          + 50 derivation rules

greenfield/skills/grill-spec/SKILL.md             + 4 cross-phase consistency checks
greenfield/skills/start/SKILL.md                  wizard step count 11 → 15
greenfield/skills/pickup/SKILL.md                 state-transitions table for 4 new phases;
                                                  un-skip detection for stale-flag interplay
greenfield/skills/check/SKILL.md                  state-transitions table

greenfield/CLAUDE.md                              architecture diagram + step layout
onboard/CLAUDE.md                                 phase listing

docs/greenfield-overview.html                     ROUND 3 LOCKED entry in Discussion Log
```

**Total: ~24 new + ~15 modified ≈ 40 files.** Lighter than Round 2.5 (~50-70 files) because Round 2.5 built the cross-cutting infrastructure; Round 3 is content authoring on top.

## Edge cases

1. **Skip-cascade contradiction (Auth=None but Privacy has data).** Single confirmation Q before Privacy collapses; "Yes I collect data" path runs reduced Privacy (Q1, Q2, Q4 only) and produces a real synthesis instead of `n/a` stub.

2. **Compliance tier conflict.** `dataArchitecture.compliance` includes HIPAA but `auth.strategy = None`, OR `privacy.regulations` omits regulations Data Architecture declared. grill-spec's 4 new cross-phase checks catch these and surface them in the pre-scaffold gate.

3. **Stale-flag chain depth ≥ 4.** Adjusting `auth.strategy` cascades through auth → privacy (DSAR endpoint moves) → security (provider API key joins secret inventory) → runtimeOperations (provider audit events flow into observability). Existing dependency-graph traversal handles arbitrary depth; verification step: smoke-test in implementation plan.

4. **Skip-cascade reversal on resume.** Session: pick `auth=None` → Privacy auto-skipped. Resume later: change to `auth=Hosted`. Stale-flag listener on `auth.strategy` triggers Privacy un-skip; `pickup` skill detects `phaseStatus.privacy = "skipped"` while `auth.strategy ≠ None` and prompts re-walk. New invariant added.

5. **Walking-skeleton stacks (Android, iOS, game engines).** Ops Qs gated on `stack.platform`; mobile rows in `defaults-derivation.md` substitute platform-native equivalents (WorkManager / BGTaskScheduler).

6. **Multi-platform projects (backend + mobile).** Auth.Q2 multi-select adds Apple+Google ID rows when a mobile target is detected.

7. **Synthesis `n/a` stub propagation.** Privacy=`n/a` → Sec.Q9, Auth.Q11, Ops.Q6 defaults that cross-reference `privacy.regulations` use null-safe lookups (`privacy?.regulations ?? []`). Section-prompts.md adds an "n/a-aware fallback" rule for every cross-phase reference.

8. **Provider catalog rot.** Auth/observability/feature-flag provider catalogs are refreshed by stack-researcher at *wizard run time*, not at template-author time. Default rules reference `stackResearch.authProviders[]` etc. rather than hardcoded names.

## Rollback path

- **Per phase**: existing `adjust-dialog` skill handles single-phase rollback. Unchanged from Round 2.5.
- **Per round (revert all of Round 3)**: identify Round 3 commit range; `git revert` or `git reset --hard <Round 2.5 final SHA = fc295ef>`. Schema rolls back to `2.0.0-alpha.3` automatically.
- **In-flight `alpha.4` sessions**: hard cutover policy (Decision 8). Sessions saved on `alpha.4` can't be resumed under `alpha.3`. `pickup` detects version mismatch via `greenfield-state.json.schemaVersion` and presents two options: "Finish on alpha.4 (re-checkout the branch)" or "Discard session, restart on alpha.3". CHANGELOG entry for alpha.3 → alpha.4 calls this out.
- **Hard escape**: if Round 3 introduces a deadlock no one foresaw, `feat/greenfield-1.2` can be rewound to Round 2.5 head; PR #50 stays open with the partial Round 1+2+2.5 set; no marketplace contract is broken because alpha-stage versions are explicitly experimental.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Author cost — 50 Q entries + 4 template pairs + 50 default rules ≈ 7500+ lines | Medium | Break implementation plan into 4 sub-phases (one per new phase); commit each before starting the next |
| Default-derivation drift — defaults reference stack research output shape | Medium | Spec fixes the stack-research-contract keys defaults can rely on; defaults that need unstable data use greenfield-opinion fallback |
| MD/HTML drift in 4 new template pairs | Low | Existing drift-check hook (Round 2.5 PRE-9) already enforces this — just inherits |
| Wizard fatigue — 15 steps, 50-90 explicit Qs depending on stack | Medium | Skip cascades are crucial; "Step X of 15" + percent-complete indicator; Lite-mode-defaults already in place |
| Round 3 size discovers as 60+ files mid-implementation | Low | Sub-phase commits give natural pause points; user can pause between phases if needed |
| Underspecified default rules for non-stack-derived Qs (e.g., runbook style) | Low | Use explicit greenfield-opinion fallback; ~10/50 Qs may not have stack-derived rules |
| Q3.11 (dep mgmt) staying in residual creates a split "supply chain" story (Renovate in residual + SBOM in security) | Low | Document the seam in question-bank Sec.Q13 prose; Round 6 may consolidate |

## Implementation order

Suggested commit cadence (matches Round 2 / Round 2.5 cadence):

1. **R3-A: Schema + scaffolding**
   - onboard 2.0 schema: 4 phase blocks
   - context-gathering state-machine extensions
   - start/pickup/check skill updates (step count 11 → 15)
   - greenfield-state.json schemaVersion bump
2. **R3-B: Auth**
   - 12 Q-bank entries + default-derivation rules
   - synthesis-review template pair + dependencies.json.example
   - section-prompts.md entry
3. **R3-C: Privacy**
   - 11 Q-bank entries + default-derivation rules
   - synthesis-review template pair + dependencies.json.example
   - section-prompts.md entry
   - skip-cascade gate Q implementation
4. **R3-D: Security**
   - 13 Q-bank entries + default-derivation rules
   - synthesis-review template pair + dependencies.json.example
   - section-prompts.md entry
   - Q4.5 / Q3.9 migration
5. **R3-E: Runtime Operations**
   - 14 Q-bank entries + default-derivation rules
   - synthesis-review template pair + dependencies.json.example
   - section-prompts.md entry
   - Q3.6 split + P4.Q7 reduction
6. **R3-F: Cross-phase + grill-spec**
   - 4 new cross-phase consistency checks
   - skip-cascade reversal invariant in pickup
   - greenfield/CLAUDE.md + onboard/CLAUDE.md diagram updates
   - docs/greenfield-overview.html ROUND 3 LOCKED entry
7. **R3-G: Release**
   - Version bumps (alpha.4)
   - marketplace.json mirror
   - CHANGELOG entry for schema break
   - cleanup pass + smoke test resume across version boundary

Each commit lands on `feat/greenfield-1.2`.

## Round 3 boundary — what's NOT in this round

- No Frontend phase work (Round 6)
- No new Architectural Framing questions (`dataArchitecture.compliance` is sufficient)
- No Cat 3 residual / Cat 4 dev-workflow synthesis (Round 6+)
- No state JSON migration framework (post-GA)
- No mattpocock-skills replacement (intentionally dropped Round 2.5)
- No non-GHA CI provider templates (Round 6)
- No Q3.11 (dep mgmt) move into Security — split deferred to Round 6
- No new adjust-dialog categories — 5-category walk stays generic and applies to all 4 new phases

## Open questions for implementation phase (non-blocking)

- Exact Q ordering within each phase (currently grouped by sub-topic; reorderable for default-derivation cleanness)
- Synthesis MD template prose style (follow Round 2 pattern; verify in R3-B)
- Whether to surface a percent-complete indicator in addition to "Step X of 15" — implementation choice, not architecture

## PR #50 administrative state at Round 3 entry

- Branch: `feat/greenfield-1.2` (clean working tree at spec write time, `fc295ef`)
- Base: `develop`
- Title (stale): "feat(greenfield)!: 3.0.0-alpha.1 — wizard overhaul Round 1 (incl. 1.2 grill-spec gate)"
- Title (target on Round 3 completion): retitle to reflect Rounds 1+2+2.5+3
- All Rounds 3-6 land on this same branch per locked plan

---

End of Round 3 design.
