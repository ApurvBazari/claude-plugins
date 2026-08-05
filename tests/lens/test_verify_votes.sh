#!/usr/bin/env bash
# shellcheck disable=SC2016 # every single-quoted literal here is a grepped markdown code span, not shell expansion
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

# House idiom (tests/lens/test_engine_api.sh): every extracted region is asserted non-empty AND
# bounded. An extractor whose terminator stops matching does not go empty — it swallows the rest of
# the file, so every pin scoped to it silently becomes a whole-file grep. A ceiling catches that.
bounded(){ # bounded <region-name> <max-lines> <region-text>
  [ -n "$3" ] || fail "$1 is empty"
  local n
  n="$(printf '%s\n' "$3" | wc -l | tr -d '[:space:]')"
  [ "$n" -le "$2" ] || fail "$1 grew to $n lines (ceiling $2) — its extractor lost its terminator"
}

# House idiom (tests/lens/test_injected_finders.sh, tests/lens/test_model_policy.sh): a wrapped markdown
# sentence is one claim across several physical lines, and flattening is what lets a pin judge the claim
# instead of the author's wrap. Used here only by the §6 retirement NEGATIVES — a positive pin flattened
# whole-file would stop being able to tell which line made its claim.
# flatten(), one_line() and section() are shared by every belt that sources them; they live in
# tests/lib so a fix to any of them reaches every belt at once, instead of the inconsistent per-belt
# copies they replace — section() in particular had drifted into two arities across those copies.
# shellcheck source=tests/lib/belt-helpers.sh
. "$ROOT/tests/lib/belt-helpers.sh"

API="$ROOT/lens/skills/engine/references/engine-api.md"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
VERIFIER="$ROOT/lens/agents/verifier.md"
ASSEMBLY="$ROOT/lens/skills/review/references/review-model-assembly.md"
FALLBACK="$ROOT/lens/skills/review/references/markdown-fallback.md"
SCHEMA="$ROOT/lens/schemas/review-findings.schema.json"
for f in "$API" "$PIPE" "$ESKILL" "$VERIFIER" "$ASSEMBLY" "$FALLBACK" "$SCHEMA"; do
  [ -s "$f" ] || fail "missing or empty $f"
done

RULE='huginn-quorum-v1'

# === 1. THE DECLARATION: verifyVotes is an engine input, declared in the canon and nowhere else ===
INPUTS="$(section '## lens:engine — inputs' "$API")"
bounded "engine-api.md § lens:engine — inputs" 50 "$INPUTS"

# PIN 1 of 4 — TYPE + RANGE, read off the inputs-table ROW rather than the section prose. The token
# already occurs in § Errors as prose, so a bare substring grep would pass with no input declared at
# all; the first cell must be exactly `verifyVotes`.
python3 - "$INPUTS" <<'PY' || fail "engine-api.md's inputs table does not declare verifyVotes as an integer in 1..5"
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

table = rows(inputs)
first_cells = [c[0] for c in table]

# TRUNCATION GUARD: a new row must not have cost the table an old one.
declared = {}
for cells in table:
    m = re.fullmatch(r"`([A-Za-z]+)(?:\[\])?`", cells[0])
    assert m, f"an inputs row does not declare an `input` name in its first cell: {cells[0]!r}"
    declared[m.group(1)] = cells
for retained in ("target", "taskIds", "injectedIntent", "injectedFinders", "finders", "modelPolicy"):
    assert retained in declared, \
        f"the inputs table lost its `{retained}` row; rows seen: {first_cells}"

assert "verifyVotes" in declared, (
    "the inputs table must carry a row whose FIRST CELL is exactly `verifyVotes` — a prose mention "
    f"is not a declaration; rows seen: {first_cells}"
)

cells = declared["verifyVotes"]
assert len(cells) >= 2, f"the verifyVotes row must carry a Shape cell, got {cells}"
shape = cells[1]
assert "integer" in shape, f"verifyVotes must be declared an integer, its Shape cell says {shape!r}"
assert "1..5" in shape, f"verifyVotes must declare the accepted range 1..5, its Shape cell says {shape!r}"

