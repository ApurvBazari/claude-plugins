# Personas Q-bank — Step 2.2

> **Round:** 4 (Discovery phase)
> **Steps:** 2.2 (front-load discovery, before architecturalFraming)
> **Modes:** Heavy ~12 Qs, Light ~4 Qs (Q1+Q2+Q3+Q6+Q_RISK kept in light; Q4/Q5/Q7/Q8/Q9-Q11 dropped)
> **Coupling:** Output (persona IDs) consumed by auto-loop in auth, privacy, frontend (and security/runtimeOps in auto-loop mode)
> **See also:** `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Personas phase

This phase captures **rich personas with downstream hooks**. Each persona = name, role, primary goal, context (device/connection/literacy), tech sophistication, 2–3 jobs-to-be-done, anti-persona. Persona IDs (P1, P2, …) become first-class identifiers referenced by downstream phases via auto-loop.

## Q-bank

### Persona.Q1 — Primary persona count

- **type:** single-select
- **options:** ["1", "2", "3", "4", "5"]
- **showInLight:** true
- **isRiskCapture:** false
- **loopTrigger:** true   <!-- Q2-Q8 iterate per primary persona -->
- **cap:** 5 primary (with up to 3 secondaries in Q9 → 8 total max)

**Prompt:** "How many primary personas drive critical user flows? (Pick 1–3 unless your product has clearly distinct user types — too many personas dilutes architectural decisions.)"

**Stores to:** `personas.primary[]` (Q1's value sets the loop iteration count for Q2-Q8; not a persisted field — wizard computes count from array length post-loop)

### Persona.Q2 — Name + role (per primary persona)

- **type:** short-text
- **showInLight:** true
- **isRiskCapture:** false
- **template:** "Persona {iter} of {Persona.Q1.value} — name + role:"

**Prompt:** "Persona name + role"

**Stores to:** `personas.primary[{iter}].name`, `personas.primary[{iter}].role`
**ID convention:** wizard assigns id = "P{iter}" (e.g., P1, P2)

### Persona.Q3 — Primary goal (per primary persona)

- **type:** short-text
- **showInLight:** true
- **isRiskCapture:** false
- **template:** "Persona {iter}: Primary goal in one sentence"

**Prompt:** "Primary goal in one sentence"

**Stores to:** `personas.primary[{iter}].goal`

### Persona.Q4 — Device + connection context (per primary persona)

- **type:** multi-select
- **options:** ["iPhone", "Android", "iPad/tablet", "Desktop", "Wearable", "Strong WiFi", "Spotty/LTE", "Offline-prone", "Mixed"]
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "Persona {iter}: Device + connection context"

**Prompt:** "Device + connection context (select all that apply)"

**Stores to:** `personas.primary[{iter}].context.device[]`, `personas.primary[{iter}].context.connection`
**Mapping notes:** device entries map to `context.device[]`; connection-related entries (Strong WiFi / Spotty / Offline-prone / Mixed) map to a single `context.connection` string (last-selected wins if multiple).

### Persona.Q5 — Tech sophistication (per primary persona)

- **type:** single-select
- **options:** ["Power user", "Comfortable", "Basic", "Novice"]
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "Persona {iter}: Tech sophistication"

**Prompt:** "Tech sophistication"

**Stores to:** `personas.primary[{iter}].context.techSophistication`

### Persona.Q6 — Jobs to be done (per primary persona)

- **type:** repeating short-text
- **min:** 1
- **max:** 5
- **showInLight:** true
- **isRiskCapture:** false
- **template:** "Persona {iter}: Jobs-to-be-done (2-3 recommended, up to 5)"

**Prompt:** "2-3 jobs-to-be-done (one per line)"

**Stores to:** `personas.primary[{iter}].jobs[]` — each entry becomes `{ "id": "J{n}", "story": "<text>" }`

### Persona.Q7 — Hard constraints (per primary persona)

- **type:** free-text
- **optional:** true
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "Persona {iter}: Hard constraints worth flagging"

**Prompt:** "Hard constraints worth flagging (e.g., 'must work on iOS 14', 'no JS execution'). Press Enter to skip."

**Stores to:** `personas.primary[{iter}].constraints`

### Persona.Q8 — Anti-persona (per primary persona)

- **type:** short-text
- **optional:** true
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "Persona {iter}: Anti-persona — who is this explicitly NOT for?"

**Prompt:** "Anti-persona — who is this explicitly NOT for? (Press Enter to skip.)"

**Stores to:** `personas.primary[{iter}].antiPersona`

**Design decision recorded:** Persona.Q8 is **short-text optional** (one anti-persona per primary persona), not structured/repeating. Resolves open Q#4 from spec § Open questions. Rationale: simplest viable shape; if multiple anti-personas needed in practice, escalate to a future round.

### Persona.Q9 — Secondary personas?

- **type:** single-select
- **options:** ["yes-lean", "no"]
- **showInLight:** false   <!-- secondaries skipped in light mode -->
- **isRiskCapture:** false
- **loopTrigger:** true   <!-- Q10/Q11 loop per secondary (max 3); fires only when answer = "yes-lean" -->

**Prompt:** "Are there secondary personas worth capturing (lean profile only — name + role + 1-line context)?"

**Stores to:** _(control flow only — answer governs Q10/Q11 loop; not persisted to context shape)_

### Persona.Q10 — Secondary name + role (per secondary)

- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "Secondary persona {iter} of (up to 3) — name + role:"

**Prompt:** "Secondary persona {iter} of (up to 3) — name + role:"

**Stores to:** `personas.secondary[{iter}].name`, `personas.secondary[{iter}].role`

### Persona.Q11 — Secondary context (per secondary)

- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **template:** "Secondary persona {iter}: 1-line context"

**Prompt:** "Secondary persona {iter}: 1-line context"

**Stores to:** `personas.secondary[{iter}].context`

### Persona.Q_RISK — Persona-related risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["compliance", "market", "team"]

**Prompt:** "What's the biggest persona-related risk for THIS project? (e.g., 'no persona covers regulator audit access', 'primary persona has high-churn behavior we can't yet measure'.)"

**Stores to:** `risks[]` array (new entry with originatingPhase = "personas", id auto-assigned R-PERSONAS-1)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Q1 | ✓ | ✓ | Primary count |
| Q2-Q3 | ✓ | ✓ | Name + role + goal (always) |
| Q4-Q5 | ✓ | — | Context + tech (heavy only) |
| Q6 | ✓ | ✓ | Jobs (always) |
| Q7-Q8 | ✓ | — | Constraints + anti-persona |
| Q9-Q11 | ✓ | — | Secondaries (heavy only) |
| Q_RISK | ✓ | ✓ | Always fires |
