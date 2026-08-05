#!/usr/bin/env bash
# shellcheck disable=SC2016 # every single-quoted literal here is a grepped markdown code span, not shell expansion
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

# flatten(), one_line() and section() are shared by every belt that sources them; they live in
# tests/lib so a fix to any of them reaches every belt at once, instead of the inconsistent per-belt
# copies they replace — section() in particular had drifted into two arities across those copies.
# shellcheck source=tests/lib/belt-helpers.sh
. "$ROOT/tests/lib/belt-helpers.sh"

# House idiom (tests/lens/test_engine_api.sh): every extracted region is asserted non-empty AND
# bounded. An extractor whose terminator stops matching does not go empty — it swallows the rest of
# the file, so every pin scoped to it silently becomes a whole-file grep. A ceiling catches that.
bounded(){ # bounded <region-name> <max-lines> <region-text>
  [ -n "$3" ] || fail "$1 is empty"
  local n
  n="$(printf '%s\n' "$3" | wc -l | tr -d '[:space:]')"
  [ "$n" -le "$2" ] || fail "$1 grew to $n lines (ceiling $2) — its extractor lost its terminator"
}

API="$ROOT/lens/skills/engine/references/engine-api.md"
[ -s "$API" ] || fail "missing or empty $API — the model policy has no declared home"

line_of(){ grep -nxF -- "$1" "$API" | head -1 | cut -d: -f1 || true; }

H_INPUTS='## lens:engine — inputs'
H_MODEL='## Model resolution — the precedence chain'
H_RETURNS='## lens:engine — returns'

# === PLACEMENT: the model section sits between the inputs table and the returns table ===
# Positional, not merely present. The inputs extractor terminates at the first following `^## `, so a
# model section spliced INTO the inputs table would truncate it and quietly narrow every pin scoped
# there; one appended at EOF would separate the declaration from the input it governs.
L_INPUTS="$(line_of "$H_INPUTS")"
L_MODEL="$(line_of "$H_MODEL")"
L_RETURNS="$(line_of "$H_RETURNS")"
[ -n "$L_INPUTS" ] || fail "engine-api.md must carry the heading '$H_INPUTS'"
[ -n "$L_MODEL" ] || fail "engine-api.md must carry the heading '$H_MODEL' (whole line)"
[ -n "$L_RETURNS" ] || fail "engine-api.md must carry the heading '$H_RETURNS'"
[ "$L_MODEL" -gt "$L_INPUTS" ] \
  || fail "'$H_MODEL' must come AFTER the whole inputs section — placing it inside truncates the inputs table"
[ "$L_MODEL" -lt "$L_RETURNS" ] \
  || fail "'$H_MODEL' must come BEFORE '$H_RETURNS' — it governs an input, not a return"

INPUTS="$(section "$H_INPUTS" "$API")"
bounded "engine-api.md § lens:engine — inputs" 50 "$INPUTS"
MODEL="$(section "$H_MODEL" "$API")"
bounded "engine-api.md § Model resolution — the precedence chain" 125 "$MODEL"

# A wrapped markdown sentence is one claim across several physical lines, so a claim whose subject and
# predicate land on different lines cannot be pinned line-scoped. MODELFLAT is the section as one line,
# used only where the claim itself wraps — every pin that fits on one line stays line-scoped below.
MODELFLAT="$(flatten "$MODEL")"

# === THE DECLARATION: an inputs-table ROW, and its exact four-key shape ===
# Pinned to the row's FIRST CELL, the same key-regex discipline the returns table uses: `modelPolicy`
# already appears in § Errors as prose, so a bare substring grep would pass with no input declared at
# all. The key set is asserted in BOTH directions — a subset check lets a key be deleted, a superset
# check lets one be invented, and widening modelPolicy past its four keys is an ask-first boundary.
python3 - "$INPUTS" <<'PY' || fail "engine-api.md's inputs table does not declare modelPolicy as the four-key shape"
import re, sys

inputs = sys.argv[1]

def rows(text):
    out = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cells[0] or set(cells[0]) <= set("-: ") or cells[0] == "Input":
            continue
        out.append(cells)
    return out

def split_top(s):
    """Split on commas that are not nested inside a brace/bracket/paren group."""
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts]

def optional_keys(body, what):
    keys = []
    for entry in split_top(body):
        m = re.match(r"`?([A-Za-z]+)\?:", entry)
        assert m, f"every {what} must be declared as `<name>?: <type>` (all are optional), got {entry!r}"
        keys.append(m.group(1))
    assert len(keys) == len(set(keys)), f"a {what} is declared twice: {keys}"
    return keys

table = rows(inputs)
first_cells = [c[0] for c in table]
declared = {}
for cells in table:
    m = re.fullmatch(r"`([A-Za-z]+)(?:\[\])?`", cells[0])
    assert m, f"an inputs row does not declare an `input` name in its first cell: {cells[0]!r}"
    declared[m.group(1)] = cells

# TRUNCATION GUARD: the new section must not have cost the table a row. The five pre-1.5.0 inputs are
# retained here as well as in test_engine_api.sh, so a truncated table fails at the belt that moved it.
for retained in ("target", "taskIds", "injectedIntent", "injectedFinders", "finders"):
    assert retained in declared, \
        f"the inputs table lost its `{retained}` row — the new section truncated it; rows seen: {first_cells}"

assert "modelPolicy" in declared, (
    "the inputs table must carry a row whose FIRST CELL is exactly `modelPolicy` — a prose mention is "
    f"not a declaration; rows seen: {first_cells}"
)

cells = declared["modelPolicy"]
assert len(cells) >= 2, f"the modelPolicy row must carry a Shape cell, got {cells}"
m = re.fullmatch(r"`\{(.*)\}`", cells[1])
assert m, f"the modelPolicy row's Shape cell must declare an object literal, got {cells[1]!r}"

keys = optional_keys(m.group(1), "modelPolicy key")
expected = {"deny", "default", "byRole", "byAgent"}
assert set(keys) == expected and len(keys) == 4, (
    "modelPolicy accepts EXACTLY four optional keys (widening it is an ask-first boundary); "
    f"undeclared={sorted(set(keys) - expected)} missing={sorted(expected - set(keys))}"
)

entries = {k: e for k, e in zip(keys, split_top(m.group(1)))}
assert "string[]" in entries["deny"], f"`deny` must be declared a string[], got {entries['deny']!r}"
assert re.search(r"default\?:\s*`?string", entries["default"]), \
    f"`default` must be declared a single string, got {entries['default']!r}"

# byRole's role set is part of the declared shape, not prose: a role outside it is a raise, so the
# enum has to be machine-readable from the same place the key set is.
inner = re.search(r"\{(.*)\}", entries["byRole"], re.S)
assert inner, f"`byRole` must declare its accepted roles inline, got {entries['byRole']!r}"
roles = optional_keys(inner.group(1), "byRole role")
assert set(roles) == {"finder", "verifier"} and len(roles) == 2, \
    f"byRole accepts exactly the roles finder and verifier, got {sorted(roles)}"

assert re.search(r"\{[^{}]*:\s*`?string", entries["byAgent"]), \
    f"`byAgent` must be declared a map to a model string, got {entries['byAgent']!r}"
PY

# === DECLARE-ONCE: the chain literal exists in exactly one place under lens/ ===
# count == 1, not >= 1. A resolution order restated in pipeline.md or engine/SKILL.md is a surface
# that has already begun to fork — and the second copy is the one that goes stale silently.
CHAIN='deny → record.model → byAgent → byRole → default → agent frontmatter → harness default'
CHAIN_HITS="$( { grep -rFo -- "$CHAIN" "$ROOT/lens" || true; } | wc -l | tr -d '[:space:]')"
[ "$CHAIN_HITS" -eq 1 ] \
  || fail "the precedence chain must be declared EXACTLY ONCE under lens/, found $CHAIN_HITS — engine-api.md § Model resolution owns it and every other file points at that section"
