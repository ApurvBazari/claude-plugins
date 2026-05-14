# Greenfield 3.0 Round 4 — Personas + Domain Modeling + Distributed Risk Design

- **Branch:** `feat/greenfield-1.3` (proposed; new branch for Round 4)
- **Date:** 2026-05-14
- **Inherits from:** Rounds 1+2+2.5+3 (shipped at `greenfield@3.0.0-alpha.4` / `onboard@2.0.0-alpha.4`); `project_greenfield_3_0_design.md` memory; Round 3 design doc `2026-05-14-greenfield-3.0-round3-design.md`
- **Estimated files touched:** ~31 unique files (~16 new + ~15 modified) across `greenfield/`, `onboard/`, root marketplace
- **Target versions on completion:** `greenfield@3.0.0-alpha.5`, `onboard@2.0.0-alpha.5`
- **Execution model:** Approach A — Big Bang single round, R3-style subagent dispatch (~35–40 tasks)

## Summary

Round 4 swings the wizard from the **technical spine** (Rounds 1–3: data, API, auth, privacy, security, runtimeOps, CICD) onto the **product/discovery side** — who the users are, what the domain looks like, and what risks live in the design. It adds **2 new top-level phases** (Personas at Step 2.2, Domain Modeling at Step 2.7), distributes **risk capture across every architectural phase** as an inline question, and extends `architecturalValidation` with a **Risk Reconciliation section** at Step 15.

Two new wizard-level mode toggles (asked at Step 1) control the depth and the **coupling** between discovery and architecture phases:

- `mode.depth = heavy | light` (default: **heavy**)
- `mode.coupling = auto-loop | hybrid` (default: **auto-loop**)
- `mode.domainFormat = full-ddd | ddd-lite` (default: **full-ddd**)

Auto-loop is the architecturally heaviest mechanic in this round: downstream phases iterate per persona and per domain entity, producing synthesis HTMLs with explicit `derivedFrom` traces. Hybrid mode loops only where personas/entities directly drive the answer (auth roles, data persistence, api CRUD, privacy access); other phases reference but don't iterate.

The wizard grows from 15 steps to **17 steps**. Schema bumps `alpha.4 → alpha.5`; in-flight alpha.4 sessions auto-migrate on `/greenfield:pickup` with the migration shim defined in § State file migration.

## Scope

### In scope (Round 4 deliverables)

1. Author **Personas** phase (~12 Qs heavy, ~4 light) — rich format: name, role, goal, context (device/connection/literacy), tech sophistication, 2–3 jobs-to-be-done, constraints, anti-persona
2. Author **Domain Modeling** phase (~15 Qs heavy + Full DDD, ~10 Qs DDD-lite, ~5 Qs Light) — entities, relationships, bounded contexts, aggregates, value objects, domain events, ubiquitous language, anti-corruption layers
3. Add **inline risk Q** to every architectural phase (8 phases): `Q_RISK` free-text + tag suggestions; result feeds shared `risks[]` array
4. Extend **`architecturalValidation`** (Step 15) with a new front section **Risk Reconciliation** — walks each captured risk, asks status (mitigated / partial / accepted-explicit / open-followup / out-of-scope), summarizes top followup cards
5. Two new wizard-level toggles at Step 1: `depth` and `coupling`; existing implicit `domainFormat` becomes explicit
6. **Auto-loop state machine** in `context-gathering/SKILL.md` — iterates Q-bank entries flagged `loopOver: personas.primary | domain.entities | domain.aggregates` per item in source
7. **Q-bank entry shape extensions:** `loopOver`, `loopMode` (always/hybrid-only), `showInLight`, `isRiskCapture`
8. **3 synthesis template pairs** + 3 `*.dependencies.json.example` sidecars: `personas`, `domain-model`, `architectural-validation-risk-reconciliation` (extension section only)
9. **New cross-cutting `risks.dependencies.json`** — populated incrementally across phases, owned by architecturalValidation
10. **Schema additions** in `onboard/skills/generation/references/context-shape-v2.json` — `mode` block, `phases.personas`, `phases.domainModel`, `phases.architecturalValidation.riskReconciliation`, top-level `risks[]`
11. **Schema additions** in `onboard/skills/generation/references/dependencies-schema.json` — phase enum extends (`personas`, `domainModel`, `risks`), path pattern extends, new optional `sourceRef` field
12. **8 cross-phase invariants** in `grill-spec/SKILL.md` — CHECK-R4-1 through CHECK-R4-8
13. **Coupling matrix** in `docs/greenfield-3.0-round4/coupling-matrix.md` — definitive table of what loops in Auto-loop vs Hybrid mode
14. Wizard step renumbering 15 → 17 (using R3 `.5/.X` convention; no global renumber)
15. Update `start/SKILL.md` (toggle UX), `pickup/SKILL.md` (mid-wizard mode switch, post-hoc persona/entity add detection), `check/SKILL.md` (verify new ADR files exist when applicable), `tooling-generation/SKILL.md` (pass new phases to onboard)
16. Architecture diagram updates in `greenfield/CLAUDE.md` and `onboard/CLAUDE.md`
17. ROUND 4 LOCKED entry in `docs/greenfield-overview.html` Discussion Log
18. Migration of "Step 2 vision/scope" users-question to a pointer ("→ See Step 2.2 Personas")
19. Stack-derived default rules for new Qs in `defaults-derivation.md` (low priority — personas/domain are user-provided, not stack-derived)
20. Version bumps: `greenfield@3.0.0-alpha.5`, `onboard@2.0.0-alpha.5`, mirrored in `marketplace.json`
21. CHANGELOG entries calling out the alpha.4 → alpha.5 schema bump (auto-migrating, NOT a hard cutover this round — see § Backward compatibility)

