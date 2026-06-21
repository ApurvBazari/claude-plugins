#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
PJSON="$ROOT/lens/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/lens/CHANGELOG.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ESKILL" "$PJSON" "$MKT" "$CHANGELOG"; do [ -s "$f" ] || fail "missing $f"; done

# === INTENT rule 0: injectedIntent override (pipeline §2) ===
grep -q 'injectedIntent' "$PIPE" || fail "INTENT: pipeline §2 must name the injectedIntent arg"
grep -qiE 'rule 0|highest priority|before .*rule 1|highest-priority' "$PIPE" || fail "INTENT: injectedIntent must be the highest-priority rule (rule 0, before rule 1)"
grep -qi 'verbatim' "$PIPE" || fail "INTENT: injected content must be used verbatim"
grep -qiE 'role.*spec.*plan|"spec" . "plan"|spec . plan' "$PIPE" || fail "INTENT: rule 0 must document the role enum (spec|plan)"
grep -q 'sourceSpec' "$PIPE" || fail "INTENT: role spec maps to sourceSpec provenance"
grep -q 'sourcePlan' "$PIPE" || fail "INTENT: role plan maps to sourcePlan provenance"
grep -qiE 'skip rules 1.4|skip .*rule 1|skip the (docs/superpowers|correlation)|skip rules 1 through 4' "$PIPE" || fail "INTENT: rule 0 must skip rules 1-4 (correlation/latest/transcript)"
grep -qiE 'not .*degraded|never .*degraded|NOT set .?degraded|do not set .?degraded' "$PIPE" || fail "INTENT: injected (explicit, full-fidelity) intent must NOT set degraded"

# === §8 cap applies to the injected path too ===
grep -qiE 'injected.*cap|cap.*injected|injectedIntent .*(cap|exceed)' "$PIPE" || fail "CAP: §8 must state the cap applies to injectedIntent"
grep -qiE 'name the skipped|named .*summary|skipped: ' "$PIPE" || fail "CAP: over-cap injected docs must be named, not silently dropped"
# strengthening (controller-added): gate the §8 source-agnostic paragraph specifically — the two assertions
# above pass against Task 1's §2 rule-0 text, so only this one proves the §8 edit was made.
grep -qi 'source-agnostic' "$PIPE" || fail "CAP: §8 must add the source-agnostic paragraph covering injectedIntent"

# === engine SKILL Step 2 mentions the injected override ===
grep -q 'injectedIntent' "$ESKILL" || fail "SKILL: engine Step 2 must name injectedIntent"
grep -qiE 'override|wins|highest|before .*docs/superpowers|skip' "$ESKILL" || fail "SKILL: Step 2 must say injectedIntent overrides the docs/superpowers correlation"
grep -qiE 'injectedIntent.*(wins|override)|(wins|override).*injectedIntent' "$ESKILL" || fail "SKILL: Step 2 must state injectedIntent wins/overrides on one line (semantic gate, not a loose whole-file match)"

# === version bump 1.1.0 -> 1.2.0 (manifest + marketplace + changelog) ===
PV=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$PJSON")
MV=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print([p["version"] for p in d["plugins"] if p["name"]=="lens"][0])' "$MKT")
[ "$PV" = "1.2.0" ] || fail "lens plugin.json must be 1.2.0 (got $PV)"
[ "$MV" = "1.2.0" ] || fail "lens marketplace.json must be 1.2.0 (got $MV)"
grep -q '## 1.2.0' "$CHANGELOG" || fail "lens CHANGELOG must have a 1.2.0 entry"
grep -qi 'injectedIntent' "$CHANGELOG" || fail "lens CHANGELOG 1.2.0 entry must mention injectedIntent"

# === backward-compat: absent/empty injectedIntent == v1.1.0 behavior ===
grep -qiE 'missing or empty|absent or empty|empty .*injectedIntent|fall through to rule 1' "$PIPE" || fail "BC: pipeline §2 must state empty/absent injectedIntent falls through to rule 1"
grep -qiE 'byte-identical|byte identical' "$PIPE" || fail "BC: pipeline §2 must promise byte-identical v1.1.0 behavior when injectedIntent is empty/absent"
grep -qiE 'JSON string|parse it defensively|parse defensively' "$PIPE" || fail "BC: pipeline §2 must say to parse a JSON-string injectedIntent defensively before the emptiness check"

echo "PASS: lens injected intent"