printf '%s\n' "$MODEL" | grep -qF -- "$CHAIN" \
  || fail "engine-api.md § Model resolution must carry the precedence chain literal: $CHAIN"

# Line-scoped helper: the selector picks the ONE line that makes a claim, and the literal must live on
# that same line. A section-wide grep would let a claim survive its own subject being renamed.
#
# The selector's SINGULARITY is asserted, not assumed — that is what makes "line-scoped" true. A
# selector matching several lines ORs them, so the pin passes while ANY one carries the literal, and
# the claim it is named for can be deleted outright. It happened here: `②–⑤` matched the denied-winner
# row AND the verifier-floor row (whose trailing clause reads "exactly as a denied ②–⑤ winner is"), and
# both carry the same code — so deleting the denied-winner row left every pin scoped to it green.
model_line_has(){ # model_line_has <line-selector> <required-literal> <why>
  local matched
  matched="$(printf '%s\n' "$MODEL" | grep -F -- "$1" || true)"
  one_line "$matched" "§ Model resolution '$1'"
  printf '%s\n' "$matched" | grep -qF -- "$2" || fail "$3"
}

# === THE TOP-LEVEL TYPE IS CHECKED FIRST, BEFORE ANY KEY ===
# Every malformation rule this section declares is KEY-scoped — an unknown key, a wrong-typed key, an
# unaccepted role — and a value that HAS no keys satisfies all of them vacuously. A modelPolicy passed as
# a JSON string therefore cleared pre-flight and was discarded silently: the run returned an ordinary
# non-degraded success with the `deny` gate simply gone, while a one-character key typo (`denyList`)
# raised. The type gate closes that, and the ORDER is half the rule: checked after the key rows, a
# wrong-typed policy has already passed them.
printf '%s\n' "$MODELFLAT" | grep -qF '`modelPolicy` must be an object' \
  || fail "engine-api.md § Model resolution must declare modelPolicy's top-level type — every key-scoped rule below it is satisfied vacuously by a value with no keys"
printf '%s\n' "$MODELFLAT" | grep -qF 'the top-level type is checked **first**, before any key is looked at' \
  || fail "the type gate must be ORDERED ahead of the key rules — a gate applied after them judges a policy that has already passed"
model_line_has 'the policy itself is not an object' 'E_INVALID_INPUT' \
  "engine-api.md § Model resolution must carry a malformation row for a modelPolicy that is not an object at all"
# NON-VACUITY: the gate has to enumerate the shapes it rejects, or 'not an object' is a rule with no
# subject — the same gap that let the array/number/bool forms through alongside the string one.
for shape in 'an array' 'a number' 'a bool'; do
  printf '%s\n' "$MODELFLAT" | grep -qF "$shape" \
    || fail "the type gate must name '$shape' among the non-object values it rejects"
done
# THE DEFENSIVE PARSE, and its boundary. injectedIntent and injectedFinders already declare it, so a
# serializing harness is forgiven here too — but the parse is not where the type stops mattering.
printf '%s\n' "$MODELFLAT" | grep -qF 'parsed defensively once' \
  || fail "a modelPolicy delivered as a JSON string must be parsed defensively — the sibling inputs declare the same posture, and modelPolicy fell outside it only because that rule was scoped to arrays"
printf '%s\n' "$INPUTS" | grep -qF 'an **object** for `modelPolicy`' \
  || fail "engine-api.md § lens:engine — inputs must extend the defensive-parse rule to modelPolicy's OBJECT form — scoped to arrays, the rule never reached it"
# WHY it raises rather than being ignored: the cost is invisible in the return, which is what makes a
# silent discard worse than a raise.
printf '%s\n' "$MODELFLAT" | grep -qF 'takes the `deny` gate down with it' \
  || fail "§ Model resolution must state what silently discarding a wrong-typed policy costs — the deny gate, on a run that still reports success"
# I-2 SAFETY: absent/null is NOT a wrong type. Without this exemption the gate would raise on the
# 1.4.3-shaped call that passes no policy at all, which floor i2-new-inputs-only forbids.
printf '%s\n' "$MODELFLAT" | grep -qF '`null` and an absent key are not a wrong type' \
  || fail "§ Model resolution must exempt null/absent from the type gate — without it a 1.4.3-shaped call could receive an envelope (I-2)"

# === THE FOUR KEYS ARE CLOSED, AND THE EMPTY POLICY IS VALID ===
printf '%s\n' "$MODEL" | grep -qF 'exactly these four optional keys, and no others' \
  || fail "engine-api.md § Model resolution must state that modelPolicy's four keys are the whole accepted set"
# Edge: an empty policy is a policy that constrains nothing. Its own pin, because "valid" and "must
# not raise" are separate promises — a doc could accept {} and still list it under the raise table.
model_line_has '`modelPolicy: {}` is **valid**' 'must not raise' \
  "engine-api.md § Model resolution must declare \`modelPolicy: {}\` valid AND explicitly must-not-raise"

# === MALFORMED → RAISE: three independent pins, each naming the code on its own row ===
# One pin per malformation, keyed to its own subject: a single region-wide grep for E_INVALID_INPUT
# stays satisfied by any one of the three rows surviving.
model_line_has '| an unknown key' 'E_INVALID_INPUT' \
  "engine-api.md § Model resolution must state that an unknown modelPolicy key raises E_INVALID_INPUT"
model_line_has '| a wrong-typed key' 'E_INVALID_INPUT' \
  "engine-api.md § Model resolution must state that a wrong-typed modelPolicy key raises E_INVALID_INPUT"
model_line_has '| a `byRole` role outside' 'E_INVALID_INPUT' \
  "engine-api.md § Model resolution must state that a byRole role outside finder/verifier raises E_INVALID_INPUT"

# === byRole COVERAGE: two roles, and what each one actually spans ===
# The role enum alone does not say what `finder` reaches. Without the coverage sentence a caller must
# guess whether a policy keyed `finder` governs the adapter tier and injectedFinders too.
printf '%s\n' "$MODEL" | grep -qF 'accepts exactly two roles' \
  || fail "engine-api.md § Model resolution must state that byRole accepts exactly two roles"
COVERAGE="$(printf '%s\n' "$MODEL" | grep -F 'every ANALYZE producer' || true)"
[ -n "$COVERAGE" ] || fail "engine-api.md § Model resolution must state which dispatches the finder role covers"
printf '%s\n' "$COVERAGE" | grep -qF '`finder`' \
  || fail "the ANALYZE-producer coverage must be keyed to the \`finder\` role on its own line"
for producer in 'five built-in finders' 'adapter tier' 'file-registered project tier' 'injectedFinders'; do
  printf '%s\n' "$COVERAGE" | grep -qF -- "$producer" \
    || fail "the finder-role coverage must name '$producer' among the ANALYZE producers it selects the model for"
done
model_line_has 'every VERIFY dispatch' '`verifier`' \
  "engine-api.md § Model resolution must state that the \`verifier\` role covers every VERIFY dispatch"

# === THE deny GATE IS A GATE ON THE WINNER, NOT A FILTER OVER THE CANDIDATES ===
# The section declared itself the single source of truth and then declared `deny` twice, incompatibly:
# position ① said it "decides which values are allowed" BEFORE the chain runs, while the denied-winner
# rule below requires a denied value to be able to WIN. Under the filter reading a denied value never
# yields, the chain falls through, and the ②–⑤ raise — this code's primary documented trigger —
# becomes unreachable. One call decides it: byRole:{finder:'haiku'} with deny:['haiku'] either silently
# runs on frontmatter or aborts pre-flight with zero finders. Pinned on the reading that makes the rest
# of the section coherent, with the retired one banned by name.
printf '%s\n' "$MODELFLAT" | grep -qF 'gate on the winner, not a filter over the candidates' \
  || fail "engine-api.md § Model resolution must state that deny gates the WINNER rather than filtering the candidates — under the filter reading the ②–⑤ raise is unreachable"