### Out of scope (do NOT relitigate — locked elsewhere)

- Frontend phase (P5) — Round 6
- Feature Roadmap (P9), Schema & API Draft Review (P10.5) — Round 5
- 12 never-asked concern areas — Round 6
- Non-GHA CI provider templates — Round 6
- Splitting Cat 3 residual or Cat 4 dev-workflow into formal phases — Round 6+
- Light-mode-specific alternate Q wording — Light is strict subset of Heavy
- Stack-derived persona/entity inference (e.g., auto-detect "B2B SaaS → admin + tenant-user personas") — possibly Round 5 helper

## Locked design decisions

These 6 decisions came out of the 2026-05-14 brainstorming session. They drive every Round 4 deliverable.

| # | Item | Decision |
|---|---|---|
| 1 | Placement | **Front-load discovery.** Personas before architecturalFraming (Step 2.2); Domain before dataArchitecture (Step 2.7); Risk distributed inline (not a standalone phase). Matches the P0.5 / P1 / P8.5 roadmap intent. |
| 2 | Round depth | **Tiered — Heavy default, Light toggle.** Heavy = ~120 wizard Qs across all phases; Light = ~65. User picks at Step 1. Risk Qs fire in both modes (cheap, valuable). |
| 3 | Risk shape | **Distributed inline + final consolidation.** Every architectural phase grows ONE inline risk Q. architecturalValidation grows a Risk Reconciliation section that walks all captured risks. No standalone Risk phase. |
| 4 | Personas format | **Rich personas with downstream hooks.** Each persona = name, role, goal, context, tech sophistication, 2–3 jobs-to-be-done, anti-persona. Persona IDs referenced by auto-looped downstream phases. |
| 5 | Domain format | **Full DDD default, DDD-lite toggle.** Full DDD = entities + contexts + aggregates + value objects + UL + domain events + anti-corruption. DDD-lite drops VO/events/anti-corruption. Light mode collapses further. |
| 6 | Coupling | **Auto-loop default, Hybrid toggle.** Auto-loop = every downstream phase iterates per persona AND per entity. Hybrid = only "directly-driven" Qs loop (auth roles, data persistence, api CRUD, privacy access). |

## Architecture

### New wizard order (15 steps → 17)

