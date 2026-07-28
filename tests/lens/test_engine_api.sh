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

echo "PASS: lens engine-api belt (ref guards, fencing preservation, JSON example integrity)"
