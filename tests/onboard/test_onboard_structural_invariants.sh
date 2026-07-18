#!/usr/bin/env bash
# test_onboard_structural_invariants.sh — onboard's structural invariants.
#
# Pins the durable regression contract for the structural/doc-only onboard diet:
# line ceilings on the two thinned orchestrators, the analysis-skill fold-in, the
# CHANGELOG-2.0 deletion, the context-shape schema single-sourcing, the empty-repo
# single-sourcing, the five caller-parsed inline safety strings, and a self-test of
# the extended numbering gate's good/bad fixtures. No behavior change is asserted
# here beyond what already-existing CI gates cover (ref integrity, notify-delegation,
# phase-tracking, doc-truth wording pins) — this belt covers the NEW structural
# invariants those gates are blind to.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 1
fail=0

ok(){ echo "ok: $1"; }
bad(){ echo "FAIL: $1"; fail=1; }

# --exclude=test_onboard_structural_invariants.sh: this belt's own comments/variable literals
# name the strings it is asserting the absence of (e.g. the pattern text itself); excluding
# self avoids the belt tripping over its own prose.
#
# grep's exit code is the source of truth, not the emptiness of its output: rc 1 (no match)
# means the assertion genuinely holds, but rc >= 2 (unreadable path, malformed ERE) means it
# was never evaluated. Collapsing both to an empty string would report ok for an assertion
# that scanned nothing — a renamed directory or a later-broken pattern would go unnoticed.
must_absent(){
  local desc="$1" pattern="$2"; shift 2
  local hits rc=0
  hits="$(grep -rnE --exclude='test_onboard_structural_invariants.sh' "$pattern" "$@" 2>&1)" || rc=$?
  case "$rc" in
    0) bad "$desc"; printf '%s\n' "$hits" ;;
    1) ok "$desc" ;;
    *) bad "$desc — grep errored (rc=$rc), so the assertion was never evaluated"; printf '%s\n' "$hits" ;;
  esac
}
must_present_nonempty(){ local desc="$1" f="$2"; if [ -s "$f" ]; then ok "$desc"; else bad "$desc (missing or empty: $f)"; fi; }

# ============================================================================
# 1. LINE CEILINGS — ratchet-down ceilings on the two thinned orchestrators.
#    Ceiling = achieved line count (verified 2026-07-16) + a small fixed
#    headroom, so an incidental doc touch-up doesn't require a ceiling bump
#    on every commit, but a future edit cannot regrow either file back
#    toward its pre-diet size (596 / 607 lines).
# ============================================================================
CEIL_GEN=340    # achieved 329 + 11 headroom
CEIL_START=420  # achieved 407 + 13 headroom

gen_lines="$(wc -l < onboard/skills/generate/SKILL.md | tr -d ' ')"
if [ "$gen_lines" -le "$CEIL_GEN" ]; then
  ok "generate/SKILL.md line count ($gen_lines) <= ceiling ($CEIL_GEN)"
else
  bad "generate/SKILL.md line count ($gen_lines) exceeds ceiling ($CEIL_GEN)"
fi

start_lines="$(wc -l < onboard/skills/start/SKILL.md | tr -d ' ')"
if [ "$start_lines" -le "$CEIL_START" ]; then
  ok "start/SKILL.md line count ($start_lines) <= ceiling ($CEIL_START)"
else
  bad "start/SKILL.md line count ($start_lines) exceeds ceiling ($CEIL_START)"
fi

# ============================================================================
# 2. ANALYSIS-GONE — the dead analysis skill is deleted; its 3 references live
#    at the agent-owned home; check-references.sh was extended to walk it.
# ============================================================================
if [ -e onboard/skills/analysis ]; then bad "onboard/skills/analysis still exists"; else ok "onboard/skills/analysis absent"; fi
must_absent "no live 'skills/analysis' reference remains" 'skills/analysis' onboard/ tests/