```
Step 1     Intro + Mode toggles (depth, coupling, domainFormat)
Step 2     Vision / Scope                                   (unchanged)
Step 2.2   🆕 Personas
Step 2.5   Architectural Framing  + inline risk Q
Step 2.7   🆕 Domain Modeling
Step 3     Data Architecture       + inline risk Q
Step 4     API & Integration       + inline risk Q
Step 5     Auth & Identity         + inline risk Q + auto-loop personas → roles
Step 6     Privacy & Governance    + inline risk Q + auto-loop personas → access
Step 7     Security                + inline risk Q
Step 8     Runtime Operations      + inline risk Q
Step 11    CI/CD & Delivery        + inline risk Q
Step 15    Architectural Validation
             └── new section: Risk Reconciliation
```

### Phase types

| Type | Phases | Role in Round 4 |
|---|---|---|
| Discovery (new) | Personas (2.2), Domain Modeling (2.7) | Produce reference data consumed by downstream auto-loop |
| Architectural (existing, modified) | 2.5, 3, 4, 5, 6, 7, 8, 11 | Each grows inline `Q_RISK`; some auto-loop on personas/entities |
| Validation (existing, extended) | 15 | Grows Risk Reconciliation front section before cross-phase invariants |

### Mode toggles (Step 1)

```
mode.depth:        heavy (default) | light
mode.coupling:     auto-loop (default) | hybrid
mode.domainFormat: full-ddd (default) | ddd-lite
```

Persisted in `.claude/greenfield-state.json` under `mode.*`. Surfaced in every synthesis HTML footer for audit.

## Phase design

### Personas phase (Step 2.2)

#### Q-bank — Heavy mode (~12 Qs)

```
Persona.Q1   "How many primary personas drive critical user flows?"
             type: single-select [1, 2, 3, 4, 5]
             cap: max 5 primary (with up to 3 secondaries in Q9 → 8 total max)
             [LOOP TRIGGER — Q2-Q8 run per persona]

PER PRIMARY PERSONA (loops 1× to N×):
Persona.Q2   "Persona name + role"                            short-text
Persona.Q3   "Primary goal in one sentence"                   short-text
Persona.Q4   "Device + connection context"                    multi-select
             [iPhone, Android, iPad/tablet, Desktop, Wearable,
              Strong WiFi, Spotty/LTE, Offline-prone, Mixed]
Persona.Q5   "Tech sophistication"
             single-select [Power user, Comfortable, Basic, Novice]
Persona.Q6   "2-3 jobs-to-be-done"                            repeating short-text
Persona.Q7   "Hard constraints worth flagging"                free-text optional
Persona.Q8   "Anti-persona — who is this explicitly NOT for?" single-text optional

Persona.Q9   "Are there secondary personas worth capturing?"
             single-select [yes-lean, no]
             [LIGHT LOOP — Q10/Q11 per secondary, max 3]

PER SECONDARY:
Persona.Q10  "Secondary persona name + role"                  short-text
Persona.Q11  "1-line context"                                 short-text

Persona.Q_RISK  "What's the biggest persona-related risk?"    free-text
                isRiskCapture: true (always fires)
```

Light mode drops Q4, Q5, Q7, Q8 and the secondaries (Q9–Q11). Q_RISK fires in both.

#### Synthesis HTML — `docs/adr/personas.html`

Six sections: Mode + Decisions; Primary Personas; Secondary Personas; Anti-Personas; Persona Risks Identified; Decisions Driven Downstream (back-filled after downstream phases).

#### Dependencies sidecar — `docs/adr/personas.dependencies.json`

Records `personas.primary[*].id`, `personas.primary[*].context.connection`, `personas.primary[*].techSophistication` — the fields downstream Qs reference.

### Domain Modeling phase (Step 2.7)

#### Q-bank — Heavy + Full DDD (default, ~15 Qs)

```
Domain.Q1    "Major sub-domains / bounded contexts"           repeating short-text
             [LOOP A — Q2-Q7 per context]

PER BOUNDED CONTEXT:
Domain.Q2    "Context name + 1-line responsibility"
Domain.Q3    "Entities in this context"                       repeating short-text
             [LOOP B — Q4-Q5 per entity]

  PER ENTITY:
  Domain.Q4  "Is this an Aggregate Root?"
             single-select [Aggregate root, Owned by another, Standalone]
  Domain.Q5  "Direct relationships to other entities"
             repeating: target entity + relationship kind
             [has-one, has-many, belongs-to, refs]

Domain.Q6    "Value objects in this context"                  repeating short-text
Domain.Q7    "Key domain events emitted from this context"    repeating short-text

Domain.Q8    "Cross-context relationships / shared kernel"    structured
Domain.Q9    "Ubiquitous Language glossary"                   repeating: term + def
Domain.Q10   "Anti-corruption layers"                         free-text optional
Domain.Q_RISK "What's the biggest domain modeling risk?"      free-text
              isRiskCapture: true (always fires)
```

