# Greenfield 3.0 Round 3 — Auth + Privacy + Security + Runtime Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert four new wizard phases — Auth (12 Qs), Privacy (11 Qs), Security (13 Qs), Runtime Operations (14 Qs) — between Step 4 and Step 5, with full synthesis review per phase, schema sections in onboard 2.0, stack-derived defaults, skip cascades, and grill-spec cross-phase checks.

**Architecture:** Same pattern as Round 2 — each new phase gets a schema section, a synthesis HTML+MD template pair with dependencies.json sidecar, a question-bank section, and a wizard step in `context-gathering/SKILL.md` that invokes `synthesis-review` inline. All cross-cutting infrastructure (stale-flag traversal, MD/HTML drift check, docs/adr output, adjust-dialog, hard schema cutover) already ships from Round 2.5 — Round 3 is pure content + orchestrator wiring on top.

**Tech Stack:** Markdown SKILL.md files, JSON Schema draft-07, HTML synthesis templates (Mustache-like `{{placeholder}}` syntax), Markdown synthesis companions, bash verification commands. No compiled code, no automated test suite for skills (consistent with Rounds 1+2+2.5).

**Source spec:** `docs/superpowers/specs/2026-05-14-greenfield-3.0-round3-design.md`

**Branch:** `feat/greenfield-1.2` (continue working on same branch — all Rounds 3-6 land here).

**Target versions on completion:** `greenfield@3.0.0-alpha.4` / `onboard@2.0.0-alpha.4`.

---

## File Structure

### NEW files (~24)

| Path | Responsibility |
|---|---|
| `greenfield/skills/synthesis-review/references/templates/auth.html` | Auth synthesis HTML template |
| `greenfield/skills/synthesis-review/references/templates/auth.md` | Auth synthesis MD companion |
| `greenfield/skills/synthesis-review/references/templates/auth-dependencies.json.example` | Auth dependency sidecar example |
| `greenfield/skills/synthesis-review/references/templates/privacy.html` | Privacy synthesis HTML template |
| `greenfield/skills/synthesis-review/references/templates/privacy.md` | Privacy synthesis MD companion |
| `greenfield/skills/synthesis-review/references/templates/privacy-dependencies.json.example` | Privacy dependency sidecar example |
| `greenfield/skills/synthesis-review/references/templates/security.html` | Security synthesis HTML template |
| `greenfield/skills/synthesis-review/references/templates/security.md` | Security synthesis MD companion |
| `greenfield/skills/synthesis-review/references/templates/security-dependencies.json.example` | Security dependency sidecar example |
| `greenfield/skills/synthesis-review/references/templates/runtime-operations.html` | Runtime Ops synthesis HTML template |
| `greenfield/skills/synthesis-review/references/templates/runtime-operations.md` | Runtime Ops synthesis MD companion |
| `greenfield/skills/synthesis-review/references/templates/runtime-operations-dependencies.json.example` | Runtime Ops dependency sidecar example |
| `docs/greenfield-3.0-round3/implementation-plan.md` | Symlink/pointer to this plan (in case index changes) |
| `docs/greenfield-3.0-round3/phase-q-derivation-rules.md` | Catalog of all 50 stack-derived default rules in one referenceable doc |
| `docs/superpowers/plans/2026-05-14-greenfield-3.0-round3-implementation.md` | This file |

### MODIFIED files (~15)

| Path | What changes |
|---|---|
| `onboard/skills/generate/references/context-shape-v2.json` | + 4 phase blocks (`auth`, `privacy`, `security`, `runtimeOperations`); update top-level description |
| `greenfield/skills/context-gathering/SKILL.md` | + 4 new state-machine entries (Step 5-8); wizard step count 11 → 15; renumber Step 5→9, 5.5→9.5, 6→10, 7→11, 8→12, 9→13, 10→14, 11→15; update progress indicators |
| `greenfield/skills/context-gathering/references/question-bank.md` | + 50 Q entries; migrate Q3.3 (auth) → Auth.Q1, Q3.6 (monitoring) → Ops.Q4-Q6, Q3.9 (secrets) → Sec.Q2, Q4.5 (security sensitivity) → Sec.Q1; reduce P4.Q7 to pointer |
| `greenfield/skills/synthesis-review/SKILL.md` | + 4 new phases in step list and prompt invocation table |
| `greenfield/skills/synthesis-review/references/section-prompts.md` | + 4 new phase-prompt blocks |
| `greenfield/skills/synthesis-review/references/defaults-derivation.md` | + 50 derivation rules |
| `greenfield/skills/grill-spec/SKILL.md` | + 4 cross-phase consistency checks |
| `greenfield/skills/start/SKILL.md` | step count 11 → 15; error matrix + phase enum |
| `greenfield/skills/pickup/SKILL.md` | state-transitions table for 4 new phases; skip-cascade reversal invariant |
| `greenfield/skills/check/SKILL.md` | state-transitions table; synthesis HTML count update |
| `greenfield/CLAUDE.md` | architecture diagram + step layout |
| `onboard/CLAUDE.md` | phase listing |
| `docs/greenfield-overview.html` | ROUND 3 LOCKED entry in Discussion Log |
| `greenfield/.claude-plugin/plugin.json` | `3.0.0-alpha.3` → `3.0.0-alpha.4` |
| `onboard/.claude-plugin/plugin.json` | `2.0.0-alpha.3` → `2.0.0-alpha.4` |
| `.claude-plugin/marketplace.json` | sync greenfield + onboard versions and descriptions |
| `onboard/CHANGELOG-2.0.md` | "Round 3 additions" entry; schema-break note |

**Total: ~24 new + ~15 modified = ~39 files** (matches design estimate of ~40).

---

## Task Order Overview

```
Phase A — Schema (foundation; parallel-safe)
   T1   Add `auth` schema section
   T2   Add `privacy` schema section
   T3   Add `security` schema section
   T4   Add `runtimeOperations` schema section
   T5   Update top-level description + commit

Phase B — Synthesis template authoring (one block per new phase)
   T6   auth.html + auth.md + auth-dependencies.json.example
   T7   privacy.html + privacy.md + privacy-dependencies.json.example
   T8   security.html + security.md + security-dependencies.json.example
   T9   runtime-operations.html + runtime-operations.md + runtime-operations-dependencies.json.example
   T10  section-prompts.md additions for 4 new phases

Phase C — Wizard surface (question bank)
   T11  Auth Q1-Q12 + default rules
   T12  Privacy Q1-Q11 + default rules + skip-cascade gate Q
   T13  Security Q1-Q13 + default rules + migrate Q4.5 + migrate Q3.9
   T14  Runtime Ops Q1-Q14 + default rules + split Q3.6 + reduce P4.Q7
   T15  Cat 3 residual cleanup + Cat 4 cleanup
   T16  defaults-derivation.md consolidation + the all-50 derivation catalog

Phase D — Orchestrator wiring (context-gathering)
   T17  Insert Step 5 Auth
   T18  Insert Step 6 Privacy + skip-cascade gate logic
   T19  Insert Step 7 Security
   T20  Insert Step 8 Runtime Operations
   T21  Renumber existing Steps 5 → 9, 5.5 → 9.5, 6 → 10, 7 → 11, 8 → 12, 9 → 13, 10 → 14, 11 → 15
   T22  Update progress-indicator strings (Step X of 11 → Step X of 15)
   T23  Update state-transitions table

Phase E — Cross-phase + grill-spec + pickup
   T24  4 new cross-phase consistency checks in grill-spec
   T25  Skip-cascade reversal invariant in pickup
   T26  start/check/CLAUDE.md/onboard CLAUDE.md updates

Phase F — Docs + Discussion Log
   T27  docs/greenfield-overview.html — ROUND 3 LOCKED entry
   T28  docs/greenfield-3.0-round3/ companion doc set

Phase G — Release
   T29  Version bumps (alpha.3 → alpha.4)
   T30  CHANGELOG-2.0.md entry + marketplace.json sync
   T31  /validate + final smoke test
```

**Parallelism:** Phase A tasks (T1–T4) are independent. Phase B tasks (T6–T9) are independent. Phase C tasks (T11–T14) are independent. Phase D tasks (T17–T20) must run in order (each renumbers downstream steps). Phase E onward is sequential.

---

## Task 1: Add `auth` schema section to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Read current schema structure**

Run: `grep -n '"phases"\|"dataArchitecture"\|"apiIntegration"\|"cicdAndDelivery"' onboard/skills/generate/references/context-shape-v2.json`

Expected: locate the `"phases"` object (top-level) and the existing topic-name phase blocks. Auth schema slots between `apiIntegration` and `cicdAndDelivery`.

- [ ] **Step 2: Add `auth` schema block**

In `onboard/skills/generate/references/context-shape-v2.json`, inside the `"phases"` object, insert the following block AFTER `apiIntegration` and BEFORE `cicdAndDelivery`:

```json
"auth": {
  "type": "object",
  "description": "Phase: Auth — identity and access control decisions. Round 3 (alpha.4). Hybrid strictness: 4 required enum-locked fields drive cross-phase contradictions; remaining fields loose to accommodate provider catalog churn (Clerk, Auth0, Supabase, Firebase, Cognito).",
  "required": ["strategy", "sessionModel", "authzModel", "enforcementPoint"],
  "additionalProperties": false,
  "properties": {
    "strategy": {
      "enum": ["none", "hosted", "self-hosted-oss", "built-in"],
      "description": "Auth strategy. 'hosted' = Clerk/Auth0/Supabase/Firebase/Cognito; 'self-hosted-oss' = Keycloak/Authentik/Ory; 'built-in' = framework session/JWT; 'none' = no auth (Privacy auto-skip gate fires)."
    },
    "sessionModel": {
      "enum": ["cookie", "jwt", "hybrid", "n/a"],
      "description": "Session container. 'n/a' valid only when strategy='none'."
    },
    "authzModel": {
      "enum": ["flat-roles", "rbac", "abac", "db-rls", "n/a"],
      "description": "Authorization model. RLS gated by dataArchitecture.engine support."
    },
    "enforcementPoint": {
      "type": "array",
      "items": { "enum": ["middleware", "route-guard", "db-rls", "api-gateway"] },
      "description": "Where authorization checks live. Multi-select."
    },
    "provider":         { "type": "string", "description": "Specific provider name (Clerk, Auth0, Supabase Auth, Firebase Auth, Cognito, Keycloak, Authentik, Ory, framework-native). Loose for catalog churn." },
    "idps":             { "type": "array", "items": { "type": "string" }, "description": "Identity providers selected (email+pw, Google, GitHub, Apple, SAML SSO, magic links, passkeys/WebAuthn)." },
    "mfa":              { "type": "object", "description": "MFA configuration: required (bool), methods (array: TOTP, SMS, passkeys)." },
    "tenantResolution": { "type": "string", "description": "Tenant resolution strategy when dataArchitecture.multiTenancy ≠ none (subdomain, path, claim, header). Empty when not multi-tenant." },
    "serviceAuth":      { "enum": ["api-keys", "mtls", "signed-jwt", "none", "n/a"], "description": "Service-to-service auth. 'n/a' when topology=monolith." },
    "lifecycle":        { "type": "object", "description": "Account lifecycle: signup flow, email verification, password reset, deletion." },
    "recovery":         { "type": "string", "description": "Account recovery (email-only, phone, recovery-codes, SSO-mediated)." },
    "passwordPolicy":   { "type": "object", "description": "Password policy: length, complexity, breach check (HIBP), or passkey-only." },
    "auditLog":         { "type": "object", "description": "Auth audit log: events captured, retention window." }
  }
},
```

Place the comma after the closing `}` to keep JSON valid.

