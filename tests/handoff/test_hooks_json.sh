#!/usr/bin/env bash
# F10 — handoff/hooks/hooks.json is dispatched by Claude Code at runtime, but no test loads
# it: the other handoff tests invoke session-start.sh directly, bypassing hooks.json entirely.
# A malformed command string or broken JSON would surface only when the hook fires. Assert
# structural validity + the command-string contract here.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
HOOKS="$REPO_ROOT/handoff/hooks/hooks.json"
fail(){ echo "FAIL: $1"; exit 1; }
[ -f "$HOOKS" ] || fail "hooks.json missing at $HOOKS"
[ -f "$REPO_ROOT/handoff/hooks/session-start.sh" ] || fail "referenced session-start.sh does not exist"

python3 - "$HOOKS" <<'PY' || fail "hooks.json failed validation"
import json,sys
h=json.load(open(sys.argv[1]))                          # valid JSON
ss=h["hooks"]["SessionStart"]
assert isinstance(ss,list) and ss, "SessionStart must be a non-empty list"
inner=ss[0]["hooks"]
assert isinstance(inner,list) and inner, "SessionStart[0].hooks must be a non-empty list"
entry=inner[0]
assert entry["type"]=="command", "hook type must be 'command'"
cmd=entry["command"]
assert "session-start.sh" in cmd, "command must invoke session-start.sh"
assert "${CLAUDE_PLUGIN_ROOT}" in cmd, "command must use ${CLAUDE_PLUGIN_ROOT} (plugin-aware path)"
assert '"${CLAUDE_PLUGIN_ROOT}"' in cmd, "${CLAUDE_PLUGIN_ROOT} must be double-quoted (exit-127 / spaces-in-path guard)"
assert int(entry.get("timeout",0))>0, "timeout must be a positive integer"
print("PASS: handoff hooks.json validity")
PY
