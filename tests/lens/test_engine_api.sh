#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

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
CLAUDEMD="$ROOT/lens/CLAUDE.md"
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

H_PRECEDENCE='## Precedence — this doc declares, the skills govern'
H_OWNERSHIP='## Ownership map'
H_INPUTS='## lens:engine — inputs'
H_RETURNS='## lens:engine — returns'
H_DOWNSTREAM='## Downstream additions (NOT engine returns)'
H_RENDER='## lens:render-review — inputs and returns'
H_CONSUMERS='## Known consumer assumptions (not part of the contract)'
H_PROCEDURE='## Where the procedure lives'

for heading in "$H_PRECEDENCE" "$H_OWNERSHIP" "$H_INPUTS" "$H_RETURNS" "$H_DOWNSTREAM" \
               "$H_RENDER" "$H_CONSUMERS" "$H_PROCEDURE"; do
  grep -qF "$heading" "$API" || fail "engine-api.md must carry the heading '$heading'"
done

# Everything between a heading and the next H2 — so each pin judges only its own section.
section(){ awk -v h="$1" 'index($0,h)==1{inside=1;next} /^## /{if(inside)exit} inside{print}' "$API"; }

# Precedence: the declaration defers to the runtime, so a stale line here can never govern behavior.
grep -qiE 'procedure wins|declares.*govern|govern.*declare' "$API" \
  || fail "engine-api.md must state that the procedure wins when it disagrees with this doc"

# The engine returns exactly six fields.
RETURNS="$(section "$H_RETURNS")"
[ -n "$RETURNS" ] || fail "the '$H_RETURNS' section is empty"
for field in findings recommendedEscalation degraded summary emptyScope adherence; do
  printf '%s\n' "$RETURNS" | grep -qF "$field" || fail "engine returns section must declare '$field'"
done
if printf '%s\n' "$RETURNS" | grep -qF 'severityTrend'; then
  fail "engine returns section must NOT list severityTrend — reconcile sets it, never the engine"
fi
if printf '%s\n' "$RETURNS" | grep -qE '(^|[^-[:alnum:]])delta\b'; then
  fail "engine returns section must NOT list delta — reconcile sets it, never the engine"
fi
if printf '%s\n' "$RETURNS" | grep -qE '(^|[^-[:alnum:]])agents\b'; then
  fail "engine returns section must NOT declare an 'agents' roster — lens does not emit one"
fi

# delta / severityTrend are declared, but as downstream additions owned by reconcile.
DOWNSTREAM="$(section "$H_DOWNSTREAM")"
[ -n "$DOWNSTREAM" ] || fail "the '$H_DOWNSTREAM' section is empty"
for field in delta severityTrend reconcile; do
  printf '%s\n' "$DOWNSTREAM" | grep -qF "$field" || fail "downstream section must name '$field'"
done
printf '%s\n' "$DOWNSTREAM" | grep -qiE 'never .*engine|not an engine return' \
  || fail "downstream section must state that the engine never sets delta/severityTrend"

# Inputs: every arg named, injectedFinders marked canonical, the scope alias recorded not renamed.
INPUTS="$(section "$H_INPUTS")"
[ -n "$INPUTS" ] || fail "the '$H_INPUTS' section is empty"
for arg in target taskIds injectedIntent injectedFinders finders; do
  printf '%s\n' "$INPUTS" | grep -qF "$arg" || fail "engine inputs section must declare '$arg'"
done
printf '%s\n' "$INPUTS" | grep -F 'injectedFinders' | grep -qi 'canonical' \
  || fail "engine inputs section must name injectedFinders the canonical project-finder path"
printf '%s\n' "$INPUTS" | grep -i 'alias' | grep -qF 'scope' \
  || fail "engine inputs section must record 'scope' as the historical alias of 'target'"

# render-review's own surface, including the empty-scope short-circuit.
RENDER="$(section "$H_RENDER")"
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
CONSUMERS="$(section "$H_CONSUMERS")"
[ -n "$CONSUMERS" ] || fail "the '$H_CONSUMERS' section is empty"
printf '%s\n' "$CONSUMERS" | grep -qE '(^|[^-[:alnum:]])agents\b' \
  || fail "consumer-assumptions section must name the 'agents' roster a consumer reads"
printf '%s\n' "$CONSUMERS" | grep -qi 'matali' \
  || fail "consumer-assumptions section must name matali as the consumer making the assumption"
printf '%s\n' "$CONSUMERS" | grep -qiE 'not part of the contract|not contracted' \
  || fail "consumer-assumptions section must state that 'agents' is not part of the contract"

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
RULE0="$(awk '/^0\. \*\*injected intent/{inside=1} inside && /^1\. \*\*explicit args/{exit} inside{print}' "$PIPE")"
[ -n "$RULE0" ] || fail "pipeline.md §2 rule 0 (injected intent) is missing"
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

# The fan-out cap covers the injected path too, and names what it skipped. Scoped to §8: earlier
# sections carry their own "name the skipped", which would otherwise mask a loss here.
CAP="$(awk '/^## 8\./{inside=1} inside{print}' "$PIPE")"
[ -n "$CAP" ] || fail "pipeline.md §8 (huge-diff rule + fan-out cap) is missing"
printf '%s\n' "$CAP" | grep -qF 'source-agnostic' || fail "pipeline.md §8 must keep the source-agnostic cap"
printf '%s\n' "$CAP" | grep -qF 'name the skipped' \
  || fail "pipeline.md §8 must keep naming the skipped docs, never silently dropping one"

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
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
[ -s "$ESKILL" ] || fail "missing $ESKILL"

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

