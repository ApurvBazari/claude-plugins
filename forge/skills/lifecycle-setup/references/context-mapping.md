# Context Mapping — Phase 1 to Engineering Skills

How to compose natural language arguments for each engineering skill from the Phase 1 context object. For each document type: which fields to use, how to compose the argument string, and what defaults to apply when fields are missing.

## General Rules

- Only include fields that have values — don't mention "not specified" for every missing field
- Use the `webResearch` object (from stack-researcher agent) to enrich context where available
- Keep arguments concise but specific — the engineering skills handle the heavy lifting
- Prefix all arguments with the app description for grounding

---

## Architecture Decision Record

**Skill**: `engineering:architecture`

**Phase 1 fields used:**

| Field | Path | Purpose |
|---|---|---|
| App description | `appDescription` | What the project is |
| Framework | `stack.framework` + `stack.version` | Primary framework choice |
| Language | `stack.language` | Language decision |
| Database | `database.type` + `database.orm` | Data layer choices |
| Auth | `auth.strategy` + `auth.provider` | Authentication approach |
| Deploy target | `deployTarget` | Infrastructure decision |
| Stack research | `webResearch` | Trade-offs and alternatives considered |
| Additional tech | `stack.additional` | Supporting libraries/tools |

**Compose argument as:**

```
Document the tech stack decisions for [appDescription].

Decisions made:
- Framework: [stack.framework] [stack.version] ([stack.language])
- Database: [database.type] with [database.orm]
- Authentication: [auth.strategy] via [auth.provider]
- Deployment: [deployTarget]
- Additional: [stack.additional joined with ", "]

Context from research: [summarize key findings from webResearch — why this stack
was chosen over alternatives, version considerations, known trade-offs]

Include trade-offs for each major decision, alternatives considered, and
consequences of these choices.
```

**Defaults when missing:**
- `database`: omit database decision section
- `auth`: omit auth decision section
- `webResearch`: note "Stack was chosen by developer preference without formal comparison"
- `stack.additional`: omit additional tech section

---

## Testing Strategy

**Skill**: `engineering:testing-strategy`

**Phase 1 fields used:**

| Field | Path | Purpose |
|---|---|---|
| App description | `appDescription` | Context |
| App type | `appType` | Determines test pyramid shape |
| Framework | `stack.framework` | Test tooling recommendations |
| Language | `stack.language` | Test framework conventions |
| Frontend patterns | `frontendPatterns` | Component/E2E testing scope |
| Backend patterns | `backendPatterns` | API/integration testing scope |
| Verification strategy | `verificationStrategy` | E2E approach |
| Feature decomposition | `featureDecomposition` | What to test |
| Database | `database.type` | Integration test scope |

**Compose argument as:**

```
Design a testing strategy for [appDescription], a [stack.language]/[stack.framework]
[appType] project using test-driven development.

Stack context:
- Frontend: [frontendPatterns.componentLibrary], [frontendPatterns.stateManagement],
  [frontendPatterns.styling]
- Backend: [backendPatterns.apiStyle], [backendPatterns.orm],
  [backendPatterns.errorHandling]
- Database: [database.type]
- Verification approach: [verificationStrategy]

Key features to cover: [summarize top features from featureDecomposition]

Provide test pyramid distribution, framework recommendations, coverage targets,
and example test cases for the main feature areas.
```

**Defaults when missing:**
- `frontendPatterns`: note "No frontend — backend/CLI only"
- `backendPatterns`: note "No backend — frontend only"
- `featureDecomposition`: note "Feature list not yet defined — provide general strategy"
- `verificationStrategy`: default to "test-runner"

---

## Deploy Checklist

**Skill**: `engineering:deploy-checklist`

**Phase 1 fields used:**

| Field | Path | Purpose |
|---|---|---|
| App description | `appDescription` | Context |
| Deploy target | `deployTarget` | Platform-specific checks |
| Deploy frequency | `deployFrequency` | Cadence considerations |
| Branching strategy | `branchingStrategy` | Release flow |
| Monitoring | `monitoring` | What to watch post-deploy |
| Database | `database.type` | Migration checks |
| Security sensitivity | `securitySensitivity` | Security gate depth |
| Docker strategy | `dockerStrategy` | Container-specific checks |