printf '%s\n' "$MODELFLAT" | grep -qF 'A denied model can therefore win' \
  || fail "§ Model resolution must state the consequence that makes the denied-winner rule reachable at all: a denied model CAN win the chain"
model_line_has '| ① | `deny` |' 'not a source and not a filter' \
  "the chain's ① row must carry the same reading as the prose — a gate on the winner, not a source and not a filter"
if printf '%s\n' "$MODELFLAT" | grep -qF 'it decides which values are allowed, never which one wins'; then
  fail "§ Model resolution must not restate deny as a pre-chain filter — that reading makes E_MODEL_POLICY_UNSATISFIABLE's primary trigger unreachable"
fi

# === DENIED-WINNER: EXACTLY TWO BRANCHES, each pinned on its own row ===
# The third row — substitute the highest-precedence allowed policy value for a denied ⑥–⑦ winner — was
# UNREACHABLE and is deleted. ③–⑤ are consulted before ⑥–⑦ and are matched to the dispatch site, so a
# dispatch that reaches ⑥–⑦ is one the policy was silent about there: the substitute set is empty by
# construction, not merely small. Keeping an unfirable branch declared is a promise a caller cannot
# collect on. The count is asserted, so a third row cannot creep back under any wording.
model_line_has '| ②–⑤ — a caller-supplied request' 'E_MODEL_POLICY_UNSATISFIABLE' \
  "engine-api.md § Model resolution must state that a denied winner from positions ②–⑤ raises E_MODEL_POLICY_UNSATISFIABLE"
model_line_has '| ②–⑤ — a caller-supplied request' 'never clamps' \
  "engine-api.md § Model resolution must state that an explicitly-requested denied model is never clamped"
model_line_has '| ⑥–⑦ — an implicit default |' 'E_MODEL_POLICY_UNSATISFIABLE' \
  "engine-api.md § Model resolution must state that a denied winner from ⑥–⑦ raises — there is no substitute branch"
model_line_has 'no allowed candidate' 'E_MODEL_POLICY_UNSATISFIABLE' \
  "engine-api.md § Model resolution must state WHY the ⑥–⑦ branch raises: the policy has offered no allowed candidate for that dispatch site"
# Scoped to the denied-winner TABLE itself, not to the section: § Model resolution carries three other
# tables (the chain, the malformation rows, the verifier floor) whose rows also open with a position
# glyph, so a section-wide count would be measuring the wrong thing.
DWTABLE="$(printf '%s\n' "$MODEL" | awk '/^\*\*Denied-winner rule\.\*\*/{inside=1;next} inside && /^\*\*/{exit} inside{print}')"
bounded "engine-api.md § Model resolution denied-winner table" 10 "$DWTABLE"
DW_ROWS="$(printf '%s\n' "$DWTABLE" | grep -cE '^\| [②③⑥⑦]' || true)"
[ "$DW_ROWS" -eq 2 ] \
  || fail "the denied-winner table must carry EXACTLY two outcome rows (found $DW_ROWS) — a third branch is either unreachable or a widening of what deny does"
printf '%s\n' "$MODELFLAT" | grep -qF 'There are **exactly two branches**' \
  || fail "§ Model resolution must state the branch count in prose as well as in the table — a count only a reader can derive is one a later edit will not notice breaking"
# NEGATIVE — the retired unreachable row, banned by its own pin, flattened so a re-wrapped revert
# cannot walk past it. Two independent literals: the row's discriminator and its outcome cell.
if printf '%s\n' "$MODELFLAT" | grep -qF 'with an allowed policy value available'; then
  fail "§ Model resolution must not restore the ⑥–⑦ substitution row — ③–⑤ are consulted first and site-scoped, so it can never fire"
fi
if printf '%s\n' "$MODELFLAT" | grep -qF '| **Substitute** the highest-precedence allowed policy value'; then
  fail "§ Model resolution must not restore the substitute OUTCOME cell — a branch a caller cannot reach is a promise it would be wrong to make"
fi

# === THE SAME NEGATIVE, WIDENED TO EVERY FILE UNDER lens/ ===
# The two pins above are scoped to § Model resolution — the section the row was deleted FROM, and the
# only place it could come back as a table row. That is not where a restatement actually reappears. The
# rule is declared once and POINTED AT from the procedure files, so the surface that re-grows a deleted
# branch is a step summarising the pointer in its own words — and that is exactly what happened:
# engine/SKILL.md Step 0 read "a denied winner substitutes or raises E_MODEL_POLICY_UNSATISFIABLE",
# naming an outcome the amended two-row rule no longer has, while every section-scoped pin above stayed
# green because none of them can see another file.
#
# Banned by OUTCOME PHRASING, never by the bare word "substitute". That word has four legitimate uses
# under lens/ and all four are DENIALS that a substitute exists — verifier.md's "no
# default/byRole/byAgent to substitute", adapter-dispatch.md's "never substituted for any part of it",
# engine-api.md's own "why there is no third, substituting branch", and the CHANGELOG's retirement note.
# A word ban would fire on all four on day one and be deleted by the next hand that hit it.
#
# And the STEM is a word ban wearing a subject. `denied…substitut` fires on any sentence carrying both
# tokens in that order, which is the shape of a DENIAL as much as of a restatement — "a denied model is
# never substituted for", "a denied value has no substitute", "the denied-winner rule replaced an
# earlier substitution branch" all trip it, and those are exactly the sentences the carve-out above
# exists to protect. The verb is therefore pinned in its ASSERTIVE forms — `substitutes` /
# `substituting` / the table cell's `**Substitute**` — which is what a restatement of the retired row
# has to use and what a denial of it cannot.
#
# Each file is FLATTENED before the scan, so a restatement wrapped across two physical lines is still
# one claim here; the patterns stay sentence-scoped (`[^.]*`) so flattening cannot marry a subject in
# one sentence to a verb in the next.
RETIRED_OUTCOME='denied[- ](winner|model|default|value)[^.]*(substitutes|substituting|\*\*Substitute\*\*)'
RETIRED_OUTCOME="$RETIRED_OUTCOME"'|substitutes? the highest-precedence allowed policy value'
RETIRED_OUTCOME="$RETIRED_OUTCOME"'|with an allowed policy value available'
RETIRED_OUTCOME="$RETIRED_OUTCOME"'|\*\*Substitute\*\* the highest-precedence allowed policy value'

# NON-VACUITY, both directions, before the scan runs. A negative pin whose regex matches nothing is
# indistinguishable from a passing one, and this pin's entire value is that it fires in a file the
# section-scoped pins cannot see. So it is proved to FIRE on the sentence that escaped and on the
# rewordings nearest it, and proved NOT to fire on the legitimate denials.
#
# The must-NOT-fire set SAMPLES THE SPACE rather than quoting the tree. Its first four entries are the
# four in-tree denials in their current word order, which proves the ban is not vacuous where it runs
# today and nothing more; a reworded denial, or a fifth one a later edit adds, is a sentence no
# tree-quoting probe describes. The four that follow are denials this tree does not contain — written
# to deny in each of the grammatical shapes the subject admits — because a carve-out is only worth the
# sentences it was tested against, and the ones it was NOT tested against are where it false-positives.
while IFS= read -r probe; do
  [ -n "$probe" ] || continue
  printf '%s\n' "$probe" | grep -qiE "$RETIRED_OUTCOME" \
    || fail "the retired-outcome ban does not match '$probe' — a negative that cannot fire is not a guard"
