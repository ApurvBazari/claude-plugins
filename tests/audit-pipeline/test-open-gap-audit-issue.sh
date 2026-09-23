#!/usr/bin/env bash
# Exercises .github/scripts/open-gap-audit-issue.sh with a PATH-shadowed `gh` stub and fixture
# reports. NEVER calls the real gh.
set -uo pipefail

# SC2015 is disabled on each `A && pass … || fail …` reporter below: `pass`/`fail`
# always return 0, so the `|| fail` branch only runs when the assertion is false.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/.github/scripts/open-gap-audit-issue.sh"
PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOXES=()
cleanup() { for d in "${SANDBOXES[@]+"${SANDBOXES[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# Sandbox: temp CWD + a gh stub. `issue list` prints $GH_STUB_OPEN_JSON; create/close are logged.
make_sandbox() {
  SBOX="$(mktemp -d)"
  SANDBOXES+=("$SBOX")
  mkdir -p "${SBOX}/bin"
  LOG="${SBOX}/gh.log"
  : > "${LOG}"
  cat > "${SBOX}/bin/gh" <<STUB
#!/usr/bin/env bash
case "\$1 \$2" in
  "issue list")   printf '%s\n' "\${GH_STUB_OPEN_JSON:-[]}" ;;
  "issue create") echo "create" >> "${LOG}"; echo "https://x/issues/200" ;;
  "issue close")  echo "close \$3" >> "${LOG}" ;;
  "label create") : ;;
  *)              echo "unexpected gh \$*" >> "${LOG}" ;;
esac
exit 0
STUB
  chmod +x "${SBOX}/bin/gh"
}

report() {  # $1 date, $2 summary, $3 optional extra body
  printf '# Tooling Gap Audit — %s\n\n## Summary\n%s\n%s' "$1" "$2" "${3:-}" > "${SBOX}/report.md"
}
open_issue_json() {  # $1 number, $2 date, $3 summary, $4 line ending ("\n" or "\r\n")
  python3 -c 'import json,sys; n,d,s,e=sys.argv[1:5]; e=e.encode().decode("unicode_escape"); print(json.dumps([{"number":int(n),"body":e.join(["# Tooling Gap Audit — "+d,"","## Summary",s,""])}]))' "$1" "$2" "$3" "$4"
}
run_script() { ( cd "${SBOX}" && PATH="${SBOX}/bin:${PATH}" GH_TOKEN=stub GH_STUB_OPEN_JSON="${1:-[]}" bash "${SCRIPT}" "$2" "${3:-report.md}" 2>&1 ); }
count() { grep -c "^$1" "${LOG}" || true; }

# 1. Missing report -> exit 1, no issue
make_sandbox
out="$(run_script '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 1 ] && echo "$out" | grep -q "No audit report" && [ "$(count create)" = 0 ]; } \
  && pass "missing report -> exit 1" || fail "missing report -> exit 1 (rc=$rc, out=$out)"

# 2. Malformed header -> exit 1
make_sandbox
printf '# Something else\n\n## Summary\nx\n' > "${SBOX}/report.md"
out="$(run_script '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 1 ] && echo "$out" | grep -q "header malformed"; } \
  && pass "malformed header -> exit 1" || fail "malformed header -> exit 1 (rc=$rc, out=$out)"

# 3. Drift, no open issue -> create 1, close 0
make_sandbox
report 2026-10-01 "Two gaps found."
run_script '[]' 2026-10-01 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 1 ] && [ "$(count close)" = 0 ]; } \
  && pass "new drift -> issue created" || fail "new drift -> issue created ($(cat "$LOG"))"

# 4. Drift unchanged vs open issue (different date line) -> nothing
make_sandbox
report 2026-10-15 "Two gaps found."
out="$(run_script "$(open_issue_json 101 2026-10-01 'Two gaps found.' '\n')" 2026-10-15)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "Report unchanged vs open issue #101" \
  && [ "$(count create)" = 0 ] && [ "$(count close)" = 0 ]; } \
  && pass "unchanged drift -> no duplicate" || fail "unchanged drift -> no duplicate (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 5. Drift changed vs open issue -> create new, close the old one
make_sandbox
report 2026-10-15 "Three gaps found."
run_script "$(open_issue_json 101 2026-10-01 'Two gaps found.' '\n')" 2026-10-15 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 1 ] && grep -q '^close 101$' "$LOG"; } \
  && pass "changed drift -> new issue, old closed" || fail "changed drift -> new issue, old closed ($(cat "$LOG"))"

# 6. No drift, no open issue -> nothing
make_sandbox
report 2026-10-01 "No tooling drift detected."
out="$(run_script '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "nothing to file" \
  && [ "$(count create)" = 0 ] && [ "$(count close)" = 0 ]; } \
  && pass "no drift, no issue -> nothing" || fail "no drift, no issue -> nothing (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 7. No drift, open issue -> close it, create nothing
make_sandbox
report 2026-10-15 "No tooling drift detected."
run_script "$(open_issue_json 101 2026-10-01 'Two gaps found.' '\n')" 2026-10-15 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 0 ] && grep -q '^close 101$' "$LOG"; } \
  && pass "drift resolved -> open issue closed" || fail "drift resolved -> open issue closed ($(cat "$LOG"))"

# 8. GitHub returns the stored body with CRLF -> still recognised as unchanged
make_sandbox
report 2026-10-15 "Two gaps found."
out="$(run_script "$(open_issue_json 101 2026-10-01 'Two gaps found.' '\r\n')" 2026-10-15)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "Report unchanged vs open issue #101" && [ "$(count create)" = 0 ]; } \
  && pass "CRLF body -> no duplicate" || fail "CRLF body -> no duplicate (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 9. Report body with shell metacharacters is never expanded
make_sandbox
report 2026-10-01 "Gap: \$(touch ${SBOX}/pwned) and \`touch ${SBOX}/pwned2\`"
run_script '[]' 2026-10-01 >/dev/null
# shellcheck disable=SC2015
{ [ ! -e "${SBOX}/pwned" ] && [ ! -e "${SBOX}/pwned2" ] && [ "$(count create)" = 1 ]; } \
  && pass "metacharacters inert" || fail "metacharacters inert"

# 10. Bad usage -> exit 2
make_sandbox
out="$( cd "${SBOX}" && PATH="${SBOX}/bin:${PATH}" bash "${SCRIPT}" 2>&1 )"; rc=$?
# shellcheck disable=SC2015
[ "$rc" -eq 2 ] && pass "no args -> exit 2" || fail "no args -> exit 2 (rc=$rc)"

echo "  audit-issue: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
