# Section Prompts — Synthesis Composition Strategies

Per-section guidance for the synthesis-review skill (Step 2). Loaded at runtime; updates here flow into all future syntheses without code changes elsewhere.

## Section anatomy

Every synthesis section contains, in order:

1. **Section title** — human-friendly name (e.g., "CI Provider", "Pre-merge Gates").
2. **Captured-as** — actual value(s) collected during the wizard, rendered in a `<pre class="captured">` block. Always include the originating wizard question ID (Q5.4 etc.) for traceability.
3. **Cross-checks** — one bullet per declared dependency from `context.dependencies[phaseId]`. Format: `Assumes <dependency-path> = <value>.` followed by the rationale. If the dependency was not yet captured at synthesis time, render "not yet captured" rather than blocking.
4. **Contradictions** (only if any) — auto-detected mismatches between the section value and any dependency. Rendered as `<div class="contradiction">`.
5. **Notes for the developer** — anything the LLM noticed during composition that the developer should be aware of (rendered as `<div class="note">`).

## Contradiction detection

Run these checks at compose time. Each one fires only if both endpoint values exist.

| Check | Condition | Fires |
|---|---|---|
| Deploy-without-deploy | `phases.cicdAndDelivery.cicd.envLadder` includes "prod" AND `phases.vision.willDeploy === false` | "cicdAndDelivery picked a production environment but vision said this project won't deploy. One of these is wrong — resolve." |
| Notifications-without-channel | `phases.cicdAndDelivery.cicd.notifications.channels` includes a channel whose corresponding stack field (e.g., Slack workspace URL) is unset | "cicdAndDelivery wants to notify on `<channel>` but the connection details haven't been captured yet." |
| Coverage-blocking-without-tests | `phases.cicdAndDelivery.cicd.coverage.blocking === true` AND `phases.workflow.testingPhilosophy` (Round 3) is `"manual-only"` | "cicdAndDelivery wants coverage to block PRs, but workflow said testing is manual-only. The block will fail every PR." |

Round 1 ships only the first check. The second and third require Round 3's `workflow` phase — the rules are documented here so they fire automatically once that phase lands.

## Round 2.5 sections (Step 2.5: Architectural Framing)

Use this table to compose `architectural-framing.html` sections. This synthesis fires before Data Architecture (Step 3), so its dependencies are backward-looking: only vision and stack are earlier phases.

| Section | Maps to (context.phases.architecturalFraming.*) | Cross-checks |
|---|---|---|
| Topology & deployment shape | `topology`, `deploymentShape` | Assumes `vision.willDeploy`. Cross-check: `topology: serverless` + `deploymentShape: on-prem` contradicts (serverless requires cloud infrastructure). |
| Scale & boundaries | `scaleTarget`, `boundaryNotes` | Assumes `vision.teamSize` (deferred to Round 4 — annotate as "not yet captured"). Note if `scaleTarget: enterprise` && `topology: monolith` (not a contradiction, but flag for architectural review). |
| Downstream implications | (derived) | Note that topology/deploymentShape/scaleTarget will be read by P3 (Data Architecture), P4 (API & Integration), and P7 (CI/CD & Delivery). If the developer adjusts any field here, remind them the detailed steps will inherit the updated value. |

### Contradiction rules specific to Architectural Framing

Append to the contradiction table:

| Check | Condition | Fires |
|---|---|---|
| Serverless-on-prem | `phases.architecturalFraming.topology === "serverless"` AND `phases.architecturalFraming.deploymentShape === "on-prem"` | "Architectural Framing picked serverless topology but on-premises deployment. Serverless by definition requires cloud infrastructure — pick a cloud deployment shape or change topology to monolith." |
| Boundary-without-microservices | `phases.architecturalFraming.boundaryNotes` contains isolation language (e.g., "isolated", "separate", "must not touch") AND `phases.architecturalFraming.topology === "monolith"` | "Architectural Framing notes hard isolation boundaries but topology is monolith. Strict isolation is achievable in a monolith via module boundaries (modular-monolith), but often signals microservices intent. Confirm the topology choice." |

## Round 1 sections (Step 7: CI/CD & Delivery)

Use this table to compose `cicd-and-delivery.html` sections.

