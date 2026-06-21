#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PIPE="$ROOT/lens/skills/engine/references/pipeline.md"
ESKILL="$ROOT/lens/skills/engine/SKILL.md"
REG="$ROOT/lens/skills/engine/references/finder-registry.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$PIPE" "$ESKILL" "$REG"; do [ -s "$f" ] || fail "missing $f"; done

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

# === version bump 1.2.0 -> 1.3.0 (manifest + marketplace + changelog) ===
PJSON="$ROOT/lens/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/lens/CHANGELOG.md"
PV=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$PJSON")
MV=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print([p["version"] for p in d["plugins"] if p["name"]=="lens"][0])' "$MKT")
[ "$PV" = "1.3.0" ] || fail "lens plugin.json must be 1.3.0 (got $PV)"
[ "$MV" = "1.3.0" ] || fail "lens marketplace.json must be 1.3.0 (got $MV)"
grep -q '## 1.3.0' "$CHANGELOG" || fail "lens CHANGELOG must have a 1.3.0 entry"
awk '/^## 1\.3\.0/{f=1;next} /^## /{f=0} f && tolower($0) ~ /injectedfinders/{hit=1} END{exit !hit}' "$CHANGELOG" \
  || fail "lens CHANGELOG 1.3.0 entry must mention injectedFinders"

echo "PASS: lens injectedFinders contract"
