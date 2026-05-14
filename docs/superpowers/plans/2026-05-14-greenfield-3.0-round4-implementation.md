# Greenfield 3.0 Round 4 — Personas + Domain Modeling + Distributed Risk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 2 new top-level wizard phases (Personas at Step 2.2, Domain Modeling at Step 2.7), distribute risk capture as an inline question across every architectural phase, extend `architecturalValidation` with a Risk Reconciliation section, and introduce wizard-level mode toggles (depth, coupling, domainFormat) with auto-loop and Heavy/Light mechanics.

**Architecture:** Same pattern as Round 3 — each new phase gets a schema section, a synthesis HTML+MD template pair with dependencies.json sidecar, Q-bank entries, and a wizard step in `context-gathering/SKILL.md` that invokes `synthesis-review` inline. New mechanics introduced in this round: auto-loop (Q-bank `loopOver` + `loopMode` flags), Heavy/Light Q gating (Q-bank `showInLight` flag), inline-risk-Q (Q-bank `isRiskCapture` flag) collecting into shared `risks[]`, and Risk Reconciliation phase extension. Cross-cutting infrastructure (synthesis review, MD/HTML companions, docs/adr output, grill-spec invariants, freshness hook, state checkpointing) all ships from Rounds 2.5/3 — Round 4 layers on top.

**Tech Stack:** Markdown SKILL.md files, JSON Schema draft-07, HTML synthesis templates (Mustache-like `{{placeholder}}` syntax), Markdown synthesis companions, bash verification commands (jq, grep, /validate skill). No compiled code, no automated test suite for skills (consistent with prior rounds).

**Source spec:** `docs/superpowers/specs/2026-05-14-greenfield-3.0-round4-design.md`

