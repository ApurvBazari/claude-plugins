# Inline Risk Q-bank — Cross-cutting (Round 4)

> **Round:** 4 (cross-cutting)
> **Scope:** 10 inline `Q_RISK` entries — 8 architectural phases (architecturalFraming, dataArchitecture, apiIntegration, auth, privacy, security, runtimeOperations, cicdAndDelivery) + 2 discovery phases (personas, domainModel).
> **Pattern:** identical shape; phase-specific prompt + tagSuggestions.
> **Mode:** always fires in both Heavy and Light modes (`showInLight: true`)
> **Persists to:** shared `risks[]` array + each phase's synthesis HTML "Risks Identified" section.
> **Reconciled at:** Step 15 Architectural Validation — Risk Reconciliation section (template fragment in `arch-val-risk-reconciliation-section.html`).
> **See also:** per-phase Q-bank files (`architectural-framing.q-bank.md`, `data-architecture.q-bank.md`, `api-integration.q-bank.md`, `auth.q-bank.md`, `privacy.q-bank.md`, `security.q-bank.md`, `runtime-operations.q-bank.md`, `cicd.q-bank.md`, `personas.q-bank.md`, `domain-model.q-bank.md`); design spec § Distributed Risk.

## Shared template

```yaml
{phaseName}.Q_RISK:
  type: free-text
  required: true
  showInLight: true
  isRiskCapture: true       # state-machine flag: append to risks[] array
  feedsIntoConsolidation: true
  prompt: "What's the biggest {phaseName} risk for THIS project?"
  charLimit: { min: 10, max: 500 }
  tagSuggestions:
    # phase-specific — see per-phase table below
```

## Per-phase tag suggestions

| Phase | Q_RISK ID | tagSuggestions |
|---|---|---|
| personas | `Persona.Q_RISK` | `compliance`, `market`, `team` |
| domainModel | `Domain.Q_RISK` | `team`, `compliance`, `vendor-lock` |
| architecturalFraming | `AF.Q_RISK` | `scaling`, `team`, `vendor-lock` |
| dataArchitecture | `Data.Q_RISK` | `scaling`, `dataloss`, `vendor-lock`, `performance` |
| apiIntegration | `Api.Q_RISK` | `performance`, `vendor-lock`, `compliance` |
| auth | `Auth.Q_RISK` | `security`, `compliance` |
| privacy | `Privacy.Q_RISK` | `compliance`, `dataloss` |
| security | `Sec.Q_RISK` | `security`, `compliance` |
| runtimeOperations | `Ops.Q_RISK` | `ops`, `scaling`, `team` |
| cicdAndDelivery | `CICD.Q_RISK` | `ops`, `scaling`, `vendor-lock` |

(Note: actual tagSuggestions per Q_RISK are authored in each phase's Q-bank file; this table is the canonical cross-reference index.)

## State machine behavior

When user answers a `Q_RISK`, the wizard:

1. Generates a new id: `R-{PHASE-UPPERCASE}-{counter}` (e.g., `R-DATAARCHITECTURE-1`).
2. Appends entry to `context.risks[]` with `originatingPhase`, `text`, optional `tags[]`, and an empty `reconciliation` block (`{ "status": null, "rationale": null }`).
3. Renders the risk in the phase's synthesis HTML "Risks Identified" section when synthesis-review runs for that phase.
4. At Step 15 Architectural Validation, the wizard loops over `context.risks[]` and asks the reconciliation Q per risk (status + rationale).

## Reconciliation status enum

The reconciliation step assigns one of these statuses:

- `mitigated` — addressed by a downstream decision (rationale cites the decision)
- `partial` — partially addressed, residual risk acknowledged (rationale cites partial)
- `accepted-explicit` — risk accepted as-is, no mitigation planned (rationale cites reason)
- `open-followup` — needs follow-up; emits a `feature-list.json` risk-followup card (rationale = recommended follow-up)
- `out-of-scope` — risk is outside the project's scope (rationale optional)
- `user-declared-none` — user proactively declared no risk for this phase

(See `risks-dependencies.json.example` for the JSON shape.)

## Edge cases

- **"No risk" responses:** if user answers with "no risk", "none", or similar negation, the wizard tags the entry as `reconciliation.status = "user-declared-none"` proactively. The reconciliation step surfaces a count summary: "3 phases declared no risk — confirm?"
- **Similarity merging:** if two phases produce semantically similar risks (similarity > 0.8 by simple lexical match — full semantic embedding deferred), wizard offers to merge at start of Reconciliation. User can decline.
- **Empty risks array:** if `context.risks[]` is empty at Step 15, the Risk Reconciliation section renders all empty buckets with `(none)` placeholders; the section still appears (not skipped).
- **Risk without tags:** `tags[]` is optional; if empty, the risk is still valid. Synthesis renders it under the originating phase without tag chips.
