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
grep -qiE 'nothing to review' "$REVIEW" || fail "review must handle the empty-diff path (mark reconcile/render deleted, report completed)"

# === engine wiring: flips handed-in taskIds, no-op when absent ===
grep -q 'taskIds' "$ENGINE" || fail "engine must read args.taskIds"
grep -qiE 'absent|no task action|task-silent|unchanged' "$ENGINE" || fail "engine must no-op when taskIds absent"
grep -qi 'task-blind' "$ENGINE" || fail "engine must state its subagents are task-blind"
grep -q 'deleted' "$ENGINE" || fail "engine empty-diff path must mark unreached stages deleted"

# === CLAUDE.md narrative + version 1.2.0 ===
grep -qiE 'task list|in-session task|progress task' "$CLAUDEMD" || fail "lens CLAUDE.md must describe the in-session task list"
PV=$(python3 -c "import json;print(json.load(open('$PJSON'))['version'])")
MV=$(python3 -c "import json;d=json.load(open('$MKT'));print([p['version'] for p in d['plugins'] if p['name']=='lens'][0])")
[ "$PV" = "1.2.0" ] || fail "lens plugin.json must be 1.2.0 (got $PV)"
[ "$MV" = "1.2.0" ] || fail "lens marketplace.json must be 1.2.0 (got $MV)"
grep -q '1.2.0' "$CHANGELOG" || fail "lens CHANGELOG must have a 1.2.0 entry"

echo "PASS: lens task-tracking"
