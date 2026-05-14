# Security Q-bank — Step 7

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 7 (Security; preceded by Step 6 privacy; inherits sensitivity tier from privacy.regulations + dataArchitecture.compliance)
> **Modes:** Heavy ~13 Qs (Sec.Q1–Q13 + Q_RISK) / Light ~5 Qs (foundational + Q_RISK; depth Qs use defaults)
> **Coupling:** Auto-loop on the threat-model Q (`loopMode: hybrid-only`, over `personas.primary`) and the attack-surface Q (`loopMode: hybrid-only`, over `domainModel.entities`). Hybrid mode collapses both to single static answers.
> **Source:** Q content migrated from `question-bank.md` § "Step 7: Security" (lines 780–992); R4 added Q_RISK + showInLight + loopOver tags + format conversion.
> **See also:** `auth.q-bank.md`, `privacy.q-bank.md`, `runtime-operations.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk + § Coupling matrix.

This phase gathers security posture decisions: sensitivity tier, threat model (per persona), attack surface (per entity), authn/authz hardening, secrets/env vars, network controls, audit, pentest, vulnerability disclosure, supply-chain hygiene. Synthesis review fires inline after Sec.Q_RISK.

## Q-bank

### Sec.Q1 — Security sensitivity tier

- **type:** single-select
- **options:** ["Standard (basic security hygiene)", "Elevated (handles PII or payment data)", "High (SOC 2 / HIPAA / PCI-DSS / ISO 27001 scope)"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.security.sensitivityTier`

**Prompt:** "What is the security sensitivity tier of this project?"

**Stores to:** `security.sensitivityTier` — locked to `"high"` if `dataArchitecture.compliance` is non-empty

**Downstream effects:** Sec.Q9 (audit retention) mandatory if tier ≠ Standard; Sec.Q11/Q12 (pentest, VDP) auto-skip for hobby + Standard combination; all subsequent Sec.Q defaults inherit from this tier.

