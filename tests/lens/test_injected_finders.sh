#!/usr/bin/env bash
# shellcheck disable=SC2016 # every single-quoted literal here is a grepped markdown code span, not shell expansion
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
REG="$ROOT/lens/skills/engine/references/finder-registry.md"
API="$ROOT/lens/skills/engine/references/engine-api.md"
ADAPTER="$ROOT/lens/skills/engine/references/adapter-dispatch.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ESKILL" "$REG" "$API" "$ADAPTER"; do [ -s "$f" ] || fail "missing $f"; done

# House idiom (tests/lens/test_engine_api.sh): every extracted region is asserted non-empty AND
# bounded. An extractor whose terminator stops matching does not go empty — it swallows the rest of
# the file, so every pin scoped to it silently becomes a whole-file grep. A ceiling catches that.
bounded(){ # bounded <region-name> <max-lines> <region-text>
  [ -n "$3" ] || fail "$1 is empty"
  local n
  n="$(printf '%s\n' "$3" | wc -l | tr -d '[:space:]')"
  [ "$n" -le "$2" ] || fail "$1 grew to $n lines (ceiling $2) — its extractor lost its terminator"
}

# A wrapped markdown sentence is one claim across several physical lines; flattening is what lets a
# pin quote the claim verbatim instead of guessing where the author's wrap landed.
# flatten(), one_line() and section() are shared by every belt that sources them; they live in
# tests/lib so a fix to any of them reaches every belt at once, instead of the inconsistent per-belt
# copies they replace — section() in particular had drifted into two arities across those copies.
# shellcheck source=tests/lib/belt-helpers.sh
. "$ROOT/tests/lib/belt-helpers.sh"

# === ANALYZE: injectedFinders is a call-time finder source (pipeline §3) ===
grep -q 'injectedFinders' "$PIPE" || fail "ANALYZE: pipeline §3 must name the injectedFinders arg"
grep -qiE 'inject(ed)? .*finder.*(alongside|in addition to).*project tier|project tier.*inject' "$PIPE" \
  || fail "ANALYZE: injected finders dispatch alongside the project tier"
grep -qiE 'read-only.*(enforced|boundary)' "$PIPE" || fail "ANALYZE: injected finders are read-only-enforced at the boundary"
grep -qiE 'normaliz' "$PIPE" || fail "ANALYZE: injected finders are normalized into the finding shape"
grep -qiE 'verif(ier|ied)|refute' "$PIPE" || fail "ANALYZE: injected finders go through the verifier"
grep -qiE 'plugin-qualified|qualified name|Agent-tool registry|agent.*registry' "$PIPE" \
  || fail "ANALYZE: the agent value may be a plugin-qualified name resolved via the Agent registry"

# === §8 cap counts injected finders ===
grep -qiE 'injectedFinders.*(cap|count|budget)|(cap|count|budget).*injectedFinders' "$PIPE" \
  || fail "CAP: §8 must state injected finders count toward the fan-out budget"

# === backward-compat: absent/empty == 1.2.0 ===
grep -qiE 'absent or empty|missing or empty|empty .*injectedFinders' "$PIPE" \
  || fail "BC: pipeline must state empty/absent injectedFinders changes nothing"
grep -qiE 'byte-identical|byte identical' "$PIPE" || fail "BC: pipeline must promise byte-identical 1.2.0 behavior when absent"
grep -qiE 'JSON string|parse it defensively|parse defensively' "$PIPE" \
  || fail "BC: pipeline must say to parse a JSON-string injectedFinders defensively"

# === engine SKILL Step 3 names the injected dispatch ===
grep -q 'injectedFinders' "$ESKILL" || fail "SKILL: engine Step 3 must name injectedFinders"
grep -qiE 'inject.*(dispatch|finder)|dispatch.*inject' "$ESKILL" || fail "SKILL: Step 3 must say it dispatches injected finders"

