#!/usr/bin/env bash
# Exercises the tooling-gap audit's two deterministic scripts with fixtures and a PATH-shadowed `gh`
# stub. NEVER calls the real gh.
#   .github/scripts/collect-audit-findings.sh — the drift facts, one per line, sorted
#   .github/scripts/open-gap-audit-issue.sh   — opens / keeps / closes the tooling-audit issue
# Issue decisions must come from the findings fingerprint, never from the model-written prose: the
# rewording cases below (5, 6, 10) are the ones a model produces run to run.
set -uo pipefail

# SC2015 is disabled on each `A && pass … || fail …` reporter below: `pass`/`fail`
# always return 0, so the `|| fail` branch only runs when the assertion is false.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILER="${REPO_ROOT}/.github/scripts/open-gap-audit-issue.sh"
COLLECT="${REPO_ROOT}/.github/scripts/collect-audit-findings.sh"
PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOXES=()
cleanup() { for d in "${SANDBOXES[@]+"${SANDBOXES[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# Sandbox: temp CWD + a gh stub. `issue list` prints $GH_STUB_OPEN_JSON; create/close are logged and
# the created issue's --body-file is copied to created-body.md.
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
  "issue create")
    echo "create" >> "${LOG}"
    prev=""
    for a in "\$@"; do
      if [ "\$prev" = "--body-file" ]; then cp "\$a" "${SBOX}/created-body.md"; fi
      prev="\$a"
    done
    echo "https://x/issues/200" ;;
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
findings() { printf '%b' "$1" > "${SBOX}/findings.txt"; }   # $1 lines, \n-separated ("" = no drift)
# An open issue whose body is $2 (a file), as `gh issue list --json number,body` returns it; $3 = line ending.
open_issue_json() {
  python3 -c 'import json,sys; n,p,e=sys.argv[1:4]; e=e.encode().decode("unicode_escape"); b=open(p).read().replace("\n", e); print(json.dumps([{"number":int(n),"body":b}]))' "$1" "$2" "$3"
}
run_filer() { ( cd "${SBOX}" && PATH="${SBOX}/bin:${PATH}" GH_TOKEN=stub GH_STUB_OPEN_JSON="${1:-[]}" bash "${FILER}" "$2" report.md findings.txt 2>&1 ); }
count() { grep -c "^$1" "${LOG}" || true; }
# Build the body an earlier run filed for these findings: run once with no open issue, keep its body.
prior_body() {  # $1 findings; leaves the prior issue body in $PRIOR
  make_sandbox
  report 2026-10-01 "Two gaps found — first wording."
  findings "$1"
  run_filer '[]' 2026-10-01 >/dev/null
  PRIOR="$(mktemp)"; SANDBOXES+=("$PRIOR"); cp "${SBOX}/created-body.md" "$PRIOR" 2>/dev/null || : > "$PRIOR"
}

TWO="structural: rule target missing: src/old/**\nbaseline path missing: onboard/CLAUDE.md\n"
TWO_REORDERED="\nbaseline path missing: onboard/CLAUDE.md\nstructural: rule target missing: src/old/**\n\n"
THREE="${TWO}baseline path missing: lens/CLAUDE.md\n"

# --- filer ---

# 1. Missing report -> exit 1, no issue
make_sandbox; findings "$TWO"
out="$(run_filer '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 1 ] && echo "$out" | grep -q "No audit report" && [ "$(count create)" = 0 ]; } \
  && pass "missing report -> exit 1" || fail "missing report -> exit 1 (rc=$rc, out=$out)"

# 2. Malformed header -> exit 1
make_sandbox; findings "$TWO"
printf '# Something else\n\n## Summary\nx\n' > "${SBOX}/report.md"
out="$(run_filer '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 1 ] && echo "$out" | grep -q "header malformed"; } \
  && pass "malformed header -> exit 1" || fail "malformed header -> exit 1 (rc=$rc, out=$out)"

# 3. Missing findings file -> exit 1 (decisions need the deterministic list, never the prose)
make_sandbox; report 2026-10-01 "Two gaps found."
out="$(run_filer '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 1 ] && echo "$out" | grep -q "No findings file" && [ "$(count create)" = 0 ]; } \
  && pass "missing findings file -> exit 1" || fail "missing findings file -> exit 1 (rc=$rc, out=$out)"

# 4. Drift, no open issue -> one issue, body = report + fingerprint marker
make_sandbox; report 2026-10-01 "Two gaps found."; findings "$TWO"
run_filer '[]' 2026-10-01 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 1 ] && [ "$(count close)" = 0 ] \
  && grep -q 'Two gaps found\.' "${SBOX}/created-body.md" \
  && grep -qE '^<!-- audit-fingerprint: [0-9a-f]{40} -->$' "${SBOX}/created-body.md"; } \
  && pass "new drift -> issue with fingerprint" || fail "new drift -> issue with fingerprint ($(cat "$LOG"); body: $(cat "${SBOX}/created-body.md" 2>/dev/null))"