INTRO="$(awk '/^# Engine/{n=1;next} n && /^## Progress tracking/{exit} n{print}' "$ESKILL")"
[ -n "$INTRO" ] || fail "engine/SKILL.md intro block is empty"
printf '%s\n' "$INTRO" | grep -qF 'references/pipeline.md' || fail "intro must keep citing references/pipeline.md"
printf '%s\n' "$INTRO" | grep -qF 'references/finder-registry.md' || fail "intro must keep citing references/finder-registry.md"
printf '%s\n' "$INTRO" | grep -qF 'Write no files' || fail "intro must keep the write-no-files / ask-no-questions clause"

# taskIds no-op-when-absent wording + task-blind sentence (Progress tracking section).
PROGRESS="$(awk '/^## Progress tracking/{n=1;next} n && /^## Step 1/{exit} n{print}' "$ESKILL")"
[ -n "$PROGRESS" ] || fail "engine/SKILL.md Progress tracking section is empty"
printf '%s\n' "$PROGRESS" | grep -qiE 'absent.*orchestrator|task action.*byte-identical' \
  || fail "Progress tracking section must keep the taskIds-absent no-op wording"
printf '%s\n' "$PROGRESS" | grep -qi 'task-blind' \
  || fail "Progress tracking section must keep the task-blind sentence"

# The degraded:false,emptyScope:true return literal (Step 1), byte-identical.
STEP1="$(awk '/^## Step 1/{n=1;next} n && /^## Step 2/{exit} n{print}' "$ESKILL")"
[ -n "$STEP1" ] || fail "engine/SKILL.md Step 1 section is empty"
printf '%s\n' "$STEP1" | grep -qF '{findings:[],recommendedEscalation:"minor",degraded:false,emptyScope:true}' \
  || fail "Step 1 must keep the byte-identical empty-scope return literal"

# The injectedIntent wins/override sentence (Step 2).
STEP2="$(awk '/^## Step 2/{n=1;next} n && /^## Step 3/{exit} n{print}' "$ESKILL")"
[ -n "$STEP2" ] || fail "engine/SKILL.md Step 2 section is empty"
printf '%s\n' "$STEP2" | grep -qiE 'injectedIntent.*(wins|override)|(wins|override).*injectedIntent' \
  || fail "Step 2 must keep the injectedIntent wins/override sentence"

# The injectedFinders dispatch sentence + the <untrusted-user-input> reference (Step 3).
STEP3="$(awk '/^## Step 3/{n=1;next} n && /^## Step 4/{exit} n{print}' "$ESKILL")"
[ -n "$STEP3" ] || fail "engine/SKILL.md Step 3 section is empty"
printf '%s\n' "$STEP3" | grep -qiE 'inject.*(dispatch|finder)|dispatch.*inject' \
  || fail "Step 3 must keep the injectedFinders dispatch sentence"
printf '%s\n' "$STEP3" | grep -qF '<untrusted-user-input>' \
  || fail "Step 3 must keep the <untrusted-user-input> fence reference"

echo "PASS: lens engine SKILL belt (canon citation, no shape/return redeclaration, corrected caller claim, retention)"

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
rstep(){ awk -v a="$1" -v b="$2" '$0 ~ a {n=1} n && $0 ~ b {exit} n{print}' "$RSKILL"; }

STEP0="$(rstep '^## Step 0' '^## Step 1')"
[ -n "$STEP0" ] || fail "review/SKILL.md Step 0 (create the task list) is missing"
printf '%s\n' "$STEP0" | grep -qF 'TaskCreate' || fail "Step 0 must still create the task list via TaskCreate"
printf '%s\n' "$STEP0" | grep -qF 'references/task-tracking.md' \
  || fail "Step 0 must still cite references/task-tracking.md as the task-list contract"

RSTEP2="$(rstep '^## Step 2' '^## Step 3')"
[ -n "$RSTEP2" ] || fail "review/SKILL.md Step 2 (run the engine) is missing"
printf '%s\n' "$RSTEP2" | grep -qF 'taskIds = { scope, intent, analyze, verify }' \
  || fail "Step 2 must still hand the engine its four taskIds"
printf '%s\n' "$RSTEP2" | grep -qF 'emptyScope === true' \
  || fail "Step 2 must still key the empty branch on result.emptyScope === true"
printf '%s\n' "$RSTEP2" | grep -qF 'nothing to review' \
  || fail "Step 2 must still report 'nothing to review' on the empty-scope branch"

RSTEP3="$(rstep '^## Step 3' '^## Step 4')"
[ -n "$RSTEP3" ] || fail "review/SKILL.md Step 3 (reconcile) is missing"
printf '%s\n' "$RSTEP3" | grep -qF 'after a successful render' \
  || fail "Step 3 must still defer the state write-back until after a successful render"

# Exactly one Key Rule is retired; the other five govern the standalone flow.
KEYRULES="$(awk '/^## Key Rules/{n=1;next} n{print}' "$RSKILL")"
[ -n "$KEYRULES" ] || fail "review/SKILL.md Key Rules section is missing"
KR_COUNT="$(printf '%s\n' "$KEYRULES" | grep -c '^- ' || true)"
[ "$KR_COUNT" -eq 5 ] || fail "review/SKILL.md must keep exactly 5 Key Rules (found $KR_COUNT)"

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
grep -qF "$PHRASE" "$CLAUDEMD" || fail "REGISTRY: lens/CLAUDE.md's Project-custom registry row must carry the experimental/secondary label"
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

echo "PASS: lens CLAUDE.md index belt (schema enumeration demoted, CI-pinned substrings retained)"
