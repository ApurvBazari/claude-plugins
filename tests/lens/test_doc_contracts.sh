#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ASM="$ROOT/lens/skills/review/references/review-model-assembly.md"
REC="$ROOT/lens/skills/review/references/reconcile.md"
SKILL="$ROOT/lens/skills/review/SKILL.md"
CLAUDEMD="$ROOT/lens/CONVENTIONS.md"
FC="$ROOT/lens/skills/engine/references/finder-contract.md"
READMEMD="$ROOT/lens/README.md"
CHANGELOGMD="$ROOT/lens/CHANGELOG.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ASM" "$REC" "$SKILL" "$CLAUDEMD" "$FC" "$READMEMD" "$CHANGELOGMD"; do [ -s "$f" ] || fail "missing $f"; done

# House idiom (tests/lens/test_injected_finders.sh, tests/lens/test_model_policy.sh): a wrapped markdown
# sentence is one claim across several physical lines, and flattening is what lets a pin judge the claim
# instead of the author's wrap. Used here only by the retirement NEGATIVE below — a positive pin
# flattened whole-file would stop being able to tell which line made its claim.
# flatten() and one_line() are shared by every belt that sources them; they live in tests/lib so a
# fix to either reaches every belt at once, instead of the inconsistent per-belt copies they replace.
# shellcheck source=tests/lib/belt-helpers.sh
. "$ROOT/tests/lib/belt-helpers.sh"

# C1 — ids are within-run stable; cross-run identity is the reconcile fingerprint, never the id.
grep -qiE 'within[- ]run' "$PIPE" || fail "C1: pipeline must call ids within-run stable"
grep -qi 'globally-stable' "$PIPE" && fail "C1: 'globally-stable' must be gone from pipeline"
grep -qi 'globally-stable' "$ASM"  && fail "C1: 'globally-stable' must be gone from review-model-assembly"
grep -qi 'globally-stable' "$FC"   && fail "C1: 'globally-stable' must be gone from finder-contract"

# C3 — no dangling cross-plugin reference to walkthrough's authoring-guide.md.
grep -qi 'authoring-guide' "$ASM" && fail "C3: dangling authoring-guide ref must be gone from review-model-assembly"

# W1 — severity trend is computed from the 4-value recommendedEscalation, not the 3-value verdict.
grep -qi 'collapses' "$REC" || fail "W1: trend section must explain verdict collapses major+critical (key on escalation)"

# D3 — state write-back is deferred until the render succeeds (no stale 'fixed' after a failed render).
grep -qi 'after a successful render' "$SKILL" || fail "D3: SKILL must write state only after a successful render"
grep -qi 'only after the render succeeds' "$REC" || fail "D3: reconcile write-back must be deferred to post-render"

# D4 — v1.1 acknowledged/won't-fix is fenced as not yet wired (no input path in v1).
grep -qiE 'not yet wired|no input path' "$REC" || fail "D4: v1.1 won't-fix must be fenced as not yet wired"

# W2 — the finding-status (confirmed vs flagged) is disambiguated from the verifier's status.
grep -qi 'distinct from the verifier' "$ASM" || fail "W2: status clarifier missing in review-model-assembly"