- [ ] **Step 3: Validate JSON parses**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`. If parse error, locate the missing comma or brace and fix.

- [ ] **Step 4: Commit T1 (don't push)**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "$(cat <<'EOF'
feat(onboard): add Auth phase schema definition

Add 'auth' phase block with 4 required enum-locked fields
(strategy, sessionModel, authzModel, enforcementPoint) and 9 loose
fields covering provider, idps, mfa, tenant resolution,
service-to-service auth, lifecycle, recovery, password policy,
audit log. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `privacy` schema section to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Insert `privacy` block after `auth`**

In `onboard/skills/generate/references/context-shape-v2.json`, inside `"phases"`, AFTER the `auth` block from T1 and BEFORE `cicdAndDelivery`, insert:

```json
"privacy": {
  "type": "object",
  "description": "Phase: Privacy — privacy, consent, and data-rights decisions. Round 3 (alpha.4). Supports synthesisStatus='n/a' stub when auth.strategy='none' AND no-data-collected gate passes.",
  "required": ["synthesisStatus"],
  "additionalProperties": false,
  "properties": {
    "synthesisStatus": {
      "enum": ["complete", "n/a"],
      "description": "'n/a' triggers stub synthesis when no auth + no data collected. All other fields optional when n/a."
    },
    "regulations":     { "type": "array", "items": { "type": "string" }, "description": "Regulatory scope (GDPR, CCPA, LGPD, PIPEDA, HIPAA, none). Pre-filled from dataArchitecture.compliance." },
    "piiCategories":   { "type": "array", "items": { "type": "string" }, "description": "PII categories collected (email, name, address, phone, location, payment, health, biometric, behavioral)." },
    "lawfulBasis":     { "type": "object", "description": "Lawful basis per PII category (consent, contract, legitimate-interest, vital-interest). Required if GDPR/UK-GDPR in regulations." },
    "retention":       { "type": "object", "description": "Retention policy: per-category retention windows." },
    "deletionFlow":    { "type": "string", "description": "Right-to-erasure (hard-delete, soft-delete-and-anonymize, deletion-request-workflow)." },
    "consentManager":  { "type": "object", "description": "Consent management: banner needed, granular categories, storage mechanism." },
    "dsar":            { "type": "object", "description": "DSAR / data export flow: format (JSON/CSV), SLA." },
    "processors":      { "type": "array", "items": { "type": "string" }, "description": "Third-party PII processors. Pre-filled from apiIntegration.externalServices." },
    "minimization":    { "type": "object", "description": "Data minimization: anonymization in analytics, IP truncation, etc." },
    "dataResidency":   { "type": "object", "description": "Cross-border transfer: residency requirements, transfer mechanisms (SCC, adequacy)." },
    "accessAudit":     { "type": "object", "description": "PII access audit log: who/when/what. Mandatory when regulations includes HIPAA." }
  }
},
```

- [ ] **Step 2: Validate**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 3: Commit T2**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "$(cat <<'EOF'
feat(onboard): add Privacy phase schema definition

Add 'privacy' phase block. Sole required field is synthesisStatus
(complete | n/a) to support skip-cascade stub when auth.strategy='none'
AND no-data-collected gate passes. 11 optional fields covering
regulations, PII inventory, lawful basis, retention, deletion flow,
consent management, DSAR, processors, minimization, data residency,
access audit. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `security` schema section to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Insert `security` block after `privacy`**

In `onboard/skills/generate/references/context-shape-v2.json`, AFTER the `privacy` block, insert:

```json
"security": {
  "type": "object",
  "description": "Phase: Security — application security posture and operational controls. Round 3 (alpha.4). 3 required enum-locked fields drive cross-phase contradictions.",
  "required": ["sensitivityTier", "threatModel", "supplyChain"],
  "additionalProperties": false,
  "properties": {
    "sensitivityTier": {
      "enum": ["standard", "elevated", "high"],
      "description": "Sensitivity tier. Locked to 'high' if dataArchitecture.compliance non-empty. 'elevated' for PII/payments. Drives Sec.Q9/Q11/Q12 conditional flow."
    },
    "threatModel": {
      "enum": ["none", "stride-lite", "formal"],
      "description": "Threat model approach. STRIDE-lite checklist or formal session."
    },
    "supplyChain": {
      "type": "object",
      "description": "Supply-chain posture: lockfile pinning (bool), signed commits (bool), SBOM generation (bool), provenance attestation (bool)."
    },
    "secrets":              { "type": "object", "description": "Secret management: storage backend (.env, platform-managed, Vault/Doppler, cloud-KMS), rotation cadence." },
    "scanning":             { "type": "object", "description": "Vulnerability scanning: deps (Dependabot/Snyk), SAST (Semgrep/CodeQL), DAST (ZAP), container scan, cadence." },
    "encryptionAtRest":     { "type": "object", "description": "Encryption at rest: DB-default, per-column for PII, app-managed." },
    "encryptionInTransit":  { "type": "object", "description": "Encryption in transit: TLS everywhere, mTLS for s2s, HSTS posture." },
    "headers":              { "type": "object", "description": "Security headers: CORS, CSP, X-Frame-Options defaults." },
    "inputValidation":      { "type": "object", "description": "Input validation policy: boundaries-only vs everywhere; library choice." },
    "auditRetention":       { "type": "object", "description": "Audit log retention: window, tamper-evidence (hash chain, write-once storage). Required when sensitivityTier ≠ standard." },
    "ir":                   { "type": "object", "description": "Incident response: runbook style, notification SLA. Pointer to runtimeOperations.incidentProcess for full detail." },
    "pentestCadence":       { "enum": ["none", "annual", "quarterly", "continuous"], "description": "Pentest cadence. Auto-skipped for hobby scaleTarget." },
    "vdp":                  { "enum": ["none", "private", "public"], "description": "Bug bounty / VDP program. Auto-skipped for hobby." }
  }
},
```

- [ ] **Step 2: Validate**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 3: Commit T3**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "$(cat <<'EOF'
feat(onboard): add Security phase schema definition

Add 'security' phase block with 3 required fields (sensitivityTier,
threatModel, supplyChain) and 10 loose fields covering secrets, scanning,
encryption at rest/in transit, headers, input validation, audit
retention, IR pointer, pentest cadence, VDP. Part of greenfield 3.0
Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add `runtimeOperations` schema section to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Insert `runtimeOperations` block after `security`**

In `onboard/skills/generate/references/context-shape-v2.json`, AFTER the `security` block, insert:

```json
"runtimeOperations": {
  "type": "object",
  "description": "Phase: Runtime Operations — background jobs, observability, alerting, feature flags, and incident process. Round 3 (alpha.4). Required fields gated by upstream skip cascades.",
  "required": [],
  "additionalProperties": false,
  "properties": {
    "jobs":             { "type": "object", "description": "Background job system: provider (Redis/BullMQ, Sidekiq, Celery, SQS, Cloud Tasks, Inngest, Temporal, none). Auto-skipped when apiIntegration.asyncPatternPattern='none'." },
    "retryStrategy":    { "type": "object", "description": "Retry / idempotency: at-least-once vs exactly-once, retry policy, dead-letter queue." },
    "scheduling":       { "type": "object", "description": "Scheduled tasks: distributed scheduler or platform cron (Vercel Cron, GH Actions, k8s CronJob)." },
    "metrics":          { "type": "object", "description": "Metrics: Prometheus / DataDog / Grafana Cloud / platform-native / none." },
    "traces":           { "type": "object", "description": "Traces: OTel + backend (Honeycomb, DataDog APM, Tempo) / none." },
    "logs":             { "type": "object", "description": "Logs: structured JSON; aggregator (Loki, Logtail, DataDog, CloudWatch); retention." },
    "alerting":         { "type": "object", "description": "Alerting & paging: tool (PagerDuty / OpsGenie / Slack-Discord / none), threshold strategy. Required ≠ none when security.sensitivityTier='high'." },
    "slo":              { "type": "object", "description": "SLI/SLO: which metrics, error budget policy. Auto-skipped when scaleTarget ∉ {production-scale, enterprise}." },
    "featureFlags":     { "type": "object", "description": "Feature flag system: provider (LaunchDarkly, Unleash, PostHog, Flagsmith, none), flag lifecycle." },
    "maintenanceMode":  { "type": "object", "description": "Maintenance mode / graceful degradation: mechanism (DB-flag, env, CDN rule), user UX." },
    "healthChecks":     { "type": "object", "description": "Health checks: liveness, readiness, deep health. Platform-driven default." },
    "runbooks":         { "type": "object", "description": "Runbooks: storage path (docs/runbooks/), template style, ownership." },
    "incidentProcess":  { "type": "object", "description": "Incident process: severity levels, escalation chain, postmortem template." },
    "onCall":           { "type": "object", "description": "On-call rotation: tool (PagerDuty schedule, OpsGenie schedule, Discord bot, none)." }
  }
}
```

(Note: no trailing comma — this is the last entry in `"phases"`.)

- [ ] **Step 2: Validate**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 3: Commit T4**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "$(cat <<'EOF'
feat(onboard): add Runtime Operations phase schema definition

Add 'runtimeOperations' phase block with no hard-required fields (all
gated by upstream skip cascades). 14 fields covering jobs, retry,
scheduling, metrics, traces, logs, alerting, SLO, feature flags,
maintenance mode, health checks, runbooks, incident process, on-call.
Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update top-level description + reorder commit

**Files:**
- Modify: `onboard/skills/generate/references/context-shape-v2.json`

- [ ] **Step 1: Update top-level description**

In `onboard/skills/generate/references/context-shape-v2.json`, find the top-level `"description"` field that currently reads (after Round 2.5):

```
"description": "Input schema for the onboard:generate skill in onboard 2.x. Rounds 1–2 fully specify dataArchitecture, apiIntegration, cicdAndDelivery, plus Round 2.5 adds architecturalFraming + architecturalValidation. ..."
```

Replace the "Rounds 1–2.5" phrase with:

```
Rounds 1–3 fully specify architecturalFraming, dataArchitecture, apiIntegration, auth, privacy, security, runtimeOperations, cicdAndDelivery, architecturalValidation
```

If the description lists deferred phases (e.g., "Phases P0, P0.5, P1, P5, ..."), remove P6 (Auth/Security) and P7 (Workflow) from the deferred list since they are now live.

- [ ] **Step 2: Validate**

Run: `python3 -c "import json; json.load(open('onboard/skills/generate/references/context-shape-v2.json'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 3: Commit T5**

```bash
git add onboard/skills/generate/references/context-shape-v2.json
git commit -m "$(cat <<'EOF'
fix(onboard): update schema description for Round 3 phases

Mark auth, privacy, security, runtimeOperations as live (Round 3).
Remove from deferred-phase list. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Author auth synthesis template (HTML + MD + dependencies)

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/auth.html`
- Create: `greenfield/skills/synthesis-review/references/templates/auth.md`
- Create: `greenfield/skills/synthesis-review/references/templates/auth-dependencies.json.example`

- [ ] **Step 1: Read existing template pair for format reference**

Run: `cat greenfield/skills/synthesis-review/references/templates/data-architecture.html | head -50`

Note the structure: `<!DOCTYPE html>` → `<head>` with `<style>` block → `<body>` → executive summary → numbered `<section>` blocks → footer. Mustache-like `{{placeholder}}` syntax for fill-ins (e.g., `{{auth.strategy}}`).

Run: `cat greenfield/skills/synthesis-review/references/templates/data-architecture.md | head -50`

Note: H1 title, frontmatter (date, phase, status), 7-section MD body with full prose where HTML had summary tables.

- [ ] **Step 2: Create `auth.html`**

Create `greenfield/skills/synthesis-review/references/templates/auth.html`. Use the `data-architecture.html` structure as the model. Section composition:

1. **Executive Summary** — strategy, provider, session model, MFA, authz model at a glance
2. **Strategy & Provider** — `{{auth.strategy}}`, `{{auth.provider}}` with rationale captured during the wizard
3. **Identity Providers (IdPs)** — table of `{{auth.idps}}` with platform applicability (web/mobile)
4. **Session & Token Model** — `{{auth.sessionModel}}`, refresh strategy, cookie/JWT trade-offs
5. **MFA & Account Security** — `{{auth.mfa}}`, `{{auth.passwordPolicy}}`, recovery
6. **Authorization & Tenancy** — `{{auth.authzModel}}`, `{{auth.enforcementPoint}}`, `{{auth.tenantResolution}}`
7. **Service-to-Service Auth** — `{{auth.serviceAuth}}` (conditional on topology)
8. **Audit & Lifecycle** — `{{auth.auditLog}}`, `{{auth.lifecycle}}`, deletion flow
9. **Downstream impact** — note dependencies referenced by privacy, security, runtimeOperations
10. **Footer** — generated-at timestamp + spec reference

Render all `{{auth.*}}` Mustache placeholders. Use the same CSS class names as `data-architecture.html` for visual consistency.

- [ ] **Step 3: Create `auth.md`**

Create `greenfield/skills/synthesis-review/references/templates/auth.md`. Follow the `data-architecture.md` structure: H1 title, frontmatter block, 9 sections matching the HTML, prose paragraphs (not tables) where the HTML used summary boxes, full rationale for each decision. The MD companion is the long-form artifact; the HTML is the executive summary.

The drift-check hook (Round 2.5 PRE-9) will compare the two files at every commit — make sure both express the same decisions in the same order.

- [ ] **Step 4: Create `auth-dependencies.json.example`**

Create `greenfield/skills/synthesis-review/references/templates/auth-dependencies.json.example` with:

```json
{
  "phaseId": "auth",
  "version": 1,
  "dependsOn": {
    "dataArchitecture.engine": "auth.authzModel (RLS feasibility)",
    "dataArchitecture.multiTenancy":   "auth.tenantResolution",
    "apiIntegration.style":            "auth.enforcementPoint (gateway vs middleware)",
    "architecturalFraming.topology":   "auth.serviceAuth (s2s only for microservices)",
    "architecturalFraming.scaleTarget":"auth.mfa.required (locked when High tier)"
  },
  "downstreamFor": [
    "privacy", "security", "runtimeOperations"
  ]
}
```

- [ ] **Step 5: Hand-verify the template pair**

Run: `ls greenfield/skills/synthesis-review/references/templates/ | grep auth`

Expected output: three files — `auth.html`, `auth.md`, `auth-dependencies.json.example`.

Run: `python3 -c "import json; json.load(open('greenfield/skills/synthesis-review/references/templates/auth-dependencies.json.example'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 6: Commit T6**

```bash
git add greenfield/skills/synthesis-review/references/templates/auth.html greenfield/skills/synthesis-review/references/templates/auth.md greenfield/skills/synthesis-review/references/templates/auth-dependencies.json.example
git commit -m "$(cat <<'EOF'
feat(greenfield): add Auth synthesis template (HTML + MD + dependencies)

