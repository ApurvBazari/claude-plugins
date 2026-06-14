# Verify-Backlog Seeding — research risk/test-gap → `docs/feature-list.json` (v3)

Loaded by `config-generator` (Generation Order step 6e) **only when a sanitized `research` object is present**. Seeds the independent-verification backlog that `onboard:verify` (via the `feature-evaluator` agent) consumes. Research is the **primary** programmatic writer of `docs/feature-list.json`; seeding is **seed-if-absent** and **always runs regardless of `research.artifacts.location`** (the backlog is a generation output that feeds verification, not one of the human-readable research docs the location prompt governs).

## Source set (verified-only)

Collect every claim whose namespaced id (`<dimension>:Cn`) is in `research.verifiedClaims` and NOT in `research.droppedClaims`, where either:
- `dimension === "security"` (the whole dimension is risk surface), OR
- the claim's `category` (case-insensitive) ∈ {`risk`, `test-gap`, `security`, `hotspot`}.

De-dupe by `(dimension, id)`. Resolve each id to its finding for `statement` + `evidence` + `confidence`. Never seed a dropped/refuted claim (the verify thesis: the backlog stays adversarially-grounded).

If the source set is **empty** → write NO feature-list (do not emit an empty list). Stop here.

## Collision (seed-if-absent)

If `docs/feature-list.json` already exists → **skip + warn** (record a warning; never clobber a list that may carry `passes` progress). The harness/interactive feature-decomposition path (when `enableHarness`) is the fallback writer and likewise writes only when no list exists.

## Output shape (evaluator-readable harness shape)

Write `docs/feature-list.json` **atomically** (`.tmp` + rename):

```json
{
  "version": "1.0.0",
  "generatedBy": "onboard",
  "projectDescription": "<wizardAnswers.projectDescription>",
  "sprints": [
    {
      "name": "Sprint 1 — Risk & Test-Gap Remediation",
      "features": [
        {
          "id": "F001",
          "category": "security",
          "description": "<claim statement>",
          "steps": ["<1–3 remediation-verification steps synthesized from statement + file:line evidence>"],
          "passes": false,
          "priority": 1
        }
      ]
    }
  ]
}
```

- **`id`** — sequential `F001`, `F002`, … across the whole list.
- **`category`** — source-derived: `security` (security-dimension or `category:"security"`), `risk` (`category ∈ {risk, hotspot}`), `test-gap` (`category:"test-gap"`). Extends the harness descriptive set (`functional, ui, data, auth, …`); the `feature-evaluator` does not validate `category`, so this is a safe, documented extension.
- **`steps`** — 1–3 concrete remediation-verification steps composed from the claim `statement` + `evidence` (findings carry no mitigation field, so synthesize). Example: `"Inspect src/auth/session.ts:42; confirm the missing CSRF guard named in the claim is added; add/verify a test covering it."`
- **`priority`** — integer tier: `security` = 1, general `risk`/`hotspot` = 2, `test-gap` = 3. Order features by tier ascending, then by `confidence` descending within a tier; assign `F00N` ids in that order.
- All seeded items start **`passes: false`**.

## Telemetry

Report back to `config-generator` step 7 for the `metadata.research` block:
- `backlogSeeded` — `true` iff this run wrote `docs/feature-list.json`; `false` when skipped (collision) or empty source.
- `backlogItemCount` — number of features written (0 when not seeded).