# The named rule is declared where the input that feeds it is declared.
assert "huginn-quorum-v1" in " ".join(cells), \
    f"the verifyVotes row must name the resolution rule huginn-quorum-v1, got {cells}"
PY

# The remaining three pins are line-scoped and independent: default, absent-never-raises and
# present-and-invalid-raises are three separate promises, and a partial rollout must name the one it
# lost rather than hide behind the other two surviving.
# The selector's SINGULARITY is asserted, not assumed: a selector matching several lines ORs them, so
# the pin passes while ANY one carries the literal and the claim it is named for can be deleted.
inputs_line_has(){ # inputs_line_has <line-selector> <required-literal> <why>
  local matched
  matched="$(printf '%s\n' "$INPUTS" | grep -F -- "$1" || true)"
  one_line "$matched" "engine-api.md § lens:engine — inputs '$1'"
  printf '%s\n' "$matched" | grep -qF -- "$2" || fail "$3"
}

# PIN 2 of 4 — the default is what makes verifyVotes optional in practice.
inputs_line_has '**Default `1`.**' 'one skeptic per finding' \
  "engine-api.md § lens:engine — inputs must declare verifyVotes' default of 1 (one skeptic per finding)"

# PIN 3 of 4 — absent never raises (I-2: a 1.4.3-shaped call cannot receive an error envelope).
inputs_line_has '**Absent never raises.**' 'cannot receive an error envelope' \
  "engine-api.md § lens:engine — inputs must state that an absent verifyVotes never raises"

# PIN 4 of 4 — present-and-invalid is the ONE way this input can raise, and it names the code.
inputs_line_has '**Present-and-invalid' 'E_INVALID_INPUT' \
  "engine-api.md § lens:engine — inputs must state that a present-and-invalid verifyVotes raises E_INVALID_INPUT"
inputs_line_has '**Present-and-invalid' '1..5' \
  "the present-and-invalid rule must name the range it rejects against (1..5)"

# === 2. ONE NAME, TWO HALVES: the canon declares it, pipeline §5 carries the procedure ===
printf '%s\n' "$INPUTS" | grep -qF "$RULE" \
  || fail "engine-api.md must name the vote-resolution rule $RULE where it declares verifyVotes"

# SECTION-SCOPED, not whole-file: the rule has one governing site, and a mention anywhere else in
# pipeline.md would not be the procedure this unit promises.
SEC5="$(section '## 5.' "$PIPE")"
bounded "pipeline.md §5 (verify + vote aggregation)" 45 "$SEC5"
printf '%s\n' "$SEC5" | grep -qF "$RULE" \
  || fail "pipeline.md §5 must carry the named rule $RULE — the canon declares the name, §5 is its procedure"

# === 3. THE RULE ITSELF: five quantities and EXACTLY THREE outcome branches ===
sec5_has(){ printf '%s\n' "$SEC5" | grep -qF -- "$1" || fail "$2"; }
sec5_line_has(){ # sec5_line_has <line-selector> <required-literal> <why>
  local matched
  matched="$(printf '%s\n' "$SEC5" | grep -F -- "$1" || true)"
  one_line "$matched" "pipeline.md §5 '$1'"
  printf '%s\n' "$matched" | grep -qF -- "$2" || fail "$3"
}

sec5_has 'ceil(n/2)' "pipeline.md §5 must define quorum as ceil(n/2)"
# Selected on the DEFINITION bullet, not the bare token: `valid` is also used inside the `refutes`
# definition one line down, so the bare selector ORed two lines and the definition it is named for
# could have been deleted while the pin stayed green off its neighbour.
sec5_line_has '- `valid` =' 'non-dead' \
  "pipeline.md §5 must define valid as the non-dead votes"
sec5_line_has '`refutes`' '`refuted:true`' \
  "pipeline.md §5 must define refutes as the valid votes carrying refuted:true"

python3 - "$SEC5" <<'PY' || fail "pipeline.md §5 does not declare exactly three outcome branches"
import re, sys

lines = sys.argv[1].splitlines()

