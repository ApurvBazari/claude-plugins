# Stale-Flag Detection & Propagation

This document specifies the dependency-graph traversal logic that powers the stale-flag mechanism introduced in Greenfield 3.0 Round 2.5 (Decision 4: "Stale-flag with explicit re-walk choice").

## Purpose

When a developer Adjusts a phase in synthesis-review, downstream phases that read changed fields are marked `stale`. On next entry, the wizard prompts a re-walk so the developer can decide whether the changed values invalidate the downstream synthesis record.

---

## Context structure required

The algorithm operates on the in-memory `context` object (backed by `greenfield-state.json`). Two fields are relevant:

1. **`context.phaseStatus`** — map of `phaseId → PhaseStatusRecord`. Added in T9.
2. **`context.dependencies[phaseId]`** — list of cross-phase dependency paths a phase reads from. Written by synthesis-review Step 3 (the `dependencies.json` sidecar). Available in-memory as the array of `{ path, value }` entries for the phase.

---

## PhaseStatusRecord shape

```jsonc
{
  "status": "not-yet-walked",      // enum (see below)
  "approvedAt": null,              // ISO-8601 string when status === "approved" or "approved-with-noted-divergences"
  "lastModified": "ISO-8601",      // ISO-8601 string, updated on every status transition
  "staleReason": null              // string when status === "stale"; null otherwise
}
```

**Status enum** (aligned with `architecturalValidation.signOffStatus` where they overlap):

| Value | Meaning |
|---|---|
| `not-yet-walked` | Phase wizard step has not yet been reached in this session |
| `in-progress` | Phase wizard step is currently being walked (context captures are partial) |
| `approved` | Synthesis reviewed and approved (all sections Approve/Adjust/Skip) |
| `stale` | Phase was previously approved but a dependency has changed since approval |
| `approved-with-noted-divergences` | Synthesis approved with recorded divergences (maps to architecturalValidation `signOffStatus`) |
| `requires-rework` | Developer sent the spec back to rework during architectural validation |

---

## Phase dependency map

The following table shows which fields each phase reads from earlier phases. This is the canonical in-memory reverse-dependency graph used by the propagation algorithm. It must be kept in sync with the cross-check annotations in the synthesis templates and `dependencies-schema.json` sidecars.

| Phase (reader) | Depends on paths in earlier phases |
|---|---|
| `dataArchitecture` | `architecturalFraming.topology`, `architecturalFraming.deploymentShape`, `vision.willDeploy` |
| `apiIntegration` | `architecturalFraming.topology`, `dataArchitecture.cache`, `dataArchitecture.engine` |
| `cicdAndDelivery` | `architecturalFraming.scaleTarget`, `architecturalFraming.deploymentShape`, `vision.willDeploy`, `vision.teamSize` |
| `architecturalValidation` | `architecturalFraming.topology`, `architecturalFraming.deploymentShape`, `architecturalFraming.scaleTarget`, `dataArchitecture.databaseHost`, `dataArchitecture.orm`, `dataArchitecture.migrationsTool`, `dataArchitecture.cache`, `apiIntegration.asyncPattern`, `apiIntegration.style`, `cicdAndDelivery.cicd.envLadder`, `cicdAndDelivery.cicd.releasePipeline.separate` |

> Note: `vision` is the pre-wizard top-level context (not a wizard phase proper), so it is not tracked in `phaseStatus`. Its fields are stable after Step 1 and do not trigger stale propagation in this round.

---

## Propagation algorithm (pseudocode)

This pseudocode runs in `synthesis-review/SKILL.md` **Step 7** after a phase P is adjusted and its changes are committed to `context.phases[P]`.