for f in tech-stack-patterns model-recommendations config-extraction-guide; do
  must_present_nonempty "agents/references/$f.md exists and is non-empty" "onboard/agents/references/$f.md"
done

# Behavioral self-test: the agents/**/references/ walk must actually DETECT an empty reference.
# A grep for the walk's source text would be vacuous — that string predates this extension, so a revert of the
# walk itself would still pass. Build a minimal scratch plugin whose only agents reference is EMPTY,
# point check-references.sh at it (it scans .claude-plugin/marketplace.json relative to CWD), and
# assert it flags the empty file; then make the file non-empty and assert it passes. Mirrors the
# numbering good/bad-fixture pattern.
CR_GATE="$ROOT/.github/scripts/check-references.sh"
cr_scratch="$(mktemp -d)"
mkdir -p "$cr_scratch/.claude-plugin" "$cr_scratch/p/skills" "$cr_scratch/p/agents/a/references"
printf '{ "plugins": [ { "name": "p", "source": "./p" } ] }\n' > "$cr_scratch/.claude-plugin/marketplace.json"
: > "$cr_scratch/p/agents/a/references/empty.md"            # EMPTY agents reference — must be flagged
if ( cd "$cr_scratch" && bash "$CR_GATE" >/dev/null 2>&1 ); then
  bad "check-references.sh did NOT flag an empty agents/**/references file (walk is vacuous)"
else
  ok "check-references.sh flags an empty agents/**/references file"
fi
printf 'non-empty\n' > "$cr_scratch/p/agents/a/references/empty.md"   # now NON-empty — must pass
if ( cd "$cr_scratch" && bash "$CR_GATE" >/dev/null 2>&1 ); then
  ok "check-references.sh exits 0 once the agents reference is non-empty"
else
  bad "check-references.sh is still nonzero after the agents reference is made non-empty"
fi
rm -rf "$cr_scratch"

if bash .github/scripts/check-references.sh >/dev/null 2>&1; then
  ok "check-references.sh exits 0"
else
  bad "check-references.sh does not exit 0"
fi

# ============================================================================
# 3. CHANGELOG-2.0-ABSENT — the orphaned v2 migration log is deleted and no
#    live reference to it remains.
# ============================================================================
if [ -f onboard/CHANGELOG-2.0.md ]; then bad "onboard/CHANGELOG-2.0.md still exists"; else ok "onboard/CHANGELOG-2.0.md absent"; fi
must_absent "no live 'CHANGELOG-2.0' reference remains" 'CHANGELOG-2\.0' onboard/ tests/ .github/

# ============================================================================
# 4. CONTEXT-SHAPE SINGLE-SOURCED — the schema lives at the new schemas/ home,
#    the old skills/generate/references/ path is gone, accept/reject shape is
#    byte-identical (required[] + additionalProperties unchanged), and both
#    prose restatements were replaced with citations.
# ============================================================================
NEW_SCHEMA=onboard/schemas/context-shape-v3.json
OLD_SCHEMA=onboard/skills/generate/references/context-shape-v3.json

must_present_nonempty "context-shape-v3.json exists at the new schemas/ path" "$NEW_SCHEMA"
if [ -f "$OLD_SCHEMA" ]; then bad "old schema path still exists ($OLD_SCHEMA)"; else ok "old schema path (skills/generate/references/) is gone"; fi
must_absent "no live reference to the old schema path remains" 'skills/generate/references/context-shape-v3' onboard/ tests/