Hybrid HTML executive summary + MD long-form companion (drift-checked).
9 sections covering strategy, providers, sessions, MFA, authorization,
tenancy, service-to-service, audit/lifecycle, downstream impact.
Dependency sidecar wires upstream framing/data/api + downstream
privacy/security/runtimeOperations. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Author privacy synthesis template (HTML + MD + dependencies)

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/privacy.html`
- Create: `greenfield/skills/synthesis-review/references/templates/privacy.md`
- Create: `greenfield/skills/synthesis-review/references/templates/privacy-dependencies.json.example`

- [ ] **Step 1: Create `privacy.html`**

Use `data-architecture.html` as structural model. Section composition:

1. **Synthesis Status Banner** — `{{#if privacy.synthesisStatus = 'n/a'}}` block explaining the n/a stub case when triggered; otherwise hidden
2. **Executive Summary** — regulations, PII categories, deletion flow, DSAR status at a glance
3. **Regulatory Scope** — `{{privacy.regulations}}` with applicability rationale
4. **PII Inventory** — `{{privacy.piiCategories}}` table; cross-link to `dataArchitecture` user schema
5. **Lawful Basis & Consent** — `{{privacy.lawfulBasis}}` + `{{privacy.consentManager}}`
6. **Retention & Deletion** — `{{privacy.retention}}` + `{{privacy.deletionFlow}}`
7. **DSAR & Data Export** — `{{privacy.dsar}}`
8. **Third-Party Processors** — `{{privacy.processors}}` (pre-filled from `apiIntegration.externalServices`)
9. **Data Minimization & Residency** — `{{privacy.minimization}}` + `{{privacy.dataResidency}}`
10. **Access Audit** — `{{privacy.accessAudit}}` (mandatory if HIPAA)
11. **Downstream impact** — security, runtimeOperations
12. **Footer**

Add a clearly visible "n/a stub" banner CSS class for the case where the entire phase collapsed.

- [ ] **Step 2: Create `privacy.md`**

Follow the `data-architecture.md` structure. Match HTML section ordering. Add prose-mode rationale for each decision. Document the n/a stub case as an opening paragraph guarded by `{{#if synthesisStatus = 'n/a'}}`.

- [ ] **Step 3: Create `privacy-dependencies.json.example`**

```json
{
  "phaseId": "privacy",
  "version": 1,
  "dependsOn": {
    "dataArchitecture.compliance":     "privacy.regulations (pre-fill)",
    "apiIntegration.externalServices": "privacy.processors (pre-fill)",
    "auth.strategy":                    "privacy skip-cascade gate"
  },
  "downstreamFor": [
    "security", "runtimeOperations"
  ]
}
```

- [ ] **Step 4: Validate JSON + verify files**

Run: `python3 -c "import json; json.load(open('greenfield/skills/synthesis-review/references/templates/privacy-dependencies.json.example'))" && echo "VALID"`

Expected: `VALID`.

Run: `ls greenfield/skills/synthesis-review/references/templates/ | grep privacy`

Expected: three files.

- [ ] **Step 5: Commit T7**

```bash
git add greenfield/skills/synthesis-review/references/templates/privacy.html greenfield/skills/synthesis-review/references/templates/privacy.md greenfield/skills/synthesis-review/references/templates/privacy-dependencies.json.example
git commit -m "$(cat <<'EOF'
feat(greenfield): add Privacy synthesis template (HTML + MD + dependencies)

12-section hybrid template. Supports n/a stub banner for skip-cascade
collapse case (auth.strategy='none' + no data collected). Dependency
sidecar wires upstream dataArchitecture/apiIntegration/auth + downstream
security/runtimeOperations. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Author security synthesis template (HTML + MD + dependencies)

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/security.html`
- Create: `greenfield/skills/synthesis-review/references/templates/security.md`
- Create: `greenfield/skills/synthesis-review/references/templates/security-dependencies.json.example`

- [ ] **Step 1: Create `security.html`**

Use `data-architecture.html` as model. Section composition:

1. **Executive Summary** — sensitivity tier, secret strategy, scanning posture, encryption summary, threat model
2. **Sensitivity Tier** — `{{security.sensitivityTier}}` with rationale from `compliance` + `apiIntegration.externalServices`
3. **Secret Management** — `{{security.secrets}}` (rotation cadence, backend)
4. **Vulnerability Scanning** — `{{security.scanning}}` (deps + SAST + DAST + container)
5. **Encryption** — `{{security.encryptionAtRest}}` + `{{security.encryptionInTransit}}`
6. **Threat Model** — `{{security.threatModel}}`
7. **Application Security** — `{{security.headers}}` + `{{security.inputValidation}}`
8. **Audit & Tamper-Evidence** — `{{security.auditRetention}}`
9. **Incident Response** — `{{security.ir}}` (with pointer to `runtimeOperations.incidentProcess`)
10. **Pentest & VDP** — `{{security.pentestCadence}}` + `{{security.vdp}}` (conditional)
11. **Supply Chain** — `{{security.supplyChain}}`
12. **Downstream impact** — runtimeOperations
13. **Footer**

- [ ] **Step 2: Create `security.md`**

Long-form companion matching the 13-section HTML structure. Capture rationale for each decision.

- [ ] **Step 3: Create `security-dependencies.json.example`**

```json
{
  "phaseId": "security",
  "version": 1,
  "dependsOn": {
    "dataArchitecture.compliance":      "security.sensitivityTier (locks 'high')",
    "apiIntegration.externalServices":  "security.sensitivityTier (payment providers → elevated)",
    "auth.strategy":                     "security skip-cascade and Sec.Q11/Q12 visibility",
    "privacy.regulations":               "security.auditRetention defaults",
    "architecturalFraming.topology":    "security.encryptionInTransit (mTLS for microservices)",
    "architecturalFraming.scaleTarget": "security.pentestCadence and Sec.Q11/Q12 visibility"
  },
  "downstreamFor": [
    "runtimeOperations"
  ]
}
```

- [ ] **Step 4: Validate**

Run: `python3 -c "import json; json.load(open('greenfield/skills/synthesis-review/references/templates/security-dependencies.json.example'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 5: Commit T8**

```bash
git add greenfield/skills/synthesis-review/references/templates/security.html greenfield/skills/synthesis-review/references/templates/security.md greenfield/skills/synthesis-review/references/templates/security-dependencies.json.example
git commit -m "$(cat <<'EOF'
feat(greenfield): add Security synthesis template (HTML + MD + dependencies)

13-section hybrid template covering sensitivity tier, secrets,
scanning, encryption, threat model, AppSec, audit, IR pointer,
pentest/VDP, supply chain. Dependency sidecar wires upstream
compliance/auth/privacy/framing. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Author runtime-operations synthesis template (HTML + MD + dependencies)

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/runtime-operations.html`
- Create: `greenfield/skills/synthesis-review/references/templates/runtime-operations.md`
- Create: `greenfield/skills/synthesis-review/references/templates/runtime-operations-dependencies.json.example`

- [ ] **Step 1: Create `runtime-operations.html`**

Section composition:

1. **Executive Summary** — job system, observability stack, alerting, feature flag tier
2. **Background Jobs & Retries** — `{{runtimeOperations.jobs}}` + `{{runtimeOperations.retryStrategy}}`
3. **Scheduled Tasks** — `{{runtimeOperations.scheduling}}`
4. **Metrics** — `{{runtimeOperations.metrics}}`
5. **Traces** — `{{runtimeOperations.traces}}`
6. **Logs** — `{{runtimeOperations.logs}}`
7. **Alerting & Paging** — `{{runtimeOperations.alerting}}`
8. **SLI / SLO** — `{{runtimeOperations.slo}}` (conditional)
9. **Feature Flags** — `{{runtimeOperations.featureFlags}}`
10. **Maintenance Mode** — `{{runtimeOperations.maintenanceMode}}`
11. **Health Checks** — `{{runtimeOperations.healthChecks}}`
12. **Runbooks** — `{{runtimeOperations.runbooks}}`
13. **Incident Process** — `{{runtimeOperations.incidentProcess}}`
14. **On-Call** — `{{runtimeOperations.onCall}}`
15. **Footer**

- [ ] **Step 2: Create `runtime-operations.md`**

15-section long-form companion. Match HTML ordering. Prose for each decision.

- [ ] **Step 3: Create `runtime-operations-dependencies.json.example`**

```json
{
  "phaseId": "runtimeOperations",
  "version": 1,
  "dependsOn": {
    "apiIntegration.asyncPattern":                "runtimeOperations.jobs (skip-cascade gate)",
    "auth.serviceAuth":                     "runtimeOperations.healthChecks (auth for s2s)",
    "security.sensitivityTier":             "runtimeOperations.alerting (required ≠ none if 'high')",
    "architecturalFraming.topology":       "runtimeOperations.scheduling (k8s CronJob vs platform cron)",
    "architecturalFraming.scaleTarget":    "runtimeOperations.slo (conditional visibility)",
    "architecturalFraming.deploymentShape":"runtimeOperations.healthChecks (platform-driven default)"
  },
  "downstreamFor": []
}
```

- [ ] **Step 4: Validate**

Run: `python3 -c "import json; json.load(open('greenfield/skills/synthesis-review/references/templates/runtime-operations-dependencies.json.example'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 5: Commit T9**

```bash
git add greenfield/skills/synthesis-review/references/templates/runtime-operations.html greenfield/skills/synthesis-review/references/templates/runtime-operations.md greenfield/skills/synthesis-review/references/templates/runtime-operations-dependencies.json.example
git commit -m "$(cat <<'EOF'
feat(greenfield): add Runtime Operations synthesis template (HTML + MD + dependencies)

15-section hybrid template covering jobs, scheduling, metrics, traces,
logs, alerting, SLO, feature flags, maintenance mode, health checks,
runbooks, IR, on-call. Dependency sidecar wires upstream
api/auth/security/framing. No downstream phases (Runtime Ops is the
last new phase in Round 3). Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Extend section-prompts.md for 4 new phases

**Files:**
- Modify: `greenfield/skills/synthesis-review/references/section-prompts.md`

- [ ] **Step 1: Read current structure**

Run: `grep -n '^## \|^### ' greenfield/skills/synthesis-review/references/section-prompts.md`

Expected: existing entries for architecturalFraming, dataArchitecture, apiIntegration, cicdAndDelivery, architecturalValidation. Round 3 adds 4 new sections in topological order (auth, privacy, security, runtimeOperations).

- [ ] **Step 2: Append 4 new sections**

After the existing `apiIntegration` section block, insert (in this order):

```markdown
## auth

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Executive Summary | strategy, provider, sessionModel, mfa.required, authzModel | always |
| Strategy & Provider | strategy, provider | always |
| Identity Providers | idps | hidden if strategy='none' |
| Session & Token Model | sessionModel | hidden if strategy='none' |
| MFA & Account Security | mfa, passwordPolicy, recovery | hidden if strategy='none' |
| Authorization & Tenancy | authzModel, enforcementPoint, tenantResolution | always |
| Service-to-Service Auth | serviceAuth | hidden if architecturalFraming.topology='monolith' |
| Audit & Lifecycle | auditLog, lifecycle | always |
| Downstream impact | (computed) | always |

**Contradiction rules (surfaced as Adjust prompts):**

- `auth.strategy='none'` + dataArchitecture.compliance contains any of {HIPAA, PCI, SOC2} → "HIPAA/PCI/SOC2 require user authentication. No-auth strategy is incompatible with the compliance scope in Data Architecture."
- `auth.serviceAuth='none'` + architecturalFraming.topology='microservices' → "Microservice topology without service-to-service auth leaves internal endpoints unprotected. Consider mTLS or signed JWTs."

---

## privacy

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Synthesis Status Banner | synthesisStatus | shown only if synthesisStatus='n/a' |
| Executive Summary | regulations, piiCategories, deletionFlow, dsar | hidden if n/a |
| Regulatory Scope | regulations | hidden if n/a |
| PII Inventory | piiCategories | hidden if n/a |
| Lawful Basis & Consent | lawfulBasis, consentManager | hidden if GDPR not in regulations |
| Retention & Deletion | retention, deletionFlow | hidden if n/a |
| DSAR & Data Export | dsar | hidden if neither GDPR nor CCPA in regulations |
| Third-Party Processors | processors | hidden if n/a |
| Data Minimization & Residency | minimization, dataResidency | hidden if n/a |
| Access Audit | accessAudit | hidden unless regulations contains HIPAA |
| Downstream impact | (computed) | always |

**Contradiction rules:**

- `privacy.regulations` does NOT contain `dataArchitecture.compliance` entry → "Data Architecture declared {X}, but Privacy regulations does not include it."
- `privacy.synthesisStatus='n/a'` + ANY piiCategories non-empty → "Privacy synthesis is n/a stub but PII categories are declared. Either change to complete synthesis or remove the PII entries."
- `privacy.regulations` contains GDPR + `privacy.dsar` empty → "GDPR requires a Data Subject Access Request process. Define DSAR flow."

---

## security

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Executive Summary | sensitivityTier, secrets, scanning, threatModel | always |
| Sensitivity Tier | sensitivityTier | always |
| Secret Management | secrets | always |
| Vulnerability Scanning | scanning | always |
| Encryption | encryptionAtRest, encryptionInTransit | always |
| Threat Model | threatModel | always |
| Application Security | headers, inputValidation | always |
| Audit & Tamper-Evidence | auditRetention | shown if sensitivityTier ≠ standard |
| Incident Response | ir | always (with pointer to runtimeOperations.incidentProcess) |
| Pentest & VDP | pentestCadence, vdp | hidden when scaleTarget='hobby' and sensitivityTier='standard' |
| Supply Chain | supplyChain | always |
| Downstream impact | (computed) | always |

**Contradiction rules:**

- `security.sensitivityTier='standard'` + `dataArchitecture.compliance` non-empty → "Compliance scope requires sensitivityTier 'elevated' or 'high'."
- `security.sensitivityTier='high'` + `security.encryptionAtRest` does not include 'per-column-for-PII' → "High tier with PII typically requires per-column encryption beyond DB-default."
- `security.supplyChain.sbom=false` + `dataArchitecture.compliance` contains 'SOC2' → "SOC 2 expects SBOM as evidence artifact."

---

## runtimeOperations

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Executive Summary | jobs, metrics, alerting, featureFlags | always |
| Background Jobs & Retries | jobs, retryStrategy | hidden if apiIntegration.asyncPatternPattern='none' |
| Scheduled Tasks | scheduling | always |
| Metrics | metrics | always |
| Traces | traces | always |
| Logs | logs | always |
| Alerting & Paging | alerting | always |
| SLI / SLO | slo | hidden when scaleTarget ∉ {production-scale, enterprise} |
| Feature Flags | featureFlags | always |
| Maintenance Mode | maintenanceMode | always |
| Health Checks | healthChecks | always |
| Runbooks | runbooks | always |
| Incident Process | incidentProcess | always |
| On-Call | onCall | always |

**Contradiction rules:**

- `security.sensitivityTier='high'` + `runtimeOperations.alerting.tool='none'` → "High sensitivity tier requires non-trivial alerting."
- `runtimeOperations.slo` non-empty + `runtimeOperations.metrics.tool='none'` → "SLO requires a metrics backend."
```

- [ ] **Step 3: Verify the file parses (markdown is forgiving; just confirm structure)**

Run: `grep -c '^## ' greenfield/skills/synthesis-review/references/section-prompts.md`

Expected: count increased by 4 from the previous total.

- [ ] **Step 4: Commit T10**

```bash
git add greenfield/skills/synthesis-review/references/section-prompts.md
git commit -m "$(cat <<'EOF'
feat(greenfield): extend section-prompts.md with 4 new Round 3 phases

Add section composition + contradiction rules for auth, privacy,
security, runtimeOperations. Contradiction rules surface as Adjust
prompts during synthesis-review walks. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Author Auth Q-bank entries (12 Qs) + default rules

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Read existing Q-bank entry shape**

Run: `sed -n '281,330p' greenfield/skills/context-gathering/references/question-bank.md`

Confirms the canonical entry format: `### <Q-id>: "<question>"`, then bulleted `Type`, `Options`, `Condition`, `Updates`, `Downstream`, `Default` (with stack-derived rules and greenfield-opinion fallback).

- [ ] **Step 2: Add the `## Step 5: Auth (12 questions)` section**

In `greenfield/skills/context-gathering/references/question-bank.md`, insert a new top-level section AFTER the `## Step 4: API & Integration (10 questions)` section and BEFORE `## Category 3 (residual): Remaining Project Details`:

```markdown
## Step 5: Auth (12 questions)

> **Round 3 (alpha.4):** Auth is the 5th major synthesis phase. Strategy is set first because it gates the rest of the phase's question flow. Synthesis output: `docs/adr/auth.html` + `.md`.

### Auth.Q1: "How do you want to handle authentication?"
- **Type**: Choice
- **Options**: "None — no auth in scope" | "Hosted (Clerk, Auth0, Supabase Auth, Firebase Auth, Cognito)" | "Self-hosted OSS (Keycloak, Authentik, Ory)" | "Built-in (framework session/JWT)"
- **Condition**: Always
- **Updates**: `auth.strategy`, `auth.provider` (follow-up if hosted/self-hosted-oss)
- **Skip-cascade**: `none` → fires single-Q gate to Privacy ("Do you collect any user data?"). Yes → reduced Privacy; No → Privacy synthesisStatus='n/a' stub.
- **Default**:
  - If `stack.stack.framework='next'` AND `Q3.4.deployTarget='vercel'` → `"Hosted (Clerk)"` (greenfield opinion: Clerk is the idiomatic choice for Next on Vercel)
  - If `stack.stack.framework='django'` → `"Built-in (framework session/JWT)"` (Django auth is first-class)
  - If `stack.stack.framework='rails'` → `"Built-in (framework session/JWT)"` (Devise idiomatic)
  - If `stack.stack.framework∈{fastapi,express,nestjs}` AND `architecturalFraming.scaleTarget∈{production-scale, enterprise}` → `"Hosted (Auth0)"` (greenfield opinion: managed auth eliminates security footguns at production scale)
  - If `architecturalFraming.scaleTarget='hobby'` → `"None — no auth in scope"`
  - Else → `"Hosted (Clerk)"` (greenfield opinion: third-party hosted auth eliminates password/session/MFA security pitfalls)
```

Then add Auth.Q2 through Auth.Q12 following the same entry shape. Use the spec § Step 5 — Auth table (`docs/superpowers/specs/2026-05-14-greenfield-3.0-round3-design.md`) for each Q's purpose, options, condition, and updates. Author the default-derivation rules per Q following these patterns:

- **Stack-derived first**: reference `stack.stack.framework`, `architecturalFraming.scaleTarget`, `architecturalFraming.topology`, `dataArchitecture.compliance`, `dataArchitecture.multiTenancy`, `dataArchitecture.engine`, `apiIntegration.style`, `apiIntegration.externalServices` as available
- **Greenfield-opinion fallback**: when no stack signal applies, give the user the most defensible "1 in 10 devs will choose differently" option with a one-sentence rationale
- **N/A handling**: when a phase is conditional (e.g., Auth.Q7 service-to-service auth gated on microservices), mark `**Condition**: architecturalFraming.topology = 'microservices'` and treat default as the "skip" outcome otherwise

Reference the existing P3.Q12 entry as an example of compliance-aware defaults and existing P4.Q5 for rate-limiting style defaults.

- [ ] **Step 3: Verify section parses**

Run: `grep -c '^### Auth.Q' greenfield/skills/context-gathering/references/question-bank.md`

Expected: `12`.

- [ ] **Step 4: Commit T11**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "$(cat <<'EOF'
feat(greenfield): add Step 5 Auth question bank (12 Qs)

Adds Auth.Q1-Q12 with stack-derived default rules. Auth.Q1 supersedes
former Q3.3 (the residual auth question now removed in T15). Skip
cascade gates Privacy phase via Auth.Q1='none'. Part of greenfield 3.0
Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Author Privacy Q-bank entries (11 Qs) + skip-cascade gate

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Add the `## Step 6: Privacy (11 questions)` section**

In `greenfield/skills/context-gathering/references/question-bank.md`, insert a new top-level section AFTER `## Step 5: Auth (12 questions)`:

```markdown
## Step 6: Privacy (11 questions)

> **Round 3 (alpha.4):** Privacy classifies the data captured in dataArchitecture and feeds Security + Runtime Operations. When `auth.strategy='none'`, the wizard fires a single-Q gate first. Synthesis output: `docs/adr/privacy.html` + `.md`.

### Privacy.Gate: "Do you collect any user data at all (emails, IPs, behavioral analytics)?"
- **Type**: Choice
- **Options**: "Yes" | "No"
- **Condition**: `auth.strategy = 'none'`
- **Updates**: `privacy.synthesisStatus` (`'complete'` if Yes; `'n/a'` if No)
- **Skip-cascade**: No → Privacy.Q1-Q11 all skipped; synthesis renders stub-only template
- **Default**: `"Yes"` (greenfield opinion: even no-auth apps usually collect minimal telemetry or contact form data)

### Privacy.Q1: "Which regulations apply to this project?"
- **Type**: Multi-select
- **Options**: "GDPR" | "CCPA" | "LGPD" | "PIPEDA" | "HIPAA" | "None"
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.regulations[]`
- **Default**:
  - Pre-populated from `dataArchitecture.compliance` (any HIPAA/PCI/SOC2 entries auto-add)
  - If `architecturalFraming.scaleTarget = 'enterprise'` AND no signals yet → `["GDPR", "CCPA"]` (greenfield opinion: enterprise products typically have EU + California users)
  - Else → `["GDPR"]` if `apiIntegration.externalServices` includes any EU-resident provider, else `[]`

### Privacy.Q2: "Which PII categories does the app collect?"
- **Type**: Multi-select
- **Options**: "Email" | "Name" | "Address" | "Phone" | "Location" | "Payment" | "Health" | "Biometric" | "Behavioral"
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.piiCategories[]`
- **Default**: derived from `auth.idps` + `apiIntegration.externalServices`; greenfield-opinion fallback is `["Email"]` (assume contact-form minimum)

### Privacy.Q3: "What's the lawful basis per PII category?"
- **Type**: Object (per-category select)
- **Options per category**: "Consent" | "Contract" | "Legitimate interest" | "Vital interest"
- **Condition**: `privacy.regulations` includes "GDPR" or "UK-GDPR"
- **Updates**: `privacy.lawfulBasis`
- **Default**: per-category mapping — Email→Contract, Behavioral→Consent, Health→Consent, Payment→Contract; greenfield-opinion fallback for unmapped categories is Consent

### Privacy.Q4: "What's the retention policy per PII category?"
- **Type**: Object (per-category retention window)
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.retention`
- **Default**: 6yr if `privacy.regulations` includes HIPAA; 2yr for billing-related categories under GDPR Art 17; greenfield-opinion fallback is 12mo

### Privacy.Q5: "How does right-to-erasure work?"
- **Type**: Choice
- **Options**: "Hard delete" | "Soft delete + anonymize" | "Manual deletion request workflow"
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.deletionFlow`
- **Default**: "Soft delete + anonymize" if `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}`; "Hard delete" for hobby

### Privacy.Q6: "How will consent be managed?"
- **Type**: Object (banner needed, granular categories, storage)
- **Condition**: any of `analytics`, `marketing` in `runtimeOperations.metrics.tool` OR `privacy.piiCategories` includes "Behavioral"
- **Updates**: `privacy.consentManager`
- **Default**: banner=true, categories=[essential, analytics, marketing], storage=cookie+server; skipped if no analytics + no marketing

### Privacy.Q7: "How are DSARs (data subject access requests) handled?"
- **Type**: Object (flow, format, SLA)
- **Condition**: `privacy.regulations` includes "GDPR" or "CCPA"
- **Updates**: `privacy.dsar`
- **Default**: flow=manual-email-then-export, format=JSON, SLA=30 days (GDPR); SLA=45 days (CCPA)

### Privacy.Q8: "Which third-party processors will receive PII?"
- **Type**: Multi-select (with text follow-up for each)
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.processors[]`
- **Default**: pre-filled from `apiIntegration.externalServices` (every external service that may touch user data)

### Privacy.Q9: "What data minimization measures are in place?"
- **Type**: Multi-select
- **Options**: "Analytics anonymization" | "IP truncation" | "Pseudonymization" | "Field-level encryption" | "None"
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.minimization`
- **Default**: `["Analytics anonymization", "IP truncation"]` if `privacy.regulations` includes GDPR; `[]` otherwise

### Privacy.Q10: "Where will user data reside? Any cross-border transfer mechanism?"
- **Type**: Object (residency region, transfer mechanism)
- **Condition**: `privacy.synthesisStatus = 'complete'`
- **Updates**: `privacy.dataResidency`
- **Default**: residency=`Q3.4.deployTarget` region; transferMechanism=SCC if GDPR in scope; none otherwise

### Privacy.Q11: "Audit log for PII access — who/when/what?"
- **Type**: Object (events captured, retention)
- **Condition**: `privacy.regulations` includes "HIPAA" (mandatory) OR `privacy.piiCategories` includes "Health"
- **Updates**: `privacy.accessAudit`
- **Default**: events=[read, update, delete, export], retention=6yr (HIPAA), 1yr otherwise
```

Each entry should be authored at full Q-bank fidelity — type, options, condition, updates, downstream, default-derivation rules with stack signals + greenfield-opinion fallback. Use existing P3.Q12 and P4.Q10 entries as stylistic models.

- [ ] **Step 2: Verify section parses**

Run: `grep -c '^### Privacy\.' greenfield/skills/context-gathering/references/question-bank.md`

Expected: `12` (1 Gate Q + 11 numbered Qs).

- [ ] **Step 3: Commit T12**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "$(cat <<'EOF'
feat(greenfield): add Step 6 Privacy question bank (11 Qs + Gate)

Adds Privacy.Gate (single-Q for auth.strategy='none' skip-cascade) +
Privacy.Q1-Q11 with stack-derived default rules. Regulations
pre-populated from dataArchitecture.compliance. Part of greenfield
3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Author Security Q-bank entries (13 Qs) + migrate Q4.5 + Q3.9

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Add the `## Step 7: Security (13 questions)` section**

In `greenfield/skills/context-gathering/references/question-bank.md`, insert a new top-level section AFTER `## Step 6: Privacy (11 questions)`:

```markdown
## Step 7: Security (13 questions)

> **Round 3 (alpha.4):** Security inherits sensitivity tier from privacy.regulations and dataArchitecture.compliance. Sec.Q1 supersedes former Q4.5; Sec.Q2 supersedes former Q3.9. Synthesis output: `docs/adr/security.html` + `.md`.

### Sec.Q1: "What's the security sensitivity tier?"
- **Type**: Choice
- **Options**: "Standard" | "Elevated (PII/payments)" | "High (SOC2/HIPAA/PCI/ISO27001)"
- **Condition**: Always
- **Updates**: `security.sensitivityTier`
- **Default**:
  - If `dataArchitecture.compliance` non-empty → `"High (SOC2/HIPAA/PCI/ISO27001)"` (locked — user cannot override downward)
  - If `apiIntegration.externalServices` includes any payment provider (Stripe, Adyen, PayPal, Braintree) → `"Elevated (PII/payments)"`
  - If `privacy.piiCategories` non-empty → `"Elevated (PII/payments)"`
  - If `architecturalFraming.scaleTarget = 'enterprise'` → `"Elevated (PII/payments)"` (greenfield opinion: enterprise products typically handle employee/customer PII)
  - Else → `"Standard"`

### Sec.Q2: "How will environment variables and secrets be managed? Rotation cadence?"
- **Type**: Object (backend, rotation)
- **Options for backend**: ".env files" | "Platform-managed (Vercel env, AWS SSM)" | "Vault / Doppler" | "Cloud KMS"
- **Condition**: Always
- **Updates**: `security.secrets`
- **Default**: backend by `Q3.4.deployTarget` (Vercel→platform-managed, AWS→SSM, other→.env); rotation=quarterly if `sensitivityTier ≠ standard`, else annual

### Sec.Q3: "Vulnerability scanning — which tools? Cadence?"
- **Type**: Multi-select (with cadence per selection)
- **Options**: "Dependency scanning (Dependabot/Snyk)" | "SAST (Semgrep/CodeQL)" | "DAST (ZAP/Burp)" | "Container scanning" | "None"
- **Condition**: Always
- **Updates**: `security.scanning`
- **Default**: `["Dependency scanning (Dependabot)"]` for standard; add SAST for elevated; add DAST + container for high

### Sec.Q4: "Threat model approach?"
- **Type**: Choice
- **Options**: "STRIDE-lite checklist" | "Formal threat-modeling session" | "None"
- **Condition**: Always
- **Updates**: `security.threatModel`
- **Default**: "STRIDE-lite" for elevated; "Formal" for high; "None" for standard

### Sec.Q5: "Encryption at rest — DB default, per-column for PII, app-managed?"
- **Type**: Multi-select
- **Options**: "DB-default" | "Per-column for PII fields" | "App-managed (envelope encryption)"
- **Condition**: Always
- **Updates**: `security.encryptionAtRest`
- **Default**: `["DB-default"]` for standard; add per-column for elevated when PII present; add app-managed for high

### Sec.Q6: "Encryption in transit — TLS everywhere, mTLS for service-to-service, HSTS posture?"
- **Type**: Object (TLS, mTLS, HSTS)
- **Condition**: Always
- **Updates**: `security.encryptionInTransit`
- **Default**: TLS=true; mTLS=true if `architecturalFraming.topology='microservices'`; HSTS=preload for elevated+high, normal otherwise

### Sec.Q7: "Default security headers — CORS, CSP, X-Frame-Options?"
- **Type**: Object
- **Condition**: `apiIntegration.exposesAPI = true` OR `hasFrontend = true`
- **Updates**: `security.headers`
- **Default**: CORS=allowlist; CSP=strict for sensitivityTier ≠ standard, basic otherwise; X-Frame-Options=DENY

### Sec.Q8: "Input validation policy — boundaries only or everywhere? Library choice?"
- **Type**: Object (policy, library)
- **Options for library**: "Zod" | "Yup" | "Joi" | "pydantic" | "framework-native"
- **Condition**: `apiIntegration.exposesAPI = true`
- **Updates**: `security.inputValidation`
- **Default**: policy=boundaries-only; library by `stack.stack.language` (TS→Zod, Python→pydantic, else framework-native)

### Sec.Q9: "Audit log retention — window? Tamper-evidence?"
- **Type**: Object (retentionWindow, tamperEvidence)
- **Options for tamperEvidence**: "Hash chain" | "Write-once storage" | "None"
- **Condition**: `security.sensitivityTier ≠ standard`
- **Updates**: `security.auditRetention`
- **Default**: retentionWindow=6yr (HIPAA) / 7yr (PCI) / 1yr otherwise; tamperEvidence=hash-chain for high, none for elevated

### Sec.Q10: "Incident response — runbook style and notification SLA?"
- **Type**: Object (runbookStyle, notificationSLA)
- **Condition**: Always
- **Updates**: `security.ir`
- **Default**: runbookStyle=markdown-in-repo; notificationSLA=1hr for high, 4hr for elevated, 24hr otherwise; cross-ref `runtimeOperations.incidentProcess`

### Sec.Q11: "Pentest / security audit cadence?"
- **Type**: Choice
- **Options**: "Annual" | "Quarterly" | "Continuous" | "None"
- **Condition**: `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}` OR `security.sensitivityTier ≠ standard`
- **Updates**: `security.pentestCadence`
- **Default**: "Annual" for elevated; "Quarterly" for high; auto-skipped (none) for hobby + standard

### Sec.Q12: "Bug bounty / VDP?"
- **Type**: Choice
- **Options**: "None" | "Private program" | "Public program"
- **Condition**: `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}` OR `security.sensitivityTier = 'high'`
- **Updates**: `security.vdp`
- **Default**: "None" for elevated; "Private program" for high; auto-skipped otherwise

### Sec.Q13: "Supply chain posture?"
- **Type**: Object (lockfilePinning, signedCommits, sbom, provenance)
- **Condition**: Always
- **Updates**: `security.supplyChain`
- **Default**: lockfilePinning=true (always); signedCommits=true for elevated+high; sbom=true for high; provenance=true if compliance includes SOC2
```