heads = [i for i, l in enumerate(lines) if l.startswith("| Condition |")]
assert len(heads) == 1, (
    "pipeline.md §5 must carry exactly one branch table, headed `| Condition | Resolution |` — "
    f"found {len(heads)}"
)
i = heads[0] + 1
assert i < len(lines) and set(lines[i].replace("|", "").replace(" ", "")) <= set("-:"), \
    "the branch table's header must be followed by its |---| rule row"

body = []
j = i + 1
while j < len(lines) and lines[j].startswith("|"):
    body.append([c.strip() for c in lines[j].strip().strip("|").split("|")])
    j += 1

# EXACTLY THREE. A fourth outcome is a new rule, not a clarification of this one — and the whole
# point of naming the rule is that its branch set is closed.
assert len(body) == 3, (
    "huginn-quorum-v1 has EXACTLY three outcome branches (abstain / drop / survive); "
    f"the table declares {len(body)}: {[r[0] for r in body]}"
)

conds = [r[0] for r in body]
assert any("valid < quorum" in c for c in conds), \
    f"a branch must fire on `valid < quorum` (the abstain branch), got {conds}"
assert any(re.search(r"refutes\s*\*\s*2\s*>=\s*valid", c) for c in conds), \
    f"a branch must fire on `refutes * 2 >= valid` (the drop branch), got {conds}"
assert any("otherwise" in c.lower() for c in conds), \
    f"a branch must be the `otherwise` fall-through (the survive branch), got {conds}"

# TIES have NO branch of their own — they fall out of the drop condition. A tie-specific row would be
# the fourth outcome the count above already forbids; this names the regression directly.
for cells in body:
    assert not re.search(r"\btie", cells[0], re.I), \
        f"no branch may special-case a tie — ties fall out of `refutes * 2 >= valid`; got {cells[0]!r}"

# Each branch states what it resolves to, so the table is the rule rather than a summary of it.
joined = " ".join(" | ".join(r) for r in body)
for literal in ('voteResolution:"abstained"', 'voteResolution:"verified"', "dropped"):
    assert literal in joined, f"the branch table must state the outcome {literal!r}; got {joined!r}"
PY

# === 4. TIES: stated as a consequence of the drop condition, never as a branch ===
sec5_has 'Ties drop' "pipeline.md §5 must state that ties drop"
sec5_line_has 'falls out of' '`refutes * 2 >= valid`' \
  "pipeline.md §5 must state that the tie case falls out of \`refutes * 2 >= valid\` rather than getting its own branch"

# === 5. ONE UNIVERSAL PATH: the same rule at every n, in both governing files ===
STEP4="$(awk '/^## Step 4/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md Step 4 (verify + dedup + rank)" 20 "$STEP4"

printf '%s\n' "$SEC5" | grep -qF 'no dual path' \
  || fail "pipeline.md §5 must state that the rule runs one universal path — no dual path"
printf '%s\n' "$STEP4" | grep -qF 'no dual path' \
  || fail "engine/SKILL.md Step 4 must state that the rule runs one universal path — no dual path"

# The n=1 reduction is DATA and a table, never a code branch. The previous ban was `if +n *==` — a
# code-shaped literal that matched nothing in either region and, in files written entirely in English
# prose, could never match anything: AC18's headline invariant was guarded by a check incapable of
# firing. What is banned now is the SEMANTICS, in the register these files are actually written in.
#
# The labelled reduction table is excluded first. Describing what the general rule YIELDS at n = 1 is
# the opposite of branching on it — that table is the evidence for the invariant, and its own header
# cell ("The one vote at `n = 1`") trips the first pattern below, which is what makes the exclusion
# load-bearing rather than cosmetic.
drop_reduction_table(){ # drop_reduction_table <region-text>
  printf '%s\n' "$1" | awk '
    index($0,"| The one vote at")==1 {intable=1}
    intable && $0 !~ /^\|/ {intable=0}
    !intable {print}'
}
# Matched case-INSENSITIVELY: prose starts sentences with a capital, so a case-sensitive ban misses
# "When `n` = 1, …" — the single most likely way this regression would actually be written.
N_BRANCH_BANS=(
  '(^|[^[:alnum:]])(when|if|at|for) +`?n`? *(==|=|is|equals) *1'
  'special[- ]cases? +`?n`?'
  '`?n`? +is +an? +special'
  '(single|one)[- ]skeptic +(path|branch|rule|case)'
  '(legacy|separate|second|its own) +(code )?(path|branch) +(at|when|for|if)'
)
# NON-VACUITY, and the whole reason this block was rewritten: a ban asserted only against text that
# already complies is indistinguishable from no ban. Each pattern gets its OWN probe, so no pattern can
# be certified by a clause meant for a different one — a single shared probe hid exactly that, passing
# the first ban on a later "at n = 1" while the capitalised "When `n` = 1" it was written for slipped by.
N_BRANCH_PROBES=(
  'When `n` = 1, keep the 1.4.3 rule instead.'
  'The engine special-cases `n` here.'
  '`n` is a special case, so it takes its own route.'
  'It takes the single-skeptic path instead.'
  'Use the legacy branch when the panel is small.'
)
[ "${#N_BRANCH_BANS[@]}" -eq "${#N_BRANCH_PROBES[@]}" ] \
  || fail "every n-branch ban must carry its own probe — ${#N_BRANCH_BANS[@]} bans, ${#N_BRANCH_PROBES[@]} probes"
