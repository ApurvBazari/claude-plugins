#!/usr/bin/env bash
# tests/round-4/migration-test.sh
#
# Round 4 alpha.4 → alpha.5 state-migration smoke driver.
# Validates that migration-alpha4-fixture.json is a clean alpha.4 state
# (no R4 fields present) and documents the manual verification steps the
# operator runs in a real Claude Code session.

set -euo pipefail

cd "$(dirname "$0")/../.."

FIXTURE="tests/round-4/migration-alpha4-fixture.json"

# 1. Fixture exists + parses
test -f "$FIXTURE" || { echo "[FAIL] fixture not found: $FIXTURE"; exit 2; }
jq . "$FIXTURE" > /dev/null
echo "[✓] fixture parses as JSON"

# 2. schemaVersion is alpha.4
SCHEMA_VERSION=$(jq -r '.schemaVersion // "absent"' "$FIXTURE")
if [ "$SCHEMA_VERSION" != "alpha.4" ]; then
  echo "[FAIL] expected schemaVersion = alpha.4, got: $SCHEMA_VERSION"
  exit 1
fi
echo "[✓] schemaVersion: alpha.4 (migration shim trigger)"

# 3. NO top-level mode block
HAS_MODE=$(jq 'has("mode")' "$FIXTURE")
[ "$HAS_MODE" = "false" ] || { echo "[FAIL] fixture has top-level 'mode' block (should be absent for alpha.4)"; exit 1; }
echo "[✓] no top-level mode block (clean alpha.4)"

# 4. NO top-level risks array
HAS_RISKS=$(jq 'has("risks")' "$FIXTURE")
[ "$HAS_RISKS" = "false" ] || { echo "[FAIL] fixture has top-level 'risks' array (should be absent for alpha.4)"; exit 1; }
echo "[✓] no top-level risks array"

# 5. NO phases.personas / phases.domainModel
HAS_PERSONAS=$(jq '.context.phases | has("personas")' "$FIXTURE")
HAS_DOMAIN_MODEL=$(jq '.context.phases | has("domainModel")' "$FIXTURE")
[ "$HAS_PERSONAS" = "false" ] && [ "$HAS_DOMAIN_MODEL" = "false" ] || {
  echo "[FAIL] fixture has R4 phase blocks (personas=$HAS_PERSONAS domainModel=$HAS_DOMAIN_MODEL)"; exit 1;
}
echo "[✓] no phases.personas / phases.domainModel"

# 6. NO architecturalValidation.riskReconciliation
HAS_RISK_RECON=$(jq '.context.phases.architecturalValidation | has("riskReconciliation")' "$FIXTURE")
[ "$HAS_RISK_RECON" = "false" ] || { echo "[FAIL] fixture has architecturalValidation.riskReconciliation (should be absent for alpha.4)"; exit 1; }
echo "[✓] no architecturalValidation.riskReconciliation"

# 7. R1-R3 phases populated
R1_R3_COUNT=$(jq '[.context.phases.architecturalFraming, .context.phases.dataArchitecture, .context.phases.apiIntegration, .context.phases.auth, .context.phases.privacy, .context.phases.security, .context.phases.runtimeOperations, .context.phases.cicdAndDelivery, .context.phases.architecturalValidation] | length' "$FIXTURE")
[ "$R1_R3_COUNT" = "9" ] || { echo "[FAIL] expected 9 R1-R3 phase blocks, got: $R1_R3_COUNT"; exit 1; }
echo "[✓] 9 R1-R3 phase blocks populated"

# 8. vision.users[] present (T24 demotion will surface this at Step 2.2 entry)
VISION_USERS_COUNT=$(jq '.context.vision.users | length' "$FIXTURE")
[ "$VISION_USERS_COUNT" -ge 1 ] || { echo "[FAIL] expected vision.users[] populated for T24 conversion-prompt test"; exit 1; }
echo "[✓] vision.users[] populated (${VISION_USERS_COUNT} entries — will trigger T24 conversion prompt at Step 2.2)"

# Manual verification steps
cat <<'MANUAL_STEPS'

=== MANUAL VERIFICATION STEPS ===

1. Set up a test project directory:
   mkdir -p /tmp/r4-migration-test/.claude
   cp tests/round-4/migration-alpha4-fixture.json /tmp/r4-migration-test/.claude/greenfield-state.json
   cd /tmp/r4-migration-test

2. Launch Claude Code in that directory and run:
   /greenfield:pickup

3. Expected migration shim behavior (pickup/SKILL.md § State migration):

   • Reads schemaVersion = "alpha.4" → triggers migration
   • Sets safe defaults (NOT new-session defaults):
       mode.depth        = "heavy"
       mode.coupling     = "hybrid"      ← safer than auto-loop for in-flight resume
       mode.domainFormat = "ddd-lite"    ← lighter; user can upgrade explicitly
   • Initializes new R4 collections:
       context.personas         = { primary: [], secondary: [], antiPersonas: [] }
       context.domainModel      = { contexts: [], entities: [], valueObjects: [],
                                    domainEvents: [], crossContextRelationships: [],
                                    ubiquitousLanguage: [], antiCorruption: "" }
       context.risks            = []
       phases.architecturalValidation.riskReconciliation = { summary: {}, topFollowups: [] }
   • Marks new phases as not-yet-walked:
       phaseStatus.personas    = { status: "not-yet-walked", approvedAt: null, ... }
       phaseStatus.domainModel = { status: "not-yet-walked", approvedAt: null, ... }
   • Bumps state.schemaVersion → "alpha.5"
   • Atomic checkpoint via .tmp + rename
   • Appends audit entry to .claude/greenfield-meta.json.audit[]
   • Surfaces user-facing notice: "Round 4 update applied — schema bumped to alpha.5..."
   • Surfaces AskUserQuestion: "How do you want to handle the new R4 phases? Add now / Defer / Skip"

4. Post-migration verification:
   jq '.schemaVersion' /tmp/r4-migration-test/.claude/greenfield-state.json
   # Expected: "alpha.5"

   jq '.mode' /tmp/r4-migration-test/.claude/greenfield-state.json
   # Expected: { "depth": "heavy", "coupling": "hybrid", "domainFormat": "ddd-lite" }

   jq '.context.personas, .context.domainModel, .risks' /tmp/r4-migration-test/.claude/greenfield-state.json
   # Expected: empty initialized objects/arrays

   jq '.phaseStatus.personas.status, .phaseStatus.domainModel.status' \
       /tmp/r4-migration-test/.claude/greenfield-state.json
   # Expected: "not-yet-walked" "not-yet-walked"

   jq '.audit[-1]' /tmp/r4-migration-test/.claude/greenfield-meta.json
   # Expected: { at: <iso8601>, action: "schema-migration", from: "alpha.4", to: "alpha.5", details: {...} }

5. T24 vision.users[] conversion test:
   When the user chooses "Add now" at step (3) above and the wizard enters Step 2.2 Personas:

   Expected prompt:
     "Migrated from Step 1 of alpha.4 wizard: 'Sara — field auditor visiting remote sites', 'Carl — compliance officer reviewing audit trails weekly'.
      Want to restructure these into the new Personas format?"

   • Accept (default): legacy strings become draft personas.primary[].name values for Q2-Q8 enrichment.
   • Decline: vision.users[] preserved as-is; loops fall back to top-level fallback prompts.

6. Idempotency:
   Re-run /greenfield:pickup. Migration should SKIP (schemaVersion is now "alpha.5"). No new audit entry.

=== END MANUAL VERIFICATION ===

[✓] Migration test setup complete. Run the manual verification above when ready.
MANUAL_STEPS

exit 0