- [ ] **Step 2: Migrate Q4.5 → Sec.Q1**

In the same file, find the `### Q4.5: "How security-sensitive is this project?"` entry in `## Category 4: Workflow (adaptive)`. Replace its body with a single redirect line:

```markdown
### Q4.5: (moved to Sec.Q1 in Round 3)
- Moved to Step 7 (Security) — see `### Sec.Q1`
```

(Keep the heading so cross-references in other docs don't break.)

- [ ] **Step 3: Migrate Q3.9 → Sec.Q2**

Similarly, find `### Q3.9: "How do you want to manage environment variables and secrets?"` in `## Category 3 (residual)`. Replace its body with:

```markdown
### Q3.9: (moved to Sec.Q2 in Round 3)
- Moved to Step 7 (Security) — see `### Sec.Q2`
```

- [ ] **Step 4: Update the Round 2 note at the top of Cat 3**

Find the existing `> **Round 2 note (2026-05-13):**` block at the top of `## Category 3 (residual)`. Append a new bullet to the "Moved" list:

```markdown
> - **Round 3 (2026-05-14): Q3.3** (auth) → Step 5 Auth.Q1, **Q3.6** (monitoring) → Step 8 Ops.Q4/Q5/Q6, **Q3.9** (env vars/secrets) → Step 7 Sec.Q2.
```

(Q3.3 + Q3.6 migrations will be completed in T14 + T15 — leave both placeholders here for now.)

- [ ] **Step 5: Verify**

Run: `grep -c '^### Sec\.Q' greenfield/skills/context-gathering/references/question-bank.md`

Expected: `13`.

Run: `grep -A2 '^### Q4.5:' greenfield/skills/context-gathering/references/question-bank.md`