done <<'PROBES'
A denied winner substitutes or raises `E_MODEL_POLICY_UNSATISFIABLE` exactly as that rule decides.
A denied winner either substitutes the allowed value or raises.
The engine substitutes the highest-precedence allowed policy value for a denied implicit default.
A Denied model substitutes when an allowed candidate exists elsewhere in the policy.
| ⑥–⑦ — an implicit default, with an allowed policy value available | **Substitute** the highest-precedence allowed policy value |
A denied winner substitutes the highest-precedence allowed policy value.
A denied default resolves by substituting the next allowed value in the chain.
PROBES
while IFS= read -r legit; do
  [ -n "$legit" ] || continue
  if printf '%s\n' "$legit" | grep -qiE "$RETIRED_OUTCOME"; then
    fail "the retired-outcome ban false-positives on a legitimate denial — '$legit' — and a ban that fires on true prose is one the next edit deletes"
  fi
done <<'LEGIT'
Edge case: `deny:['opus']` with no `default`/`byRole`/`byAgent` to substitute leaves no allowed candidate (the denied-winner rule, same section).
the wrapper prompt rides behind the contract, never substituted for any part of it
silence has nothing to substitute: the substitute set is empty by construction, not merely small
An earlier draft declared a third row that substituted "the highest-precedence allowed policy value" for a denied implicit default
A denied model is never substituted for; both branches raise.
A denied value has no substitute, because 3-5 are site-scoped.
Both denied-winner branches raise; nothing is ever substituted.
The denied-winner rule replaced an earlier substitution branch.
LEGIT

# ONE FILE IS OUT OF SCOPE, and it is the one whose job is to say the row existed. The scan bans a
# restatement of a LIVE outcome; lens/CHANGELOG.md narrates the retirement in the past tense and has to
# be able to quote the row it retired, so a ban that reaches it is a ban that forbids disclosing the
# break. The exclusion is asserted to resolve — a renamed CHANGELOG must not silently become a file the
# scan skips and nobody notices — and it is exactly one path, so it cannot grow into a carve-out.
NARRATES="$ROOT/lens/CHANGELOG.md"
[ -f "$NARRATES" ] || fail "the excluded retirement narrative is missing: $NARRATES — the exclusion below is now a no-op on a path that does not exist"

SCANNED=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$f" != "$NARRATES" ] || continue
  SCANNED=$((SCANNED + 1))
  HIT="$( { flatten "$(cat "$f")" | grep -oiE "$RETIRED_OUTCOME" | head -1; } || true)"
  [ -z "$HIT" ] \
    || fail "${f#"$ROOT/"} restates the retired ⑥–⑦ substitution outcome ('$HIT') — the denied-winner rule has two branches and both raise, and every file outside § Model resolution points at that section rather than naming an outcome of its own"
done < <(find "$ROOT/lens" -type f)
# The scan reads a tree, not a guess about one: with nothing to walk it passes vacuously.
[ "$SCANNED" -ge 10 ] \
  || fail "the retired-outcome scan walked only $SCANNED files under lens/ — a scan with nothing to read is not a scan"

# ...and the reason the deletion is safe has to stay stated, or the next reader restores the row.
printf '%s\n' "$MODEL" | grep -qF 'are consulted **before** ⑥–⑦' \
  || fail "engine-api.md § Model resolution must state that ③–⑤ are consulted before ⑥–⑦ — the fact that makes the substitute set empty"
printf '%s\n' "$MODELFLAT" | grep -qF 'never a value keyed to some other agent or some other role' \
  || fail "§ Model resolution must keep the site-scoping of ③–⑤ — it is the other half of why no substitute exists"
printf '%s\n' "$MODELFLAT" | grep -qF 'the substitute set is empty by construction, not merely small' \
  || fail "§ Model resolution must say WHY there is no third branch, not merely that there are two — 'narrow by construction' is what let the unfirable row survive"
printf '%s\n' "$MODEL" | grep -qF 'name the agent in `byAgent`, name the role in `byRole`, or set' \
  || fail "engine-api.md § Model resolution must tell a caller how to keep a dispatch off the raise path"
# A policy outcome is a resolution or a raise, never partial coverage — mis-filing either as a degrade
# would report a policy working exactly as written as a coverage gap.
model_line_has 'never a degrade' 'degradedReasons' \
  "engine-api.md § Model resolution must state that NEITHER branch records anything in degradedReasons — a policy outcome is not a coverage gap"

# === THE FILE TIER IS NOT EXEMPT FROM deny (position ② covers both record forms) ===
# D1's "a file-registered record never raises" is scoped to MALFORMATION; deny gates a value the engine
# understands perfectly. Without this stated, the two promises read as a contradiction and whichever one
# a reader reaches first governs. The standalone-path guarantee is pinned with it, because it is the
# reason the two can both be true at once.
model_line_has 'file-registered** record whose `model` is well-formed but denied' 'raises' \
  "engine-api.md § Model resolution must state that a well-formed but denied file-registered model raises"
printf '%s\n' "$MODELFLAT" | grep -qF 'that posture is scoped to malformation**' \
  || fail "engine-api.md § Model resolution must scope the file tier's normalize-or-drop posture to malformation, so deny and D1 stop contradicting"
printf '%s\n' "$MODELFLAT" | grep -qF 'never meet on the standalone path' \
  || fail "engine-api.md § Model resolution must state that deny and the file tier never meet on the standalone /lens:review path"

# === THE VERIFIER FLOOR (floor: verifier-never-below-floor) ===
# verifier.md asserts the skeptic "never resolves below the never-Haiku floor". That is a safety claim,
# and a safety claim with no mechanism behind it is worse than none — a caller reads it as enforced.
# The mechanism lives here, in the one section that governs model selection, and is pinned on four
# independent axes: that it exists, what it matches, what it does, and who it applies to.
printf '%s\n' "$MODEL" | grep -qF 'never-Haiku floor' \
  || fail "FLOOR: engine-api.md § Model resolution must declare the never-Haiku floor — verifier.md claims it and this is the only section that can enforce it"
printf '%s\n' "$MODELFLAT" | grep -qF 'Every `verifier`-role dispatch also passes a **never-Haiku floor**' \
  || fail "FLOOR: the never-Haiku floor must be declared on the verifier-role dispatch, not as free-floating prose"
# MATCHING — declared, not left to the reader: 'haiku' by substring, case-insensitively, so a dated id
# is below the floor without the floor enumerating one (the same reason deny matches that way).
printf '%s\n' "$MODELFLAT" | grep -qF 'floor matches the way `deny` matches' \
  || fail "FLOOR: the never-Haiku floor must declare its matching rule — an unmatched floor is a floor a dated model id walks past"
printf '%s\n' "$MODELFLAT" | grep -qF 'resolved id containing `haiku` is below it' \
  || fail "FLOOR: the never-Haiku floor must say concretely which resolved ids are below it"
# WHAT IT DOES — raise, never a silent downgrade. Pinned on the ③–⑤ row so it names the branch it governs.
model_line_has '③–⑤ — a caller-supplied policy value below the floor' 'E_MODEL_POLICY_UNSATISFIABLE' \
  "FLOOR: a caller-supplied policy value below the floor must RAISE, not be clamped or ignored"
printf '%s\n' "$MODEL" | grep -qF 'never silently downgrades the skeptic' \
  || fail "FLOOR: § Model resolution must state that lens never silently downgrades the adversarial skeptic"
# WHERE IT IS APPLIED — pre-flight, the one stage allowed to raise (I-1).
printf '%s\n' "$MODEL" | grep -qF 'applied in pre-flight' \
  || fail "FLOOR: the never-Haiku floor must be applied in pre-flight — a floor enforced later could not raise without breaking I-1"
# SCOPE — verifier-only. A floor silently widened to every finder would change what a caller's cheap
# finder policy does, so the narrowness is asserted rather than left implied.
printf '%s\n' "$MODELFLAT" | grep -qF 'floor is verifier-only' \
  || fail "FLOOR: § Model resolution must state that the floor is verifier-only — a finder dispatch is gated by deny alone"
