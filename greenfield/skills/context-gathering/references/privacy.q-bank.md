# Privacy & Data Governance Q-bank — Step 6

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 6 (Privacy; preceded by Step 5 auth; auth.strategy gates this phase via skip-cascade)
> **Modes:** Heavy ~12 entries (Gate + Q1–Q11 + Q_RISK) / Light ~6 entries (foundational + Q_RISK; depth Qs use defaults)
> **Coupling:** Auto-loop on the data-access-scope Q (`loopMode: always`) over `personas.primary` — fires in BOTH auto-loop and hybrid coupling modes.
> **Skip-cascade:** Privacy.Gate fires only when `auth.strategy = 'none'`. If Gate = "No", Q1–Q11 are skipped (`privacy.synthesisStatus = 'n/a'`).
> **Source:** Q content migrated from `question-bank.md` § "Step 6: Privacy" (lines 591–778); R4 added Q_RISK + showInLight + loopOver tags + format conversion.
> **See also:** `auth.q-bank.md`, `security.q-bank.md`, `data-architecture.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk + § Coupling matrix.

This phase classifies the data captured in dataArchitecture, sets regulatory compliance scope, defines per-persona access, audit logging, retention, deletion/erasure, consent, and breach notification. Synthesis review fires inline after Privacy.Q_RISK. If `privacy.synthesisStatus='n/a'`, the n/a stub template is used.

## Q-bank

### Privacy.Gate — Data collection gate

- **type:** single-select
- **options:** ["Yes", "No"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `auth.strategy = 'none'` (fires only in skip-cascade case)
- **R3-updates-path:** `context.phases.privacy.synthesisStatus`

**Prompt:** "Do you collect any user data at all (emails, IPs, behavioral analytics, contact form submissions)?"

**Stores to:** `privacy.synthesisStatus`

**Default:** `"Yes"` (greenfield opinion: even no-auth apps usually collect minimal telemetry, IPs, or contact-form submissions — answer carefully)

**Skip-cascade:** If "No" → Privacy.Q1–Q11 all skipped; synthesis renders stub-only template; `phaseStatus.privacy.status='skipped'` (for un-skip detection in `pickup`). If "Yes" → `privacy.synthesisStatus = 'complete'` and proceed to Q1.

### Privacy.Q1 — Regulatory frameworks

- **type:** multi-select
- **options:** ["GDPR (EU / EEA)", "UK-GDPR", "CCPA / CPRA (California)", "LGPD (Brazil)", "PIPEDA (Canada)", "HIPAA (US health data)", "COPPA (under-13 users)", "None — no regulatory scope yet"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.regulations`

**Prompt:** "Which regulatory frameworks apply to your data handling?"

**Stores to:** `privacy.regulations[]`

**Downstream effects:** Privacy.Q3 (lawful basis) fires only if GDPR/UK-GDPR in this list; Privacy.Q7 (DSAR) fires only if GDPR or CCPA present; Privacy.Q11 (access audit) is mandatory if HIPAA present; Security phase reads `privacy.regulations[]` for compliance threat surface.

**Default:**
- If `dataArchitecture.compliance∈{GDPR-aware}` → pre-fill `["GDPR (EU / EEA)"]` (propagated from dataArchitecture phase — extend if additional jurisdictions apply)
- If `dataArchitecture.compliance∈{HIPAA}` → pre-fill `["HIPAA (US health data)"]` (propagated from dataArchitecture compliance selection)
- If `dataArchitecture.compliance∈{SOC2,PCI-DSS}` AND `architecturalFraming.scaleTarget∈{production-scale,enterprise}` → pre-fill `["GDPR (EU / EEA)", "CCPA / CPRA (California)"]` (greenfield opinion: production apps serving international users should at minimum address GDPR and CCPA — they cover the two largest regulatory jurisdictions with highest enforcement activity)
- If `architecturalFraming.scaleTarget='enterprise'` AND `dataArchitecture.compliance` not set → `["GDPR (EU / EEA)", "CCPA / CPRA (California)"]` (enterprise deployments almost always span EU and US users; assume both unless geographic scope is explicitly US-only)
- If `architecturalFraming.scaleTarget='hobby'` → `["None — no regulatory scope yet"]` (hobby apps rarely need formal compliance; revisit before launching to real users)
- Else → `["GDPR (EU / EEA)"]` (greenfield opinion: GDPR is the highest-bar regulation and a superset of many others — building to GDPR now avoids costly retrofits if the product expands into Europe)

