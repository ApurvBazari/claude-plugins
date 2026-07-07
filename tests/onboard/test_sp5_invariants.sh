#!/usr/bin/env bash
# test_sp5_invariants.sh — SP-5 doc-truth + code invariants (grep assertions).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 1
fail=0
must_absent(){ local desc="$1"; shift; if grep -rniE "$1" "${@:2}" >/dev/null 2>&1; then echo "FAIL: $desc"; grep -rniE "$1" "${@:2}"; fail=1; else echo "ok: $desc"; fi; }

# --- O1: no auto-promote branding survives (there is no auto-promote path;
#     re-run with code added falls through to the full flow + Phase 5 hard gate) ---
must_absent "O1: no auto-promote branding survives" \
  'auto-?promot' \
  onboard/skills/start/SKILL.md \
  onboard/skills/start/references/empty-repo-stub-procedure.md \
  onboard/skills/adopt/references/detection-and-classification.md \
  tests/release-gate/manual-test-plan.md

# --- O4: no source writer emits the legacy drift name; readers keep a fallback ---
must_absent "O4: no greenfield-drift writer in scripts" \
  'greenfield-drift' onboard/scripts
must_absent "O4: no greenfield-drift init in generation SKILL" \
  'greenfield-drift' onboard/skills/generation/SKILL.md
if ! grep -q 'onboard-drift.json' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4 evolve reads onboard-drift.json"; fail=1; else echo "ok: O4 evolve reads onboard-drift.json"; fi
if ! grep -q 'greenfield-drift.json' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4 evolve keeps legacy fallback mention"; fail=1; else echo "ok: O4 evolve read-both fallback"; fi

# --- O4b: evolve documents the legacy drift-file migration (move + re-emit) ---
if ! grep -qi 'Legacy drift-file migration' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4b migration step missing"; fail=1; else echo "ok: O4b migration step present"; fi
if ! grep -qi 're-emit' onboard/skills/evolve/SKILL.md; then echo "FAIL: O4b re-emit missing"; fail=1; else echo "ok: O4b re-emit present"; fi

# --- O4b fixture: the legacy pre-migration drift shape exists (valid JSON carrying `entries`) ---
legacy_fixture="tests/onboard/fixtures/legacy-drift/.claude/greenfield-drift.json"
if [[ ! -f "$legacy_fixture" ]]; then
  echo "FAIL: O4b legacy-drift fixture missing"; fail=1
elif command -v python3 >/dev/null 2>&1 && ! python3 -c 'import json,sys; sys.exit(0 if "entries" in json.load(open(sys.argv[1])) else 1)' "$legacy_fixture" 2>/dev/null; then
  echo "FAIL: O4b legacy-drift fixture is not valid JSON carrying entries"; fail=1
elif ! grep -q '"entries"' "$legacy_fixture"; then
  echo "FAIL: O4b legacy-drift fixture lacks entries key"; fail=1
else
  echo "ok: O4b legacy-drift fixture present (valid JSON with entries)"
fi

# --- O3: no phantom greenfield-meta.json survives in evolve (it's a removed
#     plugin's file onboard never creates; plugin-drift state lives in onboard-meta.json).
#     NB: this greps `greenfield-meta` (with -meta), so it never matches the O4
#     `greenfield-drift` read-both fallback, which is intentionally kept. ---
must_absent "O3: no greenfield-meta in evolve" 'greenfield-meta' onboard/skills/evolve/SKILL.md

# --- O2: the evolve Guard early-exit names MCP (Step 2c) + LSP (Step 2g) +
#     research staleness (Step 2i). The Guard short-circuits ("in sync, stop")
#     via an AND-chain of drift pre-checks; it must only stop when EVERY drift
#     source is clean, else an MCP-only / LSP-only / stale-research project
#     falsely reports clean. We isolate the early-exit condition itself — the
#     "If onboard-drift.json has no entries …:" sentence inside the `## Guard`
#     section, up to its terminating colon — and assert the three sources are
#     named IN that condition (not merely somewhere in the file / an arbitrary
#     line window). ---
guard_cond="$(awk '
  /^## Guard$/                                        { inguard=1; next }
  inguard && /^## /                                   { exit }
  inguard && /If onboard-drift\.json has no entries/  { incond=1 }
  incond                                              { print }
  incond && /:[[:space:]]*$/                          { exit }
