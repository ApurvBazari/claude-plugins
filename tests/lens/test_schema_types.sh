#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEMA="$ROOT/lens/schemas/review-findings.schema.json"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$SCHEMA" ] || fail "schema missing"
python3 - "$SCHEMA" <<'PY' || fail "schema integer-type parity"
import json,sys
s=json.load(open(sys.argv[1]))

# THE TWO RETURN CHANNELS. The engine answers on a success channel (the review-findings object) or a
# failure channel (the pre-flight named-error envelope), and a caller branches on the presence of
# `error`. They are declared as a top-level oneOf rather than by adding an `error` PROPERTY, because the
# success return's field set is derived from s["properties"] (tests/lens/test_engine_api.sh) and an
# eighth property would silently restate the seven-field count as eight.
# Every "must stay optional" pin below is asserted against REQ — the union of whatever required[] the
# root still carries and the success branch's own — so the pins keep their teeth no matter which of the
# two the required set lives in, and a field promoted to required in EITHER place fails.
branches = s.get("oneOf")
assert isinstance(branches, list) and len(branches) == 2, \
    f"the schema must declare exactly two return channels as a top-level oneOf, got {branches!r}"
ok_branch = [b for b in branches if "error" not in b.get("required", [])]
err_branch = [b for b in branches if "error" in b.get("required", [])]
assert len(ok_branch) == 1 and len(err_branch) == 1, \
    "exactly one oneOf branch must require `error` (the failure channel) and exactly one must not (the success channel)"
ok_branch, err_branch = ok_branch[0], err_branch[0]
assert "error" not in s["properties"], (
    "the error envelope must be an alternative CHANNEL, never a top-level property of the success "
    "object — as a property it inflates the derived seven-field success count to eight"
)
# MUTUAL EXCLUSION. Without the success branch excluding `error`, an object carrying both a review and
# an envelope matches exactly one branch and validates — a half-and-half return the caller cannot branch
# on. With it, such an object matches neither.
assert ok_branch.get("not", {}).get("required") == ["error"], \
    "the success branch must EXCLUDE `error` — otherwise a hybrid object (a review carrying an envelope) validates"
assert err_branch.get("additionalProperties") is False, \
    "the failure branch must be sealed to `error` alone — an envelope must never arrive carrying half a review"
env = s["definitions"]["errorEnvelope"]
assert set(env.get("required", [])) == {"code", "message", "extra"}, \
    f"the error envelope must require exactly code/message/extra (the shape § Errors declares), got {env.get('required')}"
assert env.get("additionalProperties") is False, \
    "the error envelope must be sealed at code/message/extra — § Errors declares that key set exactly"
for k, t in (("code", "string"), ("message", "string"), ("extra", "object")):
    assert env["properties"][k]["type"] == t, f"errorEnvelope.{k} must be a {t}"
# THE CODE SET IS MIRRORED AND PINNED, exactly as degradedReasons' is. Left as a bare `code: string`,
# the "closed registry" was closed only in prose: {"error":{"code":"E_MADE_UP",…}} validated, so a
# consumer could not machine-check a set that had just moved from three codes to four. The schema's own
# stated reason for not mirroring — avoiding a second source of truth — is contradicted seventy lines
# away, where the identical claim is made for degradedReasons and then deliberately broken with a
# parity pin to keep the copy honest. This is the same trade, made the same way: a COPY, kept in step
# by the parity assertion at the bottom of this belt, not a second declaration.
codes = env["properties"]["code"].get("enum")
assert isinstance(codes, list) and codes, \
    "errorEnvelope.code must carry the closed code enum — a bare string accepts an invented code"
assert len(codes) == len(set(codes)), f"errorEnvelope.code repeats a code: {codes}"
REQ = set(s.get("required", [])) | set(ok_branch.get("required", []))

props=s["properties"]["findings"]["items"]["properties"]
assert props["line"]["type"]=="integer", "line must be integer (vicario parity)"
v=props["votes"]["properties"]
for k in ("total","couldNotRefute","refuted"):
    assert v[k]["type"]=="integer", f"votes.{k} must be integer (vicario parity)"
