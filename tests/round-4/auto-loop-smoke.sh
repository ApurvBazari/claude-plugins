#!/usr/bin/env bash
# tests/round-4/auto-loop-smoke.sh
#
# Round 4 auto-loop integration smoke — manual test driver.
# Validates that auto-loop-fixture.json is structurally sound and documents
# the manual verification steps the operator runs in a real Claude Code session.
#
# This is a MANUAL smoke test (no automated wizard runner available).
# Operator: read the steps, run them, compare actual output to expected.

set -euo pipefail

cd "$(dirname "$0")/../.."

FIXTURE="tests/round-4/auto-loop-fixture.json"

# 1. Verify fixture exists + parses
test -f "$FIXTURE" || { echo "[FAIL] fixture not found: $FIXTURE"; exit 2; }
jq . "$FIXTURE" > /dev/null
echo "[✓] fixture parses as JSON"

# 2. Verify schemaVersion = alpha.5
SCHEMA_VERSION=$(jq -r '.schemaVersion // "absent"' "$FIXTURE")
if [ "$SCHEMA_VERSION" != "alpha.5" ]; then
  echo "[FAIL] expected schemaVersion = alpha.5, got: $SCHEMA_VERSION"
  exit 1
fi
echo "[✓] schemaVersion: alpha.5"

# 3. Verify mode block is auto-loop + full-ddd
MODE_COUPLING=$(jq -r '.mode.coupling' "$FIXTURE")
MODE_DOMAIN=$(jq -r '.mode.domainFormat' "$FIXTURE")
[ "$MODE_COUPLING" = "auto-loop" ] || { echo "[FAIL] expected mode.coupling = auto-loop, got: $MODE_COUPLING"; exit 1; }
[ "$MODE_DOMAIN" = "full-ddd" ] || { echo "[FAIL] expected mode.domainFormat = full-ddd, got: $MODE_DOMAIN"; exit 1; }
echo "[✓] mode: depth=heavy coupling=auto-loop domainFormat=full-ddd"

# 4. Verify persona count = 2
PERSONA_COUNT=$(jq '.phases.personas.primary | length' "$FIXTURE")
[ "$PERSONA_COUNT" = "2" ] || { echo "[FAIL] expected 2 primary personas, got: $PERSONA_COUNT"; exit 1; }
echo "[✓] persona count: 2 (P1 Sara, P2 Carl)"

# 5. Verify entity count = 2
ENTITY_COUNT=$(jq '.phases.domainModel.entities | length' "$FIXTURE")
[ "$ENTITY_COUNT" = "2" ] || { echo "[FAIL] expected 2 entities, got: $ENTITY_COUNT"; exit 1; }
echo "[✓] entity count: 2 (Audit, Finding)"

# 6. Verify Audit is aggregate root, Finding is not
AGG_ROOTS=$(jq -r '[.phases.domainModel.entities[] | select(.isAggregateRoot) | .id] | join(",")' "$FIXTURE")
[ "$AGG_ROOTS" = "Audit" ] || { echo "[FAIL] expected aggregate roots = [Audit], got: $AGG_ROOTS"; exit 1; }
echo "[✓] aggregate roots: Audit"

# 7. Verify upstream phases (personas, domainModel, architecturalFraming) are approved
APPROVED_UPSTREAM=$(jq -r '[
  .phaseStatus.architecturalFraming.status,
  .phaseStatus.personas.status,
  .phaseStatus.domainModel.status
] | join(",")' "$FIXTURE")
[ "$APPROVED_UPSTREAM" = "approved,approved,approved" ] || {
  echo "[FAIL] expected upstream phases approved, got: $APPROVED_UPSTREAM"
  exit 1
}
echo "[✓] upstream phases: all approved (archFraming, personas, domainModel)"

# 8. Verify downstream phases are not-yet-walked
NOT_YET=$(jq -r '[
  .phaseStatus.dataArchitecture.status,
  .phaseStatus.auth.status,
  .phaseStatus.privacy.status
] | unique | join(",")' "$FIXTURE")
[ "$NOT_YET" = "not-yet-walked" ] || {
  echo "[FAIL] expected downstream phases not-yet-walked, got: $NOT_YET"
  exit 1
}
echo "[✓] downstream phases: all not-yet-walked (data, auth, privacy)"

# 9. Manual verification steps
cat <<'MANUAL_STEPS'

=== MANUAL VERIFICATION STEPS ===

1. Set up a test project directory (e.g., /tmp/r4-smoke-test):
   mkdir -p /tmp/r4-smoke-test/.claude
   cp tests/round-4/auto-loop-fixture.json /tmp/r4-smoke-test/.claude/greenfield-state.json
   cd /tmp/r4-smoke-test

2. Launch Claude Code in that directory and run:
   /greenfield:pickup

3. Expected resume behavior:
   • Pickup detects in-flight session, currentStep = step-5-auth
   • Pickup migration check: state.schemaVersion is alpha.5 already, skip migration
   • Resume continues at Step 5 (auth phase)

4. Walk Step 5 (auth) — expected loop behavior under mode.coupling=auto-loop:
   • Auth.Q5 (authorization model — role/permission) fires PER PERSONA:
     - Iteration 1: "For persona P1 (Sara, Field Auditor): what role + permission set fits?"
     - Iteration 2: "For persona P2 (Carl, Compliance Officer): what role + permission set fits?"
   • Each looped answer writes to docs/adr/auth.dependencies.json with:
       sourceRef: { phase: "personas", id: "P1" }   (for the first iteration)
       sourceRef: { phase: "personas", id: "P2" }   (for the second)

5. Walk Step 3 (dataArchitecture) or Step 4 (apiIntegration) — expected per-entity loop:
   • Data.Q5 (migrations) loops PER ENTITY:
     - Iteration 1: "For entity Audit (BC1): which migration tool + mode?"
     - Iteration 2: "For entity Finding (BC1): which migration tool + mode?"
   • Each answer carries sourceRef.phase = "domainModel", sourceRef.id = "Audit" or "Finding"

6. Verify sourceRef integrity after walks complete:
   jq '[.dependencies[] | select(.sourceRef != null) | .sourceRef.phase] | unique' \
      /tmp/r4-smoke-test/docs/adr/auth.dependencies.json
   # Expected: ["personas"]

   jq '[.dependencies[] | select(.sourceRef != null) | .sourceRef.phase] | unique' \
      /tmp/r4-smoke-test/docs/adr/data-architecture.dependencies.json
   # Expected: ["domainModel"]

=== END MANUAL VERIFICATION ===

[✓] Auto-loop smoke setup complete. Run the manual verification above when ready.
MANUAL_STEPS

exit 0