**Compose argument as:**

```
Pre-deployment checklist for [appDescription] deploying to [deployTarget].

Deploy context:
- Frequency: [deployFrequency]
- Branching: [branchingStrategy]
- Database: [database.type] (include migration verification)
- Security level: [securitySensitivity]
- Monitoring: [monitoring joined with ", "]
- Containerized: [dockerStrategy or "no"]

Include pre-deploy, deploy, post-deploy, and rollback trigger sections.
```

**Defaults when missing:**
- `monitoring`: note "No monitoring configured — recommend adding"
- `dockerStrategy`: omit container-specific checks
- `deployFrequency`: default to "manual"

---

## System Design Document

**Skill**: `engineering:system-design`

**Phase 1 fields used:**

| Field | Path | Purpose |
|---|---|---|
| App description | `appDescription` | What to design |
| App type | `appType` | Architecture shape |
| Stack | `stack` | Technology context |
| Database | `database` | Data layer |
| Auth | `auth` | Auth architecture |
| API style | `apiStyle` | API design |
| Storage strategy | `storageStrategy` | File/blob storage |
| Background jobs | `backgroundJobs` | Async processing |
| Monitoring | `monitoring` | Observability |
| API docs | `apiDocs` | Documentation tooling |

**Compose argument as:**

```
System design for [appDescription]: a [appType] built with [stack.framework]
([stack.language]).

Components:
- API: [apiStyle] [apiDocs if present]
- Database: [database.type] with [database.orm]
- Auth: [auth.strategy] via [auth.provider]
- Storage: [storageStrategy]
- Background processing: [backgroundJobs]
- Monitoring: [monitoring joined with ", "]

Provide component diagram, data flow, API boundaries, and scaling considerations.
```

**Defaults when missing:**
- `storageStrategy`: omit storage section
- `backgroundJobs`: omit async section
- `monitoring`: note "Not yet configured"
- `apiDocs`: omit API docs mention

---

## Technical Documentation / Runbook

**Skill**: `engineering:documentation`

**Phase 1 fields used:**

| Field | Path | Purpose |
|---|---|---|
| App description | `appDescription` | Context |
| Stack | `stack` | Setup instructions |
| Deploy target | `deployTarget` | Deployment steps |
| Env strategy | `envStrategy` | Environment management |
| Docker strategy | `dockerStrategy` | Container setup |
| Dep management | `depManagement` | Dependency install |
| Database | `database` | DB setup steps |

**Compose argument as:**

```
Create a runbook for [appDescription], a [stack.framework] project.

Setup context:
- Language: [stack.language], package manager: [depManagement]
- Database: [database.type] [database.orm if present]
- Environment: [envStrategy]
- Docker: [dockerStrategy or "not containerized"]
- Deploy target: [deployTarget]

Include: local development setup, environment configuration, database setup,
deployment steps, and common troubleshooting scenarios.
```

**Defaults when missing:**
- `envStrategy`: default to ".env files"
- `dockerStrategy`: omit Docker section
- `depManagement`: infer from stack.language (JS → npm, Python → pip, etc.)

---

## Incident Response Playbook

**Skill**: `engineering:incident-response`

**Phase 1 fields used:**

| Field | Path | Purpose |
|---|---|---|
| App description | `appDescription` | Context |
| Deploy target | `deployTarget` | Platform-specific runbooks |
| Monitoring | `monitoring` | Alert sources |
| Security sensitivity | `securitySensitivity` | Escalation thresholds |
| Database | `database.type` | DB incident scenarios |
| Auth | `auth` | Auth incident scenarios |

**Compose argument as:**

```
Incident response playbook for [appDescription] running on [deployTarget].

Infrastructure context:
- Monitoring: [monitoring joined with ", "]
- Database: [database.type]
- Auth: [auth.strategy] via [auth.provider]
- Security level: [securitySensitivity]

Include: severity classification, escalation paths, common incident scenarios
(database outage, auth failures, deployment rollback, data breach response),
communication templates, and post-incident review process.
```

**Defaults when missing:**
- `monitoring`: note "No monitoring configured — incident detection will be manual"
- `auth`: omit auth-specific incident scenarios
