# State JSON Schema Evolution Policy

## Overview

Greenfield persists its state to `.claude/greenfield-state.json` at every checkpoint. This document defines the policy for managing schema changes across greenfield versions and the contractual guarantee that resumable sessions always work.

**This is the state JSON owner's contract with scaffolded projects.** Schema changes are allowed—but must follow a strict two-phase evolution policy depending on release maturity (alpha vs stable).

---

## Two-Phase Policy

### Phase 1: Alpha Releases (3.0.0-alpha.X)

**During alpha, schema changes are allowed without automatic migration.**

- Breaking changes are permitted; they are called out explicitly in the CHANGELOG with a "Schema breakage" section.
- In-flight greenfield sessions from older alpha versions become **incompatible** with newer alphas.
- **Hard cutover**: when `pickup` detects a version mismatch, it emits a clear error and halts. Users must restart with `/greenfield:start`.
- **No automatic upgrade**: there is no migration framework during alpha. State JSONs are immutable during their alpha version; if the schema changes, the old state is left as-is.
- **User notification**: a new alpha release bump is advertised in the CHANGELOG. Users with in-flight sessions are informed they may need to restart via the version-check error in `pickup`.

**Rationale**: alpha releases are rapid iteration. Baking migration logic for every schema change would slow development. Users expect volatility during alpha; a clean restart is an acceptable cost.

---

### Phase 2: Stable Releases (3.0.0 onward)

**Starting with 3.0.0 stable, every schema-changing release ships a migration function.**

- Old state JSONs are **automatically upgraded** on resume.
- The `pickup` skill applies migrations sequentially to bring a state file from any prior stable version to the current version.
- Backups are created before migration: `.claude/greenfield-state.json.pre-migration.{ISO-8601-timestamp}.bak`.
- **No user intervention required**: the schema evolution is invisible during normal use.
- New optional fields are safe; required fields are never added in a breaking way mid-version (new required fields only ship as major bumps).

**Rationale**: stable releases promise compatibility. Users may have long-running projects; forcing a restart is unacceptable. Automatic migration maintains the resume contract.

---

## Schema Versioning

Every state JSON carries a `schemaVersion` field at the root, set by the `start` skill on initialization:

```json
{
  "schemaVersion": 1,
  "createdAt": "ISO-8601 timestamp",
  "updatedAt": "ISO-8601 timestamp",
  "currentPhase": "...",
  "currentStep": "...",
  "completedSteps": [],
  "context": {},
  "researchFindings": {},
  "parkedQuestions": [],
  "nextAction": "",
  "research": { "mode": "main-session" }
}
```

The `schemaVersion` is **independent of the greenfield plugin version**. It tracks schema evolution only; the plugin version in `plugin.json` tracks feature releases and bug fixes.

**Convention**: increment `schemaVersion` whenever:
- Fields are renamed
- Fields are removed
- Field types change
- Required fields are added
- Enum values become invalid

Do NOT increment when:
- New optional fields are added
- New values are added to enums of optional fields
- Documentation changes

---

## Alpha Hard-Cutover Protocol

When `pickup` detects a schema version mismatch during alpha:

1. Read `schemaVersion` from `.claude/greenfield-state.json` on startup.
2. Compare to the **expected schema version** (defined as a constant, e.g., `CURRENT_SCHEMA_VERSION = 1`).
3. If versions do not match:
   ```
   ⚠️  This wizard session was saved by a different greenfield version.
   Detected schemaVersion: 0 | Expected: 1
   
   During alpha (3.0.0-alpha.X), schema changes are not migrated.
   Restart with /greenfield:start.
   
   See greenfield/skills/start/references/state-schema-evolution.md for the policy.
   ```
4. Halt the resume flow. Do not attempt recovery.
5. The user runs `/greenfield:start` to begin a fresh session.

---

## Stable Migration Protocol (Post-3.0.0)

When `pickup` detects a schema version mismatch in a stable release:

1. Read `schemaVersion` from `.claude/greenfield-state.json`.
2. Compare to the current expected version.
3. If a mismatch is detected:
   a. Create a backup: `.claude/greenfield-state.json.pre-migration.{timestamp}.bak`
   b. Apply migrations sequentially:
      - For each version from (detected + 1) to (expected), load the corresponding migration function from `greenfield/skills/pickup/migrations/`.
      - Each migration transforms the state in-place (e.g., `migrations/0-to-1.md` or `migrations/0-to-1.sh` or inline code).
      - If any migration fails, restore from backup and emit an error.
   c. Increment `schemaVersion` in the state to match the current version.
   d. Update `updatedAt` to the migration timestamp.
   e. Write the upgraded state to `.claude/greenfield-state.json`.
   f. Proceed with resume normally.
4. If no mismatch, proceed directly to the resume flow.

**Migration artifacts**: each schema change ships a migration in one of these formats:

