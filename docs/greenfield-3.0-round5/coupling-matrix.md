# Round 5 — Coupling Matrix (extends R4)

## R5 additions

| Phase | Reads from | Writes to | Auto-loop |
|---|---|---|---|
| **featureRoadmap** (Step 16) | `personas.primary[]`, `domainModel.entities[]`, `risks[]` | `phases.featureRoadmap.*`; onboard later → `docs/feature-list.json` + `docs/sprint-contracts/sprint-1.json` | Per primary persona on FR.Q4-Q9 (when `mode.coupling = auto-loop`) |
| **schemaDraftReview** (Step 19) | `domainModel.entities[]`, `domainModel.domainEvents[]`, `auth.scopes[]`, `auth.roles[]`, `privacy.piiFields[]`, `apiIntegration.endpoints[]`, `apiIntegration.asyncPattern`, `runtimeOperations.observability`, `dataArchitecture.engine` | `phases.schemaDraftReview.drafts.{db,api,event}`; `crossCheckWarnings[]`; onboard later → `prisma/schema.prisma` / `docs/api/openapi.yaml` / `docs/events/event-schemas.yaml` per `outputStrategy` | Per draft (DB / API / Event) — each gets its own review pair (SDR.Q3/Q4, Q5/Q6, Q7/Q8) |

## R5 mode interactions

| `mode.depth` | `mode.coupling` | P9 effective Qs | P10.5 effective Qs | R5 total prompts |
|---|---|---|---|---|
| heavy | auto-loop | 14 base × ~3 personas ≈ ~30 | 12 | ~40+ |
| heavy | hybrid | 14 (flat) | 12 | ~26 |
| light | auto-loop | 7 base × personas ≈ ~14 | 6 | ~20 |
| light | hybrid | 7 (flat) | 6 | ~13 (lightest path) |

## R5 cross-phase dependencies (graphical summary)

```
Step 2.2 (Personas) ─────────┐
Step 2.7 (DomainModel) ──────┤
Step 6 (Privacy) ────────────┤
Step 4 (APIIntegration) ─────┤
Step 5 (Auth) ───────────────┤
Step 8 (RuntimeOps) ─────────┤
Step 3 (DataArchitecture) ───┤
                              │
                              ▼
                       ┌────────────────────────────────┐
                       │  Step 19 — auto-render hook    │
                       │  render-schema-drafts.sh       │
                       │  ↓                             │
                       │  drafts.{db,api,event}.content │
                       │  + crossCheckWarnings[]        │
                       └────────────────────────────────┘
                              │
                              ▼
                       Step 19 review (Approve/Adjust/Reject per draft)
                              │
                              ▼
                       Lock → onboard writes verbatim


Step 2.2 (Personas) ─────────┐
Step 2.7 (DomainModel) ──────┤
Step ALL (Risks) ────────────┤
                              │
                              ▼
                       ┌────────────────────────────────┐
                       │  Step 16 — featureRoadmap       │
                       │  (auto-loops per persona,       │
                       │   collects features +           │
                       │   sprint-1 contract)            │
                       └────────────────────────────────┘
                              │
                              ▼
                       onboard writes:
                         docs/feature-list.json
                         docs/sprint-contracts/sprint-1.json
```

See also: `docs/greenfield-3.0-round4/coupling-matrix.md` for R4 dependencies.
