# Feature Roadmap Q-bank — Step 16

> **Round:** 5 (Roadmap synthesis phase)
> **Steps:** 16 (after architecturalValidation at Step 15, before pluginRecommendation at Step 17)
> **Modes:** Heavy ~14 Qs + per-persona auto-loop / Light ~7 Qs (drops Q5/Q6/Q7/Q9)
> **Coupling:** Reads `personas.primary[]`, `domainModel.entities[]`, `risks[]`. Writes `phases.featureRoadmap.*`. Output drives `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` via onboard generation.
> **See also:** `personas.q-bank.md`, `domain-model.q-bank.md`, `inline-risk.q-bank.md`, design spec § Phase 1: Feature Roadmap (P9)

This phase captures **rich features with epic grouping, persona/entity/risk back-links, acceptance criteria, verification steps, and sizing**. Output is fully deterministic — onboard's generation skill renders `feature-list.json` + `sprint-1.json` field-by-field from the answers.

## Q-bank

### FR.Q1 — Horizon
- **type:** single-select
- **options:** ["mvp-only", "3-months", "6-months", "1-year", "open-ended"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "What's your roadmap horizon? (Single-feature MVP → broad multi-quarter scope)"
- **Stores to:** `phases.featureRoadmap.horizon`

### FR.Q2 — MVP boundary
- **type:** long-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "What separates MVP scope from post-MVP? (One paragraph — a clear boundary keeps sprint-1 honest.)"
- **Stores to:** `phases.featureRoadmap.mvpBoundary`

### FR.Q3 — Sizing scale
- **type:** single-select
- **options:** ["tshirt (S/M/L/XL)", "fibonacci", "hours", "none"]
- **default:** "tshirt"
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Sizing scale for features? (tshirt is recommended unless your team already uses fibonacci/hours.)"
- **Stores to:** `phases.featureRoadmap.sizingScale`

### FR.Q4 — Features by persona  [LOOP — per primary persona]
- **type:** repeating structured (title, category, size)
- **loopOver:** `personas.primary`
- **loopMode:** hybrid-only  <!-- collapses to flat in mode.coupling=hybrid -->
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "What does {persona.name} need to do in the system? (List features that serve this persona — wizard auto-tags personaIds[])"
- **Stores to:** `phases.featureRoadmap.features[]` (id auto-assigned F001/F002/…; personaIds[] = [currentPersona.id])

### FR.Q5 — Entity links  [PER-FEATURE]
- **type:** multi-select (per feature)
- **options:** dynamic from `domainModel.entities[].id`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Which domain entities does {feature.title} touch?"
- **Stores to:** `phases.featureRoadmap.features[*].entityIds[]`

### FR.Q6 — Risk links  [PER-FEATURE]
- **type:** multi-select (per feature)
- **options:** dynamic from `risks[].id`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Which captured risks does {feature.title} address or expose?"
- **Stores to:** `phases.featureRoadmap.features[*].riskIds[]`

### FR.Q7 — Acceptance criteria  [PER-FEATURE]
- **type:** bulleted free-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Acceptance criteria for {feature.title}? (Bulleted — each line a checkable assertion.)"
- **Stores to:** `phases.featureRoadmap.features[*].acceptanceCriteria[]`

### FR.Q8 — Verification steps  [PER-FEATURE]
- **type:** bulleted free-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Verification steps for {feature.title}? (Automatable preferred — these feed `feature-list.json` and the sprint gate.)"
- **Stores to:** `phases.featureRoadmap.features[*].verificationSteps[]`

### FR.Q9 — Epic grouping  [PER-PERSONA]
- **type:** structured (epic title + featureIds[])
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Group {persona.name}'s features into epics. (One epic per coherent theme — epic IDs auto-assigned E1/E2/…)"
- **Stores to:** `phases.featureRoadmap.epics[]` (id, title); `features[*].epicId`

### FR.Q10 — Cross-cutting features
- **type:** repeating structured (title, category, size, verificationSteps)
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Features not tied to a specific persona (ops dashboards, admin, observability, internal tooling)? Same shape as FR.Q4 but condensed."
- **Stores to:** `phases.featureRoadmap.features[]` with personaIds[] = []

### FR.Q11 — Epic sequencing
- **type:** structured (per epic: prerequisites)
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "For each epic, which epics must precede it? (Order-of-build constraints.)"
- **Stores to:** `phases.featureRoadmap.epics[*].sequenceAfter[]`

### FR.Q12 — Sprint-1 selection
- **type:** multi-select
- **options:** dynamic from captured features
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which features land in sprint-1? (Pick a focused set — size-budget warning triggers if S=1/M=3/L=5/XL=8 sum > 15.)"
- **Stores to:** `phases.featureRoadmap.sprint1.featureIds[]`; `features[*].sprintAssignment = 1`

### FR.Q13 — Sprint-1 contract
- **type:** structured (criteria[] with name/weight/description/threshold)
- **showInLight:** true
- **isRiskCapture:** false
- **defaults:** functional/quality/testing as `required`; performance/security/a11y as `recommended` when applicable
- **Prompt:** "Sprint-1 completion gate. Adopt onboard's standard criteria (functional/quality/testing required) or customize?"
- **Stores to:** `phases.featureRoadmap.sprint1.criteria[]`, `phases.featureRoadmap.sprint1.completionGate`

### FR.Q14 — Q_RISK trailer
- **type:** long-text (parseable into structured risks[])
- **showInLight:** false
- **isRiskCapture:** true
- **Prompt:** "Roadmap risks? (Scope creep on epic X, persona Y unvalidated, dependency on external vendor, etc.)"
- **Stores to:** `risks[]` with `originatingPhase: "featureRoadmap"`

## Auto-loop behavior

| Mode | FR.Q4–Q9 |
|---|---|
| `mode.coupling = auto-loop` AND `personas.skipped != true` | Loops per `personas.primary[]`. Each iteration auto-tags `personaIds[]`. |
| `mode.coupling = hybrid` | Loop collapses; static prompts list all primary personas inline; user assigns `personaIds[]` per feature. |
| `personas.skipped = true` | FR.Q4–Q9 skipped entirely; all features captured via FR.Q10. |

## Edge cases

- `personas.skipped = true` → FR.Q4-Q9 loop skipped; features captured via FR.Q10 only.
- `domainModel.deferred = true` → FR.Q5 optional; rendered with empty arrays.
- Zero `Q_RISK` answers across all phases → FR.Q6 optional; rendered with empty arrays.
- `mode.depth = light` → drops FR.Q5/Q6/Q7/Q9 (~7 effective Qs).
- `mode.depth = light` AND `mode.coupling = hybrid` → minimum-viable P9 (~5 effective prompts).
- Sprint-1 size budget exceeded (sum > 15) → "Sprint-1 has Xpts — typical is 10-15. Trim or accept?" prompt before lock (R-R5-3 mitigation).
