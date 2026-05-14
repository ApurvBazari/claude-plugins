# Round 4 Cross-Phase Invariants

This document defines the cross-phase invariants that grill-spec checks AFTER Step 15.2 (architectural validation cross-phase invariant check). Each invariant has a severity (hard-fail blocks final sign-off; warn surfaces but allows continue; suggestion is informational only).

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
- **Source phases:** mode.coupling + all downstream auto-loop phases (auth, privacy, dataArchitecture, apiIntegration, security, runtimeOperations)
- **Predicate:**

```
if mode.coupling == "auto-loop":
  forall downstream phase D in [auth, privacy, dataArchitecture, apiIntegration]:
    forall answer A in <D>.<looped-Q> where derivedFrom is set:
      assert <D>.dependencies.json contains entry where
             entry.path matches answer.path
             AND entry.sourceRef.phase ∈ {"personas", "domainModel"}
             AND entry.sourceRef.id matches answer.derivedFrom
```

- **Message on fail:** "Auto-loop coupling expected sourceRef trace in {phase}.{path}, but dependencies.json has no matching entry. State machine bug — file an issue at https://github.com/ApurvBazari/claude-plugins/issues."

## CHECK-R4-4 — Every captured risk has reconciliation status

- **Severity:** hard-fail
- **Source phases:** risks (any) + architecturalValidation.riskReconciliation
- **Predicate:**

```
forall r in risks:
  assert r.reconciliation.status is set
  assert r.reconciliation.status in [
    "mitigated", "partial", "accepted-explicit", "open-followup", "out-of-scope", "user-declared-none"
  ]
```

- **Message on fail:** "Risk {r.id} ({r.text}) has no reconciliation status. Run Step 15 Risk Reconciliation before signing off."

## CHECK-R4-5 — No auth.access[] rule for unknown entity

- **Severity:** warn
- **Source phases:** auth + domainModel
- **Predicate:**

```
forall rule in auth.access:
  if rule.entityId is set:
    assert exists e in domainModel.entities where e.id == rule.entityId
```

- **Message:** "Auth rule references entity {rule.entityId} which doesn't exist in domain model. Likely typo or entity removed in a later Adjust mode pass."

## CHECK-R4-6 — Bounded-contexts count ≤ entities count

- **Severity:** warn
- **Source phases:** domainModel
- **Predicate:** `domainModel.contexts.length <= domainModel.entities.length`
- **Message:** "Bounded contexts ({contexts.length}) exceed entity count ({entities.length}). Likely over-engineering — consider consolidating contexts via /greenfield:pickup → Adjust mode."

## CHECK-R4-7 — Anti-persona name uniqueness

- **Severity:** warn
- **Source phases:** personas
- **Predicate:** anti-persona names (top-level `personas.antiPersonas[]` array) don't collide with primary or secondary persona names (case-insensitive).
- **Message:** "Anti-persona '{name}' has the same name as a primary/secondary persona. Use a different name to avoid confusion in downstream synthesis rendering."

## CHECK-R4-8 — Light + DDD-lite suggests Hybrid coupling

- **Severity:** suggestion (not blocking)
- **Source phases:** mode (any)
- **Predicate:** if `mode.depth == "light"` AND `mode.domainFormat == "ddd-lite"` AND `mode.coupling == "auto-loop"`
- **Message:** "Auto-loop coupling with Light depth + DDD-lite domain is wasteful (sparse persona/entity data + many loops = low value, high time). Consider switching coupling to Hybrid via /greenfield:pickup → Adjust mode."
