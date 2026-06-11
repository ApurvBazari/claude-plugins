<!-- Extracted from generation/SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Round 4 — Personas, Domain Model, Risk Reconciliation, mode, risks

## Round 4 — new phase blocks (Personas, Domain Model, Risk Reconciliation, mode, risks)

Onboard 2.0 alpha.5+ accepts a context object with up to 11 phase blocks plus a top-level `risks[]` array and a top-level `mode` block:

- **R1:** `cicdAndDelivery`
- **R2:** `dataArchitecture`, `apiIntegration`
- **R2.5:** `architecturalFraming`, `architecturalValidation`
- **R3:** `auth`, `privacy`, `security`, `runtimeOperations`
- **R4 (new):** `personas`, `domainModel`

Plus two top-level R4 additions:

- `risks[]` — captured inline at each phase's `Q_RISK` trailer; reconciled at `phases.architecturalValidation.riskReconciliation`.
- `mode` — three wizard-level toggles: `depth` (heavy/light), `coupling` (auto-loop/hybrid), `domainFormat` (full-ddd/ddd-lite).

All R4 additions are **optional**. If absent, onboard generation behaves identically to alpha.4 — no R4-aware code paths fire.

### Generation behavior when R4 blocks are present

When generating CLAUDE.md, rules, skills, agents, and hooks, layer the following R4-aware behaviors on top of the existing alpha.4 generation:

1. **`phases.personas` present** — incorporate persona IDs into agent generation:
   - For auth-enriched generation: generate role-specific agents named after personas (e.g., if `personas.primary[0].name = "FieldAuditor"`, the auth-aware agent set may include a `field-auditor-agent.md` for persona-specific workflows).
   - For frontend-enriched generation (Round 6 consumer): persona names drive UI persona-modeling sections in `docs/personas.md` if not already present.
   - For the project's `docs/personas.md` (if onboard generates a docs scaffold): copy persona summaries.

2. **`phases.domainModel` present** — incorporate entity IDs into schema-generation hooks:
   - For dataArchitecture-enriched generation: generate per-entity migration scaffolds in `db/migrations/` (one file per `domainModel.entities[].id` where `isAggregateRoot == true`).
   - For apiIntegration-enriched generation: pre-populate route maps with one route per aggregate-root entity.
   - For the freshness hook config: register entity-ID-aware drift detection (if an entity is renamed in `domainModel.entities[].id`, surface a drift queue entry for stale migration files).

3. **`risks[]` non-empty AND at least one `risk.reconciliation.status == "open-followup"`** — prepend a `docs/risks.md` to the generated docs/ directory listing open follow-ups. Format: one heading per risk ID, with originating phase + text + recommended follow-up rationale. Sort by originating phase order (architecturalFraming → cicdAndDelivery).

4. **`mode.coupling == "auto-loop"`** — log a metadata note in the generated CLAUDE.md: *"This project's wizard ran in auto-loop coupling — sourceRef traces in `docs/adr/*.dependencies.json` document per-persona / per-entity decisions."* The note is informational only and surfaces during human review of the generated CLAUDE.md.

5. **`mode.depth == "light"`** — gate aspirational sections in generated CLAUDE.md:
   - Skip the "Detailed architecture diagrams" section (light projects usually don't have them).
   - Skip the "Production readiness checklist" section (light = prototype).
   - Replace with a "Prototype mode" header noting that the project was scaffolded in Light depth and many architectural decisions used defaults.

### Backward compatibility (mandatory)

- If `phases.personas` is **absent**: generate identically to alpha.4 (no persona-aware agents).
- If `phases.personas` is `{}` (empty object — explicit user-skip signal): same as absent.
- If `phases.domainModel` is **absent or empty**: generate identically to alpha.4 (no entity-aware schemas/routes).
- If `risks` is **absent or `[]`**: skip the docs/risks.md generation.
- If `mode` is **absent**: assume new-session defaults (heavy + auto-loop + full-ddd) and surface a warning in the generation log: *"Mode block missing from context — assuming new-session defaults."*
- If `mode.coupling` is `"hybrid"` (explicit non-auto-loop): skip the auto-loop sourceRef note. No-op.

No hard errors on absence — generation is **layered, not gated**. Existing alpha.4 generation paths run unchanged; R4 paths layer on top when their input blocks are present.

### State-shape contract for upstream callers

Upstream callers pass the R4 fields alongside the existing R1–R3 fields:

- `phases.personas` is sent verbatim from the caller's context.
- `phases.domainModel` is sent verbatim from the caller's context.
- `risks` is sent verbatim from the caller's `risks[]`.
- `mode` is sent verbatim from the caller's context.

Onboard does not transform these on receipt; it consumes them as-is and applies the layered behaviors above.