```
INPUT: adjustedPhaseId P, changedFields[] (list of dot-paths that changed, e.g. ["architecturalFraming.topology"])

FUNCTION propagate_stale(P, changedFields):
  staleCount = 0
  now = current ISO-8601 timestamp

  FOR each phaseId Q in context.phaseStatus WHERE Q !== P:
    currentStatus = context.phaseStatus[Q].status

    # Only propagate to phases that have already been approved
    IF currentStatus NOT IN ["approved", "approved-with-noted-divergences"]:
      CONTINUE  # not-yet-walked, in-progress, stale, requires-rework: skip

    # Load the dependency list for Q from its dependencies.json sidecar or in-memory cache
    depsForQ = context.dependencies[Q]  # array of { path, value } entries

    # Check if any of Q's dependencies intersects with the changed fields in P
    matchedField = null
    FOR each dep IN depsForQ:
      FOR each changedPath IN changedFields:
        IF dep.path STARTS WITH (P + ".") AND dep.path === changedPath:
          matchedField = dep.path
          BREAK
      IF matchedField: BREAK

    IF matchedField IS NOT null:
      context.phaseStatus[Q].status = "stale"
      context.phaseStatus[Q].lastModified = now
      context.phaseStatus[Q].staleReason = P + "." + last_segment(matchedField) + " changed"
      staleCount += 1

  RETURN staleCount

# Caller (synthesis-review Step 7) calls:
n = propagate_stale(phaseId, changedFields)
IF n > 0:
  EMIT "Marked " + n + " phase(s) stale due to adjustments in " + phaseId
```

---

## Rules for propagation

1. **Never propagate to `not-yet-walked` or `in-progress` phases.** Those are pre-state — they have not yet established an assumption set to be invalidated.
2. **Never propagate to a phase that is already `stale`.** Double-marking is idempotent but wastes cycles and could overwrite a more precise `staleReason` from an earlier propagation. Skip it.
3. **Never propagate backward (to an upstream phase).** A downstream phase becoming stale does not retroactively stale its own upstreams.
4. **`staleReason` is single-field only.** If multiple changed fields in P affect Q, capture the first matching one. The developer can see all changes in the field-level diff on re-walk.
5. **Propagation is not recursive.** If marking Q stale would logically also stale R (Q depends on R), this round does NOT chain-propagate. The developer's re-walk of Q will naturally produce a new adjustment event that then propagates to R. Chain propagation is reserved for a future round once the graph is more mature.
6. **`approvedAt` is NOT cleared on stale.** It preserves the timestamp of when the phase was last properly approved — useful for auditing how long a phase has been stale.

---

## Field-level diff capture

Before the propagation runs, the adjust-dialog returns a structured diff. The diff is captured in `context.adjustmentDiffs[phaseId][sectionId]`:

```jsonc
{
  "before": "<original value>",
  "after": "<adjusted value>",
  "field": "<dot-path within the phase, e.g. architecturalFraming.topology>"
}
```

The `field` value is what becomes the `changedFields[]` input to `propagate_stale`. If a single adjust-dialog interaction touches multiple fields (multi-field section), all changed paths are included in `changedFields`.

---

## Entry-guard check (on next phase entry)

When `synthesis-review` (or `context-gathering`) is about to enter a phase Q:

```
IF context.phaseStatus[Q].status === "stale":
  SHOW: "The {Q} synthesis references {staleReason} which changed since it was approved."
  ASK (AskUserQuestion): "Re-walk this phase? (Recommended) / Skip and keep current synthesis"
  IF user chooses "Skip":
    SET synthesisStatus = "stale-deferred"
    RETURN control to caller; do NOT continue into the phase wizard
  IF user chooses "Re-walk":
    CLEAR context.phaseStatus[Q].staleReason
    SET context.phaseStatus[Q].status = "in-progress"
    CONTINUE into normal phase wizard flow
```

The `stale-deferred` status is ephemeral — it is NOT written to `phaseStatus.status` (that field keeps its `stale` value so the next entry picks it up again). It is only used in the immediate return value to tell the caller to skip.

---

## Initial state (on session start)

When `greenfield/skills/start/SKILL.md` writes the first checkpoint, `phaseStatus` is initialized as an empty map `{}`. Phases are added to the map when they are first reached:

- On entering Step 2.5 → add `architecturalFraming: { status: "in-progress", ... }`
- On synthesis-review approval → set `status: "approved"`, write `approvedAt`
- On adjustment committed + propagation → downstream phases transition to `stale`

---

## staleTrackingMode per phase dependency

The `dependencies-schema.json` supports an optional `staleTrackingMode` field on the per-phase dependency record. The propagation algorithm respects it:

| Value | Behavior |
|---|---|
| `"all"` | Any field change in the source phase marks this dependency stale |
| `"explicit"` | Only changes to the specifically listed `path` trigger stale marking (default) |

When `staleTrackingMode` is absent, it defaults to `"explicit"`.