# U4 — the vote tally is a closed four-key set, asserted BOTH directions: the rule's invariant is
# couldNotRefute + refuted + abstained == total, so a missing key makes the invariant unstatable and
# an extra one makes it unprovable. abstained is typed here alongside the three it joins.
votes_keys=set(v)
assert votes_keys=={"total","couldNotRefute","refuted","abstained"}, \
    f"votes must declare exactly total/couldNotRefute/refuted/abstained, got {sorted(votes_keys)}"
assert v["abstained"]["type"]=="integer", "votes.abstained must be integer (it tallies dead votes)"
# RANGE, not just type. `{"total":1,"couldNotRefute":1,"refuted":1,"abstained":1}` and an all-negative
# tally both validated: a vote count is a count of DISPATCHES, so a negative member names a state the
# engine cannot reach, and a `total` outside 1..5 names a panel size no caller can ask for (verifyVotes
# is itself bounded 1..5 and rejected in pre-flight otherwise). A lower bound rejects no sibling field,
# so the vicario field-additive argument gives the omission no cover. The sum invariant stays prose —
# draft-07 cannot express a relation between siblings.
for k in ("total","couldNotRefute","refuted","abstained"):
    assert v[k].get("minimum")==0 or (k=="total" and v[k].get("minimum")==1), \
        f"votes.{k} must carry a lower bound — a negative tally is a state the engine cannot produce"
assert v["total"].get("minimum")==1 and v["total"].get("maximum")==5, (
    "votes.total must be bounded 1..5, the same range verifyVotes is validated against — a tally of a "
    f"panel size no caller can request is unreachable, got {v['total']}"
)
for k in ("couldNotRefute","refuted","abstained"):
    assert v[k].get("minimum")==0, f"votes.{k} must carry minimum:0"
    assert "maximum" not in v[k], (
        f"votes.{k} must NOT carry an upper bound of its own — it is bounded by the sum invariant "
        "against total, and a second, independent ceiling would be a rule the engine never checks"
    )
# voteResolution — the per-finding outcome of huginn-quorum-v1. EXACT enum, both directions:
# 'dropped' is deliberately absent because a dropped finding never reaches findings[], so a value
# that can never be observed would advertise a state the contract cannot produce.
vr=props["voteResolution"]
assert vr["type"]=="string", "voteResolution must be a string"
assert set(vr["enum"])=={"verified","abstained"} and len(vr["enum"])==2, \
    f"voteResolution enum must be exactly verified/abstained, got {vr['enum']}"
assert "dropped" not in vr["enum"], \
    "voteResolution must never carry 'dropped' — a dropped finding is absent from findings[], not labelled"
# Both stay optional: a 1.4.3-shaped finding carries neither and must still validate.
finding_required=set(s["properties"]["findings"]["items"].get("required",[]))
for k in ("votes","voteResolution"):
    assert k not in finding_required, f"{k} must stay optional (not in the per-finding required[])"
    assert k not in REQ, f"{k} must not enter the success channel's required[]"
# The dimension enum is the canonical 9-value SHARED contract (vicario's six + lens's
# test/risk/comment). Assert it EXACTLY: a subset check would let test/risk/comment be deleted
# silently (every other test still passes), and an extra value would diverge from the co-owned
# vicario enum. Lock both directions here.
expected={"requirements","correctness","security","types","silent-failure","simplify","test","risk","comment"}
dims=props["dimension"]["enum"]
assert len(dims)==len(expected) and set(dims)==expected, \
    f"dimension enum must be exactly the 9 canonical shared values, got {dims}"
# convergence fields — optional + field-additive (must NOT enter required); iteration stays render-only.
top=s["properties"]
assert top["severityTrend"]["type"]=="string", "severityTrend must be a string"
assert set(top["severityTrend"]["enum"])=={"improving","same","regressed"}, \
    f"severityTrend enum must be improving/same/regressed, got {top['severityTrend']['enum']}"
assert top["delta"]["type"]=="object", "delta must be an object"
for k in ("fixed","new","stillOpen"):
    assert top["delta"]["properties"][k]["type"]=="integer", f"delta.{k} must be integer"