#### Mode permutations

| Combo | Qs | Drops |
|---|---|---|
| Heavy + Full DDD (default) | ~15 | nothing |
| Heavy + DDD-lite | ~10 | Q6, Q7, Q10 |
| Light + (any) | ~5 | bounded contexts collapse to single default; only entities + relationships + Q_RISK |

#### Synthesis HTML — `docs/adr/domain-model.html`

Ten sections: Mode + Coupling; Bounded Contexts; Entities (with aggregate marks); Value Objects; Domain Events; Cross-Context Relationships; Ubiquitous Language; Anti-Corruption Layers; Domain Risks Identified; Decisions Driven Downstream.

DDD-lite drops sections 4, 5, 8. Light collapses to 2/3/9/10.

### Distributed risk pattern

#### Inline risk Q (per architectural phase)

Every architectural phase grows one final question:

```
{phaseName}.Q_RISK   "What's the biggest risk in this phase for THIS project?"
                     kind: free-text required (1-3 sentences)
                     isRiskCapture: true
                     showInLight: true
                     tagSuggestions: [scaling, security, dataloss, vendor-lock,
                                      compliance, performance, ops, team, market]
```

Risk persists to:
1. The phase's synthesis HTML (Risks Identified section)
2. The cross-cutting `context.risks[]` array
3. The shared `docs/adr/risks.dependencies.json` file

#### Risk Reconciliation in architecturalValidation (Step 15)

Existing phase grows a new **front section** before cross-phase invariant check:

```
Step 15.1   Risk Reconciliation  (NEW)
            - Render risks table (10–15 risks across all phases)
            - PER RISK: ask reconciliation status + rationale
            - Capture top followup cards
Step 15.2   Cross-phase invariant check  (existing CHECK-R3-* + new CHECK-R4-*)
Step 15.3   Final sign-off Q              (existing)
```

#### Reconciliation status enum

`mitigated | partial | accepted-explicit | open-followup | out-of-scope | user-declared-none`

#### Followup integration

Top followups (selected via `ArchVal.Q_RISK_SUMMARY`) generate corresponding rows in `docs/feature-list.json` with `feature.kind = "risk-followup"`.

## Auto-loop mechanic

### Q-bank entry shape extensions

```jsonc
{
  "id": "Auth.Q_ROLE_PERMS",
  "phase": "auth",
  "loopOver": "personas.primary",       // ← new: source iterator
  "loopMode": "always",                 // ← new: "always" | "hybrid-only"
  "showInLight": true,                  // ← new: false → drop in light mode
  "isRiskCapture": false,               // ← new: true only for Q_RISK entries
  "promptTemplate": "For persona {persona.id} ({persona.name}, {persona.role}), what role + permission set fits best?",
  "answerSchema": { "role": "string", "permissions": ["string"] }
}
```

### State machine decision rule

```
For each Q-bank entry Q in the current phase:
  if Q.loopOver is set:
    if mode.coupling == "auto-loop":
      → fire Q once per item in context[Q.loopOver]
    elif mode.coupling == "hybrid":
      if Q.loopMode == "always":
        → fire Q once per item in context[Q.loopOver]
      else:
        → fire Q ONCE as static (no loop); user types free-form
  else:
    → fire Q once (static)
```

### Coupling matrix (definitive)

