#!/usr/bin/env bash
# Belt test for belt-helpers.sh — the three selector helpers the lens belts rely on, each run against an
# input it must accept AND an input it must reject. Mirrors tests/lib/test_assert_versions.sh, the
# house precedent: a helper is exercised on a real passing case and on a synthetic failing one, and
# the failing case is asserted to actually fail.
#
# Why the failing halves are the point: `one_line()` exists to catch a selector that silently matched
# several lines, and `section()` exists to stop a region extractor being pointed at the wrong file.
# An inverted comparison or an always-true condition in either would ship green — nothing ran them
# against an input they were built to reject. That is the same "gate that cannot fail" class the
# helpers themselves were written to close, left open one level down.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPERS="$ROOT/tests/lib/belt-helpers.sh"
fails=0
note(){ echo "  ok: $1"; }
bad(){ echo "FAIL: $1"; fails=$((fails + 1)); }

[ -s "$HELPERS" ] || { echo "FAIL: missing $HELPERS"; exit 1; }

# The helpers call fail() on rejection, and the belts that source them define fail() as an `exit 1`.
# Each case therefore runs in its own subshell with that same contract, and this belt reads the EXIT
# STATUS — which is the behavior a sourcing belt actually depends on.
run_case() { # run_case <bash-snippet> -> exit status of the snippet
  (
    # shellcheck disable=SC2317 # invoked from the injected snippet, not from this scope
    fail(){ echo "    (helper rejected: $1)" >&2; exit 1; }
    # shellcheck source=tests/lib/belt-helpers.sh
    . "$HELPERS"
    eval "$1"
  ) >/dev/null 2>&1
}

expect_pass() { # expect_pass <label> <snippet>
  if run_case "$2"; then note "$1"; else bad "$1 — expected the helper to ACCEPT this input, it rejected"; fi
}
expect_fail() { # expect_fail <label> <snippet>
  if run_case "$2"; then bad "$1 — expected the helper to REJECT this input, it accepted"; else note "$1"; fi
}

# === one_line() — the guard whose whole value is its negative half ===
expect_pass "one_line accepts a single line" \
  'one_line "the only line" "single-line selector"'
expect_fail "one_line REJECTS a deliberately multi-line input" \
  'one_line "$(printf "first line\nsecond line\n")" "two-line selector"'
expect_fail "one_line REJECTS a three-line input" \
  'one_line "$(printf "a\nb\nc\n")" "three-line selector"'
# Empty is not one line either: a selector that matched NOTHING is a pin scoped to nothing at all,
# and a helper that let it through would turn every downstream assertion vacuous.
expect_fail "one_line REJECTS an empty selector result" \
  'one_line "" "empty selector"'
# Blank lines do not count as content — grep -c . is what makes a trailing newline harmless.
expect_pass "one_line accepts one content line padded with blanks" \
  'one_line "$(printf "\nthe only line\n\n")" "padded single-line selector"'

# === flatten() — a wrapped claim becomes one line, whitespace squeezed ===
expect_pass "flatten joins a wrapped sentence into one line" \
  '[ "$(flatten "$(printf "a wrapped\nclaim\n")")" = "a wrapped claim " ] || fail "flatten did not join the wrap"'
expect_pass "flatten squeezes runs of spaces" \
  '[ "$(flatten "one     two")" = "one two " ] || fail "flatten did not squeeze the run"'
# The property the ABSENCE pins depend on: a banned phrase re-wrapped across two physical lines must
# still be findable after flattening. A flatten that lost the join would let a re-wrapped revert past.
expect_pass "a re-wrapped banned phrase is still greppable after flatten" \
  'printf "%s\n" "$(flatten "$(printf "the retired\nclaim\n")")" | grep -qF "the retired claim" || fail "the re-wrapped phrase was not found"'

# === section() — one arity, and the file argument is mandatory ===
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '## Alpha\nalpha body\n\n## Beta\nbeta body\n' > "$TMP/doc.md"
printf '## Alpha\nDECOY body\n' > "$TMP/other.md"

expect_pass "section extracts the named region and stops at the next H2" \
  '[ "$(section "## Alpha" "'"$TMP"'/doc.md")" = "alpha body" ] || fail "section did not stop at the next H2"'
expect_pass "section extracts a later region too" \
  '[ "$(section "## Beta" "'"$TMP"'/doc.md")" = "beta body" ] || fail "section did not find the later region"'
# THE ARITY PIN. This is the copied-call bug the hoist exists to prevent: with an implicit file, a
# one-argument call silently extracted from whatever that belt happened to bind. It must now fail.
expect_fail "section REJECTS a one-argument call (the dropped-file bug)" \
  'section "## Alpha"'
expect_fail "section REJECTS an empty file argument" \
  'section "## Alpha" ""'
# NON-VACUITY for the pin above: the two-argument form must genuinely read the file it is HANDED,
# not some other one — otherwise "the file argument is mandatory" would be a check with no subject.
expect_pass "section reads the file it is handed, not another" \
  '[ "$(section "## Alpha" "'"$TMP"'/other.md")" = "DECOY body" ] || fail "section read the wrong file"'

# === The helper file is SOURCED, never discovered as a belt of its own ===
# belt-helpers.sh defines functions and runs nothing, so it deliberately does not match run-all.sh's
# discovery pattern. If it ever did, the runner would execute it as a belt with zero assertions and
# report a pass that proved nothing.
case "$(basename "$HELPERS")" in
  test_*.sh|test-*.sh|*-smoke.sh) bad "belt-helpers.sh must NOT match tests/run-all.sh's discovery pattern — it would run as a zero-assertion belt" ;;
  *) note "belt-helpers.sh stays out of the runner's discovery pattern" ;;
esac

[ "$fails" -eq 0 ] || { echo "FAIL: $fails belt-helper case(s) failed"; exit 1; }
echo "PASS: belt helpers (one_line accepts one line and rejects none/two/three, flatten joins a wrap, section takes a mandatory file argument)"