# W3 — CLAUDE.md's skill inventory names every skill that actually exists (derived, not a count literal).
for d in "$ROOT"/lens/skills/*/; do
  s="$(basename "$d")"
  grep -q "$s" "$CLAUDEMD" || fail "W3: lens CLAUDE.md must mention skill '$s'"
done

# W1/D3 consistency — the renamed 'severity trend' / deferred write-back must not leave stale 'verdict trend' wording in the operative docs.
grep -qi 'verdict trend' "$REC" && fail "reconcile must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$SKILL" && fail "SKILL must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$CLAUDEMD" && fail "CLAUDE.md must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$READMEMD" && fail "README must say 'severity trend', not 'verdict trend'"
grep -qi 'verdict trend' "$CHANGELOGMD" && fail "CHANGELOG must say 'severity trend', not 'verdict trend'"

# C2/I1 — the possibly-resolved enum mapping must state the ' — verify' suffix is markdown-only (dropped for the bare enum value).
grep -qi 'suffix is markdown-only' "$ASM" || fail "review-model-assembly must explain possibly-resolved suffix is dropped for the enum"

# L1 — engine stage count is 4 and ASSEMBLE is not attributed to the engine as a render step.
grep -q '4 engine stages' "$CLAUDEMD" || fail "L1: CLAUDE.md must say '4 engine stages'"
grep -qi '5 engine stages' "$CLAUDEMD" && fail "L1: CLAUDE.md must not say '5 engine stages'"
grep -qi 'delegates the 5-stage engine' "$CLAUDEMD" && fail "L1: CLAUDE.md skills list must not say '5-stage engine'"
# the render (review-model + walkthrough:render) must be named as the review skill's stage, not an engine stage.
grep -qi "review.* skill.s render stage" "$CLAUDEMD" || fail "L1: CLAUDE.md must attribute review-model/walkthrough:render to the review skill's render stage"
# pipeline.md must agree on the 4-stage framing.
grep -q 'four stages' "$PIPE" || fail "L1: pipeline.md must say 'four stages'"
grep -qi 'five stages' "$PIPE" && fail "L1: pipeline.md must not say 'five stages'"

# L5 — the schema exists now: no stale '(built in a later task)'; and the vicario/matali roles are stated.
grep -qi 'built in a later task' "$CLAUDEMD" && fail "L5: CLAUDE.md must drop the stale '(built in a later task)' — the schema exists"
grep -qi 'schema-parity target' "$CLAUDEMD" || fail "L5: CLAUDE.md must state vicario = schema-parity target"
grep -qi 'live consumer' "$CLAUDEMD" || fail "L5: CLAUDE.md must state matali = the live consumer"

# L2 — the headless path consumes the engine's returned adherence block first; derive-from-gaps is the true fallback.
grep -qi "engine.*adherence" "$ASM" || fail "L2: review-model-assembly headless path must consume the engine's adherence block when present"
# pin the PRIMARY consume-first instruction independently of the fallback sentence (both prior greps also match the fallback line).
grep -qi "consume that block when present" "$ASM" || fail "L2: review-model-assembly must independently pin the primary 'consume the engine's adherence block when present' instruction"
grep -qiE "true fallback|only when.*adherence.*absent|only if.*adherence.*absent" "$ASM" || fail "L2: derive-from-requirements must be framed as the fallback used only when the engine's adherence block is absent"

# AC29a — the skill count-word is DERIVED from lens/skills/*/, not a bare literal: a 5th skill added
# later without a doc update fails here, rather than the count silently going stale. Mirrors the
# WORDS-table idiom at tests/lens/test_engine_api.sh:171.
API="$ROOT/lens/skills/engine/references/engine-api.md"
CAPSKILL="$ROOT/lens/skills/capability/SKILL.md"
python3 - "$ROOT/lens/skills" "$CLAUDEMD" <<'PY' || fail "AC29a: lens/CONVENTIONS.md's skill count-word is not the derived word for lens/skills/*/"
import os, sys