| Q | Auto-loop | Hybrid |
|---|---|---|
| `auth.roles` (per persona) | loop persona | loop persona — `always` |
| `privacy.access` (per persona) | loop persona | loop persona — `always` |
| `frontend.devices` (per persona, Round 6 placeholder) | loop persona | loop persona — `always` |
| `data.persistence` (per entity) | loop entity | loop entity — `always` |
| `data.access-pattern` (per entity) | loop entity | loop entity — `always` |
| `api.crud-surface` (per entity) | loop entity | loop entity — `always` |
| `api.async-pattern` (per entity) | loop entity | no-loop — `hybrid-only` |
| `security.threat-model` (per persona) | loop persona | no-loop — `hybrid-only` |
| `security.attack-surface` (per entity) | loop entity | no-loop — `hybrid-only` |
| `runtimeOps.SLO` (per persona) | loop persona | no-loop — `hybrid-only` |
| `runtimeOps.alert` (per persona) | loop persona | no-loop — `hybrid-only` |
| `cicd.*` | no loop | no loop |

### Synthesis HTML loop trace

Looped answers render as tables with `derivedFrom: P<n>` columns. Each looped answer carries a `sourceRef: { phase, id }` in the dependencies sidecar.

### Loop UX

Wizard shows progress per loop iteration: `Step 5 — Auth [Persona 1 of 2]`. State machine checkpoints per loop iteration so `/greenfield:pickup` resumes mid-loop precisely.

## Heavy/Light toggle mechanic

### Q-bank flag

Each Q-bank entry gets `showInLight: boolean` (default: `true`).

- `true` → fires in both modes
- `false` → skipped in Light mode

No light-mode-specific alternate questions. Light = strict subset of Heavy. Q-bank single-source-of-truth.

### Counts per phase

| Phase | Heavy | Light |
|---|---|---|
| Personas | ~12 | ~4 |
| ArchFraming | 4 | 4 |
| Domain | ~15 | ~5 |
| Data | 12 | ~7 |
| Api | 10 | ~6 |
| Auth | ~10 | ~5 |
| Privacy | ~12 | ~6 |
| Security | ~10 | ~5 |
| RuntimeOps | ~14 | ~7 |
| CICD | 17 | ~10 |
| ArchVal | ~6 | ~4 |
| **Total** | **~120** | **~65** |

Risk Qs (10 inline: 2 discovery + 8 architectural phases) always fire. Step 15 has Risk Reconciliation, not an inline Q_RISK.

### Interaction with `mode.domainFormat`

- `Heavy + Full DDD`: full ~15 Domain Qs
- `Heavy + DDD-lite`: ~10 Domain Qs (drops Q6/Q7/Q10)
- `Light + (any)`: ~5 Domain Qs (Full DDD setting ignored)

### Mid-wizard switch

User flips mode via `/greenfield:pickup → "Adjust mode"`. Wizard plays new-mode-only Qs across completed phases; existing answers preserved.

## Schema changes

### `context-shape-v2.json`

Add top-level `mode` block, two new phase blocks, one extended phase block, one cross-cutting `risks[]` array. Full shape:

```jsonc
{
  "version": 2,
  "mode": {
    "depth": "heavy" | "light",
    "coupling": "auto-loop" | "hybrid",
    "domainFormat": "full-ddd" | "ddd-lite"
  },
  "phases": {
    "personas": {
      "primary": [/* Persona shape: id, name, role, goal, context, jobs, constraints, antiPersona */],
      "secondary": [/* lean persona shape */],
      "antiPersonas": ["string"],
      "skipped": boolean,
      "deferredReason": "string?"
    },
    "domainModel": {
      "contexts": [{ "id": "BC1", "name": "string", "responsibility": "string" }],
      "entities": [{ "id": "string", "contextId": "string", "isAggregateRoot": boolean, "relationships": [...] }],
      "valueObjects": ["string"],
      "domainEvents": ["string"],
      "crossContextRelationships": [...],
      "ubiquitousLanguage": [{ "term": "string", "definition": "string" }],
      "antiCorruption": "string?",
      "deferred": boolean
    },
    "architecturalValidation": {
      "riskReconciliation": {
        "summary": {
          "mitigated": ["risk-id"], "partial": [], "acceptedExplicit": [],
          "openFollowup": [], "outOfScope": []
        },
        "topFollowups": ["risk-id"]
      }
    }
  },
  "risks": [
    {
      "id": "R-DATA-1",
      "originatingPhase": "string",
      "text": "string",
      "tags": ["string"],
      "reconciliation": {
        "status": "mitigated|partial|accepted-explicit|open-followup|out-of-scope|user-declared-none",
        "rationale": "string?"
      }
    }
  ]
}
```