# I-2 — the floor cannot make a 1.4.3-shaped call raise: with no modelPolicy the verifier resolves at ⑥.
printf '%s\n' "$MODELFLAT" | grep -qF 'call never meets the floor' \
  || fail "FLOOR: § Model resolution must state that a 1.4.3-shaped call never meets the floor (I-2)"

# === MATCHING: two independent pins, each with its worked example ===
# deny is broad on purpose; byAgent is exact on purpose. They are opposite promises, so losing either
# one must fail on its own rather than behind the other surviving.
printf '%s\n' "$MODEL" | grep -qF 'case-insensitively, by substring, against the resolved model id' \
  || fail "engine-api.md § Model resolution must state that deny matches case-insensitively by substring against the resolved model id"
printf '%s\n' "$MODEL" | grep -qF 'claude-haiku-4-5-20251001' \
  || fail "engine-api.md § Model resolution must carry the worked deny example against a dated model id"
printf '%s\n' "$MODEL" | grep -qF 'matches the `agent` value verbatim' \
  || fail "engine-api.md § Model resolution must state that byAgent matches the agent value verbatim"
model_line_has 'no plugin-prefix stripping' 'no normalization' \
  "engine-api.md § Model resolution must state that byAgent applies no normalization and no plugin-prefix stripping"
model_line_has 'matali:principles-finder' 'does **not** match' \
  "engine-api.md § Model resolution must carry the plugin-qualified non-match example for byAgent"

# === NEGATIVE DECLARE-ONCE: no procedure file re-declares the policy shape ===
# byRole and byAgent on one line is what a restated shape looks like; the procedure files point at
# § Model resolution instead. Mirrors the existing `Array<{` bans on these same files.
NEG_FILES=(
  "$ROOT/lens/skills/engine/references/pipeline.md"
  "$ROOT/lens/skills/engine/SKILL.md"
  "$ROOT/lens/skills/engine/references/finder-registry.md"
  "$ROOT/lens/CLAUDE.md"
)
for f in "${NEG_FILES[@]}"; do
  [ -s "$f" ] || fail "missing $f"
  if printf '%s\n' "$( { grep -F 'byRole' "$f" || true; } )" | grep -qF 'byAgent'; then
    fail "${f#"$ROOT/"} must not co-declare byRole and byAgent — engine-api.md § Model resolution owns the modelPolicy shape"
  fi
done

# === WHERE THE POLICY IS READ: pre-flight, once — not at each dispatch site ===
# The declaration above says what a policy MEANS; this says WHERE it is read. Both halves are load-
# bearing: a shape declared but resolved per-dispatch would re-read the policy mid-run, which is exactly
# what "resolved once in pre-flight and never re-read mid-run" promises it does not do.
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
[ -s "$ESKILL" ] || fail "missing $ESKILL"
ESTEP0="$(awk 'index($0,"## Step 0")==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$ESKILL")"
bounded "engine/SKILL.md Step 0 (PRE-FLIGHT)" 30 "$ESTEP0"
step0_line_has(){ # step0_line_has <line-selector> <required-literal> <why>
  local matched
  matched="$(printf '%s\n' "$ESTEP0" | grep -F -- "$1" || true)"
  one_line "$matched" "engine/SKILL.md Step 0 '$1'"
  printf '%s\n' "$matched" | grep -qF -- "$2" || fail "$3"
}

step0_line_has 'modelPolicy' 'four-key shape' \
  "engine/SKILL.md Step 0 must validate modelPolicy against its declared four-key shape"
# The runtime orders the two checks the same way the declaration does. A pre-flight that reaches the
# four-key shape first has already accepted a policy with no keys — the ordering IS the rule here, so it
# is pinned on the procedure side as well as on the declaration side.
step0_line_has 'modelPolicy' 'top-level type first' \
  "engine/SKILL.md Step 0 must check modelPolicy's top-level type BEFORE its four-key shape — the key-scoped checks cannot judge a value that has no keys"
step0_line_has 'Resolve the model plan' 'every producer' \
  "engine/SKILL.md Step 0 must resolve the model plan for every producer, once, in pre-flight"
step0_line_has '§ Model resolution' 'references/engine-api.md' \
  "engine/SKILL.md Step 0 must resolve BY POINTER to engine-api.md § Model resolution"

# =====================================================================================
# === DISPATCH OBLIGATION (AC15 / AC21 / verifier-never-below-floor): the resolved   ===
# === model actually rides every dispatch — not just declared, but wired at each site ===
# =====================================================================================
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ADAPTER="$ROOT/lens/skills/engine/references/adapter-dispatch.md"
VERIFIER="$ROOT/lens/agents/verifier.md"
for f in "$PIPE" "$ADAPTER" "$VERIFIER"; do [ -s "$f" ] || fail "missing $f"; done