for k in ("delta","severityTrend"):
    assert k not in REQ, f"{k} must stay optional (field-additive superset)"
# F1 — emptyScope discriminator: must exist as boolean, must NOT be required
# (field-additive — vicario's validator ignores it; only the dimension enum is co-owned)
assert top["emptyScope"]["type"]=="boolean", "emptyScope must be a boolean property"
assert "emptyScope" not in REQ, \
    "emptyScope must stay optional (field-additive; vicario must not require it)"
# L3 — adherence item shape is declared (additive: properties only, never required,
# no additionalProperties:false — matali payloads valid under 1.4.1 must stay valid).
adh = top["adherence"]
assert adh["type"] == "object", "adherence must be an object"
assert "adherence" not in REQ, "adherence must stay optional (field-additive)"
si = adh["properties"]["specItems"]
ps = adh["properties"]["planSteps"]
assert si["type"] == "array" and ps["type"] == "array", "specItems/planSteps must be arrays"
si_props = si["items"]["properties"]
ps_props = ps["items"]["properties"]
for k in ("label", "state", "sourceSpec"):
    assert k in si_props, f"specItems.items must declare '{k}' property"
for k in ("label", "state", "sourcePlan"):
    assert k in ps_props, f"planSteps.items must declare '{k}' property"
# L3 harden — pin the state ENUM VALUES, not just key presence: a dropped/renamed/added member
# must fail, and the enums must stay in agreement with review-model-assembly.md's documented vocabulary.
assert set(si_props["state"].get("enum", [])) == {"met", "partial", "missing"}, \
    f"specItems.state enum must be exactly met/partial/missing, got {si_props['state'].get('enum')}"
assert set(ps_props["state"].get("enum", [])) == {"followed", "deviated"}, \
    f"planSteps.state enum must be exactly followed/deviated, got {ps_props['state'].get('enum')}"
# additive-safety: the item objects must NOT force required keys or seal additionalProperties,
# or a valid 1.4.1 adherence payload (e.g. flat single-spec items lacking sourceSpec) would be rejected.
assert "required" not in si["items"] and "required" not in ps["items"], \
    "adherence item objects must not add a required[] (would reject 1.4.1-valid payloads)"
assert si["items"].get("additionalProperties", True) is not False, "specItems.items must not seal additionalProperties"
assert ps["items"].get("additionalProperties", True) is not False, "planSteps.items must not seal additionalProperties"
# U2 — degradedReasons: array, closed 7-code enum (both directions), detail is a string, optional
# (never required); and the top-level required[] is pinned so a widening there fails loudly too.
dr = top["degradedReasons"]
assert dr["type"] == "array", "degradedReasons must be an array"
dr_props = dr["items"]["properties"]
expected_codes = {
    "finder-died", "finder-malformed", "intent-soft", "intent-reconstructed",
    "adherence-capped", "finders-capped", "diff-truncated",
}
codes = set(dr_props["code"]["enum"])
assert codes == expected_codes, \
    f"degradedReasons code enum must be exactly the 7 closed causes, got {codes}"
assert dr_props["detail"]["type"] == "string", "degradedReasons.detail must be a string"
# CONDITIONALLY required, never UNCONDITIONALLY so — and the difference is the whole point. REQ is
# built from the root and success-branch required[] arrays only, so it is structurally blind to the
# allOf's conditional `required: ["degradedReasons"]` asserted below. Read as "degradedReasons is
# optional", this line was false as a statement about the contract — a degraded return that omits the
# array is REJECTED — and it is the line a maintainer reads as the backward-compat guard. Its true
# content is narrower, and is stated here as the two halves it actually has, each falsifiable: promote
# the field into the root required[] and the first fires; delete the conditional clause and the second.
assert "degradedReasons" not in REQ, (
    "degradedReasons must not be UNCONDITIONALLY required — a clean return omits it entirely and must "
    "still validate (that is the 1.4.3-shaped success case)"
)
assert any(
    c.get("then", {}).get("required") == ["degradedReasons"]
    for c in ok_branch.get("allOf", [])
), (
    "degradedReasons must be CONDITIONALLY required by the degraded:true clause — 'optional' on its own "
    "is not a true statement about this contract, and asserting only the absence from required[] "
    "certifies the half that cannot fail"
)
# The cause object is SEALED AROUND `code`. Both halves are pinned separately because they fail
# differently: without required[code], {} and {"detail": "…"} validate and a degrade names no cause
# at all; without additionalProperties:false, a typo'd key rides along beside a valid code and the
# closed enum above guards a field nothing has to carry.
dr_items = dr["items"]
assert dr_items.get("required") == ["code"], \
    f"degradedReasons items must require exactly ['code'] — otherwise a cause object naming no cause validates, got {dr_items.get('required')!r}"