# 5. Same findings (reordered, blank lines), reworded prose -> no duplicate
prior_body "$TWO"
make_sandbox; report 2026-10-15 "The audit found two gaps; wording differs this run."; findings "$TWO_REORDERED"
out="$(run_filer "$(open_issue_json 101 "$PRIOR" '\n')" 2026-10-15)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "Findings unchanged vs open issue #101" \
  && [ "$(count create)" = 0 ] && [ "$(count close)" = 0 ]; } \
  && pass "reworded report, same findings -> no duplicate" || fail "reworded report, same findings -> no duplicate (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 6. Same, but GitHub returns the stored body with CRLF -> still recognised
make_sandbox; report 2026-10-15 "Reworded again."; findings "$TWO"
out="$(run_filer "$(open_issue_json 101 "$PRIOR" '\r\n')" 2026-10-15)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "Findings unchanged vs open issue #101" && [ "$(count create)" = 0 ]; } \
  && pass "CRLF body -> no duplicate" || fail "CRLF body -> no duplicate (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 7. Changed findings -> new issue, the superseded one closed
make_sandbox; report 2026-10-15 "Three gaps found."; findings "$THREE"
run_filer "$(open_issue_json 101 "$PRIOR" '\n')" 2026-10-15 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 1 ] && grep -q '^close 101$' "$LOG"; } \
  && pass "changed findings -> new issue, old closed" || fail "changed findings -> new issue, old closed ($(cat "$LOG"))"

# 8. No findings (paraphrased no-drift summary, no trailing period), no open issue -> nothing
make_sandbox; report 2026-10-01 "Everything matches the baseline"; findings ""
out="$(run_filer '[]' 2026-10-01)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "nothing to file" \
  && [ "$(count create)" = 0 ] && [ "$(count close)" = 0 ]; } \
  && pass "no findings, no issue -> nothing (wording irrelevant)" || fail "no findings, no issue -> nothing (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 9. No findings, open issue -> close it, create nothing
make_sandbox; report 2026-10-15 "All clear"; findings ""
run_filer "$(open_issue_json 101 "$PRIOR" '\n')" 2026-10-15 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 0 ] && grep -q '^close 101$' "$LOG"; } \
  && pass "drift resolved -> open issue closed" || fail "drift resolved -> open issue closed ($(cat "$LOG"))"

# 10. Drift report whose prose quotes the no-drift sentence -> must NOT close real drift
make_sandbox
report 2026-10-15 "Two gaps." "## Rules\nThe old report said: No tooling drift detected. That is no longer true.\n"
findings "$TWO"
out="$(run_filer "$(open_issue_json 101 "$PRIOR" '\n')" 2026-10-15)"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && [ "$(count close)" = 0 ] && [ "$(count create)" = 0 ]; } \
  && pass "no-drift sentence inside a drift report -> issue kept open" || fail "no-drift sentence inside a drift report -> issue kept open (rc=$rc, out=$out, log=$(cat "$LOG"))"