if command -v jq >/dev/null 2>&1 && [ -f "$NEW_SCHEMA" ]; then
  if jq -e '.required == ["version","source","projectPath","callerExtras"]' "$NEW_SCHEMA" >/dev/null 2>&1; then
    ok "required[] is byte-identical to [version, source, projectPath, callerExtras]"
  else
    bad "required[] changed from [version, source, projectPath, callerExtras]"
  fi
  if jq -e '.additionalProperties == true' "$NEW_SCHEMA" >/dev/null 2>&1; then
    ok "root additionalProperties is still true"
  else
    bad "root additionalProperties is not true"
  fi
  if jq -e '([.. | objects | select(has("additionalProperties")) | select(.additionalProperties == false)] | length) == 0' "$NEW_SCHEMA" >/dev/null 2>&1; then
    ok "no nested additionalProperties:false anywhere in the schema"
  else
    bad "found a nested additionalProperties:false (would HARD-REJECT real runtime contexts)"
  fi
else
  bad "jq unavailable or schema missing — cannot verify required[]/additionalProperties"
fi

# This belt and the release-gate runner (tests/release-gate/run-automated-checks.sh:~842, which is
# NOT in CI) are check-schemas.py's two invokers. That second invoker still treats exit 2
# ("jsonschema absent — full suite skipped") as a warning, not a failure; bringing it to the
# exit-0 parity this belt enforces is deferred to SP-9 (SP9-guard-hardening). In CI, this belt is
# the only invoker, so accepting its exit-2 as a pass would mean the schema is validated nowhere: a
# skipped suite must never be mistakable for a passing one. Demand exit 0, and name the skip as a
# skip when the dependency is missing.
if command -v python3 >/dev/null 2>&1; then
  cs_out=""; cs_rc=0
  cs_out="$(python3 onboard/schemas/check-schemas.py 2>&1)" || cs_rc=$?
  case "$cs_rc" in
    0) ok "check-schemas.py validated every fixture (exit 0)" ;;
    2) bad "check-schemas.py SKIPPED its suite (exit 2 — jsonschema absent); install it: pip install jsonschema" ;;
    *) bad "check-schemas.py failed (exit $cs_rc)"; printf '%s\n' "$cs_out" ;;
  esac
else
  bad "python3 unavailable — cannot run check-schemas.py"
fi

if grep -q 'context-shape-v3' onboard/schemas/check-schemas.py 2>/dev/null; then
  bad "check-schemas.py still contains a context-shape-v3 name special-case"
else
  ok "check-schemas.py has no context-shape-v3 special-case (falls to the default path rule)"
fi

if grep -q 'Required Context Structure' onboard/skills/generate/SKILL.md 2>/dev/null; then
  bad "generate/SKILL.md still restates the Required Context Structure heading"
else
  ok "generate/SKILL.md no longer restates the Required Context Structure section"
fi
if grep -q '```jsonc' onboard/skills/start/references/onboard-context-builder.md 2>/dev/null; then
  bad "onboard-context-builder.md still carries a JSON-fenced Output schema restatement"
else
  ok "onboard-context-builder.md no longer carries a JSON-fenced Output schema restatement"
fi
if grep -q 'context-shape-v3.json' onboard/skills/start/references/onboard-context-builder.md 2>/dev/null; then
  ok "onboard-context-builder.md cites the schema instead of restating it"
else
  bad "onboard-context-builder.md no longer cites the schema at all"
fi

# ============================================================================
# 5. EMPTY-REPO SINGLY-SOURCED — start Phase 0 is a thin pointer (heading
#    retained, body kept short); empty-repo-stub-procedure.md owns detection
#    + the 3-option menu.
# ============================================================================
CEIL_PHASE0_SPAN=15  # achieved 10-line span (Phase 0 heading -> Step 0 heading) + 5 headroom

phase0_line="$(grep -n '^## Phase 0' onboard/skills/start/SKILL.md | head -1 | cut -d: -f1)"
step0_line="$(grep -n '^## Step 0' onboard/skills/start/SKILL.md | head -1 | cut -d: -f1)"
if [ -n "$phase0_line" ] && [ -n "$step0_line" ]; then
  span=$((step0_line - phase0_line))
  if [ "$span" -le "$CEIL_PHASE0_SPAN" ]; then
    ok "start/SKILL.md Phase-0-to-Step-0 span ($span) <= ceiling ($CEIL_PHASE0_SPAN)"
  else
    bad "start/SKILL.md Phase-0-to-Step-0 span ($span) exceeds ceiling ($CEIL_PHASE0_SPAN) — Phase 0 body was re-inflated"
  fi
