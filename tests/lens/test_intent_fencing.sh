#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

# === intent data-fencing: engine pipeline §3 (all sources) ===
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
[ -s "$PIPE" ] || fail "missing $PIPE"
grep -q '<untrusted-user-input>' "$PIPE" || fail "FENCE: pipeline must wrap the intent doc in <untrusted-user-input>"
grep -qiE 'data, not instructions' "$PIPE" || fail "FENCE: pipeline must carry the data-not-instructions directive"
grep -qiE 'framing, not filtering' "$PIPE" || fail "FENCE: pipeline must state framing-not-filtering (no length cap)"
grep -qi 'all sources' "$PIPE" || fail "FENCE: pipeline must state the fence applies to all intent sources"

# === intent data-fencing: adherence agents treat intent as untrusted data ===
SPECAG="$ROOT/lens/agents/spec-adherence.md"
PLANAG="$ROOT/lens/agents/plan-adherence.md"
[ -s "$SPECAG" ] || fail "missing $SPECAG"
[ -s "$PLANAG" ] || fail "missing $PLANAG"
grep -q '<untrusted-user-input>' "$SPECAG" || fail "FENCE: spec-adherence must state intent arrives in <untrusted-user-input>"
grep -qiE 'data, not instructions|never as an instruction' "$SPECAG" || fail "FENCE: spec-adherence must treat intent as data, not instructions"
grep -q '<untrusted-user-input>' "$PLANAG" || fail "FENCE: plan-adherence must state intent arrives in <untrusted-user-input>"
grep -qiE 'data, not instructions|never as an instruction' "$PLANAG" || fail "FENCE: plan-adherence must treat intent as data, not instructions"

# === intent data-fencing: engine SKILL Step 3 + lens CLAUDE.md security note ===
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
CLAUDEMD="$ROOT/lens/CLAUDE.md"
[ -s "$ESKILL" ] || fail "missing $ESKILL"
[ -s "$CLAUDEMD" ] || fail "missing $CLAUDEMD"
grep -q '<untrusted-user-input>' "$ESKILL" || fail "FENCE: engine SKILL Step 3 must reference the <untrusted-user-input> fence"
grep -qiE 'untrusted intent content|<untrusted-user-input>' "$CLAUDEMD" || fail "FENCE: lens CLAUDE.md must document the untrusted-intent fencing"
grep -qiE 'framing, not filtering|not .*capped|verbatim' "$CLAUDEMD" || fail "FENCE: lens CLAUDE.md must note framing-not-filtering / no-cap"

echo "PASS: lens intent fencing"