Expected: shows the moved-to-Sec.Q1 redirect.

- [ ] **Step 6: Commit T13**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "$(cat <<'EOF'
feat(greenfield): add Step 7 Security question bank (13 Qs) + migrate Q4.5 + Q3.9

Adds Sec.Q1-Q13 with stack-derived default rules. Sec.Q1 supersedes
Q4.5 (security sensitivity, expanded to 3 tiers). Sec.Q2 supersedes
Q3.9 (env vars/secrets, expanded with rotation cadence). Old entries
become redirect stubs. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Author Runtime Operations Q-bank entries (14 Qs) + split Q3.6 + reduce P4.Q7

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Add the `## Step 8: Runtime Operations (14 questions)` section**

In `greenfield/skills/context-gathering/references/question-bank.md`, insert a new top-level section AFTER `## Step 7: Security (13 questions)`:

```markdown
## Step 8: Runtime Operations (14 questions)

> **Round 3 (alpha.4):** Runtime Operations is the last new phase before Cat 3 residual (now Step 9). Ops.Q1-Q3 supersede P4.Q7 detail; Ops.Q4-Q6 split former Q3.6. Synthesis output: `docs/adr/runtime-operations.html` + `.md`.

### Ops.Q1: "What background job system will you use?"
- **Type**: Choice (research-informed)
- **Options**: Dynamically generated from stack research; baseline options include "Redis/BullMQ", "Sidekiq (Ruby)", "Celery (Python)", "SQS (AWS)", "Cloud Tasks (GCP)", "Inngest", "Temporal", "Platform-native", "None"
- **Condition**: `apiIntegration.asyncPattern != 'no'`
- **Updates**: `runtimeOperations.jobs`
- **Default**:
  - If `stack.stack.framework='next'` AND `Q3.4.deployTarget='vercel'` → `"Inngest"` (greenfield opinion: Inngest is the Vercel-native choice with zero-infra setup)
  - If `stack.stack.language='ruby'` → `"Sidekiq"`
  - If `stack.stack.language='python'` → `"Celery"`
  - If `Q3.4.deployTarget='aws'` → `"SQS"`
  - If `Q3.4.deployTarget='gcp'` → `"Cloud Tasks"`
  - If `architecturalFraming.scaleTarget='hobby'` → `"None"`
  - Else → `"Redis/BullMQ"` (greenfield opinion: BullMQ is the most universally portable JS option)

### Ops.Q2: "Retry strategy and idempotency model for background jobs?"
- **Type**: Object (deliveryGuarantee, retryPolicy, deadLetterQueue)
- **Options for deliveryGuarantee**: "At-least-once" | "Exactly-once" | "At-most-once"
- **Condition**: `runtimeOperations.jobs ≠ none`
- **Updates**: `runtimeOperations.retryStrategy`
- **Default**: deliveryGuarantee=at-least-once; retryPolicy=exponential-backoff-3x; deadLetterQueue=enabled

### Ops.Q3: "Scheduled tasks — distributed scheduler or platform cron?"
- **Type**: Choice
- **Options**: "Distributed (BullMQ delayed, Temporal)" | "Platform cron (Vercel Cron, GH Actions, k8s CronJob)" | "None"
- **Condition**: `apiIntegration.asyncPattern ≠ no`
- **Updates**: `runtimeOperations.scheduling`
- **Default**: by `Q3.4.deployTarget` — Vercel→Vercel Cron, k8s→CronJob, AWS→EventBridge, other→GH Actions cron

### Ops.Q4: "Metrics — which backend?"
- **Type**: Choice
- **Options**: "Prometheus + Grafana" | "DataDog" | "Grafana Cloud" | "Platform-native (Vercel Analytics, CloudWatch)" | "None"
- **Condition**: Always
- **Updates**: `runtimeOperations.metrics`
- **Default**: "Platform-native" for hobby + startup; "DataDog" for enterprise; "Prometheus + Grafana" for production-scale with self-hosted/k8s; "None" for hobby with no signals

### Ops.Q5: "Distributed traces?"
- **Type**: Object (otel, backend)
- **Options for backend**: "Honeycomb" | "DataDog APM" | "Grafana Tempo" | "Jaeger" | "None"
- **Condition**: `architecturalFraming.topology ∈ {microservices, modular}` OR `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}`
- **Updates**: `runtimeOperations.traces`
- **Default**: otel=true; backend by topology — microservices+enterprise→DataDog APM, production-scale→Honeycomb, else→none

### Ops.Q6: "Logs — structured format and aggregator?"
- **Type**: Object (format, aggregator, retention)
- **Options for aggregator**: "Loki" | "Logtail" | "DataDog" | "CloudWatch" | "Platform-native" | "stdout only"
- **Condition**: Always
- **Updates**: `runtimeOperations.logs`
- **Default**: format=JSON-structured; aggregator by deployTarget (Vercel→platform, AWS→CloudWatch, k8s→Loki); retention=30d for hobby, 1yr for production+

### Ops.Q7: "Alerting and paging tool?"
- **Type**: Object (tool, thresholdStrategy)
- **Options for tool**: "PagerDuty" | "OpsGenie" | "Slack webhook" | "Discord webhook" | "Email" | "None"
- **Condition**: Always (locked ≠ none if `security.sensitivityTier = high`)
- **Updates**: `runtimeOperations.alerting`
- **Default**: tool=Slack webhook for startup+production; PagerDuty for enterprise+high tier; None for hobby (unless tier=high — then forced to Slack at minimum)

### Ops.Q8: "SLI / SLO — which metrics? Error budget policy?"
- **Type**: Object (metrics, errorBudget)
- **Condition**: `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}`
- **Updates**: `runtimeOperations.slo`
- **Default**: metrics=[availability, latencyP99, error-rate]; errorBudget=99.9% (3-9s) for production-scale, 99.95% (3.5-9s) for enterprise; auto-skipped otherwise

### Ops.Q9: "Feature flag system?"
- **Type**: Object (provider, lifecycle)
- **Options for provider**: "LaunchDarkly" | "Unleash" | "PostHog" | "Flagsmith" | "config-file flags" | "None"
- **Condition**: Always
- **Updates**: `runtimeOperations.featureFlags`
- **Default**: provider=config-file flags for hobby; PostHog for startup; LaunchDarkly for enterprise; lifecycle=tagged-for-cleanup

### Ops.Q10: "Maintenance mode / graceful degradation?"
- **Type**: Object (mechanism, userExperience)
- **Options for mechanism**: "DB flag" | "Env var + redeploy" | "CDN rule" | "Platform-managed"
- **Condition**: `isProduction = true`
- **Updates**: `runtimeOperations.maintenanceMode`
- **Default**: mechanism=DB flag; userExperience=branded maintenance page; skipped for hobby

### Ops.Q11: "Health check endpoints — liveness, readiness, deep?"
- **Type**: Object (liveness, readiness, deep)
- **Condition**: `apiIntegration.exposesAPI = true`
- **Updates**: `runtimeOperations.healthChecks`
- **Default**: liveness=/healthz (always); readiness=/readyz (when k8s); deep=/healthz/deep (production+ with downstream deps); by `architecturalFraming.deploymentShape` (k8s→all three, serverless→liveness only)

### Ops.Q12: "Runbooks — storage path, template style, ownership?"
- **Type**: Object
- **Condition**: Always
- **Updates**: `runtimeOperations.runbooks`
- **Default**: storagePath=docs/runbooks/; templateStyle=incident-checklist-md; ownership=DRI rotation (hobby→solo); skipped for hobby tier

### Ops.Q13: "Incident process — severity levels, escalation, postmortem template?"
- **Type**: Object
- **Condition**: `isProduction = true`
- **Updates**: `runtimeOperations.incidentProcess`
- **Default**: severityLevels=[SEV1, SEV2, SEV3]; escalation=on-call→engineering manager→CTO (chain by scaleTarget); postmortem=Google-template; skipped for hobby

### Ops.Q14: "On-call rotation tool?"
- **Type**: Choice
- **Options**: "PagerDuty schedule" | "OpsGenie schedule" | "Discord bot rotation" | "None"
- **Condition**: `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}` OR `security.sensitivityTier = high`
- **Updates**: `runtimeOperations.onCall`
- **Default**: PagerDuty for enterprise; OpsGenie if `Q3.4.deployTarget=aws`; None for hobby+startup
```

- [ ] **Step 2: Split Q3.6 → Ops.Q4 + Ops.Q5 + Ops.Q6**

In `## Category 3 (residual)`, find `### Q3.6: "What's your monitoring and observability strategy?"`. Replace its body with:

```markdown
### Q3.6: (split across Step 8 in Round 3)
- "Logging framework" → Step 8 Ops.Q6 (logs)
- "Error tracking" → Step 8 Ops.Q5 (traces / error tracking)
- "Analytics" → deferred to Round 6 (frontend / product analytics)
- "Uptime monitoring" → Step 8 Ops.Q4 (metrics + uptime)
```

- [ ] **Step 3: Reduce P4.Q7 to pointer**

Find `### P4.Q7:` in the `## Step 4: API & Integration (10 questions)` section. Replace its body with:

```markdown
### P4.Q7: "Does this app have async background work?"
- **Type**: Choice
- **Options**: "Yes" | "No"
- **Condition**: `apiIntegration.exposesAPI = true`
- **Updates**: `apiIntegration.asyncPattern`
- **Default**: `"Yes"` if `architecturalFraming.scaleTarget ∈ {production-scale, enterprise}` else `"No"`
- **Note**: Full background job configuration moved to Step 8 Runtime Operations (Ops.Q1-Q3).
```

- [ ] **Step 4: Verify**

Run: `grep -c '^### Ops\.Q' greenfield/skills/context-gathering/references/question-bank.md`

Expected: `14`.

Run: `grep -B1 -A6 '^### P4.Q7:' greenfield/skills/context-gathering/references/question-bank.md`

Expected: 1-line entry referencing Step 8.

- [ ] **Step 5: Commit T14**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "$(cat <<'EOF'
feat(greenfield): add Step 8 Runtime Operations bank (14 Qs) + split Q3.6 + reduce P4.Q7

Adds Ops.Q1-Q14 with stack-derived default rules. Q3.6 splits into
Ops.Q4 (metrics+uptime), Ops.Q5 (traces+error tracking), Ops.Q6 (logs).
Q3.6 product-analytics deferred to Round 6 frontend phase. P4.Q7
reduced to a 1-line pointer (full background job config moved to
Ops.Q1-Q3). Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Cat 3 + Cat 4 residual cleanup (remove migrated Qs)

**Files:**
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Migrate Q3.3 → Auth.Q1**

In `## Category 3 (residual)`, find `### Q3.3: "How do you want to handle authentication?"`. Replace its body with:

```markdown
### Q3.3: (moved to Auth.Q1 in Round 3)
- Moved to Step 5 (Auth) — see `### Auth.Q1`
```

- [ ] **Step 2: Update the Round 2 note at the top of Cat 3 to consolidate Round 3 migrations**

The note added in T13 Step 4 should now reflect the full migration set. Update it to read:

```markdown
> **Round 3 note (2026-05-14):** Q3.3 (auth) → Step 5 Auth.Q1. Q3.6 (monitoring) → Step 8 Ops.Q4/Q5/Q6 (product analytics deferred to Round 6). Q3.9 (env vars/secrets) → Step 7 Sec.Q2.
> **Staying here:** Q3.1, Q3.4, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 (10 Qs total — down from 13).
```

- [ ] **Step 3: Update the Cat 4 header note**

Find `## Category 4: Workflow (adaptive)`. Add an updated note below the header:

```markdown
> **Round 3 (2026-05-14):** Q4.5 (security sensitivity) → Step 7 Sec.Q1. Cat 4 retains 6 Qs (Q4.1-Q4.4, Q4.6, Q4.7).
```

- [ ] **Step 4: Verify the residual Cat 3 + Cat 4 count**

Run: `awk '/^## Category 3/,/^## Category 4/' greenfield/skills/context-gathering/references/question-bank.md | grep -c '^### Q3\.' | head -1`

Expected: 13 entries total (10 active + 3 redirect stubs).

Run: `awk '/^## Category 4/,/^## Category 5/' greenfield/skills/context-gathering/references/question-bank.md | grep -c '^### Q4\.' | head -1`

Expected: 7 entries (6 active + 1 redirect stub).

- [ ] **Step 5: Commit T15**

```bash
git add greenfield/skills/context-gathering/references/question-bank.md
git commit -m "$(cat <<'EOF'
refactor(greenfield): finalize Cat 3 + Cat 4 residual migration for Round 3

Migrate Q3.3 → Auth.Q1 (moved in Round 3). Update Cat 3 + Cat 4 header
notes to reflect final migration set: 5 Qs moved out (Q3.3, Q3.6,
Q3.9, Q4.5, P4.Q7-detail), 16 Qs remain in residual (10 Cat 3 + 6 Cat
4). Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Consolidate defaults-derivation.md additions

**Files:**
- Modify: `greenfield/skills/synthesis-review/references/defaults-derivation.md`
- Create: `docs/greenfield-3.0-round3/phase-q-derivation-rules.md`

- [ ] **Step 1: Read existing defaults-derivation.md structure**

Run: `grep -n '^## \|^### ' greenfield/skills/synthesis-review/references/defaults-derivation.md`

Expected: existing sections covering P3, P4, P8 derivation rules, the stack-research contract, and the greenfield-opinion fallback policy. Round 3 adds 4 new derivation blocks.

- [ ] **Step 2: Append 4 new derivation rule blocks**

After the last existing block (likely apiIntegration), insert:

```markdown
## auth — Round 3 derivation rules

Refer to `question-bank.md § Step 5: Auth` for the full rule set on each Q.
Summary of cross-phase dependencies the rules consume:

- `stack.stack.framework` → strategy provider preselection (Next→Clerk, Django→built-in, Rails→Devise/built-in)
- `Q3.4.deployTarget` → strategy preselection (Vercel→Clerk; AWS+enterprise→Cognito)
- `architecturalFraming.scaleTarget` → strategy + MFA defaults
- `architecturalFraming.topology` → Auth.Q7 (service-to-service) visibility
- `dataArchitecture.engine` → Auth.Q5 RLS feasibility
- `dataArchitecture.multiTenancy` → Auth.Q6 tenant resolution visibility
- `dataArchitecture.compliance` → Auth.Q4 MFA locked + Auth.Q11 audit retention locked

## privacy — Round 3 derivation rules

Refer to `question-bank.md § Step 6: Privacy` for the full rule set on each Q.
Summary of cross-phase dependencies:

- `auth.strategy='none'` → Privacy.Gate fires + skip-cascade
- `dataArchitecture.compliance` → Privacy.Q1 pre-population
- `apiIntegration.externalServices` → Privacy.Q8 (processors) pre-population
- `architecturalFraming.scaleTarget='enterprise'` → broader regulatory default

## security — Round 3 derivation rules

Refer to `question-bank.md § Step 7: Security` for the full rule set on each Q.
Summary of cross-phase dependencies:

- `dataArchitecture.compliance` non-empty → Sec.Q1 locked to High
- `apiIntegration.externalServices` includes payment providers → Sec.Q1 default Elevated
- `privacy.piiCategories` non-empty → Sec.Q1 default Elevated
- `architecturalFraming.scaleTarget='hobby'` → Sec.Q11/Q12 auto-skip
- `architecturalFraming.topology='microservices'` → Sec.Q6 mTLS suggested

## runtimeOperations — Round 3 derivation rules

Refer to `question-bank.md § Step 8: Runtime Operations` for the full rule set on each Q.
Summary of cross-phase dependencies:

- `apiIntegration.asyncPatternPattern='none'` → Ops.Q1-Q3 skip-cascade
- `Q3.4.deployTarget` → Ops.Q1 (jobs) + Ops.Q3 (scheduling) + Ops.Q11 (health checks) provider defaults
- `security.sensitivityTier='high'` → Ops.Q7 (alerting) locked ≠ none
- `architecturalFraming.scaleTarget ∉ {production-scale, enterprise}` → Ops.Q8 (SLO) skip
```

- [ ] **Step 3: Create the all-50 catalog at `docs/greenfield-3.0-round3/phase-q-derivation-rules.md`**

Create `docs/greenfield-3.0-round3/phase-q-derivation-rules.md` with a complete table of all 50 Round 3 Qs and their derivation rules — this is the single referenceable doc for future audits/maintenance.

```markdown
# Round 3 — Stack-Derived Default Rules for All 50 Qs

Single-source-of-truth catalog. Each row lists the Q, its consumed signals, and the produced default. Source: `greenfield/skills/context-gathering/references/question-bank.md`.

## Auth (12 Qs)

| Q | Consumed signals | Default |
|---|---|---|
| Auth.Q1 | framework, deployTarget, scaleTarget | (see question-bank for full rule) |
| Auth.Q2 | … | … |
| … | … | … |

## Privacy (11 Qs)

| Q | Consumed signals | Default |
|---|---|---|
| Privacy.Q1 | dataArchitecture.compliance, scaleTarget | … |
| … | … | … |

## Security (13 Qs)

| Q | Consumed signals | Default |
|---|---|---|
| Sec.Q1 | compliance, externalServices, piiCategories, scaleTarget | … |
| … | … | … |

## Runtime Operations (14 Qs)

| Q | Consumed signals | Default |
|---|---|---|
| Ops.Q1 | framework, deployTarget, language, scaleTarget | … |
| … | … | … |
```

Populate each row by lifting the default-derivation summary from the corresponding Q-bank entry. Keep cells compact — full rule text stays in `question-bank.md`.

- [ ] **Step 4: Commit T16**

```bash
git add greenfield/skills/synthesis-review/references/defaults-derivation.md docs/greenfield-3.0-round3/phase-q-derivation-rules.md
git commit -m "$(cat <<'EOF'
docs(greenfield): catalog Round 3 derivation rules

Extend defaults-derivation.md with 4 new derivation summary blocks
(auth, privacy, security, runtimeOperations) and create a single
auditable all-50 catalog at docs/greenfield-3.0-round3/. Part of
greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Insert Step 5 Auth into context-gathering SKILL.md

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Read the structure of an existing Step entry**

Run: `sed -n '270,315p' greenfield/skills/context-gathering/SKILL.md`

Note the `### Step 4 of 11: API & Integration` pattern: stale entry-guard → state checkpointing → wizard run → inline synthesis-review invocation → return-to-flow note.

- [ ] **Step 2: Insert `### Step 5 of 15: Auth` entry**

In `greenfield/skills/context-gathering/SKILL.md`, insert a new step section AFTER the existing `### Step 4 of 11: API & Integration` block (which will become `Step 4 of 15: API & Integration` in T22) and BEFORE the existing `### Step 5 of 11: Remaining Project Details (residual)` (which becomes Step 9):

```markdown
### Step 5 of 15: Auth

Emit the progress indicator. This step gathers identity and access control decisions: strategy, identity providers, session model, MFA, authorization, tenancy, service-to-service auth, lifecycle, recovery, password policy, audit log, enforcement point. About 12 questions; some may be skipped based on `auth.strategy` and earlier framing/data/api answers.

**Stale entry-guard** (check before any wizard prompt fires for this step): if `completedSteps` already contains `"step-5-auth"` AND `context.phaseStatus.auth.status === "stale"`, skip re-asking the wizard questions and proceed directly to the synthesis-review call. Synthesis-review Step 0 will surface the re-walk prompt.

Tell the developer (verbatim):

> Step 5 of 15: Auth. I'll ask about authentication strategy, identity providers, session model, MFA, authorization, and audit. About 12 questions. Some may be skipped based on your earlier framing and data decisions.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 5: Auth` in order. Honor the conditions. Write each answer to its destination field under `context.phases.auth`.

**State checkpointing**: after each answered question, write to `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-5-auth"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "auth")
```

This will render `docs/adr/auth.md` + `docs/adr/auth.html` and walk the developer through approve/adjust/skip for each section. Returns control here with `phaseStatus.auth.status` updated.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `auth.html`/`.md` ship in Round 3), tell the developer and continue to Step 6.
```

- [ ] **Step 3: Verify the entry inserts at the correct location**

Run: `grep -n '^### Step' greenfield/skills/context-gathering/SKILL.md`

Expected: `### Step 5 of 15: Auth` now appears after `### Step 4 of 11: API & Integration`. (The existing Step entries still say "of 11" — they'll be renumbered in T22.)

- [ ] **Step 4: Commit T17**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): insert Step 5 Auth in context-gathering wizard

Adds Step 5 of 15 entry with stale entry-guard, state checkpointing,
12-Q inline wizard run, and inline synthesis-review invocation for
phaseId='auth'. Subsequent step renumbering follows in T21. Part of
greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: Insert Step 6 Privacy + skip-cascade gate logic

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Insert `### Step 6 of 15: Privacy` entry**

In `greenfield/skills/context-gathering/SKILL.md`, AFTER the new Step 5 Auth block from T17, insert:

```markdown
### Step 6 of 15: Privacy

Emit the progress indicator. This step classifies the data and gates regulatory scope. If `auth.strategy = 'none'`, the wizard fires a single-Q gate FIRST. If the gate returns "No data collected", Privacy synthesis is rendered as an n/a stub and Q1-Q11 are skipped.

**Stale entry-guard**: if `completedSteps` already contains `"step-6-privacy"` AND `context.phaseStatus.privacy.status === "stale"`, skip re-asking the wizard questions and proceed directly to the synthesis-review call.

**Skip-cascade gate (only if `auth.strategy === 'none'`):**

Ask the Privacy.Gate question first:

> Do you collect any user data at all — emails, IPs, behavioral analytics, contact form submissions?

If the answer is "No":
- Set `context.phases.privacy.synthesisStatus = "n/a"`
- Set `context.phaseStatus.privacy.status = "skipped"` (NOT "complete" — required so the skip-cascade reversal logic in `pickup` can detect a later un-skip)
- Skip Q1-Q11 entirely
- Invoke `Skill(synthesis-review, phaseId: "privacy")` — synthesis-review will render the n/a stub template and confirm with developer
- Proceed to Step 7

If the answer is "Yes":
- Set `context.phases.privacy.synthesisStatus = "complete"`
- Continue to Q1-Q11 below

**If `auth.strategy !== 'none'`**, skip the gate entirely and start at Q1.

Tell the developer (verbatim, after the gate decision):

> Step 6 of 15: Privacy. I'll ask about regulatory scope, PII inventory, consent, retention, deletion, DSAR, and data residency. About 11 questions; some may be skipped based on regulations and data architecture.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 6: Privacy` (excluding the Gate, which already ran) in order. Honor the conditions. Write each answer to its destination field under `context.phases.privacy`.

**State checkpointing**: after each answered question, write `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-6-privacy"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "privacy")
```

If `synthesisStatus: "n/a"` was set by the gate, synthesis-review uses the stub template.

If the synthesis-review skill returns `synthesisStatus: "no-template"`, tell the developer and continue to Step 7.
```

- [ ] **Step 2: Verify**

Run: `grep -n '^### Step' greenfield/skills/context-gathering/SKILL.md`

Expected: Step 6 of 15: Privacy now appears after Step 5 Auth.

- [ ] **Step 3: Commit T18**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): insert Step 6 Privacy with skip-cascade gate logic

Adds Step 6 of 15 entry. When auth.strategy='none', wizard fires
Privacy.Gate first; 'No' answer triggers synthesisStatus='n/a' stub
and phaseStatus='skipped' (enabling un-skip detection in pickup).
Q1-Q11 run only when synthesisStatus='complete'. Part of greenfield
3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 19: Insert Step 7 Security into context-gathering SKILL.md

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Insert `### Step 7 of 15: Security` entry**

After Step 6 Privacy, insert:

```markdown
### Step 7 of 15: Security

Emit the progress indicator. This step covers application security posture: sensitivity tier, secret management, vulnerability scanning, threat model, encryption, headers, input validation, audit retention, IR pointer, pentest cadence, VDP, supply chain. About 13 questions; some may be skipped based on `security.sensitivityTier` and `architecturalFraming.scaleTarget`.

**Stale entry-guard**: if `completedSteps` already contains `"step-7-security"` AND `context.phaseStatus.security.status === "stale"`, skip re-asking wizard questions and proceed directly to the synthesis-review call.

Tell the developer (verbatim):

> Step 7 of 15: Security. I'll ask about sensitivity tier, secret management, vulnerability scanning, threat model, encryption, audit logging, incident response, and supply chain. About 13 questions. Some may be skipped for hobby-scale projects.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 7: Security` in order. Honor the conditions. Write each answer to its destination field under `context.phases.security`.

**State checkpointing**: set `currentStep: "step-7-security"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "security")
```

If the synthesis-review skill returns `synthesisStatus: "no-template"`, tell the developer and continue to Step 8.
```

- [ ] **Step 2: Verify + Commit T19**

Run: `grep -n '^### Step' greenfield/skills/context-gathering/SKILL.md`

Expected: Step 7 of 15: Security appears after Step 6.

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): insert Step 7 Security in context-gathering wizard

Adds Step 7 of 15 entry with stale entry-guard, 13-Q inline wizard run,
inline synthesis-review invocation for phaseId='security'. Part of
greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 20: Insert Step 8 Runtime Operations into context-gathering SKILL.md

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Insert `### Step 8 of 15: Runtime Operations` entry**

After Step 7 Security, insert:

```markdown
### Step 8 of 15: Runtime Operations

Emit the progress indicator. This step covers background jobs, observability, alerting, feature flags, maintenance mode, health checks, runbooks, incident process, and on-call. About 14 questions; Ops.Q1-Q3 (jobs/retry/scheduling) skip when `apiIntegration.asyncPatternPattern='none'`. Ops.Q8 (SLO) skips for non-production scale targets.

**Stale entry-guard**: if `completedSteps` already contains `"step-8-runtime-ops"` AND `context.phaseStatus.runtimeOperations.status === "stale"`, skip re-asking wizard questions and proceed directly to the synthesis-review call.

Tell the developer (verbatim):

> Step 8 of 15: Runtime Operations. I'll ask about background jobs, observability (metrics/traces/logs), alerting, feature flags, maintenance mode, health checks, runbooks, and incident response. About 14 questions. Some are skipped for hobby projects or no-async-work setups.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 8: Runtime Operations` in order. Honor the conditions. Write each answer to its destination field under `context.phases.runtimeOperations`.

**State checkpointing**: set `currentStep: "step-8-runtime-ops"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "runtimeOperations")
```

If the synthesis-review skill returns `synthesisStatus: "no-template"`, tell the developer and continue to Step 9 (residual).
```

- [ ] **Step 2: Verify + Commit T20**

Run: `grep -n '^### Step' greenfield/skills/context-gathering/SKILL.md`

Expected: Step 8 of 15: Runtime Operations appears after Step 7.

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): insert Step 8 Runtime Operations in context-gathering wizard

Adds Step 8 of 15 entry with stale entry-guard, 14-Q inline wizard run,
inline synthesis-review invocation for phaseId='runtimeOperations'.
Skip cascades: Ops.Q1-Q3 hidden when apiIntegration.asyncPatternPattern='none';
Ops.Q8 (SLO) hidden for non-production scale. Part of greenfield 3.0
Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 21: Renumber existing Steps 5–11 → 9–15

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Find every existing step heading and its current number**

Run: `grep -n '^### Step' greenfield/skills/context-gathering/SKILL.md`

Expected to see after T17–T20 inserts (in order of appearance):
- Step 1 of 11
- Step 2 of 11
- Step 2.5 of 11
- Step 3 of 11
- Step 4 of 11
- Step 5 of 15: Auth (new from T17)
- Step 6 of 15: Privacy (new from T18)
- Step 7 of 15: Security (new from T19)
- Step 8 of 15: Runtime Operations (new from T20)
- Step 5 of 11: Remaining Project Details (residual) — TO RENAME
- Step 5.5 of 11: Pain Points (always ask) — TO RENAME
- Step 6 of 11: Workflow Preferences (Category 4) — TO RENAME
- Step 7 of 11: CI/CD & Auto-Evolution — TO RENAME
- Step 8 of 11: Feature Decomposition — TO RENAME
- Step 9 of 11: Confirmation — TO RENAME
- Step 10 of 11: Phase 1.5 Architectural Research — TO RENAME
- Step 11 of 11: Architectural Validation — TO RENAME

- [ ] **Step 2: Renumber in reverse order to avoid number collisions**

Apply these renames one at a time (use Edit tool with unique-enough context):

| From | To |
|---|---|
| `### Step 11 of 11: Architectural Validation` | `### Step 15 of 15: Architectural Validation` |
| `### Step 10 of 11: Phase 1.5 Architectural Research` | `### Step 14 of 15: Phase 1.5 Architectural Research` |
| `### Step 9 of 11: Confirmation` | `### Step 13 of 15: Confirmation` |
| `### Step 8 of 11: Feature Decomposition` | `### Step 12 of 15: Feature Decomposition` |
| `### Step 7 of 11: CI/CD & Auto-Evolution` | `### Step 11 of 15: CI/CD & Auto-Evolution` |
| `### Step 6 of 11: Workflow Preferences` | `### Step 10 of 15: Workflow Preferences` |
| `### Step 5.5 of 11: Pain Points (always ask)` | `### Step 9.5 of 15: Pain Points (always ask)` |
| `### Step 5 of 11: Remaining Project Details (residual)` | `### Step 9 of 15: Remaining Project Details (residual)` |

For each, run Edit with sufficient context to ensure unique replacement.

- [ ] **Step 3: Renumber the early steps (1–4 and 2.5)**

| From | To |
|---|---|
| `### Step 1 of 11: Project Vision` | `### Step 1 of 15: Project Vision` |
| `### Step 2 of 11: Tech Stack` | `### Step 2 of 15: Tech Stack` |
| `### Step 2.5 of 11: Architectural Framing` | `### Step 2.5 of 15: Architectural Framing` |
| `### Step 3 of 11: Data Architecture` | `### Step 3 of 15: Data Architecture` |
| `### Step 4 of 11: API & Integration` | `### Step 4 of 15: API & Integration` |

- [ ] **Step 4: Update inline `Step X of 11` references in step bodies**

