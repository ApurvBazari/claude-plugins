#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AD="$ROOT/lens/skills/engine/references/adapter-dispatch.md"
REG="$ROOT/lens/skills/engine/references/finder-registry.md"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$AD" ] || fail "adapter-dispatch.md missing"

# Part 1 — the generic forcing wrapper-prompt (read-only + emit the finding shape).
grep -qi 'findings-only' "$AD" || fail "no findings-only wrapper instruction"
grep -qiE 'review-findings|finding shape' "$AD" || fail "wrapper must force the review-findings finding shape"

# Part 2 — a mapping section per adapter.
for a in silent-failure-hunter type-design-analyzer comment-analyzer pr-test-analyzer feature-dev:code-reviewer; do
  grep -q "$a" "$AD" || fail "no per-adapter map for $a"
done

# finder-registry references the dispatch doc.
grep -qi 'adapter-dispatch' "$REG" || fail "finder-registry must reference adapter-dispatch.md"

echo "PASS: adapter dispatch contract"