else
  bad "could not locate both '## Phase 0' and '## Step 0' headings in start/SKILL.md"
fi
if grep -q '^## Phase 0: Empty-Repo Guard' onboard/skills/start/SKILL.md; then
  ok "start/SKILL.md retains the '## Phase 0: Empty-Repo Guard' heading"
else
  bad "start/SKILL.md no longer has the '## Phase 0: Empty-Repo Guard' heading (breaks empty-repo-stub-procedure.md's backtick-path ref)"
fi

PROC=onboard/skills/start/references/empty-repo-stub-procedure.md
if grep -q 'SRC_COUNT' "$PROC" 2>/dev/null; then
  ok "empty-repo-stub-procedure.md owns the SRC_COUNT detection filter"
else
  bad "empty-repo-stub-procedure.md is missing the SRC_COUNT detection filter"
fi
if grep -qi '3-option menu' "$PROC" 2>/dev/null \
   && grep -q '\*\*Abort\*\*' "$PROC" 2>/dev/null \
   && grep -q '\*\*Placeholder only\*\*' "$PROC" 2>/dev/null \
   && grep -q '\*\*Generate canonical stub\*\*' "$PROC" 2>/dev/null; then
  ok "empty-repo-stub-procedure.md owns the 3-option menu (Abort / Placeholder only / Generate canonical stub)"
else
  bad "empty-repo-stub-procedure.md is missing the 3-option menu"
fi

# ============================================================================
# 6. INLINE SAFETY STRINGS — the five caller-parsed strings in generate/SKILL.md
#    must survive the extraction verbatim; a stray relocation to a reference
#    breaks any caller that greps generate's raw output for these strings.
# ============================================================================
GEN=onboard/skills/generate/SKILL.md
# shellcheck disable=SC2016  # backticks below are literal (single-quoted), not command substitution
for pinned in \
  'DISPATCH CONTRACT — READ BEFORE TOUCHING ANYTHING' \
  'Generation aborted (non-v3 context)' \
  'requires a `research` object for full (re)generation' \
  'failed `research-dossier.json` validation' \
  'Required JSON response shape'
do
  if grep -qF "$pinned" "$GEN" 2>/dev/null; then
    ok "generate/SKILL.md still contains verbatim: $pinned"
  else
    bad "generate/SKILL.md is missing the caller-parsed string: $pinned"
  fi
done

# ============================================================================
# 7. NUMBERING SELF-TEST — the check-phase-numbering.sh gate must accept every
#    in-family label and reject every out-of-family one. Asserted per-VIOLATION
#    (each line lifted into its own scratch file) rather than one exit code per
#    fixture, so a single catch-all line cannot carry a whole file's coverage.
#    The step and phase fixtures are kept separate and the step fixture is
#    Phase-free, so the step assertions cannot be satisfied by the phase regex.
#    Mirrors test_ref_anchors.sh's fixture self-test pattern.
# ============================================================================
NUMBERING_GATE=.github/scripts/check-phase-numbering.sh
GOOD_FIXTURE=tests/onboard/fixtures/numbering/good.md
BAD_STEPS_FIXTURE=tests/onboard/fixtures/numbering/bad-steps.md
BAD_PHASES_FIXTURE=tests/onboard/fixtures/numbering/bad-phases.md

# Runs the gate over a scratch tree holding exactly one line, so the verdict is
# attributable to that line alone.
gate_rejects_line(){
  local line="$1" dir rc=0
  dir="$(mktemp -d)"
  printf '%s\n' "$line" > "$dir/case.md"
  bash "$NUMBERING_GATE" "$dir" >/dev/null 2>&1 || rc=$?
  rm -rf "$dir"
  [ "$rc" -ne 0 ]
}