' onboard/skills/evolve/SKILL.md)"
if [[ -z "$guard_cond" ]] || ! printf '%s' "$guard_cond" | grep -q 'AND no'; then
  echo "FAIL: O2 could not locate the evolve Guard early-exit AND-chain"; fail=1
else
  for k in 'MCP' 'LSP' 'research'; do
    if printf '%s' "$guard_cond" | grep -qiE "no ${k}[a-z ]*(drift|staleness) was detected"; then
      echo "ok: O2 Guard early-exit names $k"
    else
      echo "FAIL: O2 Guard early-exit omits $k drift"; fail=1
    fi
  done
fi

# --- O2 (completion): the Guard's user-facing "in sync" BLOCKQUOTE must ALSO
#     name MCP + LSP + research, in lockstep with the AND-chain above. The
#     blockquote is what the developer reads when the Guard reports "nothing to
#     do"; if it enumerates only the old four sources it re-teaches the wrong
#     mental model. We isolate the `>`-quoted block that opens with "in sync"
#     inside the `## Guard` section (NOT the AND-chain line, which already names
#     them and would pass vacuously) and assert the three sources appear IN the
#     blockquote itself. ---
guard_bq="$(awk '
  /^## Guard$/            { inguard=1; next }
  inguard && /^## /       { exit }
  inguard && /in sync/    { inbq=1 }
  inbq && /^>/            { print; next }
  inbq && !/^>/           { exit }
' onboard/skills/evolve/SKILL.md)"
if [[ -z "$guard_bq" ]] || ! printf '%s' "$guard_bq" | grep -q 'in sync'; then
  echo "FAIL: O2 could not locate the evolve Guard 'in sync' blockquote"; fail=1
else
  for k in 'MCP' 'LSP' 'research'; do
    if printf '%s' "$guard_bq" | grep -qi "$k"; then
      echo "ok: O2 Guard 'in sync' blockquote names $k"
    else
      echo "FAIL: O2 Guard 'in sync' blockquote omits $k"; fail=1
    fi
  done
fi

# --- O5: FileChanged hooks do not set -e and end with an explicit exit 0 ---
for s in detect-config-changes detect-dep-changes detect-structure-changes; do
  f="onboard/scripts/$s.sh"
  if grep -qE '^set -euo pipefail|^set -e' "$f"; then echo "FAIL: O5 $s still set -e"; fail=1; else echo "ok: O5 $s no set -e"; fi
  if ! tail -3 "$f" | grep -qE '^exit 0'; then echo "FAIL: O5 $s missing explicit exit 0"; fail=1; else echo "ok: O5 $s exit 0"; fi
done

# --- O7: no 'three analysis scripts' fiction in update (recon is script-free in
#     v3 — the 3 recon scripts were deleted; recon runs via the codebase-analyzer
#     agent) ---
must_absent "O7: no 'three analysis scripts' in update" 'three analysis scripts' onboard/skills/update/SKILL.md

# --- O8: feature-evaluator is read-only and RETURNS data; /onboard:verify owns
#     every write. The evaluator runs with `isolation: worktree`, so any file it
#     writes lands in a throwaway worktree and is silently discarded — it must
#     therefore RETURN its verdicts + report body and let the orchestrator write.
#     (a) it no longer claims it may modify feature-list; (b) it states its output
#     IS the returned structured verdict set — a phrase unique to the returns-data
#     clause, because a bare `grep 'return'` gates only incidentally (the word is
#     absent today) and any stray future "return" would satisfy it vacuously;
#     (c) it no longer claims to write the report to a file. ---
must_absent "O8: evaluator no longer claims it may modify feature-list" \
  'you may (only )?modify .*feature-list' onboard/agents/feature-evaluator.md
if ! grep -qi 'structured verdict set' onboard/agents/feature-evaluator.md; then echo "FAIL: O8 evaluator should RETURN its structured verdict set"; fail=1; else echo "ok: O8 evaluator returns its structured verdict set"; fi
must_absent "O8: evaluator no longer claims to write the report to a file" \
  'always write the (full )?report to' onboard/agents/feature-evaluator.md

exit $fail
