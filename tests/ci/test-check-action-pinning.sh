#!/usr/bin/env bash
# test-check-action-pinning.sh — fixture belt for .github/scripts/check-action-pinning.sh.
# Each bad fixture lives alone in its own directory, so a pass cannot come from a neighbour's error.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINTER="${REPO_ROOT}/.github/scripts/check-action-pinning.sh"
PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
SHA="3d3c42e5aac5ba805825da76410c181273ba90b1"

fixture() {  # $1 name, $2 the uses: line body
  mkdir -p "$tmp/$1"
  printf 'jobs:\n  j:\n    steps:\n      - uses: %s\n' "$2" > "$tmp/$1/w.yml"
}

expect_ok() {
  local out rc; out="$(bash "$LINTER" "$tmp/$1" 2>&1)"; rc=$?
  # shellcheck disable=SC2015
  [ "$rc" -eq 0 ] && pass "$1 accepted" || fail "$1 should pass (rc=$rc, out=$out)"
}
expect_bad() {  # $1 name, $2 substring the error must contain
  local out rc; out="$(bash "$LINTER" "$tmp/$1" 2>&1)"; rc=$?
  # shellcheck disable=SC2015
  { [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '::error file=' && printf '%s' "$out" | grep -qF -- "$2"; } \
    && pass "$1 rejected" || fail "$1 should fail naming '$2' (rc=$rc, out=$out)"
}

fixture sha-with-comment        "actions/checkout@${SHA} # v7.0.1"
fixture sha-comment-no-space    "actions/checkout@${SHA} #v7.0.1"
fixture subpath-sha             "github/codeql-action/init@${SHA} # v3.2.1"
fixture quoted-sha              "\"actions/checkout@${SHA}\" # v7.0.1"
fixture local-action            "./.github/actions/setup"
fixture docker-image            "docker://alpine:3.20"
fixture version-tag             "actions/checkout@v4"
fixture semver                  "actions/checkout@4.2.2"
fixture branch                  "actions/checkout@main"
fixture moving-beta             "anthropics/claude-code-action@beta"
fixture short-sha               "actions/checkout@3d3c42e # v7.0.1"
fixture sha-no-comment          "actions/checkout@${SHA}"
fixture subpath-tag             "github/codeql-action/init@v3"
fixture uppercase-sha           "actions/checkout@3D3C42E5AAC5BA805825DA76410C181273BA90B1 # v7.0.1"
fixture no-ref                  "actions/checkout"

for ok in sha-with-comment sha-comment-no-space subpath-sha quoted-sha local-action docker-image; do
  expect_ok "$ok"
done
expect_bad version-tag     "actions/checkout@v4"
expect_bad semver          "actions/checkout@4.2.2"
expect_bad branch          "actions/checkout@main"
expect_bad moving-beta     "anthropics/claude-code-action@beta"
expect_bad short-sha       "actions/checkout@3d3c42e"
expect_bad sha-no-comment  "no '# <version>' comment"
expect_bad subpath-tag     "github/codeql-action/init@v3"
expect_bad uppercase-sha   "not pinned to a full commit SHA"
expect_bad no-ref          "actions/checkout"

# A `uses:` inside a run: block or prompt is prose, not a step — must not be linted.
mkdir -p "$tmp/prose"
printf 'jobs:\n  j:\n    steps:\n      - run: |\n          echo "see uses: actions/checkout@v4 in the docs"\n' > "$tmp/prose/w.yml"
expect_ok prose

# The real repository must pass.
out="$( cd "$REPO_ROOT" && bash "$LINTER" 2>&1 )"; rc=$?
# shellcheck disable=SC2015
[ "$rc" -eq 0 ] && pass "repository workflows pass" || fail "repository workflows fail the linter: $out"

echo "  action-pinning: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
