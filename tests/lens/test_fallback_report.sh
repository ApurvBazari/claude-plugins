#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/tests/lens/fixtures/fallback-sample.md"
MF="$ROOT/lens/skills/review/references/markdown-fallback.md"
fail(){ echo "FAIL: $1"; exit 1; }
[ -s "$F" ] || fail "fixture missing: produce via markdown-fallback on the sample review-model"
[ -s "$MF" ] || fail "markdown-fallback.md missing"

# Degrade notice — this is the markdown path, taken when walkthrough is absent.
grep -qi 'walkthrough is not installed' "$F" || fail "missing fallback notice"

# Verdict must be DERIVED from the engine sample's recommendedEscalation, not just present.
# engine-output-sample.json sets escalation 'major', which review-model-assembly.md maps to 'block'.
# A bare verdict header (the old assertion) green-lit the 'fix'/'block' drift — assert the value.
grep -qiE '^\*\*verdict:[[:space:]]*block\*\*' "$F" \
  || fail "verdict must be 'block' (engine sample escalation is 'major' -> block)"

grep -qi '^## Adherence' "$F" || fail "no adherence section"

# Both findings from engine-output-sample.json must be listed, each under its severity group.
# The old 'grep F1' was too weak: it passed even when the medium finding was dropped and the
# high finding was mislabeled F1. Assert both severity headers AND both finding ids.
grep -qE '^## High'   "$F" || fail "missing '## High' severity group"
grep -qE '^## Medium' "$F" || fail "missing '## Medium' severity group (the medium rate-limit finding was dropped)"
grep -qE 'F1:' "$F" || fail "finding F1 (rate-limit, medium) not listed"
grep -qE 'F2:' "$F" || fail "finding F2 (password ==, high) not listed"

# Risk table — one row per changed file (markdown-fallback § 5).
grep -qE '^## Risk' "$F" || fail "missing '## Risk' table"

# D1 — full parity: the fallback carries the narrative spine + a diff-hunks section, not just findings.
grep -qiE '^## Decisions' "$F" || fail "no Decisions narrative section (D1 parity)"
grep -qiE '^## The change, annotated' "$F" || fail "no diff-hunks section (D1 parity)"
grep -qE '← *F[0-9]' "$F" || fail "diff hunks lack inline finding markers (← F<n>)"

# D1 — markdown-fallback section numbering must be sequential (no duplicate/skipped headings).
[ "$(grep -cE '^### 4\.' "$MF")" -eq 1 ] || fail "markdown-fallback: duplicate or missing '### 4.' heading"
grep -qE '^### 5\. Findings' "$MF" || fail "markdown-fallback: Findings must be section 5"
grep -qE '^### 7\. Risk' "$MF" || fail "markdown-fallback: Risk table must be section 7"

# === F4 — markdown-fallback.md: omit-empty severity rule + clean-review no-findings line ===
# Real text (line 74): "severity heading only when that group has at least one finding (omit-empty — never render an empty"
# Use the severity-specific phrase so a generic 'omit-empty' on another line cannot mask a deletion here.
grep -qiE 'severity heading only when|never render an empty.*High|omit-empty.*never render' "$MF" || fail "markdown-fallback must omit empty severity headings (omit-empty rule)"
# Real text (line 77): "_No findings — the diff was reviewed and nothing was flagged._"
# Use the combined phrase "nothing was flagged" so the generic "clean review" mentions on nearby lines
# (which describe the concept, not the output template) can't mask a deletion of the actual output line.
grep -qiE 'nothing was flagged|_No findings[^_]*reviewed' "$MF" || fail "markdown-fallback must define the clean-review no-findings output line (e.g. 'nothing was flagged')"

echo "PASS: lens fallback report"