**Default:**
- If `dataArchitecture.compliance` is non-empty (any value) → `"High"` (compliance scope implies formal security controls — lock to high; this is not configurable)
- If `apiIntegration.externalServices` includes payment processors (Stripe, Braintree, Adyen, etc.) → `"Elevated"` (payment data processing triggers PCI-DSS scope regardless of whether you're storing cards)
- If `privacy.piiCategories[]` includes `"Health / medical data"` OR `"Biometric data"` OR `"Government ID / SSN"` OR `"Payment card data"` → `"Elevated"` (sensitive PII categories materially increase breach impact and regulatory exposure)
- If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` AND `auth.strategy ≠ 'none'` → `"Elevated"` (greenfield opinion: production apps serving real users should operate at elevated baseline — the cost of a breach at this scale exceeds the overhead of elevated controls)
- If `architecturalFraming.scaleTarget: "hobby"` → `"Standard"` (hobby apps are low-target, low-breach-impact; standard hygiene is appropriate)
- Else → `"Standard"` (greenfield opinion: most projects should start at standard and deliberately elevate when PII, payments, or compliance come in scope — security controls are cost-effective when scoped to actual risk)

### Sec.Q2 — Secrets and environment variable management

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.security.secrets`

**Prompt:** "How do you want to manage environment variables and secrets?"

**Stores to:** `security.secrets` (object)

**Sub-questions:**
- `storage` (single-select): `".env files"` | `"platform-managed (Vercel env, AWS SM, GCP Secret Manager)"` | `"Vault / Doppler / external secrets manager"` | `"cloud KMS (AWS KMS, GCP KMS, Azure Key Vault)"`
- `rotationCadence` (single-select): `"manual (ad hoc)"` | `"90d"` | `"30d"` | `"automated-on-trigger"` | `"none"`
- `vaultingForCI` (boolean): whether CI/CD secrets are stored separately from runtime secrets

**Downstream effects:** cicdAndDelivery reads `security.secrets.storage` for secret injection patterns; Sec.Q3 (scanning) uses `security.secrets.storage` to suggest secret-leak SAST rules; supply-chain security (Sec.Q13) considers vaulted CI secrets for provenance.

**Default:**
- If `security.sensitivityTier: "high"` → `storage: "Vault / Doppler / external secrets manager"`, `rotationCadence: "30d"`, `vaultingForCI: true` (high-tier compliance (SOC 2, HIPAA, PCI-DSS) requires documented secret rotation and access controls; Vault/Doppler provides audit logs, rotation automation, and RBAC)
- If `security.sensitivityTier: "elevated"` → `storage: "platform-managed (Vercel env, AWS SM, GCP Secret Manager)"`, `rotationCadence: "90d"`, `vaultingForCI: true` (greenfield opinion: platform-managed secrets provide encryption-at-rest and access logging without Vault's operational overhead — right balance for elevated-tier apps)
- If `architecturalFraming.scaleTarget: "hobby"` → `storage: ".env files"`, `rotationCadence: "none"`, `vaultingForCI: false` (hobby projects have no secrets rotation requirements; .env with gitignore is the zero-overhead solution)
- If `apiIntegration.externalServices` includes cloud providers (AWS, GCP, Azure) → `storage: "platform-managed (Vercel env, AWS SM, GCP Secret Manager)"`, `rotationCadence: "90d"`, `vaultingForCI: true` (cloud-native secret managers integrate natively with IAM and eliminate the need to store secrets in env files at all)
- If `architecturalFraming.topology: "microservices"` → `storage: "Vault / Doppler / external secrets manager"`, `rotationCadence: "90d"`, `vaultingForCI: true` (microservices with multiple independent deployables need a centralized secrets plane — per-service .env files become unmanageable quickly)
- Else → `storage: "platform-managed (Vercel env, AWS SM, GCP Secret Manager)"`, `rotationCadence: "90d"`, `vaultingForCI: false` (greenfield opinion: platform-managed secrets are zero-overhead and work out of the box; they provide encryption-at-rest and access logging that .env files never can)

### Sec.Q3 — Vulnerability scanning strategy

<!-- skipped in hybrid coupling; fires once static in hybrid mode -->

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.security.scanning`
- **loopOver:** domainModel.entities
- **loopMode:** hybrid-only

**Prompt (auto-loop):** "For entity {entity.id}, what attack surface is exposed?"

**Prompt (hybrid fallback):** "Enumerate the system's primary attack surfaces."

**Stores to:** `security.scanning` (object)

**Sub-questions:**
- `depScanning` (single-select): `"Dependabot (GitHub-native)"` | `"Snyk"` | `"OWASP Dependency-Check"` | `"none"` — dependency CVE scanning
- `sast` (single-select): `"Semgrep"` | `"CodeQL (GitHub Advanced Security)"` | `"none"` — static analysis for code-level vulns
- `dast` (single-select): `"OWASP ZAP (CI-integrated)"` | `"manual periodic"` | `"none"` — dynamic/runtime scanning
- `containerScan` (single-select): `"Trivy"` | `"Grype"` | `"Docker Scout"` | `"none"` — only prompted if Docker in use
- `cadence` (single-select): `"every-commit"` | `"daily"` | `"weekly"` | `"on-release-only"`

**Downstream effects:** cicdAndDelivery generates CI scanning pipeline steps from this object; Sec.Q13 (supply-chain) uses `depScanning` choice for SBOM integration.

**Default:**
- If `security.sensitivityTier: "high"` → `depScanning: "Snyk"`, `sast: "CodeQL (GitHub Advanced Security)"`, `dast: "OWASP ZAP (CI-integrated)"`, `containerScan: "Trivy"` (if Docker used), `cadence: "every-commit"` (compliance tiers require continuous, multi-layer scanning: dep + SAST + DAST + container is the minimum defensible posture for SOC 2 / PCI-DSS audits)
- If `security.sensitivityTier: "elevated"` → `depScanning: "Dependabot (GitHub-native)"`, `sast: "Semgrep"`, `dast: "none"`, `containerScan: "Trivy"` (if Docker used), `cadence: "every-commit"` (greenfield opinion: Dependabot + Semgrep covers 90% of CVE and OWASP Top 10 risk for elevated apps at zero marginal cost — add DAST when you're ready for formal pen-test prep)
- If `architecturalFraming.scaleTarget: "hobby"` → `depScanning: "Dependabot (GitHub-native)"`, `sast: "none"`, `dast: "none"`, `containerScan: "none"`, `cadence: "weekly"` (hobby apps deserve dep scanning for known CVEs; the rest is overhead)
- If `auth.strategy ≠ 'none'` AND `security.sensitivityTier: "standard"` → `depScanning: "Dependabot (GitHub-native)"`, `sast: "Semgrep"`, `dast: "none"`, `containerScan: "none"`, `cadence: "every-commit"` (greenfield opinion: any app with auth surfaces SQL injection, XSS, and broken access control risks — Semgrep rules for these are free and catch the most common vulnerabilities)
- Else → `depScanning: "Dependabot (GitHub-native)"`, `sast: "none"`, `dast: "none"`, `containerScan: "none"`, `cadence: "weekly"` (greenfield opinion: Dependabot is the minimum acceptable scanning posture — known CVEs in dependencies are the most common breach vector for hobby and standard apps)

### Sec.Q4 — Threat model approach

<!-- skipped in hybrid coupling; fires once static in hybrid mode -->

- **type:** single-select
- **options:** ["STRIDE-lite checklist (guided, self-service)", "Formal threat modeling session (document assets, threats, mitigations)", "None — rely on code scanning only"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.security.threatModel`
- **loopOver:** personas.primary
- **loopMode:** hybrid-only

**Prompt (auto-loop):** "For persona {persona.id}, what's the dominant attacker-from-persona-context threat?"

**Prompt (hybrid fallback):** "What are the top 3 threat-actor scenarios you're designing against?"

**Stores to:** `security.threatModel`

**Downstream effects:** Synthesis includes threat model summary in `docs/adr/security.html`; formal session output becomes an ADR section.

**Default:**
- If `security.sensitivityTier: "high"` → `"Formal threat modeling session"` (SOC 2 Type II and HIPAA both require documented risk assessments; a formal STRIDE session produces the evidence needed for auditors)
- If `security.sensitivityTier: "elevated"` → `"STRIDE-lite checklist"` (greenfield opinion: STRIDE-lite is the right balance for elevated-tier apps — structured enough to catch design-level threats, lightweight enough to complete in a single session before scaffolding)
- If `architecturalFraming.scaleTarget: "hobby"` → `"None — rely on code scanning only"` (threat modeling overhead exceeds the risk surface for hobby apps with no sensitive data)
- If `architecturalFraming.topology: "microservices"` → `"Formal threat modeling session"` (microservices multiply the attack surface — service-to-service trust boundaries, network exposure, and blast radius analysis require a structured session to get right)
- Else → `"STRIDE-lite checklist"` (greenfield opinion: a STRIDE-lite checklist takes 30 minutes, catches the top 5 design-level threats, and produces documentation you'll reference when something goes wrong — it's the highest-ROI security investment at project start)

### Sec.Q5 — Encryption at rest

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `dataArchitecture.engine ≠ null` OR `dataArchitecture.fileStorage ≠ null`
- **R3-updates-path:** `context.phases.security.encryptionAtRest`

**Prompt:** "What is the encryption-at-rest strategy?"

**Stores to:** `security.encryptionAtRest` (object)

**Sub-questions:**
- `dbEncryption` (single-select): `"DB-default (provider-managed, transparent)"` | `"per-column for sensitive fields (app-managed AES)"` | `"full application-managed encryption"`
- `fileStorage` (single-select): `"provider-managed (S3 SSE, GCS default)"` | `"client-side encryption before upload"` | `"none"` — only prompted if `dataArchitecture.fileStorage ≠ none`
- `backups` (single-select): `"encrypted by default (provider-managed)"` | `"additional app-layer encryption"` | `"none"`

**Downstream effects:** Synthesis renders encryption-at-rest section in `docs/adr/security.html`; infrastructure scaffolding configures DB encryption flags accordingly.

**Default:**
- If `security.sensitivityTier: "high"` → `dbEncryption: "per-column for sensitive fields (app-managed AES)"`, `fileStorage: "client-side encryption before upload"`, `backups: "additional app-layer encryption"` (PCI-DSS and HIPAA require field-level encryption for cardholder data and PHI respectively; transparent DB encryption is not sufficient — attackers with DB credentials would see plaintext)
- If `security.sensitivityTier: "elevated"` AND `privacy.piiCategories[]` includes sensitive fields → `dbEncryption: "per-column for sensitive fields (app-managed AES)"`, `fileStorage: "provider-managed (S3 SSE, GCS default)"`, `backups: "encrypted by default (provider-managed)"` (per-column encryption for the specific sensitive fields reduces breach impact without the overhead of full app-layer encryption)
- If `dataArchitecture.engine ∈ (postgres, mysql, sqlite)` → `dbEncryption: "DB-default (provider-managed, transparent)"`, `backups: "encrypted by default (provider-managed)"` (managed cloud DBs encrypt at rest by default; no action needed unless compliance requires field-level encryption)
- If `architecturalFraming.scaleTarget: "hobby"` → `dbEncryption: "DB-default (provider-managed, transparent)"`, `backups: "encrypted by default (provider-managed)"` (provider-managed encryption is sufficient for hobby apps — no additional configuration needed)
- Else → `dbEncryption: "DB-default (provider-managed, transparent)"`, `fileStorage: "provider-managed (S3 SSE, GCS default)"`, `backups: "encrypted by default (provider-managed)"` (greenfield opinion: provider-managed encryption covers most threat models without any engineering overhead — only add application-layer encryption when you have specific regulatory or threat requirements)

### Sec.Q6 — Encryption in transit

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy` OR `architecturalFraming.topology ≠ 'local-only'`
- **R3-updates-path:** `context.phases.security.encryptionInTransit`

**Prompt:** "What encryption-in-transit posture should be adopted?"

**Stores to:** `security.encryptionInTransit` (object)

**Sub-questions:**
- `externalTls` (single-select): `"TLS everywhere (HTTPS enforced, HTTP redirect)"` | `"TLS with HSTS (Strict-Transport-Security)"` | `"TLS with HSTS + preload"`
- `serviceToService` (single-select): `"plain TLS (standard HTTPS)"` | `"mTLS (mutual TLS, both sides present certs)"` | `"none (internal cluster network only)"`
- `minimumTlsVersion` (single-select): `"TLS 1.2"` | `"TLS 1.3 (preferred)"` | `"TLS 1.2 with 1.3 upgrade path"`

**Downstream effects:** Infrastructure scaffolding sets TLS configuration; CI checks for downgrade vulnerabilities; mTLS triggers service-mesh configuration recommendations.

**Default:**
- If `architecturalFraming.topology: "microservices"` → `externalTls: "TLS with HSTS"`, `serviceToService: "mTLS (mutual TLS, both sides present certs)"`, `minimumTlsVersion: "TLS 1.2 with 1.3 upgrade path"` (greenfield opinion: microservices have multiple east-west attack surfaces — mTLS ensures every service-to-service call is authenticated and encrypted; service mesh (Istio, Linkerd) can manage certificates automatically)
- If `security.sensitivityTier: "high"` → `externalTls: "TLS with HSTS + preload"`, `serviceToService: "mTLS (mutual TLS, both sides present certs)"`, `minimumTlsVersion: "TLS 1.3 (preferred)"` (compliance tiers require the strongest TLS posture; HSTS preload prevents first-visit downgrades; TLS 1.3 removes deprecated cipher suites)
- If `security.sensitivityTier: "elevated"` → `externalTls: "TLS with HSTS"`, `serviceToService: "plain TLS (standard HTTPS)"`, `minimumTlsVersion: "TLS 1.2 with 1.3 upgrade path"` (HSTS prevents SSL-stripping attacks; TLS 1.2 is the current baseline with 1.3 as the upgrade path)
- If `architecturalFraming.scaleTarget: "hobby"` → `externalTls: "TLS everywhere (HTTPS enforced, HTTP redirect)"`, `serviceToService: "none (internal cluster network only)"`, `minimumTlsVersion: "TLS 1.2"` (HTTPS is non-negotiable even for hobby apps; HSTS and mTLS overhead not worth it at hobby scale)
- Else → `externalTls: "TLS with HSTS"`, `serviceToService: "plain TLS (standard HTTPS)"`, `minimumTlsVersion: "TLS 1.2 with 1.3 upgrade path"` (greenfield opinion: HSTS is a one-line header that eliminates SSL-stripping attacks — add it to all production apps by default)

### Sec.Q7 — Security headers and CORS policy

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `apiIntegration.externalServices` is non-empty OR `hasFrontend: true`
- **R3-updates-path:** `context.phases.security.headers`

**Prompt:** "What security headers and CORS policy should be configured?"

**Stores to:** `security.headers` (object)

**Sub-questions:**
- `corsPolicy` (single-select): `"permissive (allow all origins)"` | `"restrictive (allowlist of specific origins)"` | `"credentials-aware (withCredentials + explicit origin)"` | `"none (no cross-origin requests)"`
- `csp` (single-select): `"strict (nonce-based)"` | `"moderate (self + known CDNs)"` | `"report-only (monitoring, not enforcing)"` | `"none"`
- `xFrameOptions` (single-select): `"DENY"` | `"SAMEORIGIN"` | `"none"`
- `additionalHeaders` (multi-select): `"X-Content-Type-Options: nosniff"` | `"Referrer-Policy: strict-origin-when-cross-origin"` | `"Permissions-Policy"` | `"none"`

**Downstream effects:** Scaffolding generates middleware/framework config for headers; CSP setting informs inline-script restrictions in frontend scaffolding; CORS policy informs API gateway or framework CORS config.

**Default:**
- If `security.sensitivityTier: "high"` → `corsPolicy: "restrictive (allowlist of specific origins)"`, `csp: "strict (nonce-based)"`, `xFrameOptions: "DENY"`, `additionalHeaders: ["X-Content-Type-Options: nosniff", "Referrer-Policy: strict-origin-when-cross-origin", "Permissions-Policy"]` (compliance-tier apps need the full header suite; strict CSP with nonces is the only CSP that reliably prevents XSS)
- If `hasFrontend: true` AND `apiIntegration.externalServices` is non-empty → `corsPolicy: "credentials-aware (withCredentials + explicit origin)"`, `csp: "moderate (self + known CDNs)"`, `xFrameOptions: "SAMEORIGIN"`, `additionalHeaders: ["X-Content-Type-Options: nosniff", "Referrer-Policy: strict-origin-when-cross-origin"]` (greenfield opinion: credentials-aware CORS prevents token hijacking on cross-origin requests; moderate CSP blocks most XSS without breaking CDN-loaded assets)
- If `hasFrontend: false` AND `hasAPI: true` → `corsPolicy: "restrictive (allowlist of specific origins)"`, `csp: "none"`, `xFrameOptions: "DENY"`, `additionalHeaders: ["X-Content-Type-Options: nosniff"]` (API-only services should lock down CORS to known consumers — no frontend = no CSP needed)
- If `architecturalFraming.scaleTarget: "hobby"` → `corsPolicy: "permissive (allow all origins)"`, `csp: "none"`, `xFrameOptions: "SAMEORIGIN"`, `additionalHeaders: ["X-Content-Type-Options: nosniff"]` (hobby apps can use permissive CORS for development ease; tighten before adding auth or PII)
- Else → `corsPolicy: "restrictive (allowlist of specific origins)"`, `csp: "moderate (self + known CDNs)"`, `xFrameOptions: "SAMEORIGIN"`, `additionalHeaders: ["X-Content-Type-Options: nosniff", "Referrer-Policy: strict-origin-when-cross-origin"]` (greenfield opinion: restrictive CORS + moderate CSP + standard headers is the right baseline — it blocks the three most common web vulns (CORS abuse, XSS, clickjacking) with minimal configuration)

### Sec.Q8 — Input validation policy

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `hasAPI: true` OR `hasFrontend: true`
- **R3-updates-path:** `context.phases.security.inputValidation`

**Prompt:** "What input validation policy should be enforced?"

**Stores to:** `security.inputValidation` (object)

**Sub-questions:**
- `scope` (single-select): `"trust-boundaries-only (API entry points, form handlers)"` | `"everywhere (all function inputs, defensive)"` | `"schema-validation (Zod, Pydantic, Joi at ingress)"`
- `library` (single-select): `"Zod (TypeScript)"` | `"Pydantic (Python)"` | `"Joi"` | `"class-validator (NestJS)"` | `"native ORM constraints only"` | `"none"`
- `sanitization` (single-select): `"DOMPurify for HTML output"` | `"parameterized queries only (no sanitization)"` | `"both"` | `"none"`

**Downstream effects:** Scaffolding generates request-validation middleware; Sec.Q3 SAST rules tune to match validation approach; synthesized ADR includes injection-prevention rationale.

**Default:**
- If `security.sensitivityTier: "high"` → `scope: "everywhere (all function inputs, defensive)"`, `library` (derived from stack), `sanitization: "both"` (compliance apps must defensively validate all inputs — OWASP ASVS Level 2+ requires input validation at every trust boundary and within business logic)
- If `stack.stack.language: "typescript"` → `library: "Zod (TypeScript)"` (Zod is the TypeScript ecosystem standard for runtime schema validation; parse-don't-validate pattern prevents trust-boundary bypass)
- If `stack.stack.language: "python"` → `library: "Pydantic (Python)"` (Pydantic is the de facto validation library for Python APIs; FastAPI uses it natively)
- If `stack.stack.framework: "nestjs"` → `library: "class-validator (NestJS)"` (NestJS's built-in pipe validation uses class-validator; consistent with framework conventions)
- If `hasFrontend: true` AND (`security.sensitivityTier ∈ (elevated, high)`) → `sanitization: "DOMPurify for HTML output"` (greenfield opinion: any user-generated content rendered as HTML needs DOMPurify — stored XSS via unsanitized HTML is among the highest-severity web vulnerabilities)
- Else → `scope: "trust-boundaries-only (API entry points, form handlers)"`, `library` (stack-derived), `sanitization: "parameterized queries only (no sanitization)"` (greenfield opinion: trust-boundary-only validation + parameterized queries prevents SQL injection and the most common injection attacks without the overhead of defensive validation everywhere)

### Sec.Q9 — Audit log retention and tamper-evidence

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `security.sensitivityTier ≠ 'standard'` — **SKIP this question (default to `retentionWindow: 90d`, `tamperEvidence: none`, `scope: ["authentication events"]`) if `security.sensitivityTier = 'standard'`**
- **R3-updates-path:** `context.phases.security.auditRetention`

**Prompt:** "What audit log retention and tamper-evidence requirements apply?"

**Stores to:** `security.auditRetention` (object)

**Sub-questions:**
- `retentionWindow` (single-select): `"30d"` | `"90d"` | `"1y"` | `"3y"` | `"7y"` | `"indefinite"`
- `tamperEvidence` (single-select): `"hash-chain (append-only linked digests)"` | `"write-once storage (S3 Object Lock, Worm)"` | `"both"` | `"none"`
- `scope` (multi-select): `"authentication events"` | `"privilege escalation"` | `"admin actions"` | `"data export / bulk reads"` | `"configuration changes"` | `"API key creation / revocation"`

**Cross-reference:** Cross-referenced with `privacy.accessAudit` — security audit log covers system/admin events; privacy access audit covers data-access events; synthesis flags gaps if neither covers a required event type.

**Downstream effects:** Cross-referenced with `privacy.accessAudit`; synthesis flags gaps if neither covers a required event type.

**Default:**
- If `dataArchitecture.compliance ∈ (HIPAA)` → `retentionWindow: "7y"`, `tamperEvidence: "both"`, `scope: ["authentication events", "privilege escalation", "admin actions", "data export / bulk reads", "configuration changes", "API key creation / revocation"]` (HIPAA §164.312(b) requires comprehensive audit controls; 6-year minimum rounded to 7y; tamper-evidence required for audit defensibility)
- If `dataArchitecture.compliance ∈ (SOC 2)` → `retentionWindow: "1y"`, `tamperEvidence: "hash-chain (append-only linked digests)"`, `scope: ["authentication events", "privilege escalation", "admin actions", "configuration changes"]` (SOC 2 Trust Service Criteria CC7 requires security event monitoring and audit trails for at least 1 year)
- If `dataArchitecture.compliance ∈ (PCI-DSS)` → `retentionWindow: "1y"`, `tamperEvidence: "write-once storage (S3 Object Lock, Worm)"`, `scope: ["authentication events", "privilege escalation", "admin actions", "API key creation / revocation", "configuration changes"]` (PCI-DSS Requirement 10: 12-month retention with 3-month immediate availability; write-once storage satisfies tamper-evidence requirement)
- If `security.sensitivityTier: "elevated"` → `retentionWindow: "1y"`, `tamperEvidence: "hash-chain (append-only linked digests)"`, `scope: ["authentication events", "admin actions", "data export / bulk reads"]` (greenfield opinion: elevated-tier apps should retain security events for 1 year to support incident post-mortems; hash-chaining is lightweight and sufficient outside formal compliance scope)
- Else → `retentionWindow: "90d"`, `tamperEvidence: "none"`, `scope: ["authentication events", "admin actions"]` (greenfield opinion: 90d covers most incident response windows; authentication + admin events are the minimum useful scope for detecting breaches and insider threats)

### Sec.Q10 — Incident response posture

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `security.sensitivityTier ≠ 'standard'` OR `isProduction: true`
- **R3-updates-path:** `context.phases.security.ir`

**Prompt:** "What is the incident response posture?"

**Stores to:** `security.ir` (object)

**Sub-questions:**
- `runbookStyle` (single-select): `"inline-checklist (Markdown in repo)"` | `"external runbook (PagerDuty, Confluence)"` | `"none"`
- `notificationSla` (single-select): `"72h (GDPR breach notification)"` | `"24h (internal)"` | `"best-effort"` | `"none"`
- `escalationPath` (free-text): e.g., `"solo developer — self-escalate"`, `"engineering on-call → security lead → legal"`

**Cross-reference:** Full incident process detail lives in `runtimeOperations.incidentProcess` — this question captures security-specific posture; scaffolding ensures the two are consistent and non-overlapping.

**Downstream effects:** Synthesis cross-links `security.ir` ↔ `runtimeOperations.incidentProcess` to prevent duplicate or contradictory runbooks; `notificationSla: "72h"` triggers a GDPR breach notification checklist section in `docs/adr/security.html`.

**Default:**
- If `security.sensitivityTier: "high"` → `runbookStyle: "inline-checklist (Markdown in repo)"`, `notificationSla: "72h (GDPR breach notification)"`, `escalationPath: "engineering on-call → security lead → legal"` (high-tier apps need a documented IR runbook for audits; GDPR 72h notification SLA is legally mandated; documented escalation path is required for SOC 2 and ISO 27001)
- If `security.sensitivityTier: "elevated"` AND `privacy.regulations[]` includes GDPR → `runbookStyle: "inline-checklist (Markdown in repo)"`, `notificationSla: "72h (GDPR breach notification)"`, `escalationPath: "solo developer — self-escalate"` (GDPR Article 33 requires breach notification within 72h — even solo developers need a documented response plan to meet this requirement)
- If `isProduction: true` AND `security.sensitivityTier: "standard"` → `runbookStyle: "inline-checklist (Markdown in repo)"`, `notificationSla: "best-effort"`, `escalationPath: "solo developer — self-escalate"` (greenfield opinion: every production app should have a minimal IR checklist — it takes 30 minutes to write and prevents panic-driven mistakes when an incident actually happens)
- If `architecturalFraming.scaleTarget: "hobby"` → `runbookStyle: "none"`, `notificationSla: "none"`, `escalationPath: "solo developer — self-escalate"` (hobby apps do not need formal IR posture; revisit when serving real users)
- Else → `runbookStyle: "inline-checklist (Markdown in repo)"`, `notificationSla: "best-effort"`, `escalationPath: "solo developer — self-escalate"` (greenfield opinion: an inline checklist is the minimum viable IR posture — it costs nothing to create and pays off significantly the first time you have an incident)

### Sec.Q11 — Pentest and security audit cadence

- **type:** single-select
- **options:** ["Annual third-party pentest", "Quarterly internal + annual external", "Continuous (automated + periodic red-team)", "None — rely on scanning only"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** (`architecturalFraming.scaleTarget ∈ (production-scale, enterprise)`) OR (`security.sensitivityTier ≠ 'standard'`) — **AUTO-SKIP for `architecturalFraming.scaleTarget='hobby'` AND `security.sensitivityTier='standard'`; default to `"None — rely on scanning only"` without asking**
- **R3-updates-path:** `context.phases.security.pentestCadence`

**Prompt:** "What pentest / security audit cadence should be adopted?"

**Stores to:** `security.pentestCadence`

**Downstream effects:** Synthesis includes pentest section in `docs/adr/security.html`; high-cadence selection triggers a pentest-prep checklist in the ADR.

**Default:**
- If `security.sensitivityTier: "high"` AND `architecturalFraming.scaleTarget: "enterprise"` → `"Quarterly internal + annual external"` (enterprise + compliance tier requires documented pentest evidence for SOC 2 / PCI-DSS auditors; quarterly internal keeps the surface continuously assessed between annual third-party engagements)
- If `security.sensitivityTier: "high"` → `"Annual third-party pentest"` (compliance-tier apps need at least one annual external pentest to satisfy SOC 2, ISO 27001, and PCI-DSS audit requirements)
- If `security.sensitivityTier: "elevated"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Annual third-party pentest"` (greenfield opinion: elevated-tier production apps should have at least one annual external pentest — it catches design-level vulnerabilities that scanning misses and signals security maturity to enterprise customers)
- If `architecturalFraming.scaleTarget: "hobby"` OR `security.sensitivityTier: "standard"` → `"None — rely on scanning only"` (**auto-skipped for hobby + standard — not asked**; pentests are not cost-effective at this scale)
- Else → `"Annual third-party pentest"` (greenfield opinion: if you've made it past the hobby + standard auto-skip, you're building something that warrants at least an annual external review — automated scanning misses business-logic vulnerabilities that a human tester finds)

### Sec.Q12 — Vulnerability disclosure program

- **type:** single-select
- **options:** ["Public bug bounty (HackerOne, Bugcrowd)", "Private bug bounty (invite-only, limited scope)", "Vulnerability disclosure policy only (no rewards)", "None"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** (`architecturalFraming.scaleTarget ∈ (production-scale, enterprise)`) OR (`security.sensitivityTier ≠ 'standard'`) — **AUTO-SKIP for `architecturalFraming.scaleTarget='hobby'` AND `security.sensitivityTier='standard'`; default to `"None"` without asking**
- **R3-updates-path:** `context.phases.security.vdp`

**Prompt:** "Should a bug bounty or vulnerability disclosure program (VDP) be established?"

**Stores to:** `security.vdp`

**Downstream effects:** Synthesis includes VDP/bug-bounty section in `docs/adr/security.html`; `"Public bug bounty"` triggers a security.txt and responsible-disclosure policy scaffold.

**Default:**
- If `security.sensitivityTier: "high"` AND `architecturalFraming.scaleTarget: "enterprise"` → `"Public bug bounty (HackerOne, Bugcrowd)"` (enterprise compliance expectations often include a public bug bounty; it also signals security maturity to enterprise customers and investors)
- If `security.sensitivityTier: "high"` → `"Vulnerability disclosure policy only (no rewards)"` (greenfield opinion: a VDP without rewards is a low-cost way to provide a safe reporting channel — required for ISO 27001 and expected for SOC 2; add a formal bug bounty when you have the operational capacity to triage reports)
- If `security.sensitivityTier: "elevated"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Vulnerability disclosure policy only (no rewards)"` (a VDP is the right starting point for elevated-tier production apps — it establishes a responsible-disclosure channel without the operational overhead of a bounty program)
- If `architecturalFraming.scaleTarget: "hobby"` OR `security.sensitivityTier: "standard"` → `"None"` (**auto-skipped for hobby + standard — not asked**; bug bounties are not appropriate at this scale)
- Else → `"Vulnerability disclosure policy only (no rewards)"` (greenfield opinion: a VDP costs nothing to publish and protects you legally — security researchers who find vulnerabilities need a channel to report responsibly; without one, they have no safe option)

### Sec.Q13 — Supply-chain security controls

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.security.supplyChain`

**Prompt:** "What supply-chain security controls should be applied?"

**Stores to:** `security.supplyChain` (object)

**Sub-questions:**
- `lockfilePinning` (single-select): `"exact versions (package-lock.json, poetry.lock, Cargo.lock)"` | `"ranges allowed"` | `"none"`
- `signedCommits` (boolean): enforce GPG/SSH commit signing via branch protection
- `sbom` (single-select): `"generate on release (CycloneDX or SPDX)"` | `"generate on every build"` | `"none"`
- `provenance` (single-select): `"SLSA Level 1 (build provenance attestation)"` | `"SLSA Level 2 (hosted build, signed provenance)"` | `"none"`

**Downstream effects:** cicdAndDelivery generates SBOM generation step; Sec.Q3 `depScanning` integrates with SBOM for CVE cross-referencing; signed commits configuration goes into branch protection scaffold.

**Default:**
- If `security.sensitivityTier: "high"` → `lockfilePinning: "exact versions"`, `signedCommits: true`, `sbom: "generate on release (CycloneDX or SPDX)"`, `provenance: "SLSA Level 2 (hosted build, signed provenance)"` (compliance-tier apps face supply-chain regulatory scrutiny; SLSA Level 2 satisfies most audit requirements and is achievable with GitHub Actions + sigstore/cosign without custom infrastructure)
- If `security.sensitivityTier: "elevated"` → `lockfilePinning: "exact versions"`, `signedCommits: false`, `sbom: "generate on release (CycloneDX or SPDX)"`, `provenance: "SLSA Level 1 (build provenance attestation)"` (greenfield opinion: lockfile pinning + release SBOM is the right supply-chain baseline for elevated apps — it makes dependency audits deterministic and provides an inventory for CVE tracking without the overhead of full SLSA Level 2)
- If `architecturalFraming.scaleTarget: "enterprise"` → `lockfilePinning: "exact versions"`, `signedCommits: true`, `sbom: "generate on every build"`, `provenance: "SLSA Level 2 (hosted build, signed provenance)"` (enterprise apps with multiple contributors need signed commits for non-repudiation; build-time SBOMs enable continuous CVE monitoring across the dependency tree)
- If `architecturalFraming.scaleTarget: "hobby"` → `lockfilePinning: "exact versions"`, `signedCommits: false`, `sbom: "none"`, `provenance: "none"` (greenfield opinion: lockfile pinning is the minimum supply-chain hygiene for any project — it makes builds reproducible and prevents surprise dep updates from breaking your app)
- Else → `lockfilePinning: "exact versions"`, `signedCommits: false`, `sbom: "generate on release (CycloneDX or SPDX)"`, `provenance: "SLSA Level 1 (build provenance attestation)"` (greenfield opinion: lockfiles + release SBOMs give you a defensible supply-chain posture at near-zero cost; SLSA Level 1 provenance attestation is achievable with a single GitHub Actions step and enables future upgrade to Level 2)

**After Sec.Q13**, invoke synthesis-review inline:

> Invoke `Skill(synthesis-review, phaseId: "security")` — renders `docs/adr/security.html` and walks the developer through approve/adjust/skip.

---

### Sec.Q_RISK — Security risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["security", "compliance"]

**Prompt:** "What's the biggest security risk for THIS project? (e.g., 'WAF deferred to post-launch — first-week exposure', 'secrets in env vars without rotation', 'no incident response runbook'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "security"`, id auto-assigned `R-SECURITY-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Sec.Q1 | ✓ | ✓ | Sensitivity tier — foundational; gates all downstream Q defaults |
| Sec.Q2 | ✓ | ✓ | Secrets management — foundational security hygiene for all projects |
| Sec.Q3 | ✓ | — | Vulnerability scanning / attack surface — depth; `loopMode: hybrid-only` over `domainModel.entities` |
| Sec.Q4 | ✓ | ✓ | Threat model approach — foundational; hybrid-only loop over `personas.primary` |
| Sec.Q5 | ✓ | — | Encryption at rest — depth; uses defaults in light (condition-skipped if no DB/file storage) |
| Sec.Q6 | ✓ | — | Encryption in transit — depth; uses defaults in light |
| Sec.Q7 | ✓ | — | Security headers + CORS — depth; uses defaults in light |
| Sec.Q8 | ✓ | — | Input validation — depth; uses defaults in light |
| Sec.Q9 | ✓ | — | Audit log retention — depth; condition-skipped for standard tier |
| Sec.Q10 | ✓ | — | Incident response — depth; uses defaults in light |
| Sec.Q11 | ✓ | — | Pentest cadence — depth; auto-skipped for hobby + standard |
| Sec.Q12 | ✓ | — | VDP / bug bounty — depth; auto-skipped for hobby + standard |
| Sec.Q13 | ✓ | — | Supply-chain controls — depth; uses defaults in light |
| Sec.Q_RISK | ✓ | ✓ | Always fires |
