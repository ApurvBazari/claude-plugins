#!/usr/bin/env bash
# Exercises .github/scripts/open-gap-audit-pr.sh with a PATH-shadowed `gh` stub and fixture
# reports. NEVER calls the real gh. Tier-A of the tooling-gap-audit runtime-fidelity check.
set -uo pipefail

# SC2015 is disabled on each `A && pass … || fail …` reporter below: `pass`/`fail`
# always return 0, so the `|| fail` branch only runs when the assertion is false.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/.github/scripts/open-gap-audit-pr.sh"
PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOXES=()
cleanup() { for d in "${SANDBOXES[@]+"${SANDBOXES[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# Build a sandbox: temp CWD with docs/tooling-gap-reports + a PATH-shadowed gh stub.
make_sandbox() {
  SBOX="$(mktemp -d)"
  SANDBOXES+=("$SBOX")
  mkdir -p "${SBOX}/docs/tooling-gap-reports" "${SBOX}/bin"
  CREATE_LOG="${SBOX}/gh-create.log"
  : > "${CREATE_LOG}"
  cat > "${SBOX}/bin/gh" <<STUB
#!/usr/bin/env bash
# fake gh: configurable 'pr list', recorded 'pr create'
if [ "\$1" = "pr" ] && [ "\$2" = "list" ]; then echo "\${GH_STUB_EXISTING_PR:-}"; exit 0; fi
if [ "\$1" = "pr" ] && [ "\$2" = "create" ]; then echo create >> "${CREATE_LOG}"; echo "https://x/pull/999"; exit 0; fi
exit 0
STUB
  chmod +x "${SBOX}/bin/gh"
}

run_script() { ( cd "${SBOX}" && PATH="${SBOX}/bin:${PATH}" GH_TOKEN=stub GH_STUB_EXISTING_PR="${1:-}" bash "${SCRIPT}" "${2}" "${3}" ); }
report() { printf '# Tooling Gap Audit — %s\n\n## Summary\n%s\n' "$1" "$2" > "${SBOX}/docs/tooling-gap-reports/${1}-gap-report.md"; }
created_count() { wc -l < "${CREATE_LOG}" | tr -d ' '; }

# 1. Missing report -> skip, exit 0, no PR
make_sandbox
out="$(run_script "" 2026-06-17 chore/audit-2026-06-17)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "No report found" && [ "$(created_count)" = 0 ]; } \
  && pass "missing report -> skip" || fail "missing report -> skip (rc=$rc, out=$out)"

# 2. First-ever report (no prior) -> opens PR
make_sandbox
report 2026-06-17 "Two gaps found."
run_script "" 2026-06-17 chore/audit-2026-06-17 >/dev/null
# shellcheck disable=SC2015
[ "$(created_count)" = 1 ] && pass "first report -> opens PR" || fail "first report -> opens PR (created=$(created_count))"

# 3. Unchanged content vs prior -> skip
make_sandbox
report 2026-06-01 "Same body."
report 2026-06-17 "Same body."
run_script "" 2026-06-17 chore/audit-2026-06-17 >/dev/null
# shellcheck disable=SC2015
[ "$(created_count)" = 0 ] && pass "unchanged vs prior -> skip" || fail "unchanged vs prior -> skip (created=$(created_count))"

# 4. Changed content vs prior -> opens PR
make_sandbox
report 2026-06-01 "Old body."
report 2026-06-17 "New body."
run_script "" 2026-06-17 chore/audit-2026-06-17 >/dev/null
# shellcheck disable=SC2015
[ "$(created_count)" = 1 ] && pass "changed vs prior -> opens PR" || fail "changed vs prior -> opens PR (created=$(created_count))"

# 5. Existing open PR -> skip even with content
make_sandbox
report 2026-06-17 "Body."
run_script 42 2026-06-17 chore/audit-2026-06-17 >/dev/null
# shellcheck disable=SC2015
[ "$(created_count)" = 0 ] && pass "existing PR -> skip" || fail "existing PR -> skip (created=$(created_count))"

echo "  audit-pipeline: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