These appear in the verbatim prompts told to the developer ("Step 3 of 11: Data Architecture …"). Use replace_all when safe (e.g., `Step 3 of 11:` is unique enough):

For each old step, find and update the verbatim prompt:
- `Step 1 of 11` → `Step 1 of 15` (in the verbatim block, NOT in section heading — already done)
- `Step 2 of 11` → `Step 2 of 15`
- `Step 2.5 of 11` → `Step 2.5 of 15`
- `Step 3 of 11` → `Step 3 of 15`
- `Step 4 of 11` → `Step 4 of 15`
- `Step 5 of 11` → `Step 9 of 15`
- `Step 5.5 of 11` → `Step 9.5 of 15`
- `Step 6 of 11` → `Step 10 of 15`
- `Step 7 of 11` → `Step 11 of 15`
- `Step 8 of 11` → `Step 12 of 15`
- `Step 9 of 11` → `Step 13 of 15`
- `Step 10 of 11` → `Step 14 of 15`
- `Step 11 of 11` → `Step 15 of 15`

Use Read + Edit with surrounding context for each, since some quoted prompts may include adjacent words.

- [ ] **Step 5: Update progress-indicator template**

Find (line ~98 in the file): `Wizard progress: Step [X] of 11 — [step name]`. Replace with: `Wizard progress: Step [X] of 15 — [step name]`.

- [ ] **Step 6: Update the description frontmatter**

The skill's YAML frontmatter `description` field currently includes `through 11 named Steps`. Update to `through 15 named Steps`.

- [ ] **Step 7: Verify no `of 11` remains**

Run: `grep -n 'of 11' greenfield/skills/context-gathering/SKILL.md`

Expected: no output. If anything matches, fix it.

- [ ] **Step 8: Commit T21**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "$(cat <<'EOF'
refactor(greenfield): renumber wizard steps 11 → 15 for Round 3 phases

Inserts Step 5 (Auth) through Step 8 (Runtime Ops) shift all later
steps by +4: residual 5 → 9, 5.5 → 9.5, workflow 6 → 10, cicd 7 → 11,
feature-decomp 8 → 12, confirmation 9 → 13, arch-research 10 → 14,
arch-validation 11 → 15. Updates progress-indicator template, verbatim
prompts, and frontmatter description. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 22: Extend state-transitions table for 4 new phases

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`
- Modify: `greenfield/skills/pickup/SKILL.md`
- Modify: `greenfield/skills/check/SKILL.md`

- [ ] **Step 1: Locate state-transitions table in each file**

Run: `grep -n 'state-transitions\|currentStep\|state-machine' greenfield/skills/context-gathering/SKILL.md greenfield/skills/pickup/SKILL.md greenfield/skills/check/SKILL.md`

Expected: each file has a table listing valid `currentStep` values and their allowed transitions.

- [ ] **Step 2: Add 4 new step entries to context-gathering SKILL.md state table**

Use the same state-machine convention as existing Round 2 phases: the wizard sets `currentPhase: "phase-1-context-gathering"` + `currentStep: "step-X-<name>"` while asking questions, then transitions to `currentPhase: "phase-1.8-synthesis-review"` + `currentSynthesisPhase: "<phaseName>"` for the inline synthesis-review pass, then returns to `phase-1-context-gathering` with `currentStep` set to the next step. There is NO separate `step-X-synthesis-review` step-id — synthesis is its own phase tracked by `currentSynthesisPhase`.

Insert 4 new rows in the state-transitions table (between the `step-4-api-integration` row and what will become the `step-9-residual` row):

| step-id | currentPhase | Valid next state |
|---|---|---|
| `step-5-auth` | `phase-1-context-gathering` | transition to `phase-1.8-synthesis-review` with `currentSynthesisPhase: "auth"`, then return with `currentStep: "step-6-privacy"` |
| `step-6-privacy` (preceded by Privacy.Gate if `auth.strategy='none'`) | `phase-1-context-gathering` | transition to `phase-1.8-synthesis-review` with `currentSynthesisPhase: "privacy"` (uses n/a stub template if synthesisStatus='n/a'), then return with `currentStep: "step-7-security"` |
| `step-7-security` | `phase-1-context-gathering` | transition to `phase-1.8-synthesis-review` with `currentSynthesisPhase: "security"`, then return with `currentStep: "step-8-runtime-ops"` |
| `step-8-runtime-ops` | `phase-1-context-gathering` | transition to `phase-1.8-synthesis-review` with `currentSynthesisPhase: "runtimeOperations"`, then return with `currentStep: "step-9-residual"` (was `step-5-residual`) |

Also update the existing `step-5-residual` row to be renamed `step-9-residual`, and similarly for the rest of the renumbered steps: `step-5.5-pain` → `step-9.5-pain`, `step-6-workflow` → `step-10-workflow`, `step-7-cicd` → `step-11-cicd`, `step-8-feature-decomp` → `step-12-feature-decomp`, `step-9-confirmation` → `step-13-confirmation`, `step-10-arch-research` → `step-14-arch-research`, `step-11-arch-validation` → `step-15-arch-validation`.

- [ ] **Step 3: Apply equivalent updates to pickup/SKILL.md and check/SKILL.md**

Both files have similar state-transitions tables. Apply the same 4 new entries + the rename.

- [ ] **Step 4: Verify**

Run: `grep -c 'step-5-auth\|step-6-privacy\|step-7-security\|step-8-runtime-ops' greenfield/skills/context-gathering/SKILL.md greenfield/skills/pickup/SKILL.md greenfield/skills/check/SKILL.md`

Expected: at least 4 hits per file.

- [ ] **Step 5: Commit T22**

```bash
git add greenfield/skills/context-gathering/SKILL.md greenfield/skills/pickup/SKILL.md greenfield/skills/check/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): extend state-transitions tables for Round 3 phases

Add step-5-auth, step-6-privacy, step-7-security, step-8-runtime-ops
to state-transitions tables in context-gathering, pickup, and check
skills. Rename downstream step-id values to match renumbered steps.
Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 23: Add synthesis-review wiring for 4 new phases

**Files:**
- Modify: `greenfield/skills/synthesis-review/SKILL.md`

- [ ] **Step 1: Read existing wiring for `dataArchitecture`/`apiIntegration`**

Run: `grep -n 'phaseId\|dataArchitecture\|apiIntegration\|architecturalFraming' greenfield/skills/synthesis-review/SKILL.md`

Note: the skill switches on `phaseId` to select a template + section-prompts entry.

- [ ] **Step 2: Add the 4 new phaseId branches**

In `greenfield/skills/synthesis-review/SKILL.md`, find the phaseId switch (or table) that lists valid phases. Add 4 new rows (or branches) for `auth`, `privacy`, `security`, `runtimeOperations`. Each row references its template pair, dependency sidecar, and section-prompts entry.

Example shape of the row (match existing style):

```markdown
| auth | `auth.html` + `auth.md` | `auth-dependencies.json.example` | `## auth` |
| privacy | `privacy.html` + `privacy.md` | `privacy-dependencies.json.example` | `## privacy` |
| security | `security.html` + `security.md` | `security-dependencies.json.example` | `## security` |
| runtimeOperations | `runtime-operations.html` + `runtime-operations.md` | `runtime-operations-dependencies.json.example` | `## runtimeOperations` |
```

- [ ] **Step 3: Update the skill's frontmatter `description` to mention the new phases**

If the frontmatter lists the wired phases by name, add the 4 new ones.

- [ ] **Step 4: Verify**

Run: `grep -c 'auth\|privacy\|security\|runtimeOperations' greenfield/skills/synthesis-review/SKILL.md`

Expected: count includes the new rows (≥4 added).

- [ ] **Step 5: Commit T23**

```bash
git add greenfield/skills/synthesis-review/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): wire synthesis-review for 4 Round 3 phases

Add phaseId switch entries for auth, privacy, security,
runtimeOperations. Each references its template pair, dependency
sidecar, and section-prompts entry. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 24: Add 4 cross-phase consistency checks to grill-spec

**Files:**
- Modify: `greenfield/skills/grill-spec/SKILL.md`

- [ ] **Step 1: Read existing grill-spec cross-checks**

Run: `grep -n 'cross-check\|context.syntheses\|contradiction' greenfield/skills/grill-spec/SKILL.md`

Expected: existing cross-checks for Round 2 phases. Round 3 adds 4 new checks.

- [ ] **Step 2: Append a new "Round 3 cross-phase checks" section**

In `greenfield/skills/grill-spec/SKILL.md`, after the existing cross-check section, insert:

```markdown
## Round 3 cross-phase consistency checks

After Steps 5–8 complete and before scaffold begins, validate these invariants. If any fail, present the contradiction to the developer and offer Adjust loop.

### CHECK-R3-1: Compliance scope coverage
`dataArchitecture.compliance ⊆ privacy.regulations` — every entry in `context.phases.dataArchitecture.compliance` must appear in `context.phases.privacy.regulations`.

> **Violation message:** "Data Architecture declared compliance scope `{missingEntries}`, but Privacy regulations does not include them. Either extend privacy.regulations or remove from dataArchitecture.compliance."

### CHECK-R3-2: Auth required for sensitive compliance
If `context.phases.dataArchitecture.compliance` contains any of `["HIPAA", "PCI-DSS", "SOC 2"]`, then `context.phases.auth.strategy` MUST NOT be `"none"`.

> **Violation message:** "HIPAA/PCI/SOC2 compliance requires user authentication. The current auth.strategy='none' is incompatible. Choose an auth strategy or remove the compliance scope."

### CHECK-R3-3: Security tier matches compliance
If `context.phases.dataArchitecture.compliance` is non-empty, then `context.phases.security.sensitivityTier` MUST be `"elevated"` or `"high"`.

> **Violation message:** "Compliance scope `{compliance}` requires sensitivity tier 'elevated' or 'high'. Current tier='standard'."

### CHECK-R3-4: Alerting required for high sensitivity
If `context.phases.security.sensitivityTier === "high"`, then `context.phases.runtimeOperations.alerting.tool` MUST NOT be `"none"` (or undefined).

> **Violation message:** "High sensitivity tier requires non-trivial alerting (PagerDuty, OpsGenie, or webhook). Current alerting.tool='none'."
```

- [ ] **Step 3: Verify**

Run: `grep -c '^### CHECK-R3-' greenfield/skills/grill-spec/SKILL.md`

Expected: `4`.

- [ ] **Step 4: Commit T24**

```bash
git add greenfield/skills/grill-spec/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): add 4 Round 3 cross-phase consistency checks to grill-spec

Adds CHECK-R3-1 (compliance scope ⊆ privacy.regulations),
CHECK-R3-2 (sensitive compliance forbids auth.strategy='none'),
CHECK-R3-3 (compliance forbids sensitivityTier='standard'), and
CHECK-R3-4 (sensitivityTier='high' requires non-trivial alerting).
Surfaced as Adjust prompts during pre-scaffold validation gate. Part
of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 25: Skip-cascade reversal invariant in pickup

**Files:**
- Modify: `greenfield/skills/pickup/SKILL.md`

- [ ] **Step 1: Find pickup's session-resume logic**

Run: `grep -n 'phaseStatus\|currentStep\|completedSteps' greenfield/skills/pickup/SKILL.md`

Expected: existing resume logic reads `greenfield-state.json` and decides where to drop the developer back into the wizard.

- [ ] **Step 2: Add the skip-cascade reversal invariant**

Find the section that loads the state file and validates phase statuses. Add a new invariant block:

```markdown
### Skip-cascade reversal invariant (Round 3)

When resuming a session, check for the case where a phase was previously skipped via skip-cascade but the cascade's upstream gate has since changed. If detected, prompt the developer to un-skip.

**Detection rule:**

1. If `context.phaseStatus.privacy.status === "skipped"` AND `context.phases.auth.strategy !== "none"`:
   - The skip was triggered by `auth.strategy='none'`. The developer has since changed auth strategy.
   - Tell the developer (verbatim):
     > Your Auth strategy has changed from "none" to "{auth.strategy}", which un-skips the Privacy phase. Would you like to walk through Privacy now?
   - If Yes: set `currentStep: "step-6-privacy"`; clear `phaseStatus.privacy.status`; route into Step 6.
   - If No: keep skipped; emit warning that Privacy synthesis remains stub.

2. If `context.phaseStatus.runtimeOperations.status === "skipped"` AND `context.phases.apiIntegration.asyncPattern === "yes"`:
   - The skip was triggered by `apiIntegration.asyncPatternPattern='none'`. The developer has since changed the async flag.
   - Apply the same un-skip prompt for Step 8.

3. If `context.phases.dataArchitecture.compliance` is non-empty AND `context.phaseStatus.security.status === "skipped"`:
   - The skip was triggered by a hobby tier or empty compliance. Compliance scope now non-empty forbids skipping Security.
   - Tell the developer:
     > Compliance scope `{compliance}` requires Security to be walked. Skipping is not allowed at this tier.
   - Route into Step 7 unconditionally.
```

- [ ] **Step 3: Verify**

Run: `grep -A2 'Skip-cascade reversal' greenfield/skills/pickup/SKILL.md`

Expected: the new invariant block.

- [ ] **Step 4: Commit T25**

```bash
git add greenfield/skills/pickup/SKILL.md
git commit -m "$(cat <<'EOF'
feat(greenfield): add skip-cascade reversal invariant to pickup

Detect when a previously skipped Round 3 phase needs to be un-skipped
because its upstream gate changed. Three cases: auth.strategy ≠ 'none'
un-skips Privacy; apiIntegration.asyncPatternPattern ≠ 'none' un-skips Runtime Ops
jobs; compliance non-empty forbids Security skip. Part of greenfield
3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 26: Update start/check skills + CLAUDE.md files

**Files:**
- Modify: `greenfield/skills/start/SKILL.md`
- Modify: `greenfield/skills/check/SKILL.md`
- Modify: `greenfield/CLAUDE.md`
- Modify: `onboard/CLAUDE.md`

- [ ] **Step 1: Update `greenfield/skills/start/SKILL.md`**

Find the wizard step count references (`of 11`, `11 named Steps`, etc.) and update to `of 15` / `15 named Steps`. Update the error matrix and phase enum to include `auth`, `privacy`, `security`, `runtimeOperations`.

Run: `grep -n '11\|phase enum' greenfield/skills/start/SKILL.md`

Apply Edit for each. Use replace_all where the substring `of 11` is unique enough.

- [ ] **Step 2: Update `greenfield/skills/check/SKILL.md`**

Same as Step 1 — update step count and synthesis HTML count (was probably listed as 3 in Round 2 final state; now should be 7 after Round 3 adds 4).

Run: `grep -n '11\|synthesis HTML count\|of 11' greenfield/skills/check/SKILL.md`

Apply Edit for each.

- [ ] **Step 3: Update `greenfield/CLAUDE.md`**

Find the architecture diagram + step layout section. Update to reflect 15-step wizard with the 4 new Round 3 phases in correct positions. Reference the spec section 1 architecture diagram.

Update the line that says (Round 2.5 state):
> `synthesis-review skill (Phase 1.8 — ... Round 2 / 2.5: Step 2.5 → architecturalFraming, Step 3 → dataArchitecture, Step 4 → apiIntegration, Step 7 → cicdAndDelivery, Step 11 → architecturalValidation)`

