# Schema & API Draft Review Q-bank — Step 19

> **Round:** 5 (Draft-review phase — the architectural inversion)
> **Steps:** 19 (after pluginInstall at Step 18, before handoff at Step 20)
> **Modes:** Heavy ~12 Qs / Light ~6 Qs (drops Adjust flows SDR.Q4/Q6/Q8)
> **Coupling:** Reads `domainModel.*`, `auth.*`, `privacy.*`, `apiIntegration.*`, `runtimeOperations.observability`. Writes `phases.schemaDraftReview.*`. Auto-renders DB/API/Event drafts mid-flow.
> **See also:** `feature-roadmap.q-bank.md`, design spec § Phase 2: Schema & API Draft Review (P10.5), `greenfield/scripts/render-schema-drafts.sh`

This phase is **architecturally inverted**: most phases capture then render. P10.5 renders first (auto-synthesizing drafts from upstream discovery), then captures the user's review decisions inline.

## Q-bank

### SDR.Q1 — Applicable artifacts
- **type:** multi-select
- **options:** ["db", "api", "event"]
- **showInLight:** true
- **isRiskCapture:** false
- **pre-checked:** db if `dataArchitecture.engine != "none"`; api if `apiIntegration.endpoints[]` non-empty OR `asyncPattern != "none"`; event if `domainModel.domainEvents[]` non-empty
- **Prompt:** "Which artifacts apply to this project? (Pre-checked from upstream answers — deselect anything not applicable.)"
- **Stores to:** `phases.schemaDraftReview.applicableArtifacts[]`

### SDR.Q2 — Language preferences
- **type:** structured (one single-select per enabled artifact)
- **options:**
  - db: ["prisma", "sql-ddl", "typeorm", "sqlalchemy", "none"]
  - api: ["openapi-3.0", "graphql-sdl", "trpc", "postman", "none"]
  - event: ["asyncapi", "json-schema", "avro", "none"]
- **defaults:** pre-filled from stack
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Output language per artifact?"
- **Stores to:** `phases.schemaDraftReview.languages.{db,api,event}`

### AUTO-RENDER  (system action — not a question)

Wizard runs `${CLAUDE_PLUGIN_ROOT}/scripts/render-schema-drafts.sh <state-file>` which:
- reads context-shape-v2 state
- writes `phases.schemaDraftReview.drafts.{db,api,event}.{content,sourceRefs,renderedAt}` + `crossCheckWarnings[]`
- if render fails: surface error + halt before SDR.Q3.

For each artifact not in `applicableArtifacts[]`, the wizard sets `drafts.{artifact}.skipped = true` and skips its SDR.Q3-Q8 pair.

### SDR.Q3 — DB review
- **type:** single-select
- **options:** ["Approve", "Adjust", "Reject + regenerate"]
- **showInLight:** true
- **isRiskCapture:** false
- **skip if:** `drafts.db.skipped = true`
- **Prompt:** "Review the rendered DB schema below. Approve as-is, adjust inline, or reject and edit upstream answers?\n\n{drafts.db.content}"
- **Stores to:** `phases.schemaDraftReview.drafts.db.approved` (true on Approve)

### SDR.Q4 — DB adjust  [CONDITIONAL on SDR.Q3 = Adjust]
- **type:** long-text or structured delta (add field / rename / change type / add index)
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Describe the adjustment — wizard re-renders and re-prompts SDR.Q3."
- **Stores to:** `phases.schemaDraftReview.drafts.db.adjustments[]`

### SDR.Q5 — API review
- Same pattern as SDR.Q3, operating on `drafts.api`.
- **Stores to:** `phases.schemaDraftReview.drafts.api.approved`

### SDR.Q6 — API adjust  [CONDITIONAL on SDR.Q5 = Adjust]
- Same pattern as SDR.Q4.
- **Stores to:** `phases.schemaDraftReview.drafts.api.adjustments[]`

### SDR.Q7 — Event review
- Same pattern as SDR.Q3, operating on `drafts.event`.
- **Stores to:** `phases.schemaDraftReview.drafts.event.approved`

### SDR.Q8 — Event adjust  [CONDITIONAL on SDR.Q7 = Adjust]
- Same pattern as SDR.Q4.
- **Stores to:** `phases.schemaDraftReview.drafts.event.adjustments[]`

### SDR.Q9 — Cross-check resolution
- **type:** structured (per warning: addressed bool + optional note)
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Resolve cross-check warnings (per-warning prompt below). Errors must be addressed before the lock gate; warns/info are advisory."
- **Stores to:** `phases.schemaDraftReview.crossCheckWarnings[*].addressed`

### SDR.Q10 — Lock gate
- **type:** confirm
- **showInLight:** true
- **isRiskCapture:** false
- **gate:** blocked unless every enabled draft has `approved = true` AND every `level=error` warning has `addressed = true` (per CHECK-R5-4)
- **Prompt:** "Lock these drafts as canonical? Onboard will write them verbatim during tooling generation."
- **Stores to:** `phases.schemaDraftReview.lockedAt`

### SDR.Q11 — Output strategy
- **type:** single-select
- **options:** ["project-root", "docs-drafts"]
- **default:** "project-root"
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Write schema/contract files directly to project root (`prisma/schema.prisma`, `docs/api/openapi.yaml`, `docs/events/event-schemas.yaml`) or to `docs/drafts/` for manual placement?"
- **Stores to:** `phases.schemaDraftReview.outputStrategy`

### SDR.Q12 — Q_RISK trailer
- **type:** long-text
- **showInLight:** false
- **isRiskCapture:** true
- **Prompt:** "Schema/contract risks? (Schema mismatch with downstream consumers, API breaking change before v1.0, etc.)"
- **Stores to:** `risks[]` with `originatingPhase: "schemaDraftReview"`

## Edge cases

- `dataArchitecture.engine = "none"` → `drafts.db.skipped = true`; SDR.Q3/Q4 skipped.
- `apiIntegration.endpoints[]` empty AND `asyncPattern = "none"` → `drafts.api.skipped = true`; SDR.Q5/Q6 skipped.
- `domainModel.domainEvents[]` empty → `drafts.event.skipped = true`; SDR.Q7/Q8 skipped.
- **All three skipped** → entire P10.5 skipped with `phases.schemaDraftReview.skipped=true` AND `deferredReason="no applicable artifacts"`; wizard jumps Step 18 → Step 20.
- `mode.depth = light` → SDR.Q4/Q6/Q8 (Adjust) skipped; only Approve/Reject. Reject loops back to upstream phase via Adjust mode.
- Multiple databases → `drafts.db` becomes array `drafts.db[]`; SDR.Q3/Q4 fire per database. (Round 5 stretch goal — gracefully degrade to first-DB-only if state still scalar.)
- Reject + upstream change → Reject branch shows "the X part of this draft came from phase Y — adjust there?" with `/greenfield:pickup` Adjust-mode jump-link.
- Renderer failure → surface error; halt before SDR.Q3. Allow retry or skip-with-deferred-reason path.