# A wrapped markdown sentence is one claim across several physical lines; flattening is what lets a
# pin quote the claim verbatim instead of guessing where the author's wrap landed.
pregion2(){ awk -v h="$1" 'index($0,h)==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$PIPE"; }
eregion2(){ awk -v h="$1" 'index($0,h)==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$ESKILL"; }

ESTEP3="$(eregion2 '## Step 3')"
bounded "engine/SKILL.md Step 3 (Analyze)" 25 "$ESTEP3"
ESTEP4="$(eregion2 '## Step 4')"
bounded "engine/SKILL.md Step 4 (Verify + dedup + rank)" 20 "$ESTEP4"
PSEC3="$(pregion2 '## 3.')"
bounded "pipeline.md §3 (parallel dispatch)" 90 "$PSEC3"
PSEC5="$(pregion2 '## 5.')"
bounded "pipeline.md §5 (verify + vote aggregation)" 45 "$PSEC5"
PSEC8="$(pregion2 '## 8.')"
bounded "pipeline.md §8 (huge-diff rule + fan-out cap)" 45 "$PSEC8"
PART1="$(awk '/^## Part 1 —/{inside=1;next} /^## /{if(inside)exit} inside{print}' "$ADAPTER")"
bounded "adapter-dispatch.md Part 1 (forcing wrapper-prompt)" 35 "$PART1"

CLAUSE='the model Step 0 resolved for this producer'
TRANSPORT="the Agent/Task tool's \`model\` parameter"

# === (1) ONE INDEPENDENT PIN PER ANALYZE DISPATCH SITE — engine/SKILL.md Step 3 ===
# A partial rollout must name the producer it left behind, not hide behind the other four surviving.
STEP3_DISPATCH="$(printf '%s\n' "$ESTEP3" | grep -F -- "$CLAUSE" || true)"
[ -n "$STEP3_DISPATCH" ] \
  || fail "engine/SKILL.md Step 3 must state that dispatch uses $CLAUSE"
for site in '3 fixed built-ins' 'adherence fan-out' 'adapter tier' 'file-registered project tier' 'injectedFinders'; do
  printf '%s\n' "$STEP3_DISPATCH" | grep -qF -- "$site" \
    || fail "engine/SKILL.md Step 3's dispatch clause must name '$site' among the ANALYZE producers it governs"
done
printf '%s\n' "$STEP3_DISPATCH" | grep -qF -- "$TRANSPORT" \
  || fail "engine/SKILL.md Step 3 must name the transport explicitly: $TRANSPORT"

# === (1) SAME, at pipeline.md §3 — its own governing site, not a restatement masked by Step 3 ===
# Line-scoped, not whole-region: a whole-region flatten would let a producer name already mentioned
# elsewhere in §3 (for unrelated reasons) satisfy this pin with no dispatch clause present at all.
PSEC3_DISPATCH="$(printf '%s\n' "$PSEC3" | grep -F -- "$CLAUSE" || true)"
[ -n "$PSEC3_DISPATCH" ] \
  || fail "pipeline.md §3 must state that dispatch uses $CLAUSE"
for site in '3 fixed built-ins' 'adherence fan-out' 'adapter tier' 'file-registered project tier' 'injectedFinders'; do
  printf '%s\n' "$PSEC3_DISPATCH" | grep -qF -- "$site" \
    || fail "pipeline.md §3's dispatch clause must name '$site' among the ANALYZE producers it governs"
done
printf '%s\n' "$PSEC3_DISPATCH" | grep -qF -- "$TRANSPORT" \
  || fail "pipeline.md §3 must name the transport explicitly: $TRANSPORT"

# === (1) VERIFY dispatch site — engine/SKILL.md Step 4 and pipeline.md §5 ===
STEP4_DISPATCH="$(printf '%s\n' "$ESTEP4" | grep -F -- "$CLAUSE" || true)"
[ -n "$STEP4_DISPATCH" ] \
  || fail "engine/SKILL.md Step 4 must state that every verifier vote dispatches with $CLAUSE"
printf '%s\n' "$STEP4_DISPATCH" | grep -qF 'verifier' \
  || fail "engine/SKILL.md Step 4's dispatch clause must name the verifier vote as its site"
printf '%s\n' "$STEP4_DISPATCH" | grep -qF -- "$TRANSPORT" \
  || fail "engine/SKILL.md Step 4 must name the transport explicitly: $TRANSPORT"

PSEC5_DISPATCH="$(printf '%s\n' "$PSEC5" | grep -F -- "$CLAUSE" || true)"
[ -n "$PSEC5_DISPATCH" ] \
  || fail "pipeline.md §5 must state that every verifier vote dispatches with $CLAUSE"
printf '%s\n' "$PSEC5_DISPATCH" | grep -qF 'verifier' \
  || fail "pipeline.md §5's dispatch clause must name the verifier vote as its site"
printf '%s\n' "$PSEC5_DISPATCH" | grep -qF -- "$TRANSPORT" \
  || fail "pipeline.md §5 must name the transport explicitly: $TRANSPORT"

# === (2) already checked per-site above — repeated once more, tree-scoped, as a non-vacuity floor ===
grep -qF -- "$TRANSPORT" "$ESKILL" || fail "engine/SKILL.md must name the transport explicitly: $TRANSPORT"
grep -qF -- "$TRANSPORT" "$PIPE" || fail "pipeline.md must name the transport explicitly: $TRANSPORT"

# === (3) adapter-dispatch.md Part 1: BOTH the resolved model and the effort directive ===
FLATPART1="$(flatten "$PART1")"
printf '%s\n' "$FLATPART1" | grep -qF -- "$CLAUSE" \
  || fail "adapter-dispatch.md Part 1 must state that the resolved model rides the same dispatch: $CLAUSE"
printf '%s\n' "$FLATPART1" | grep -qF -- "$TRANSPORT" \
  || fail "adapter-dispatch.md Part 1 must name the transport explicitly: $TRANSPORT"
printf '%s\n' "$FLATPART1" | grep -qF 'effort' \
  || fail "adapter-dispatch.md Part 1 must still carry the effort directive alongside the resolved model"
# RETENTION — the read-only findings-only forcing sentence and the validation-backstop paragraph,
# pinned verbatim, so wiring the model in cannot have displaced either.
printf '%s\n' "$FLATPART1" | grep -qF 'You are running as a **read-only, findings-only** lens adapter.' \
  || fail "adapter-dispatch.md Part 1 must keep its read-only, findings-only contract sentence verbatim"
printf '%s\n' "$FLATPART1" | grep -qF 'the wrapper raises the hit rate; it does not replace validation' \
  || fail "adapter-dispatch.md Part 1 must keep the validation-backstop paragraph verbatim"

# === (4) verifier.md: model: opus retained UNCHANGED, AND declared an overridable default above the floor ===
VFRONT="$(awk '/^---$/{n++; next} n==1{print}' "$VERIFIER")"
[ -n "$VFRONT" ] || fail "verifier.md frontmatter block is empty"
printf '%s\n' "$VFRONT" | grep -qxF 'model: opus' \
  || fail "RETENTION: verifier.md frontmatter must keep 'model: opus' unchanged"
grep -qF 'overridable default' "$VERIFIER" \
  || fail "verifier.md must declare model: opus an overridable default"
grep -qF 'never-Haiku floor' "$VERIFIER" \
  || fail "verifier.md must state the floor: it never resolves below the never-Haiku floor"
# THE CLAIM MUST CITE ITS MECHANISM. An agent file asserting a safety invariant with nothing behind it
# is the failure mode this pin exists for: a reader (and a caller) takes it as enforced. verifier.md
# does not enforce anything — it is a prompt — so the claim has to name the section that does, and that
# section has to actually carry the floor (asserted above, on § Model resolution's own body).
FLOORCLAIM="$(grep -F 'never-Haiku floor' "$VERIFIER" || true)"
printf '%s\n' "$FLOORCLAIM" | grep -qF 'engine-api.md` § Model resolution' \
  || fail "verifier.md's never-Haiku floor claim must cite engine-api.md § Model resolution — the section that enforces it"
printf '%s\n' "$FLOORCLAIM" | grep -qF 'pre-flight' \
  || fail "verifier.md's floor claim must say where the floor is applied: when the model plan is resolved in pre-flight"

# === (5) verifier.md: n votes may run, and the ENGINE aggregates — by POINTER, not restatement ===
grep -qF 'n votes may run' "$VERIFIER" \
  || fail "verifier.md must state that n votes may run for the same finding"
grep -qF 'the engine aggregates' "$VERIFIER" \
  || fail "verifier.md must state that the engine aggregates the votes"
grep -qF 'huginn-quorum-v1' "$VERIFIER" \
  || fail "verifier.md must name the governing rule huginn-quorum-v1 by pointer"
grep -qF 'references/pipeline.md' "$VERIFIER" \
  || fail "verifier.md must point at pipeline.md for the governing vote-resolution procedure rather than restate it"
# NEGATIVE — the retired restatement (three-key schema shape) and the retired unanimous-drop rule must
# never come back. Each is its own pin: a partial revert must name the one it brought back.
#
# Both are judged against a backtick-stripped AND FLATTENED copy of the file. Backtick-stripped because
# the retired wording spelled `refuted:true` as a markdown code span, so a plain-text grep would never
# match the very sentence it exists to ban. Flattened because a `grep -F` is LINE-scoped, and a retired
# markdown sentence re-wrapped across two physical lines is the same claim with the ban matching
# neither half — a deliberately re-wrapped revert walked straight past both of these. flatten() is the
# same helper the adapter Part 1 pins above already use; the tolerated-whitespace regex is what lets
# the votes-shape ban survive a wrap landing inside the token itself. Only these ABSENCE pins are
# flattened — a positive pin flattened whole-file would stop being able to tell which line made its claim.
VERIFIER_PLAIN="$(flatten "$(tr -d '`' < "$VERIFIER")")"
if printf '%s\n' "$VERIFIER_PLAIN" | grep -qE 'votes *\{ *total, *couldNotRefute, *refuted *\}'; then
  fail "verifier.md must not restate the schema's votes shape — it is four keys now (pipeline.md §5 / engine-api.md govern it)"
fi
if printf '%s\n' "$VERIFIER_PLAIN" | grep -qF 'a refuted:true vote drops the finding from the surviving set'; then
  fail "verifier.md must not restate the retired unanimous-drop rule — huginn-quorum-v1 (not a single refuted:true vote) governs drop"
fi

# === (6) EDGE 4 WORKED EXAMPLE: deny:['opus'] with no substitute ⇒ RAISE, never a silent downgrade ===
grep -qF "deny:['opus']" "$VERIFIER" \
  || fail "verifier.md must carry the edge-4 worked example: deny:['opus']"
grep -qF 'no allowed candidate' "$VERIFIER" \
  || fail "verifier.md's edge-4 example must state it leaves no allowed candidate"
grep -qiE 'raises rather than' "$VERIFIER" \
  || fail "verifier.md's edge-4 example must state the run RAISES rather than silently downgrading"
grep -qiE 'silently downgrad' "$VERIFIER" \
  || fail "verifier.md's edge-4 example must state the adversarial skeptic is never silently downgraded"
# I-1 SAFETY: verifier.md is NOT allow-listed to carry an error code (E_ALLOWED is API/ESKILL/CAPSKILL
# only) — the raise above must be phrased without a bare E_ code leaking into this file.
if grep -qE '(^|[^A-Za-z0-9_])E_[A-Z]' "$VERIFIER"; then
  fail "verifier.md must not name a bare E_ code — it is not an allow-listed error-raising file; phrase the raise without it"
fi

# === (7) pipeline.md §8: the verify fan-out bound is stated and independent of the ANALYZE cap ===
printf '%s\n' "$PSEC8" | grep -qF 'n ≤ 5' \
  || fail "pipeline.md §8 must state the verify fan-out bound: one parallel batch of n ≤ 5 votes per surviving candidate"
printf '%s\n' "$PSEC8" | grep -qF 'neither governs nor is governed by' \
  || fail "pipeline.md §8 must state the verify fan-out bound neither governs nor is governed by the ≤8-adherence / ≤11-finder cap"
# RETENTION — §8's pre-existing pins still pass (source-agnostic + the three 'name the skipped …' pins).
printf '%s\n' "$PSEC8" | grep -qF 'source-agnostic' \
  || fail "RETENTION: pipeline.md §8 must keep the source-agnostic cap"
for phrase in 'name the skipped specs/plans' 'name the skipped injected docs' 'name the skipped finders'; do
  printf '%s\n' "$PSEC8" | grep -qF -- "$phrase" \
    || fail "RETENTION: pipeline.md §8 must keep '$phrase'"
done

# === (8) RETENTION: verifier.md's fenced JSON block still parses; its unverified-flagged sites survive ===
python3 - "$VERIFIER" <<'PY' || fail "verifier.md's fenced JSON example no longer parses"
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r'```json\n(.*?)\n```', text, re.S)
assert blocks, "verifier.md must still carry a fenced json Output Format example"
for block in blocks:
    json.loads(block)
PY
VUFCOUNT="$( { grep -cF 'unverified-flagged' "$VERIFIER" || true; } | tr -d '[:space:]')"
[ "$VUFCOUNT" -ge 4 ] \
  || fail "RETENTION: verifier.md must keep at least four 'unverified-flagged' sites (found $VUFCOUNT)"
if grep -q 'abstained' "$VERIFIER"; then
  fail "verifier.md must not name 'abstained' — the one-skeptic layer keeps its own vocabulary (R4 / SP-10 scar guard)"
fi

# === THE RULE HAS A NAME, DECLARED HERE AND ADVERTISED THERE ===
# `huginn-quorum-v1` proved the pattern: a named rule can be advertised by `lens:capability` without
# the advertised set having to restate it. Model resolution had no name, so the advertised value was
# an arrow string — a SIX-position restatement of this seven-position chain — and the declare-once
# rule this section opens with was broken by the surface meant to describe it. The name closes that at
# the root. Pinned in both directions: declared beside the chain here, and advertised there (the
# capability half lives in tests/lens/test_capability.sh, which reads it from the skill's own JSON).
printf '%s\n' "$MODELFLAT" | grep -qF 'The chain has a **name**: `lens-model-precedence-v1`' \
  || fail "engine-api.md § Model resolution must give the chain a NAME — an unnamed rule can only be advertised by restating it, and a restatement forks"
printf '%s\n' "$MODELFLAT" | grep -qF 'supports.resolutionRules.model' \
  || fail "the name must say which advertised slot carries it, so the declaration and the advertisement move together"
printf '%s\n' "$MODELFLAT" | grep -qF 'huginn-quorum-v1' \
  || fail "the naming rule must cite huginn-quorum-v1 as the precedent it follows — one convention for named rules, not two"
printf '%s\n' "$MODELFLAT" | grep -qF 'A rule NAME is what the advertised set carries' \
  || fail "§ Model resolution must state the rule the name exists to enforce: the advertised set carries names, never restatements"
# The advertised value and the declared name are the SAME string, derived from both files.
ADVERTISED_MODEL_RULE="$(python3 - "$ROOT/lens/skills/capability/SKILL.md" <<'PY'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
reports = [json.loads(b) for b in re.findall(r"```json\n(.*?)\n```", text, re.S)]
reports = [r for r in reports if isinstance(r, dict) and "capabilities" in r]
assert len(reports) == 1
print(reports[0]["supports"]["resolutionRules"]["model"])
PY
)"
printf '%s\n' "$MODEL" | grep -qF -- "$ADVERTISED_MODEL_RULE" \
  || fail "capability advertises the model rule as '$ADVERTISED_MODEL_RULE', which § Model resolution does not declare — the advertised name must resolve to this section"

