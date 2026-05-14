# Round 5 Cross-Phase Invariants

> **Wired into:** `grill-spec/SKILL.md` (5-category adversarial walk)
> **Severity legend:** `error` = blocks scaffold; `warn` = surfaces in grill-spec output, user can override
> **See also:** `check-r4-invariants.md` (R4 invariants), design spec § Cross-phase invariants

This file defines the 6 invariants introduced in Round 5 covering the new featureRoadmap (Step 16) and schemaDraftReview (Step 19) phases and their cross-phase dependencies on personas, domainModel, risks, dataArchitecture, apiIntegration, auth, and privacy.

## CHECK-R5-1: Roadmap referential integrity

**Invariant:** All `featureRoadmap.features[].personaIds[]` resolve to existing `personas.primary[].id` ∪ `personas.secondary[].id`; all `entityIds[]` resolve to `domainModel.entities[].id`; all `riskIds[]` resolve to `risks[].id`.

**Severity:** error
**Phases involved:** featureRoadmap × personas × domainModel × risks

**Detection (jq):**
```
jq -e '
  (.phases.personas.primary // []) + (.phases.personas.secondary // []) | [.[].id] as $pids
  | [.phases.domainModel.entities // [] | .[].id] as $eids
  | [.risks // [] | .[].id] as $rids
  | [.phases.featureRoadmap.features // [] | .[] |
      ((.personaIds // [])[] | select(. as $x | $pids | index($x) | not)),
      ((.entityIds // [])[] | select(. as $x | $eids | index($x) | not)),
      ((.riskIds // [])[] | select(. as $x | $rids | index($x) | not))
    ] | length == 0
' "$STATE_FILE"
```

**Failure prompt:** "Feature `<feature.id>` references `<personaId|entityId|riskId>` which does not exist. Fix the reference or remove."

## CHECK-R5-2: Sprint/epic referential integrity

**Invariant:** All `featureRoadmap.sprint1.featureIds[]` resolve to existing `featureRoadmap.features[].id`; all `features[].epicId` (when set) resolves to `featureRoadmap.epics[].id`; epic IDs unique.

**Severity:** error
**Phases involved:** featureRoadmap (intra-phase)

**Detection:** Confirm unique `epics[].id`; confirm sprint1.featureIds ⊆ features[].id; confirm every non-null `features[*].epicId` ∈ `epics[].id`.

**Failure prompt:** "Sprint-1 references feature ID `<id>` that doesn't exist." OR "Feature `<id>` has `epicId: <epicId>` but no matching epic." OR "Epic IDs are not unique: `<duplicate>`."

## CHECK-R5-3: P10.5 applicableArtifacts consistent with upstream

**Invariant:**
- `applicableArtifacts` includes `db` if and only if `dataArchitecture.engine != "none"`
- `applicableArtifacts` includes `api` if and only if `apiIntegration.endpoints[]` non-empty OR `apiIntegration.asyncPattern != "none"`
- `applicableArtifacts` includes `event` if and only if `domainModel.domainEvents[]` non-empty

**Severity:** warn (advisory — user may have valid reasons to include/exclude regardless)
**Phases involved:** schemaDraftReview × dataArchitecture × apiIntegration × domainModel

**Failure prompt:** "Step 19 `applicableArtifacts` includes `<art>` but upstream phase suggests it should be skipped (or vice versa). Confirm or remove."

## CHECK-R5-4: P10.5 lock gate

**Invariant:** When `schemaDraftReview.lockedAt` is set, every enabled draft (`drafts.{X}.skipped != true`) has `approved = true` AND every `level=error` warning has `addressed = true`.

**Severity:** error
**Phases involved:** schemaDraftReview (intra-phase)

**Detection (jq):**
```
jq -e '
  if (.phases.schemaDraftReview.lockedAt // "") == "" then true
  else
    ([.phases.schemaDraftReview.drafts | to_entries[] |
       select(.value.skipped != true) |
       .value.approved == true] | all)
    and
    ([.phases.schemaDraftReview.crossCheckWarnings // [] |
       .[] | select(.level == "error") |
       .addressed == true] | all)
  end
' "$STATE_FILE"
```

**Failure prompt:** "Step 19 is locked (`lockedAt` set) but `<draft|warning>` is `<unapproved|unaddressed>`. Unlock to fix, or address the gap."

## CHECK-R5-5: P9 sizing consistency

**Invariant:** `featureRoadmap.sizingScale` is consistent with feature `size` field presence:
- `tshirt` → every feature has `size ∈ {"S", "M", "L", "XL"}`
- `none` → no feature has a `size` field set
- `fibonacci` → every feature has a numeric `size`
- `hours` → every feature has a numeric `size`

**Severity:** warn
**Phases involved:** featureRoadmap (intra-phase)

**Failure prompt:** "Sizing scale is `<scale>` but feature `<id>` has `size=<value>` which doesn't match expected shape. Reconcile or change scale."

## CHECK-R5-6: P9 render budget

**Invariant:** `featureRoadmap.features[].length <= 100`.

**Severity:** warn (surfaces a consolidation prompt; not blocking)
**Phases involved:** featureRoadmap (intra-phase)

**Failure prompt:** "featureRoadmap has `<N>` features (cap is 100). Consider consolidating before locking the roadmap — too many features dilutes sprint planning and bloats `feature-list.json`."

## Wiring into grill-spec

`grill-spec/SKILL.md` should reference this file alongside `check-r4-invariants.md` in the 5-category adversarial walk. Place CHECK-R5-1 + CHECK-R5-2 + CHECK-R5-6 in the "roadmap-integrity" category and CHECK-R5-3 + CHECK-R5-4 + CHECK-R5-5 in the "schema-coherence" category (or whichever existing categories grill-spec uses — adapt as needed).