# === finder-registry documents the injected tier ===
grep -qiE 'inject(ed)? (tier|finder)' "$REG" || fail "REG: finder-registry must document the injected tier"
grep -qiE 'call[- ]time|programmatic caller' "$REG" || fail "REG: injected tier is the call-time source (vs settings.md file)"

# === verifier teaches a simplify default (co-requisite for injected principle findings) ===
VERIFIER="$ROOT/lens/agents/verifier.md"
[ -s "$VERIFIER" ] || fail "missing $VERIFIER"
grep -q 'simplify' "$VERIFIER" || fail "VERIFIER: must give the simplify dimension a default"
grep -qiE 'simplify.*judg(e|ment)|judg(e|ment).*simplify' "$VERIFIER" || fail "VERIFIER: simplify is a judgment dimension"
grep -qiE 'signal .*(real|present|at the (cited )?locus)|locus.*match' "$VERIFIER" \
  || fail "VERIFIER: keep simplify only if the cited violation signal is real at the locus"
grep -qiE 'warranted|justified' "$VERIFIER" || fail "VERIFIER: refute a simplify finding when the change is clearly warranted"

# === RECORD SHAPE: both Tier-3 forms carry the same optional model/effort, declared in the canon ===
# One pin per FORM, each scoped to that form's own inputs-table row and to its SHAPE cell rather than
# the whole row — the Notes cell names both keys in prose, so a row-wide grep would stay satisfied
# with the declaration itself missing. A partial rollout must name the form it left behind.
INPUTS="$(section '## lens:engine — inputs' "$API")"
bounded "engine-api.md § lens:engine — inputs" 50 "$INPUTS"
FLATINPUTS="$(flatten "$INPUTS")"