### `dependencies-schema.json`

- Phase enum extends: add `personas`, `domainModel`, `risks` (pseudo-phase for cross-cutting record)
- Path pattern extends: allow `personas.*`, `domainModel.*`, `risks[*].*`
- New optional `sourceRef` field on dependency entries (required when produced by auto-loop iteration):

```jsonc
{
  "path": "auth.roles[?personaId='P1'].role",
  "value": "FieldAuditor",
  "rationale": "Derived from personas.primary[P1]",
  "sourceRef": { "phase": "personas", "id": "P1" }
}
```

## Cross-phase invariants (CHECK-R4-*)

| ID | Rule | Severity |
|---|---|---|
| CHECK-R4-1 | Every primary persona has ≥ 1 job-to-be-done OR `mode.depth=light` | hard-fail |
| CHECK-R4-2 | Every aggregate-root entity has a corresponding `data.persistence` decision | hard-fail |
| CHECK-R4-3 | If `mode.coupling=auto-loop`, every persona referenced in auth/privacy/frontend has `derivedFrom: P<n>` | hard-fail |
| CHECK-R4-4 | Every captured risk has a reconciliation status before final sign-off | hard-fail |
| CHECK-R4-5 | No `auth.access[]` rule for an entity that has no corresponding `domainModel.entities[].id` | warn |
| CHECK-R4-6 | `bounded-contexts ≤ entities` count (otherwise contexts are vacuous) | warn |
| CHECK-R4-7 | No anti-persona name collides with a primary/secondary persona name | warn |
| CHECK-R4-8 | Light + DDD-lite implies coupling=hybrid is recommended (auto-loop with sparse data is wasteful); wizard offers auto-switch | suggestion |

## Affected files

### Files created (~16)

```
greenfield/skills/context-gathering/references/
  ├── personas.q-bank.md
  ├── domain-model.q-bank.md
  └── inline-risk.q-bank.md

greenfield/skills/synthesis-review/references/
  ├── personas.synthesis.html.tpl
  ├── personas.synthesis.md.tpl
  ├── personas.dependencies.json.example
  ├── domain-model.synthesis.html.tpl
  ├── domain-model.synthesis.md.tpl
  ├── domain-model.dependencies.json.example
  ├── arch-val-risk-reconciliation-section.html.tpl
  └── risks.dependencies.json.example

greenfield/skills/grill-spec/references/
  └── check-r4-invariants.md

docs/greenfield-3.0-round4/
  ├── overview.md
  ├── coupling-matrix.md
  └── migration-notes.md
```

### Files modified (~15)

| File | Change |
|---|---|
| `greenfield/skills/context-gathering/SKILL.md` | Add Steps 2.2, 2.7; depth + coupling toggles at Step 1; auto-loop state machine logic |
| `greenfield/skills/context-gathering/references/{auth,privacy,security,runtimeOps,cicd,data,api,architecturalFraming}.q-bank.md` (8 files) | Add `Q_RISK` entry; tag existing Qs with `loopOver` + `loopMode`; add `showInLight` flag |
| `greenfield/skills/synthesis-review/SKILL.md` | Handle 2 new templates; back-fill "Decisions Driven Downstream" after loops; render `sourceRef` traces |
| `greenfield/skills/grill-spec/SKILL.md` | Wire CHECK-R4-1 through CHECK-R4-8 |
| `greenfield/skills/pickup/SKILL.md` | Mid-wizard mode switch; post-hoc persona/entity add detection; alpha.4 → alpha.5 state migration |
| `greenfield/skills/tooling-generation/SKILL.md` | Pass `phases.personas` + `phases.domainModel` to `/onboard:generate` |
| `greenfield/skills/start/SKILL.md` | Step 1 toggle UX; mode persistence |
| `greenfield/skills/check/SKILL.md` | Verify `docs/adr/personas.html` + `domain-model.html` exist (when applicable) |
| `greenfield/CLAUDE.md` | Update wizard diagram (17 steps), mode toggles, Round 4 commentary |
| `greenfield/.claude-plugin/plugin.json` | `3.0.0-alpha.4` → `3.0.0-alpha.5` |
| `onboard/.claude-plugin/plugin.json` | `2.0.0-alpha.4` → `2.0.0-alpha.5` |
| `onboard/skills/generation/references/context-shape-v2.json` | Add `mode`, `phases.personas`, `phases.domainModel`, `risks[]`; extend `phases.architecturalValidation` |
| `onboard/skills/generation/references/dependencies-schema.json` | Phase enum + path pattern + `sourceRef` |
| `onboard/skills/generation/SKILL.md` | Handle new phase blocks (or absent — backward compat) |
| `.claude-plugin/marketplace.json` | Version sync (greenfield + onboard) |

