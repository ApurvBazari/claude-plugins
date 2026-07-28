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
grep -qi 'framing, not filtering' "$CLAUDEMD" || fail "CLAUDE.md must keep the 'framing, not filtering' clause"
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
printf '%s\n' "$RENDER" | grep -qF 'skipped: nothing to review' \
  || fail "render-review section must declare the literal 'skipped: nothing to review' return"

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

echo "PASS: lens engine-api belt (ref guards, fencing preservation, JSON example integrity, canon)"