i=0
while [ "$i" -lt "${#N_BRANCH_BANS[@]}" ]; do
  printf '%s\n' "${N_BRANCH_PROBES[$i]}" | grep -qiE -- "${N_BRANCH_BANS[$i]}" \
    || fail "the n-branch ban /${N_BRANCH_BANS[$i]}/ does not match its own deliberate violation (${N_BRANCH_PROBES[$i]}) — it cannot fire, which is the defect this block replaced"
  i=$((i + 1))
done
for region_name in "pipeline.md §5" "engine/SKILL.md Step 4"; do
  case "$region_name" in
    "pipeline.md §5") region="$SEC5" ;;
    *) region="$STEP4" ;;
  esac
  scanned="$(drop_reduction_table "$region")"
  [ -n "$scanned" ] || fail "$region_name is empty once its reduction table is dropped — the n-branch scan has nothing to judge"
  for pat in "${N_BRANCH_BANS[@]}"; do
    if printf '%s\n' "$scanned" | grep -qiE -- "$pat"; then
      fail "$region_name keys a rule on the panel size (/$pat/) — n = 1 is the smallest instance of one universal rule, not a case of its own"
    fi
  done
done

# Step 4 resolves through the named rule rather than restating it — the shape stays declared once.
printf '%s\n' "$STEP4" | grep -qF "$RULE" \
  || fail "engine/SKILL.md Step 4 must resolve votes by the named rule $RULE"
printf '%s\n' "$STEP4" | grep -qF 'votes{total,couldNotRefute,refuted,abstained}' \
  || fail "engine/SKILL.md Step 4 must aggregate into votes{total,couldNotRefute,refuted,abstained}"
printf '%s\n' "$STEP4" | grep -qF 'voteResolution' \
  || fail "engine/SKILL.md Step 4 must resolve the per-finding voteResolution alongside verified"

# === 6. RETIREMENT: the deferred-multi-skeptic paragraph is gone, three independent negatives ===
# This is the release's one non-additive edit, so each retired claim is pinned on its own: a partial
# revert must name the sentence it brought back.
# Both are judged against a FLATTENED copy of the file: `grep -F` is line-scoped, so a retired sentence
# reintroduced with its wrap moved — `v1 resolution is` / `unanimous-drop`, `Wiring` / `multi-skeptic
# voting` — is the same retired claim with the ban matching neither half. A revert has to fail however
# the author wrapped it.
PIPE_FLAT="$(flatten "$(cat "$PIPE")")"
if printf '%s\n' "$PIPE_FLAT" | grep -qF 'v1 resolution is unanimous-drop'; then
  fail "pipeline.md must no longer claim 'v1 resolution is unanimous-drop' — $RULE replaced it"
fi
if printf '%s\n' "$PIPE_FLAT" | grep -qF 'Wiring multi-skeptic voting'; then
  fail "pipeline.md must no longer defer multi-skeptic voting — verifyVotes wires it"
