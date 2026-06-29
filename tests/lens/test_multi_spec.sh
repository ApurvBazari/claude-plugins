#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
SPECAG="$ROOT/lens/agents/spec-adherence.md"
PLANAG="$ROOT/lens/agents/plan-adherence.md"
ASM="$ROOT/lens/skills/review/references/review-model-assembly.md"
MDFB="$ROOT/lens/skills/review/references/markdown-fallback.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ESKILL" "$SPECAG" "$PLANAG" "$ASM" "$MDFB"; do [ -s "$f" ] || fail "missing $f"; done

# === INTENT: diff-correlated multi-spec/plan selection ===
grep -qi 'diff-correlated' "$PIPE" || fail "INTENT: pipeline must describe diff-correlated selection"
grep -qiE 'Added or Modified' "$PIPE" || fail "INTENT: must select specs/plans Added or Modified in the diff"
grep -qi 'Prefer Added' "$PIPE" || fail "INTENT: must prefer Added over Modified"
grep -qiE 'only Modified|Modified-only' "$PIPE" || fail "INTENT: modified-only must be a soft (degraded) signal"
grep -qi 'latest-only fallback' "$PIPE" || fail "INTENT: empty set must fall back to latest-only"
grep -qi 'name the skipped' "$PIPE" || fail "INTENT: over-cap specs must be named in summary, not dropped"
grep -qiE 'multiple specs|more than one spec|span' "$ESKILL" || fail "INTENT: engine SKILL Step 2 must state intent can span multiple specs/plans"
grep -qi 'diff-correlated' "$ESKILL" || fail "INTENT: engine SKILL Step 2 must reference diff-correlated selection"

# === ANALYZE: per-spec/plan fan-out + provenance ===
grep -qiE 'spec-adherence.*per spec|per spec.*spec-adherence|one .?spec-adherence.? (agent )?per spec' "$PIPE" || fail "ANALYZE: one spec-adherence per spec"
grep -qiE 'plan-adherence.*per plan|per plan.*plan-adherence|one .?plan-adherence.? (agent )?per plan' "$PIPE" || fail "ANALYZE: one plan-adherence per plan"
grep -qiE 'same single parallel batch|same parallel batch' "$PIPE" || fail "ANALYZE: fan-out is one parallel batch"
grep -q 'sourceSpec' "$PIPE" || fail "ANALYZE: provenance sourceSpec documented"
grep -q 'sourcePlan' "$PIPE" || fail "ANALYZE: provenance sourcePlan documented"
grep -qiE 'merges? (all )?(specItems|planSteps|findings).*(across|fan-out)|across the fan-out' "$PIPE" || fail "ANALYZE: engine merges across the fan-out"
grep -qiE 'per spec|per plan' "$ESKILL" || fail "ANALYZE: engine SKILL Step 3 must state per-spec/plan fan-out"

# === Adherence agents: single-doc judgment + provenance ===
grep -qiE 'one spec|a single spec|exactly one spec' "$SPECAG" || fail "spec-adherence must judge against one spec"
grep -q 'sourceSpec' "$SPECAG" || fail "spec-adherence must tag specItems/findings with sourceSpec"
grep -qiE 'one plan|a single plan|exactly one plan' "$PLANAG" || fail "plan-adherence must judge against one plan"
grep -q 'sourcePlan' "$PLANAG" || fail "plan-adherence must tag planSteps/findings with sourcePlan"

# === lens render: grouped adherence + markdown fallback ===
grep -qi 'groups' "$ASM" || fail "review-model-assembly must document grouped adherence"
grep -qiE 'more than one spec|N>1|multiple specs' "$ASM" || fail "assembly: grouped only when N>1"
grep -qiE 'flat .*specItems|specItems.*flat|N=1' "$ASM" || fail "assembly: flat shape when N=1 or headless"
grep -q 'sourceSpec' "$ASM" || fail "assembly: groups built from sourceSpec/sourcePlan provenance"
grep -qiE 'sub-section per spec|per spec/plan|one .* per spec' "$MDFB" || fail "markdown fallback must group adherence per spec/plan"

# === lens narrative + version ===
CLAUDEMD="$ROOT/lens/CLAUDE.md"
PJSON="$ROOT/lens/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/lens/CHANGELOG.md"
grep -qiE 'multiple specs|multi-spec|diff-correlated' "$CLAUDEMD" || fail "lens CLAUDE.md must describe multi-spec intent"
PV=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$PJSON")
MV=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print([p["version"] for p in d["plugins"] if p["name"]=="lens"][0])' "$MKT")
[ "$PV" = "1.4.1" ] || fail "lens plugin.json must be 1.4.1 (got $PV)"
[ "$MV" = "1.4.1" ] || fail "lens marketplace.json must be 1.4.1 (got $MV)"
grep -q '1.1.0' "$CHANGELOG" || fail "lens CHANGELOG must have a 1.1.0 entry"

echo "PASS: lens multi-spec"