### Migrations from existing Q-bank

| Existing Q | Action |
|---|---|
| Step 2 vision/scope "Who are the users?" | **Pointer-only** — text becomes "→ See Step 2.2 Personas". Existing answer preserved as `vision.users[]` (legacy field) for backward compat. |
| Step 2.5 architecturalFraming `boundaryNotes` | **Unchanged.** Boundary notes ≠ bounded contexts; document the distinction in CLAUDE.md. |
| Step 5 auth — existing role Qs | **Auto-loop wrapped.** Original Qs become persona-iterated versions. Old phrasing preserved as fallback (Hybrid mode + no personas). |
| Step 7 security — threat model Qs | **`showInLight: false`** for depth Qs; threat model auto-loops on entities in Heavy + auto-loop combo. |

### State file migration (`greenfield-state.json`: alpha.4 → alpha.5)

Auto-run on `/greenfield:pickup` when schema mismatch detected:

```
1. Set mode.depth         = "heavy"
2. Set mode.coupling      = "hybrid"     ← SAFER default for in-flight sessions
3. Set mode.domainFormat  = "ddd-lite"
4. Mark personas + domain phases status: "not-yet-run"
5. Bump state.schemaVersion → "alpha.5"
6. Log migration to .claude/greenfield-meta.json.audit[]
```

The `hybrid` coupling default for migrated sessions is intentionally less invasive than the cold-start default (`auto-loop`) — in-flight users shouldn't have all completed phases retroactively expanded by persona/entity loops.

## Edge cases (round-level)

1. **alpha.4 user in-flight when alpha.5 lands.** On next `/greenfield:pickup`, wizard runs state migration. Explanation: "Round 4 added Personas + Domain phases. Resume current step, or run new phases retroactively?"
2. **User on Light + Hybrid upgrades mid-project.** `/greenfield:pickup → "Adjust mode"`. Wizard runs delta-Qs only; preserves all existing answers.
3. **`/greenfield:check` post-generation.** Health check verifies `personas.html` + `domain-model.html` exist. If `mode.skipped` set, check passes silently. Otherwise flags "no personas captured."
4. **Onboard alpha.5 invoked from non-Round-4 source.** Treats `phases.personas` + `phases.domainModel` as optional. If absent, behaves as alpha.4.
5. **Auto-loop runaway** (e.g., 5 personas × 3 entities × 6 phases = 90 loop iterations). Wizard hard-caps at 200 Qs per phase. Beyond, prompts "consolidate." Logs degradation reason.
6. **Heavy + Full DDD + Auto-loop on a hobby project.** Wizard detects > 150 projected Qs and offers ONE-TIME "Switch to Light + DDD-lite + Hybrid?" prompt at end of Step 1.
7. **Persona answers Q_RISK with "no risks."** Tagged `risks[].status = "user-declared-none"`. Reconciliation surfaces count: "3 phases declared no risk — confirm?" Once.
8. **Risk text drift across phases.** Same risk worded differently in two phases. Wizard runs similarity check at start of Reconciliation; offers to merge.
9. **Persona has empty `jobs[]` (Light mode).** Q text that templates over `{persona.jobs}` falls back to a generic prompt; synthesis renders a footnote.
10. **Hybrid + DDD-lite + no aggregate roots tagged.** Data.persistence loops use entity list as-is; aggregate-boundary question collapses to single repository-pattern Q.

