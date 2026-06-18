#!/usr/bin/env bash
# test-check-ref-paths.sh — fixture test for .github/scripts/check-ref-paths.sh.
# Builds a synthetic tree exercising every classification branch and asserts the resolver
# reports EXACTLY the one real wrong-path bug while exempting the collision + every lookalike.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="${SCRIPT_DIR}/../../.github/scripts/check-ref-paths.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

root="${tmp}/onboard"
mkdir -p "${root}/skills/alpha/references" "${root}/skills/beta/references"
echo "real"   > "${root}/skills/alpha/references/real-doc.md"   # target of the real bug
echo "rootmd" > "${root}/CLAUDE.md"                             # collision target (a real CLAUDE.md)

cat > "${root}/skills/beta/references/citer.md" <<'EOF'
- resolves correctly: `../../alpha/references/real-doc.md`
- REAL wrong-path bug: `references/real-doc.md`
- collision lookalike: `src/components/CLAUDE.md`
- generated lookalike: `docs/progress.md`
- cross-plugin lookalike: `walkthrough/skills/render/references/foo.md`
- bare ref (never checked, no slash): `real-doc.md`
EOF

out="$("$RESOLVER" "$root" 2>&1)"; rc=$?
fail() { echo "FAIL: $1"; echo "--- resolver output ---"; printf '%s\n' "$out"; exit 1; }

[ "$rc" -eq 1 ] || fail "expected exit 1 (one broken ref), got $rc"
broken_count="$(printf '%s\n' "$out" | grep -c 'BROKEN:')"
[ "$broken_count" -eq 1 ] || fail "expected exactly 1 BROKEN line, got $broken_count"
printf '%s\n' "$out" | grep -q "references/real-doc.md" || fail "did not flag the real wrong-path bug"
printf '%s\n' "$out" | grep -q 'CLAUDE.md'   && fail "collision CLAUDE.md was wrongly flagged"
printf '%s\n' "$out" | grep -q 'progress.md' && fail "generated lookalike progress.md was wrongly flagged"
printf '%s\n' "$out" | grep -q 'foo.md'      && fail "cross-plugin lookalike foo.md was wrongly flagged"

echo "PASS: resolver flags exactly the real wrong-path bug; collision + all lookalikes exempt"
exit 0
