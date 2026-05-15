# Round 6 Cross-Phase Invariants

> **Wired into:** `grill-spec/SKILL.md` (5-category adversarial walk)
> **Severity legend:** `error` = blocks scaffold; `warn` = surfaces in grill-spec output, user can override; `info` = non-blocking suggestion
> **See also:** `check-r4-invariants.md` (R4), `check-r5-invariants.md` (R5), design spec § Cross-phase invariants

This file defines the 9 invariants introduced in Round 6 covering the 3-frontend split + 6 concern phases + 6 inline gates + CI Draft Review + auto-loop cap.

## CHECK-R6-1: Gate vendor required when needed

**Invariant:** For each `phases.<parent>.concerns.<gate>`, `needed: false` ⟹ no vendor required; `needed: true` ⟹ `vendor` is a non-empty string.

**Severity:** error
**Phases involved:** auth, uxAccessibilityPerf, cicdAndDelivery

**Detection (jq):**
```bash
jq -e '
  [ (.phases.auth.concerns // {}),
    (.phases.uxAccessibilityPerf.concerns // {}),
    (.phases.cicdAndDelivery.concerns // {}) ]
  | map(to_entries[]) | flatten
  | all(.value.needed != true or ((.value.vendor // "") | length > 0))
' "$STATE_FILE"
```

**Failure prompt:** "Gate `<gate>` marked needed=true but has no vendor selected. Fix or set needed=false."

## CHECK-R6-2: Concern phases reference at least one entity

**Invariant:** Each of `phases.{search, caching, realtime}` not marked `skipped: true` references at least one entity from `phases.dataArchitecture.entities[]`.

**Severity:** warn
**Phases involved:** search × caching × realtime × dataArchitecture

**Detection:** For each of the 3 phases, check it has a path indexing into dataArchitecture (e.g., `search.indexScope[]` non-empty when `engine != "none"`).

**Failure prompt:** "Phase `<phase>` is active but doesn't touch any entity from dataArchitecture. Confirm scope or mark skipped."

## CHECK-R6-3: Payments ⟹ privacy.pii.financial

**Invariant:** `phases.payments.provider != "none"` AND `phases.payments.skipped != true` ⟹ `phases.privacy.pii.financial == true`.

**Severity:** error
**Phases involved:** payments × privacy

**Detection (jq):**
```bash
jq -e '
  (.phases.payments.skipped != true and (.phases.payments.provider // "none") != "none")
  | if . then (.phases.privacy.pii.financial == true) else true end
' "$STATE_FILE"
```

**Failure prompt:** "Payments captured but Privacy phase did not flag financial PII. Re-run Step 12 Privacy to declare `pii.financial = true` for PCI consistency."

## CHECK-R6-4: P5 frameworkConfirmed matches architecturalFraming

**Invariant:** `phases.frontendArchitecture.frameworkConfirmed == phases.architecturalFraming.frontendFramework` (when frontendArchitecture is not skipped).

**Severity:** error
**Phases involved:** frontendArchitecture × architecturalFraming

**Detection (jq):**
```bash
jq -e '
  (.phases.frontendArchitecture.skipped != true)
  | if . then (.phases.frontendArchitecture.frameworkConfirmed == .phases.architecturalFraming.frontendFramework) else true end
' "$STATE_FILE"
```

**Failure prompt:** "Frontend Architecture confirmed `<X>` but architecturalFraming declared `<Y>`. Update one or the other to resolve stack divergence."

## CHECK-R6-5: P5.6 surfacesByPersona covers every persona

**Invariant:** Every persona ID in `phases.personas.primary[].id ∪ phases.personas.secondary[].id` appears as a key in `phases.uxAccessibilityPerf.surfacesByPersona` AND maps to a non-empty array.

**Severity:** error
**Phases involved:** uxAccessibilityPerf × personas

**Detection:**
```bash
jq -e '
  (.phases.uxAccessibilityPerf.skipped != true)
  | if . then
      ((.phases.personas.primary // []) + (.phases.personas.secondary // []) | [.[].id]) as $pids
      | $pids | all(. as $id | (.phases.uxAccessibilityPerf.surfacesByPersona[$id] // []) | length > 0)
    else true end
' "$STATE_FILE"
```

**Failure prompt:** "Persona `<id>` has no UX surface mapping. Re-run Step 24 UX/A11y/Perf to define surfaces for this persona."

## CHECK-R6-6: i18n locales ⟹ translation strategy committed

**Invariant:** `phases.i18nL10n.targetLocales[]` non-empty ⟹ all synthesis docs that reference user-facing copy commit to a translation strategy (`translationSource != "none"`, `library != "none"`).

**Severity:** warn
**Phases involved:** i18nL10n × any phase with user-facing copy

**Failure prompt:** "i18n declares locales but no translation strategy. Set `translationSource` and `library` in Step 25."

## CHECK-R6-7: Plugin recommendation covers each needed gate's vendor

**Invariant:** For every `concerns.<gate>` with `needed: true`, if the marketplace has an integration plugin for `vendor`, `phases.pluginRecommendation.suggested` includes it.

**Severity:** info
**Phases involved:** pluginRecommendation × all gates

**Detection:** Best-effort string match between `concerns.<gate>.vendor` and `pluginRecommendation.suggested[]`. Non-blocking — surfaces as a suggestion.

## CHECK-R6-8: LLM-fallback CI requires addressed warnings

**Invariant:** When `phases.cicdAndDelivery.draftFallback == true` AND `lockedYaml != null`, every `draftWarnings[]` entry has `addressed == true`.

**Severity:** error
**Phases involved:** cicdAndDelivery

**Detection (jq):**
```bash
jq -e '
  (.phases.cicdAndDelivery.draftFallback // false)
  | if . then
      (.phases.cicdAndDelivery.lockedYaml // null) == null
      or ((.phases.cicdAndDelivery.draftWarnings // []) | all(.addressed == true))
    else true end
' "$STATE_FILE"
```

**Failure prompt:** "CI Draft Review used the LLM-fallback path. Approve is blocked until every warning is marked addressed. Re-enter Step 20 to resolve."

## CHECK-R6-9: Auto-loop iteration cap

**Invariant:** For each concern phase that auto-loops per persona (`realtime`, `fileUploads`, `payments`, `frontendArchitecture`, `uxAccessibilityPerf`), `loopIterations <= min(personas.length, 4)`.

**Severity:** error
**Phases involved:** any auto-looping phase × personas

**Detection (jq):**
```bash
jq -e '
  ((.phases.personas.primary // []) | length) as $plen
  | (if $plen > 4 then 4 else $plen end) as $cap
  | [ .phases.realtime.loopIterations // 0,
      .phases.fileUploads.loopIterations // 0,
      .phases.payments.loopIterations // 0,
      .phases.frontendArchitecture.loopIterations // 0,
      .phases.uxAccessibilityPerf.loopIterations // 0 ]
  | all(. <= $cap)
' "$STATE_FILE"
```

**Failure prompt:** "Phase `<phase>` recorded `loopIterations=<N>` but cap is `<cap>`. State corrupted; manual inspection required."