## Backward compatibility

Round 4 is the **first round to break the R3-style "hard cutover"** posture. Reasoning: R3's break was a schema reshape; R4's break is purely additive (new fields, new phases). The auto-migration shim lets alpha.4 sessions resume seamlessly under alpha.5.

Onboard 2.0 alpha.5 retains its R3 hard-cutover for the `phases.*` blocks added in R3 (auth/privacy/security/runtimeOps) — those still require alpha.4+ context input. R4's additions are layered on top.

Lossy forward-compat: alpha.4 wizard reading an alpha.5 state file ignores unknown `mode.*`, `phases.personas`, `phases.domainModel`, `risks[]` fields. State preserved on next alpha.5 read.

## Rollback path

| Level | Action | Cost |
|---|---|---|
| Single phase | Revert that phase's commits (~5–10 commits per subagent task). State file resets that phase to "not-yet-run." | Low |
| Single feature (e.g., auto-loop) | Revert the loop mechanic commits; keep new phases as static (no looping). Q-bank entries lose `loopOver` field but remain valid. | Medium |
| Full Round 4 rollback | Revert all R4 commits; `plugin.json` → `3.0.0-alpha.4`. Users with alpha.5 state files: on next pickup, wizard detects schema downgrade, offers to clear `mode.*` + personas + domainModel + risks. Existing tech-spine phases unaffected. | High |

## Testing strategy

- **Q-bank validator (pre-existing pattern)**: validates `showInLight: false` Qs aren't referenced by templates in non-light Qs. Hard CI fail.
- **Auto-loop integration tests**: simulate 2 personas × 3 entities; verify auth/privacy/data/api loop counts match expected; verify `sourceRef` populated on each looped answer.
- **State migration tests**: feed alpha.4 state JSON into alpha.5 pickup; verify migration shim runs deterministically; verify no data loss.
- **Coupling matrix tests**: for each row in the matrix, exercise both Auto-loop and Hybrid; verify the Q either loops or fires statically as specified.
- **Synthesis HTML rendering tests**: render each template (`personas`, `domain-model`, `architectural-validation`) with representative data; snapshot-diff against golden files.
- **Cross-phase invariant tests**: feed crafted bad contexts (missing aggregate-root persistence, persona name colliding with anti-persona, etc.); verify CHECK-R4-* fire with the right severity.

## Execution model (Approach A — Big Bang)

Following the R3 pattern:

1. **Spec lock** (this document, approved by user)
2. **Implementation plan** (next step — via `superpowers:writing-plans`)
3. **Subagent dispatch** — ~35–40 tasks across personas/domain authoring, Q-bank modifications, schema updates, synthesis templates, invariants, state machine extensions, migrations, tests, version bumps
4. **Mid-execution checkpoint** — after Q-bank entries land but before state machine wiring; verify schema + Q-bank shape are consistent (lesson from R3: catch field-name drift early)
5. **Quality + spec reviews per task** (R3 pattern)
6. **Final integration: PR #51 against develop** with version `3.0.0-alpha.5`
7. **Memory + Discussion Log update** post-merge

## Open questions for the plan phase

(These fit better in the implementation plan than the spec, but are surfaced here so the plan author doesn't miss them.)

1. **Exact wording of the Step 1 toggle prompts** — three toggles back-to-back is a lot of UX surface; should they be one combined screen or three sequential?
2. **`risks.dependencies.json` ownership during incremental write** — which step's commit lands the file initially? Architectural Framing (first phase to produce a risk)? Or initialize empty at Step 1?
3. **Loop progress indicator copy** — "Persona 1 of 2" is clear; for entity loops with potentially 6+ entities, do we want "Entity 1 of 6 — Audit" or "Audit (1/6)"?
4. **Anti-persona free-text vs. structured** — `Persona.Q8` is single-text now; should it become repeating (multiple anti-personas) or stay flat?
5. **Schema for `domainModel.crossContextRelationships`** — current shape is structured pair + relationship; consider whether to support "anti-corruption-layer" as a relationship kind or as a separate `Q10` field (current spec uses both — relationship + free-text).
