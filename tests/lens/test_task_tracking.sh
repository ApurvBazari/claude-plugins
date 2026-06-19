#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TT="$ROOT/lens/skills/review/references/task-tracking.md"
REVIEW="$ROOT/lens/skills/review/SKILL.md"
ENGINE="$ROOT/lens/skills/engine/SKILL.md"
MDFB="$ROOT/lens/skills/review/references/markdown-fallback.md"
CLAUDEMD="$ROOT/lens/CLAUDE.md"
PJSON="$ROOT/lens/.claude-plugin/plugin.json"
MKT="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/lens/CHANGELOG.md"
fail(){ echo "FAIL: $1"; exit 1; }
for f in "$REVIEW" "$ENGINE" "$MDFB" "$CLAUDEMD" "$PJSON" "$MKT" "$CHANGELOG"; do [ -s "$f" ] || fail "missing $f"; done
[ -s "$TT" ] || fail "task-tracking.md reference missing"

# === reference doc: the task-list contract ===
for slug in setup scope intent analyze verify reconcile render report; do
  grep -qE "\| \`$slug\` \|" "$TT" || fail "task-tracking.md stage table missing row '$slug'"
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
grep -qiE 'first review|settings\.md.*absent|only on the first' "$TT" || fail "task-tracking.md must state setup task is first-review-only"
grep -qiE 'aborts? before|never left .?in_progress|deleted.* never' "$TT" || fail "task-tracking.md must state abort path never leaves a task in_progress"
grep -qiE 'one task per stage|never per finder|single .?analyze' "$TT" || fail "task-tracking.md must state one task per stage, never per finder"

# === review wiring: owns the list + passes taskIds ===
grep -q 'TaskCreate' "$REVIEW" || fail "review must create the task list via TaskCreate"
grep -q 'taskIds' "$REVIEW" || fail "review must pass taskIds to the engine"
grep -q 'task-tracking' "$REVIEW" || fail "review must reference references/task-tracking.md"
grep -qiE 'create no tasks|no .?taskIds|no task list' "$REVIEW" || fail "review orchestrator mode must skip tracking"
grep -qiE 'nothing to review' "$REVIEW" || fail "review must handle the empty-diff path (mark reconcile/render deleted, report completed)"
grep -qiE 'render fail.*skip the (state )?write' "$REVIEW" || fail "review SKILL must state render-failure skips the state write"
grep -qiE 'render failure|empty output|no path returned' "$MDFB" || fail "markdown-fallback must define render failure"

# === engine wiring: flips handed-in taskIds, no-op when absent ===
grep -q 'taskIds' "$ENGINE" || fail "engine must read args.taskIds"
grep -qiE 'absent.*orchestrator|task action.*byte-identical' "$ENGINE" || fail "engine must no-op when taskIds absent"
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