if [ -f "$NUMBERING_GATE" ] && [ -f "$GOOD_FIXTURE" ] && [ -f "$BAD_STEPS_FIXTURE" ] && [ -f "$BAD_PHASES_FIXTURE" ]; then
  if bash "$NUMBERING_GATE" "$GOOD_FIXTURE" >/dev/null 2>&1; then
    ok "check-phase-numbering.sh exits 0 on the in-family fixture (good.md)"
  else
    bad "check-phase-numbering.sh exits nonzero on the in-family fixture (good.md) — a legitimate Step/Phase label was flagged"
    bash "$NUMBERING_GATE" "$GOOD_FIXTURE" 2>&1 | sed 's/^/    /'
  fi

  # The step fixture must carry no phase label at all: if it did, the pre-existing
  # phase regex could satisfy the assertion below with the step logic deleted.
  phase_contamination="$(grep -nE 'Phase [0-9]' "$BAD_STEPS_FIXTURE" 2>/dev/null || true)"
  if [ -z "$phase_contamination" ]; then
    ok "the out-of-family step fixture is Phase-free — its rejection can only come from the step logic"
  else
    bad "the out-of-family step fixture carries a Phase label — the step assertions would pass with the step logic deleted"
    printf '%s\n' "$phase_contamination"
  fi

  for fixture in "$BAD_STEPS_FIXTURE" "$BAD_PHASES_FIXTURE"; do
    if bash "$NUMBERING_GATE" "$fixture" >/dev/null 2>&1; then
      bad "check-phase-numbering.sh exits 0 on the out-of-family fixture ($fixture) — it should have exited nonzero"
    else
      ok "check-phase-numbering.sh exits nonzero on the out-of-family fixture ($fixture)"
    fi
    # Every declared violation must stand on its own.
    while IFS= read -r viol; do
      [ -n "$viol" ] || continue
      if gate_rejects_line "$viol"; then
        ok "check-phase-numbering.sh rejects the out-of-family label in isolation: $viol"
      else
        bad "check-phase-numbering.sh accepts the out-of-family label in isolation: $viol"
      fi
    done < <(grep -E '(Step|Phase) ' "$fixture" 2>/dev/null | grep -E '^(#{1,6} |\*\*|- )' || true)
  done

  # Prose is not a declaration: these must never be tokenized into labels.
  for prose in "Step Through the wizard" "Step One is optional" "Step Back and review"; do
    if gate_rejects_line "$prose"; then
      bad "check-phase-numbering.sh flags ordinary prose as a step label: $prose"
    else
      ok "check-phase-numbering.sh leaves ordinary prose un-tokenized: $prose"
    fi
  done

  # A gate that scanned nothing must never report a pass.
  if bash "$NUMBERING_GATE" "$ROOT/tests/onboard/fixtures/numbering/__no_such_root__" >/dev/null 2>&1; then
    bad "check-phase-numbering.sh exits 0 on a root that does not exist — it would report a pass it never earned"
  else
    ok "check-phase-numbering.sh exits nonzero on a root that does not exist"
  fi
else
  bad "numbering gate or fixtures missing (gate=$NUMBERING_GATE good=$GOOD_FIXTURE steps=$BAD_STEPS_FIXTURE phases=$BAD_PHASES_FIXTURE)"
fi

# ============================================================================
# 8. VERSION TRIPLE — plugin.json, the marketplace.json onboard entry, and the
#    CHANGELOG head must all agree. Delegated to the shared derived helper
#    (tests/lib/assert-versions.sh) rather than re-implemented with a pinned
#    literal, so no belt edit is needed at the next version bump.
# ============================================================================
if version_out="$(bash tests/lib/assert-versions.sh onboard 2>&1)"; then
  ok "onboard version triple agrees: $version_out"
else
  bad "onboard version triple mismatch: $version_out"
fi

exit $fail