skills_dir, claudemd = sys.argv[1], sys.argv[2]
count = len([d for d in os.listdir(skills_dir) if os.path.isdir(os.path.join(skills_dir, d))])
WORDS = {4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten"}
word = WORDS.get(count)
assert word, f"lens/skills/*/ has {count} dirs — no number word is mapped for that count"
text = open(claudemd, encoding="utf-8").read()
assert f"{word} skills" in text, \
    f"lens/CONVENTIONS.md must claim '{word} skills' (derived from the {count} dirs under lens/skills/*/)"
PY

# AC26 — CLAUDE.md § Skills carries the capability row, matching the engine/render-review pattern.
SKILLSREGION="$(awk '/^## Skills/{n=1;next} n && /^## /{exit} n{print}' "$CLAUDEMD")"
[ -n "$SKILLSREGION" ] || fail "AC26: CLAUDE.md § Skills section is missing"
printf '%s\n' "$SKILLSREGION" | grep -qF 'skills/capability/SKILL.md' \
  || fail "AC26: CLAUDE.md § Skills must carry a capability row/bullet, matching the engine/render-review pattern"
printf '%s\n' "$SKILLSREGION" | grep -qF 'user-invocable: false' \
  || fail "AC26: CLAUDE.md's capability row must name it internal (user-invocable: false), like the engine/render-review rows"

# AC26 — error-posture section: degrade-by-default + the narrow pre-flight hard-fail channel, I-1/I-2
# named, POINTING at engine-api.md § Errors rather than restating the registry.
ERRPOSTURE="$(awk '/^## Error posture/{n=1;next} n && /^## /{exit} n{print}' "$CLAUDEMD")"
[ -n "$ERRPOSTURE" ] || fail "AC26: CLAUDE.md must carry an error-posture section"
printf '%s\n' "$ERRPOSTURE" | grep -qF 'degrade-by-default' \
  || fail "AC26: CLAUDE.md's error-posture section must name the degrade-by-default posture"
printf '%s\n' "$ERRPOSTURE" | grep -qF 'pre-flight hard-fail channel' \
  || fail "AC26: CLAUDE.md's error-posture section must name the narrow pre-flight hard-fail channel"
printf '%s\n' "$ERRPOSTURE" | grep -qF 'I-1' \
  || fail "AC26: CLAUDE.md's error-posture section must name I-1 by name"
printf '%s\n' "$ERRPOSTURE" | grep -qF 'I-2' \
  || fail "AC26: CLAUDE.md's error-posture section must name I-2 by name"
printf '%s\n' "$ERRPOSTURE" | grep -qF 'engine-api.md' \
  || fail "AC26: CLAUDE.md's error-posture section must point at engine-api.md rather than restate the registry"
printf '%s\n' "$ERRPOSTURE" | grep -qF '§ Errors' \
  || fail "AC26: CLAUDE.md's error-posture section must point at engine-api.md's § Errors specifically"
if printf '%s\n' "$ERRPOSTURE" | grep -qE '(^|[^A-Za-z0-9_])E_[A-Z]'; then
  fail "AC26: CLAUDE.md's error-posture section must POINT at § Errors, not restate an E_ code — the registry lives once, in engine-api.md"
fi
if printf '%s\n' "$ERRPOSTURE" | grep -qF 'Raised by'; then
  fail "AC26: CLAUDE.md's error-posture section must not re-materialize the § Errors registry table"
fi

# AC26 — the named vote-resolution rule appears in CLAUDE.md.
grep -qF 'huginn-quorum-v1' "$CLAUDEMD" \
  || fail "AC26: CLAUDE.md must name the vote-resolution rule huginn-quorum-v1"

# CLAUDE.md points at the governing declaration for the vote tally instead of spelling the shape out.
# This is CLAUDE.md's OWN pin, independent of verifier.md's (which test_model_policy.sh owns): the same
# stale three-key restatement rotted in both files, so a partial revert must name the file that brought
# it back. The ban is judged against a backtick-stripped copy so a code-span spelling cannot slip past,
# and it covers ANY votes{...} enumeration — writing today's key list here would trade a false statement
# for a second source of truth, which is the thing CLAUDE.md's pointer-only role exists to prevent.
# The ban itself runs against a FLATTENED copy with tolerated whitespace at the wrap point: `grep` is
# line-scoped, so a restatement wrapped as `votes` / `{total,…}` across two physical lines is the same
# re-fork with the ban matching neither half. The line-scoped positive below deliberately keeps the
# UNflattened copy — flattening it would turn "the line naming the rule also names its home" into a
# whole-file grep, which is the weakening this pin exists to prevent.
CLAUDEMD_PLAIN="$(tr -d '`' < "$CLAUDEMD")"
if printf '%s\n' "$(flatten "$CLAUDEMD_PLAIN")" | grep -qE 'votes *\{'; then
  fail "lens/CONVENTIONS.md must not restate the vote-tally shape (e.g. votes{total,couldNotRefute,refuted}) — pipeline.md §5 / engine-api.md govern it; CLAUDE.md points"
fi
# SECTION-SCOPED, one pin per site, each one_line-guarded. `huginn-quorum-v1` occurs on TWO lines of
# lens/CONVENTIONS.md — the VERIFY stage bullet in § The pipeline and the agents bullet in § Skills — and
# BOTH already carried the citation, so a whole-file selector ORed them: deleting the citation from the
# pipeline bullet (the exact line a previous fix cycle repaired) left the pin green off the other one.
# A guard that cannot detect the removal of the thing it repaired is not a guard.
for cmsection in 'The pipeline' 'Skills'; do
  QLINE="$(printf '%s\n' "$CLAUDEMD_PLAIN" | awk -v h="^## $cmsection" '$0 ~ h {n=1;next} n && /^## /{exit} n{print}' | grep -F 'huginn-quorum-v1' || true)"
  [ -n "$QLINE" ] \
    || fail "lens/CONVENTIONS.md § $cmsection must name huginn-quorum-v1 — it is the rule that section's own claim depends on"
  one_line "$QLINE" "lens/CONVENTIONS.md § $cmsection huginn-quorum-v1 citation"
  printf '%s\n' "$QLINE" | grep -qF 'skills/engine/references/pipeline.md' \
    || fail "lens/CONVENTIONS.md § $cmsection must point at skills/engine/references/pipeline.md where it names huginn-quorum-v1, rather than describing the tally"
done

# AC26 — README gains exactly ONE internal-skill blockquote for capability, matching the two existing ones.
CAP_BLOCKQUOTES="$(grep -cE '^> `capability` ' "$READMEMD" || true)"
[ "$CAP_BLOCKQUOTES" -eq 1 ] \
  || fail "AC26: lens/README.md must carry exactly one internal-skill blockquote for capability (found $CAP_BLOCKQUOTES)"
grep -qE '^> `capability` is also internal' "$READMEMD" \
  || fail "AC26: lens/README.md's capability blockquote must match the 'is also internal' phrasing of the engine/render-review lines"
CAPLINE="$(grep -F '`capability` is also internal' "$READMEMD" || true)"
one_line "$CAPLINE" "lens/README.md capability blockquote"
printf '%s\n' "$CAPLINE" | grep -qF 'you never invoke it directly' \
  || fail "AC26: lens/README.md's capability blockquote must keep the 'you never invoke it directly' clause"

# ALWAYS-DO DISAMBIGUATION — the two capability-locked sites each carry a clarifier separating the
# tool-permission sense from lens:capability tokens; one independent pin per site, so a partial
# rollout names the missing file. (engine-api.md's own 'capability-locked' mention is the canon
# declaring the two senses, not a site needing disambiguation, and is out of this unit's file list.)
FREG="$ROOT/lens/skills/engine/references/finder-registry.md"
ADAPTDISPATCH="$ROOT/lens/skills/engine/references/adapter-dispatch.md"
for f in "$FREG" "$ADAPTDISPATCH"; do [ -s "$f" ] || fail "missing $f"; done

FREG_CAPLINE="$(grep -F 'capability-locked' "$FREG" || true)"
[ -n "$FREG_CAPLINE" ] || fail "finder-registry.md must still carry its 'capability-locked' site"
printf '%s\n' "$FREG_CAPLINE" | grep -qi 'tool-permission' \
  || fail "finder-registry.md's capability-locked site must clarify the tool-permission sense"
printf '%s\n' "$FREG_CAPLINE" | grep -qF 'lens:capability' \
  || fail "finder-registry.md's capability-locked site must name lens:capability to disambiguate from it"

ADAPT_CAPLINE="$(grep -F 'capability-locked' "$ADAPTDISPATCH" || true)"
[ -n "$ADAPT_CAPLINE" ] || fail "adapter-dispatch.md must still carry its 'capability-locked' site"
printf '%s\n' "$ADAPT_CAPLINE" | grep -qi 'tool-permission' \
  || fail "adapter-dispatch.md's capability-locked site must clarify the tool-permission sense"
printf '%s\n' "$ADAPT_CAPLINE" | grep -qF 'lens:capability' \
  || fail "adapter-dispatch.md's capability-locked site must name lens:capability to disambiguate from it"

# R2 CROSS-CHECK (the drift guard) — a token→governing-anchor map covering ALL 11 capabilities[]
# tokens, BOTH directions: every advertised token must resolve to a governing anchor in engine-api.md,
# and every mapped token must actually be advertised. The left-hand side is read from
# capability/SKILL.md itself (U8's declared set), never hand-copied here.
python3 - "$CAPSKILL" "$API" <<'PY' || fail "R2: a capabilities[] token has no governing anchor in engine-api.md, or a mapped token is not actually advertised"
import json, re, sys

skill_path, api_path = sys.argv[1], sys.argv[2]
skill = open(skill_path, encoding="utf-8").read()
api = open(api_path, encoding="utf-8").read()

blocks = re.findall(r"```json\n(.*?)\n```", skill, re.S)
reports = [json.loads(b) for b in blocks if b.strip()]
reports = [r for r in reports if isinstance(r, dict) and "capabilities" in r]
assert len(reports) == 1, "capability/SKILL.md must declare exactly one capability report"
advertised = set(reports[0]["capabilities"])

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

INPUTS = section("## lens:engine — inputs")
RETURNS = section("## lens:engine — returns")
ERRORS = section("## Errors")
RENDER = section("## lens:render-review — inputs and returns")
assert INPUTS and RETURNS and ERRORS and RENDER, "one of the R2 anchor sections is missing from engine-api.md"

# token -> (anchor section text, evidence literal that must appear inside it)
ANCHORS = {
    "modelPolicy":     (INPUTS,  "modelPolicy"),
    "verifyVotes":     (INPUTS,  "verifyVotes"),
    "injectedIntent":  (INPUTS,  "injectedIntent"),
    "injectedFinders": (INPUTS,  "injectedFinders"),
    "finderModel":     (INPUTS,  "model?"),
    "finderEffort":    (INPUTS,  "effort?"),
    "degradedReasons": (RETURNS, "degradedReasons"),
    "adherenceReturn": (RETURNS, "`adherence`"),
    "emptyScope":      (RETURNS, "emptyScope"),
    "namedErrors":     (ERRORS,  "E_"),
    "renderReview":    (RENDER,  "outputPath"),
}

missing_anchor = []
for tok in advertised:
    entry = ANCHORS.get(tok)
    if entry is None:
        missing_anchor.append(tok)
        continue
    body, evidence = entry
    if evidence not in body:
        missing_anchor.append(tok)
assert not missing_anchor, \
    f"capabilities[] token(s) with no governing anchor found in engine-api.md: {sorted(missing_anchor)}"

unadvertised_mapped = sorted(set(ANCHORS) - advertised)
assert not unadvertised_mapped, \
    f"token(s) mapped to a governing anchor but not present in capabilities[]: {unadvertised_mapped}"

assert set(ANCHORS) == advertised, \
    "the R2 cross-check map must cover EXACTLY the advertised capabilities[] set, both directions"
PY

# AC25 — the 1.5.0 CHANGELOG entry names each in-scope change and states its backward-compat
# position AGAINST 1.4.3, using the SAME section-scoped awk idiom as the existing 1.3.0 pin
# (tests/lens/test_injected_finders.sh).
ENTRY_150="$(awk '/^## 1\.5\.0/{f=1;next} /^## /{f=0} f{print}' "$CHANGELOGMD")"
[ -n "$ENTRY_150" ] || fail "AC25: lens CHANGELOG must have a 1.5.0 entry"

for tok in 'lens:capability' 'modelPolicy' 'verifyVotes' 'degradedReasons'; do
  printf '%s\n' "$ENTRY_150" | grep -qF "$tok" \
    || fail "AC25: lens CHANGELOG 1.5.0 entry must name $tok"
done
printf '%s\n' "$ENTRY_150" | grep -qF '`model`' \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must name the Tier-3 record's model key"
printf '%s\n' "$ENTRY_150" | grep -qF '`effort`' \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must name the Tier-3 record's effort key"

# The two caller-visible contract additions that are not one of the five in-scope items get the same
# treatment, because a caller reads this file to learn what it can now receive: a raise it could not
# receive in 1.4.3 is exactly the class of change a CHANGELOG exists to disclose. Each is pinned on
# its own bullet — a partial rollout must name the one it dropped.
# Each selector must resolve to EXACTLY ONE line. A `grep -F` that matches two lines ORs them, so every
# pin scoped to the result passes as long as EITHER line carries the literal — and the aggregate belt
# note names some of the same subjects these bullets do, which is exactly how a disclosure bullet could
# be gutted while the note underneath kept the pins green. one_line() is the shared helper sourced at
# the top of this file; the local copy that used to sit here drifted from its twins.
# The DISCLOSURE bullet, not merely a line mentioning the subject: bullets are `- feat:`/`- fix:`, the
# coverage summary is `- note:`, and only the former is a disclosure to a caller.
FLOORBULLET="$(printf '%s\n' "$ENTRY_150" | grep -F 'never-Haiku floor' | grep -F -- '- feat:' || true)"
[ -n "$FLOORBULLET" ] \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must disclose the verifier's never-Haiku floor in a bullet of its own — it is a raise a caller with a modelPolicy can now receive"
one_line "$FLOORBULLET" "never-Haiku floor bullet"
printf '%s\n' "$FLOORBULLET" | grep -qF '1.4.3' \
  || fail "AC25: the never-Haiku floor bullet must state its backward-compat position against 1.4.3"
REQBULLET="$(printf '%s\n' "$ENTRY_150" | grep -F 'array of strings' | grep -F -- '- feat:' || true)"
[ -n "$REQBULLET" ] \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must disclose that lens:capability validates require's shape"
one_line "$REQBULLET" "require-validation bullet"
# Named WITHOUT the bare code: the tree-wide allow-list in test_engine_api.sh keeps every E_ literal
# inside the three files that declare or raise one, and a CHANGELOG does neither. It names the channel
# and points at the code's declared home instead — the same voice the rest of this entry already uses.
printf '%s\n' "$REQBULLET" | grep -qF 'named-error envelope' \
  || fail "AC25: the require-validation bullet must say a shape violation comes back as the named-error envelope"
printf '%s\n' "$REQBULLET" | grep -qF 'engine-api.md` § Errors' \
  || fail "AC25: the require-validation bullet must point at the code's one declared home rather than restate the code"
printf '%s\n' "$REQBULLET" | grep -qF '1.4.3' \
  || fail "AC25: the require-validation bullet must state its backward-compat position against 1.4.3"

# each change's backward-compat position is stated AGAINST 1.4.3, not 1.4.2.
BC143_COUNT="$(printf '%s\n' "$ENTRY_150" | grep -coF '1.4.3' || true)"
[ "$BC143_COUNT" -ge 5 ] \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must state each of the five items' backward-compat position against 1.4.3 (found $BC143_COUNT citations)"
printf '%s\n' "$ENTRY_150" | grep -qF '1.4.2' \
  && fail "AC25: lens CHANGELOG 1.5.0 entry must compare against 1.4.3, not 1.4.2"

# the n=1 reduction claim: absent verifyVotes => n=1 => all three branches reproduce 1.4.3
# through ONE universal path.
printf '%s\n' "$ENTRY_150" | grep -qF 'n=1' \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must carry the n=1 reduction claim"
printf '%s\n' "$ENTRY_150" | grep -qiE 'one universal (code )?path' \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must state the n=1 reduction runs through one universal path"
printf '%s\n' "$ENTRY_150" | grep -qiE 'all three' \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must name all three outcome branches in the n=1 reduction claim"

# the ONE honest non-identity: the return gains fields, so it is not byte-identical to 1.4.3.
printf '%s\n' "$ENTRY_150" | grep -qiE 'not byte-identical' \
  || fail "AC25: lens CHANGELOG 1.5.0 entry must state the return is NOT byte-identical to 1.4.3"

# === THE degradedReasons BULLET MUST CLASSIFY ITS OWN CHANGE CORRECTLY ===
# It called the biconditional "field-additive, the same class of change as 1.1.0's emptyScope and
# 1.4.0's adherence". That is false, and the belt used to REQUIRE the false version. Those two were
# optional additions that cannot invalidate a document already valid; this constraint invalidates EVERY
# 1.4.3-produced return carrying degraded:true, because degradedReasons did not exist to satisfy it.
# Executed under both schema versions to confirm before this pin was written. The bullet must now say
# so, name the affected caller shape, and give the recovery — and the two prior releases must be cited
# as the class this change is NOT, so the comparison a reader would otherwise draw is pre-empted rather
# than deleted. Scoped to the bullet, since the entry names all of these subjects elsewhere.
DRBULLET="$(printf '%s\n' "$ENTRY_150" | grep -F 'degradedReasons[]` (closed 7-code enum' || true)"
[ -n "$DRBULLET" ] || fail "AC25: lens CHANGELOG 1.5.0 entry must carry the degradedReasons feat bullet"
one_line "$DRBULLET" "CHANGELOG 1.5.0 degradedReasons bullet"
printf '%s\n' "$DRBULLET" | grep -qiF 'NARROWING' \
  || fail "AC25: the degradedReasons bullet must classify the biconditional as a NARROWING — 'field-additive' describes the field and hides the constraint, which is the class of change that breaks a consumer"
printf '%s\n' "$DRBULLET" | grep -qF 'no 1.4.3-produced return carrying `degraded: true` validates' \
  || fail "AC25: the degradedReasons bullet must state the concrete breakage — a 1.4.3/vicario document with degraded:true no longer validates"
printf '%s\n' "$DRBULLET" | grep -qiE 'backfill' \
  || fail "AC25: the degradedReasons bullet must give the backfill recovery for a consumer holding prior-run state"
printf '%s\n' "$DRBULLET" | grep -qiE 'skip validation' \
  || fail "AC25: the degradedReasons bullet must give the skip-validation recovery as the alternative to backfilling"
printf '%s\n' "$DRBULLET" | grep -qF 'prior-run' \
  || fail "AC25: the degradedReasons bullet must name WHICH consumer shape the break reaches — one validating prior-run state"
# The two prior releases stay cited, as the contrast rather than the comparison.
printf '%s\n' "$DRBULLET" | grep -qF '1.1.0' \
  || fail "AC25: the degradedReasons bullet must still cite 1.1.0's emptyScope — as the class this change is NOT"
printf '%s\n' "$DRBULLET" | grep -qF '1.4.0' \
  || fail "AC25: the degradedReasons bullet must still cite 1.4.0's adherence — as the class this change is NOT"
printf '%s\n' "$DRBULLET" | grep -qF 'not as the same class of change' \
  || fail "AC25: the degradedReasons bullet must say explicitly that this is NOT the same class as those two — citing them without the negation is the false classification restated"
if printf '%s\n' "$DRBULLET" | grep -qF 'field-additive, the same class of change as'; then
  fail "AC25: the degradedReasons bullet must not restore the false 'field-additive, the same class of change as 1.1.0's emptyScope' classification — those two could not invalidate a valid document; this one does"
fi

# === EVERY NARROWING IS DISCLOSED, AND THE SET IS COMPLETE ===
# One bullet owns the disclosure so a reader auditing compatibility has a single place to look, and its
# subject list is checked against the schema's real narrowings — adding a fourth without naming it fails
# here, which is what stops the next one shipping labelled additive. The derivation walks the schema for
# every constraint keyword reachable by a 1.4.3 document (tests/lib/schema-narrowings.py), not only the
# success branch's conditional clauses: a clause-only reading derived two of the three shipped
# narrowings and was blind to `votes`' bounds, which are plain `minimum`/`maximum` under `properties` —
# and `minimum`/`maximum`/`enum`/`required`/`additionalProperties` is most of what a schema narrows with.
NARROWNOTE="$(printf '%s\n' "$ENTRY_150" | grep -F 'what this release NARROWS' || true)"
[ -n "$NARROWNOTE" ] || fail "AC25: lens CHANGELOG 1.5.0 entry must carry a bullet disclosing what the release narrows"
one_line "$NARROWNOTE" "CHANGELOG 1.5.0 narrowings bullet"
for subject in 'degradedReasons' 'emptyScope' 'votes'; do
  printf '%s\n' "$NARROWNOTE" | grep -qF "$subject" \
    || fail "AC25: the narrowings bullet must name the '$subject' constraint — a partial disclosure is how the next one ships unlabelled"
done
printf '%s\n' "$NARROWNOTE" | grep -qiE 'backfill' \
  || fail "AC25: the narrowings bullet must give the recovery, not only the breakage"
printf '%s' "$NARROWNOTE" \
  | python3 "$ROOT/tests/lib/schema-narrowings.py" "$ROOT/lens/schemas/review-findings.schema.json" \
  || fail "AC25: the 1.5.0 entry's narrowings bullet does not name every narrowing the schema carries over 1.4.3"

# The non-identity claim is EXHAUSTIVE, not illustrative. Its subject list is checked against the
# schema's real delta over the frozen 1.4.3 key set, and scoped to the SENTENCE that makes the claim —
# a line-scoped grep would stay green on a claim narrowed back to one field while the other added
# fields ship undisclosed, since a bullet names them earlier in its own prose. Adding a field to the
# schema without naming it in that sentence fails here; removing one fails too, since the entry
# promises nothing was renamed, re-typed, or removed.
python3 - "$ROOT/lens/schemas/review-findings.schema.json" "$ENTRY_150" <<'PY' || fail "AC25: the 1.5.0 entry's non-identity claim does not match the schema's real field delta over 1.4.3"
import json, re, sys

schema, entry = json.load(open(sys.argv[1])), sys.argv[2]

# The 1.4.3 return contract, frozen — the shape the backward-compat promise is made against.
BASE_TOP = {"adherence", "degraded", "delta", "emptyScope", "findings", "recommendedEscalation",
            "severityTrend", "summary"}
BASE_FINDING = {"claim", "detail", "dimension", "file", "id", "label", "line", "severity", "source",
                "suggestedFix", "tags", "title", "verified", "voteDegraded", "votes"}
BASE_VOTES = {"couldNotRefute", "refuted", "total"}

top = set(schema["properties"])
finding = set(schema["properties"]["findings"]["items"]["properties"])
votes = set(schema["properties"]["findings"]["items"]["properties"]["votes"]["properties"])

dropped = sorted((BASE_TOP - top) | (BASE_FINDING - finding) | {f"votes.{v}" for v in BASE_VOTES - votes})
assert not dropped, f"1.4.3 return field(s) removed from the schema — the entry promises none were: {dropped}"

added = sorted((top - BASE_TOP) | (finding - BASE_FINDING) | {f"votes.{v}" for v in votes - BASE_VOTES})
assert added, "the schema adds no field over 1.4.3, but the entry claims the return is not byte-identical"

flat = " ".join(entry.split())
claims = [s for s in re.split(r"(?<=[.!?])\s+", flat) if "not byte-identical" in s.lower()]
assert len(claims) == 1, \
    f"exactly one sentence may make the not-byte-identical claim (it is the exhaustive list), found {len(claims)}"

undisclosed = [f for f in added if f not in claims[0]]
assert not undisclosed, \
    f"field(s) the return gains over 1.4.3 but the non-identity claim does not name: {undisclosed}"
PY

# the three new belt filenames cited as the pins.
for belt in 'test_capability.sh' 'test_model_policy.sh' 'test_verify_votes.sh'; do
  printf '%s\n' "$ENTRY_150" | grep -qF "$belt" \
    || fail "AC25: lens CHANGELOG 1.5.0 entry must cite $belt as a pin"
done

# AC25 requires each change to cite THE BELT PINNING IT, and the aggregate note above is not that: a
# change disclosed in its own bullet with only a doc section beside it cites the place the rule is
# STATED, not the place that fails when the rule stops holding. Both bullets added late in the release
# cited a § of engine-api.md and no belt at all. Each is pinned on its own bullet, so a half-repair
# names the half it left.
printf '%s\n' "$FLOORBULLET" | grep -qE 'test_[a-z_]+\.sh' \
  || fail "AC25: the never-Haiku floor bullet must cite the BELT that pins the floor, not only the doc section that declares it"
printf '%s\n' "$FLOORBULLET" | grep -qF 'test_model_policy.sh' \
  || fail "AC25: the never-Haiku floor bullet must cite test_model_policy.sh — that is the belt whose pins fail when the floor stops holding"
printf '%s\n' "$REQBULLET" | grep -qE 'test_[a-z_]+\.sh' \
  || fail "AC25: the require-validation bullet must cite the BELT that pins the shape gate, not only the doc section that declares it"
printf '%s\n' "$REQBULLET" | grep -qF 'test_capability.sh' \
  || fail "AC25: the require-validation bullet must cite test_capability.sh — that is the belt whose pins fail when the shape gate stops holding"

# THE AGGREGATE NOTE MUST BE TRUE. It is the entry's one coverage summary, so a reader auditing what is
# pinned reads it and stops. It described test_model_policy.sh without the floor and test_capability.sh
# without require's shape gate — both of which those belts do pin — so the summary under-reported its
# own coverage while two bullets pointed nowhere. Each clause is checked against a subject the belt
# actually carries.
BELTNOTE="$(printf '%s\n' "$ENTRY_150" | grep -F 'new belts pin this release' || true)"
[ -n "$BELTNOTE" ] || fail "AC25: lens CHANGELOG 1.5.0 entry must carry the aggregate belt note"
printf '%s\n' "$BELTNOTE" | grep -qF 'never-Haiku floor' \
  || fail "AC25: the belt note must name the never-Haiku floor among what test_model_policy.sh pins — it does pin it, and the note is where coverage is read off"
printf '%s\n' "$BELTNOTE" | grep -qF 'type gate' \
  || fail "AC25: the belt note must name the modelPolicy type gate among what test_model_policy.sh pins"
printf '%s\n' "$BELTNOTE" | grep -qF '`require`' \
  || fail "AC25: the belt note must name require's shape gate among what test_capability.sh pins"
# THE BELT COUNT IS DERIVED, not written. tests/run-all.sh discovers via `git ls-files`, so the count a
# reader trusts goes stale the moment a belt is added or unstaged — and an unstaged new belt is
# invisible to the runner, which is exactly the failure this number exists to make visible.
BELT_COUNT="$(git -C "$ROOT" ls-files -- 'tests/*.sh' \
  | grep -E '/(test_[^/]+|test-[^/]+|[^/]+-smoke)\.sh$' \
  | grep -v '^tests/release-gate/' | grep -v '/lib\.sh$' \
  | grep -v '/run\.sh$' | grep -v '/run-all\.sh$' | grep -c . || true)"
[ "$BELT_COUNT" -gt 0 ] || fail "no belts were discovered — the count derivation is broken"
printf '%s\n' "$BELTNOTE" | grep -qF "**$BELT_COUNT** belts" \
  || fail "AC25: the belt note must state the derived suite size (**$BELT_COUNT** belts) — a hand-written count goes stale, and an unstaged belt the runner cannot see is what that number would otherwise hide"

# === THE 1.5.0 COMPAT NOTE MUST NOT OVERCLAIM ITS OWN ENTRY (P2-7's regression guard) ===
# The closing note opened "a call that passes none of them behaves exactly as 1.4.3 did" while an
# earlier bullet of the SAME entry says, in bold and belt-pinned, that such a caller still receives
# three new fields and it is "not byte-identical". A summary that generalizes over a bullet has to be
# re-derived when the bullet is strengthened, and it was not. The note must separate the two surfaces.
COMPATNOTE="$(printf '%s\n' "$ENTRY_150" | grep -F 'matali is not' || true)"
[ -n "$COMPATNOTE" ] || fail "AC25: lens CHANGELOG 1.5.0 entry must carry its closing compatibility note"
one_line "$COMPATNOTE" "CHANGELOG 1.5.0 closing compatibility note"
if printf '%s\n' "$COMPATNOTE" | grep -qF 'behaves exactly as 1.4.3 did'; then
  fail "AC25: the closing note must not claim a 1.4.3-shaped call behaves exactly as 1.4.3 did — the same entry states the return gains three fields and is not byte-identical"
fi
printf '%s\n' "$COMPATNOTE" | grep -qiE 'input surface|INPUT surface' \
  || fail "AC25: the closing note must say WHICH surface is compatible — the input surface, not the return"
# ...and the meta-clause goes with it. 1.5.0 has never shipped, so there is no previously-published
# text for a reader to reconcile: a CHANGELOG entry narrating its own drafting history is process
# traceability in a consumer-facing document.
if printf '%s\n' "$ENTRY_150" | grep -qiE 'this entry previously said|an earlier version of this entry'; then
  fail "AC25: the 1.5.0 entry must not narrate its own revision history — 1.5.0 has never shipped, so no reader has seen the earlier text"
fi

echo "PASS: lens doc contracts"
