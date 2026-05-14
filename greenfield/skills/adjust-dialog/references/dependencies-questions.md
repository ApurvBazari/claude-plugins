# Dependencies Probes — Adjust Dialog Category 5

What downstream phases, fields, or systems inherit this choice, and what must change if we change it? Dependencies probes map the propagation chain — they surface what will need to be updated in phases already reviewed, phases yet to be reviewed, and external systems outside the spec.

## Probe selection

Use more probes (2-3) when:
- The adjusted value is a cross-cutting decision (auth, data layer, API contract, deployment topology)
- `listedPhases` contains phases that are likely downstream of `phaseId`

Use fewer probes (1) when:
- The adjustment is phase-local (e.g., a naming convention inside one phase's section)
- `listedPhases` is short (1-2 phases) and the dependency graph is simple

Chain probes when: the response to the primary dependency probe names multiple downstream phases — follow with a prioritization probe to determine which dependency must be addressed first.

---

### Probe D1: Downstream phase inheritance

> Which of the phases in `{listedPhases}` will inherit this adjusted value and need to be re-reviewed as a result?

**Trigger condition**: near-universal when `listedPhases` has 2 or more entries. Use for any structural choice.

**Follow-up hint**: the developer should be able to reason about the dependency graph. If they can't name any downstream phases for a high-impact change, that's a yellow flag.

---

### Probe D2: Already-reviewed phase impact

> Have any of the phases already reviewed in this session approved a section that assumed the original value? If so, which ones?

**Trigger condition**: use when `listedPhases` suggests upstream phases have already been walked (e.g., `architecturalFraming` and `dataArchitecture` are listed before `apiIntegration`).

**Follow-up hint**: stale approval records are a meaningful risk. If a previously approved section assumed `databaseHost = managed-rdbms` and the developer is now changing that, the prior approval is misleading.

---

### Probe D3: CI/CD pipeline dependency

> Does this adjustment require changes to the CI/CD pipeline — build steps, environment variables, deploy targets, or container configuration?

**Trigger condition**: use when the adjusted value touches the tech stack (runtime, framework, build tool) or infrastructure (database, cloud provider, hosting).

**Follow-up hint**: CI/CD changes are easy to forget at spec time. Surfacing them here means the developer enters Phase 2 knowing what pipeline work is coming.

---

### Probe D4: Schema or migration dependency

> Does this adjustment change the database schema or require new migrations? Are existing migrations still valid?

**Trigger condition**: use when the adjusted value touches database engine, ORM, migration tool, or schema design choices.

**Follow-up hint**: schema dependency changes are the most common source of "spec looks clean, implementation is messy." This probe surfaces whether the developer has a migration plan or is assuming a greenfield DB.

---

### Probe D5: API contract dependency

> Does this adjustment affect the API contract — endpoints, request/response shape, auth headers, or versioning?

**Trigger condition**: use when the adjusted value touches auth strategy, data models, or API layer decisions.

**Follow-up hint**: API contract changes downstream can break mobile apps, third-party integrations, or consumer services. If any consumers exist (even internal), this dependency should be named.

---

### Probe D6: External service dependency

> Does this adjustment change how the system interacts with external services — webhooks, third-party APIs, cloud services?

**Trigger condition**: use when the adjusted value involves integrations (payment, email, storage, notifications, analytics, AI APIs).

**Follow-up hint**: external service dependencies create coupling that's hard to change later. The developer should know which external service will need reconfiguration.

---

### Probe D7: Team-level dependency

> Does this adjustment create a dependency on another team, person, or external approval — infrastructure provisioning, security review, legal/compliance sign-off?

**Trigger condition**: use when the adjusted value involves managed infrastructure, enterprise auth, compliance-relevant data handling, or third-party contracts.

**Follow-up hint**: people dependencies are often missed in solo-developer spec reviews. If an adjustment requires someone else to do something (provision an RDS instance, approve a security policy), that's a blocker that needs to be surfaced now.

---

### Probe D8: Feature-level dependency

> Which features in `featureDecomposition` depend on the adjusted value being what you're setting it to? Are any features built on the assumption of `{originalValue}`?

**Trigger condition**: use when `featureDecomposition` (from Phase 1) exists in context and the adjusted value is a foundational technical choice (data layer, auth, API style).

**Follow-up hint**: if a feature was scoped assuming Prisma + PostgreSQL and the developer is switching to MongoDB, the feature's implementation approach may need to change. This probe surfaces that coupling.

---

### Probe D9: Version or compatibility dependency

> Does the adjusted value require a specific version of a dependency, runtime, or platform — and is that version already locked in?

**Trigger condition**: use when the adjusted value is a library, SDK, or framework with known version constraints.

**Follow-up hint**: version compatibility issues are most painful when discovered after scaffolding. The developer should know whether their chosen version of a tool is compatible with the rest of the locked-in stack.