assert dr_items.get("additionalProperties") is False, \
    "degradedReasons items must seal additionalProperties — otherwise an undeclared key validates alongside the closed code enum"
# THE BICONDITIONAL. `degraded` and a non-empty `degradedReasons[]` are one fact stated twice, and
# the two if/then clauses in the success branch are what make the second statement checkable rather
# than merely written down. Asserted clause by clause — an allOf that survives having lost a half
# leaves exactly the contradiction the pair exists to forbid, so "allOf is non-empty" is not a pin.
clauses = ok_branch.get("allOf")
assert isinstance(clauses, list) and len(clauses) == 3, (
    "the success branch must carry exactly three allOf clauses — the two directions of the degraded "
    f"biconditional, plus emptyScope's implication — got {clauses!r}"
)
# Partitioned by the key each clause fires on, so the emptyScope clause cannot be mistaken for a
# degraded one and a missing clause names the field it governed.
by_key = {}
for c in clauses:
    cond = c.get("if", {})
    req = cond.get("required")
    assert isinstance(req, list) and len(req) == 1, \
        f"each cross-field clause must fire on exactly one present key, got if={cond!r}"
    key = req[0]
    const = cond.get("properties", {}).get(key, {}).get("const")
    assert isinstance(const, bool), \
        f"each clause's `if` must pin `{key}` to a boolean const (that is what selects the direction), got {const!r}"
    by_key.setdefault(key, {})[const] = c.get("then", {})
assert set(by_key) == {"degraded", "emptyScope"}, \
    f"the success branch's cross-field clauses must govern degraded and emptyScope, got {sorted(by_key)}"

by_const = by_key["degraded"]
assert set(by_const) == {True, False}, \
    f"the clauses must cover BOTH directions (degraded true and degraded false), got {sorted(by_const)}"
assert by_const[True].get("required") == ["degradedReasons"], \
    "degraded:true must require degradedReasons — otherwise the bit is set and no cause is ever named"
assert by_const[True].get("properties", {}).get("degradedReasons", {}).get("minItems") == 1, \
    "degraded:true must force degradedReasons non-empty — a present-but-empty array names no cause either"
assert by_const[False].get("properties", {}).get("degradedReasons", {}).get("maxItems") == 0, \
    "degraded:false must force degradedReasons empty — otherwise a return names causes while claiming full coverage"

# emptyScope carries the same contradiction the biconditional just closed, read from one side:
# `{emptyScope: true, findings: [<a finding>]}` validated, despite emptyScope being declared "true ONLY
# on empty-diff/no-repo" and "the SOLE discriminator between nothing-to-review and a review that found
# nothing". A caller keyed on the flag, as the contract instructs, would report a populated review as
# nothing to review — and render-review would return `noop:` and write no artifact for it.
assert True in by_key["emptyScope"], \
    "a clause must fire on emptyScope:true — the flag is the sole nothing-to-review discriminator and must agree with findings[]"
assert by_key["emptyScope"][True].get("properties", {}).get("findings", {}).get("maxItems") == 0, \
    "emptyScope:true must force findings[] empty — the flag and a populated array are contradictory claims about the same run"
assert False not in by_key["emptyScope"], (
    "there must be NO emptyScope:false clause — a normal run legitimately returns findings, and the "
    "converse would forbid every non-empty review"
)

assert REQ == {"findings", "recommendedEscalation", "degraded"}, \
    f"the success channel's required[] must stay exactly [findings, recommendedEscalation, degraded], got {sorted(REQ)}"