fi
if printf '%s\n' "$SEC5" | grep -qiE '\bdeferred\b'; then
  fail "pipeline.md §5 must carry no deferred clause — the rule it deferred is now the rule it states"
fi

# === 7. THE ONE-SKEPTIC VOCABULARY SURVIVES, BOTH DIRECTIONS ===
# `unverified-flagged` is the VERIFIER's word for its own errored vote; `abstained` is the ENGINE's
# word for how it tallies such a vote. Neither replaced the other, and a rename that collapsed them
# would break the vote shape the engine consumes. Each site is pinned independently.
VCOUNT="$( { grep -cF 'unverified-flagged' "$VERIFIER" || true; } | tr -d '[:space:]')"
[ "$VCOUNT" -ge 4 ] \
  || fail "lens/agents/verifier.md must keep all four 'unverified-flagged' sites (found $VCOUNT)"
printf '%s\n' "$SEC5" | grep -qF 'unverified-flagged' \
  || fail "pipeline.md §5 must keep naming the verifier's 'unverified-flagged' status as the dead-vote source"
grep -qF 'unverified-flagged' "$ASSEMBLY" \
  || fail "review/references/review-model-assembly.md must keep its 'unverified-flagged' rendering label"
grep -qF 'unverified-flagged' "$FALLBACK" \
  || fail "review/references/markdown-fallback.md must keep its 'unverified-flagged' rendering label"

if grep -q 'abstained' "$VERIFIER"; then
  fail "lens/agents/verifier.md must not name 'abstained' — a single verifier emits a vote, the engine tallies it"
fi

# RETENTION: the verifier's identity and its adversarial model are untouched by this unit.
VFRONT="$(awk '/^---$/{n++; next} n==1{print}' "$VERIFIER")"
[ -n "$VFRONT" ] || fail "lens/agents/verifier.md frontmatter block is empty"
printf '%s\n' "$VFRONT" | grep -qxF 'name: verifier' || fail "verifier.md frontmatter must keep 'name: verifier'"
printf '%s\n' "$VFRONT" | grep -qxF 'model: opus' || fail "verifier.md frontmatter must keep 'model: opus'"

# === 8. THE EXECUTABLE RULE: huginn-quorum-v1 implemented ONCE, applied to every fixture ===
# Prose cannot be executed, so the strongest available proof that the n=1 reduction is the general
# rule is data: one rule function, no branch on n, run against a 1-vote nominal fixture, a 1-vote
# degraded fixture and a 3-vote quorum fixture. If n=1 needed its own path, this would fail.
NOMINAL="$ROOT/tests/lens/fixtures/engine-output-sample.json"
DEGRADED="$ROOT/tests/lens/fixtures/engine-output-degraded-sample.json"
QUORUM="$ROOT/tests/lens/fixtures/engine-output-quorum-sample.json"
for f in "$NOMINAL" "$DEGRADED" "$QUORUM"; do [ -s "$f" ] || fail "missing or empty fixture $f"; done

python3 - "$SCHEMA" "$NOMINAL" "$DEGRADED" "$QUORUM" <<'PY' || fail "a fixture violates huginn-quorum-v1"
import json, math, sys

schema_path, paths = sys.argv[1], sys.argv[2:]

def resolve(v):
    """huginn-quorum-v1 — implemented once, with no branch on n."""
    total, abstained = v["total"], v["abstained"]
    valid = total - abstained
    quorum = math.ceil(total / 2)
    refutes = v["refuted"]
    if valid < quorum:
        return "abstained"
    if refutes * 2 >= valid:
        return "dropped"
    return "verified"