| Section | Maps to (context.phases.cicdAndDelivery.cicd.*) | Cross-checks |
|---|---|---|
| Pipeline trigger model | `provider`, `triggers[]` | Assumes `vision.willDeploy = true`. |
| Pre-merge quality gates | `requiredPreMergeChecks[]`, `coverage{}` | Assumes `workflow.testingPhilosophy` (deferred to Round 3 — annotate as "not yet captured"). |
| Environment ladder & deploy strategy | `envLadder[]`, `autoDeploy`, `deployCadence` | Assumes `vision.willDeploy`. Cross-check: any env beyond "dev" requires willDeploy=true. |
| Secrets & rollback | `secrets{}`, `rollback{}` | Assumes `dataArchitecture.databaseHost` (deferred to Round 2 — annotate). |
| Notifications & on-call | `notifications{}` | Assumes `vision.teamSize`. Lone-developer + Slack notifications combination produces a warning note. |
| Performance & cost | `buildMatrix{}`, `caching{}`, `timeBudget{}` | None for Round 1. |
| Release pipeline | `releasePipeline{}` | Assumes `stack.stack`. release-please needs Node tooling; semantic-release needs Node tooling. Flag mismatches. |
| Auto-evolution & PR review | `_v1_carryover.ciAuditAction`, `_v1_carryover.autoEvolutionMode`, `_v1_carryover.prReviewTrigger` | None — these are the legacy Q5.1/Q5.2/Q5.3 answers preserved as-is. |

## Round 2 sections (Step 3: Data Architecture)

Use this table to compose `data-architecture.html` sections.

| Section | Maps to (context.phases.dataArchitecture.*) | Cross-checks |
|---|---|---|
| Database engine & host | `engine`, `databaseHost` | Assumes `vision.willDeploy`. Note if `databaseHost: none` && `stack.stack.database` is set. |
| Schema & migrations | `orm`, `migrationsTool`, `migrationsMode` | Assumes `stack.stack.language`. Contradiction if `orm: prisma` && `stack.stack.language: python`. |
| Multi-tenancy isolation | `multiTenancy` | Assumes future `authSecurity` (Round 3 — render "not yet captured"). |
| Search & retrieval | `search` | None. Note if search mentions "vector" && `engine` is not vector-capable. |
| Caching | `cache`, `cacheInvalidation` | Assumes `vision.teamSize`. Solo + multi-layer cache produces over-engineering note. |
| File / object storage | `fileStorage` | Assumes `vision.willDeploy`. Local-FS + willDeploy=true triggers deployment-portability note. |
| Codegen, backup & compliance | `codegen[]`, `backup`, `compliance` | Note if `compliance: hipaa` && `backup !~ "managed\|continuous"`. |

## Round 2 sections (Step 4: API & Integration)

Use this table to compose `api-integration.html` sections.

| Section | Maps to (context.phases.apiIntegration.*) | Cross-checks |
|---|---|---|
| API style & documentation | `style`, `documentation` | Assumes `stack.stack.framework`. Contradiction if `style: trpc` && `stack.stack.language != typescript`. Note if `style: graphql` && `dataArchitecture.codegen[]` doesn't include graphql codegen. |
| Versioning | `versioningPolicy` | Note if `versioningPolicy: none-yet` && `vision.willDeploy: true` && `vision.teamSize != solo`. |
| Surface protection | `rateLimit`, `pagination` | Assumes `dataArchitecture.cache`. Note if `rateLimit` is set but `dataArchitecture.cache: none`. |
| Async patterns | `asyncPattern` | Contradiction if `asyncPattern: queue-and-worker` && `dataArchitecture.cache` doesn't include a broker-capable store. Note if `asyncPattern: serverless-functions` && `cicdAndDelivery.cicd.provider: none`. |
| Real-time | `realtime` | Note if `realtime != none` && `vision.willDeploy: false`. |
| Webhooks & external integrations | `webhooks`, `externalServices[]` | Note if `webhooks` mentions "outgoing" && `externalServices[]` empty. Note PCI-scope flag if `externalServices[]` includes a payment vendor. |

## Round 2.5 contradiction-detection additions (Architectural Framing)

Append to the contradiction table above the section-prompts file:

| Check | Condition | Fires |
|---|---|---|
| Serverless-on-prem | `phases.architecturalFraming.topology === "serverless"` AND `phases.architecturalFraming.deploymentShape === "on-prem"` | "Architectural Framing picked serverless topology but on-premises deployment. Serverless requires cloud infrastructure — pick a cloud deployment shape or change topology to monolith." |
| Serverless-ORM-native-migrations | `phases.architecturalFraming.topology === "serverless"` AND `phases.dataArchitecture.migrationsTool === "orm-native"` | "Architectural Framing picked serverless topology but Data Architecture chose ORM-native migrations. ORM-native migrations (Prisma migrate, Drizzle kit) run as long-lived processes — they conflict with function lifecycle. Switch to Flyway, Liquibase, or raw-SQL migrations run as a separate job." |
| Microservices-embedded-DB | `phases.architecturalFraming.topology === "microservices"` AND `phases.dataArchitecture.databaseHost === "embedded"` | "Architectural Framing picked microservices but Data Architecture chose an embedded DB. Embedded databases (SQLite, DuckDB) are single-process — they cannot be shared across microservices. Use a managed or serverless RDBMS instead." |
| Isolation-note-with-monolith | `phases.architecturalFraming.boundaryNotes` includes isolation language AND `phases.architecturalFraming.topology === "monolith"` | "Architectural Framing notes hard isolation requirements but topology is monolith. Consider modular-monolith for enforced module boundaries, or microservices for true runtime isolation." |

## Round 2 contradiction-detection additions

Append to the contradiction table above the section-prompts file:

| Check | Condition | Fires |
|---|---|---|
| Prisma-on-Python | `phases.dataArchitecture.orm === "prisma"` AND `phases.stack.stack.language === "python"` | "Data Architecture picked Prisma but Stack said the language is Python. Prisma is TypeScript-only — pick SQLAlchemy / Django ORM / raw-sql instead." |
| tRPC-on-non-TS | `phases.apiIntegration.style === "trpc"` AND `phases.stack.stack.language !== "typescript"` | "API & Integration picked tRPC but Stack said the language isn't TypeScript. tRPC is TS-only — pick REST or GraphQL instead." |
| Queue-without-broker | `phases.apiIntegration.asyncPattern === "queue-and-worker"` AND `phases.dataArchitecture.cache` is empty OR doesn't include a broker-capable string | "API & Integration wants a queue+worker but Data Architecture cache doesn't include a broker. Either add Redis/RabbitMQ to dataArchitecture cache or pick scheduled-cron." |

## Round 2.5 sections (Step 11: Architectural Validation)

Use this table to compose `architectural-validation.html` sections. This synthesis fires LAST — after all other phases have been approved. Its dependencies are forward-looking (all prior phases) rather than backward-looking.

| Section | Maps to (context.phases.architecturalValidation.* + prior phases) | Cross-checks |
|---|---|---|
| Framing → Data Architecture divergences | Compare `architecturalFraming.{topology,deploymentShape,scaleTarget}` against `dataArchitecture.*` final values | Serverless + orm-native migrations; microservices + embedded DB; edge-distributed + managed RDBMS driver issues |
| Framing → API & Integration divergences | Compare `architecturalFraming.topology` against `apiIntegration.asyncPattern` | Serverless + queue-and-worker contradict; microservices + no-api-surface unusual |
| Framing → CI/CD divergences | Compare `architecturalFraming.scaleTarget` against `cicdAndDelivery.cicd.{envLadder,releasePipeline}` | Hobby + full release pipeline over-engineered; enterprise + no env ladder under-specified |
| Data ↔ API cross-checks | `apiIntegration.asyncPattern` vs `dataArchitecture.cache` | Queue-and-worker without a broker-capable cache store |
| Sign-off & divergence record | `signOffStatus`, `divergences[]`, `unresolvedContradictions[]`, `finalNotes` | None — this section records the developer's explicit sign-off and any noted exceptions |

### Contradiction rules specific to Architectural Validation

All pre-existing contradiction rules from earlier phases are re-evaluated here with final values. Additional rules:

| Check | Condition | Fires |
|---|---|---|
| Framing-drift-serverless-orm | `phases.architecturalFraming.topology === "serverless"` AND `phases.dataArchitecture.migrationsTool === "orm-native"` (final approved) | "Architectural Framing set topology=serverless but Data Architecture approved orm-native migrations. ORM-native migrations (Prisma migrate, Drizzle kit) are long-lived processes — they conflict with serverless function lifecycle. Record as divergence or send back for rework." |
| Framing-drift-microservices-embedded | `phases.architecturalFraming.topology === "microservices"` AND `phases.dataArchitecture.databaseHost === "embedded"` (final approved) | "Architectural Framing set topology=microservices but Data Architecture approved an embedded DB. Embedded databases cannot be shared across service boundaries. Record as divergence or send back for rework." |
| Framing-drift-hobby-enterprise-pipeline | `phases.architecturalFraming.scaleTarget === "hobby"` AND `phases.cicdAndDelivery.cicd.releasePipeline.separate === true` | "Architectural Framing set scaleTarget=hobby but CI/CD approved a separate release pipeline. A full release pipeline for a hobby project is over-engineered; note as divergence." |
| Unapproved-synthesis | Any key in `{ "architecturalFraming", "dataArchitecture", "apiIntegration", "cicdAndDelivery" }` missing from `context.syntheses` entirely | "Phase <X> has no synthesis record — it was never reviewed via Approve/Adjust/Skip. Validation is incomplete for that phase." |

### Section composition notes for Architectural Validation

This synthesis is read-only — it does not capture new wizard answers (those came in Steps 1–10). The synthesis-review skill must:
1. Build the divergence table by diffing `context.phases.architecturalFraming.*` against the final approved values in all subsequent phases.
2. Render each contradiction that fired as a row in the "Unresolved Contradictions" section if `signOffStatus !== "approved"`.
3. Render `finalNotes` verbatim (developer owns this text; do not paraphrase or truncate).
4. The "Sign-off" section renders `signOffStatus` prominently — this is the gate that grill-spec reads.

## Tone

- Render captured values verbatim. Do not paraphrase.
- Cross-checks are descriptive, not interrogative. "Assumes vision.willDeploy = true." not "Did you remember that vision said willDeploy is true?"
- Contradictions are blunt. "cicdAndDelivery wants to auto-deploy to prod, but vision said this project won't deploy. One of these is wrong."
- Notes are colloquial. "Heads-up — you picked GitLab CI but Round 1 only emits GitHub Actions templates."

## Anti-patterns

- Don't invent dependency cross-checks that don't have both endpoints captured. Render "not yet captured" instead.
- Don't soften contradictions. They're the point.
- Don't write more than ~3 lines per section's Notes block. Long notes belong in `CLAUDE.md`.
- Don't omit the `Captured-as` block even if the value is `null` — render `null` explicitly so the developer sees the gap.

## Round 3 sections (Step 5: Auth)

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Strategy & Provider | strategy, provider | always |
| Identity Providers | idps | hidden if strategy='none' |
| Session & Token Model | sessionModel | hidden if strategy='none' |
| MFA & Account Security | mfa, passwordPolicy, recovery | hidden if strategy='none' |
| Authorization & Tenancy | authzModel, enforcementPoint, tenantResolution | always |
| Service-to-Service Auth | serviceAuth | hidden if architecturalFraming.topology='monolith' |
| Audit & Lifecycle | auditLog, lifecycle | always |
| Downstream Impact | (computed) | always |

**Contradiction rules (surfaced as Adjust prompts):**

- `auth.strategy='none'` + dataArchitecture.compliance contains any of {HIPAA, PCI, SOC2} → "HIPAA/PCI/SOC2 require user authentication. No-auth strategy is incompatible with the compliance scope in Data Architecture."
- `auth.serviceAuth='none'` + architecturalFraming.topology='microservices' → "Microservice topology without service-to-service auth leaves internal endpoints unprotected. Consider mTLS or signed JWTs."

---

## Round 3 sections (Step 6: Privacy)

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Synthesis Status Banner | synthesisStatus | shown only if synthesisStatus='n/a' |
| Regulatory Scope | regulations | hidden if n/a |
| PII Inventory | piiCategories | hidden if n/a |
| Lawful Basis & Consent | lawfulBasis, consentManager | hidden if GDPR not in regulations |
| Retention & Deletion | retention, deletionFlow | hidden if n/a |
| DSAR & Data Export | dsar | hidden if neither GDPR nor CCPA in regulations |
| Third-Party Processors | processors | hidden if n/a |
| Data Minimization & Residency | minimization, dataResidency | hidden if n/a |
| Access Audit | accessAudit | hidden unless regulations contains HIPAA |

**Contradiction rules:**