To (post-Round-3):
> `synthesis-review skill (Phase 1.8 — ... Round 2 / 2.5 / 3: Step 2.5 → architecturalFraming, Step 3 → dataArchitecture, Step 4 → apiIntegration, Step 5 → auth, Step 6 → privacy, Step 7 → security, Step 8 → runtimeOperations, Step 11 → cicdAndDelivery, Step 15 → architecturalValidation)`

Also update the Skills section that lists wired phases (`context-gathering` description block).

- [ ] **Step 4: Update `onboard/CLAUDE.md`**

Find the phase listing. Add `auth`, `privacy`, `security`, `runtimeOperations` to the live-phases list. Mark Rounds 1–3 as complete.

- [ ] **Step 5: Verify**

Run: `grep -n 'auth\|privacy\|security\|runtimeOperations' greenfield/CLAUDE.md onboard/CLAUDE.md`

Expected: each file references all 4 new phases.

- [ ] **Step 6: Commit T26**

```bash
git add greenfield/skills/start/SKILL.md greenfield/skills/check/SKILL.md greenfield/CLAUDE.md onboard/CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(greenfield): update CLAUDE.md and start/check skills for Round 3

Update wizard step counts (11 → 15), phase enums, synthesis HTML
counts, and architecture diagrams across start/check skill files and
both CLAUDE.md docs. Add auth/privacy/security/runtimeOperations to
all referenced lists. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 27: Add ROUND 3 LOCKED entry to greenfield-overview.html Discussion Log

**Files:**
- Modify: `docs/greenfield-overview.html`

- [ ] **Step 1: Locate the Discussion Log section**

Run: `grep -n 'Discussion Log\|ROUND 2.5 LOCKED\|ROUND 2 LOCKED' docs/greenfield-overview.html`

Expected: existing entries for Round 1, Round 2, and Round 2.5. Round 3 entry goes at the top of the Discussion Log (newest first).

- [ ] **Step 2: Compose the ROUND 3 LOCKED entry**

Insert at the top of the Discussion Log (just above `ROUND 2.5 LOCKED`):

```html
<div class="discussion-entry">
  <h3>ROUND 3 LOCKED — 2026-05-14</h3>
  <p><strong>What changed:</strong> Four new wizard phases inserted between Step 4 and Step 5: <strong>Auth</strong>, <strong>Privacy</strong>, <strong>Security</strong>, <strong>Runtime Operations</strong>. Wizard grows from 11 to 15 steps. ~50 new questions; ~24 new files + ~15 modified.</p>

  <p><strong>5 locked decisions from the 2026-05-14 brainstorm:</strong></p>
  <ol>
    <li><strong>P6 shape</strong>: three separate phases (Auth + Privacy + Security), each with own synthesis, dependency sidecar, schema section, and stale-flag domain.</li>
    <li><strong>P7 scope</strong>: Runtime Operations only — jobs, observability, alerting, feature flags, runbooks, incident process. Cat 4 dev workflow stays where it is.</li>
    <li><strong>Depth</strong>: Heavy — 11–14 Qs per phase, ~50 total. Aligns with "time isn't a constraint; surprises are the failure mode."</li>
    <li><strong>Internal ordering</strong>: Auth → Privacy → Security → Runtime Operations. Each consumes only earlier-phase outputs.</li>
    <li><strong>Topic names</strong>: <code>auth</code> / <code>privacy</code> / <code>security</code> / <code>runtimeOperations</code>.</li>
  </ol>

  <p><strong>Migrations:</strong> Q3.3 (auth) → Auth.Q1. Q3.6 (monitoring) split across Ops.Q4/Q5/Q6. Q3.9 (env vars/secrets) → Sec.Q2. Q4.5 (security sensitivity) → Sec.Q1. P4.Q7 (async background work) reduced to a pointer; full detail in Ops.Q1–Q3.</p>

  <p><strong>Skip cascades (new):</strong> <code>auth.strategy='none'</code> → Privacy.Gate fires; <code>scaleTarget='hobby'</code> → Sec.Q11/Q12/Ops.Q8 auto-skip; <code>apiIntegration.asyncPatternPattern='none'</code> → Ops.Q1–Q3 collapse; <code>compliance</code> non-empty → no skips allowed in Security.</p>

  <p><strong>Versions:</strong> <code>greenfield@3.0.0-alpha.4</code> + <code>onboard@2.0.0-alpha.4</code>. Hard cutover during alpha (no migration framework).</p>

  <p><strong>Where to read:</strong> <code>docs/superpowers/specs/2026-05-14-greenfield-3.0-round3-design.md</code> + <code>docs/superpowers/plans/2026-05-14-greenfield-3.0-round3-implementation.md</code>.</p>
</div>
```

- [ ] **Step 3: Update the Phase 1.8 box (if present) to show 4 new wired phases**

Find the SVG/HTML box that visualizes Phase 1.8 with phase count. Bump from 3 wired (Round 1+2) or 5 wired (Round 2.5) to 9 wired (Round 3 final: architecturalFraming + dataArchitecture + apiIntegration + auth + privacy + security + runtimeOperations + cicdAndDelivery + architecturalValidation).

- [ ] **Step 4: Open in browser to verify rendering (optional manual check)**

Open `docs/greenfield-overview.html` in a browser. Confirm the new Discussion Log entry renders without HTML errors.

- [ ] **Step 5: Commit T27**

```bash
git add docs/greenfield-overview.html
git commit -m "$(cat <<'EOF'
docs(greenfield-3.0): add ROUND 3 LOCKED entry to Discussion Log

Document the 5 locked decisions from the 2026-05-14 brainstorm, the
migration map (5 Qs out), the skip-cascade rules, and the version
bump policy. Update Phase 1.8 wired-phase count to 9 (was 5 after
Round 2.5). Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 28: Create docs/greenfield-3.0-round3/ companion doc set

**Files:**
- Create: `docs/greenfield-3.0-round3/implementation-plan.md`
- (Already created in T16: `docs/greenfield-3.0-round3/phase-q-derivation-rules.md`)

- [ ] **Step 1: Author implementation-plan.md pointer**

Create `docs/greenfield-3.0-round3/implementation-plan.md` with a 1-page pointer to the canonical plan in `docs/superpowers/plans/`:

```markdown
# Greenfield 3.0 Round 3 — Implementation Plan

This is a navigational pointer. The canonical implementation plan lives at:

`docs/superpowers/plans/2026-05-14-greenfield-3.0-round3-implementation.md`

## Quick reference

- **Phase A** — Schema (T1–T5)
- **Phase B** — Synthesis templates (T6–T10)
- **Phase C** — Question bank (T11–T16)
- **Phase D** — Orchestrator wiring (T17–T23)
- **Phase E** — Cross-phase + grill-spec + pickup (T24–T26)
- **Phase F** — Docs (T27–T28)
- **Phase G** — Release (T29–T31)

See the source spec at `docs/superpowers/specs/2026-05-14-greenfield-3.0-round3-design.md` for the full design rationale.
```

- [ ] **Step 2: Commit T28**

```bash
git add docs/greenfield-3.0-round3/implementation-plan.md
git commit -m "$(cat <<'EOF'
docs(greenfield-3.0): add Round 3 round-scoped companion docs

Adds docs/greenfield-3.0-round3/ pointer doc to canonical plan in
docs/superpowers/plans/. Companion to phase-q-derivation-rules.md
catalog from T16. Part of greenfield 3.0 Round 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 29: Version bumps to alpha.4

**Files:**
- Modify: `greenfield/.claude-plugin/plugin.json`
- Modify: `onboard/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump `greenfield/.claude-plugin/plugin.json`**

Read the current file. Find `"version": "3.0.0-alpha.3"`. Replace with `"version": "3.0.0-alpha.4"`.

If the `description` field references the wizard topology, update to reflect 15 steps with all Round 3 phases.

- [ ] **Step 2: Bump `onboard/.claude-plugin/plugin.json`**

Find `"version": "2.0.0-alpha.3"`. Replace with `"version": "2.0.0-alpha.4"`.

- [ ] **Step 3: Validate both JSON files**

Run:
```bash
python3 -c "import json; json.load(open('greenfield/.claude-plugin/plugin.json'))" && \
python3 -c "import json; json.load(open('onboard/.claude-plugin/plugin.json'))" && \
echo "BOTH VALID"
```

Expected: `BOTH VALID`.

- [ ] **Step 4: Commit T29 (don't push)**

```bash
git add greenfield/.claude-plugin/plugin.json onboard/.claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore: bump greenfield to 3.0.0-alpha.4 and onboard to 2.0.0-alpha.4

Round 3 release: adds 4 new phases (auth, privacy, security,
runtimeOperations). Hard cutover from alpha.3 — in-flight alpha.3
sessions will not resume under alpha.4 (per state JSON evolution
policy, Round 2.5 Decision 8).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 30: Sync marketplace.json + CHANGELOG-2.0.md

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `onboard/CHANGELOG-2.0.md`

- [ ] **Step 1: Update `.claude-plugin/marketplace.json`**

Find the `greenfield` entry. Bump `version` to `3.0.0-alpha.4`. Update its `description` to reflect Round 3 if it references the wizard topology.

Find the `onboard` entry. Bump `version` to `2.0.0-alpha.4`. Update its description similarly.

Run: `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" && echo "VALID"`

Expected: `VALID`.

- [ ] **Step 2: Append a Round 3 section to `onboard/CHANGELOG-2.0.md`**

Add a top section (above any prior entries):

```markdown
## 2.0.0-alpha.4 — 2026-05-14 (Round 3)

### Added
- 4 new live phase schemas: `auth`, `privacy`, `security`, `runtimeOperations`
- Top-level description updated to mark Rounds 1–3 phases as live

### Schema break notice (hard cutover during alpha)
- In-flight `2.0.0-alpha.3` greenfield sessions cannot be resumed under `2.0.0-alpha.4`.
- The `pickup` skill detects `schemaVersion` mismatch and presents two recovery options:
  1. Finish the session on `alpha.4` (re-checkout the older greenfield branch)
  2. Discard the session and restart on `alpha.4`
- No migration framework ships (per Round 2.5 Decision 8 — migrations only from stable).

### Removed
- Nothing removed; schema additions are additive.
```

- [ ] **Step 3: Verify**

Run: `grep -n 'alpha.4\|Round 3' onboard/CHANGELOG-2.0.md .claude-plugin/marketplace.json`

Expected: marketplace.json lists both plugins at alpha.4 with Round 3 descriptions; CHANGELOG has the new entry.

- [ ] **Step 4: Commit T30**

```bash
git add .claude-plugin/marketplace.json onboard/CHANGELOG-2.0.md
git commit -m "$(cat <<'EOF'
chore: sync marketplace + CHANGELOG to alpha.4 (Round 3)

Update marketplace.json with greenfield@3.0.0-alpha.4 and
onboard@2.0.0-alpha.4 versions + descriptions. Add Round 3 entry to
CHANGELOG-2.0.md including hard-cutover schema break notice.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 31: Validate + final smoke test

**Files:**
- (Read-only validation)

- [ ] **Step 1: Run `/validate` skill on the whole marketplace**

Invoke the skill. Expected: no errors across all plugins (greenfield, onboard, notify, handoff).

If errors:
- ShellCheck errors on `.sh` scripts — fix and re-commit
- Missing referenced files in skills/agents — fix and re-commit
- Malformed plugin.json or marketplace.json — fix and re-commit
- Markdown frontmatter errors — fix and re-commit

- [ ] **Step 2: Schema soundness check**

Run:
```bash
python3 -c "
import json
schema = json.load(open('onboard/skills/generate/references/context-shape-v2.json'))
phases = schema['properties']['phases']['properties']
required_round3 = {'auth', 'privacy', 'security', 'runtimeOperations'}
missing = required_round3 - set(phases.keys())
print('Missing phases:', missing if missing else 'NONE')
print('Live phases:', sorted(set(phases.keys())))
"
```

Expected: `Missing phases: NONE` and the live-phases list includes auth, privacy, security, runtimeOperations.

- [ ] **Step 3: Reference integrity — every templated file exists**

Run:
```bash
for f in auth privacy security runtime-operations; do
  for ext in html md; do
    p="greenfield/skills/synthesis-review/references/templates/${f}.${ext}"
    [ -f "$p" ] && echo "OK $p" || echo "MISSING $p"
  done
  p="greenfield/skills/synthesis-review/references/templates/${f}-dependencies.json.example"
  [ -f "$p" ] && echo "OK $p" || echo "MISSING $p"
done
```

Expected: 12 `OK` lines, zero `MISSING`.

- [ ] **Step 4: Q-bank completeness check**

Run:
```bash
echo "Auth Qs:" && grep -c '^### Auth.Q' greenfield/skills/context-gathering/references/question-bank.md
echo "Privacy Qs:" && grep -c '^### Privacy\.' greenfield/skills/context-gathering/references/question-bank.md
echo "Security Qs:" && grep -c '^### Sec.Q' greenfield/skills/context-gathering/references/question-bank.md
echo "Ops Qs:" && grep -c '^### Ops.Q' greenfield/skills/context-gathering/references/question-bank.md
```

Expected: 12 / 12 (incl. Gate) / 13 / 14.

- [ ] **Step 5: Step renumbering check**

Run: `grep -n 'of 11' greenfield/skills/context-gathering/SKILL.md`

Expected: no output. If any `of 11` remains, fix in T21 (return to that task).

- [ ] **Step 6: Stale-flag interplay smoke test (manual)**

Hand-walk one stale-flag scenario in a throwaway scratch state file:
1. Author state with `auth.strategy='hosted'`, `phaseStatus.auth='complete'`, `phaseStatus.privacy='complete'`, `phaseStatus.security='complete'`.
2. Simulate Adjust: change `auth.strategy → 'self-hosted-oss'`.
3. Expected: stale-flag mechanism (Round 2.5 PRE-5) cascades to `phaseStatus.privacy.status='stale'`, `phaseStatus.security.status='stale'`, `phaseStatus.runtimeOperations.status='stale'`.
4. Document the expected behavior in a comment in `docs/greenfield-3.0-round3/implementation-plan.md` (post-implementation note).

- [ ] **Step 7: Final commit (if any fix-ups landed)**

If T31 turned up any small fixups, commit them with the appropriate scope. If clean:

```bash
git status -s
```

Expected: clean working tree.

- [ ] **Step 8: View the final history**

```bash
git log --oneline -32
```

Expected: ~31 commits since Round 2.5 final (`fc295ef`). The Round 3 design spec commit (`3701659`) was made before the implementation plan was written; it remains at the same SHA.

---

## Done

Round 3 is complete. The branch `feat/greenfield-1.2` now contains Rounds 1+2+2.5+3. PR #50 retitle pending — defer until Round 4 is also ready, or retitle now with "Rounds 1+2+2.5+3 — wizard overhaul through Runtime Operations" if a coordinated check-in is desired.

**Pre-Round-4 check-in**: per the locked plan, pause after Round 3. Confirm with user before proceeding to Round 4 (Personas, Domain Modeling, Risk ID).
