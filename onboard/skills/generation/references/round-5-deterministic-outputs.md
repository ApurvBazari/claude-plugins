<!-- Extracted from generation/SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Round 5 — deterministic outputs from featureRoadmap + schemaDraftReview

## Round 5 — deterministic outputs from featureRoadmap + schemaDraftReview

When the v2 context carries populated R5 phases, onboard generates the feature roadmap artifacts and schema/contract files **deterministically** instead of through interactive prompts. Pre-R5 (alpha.5) contexts continue to use the interactive flow below as fallback.

### Round 5 — feature-list.json + sprint-1.json (deterministic)

**Run condition:** `context.phases.featureRoadmap.skipped != true` AND `context.phases.featureRoadmap.features` is non-empty.

**Step A — write `docs/feature-list.json`:**

Direct field-by-field map from `phases.featureRoadmap`. Build the JSON as:

```json
{
  "schemaVersion": 1,
  "generatedAt": "<ISO8601 generation timestamp>",
  "features": [
    {
      "id": "<features[].id>",
      "title": "<features[].title>",
      "category": "<features[].category>",
      "epicId": "<features[].epicId>",
      "personaIds": "<features[].personaIds>",
      "entityIds": "<features[].entityIds>",
      "riskIds": "<features[].riskIds>",
      "size": "<features[].size>",
      "acceptanceCriteria": "<features[].acceptanceCriteria>",
      "verificationSteps": "<features[].verificationSteps>",
      "sprintAssignment": "<features[].sprintAssignment>"
    }
  ],
  "epics": "<phases.featureRoadmap.epics>"
}
```

mkdir -p `docs/` if absent. Atomic write via `.tmp + rename`.

**Step B — write `docs/sprint-contracts/sprint-1.json`:**

```json
{
  "sprint": 1,
  "name": "<phases.featureRoadmap.sprint1.name>",
  "negotiatedAt": "<ISO8601 generation timestamp>",
  "features": "<phases.featureRoadmap.sprint1.featureIds>",
  "criteria": "<phases.featureRoadmap.sprint1.criteria>",
  "completionGate": "<phases.featureRoadmap.sprint1.completionGate>"
}
```

mkdir -p `docs/sprint-contracts/` if absent. Atomic write.

**Backward compatibility:** If `featureRoadmap.skipped = true` OR `features[]` is empty, fall back to the interactive handoff flow below — onboard prompts the developer for features and sprint-1 contract as it did pre-R5.

**Sprint-2..N contracts:** unchanged from pre-R5. Interactively negotiated at sprint boundaries per `references/sprint-contracts.md`. R5 only changes how sprint-1 is born.

### Round 5 — schema/contract files (deterministic)

**Run condition:** `context.phases.schemaDraftReview.skipped != true` AND `context.phases.schemaDraftReview.lockedAt` is set (non-empty ISO-8601 string).

For each `artifact` in `["db", "api", "event"]`:

1. Skip if `drafts.{artifact}.skipped = true` OR `drafts.{artifact}.approved != true`.
2. Resolve the output path from `phases.schemaDraftReview.languages.{artifact}` + `outputStrategy`:

| Artifact | Language | outputStrategy=`project-root` | outputStrategy=`docs-drafts` |
|---|---|---|---|
| db | prisma | `prisma/schema.prisma` | `docs/drafts/schema.prisma` |
| db | sql-ddl | `sql/migrations/0001_init.sql` | `docs/drafts/schema.sql` |
| api | openapi-3.0 | `docs/api/openapi.yaml` | `docs/drafts/openapi.yaml` |
| api | graphql-sdl | `schema.graphql` | `docs/drafts/schema.graphql` |
| event | asyncapi | `docs/events/event-schemas.yaml` | `docs/drafts/event-schemas.yaml` |
| event | json-schema | `docs/events/event-schemas.json` | `docs/drafts/event-schemas.json` |

3. mkdir -p the parent directory if absent.
4. Write `drafts.{artifact}.content` **verbatim** to the resolved path. No transformation — the wizard's renderer script produced finished content; onboard preserves it byte-for-byte.
5. Atomic write via `.tmp + rename`.

**Backward compatibility:** If `schemaDraftReview.skipped = true` OR `lockedAt` is absent, onboard writes NO schema/contract files. Pre-R5 projects do not get these artifacts.

**Failure modes:**
- If `drafts.{X}.content` is empty when `approved = true` (shouldn't happen, but possible if state file is hand-edited): log a warning, skip that artifact, do not block the rest of generation.
- If the resolved path collides with an existing user file: log the collision; do NOT overwrite without confirmation; surface to the developer via the generation report.