seen, totals = set(), set()
for path in paths:
    doc = json.load(open(path, encoding="utf-8"))
    for f in doc["findings"]:
        v = f.get("votes")
        if v is None:
            continue
        fid = f"{path}:{f['id']}"
        assert set(v) == {"total", "couldNotRefute", "refuted", "abstained"}, \
            f"{fid}: votes must carry exactly total/couldNotRefute/refuted/abstained, got {sorted(v)}"
        assert v["couldNotRefute"] + v["refuted"] + v["abstained"] == v["total"], \
            f"{fid}: couldNotRefute + refuted + abstained must equal total, got {v}"
        outcome = resolve(v)
        # A dropped finding never reaches findings[] — so a present finding resolving to `dropped`
        # means the fixture kept something the rule discards.
        assert outcome != "dropped", \
            f"{fid}: resolves to DROPPED under huginn-quorum-v1 — a dropped finding must never reach findings[]"
        assert f.get("voteResolution") == outcome, \
            f"{fid}: voteResolution must be {outcome!r} for votes {v}, got {f.get('voteResolution')!r}"
        assert f["verified"] is (outcome == "verified"), \
            f"{fid}: verified must be {outcome == 'verified'} for votes {v}, got {f['verified']}"
        seen.add(outcome)
        totals.add(v["total"])

# NON-VACUITY: the fixture set must actually exercise both surviving outcomes and a panel larger
# than one, or the uniformity above proves nothing.
assert seen == {"verified", "abstained"}, \
    f"the fixtures must exercise both surviving outcomes (verified + abstained), saw {sorted(seen)}"
assert 1 in totals, "the fixtures must include the n=1 reduction (a votes.total of 1)"
assert max(totals) >= 3, f"the fixtures must include a multi-skeptic panel (n >= 3), saw totals {sorted(totals)}"

# Every fixture validates against the schema it claims to satisfy. jsonschema is the one validator
# dependency this repo installs in CI; absent locally, the sub-check reports itself as skipped
# rather than passing silently (the onboard/check-schemas.py convention).
try:
    import jsonschema
except ImportError:
    print("SKIP: jsonschema not installed — fixture schema validation not run (pip install jsonschema)")
else:
    schema = json.load(open(schema_path, encoding="utf-8"))
    for path in paths:
        jsonschema.validate(json.load(open(path, encoding="utf-8")), schema)
PY

# === 8b. THE TIE RULE, PINNED BOTH WAYS ===
# The corrected tie sentence was the ONE fix of its batch that no belt could kill: reverting it to the
# false "exactly when the refuters halve the valid panel" left every lens belt green, because the only
# guard pinned that the tie "falls out of `refutes * 2 >= valid`" — a clause the false restatement
# preserves word for word. No fixture reaches the drop branch either, so the drop rule's only
# human-readable statement was the unguarded one. Two independent pins close that: the sentence, and
# the arithmetic it describes, executed.
TIE="$(printf '%s\n' "$SEC5" | awk '/^\*\*Ties drop/{n=1} n{print} n && /^$/{exit}')"
bounded "pipeline.md §5 tie paragraph" 8 "$TIE"
TIEFLAT="$(flatten "$TIE")"
printf '%s\n' "$TIEFLAT" | grep -qF 'at least half the valid panel — the tie case included' \
  || fail "pipeline.md §5's tie paragraph must describe the drop condition as AT LEAST half the valid panel, naming the tie as an included case — not as the tie alone"
printf '%s\n' "$TIEFLAT" | grep -qF 'refutes * 2 >= valid' \
  || fail "the tie paragraph must cite the condition it falls out of"
# NEGATIVE — the false restatement, banned however it is wrapped. `>=` covers a MAJORITY of refuters as
# well as a tie, so a sentence saying the drop happens "exactly when" the refuters halve the panel
# describes a strictly narrower rule than the one the table declares and the engine runs.
if printf '%s\n' "$TIEFLAT" | grep -qiE 'exactly when|halve'; then
  fail "pipeline.md §5's tie paragraph must not restate the drop condition as 'exactly when the refuters halve the valid panel' — >= also covers a refuting majority, so that reading is strictly narrower than the rule"
fi

# ...AND THE ARITHMETIC, RUN. The tie is the boundary case of `refutes * 2 >= valid`, and no fixture
# reaches the drop branch, so prose was the only thing standing between the rule and a narrower one.
# Synthetic tallies exercise the boundary from both sides, through the SAME resolve() the fixtures use.
python3 <<'PY' || fail "huginn-quorum-v1's tie boundary does not behave as pipeline.md §5 declares"
import math

