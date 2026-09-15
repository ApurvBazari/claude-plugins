#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

# Every extracted region below is asserted non-empty AND bounded. An extractor whose terminator stops
# matching does not go empty — it swallows the rest of the file, so every pin scoped to it silently
# becomes a whole-file grep. An emptiness guard cannot see that; a ceiling can.
bounded(){ # bounded <region-name> <max-lines> <region-text>
  [ -n "$3" ] || fail "$1 is empty"
  local n
  n="$(printf '%s\n' "$3" | wc -l | tr -d '[:space:]')"
  [ "$n" -le "$2" ] || fail "$1 grew to $n lines (ceiling $2) — its extractor lost its terminator"
}

# flatten(), one_line() and section() are shared by every belt that sources them; they live in
# tests/lib so a fix to any of them reaches every belt at once. This belt carried four inline copies of flatten's `tr` pipeline
# and its own section() under a second, incompatible arity — the largest belt, and the one with the
# most new selectors, was the one running unshared code.
# shellcheck source=tests/lib/belt-helpers.sh
. "$ROOT/tests/lib/belt-helpers.sh"

# === REF GUARDS: lens must resolve cleanly under both citation guards ===
# Both guards set 'set -uo pipefail' (no -e) and exit 1 on a broken reference, so they
# are wrapped in an explicit `if ! ...` rather than relied on to propagate via -e.
if ! (cd "$ROOT" && bash .github/scripts/check-ref-paths.sh lens); then
  fail "check-ref-paths.sh lens must exit 0 (a citation is mis-rooted)"
fi
if ! (cd "$ROOT" && bash .github/scripts/check-skill-refs.sh lens); then
  fail "check-skill-refs.sh lens must exit 0 (a <path>/SKILL.md citation is mis-rooted)"
fi

# === FENCING PRESERVATION: the untrusted-intent fencing sentence survives its path-token repair ===
CLAUDEMD="$ROOT/lens/CONVENTIONS.md"
[ -s "$CLAUDEMD" ] || fail "missing $CLAUDEMD"
grep -q '<untrusted-user-input>' "$CLAUDEMD" || fail "CLAUDE.md must keep the <untrusted-user-input> fence reference"
grep -qi 'data, not instructions' "$CLAUDEMD" || fail "CLAUDE.md must keep the 'data, not instructions' clause"
grep -qF 'framing, not filtering' "$CLAUDEMD" || fail "CLAUDE.md must keep the 'framing, not filtering' clause"
grep -q '§3' "$CLAUDEMD" || fail "CLAUDE.md must keep the §3 anchor"

# === JSON EXAMPLE INTEGRITY: illustrative-path repairs must not corrupt a fenced JSON sample ===
JSON_EXAMPLE_FILES=(
  "$ROOT/lens/agents/correctness.md"
  "$ROOT/lens/agents/risk-classify.md"
  "$ROOT/lens/agents/spec-adherence.md"
  "$ROOT/lens/agents/plan-adherence.md"
  "$ROOT/lens/agents/test-gaps.md"
  "$ROOT/lens/agents/verifier.md"
)
for f in "${JSON_EXAMPLE_FILES[@]}"; do
  [ -s "$f" ] || fail "missing $f"
done
python3 - "${JSON_EXAMPLE_FILES[@]}" <<'PY' || fail "an edited example file has a fenced JSON block that fails to parse"
import json, re, sys

for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    blocks = re.findall(r'```json\n(.*?)\n```', text, re.S)
    if not blocks:
        print(f"{path}: no fenced JSON block found", file=sys.stderr)
        sys.exit(1)
    for block in blocks:
        json.loads(block)
PY

# === CANON: the programmatic surface is declared once, in one file, with an owner column ===
API="$ROOT/lens/skills/engine/references/engine-api.md"
[ -s "$API" ] || fail "missing or empty $API — the programmatic surface has no declared home"

# Hoisted from the ENGINE SKILL section below: the error-code allow-list names this file as the one
# PROCEDURE site permitted to carry a code (its pre-flight region), so it has to exist before that scan.
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
[ -s "$ESKILL" ] || fail "missing $ESKILL"

# The second procedure site permitted to carry a code: lens:capability raises E_UNSUPPORTED_CAPABILITY,
# which is a pre-dispatch answer about the contract itself and never a mid-review outcome (I-1 is
# about the ENGINE's stages, and this skill has none). Its own belt is tests/lens/test_capability.sh.
CAPSKILL="$ROOT/lens/skills/capability/SKILL.md"
[ -s "$CAPSKILL" ] || fail "missing $CAPSKILL"

H_PRECEDENCE='## Precedence — this doc declares, the skills govern'
H_OWNERSHIP='## Ownership map'
H_INPUTS='## lens:engine — inputs'
H_RETURNS='## lens:engine — returns'
H_CHANNELS='## lens:engine — return channels'
H_DOWNSTREAM='## Downstream additions (NOT engine returns)'
H_RENDER='## lens:render-review — inputs and returns'
H_CONSUMERS='## Known consumer assumptions (not part of the contract)'
H_ERRORS='## Errors'
H_CAPABILITY='## lens:capability'
H_PROCEDURE='## Where the procedure lives'

# The inventory is counted as well as walked: a section dropped from the list stops being required
# without any assertion failing, so the count is what keeps the list from quietly shrinking.
HEADINGS=("$H_PRECEDENCE" "$H_OWNERSHIP" "$H_INPUTS" "$H_RETURNS" "$H_CHANNELS" "$H_DOWNSTREAM" \
          "$H_RENDER" "$H_CONSUMERS" "$H_ERRORS" "$H_CAPABILITY" "$H_PROCEDURE")
[ "${#HEADINGS[@]}" -eq 11 ] \
  || fail "engine-api.md's heading inventory must cover all 11 declared sections (found ${#HEADINGS[@]} in the list)"
for heading in "${HEADINGS[@]}"; do
  grep -qF "$heading" "$API" || fail "engine-api.md must carry the heading '$heading'"
done


# Precedence: the declaration defers to the runtime, so a stale line here can never govern behavior.
# Body-scoped (section() skips the heading itself): the H2 title already reads "this doc declares, the
# skills govern", so a whole-file grep for that idea was satisfied by the heading the loop above pins —
# and could not fail even with the whole Precedence body deleted. Pin the load-bearing sentence.
PRECEDENCE="$(section "$H_PRECEDENCE" "$API")"
[ -n "$PRECEDENCE" ] || fail "the '$H_PRECEDENCE' section is empty"
printf '%s\n' "$PRECEDENCE" | grep -qF 'the procedure wins and this doc is the bug' \
  || fail "engine-api.md § Precedence must state that the procedure wins when it disagrees with this doc"

# The engine's return surface is DERIVED from the schema it declares, never listed by hand here: the
# schema's top-level properties minus the two reconcile-owned ones ARE the set the canon must declare.
# One assertion pins that set exactly (both directions), the count claim, the per-finding required list,
# the downstream owner column and the schema citation — so an invented row, a renamed row, a re-worded
# count or a doc/schema contradiction fails loudly instead of surviving a handful of substring greps.
# Same exact-set discipline as tests/lens/test_schema_types.sh's dimension-enum pin, for the same
# reason: a subset check lets a declaration be deleted, a superset check lets one be invented.
SCHEMA="$ROOT/lens/schemas/review-findings.schema.json"
[ -s "$SCHEMA" ] || fail "missing $SCHEMA"
python3 - "$API" "$SCHEMA" <<'PY' || fail "engine-api.md's declared surface is out of parity with the schema it declares"
import json, os, re, sys

api_path, schema_path = sys.argv[1], sys.argv[2]
api = open(api_path, encoding="utf-8").read()
schema = json.load(open(schema_path, encoding="utf-8"))

def section(title):
    body, inside = [], False
    for line in api.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == title
            continue
        if inside:
            body.append(line)
    return body

def rows(lines):
    """Each markdown table row as its cells, minus the header and the |---| rule."""
    out = []
    for line in lines:
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
        if not cells[0] or set(cells[0]) <= set("-: ") or cells[0] in ("Field", "Surface", "Input", "Return"):
            continue
        out.append(cells)
    return out

def keys(table):
    out = []
    for cells in table:
        m = re.fullmatch(r"`([A-Za-z]+)(?:\[\])?`", cells[0])
        assert m, f"table row does not declare a `field` name in its first cell: {cells[0]!r}"
        out.append(m.group(1))
    return out

RETURNS = section("## lens:engine — returns")
DOWN = section("## Downstream additions (NOT engine returns)")
OWNER = section("## Ownership map")
assert RETURNS and DOWN and OWNER, "engine-api.md is missing a section this parity check reads"

reconcile_owned = {"delta", "severityTrend"}
engine_owned = set(schema["properties"]) - reconcile_owned

# THE ERROR CHANNEL MUST NOT INFLATE THE SUCCESS FIELD SET. The count below is DERIVED from
# schema["properties"], so declaring the named-error envelope as an eighth property would silently
# rewrite "seven fields, and nothing else" into a lie — and the returns table, derived from the same
# set, would sprout a row for a field no success return ever carries. The envelope is declared as an
# alternative oneOf BRANCH instead (tests/lens/test_schema_types.sh owns its shape); this pin is what
# keeps the two facts from being reconciled the easy, wrong way.
assert "error" not in schema["properties"], (
    "the error envelope must be declared as an alternative return CHANNEL (a top-level oneOf branch), "
    "never as a top-level property — as a property it inflates the derived success field count"
)
assert isinstance(schema.get("oneOf"), list) and len(schema["oneOf"]) == 2, \
    "the schema must declare exactly two return channels (success | failure) as a top-level oneOf"

declared = keys(rows(RETURNS))
assert len(declared) == len(set(declared)), f"a field is declared twice in the returns table: {declared}"
assert set(declared) == engine_owned, (
    "the returns table must declare EXACTLY the schema's engine-owned fields (every top-level schema "
    f"property except {sorted(reconcile_owned)}); missing={sorted(engine_owned - set(declared))} "
    f"invented={sorted(set(declared) - engine_owned)}"
)

