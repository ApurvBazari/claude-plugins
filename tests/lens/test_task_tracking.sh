#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TT="$ROOT/lens/skills/review/references/task-tracking.md"
REVIEW="$ROOT/lens/skills/review/SKILL.md"
ENGINE="$ROOT/lens/skills/engine/SKILL.md"
CLAUDEMD="$ROOT/lens/CLAUDE.md"
PJSON="$ROOT/lens/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/lens/CHANGELOG.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$REVIEW" "$ENGINE" "$CLAUDEMD" "$PJSON" "$MKT" "$CHANGELOG"; do [ -s "$f" ] || fail "missing $f"; done
[ -s "$TT" ] || fail "task-tracking.md reference missing"

# === reference doc: the task-list contract ===
for slug in setup scope intent analyze verify reconcile render report; do
  grep -q "$slug" "$TT" || fail "task-tracking.md missing stage '$slug'"
done
grep -qi 'in-session' "$TT" || fail "task-tracking.md must state in-session visibility only"
for st in pending in_progress completed deleted; do
  grep -q "$st" "$TT" || fail "task-tracking.md missing status '$st'"
done
grep -qiE 'no .?failed' "$TT" || fail "task-tracking.md must state there is no failed status"
grep -qi 'display-only' "$TT" || fail "task-tracking.md must state subjects are display-only"
grep -qi 'task-blind' "$TT" || fail "task-tracking.md must state subagents are task-blind"
grep -qiE 'standalone only|orchestrator' "$TT" || fail "task-tracking.md must state standalone-only / orchestrator skip"
grep -q 'taskIds' "$TT" || fail "task-tracking.md must document the handed-in taskIds"

# === review wiring: owns the list + passes taskIds ===
grep -q 'TaskCreate' "$REVIEW" || fail "review must create the task list via TaskCreate"
grep -q 'taskIds' "$REVIEW" || fail "review must pass taskIds to the engine"
grep -q 'task-tracking' "$REVIEW" || fail "review must reference references/task-tracking.md"
grep -qiE 'create no tasks|no .?taskIds|no task list' "$REVIEW" || fail "review orchestrator mode must skip tracking"

echo "PASS: lens task-tracking"