# =====================================================================================
# === THE EXECUTABLE RULE: lens-model-precedence-v1 implemented ONCE, run over a     ===
# === matrix of (modelPolicy, record, agent, role) cases                            ===
# =====================================================================================
# Everything above pins the PROSE. Prose cannot be executed, so the strongest available proof that the
# chain, the two gates and their outcomes actually compose is data — the same argument, and the same
# shape, as tests/lens/test_verify_votes.sh's huginn-quorum-v1 block. Model resolution is the denser of
# the two rules (a gate on the winner, five precedence levels, a substring floor, and a raise that
# depends on WHICH position won), and it governs a cost/compliance control, yet it was the one proved
# only by grepping English.
#
# The POSITION ORDER is derived from the chain literal in the doc, not typed into this belt: re-listing
# it here would make the belt a second declaration of the very thing § Model resolution owns.
python3 - "$CHAIN" "$VERIFIER" <<'PY' || fail "lens-model-precedence-v1 does not resolve as § Model resolution declares"
import re, sys

chain_literal, verifier_path = sys.argv[1], sys.argv[2]

# --- the declared order, read off the doc ---
positions = [p.strip().strip("`") for p in chain_literal.split("→")]
assert positions == ["deny", "record.model", "byAgent", "byRole", "default",
                     "agent frontmatter", "harness default"], \
    f"the chain literal no longer declares the seven positions this rule implements: {positions}"
SOURCES = positions[1:]          # `deny` is a gate, not a source — it yields nothing
CALLER_CHOSEN = set(SOURCES[:4]) # ②–⑤: the positions a caller supplied a value for
IMPLICIT = set(SOURCES[4:])      # ⑥–⑦: the defaults nobody requested

# --- the verifier's frontmatter default, read from the agent file rather than assumed ---
front = re.search(r"^---\n(.*?)\n---", open(verifier_path, encoding="utf-8").read(), re.S)
assert front, "verifier.md must open with a frontmatter block"
m = re.search(r"^model:\s*(\S+)\s*$", front.group(1), re.M)
assert m, "verifier.md frontmatter must declare a model:"
VERIFIER_FRONTMATTER = m.group(1)

HARNESS_DEFAULT = "harness-default-model"
FINDER_FRONTMATTER = "sonnet"

class Raise(Exception):
    def __init__(self, gate): self.gate = gate

def denied(policy, model):
    """deny matches case-insensitively, BY SUBSTRING, against the resolved model id."""
    return any(entry.lower() in model.lower() for entry in (policy or {}).get("deny", []))

def below_floor(role, model):
    """The never-Haiku floor matches the way deny matches, and is verifier-only."""
    return role == "verifier" and "haiku" in model.lower()