**Branch:** `feat/greenfield-1.3` (new branch for Round 4; merged via PR #51 once complete).

**Target versions on completion:** `greenfield@3.0.0-alpha.5` / `onboard@2.0.0-alpha.5`.

---

## File Structure

### NEW files (~16)

| Path | Responsibility |
|---|---|
| `greenfield/skills/context-gathering/references/personas.q-bank.md` | 12 Q entries (heavy) for Personas phase with showInLight flags |
| `greenfield/skills/context-gathering/references/domain-model.q-bank.md` | 15 Q entries (heavy + Full DDD) for Domain Modeling phase |
| `greenfield/skills/context-gathering/references/inline-risk.q-bank.md` | 10 inline `Q_RISK` entries (8 architectural + 2 discovery phases) with shared template |
| `greenfield/skills/synthesis-review/references/templates/personas.html` | Personas synthesis HTML template (6 sections) |
| `greenfield/skills/synthesis-review/references/templates/personas.md` | Personas synthesis MD companion |
| `greenfield/skills/synthesis-review/references/templates/personas-dependencies.json.example` | Personas dependency sidecar example |
| `greenfield/skills/synthesis-review/references/templates/domain-model.html` | Domain Modeling synthesis HTML template (10 sections) |
| `greenfield/skills/synthesis-review/references/templates/domain-model.md` | Domain Modeling synthesis MD companion |
| `greenfield/skills/synthesis-review/references/templates/domain-model-dependencies.json.example` | Domain Modeling dependency sidecar example |
| `greenfield/skills/synthesis-review/references/templates/arch-val-risk-reconciliation-section.html` | Risk Reconciliation section partial (renders inside existing architectural-validation.html) |
| `greenfield/skills/synthesis-review/references/templates/risks-dependencies.json.example` | Shared cross-phase risks sidecar example |
| `greenfield/skills/grill-spec/references/check-r4-invariants.md` | CHECK-R4-1 through CHECK-R4-8 invariant definitions |
| `docs/greenfield-3.0-round4/overview.md` | Round 4 summary, commit log placeholder, brainstorm-to-merge narrative |
| `docs/greenfield-3.0-round4/coupling-matrix.md` | Definitive auto-loop / Hybrid coupling table |
| `docs/greenfield-3.0-round4/migration-notes.md` | alpha.4 → alpha.5 user-facing migration notes |
| `docs/superpowers/plans/2026-05-14-greenfield-3.0-round4-implementation.md` | This file |

### MODIFIED files (~15)

| Path | What changes |
|---|---|
| `onboard/skills/generation/references/context-shape-v2.json` | + `mode` top-level block; + `phases.personas`; + `phases.domainModel`; + `phases.architecturalValidation.riskReconciliation`; + top-level `risks[]`; update root description |
| `onboard/skills/generation/references/dependencies-schema.json` | Phase enum extends (+`personas`, `domainModel`, `risks`); path pattern extends; + optional `sourceRef` field on dependency entries |
| `onboard/skills/generation/SKILL.md` | Handle new phase blocks (or absent — backward-compat semantics) |
| `greenfield/skills/context-gathering/SKILL.md` | + Steps 2.2 (Personas) and 2.7 (Domain); + Step 1 mode-toggle prompts; + auto-loop state machine logic; wizard step count 15 → 17; renumber progress indicators |
| `greenfield/skills/context-gathering/references/question-bank.md` | Add `showInLight`, `loopOver`, `loopMode`, `isRiskCapture` flag documentation; demote Step 2 vision/scope users-Q to pointer |
| `greenfield/skills/context-gathering/references/{architectural-framing,data-architecture,api-integration,auth,privacy,security,runtime-operations,cicd}.q-bank.md` (8 files) | + `Q_RISK` entry at end; tag selected existing Qs with `loopOver` / `loopMode`; add `showInLight: false` to depth-only Qs |
| `greenfield/skills/synthesis-review/SKILL.md` | Handle 2 new templates (personas, domain-model); back-fill "Decisions Driven Downstream" section after downstream phases complete; render `sourceRef` traces |
| `greenfield/skills/synthesis-review/references/section-prompts.md` | + section-prompt blocks for Personas (6) and Domain Modeling (10) |
| `greenfield/skills/grill-spec/SKILL.md` | Wire CHECK-R4-1 through CHECK-R4-8 alongside existing CHECK-R3-* |
| `greenfield/skills/start/SKILL.md` | Step 1 toggle UX (depth, coupling, domainFormat); wizard step count 15 → 17 |
| `greenfield/skills/pickup/SKILL.md` | Mid-wizard mode-switch flow; post-hoc persona/entity add detection; alpha.4 → alpha.5 state migration shim |
| `greenfield/skills/check/SKILL.md` | Verify `docs/adr/personas.html` + `domain-model.html` exist when applicable |
| `greenfield/skills/tooling-generation/SKILL.md` | Pass `phases.personas` + `phases.domainModel` + `risks[]` to `/onboard:generate` |
| `greenfield/CLAUDE.md` | Update wizard diagram (17 steps), mode toggles, Round 4 commentary; bump round-status section |
| `onboard/CLAUDE.md` | Phase listing additions (personas, domainModel, riskReconciliation) |
| `docs/greenfield-overview.html` | ROUND 4 LOCKED entry in Discussion Log |
| `greenfield/.claude-plugin/plugin.json` | `3.0.0-alpha.4` → `3.0.0-alpha.5` |
| `onboard/.claude-plugin/plugin.json` | `2.0.0-alpha.4` → `2.0.0-alpha.5` |
| `.claude-plugin/marketplace.json` | Version sync (greenfield + onboard); update descriptions |
| `greenfield/CHANGELOG.md` | "Round 4 additions" entry — alpha.4 → alpha.5 (auto-migrating, not hard cutover) |
| `onboard/CHANGELOG-2.0.md` | "Round 4 additions" entry; schema-extension note |

**Total: ~16 new + ~15 modified = ~31 files** (matches design estimate of ~31).

---

## Task Order Overview

```
Phase A — Schema foundations
   T1   Add `mode` block + `phases.personas` + `phases.domainModel` + `phases.architecturalValidation.riskReconciliation` + top-level `risks[]` to context-shape-v2.json
   T2   Extend dependencies-schema.json (phase enum, path pattern, sourceRef)

Phase B — Q-bank authoring (new phases)
   T3   personas.q-bank.md — 12 Q entries with showInLight flags
   T4   domain-model.q-bank.md — 15 Q entries with DDD-lite tagging

Phase C — Q-bank modifications (existing 8 architectural phases)
   T5   architectural-framing.q-bank.md — + Q_RISK + showInLight tags
   T6   data-architecture.q-bank.md — + Q_RISK + loopOver entity tags + showInLight
   T7   api-integration.q-bank.md — + Q_RISK + loopOver entity tags + showInLight
   T8   auth.q-bank.md — + Q_RISK + loopOver persona tags + showInLight
   T9   privacy.q-bank.md — + Q_RISK + loopOver persona tags + showInLight
   T10  security.q-bank.md — + Q_RISK + loopOver tags + showInLight
   T11  runtime-operations.q-bank.md — + Q_RISK + loopOver persona tags + showInLight
   T12  cicd.q-bank.md — + Q_RISK + showInLight (no loops)

Phase D — Synthesis templates
   T13  personas.html + personas.md + personas-dependencies.json.example
   T14  domain-model.html + domain-model.md + domain-model-dependencies.json.example
   T15  arch-val-risk-reconciliation-section.html + risks-dependencies.json.example
   T16  inline-risk.q-bank.md (shared template doc) + section-prompts.md additions

Phase E — State machine + skill updates
   T17  context-gathering/SKILL.md — Step 1 mode toggles + Steps 2.2 & 2.7 + auto-loop state machine
   T18  context-gathering/SKILL.md — renumber + progress indicators 15 → 17
   T19  synthesis-review/SKILL.md — handle 2 new templates + sourceRef rendering + back-fill section 6
   T20  start/SKILL.md — Step 1 toggle UX
   T21  pickup/SKILL.md — mid-wizard mode switch + state migration shim
   T22  check/SKILL.md + tooling-generation/SKILL.md — health check + onboard pass-through

Phase F — Cross-phase invariants
   T23  check-r4-invariants.md + grill-spec/SKILL.md wiring + question-bank.md flag docs

Phase G — Migrations
   T24  Demote Step 2 vision/scope users-Q to pointer; preserve as legacy field
   T25  Onboard SKILL.md: handle new phase blocks (backward-compat: optional)

Phase H — Docs + bookkeeping
   T26  greenfield/CLAUDE.md + onboard/CLAUDE.md — diagrams, round-status section
   T27  docs/greenfield-3.0-round4/ companion docs + greenfield-overview.html Discussion Log
   T28  Version bumps + marketplace.json + CHANGELOGs

Phase I — Integration smoke + final pass
   T29  End-to-end auto-loop simulation (mock context, run through Steps 5-8, verify sourceRef populated)
   T30  alpha.4 → alpha.5 state migration test
   T31  Run /validate skill across all plugins; PR creation
```

**Estimated total: 31 tasks.** Each task = 1 logical commit. Subagent dispatch estimated at ~70-90 invocations (implementer + spec-review + quality-review + occasional fix per task, matching R3 cadence).

**Two mid-execution checkpoints (lessons from R3):**

1. **After Phase A (schema lock)** — before any Q-bank or template work uses field names, verify schema is final. Catches the R3 "invented field names" failure mode.
2. **After Phase D (template lock)** — before state machine wiring, verify synthesis template variable names match Q-bank answer-schema field names. Catches the R3 "aspirational template structure" failure mode.

---

## Phase A — Schema foundations

### Task 1: Add `mode`, `phases.personas`, `phases.domainModel`, `phases.architecturalValidation.riskReconciliation`, top-level `risks[]` to context-shape-v2.json

**Files:**
- Modify: `onboard/skills/generation/references/context-shape-v2.json`

- [ ] **Step 1: Inspect current schema shape**

Run: `jq 'keys' onboard/skills/generation/references/context-shape-v2.json`

Expected output includes: `phases`, `version`, possibly `metadata`. No `mode` or `risks` top-level keys yet.

- [ ] **Step 2: Add the `mode` top-level block**

Insert after the `version` key (use the structure below; preserve existing JSON formatting):

```jsonc
"mode": {
  "type": "object",
  "description": "Wizard-level mode toggles set at Step 1. Persisted in greenfield-state.json.",
  "properties": {
    "depth": {
      "type": "string",
      "enum": ["heavy", "light"],
      "default": "heavy",
      "description": "Heavy: full Q-bank (~120 Qs total). Light: showInLight=true Qs only (~65)."
    },
    "coupling": {
      "type": "string",
      "enum": ["auto-loop", "hybrid"],
      "default": "auto-loop",
      "description": "Auto-loop: every downstream phase iterates per persona/entity. Hybrid: only loopMode=always Qs iterate."
    },
    "domainFormat": {
      "type": "string",
      "enum": ["full-ddd", "ddd-lite"],
      "default": "full-ddd",
      "description": "Full DDD includes value objects, domain events, anti-corruption. DDD-lite drops them."
    }
  },
  "required": ["depth", "coupling", "domainFormat"]
}
```

- [ ] **Step 3: Add `phases.personas` block**

Insert as a new key under `phases`:

```jsonc
"personas": {
  "type": "object",
  "description": "Round 4 — discovery phase (Step 2.2). Produces persona reference data for auto-loop.",
  "properties": {
    "primary": {
      "type": "array",
      "maxItems": 5,
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string", "pattern": "^P[0-9]+$" },
          "name": { "type": "string" },
          "role": { "type": "string" },
          "goal": { "type": "string" },
          "context": {
            "type": "object",
            "properties": {
              "device": { "type": "array", "items": { "type": "string" } },
              "connection": { "type": "string" },
              "techSophistication": { "type": "string", "enum": ["Power user","Comfortable","Basic","Novice"] }
            }
          },
          "jobs": {
            "type": "array",
            "items": { "type": "object", "properties": { "id":{"type":"string"}, "story":{"type":"string"} } }
          },
          "constraints": { "type": "string" },
          "antiPersona": { "type": "string" }
        },
        "required": ["id", "name", "role", "goal"]
      }
    },
    "secondary": {
      "type": "array",
      "maxItems": 3,
      "items": {
        "type": "object",
        "properties": { "id":{"type":"string"}, "name":{"type":"string"}, "role":{"type":"string"}, "context":{"type":"string"} }
      }
    },
    "antiPersonas": { "type": "array", "items": { "type": "string" } },
    "skipped": { "type": "boolean", "default": false },
    "deferredReason": { "type": "string" }
  }
}
```

- [ ] **Step 4: Add `phases.domainModel` block**

Insert as a new key under `phases`:

```jsonc
"domainModel": {
  "type": "object",
  "description": "Round 4 — discovery phase (Step 2.7). Produces domain reference data for auto-loop.",
  "properties": {
    "contexts": {
      "type": "array",
      "items": { "type": "object", "properties": { "id":{"type":"string","pattern":"^BC[0-9]+$"}, "name":{"type":"string"}, "responsibility":{"type":"string"} } }
    },
    "entities": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "contextId": { "type": "string" },
          "isAggregateRoot": { "type": "boolean" },
          "relationships": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": { "target":{"type":"string"}, "kind":{"type":"string","enum":["has-one","has-many","belongs-to","refs"]} }
            }
          }
        },
        "required": ["id", "contextId", "isAggregateRoot"]
      }
    },
    "valueObjects": { "type": "array", "items": { "type": "string" } },
    "domainEvents": { "type": "array", "items": { "type": "string" } },
    "crossContextRelationships": {
      "type": "array",
      "items": { "type": "object", "properties": { "from":{"type":"string"}, "to":{"type":"string"}, "kind":{"type":"string"} } }
    },
    "ubiquitousLanguage": {
      "type": "array",
      "items": { "type": "object", "properties": { "term":{"type":"string"}, "definition":{"type":"string"} } }
    },
    "antiCorruption": { "type": "string" },
    "deferred": { "type": "boolean", "default": false }
  }
}
```

- [ ] **Step 5: Extend `phases.architecturalValidation` with `riskReconciliation` sub-block**

Find the existing `architecturalValidation` block. Add this property under its `properties`:

```jsonc
"riskReconciliation": {
  "type": "object",
  "description": "Round 4 — front section of Step 15. Walks each captured risk + asks reconciliation status.",
  "properties": {
    "summary": {
      "type": "object",
      "properties": {
        "mitigated":         { "type": "array", "items": { "type": "string" } },
        "partial":           { "type": "array", "items": { "type": "string" } },
        "acceptedExplicit":  { "type": "array", "items": { "type": "string" } },
        "openFollowup":      { "type": "array", "items": { "type": "string" } },
        "outOfScope":        { "type": "array", "items": { "type": "string" } }
      }
    },
    "topFollowups": { "type": "array", "items": { "type": "string" }, "description": "Risk IDs flagged as worth a feature-list.json followup card." }
  }
}
```

- [ ] **Step 6: Add top-level `risks[]` array**

Insert at the root (alongside `version`, `mode`, `phases`):

```jsonc
"risks": {
  "type": "array",
  "description": "Cross-cutting risks collected from inline Q_RISK in each architectural phase + 2 discovery phases. 10 entries max in default cadence.",
  "items": {
    "type": "object",
    "properties": {
      "id": { "type": "string", "pattern": "^R-[A-Z]+-[0-9]+$" },
      "originatingPhase": { "type": "string", "enum": ["personas","domainModel","architecturalFraming","dataArchitecture","apiIntegration","auth","privacy","security","runtimeOperations","cicdAndDelivery"] },
      "text": { "type": "string" },
      "tags": { "type": "array", "items": { "type": "string", "enum": ["scaling","security","dataloss","vendor-lock","compliance","performance","ops","team","market"] } },
      "reconciliation": {
        "type": "object",
        "properties": {
          "status": { "type": "string", "enum": ["mitigated","partial","accepted-explicit","open-followup","out-of-scope","user-declared-none"] },
          "rationale": { "type": "string" }
        }
      }
    },
    "required": ["id", "originatingPhase", "text"]
  }
}
```

- [ ] **Step 7: Update root description**

Find the root `description` field. Append: `"Round 4 extension: adds mode toggles, personas/domainModel phases, riskReconciliation in architecturalValidation, and top-level risks[]."`

- [ ] **Step 8: Validate JSON syntax**

Run: `jq . onboard/skills/generation/references/context-shape-v2.json > /dev/null`

Expected: no output (silent success). If parse error, fix syntax.

- [ ] **Step 9: Verify new top-level keys present**

Run: `jq 'keys' onboard/skills/generation/references/context-shape-v2.json`

Expected output includes: `mode`, `phases`, `risks`, `version`.

Run: `jq '.phases | keys' onboard/skills/generation/references/context-shape-v2.json`

Expected output includes: `personas`, `domainModel`, `architecturalValidation` (alongside the R3 phases).

- [ ] **Step 10: Commit**

```bash
git add onboard/skills/generation/references/context-shape-v2.json
git commit -m "feat(onboard): context-shape-v2 R4 — mode block, personas, domainModel, riskReconciliation, risks[]"
```

---

### Task 2: Extend dependencies-schema.json (phase enum, path pattern, sourceRef)

**Files:**
- Modify: `onboard/skills/generation/references/dependencies-schema.json`

- [ ] **Step 1: Inspect current schema**

Run: `jq . onboard/skills/generation/references/dependencies-schema.json`

Note the current `phase` enum values and `path` pattern regex.

- [ ] **Step 2: Extend phase enum**

Locate the `phase` property's enum. Add three new values:

```jsonc
"phase": {
  "type": "string",
  "enum": [
    // ... existing R3 values: architecturalFraming, dataArchitecture, apiIntegration,
    //                          auth, privacy, security, runtimeOperations, cicdAndDelivery,
    //                          architecturalValidation
    "personas",       // NEW R4
    "domainModel",    // NEW R4
    "risks"           // NEW R4 pseudo-phase for cross-cutting record
  ]
}
```

- [ ] **Step 3: Extend path pattern**

Locate the `path` property's pattern regex. Extend to allow `personas.*`, `domainModel.*`, `risks[*].*`. Example final pattern:

```jsonc
"path": {
  "type": "string",
  "pattern": "^(personas|domainModel|risks|architecturalFraming|dataArchitecture|apiIntegration|auth|privacy|security|runtimeOperations|cicdAndDelivery|architecturalValidation)(\\.[\\w\\[\\]\\?='*\\.]+)*$"
}
```

- [ ] **Step 4: Add optional `sourceRef` field on dependency entries**

Locate the `dependencies` array's `items` object. Add a new optional property:

```jsonc
"sourceRef": {
  "type": "object",
  "description": "Round 4 — when this dependency was produced by an auto-loop iteration, sourceRef points to the source persona/entity. REQUIRED if path contains [?personaId=…] or [?entityId=…] predicate; omitted otherwise.",
  "properties": {
    "phase": { "type": "string", "enum": ["personas", "domainModel"] },
    "id": { "type": "string", "description": "Persona ID (P1, P2, …) or Entity ID" }
  },
  "required": ["phase", "id"]
}
```

- [ ] **Step 5: Validate JSON syntax**

Run: `jq . onboard/skills/generation/references/dependencies-schema.json > /dev/null`

Expected: silent success.

- [ ] **Step 6: Smoke-test the path pattern**

Run a quick sanity check:

```bash
# Valid R4 paths:
echo "personas.primary[0].id"           | grep -E "$(jq -r '.properties.path.pattern' onboard/skills/generation/references/dependencies-schema.json)"
echo "domainModel.entities[?id='Audit'].isAggregateRoot" | grep -E "$(jq -r '.properties.path.pattern' onboard/skills/generation/references/dependencies-schema.json)"
echo "risks[0].text"                    | grep -E "$(jq -r '.properties.path.pattern' onboard/skills/generation/references/dependencies-schema.json)"
```

Expected: all three match (echo each line if pattern accepts).

- [ ] **Step 7: Commit**

```bash
git add onboard/skills/generation/references/dependencies-schema.json
git commit -m "feat(onboard): dependencies-schema R4 — extend phase enum, path pattern, add sourceRef"
```

---

## Phase B — Q-bank authoring (new phases)

> **Note:** Each Q-bank file follows the existing convention seen in R3 (`auth.q-bank.md`, `privacy.q-bank.md`, etc.) — H2 sections per Q, frontmatter or inline YAML for metadata. If unsure of exact shape, reference `greenfield/skills/context-gathering/references/auth.q-bank.md`.

### Task 3: Author personas.q-bank.md

**Files:**
- Create: `greenfield/skills/context-gathering/references/personas.q-bank.md`

- [ ] **Step 1: Inspect an existing Q-bank file for shape**

Run: `head -80 greenfield/skills/context-gathering/references/auth.q-bank.md`

Note: H1 title, intro paragraph, then H2 per question with metadata, question text, answer-schema, optional default-derivation notes.

- [ ] **Step 2: Author file header**

```markdown
# Personas Q-bank — Step 2.2

> **Round:** 4 (Discovery phase)
> **Steps:** 2.2 (front-load discovery, before architecturalFraming)
> **Modes:** Heavy ~12 Qs, Light ~4 Qs
> **Coupling:** Output (persona IDs) consumed by auto-loop in auth, privacy, frontend (and security/runtimeOps in auto-loop mode)
> **See also:** `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Personas phase

This phase captures **rich personas with downstream hooks**. Each persona = name, role, primary goal, context (device/connection/literacy), tech sophistication, 2–3 jobs-to-be-done, anti-persona. Persona IDs (P1, P2, …) become first-class identifiers referenced by downstream phases via auto-loop.

## Q-bank
```

- [ ] **Step 3: Author Q1 — primary persona count**

```markdown
### Persona.Q1 — Primary persona count

- **type:** single-select
- **options:** ["1", "2", "3", "4", "5"]
- **showInLight:** true
- **isRiskCapture:** false
- **loopTrigger:** true   <!-- Q2-Q8 iterate per primary persona -->
- **cap:** 5 primary (with up to 3 secondaries in Q9 → 8 total max)

**Prompt:** "How many primary personas drive critical user flows? (Pick 1–3 unless your product has clearly distinct user types — too many personas dilutes architectural decisions.)"

**Stores to:** `personas.primary[].count` (used to iterate Q2-Q8 N times)
```

- [ ] **Step 4: Author Q2-Q8 (loops per primary persona)**

For Q2-Q8, follow the pattern below. Full text per question is in design spec § Personas phase Q-bank Heavy mode:

```markdown
### Persona.Q2 — Name + role (per primary persona)

- **type:** short-text
- **showInLight:** true
- **isRiskCapture:** false
- **template:** "Persona {iter} of {Persona.Q1.value} — name + role:"

**Stores to:** `personas.primary[{iter}].name`, `personas.primary[{iter}].role`
**ID convention:** wizard assigns id = "P{iter}" (e.g., P1, P2)
```

(Continue with Q3 "Primary goal" — short-text, showInLight:true; Q4 "Device + connection context" — multi-select with the option list from spec, showInLight:false; Q5 "Tech sophistication" — single-select [Power user, Comfortable, Basic, Novice], showInLight:false; Q6 "2-3 jobs-to-be-done" — repeating short-text min 1 max 5, showInLight:true; Q7 "Hard constraints worth flagging" — free-text optional, showInLight:false; Q8 "Anti-persona — who is this NOT for?" — single-text optional, showInLight:false.)

- [ ] **Step 5: Author Q9-Q11 (secondaries)**

```markdown
### Persona.Q9 — Secondary personas?

- **type:** single-select
- **options:** ["yes-lean", "no"]
- **showInLight:** false   <!-- secondaries skipped in light mode -->
- **isRiskCapture:** false
- **loopTrigger:** true (when "yes-lean", Q10/Q11 loop up to 3 times)

**Prompt:** "Are there secondary personas worth capturing (lean profile only — name + role + 1-line context)?"

### Persona.Q10 — Secondary name + role (per secondary)

- **type:** short-text
- **showInLight:** false
- **template:** "Secondary persona {iter} of (up to 3) — name + role:"

**Stores to:** `personas.secondary[{iter}].name`, `personas.secondary[{iter}].role`

### Persona.Q11 — Secondary context (per secondary)

- **type:** short-text
- **showInLight:** false
**Stores to:** `personas.secondary[{iter}].context`
```

- [ ] **Step 6: Author Q_RISK (always fires)**

```markdown
### Persona.Q_RISK — Persona-related risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["compliance", "market", "team"]

**Prompt:** "What's the biggest persona-related risk for THIS project? (e.g., 'no persona covers regulator audit access', 'primary persona has high-churn behavior we can't yet measure'.)"

**Stores to:** `risks[]` array (new entry with originatingPhase = "personas", id auto-assigned R-PERSONAS-1)
```

- [ ] **Step 7: Append "Mode/coupling matrix" footer**

```markdown
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
```

- [ ] **Step 8: Verify file shape**

Run: `grep -c "^### Persona\." greenfield/skills/context-gathering/references/personas.q-bank.md`

Expected: `12` (Q1, Q2, Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q10, Q11, Q_RISK).

- [ ] **Step 9: Commit**

```bash
git add greenfield/skills/context-gathering/references/personas.q-bank.md
git commit -m "feat(greenfield): personas Q-bank (12 Qs heavy / 4 light) — Step 2.2"
```

---

### Task 4: Author domain-model.q-bank.md

**Files:**
- Create: `greenfield/skills/context-gathering/references/domain-model.q-bank.md`

- [ ] **Step 1: Author file header**

```markdown
# Domain Modeling Q-bank — Step 2.7

> **Round:** 4 (Discovery phase)
> **Step:** 2.7 (front-load discovery, before dataArchitecture)
> **Modes:** Heavy + Full DDD ~15 Qs / Heavy + DDD-lite ~10 Qs / Light ~5 Qs (Full DDD ignored)
> **Coupling:** Output (entity IDs + aggregate-root flags) consumed by auto-loop in data, api (and security in auto-loop mode)
> **See also:** `personas.q-bank.md`, `inline-risk.q-bank.md`, design spec § Domain Modeling phase

This phase captures domain structure using DDD vocabulary. Full DDD mode = entities + bounded contexts + aggregates + value objects + domain events + ubiquitous language + anti-corruption layers. DDD-lite drops value objects, domain events, and anti-corruption. Light mode collapses bounded contexts to a single default context and drops aggregate distinction.

## Q-bank
```

- [ ] **Step 2: Author Q1 (bounded context list — outer loop trigger)**

```markdown
### Domain.Q1 — Bounded contexts

- **type:** repeating short-text
- **showInLight:** false   <!-- Light: single default context -->
- **isRiskCapture:** false
- **loopTrigger:** true (Q2-Q7 loop per context)
- **min:** 1, **max:** 6

**Prompt:** "List major sub-domains / bounded contexts. Each should have a distinct responsibility (e.g., 'Field-Audit', 'Reporting', 'Identity'). For small CRUD apps, 1 context is fine."

**Stores to:** `domainModel.contexts[].name` (id auto-assigned BC1, BC2…)
```

- [ ] **Step 3: Author Q2-Q3 (per context: name + responsibility, entities)**

```markdown
### Domain.Q2 — Context responsibility (per BC)

- **type:** short-text
- **showInLight:** false
- **template:** "BC{iter} ({context.name}) — one-line responsibility:"

### Domain.Q3 — Entities in this context (per BC)

- **type:** repeating short-text
- **showInLight:** true   <!-- Light: entities still captured -->
- **loopTrigger:** true (Q4-Q5 loop per entity)
- **min:** 1, **max:** 12

**Prompt:** "Entities in {context.name} (e.g., Audit, Finding, Site):"

**Stores to:** `domainModel.entities[]` with contextId = BC{iter}
```

- [ ] **Step 4: Author Q4-Q5 (per entity)**

```markdown
### Domain.Q4 — Aggregate root status (per entity)

- **type:** single-select
- **options:** ["Aggregate root", "Owned by another", "Standalone"]
- **showInLight:** false   <!-- Light collapses to "Standalone" default -->
- **template:** "{entity.id} — aggregate role:"

**Stores to:** `domainModel.entities[entity].isAggregateRoot` (true iff "Aggregate root")

### Domain.Q5 — Relationships (per entity)

- **type:** repeating structured
- **schema:** [{ target: string, kind: enum["has-one","has-many","belongs-to","refs"] }]
- **showInLight:** true   <!-- Light keeps relationships -->
- **template:** "{entity.id} relationships:"
```

- [ ] **Step 5: Author Q6-Q7 (per BC — value objects + domain events)**

```markdown
### Domain.Q6 — Value objects (per BC)

- **type:** repeating short-text
- **showInLight:** false
- **format-gated:** Full DDD only (skipped if `mode.domainFormat=ddd-lite`)
- **examples:** Money, Email, Address, GPSCoordinate

### Domain.Q7 — Domain events (per BC)

- **type:** repeating short-text
- **showInLight:** false
- **format-gated:** Full DDD only
- **examples:** FindingRecorded, AuditCompleted
```

- [ ] **Step 6: Author Q8-Q10 (cross-context, UL, anti-corruption)**

```markdown
### Domain.Q8 — Cross-context relationships

- **type:** repeating structured
- **schema:** [{ from: BC-id, to: BC-id, kind: string }]
- **showInLight:** false
- **examples:** "Field-Audit publishes-events-to Reporting"

### Domain.Q9 — Ubiquitous Language glossary

- **type:** repeating { term, definition }
- **showInLight:** false
- **min:** 3 (per Full DDD), 0 (DDD-lite)

### Domain.Q10 — Anti-corruption layers

- **type:** free-text optional
- **showInLight:** false
- **format-gated:** Full DDD only
- **prompt:** "Any external systems whose vocabulary you refuse to leak in?"
```

- [ ] **Step 7: Author Q_RISK**

```markdown
### Domain.Q_RISK — Domain modeling risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["team", "compliance", "vendor-lock"]

**Prompt:** "What's the biggest domain modeling risk for THIS project?"
**Stores to:** `risks[]` (originatingPhase = "domainModel", id R-DOMAINMODEL-1)
```

- [ ] **Step 8: Append "Mode/format matrix" footer**

```markdown
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
```

- [ ] **Step 9: Verify shape**

Run: `grep -c "^### Domain\." greenfield/skills/context-gathering/references/domain-model.q-bank.md`

Expected: `11` (Q1-Q10 + Q_RISK).

- [ ] **Step 10: Commit**

```bash
git add greenfield/skills/context-gathering/references/domain-model.q-bank.md
git commit -m "feat(greenfield): domain-model Q-bank (15/10/5 Qs by mode) — Step 2.7"
```

---

## Phase C — Q-bank modifications (existing 8 architectural phases)

> **Pattern for Tasks 5-12:** Each existing phase Q-bank file gets:
> 1. A new `Q_RISK` entry appended at the end (free-text, `isRiskCapture: true`, `showInLight: true`)
> 2. Existing Qs tagged with `showInLight: false` for depth-only Qs (depth-only = drops in Light mode)
> 3. Existing Qs that should auto-loop tagged with `loopOver` + `loopMode` (per the coupling matrix in spec § Auto-loop mechanic)
> 4. File header updated to mention Round 4 additions
>
> All 8 tasks follow the same template. Below, Task 5 shows the full template. Tasks 6-12 repeat the pattern with phase-specific values from the coupling matrix.

### Task 5: architectural-framing.q-bank.md — + Q_RISK + showInLight tags (no loops)

**Files:**
- Modify: `greenfield/skills/context-gathering/references/architectural-framing.q-bank.md`

- [ ] **Step 1: Read current file**

Run: `wc -l greenfield/skills/context-gathering/references/architectural-framing.q-bank.md`

Note current line count + Q count (`grep -c "^### "`).

- [ ] **Step 2: Add Round 4 note to header**

Find the first H1 and frontmatter region. Append:

```markdown
> **Round 4 update:** + Q_RISK appended; existing Qs tagged with `showInLight` (default true). No auto-loop — architecturalFraming is a singleton phase.
```

- [ ] **Step 3: Audit + tag `showInLight` on existing Qs**

For architecturalFraming's 4 existing Qs (topology, deploymentShape, scaleTarget, boundaryNotes), all are foundational — keep `showInLight: true` for all. Add the explicit flag to each Q's metadata block.

- [ ] **Step 4: Append Q_RISK at end of file**

```markdown
### ArchFraming.Q_RISK — Architectural framing risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["scaling", "team", "vendor-lock"]

**Prompt:** "What's the biggest architectural framing risk for THIS project? (e.g., 'monolith decision may bottleneck future team growth', 'multi-tenant vs single-tenant choice locked in too early'.)"

**Stores to:** `risks[]` (originatingPhase = "architecturalFraming", id auto-assigned)
```

- [ ] **Step 5: Verify new Q count**

Run: `grep -c "^### " greenfield/skills/context-gathering/references/architectural-framing.q-bank.md`

Expected: previous count + 1.

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/context-gathering/references/architectural-framing.q-bank.md
git commit -m "feat(greenfield): architecturalFraming Q-bank R4 — + Q_RISK + showInLight tags"
```

---

### Task 6: data-architecture.q-bank.md — + Q_RISK + loopOver entity tags + showInLight

**Files:**
- Modify: `greenfield/skills/context-gathering/references/data-architecture.q-bank.md`

- [ ] **Step 1: Read current file**

Run: `wc -l greenfield/skills/context-gathering/references/data-architecture.q-bank.md`

- [ ] **Step 2: Add Round 4 note to header**

```markdown
> **Round 4 update:** + Q_RISK appended; auto-loop tags added per coupling matrix (data.persistence per entity, data.access-pattern per entity — both `loopMode: always`, so they loop in BOTH auto-loop and hybrid coupling modes). depth-only Qs tagged `showInLight: false`.
```

- [ ] **Step 3: Tag existing Qs with `loopOver` per coupling matrix**

Per spec § Coupling matrix:
- `data.persistence` Q (whichever existing Q drives schema/storage decisions per entity) → add `loopOver: domainModel.entities`, `loopMode: always`
- `data.access-pattern` Q (whichever existing Q drives read/write patterns per entity) → add `loopOver: domainModel.entities`, `loopMode: always`

For each tagged Q, prepend a metadata block:

```markdown
- **loopOver:** `domainModel.entities`
- **loopMode:** `always`   <!-- fires in both auto-loop and hybrid -->
- **promptTemplate update:** prefix existing prompt with "For entity {entity.id} ({entity.contextId}):"
```

- [ ] **Step 4: Tag depth-only Qs with `showInLight: false`**

Identify Qs that are "depth" (not foundational schema decisions but elaborations — partitioning, sharding, etc.). Tag with `showInLight: false`.

Target: data Heavy ~12 Qs → Light ~7. So ~5 Qs get `showInLight: false`.

- [ ] **Step 5: Append Q_RISK**

```markdown
### Data.Q_RISK — Data architecture risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["scaling", "dataloss", "vendor-lock", "performance"]

**Prompt:** "What's the biggest data architecture risk for THIS project? (e.g., 'Single Postgres for OLTP+analytics will need split by Y2'.)"

**Stores to:** `risks[]` (originatingPhase = "dataArchitecture")
```

- [ ] **Step 6: Verify**

Run: `grep -c "loopOver:" greenfield/skills/context-gathering/references/data-architecture.q-bank.md`

Expected: `2` (data.persistence + data.access-pattern).

Run: `grep -c "showInLight: false" greenfield/skills/context-gathering/references/data-architecture.q-bank.md`

Expected: ~5 (per Step 4 target).

- [ ] **Step 7: Commit**

```bash
git add greenfield/skills/context-gathering/references/data-architecture.q-bank.md
git commit -m "feat(greenfield): dataArchitecture Q-bank R4 — + Q_RISK + auto-loop entity tags + showInLight"
```

---

### Task 7: api-integration.q-bank.md — + Q_RISK + loopOver entity tags + showInLight

**Files:**
- Modify: `greenfield/skills/context-gathering/references/api-integration.q-bank.md`

- [ ] **Step 1: Read current file**

- [ ] **Step 2: Add Round 4 note to header**

```markdown
> **Round 4 update:** + Q_RISK appended; auto-loop tags added (api.crud-surface per entity `loopMode: always`; api.async-pattern per entity `loopMode: hybrid-only` — fires in auto-loop but NOT in hybrid). depth-only Qs tagged `showInLight: false`.
```

- [ ] **Step 3: Tag `api.crud-surface` Q**

```markdown
- **loopOver:** `domainModel.entities`
- **loopMode:** `always`
- **promptTemplate update:** prefix "For entity {entity.id}:"
```

- [ ] **Step 4: Tag `api.async-pattern` Q**

```markdown
- **loopOver:** `domainModel.entities`
- **loopMode:** `hybrid-only`   <!-- skipped in hybrid mode (fires static once) -->
- **promptTemplate update:** prefix "For entity {entity.id} async pattern:"
```

- [ ] **Step 5: Tag depth-only Qs with `showInLight: false`**

Target: api Heavy ~10 Qs → Light ~6. ~4 Qs get `showInLight: false`.

- [ ] **Step 6: Append Q_RISK**

```markdown
### Api.Q_RISK — API integration risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **tagSuggestions:** ["performance", "vendor-lock", "compliance"]

**Prompt:** "What's the biggest API integration risk for THIS project? (e.g., 'sync REST chosen but two callers really need async').
"
**Stores to:** `risks[]` (originatingPhase = "apiIntegration")
```

- [ ] **Step 7: Verify + commit**

```bash
git add greenfield/skills/context-gathering/references/api-integration.q-bank.md
git commit -m "feat(greenfield): apiIntegration Q-bank R4 — + Q_RISK + auto-loop entity tags + showInLight"
```

---

### Task 8: auth.q-bank.md — + Q_RISK + loopOver persona tags + showInLight

**Files:**
- Modify: `greenfield/skills/context-gathering/references/auth.q-bank.md`

- [ ] **Step 1: Read current file**

- [ ] **Step 2: Add Round 4 note to header**

```markdown
> **Round 4 update:** + Q_RISK appended; `auth.roles` Q tagged `loopOver: personas.primary` with `loopMode: always` (loops in both auto-loop and hybrid). depth-only auth Qs tagged `showInLight: false`.
```

- [ ] **Step 3: Tag `auth.roles` Q (or equivalent role/permission Q)**

```markdown
- **loopOver:** `personas.primary`
- **loopMode:** `always`
- **promptTemplate update:** "For persona {persona.id} ({persona.name}, {persona.role}), what role + permission set fits best?"
- **answerSchema:** { role: string, permissions: [string] }
```

After loop completes, ALSO ask a non-looped "any additional roles?" tail Q (e.g., for system/admin/service roles not bound to a persona).

- [ ] **Step 4: Tag depth-only Qs `showInLight: false`**

Target: auth Heavy ~10 Qs → Light ~5. ~5 Qs (cross-tenant, secondary IdP, deep MFA configuration) get `showInLight: false`.

- [ ] **Step 5: Append Q_RISK**

```markdown
### Auth.Q_RISK — Auth risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **tagSuggestions:** ["security", "compliance"]

**Prompt:** "What's the biggest auth-related risk for THIS project? (e.g., 'JWT-only means revocation latency in compromised-token case'.)"
**Stores to:** `risks[]` (originatingPhase = "auth")
```

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/context-gathering/references/auth.q-bank.md
git commit -m "feat(greenfield): auth Q-bank R4 — + Q_RISK + auto-loop persona tags + showInLight"
```

---

### Task 9: privacy.q-bank.md — + Q_RISK + loopOver persona tags + showInLight

**Files:**
- Modify: `greenfield/skills/context-gathering/references/privacy.q-bank.md`

- [ ] **Step 1: Read current file**

- [ ] **Step 2: Add Round 4 header note** (analogous to Task 8)

- [ ] **Step 3: Tag `privacy.access` Q (data-access-per-persona)**

```markdown
- **loopOver:** `personas.primary`
- **loopMode:** `always`
- **promptTemplate update:** "For persona {persona.id}, what data access scope applies (own-only / org-wide / read-only-cross-org / admin)?"
```

- [ ] **Step 4: Tag depth-only Qs `showInLight: false`**

Target: privacy Heavy ~12 Qs → Light ~6.

- [ ] **Step 5: Append Q_RISK**

```markdown
### Privacy.Q_RISK — Privacy/governance risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **tagSuggestions:** ["compliance", "dataloss"]

**Prompt:** "What's the biggest privacy/governance risk? (e.g., 'storing audit photos creates GDPR-erasure complexity'.)"
```

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/context-gathering/references/privacy.q-bank.md
git commit -m "feat(greenfield): privacy Q-bank R4 — + Q_RISK + auto-loop persona tags + showInLight"
```

---

### Task 10: security.q-bank.md — + Q_RISK + loopOver tags + showInLight

**Files:**
- Modify: `greenfield/skills/context-gathering/references/security.q-bank.md`

- [ ] **Step 1: Read current file**

- [ ] **Step 2: Add Round 4 header note**

```markdown
> **Round 4 update:** + Q_RISK appended; `security.threat-model` Q tagged `loopOver: personas.primary` with `loopMode: hybrid-only` (loops in auto-loop, static once in hybrid); `security.attack-surface` Q tagged `loopOver: domainModel.entities` with `loopMode: hybrid-only`. depth-only Qs tagged `showInLight: false`.
```

- [ ] **Step 3: Tag `security.threat-model` and `security.attack-surface` Qs**

Both with `loopMode: hybrid-only` per coupling matrix.

```markdown
### security.threat-model (existing Q)

- **loopOver:** `personas.primary`
- **loopMode:** `hybrid-only`
- **promptTemplate (auto-loop):** "For persona {persona.id}, what's the dominant attacker-from-persona-context threat?"
- **promptTemplate (hybrid fallback):** "What are the top 3 threat-actor scenarios you're designing against?"

### security.attack-surface (existing Q)

- **loopOver:** `domainModel.entities`
- **loopMode:** `hybrid-only`
- **promptTemplate (auto-loop):** "For entity {entity.id}, what attack surface is exposed?"
- **promptTemplate (hybrid fallback):** "Enumerate the system's primary attack surfaces."
```

- [ ] **Step 4: Tag depth-only Qs `showInLight: false`**

Target: security Heavy ~10 Qs → Light ~5.

- [ ] **Step 5: Append Q_RISK**

```markdown
### Security.Q_RISK — Security risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **tagSuggestions:** ["security"]

**Prompt:** "What's the biggest security risk for THIS project? (e.g., 'WAF deferred to post-launch — first-week exposure'.)"
```

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/context-gathering/references/security.q-bank.md
git commit -m "feat(greenfield): security Q-bank R4 — + Q_RISK + hybrid-only auto-loop tags + showInLight"
```

---

### Task 11: runtime-operations.q-bank.md — + Q_RISK + loopOver persona tags + showInLight

**Files:**
- Modify: `greenfield/skills/context-gathering/references/runtime-operations.q-bank.md`

- [ ] **Step 1: Read current file**

- [ ] **Step 2: Add Round 4 header note** (loopMode: hybrid-only for SLO + alert Qs)

- [ ] **Step 3: Tag `runtimeOps.SLO` Q and `runtimeOps.alert` Q**

```markdown
### runtimeOps.SLO (existing Q)

- **loopOver:** `personas.primary`
- **loopMode:** `hybrid-only`
- **promptTemplate (auto-loop):** "For persona {persona.id}, what SLO target applies (availability, p95 latency)?"
- **promptTemplate (hybrid fallback):** "Define top 3 SLO targets for the system."

### runtimeOps.alert (existing Q)

- **loopOver:** `personas.primary`
- **loopMode:** `hybrid-only`
- **promptTemplate (auto-loop):** "For persona {persona.id}, what alert routing applies?"
- **promptTemplate (hybrid fallback):** "Define alert routing strategy."
```

- [ ] **Step 4: Tag depth-only Qs `showInLight: false`**

Target: runtimeOps Heavy ~14 Qs → Light ~7.

- [ ] **Step 5: Append Q_RISK**

```markdown
### Ops.Q_RISK — Runtime ops risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **tagSuggestions:** ["ops", "scaling"]

**Prompt:** "What's the biggest runtime operations risk? (e.g., 'no on-call rotation defined for first month'.)"
```

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/context-gathering/references/runtime-operations.q-bank.md
git commit -m "feat(greenfield): runtimeOps Q-bank R4 — + Q_RISK + hybrid-only auto-loop tags + showInLight"
```

---

### Task 12: cicd.q-bank.md — + Q_RISK + showInLight (no loops)

**Files:**
- Modify: `greenfield/skills/context-gathering/references/cicd.q-bank.md` (or the file matching the existing R1 CI/CD Q-bank — verify filename first)

- [ ] **Step 1: Verify exact filename**

Run: `ls greenfield/skills/context-gathering/references/ | grep -i cicd`

Use the exact filename returned (could be `cicd.q-bank.md`, `ci-cd.q-bank.md`, or `cicd-delivery.q-bank.md` depending on R1 naming).

- [ ] **Step 2: Add Round 4 header note**

```markdown
> **Round 4 update:** + Q_RISK appended; no auto-loop (CI/CD is pipeline-level, not entity/persona-scoped). depth-only Qs tagged `showInLight: false`.
```

- [ ] **Step 3: Tag depth-only Qs `showInLight: false`**

Target: cicd Heavy 17 Qs → Light ~10. ~7 Qs (env-specific replication, region failover specifics, etc.) get `showInLight: false`.

- [ ] **Step 4: Append Q_RISK**

```markdown
### CICD.Q_RISK — CI/CD risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **tagSuggestions:** ["ops", "scaling", "vendor-lock"]

**Prompt:** "What's the biggest CI/CD risk for THIS project? (e.g., 'single-region deploys, no canary path yet'.)"
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/context-gathering/references/cicd.q-bank.md
git commit -m "feat(greenfield): cicd Q-bank R4 — + Q_RISK + showInLight (no loops)"
```

---

> **🔒 CHECKPOINT after Phase C:** before Phase D template work begins, verify that all 8 modified phase Q-bank files compile cleanly — every `loopOver` references a real source path (`personas.primary` or `domainModel.entities`), every `Q_RISK` has `isRiskCapture: true`. Run:
>
> ```bash
> grep -rE "loopOver:" greenfield/skills/context-gathering/references/ | grep -vE "(personas\.primary|domainModel\.entities|domainModel\.aggregates)"
> ```
>
> Expected: no output. Any output = invalid loopOver path; fix before proceeding.

---

## Phase D — Synthesis templates

### Task 13: personas synthesis HTML + MD + dependencies example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/personas.html`
- Create: `greenfield/skills/synthesis-review/references/templates/personas.md`
- Create: `greenfield/skills/synthesis-review/references/templates/personas-dependencies.json.example`

- [ ] **Step 1: Inspect existing template shape**

Run: `head -40 greenfield/skills/synthesis-review/references/templates/auth.html`

Note: HTML5 structure, `{{placeholder}}` Mustache-like syntax, section structure with `<h2>` headers.

- [ ] **Step 2: Author personas.html**

Six sections per design spec § Personas synthesis HTML:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Personas — {{project.name}}</title>
  <link rel="stylesheet" href="synthesis-base.css">
</head>
<body>
  <header>
    <h1>Personas</h1>
    <p class="meta">Phase 2.2 — captured {{captured.at}} — Round 4</p>
  </header>

  <section id="mode">
    <h2>1. Mode + Coupling</h2>
    <p>Coupling: <strong>{{mode.coupling}}</strong> | Depth: <strong>{{mode.depth}}</strong></p>
  </section>

  <section id="primary">
    <h2>2. Primary Personas</h2>
    {{#each personas.primary}}
    <article class="persona">
      <h3>[{{this.id}}] {{this.name}} — {{this.role}}</h3>
      <p class="goal">Goal: {{this.goal}}</p>
      {{#if this.context}}<p class="context">Context: {{this.context.device}} / {{this.context.connection}} / {{this.context.techSophistication}}</p>{{/if}}
      {{#if this.jobs}}<ul class="jobs">{{#each this.jobs}}<li>[{{this.id}}] {{this.story}}</li>{{/each}}</ul>{{/if}}
      {{#if this.constraints}}<p class="constraint">Constraint: {{this.constraints}}</p>{{/if}}
    </article>
    {{/each}}
  </section>

  <section id="secondary">
    <h2>3. Secondary Personas</h2>
    {{#each personas.secondary}}
    <p>[{{this.id}}-lean] {{this.name}} ({{this.role}}) — {{this.context}}</p>
    {{/each}}
  </section>

  <section id="anti">
    <h2>4. Anti-Personas</h2>
    <ul>
    {{#each personas.antiPersonas}}<li>Not for: {{this}}</li>{{/each}}
    </ul>
  </section>

  <section id="risks">
    <h2>5. Persona Risks Identified</h2>
    {{#each risks}}
      {{#if (eq this.originatingPhase "personas")}}
      <p>• {{this.text}}</p>
      {{/if}}
    {{/each}}
  </section>

  <section id="downstream">
    <h2>6. Decisions Driven Downstream</h2>
    <p class="back-fill-note">{{#unless downstreamTraces}}This section back-fills after downstream phases complete and run synthesis-review.{{/unless}}</p>
    {{#each downstreamTraces}}
    <p>→ {{this.phase}}.{{this.path}}: {{this.summary}}</p>
    {{/each}}
  </section>

  <footer>
    <p>Round 4 — alpha.5 — generated by greenfield/synthesis-review</p>
  </footer>
</body>
</html>
```

- [ ] **Step 3: Author personas.md (markdown companion)**

Mirror the HTML's 6 sections in markdown. Used for terminal/preview rendering.

```markdown
# Personas — {{project.name}}

> Phase 2.2 — captured {{captured.at}} — Round 4

## 1. Mode + Coupling

Coupling: **{{mode.coupling}}** | Depth: **{{mode.depth}}**

## 2. Primary Personas

{{#each personas.primary}}
### [{{this.id}}] {{this.name}} — {{this.role}}

- **Goal:** {{this.goal}}
{{#if this.context}}- **Context:** {{this.context.device}} / {{this.context.connection}} / {{this.context.techSophistication}}{{/if}}
{{#if this.jobs}}- **Jobs:**
{{#each this.jobs}}  - [{{this.id}}] {{this.story}}
{{/each}}
{{/if}}
{{#if this.constraints}}- **Constraint:** {{this.constraints}}{{/if}}

{{/each}}

## 3. Secondary Personas

{{#each personas.secondary}}
- [{{this.id}}-lean] {{this.name}} ({{this.role}}) — {{this.context}}
{{/each}}

## 4. Anti-Personas

{{#each personas.antiPersonas}}
- Not for: {{this}}
{{/each}}

## 5. Persona Risks Identified

{{#each risks}}
{{#if (eq this.originatingPhase "personas")}}
- {{this.text}}
{{/if}}
{{/each}}

## 6. Decisions Driven Downstream

{{#unless downstreamTraces}}*This section back-fills after downstream phases complete and run synthesis-review.*{{/unless}}

{{#each downstreamTraces}}
- → {{this.phase}}.{{this.path}}: {{this.summary}}
{{/each}}
```

- [ ] **Step 4: Author personas-dependencies.json.example**

```jsonc
{
  "schemaVersion": "2.0",
  "phase": "personas",
  "recordedAt": "2026-05-15T10:00:00Z",
  "dependencies": [
    {
      "path": "personas.primary[*].id",
      "value": ["P1", "P2"],
      "rationale": "Persona IDs referenced by auto-looped downstream phases (auth, privacy, frontend)"
    },
    {
      "path": "personas.primary[*].context.connection",
      "value": ["spotty", "strong-wifi"],
      "rationale": "Drives offline-first architecture decision in dataArchitecture + apiIntegration"
    },
    {
      "path": "personas.primary[*].techSophistication",
      "value": ["Basic", "Power user"],
      "rationale": "Drives UI complexity decisions in frontend phase (Round 6 consumer)"
    },
    {
      "path": "personas.antiPersonas",
      "value": ["desktop-bound compliance officers", "external API consumers"],
      "rationale": "Excluded from auth, privacy, and frontend scope"
    }
  ]
}
```

- [ ] **Step 5: Verify HTML+MD section parity**

Run: `grep -c "^<section" greenfield/skills/synthesis-review/references/templates/personas.html`

Expected: `6`.

Run: `grep -c "^## " greenfield/skills/synthesis-review/references/templates/personas.md`

Expected: `6`.

- [ ] **Step 6: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/personas.html \
        greenfield/skills/synthesis-review/references/templates/personas.md \
        greenfield/skills/synthesis-review/references/templates/personas-dependencies.json.example
git commit -m "feat(greenfield): personas synthesis templates (HTML + MD + deps example)"
```

---

### Task 14: domain-model synthesis HTML + MD + dependencies example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/domain-model.html`
- Create: `greenfield/skills/synthesis-review/references/templates/domain-model.md`
- Create: `greenfield/skills/synthesis-review/references/templates/domain-model-dependencies.json.example`

- [ ] **Step 1: Author domain-model.html (10 sections per design spec)**

Sections: Mode+Coupling; Bounded Contexts; Entities per Context (with aggregate marks); Value Objects; Domain Events; Cross-Context Relationships; Ubiquitous Language; Anti-Corruption Layers; Domain Risks Identified; Decisions Driven Downstream.

Use the same Mustache template pattern as personas.html. Render aggregate-root entities with a "⊕" symbol prefix; render owned entities with "↳" indentation; render standalone entities flat.

For DDD-lite mode, sections 4 (Value Objects), 5 (Domain Events), 8 (Anti-Corruption Layers) render as `(deferred — DDD-lite mode)` placeholders.

For Light mode, sections 4, 5, 6, 7, 8 ALL render as placeholders.

- [ ] **Step 2: Author domain-model.md**

10 sections mirroring the HTML. Use the same templating + mode-gated placeholder strings.

- [ ] **Step 3: Author domain-model-dependencies.json.example**

```jsonc
{
  "schemaVersion": "2.0",
  "phase": "domainModel",
  "recordedAt": "2026-05-15T10:30:00Z",
  "dependencies": [
    {
      "path": "domainModel.contexts[*].id",
      "value": ["BC1", "BC2", "BC3"],
      "rationale": "Bounded context IDs partition data + api surface"
    },
    {
      "path": "domainModel.entities[*].id",
      "value": ["Audit", "Finding", "Site", "Report", "AggregateFinding"],
      "rationale": "Entity list drives auto-loop in data + api phases"
    },
    {
      "path": "domainModel.entities[*].isAggregateRoot",
      "value": [
        { "id": "Audit", "root": true },
        { "id": "Finding", "root": false },
        { "id": "Site", "root": false },
        { "id": "Report", "root": true },
        { "id": "AggregateFinding", "root": false }
      ],
      "rationale": "Aggregate roots become repository boundaries in data phase"
    }
  ]
}
```

- [ ] **Step 4: Verify**

Run: `grep -c "^<section" greenfield/skills/synthesis-review/references/templates/domain-model.html`

Expected: `10`.

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/domain-model.html \
        greenfield/skills/synthesis-review/references/templates/domain-model.md \
        greenfield/skills/synthesis-review/references/templates/domain-model-dependencies.json.example
git commit -m "feat(greenfield): domain-model synthesis templates (HTML + MD + deps example)"
```

---

### Task 15: Risk Reconciliation section + shared risks.dependencies.json example

**Files:**
- Create: `greenfield/skills/synthesis-review/references/templates/arch-val-risk-reconciliation-section.html`
- Create: `greenfield/skills/synthesis-review/references/templates/risks-dependencies.json.example`

- [ ] **Step 1: Author arch-val-risk-reconciliation-section.html**

This is a PARTIAL template (not a full HTML document) — it gets inserted as a new front section inside the existing `architectural-validation.html` template.

```html
<section id="risk-reconciliation">
  <h2>1. Risk Reconciliation</h2>
  <p class="meta">{{risks.length}} risks captured across {{distinct(risks.originatingPhase).length}} phases.</p>

  <h3>Mitigated ({{risks | filter(r => r.reconciliation.status == "mitigated") | length}})</h3>
  <ul>
  {{#each risks}}{{#if (eq this.reconciliation.status "mitigated")}}
    <li>{{this.originatingPhase}}.Q_RISK → "{{this.reconciliation.rationale}}"</li>
  {{/if}}{{/each}}
  </ul>

  <h3>Partial ({{risks | filter(r => r.reconciliation.status == "partial") | length}})</h3>
  <ul>{{#each risks}}{{#if (eq this.reconciliation.status "partial")}}<li>{{this.originatingPhase}}.Q_RISK → "{{this.reconciliation.rationale}}"</li>{{/if}}{{/each}}</ul>

  <h3>Accepted-explicit ({{risks | filter(...) | length}})</h3>
  <ul>{{#each risks}}{{#if (eq this.reconciliation.status "accepted-explicit")}}<li>{{this.originatingPhase}}.Q_RISK → "{{this.reconciliation.rationale}}"</li>{{/if}}{{/each}}</ul>

  <h3>Open / Needs followup ({{risks | filter(...) | length}})</h3>
  <ul>{{#each risks}}{{#if (eq this.reconciliation.status "open-followup")}}<li>{{this.originatingPhase}}.Q_RISK → "{{this.text}}" (recommended followup: {{this.reconciliation.rationale}})</li>{{/if}}{{/each}}</ul>

  <h3>Out-of-scope ({{risks | filter(...) | length}})</h3>
  <ul>{{#each risks}}{{#if (eq this.reconciliation.status "out-of-scope")}}<li>{{this.originatingPhase}}.Q_RISK</li>{{/if}}{{/each}}</ul>

  <h3>Top followups (→ feature-list.json risk-followup cards)</h3>
  <ul>
  {{#each phases.architecturalValidation.riskReconciliation.topFollowups}}
    <li>{{lookup_risk_text(this)}}</li>
  {{/each}}
  </ul>
</section>
```

- [ ] **Step 2: Author risks-dependencies.json.example**

```jsonc
{
  "schemaVersion": "2.0",
  "phase": "risks",
  "recordedAt": "2026-05-15T11:00:00Z",
  "risks": [
    {
      "id": "R-DATA-1",
      "originatingPhase": "dataArchitecture",
      "text": "Single Postgres for OLTP+analytics will need split by Y2",
      "tags": ["scaling"],
      "reconciliation": {
        "status": "mitigated",
        "rationale": "Adopted read-replica plan in apiIntegration.Q3"
      }
    },
    {
      "id": "R-AUTH-1",
      "originatingPhase": "auth",
      "text": "JWT-only means revocation latency in compromised-token case",
      "tags": ["security"],
      "reconciliation": {
        "status": "partial",
        "rationale": "Short JWT TTL adopted; explicit revocation deferred to Sprint 3"
      }
    },
    {
      "id": "R-PERSONAS-1",
      "originatingPhase": "personas",
      "text": "No persona covers regulator audit access",
      "tags": ["compliance"],
      "reconciliation": {
        "status": "open-followup",
        "rationale": "Add regulator persona in v2; defer corresponding auth role"
      }
    }
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/synthesis-review/references/templates/arch-val-risk-reconciliation-section.html \
        greenfield/skills/synthesis-review/references/templates/risks-dependencies.json.example
git commit -m "feat(greenfield): risk reconciliation section template + shared risks deps example"
```

---

### Task 16: Shared inline-risk Q-bank doc + section-prompts.md additions

**Files:**
- Create: `greenfield/skills/context-gathering/references/inline-risk.q-bank.md`
- Modify: `greenfield/skills/synthesis-review/references/section-prompts.md`

- [ ] **Step 1: Author inline-risk.q-bank.md**

```markdown
# Inline Risk Q-bank — Cross-cutting (Round 4)

> **Round:** 4 (cross-cutting)
> **Scope:** 10 inline `Q_RISK` entries — 8 architectural phases (architecturalFraming, dataArchitecture, apiIntegration, auth, privacy, security, runtimeOperations, cicdAndDelivery) + 2 discovery phases (personas, domainModel).
> **Pattern:** identical shape; phase-specific prompt + tagSuggestions.
> **Mode:** always fires in both Heavy and Light modes (`showInLight: true`)
> **Persists to:** shared `risks[]` array + each phase's synthesis HTML "Risks Identified" section
> **Reconciled at:** Step 15 Architectural Validation — Risk Reconciliation section

## Shared template

```yaml
{phaseName}.Q_RISK:
  type: free-text
  required: true
  showInLight: true
  isRiskCapture: true       # ← state-machine flag: append to risks[] array
  feedsIntoConsolidation: true
  prompt: "What's the biggest {phaseName} risk for THIS project?"
  charLimit: { min: 10, max: 500 }
  tagSuggestions:
    # phase-specific — see per-phase table below
```

## Per-phase tag suggestions

| Phase | Q_RISK ID | tagSuggestions |
|---|---|---|
| personas | `Persona.Q_RISK` | compliance, market, team |
| domainModel | `Domain.Q_RISK` | team, compliance, vendor-lock |
| architecturalFraming | `ArchFraming.Q_RISK` | scaling, team, vendor-lock |
| dataArchitecture | `Data.Q_RISK` | scaling, dataloss, vendor-lock, performance |
| apiIntegration | `Api.Q_RISK` | performance, vendor-lock, compliance |
| auth | `Auth.Q_RISK` | security, compliance |
| privacy | `Privacy.Q_RISK` | compliance, dataloss |
| security | `Security.Q_RISK` | security |
| runtimeOperations | `Ops.Q_RISK` | ops, scaling |
| cicdAndDelivery | `CICD.Q_RISK` | ops, scaling, vendor-lock |

## State machine behavior

When user answers a `Q_RISK`, the wizard:
1. Generates a new id: `R-{PHASE-UPPERCASE}-{counter}` (e.g., `R-DATA-1`)
2. Appends entry to `context.risks[]` with `originatingPhase`, `text`, optional `tags[]`, and empty `reconciliation` block
3. Renders the risk in the phase's synthesis HTML "Risks Identified" section (if synthesis-review runs)
4. At Step 15 Architectural Validation, loops over all risks and asks the reconciliation Q per risk

## Edge cases

- If user answers "no risk" / "none" / similar negative: tag as `risks[].reconciliation.status = "user-declared-none"` proactively. Reconciliation step will surface count: "3 phases declared no risk — confirm?"
- If two phases produce semantically-similar risks (similarity > 0.8): wizard offers to merge at start of Reconciliation. User can decline.
```

- [ ] **Step 2: Add section-prompts entries for Personas + Domain**

Append to `greenfield/skills/synthesis-review/references/section-prompts.md`:

```markdown
## personas — Section prompts

| Section | Title | Approve/Adjust/Skip prompt |
|---|---|---|
| 1 | Mode + Decisions | "Mode toggle values look right?" |
| 2 | Primary Personas | "Primary personas accurately captured?" |
| 3 | Secondary Personas | "Secondary personas captured if applicable?" |
| 4 | Anti-Personas | "Anti-personas correctly excluded?" |
| 5 | Persona Risks Identified | "Persona-related risk recorded?" |
| 6 | Decisions Driven Downstream | (auto, back-fills after downstream phases — no user prompt at this stage) |

## domainModel — Section prompts

| Section | Title | Approve/Adjust/Skip prompt |
|---|---|---|
| 1 | Mode + Coupling | "Format + coupling values look right?" |
| 2 | Bounded Contexts | "Bounded contexts capture the major sub-domains?" |
| 3 | Entities per Context | "Entities + relationships + aggregate roots accurate?" |
| 4 | Value Objects | "Value objects captured?" (skipped in DDD-lite) |
| 5 | Domain Events | "Domain events captured?" (skipped in DDD-lite) |
| 6 | Cross-Context Relationships | "Cross-context relationships captured?" |
| 7 | Ubiquitous Language | "Glossary terms agree with how the team speaks?" |
| 8 | Anti-Corruption Layers | "Boundary translations identified?" (skipped in DDD-lite) |
| 9 | Domain Risks Identified | "Domain risk recorded?" |
| 10 | Decisions Driven Downstream | (auto, back-fills) |
```

- [ ] **Step 3: Commit**

```bash
git add greenfield/skills/context-gathering/references/inline-risk.q-bank.md \
        greenfield/skills/synthesis-review/references/section-prompts.md
git commit -m "feat(greenfield): inline-risk Q-bank doc + section-prompts for personas + domain"
```

---

> **🔒 CHECKPOINT after Phase D:** before Phase E state machine work, verify template variable names match Q-bank answer-schema field names. Spot-check via:
>
> ```bash
> # Personas HTML uses {{this.id}}, {{this.name}}, {{this.role}}, {{this.goal}}, {{this.context.connection}}, {{this.jobs}}
> # Personas Q-bank stores to: personas.primary[].id, .name, .role, .goal, .context.connection, .jobs
> grep -oE '{{[^}]+}}' greenfield/skills/synthesis-review/references/templates/personas.html | sort -u
> grep -oE 'Stores to:.*' greenfield/skills/context-gathering/references/personas.q-bank.md
> ```
>
> Manually verify the two lists align. Any mismatch = template will render `(undefined)` placeholders. Fix before state machine wiring.

---

## Phase E — State machine + skill updates

### Task 17: context-gathering/SKILL.md — Step 1 mode toggles + Steps 2.2 & 2.7 + auto-loop state machine

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md`

- [ ] **Step 1: Read current state-machine table**

Run: `grep -A2 "^## State" greenfield/skills/context-gathering/SKILL.md | head -30`

Note the existing step format.

- [ ] **Step 2: Add Step 1 mode-toggle prompts**

Find Step 1. Append a new sub-section "1.1 Mode toggles":

```markdown
### Step 1.1 — Mode toggles

After intro narration, ask three single-AskUserQuestion calls (one combined batched call preferred — see ask-user-question-guard rule):

**Question 1: Depth**

```
"Wizard depth — comprehensive or stripped-down?"
  • Heavy (default) — ~120 Qs total, comprehensive for production projects
  • Light            — ~65 Qs total, stripped for prototypes/spike work
```

Persist as `mode.depth`.

**Question 2: Coupling**

```
"Coupling between discovery (personas/domain) and architecture — tight or loose?"
  • Auto-loop (default) — every downstream phase iterates per persona AND per entity
  • Hybrid              — only auth/privacy/frontend loop personas; data/api loop entities; security/runtimeOps don't loop
```

Persist as `mode.coupling`.

**Question 3: Domain format**

```
"Domain modeling depth — full DDD or lite?"
  • Full DDD (default) — entities + contexts + aggregates + value objects + domain events + UL
  • DDD-lite            — drops value objects, domain events, anti-corruption
```

Persist as `mode.domainFormat`.

> **Adjacent runaway guard:** if user picks Heavy + Full DDD + Auto-loop AND project description suggests hobby/prototype work (length-of-description < 200 chars or contains "weekend"/"learning"/"toy"), surface ONE-TIME prompt: "Switch to Light + DDD-lite + Hybrid?" before continuing.
```

- [ ] **Step 3: Insert Step 2.2 (Personas)**

Insert a new state-machine row between Step 2 (vision/scope) and Step 2.5 (architecturalFraming):

```markdown
### Step 2.2 — Personas

- **Q-bank:** `personas.q-bank.md` (12 Qs heavy / 4 light)
- **Loop structure:** Q1 sets primary count → Q2-Q8 loop per primary persona → Q9 optional secondaries → Q10-Q11 loop per secondary → Q_RISK
- **Skip path:** if user picks "Skip phase — capture anti-personas only", set `personas.skipped: true` and jump to Q_RISK
- **On completion:**
  1. Write `docs/adr/personas.html` + `personas.md` via synthesis-review
  2. Write `docs/adr/personas.dependencies.json`
  3. Append `Persona.Q_RISK` answer to `risks[]` array (id `R-PERSONAS-1`)
  4. Checkpoint state to `greenfield-state.json`
- **State machine constraint:** auto-loop downstream phases (Step 5+) MUST observe `personas.primary[]` length when iterating
```

- [ ] **Step 4: Insert Step 2.7 (Domain Modeling)**

Insert between Step 2.5 (architecturalFraming) and Step 3 (dataArchitecture):

```markdown
### Step 2.7 — Domain Modeling

- **Q-bank:** `domain-model.q-bank.md` (15 Qs heavy + Full DDD / 10 DDD-lite / 5 Light)
- **Loop structure:** Q1 sets bounded-context list → Q2-Q7 loop per BC (Q3 nested-loops per entity for Q4-Q5) → Q8-Q10 cross-cutting → Q_RISK
- **Mode-gated Qs:** Q6 (value objects), Q7 (domain events), Q10 (anti-corruption) skip if `mode.domainFormat == "ddd-lite"` OR `mode.depth == "light"`
- **On completion:**
  1. Write `docs/adr/domain-model.html` + `domain-model.md`
  2. Write `docs/adr/domain-model.dependencies.json`
  3. Append `Domain.Q_RISK` answer to `risks[]` (id `R-DOMAINMODEL-1`)
  4. Checkpoint state
- **State machine constraint:** auto-loop downstream phases (Step 3+) MUST observe `domainModel.entities[]` length
```

- [ ] **Step 5: Add auto-loop state machine logic**

Add a new "## Auto-loop mechanic" section after the state-machine table:

```markdown
## Auto-loop mechanic

For each Q-bank entry Q being asked:

1. If Q lacks `loopOver`: fire Q once (static). Move to next Q.
2. If Q has `loopOver` (e.g., `personas.primary` or `domainModel.entities`):
   - Read `mode.coupling` from state
   - If `mode.coupling == "auto-loop"`: fire Q once per item in the source array
   - If `mode.coupling == "hybrid"`:
     - If `Q.loopMode == "always"`: fire Q once per item (still loops)
     - Else (Q.loopMode `hybrid-only` or omitted): fire Q ONCE as static; user types free-form
3. For each looped fire, set context variable `{{persona}}` or `{{entity}}` to the iteration item; render Q.promptTemplate with that variable.
4. For each looped answer, write a `derivedFrom` field to the synthesis output AND a `sourceRef` field to the dependencies.json sidecar.

### Loop progress indicator

When firing a looped Q, render UI header:

```
─────────────────────────────────────────
  Step 5 — Auth         [Persona 1 of 2]
─────────────────────────────────────────
```

After last iteration of a loop, the state machine checkpoints state (`.greenfield-state.json`) so `/greenfield:pickup` can resume mid-loop precisely.

### Loop hard-cap

If a single phase's loop iteration count > 200 Qs (e.g., 5 personas × 6 entities × 8 looped Qs = 240), wizard surfaces "Consolidate — you may have too many personas/entities" before continuing. Logs `degradation: { phase, reason }` to state file.
```

- [ ] **Step 6: Update wizard step count**

Search for "Step X of 15" and replace with "Step X of 17" (preserve existing X numbers; the new Steps 2.2 and 2.7 use decimal numbers so 15 → 17 reflects "two extra major steps").

```bash
grep -n "of 15" greenfield/skills/context-gathering/SKILL.md
```

For each match, update to "of 17".

- [ ] **Step 7: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "feat(greenfield): context-gathering R4 — mode toggles, Step 2.2/2.7, auto-loop state machine"
```

---

### Task 18: context-gathering renumber + progress indicators

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md` (continue)

- [ ] **Step 1: Search for remaining "of 15" references**

```bash
grep -rn "of 15" greenfield/skills/
```

Update each to "of 17".

- [ ] **Step 2: Search for "15 steps" / "15-step" references**

```bash
grep -rn "15 step\|15-step\|wizard.*15\|fifteen step" greenfield/
```

Update each to "17 step".

- [ ] **Step 3: Update `## Wizard flow` diagram if present**

Find any ASCII diagrams showing wizard step ordering. Insert Step 2.2 (Personas) between Step 2 and Step 2.5, and Step 2.7 (Domain) between Step 2.5 and Step 3.

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md
git commit -m "refactor(greenfield): renumber progress indicators 15 → 17 for R4"
```

---

### Task 19: synthesis-review/SKILL.md — handle 2 new templates + sourceRef rendering + back-fill section 6

**Files:**
- Modify: `greenfield/skills/synthesis-review/SKILL.md`

- [ ] **Step 1: Read current template-handling table**

Run: `grep -A2 "^## Templates\|^## Supported phases" greenfield/skills/synthesis-review/SKILL.md | head -30`

- [ ] **Step 2: Add personas + domain-model rows to the template table**

Find the table listing supported phases. Add:

```markdown
| personas | `personas.html` + `personas.md` + `personas-dependencies.json.example` | 6 sections; Section 6 back-fills after downstream phases |
| domainModel | `domain-model.html` + `domain-model.md` + `domain-model-dependencies.json.example` | 10 sections; sections 4/5/8 mode-gated; Section 10 back-fills |
```

- [ ] **Step 3: Add `sourceRef` rendering rule**

Add a new "## sourceRef rendering" section:

```markdown
## sourceRef rendering (Round 4)

When a synthesis HTML section displays an answer that has a `sourceRef` in its dependencies.json sidecar:

- Render `sourceRef.phase`.`sourceRef.id` as a small visual link/badge next to the value (e.g., "FieldAuditor [from P1]")
- In MD companion, render as " (from {{sourceRef.phase}}/{{sourceRef.id}})"

Example (auth.html — auto-loop produced):

```html
<tr>
  <td>FieldAuditor</td>
  <td class="ref">[from <a href="personas.html#P1">P1</a>]</td>
</tr>
```

Markdown rendering:

```
- FieldAuditor (from personas/P1)
```
```

- [ ] **Step 4: Add back-fill mechanic for "Decisions Driven Downstream" section**

Add a new "## Back-fill mechanic" section:

```markdown
## Back-fill mechanic (Round 4)

Two synthesis HTMLs have a "Decisions Driven Downstream" section that is initially empty:

- `personas.html` Section 6
- `domain-model.html` Section 10

These sections back-fill after downstream phases complete and run their own synthesis-review. The freshness hook detects when a downstream phase has been Approved AND it has `sourceRef.phase == "personas"` (or `"domainModel"`) in its dependencies — at that point, the back-fill writer:

1. Reads all downstream synthesis HTMLs' dependencies.json sidecars
2. Filters for `sourceRef.phase == "personas"` (resp. "domainModel")
3. Aggregates into the back-fill section, grouped by downstream phase
4. Re-renders the personas.html (resp. domain-model.html) preserving all other sections' Approved state

Trigger: invoke `back-fill-downstream-section.sh` after any downstream phase Approval. (Script to be added in Task 22.)
```

- [ ] **Step 5: Commit**

```bash
git add greenfield/skills/synthesis-review/SKILL.md
git commit -m "feat(greenfield): synthesis-review R4 — personas + domain templates, sourceRef rendering, back-fill"
```

---

### Task 20: start/SKILL.md — Step 1 toggle UX

**Files:**
- Modify: `greenfield/skills/start/SKILL.md`

- [ ] **Step 1: Read current Step 1 description**

- [ ] **Step 2: Update Step 1 to invoke the 3 mode toggles**

Find the Step 1 narration section. Add:

```markdown
After intro narration, run the 3 mode-toggle AskUserQuestion calls (see context-gathering/SKILL.md § Step 1.1):

1. Depth: Heavy (default) or Light
2. Coupling: Auto-loop (default) or Hybrid
3. Domain format: Full DDD (default) or DDD-lite

Persist values to `.claude/greenfield-state.json.mode.*`. Surface chosen values back to user as confirmation: "Wizard configured: Heavy depth, Auto-loop coupling, Full DDD domain. Press Enter to continue."

The defaults reflect a comprehensive-by-default posture. Users wanting prototypes/MVPs should flip ALL three toggles. The wizard surfaces a one-time guidance prompt at the start of Step 2 (vision/scope) if Heavy+FullDDD+AutoLoop is chosen AND the project description hints at prototype scale.
```

- [ ] **Step 3: Update wizard-overview text**

If start/SKILL.md has a wizard-overview section, update "15 steps" → "17 steps" and add 2.2 (Personas) + 2.7 (Domain) to the step listing.

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/start/SKILL.md
git commit -m "feat(greenfield): start R4 — Step 1 mode toggle UX"
```

---

### Task 21: pickup/SKILL.md — mid-wizard mode switch + state migration

**Files:**
- Modify: `greenfield/skills/pickup/SKILL.md`

- [ ] **Step 1: Add "Adjust mode" entry point**

Add a new section "## Adjust mode (mid-wizard mode switch)":

```markdown
## Adjust mode (mid-wizard mode switch)

If the user wants to change `mode.depth`, `mode.coupling`, or `mode.domainFormat` after the wizard has started, present the AskUserQuestion: "Which mode field to adjust?"

For each adjustment:
- If depth Light → Heavy: queue all `showInLight: false` Qs from completed phases as "pending"
- If depth Heavy → Light: existing Heavy-only answers preserved (but flagged "may not appear in synthesis HTML rendering" — synthesis re-render hides them)
- If coupling Auto-loop → Hybrid: existing auto-loop answers preserved; new looped Qs (from now on) follow hybrid rule
- If coupling Hybrid → Auto-loop: any existing static answers for `loopMode: hybrid-only` Qs trigger "want to re-ask per persona/entity?" confirmation
- If domainFormat changes: domain phase Qs re-asked from Q6 onward if upgrading lite → full; existing Full DDD answers preserved on downgrade

All adjustments checkpoint state. Adjustment log appended to `.claude/greenfield-meta.json.audit[]`.
```

- [ ] **Step 2: Add post-hoc persona/entity add detection**

Add a new section "## Persona/entity post-hoc add detection":

```markdown
## Persona/entity post-hoc add detection (Round 4)

On pickup, check the integrity of auto-loop downstream answers:

1. Count current `personas.primary[]` length
2. Compare to the persona-loop count recorded in each downstream phase's metadata
3. If lengths differ (user added/removed a persona mid-wizard or via /greenfield:pickup → Adjust mode):
   - For each downstream phase that auto-looped, flag synthesis HTML as stale
   - Offer: "Add follow-up Qs for new persona, or detach stale answers?"
4. Same check for `domainModel.entities[]` length vs downstream entity loops

Repeats for both personas and domain entities on every pickup.
```

- [ ] **Step 3: Add state migration shim (alpha.4 → alpha.5)**

Add a new section "## State migration: alpha.4 → alpha.5":

```markdown
## State migration: alpha.4 → alpha.5 (Round 4)

On pickup, read `.claude/greenfield-state.json.schemaVersion`. If `alpha.4`:

1. Set `mode.depth = "heavy"` (preserve comprehensive default)
2. Set `mode.coupling = "hybrid"` (SAFER default for in-flight sessions — avoid retroactively expanding all completed phases by persona/entity loops)
3. Set `mode.domainFormat = "ddd-lite"` (lighter — user can upgrade explicitly)
4. Mark personas + domain phases as `status: "not-yet-run"` (will run on next phase advance or via Adjust mode)
5. Initialize `risks[]` as empty array
6. Initialize `phases.architecturalValidation.riskReconciliation` as empty
7. Bump `state.schemaVersion` → `"alpha.5"`
8. Append to `.claude/greenfield-meta.json.audit[]`: `{ at: now, action: "alpha-4-to-alpha-5-migration", details: { mode-defaults-set: {...} } }`
9. Surface to user: "Round 4 added Personas + Domain phases. Resume current step, or run new phases retroactively via /greenfield:pickup → Add R4 phases?"

The migration is non-destructive — all existing R1-R3 state is preserved.
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/pickup/SKILL.md
git commit -m "feat(greenfield): pickup R4 — mode switch + persona/entity add detection + state migration shim"
```

---

### Task 22: check/SKILL.md + tooling-generation/SKILL.md — health check + onboard pass-through + back-fill script

**Files:**
- Modify: `greenfield/skills/check/SKILL.md`
- Modify: `greenfield/skills/tooling-generation/SKILL.md`
- Create: `greenfield/scripts/back-fill-downstream-section.sh`

- [ ] **Step 1: Update check/SKILL.md verifications**

Find the health-check checklist. Add:

```markdown
- [ ] If `mode.depth` set in state, verify `.claude/greenfield-state.json.mode` exists and matches expected schema
- [ ] If `personas.skipped` is not true, verify `docs/adr/personas.html` exists; if missing, flag "Personas synthesis not generated"
- [ ] If `domainModel.deferred` is not true, verify `docs/adr/domain-model.html` exists; if missing, flag "Domain synthesis not generated"
- [ ] Verify `docs/adr/risks.dependencies.json` exists if at least one phase has been completed; expected length `risks[].length >= phases-completed`
- [ ] If `mode.coupling == auto-loop`, verify at least one downstream synthesis HTML has `sourceRef` annotations (otherwise auto-loop ran but didn't trace)
```

- [ ] **Step 2: Update tooling-generation/SKILL.md**

Add personas + domainModel + risks to the onboard pass-through:

```markdown
## Round 4 — pass new phases to onboard

In the enriched context passed to `/onboard:generate`, include:

```jsonc
{
  // ... existing R3 fields
  "phases": {
    // ... existing R3 phases (architecturalFraming, dataArchitecture, etc.)
    "personas": { /* full personas block from greenfield-state.json */ },
    "domainModel": { /* full domain model block */ }
  },
  "risks": [ /* full risks array */ ],
  "mode": { /* depth, coupling, domainFormat */ }
}
```

Onboard 2.0 alpha.5+ treats these as optional — if absent, behaves as alpha.4. Greenfield always sends them when present.
```

- [ ] **Step 3: Create back-fill-downstream-section.sh stub**

```bash
#!/usr/bin/env bash
# back-fill-downstream-section.sh — re-render personas.html or domain-model.html with
# "Decisions Driven Downstream" section populated from downstream sourceRef dependencies.
#
# Invoked after any downstream phase Approval (called by synthesis-review SKILL.md).
#
# Args:
#   $1 — phase to back-fill ("personas" | "domainModel")
#   $2 — project root path

set -euo pipefail

PHASE="${1:?phase required (personas|domainModel)}"
PROJECT_ROOT="${2:?project root required}"

# Logical steps (to be wired into the synthesis-review flow on next iteration):
# 1. Find all downstream phase dependency files via:
#      find "$PROJECT_ROOT/docs/adr" -name '*.dependencies.json'
# 2. Filter for sourceRef.phase == $PHASE via:
#      jq --arg phase "$PHASE" '[.dependencies[] | select(.sourceRef.phase == $phase)]'
# 3. Aggregate by downstream phase + path; pass aggregation as template var "downstreamTraces"
# 4. Re-render <synthesis>.html via the synthesis-review SKILL's renderer with new var
# 5. Preserve all other sections' Approved state (the renderer reads existing Approved marks)

# Current implementation (stub — minimal, side-effect-free):
echo "[back-fill stub] phase=$PHASE root=$PROJECT_ROOT"
echo "[back-fill stub] would scan: $PROJECT_ROOT/docs/adr/*.dependencies.json"
echo "[back-fill stub] would re-render: $PROJECT_ROOT/docs/adr/${PHASE}.html"
exit 0
```

- [ ] **Step 4: Mark executable + commit**

```bash
chmod +x greenfield/scripts/back-fill-downstream-section.sh
git add greenfield/skills/check/SKILL.md \
        greenfield/skills/tooling-generation/SKILL.md \
        greenfield/scripts/back-fill-downstream-section.sh
git commit -m "feat(greenfield): check + tooling-generation R4 + back-fill script stub"
```

---

## Phase F — Cross-phase invariants

### Task 23: check-r4-invariants.md + grill-spec SKILL.md wiring + question-bank.md flag docs

**Files:**
- Create: `greenfield/skills/grill-spec/references/check-r4-invariants.md`
- Modify: `greenfield/skills/grill-spec/SKILL.md`
- Modify: `greenfield/skills/context-gathering/references/question-bank.md`

- [ ] **Step 1: Author check-r4-invariants.md**

```markdown
# Round 4 Cross-Phase Invariants

## CHECK-R4-1 — Every primary persona has ≥ 1 job-to-be-done

- **Severity:** hard-fail
- **Source phases:** personas + (mode.depth=light loosens to "name+role+goal sufficient")
- **Predicate (pseudo-code):**

```
forall p in personas.primary:
  assert mode.depth == "light" OR p.jobs.length >= 1
```

- **Message on fail:** "Persona {p.id} ({p.name}) has no jobs-to-be-done. Heavy mode requires at least one job per primary persona."

## CHECK-R4-2 — Every aggregate-root entity has corresponding data.persistence decision

- **Severity:** hard-fail
- **Source phases:** domainModel + dataArchitecture
- **Predicate:**

```
forall e in domainModel.entities where e.isAggregateRoot:
  assert exists d in dataArchitecture.persistence where d.entityId == e.id
```

- **Message on fail:** "Aggregate root {e.id} has no corresponding data.persistence decision. Either add a persistence Q answer for {e.id} or unmark as aggregate root."

## CHECK-R4-3 — Auto-loop traceability (sourceRef populated)

- **Severity:** hard-fail
- **Predicate:**

```
if mode.coupling == "auto-loop":
  forall downstream phase in [auth, privacy, frontend (R6)]:
    forall answer in <phase>.<looped-Q> where derivedFrom is set:
      assert <phase>.dependencies.json contains an entry with matching path AND sourceRef.phase == "personas" AND sourceRef.id matches derivedFrom
```

- **Message on fail:** "Auto-loop coupling expected sourceRef trace in {phase}.{path}, but dependencies.json has no matching entry. State machine bug — file an issue."

## CHECK-R4-4 — Every captured risk has reconciliation status

- **Severity:** hard-fail
- **Predicate:**

```
forall r in risks:
  assert r.reconciliation.status is set AND r.reconciliation.status in [
    "mitigated", "partial", "accepted-explicit", "open-followup", "out-of-scope", "user-declared-none"
  ]
```

- **Message on fail:** "Risk {r.id} ({r.text}) has no reconciliation status. Run Step 15 Risk Reconciliation before signing off."

## CHECK-R4-5 — No auth.access[] rule for unknown entity

- **Severity:** warn
- **Predicate:**

```
forall rule in auth.access:
  if rule.entityId is set:
    assert exists e in domainModel.entities where e.id == rule.entityId
```

- **Message:** "Auth rule references entity {rule.entityId} which doesn't exist in domain model. Likely typo or entity removed."

## CHECK-R4-6 — Bounded-contexts count ≤ entities count

- **Severity:** warn
- **Predicate:** `domainModel.contexts.length <= domainModel.entities.length`
- **Message:** "Bounded contexts ({contexts.length}) exceed entity count ({entities.length}). Likely over-engineering — consider consolidating contexts."

## CHECK-R4-7 — Anti-persona name uniqueness

- **Severity:** warn
- **Predicate:** anti-persona names don't collide with primary/secondary persona names
- **Message:** "Anti-persona '{name}' has the same name as a primary/secondary persona. Use a different name to avoid confusion."

## CHECK-R4-8 — Light + DDD-lite suggests Hybrid coupling

- **Severity:** suggestion (not blocking)
- **Predicate:** if mode.depth == "light" AND mode.domainFormat == "ddd-lite" AND mode.coupling == "auto-loop"
- **Message:** "Auto-loop coupling with Light depth + DDD-lite domain is wasteful (sparse persona/entity data + many loops = low value, high time). Consider switching coupling to Hybrid via /greenfield:pickup → Adjust mode."
```

- [ ] **Step 2: Wire CHECK-R4-* invariants in grill-spec/SKILL.md**

Find the existing CHECK-R3-* section. Append:

```markdown
## Round 4 invariants (CHECK-R4-*)

Run after Step 15.2 (Cross-phase invariant check) — see `references/check-r4-invariants.md` for predicate definitions.

| ID | Severity | Phase deps |
|---|---|---|
| CHECK-R4-1 | hard-fail | personas |
| CHECK-R4-2 | hard-fail | domainModel + dataArchitecture |
| CHECK-R4-3 | hard-fail | personas + auto-loop downstream |
| CHECK-R4-4 | hard-fail | risks (any) + architecturalValidation |
| CHECK-R4-5 | warn | domainModel + auth |
| CHECK-R4-6 | warn | domainModel |
| CHECK-R4-7 | warn | personas |
| CHECK-R4-8 | suggestion | mode (any) |

If any hard-fail invariant fails, block Step 15.3 final sign-off. User must fix or explicitly override.
```

- [ ] **Step 3: Add Q-bank flag documentation**

Add to `greenfield/skills/context-gathering/references/question-bank.md`:

```markdown
## Round 4 Q-bank flag reference

### `showInLight: boolean` (default: true)

If `false`, the Q is skipped when `mode.depth == "light"`. Used to gate depth-only Qs in personas (Q4-Q5, Q7-Q8, Q9-Q11), domain (Q6, Q7, Q10), and 8 architectural phases.

### `loopOver: string` (optional)

If set, the Q iterates over items in the named array. Valid sources: `personas.primary`, `personas.secondary`, `domainModel.entities`, `domainModel.aggregates` (derived view of entities with isAggregateRoot=true).

### `loopMode: "always" | "hybrid-only"` (default: "always" if loopOver set)

Controls whether the Q loops in Hybrid coupling mode:
- `always`: loops in both auto-loop and hybrid (e.g., auth.roles per persona — critical loop)
- `hybrid-only`: loops in auto-loop ONLY; fires static once in hybrid (e.g., security.threat-model per persona — nice-to-have loop)

Misnomer: `hybrid-only` means "skip the loop in hybrid mode." A clearer name in retrospect would be `hybrid-skip` — but the spec is locked. Document the surprise in CLAUDE.md.

### `isRiskCapture: boolean` (default: false)

If `true`, the Q's answer appends to `context.risks[]` array. Used by `Q_RISK` entries in personas, domain, and 8 architectural phases (10 total).

### `feedsIntoConsolidation: boolean` (default: false)

If `true` (always paired with `isRiskCapture: true`), the captured risk participates in Step 15 Risk Reconciliation. Currently identical to `isRiskCapture` semantically but kept separate for future extensibility (e.g., risks captured but excluded from reconciliation).
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/grill-spec/references/check-r4-invariants.md \
        greenfield/skills/grill-spec/SKILL.md \
        greenfield/skills/context-gathering/references/question-bank.md
git commit -m "feat(greenfield): CHECK-R4-1 through CHECK-R4-8 cross-phase invariants + flag docs"
```

---

## Phase G — Migrations

### Task 24: Demote Step 2 vision/scope users-Q to pointer; preserve as legacy field

**Files:**
- Modify: `greenfield/skills/context-gathering/SKILL.md` (Step 2 section)
- Modify: appropriate Q-bank file (likely `greenfield/skills/context-gathering/references/vision.q-bank.md` or in-line Step 2 Q list)

- [ ] **Step 1: Locate the current "Who are the users?" Q**

Run: `grep -rn "users.*who\|who.*users\|user.*Q" greenfield/skills/context-gathering/references/`

- [ ] **Step 2: Demote the Q to a pointer**

Replace the Q text with:

```markdown
> **Migrated to Step 2.2 Personas in Round 4.** Existing free-text user descriptions are preserved as `vision.users[]` (legacy field) for backward compatibility with alpha.4 state files. New wizard runs use Step 2.2's rich-persona format.
```

- [ ] **Step 3: Ensure backward-compat in state machine**

In `greenfield/skills/context-gathering/SKILL.md`, add a state-migration note in Step 2:

```markdown
**Backward compat:** if alpha.4 state has `vision.users[]` populated, surface to user at Step 2.2: "Migrated from Step 2 of alpha.4 wizard: {{vision.users|join(', ')}}. Want to restructure as personas?" Default: yes.
```

- [ ] **Step 4: Commit**

```bash
git add greenfield/skills/context-gathering/SKILL.md \
        greenfield/skills/context-gathering/references/vision.q-bank.md
git commit -m "refactor(greenfield): demote Step 2 users-Q to pointer; preserve as vision.users[] legacy"
```

---

### Task 25: Onboard SKILL.md — handle new phase blocks (backward-compat)

**Files:**
- Modify: `onboard/skills/generation/SKILL.md`

- [ ] **Step 1: Read current phase-handling section**

- [ ] **Step 2: Add Round 4 phase handling**

```markdown
## Round 4 — new phase blocks (Personas, Domain Model, Risk Reconciliation, mode, risks)

Onboard 2.0 alpha.5+ accepts a context object with up to 11 phase blocks (R1: cicdAndDelivery; R2: data, api; R2.5: architecturalFraming; R3: auth, privacy, security, runtimeOperations; R3: architecturalValidation; R4: personas, domainModel). All are optional in alpha.5.

When generating CLAUDE.md / rules / skills / agents / hooks:

1. If `phases.personas` present: incorporate persona IDs into agent generation (e.g., role-specific agents in auth-enriched generation)
2. If `phases.domainModel` present: incorporate entity IDs into schema generation hooks
3. If `risks[]` non-empty + at least one `reconciliation.status == "open-followup"`: prepend a docs/risks.md to the generated docs/ directory listing open followups
4. If `mode.coupling == "auto-loop"`: log a metadata note in CLAUDE.md "This project's wizard ran in auto-loop coupling — sourceRef traces in docs/adr/*.dependencies.json"

**Backward compat:** if any phase block is absent, behave as alpha.4 generator. No hard errors. Generation is layered, not gated.
```

- [ ] **Step 3: Commit**

```bash
git add onboard/skills/generation/SKILL.md
git commit -m "feat(onboard): generate SKILL R4 — handle personas, domainModel, risks (optional/backward-compat)"
```

---

## Phase H — Docs + bookkeeping

### Task 26: greenfield/CLAUDE.md + onboard/CLAUDE.md updates

**Files:**
- Modify: `greenfield/CLAUDE.md`
- Modify: `onboard/CLAUDE.md`

- [ ] **Step 1: Update greenfield/CLAUDE.md architecture diagram**

Find the wizard architecture diagram. Insert Steps 2.2 and 2.7. Update step count 15 → 17. Add mode toggles to Step 1 description.

Reference: design spec § Architecture for the new diagram shape.

- [ ] **Step 2: Update greenfield/CLAUDE.md "Skill Hierarchy" section**

Find the `context-gathering/SKILL.md` description. Update wizard step count and add: "Round 4: 17 wizard steps (Steps 2.2 Personas + 2.7 Domain Model + inline risk Qs in 8 architectural phases + Risk Reconciliation in Step 15)."

Update synthesis-review description with new templates (personas, domain-model, arch-val-risk-reconciliation-section).

- [ ] **Step 3: Update Q-bank flag doc reference**

Add a bullet under "Key Patterns":

```markdown
- **Round 4 Q-bank flags:** `showInLight` (light-mode gating), `loopOver` + `loopMode` (auto-loop on personas/entities), `isRiskCapture` (collects to shared `risks[]`). See `context-gathering/references/question-bank.md` § Round 4 Q-bank flag reference.
```

- [ ] **Step 4: Update onboard/CLAUDE.md phase listing**

Find the phase-listing section. Add: `personas`, `domainModel`, and note that `architecturalValidation.riskReconciliation` is an extension. Update top-level `risks[]` documentation.

- [ ] **Step 5: Commit**

```bash
git add greenfield/CLAUDE.md onboard/CLAUDE.md
git commit -m "docs(greenfield + onboard): CLAUDE.md R4 — Steps 2.2/2.7, mode toggles, Q-bank flags"
```

---

### Task 27: docs/greenfield-3.0-round4/ companion docs + greenfield-overview.html Discussion Log

**Files:**
- Create: `docs/greenfield-3.0-round4/overview.md`
- Create: `docs/greenfield-3.0-round4/coupling-matrix.md`
- Create: `docs/greenfield-3.0-round4/migration-notes.md`
- Modify: `docs/greenfield-overview.html`

- [ ] **Step 1: Author overview.md**

```markdown
# Greenfield 3.0 Round 4 — Overview

> **Round status:** Implementation in progress (started 2026-05-14).
> **Spec:** `docs/superpowers/specs/2026-05-14-greenfield-3.0-round4-design.md`
> **Plan:** `docs/superpowers/plans/2026-05-14-greenfield-3.0-round4-implementation.md`
> **Target versions:** greenfield@3.0.0-alpha.5, onboard@2.0.0-alpha.5

## What Round 4 adds

- **2 new phases:** Personas (Step 2.2), Domain Modeling (Step 2.7)
- **Distributed risk capture:** 10 inline Q_RISK entries (8 architectural + 2 discovery phases)
- **Risk Reconciliation:** new front section in architecturalValidation (Step 15)
- **3 wizard-level mode toggles:** depth (heavy/light), coupling (auto-loop/hybrid), domainFormat (full-ddd/ddd-lite)
- **Auto-loop mechanic:** downstream phases iterate per persona/entity (when coupling=auto-loop)

## Round 4 commit log

(Populated as commits land — `git log --oneline feat/greenfield-1.3 | grep R4`)

## Lessons + adjustments

(Populated post-execution — particularly any mid-execution drift items.)
```

- [ ] **Step 2: Author coupling-matrix.md**

Reproduce the full coupling matrix table from design spec § Coupling matrix (definitive). Include the auto-loop and hybrid columns + per-Q notes.

- [ ] **Step 3: Author migration-notes.md**

```markdown
# Round 4 — Migration Notes

## For users on alpha.4 with an in-flight wizard

On next `/greenfield:pickup`, the wizard auto-migrates your state:

- `mode.depth = "heavy"` (matches alpha.4 implicit posture)
- `mode.coupling = "hybrid"` (safer than auto-loop for in-flight sessions — see below)
- `mode.domainFormat = "ddd-lite"` (lighter; you can upgrade explicitly)
- `phases.personas` + `phases.domainModel` marked as "not-yet-run"
- `risks[]` initialized empty

The wizard prompts: "Round 4 added Personas + Domain phases. Resume current step, or run new phases retroactively?"

### Why default coupling=hybrid for migrated sessions?

In a cold-start wizard, auto-loop is the default because every downstream phase from the start gets persona/entity iteration. For an in-flight session, switching to auto-loop retroactively would expand many already-completed phases — too much re-asking. Hybrid is the conservative choice; user can upgrade to auto-loop via `/greenfield:pickup → Adjust mode`.

## For users on alpha.4 with COMPLETED wizard (post-scaffold)

No automatic migration runs. `/greenfield:check` will flag missing `personas.html` + `domain-model.html` and offer to run those phases retroactively in `/greenfield:pickup`. The freshness hook still works on existing R1-R3 syntheses.

## For maintainers — schema break posture

Round 4 is the first **non-hard-cutover** schema bump since R2. It's purely additive:

- New top-level keys: `mode`, `risks`
- New phase blocks: `personas`, `domainModel`
- Extended phase block: `architecturalValidation.riskReconciliation`
- New optional field: `sourceRef` on dependency entries

alpha.4 wizard reads alpha.5 state file by IGNORING unknown keys. alpha.5 wizard reads alpha.4 state by running the migration shim. No data loss in either direction.

## Rollback path

If R4 needs to be reverted post-merge:
- Revert all R4 commits
- `plugin.json` → `3.0.0-alpha.4`
- alpha.5 state files: on next pickup with alpha.4 wizard, unknown keys silently dropped (lossy but non-corrupting)
```

- [ ] **Step 4: Add ROUND 4 LOCKED entry to greenfield-overview.html Discussion Log**

Find the Discussion Log section in `docs/greenfield-overview.html`. Add a new entry:

```html
<article class="locked-entry">
  <h3>ROUND 4 LOCKED — 2026-05-14</h3>
  <p><strong>Scope:</strong> Personas (Step 2.2) + Domain Modeling (Step 2.7) + Distributed risk capture (inline Q_RISK in 10 phases + Risk Reconciliation in Step 15) + 3 wizard-level mode toggles (depth, coupling, domainFormat).</p>
  <p><strong>Decisions:</strong></p>
  <ol>
    <li>Front-load discovery placement (Personas before architecturalFraming; Domain before dataArchitecture)</li>
    <li>Tiered depth: Heavy default, Light opt-in</li>
    <li>Distributed risk inline + Risk Reconciliation consolidation (no standalone Risk phase)</li>
    <li>Rich personas with downstream hooks (auto-loop on persona IDs)</li>
    <li>Full DDD default, DDD-lite toggle</li>
    <li>Auto-loop coupling default, Hybrid toggle</li>
  </ol>
  <p><strong>Target:</strong> greenfield@3.0.0-alpha.5 / onboard@2.0.0-alpha.5 — first non-hard-cutover schema bump (additive + auto-migrating).</p>
  <p><strong>Spec:</strong> <code>docs/superpowers/specs/2026-05-14-greenfield-3.0-round4-design.md</code></p>
</article>
```

- [ ] **Step 5: Commit**

```bash
git add docs/greenfield-3.0-round4/ docs/greenfield-overview.html
git commit -m "docs(greenfield): R4 companion docs + greenfield-overview Discussion Log"
```

---

### Task 28: Version bumps + marketplace.json + CHANGELOGs

**Files:**
- Modify: `greenfield/.claude-plugin/plugin.json`
- Modify: `onboard/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `greenfield/CHANGELOG.md`
- Modify: `onboard/CHANGELOG-2.0.md`

- [ ] **Step 1: Bump greenfield version**

```bash
sed -i.bak 's/"version": "3.0.0-alpha.4"/"version": "3.0.0-alpha.5"/' greenfield/.claude-plugin/plugin.json && rm greenfield/.claude-plugin/plugin.json.bak
```

Verify: `jq -r .version greenfield/.claude-plugin/plugin.json` → `3.0.0-alpha.5`

- [ ] **Step 2: Bump onboard version**

```bash
sed -i.bak 's/"version": "2.0.0-alpha.4"/"version": "2.0.0-alpha.5"/' onboard/.claude-plugin/plugin.json && rm onboard/.claude-plugin/plugin.json.bak
```

Verify: `jq -r .version onboard/.claude-plugin/plugin.json` → `2.0.0-alpha.5`

- [ ] **Step 3: Sync marketplace.json**

```bash
jq '(.plugins[] | select(.name=="greenfield") | .version) = "3.0.0-alpha.5" | (.plugins[] | select(.name=="onboard") | .version) = "2.0.0-alpha.5"' \
  .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp && \
  mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json
```

Verify: `jq '.plugins[] | select(.name=="greenfield" or .name=="onboard") | {name, version}' .claude-plugin/marketplace.json`

- [ ] **Step 4: Add greenfield CHANGELOG entry**

```markdown
## 3.0.0-alpha.5 — Round 4 (Personas + Domain + Distributed Risk)

**New phases:**
- Step 2.2 — Personas (12 Qs heavy / 4 light)
- Step 2.7 — Domain Modeling (15 Qs heavy + Full DDD / 10 DDD-lite / 5 light)

**New mechanics:**
- Wizard mode toggles at Step 1: depth (heavy/light), coupling (auto-loop/hybrid), domainFormat (full-ddd/ddd-lite)
- Auto-loop: every downstream phase iterates per persona AND per entity (auto-loop mode); critical-only loops (auth.roles, data.persistence, etc.) in hybrid mode
- Inline risk capture: every architectural phase grows one final Q_RISK; risks collect to shared `risks[]` array
- Risk Reconciliation: new front section in architecturalValidation (Step 15)

**Schema:**
- alpha.4 → alpha.5 is the first **non-hard-cutover** schema bump (additive + auto-migrating)
- `/greenfield:pickup` auto-migrates alpha.4 state on first run

**Cross-phase invariants:**
- CHECK-R4-1 through CHECK-R4-8 added to grill-spec

**Wizard step count:** 15 → 17 (Steps 2.2 + 2.7 added; renumbering uses .X notation, no global renumber)
```

- [ ] **Step 5: Add onboard CHANGELOG-2.0.md entry**

```markdown
## 2.0.0-alpha.5 — Round 4 schema extensions

**context-shape-v2.json additions (additive — alpha.4 sessions auto-migrate):**
- New top-level `mode` block (depth/coupling/domainFormat)
- New `phases.personas` block
- New `phases.domainModel` block
- Extended `phases.architecturalValidation.riskReconciliation`
- New top-level `risks[]` array

**dependencies-schema.json additions:**
- Phase enum extends: `personas`, `domainModel`, `risks`
- Path pattern extends to allow new phase paths
- New optional `sourceRef` field on dependency entries (required when produced by auto-loop)

**SKILL.md updates:** generate handles new phase blocks (optional/backward-compat). If absent, behaves as alpha.4 generator.
```

- [ ] **Step 6: Commit**

```bash
git add greenfield/.claude-plugin/plugin.json \
        onboard/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        greenfield/CHANGELOG.md \
        onboard/CHANGELOG-2.0.md
git commit -m "chore(greenfield + onboard): bump 3.0.0-alpha.5 / 2.0.0-alpha.5 for Round 4"
```

---

## Phase I — Integration smoke + final pass

### Task 29: End-to-end auto-loop simulation (mock context, run through Steps 5-8, verify sourceRef populated)

**Files:**
- Create: `tests/round-4/auto-loop-fixture.json` (mock alpha.5 context)
- Create: `tests/round-4/auto-loop-smoke.sh` (manual test driver)

- [ ] **Step 1: Author the fixture context**

```jsonc
// tests/round-4/auto-loop-fixture.json
{
  "version": 2,
  "mode": {
    "depth": "heavy",
    "coupling": "auto-loop",
    "domainFormat": "full-ddd"
  },
  "phases": {
    "personas": {
      "primary": [
        {
          "id": "P1",
          "name": "Sara",
          "role": "Field Auditor",
          "goal": "Record findings on-site, sync later",
          "context": { "device": ["iPad"], "connection": "spotty", "techSophistication": "Basic" },
          "jobs": [{ "id": "J1", "story": "Photo + note in <30s" }]
        },
        {
          "id": "P2",
          "name": "Carl",
          "role": "Compliance Officer",
          "goal": "Review audit trails weekly",
          "context": { "device": ["Desktop"], "connection": "strong-wifi", "techSophistication": "Comfortable" },
          "jobs": [{ "id": "J2", "story": "Generate weekly report" }]
        }
      ]
    },
    "domainModel": {
      "contexts": [
        { "id": "BC1", "name": "Field-Audit", "responsibility": "Capture findings on site" }
      ],
      "entities": [
        { "id": "Audit", "contextId": "BC1", "isAggregateRoot": true, "relationships": [{ "target": "Finding", "kind": "has-many" }] },
        { "id": "Finding", "contextId": "BC1", "isAggregateRoot": false, "relationships": [] }
      ]
    }
  },
  "risks": []
}
```

- [ ] **Step 2: Author the smoke-test driver**

```bash
#!/usr/bin/env bash
# tests/round-4/auto-loop-smoke.sh — verify auto-loop fires per persona/entity given mock fixture
#
# This is a MANUAL smoke test (no automated test framework available).
# Operator: read the steps + run each, compare output to expected.

set -euo pipefail

cd "$(dirname "$0")/../.."

# 1. Verify fixture parses
jq . tests/round-4/auto-loop-fixture.json > /dev/null
echo "✓ Fixture parses"

# 2. Verify persona count = 2
PERSONA_COUNT=$(jq '.phases.personas.primary | length' tests/round-4/auto-loop-fixture.json)
[ "$PERSONA_COUNT" = "2" ] || { echo "✗ Expected 2 personas, got $PERSONA_COUNT"; exit 1; }
echo "✓ Persona count: 2"

# 3. Verify entity count = 2 (Audit, Finding)
ENTITY_COUNT=$(jq '.phases.domainModel.entities | length' tests/round-4/auto-loop-fixture.json)
[ "$ENTITY_COUNT" = "2" ] || { echo "✗ Expected 2 entities, got $ENTITY_COUNT"; exit 1; }
echo "✓ Entity count: 2"

# 4. Manual verification: run /greenfield:pickup with this fixture loaded
echo ""
echo "=== MANUAL STEP ==="
echo "Load this fixture as .claude/greenfield-state.json in a test project."
echo "Run /greenfield:pickup → Resume at Step 5 (auth)."
echo ""
echo "Expected behavior:"
echo "  • Auth phase loops auth.roles Q per persona (2 iterations: P1, P2)"
echo "  • Data phase loops data.persistence Q per entity (2 iterations: Audit, Finding)"
echo "  • Privacy phase loops privacy.access Q per persona"
echo "  • Each looped answer's dependencies.json has sourceRef.phase + sourceRef.id"
echo ""
echo "✓ Auto-loop smoke setup complete. Run manually."
```

- [ ] **Step 3: Run the smoke setup**

```bash
chmod +x tests/round-4/auto-loop-smoke.sh
bash tests/round-4/auto-loop-smoke.sh
```

Expected: 3 ✓ lines + "MANUAL STEP" prompt.

- [ ] **Step 4: Document the smoke test in Round 4 overview.md**

Add a "Smoke tests" section to `docs/greenfield-3.0-round4/overview.md` linking to `tests/round-4/auto-loop-smoke.sh` and `tests/round-4/auto-loop-fixture.json`.

- [ ] **Step 5: Commit**

```bash
git add tests/round-4/ docs/greenfield-3.0-round4/overview.md
git commit -m "test(greenfield): auto-loop smoke test fixture + driver"
```

---

### Task 30: alpha.4 → alpha.5 state migration test

**Files:**
- Create: `tests/round-4/migration-alpha4-fixture.json`
- Create: `tests/round-4/migration-test.sh`

- [ ] **Step 1: Author alpha.4 fixture (no R4 fields)**

```jsonc
// tests/round-4/migration-alpha4-fixture.json
{
  "schemaVersion": "alpha.4",
  "version": 2,
  "phases": {
    "architecturalFraming": { "topology": "monolith", "scaleTarget": "small-team", "deploymentShape": "containerized", "boundaryNotes": "single-region" },
    "dataArchitecture": { "engine": "postgres", "compliance": "soc2" }
  }
}
```

- [ ] **Step 2: Author migration test**

```bash
#!/usr/bin/env bash
# tests/round-4/migration-test.sh — verify alpha.4 → alpha.5 migration shim is deterministic
#
# Manual smoke test:
# 1. Copy fixture to a test project's .claude/greenfield-state.json
# 2. Run /greenfield:pickup
# 3. Verify migration ran (mode.* set; schemaVersion bumped; audit entry added)

set -euo pipefail

cd "$(dirname "$0")/../.."

# Verify fixture parses
jq . tests/round-4/migration-alpha4-fixture.json > /dev/null

# Verify fixture has NO R4 fields
HAS_MODE=$(jq 'has("mode")' tests/round-4/migration-alpha4-fixture.json)
HAS_RISKS=$(jq 'has("risks")' tests/round-4/migration-alpha4-fixture.json)
HAS_PERSONAS=$(jq '.phases | has("personas")' tests/round-4/migration-alpha4-fixture.json)

[ "$HAS_MODE" = "false" ] && [ "$HAS_RISKS" = "false" ] && [ "$HAS_PERSONAS" = "false" ] || {
  echo "✗ Fixture has R4 fields — not a valid alpha.4 fixture";
  exit 1;
}
echo "✓ Fixture is clean alpha.4"

echo ""
echo "=== MANUAL STEPS ==="
echo "1. cp tests/round-4/migration-alpha4-fixture.json /tmp/test-project/.claude/greenfield-state.json"
echo "2. cd /tmp/test-project && claude '/greenfield:pickup'"
echo ""
echo "Expected pickup output:"
echo "  • Migration shim runs (state.schemaVersion: alpha.4 → alpha.5)"
echo "  • mode.depth = 'heavy', mode.coupling = 'hybrid' (NOT auto-loop), mode.domainFormat = 'ddd-lite'"
echo "  • phases.personas marked 'not-yet-run'"
echo "  • phases.domainModel marked 'not-yet-run'"
echo "  • risks[] initialized as []"
echo "  • audit entry written to .claude/greenfield-meta.json"
echo "  • Prompt: 'Round 4 added Personas + Domain phases. Resume current step, or run new phases retroactively?'"
echo ""
echo "After pickup completes, verify:"
echo "  jq .mode /tmp/test-project/.claude/greenfield-state.json"
echo "Expected: { depth: 'heavy', coupling: 'hybrid', domainFormat: 'ddd-lite' }"
```

- [ ] **Step 3: Run the test**

```bash
chmod +x tests/round-4/migration-test.sh
bash tests/round-4/migration-test.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/round-4/migration-alpha4-fixture.json tests/round-4/migration-test.sh
git commit -m "test(greenfield): alpha.4 → alpha.5 state migration smoke test"
```

---

### Task 31: Run /validate skill across all plugins; PR creation

**Files:** none

- [ ] **Step 1: Run plugin validation**

```bash
# From repo root
shellcheck greenfield/scripts/*.sh onboard/scripts/*.sh notify/scripts/*.sh handoff/scripts/*.sh 2>/dev/null || true
```

Expected: no errors. If any, fix before PR.

- [ ] **Step 2: Validate all plugin manifests**

```bash
jq . greenfield/.claude-plugin/plugin.json > /dev/null
jq . onboard/.claude-plugin/plugin.json > /dev/null
jq . .claude-plugin/marketplace.json > /dev/null
```

Expected: silent success on all 3.

- [ ] **Step 3: Verify all referenced files exist**

```bash
# Quick reference integrity check
for f in greenfield/skills/synthesis-review/references/templates/personas.html \
         greenfield/skills/synthesis-review/references/templates/personas.md \
         greenfield/skills/synthesis-review/references/templates/personas-dependencies.json.example \
         greenfield/skills/synthesis-review/references/templates/domain-model.html \
         greenfield/skills/synthesis-review/references/templates/domain-model.md \
         greenfield/skills/synthesis-review/references/templates/domain-model-dependencies.json.example \
         greenfield/skills/synthesis-review/references/templates/arch-val-risk-reconciliation-section.html \
         greenfield/skills/synthesis-review/references/templates/risks-dependencies.json.example \
         greenfield/skills/context-gathering/references/personas.q-bank.md \
         greenfield/skills/context-gathering/references/domain-model.q-bank.md \
         greenfield/skills/context-gathering/references/inline-risk.q-bank.md \
         greenfield/skills/grill-spec/references/check-r4-invariants.md; do
  [ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
done
echo "✓ All R4 new files exist"
```

- [ ] **Step 4: Verify schema validity**

```bash
jq -e '.mode and .phases.personas and .phases.domainModel and .risks' onboard/skills/generation/references/context-shape-v2.json > /dev/null
echo "✓ context-shape-v2.json has R4 top-level keys"

jq -e '.properties.phase.enum | contains(["personas", "domainModel", "risks"])' onboard/skills/generation/references/dependencies-schema.json > /dev/null
echo "✓ dependencies-schema.json has R4 phase enum extensions"
```

- [ ] **Step 5: Run /validate skill (if available)**

```bash
# Inside Claude Code session:
# /validate
```

Expected: all 4 plugins (greenfield, onboard, notify, handoff) pass structure + manifest + reference checks.

- [ ] **Step 6: Push the branch**

```bash
git push -u origin feat/greenfield-1.3
```

- [ ] **Step 7: Open PR**

```bash
gh pr create --base develop --title "feat(greenfield)!: 3.0.0-alpha.5 — Round 4 (Personas + Domain + Distributed Risk)" --body "$(cat <<'EOF'
## Summary

Round 4 of the greenfield 3.0 wizard overhaul. Adds:
- **2 new phases** — Personas (Step 2.2) + Domain Modeling (Step 2.7)
- **Distributed risk capture** — 10 inline Q_RISK entries + Risk Reconciliation section in architecturalValidation
- **3 wizard mode toggles** — depth (heavy/light), coupling (auto-loop/hybrid), domainFormat (full-ddd/ddd-lite)
- **Auto-loop mechanic** — downstream phases iterate per persona/entity
- **8 cross-phase invariants** — CHECK-R4-1 through CHECK-R4-8

**Schema bump:** alpha.4 → alpha.5 (first non-hard-cutover bump since R2 — purely additive with auto-migration shim).

**Wizard step count:** 15 → 17.

**Source spec:** `docs/superpowers/specs/2026-05-14-greenfield-3.0-round4-design.md`

## Test plan

- [ ] All commits land cleanly on feat/greenfield-1.3
- [ ] `jq` validation passes on context-shape-v2.json + dependencies-schema.json
- [ ] All new files exist (per Task 31 Step 3 script)
- [ ] `/validate` skill passes on all 4 plugins
- [ ] Auto-loop smoke test (tests/round-4/auto-loop-smoke.sh) — fixture parses + manual /greenfield:pickup
- [ ] State migration test (tests/round-4/migration-test.sh) — alpha.4 fixture → alpha.5 via /greenfield:pickup
- [ ] Manual: trigger Steps 2.2 + 2.7 in a fresh wizard run; verify synthesis HTML renders for both
- [ ] Manual: verify Step 15 Risk Reconciliation walks captured risks
- [ ] Manual: verify CHECK-R4-1 through CHECK-R4-4 hard-fail when expected

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 8: Update memory + Discussion Log entry**

After PR creation (and before merge), update `~/.claude/projects/-Users-apurvbazari-Desktop-projects-claude-plugins/memory/project_greenfield_3_0_design.md` with PR number + status.

Update `docs/greenfield-3.0-round4/overview.md` with the final commit log (`git log --oneline feat/greenfield-1.3 ^develop | grep R4 | head -40`).

---

## Self-Review Checklist (run after plan is complete)

Run these checks before handing off to subagent dispatch:

1. **Spec coverage scan:**
   - [ ] Each item in design spec § In scope deliverables (21 items) has a corresponding task
   - [ ] Each cross-phase invariant (CHECK-R4-1 through CHECK-R4-8) is authored in Task 23
   - [ ] All 16 new files appear in at least one task's Create list
   - [ ] All 15 modified files appear in at least one task's Modify list

2. **Placeholder scan:**
   - [ ] No "TBD" / "TODO" / "fill in later" in task bodies
   - [ ] Every code block contains real content (no `// ...` ellipses except for documenting where to insert)
   - [ ] Every command has expected output described

3. **Type consistency:**
   - [ ] Q-bank field names (`loopOver`, `loopMode`, `showInLight`, `isRiskCapture`, `feedsIntoConsolidation`) match across Tasks 3, 4, 5-12, 16, 23
   - [ ] Schema property names (`mode.*`, `phases.personas.*`, `phases.domainModel.*`, `risks[]`) consistent across Tasks 1, 17, 25
   - [ ] Persona ID convention (`P1`, `P2`) consistent across Tasks 3, 13, 17, 21, 29
   - [ ] Entity ID + isAggregateRoot consistent across Tasks 4, 14, 17, 23, 29

4. **Mid-execution checkpoints documented:**
   - [ ] Phase A checkpoint (schema lock) — verify Task 12 references schema
   - [ ] Phase D checkpoint (template lock) — verify post-D verification step exists

5. **Rollback path documented:** Task 27 migration-notes.md includes 3-tier rollback path.