print("PASS: schema integer-type parity + 9-value dimension enum + convergence fields + emptyScope + adherence item shape + degradedReasons + votes.abstained/voteResolution")
PY

# === ERROR-CODE PARITY: the schema's mirrored enum against engine-api.md § Errors' registry table ===
# The mirror buys machine-checkability and costs a second copy, so the copy is pinned back to its
# source — the exact trade degradedReasons' 7-code enum already makes, and the reason that one is safe.
# Both directions: a code declared in § Errors and missing from the schema means a legitimate raise
# fails validation; a code in the schema and missing from § Errors means the registry is not closed
# where it says it is. Neither list is written in this belt.
API="$ROOT/lens/skills/engine/references/engine-api.md"
[ -s "$API" ] || fail "missing $API"
python3 - "$SCHEMA" "$API" <<'PY' || fail "the schema's errorEnvelope code enum is out of parity with engine-api.md § Errors"
import json, re, sys

schema = json.load(open(sys.argv[1], encoding="utf-8"))
api = open(sys.argv[2], encoding="utf-8").read()

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
    return "\n".join(body)

errors = section("## Errors")
assert errors, "engine-api.md § Errors is missing — the parity check has no source"

# The registry TABLE's first cell, not any mention: § Errors names codes in prose too, and a prose
# mention is a reference rather than a registration.
declared = set()
for line in errors.splitlines():
    if not line.startswith("|"):
        continue
    first = line.strip().strip("|").split("|")[0].strip().strip("`")
    if re.fullmatch(r"E_[A-Z_]+", first):
        declared.add(first)
assert declared, "no registry rows were derived from § Errors — the extractor is broken"

mirrored = set(schema["definitions"]["errorEnvelope"]["properties"]["code"]["enum"])
assert mirrored == declared, (
    "review-findings.schema.json's errorEnvelope.code enum must mirror § Errors' registry EXACTLY; "
    f"schema-only={sorted(mirrored - declared)} registry-only={sorted(declared - mirrored)}"
)
PY

# NON-VACUITY for the mirror: the enum is RUN against an invented code, and against every registered
# one, so "the enum exists" is not mistaken for "the enum bites".
python3 - "$SCHEMA" <<'PY' || fail "the schema does not actually enforce the closed error-code registry"
import json, sys

schema = json.load(open(sys.argv[1], encoding="utf-8"))
try:
    import jsonschema
    from jsonschema.exceptions import ValidationError
except ImportError:
    print("SKIP: jsonschema not installed — error-code enforcement probe not run (pip install jsonschema)")
    sys.exit(0)

def envelope(code):
    return {"error": {"code": code, "message": "one line", "extra": {}}}

try:
    jsonschema.validate(envelope("E_MADE_UP"), schema)
except ValidationError:
    pass
else:
    raise AssertionError("the schema ACCEPTS an invented error code — the closed registry guards nothing")

for code in schema["definitions"]["errorEnvelope"]["properties"]["code"]["enum"]:
    try:
        jsonschema.validate(envelope(code), schema)
    except ValidationError as e:
        raise AssertionError(f"the schema REJECTS the registered code {code}: {e.message}") from None

print("PASS: error-code registry enforcement — an invented code fails and every registered one validates")
PY

# NON-VACUITY: the degradedReasons rules are RUN, not just read. Everything above describes the
# schema's shape, and a shape pin cannot tell the difference between a rule that bites and one that
# has been written around — so each rule is exercised against a document it must reject, and against
# the legitimate returns it must keep accepting. Without the accept half, "reject everything" would
# pass this block. jsonschema is the one validator dependency CI installs; absent locally, this
# sub-check reports itself skipped rather than passing silently (tests/lens/test_verify_votes.sh).
python3 - "$SCHEMA" <<'PY' || fail "the schema does not actually enforce the degradedReasons contract"
import json, sys

schema = json.load(open(sys.argv[1], encoding="utf-8"))

try:
    import jsonschema
    from jsonschema.exceptions import ValidationError
except ImportError:
    print("SKIP: jsonschema not installed — degradedReasons enforcement probe not run (pip install jsonschema)")
    sys.exit(0)

