#!/usr/bin/env bash
# Usage: source "$ROOT/tests/lib/belt-helpers.sh"
#
# Three selector helpers the belts share. Each existed as per-belt copies, applied inconsistently — a
# belt that had one and not the other pinned a wrapped claim it could not see, or scoped a pin to a
# selector that silently matched several lines. They live here so every belt gets the same three.
#
# Sourced, never executed: this file defines functions and runs nothing. It deliberately does NOT
# match tests/run-all.sh's discovery pattern (test_*.sh / test-*.sh / *-smoke.sh), so the runner walks
# past it instead of running it as a belt with zero assertions.
#
# A belt that sources this must already define fail().

# flatten <text> — a wrapped markdown sentence is ONE claim across several physical lines, and `grep`
# is line-scoped. Flattening is what lets a pin quote the claim verbatim instead of guessing where the
# author's wrap landed — and what makes a NEGATIVE pin survive a revert that moved the wrap.
# Use it for absence pins and for claims that wrap. Do NOT flatten a whole file for a positive
# line-scoped pin: that turns "the line making this claim also carries X" into a whole-file grep.
flatten() { printf '%s\n' "$1" | tr '\n' ' ' | tr -s ' '; }

# one_line <text> <what> — assert a selector resolved to exactly ONE line. A `grep -F` matching three
# lines ORs them, so every pin scoped to the result passes while ANY one of them carries the literal.
# These docs state each rule two or three times (a declaration, the step that enforces it, a Key
# Rule), so a selector spanning the restatements can have its declaration site gutted and stay green.
one_line() {
  local n
  n="$(printf '%s\n' "$1" | grep -c . || true)"
  [ "$n" -eq 1 ] \
    || fail "the $2 selector must resolve to exactly one line, matched $n — a multi-line match ORs the pins scoped to it"
}

# section <heading-prefix> <file> — everything between a heading and the next H2, so each pin judges
# only its own section. The heading line itself is skipped and the terminator is STRUCTURAL (`^## `)
# rather than keyed to the next heading's title, so renaming that title cannot widen a region to EOF
# and turn every pin scoped to it into a whole-file grep.
#
# The FILE ARGUMENT IS MANDATORY, and that is the point of hoisting this. The belts that carried their
# own copy under this same name carried it in two incompatible arities — some took the file as arg 2,
# others bound one file implicitly — so copying a working `section "$H" "$FILE"` call into such a belt
# silently dropped the second argument and pinned the claim against the wrong document, passing.
# One arity, checked, is what makes a copied call fail loudly instead.
section() {
  [ "$#" -eq 2 ] && [ -n "${2:-}" ] \
    || fail "section() takes <heading-prefix> <file> — a call with $# argument(s) would extract from the wrong document"
  awk -v h="$1" 'index($0,h)==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$2"
}
