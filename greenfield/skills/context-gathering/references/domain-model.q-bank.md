# Domain Modeling Q-bank — Step 2.7

> **Round:** 4 (Discovery phase)
> **Step:** 2.7 (front-load discovery, before dataArchitecture)
> **Modes:** Heavy + Full DDD ~15 Qs / Heavy + DDD-lite ~10 Qs / Light ~5 Qs (Full DDD ignored)
> **Coupling:** Output (entity IDs + aggregate-root flags) consumed by auto-loop in data, api (and security in auto-loop mode)
> **See also:** `personas.q-bank.md`, `inline-risk.q-bank.md`, design spec § Domain Modeling phase

This phase captures domain structure using DDD vocabulary. Full DDD mode = entities + bounded contexts + aggregates + value objects + domain events + ubiquitous language + anti-corruption layers. DDD-lite drops value objects, domain events, and anti-corruption. Light mode collapses bounded contexts to a single default context and drops aggregate distinction.

## Q-bank

### Domain.Q1 — Bounded contexts

- **type:** repeating short-text
- **showInLight:** false
- **isRiskCapture:** false
- **min:** 1
- **max:** 6
- **loopTrigger:** true   <!-- Q2-Q7 loop per bounded context -->

**Prompt:** "List major sub-domains / bounded contexts. Each should have a distinct responsibility (e.g., 'Field-Audit', 'Reporting', 'Identity'). For small CRUD apps, 1 context is fine."

**Stores to:** `domainModel.contexts[]` — each entry becomes `{ "id": "BC{iter}", "name": "<text>" }` (id auto-assigned BC1, BC2, …); `responsibility` is populated by Q2.

**Light-mode note:** `mode.depth = light` collapses this to a single default BC (`{ "id": "BC1", "name": "default" }`) without prompting; the loop body runs once.

### Domain.Q2 — Context responsibility (per BC)

- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "BC{iter} ({context.name}) — one-line responsibility:"

**Prompt:** "BC{iter} ({context.name}) — one-line responsibility (what does this context own?)"

**Stores to:** `domainModel.contexts[{iter}].responsibility`

### Domain.Q3 — Entities in this context (per BC)

- **type:** repeating short-text
- **showInLight:** true
- **isRiskCapture:** false
- **min:** 1
- **max:** 12
- **loopTrigger:** true   <!-- Q4-Q5 loop per entity within this BC -->
- **template:** "Entities in {context.name}"

**Prompt:** "Entities in {context.name} (e.g., Audit, Finding, Site)"

**Stores to:** `domainModel.entities[]` — each entry becomes `{ "id": "<text>", "contextId": "BC{iter}", "isAggregateRoot": <Q4>, "relationships": <Q5> }`

### Domain.Q4 — Aggregate root status (per entity)

- **type:** single-select
- **options:** ["Aggregate root", "Owned by another", "Standalone"]
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "{entity.id} — aggregate role:"

**Prompt:** "{entity.id} — aggregate role (Aggregate root = independent transactional boundary; Owned by another = part of a parent aggregate; Standalone = no aggregate distinction)"

**Stores to:** `domainModel.entities[<entity>].isAggregateRoot` — `true` iff answer is `"Aggregate root"`; `false` otherwise.

**Light-mode note:** `mode.depth = light` defaults all entities to `isAggregateRoot: false` (i.e., "Standalone") without prompting.

### Domain.Q5 — Relationships (per entity)

- **type:** repeating structured
- **schema:** `[{ "target": "string", "kind": "has-one" | "has-many" | "belongs-to" | "refs" }]`
- **showInLight:** true
- **isRiskCapture:** false
- **template:** "{entity.id} relationships:"

**Prompt:** "{entity.id} relationships — what does it have-one/has-many/belongs-to/refs? (One per line, format: '<target-entity> <kind>')"

**Stores to:** `domainModel.entities[<entity>].relationships[]` — each entry is `{ "target": "<entity-id>", "kind": "<has-one|has-many|belongs-to|refs>" }`

### Domain.Q6 — Value objects (per BC)

- **type:** repeating short-text
- **showInLight:** false
- **isRiskCapture:** false
- **format-gated:** Full DDD only (skipped if `mode.domainFormat = ddd-lite`)
- **examples:** Money, Email, Address, GPSCoordinate
- **template:** "Value objects in {context.name}:"