- `privacy.regulations` does NOT contain `dataArchitecture.compliance` entry → "Data Architecture declared {X}, but Privacy regulations does not include it."
- `privacy.synthesisStatus='n/a'` + ANY piiCategories non-empty → "Privacy synthesis is n/a stub but PII categories are declared. Either change to complete synthesis or remove the PII entries."
- `privacy.regulations` contains GDPR + `privacy.dsar` empty → "GDPR requires a Data Subject Access Request process. Define DSAR flow."

---

## Round 3 sections (Step 7: Security)

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Sensitivity Tier | sensitivityTier | always |
| Secret Management | secrets | always |
| Vulnerability Scanning | scanning | always |
| Threat Model | threatModel | always |
| Encryption | encryptionAtRest, encryptionInTransit | always |
| Application Security | headers, inputValidation | hidden if no apiIntegration AND no frontend |
| Audit & Incident Response | auditRetention, ir | shown if sensitivityTier ≠ standard for auditRetention |
| Pentest, VDP, Supply Chain | pentestCadence, vdp, supplyChain | hidden when scaleTarget='hobby' and sensitivityTier='standard' |

**Contradiction rules:**

- `security.sensitivityTier='standard'` + `dataArchitecture.compliance` non-empty → "Compliance scope requires sensitivityTier 'elevated' or 'high'."
- `security.sensitivityTier='high'` + `security.encryptionAtRest.perColumnForPII=false` → "High tier with PII typically requires per-column encryption beyond DB-default."
- `security.supplyChain.sbom=false` + `dataArchitecture.compliance` contains 'SOC 2' → "SOC 2 expects SBOM as evidence artifact."

---

## Round 3 sections (Step 8: Runtime Operations)

**Section composition rules:**

| Section | Source fields | Conditional rules |
|---|---|---|
| Background Jobs & Retries | jobs, retryStrategy | hidden if apiIntegration.asyncPattern='none' |
| Scheduled Tasks | scheduling | always |
| Observability — Metrics | metrics | always |
| Observability — Traces | traces | gated on topology=microservices OR scaleTarget=production-scale+ |
| Observability — Logs | logs | always |
| Alerting & On-Call | alerting, onCall | always |
| SLO & Feature Flags | slo, featureFlags | SLO sub-section hidden when scaleTarget ∉ {production-scale, enterprise} |
| Operations Process | maintenanceMode, healthChecks, runbooks, incidentProcess | always |

**Contradiction rules:**

- `security.sensitivityTier='high'` + `runtimeOperations.alerting.tool='none'` → "High sensitivity tier requires non-trivial alerting."
- `runtimeOperations.slo` non-empty + `runtimeOperations.metrics.tool='none'` → "SLO requires a metrics backend."
- `apiIntegration.asyncPattern ≠ 'none'` + `runtimeOperations.jobs.provider='none'` → "API integration declares async work but Runtime Ops has no job system."

## personas — Section prompts

| Section | Title | Approve/Adjust/Skip prompt |
|---|---|---|
| 1 | Mode + Decisions | "Mode toggle values look right?" |
| 2 | Primary Personas | "Primary personas accurately captured?" |
| 3 | Secondary Personas | "Secondary personas captured if applicable?" |
| 4 | Anti-Personas | "Anti-personas correctly excluded?" |
| 5 | Persona Risks Identified | "Persona-related risk recorded?" |
| 6 | Decisions Driven Downstream | _(auto, back-fills after downstream phases — no user prompt at this stage)_ |

## domainModel — Section prompts

| Section | Title | Approve/Adjust/Skip prompt |
|---|---|---|
| 1 | Mode + Coupling | "Format + coupling values look right?" |
| 2 | Bounded Contexts | "Bounded contexts capture the major sub-domains?" |
| 3 | Entities per Context | "Entities + relationships + aggregate roots accurate?" |
| 4 | Value Objects | "Value objects captured?" _(skipped in DDD-lite)_ |
| 5 | Domain Events | "Domain events captured?" _(skipped in DDD-lite)_ |
| 6 | Cross-Context Relationships | "Cross-context relationships captured?" |
| 7 | Ubiquitous Language | "Glossary terms agree with how the team speaks?" |
| 8 | Anti-Corruption Layers | "Boundary translations identified?" _(skipped in DDD-lite)_ |
| 9 | Domain Risks Identified | "Domain risk recorded?" |
| 10 | Decisions Driven Downstream | _(auto, back-fills)_ |