def doc(**over):
    """A minimal conforming success return, overridden per case."""
    d = {"findings": [], "recommendedEscalation": "minor", "degraded": False}
    d.update(over)
    return d

def rejects(why, d):
    try:
        jsonschema.validate(d, schema)
    except ValidationError:
        return
    raise AssertionError(f"the schema ACCEPTS {why} — {json.dumps(d)}")

def accepts(why, d):
    try:
        jsonschema.validate(d, schema)
    except ValidationError as e:
        raise AssertionError(f"the schema REJECTS {why} — {json.dumps(d)}: {e.message}") from None

# A cause object must name a cause.
rejects("a degrade reason carrying nothing at all", doc(degraded=True, degradedReasons=[{}]))
rejects("a degrade reason carrying only a detail", doc(degraded=True, degradedReasons=[{"detail": "finder timed out"}]))
rejects("a degrade reason whose code key is misspelled", doc(degraded=True, degradedReasons=[{"cod": "finder-died"}]))
# ...and nothing else. A sealed object is what makes the closed code enum load-bearing: unsealed, an
# unrecognized cause simply rides in beside a recognized one.
rejects("an undeclared key riding alongside a valid code",
        doc(degraded=True, degradedReasons=[{"code": "finder-died", "severity": "high"}]))
rejects("a code outside the closed seven-cause set", doc(degraded=True, degradedReasons=[{"code": "finder-slow"}]))
# The biconditional, exercised from both sides.
rejects("degraded:true naming no causes at all", doc(degraded=True))
rejects("degraded:true with an empty degradedReasons", doc(degraded=True, degradedReasons=[]))
rejects("degraded:false while naming a cause", doc(degraded=False, degradedReasons=[{"code": "intent-soft"}]))

accepts("a clean run omitting degradedReasons", doc(degraded=False))
accepts("a clean run carrying an empty degradedReasons", doc(degraded=False, degradedReasons=[]))
accepts("a degraded run naming one cause", doc(degraded=True, degradedReasons=[{"code": "finder-died"}]))
accepts("a degraded run naming a cause with its detail",
        doc(degraded=True, degradedReasons=[{"code": "diff-truncated", "detail": "the diff exceeded the cap"}]))

# --- emptyScope's implication, exercised the same way ---
FINDING = {"id": "F1", "title": "a finding", "severity": "low", "dimension": "correctness",
           "verified": True}
rejects("emptyScope:true beside a populated findings[]",
        doc(emptyScope=True, findings=[FINDING]))
accepts("emptyScope:true with an empty findings[] — the nothing-to-review return",
        doc(emptyScope=True))
accepts("a clean review that found nothing, with emptyScope explicitly false",
        doc(emptyScope=False))
accepts("an ordinary review carrying findings and no emptyScope", doc(findings=[FINDING]))
accepts("an ordinary review carrying findings with emptyScope:false",
        doc(findings=[FINDING], emptyScope=False))

# --- the votes bounds, exercised on each member ---
def with_votes(**v):
    f = dict(FINDING)
    f["votes"] = v
    return doc(findings=[f])

rejects("a negative couldNotRefute", with_votes(total=1, couldNotRefute=-1, refuted=1, abstained=1))
rejects("a negative refuted", with_votes(total=1, couldNotRefute=1, refuted=-1, abstained=1))
rejects("a negative abstained", with_votes(total=1, couldNotRefute=0, refuted=0, abstained=-1))
rejects("a votes.total of 0 — no panel was dispatched", with_votes(total=0, couldNotRefute=0, refuted=0, abstained=0))
rejects("a votes.total above verifyVotes' own ceiling", with_votes(total=6, couldNotRefute=6, refuted=0, abstained=0))
accepts("the n=1 tally", with_votes(total=1, couldNotRefute=1, refuted=0, abstained=0))
accepts("a full five-vote panel", with_votes(total=5, couldNotRefute=3, refuted=1, abstained=1))
accepts("a finding carrying no votes at all — the field stays optional",
        doc(findings=[FINDING]))

print("PASS: degradedReasons enforcement — the cause object is sealed around `code` and the degraded biconditional bites in both directions")
print("PASS: emptyScope implies an empty findings[], and the votes counts are bounded")
PY