# 11. An open issue from before fingerprints existed -> replaced, not matched
make_sandbox; report 2026-10-15 "Two gaps found."; findings "$TWO"
printf '# Tooling Gap Audit — 2026-09-01\n\n## Summary\nTwo gaps found.\n' > "${SBOX}/legacy.md"
run_filer "$(open_issue_json 99 "${SBOX}/legacy.md" '\n')" 2026-10-15 >/dev/null
# shellcheck disable=SC2015
{ [ "$(count create)" = 1 ] && grep -q '^close 99$' "$LOG"; } \
  && pass "pre-fingerprint issue -> superseded" || fail "pre-fingerprint issue -> superseded ($(cat "$LOG"))"

# 12. Report body with shell metacharacters is never expanded
make_sandbox
report 2026-10-01 "Gap: \$(touch ${SBOX}/pwned) and \`touch ${SBOX}/pwned2\`"; findings "$TWO"
run_filer '[]' 2026-10-01 >/dev/null
# shellcheck disable=SC2015
{ [ ! -e "${SBOX}/pwned" ] && [ ! -e "${SBOX}/pwned2" ] && [ "$(count create)" = 1 ]; } \
  && pass "metacharacters inert" || fail "metacharacters inert"

# 13. Bad usage -> exit 2
make_sandbox
out="$( cd "${SBOX}" && PATH="${SBOX}/bin:${PATH}" bash "${FILER}" 2026-10-01 report.md 2>&1 )"; rc=$?
# shellcheck disable=SC2015
[ "$rc" -eq 2 ] && pass "missing findings arg -> exit 2" || fail "missing findings arg -> exit 2 (rc=$rc)"

# --- collector ---

make_sandbox
mkdir -p "${SBOX}/rules"; : > "${SBOX}/present.md"
printf '{"tooling":{"claudeMd":["present.md","gone.md"],"rules":["rules","rules-gone"],"hooks":[]}}\n' > "${SBOX}/baseline.json"
printf '## Tooling Audit Report\n\n### Checking CLAUDE.md commands...\n### Checking rule path targets...\n\n### Drift Detected\n\n  - Rule target missing: src/old/**\n  - CLAUDE.md references missing script: scripts/x.sh\n\n' > "${SBOX}/drift.md"
printf '## Tooling Audit Report\n\n### Checking CLAUDE.md commands...\n\n### No Drift\nAll tooling is in sync with the codebase.\n' > "${SBOX}/clean.md"

# 14. Structural items + missing baseline paths, sorted, nothing else
out="$( cd "${SBOX}" && bash "${COLLECT}" drift.md baseline.json 2>&1 )"; rc=$?
want="$(printf '%s\n' 'baseline path missing: gone.md' 'baseline path missing: rules-gone' \
  'structural: CLAUDE.md references missing script: scripts/x.sh' 'structural: Rule target missing: src/old/**')"
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && [ "$out" = "$want" ]; } \
  && pass "collector -> sorted structural + baseline findings" || fail "collector -> sorted findings (rc=$rc)
--- got ---
$out
--- want ---
$want"

# 15. No drift and every baseline path present -> empty output
printf '{"tooling":{"claudeMd":["present.md"],"rules":["rules"],"hooks":[]}}\n' > "${SBOX}/baseline-ok.json"
out="$( cd "${SBOX}" && bash "${COLLECT}" clean.md baseline-ok.json 2>&1 )"; rc=$?
# shellcheck disable=SC2015
{ [ "$rc" -eq 0 ] && [ -z "$out" ]; } \
  && pass "collector -> empty when nothing drifted" || fail "collector -> empty when nothing drifted (rc=$rc, out=$out)"

# 16. Missing input -> exit 2
out="$( cd "${SBOX}" && bash "${COLLECT}" nope.md baseline.json 2>&1 )"; rc=$?
# shellcheck disable=SC2015
[ "$rc" -eq 2 ] && pass "collector missing input -> exit 2" || fail "collector missing input -> exit 2 (rc=$rc)"

echo "  audit-issue: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
