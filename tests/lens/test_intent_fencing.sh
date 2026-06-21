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

echo "PASS: lens intent fencing"