def resolve(v):
    """huginn-quorum-v1 — the same implementation the fixture block runs, no branch on n."""
    total, abstained = v["total"], v["abstained"]
    valid = total - abstained
    quorum = math.ceil(total / 2)
    refutes = v["refuted"]
    if valid < quorum:
        return "abstained"
    if refutes * 2 >= valid:
        return "dropped"
    return "verified"

def votes(total, couldNotRefute, refuted, abstained):
    assert couldNotRefute + refuted + abstained == total, "a test tally must satisfy the sum invariant"
    return {"total": total, "couldNotRefute": couldNotRefute, "refuted": refuted, "abstained": abstained}

CASES = [
    # AN EXACT TIE DROPS — the case the false restatement gets right and everything else wrong.
    ("2 valid votes, 1 refute — an exact tie", votes(2, 1, 1, 0), "dropped"),
    ("4 valid votes, 2 refutes — an exact tie at a wider panel", votes(4, 2, 2, 0), "dropped"),
    # A REFUTING MAJORITY DROPS TOO — this is what "exactly when they halve it" denies.
    ("3 valid votes, 2 refutes — a refuting majority", votes(3, 1, 2, 0), "dropped"),
    ("5 valid votes, 5 refutes — unanimous refute", votes(5, 0, 5, 0), "dropped"),
    # BELOW HALF SURVIVES — without this the rule could be "always drop".
    ("3 valid votes, 1 refute — below half", votes(3, 2, 1, 0), "verified"),
    ("5 valid votes, 2 refutes — below half", votes(5, 3, 2, 0), "verified"),
    # THE TIE IS COMPUTED AGAINST `valid`, NOT `total` — dead votes leave the panel first.
    ("4 dispatched, 1 dead, 2 of the 3 valid refute — a majority of the VALID panel",
     votes(4, 1, 2, 1), "dropped"),
    # n=1, the 1.4.3 reduction: one refute is 'at least half' of a one-vote panel.
    ("n=1 with a refute — 1.4.3's single-refute drop", votes(1, 0, 1, 0), "dropped"),
    ("n=1 with no refute — 1.4.3's keep", votes(1, 1, 0, 0), "verified"),
    ("n=1 dead vote — 1.4.3's verify-error, kept and flagged", votes(1, 0, 0, 1), "abstained"),
]

for label, v, expected in CASES:
    got = resolve(v)
    assert got == expected, f"{label}: expected {expected!r} for {v}, got {got!r}"

# NON-VACUITY: the boundary is exercised from BOTH sides and all three outcomes appear, so neither
# "always drop" nor "never drop" satisfies this block.
assert {c[2] for c in CASES} == {"dropped", "verified", "abstained"}, \
    "the tie matrix must exercise all three outcomes"
assert any(c[1]["refuted"] * 2 == c[1]["total"] - c[1]["abstained"] for c in CASES), \
    "the tie matrix must include an EXACT tie — that is the boundary the prose describes"
assert any(c[1]["refuted"] * 2 > c[1]["total"] - c[1]["abstained"] for c in CASES), \
    "the tie matrix must include a refuting MAJORITY — the case 'exactly when they halve it' excludes"
PY

# === 9. WHERE THE RANGE IS CHECKED: pre-flight, before any vote is dispatched ===
# verifyVotes governs VERIFY, but it is rejected long before it: an out-of-range panel size is a caller
# bug, and I-1 gives a caller bug exactly one place to surface. A range check left at the VERIFY site
# would raise after finders had already run, which is the invariant this pin protects.
ESTEP0="$(section '## Step 0' "$ESKILL")"
bounded "engine/SKILL.md Step 0 (PRE-FLIGHT)" 30 "$ESTEP0"
STEP0_VOTES="$(printf '%s\n' "$ESTEP0" | grep -F 'verifyVotes' || true)"
one_line "$STEP0_VOTES" "engine/SKILL.md Step 0 verifyVotes rule"
printf '%s\n' "$STEP0_VOTES" | grep -qF '1..5' \
  || fail "engine/SKILL.md Step 0 must range-check verifyVotes against 1..5 in pre-flight"

echo "PASS: lens verifyVotes belt (declaration, huginn-quorum-v1 procedure, one universal path, retirement, vocabulary, executable rule, pre-flight range check)"
