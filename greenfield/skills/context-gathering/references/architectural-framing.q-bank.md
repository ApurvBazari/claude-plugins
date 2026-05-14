# Architectural Framing Q-bank — Step 2.5

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 2.5 (gates the detailed architectural phases P3-P9)
> **Modes:** Heavy ~5 Qs (AF.Q1-Q4 + Q_RISK) / Light ~3 Qs (Q1 + Q3 + Q_RISK; Q2 and Q4 use defaults)
> **Coupling:** No loopOver — single-shot architectural framing that precedes persona/entity discovery loops.
> **Source:** Q content migrated from `question-bank.md` § "Step 2.5"; R4 added Q_RISK + showInLight tags + format conversion.
> **See also:** `personas.q-bank.md`, `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk

This phase gathers early architectural choices that inform all detailed phases (P3–P9): service topology, deployment shape, scale target, and hard boundary constraints. Synthesis review fires inline after AF.Q4 (or after Q_RISK if migration logic decides Q_RISK runs after synthesis).

## Q-bank

### AF.Q1 — Service topology

- **type:** single-select
- **options:** ["Monolith", "Modular monolith", "Microservices", "Serverless"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (gate question for the step)
- **R3-updates-path:** `context.phases.architecturalFraming.topology`

**Prompt:** "What's your service topology?"

**Stores to:** `architecturalFraming.topology`

**Options (with descriptions):**
- "Monolith (single deployable unit)"
- "Modular monolith (internal modules, single deploy)"
- "Microservices (independent services, independent deploys)"
- "Serverless (function-per-endpoint, no persistent server)"

**Downstream effects:** All detailed phases (P3–P9) read topology. Microservices + monolith DB contradict; serverless + ORM-native migrations produce a note; monolith is the recommended default for solo or startup projects.

**Recommend:** Lead with monolith for solo developers (`isProduction: false` or `teamSize = solo-or-pair`); serverless for `appType: api` with `scaleTarget: startup`; microservices only for `teamSize: 5+` or when the user explicitly identifies independently-scalable domains.

**Default:** `"Monolith"`
- If `hasTeam: true` AND `architecturalFraming.scaleTarget: "enterprise"` → `"Modular monolith"`
- If `appType: "api"` AND `architecturalFraming.scaleTarget: "startup"` → `"Serverless"`
- Else → `"Monolith"` (greenfield opinion: the simplest topology that can grow; avoid premature distribution)

### AF.Q2 — Deployment shape

- **type:** single-select
- **options:** ["Single-region", "Multi-region", "Edge-distributed", "On-premises"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** NOT (`appType: cli`). If `willDeploy = false`, default to `"single-region"` and note rather than asking.
- **R3-updates-path:** `context.phases.architecturalFraming.deploymentShape`

**Prompt:** "What's your deployment shape?"

**Stores to:** `architecturalFraming.deploymentShape`

**Options (with descriptions):**
- "Single-region (one cloud region, simplest)"
- "Multi-region (active/active or active/passive across regions)"
- "Edge-distributed (CDN edge workers, globally distributed)"
- "On-premises (self-managed infrastructure)"

**Downstream effects:** cicdAndDelivery reads for env ladder and rollback strategy; dataArchitecture reads for DB hosting model compatibility.

**Recommend:** Single-region unless `scaleTarget: enterprise` or user explicitly names a global user base. Edge-distributed is powerful but constrains ORM options (Prisma + serverless edge drivers; SQLAlchemy not edge-compatible).

**Default:** `"Single-region"`
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Multi-region"`
- If `architecturalFraming.topology: "serverless"` AND `appType ∈ (api, fullstack)` → `"Edge-distributed"`
- Else → `"Single-region"` (greenfield opinion: the right default for 95% of new projects; multi-region is an operational complexity multiplier)

### AF.Q3 — Scale target

- **type:** single-select
- **options:** ["Hobby", "Startup", "Production-scale", "Enterprise"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.architecturalFraming.scaleTarget`

**Prompt:** "What's the scale target?"

**Stores to:** `architecturalFraming.scaleTarget`

**Options (with descriptions):**
- "Hobby / personal project (single user, occasional traffic)"
- "Startup (public launch, growth expected, 100–10k users)"
- "Production-scale (established product, sustained load, 10k–1M users)"
- "Enterprise (regulated, SLA-backed, 1M+ users or organizational complexity)"

**Downstream effects:** dataArchitecture caching, backup, and compliance questions weight their recommendations against scale target; cicdAndDelivery env ladder and release pipeline complexity track scale; authSecurity (Round 3) uses scale to calibrate identity recommendations.

**Recommend:** Be honest about current scale, not aspirational. Most projects starting today are `startup`; `enterprise` triggers heavier compliance cross-checks.

**Default:** `"Startup"`
- If `isProduction: false` AND `hasTeam: false` → `"Hobby"`
- Else → `"Startup"` (greenfield opinion: most new public projects are in startup territory; hobby under-calibrates; enterprise over-calibrates and adds unnecessary compliance overhead)

### AF.Q4 — Boundary constraints

- **type:** free-text
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.architecturalFraming.boundaryNotes`

**Prompt:** "Do you have any hard architectural boundary requirements or constraints?"

**Suggested prompts:**
- "Domain separation you know you need (e.g., billing must be isolated from auth)?"
- "Regulatory constraints that force isolation (e.g., PCI data must not touch user PII)?"
- "Team ownership lines that need to map to service boundaries?"

**Stores to:** `architecturalFraming.boundaryNotes`

**Downstream effects:** grill-spec cross-checks `boundaryNotes` against topology when non-empty (e.g., "must isolate payments" + `topology: monolith` produces a contradiction flag); synthesis-review § Downstream Implications renders this as a note.

**If no constraints:** capture as `""` (empty string) or `"none stated"`. Do not leave null — the schema accepts empty string; null would fail required-field presence in future tooling.

**Default:** `""` (empty — no boundary constraints) (always — greenfield opinion: most early-stage projects have no hard constraints; capturing empty is correct rather than a forced placeholder)

### AF.Q_RISK — Architectural framing risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["scaling", "vendor-lock", "team"]

**Prompt:** "What's the biggest architectural-framing risk for THIS project? (e.g., 'monolith may not scale past 100k users', 'microservices ambition without infra to support it', 'vendor lock-in via serverless platform-specific APIs'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "architecturalFraming"`, id auto-assigned `R-ARCHITECTURALFRAMING-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| AF.Q1 | ✓ | ✓ | Topology — fundamental |
| AF.Q2 | ✓ | — | Deployment shape — uses default in light |
| AF.Q3 | ✓ | ✓ | Scale target — fundamental |
| AF.Q4 | ✓ | — | Boundary notes — empty default in light |
| AF.Q_RISK | ✓ | ✓ | Always fires |
