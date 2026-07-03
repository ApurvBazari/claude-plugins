#!/usr/bin/env bash
# Belt test for assert-versions.sh — runs it against every real plugin (all must be
# self-consistent right now) and against a synthetic mismatch (must fail).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/tests/lib/assert-versions.sh"
fail(){ echo "FAIL: $1"; exit 1; }
[ -x "$HELPER" ] || fail "assert-versions.sh missing or not executable"

# 1) Every shipped plugin is currently version-consistent.
for p in onboard notify handoff walkthrough lens; do
  bash "$HELPER" "$p" >/dev/null || fail "expected $p to be version-consistent"
done

# 2) Synthetic mismatch: a temp plugin whose CHANGELOG heading disagrees with plugin.json must FAIL.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/zzz/.claude-plugin" "$TMP/.claude-plugin"
printf '{"name":"zzz","version":"9.9.9"}\n' > "$TMP/zzz/.claude-plugin/plugin.json"
printf '{"plugins":[{"name":"zzz","version":"9.9.9"}]}\n' > "$TMP/.claude-plugin/marketplace.json"
printf '# Changelog\n\n## 1.0.0 — 2020-01-01\n' > "$TMP/zzz/CHANGELOG.md"
if ROOT_OVERRIDE="$TMP" bash "$HELPER" zzz >/dev/null 2>&1; then
  fail "expected version mismatch (9.9.9 plugin vs 1.0.0 changelog) to FAIL"
fi

echo "PASS: assert-versions helper"