### Privacy.Q2 — PII categories

- **type:** multi-select
- **options:** ["Email address", "Full name", "Physical address", "Phone number", "Precise location (GPS)", "Approximate location (IP-derived)", "Payment card data", "Bank account details", "Health / medical data", "Biometric data", "Behavioral analytics (clicks, sessions, heatmaps)", "Device fingerprint / user agent", "Government ID / SSN", "None — no PII collected"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.piiCategories`

**Prompt:** "What categories of PII does the app collect or process?"

**Stores to:** `privacy.piiCategories[]`

**Downstream effects:** Privacy.Q4 (retention) scopes per-category defaults; Privacy.Q8 (processors) cross-refs which categories are shared; Security phase reads `privacy.piiCategories[]` for data-breach impact scoring.

**Default:**
- If `auth.idps[]` includes `"Email + password"` OR any social IdP → auto-include `"Email address"` (any email-based IdP or social login collects at minimum the user's email)
- If `auth.idps[]` includes `"Phone / SMS OTP"` OR `auth.recovery` includes phone → auto-include `"Phone number"` (SMS-based flows require phone number collection and storage)
- If `apiIntegration.externalServices` includes any payment processor (Stripe, Braintree, etc.) → auto-include `"Payment card data"` (tokenized or not, payment flows process card data — may be processor-scoped but PII inventory must acknowledge it)
- If `dataArchitecture.compliance∈{HIPAA}` → auto-include `"Health / medical data"` (HIPAA scope implies health data collection by definition)
- If `architecturalFraming.scaleTarget∈{startup,production-scale,enterprise}` → auto-include `"Behavioral analytics (clicks, sessions, heatmaps)"` (production apps almost always instrument some form of behavioral analytics for product decisions)
- Else → `["Email address", "Approximate location (IP-derived)"]` (greenfield opinion: most web apps collect at minimum an email for auth and IP address for logging — acknowledge both even if no explicit location feature is planned)

### Privacy.Q3 — Lawful basis for processing

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` — **SKIP this question entirely if neither GDPR nor UK-GDPR is in `privacy.regulations[]`**
- **R3-updates-path:** `context.phases.privacy.lawfulBasis`

**Prompt:** "What is the lawful basis for processing each PII category?"

**Stores to:** `privacy.lawfulBasis` (object keyed by PII category)

**Sub-questions (per PII category from Privacy.Q2):**
- `basis` (single-select): `"consent"` | `"contract"` | `"legitimate interest"` | `"vital interest"` | `"legal obligation"` | `"public task"`
- `notes` (free-text): rationale (optional but recommended for audit trail)

**Downstream effects:** Synthesis renders lawful-basis table in `docs/adr/privacy.html`; Security phase flags if `"consent"` is basis for sensitive categories (biometric, health) — revocable consent requires consent-withdrawal flows.

**Default:**
- If `auth.strategy ≠ 'none'` AND category is `"Email address"` → `basis: "contract"` (email is required to fulfill the user account contract — login, password reset, transactional notifications)
- If category is `"Behavioral analytics (clicks, sessions, heatmaps)"` → `basis: "consent"` (analytics is not necessary for contract fulfillment; GDPR Article 6 requires explicit consent for non-essential processing)
- If category is `"Payment card data"` AND `apiIntegration.externalServices` includes payment processor → `basis: "contract"` (payment processing is necessary to fulfill the purchase contract)
- If category is `"Health / medical data"` → `basis: "consent"` (GDPR Article 9 special category — explicit consent is the safest and most common basis for health data unless you are a healthcare provider with legal obligation)
- If category is `"Approximate location (IP-derived)"` → `basis: "legitimate interest"` (IP-based geolocation for fraud detection and rate-limiting passes the legitimate-interest balancing test for most apps)
- Else → `basis: "legitimate interest"` (greenfield opinion: legitimate interest is a reasonable starting basis for many processing activities, but it requires a documented balancing test — replace with `contract` where the data is strictly necessary to provide the service)

### Privacy.Q4 — Data retention periods

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.retention`

**Prompt:** "What data retention periods apply per PII category?"

**Stores to:** `privacy.retention` (object keyed by PII category)

**Sub-questions (per PII category from Privacy.Q2):**
- `period` (short-text): e.g., `"90d"` | `"1y"` | `"3y"` | `"7y"` | `"duration-of-account"` | `"indefinite"` | `"session-only"`
- `deletionTrigger` (single-select): `"account-deletion"` | `"user-request"` | `"expiry"` | `"regulatory-mandate"` | `"manual-review"`

**Downstream effects:** Privacy.Q5 (deletion flow) uses retention periods to scope deletion logic; Security phase reads retention to flag long-lived sensitive data as elevated breach risk.

**Default:**
- If `privacy.regulations[]` includes `"HIPAA"` AND category is `"Health / medical data"` → `period: "7y"`, `deletionTrigger: "regulatory-mandate"` (HIPAA requires 6-year minimum record retention from date of creation or date last in effect; rounded to 7y for safety)
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `period: "duration-of-account"`, `deletionTrigger: "account-deletion"` (GDPR data minimization principle: retain only as long as necessary; account-duration is the most defensible default for account-linked data)
- If category is `"Payment card data"` → `period: "7y"`, `deletionTrigger: "regulatory-mandate"` (financial records typically require 7-year retention for tax/audit compliance; card data itself should be tokenized and not stored raw)
- If category is `"Behavioral analytics (clicks, sessions, heatmaps)"` → `period: "90d"`, `deletionTrigger: "expiry"` (analytics data loses product value after 90d for most apps; longer retention inflates breach impact without proportionate benefit)
- If category is `"Approximate location (IP-derived)"` → `period: "90d"`, `deletionTrigger: "expiry"` (IP logs are primarily useful for fraud investigation; 90d covers most incident response windows)
- Else → `period: "duration-of-account"`, `deletionTrigger: "account-deletion"` (greenfield opinion: account-linked data should expire when the account is deleted — this is the simplest policy to implement correctly and satisfies most regulators' data minimization requirements)

### Privacy.Q5 — Deletion / erasure flow

- **type:** single-select
- **options:** ["Hard delete (immediate, irreversible purge)", "Soft delete + anonymization (nullify PII fields, retain record shell)", "Soft delete with grace window (restore possible within N days)", "Deletion request workflow (user submits request, admin processes within SLA)", "No deletion flow — data retained per retention schedule only"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.deletionFlow`

**Prompt:** "How should the app handle user data deletion requests?"

**Stores to:** `privacy.deletionFlow`

**Downstream effects:** Synthesis generates deletion flow ADR section; Security phase reads deletion approach for breach-notification readiness scoring.

**Default:**
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` OR `"CCPA / CPRA (California)"` → `"Soft delete + anonymization (nullify PII fields, retain record shell)"` (GDPR Article 17 right to erasure; CCPA right to deletion — soft delete + anonymization satisfies erasure obligations while preserving referential integrity for financial/audit records)
- If `auth.lifecycle.accountDeletion='self-serve-immediate'` → `"Hard delete (immediate, irreversible purge)"` (if account deletion is self-serve and immediate, data deletion should follow the same model for consistency)
- If `auth.lifecycle.accountDeletion='self-serve-soft-delete'` → `"Soft delete with grace window (restore possible within N days)"` (align with the account deletion model; grace window allows accidental-deletion recovery before purge)
- If `architecturalFraming.scaleTarget='enterprise'` → `"Deletion request workflow (user submits request, admin processes within SLA)"` (enterprise apps often need deletion to be a controlled event with approvals, especially when financial records or contractual data is involved)
- If `architecturalFraming.scaleTarget='hobby'` → `"Hard delete (immediate, irreversible purge)"` (simplest implementation; hobby apps rarely have audit-trail requirements that mandate soft-delete)
- Else → `"Soft delete + anonymization (nullify PII fields, retain record shell)"` (greenfield opinion: soft delete + anonymization is the safest default — it satisfies regulatory erasure obligations, preserves aggregate analytics, and avoids foreign-key integrity failures that hard delete causes in relational schemas)

### Privacy.Q6 — Consent management

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `privacy.piiCategories[]` includes `"Behavioral analytics"` OR `apiIntegration.externalServices` includes any marketing/ads tool — **SKIP this question entirely if neither condition is met**
- **R3-updates-path:** `context.phases.privacy.consentManager`

**Prompt:** "What consent management approach should the app use?"

**Stores to:** `privacy.consentManager` (object)

**Sub-questions:**
- `mechanism` (single-select): `"cookie-banner (IAB TCF)"` | `"custom-consent-modal"` | `"settings-page-only"` | `"implied-consent (privacy-policy link)"` | `"none"`
- `granularity` (single-select): `"all-or-nothing"` | `"by-category (analytics / marketing / functional)"` | `"per-vendor"`
- `storage` (single-select): `"cookie"` | `"db-per-user"` | `"local-storage"` | `"none"`
- `withdrawalFlow` (single-select): `"settings-toggle"` | `"support-email"` | `"none"`

**Downstream effects:** Synthesis generates cookie-policy section in `docs/adr/privacy.html`; scaffolding suggests consent-library (e.g., Cookiebot, Osano) if IAB TCF selected.

**Default:**
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `mechanism: "cookie-banner (IAB TCF)"`, `granularity: "by-category (analytics / marketing / functional)"`, `storage: "db-per-user"`, `withdrawalFlow: "settings-toggle"` (GDPR requires prior consent for non-essential cookies; IAB TCF is the industry standard; per-category granularity is required; withdrawal must be as easy as giving consent)
- If `privacy.regulations[]` includes `"CCPA / CPRA (California)"` AND NOT GDPR → `mechanism: "custom-consent-modal"`, `granularity: "all-or-nothing"`, `storage: "cookie"`, `withdrawalFlow: "settings-toggle"` (CCPA opt-out model vs GDPR opt-in; simpler implementation but must offer "Do Not Sell My Personal Information" link)
- If `architecturalFraming.scaleTarget='hobby'` → `mechanism: "implied-consent (privacy-policy link)"`, `granularity: "all-or-nothing"`, `storage: "none"`, `withdrawalFlow: "none"` (hobby apps outside EU/CA can use implied consent with a privacy policy link; revisit if you plan to serve EU users)
- If `architecturalFraming.scaleTarget='enterprise'` → `mechanism: "cookie-banner (IAB TCF)"`, `granularity: "per-vendor"`, `storage: "db-per-user"`, `withdrawalFlow: "settings-toggle"` (enterprise apps must demonstrate consent auditability; per-vendor granularity is required for GDPR DPA relationships)
- Else → `mechanism: "custom-consent-modal"`, `granularity: "by-category (analytics / marketing / functional)"`, `storage: "db-per-user"`, `withdrawalFlow: "settings-toggle"` (greenfield opinion: a custom modal gives you design control while implementing category-level consent; storing consent in the DB (not just a cookie) ensures consent records survive cookie clearing and can be exported in DSAR responses)

### Privacy.Q7 — DSAR / data export flow

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `privacy.regulations[]` includes `"GDPR (EU / EEA)"`, `"UK-GDPR"`, OR `"CCPA / CPRA (California)"` — **SKIP this question entirely if none of these regulations are in `privacy.regulations[]`**
- **R3-updates-path:** `context.phases.privacy.dsar`

**Prompt:** "What data subject access request (DSAR) / data export flow is needed?"

**Stores to:** `privacy.dsar` (object)

**Sub-questions:**
- `flow` (single-select): `"self-serve-portal"` | `"email-request-to-support"` | `"in-app-download"` | `"none"`
- `format` (single-select): `"JSON"` | `"CSV"` | `"PDF"` | `"multiple-formats"`
- `sla` (single-select): `"30d"` | `"45d"` | `"72h-breach-only"` | `"best-effort"` | `"none"`
- `scope` (single-select): `"all-data"` | `"user-generated-data-only"` | `"account-data-only"`

**Downstream effects:** Synthesis generates DSAR process ADR section; scaffolding suggests data-export service patterns if `flow='in-app-download'`.

**Default:**
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `flow: "in-app-download"`, `format: "JSON"`, `sla: "30d"`, `scope: "all-data"` (GDPR Article 15 right of access + Article 20 data portability: 30-day SLA is legally mandated; machine-readable format required for portability; all personal data in scope)
- If `privacy.regulations[]` includes `"CCPA / CPRA (California)"` AND NOT GDPR → `flow: "email-request-to-support"`, `format: "CSV"`, `sla: "45d"`, `scope: "all-data"` (CCPA allows 45-day response; email-based flow is compliant for smaller apps; CSV is acceptable format)
- If `architecturalFraming.scaleTarget='enterprise'` → `flow: "self-serve-portal"`, `format: "multiple-formats"`, `sla: "30d"`, `scope: "all-data"` (enterprise apps should offer self-serve DSAR to reduce support load; multiple formats for accessibility; 30d as conservative default)
- If `architecturalFraming.scaleTarget='hobby'` AND regulations require DSAR → `flow: "email-request-to-support"`, `format: "JSON"`, `sla: "30d"`, `scope: "user-generated-data-only"` (hobby apps can comply with email-based DSAR workflow; limit export scope to reduce implementation burden)
- Else → `flow: "in-app-download"`, `format: "JSON"`, `sla: "30d"`, `scope: "all-data"` (greenfield opinion: in-app self-serve download scales better than email-based DSAR as user count grows; JSON is the most interoperable format for data portability)

### Privacy.Q8 — Third-party processors

- **type:** multi-select
- **options:** ["Analytics provider (Mixpanel, Amplitude, PostHog)", "Error tracker (Sentry, Datadog)", "Email provider (SendGrid, Resend, Postmark)", "Payment processor (Stripe, Braintree)", "CRM (HubSpot, Salesforce)", "Marketing / ads platform (Meta, Google Ads)", "Customer support (Intercom, Zendesk)", "Cloud infrastructure provider (AWS, GCP, Azure)", "None — no third-party PII sharing"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.processors`

**Prompt:** "Which third-party services receive or process user PII?"

**Stores to:** `privacy.processors[]`

**Note:** Options are derived from `apiIntegration.externalServices` list plus common additions above.

**Downstream effects:** Synthesis generates third-party processor table in `docs/adr/privacy.html`; Privacy.Q10 (cross-border transfer) uses processors list to identify data residency implications; Security phase reads processors list for supply-chain risk.

**Default:**
- If `apiIntegration.externalServices` includes analytics tools → auto-include relevant analytics processor (processors list is pre-filled from `apiIntegration.externalServices` — review and confirm rather than start from scratch)
- If `apiIntegration.externalServices` includes payment services → auto-include payment processor entry
- If `auth.strategy` includes `"Hosted"` (Clerk, Auth0, etc.) → auto-include the auth provider as a processor (hosted auth providers process user credentials and PII as data processors — DPA is required)
- If `architecturalFraming.scaleTarget∈{startup,production-scale,enterprise}` → auto-include `"Cloud infrastructure provider (AWS, GCP, Azure)"` (your cloud provider is a data processor for all data you store with them — DPA/BAA required for HIPAA)
- If `auth.strategy='self-hosted-oss'` → auto-include self-hosted auth system as internal processor (greenfield opinion: self-hosted OSS auth (Keycloak, Authentik, Ory) processes user credentials internally — document it in the processor inventory to maintain a complete data-flow map)
- Else → pre-fill from `apiIntegration.externalServices` where PII handling is likely; prompt user to confirm and add any omitted processors (greenfield opinion: every integration that touches user data needs a DPA — start with your cloud provider and auth system at minimum)

### Privacy.Q9 — Data minimization and anonymization

- **type:** multi-select
- **options:** ["IP truncation before storage (last octet removed)", "Anonymize analytics events after 90 days", "Hash or tokenize PII in logs", "Pseudonymize user IDs in analytics pipelines", "Aggregate-only reporting (no individual-level data retained)", "Differential privacy for exported aggregates", "None — no minimization techniques applied"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.minimization`

**Prompt:** "What data minimization and anonymization practices will be applied?"

**Stores to:** `privacy.minimization`

**Downstream effects:** Security phase reads minimization list for breach-impact scoring (minimized data = lower severity); Synthesis notes minimization practices in `docs/adr/privacy.html`.

**Default:**
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `["IP truncation before storage (last octet removed)", "Anonymize analytics events after 90 days", "Pseudonymize user IDs in analytics pipelines"]` (GDPR Article 5(1)(c) data minimization principle; IP truncation means truncated IPs are no longer personal data under GDPR recital 26; anonymization after 90d removes GDPR obligations from historical analytics)
- If `privacy.piiCategories[]` includes `"Health / medical data"` OR `"Biometric data"` → `["Hash or tokenize PII in logs", "Pseudonymize user IDs in analytics pipelines"]` (sensitive special-category data should never appear in plaintext in logs; tokenization limits blast radius on log exfiltration)
- If `architecturalFraming.scaleTarget∈{production-scale,enterprise}` → `["IP truncation before storage (last octet removed)", "Pseudonymize user IDs in analytics pipelines", "Hash or tokenize PII in logs"]` (production apps should minimize PII surface area as a defense-in-depth measure — breach impact is directly proportional to the PII retained)
- If `architecturalFraming.scaleTarget='hobby'` → `["IP truncation before storage (last octet removed)"]` (IP truncation is low-effort, high-value — implement it even for hobby apps since it's one line of middleware)
- Else → `["IP truncation before storage (last octet removed)", "Anonymize analytics events after 90 days"]` (greenfield opinion: IP truncation and analytics anonymization are the two highest-ROI minimization techniques — minimal engineering effort, significant reduction in GDPR and breach-severity exposure)

### Privacy.Q10 — Cross-border transfer and data residency

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.dataResidency`

**Prompt:** "What cross-border data transfer mechanisms and residency constraints apply?"

**Stores to:** `privacy.dataResidency` (object)

**Sub-questions:**
- `residencyConstraints` (single-select): `"EU-only"` | `"US-only"` | `"country-specific (specify)"` | `"no-constraints"` | `"unknown"`
- `transferMechanisms` (multi-select): `"EU adequacy decision"` | `"Standard Contractual Clauses (SCC)"` | `"Binding Corporate Rules (BCR)"` | `"Data Processing Agreement (DPA)"` | `"None — no cross-border transfers"` | `"Unknown — needs legal review"`
- `primaryRegion` (short-text): cloud region (e.g., `"eu-west-1"`, `"us-east-1"`) — derived from `architecturalFraming`

**Downstream effects:** Synthesis generates cross-border transfer section in `docs/adr/privacy.html`; scaffolding recommends cloud region configuration matching residency constraints; Privacy.Q8 processors list feeds SCC applicability.

**Default:**
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` AND `privacy.processors[]` includes US-based services → `residencyConstraints: "EU-only"`, `transferMechanisms: ["Standard Contractual Clauses (SCC)", "Data Processing Agreement (DPA)"]` (post-Schrems II, SCCs are the primary transfer mechanism for EU→US data flows; DPA is required for each processor)
- If `privacy.regulations[]` includes `"HIPAA"` → `residencyConstraints: "US-only"`, `transferMechanisms: ["Data Processing Agreement (DPA)"]`, `primaryRegion: "us-east-1"` (HIPAA PHI should remain within US jurisdiction; BAA (which is a form of DPA) required for all processors handling PHI)
- If `architecturalFraming.scaleTarget='enterprise'` AND `privacy.regulations[]` not empty → `residencyConstraints: "country-specific (specify)"`, `transferMechanisms: ["Standard Contractual Clauses (SCC)", "Data Processing Agreement (DPA)", "Binding Corporate Rules (BCR)"]` (enterprise deployments often have contractual or regulatory data residency requirements — get specific requirements from legal/compliance before choosing region)
- If `architecturalFraming.scaleTarget='hobby'` → `residencyConstraints: "no-constraints"`, `transferMechanisms: ["None — no cross-border transfers"]` (hobby apps rarely have cross-border data transfer obligations; revisit before serving EU users)
- If `auth.strategy='self-hosted-oss'` AND `privacy.regulations[]` includes GDPR → `residencyConstraints: "EU-only"`, `transferMechanisms: ["Data Processing Agreement (DPA)"]` (self-hosted auth keeps credentials on your infrastructure — ensure your cloud region is EU-based and your cloud provider has an EU DPA)
- Else → `residencyConstraints: "no-constraints"`, `transferMechanisms: ["Data Processing Agreement (DPA)"]` (greenfield opinion: even without strict residency constraints, sign DPAs with every processor that handles user data — it's a lightweight compliance requirement that becomes mandatory as soon as any EU users sign up)

### Privacy.Q11 — Per-persona data access scope

- **type:** single-select
- **options:** ["Own data only (users see only their own records)", "Org-wide read (members read all org data)", "Read-only cross-org (analytics/reporting across tenants)", "Admin / privileged access (full dataset visibility)", "Role-defined (varies per persona role)"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (after Gate = "Yes" or `auth.strategy ≠ 'none'`)
- **R3-updates-path:** `context.phases.privacy.accessAudit`
- **loopOver:** personas.primary
- **loopMode:** always <!-- fires in both auto-loop and hybrid -->

**Prompt:** "For persona {persona.id}: What data access scope applies to this persona — which records can they see and export?"

**Stores to:** `privacy.accessAudit`

**answerSchema:** `{ personaId: string, accessScope: string, auditEnabled: boolean, auditEvents: [string], retention: string, storage: string, immutable: boolean }`

**Note:** Access scope drives audit log configuration. If `privacy.regulations[]` includes `"HIPAA"`, `auditEnabled` is mandatory `true` regardless of persona. If `privacy.piiCategories[]` contains only non-sensitive categories AND `privacy.regulations[]` does not include HIPAA, GDPR, or CCPA, `auditEnabled` defaults to `false`.

**Downstream effects:** Security phase reads `privacy.accessAudit.enabled` for insider-threat mitigation score; auth audit log cross-reference ensures no coverage gap between `auth.auditLog` (authentication events) and `privacy.accessAudit` (data access events).

**Default:**
- If `privacy.regulations[]` includes `"HIPAA"` → `accessScope: "Role-defined"`, `auditEnabled: true`, `auditEvents: ["user-record-read","user-record-update","user-record-export","admin-lookup","bulk-export","deletion-request"]`, `retention: "7y"`, `storage: "separate-audit-db"`, `immutable: true` (HIPAA §164.312(b) audit control standard: access to PHI must be logged; 6-year minimum rounded to 7y; tamper-evidence is required for audit defensibility; separate DB ensures log integrity if app DB is compromised)
- If `privacy.regulations[]` includes `"GDPR (EU / EEA)"` OR `"UK-GDPR"` → `accessScope: "Own data only (users see only their own records)"`, `auditEnabled: true`, `auditEvents: ["user-record-read","admin-lookup","user-record-export","deletion-request","consent-change"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: false` (GDPR accountability principle requires ability to demonstrate lawful processing; access logs support data breach response and DSAR fulfillment audit trails)
- If `privacy.piiCategories[]` includes `"Health / medical data"` OR `"Biometric data"` → `accessScope: "Role-defined"`, `auditEnabled: true`, `auditEvents: ["user-record-read","admin-lookup","bulk-export","user-record-export"]`, `retention: "1y"`, `storage: "separate-audit-db"`, `immutable: true` (special-category data access should always be logged — insider threat risk is highest for sensitive categories)
- If `architecturalFraming.scaleTarget='enterprise'` → `accessScope: "Role-defined"`, `auditEnabled: true`, `auditEvents: ["user-record-read","user-record-update","admin-lookup","bulk-export","deletion-request","consent-change"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: false` (enterprise apps should log all PII access for compliance audits and insider-threat detection)
- If `architecturalFraming.scaleTarget='hobby'` → `accessScope: "Own data only (users see only their own records)"`, `auditEnabled: false` (hobby apps do not need PII access audit logs; the overhead outweighs the benefit at hobby scale — revisit if the product grows or serves regulated users)
- Else → `accessScope: "Own data only (users see only their own records)"`, `auditEnabled: true`, `auditEvents: ["admin-lookup","bulk-export","deletion-request"]`, `retention: "90d"`, `storage: "app-db"`, `immutable: false` (greenfield opinion: log at minimum admin lookups and bulk exports — these are the highest-risk access patterns for PII misuse. 90d covers most incident response windows without long-term storage cost)

**After Privacy.Q11**, invoke synthesis-review inline:

> Invoke `Skill(synthesis-review, phaseId: "privacy")` — renders `docs/adr/privacy.html` and walks the developer through approve/adjust/skip. If `privacy.synthesisStatus='n/a'`, the n/a stub template is used.

---

### Privacy.Q_RISK — Privacy/governance risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["compliance", "dataloss"]

**Prompt:** "What's the biggest privacy/governance risk for THIS project? (e.g., 'storing audit photos creates GDPR-erasure complexity', 'no consent revocation API', 'cross-border data transfer mechanism not defined'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "privacy"`, id auto-assigned `R-PRIVACY-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Privacy.Gate | ✓ | ✓ | Skip-cascade gate — fires only when `auth.strategy='none'`; foundational |
| Privacy.Q1 | ✓ | ✓ | Regulatory frameworks — gates compliance scope for downstream Qs |
| Privacy.Q2 | ✓ | ✓ | PII categories — foundational inventory for all downstream privacy decisions |
| Privacy.Q3 | ✓ | — | Lawful basis — depth; condition-skipped if no GDPR/UK-GDPR |
| Privacy.Q4 | ✓ | — | Retention periods — depth, uses defaults in light |
| Privacy.Q5 | ✓ | ✓ | Deletion/erasure flow — foundational right-to-erasure compliance |
| Privacy.Q6 | ✓ | ✓ | Consent management — foundational; condition-skipped if no analytics/marketing |
| Privacy.Q7 | ✓ | — | DSAR / data export — depth; condition-skipped if no GDPR/CCPA |
| Privacy.Q8 | ✓ | — | Third-party processors — depth, uses default pre-fill in light |
| Privacy.Q9 | ✓ | — | Data minimization — depth, uses defaults in light |
| Privacy.Q10 | ✓ | — | Cross-border transfer — depth, uses defaults in light |
| Privacy.Q11 | ✓ | ✓ | Per-persona data access scope — foundational (loops per persona; data-access-scope Q, always mode) |
| Privacy.Q_RISK | ✓ | ✓ | Always fires |