# `head -1` used to hide a multi-row match; the row selector is a table's first cell, so it must be
# unique — one_line() makes a duplicated row fail instead of silently pinning whichever came first.
inputs_row(){ # inputs_row <input-name>
  local matched
  matched="$(printf '%s\n' "$INPUTS" | grep -F "| \`$1\` |" || true)"
  one_line "$matched" "engine-api.md inputs-table \`$1\` row"
  printf '%s\n' "$matched"
}
shape_cell(){ printf '%s\n' "$1" | awk -F'|' '{print $3}'; }

INJROW="$(inputs_row injectedFinders)"
[ -n "$INJROW" ] || fail "engine-api.md's inputs table has no \`injectedFinders\` row"
FINROW="$(inputs_row finders)"
[ -n "$FINROW" ] || fail "engine-api.md's inputs table has no \`finders\` row"

for key in 'model?' 'effort?'; do
  shape_cell "$INJROW" | grep -qF "$key" \
    || fail "RECORD: the \`injectedFinders\` row's SHAPE cell must declare the optional $key key"
  shape_cell "$FINROW" | grep -qF "$key" \
    || fail "RECORD: the \`finders\` row's SHAPE cell must declare the optional $key key"
done

# EFFORT ENUM, exact set both directions. A subset check lets a value be deleted, a superset check
# lets one be invented — and the vocabulary is the whole contract a caller writes against.
python3 - "$FLATINPUTS" <<'PY' || fail "engine-api.md § lens:engine — inputs does not declare effort's exact value set"
import re, sys

flat = sys.argv[1]
m = re.search(r"`effort` is exactly ((?:`[a-z]+`(?: \| )?)+)", flat)
assert m, "the inputs section must declare the accepted effort values as '`effort` is exactly `a` | `b` | …'"
values = re.findall(r"`([a-z]+)`", m.group(1))
expected = {"low", "medium", "high", "xhigh", "max"}
assert len(values) == len(set(values)), f"an effort value is declared twice: {values}"
assert set(values) == expected, (
    "effort accepts EXACTLY five values; "
    f"undeclared={sorted(set(values) - expected)} missing={sorted(expected - set(values))}"
)
PY

# CHANNEL: effort is delivered as prompt text, not as a dispatch parameter and not as a model. The
# claim is what tells a reader why it needs no model-resolution position of its own.
printf '%s\n' "$FLATINPUTS" | grep -qF 'prompt-level directive prepended to the dispatched finder prompt' \
  || fail "CHANNEL: engine-api.md must declare effort a prompt-level directive prepended to the dispatched finder prompt"

# D1 — the raise/degrade asymmetry, THREE independent pins. The two halves live on the row of the
# form they govern, so losing either one fails naming that form; the third is the sentence that makes
# the split read as intent rather than as two rules that disagree.
printf '%s\n' "$FINROW" | grep -qF 'never raises' \
  || fail "D1: the \`finders\` row must state that a malformed model/effort on a file-registered record never raises"
printf '%s\n' "$FINROW" | grep -qF 'finder-malformed' \
  || fail "D1: the \`finders\` row must name the degradedReasons code finder-malformed as the file-registered degrade path"
printf '%s\n' "$INJROW" | grep -qF 'E_INVALID_INPUT' \
  || fail "D1: the \`injectedFinders\` row must state that a malformed call-time model/effort raises E_INVALID_INPUT"
# THE NO-RAISE TWIN. `injectedFinders` is the only PRE-EXISTING caller channel (1.3.0) that gained a
# hard-fail in 1.5.0, and only the raise direction was declared — so a 1.3.0 caller reading this row
# learns its records can now abort a run, and reads nothing saying its own records still cannot. Every
# other 1.5.0 input carries that positive twin on the same page (`verifyVotes`' "absent never raises";
# `modelPolicy`'s "null and an absent key are not a wrong type"), and I-2 is what makes it true here:
# a record carrying neither 1.5.0 key has no 1.5.0 key to be malformed.
printf '%s\n' "$INJROW" | grep -qF 'A record carrying neither key never raises' \
  || fail "D1: the \`injectedFinders\` row must declare the no-raise direction too — a 1.3.0-shaped record has no 1.5.0 key to be malformed, and the raise half alone reads as if it might"
printf '%s\n' "$INJROW" | grep -qF 'I-2' \
  || fail "D1: the no-raise twin must cite I-2 — it is the invariant that makes the promise binding rather than a courtesy"
printf '%s\n' "$FLATINPUTS" | grep -qF 'deliberate decision, not an inconsistency' \
  || fail "D1: engine-api.md must declare the raise/degrade asymmetry a deliberate decision, not an inconsistency"

# TRUST BOUNDARY — the reason the file tier degrades: it is the only finder path a human running
# /lens:review standalone has, and that path passes none of the inputs that can raise.
printf '%s\n' "$FINROW" | grep -qF 'cannot fail on project config' \
  || fail "TRUST: the \`finders\` row must state that standalone /lens:review cannot fail on project config"
printf '%s\n' "$FINROW" | grep -qF '/lens:review' \
  || fail "TRUST: the file-registered rule must name standalone /lens:review as the path it protects"

# D3 — the knob is `effort`, with the repo's five-value vocabulary. The intent record called it
# `thinking` with three values; a half-revert to that name anywhere under lens/ is caught here.
#
# Scoped to the RECORD-KEY spelling, exactly the way D4 below is scoped to its two token spellings, and
# for the same reason: what D3 renamed is a key, not a word. The former `grep -rniE 'thinking'` banned
# the English word case-insensitively across every file under lens/ — including CHANGELOG.md and
# README.md — so the release could never disclose its own rename in the changelog AC25 requires, and
# the word could never be used in prose about reasoning depth even where it is the right word. The ban
# that matters is a key named `thinking` reappearing on a Tier-3 record, and that is what this matches.
THINKING="$(grep -rnE '`thinking`|"thinking"|\bthinking\??:' "$ROOT/lens" || true)"
[ -z "$THINKING" ] \
  || fail "D3: the Tier-3 record key is \`effort\`, never \`thinking\` — found a thinking-era key spelling: $THINKING"
# POSITIVE TWIN: the ban above is pure absence, so it is satisfied by a tree with no knob at all. The
# key it renamed TO must be declared on both record forms, which the record-shape pins above assert —
# restated here as the floor that keeps the negative from passing vacuously.
printf '%s\n' "$FLATINPUTS" | grep -qF '`effort` is exactly `low` | `medium` | `high` |' \
  || fail "D3: the ban on the thinking-era key is vacuous unless \`effort\` itself is declared — engine-api.md must carry the five-value vocabulary"

# D4 — the advertised token names rename in step with D3. Pinned separately: the capability tokens
# are a different promise from the record key, and a partial rename would leave exactly these two.
D4="$(grep -rnE 'finderThinking|thinkingChannel' "$ROOT/lens" || true)"
[ -z "$D4" ] || fail "D4: the advertised tokens are finderEffort / effortChannel — found a thinking-era token: $D4"

# CHANNEL, adapter tier: an adapter is dispatched behind a forcing wrapper-prompt, so the directive
# rides that wrapper rather than getting a prompt of its own — and the wrapper's read-only contract
# is not what gets displaced to make room.
PART1="$(awk '/^## Part 1 —/{n=1;next} n && /^## /{exit} n{print}' "$ADAPTER")"
bounded "adapter-dispatch.md Part 1 (forcing wrapper-prompt)" 35 "$PART1"
FLATPART1="$(flatten "$PART1")"
printf '%s\n' "$FLATPART1" | grep -qF 'appended to the wrapper above' \
  || fail "CHANNEL: adapter-dispatch.md Part 1 must state that the effort directive is appended to the existing wrapper-prompt"
printf '%s\n' "$FLATPART1" | grep -qF 'effort' \
  || fail "CHANNEL: adapter-dispatch.md Part 1 must name the effort directive it carries"

# ORDERING IS THE GUARD. A record-carried directive that lands BEFORE the read-only, findings-only
# contract is prose a foreign agent reads first, and a foreign agent that reads a directive first can
# read the contract behind it as something the directive re-frames. Three independent pins: the
# placement, its negation, and the reason — the reason is what stops the placement being "re-ordered
# for readability" by someone who never learns why the order was load-bearing.
printf '%s\n' "$FLATPART1" | grep -qF 'after its read-only, findings-only contract' \
  || fail "ORDERING: adapter-dispatch.md Part 1 must place the effort directive AFTER the read-only, findings-only contract"
printf '%s\n' "$FLATPART1" | grep -qF 'never ahead of it' \
  || fail "ORDERING: adapter-dispatch.md Part 1 must state the directive is never placed ahead of the read-only contract"
printf '%s\n' "$FLATPART1" | grep -qF 'Ordering is the guard' \
  || fail "ORDERING: adapter-dispatch.md Part 1 must say WHY the order is load-bearing, not just what it is"
# The injection surface itself: the record's own bytes never become prompt text. The directive is
# engine-composed from the one validated token, so registry prose has no path into this wrapper.
printf '%s\n' "$FLATPART1" | grep -F 'composed by' | grep -qF 'validated token' \
  || fail "INJECTION: adapter-dispatch.md Part 1 must state the directive is engine-composed from the validated token, not copied from the record"
printf '%s\n' "$FLATPART1" | grep -qF 'read-only, findings-only contract stands unchanged' \
  || fail "CHANNEL: adapter-dispatch.md Part 1 must state that read-only enforcement is unaffected by the directive"
# RETENTION — the two sentences that make the wrapper a contract rather than a suggestion, verbatim.
printf '%s\n' "$FLATPART1" | grep -qF 'You are running as a **read-only, findings-only** lens adapter.' \
  || fail "CHANNEL: adapter-dispatch.md Part 1 must keep its read-only, findings-only contract sentence verbatim"
printf '%s\n' "$FLATPART1" | grep -qF 'the wrapper raises the hit rate; it does not replace validation' \
  || fail "CHANNEL: adapter-dispatch.md Part 1 must keep the validation-backstop paragraph verbatim"

# The channel has a governing procedure, not just a declaration: §3 is where a finder prompt is
# composed, so it is where the directive is prepended and where a malformed file-registered record
# degrades. Region-scoped — §8 and §2 carry their own degrade wording, which would mask a loss here.
SEC3="$(awk '/^## 3\./{n=1;next} n && /^## /{exit} n{print}' "$PIPE")"
bounded "pipeline.md §3 (parallel dispatch)" 90 "$SEC3"
FLATSEC3="$(flatten "$SEC3")"
printf '%s\n' "$FLATSEC3" | grep -qF 'prepend it to that finder' \
  || fail "CHANNEL: pipeline.md §3 must prepend a record's effort to that finder's dispatch prompt"
printf '%s\n' "$FLATSEC3" | grep -qF 'finder-malformed' \
  || fail "D1: pipeline.md §3 must name the degradedReasons code finder-malformed for a malformed file-registered record"

# TRUST CLASS OF THE REGISTRY. `.claude/lens/settings.md` is a git-tracked, contributor-writable file
# (review/references/setup.md steers projects to track it), and §3 is the one place its records turn
# into prompt text. It is the same trust class as an intent doc, so it gets the same fence and the
# same subordination to the read-only rules — otherwise lens fences every file-sourced prose but one.
printf '%s\n' "$FLATSEC3" | grep -qF 'composes from the validated token' \
  || fail "INJECTION: pipeline.md §3 must state that the effort directive is engine-composed from the validated token"
printf '%s\n' "$FLATSEC3" | grep -qF 'bytes are not copied into a prompt' \
  || fail "INJECTION: pipeline.md §3 must state that a Tier-3 record's own bytes never become prompt text"
printf '%s\n' "$FLATSEC3" | grep -qF 'behind** any read-only/findings-only contract' \
  || fail "ORDERING: pipeline.md §3 must place the effort directive behind the prompt's read-only/findings-only contract"
printf '%s\n' "$FLATSEC3" | grep -qF 'never ahead of it' \
  || fail "ORDERING: pipeline.md §3 must state the directive is never placed ahead of the read-only contract"
# The fence itself, keyed to the record sentence rather than a bare §3 grep: §3 already names the
# fence for the intent doc, so an unkeyed grep would pass with the registry left entirely unfenced.
FENCESENT="$(printf '%s\n' "$FLATSEC3" | grep -oE 'any record-sourced text[^.]*\.' || true)"
[ -n "$FENCESENT" ] \
  || fail "INJECTION: pipeline.md §3 must state what happens to record-sourced text that does reach a dispatch prompt"
printf '%s\n' "$FENCESENT" | grep -qF '<untrusted-user-input>' \
  || fail "INJECTION: record-sourced text reaching a prompt must be wrapped in the <untrusted-user-input> fence"
printf '%s\n' "$FLATSEC3" | grep -qF 'settings.md` is contributor-writable' \
  || fail "INJECTION: pipeline.md §3 must name settings.md contributor-writable — the fact that puts it in the fenced trust class"

# === version consistency (derived via assert-versions.sh) ===
CHANGELOG="$ROOT/lens/CHANGELOG.md"
bash "$ROOT/tests/lib/assert-versions.sh" lens || fail "lens version consistency (plugin.json = marketplace = CHANGELOG)"
grep -q '## 1.3.0' "$CHANGELOG" || fail "lens CHANGELOG must have a 1.3.0 entry"
awk '/^## 1\.3\.0/{f=1;next} /^## /{f=0} f && tolower($0) ~ /injectedfinders/{hit=1} END{exit !hit}' "$CHANGELOG" \
  || fail "lens CHANGELOG 1.3.0 entry must mention injectedFinders"

echo "PASS: lens injectedFinders contract"