def resolve(policy, record, agent, role, frontmatter="__role__"):
    """lens-model-precedence-v1 — implemented once, in the declared order.

    `deny` is a GATE ON THE WINNER, not a filter over the candidates: the chain resolves first and the
    gates judge what won. That is what makes the caller-chosen raise reachable at all.

    `frontmatter=None` models a dispatched agent that declares no `model:` line at all — the only way
    position ⑦ is ever reached, and the reason it is a position rather than a footnote: the adapter and
    project tiers dispatch agents lens does not ship and cannot assume carry one.
    """
    policy = policy or {}
    if frontmatter == "__role__":
        frontmatter = VERIFIER_FRONTMATTER if role == "verifier" else FINDER_FRONTMATTER
    candidates = {
        "record.model":      (record or {}).get("model"),
        "byAgent":           policy.get("byAgent", {}).get(agent),   # verbatim key, no normalization
        "byRole":            policy.get("byRole", {}).get(role),
        "default":           policy.get("default"),
        "agent frontmatter": frontmatter,
        "harness default":   HARNESS_DEFAULT,
    }
    for source in SOURCES:
        won = candidates[source]
        if won is None:
            continue
        if denied(policy, won):
            raise Raise("deny")            # both branches raise; only the reason differs
        if below_floor(role, won):
            raise Raise("verifier-floor")
        return source, won
    raise AssertionError("the chain fell through — position ⑦ always yields")

def outcome(policy, record, agent, role, frontmatter="__role__"):
    try:
        return ("dispatch",) + resolve(policy, record, agent, role, frontmatter)
    except Raise as r:
        return ("raise", r.gate)

CASES = [
    # label, policy, record, agent, role, expected[, frontmatter]
    ("no policy at all resolves at frontmatter — the 1.4.3 path (I-2)",
     None, None, "correctness", "finder", ("dispatch", "agent frontmatter", FINDER_FRONTMATTER)),
    ("an empty policy constrains nothing and must not raise",
     {}, None, "correctness", "finder", ("dispatch", "agent frontmatter", FINDER_FRONTMATTER)),
    ("no policy: every verifier vote resolves at ⑥ to the frontmatter model (I-2, the floor is unreachable)",
     None, None, "verifier", "verifier", ("dispatch", "agent frontmatter", VERIFIER_FRONTMATTER)),
    # --- ORDER: each position wins only when every position left of it is silent ---
    ("record.model outranks byAgent, byRole and default",
     {"byAgent": {"correctness": "a"}, "byRole": {"finder": "b"}, "default": "c"},
     {"model": "record-model"}, "correctness", "finder", ("dispatch", "record.model", "record-model")),
    ("byAgent outranks byRole and default",
     {"byAgent": {"correctness": "by-agent"}, "byRole": {"finder": "b"}, "default": "c"},
     None, "correctness", "finder", ("dispatch", "byAgent", "by-agent")),
    ("byRole outranks default",
     {"byRole": {"finder": "by-role"}, "default": "c"},
     None, "correctness", "finder", ("dispatch", "byRole", "by-role")),
    ("default wins when the policy names neither this agent nor this role",
     {"default": "the-default"}, None, "correctness", "finder", ("dispatch", "default", "the-default")),
    ("frontmatter wins when the policy supplies nothing for this site",
     {"byAgent": {"some-other-agent": "x"}, "byRole": {"verifier": "y"}},
     None, "correctness", "finder", ("dispatch", "agent frontmatter", FINDER_FRONTMATTER)),
    # --- byAgent matches the agent value VERBATIM: no prefix stripping ---
    ("byAgent does NOT match a plugin-qualified agent under its bare name",
     {"byAgent": {"principles-finder": "x"}, "default": "the-default"},
     None, "matali:principles-finder", "finder", ("dispatch", "default", "the-default")),
    ("byAgent matches the plugin-qualified spelling exactly",
     {"byAgent": {"matali:principles-finder": "qualified"}, "default": "the-default"},
     None, "matali:principles-finder", "finder", ("dispatch", "byAgent", "qualified")),
    # --- THE DENY GATE, on each of the caller-chosen positions ---
    ("a denied record.model raises — a caller's explicit request is never clamped",
     {"deny": ["haiku"], "default": "opus"},
     {"model": "claude-haiku-4-5"}, "correctness", "finder", ("raise", "deny")),
    ("a denied byRole winner raises EVEN THOUGH an allowed default exists",
     {"deny": ["haiku"], "byRole": {"finder": "claude-haiku-4-5"}, "default": "opus"},
     None, "correctness", "finder", ("raise", "deny")),
    ("deny matches case-insensitively and by substring against a dated id",
     {"deny": ["HAIKU"]}, {"model": "claude-haiku-4-5-20251001"}, "correctness", "finder",
     ("raise", "deny")),
    ("a denied IMPLICIT default raises too — there is no substitute branch",
     {"deny": ["sonnet"]}, None, "correctness", "finder", ("raise", "deny")),
    ("a deny list that matches nothing gates nothing",
     {"deny": ["haiku"], "default": "opus"}, None, "correctness", "finder",
     ("dispatch", "default", "opus")),
    # --- THE VERIFIER FLOOR: a second gate, verifier-only ---
    ("a policy value below the never-Haiku floor raises on a verifier dispatch",
     {"byRole": {"verifier": "claude-haiku-4-5"}}, None, "verifier", "verifier",
     ("raise", "verifier-floor")),
    ("the floor catches a dated Haiku id by substring, like deny",
     {"default": "claude-haiku-4-5-20251001"}, None, "verifier", "verifier",
     ("raise", "verifier-floor")),
    ("the floor is VERIFIER-ONLY — a finder may run on Haiku",
     {"byRole": {"finder": "claude-haiku-4-5"}}, None, "correctness", "finder",
     ("dispatch", "byRole", "claude-haiku-4-5")),
    ("a verifier dispatch above the floor resolves normally",
     {"byRole": {"verifier": "opus"}}, None, "verifier", "verifier", ("dispatch", "byRole", "opus")),
    # --- POSITION ⑦, the only way to reach it: an agent carrying no `model:` at all ---
    ("the harness default wins for an agent with no frontmatter model and no policy value",
     {}, None, "some-project-finder", "finder",
     ("dispatch", "harness default", HARNESS_DEFAULT), None),
    ("a denied harness default raises — ⑦ is an implicit default like any other",
     {"deny": ["harness"]}, None, "some-project-finder", "finder", ("raise", "deny"), None),
]

for case in CASES:
    label, policy, record, agent, role, expected = case[:6]
    frontmatter = case[6] if len(case) > 6 else "__role__"
    got = outcome(policy, record, agent, role, frontmatter)
    assert got == expected, f"{label}: expected {expected}, got {got}"

# NON-VACUITY. A matrix that never reaches a position, never fires a gate, or never dispatches proves
# nothing about the parts it skipped — and a resolve() that raised on everything would satisfy every
# raise case above on its own.
winners = {c[5][1] for c in CASES if c[5][0] == "dispatch"}
assert winners == set(SOURCES), (
    "the matrix must exercise EVERY chain position as the winner at least once; "
    f"never-won={sorted(set(SOURCES) - winners)}"
)
gates = {c[5][1] for c in CASES if c[5][0] == "raise"}
assert gates == {"deny", "verifier-floor"}, \
    f"the matrix must fire BOTH gates, saw {sorted(gates)}"
assert any(c[5][0] == "raise" and c[1] and c[1].get("deny") and not (c[2] or {}).get("model")
           and "byRole" not in c[1] for c in CASES), \
    "the matrix must include a denied IMPLICIT default (⑥–⑦) — that is the branch whose substitute row was deleted"
assert sum(1 for c in CASES if c[5][0] == "dispatch") >= 10, \
    "the matrix must dispatch far more often than it raises, or 'raise on everything' would pass it"
PY

echo PASS