WORDS = {4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten"}
word = WORDS.get(len(engine_owned))
assert word, f"the schema now declares {len(engine_owned)} engine-owned fields — no number word for that count"
flat = " ".join(" ".join(RETURNS).split())
assert f"**{word} fields, and nothing else**" in flat, \
    f"the returns section must claim exactly {word} fields — the count derived from the schema"
assert f"beyond these {word}" in flat, \
    f"the returns section's closing boundary sentence must name the same count ({word})"

findings_row = [c for c in rows(RETURNS) if c[0].startswith("`findings")][0]
m = re.search(r"required:(.*)", " ".join(findings_row[1:]))
assert m, "the findings[] row must state the per-finding required list"
doc_required = set(re.findall(r"`([A-Za-z]+)`", m.group(1)))
schema_required = set(schema["properties"]["findings"]["items"]["required"])
assert doc_required == schema_required, (
    "the findings[] row's per-finding required list must match the schema's exactly; "
    f"doc-only={sorted(doc_required - schema_required)} schema-only={sorted(schema_required - doc_required)}"
)

# DEGRADE-CODE PARITY — the doc's code SPELLINGS against the schema's enum, exact set BOTH directions.
# The returns row names the seven causes in prose and nothing read them, so renaming `finder-died` to
# `finder-dead` here alone left every belt green while a consumer branching on the documented spelling
# would never match a code the engine actually emits. The enum is DERIVED from the schema at runtime:
# re-listing the seven strings in this belt would make the belt itself the second source of truth this
# whole parity block exists to prevent. A doc typo fails; a code added to the schema and left
# undocumented fails just as loudly.
degraded_rows = [c for c in rows(RETURNS) if c[0].startswith("`degradedReasons")]
assert len(degraded_rows) == 1, \
    f"the returns table must carry exactly one `degradedReasons[]` row, found {len(degraded_rows)}"
m = re.search(r"the closed set of degrade causes:(.*?)\.\s", " ".join(degraded_rows[0][1:]))
assert m, "the degradedReasons[] row must name the closed set of degrade causes"
doc_codes = set(re.findall(r"`([a-z][a-z0-9-]*)`", m.group(1)))
schema_codes = set(schema["properties"]["degradedReasons"]["items"]["properties"]["code"]["enum"])
assert doc_codes == schema_codes, (
    "the degradedReasons[] row must name EXACTLY the schema's code enum, each as its own `code span`; "
    f"doc-only={sorted(doc_codes - schema_codes)} schema-only={sorted(schema_codes - doc_codes)}"
)

# THE ROW MUST STATE THE RULE THE SCHEMA ACTUALLY ENFORCES. It said "Present if and only if `degraded`
# is true", and the enforced rule is NON-EMPTY if and only if true: `degraded:false` beside an empty
# array validates, so presence was never the discriminator. Once the constraint became machine-checked
# the doc became the falsifiable half, and under this repo's own precedence rule (the procedure wins,
# the doc is the bug) the row is what has to move. It is also the one place a caller could read to
# build a wrong presence check.
degraded_row = " ".join(degraded_rows[0][1:])
assert "Non-empty if and only if" in degraded_row, (
    "the degradedReasons[] row must state the rule as NON-EMPTY if and only if `degraded` is true — "
    "'present if and only if' is falsified by the schema, which accepts degraded:false with an empty array"
)
assert "Present if and only if" not in degraded_row, \
    "the degradedReasons[] row must not restate the retired presence rule the schema contradicts"
assert re.search(r"present-but-empty|empty array", degraded_row), (
    "the row must say what a present-but-empty array means, since presence alone is not the "
    "discriminator — a caller told only 'if and only if' will branch on the key existing"
)

rtext = "\n".join(RETURNS)
for bad, why in (("severityTrend", "reconcile sets it, never the engine"),
                 ("delta", "reconcile sets it, never the engine"),
                 ("agents", "lens emits no finder roster")):
    assert not re.search(rf"(?<![-\w]){bad}\b", rtext), \
        f"the returns section must not name '{bad}' — {why}"

assert set(keys(rows(DOWN))) == reconcile_owned, \
    f"the downstream table must declare exactly {sorted(reconcile_owned)}, got {sorted(keys(rows(DOWN)))}"
for cells in rows(DOWN):
    assert "reconcile" in cells[-1], \
        f"downstream field {cells[0]} must name reconcile in its 'Set by' cell, got {cells[-1]!r}"

rel = os.path.relpath(schema_path, os.path.dirname(api_path))
schema_owned = [c for c in rows(OWNER) if "the schema" in c[1]]
assert len(schema_owned) == 1, "the ownership map must carry exactly one schema-owned row"
assert rel in schema_owned[-1][-1], \
    f"the schema-owned ownership row must point at {rel}, got {schema_owned[-1][-1]!r}"
assert rel in flat, f"the returns section must cite the schema it validates against ({rel})"
PY

# === RETURN CHANNELS: the named-error envelope is a DECLARED return, with a branch key ===
# Before this section the engine was in simultaneous violation of two of its own rules on every raise:
# the returns table declared seven fields "and nothing else", and § Errors mandated an envelope carrying
# none of them. render-review already declares three returns and a branch rule, and lens:capability two
# — the engine was the only surface whose failure channel had neither, so the named consumer that
# validates the return against the schema met the envelope as a schema-invalid object on a channel
# nothing declared. Four pins: that the channels are declared, the branch key, that the failure channel
# is the envelope § Errors owns rather than a second declaration of it, and that I-2 still bounds it.
CHANNELS="$(section "$H_CHANNELS" "$API")"
bounded "engine-api.md § lens:engine — return channels" 30 "$CHANNELS"
CHANNELSFLAT="$(flatten "$CHANNELS")"
printf '%s\n' "$CHANNELSFLAT" | grep -qF 'branch on the presence of `error`' \
  || fail "the return-channels section must name the ONE key a consumer tells the two channels apart by"
printf '%s\n' "$CHANNELSFLAT" | grep -qF 'two channels' \
  || fail "the return-channels section must declare that lens:engine answers on two channels"
# ORDER OF OPERATIONS — the whole point of a branch key. A consumer that validates first reads a
# failure as a malformed success, which is exactly the reported behavior of the live consumer.
printf '%s\n' "$CHANNELSFLAT" | grep -qiE 'branch first|validates before it branches' \
  || fail "the return-channels section must tell a consumer to branch BEFORE it validates — validating first is what turns a declared failure back into a malformed success"
# BY POINTER, both ways: the envelope stays declared once in § Errors, and the success shape stays
# declared once in § lens:engine — returns. A channels section that respelled either has re-forked them.
printf '%s\n' "$CHANNELSFLAT" | grep -qF '§ Errors' \
  || fail "the failure channel must point at § Errors for the envelope rather than restating its shape"
printf '%s\n' "$CHANNELSFLAT" | grep -qF '§ lens:engine — returns' \
  || fail "the success channel must point at § lens:engine — returns rather than restating the seven fields"
if printf '%s\n' "$CHANNELS" | grep -qE '^\| `[a-zA-Z]+\[?\]?` \|'; then
  fail "the return-channels section must not re-declare a FIELD row — it declares channels; § lens:engine — returns owns the field set"
fi
# I-2 SURVIVES THE NEW CHANNEL. A declared failure channel is exactly the kind of addition that quietly
# widens what a 1.4.3-shaped call can receive, so the bound is restated where the channel is declared.
printf '%s\n' "$CHANNELSFLAT" | grep -qF '1.4.3-shaped call' \
  || fail "the return-channels section must state that a 1.4.3-shaped call receives the success channel and nothing else (I-2)"
# The section is POSITIONAL: it must follow the returns table it branches against, and precede the
# downstream-additions section, or the reading order declares a branch over a shape not yet stated.
L_RET="$({ grep -nxF -- "$H_RETURNS" "$API" || true; } | head -1 | cut -d: -f1)"
L_CHAN="$({ grep -nxF -- "$H_CHANNELS" "$API" || true; } | head -1 | cut -d: -f1)"
L_DOWN="$({ grep -nxF -- "$H_DOWNSTREAM" "$API" || true; } | head -1 | cut -d: -f1)"
[ -n "$L_RET" ] && [ -n "$L_CHAN" ] && [ -n "$L_DOWN" ] \
  || fail "engine-api.md must carry '$H_RETURNS', '$H_CHANNELS' and '$H_DOWNSTREAM' each as a whole line"
[ "$L_CHAN" -gt "$L_RET" ] \
  || fail "'$H_CHANNELS' must come AFTER '$H_RETURNS' — placed before it, the returns extractor stops early and every pin scoped there goes narrow"
[ "$L_CHAN" -lt "$L_DOWN" ] \
  || fail "'$H_CHANNELS' must come BEFORE '$H_DOWNSTREAM' — the engine's own channels precede the fields it never sets"

# The returns section hands off to the channel declaration instead of ending on "nothing else": a
# consumer reading only the seven-field table has to be told where the other channel is declared.
RETURNS_FLAT="$(flatten "$(section "$H_RETURNS" "$API")")"
[ -n "$RETURNS_FLAT" ] || fail "the '$H_RETURNS' section is empty"
printf '%s\n' "$RETURNS_FLAT" | grep -qF '§ lens:engine — return channels' \
  || fail "engine-api.md § lens:engine — returns must point at the return-channels section — otherwise its closing 'beyond these seven' sentence still reads as if a raise were outside the contract"

# === finder-malformed IS THE ONE CODE WITH THREE EMITTING SITES, SO `detail` CARRIES THE REST ===
# The other six codes each have one governing site; this one gained a third in this release (adapter
# output that cannot be normalized) alongside a file-registered record rejected in pre-flight and a
# finder's own output rejected at Step 4. Those are three DIFFERENT coverage states — in one of them
# the finder never ran at all — behind one branchable code. The set stays closed at seven by developer
# decision, so the discrimination has to be declared as an obligation on `detail`; without it a
# consumer branching on the code cannot tell "the finder was never dispatched" from "it ran and its
# output was rejected". Four pins: that the obligation exists, that it is mandatory, and one per site.
printf '%s\n' "$RETURNS_FLAT" | grep -qF 'must name its emitting site in `detail`' \
  || fail "engine-api.md § lens:engine — returns must declare that a finder-malformed entry names its emitting site in detail — one code covers three stages with different coverage states"
printf '%s\n' "$RETURNS_FLAT" | grep -qF '**MUST** name which of those three sites produced it' \
  || fail "the finder-malformed detail rule must be an obligation, not a suggestion — a free-form detail leaves the three stages indistinguishable"
for emitter in 'rejected in pre-flight' 'rejected at Step 4' 'could not be normalized'; do
  printf '%s\n' "$RETURNS_FLAT" | grep -qF -- "$emitter" \
    || fail "the finder-malformed detail rule must name the emitting site '$emitter' — a rule that does not enumerate the three sites cannot be complied with"
done

# The engine SKILL's schema-valid Key Rule must be coherent with the two channels it can return on.
# Scoped to the rule itself: the file names the schema elsewhere, so a whole-file grep would pass on a
# Key Rule that still claims every output is a review-findings object.
SCHEMARULE="$(grep -F '**Schema-valid.**' "$ESKILL" || true)"
[ -n "$SCHEMARULE" ] || fail "engine/SKILL.md must keep the Schema-valid Key Rule"
printf '%s\n' "$SCHEMARULE" | grep -qF 'error' \
  || fail "engine/SKILL.md's Schema-valid Key Rule must account for the error channel — unqualified, it declares every raise a violation of itself"
printf '%s\n' "$SCHEMARULE" | grep -qF 'engine-api.md` § lens:engine — return channels' \
  || fail "engine/SKILL.md's Schema-valid Key Rule must cite the section that declares the two channels"

# delta / severityTrend are declared, but as downstream additions owned by reconcile.
DOWNSTREAM="$(section "$H_DOWNSTREAM" "$API")"
[ -n "$DOWNSTREAM" ] || fail "the '$H_DOWNSTREAM' section is empty"
printf '%s\n' "$DOWNSTREAM" | grep -qiE 'never .*engine|not an engine return' \
  || fail "downstream section must state that the engine never sets delta/severityTrend"

# Inputs: every arg named, injectedFinders marked canonical, the scope alias recorded not renamed.
INPUTS="$(section "$H_INPUTS" "$API")"
[ -n "$INPUTS" ] || fail "the '$H_INPUTS' section is empty"
for arg in target taskIds injectedIntent injectedFinders finders; do
  printf '%s\n' "$INPUTS" | grep -qF "$arg" || fail "engine inputs section must declare '$arg'"
done
# Line-scoped, and the selector's SINGULARITY is asserted rather than assumed. A bare `injectedFinders`
# grep matches five lines of this section — the row, the `finders` row that contrasts with it, the
# effort paragraph and two others — so the pin passed while ANY of them carried the word "canonical",
# and the row it is named for could be gutted outright. The row's own first cell is the selector.
INJ_ROW="$(printf '%s\n' "$INPUTS" | grep -F '| `injectedFinders` |' || true)"
one_line "$INJ_ROW" "engine-api.md inputs-table \`injectedFinders\` row"
printf '%s\n' "$INJ_ROW" | grep -qi 'canonical' \
  || fail "engine inputs section must name injectedFinders the canonical project-finder path, on its own row"
# THE NO-RAISE TWIN. The raise direction is pinned on this row already; nothing pinned that a record
# carrying NEITHER 1.5.0 key must not raise. Every other 1.5.0 input has that positive twin declared
# beside its raise (verifyVotes' "absent never raises"; modelPolicy's "null and an absent key are not a
# wrong type"), and injectedFinders is the one PRE-EXISTING channel that gained a hard-fail — so a
# 1.3.0 caller reading only the raise sentence has no statement that its own records are still safe.
printf '%s\n' "$INJ_ROW" | grep -qF 'A record carrying neither key never raises' \
  || fail "the injectedFinders row must state that a record carrying neither model nor effort never raises — the raise half is pinned and its I-2 twin was not, on the one pre-1.5.0 channel that can now hard-fail"
printf '%s\n' "$INJ_ROW" | grep -qF 'I-2' \
  || fail "the injectedFinders no-raise twin must tie itself to I-2 — that is the invariant making it true, not a courtesy"

ALIAS_LINE="$(printf '%s\n' "$INPUTS" | grep -i 'alias' || true)"
one_line "$ALIAS_LINE" "engine-api.md inputs section alias record"
printf '%s\n' "$ALIAS_LINE" | grep -qF 'scope' \
  || fail "engine inputs section must record 'scope' as the historical alias of 'target'"

# `model`'s MALFORMATION CRITERION. finder-contract.md tells a finder author that "what a malformed one
# does" is declared in this section — for `effort` it was (the five-value set), for `model` it was not,
# so the promise pointed at nothing and every raise/degrade rule keyed to "a malformed model" had no
# subject. Four pins: that a criterion exists, what it is, what lens deliberately does NOT check, and
# that the two record forms still take their own declared paths from it.
INPUTSFLAT="$(flatten "$INPUTS")"

# === THE effort DIRECTIVE'S ORDERING RULE SURVIVES IN THE CANON, NOT ONLY IN THE PROCEDURES ===
# pipeline.md §3 and adapter-dispatch.md Part 1 both require the directive BEHIND the read-only /
# findings-only contract, and both name that ordering as the guard: a directive that arrives first can
# be read as re-framing the contract behind it. The canon said only "prepended", unqualified — and it
# is the file a programmatic caller and any reimplementer read first, so an implementation written
# from it alone would defeat a guard two procedures declare load-bearing.
printf '%s\n' "$INPUTSFLAT" | grep -qF 'prompt-level directive prepended to the dispatched finder prompt' \
  || fail "engine-api.md must keep declaring effort a prompt-level directive prepended to the dispatched finder prompt"
printf '%s\n' "$INPUTSFLAT" | grep -qF 'never ahead of it' \
  || fail "the canon's effort declaration must carry the ordering rule both procedures enforce — the directive goes BEHIND the read-only/findings-only contract, never ahead of it"
printf '%s\n' "$INPUTSFLAT" | grep -qF 're-framing the contract behind it' \
  || fail "the canon must say WHY the ordering is load-bearing — a rule with no reason is the one that gets re-ordered for readability"
for procedure in './pipeline.md` §3' './adapter-dispatch.md` Part 1'; do
  printf '%s\n' "$INPUTSFLAT" | grep -qF -- "$procedure" \
    || fail "the canon's ordering rule must cite the procedure that enforces it ($procedure) rather than float free of both"
done
printf '%s\n' "$INPUTSFLAT" | grep -qF 'What a malformed `model` is' \
  || fail "engine inputs section must declare what makes a \`model\` malformed — finder-contract.md points here for it"
printf '%s\n' "$INPUTSFLAT" | grep -qF '`model` is a **model id string**, non-empty once trimmed' \
  || fail "the malformed-model criterion must state the accepted shape: a non-empty model id string"
printf '%s\n' "$INPUTSFLAT" | grep -qF 'shape, not the id' \
  || fail "the malformed-model criterion must state that lens validates the SHAPE and not the id — a model catalog written here goes stale on the next release"
printf '%s\n' "$INPUTSFLAT" | grep -qF 'raise for a call-time `injectedFinders` record, normalize-or-drop for a file-registered one' \
  || fail "the malformed-model criterion must route the two record forms to their own declared paths (D1)"
# NON-VACUITY: the criterion has to actually enumerate the malformed shapes, not just assert a rule.
for shape in 'a number' 'a bool' 'an object' 'an array' 'whitespace-only string' 'no value'; do
  printf '%s\n' "$INPUTSFLAT" | grep -qF "$shape" \
    || fail "the malformed-model criterion must name '$shape' among the shapes it rejects"
done

# render-review's own surface, including the empty-scope short-circuit.
RENDER="$(section "$H_RENDER" "$API")"
[ -n "$RENDER" ] || fail "the '$H_RENDER' section is empty"
for field in findings priorFindings diffRef spec plan adherence outputPath emptyScope; do
  printf '%s\n' "$RENDER" | grep -qF "$field" || fail "render-review section must declare '$field'"
done
# Pinned to the returns-table ROW, not a bare substring: the section names the literal in prose too, so
# a bare grep stays satisfied even if the declaration itself is renamed.
# shellcheck disable=SC2016 # literal backticks — this is the exact grepped row, not shell expansion
printf '%s\n' "$RENDER" | grep -qF '| `noop: nothing to review` | success |' \
  || fail "render-review section must declare 'noop: nothing to review' as a SUCCESS return"
printf '%s\n' "$RENDER" | grep -qF 'wrote: <path>' \
  || fail "render-review section must declare the 'wrote: <path>' success return alongside it"
# The empty case is a success; `skipped:` is the failure channel. Declaring the empty case ON that
# channel is what made a healthy empty scope indistinguishable from a broken render for a consumer.
if printf '%s\n' "$RENDER" | grep -qF 'skipped: nothing to review'; then
  fail "render-review section must NOT declare 'skipped: nothing to review' — 'skipped:' is failure-only"
fi
printf '%s\n' "$RENDER" | grep -qiE 'failure only|failure channel' \
  || fail "render-review section must name 'skipped:' the failure-only return"

# A consumer's assumption is recorded as a divergence, never promoted to contract.
CONSUMERS="$(section "$H_CONSUMERS" "$API")"
[ -n "$CONSUMERS" ] || fail "the '$H_CONSUMERS' section is empty"
# Pinned to the DECLARING bullet, not a bare substring: the section quotes `agents` again further down
# (matali's own CLAUDE.md wording), so a bare grep stayed satisfied even with the declaration renamed.
# shellcheck disable=SC2016 # literal backticks — this is the exact grepped bullet, not shell expansion
printf '%s\n' "$CONSUMERS" | grep -qF -- '- **An `agents` finder roster.**' \
  || fail "consumer-assumptions section must declare the 'agents' roster a consumer reads"
printf '%s\n' "$CONSUMERS" | grep -qi 'matali' \
  || fail "consumer-assumptions section must name matali as the consumer making the assumption"
printf '%s\n' "$CONSUMERS" | grep -qiE 'not part of the contract|not contracted' \
  || fail "consumer-assumptions section must state that 'agents' is not part of the contract"

# The hard-fail channel: one envelope, a CLOSED code registry, and both bounding invariants — declared
# in the canon and nowhere else, so a consumer branches on a code lens promises rather than on prose.
ERRORS="$(section "$H_ERRORS" "$API")"
bounded "engine-api.md § Errors" 40 "$ERRORS"

python3 - "$ERRORS" <<'PY' || fail "engine-api.md § Errors does not declare the envelope and the closed code registry"
import json, re, sys

errors = sys.argv[1]

# ENVELOPE — parsed, not substring-matched, and asserted in BOTH directions: a fourth key, a renamed
# key or a dropped one all fail. A caller pattern-matches this shape, so its key set IS the contract.
m = re.search(r"```json\n(.*?)\n```", errors, re.S)
assert m, "§ Errors must carry the error envelope as a fenced json block"
env = json.loads(m.group(1))
assert set(env) == {"error"}, f"the envelope's top level must be exactly 'error', got {sorted(env)}"
assert set(env["error"]) == {"code", "message", "extra"}, \
    f"the envelope must declare exactly code/message/extra, got {sorted(env['error'])}"
assert env["error"]["message"], "the envelope must show what 'message' holds, not an empty placeholder"
assert isinstance(env["error"]["extra"], dict), "the envelope's 'extra' must be an object"

# CLOSED REGISTRY, exact set both directions — widening it is an ask-first boundary in the spec, so
# it is machine-checked here rather than trusted to review; a deleted code fails just as loudly.
# The prefix class is MANDATORY on every E_ scan in this repo: a bare `E_[A-Z_]+` also matches
# MERGE_BASE / DEFAULT_BRANCH in pipeline.md's shell example.
expected = {"E_UNSUPPORTED_CAPABILITY", "E_MODEL_POLICY_UNSATISFIABLE", "E_INVALID_INPUT",
            "E_MANIFEST_UNREADABLE"}
found = set(re.findall(r"(?:^|[^A-Za-z0-9_])(E_[A-Z_]+)", errors, re.M))
assert found == expected, \
    f"the registry is closed at exactly 4 codes; undeclared={sorted(found - expected)} missing={sorted(expected - found)}"

def rows(text):
    out = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cells[0] or set(cells[0]) <= set("-: ") or cells[0] == "Code":
            continue
        out.append(cells)
    return out

registry = {c[0].strip("`"): c for c in rows(errors)}
assert set(registry) == expected, \
    f"the registry TABLE must carry a row per code and no other row, got {sorted(registry)}"

# ONE INDEPENDENT PIN PER CODE — each row names the skill that raises it and a machine-branchable
# `extra`. Raisers are checked per code, not as a set: 'lens:engine' is not a substring of
# 'lens:capability', so a row that names the wrong raiser fails naming itself.
for code, raiser in (("E_UNSUPPORTED_CAPABILITY", "lens:capability"),
                     ("E_MODEL_POLICY_UNSATISFIABLE", "lens:engine"),
                     ("E_MANIFEST_UNREADABLE", "lens:capability"),
                     ("E_INVALID_INPUT", "lens:engine"),
                     # E_INVALID_INPUT is raised from BOTH skills: the engine's 1.5.0 keys and
                     # lens:capability's `require`. Named per skill, because a registry that assigns a
                     # code to one owner makes it unreachable from the other by the registry's own
                     # ownership rule — and an unreachable code is a validation promise that cannot be
                     # kept. The `require` half is asserted separately, so losing it names itself.
                     ("E_INVALID_INPUT", "lens:capability")):
    cells = registry[code]
    assert len(cells) == 4, f"{code}'s row must carry Code / Raised by / Trigger / extra, got {cells}"
    assert raiser in cells[1], f"{code} must be raised by {raiser}, its row says {cells[1]!r}"
    assert re.search(r"[A-Za-z]", cells[2]), f"{code}'s row must state what triggers it"
    assert re.search(r"[A-Za-z]", cells[3]), f"{code}'s row must declare a non-empty 'extra' shape"

for key in ("missing", "have"):
    assert key in registry["E_UNSUPPORTED_CAPABILITY"][3], \
        f"E_UNSUPPORTED_CAPABILITY's extra must name '{key}' — a caller needs both what was asked for and what exists"

# THE INSTALL-INTEGRITY CODE. Its `extra` is the whole reason the failure is machine-actionable: the
# path says WHICH install is broken and the exit status says HOW, so a half-synced manifest is
# distinguishable from an absent one without parsing the message.
for key in ("path", "exit"):
    assert key in registry["E_MANIFEST_UNREADABLE"][3], \
        f"E_MANIFEST_UNREADABLE's extra must name '{key}' — a caller needs which file failed and how"
manifest_trigger = registry["E_MANIFEST_UNREADABLE"][2]
assert ".version" in manifest_trigger, \
    "E_MANIFEST_UNREADABLE's trigger must name the `.version` read it guards"
assert re.search(r"never a fallback|no version is guessed", manifest_trigger), (
    "E_MANIFEST_UNREADABLE's trigger must state that an unreadable manifest is a failure and never a "
    "fallback — a fabricated version is the outcome this code exists to forbid"
)

# THE TRIGGER MUST COVER BOTH RAISE CASES the governing § Model resolution declares. The narrow
# reading — "denied, and no allowed candidate is left to substitute" — is true only of positions ⑥–⑦.
# A denied winner from ②–⑤ raises EVEN WHEN a substitute is available, because lens never clamps a
# model the caller explicitly asked for. A trigger that states only the ⑥–⑦ half tells a caller the
# ②–⑤ raise cannot happen, which is the contradiction this pin exists to prevent recurring.
trigger = registry["E_MODEL_POLICY_UNSATISFIABLE"][2]
for positions in ("②–⑤", "⑥–⑦"):
    assert positions in trigger, \
        f"E_MODEL_POLICY_UNSATISFIABLE's trigger must name raising positions {positions}, got {trigger!r}"
assert "even when an allowed candidate exists" in trigger, \
    "the trigger must state that a ②–⑤ denied winner raises EVEN WHEN an allowed candidate exists — " \
    "narrowing it to the no-candidate case contradicts § Model resolution's denied-winner rule"
assert "no allowed candidate" in trigger, \
    "the trigger must state that a ⑥–⑦ denied winner with no allowed candidate raises"
# THE THIRD RAISE CASE: the verifier floor. `deny` is not the only gate § Model resolution declares, so
# a trigger naming only `deny` tells a caller that a policy clearing the deny list always resolves —
# and a caller reading that has no way to anticipate the floor raise it can still receive.
assert "floor" in trigger, \
    "E_MODEL_POLICY_UNSATISFIABLE's trigger must also name the verifier floor — it is a second gate " \
    "that raises on the same terms, and a trigger that omits it under-declares the code's raise set"
assert "verifier" in trigger, \
    "the floor half of the trigger must name the `verifier` dispatch it applies to"
# ...AND `extra` MUST BE ABLE TO EXPRESS IT. The trigger covers two gates; the extra listed only a
# `deny` list, glossed as "the deny list that rejected that model" — but on a floor raise no deny list
# rejected anything and `deny` may be absent entirely, so the one code with two triggers came back
# with no way to tell them apart. `extra.role` is not the discriminator either: a deny raise on a
# verifier dispatch carries role `verifier` too. The section promises nothing must be recovered by
# parsing prose, so the discriminator has to be a field.
model_extra = registry["E_MODEL_POLICY_UNSATISFIABLE"][3]
for key in ("role", "agent", "resolved", "gate", "deny"):
    assert key in model_extra, \
        f"E_MODEL_POLICY_UNSATISFIABLE's extra must name '{key}'; got {model_extra!r}"
assert "verifier-floor" in model_extra and '"deny"' in model_extra, (
    "extra.gate must declare its two values — `\"deny\"` and `\"verifier-floor\"` — or a caller cannot "
    "tell which of the code's two triggers fired, which is the whole reason the field exists"
)
assert re.search(r"absent or empty on a floor raise", model_extra), (
    "the extra must state that `deny` is absent or empty on a floor raise — otherwise a caller reads "
    "an empty deny list as a malformed envelope instead of as the other gate"
)

# THE REQUIRE HALF of E_INVALID_INPUT. The spec's user-input trust boundary names lens:capability's
# require[] alongside the engine's three, so the trigger has to reach it or the boundary is declared
# and unenforced.
invalid_trigger = registry["E_INVALID_INPUT"][2]
assert "require" in invalid_trigger, \
    "E_INVALID_INPUT's trigger must name `require` — lens:capability's only caller input is inside the " \
    f"same strictly-validated trust boundary as the engine's, got {invalid_trigger!r}"
PY

# I-1 and I-2 bound the channel, and each is pinned by its own verbatim clause inside § Errors: they
# are separate promises (WHEN an error may be raised vs WHICH inputs may cause one) and losing either
# one must fail on its own rather than behind the other surviving.
printf '%s\n' "$ERRORS" | grep -qF 'only in pre-flight, before the first finder is dispatched' \
  || fail "engine-api.md § Errors must state I-1: an error may be raised only in pre-flight, before the first finder is dispatched"
printf '%s\n' "$ERRORS" | grep -qF 'a 1.4.3-shaped call can never receive an error envelope' \
  || fail "engine-api.md § Errors must state I-2: a 1.4.3-shaped call can never receive an error envelope"
# I-2's consequence is a separate claim from I-2 itself: without it, "no envelope" could be read as
# "the malformed old input is accepted", which is the opposite of the preserved normalize-or-drop posture.
printf '%s\n' "$ERRORS" | grep -qF 'normalize-or-drop' \
  || fail "engine-api.md § Errors must state that a malformed pre-1.5.0 input keeps its normalize-or-drop posture"

# The taxonomy is DECLARED in one file, RAISED from two procedure files (engine/SKILL.md's pre-flight
# and capability/SKILL.md), MIRRORED as a closed enum in the schema, and NARRATED in two release-facing
# documents. Those are three different relationships to a code and they get three different rules:
#
#   E_REQUIRED  — must carry at least one code (both directions), because each is a site the contract
#                 could not be stated without. A file here that carries none has lost its declaration.
#   E_NARRATIVE — MAY name a code and must not build a registry. A tree-wide ban that reached these
#                 two made the release's headline named-errors feature undisclosable: CHANGELOG.md
#                 could only write "the registry is closed at four" without saying which four, so no
#                 release note could tell a consumer what to branch on. Naming four strings is
#                 disclosure; a table of raisers and triggers is a second registry, and that is what
#                 the teeth below forbid.
#   everything else — banned outright, unchanged.
#
# This coexists with the finer REGION-level pin further down: inside engine/SKILL.md a code is legal in
# pre-flight and illegal in every stage below it (I-1).
E_PATTERN='(^|[^A-Za-z0-9_])E_[A-Z]'
E_REQUIRED=("$API" "$ESKILL" "$CAPSKILL" "$SCHEMA")
E_NARRATIVE=("$ROOT/lens/CHANGELOG.md" "$ROOT/lens/README.md")
E_FOUND="$(grep -rlE "$E_PATTERN" "$ROOT/lens" || true)"
for allowedfile in "${E_REQUIRED[@]}"; do
  printf '%s\n' "$E_FOUND" | grep -qxF "$allowedfile" \
    || fail "$allowedfile must carry the error codes it declares, raises or mirrors, and carries none"
done
while IFS= read -r foundfile; do
  [ -n "$foundfile" ] || continue
  ok=0
  for allowedfile in "${E_REQUIRED[@]}" "${E_NARRATIVE[@]}"; do
    if [ "$foundfile" = "$allowedfile" ]; then ok=1; fi
  done
  [ "$ok" -eq 1 ] \
    || fail "an error code escaped into $foundfile — engine-api.md declares the taxonomy, engine/SKILL.md's pre-flight and capability/SKILL.md raise from it, the schema mirrors the spellings, and only CHANGELOG.md/README.md may narrate one"
done <<< "$E_FOUND"

# THE TEETH ON THE NARRATIVE FILES. Widening the allow-list buys disclosure, not a second home for the
# registry: a narrative file may NAME codes and must not carry the table that says who raises them,
# what triggers them, or what `extra` they hold. Two independent negatives — the registry table's own
# header cells, and a code appearing as the leading cell of a table row, which is what a registry row
# looks like whatever its header says.
for narrated in "${E_NARRATIVE[@]}"; do
  [ -s "$narrated" ] || fail "missing $narrated"
  if grep -qE '^\|[^|]*\bRaised by\b' "$narrated"; then
    fail "${narrated#"$ROOT/"} must not re-materialize the § Errors registry table — it may name a code, not own one"
  fi
  if grep -qE '^\| *`?E_[A-Z_]+`? *\|' "$narrated"; then
    fail "${narrated#"$ROOT/"} must not carry an error code as a table row's leading cell — that is a registry row; engine-api.md § Errors owns the registry"
  fi
done

# AND THE DISCLOSURE ITSELF, which is the whole reason the list was widened. A permission nobody uses
# is indistinguishable from the ban it replaced, so the CHANGELOG must actually name every code in the
# closed registry — DERIVED from § Errors, never re-listed here.
CHANGELOG_LENS="$ROOT/lens/CHANGELOG.md"
while IFS= read -r code; do
  [ -n "$code" ] || continue
  grep -qF -- "$code" "$CHANGELOG_LENS" \
    || fail "lens/CHANGELOG.md must NAME $code — the registry is closed at four and this is the release note a consumer reads to learn which four to branch on"
done < <(printf '%s\n' "$ERRORS" | grep -oE '(^|[^A-Za-z0-9_])E_[A-Z_]+' | grep -oE 'E_[A-Z_]+' | sort -u)

# === THE REVERSE CROSS-CHECK: every degrade SITE names a code, not just every code a site ===
# The forward direction (each declared code appears at its governing rule site) is checked per-code
# above and in the pipeline pins below. It is only half the pairing: it proves no code is orphaned, and
# proves nothing about a rule that sets the bit and names no cause. Those existed — the adherence cap
# in §2, the injected-intent cap in rule 0, the two intent rules in engine/SKILL.md Step 2 and the
# adapter normalization backstop all instructed `degraded: true` with no code, so the schema's closed
# enum guarded a field the runtime was never told to populate.
#
# Scoped to lens/skills + lens/agents, the runtime prose: CHANGELOG.md and README.md NARRATE the field,
# they do not instruct the engine to set it, and a release note describing the pairing is not a degrade
# site. Codes are DERIVED from the schema enum, never re-listed here — a belt that carried its own copy
# would be the second source of truth the whole pairing block exists to prevent.
python3 - "$ROOT/lens" "$SCHEMA" <<'PY' || fail "a degrade site under lens/ sets degraded:true without naming its degradedReasons code"
import json, os, re, sys

lens_root, schema_path = sys.argv[1], sys.argv[2]
enum = set(json.load(open(schema_path, encoding="utf-8"))
           ["properties"]["degradedReasons"]["items"]["properties"]["code"]["enum"])

# THE LINE SELECTOR IS THE PART THAT LEAKED. The file walk below has always been comprehensive; the
# selector was `degraded`-adjacent-to-a-colon, so it saw only ONE of the three ways this tree writes
# the instruction. It missed the JSON form `"degraded": true` — already used in-tree for the FALSE
# case, so the true case was one keystroke from being invisible — and every prose form ("sets
# `degraded` to true"), which is how review/references/setup.md restated the file-registered degrade
# path with no code at all and no pin able to see it. All three forms are matched now.
SITE = re.compile(
    r"`?\"?degraded\"?`?"          # the field, bare / backticked / JSON-quoted
    r"(?:`?\s*:\s*|\s+(?:to|is|as)\s+)"  # `: `  or  ` to `/` is `/` as `
    r"`?true`?",                   # the value it is set to
    re.I,
)
# A code SPAN, not any backticked word: a degradedReasons code is a hyphenated lowercase token, so
# this cannot be satisfied (or tripped) by `summary`, `verified:false` or a cited file path.
CODE = re.compile(r"`([a-z][a-z0-9]*(?:-[a-z0-9]+)+)`")

# engine-api.md DECLARES the field — it states the biconditional and lists all seven codes on one row.
# It is not a degrade site: it instructs no engine to set anything, and counting it would hand the
# non-vacuity check below every code from a single declaration line, making it pass against a tree
# whose real instruction sites had all lost their codes. Same reason CHANGELOG.md and README.md sit
# outside this walk. The exclusion is asserted to resolve, so a rename cannot silently turn it into a
# no-op that re-admits the declaration.
DECLARING = os.path.join(lens_root, "skills", "engine", "references", "engine-api.md")
assert os.path.isfile(DECLARING), f"the excluded declaration file is missing: {DECLARING}"
assert SITE.search(open(DECLARING, encoding="utf-8").read()), (
    "engine-api.md no longer matches the site selector — the exclusion below is now a no-op, which "
    "means the selector has narrowed and this whole scan may have narrowed with it"
)

sites, named = [], set()
for sub in ("skills", "agents"):
    for dirpath, _, filenames in os.walk(os.path.join(lens_root, sub)):
        for name in sorted(filenames):
            if not name.endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            if os.path.abspath(path) == os.path.abspath(DECLARING):
                continue
            for n, line in enumerate(open(path, encoding="utf-8"), 1):
                if not SITE.search(line):
                    continue
                where = f"{os.path.relpath(path, lens_root)}:{n}"
                sites.append(where)
                assert "degradedReasons" in line, (
                    f"{where}: instructs `degraded: true` without naming degradedReasons on the same "
                    "line — the bit says a gap exists and the array says which, so a rule that sets "
                    "one without the other emits a return the schema now rejects"
                )
                invented = {c for c in CODE.findall(line)} - enum
                assert not invented, \
                    f"{where}: names {sorted(invented)}, which is not in the schema's degradedReasons enum"
                named |= {c for c in CODE.findall(line)} & enum

# NON-VACUITY, both ways. A scan with no sites passes every assertion above, and a scan whose sites all
# happen to name the same code proves nothing about the other six. The union must be the whole enum —
# which is the forward check restated as data rather than as a hand-written list of regions.
assert sites, "no `degraded: true` site was found under lens/skills or lens/agents — the scan is broken"
assert named == enum, (
    "every declared degradedReasons code must be named at a site that actually sets `degraded: true`; "
    f"never-set={sorted(enum - named)} (scanned {len(sites)} sites)"
)

# THE SELECTOR ITSELF IS EXERCISED, not trusted. Every phrasing family it is meant to cover is run
# through it here, and one it must NOT match is run through too — a selector broadened until it
# matches the word "degraded" anywhere would pass the whole block above while pinning nothing.
for form in ('set `degraded: true` and', '{ "degraded": true }', 'sets `degraded` to true',
             'degraded:true', 'the run is degraded as true'):
    assert SITE.search(form), f"the degrade-site selector fails to match the in-tree form {form!r}"
for notform in ('"degraded": false', 'degraded: false', 'a degraded run', 'not degraded'):
    assert not SITE.search(notform), \
        f"the degrade-site selector matches {notform!r}, which sets nothing — it has broadened past its subject"

# THE CODED SITE THIS DIFF ADDED. setup.md restated the file-registered degrade path for a human
# writing project config and named neither the bit nor the code; it is the site the widened selector
# was built to catch, so it is asserted by name rather than left to the sweep to notice.
setup = os.path.join(lens_root, "skills", "review", "references", "setup.md")
assert any(s.startswith("skills/review/references/setup.md:") for s in sites), (
    f"{setup}: the file-registered malformed-record rule must instruct `degraded: true` with its "
    "degradedReasons code — a human reading only this file otherwise learns the drop is silent"
)
PY

# The canon points at the procedure it defers to.
for citation in '../../review/references/reconcile.md' '../../render-review/SKILL.md' '../SKILL.md'; do
  grep -qF "$citation" "$API" || fail "engine-api.md must cite '$citation'"
done

# === PIPELINE: the stage procedure keeps every rule; the arg shapes live in the canon ===
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
[ -s "$PIPE" ] || fail "missing $PIPE"

# No argument shape is re-declared here — a shape stated twice is a surface that has begun to fork.
if grep -qF 'Array<{' "$PIPE"; then
  fail "pipeline.md must not re-declare an argument type — engine-api.md owns the shapes"
fi
if grep -qF 'severityTrend' "$PIPE"; then
  fail "pipeline.md must not name severityTrend — reconcile sets it, never the engine"
fi
if grep -qE '(^|[^-[:alnum:]])delta\b' "$PIPE"; then
  fail "pipeline.md must not name delta — reconcile sets it, never the engine"
fi
grep -qF 'engine-api.md' "$PIPE" || fail "pipeline.md must point at engine-api.md for the declared arg shapes"

# Rule 0's ordering IS behavior. Each clause is pinned on its own, and scoped to rule 0 itself — the
# later rules repeat some of this wording, so a whole-file grep would survive losing rule 0's copy.
# The terminator is structural as well as textual (`^## ` mirrors section()'s): keyed only to rule 1's
# title, renaming that title widened the region to EOF — where rule 1's own "wins outright" masked the
# loss of rule 0's copy. The ceiling catches the widening the emptiness guard structurally cannot.
RULE0="$(awk '/^0\. \*\*injected intent/{inside=1} inside && (/^1\. \*\*explicit args/ || /^## /){exit} inside{print}' "$PIPE")"
bounded "pipeline.md §2 rule 0 (injected intent)" 35 "$RULE0"
rule0_has(){ printf '%s\n' "$RULE0" | grep -qE "$1" || fail "$2"; }
rule0_has 'highest-priority' "pipeline.md rule 0 must stay the highest-priority intent source"
rule0_has 'before \*\*rule 1\*\*|before rule 1' "pipeline.md rule 0 must still run before rule 1"
rule0_has 'wins outright' "pipeline.md rule 0 must still win outright over every rule below"
rule0_has 'skip rules 1' "pipeline.md rule 0 must still skip rules 1-4 entirely"
rule0_has "[Nn][Oo][Tt] \`?degraded\`?" "pipeline.md rule 0 must keep the exemption: explicit full-fidelity intent is NOT degraded"
rule0_has 'parse it defensively' "pipeline.md rule 0 must keep the defensive JSON-string parse"

# The intent doc reaches an agent as fenced data — the whole framing paragraph survives.
grep -qF '<untrusted-user-input>' "$PIPE" || fail "pipeline.md §3 must keep the <untrusted-user-input> fence"
grep -qF 'data, not instructions' "$PIPE" || fail "pipeline.md §3 must keep the 'data, not instructions' directive"
grep -qF 'framing, not filtering' "$PIPE" || fail "pipeline.md §3 must keep 'framing, not filtering' (no length cap)"
grep -qF 'all sources' "$PIPE" || fail "pipeline.md §3 must keep the fence applying to all intent sources"

# CODE↔SITE CROSS-CHECK (U2): each of the 7 degradedReasons codes engine-api.md declares must be
# NAMED at its own governing procedure site — a code with no governing site fails its own pin,
# independent of the other six. §2 (this section) governs the two intent-selection codes.
SEC2="$(awk '/^## 2\./{inside=1;next} /^## /{if(inside)exit} inside{print}' "$PIPE")"
bounded "pipeline.md §2 (intent-source selection)" 70 "$SEC2"
printf '%s\n' "$SEC2" | grep -qF 'intent-soft' \
  || fail "pipeline.md §2 must name degradedReasons code intent-soft at the modified-only soft-signal rule"
printf '%s\n' "$SEC2" | grep -qF 'intent-reconstructed' \
  || fail "pipeline.md §2 must name degradedReasons code intent-reconstructed at the transcript-reconstruction rule"

# The fan-out cap covers the injected path too, and names what it skipped. Scoped to §8: earlier
# sections carry their own "name the skipped", which would otherwise mask a loss here.
CAP="$(awk '/^## 8\./{inside=1;next} /^## /{if(inside)exit} inside{print}' "$PIPE")"
bounded "pipeline.md §8 (huge-diff rule + fan-out cap)" 45 "$CAP"
printf '%s\n' "$CAP" | grep -qF 'source-agnostic' || fail "pipeline.md §8 must keep the source-agnostic cap"
# One pin per promise, keyed to its own subject: §8 makes the never-silently-drop promise THREE times
# (diff-correlated specs/plans, injected docs, injected finders) and a single region-wide grep for the
# shared phrasing was satisfied by any one of them surviving.
printf '%s\n' "$CAP" | grep -qF 'name the skipped specs/plans' \
  || fail "pipeline.md §8 must keep naming the skipped specs/plans, never silently dropping one"
printf '%s\n' "$CAP" | grep -qF 'name the skipped injected docs' \
  || fail "pipeline.md §8 must keep naming the skipped injected docs, never silently dropping one"
printf '%s\n' "$CAP" | grep -qF 'name the skipped finders' \
  || fail "pipeline.md §8 must keep naming the skipped injected finders, never silently dropping one"
# CODE↔SITE CROSS-CHECK (U2 continued): §8 governs the three cap/truncation codes.
printf '%s\n' "$CAP" | grep -qF 'diff-truncated' \
  || fail "pipeline.md §8 must name degradedReasons code diff-truncated at the huge-diff truncation rule"
printf '%s\n' "$CAP" | grep -qF 'adherence-capped' \
  || fail "pipeline.md §8 must name degradedReasons code adherence-capped at the adherence fan-out cap rule"
printf '%s\n' "$CAP" | grep -qF 'finders-capped' \
  || fail "pipeline.md §8 must name degradedReasons code finders-capped at the injected-finders cap rule"

# Both back-compat promises (absent injectedIntent, absent injectedFinders) survive. Region-scoped —
# pipeline.md carries a THIRD, unrelated 'byte-identical' line (§1's emptyScope/findings[] return
# contract), so a whole-file line count could lose either named promise and still clear a >=2 threshold.
rule0_has 'byte-identical' "pipeline.md rule 0 must keep its own byte-identical back-compat promise (behavior byte-identical to v1.1.0)"

INJFINDERS="$(awk '/^\*\*Injected finders \(programmatic caller\)\.\*\*/{print}' "$PIPE")"
[ -n "$INJFINDERS" ] || fail "pipeline.md §3 injected finders paragraph is missing"
printf '%s\n' "$INJFINDERS" | grep -qF 'byte-identical' \
  || fail "pipeline.md §3 injected finders paragraph must keep its byte-identical back-compat promise (to 1.2.0)"

echo "PASS: lens engine-api belt (ref guards, fencing preservation, JSON example integrity, canon, pipeline)"

# === ENGINE SKILL: canon citation, no shape/return redeclaration, corrected caller claim ===
# (ESKILL is defined above, alongside API — the error-code allow-list needs it.)

# 1. The engine SKILL cites the canon as its declared input/return surface.
grep -qF 'references/engine-api.md' "$ESKILL" || fail "engine/SKILL.md must cite references/engine-api.md"

# 2. No shape redeclaration — the canon is the only place an arg/return shape is spelled out.
if grep -qF 'Array<{' "$ESKILL"; then
  fail "engine/SKILL.md must not re-declare an argument shape — engine-api.md owns the shapes"
fi

# 3. Floor (b): neither delta nor severityTrend as an engine return, in the engine's own runtime file.
if grep -qF 'severityTrend' "$ESKILL"; then
  fail "engine/SKILL.md must not name severityTrend — reconcile sets it, never the engine"
fi
if grep -qE '(^|[^-[:alnum:]])delta\b' "$ESKILL"; then
  fail "engine/SKILL.md must not name delta — reconcile sets it, never the engine"
fi

# 4. Frontmatter description: the stale 'invoked BY lens:review'-only claim is corrected to name the
# real callers. Scoped to the description line itself, not a whole-file grep — Step 2's body legitimately
# says "lens:review" elsewhere for an unrelated reason, which would make a whole-file check vacuous.
DESC="$(grep '^description:' "$ESKILL")"
[ -n "$DESC" ] || fail "engine/SKILL.md frontmatter must carry a description: line"
if printf '%s\n' "$DESC" | grep -qF 'invoked BY lens:review'; then
  fail "engine/SKILL.md description must no longer claim it is invoked BY lens:review only"
fi
printf '%s\n' "$DESC" | grep -qiE 'matali|orchestrator' \
  || fail "engine/SKILL.md description must name matali or a programmatic orchestrator as a real caller"
printf '%s\n' "$DESC" | grep -qF '/lens:review' \
  || fail "engine/SKILL.md description must still name /lens:review as a real caller"

# 5. RETENTION — scoped to the regions this unit's two edits touch (frontmatter + intro), so a
# whole-file grep can't mask a loss the way U3's gatekeeper caught elsewhere.
FRONTMATTER="$(awk '/^---$/{n++; next} n==1{print}' "$ESKILL")"
[ -n "$FRONTMATTER" ] || fail "engine/SKILL.md frontmatter block is empty"
printf '%s\n' "$FRONTMATTER" | grep -qF 'name: engine' || fail "frontmatter must keep name: engine"
printf '%s\n' "$FRONTMATTER" | grep -qF 'user-invocable: false' || fail "frontmatter must keep user-invocable: false"

INTRO="$(awk '/^# Engine/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md intro block" 15 "$INTRO"
printf '%s\n' "$INTRO" | grep -qF 'references/pipeline.md' || fail "intro must keep citing references/pipeline.md"
printf '%s\n' "$INTRO" | grep -qF 'references/finder-registry.md' || fail "intro must keep citing references/finder-registry.md"
printf '%s\n' "$INTRO" | grep -qF 'Write no files' || fail "intro must keep the write-no-files / ask-no-questions clause"

# taskIds no-op-when-absent wording + task-blind sentence (Progress tracking section).
PROGRESS="$(awk '/^## Progress tracking/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md Progress tracking section" 20 "$PROGRESS"
printf '%s\n' "$PROGRESS" | grep -qiE 'absent.*orchestrator|task action.*byte-identical' \
  || fail "Progress tracking section must keep the taskIds-absent no-op wording"
printf '%s\n' "$PROGRESS" | grep -qi 'task-blind' \
  || fail "Progress tracking section must keep the task-blind sentence"

# Everything between an H2 and the next one, so each pin judges only its own stage. The terminator is
# structural (`^## `), not keyed to the next heading's title, so renaming that title cannot widen a
# region to EOF and turn every pin scoped to it into a whole-file grep.
eregion(){ awk -v h="$1" 'index($0,h)==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$ESKILL"; }

# === STEP 0 — PRE-FLIGHT: the one chokepoint ===
# POSITIONAL, not merely present. A Step 0 appended at EOF satisfies a `grep -q` while running after
# every stage it exists to gate, and one placed above `## Progress tracking` would truncate the intro
# extractor (which stops at the first `^## `). The line numbers are compared numerically.
eline_of(){ { grep -nE -- "$1" "$ESKILL" || true; } | head -1 | cut -d: -f1; }
# The heading itself must be the FORM .claude/rules/skills-authoring.md § SKILL.md Sections mandates —
# `## Step N: Action`. The em-dash/SHOUTED variant this section used to pin was the only heading in the
# marketplace breaking that rule, and pinning its literal is what would have made conforming later a
# red-belt change. The form is asserted by regex so a future Step 0 cannot drift back out of it, and
# the exact heading is derived once into STEP0_HEADING (used again by the exhaustive I-1 walk below).
STEP0_HEADING='## Step 0: Pre-flight'
grep -qxF "$STEP0_HEADING" "$ESKILL" \
  || fail "engine/SKILL.md must carry the heading '$STEP0_HEADING' on a line of its own — .claude/rules/skills-authoring.md mandates the '## Step N: Action' form, and review/SKILL.md proves it accommodates a Step 0"
if grep -qE '^## Step [0-9]+ ' "$ESKILL"; then
  fail "engine/SKILL.md step headings must use the mandated '## Step N: Action' form — a space after the number means it is not the colon form"
fi

L_PROGRESS="$(eline_of '^## Progress tracking')"
L_STEP0="$(eline_of '^## Step 0:')"
L_STEP1="$(eline_of '^## Step 1:')"
[ -n "$L_PROGRESS" ] || fail "engine/SKILL.md must carry a '## Progress tracking' heading"
[ -n "$L_STEP0" ] || fail "engine/SKILL.md must carry a '## Step 0:' heading on a line of its own"
[ -n "$L_STEP1" ] || fail "engine/SKILL.md must carry a '## Step 1:' heading"
[ "$L_STEP0" -gt "$L_PROGRESS" ] \
  || fail "'$STEP0_HEADING' must come AFTER '## Progress tracking' — placed above it, it truncates the intro extractor"
[ "$L_STEP0" -lt "$L_STEP1" ] \
  || fail "'$STEP0_HEADING' must come BEFORE '## Step 1:' — validation that runs after SCOPE is not pre-flight"

ESTEP0="$(eregion '## Step 0')"
bounded "engine/SKILL.md Step 0 (PRE-FLIGHT)" 30 "$ESTEP0"
step0_has(){ printf '%s\n' "$ESTEP0" | grep -qF -- "$1" || fail "$2"; }
# Line-scoped: the selector picks the ONE line making a claim, and the required literal must live on
# that same line — a region-wide grep would let a claim survive its own subject being renamed.
# The selector's SINGULARITY is asserted, not assumed — that is what makes "line-scoped" true. A
# selector matching several lines ORs them, so the pin passes while ANY one carries the literal and
# the claim it is named for can be deleted outright.
step0_line_has(){ # step0_line_has <line-selector> <required-literal> <why>
  local matched
  matched="$(printf '%s\n' "$ESTEP0" | grep -F -- "$1" || true)"
  one_line "$matched" "engine/SKILL.md Step 0 '$1'"
  printf '%s\n' "$matched" | grep -qF -- "$2" || fail "$3"
}

# THREE JOBS, one independent pin each. A pre-flight that validates but never resolves, or resolves but
# never raises, is a different stage than the one every downstream dispatch site is written against.
step0_line_has 'Validate the 1.5.0 keys' 'E_INVALID_INPUT' \
  "Step 0 must state that a malformed 1.5.0 key raises E_INVALID_INPUT"
for key in 'modelPolicy' 'verifyVotes' '`model`/`effort`'; do
  step0_has "$key" "Step 0's validation job must name the 1.5.0-introduced key $key"
done
step0_line_has 'Resolve the model plan' 'every producer' \
  "Step 0 must resolve the model plan for EVERY producer at once — resolution repeated per dispatch is the thing the chokepoint replaces"
# WHAT MAKES "every producer" RESOLVABLE THIS EARLY. Two producer tiers are only DETECTED at runtime
# (the adapter tier) or counted at INTENT (the adherence fan-out), so a plan keyed by dispatch instance
# could not be built here at all — and a stage below forced to resolve a late-arriving producer would
# either raise after ANALYZE began (I-1) or leave the deny gate unenforced for it. The plan is keyed by
# (role, agent) instead, and every agent NAME is knowable in pre-flight.
step0_line_has 'Resolve the model plan' '(role, agent)' \
  "Step 0's plan must be keyed by (role, agent), not by dispatch instance — a per-instance plan is not resolvable before INTENT or before adapter detection"
step0_line_has 'Resolve the model plan' 'detection decides only whether an already-resolved producer runs' \
  "Step 0 must state that runtime detection decides only WHETHER a resolved producer runs, never what it resolves to"
for knowable in 'adherence fan-out' 'references/finder-registry.md' 'settings.md'; do
  step0_line_has 'Resolve the model plan' "$knowable" \
    "Step 0's plan-keying sentence must account for '$knowable' — the producer sources whose membership is not knowable at Step 0"
done
# The floor rides the same resolution point, so the one stage allowed to raise is the one that applies it.
step0_line_has 'Resolve the model plan' 'verifier floor' \
  "Step 0 must apply the verifier floor where it resolves the plan — a floor applied later could not raise without breaking I-1"

# WHERE A MALFORMED FILE-REGISTERED RECORD IS DROPPED. Pre-flight consumes the file tier's model/effort
# to build the plan, so a rule that drops the malformed ones at any stage BELOW pre-flight runs after
# the plan it was meant to influence is already frozen. The drop site is named here, on the same line
# as the record form it governs, so a pointer aimed at the wrong stage fails rather than reads plausibly.
# The clause wraps across four physical lines, so it is pinned against the flattened bullet: the
# subject ("a file-registered record") and the rule that governs it land on different lines, and a
# line-scoped pin could only ever see one of them.
STEP0FLAT="$(flatten "$ESTEP0")"
FILEREG="$(printf '%s\n' "$STEP0FLAT" | grep -oE '\*\*file-registered\*\*[^|]*normalize' || true)"
[ -n "$FILEREG" ] \
  || fail "Step 0 must carry a clause governing a **file-registered** record's malformed model/effort"
printf '%s\n' "$FILEREG" | grep -qF 'normalized-or-dropped here in pre-flight' \
  || fail "Step 0 must state that a file-registered record's malformed model/effort is normalized-or-dropped IN PRE-FLIGHT — a drop at a later stage runs after the plan is frozen"
printf '%s\n' "$FILEREG" | grep -qF 'references/pipeline.md' \
  || fail "Step 0's file-registered clause must cite the governing rule's real home (pipeline.md §3), not a stage that governs finder OUTPUT items"
printf '%s\n' "$STEP0FLAT" | grep -qF 'frozen from what survives' \
  || fail "Step 0 must say WHY the drop has to happen in pre-flight: the model plan resolved next is frozen from what survives"
# NEGATIVE — the retired mis-pointer. Step 4 governs finder OUTPUT items and carries no record-level
# clause, so deferring a record-level rule to it pointed at a rule that does not exist.
if printf '%s\n' "$ESTEP0" | grep -qF 'Step 4'; then
  fail "Step 0 must not defer a file-registered RECORD's malformed model/effort to Step 4 — Step 4 governs finder OUTPUT items and has no record-level clause"
fi
# BY POINTER. The chain is declared once, in engine-api.md § Model resolution; restating it here is
# what test_model_policy.sh's count==1 pin forbids globally, so Step 0 cites the section instead.
step0_line_has '§ Model resolution' 'references/engine-api.md' \
  "Step 0 must resolve BY POINTER to engine-api.md § Model resolution rather than restating the chain"
step0_line_has 'Raise or proceed' 'no finder is dispatched' \
  "Step 0 must raise-or-proceed, with no finder dispatched on the raise path (I-1)"

# D2 — ORDERING. Pre-flight precedes the Step 1 short-circuit, so a caller bug surfaces regardless of
# diff state. Pinned on Step 0's side here; Step 1 carries the reciprocal note below.
step0_line_has 'before Step 1' 'not `emptyScope:true`' \
  "Step 0 must state D2 — it runs before Step 1's empty-scope short-circuit, so an empty diff carrying a malformed 1.5.0 input returns the error, not emptyScope:true"

# I-2 — WHICH INPUTS MAY RAISE. Two independent pins: that a pre-1.5.0-only call can never receive an
# envelope, and that a malformed pre-1.5.0 input still normalizes-or-drops. The second is not implied
# by the first — "no envelope" could otherwise be read as "the malformed old input is accepted".
I2LINE="$(printf '%s\n' "$ESTEP0" | grep -F 'can never receive an error envelope' || true)"
[ -n "$I2LINE" ] \
  || fail "Step 0 must state I-2: a call passing only pre-1.5.0 inputs can never receive an error envelope"
for old in target taskIds injectedIntent injectedFinders finders; do
  printf '%s\n' "$I2LINE" | grep -qF -- "$old" \
    || fail "Step 0's I-2 sentence must name '$old' among the pre-1.5.0 inputs that can never raise"
done
step0_line_has 'malformed pre-1.5.0 input' 'normalize-or-drop' \
  "Step 0 must state that a malformed pre-1.5.0 input keeps its normalize-or-drop posture"

# PAIRED POSITIVE for the I-1 scope scan below. That scan is a pure negative: deleting every code from
# the tree would satisfy it. Pre-flight must actually NAME the channel it gates, and name more than one
# code, so a registry collapsed to a single code fails here rather than passing both halves.
STEP0_CODES="$(printf '%s\n' "$ESTEP0" | grep -oE '(^|[^A-Za-z0-9_])E_[A-Z_]+' | grep -oE 'E_[A-Z_]+' | sort -u | grep -c '^E_' || true)"
[ "$STEP0_CODES" -ge 2 ] \
  || fail "Step 0 must name at least TWO DISTINCT error codes (found $STEP0_CODES) — without it the I-1 scan below passes vacuously against a tree with no codes at all"

# The degraded:false,emptyScope:true return literal (Step 1), byte-identical.
STEP1="$(awk '/^## Step 1/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md Step 1 section" 20 "$STEP1"
printf '%s\n' "$STEP1" | grep -qF '{findings:[],recommendedEscalation:"minor",degraded:false,emptyScope:true}' \
  || fail "Step 1 must keep the byte-identical empty-scope return literal"
# D2's reciprocal half, in the region the ordering actually constrains: whoever reads the short-circuit
# has to know it is already downstream of pre-flight, or D2 lives only in the section it exempts.
STEP1_D2="$(printf '%s\n' "$STEP1" | grep -F 'Step 0' || true)"
one_line "$STEP1_D2" "engine/SKILL.md Step 1 reciprocal D2 note"
printf '%s\n' "$STEP1_D2" | grep -qF 'empty-scope short-circuit' \
  || fail "Step 1 must carry the reciprocal D2 note — its empty-scope short-circuit is reached only after pre-flight passed"

# The injectedIntent wins/override sentence (Step 2).
STEP2="$(awk '/^## Step 2/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md Step 2 section" 20 "$STEP2"
printf '%s\n' "$STEP2" | grep -qiE 'injectedIntent.*(wins|override)|(wins|override).*injectedIntent' \
  || fail "Step 2 must keep the injectedIntent wins/override sentence"

# The injectedFinders dispatch sentence + the <untrusted-user-input> reference (Step 3).
STEP3="$(awk '/^## Step 3/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md Step 3 section" 25 "$STEP3"
printf '%s\n' "$STEP3" | grep -qiE 'inject.*(dispatch|finder)|dispatch.*inject' \
  || fail "Step 3 must keep the injectedFinders dispatch sentence"
printf '%s\n' "$STEP3" | grep -qF '<untrusted-user-input>' \
  || fail "Step 3 must keep the <untrusted-user-input> fence reference"
# CODE↔SITE CROSS-CHECK (U2): the dead/errored-finder cause is governed at Step 3.
printf '%s\n' "$STEP3" | grep -qF 'finder-died' \
  || fail "Step 3 must name degradedReasons code finder-died at the dead/errored finder rule"

# The finder-output normalization/reject rule (Step 4).
STEP4="$(awk '/^## Step 4/{n=1;next} n && /^## /{exit} n{print}' "$ESKILL")"
bounded "engine/SKILL.md Step 4 section" 20 "$STEP4"
# CODE↔SITE CROSS-CHECK (U2): the malformed-finder-output cause is governed at Step 4.
printf '%s\n' "$STEP4" | grep -qF 'finder-malformed' \
  || fail "Step 4 must name degradedReasons code finder-malformed at the normalize/reject rule"

# === KEY RULES: the four 1.4.3 invariants, plus I-1 and I-2 as rules of the runtime that obeys them ===
# The count is asserted EXACTLY, so a silently added seventh rule fails. The count alone never READS a
# rule, though — one rewritten in place keeps the section at six — so each is also pinned by a verbatim
# clause of its own invariant, and a gutted rule fails naming itself.
EKEYRULES="$(eregion '## Key Rules')"
bounded "engine/SKILL.md Key Rules section" 15 "$EKEYRULES"
EKR_COUNT="$(printf '%s\n' "$EKEYRULES" | grep -c '^- ' || true)"
[ "$EKR_COUNT" -eq 6 ] \
  || fail "engine/SKILL.md must carry exactly 6 Key Rules — the four from 1.4.3 plus I-1 and I-2 (found $EKR_COUNT)"
while IFS= read -r rule; do
  printf '%s\n' "$EKEYRULES" | grep -qF "$rule" || fail "engine/SKILL.md Key Rules must keep: '$rule'"
done <<'RULES'
Data only.
Schema-valid.
Read-only adapters.
Nothing dropped silently.
only in pre-flight, before the first finder is dispatched
a 1.4.3-shaped call can never receive an error envelope
RULES

# THE CATCH-ALL RULE MUST CARRY BOTH HALVES OF THE BICONDITIONAL. It instructed `degraded:true` ⇒
# degradedReasons three times and stated the converse nowhere, so an engine that recorded a cause and
# then judged coverage fine would emit `degraded:false` beside a populated array — which the schema now
# REJECTS, with no warning in the runtime file the engine actually follows. Pinned on the rule itself,
# because the file names degradedReasons elsewhere and a whole-file grep would be satisfied by the
# forward half surviving alone. Amended in place: the section is pinned at exactly six rules above, so
# the converse joins the rule that owns it rather than becoming a seventh.
DROPRULE="$(printf '%s\n' "$EKEYRULES" | grep -F 'Nothing dropped silently.' || true)"
one_line "$DROPRULE" "engine/SKILL.md 'Nothing dropped silently' Key Rule"
printf '%s\n' "$DROPRULE" | grep -qF 'never name a cause without the bit' \
  || fail "engine/SKILL.md's degrade Key Rule must instruct the CONVERSE too — degraded:false must carry no degradedReasons entries, and only this rule tells the runtime so"
printf '%s\n' "$DROPRULE" | grep -qF 'if and only if' \
  || fail "the degrade Key Rule must state the pairing as a biconditional — one direction stated alone is what let a populated array ship beside degraded:false"
printf '%s\n' "$DROPRULE" | grep -qF 'rejects a populated array beside `degraded:false`' \
  || fail "the degrade Key Rule must say the schema rejects the converse violation too, not only the bare bit — the runtime doc is where an engine learns what will be rejected"

# === I-1 SCOPE: pre-flight is the ONLY region that may name an error code ===
# The literals are DERIVED from § Errors rather than re-listed here: a hand-copied list goes stale the
# moment the registry moves, and would then ban codes that no longer exist while missing the new ones.
E_CODES="$(printf '%s\n' "$ERRORS" | grep -oE '(^|[^A-Za-z0-9_])E_[A-Z_]+' | grep -oE 'E_[A-Z_]+' | sort -u)"
E_CODE_COUNT="$(printf '%s\n' "$E_CODES" | grep -c '^E_' || true)"
[ "$E_CODE_COUNT" -eq 4 ] \
  || fail "the I-1 scan derived $E_CODE_COUNT codes from § Errors, expected the closed 4 — the derivation is broken, so the scan below would be scanning for nothing"

pregion(){ awk -v h="$1" 'index($0,h)==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$PIPE"; }
code_free(){ # code_free <region-label> <region-text>
  [ -n "$2" ] || fail "$1 is empty — the I-1 scan cannot see the region it is meant to clear"
  while IFS= read -r code; do
    [ -n "$code" ] || continue
    if printf '%s\n' "$2" | grep -qF -- "$code"; then
      fail "I-1: $1 names $code — an error may be raised only in pre-flight, so only Step 0 may name a code"
    fi
  done <<< "$E_CODES"
  # The non-word-char PREFIX CLASS is mandatory, not stylistic: a bare `E_[A-Z_]+` also matches
  # MERGE_BASE and DEFAULT_BRANCH in pipeline.md §1's shell example, so this scan would fail against
  # shell variables that are not error codes at all.
  if printf '%s\n' "$2" | grep -qE '(^|[^A-Za-z0-9_])E_[A-Z]'; then
    fail "I-1: $1 names an error code — an error may be raised only in pre-flight"
  fi
  return 0
}

for n in 1 2 3 4 5; do
  code_free "engine/SKILL.md Step $n" "$(eregion "## Step $n")"
done
for n in 1 2 3 4 5 6 7 8; do
  code_free "pipeline.md §$n" "$(pregion "## $n.")"
done

# The five stage regions above are a HAND-WRITTEN list, and a hand-written list only ever covers the
# regions someone remembered to write down. A code parked in `## Progress tracking`, or worded into an
# existing `## Key Rules` bullet, sat outside every named region and cleared the whole belt — `## Key
# Rules` was protected only incidentally, by the exactly-6-bullets count, which catches a code added as
# a NEW bullet and nothing else. So engine/SKILL.md is walked EXHAUSTIVELY here: the intro above the
# first H2, then every H2 the file actually carries, ENUMERATED FROM THE FILE rather than from this
# script. Step 0 is the single exemption; every other region — including an H2 added tomorrow — is
# scanned without this list ever being touched again. Each region is asserted non-empty by code_free,
# so a renamed heading fails loudly instead of silently scanning nothing.
ESKILL_H2S="$(grep '^## ' "$ESKILL" || true)"
[ -n "$ESKILL_H2S" ] || fail "engine/SKILL.md carries no H2 heading — the exhaustive I-1 walk has no region to scan"
printf '%s\n' "$ESKILL_H2S" | grep -qxF "$STEP0_HEADING" \
  || fail "engine/SKILL.md must carry '$STEP0_HEADING' verbatim — it is the ONE region the I-1 walk exempts, and a renamed heading would exempt the wrong one"
code_free "engine/SKILL.md intro (everything above the first H2)" "$(awk '/^## /{exit} {print}' "$ESKILL")"
while IFS= read -r h2; do
  [ -n "$h2" ] || continue
  if [ "$h2" = "$STEP0_HEADING" ]; then continue; fi
  code_free "engine/SKILL.md $h2" "$(eregion "$h2")"
done <<< "$ESKILL_H2S"

echo "PASS: lens engine SKILL belt (canon citation, pre-flight chokepoint, I-1 scoping, key rules, retention)"

# === REVIEW SKILL: the standalone flow only — no orchestrator/compute-only surface ===
# A programmatic caller drives lens:engine directly and never enters /lens:review, so the mode this
# file used to describe was unreachable prose. reconcile.md carries an identically-titled section that
# IS live (render-review consumes it); the pins below are what keep the two from being confused.
RSKILL="$ROOT/lens/skills/review/SKILL.md"
RECONCILE="$ROOT/lens/skills/review/references/reconcile.md"
RRSKILL="$ROOT/lens/skills/render-review/SKILL.md"
for f in "$RSKILL" "$RECONCILE" "$RRSKILL"; do [ -s "$f" ] || fail "missing $f"; done

# Ordered narrowest-first, so each pin names the specific shape of what came back.
if grep -qiE '^#+ +Orchestrator mode' "$RSKILL"; then
  fail "the 'Orchestrator mode' heading belongs to reconcile.md alone — review/SKILL.md must not carry one"
fi
if grep -qi 'orchestrat' "$RSKILL"; then
  fail "review/SKILL.md must name no orchestrator — /lens:review has one path and it is standalone"
fi
if grep -qi 'compute-only' "$RSKILL"; then
  fail "review/SKILL.md must carry no compute-only surface — /lens:review always renders and writes state"
fi
grep -qF '../engine/references/engine-api.md' "$RSKILL" \
  || fail "review/SKILL.md must cite ../engine/references/engine-api.md as the engine's declared contract"

# The 1.5.0 surface stops at the engine. The standalone path hands the engine none of the new inputs,
# so naming one here would advertise a channel a human running /lens:review has no way to fill — and
# an error code here would promise a hard-fail branch this skill does not have. Each token is its own
# assertion, so a partial leak names the one that arrived.
if grep -qE '(^|[^A-Za-z0-9_])E_[A-Z]' "$RSKILL"; then
  fail "review/SKILL.md must name no error code — the standalone path passes no 1.5.0 input and gains no error branch"
fi
for tok in modelPolicy verifyVotes degradedReasons; do
  if grep -qF "$tok" "$RSKILL"; then
    fail "review/SKILL.md must not name '$tok' — /lens:review passes no 1.5.0 input"
  fi
done
# The record-key spelling only, not the English word: `effort` is a Tier-3 record key on the
# programmatic-caller surface, and banning the whole word would be a different, false claim.
if grep -qE '`effort`|"effort"|\beffort:' "$RSKILL"; then
  fail "review/SKILL.md must not carry 'effort' as a record key — it is a programmatic-caller knob"
fi

# reconcile.md's two anchors are load-bearing for render-review's Step 1 and survive byte-for-byte.
grep -qxF '#### Wired in orchestrator mode' "$RECONCILE" \
  || fail "reconcile.md must keep the exact line '#### Wired in orchestrator mode'"
grep -qxF '## Orchestrator mode (compute-only)' "$RECONCILE" \
  || fail "reconcile.md must keep the exact line '## Orchestrator mode (compute-only)'"

# Pointer and target move together or not at all.
grep -qF '../review/references/reconcile.md' "$RRSKILL" \
  || fail "render-review/SKILL.md must still cite ../review/references/reconcile.md"
grep -qF '§ Orchestrator mode' "$RRSKILL" \
  || fail "render-review/SKILL.md must still cite reconcile.md's '§ Orchestrator mode' anchor"

# RETENTION — the live standalone flow is untouched. Each pin is scoped to the step that owns the
# behavior, so an over-deletion cannot be masked by wording that repeats elsewhere in the file.
# The terminator is structural (`^## `) as well as textual, and the heading line itself is skipped, so
# renaming the NEXT step's heading can no longer widen a region to EOF and turn every pin below into a
# whole-file grep. Each region is also bounded, which is what makes that widening fail loudly.
rstep(){ awk -v a="$1" -v b="$2" '$0 ~ a {n=1;next} n && ($0 ~ b || /^## /){exit} n{print}' "$RSKILL"; }

STEP0="$(rstep '^## Step 0' '^## Step 1')"
bounded "review/SKILL.md Step 0 (create the task list)" 20 "$STEP0"
printf '%s\n' "$STEP0" | grep -qF 'TaskCreate' || fail "Step 0 must still create the task list via TaskCreate"
printf '%s\n' "$STEP0" | grep -qF 'references/task-tracking.md' \
  || fail "Step 0 must still cite references/task-tracking.md as the task-list contract"

RSTEP2="$(rstep '^## Step 2' '^## Step 3')"
bounded "review/SKILL.md Step 2 (run the engine)" 30 "$RSTEP2"
printf '%s\n' "$RSTEP2" | grep -qF 'taskIds = { scope, intent, analyze, verify }' \
  || fail "Step 2 must still hand the engine its four taskIds"
printf '%s\n' "$RSTEP2" | grep -qF 'emptyScope === true' \
  || fail "Step 2 must still key the empty branch on result.emptyScope === true"
printf '%s\n' "$RSTEP2" | grep -qF 'nothing to review' \
  || fail "Step 2 must still report 'nothing to review' on the empty-scope branch"

RSTEP3="$(rstep '^## Step 3' '^## Step 4')"
bounded "review/SKILL.md Step 3 (reconcile)" 20 "$RSTEP3"
printf '%s\n' "$RSTEP3" | grep -qF 'after a successful render' \
  || fail "Step 3 must still defer the state write-back until after a successful render"

# Exactly one Key Rule is retired; the other five govern the standalone flow.
KEYRULES="$(awk '/^## Key Rules/{n=1;next} n && /^## /{exit} n{print}' "$RSKILL")"
bounded "review/SKILL.md Key Rules section" 15 "$KEYRULES"
# The count alone never reads a rule — a rule rewritten in place keeps the section at five. It stays
# as the over-addition guard; each surviving rule is pinned by a verbatim clause of its own invariant,
# so a gutted rule fails naming itself.
KR_COUNT="$(printf '%s\n' "$KEYRULES" | grep -c '^- ' || true)"
[ "$KR_COUNT" -eq 5 ] || fail "review/SKILL.md must keep exactly 5 Key Rules (found $KR_COUNT)"
while IFS= read -r rule; do
  printf '%s\n' "$KEYRULES" | grep -qF "$rule" || fail "review/SKILL.md Key Rules must keep: '$rule'"
done <<'RULES'
Never commit, edit, stage, or block
Engine owns judgment; review owns rendering + state.
never re-flag a finding as new just because lines moved
Markdown fallback when absent
finder subagents are task-blind
RULES

echo "PASS: lens review belt (standalone-only surface, reconcile anchors intact, live flow retained)"

# === REGISTRY: the file-based finder registry is labelled experimental/secondary, one phrasing, ===
# === at exactly the four programmatic-surface sites — and nowhere a human-only doc would go false ===
# shellcheck disable=SC2016 # literal backticks — this is the exact grepped string, not shell expansion
PHRASE='experimental — secondary to `injectedFinders`'
FREG="$ROOT/lens/skills/engine/references/finder-registry.md"
SETUP="$ROOT/lens/skills/review/references/setup.md"
FCONTRACT="$ROOT/lens/skills/engine/references/finder-contract.md"
LENSREADME="$ROOT/lens/README.md"
for f in "$FREG" "$SETUP" "$FCONTRACT" "$LENSREADME"; do [ -s "$f" ] || fail "missing $f"; done

# 1. The one phrasing appears verbatim at each of the four named sites — one assertion per file, so a
# partial rollout fails loudly naming the missing file rather than a single combined pass/fail.
grep -qF "$PHRASE" "$FREG" || fail "REGISTRY: finder-registry.md Tier 3 must carry the experimental/secondary label"
grep -qF "$PHRASE" "$CLAUDEMD" || fail "REGISTRY: lens/CONVENTIONS.md's Project-custom registry row must carry the experimental/secondary label"
grep -qF "$PHRASE" "$PIPE" || fail "REGISTRY: pipeline.md §3's project tier must carry the experimental/secondary label"
grep -qF "$PHRASE" "$ESKILL" || fail "REGISTRY: engine/SKILL.md Step 3's project tier must carry the experimental/secondary label"

# 2. NEGATIVE SCOPE PIN — a human running /lens:review standalone has no injectedFinders channel, so
# calling the file registry "secondary" in a human-facing doc would turn a true doc false.
grep -qF "$PHRASE" "$LENSREADME" && fail "REGISTRY: lens/README.md must NOT carry the experimental/secondary label — it is the only finder path for a standalone human run"
grep -qF "$PHRASE" "$SETUP" && fail "REGISTRY: review/references/setup.md must NOT carry the experimental/secondary label — same reason"

# 3. No arg shape may be re-declared in finder-registry.md — engine-api.md owns the shapes.
if grep -qF 'Array<{' "$FREG"; then
  fail "REGISTRY: finder-registry.md must not re-declare an argument shape — engine-api.md owns the shapes"
fi

# 4. finder-registry.md points at the canon for the shape it no longer declares.
grep -qF 'engine-api.md' "$FREG" || fail "REGISTRY: finder-registry.md must cite engine-api.md for the injectedFinders shape"

# 5. RETENTION (criterion 15a) — finder-contract.md's four numbered requirements survive, each heading
# present exactly once (a demotion elsewhere must not have collaterally trimmed the authoring contract).
for heading in '## 1. Emit' '## 2. Pick' '## 3. Be read-only' '## 4. Register'; do
  COUNT="$(grep -cF "$heading" "$FCONTRACT" || true)"
  [ "$COUNT" -eq 1 ] || fail "REGISTRY: finder-contract.md must carry '$heading' exactly once (found $COUNT)"
done

# 6. RETENTION (criterion 15b) — setup.md still writes the empty project registry and still explains
# what the list holds.
grep -qF 'finders: []' "$SETUP" || fail "REGISTRY: setup.md must still write the empty 'finders: []' project registry"
grep -qiE 'finders.*list holds.*project tier|project tier.*finders.*list' "$SETUP" \
  || fail "REGISTRY: setup.md must still explain the finders: list holds the project tier"

# 7. SHAPE INTEGRITY — the three Tier-3 YAML examples are the form a project actually copies, and
# nothing checked their keys: a demoted shape declaration left them unguarded, so an example could
# drift a key (or lose one) while every declare-once pin above stayed green. Parsed with regex/line
# scanning only — CI installs jsonschema and no PyYAML, so a YAML library is not available here.
python3 - "$ROOT/lens" "$FREG" "$FCONTRACT" "$SETUP" <<'PY' || fail "REGISTRY: a Tier-3 YAML example does not match the declared record shape"
import os, re, sys

lens_root, expected = sys.argv[1], sys.argv[2:]

ALLOWED = {"agent", "dimension", "label", "readonly", "model", "effort"}
REQUIRED = {"agent", "dimension", "readonly"}

def finder_blocks(text):
    """Every ```yaml fence declaring a `finders:` list WITH list items.

    setup.md's `finders: []` sits inside a ```markdown fence and declares no item — it is the
    settings-file skeleton, not a record example, and is deliberately out of scope."""
    out = []
    for block in re.findall(r"^```yaml\n(.*?)^```", text, re.S | re.M):
        lines = block.splitlines()
        if not any(re.match(r"^finders:\s*$", line) for line in lines):
            continue
        if not any(re.match(r"^\s*-\s+\S", line) for line in lines):
            continue
        out.append(lines)
    return out

def records(lines):
    """Each list item as its ordered key list. A `- key: value` line opens a record; an indented
    `key: value` line adds to the open one. Trailing `# comments` are stripped first."""
    out, cur = [], None
    for raw in lines:
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        m = re.match(r"^\s*-\s+([A-Za-z_][A-Za-z0-9_]*):", line)
        if m:
            if cur is not None:
                out.append(cur)
            cur = [m.group(1)]
            continue
        m = re.match(r"^\s+([A-Za-z_][A-Za-z0-9_]*):", line)
        if m and cur is not None:
            cur.append(m.group(1))
    if cur is not None:
        out.append(cur)
    return out

# TREE-WIDE, not just the three named files: a fourth example added elsewhere is exactly as
# unguarded as these were, and one deleted here must name the file it went missing from.
found = {}
for dirpath, _, filenames in os.walk(lens_root):
    for name in sorted(filenames):
        if not name.endswith(".md"):
            continue
        path = os.path.join(dirpath, name)
        blocks = finder_blocks(open(path, encoding="utf-8").read())
        if blocks:
            found[path] = blocks

missing = [p for p in expected if p not in found]
assert not missing, f"a Tier-3 finders: YAML example went missing from: {[os.path.relpath(p, lens_root) for p in missing]}"
unexpected = [p for p in found if p not in expected]
assert not unexpected, (
    "a Tier-3 finders: YAML example appeared outside the three guarded files: "
    f"{[os.path.relpath(p, lens_root) for p in unexpected]} — add it to this belt or remove it"
)
total = sum(len(b) for b in found.values())
assert total == 3, f"expected exactly 3 Tier-3 finders: YAML examples under lens/, found {total}"

demonstrates_both = 0
for path, blocks in found.items():
    where = os.path.relpath(path, lens_root)
    for lines in blocks:
        items = records(lines)
        assert items, f"{where}: its finders: example declares no record"
        for keys in items:
            assert len(keys) == len(set(keys)), f"{where}: a finders record repeats a key: {keys}"
            got = set(keys)
            assert got <= ALLOWED, (
                f"{where}: a finders record declares {sorted(got - ALLOWED)}, which is not part of the "
                f"Tier-3 record — engine-api.md declares it as {sorted(ALLOWED)}"
            )
            assert REQUIRED <= got, \
                f"{where}: a finders record is missing the required key(s) {sorted(REQUIRED - got)}"
            if {"model", "effort"} <= got:
                demonstrates_both += 1

# The two optional keys are the ones a reader is most likely to guess wrong, so at least one example
# has to show them in place rather than leaving them to prose.
assert demonstrates_both >= 1, \
    "at least one Tier-3 YAML example must demonstrate BOTH the optional model and effort keys"
PY

echo "PASS: lens finder-registry belt (experimental/secondary label, scope-pinned, shape demoted, retention intact)"

# === CLAUDE.md INDEX: the schema field enumeration is demoted to a pointer, not re-materialized ===

# 1-2. NEGATIVE — the four field-enumeration bullets are gone; the schema owns the field list now.
# Unanchored (not '^'-pinned): an indented re-materialization ("  - **Per finding ...") is still the
# same regression and must still be caught, the way its sibling '- **Top-level:**' check already is.
if grep -qF -- '- **Per finding' "$CLAUDEMD"; then
  fail "INDEX: CLAUDE.md must not re-materialize the per-finding field enumeration — schemas/review-findings.schema.json owns it"
fi
if grep -qF -- '- **Top-level:**' "$CLAUDEMD"; then
  fail "INDEX: CLAUDE.md must not re-materialize the top-level field enumeration — schemas/review-findings.schema.json owns it"
fi

# 2b. NEGATIVE — the two programmatic restatements U8 left behind are demoted too. An index may NAME a
# behavior and point at the canon; re-materializing the engine's empty-scope return literal or
# render-review's input list re-forks the surface engine-api.md exists to keep single. Each token below
# occurred exactly once before this demotion, so every pin here started non-vacuous.
if grep -qE -- 'emptyScope"?: *true' "$CLAUDEMD"; then
  fail "INDEX: CLAUDE.md must not re-materialize the empty-scope return literal — engine-api.md § lens:engine — returns owns it"
fi
if grep -qF -- '{ "findings": []' "$CLAUDEMD"; then
  fail "INDEX: CLAUDE.md must not re-materialize the engine's return object literal — engine-api.md § lens:engine — returns owns it"
fi
for rrfield in priorFindings diffRef outputPath; do
  if grep -qF -- "$rrfield" "$CLAUDEMD"; then
    fail "INDEX: CLAUDE.md must not re-enumerate render-review's '$rrfield' input — engine-api.md § lens:render-review — inputs and returns owns it"
  fi
done

# 3. POSITIVE — CLAUDE.md points at the canon for the declared programmatic surface.
grep -qF 'skills/engine/references/engine-api.md' "$CLAUDEMD" \
  || fail "INDEX: CLAUDE.md must cite skills/engine/references/engine-api.md as the declared programmatic surface"

# 3b. DISCRIMINATING — scoped to § Engine / render split alone. The bare substring check above is
# satisfied by either of two occurrences (this section's own pointer sentence, or the unrelated
# mention inside § The review-findings schema below); this pin isolates the first so losing IT
# specifically cannot hide behind the other one staying intact.
ENGINESPLIT="$(awk '/^## Engine \/ render split/{n=1;next} n && /^## /{exit} n{print}' "$CLAUDEMD")"
[ -n "$ENGINESPLIT" ] || fail "INDEX: CLAUDE.md § Engine / render split section is missing"
printf '%s\n' "$ENGINESPLIT" | grep -qF 'skills/engine/references/engine-api.md' \
  || fail "INDEX: CLAUDE.md § Engine / render split must itself point at skills/engine/references/engine-api.md"

# 3c. DISCRIMINATING — each site the 2b negatives emptied carries its OWN pointer, so the demotion
# reads as a redirection rather than a deletion. Scoped per section and bounded: an extractor that
# lost its terminator would swallow the rest of the file and pass on some other section's pointer.
for section in 'The pipeline' 'Skills'; do
  REGION="$(awk -v h="^## $section" '$0 ~ h {n=1;next} n && /^## /{exit} n{print}' "$CLAUDEMD")"
  bounded "CLAUDE.md § $section" 30 "$REGION"
  printf '%s\n' "$REGION" | grep -qF 'skills/engine/references/engine-api.md' \
    || fail "INDEX: CLAUDE.md § $section must point at skills/engine/references/engine-api.md rather than restate the surface"
done

# 4. CI-PINNED SUBSTRING RETENTION (criterion 16) — each an independent assertion, so a partial loss
# names itself instead of hiding behind one combined pass/fail. (The <untrusted-user-input> /
# 'framing, not filtering' fencing substrings are already pinned above in the FENCING PRESERVATION
# section on this same whole file — not repeated here, since a second bare grep would always be
# satisfied or denied by that earlier assertion first and could never independently fail.)
grep -qF '4 engine stages' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep '4 engine stages'"
grep -qF 'schema-parity target' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep 'schema-parity target'"
grep -qF 'live consumer' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep 'live consumer'"
# shellcheck disable=SC2016 # literal backticks — these are the exact grepped strings, not shell expansion
grep -qF '`review`' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must still name the review skill"
# shellcheck disable=SC2016
grep -qF '`engine`' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must still name the engine skill"
# shellcheck disable=SC2016
grep -qF '`render-review`' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must still name the render-review skill"
grep -qF 'silent-failure-hunter' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep the silent-failure-hunter adapter row"
grep -qF 'type-design-analyzer' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep the type-design-analyzer adapter row"
grep -qF 'comment-analyzer' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep the comment-analyzer adapter row"
grep -qF 'pr-test-analyzer' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep the pr-test-analyzer adapter row"
grep -qF 'feature-dev:code-reviewer' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep the feature-dev:code-reviewer adapter row"

# 5. The field-additive / co-owned alignment invariant survives.
grep -qF 'field-additive' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep 'field-additive'"
grep -qF 'co-owned' "$CLAUDEMD" || fail "INDEX: CLAUDE.md must keep 'co-owned'"

# 5b. ...AND IT MUST BE SCOPED TO WHAT IT ACTUALLY BINDS. The invariant reads "never rename, re-type,
# or repurpose a vicario field; only add optional ones" — true of the FIELD set, and silent about
# cross-field constraints, of which 1.5.0 adds three. Read unqualified it certifies that this release
# cannot invalidate a document 1.4.3's schema accepted, which is false: the degraded biconditional
# rejects every 1.4.3-produced degraded return. The round-trip claim below it needs the same treatment,
# because only ONE direction still holds. Both are pinned here, against the schema's own clause set, so
# a fourth cross-field constraint added without revisiting this section fails.
CLAUDEMD_FLAT="$(flatten "$(cat "$CLAUDEMD")")"
printf '%s\n' "$CLAUDEMD_FLAT" | grep -qF 'The invariant is about FIELDS' \
  || fail "INDEX: CLAUDE.md must scope the field-additive invariant to the FIELD set — unqualified it certifies a compatibility this release does not have"
printf '%s\n' "$CLAUDEMD_FLAT" | grep -qiF 'narrowings' \
  || fail "INDEX: CLAUDE.md must name the cross-field constraints as NARROWINGS — that is the word the CHANGELOG discloses them under, and the two must agree"
printf '%s\n' "$CLAUDEMD_FLAT" | grep -qF 'rejects *every* 1.4.3-produced return carrying `degraded: true`' \
  || fail "INDEX: CLAUDE.md must state the concrete break its invariant does not cover"
# THE ROUND-TRIP CLAIM, split by direction. "Both validators round-trip" is now true one way only.
printf '%s\n' "$CLAUDEMD_FLAT" | grep -qF 'The round-trip that still holds is the **lens → vicario** direction' \
  || fail "INDEX: CLAUDE.md's vicario round-trip claim must name the direction that still holds — stated symmetrically it is false, because a vicario-produced degraded document no longer validates here"
printf '%s\n' "$CLAUDEMD_FLAT" | grep -qF 'The **vicario → lens** direction is where the narrowings bite' \
  || fail "INDEX: CLAUDE.md must state which direction the narrowings break — a reader who only learns one half will assume the other"
# Derived by the SAME walk the CHANGELOG's disclosure is checked against (tests/lib/schema-narrowings.py),
# so the two documents cannot disagree about what the release narrows — and scoped to the PARAGRAPH that
# makes the claim rather than to the whole file, because a 200-line document names `total` and `refuted`
# incidentally and would satisfy a whole-file check while its own narrowing sentence named neither.
CLAUDEMD_NARROWPARA="$(awk '/The invariant is about FIELDS/{p=1} p{print} p&&/^$/{exit}' "$CLAUDEMD")"
[ -n "$CLAUDEMD_NARROWPARA" ] \
  || fail "INDEX: CLAUDE.md must carry the paragraph scoping the field-additive invariant — it is where the narrowings are disclosed"
printf '%s' "$CLAUDEMD_NARROWPARA" \
  | python3 "$ROOT/tests/lib/schema-narrowings.py" "$SCHEMA" \
  || fail "INDEX: CLAUDE.md's narrowing paragraph does not name every narrowing the schema carries over 1.4.3 — the invariant would go on reading as if it covered them"

echo "PASS: lens CLAUDE.md index belt (schema enumeration demoted, CI-pinned substrings retained)"