- **Descriptive file** (`N-to-N+1.md`): documents the change, what fields were affected, and the reasoning.
- **Script** (`N-to-N+1.sh` or `N-to-N+1.py`): executable transformation. Input: old state JSON (stdin or file). Output: upgraded state JSON.
- **Inline transformation**: embedded in the `pickup` skill as a conditional block (for small, one-off migrations).

The descriptive file ALWAYS ships (required); the executable is optional if the transformation is simple enough to inline in `pickup`.

---

## What Counts as a Breaking Schema Change

### Breaking (increment schemaVersion)

- **Rename**: `context.stackName` → `context.stackId` (requires field lookup transform)
- **Remove**: field is deleted; recovery is only possible from backup
- **Type change**: `isProduction: boolean` → `isProduction: string | boolean` (old clients may assume old type)
- **Required addition**: a new field becomes mandatory for downstream skills (old state JSONs fail)
- **Enum restriction**: an optional field's enum values shrink (e.g., `"dataArchitecture" | "apiIntegration" | "cicdAndDelivery"` → `"dataArchitecture" | "apiIntegration"`)
- **Restructure**: a nested object is flattened or vice versa (e.g., `context.deploy.target` → `context.deployTarget`)

### Non-breaking (do NOT increment schemaVersion)

- **New optional field**: `"additionalMetadata": {}` (old clients safely ignore it)
- **New enum value**: add `"P9"` to `currentSynthesisPhase` (old clients won't produce this value)
- **Field documentation change**: e.g., clarifying what `nextAction` should contain
- **New internal field**: a field used only by greenfield (not referenced by external tools) is safe to add

---

## Stub: Migration Directory (Empty During Alpha)

```
greenfield/skills/pickup/migrations/
├── 0-to-1.md         ← (created when first stable→stable bump occurs)
├── 0-to-1.sh         ← (optional; if transformation is complex)
├── 1-to-2.md
├── 1-to-2.py
└── README.md         ← index of all migrations
```

**During alpha (3.0.0-alpha.X)**: this directory does NOT exist or is empty. The hard-cutover protocol applies; no migrations are expected.

**Starting with first stable→stable bump after 3.0.0**: migration files are created as needed. Each file is named `N-to-N+1.*` where N is the source schemaVersion.

**Migration index**: `greenfield/skills/pickup/migrations/README.md` documents which greenfield versions created which migrations:

```markdown
# State Schema Migrations

| From | To | Greenfield | Change | Migration file |
|------|----|-----------|---------|----|
| 0 | 1 | 3.0.0 → 3.0.1 | Added `architecturalFraming` completedStep | `0-to-1.md` |
| 1 | 2 | 3.1.0 → 3.1.1 | Renamed `context.deploy.mode` → `context.deployMode` | `1-to-2.sh` |
```

---

## Round 2.5 Breaking Changes (Alpha)

Greenfield 3.0.0-alpha.3 (Round 2.5) will introduce multiple schema-breaking changes:

- **PRE-5 (T9)**: `phaseStatus` map added. `currentPhase` tracking changes from a string to a phase-status object with `status: "in-progress" | "complete" | "skipped"` and optional metadata.
- **PRE-2 (T5/T6)**: two new `completedSteps` values: `"step-3-architectural-framing"` and `"step-4-architectural-validation"`. Clients expecting a fixed set of step names will fail.
- **PRE-6 (T11)**: defaults-driven flow markers. New context fields like `autoResume: boolean` drive conditional phase skips. Old state JSONs lack these fields.

**Impact on in-flight alpha.2 sessions**: users with `.claude/greenfield-state.json` created by alpha.2 will see the hard-cutover error when they resume with alpha.3. They must restart via `/greenfield:start`.

**User notification**: the CHANGELOG entry for alpha.3 will include a "Schema breakage" section; the version-check error in `pickup` will point them to this doc and to the CHANGELOG.

---

## Canonical Policy Reference

This document is the **single source of truth** for schema evolution. All CHANGELOG entries that announce schema changes link here:

> **Schema breakage**: [list of changes]. See [state-schema-evolution.md](greenfield/skills/start/references/state-schema-evolution.md) for the alpha vs stable policy.

---

## Design Notes

- **Why per-project state?** Greenfield state is tied to a specific scaffold. If state were global, concurrent projects would overwrite each other's checkpoints.
- **Why JSON, not YAML?** The wizard updates state frequently; JSON parse/stringify is universal and fast. YAML adds no value.
- **Why a separate `schemaVersion` field?** The greenfield plugin version (`plugin.json`) tracks features and bug fixes; the state schema version tracks persistence format only. They evolve independently.
- **Why hard-cutover during alpha?** Alpha iterations are rapid. Baking migration logic for every schema bump would slow development. Users expect volatility; a clean restart is acceptable.
- **Why automatic migration in stable?** Stable releases promise compatibility. Users may have long-running projects; forcing a restart is unacceptable.