**Prompt:** "Value objects in {context.name} — immutable values defined by attributes, not identity (e.g., Money, Email, Address, GPSCoordinate). Skip if none."

**Stores to:** `domainModel.valueObjects[]` — appended (across BCs) as strings.

### Domain.Q7 — Domain events (per BC)

- **type:** repeating short-text
- **showInLight:** false
- **isRiskCapture:** false
- **format-gated:** Full DDD only (skipped if `mode.domainFormat = ddd-lite`)
- **examples:** FindingRecorded, AuditCompleted
- **template:** "Domain events in {context.name}:"

**Prompt:** "Domain events emitted by {context.name} (past-tense facts: FindingRecorded, AuditCompleted, …). Skip if none."

**Stores to:** `domainModel.domainEvents[]` — appended (across BCs) as strings.

### Domain.Q8 — Cross-context relationships

- **type:** repeating structured
- **schema:** `[{ "from": "BC-id", "to": "BC-id", "kind": "string" }]`
- **showInLight:** false
- **isRiskCapture:** false
- **examples:** Field-Audit publishes-events-to Reporting; Identity provides-auth-to Field-Audit

**Prompt:** "Cross-context relationships — how do bounded contexts depend on each other? (Format: '<from-BC> <verb-phrase> <to-BC>'.) Skip if there's only one BC."

**Stores to:** `domainModel.crossContextRelationships[]` — each entry is `{ "from": "<BC-id>", "to": "<BC-id>", "kind": "<verb-phrase>" }`

**Design decision recorded:** Domain.Q8 uses a `kind: string` (free-form verb-phrase), NOT an enum. Resolves open Q#5 from spec § Open questions. Rationale: cross-context interaction patterns are too domain-specific to enumerate; the wizard captures the user's natural phrasing and surfaces it in the synthesis HTML for grill-spec review.

### Domain.Q9 — Ubiquitous Language glossary

- **type:** repeating { term, definition }
- **showInLight:** false
- **isRiskCapture:** false
- **min:** 3 (Full DDD)
- **min:** 0 (DDD-lite — Q9 still asked but allows empty)

**Prompt:** "Ubiquitous Language — domain-specific terms with definitions all team members must agree on. Format: '<term>: <one-line definition>'. Minimum 3 entries in Full DDD; optional in DDD-lite."

**Stores to:** `domainModel.ubiquitousLanguage[]` — each entry is `{ "term": "<text>", "definition": "<text>" }`

### Domain.Q10 — Anti-corruption layers

- **type:** free-text
- **optional:** true
- **showInLight:** false
- **isRiskCapture:** false
- **format-gated:** Full DDD only (skipped if `mode.domainFormat = ddd-lite`)

**Prompt:** "Any external systems whose vocabulary you refuse to leak in? (e.g., 'legacy CRM uses Lead/Account/Opportunity — we map to our own Customer/Order language at the boundary'.) Press Enter to skip."

**Stores to:** `domainModel.antiCorruption` (single string; multiple ACLs separated by linebreaks within the string)

### Domain.Q_RISK — Domain modeling risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["team", "compliance", "vendor-lock"]

**Prompt:** "What's the biggest domain modeling risk for THIS project? (e.g., 'no shared vocabulary across team — different folks call the same thing different names', 'we're forcing aggregates onto data that doesn't have natural transactional boundaries'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "domainModel"`, id auto-assigned R-DOMAINMODEL-1)

## Mode behavior matrix

| Q ID | Heavy + Full DDD | Heavy + DDD-lite | Light |
|---|---|---|---|
| Q1 | ✓ | ✓ | — (single default BC) |
| Q2 | ✓ | ✓ | — |
| Q3 | ✓ | ✓ | ✓ (entities only) |
| Q4 | ✓ | ✓ | — (all "Standalone") |
| Q5 | ✓ | ✓ | ✓ |
| Q6 | ✓ | — | — |
| Q7 | ✓ | — | — |
| Q8 | ✓ | ✓ | — |
| Q9 | ✓ | ✓ | — |
| Q10 | ✓ | — | — |
| Q_RISK | ✓ | ✓ | ✓ |
