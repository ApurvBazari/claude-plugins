---
name: visual-companion
description: Greenfield Phase 1 — renders a clickable architecture map in the browser, drives a wait-for-intent loop so the user can pick phases in any order, and falls back to the linear wizard if Python 3 is unavailable. Internal building block invoked by greenfield start — not user-invocable.
user-invocable: false
---

# Greenfield Visual Companion

## What this skill does

Replaces the linear "Steps 1 to 30" wizard with a dependency-aware tech tree. After Step 0 has gathered project shape, this skill:

1. Resolves a status map across all 18 phases from `.claude/greenfield-state.json`.
2. Spawns a local HTTP server, opens the user's browser to the map.
3. Waits for the user to click an `AVAILABLE` phase (POST `/intent` writes a file).
4. Dispatches that phase's Q-bank via `context-gathering` in `single-phase` mode.
5. On phase completion, re-resolves the status map and loops.

Exits when every `requiredForCompletion: true` phase is APPROVED.

## Preconditions

- `.claude/greenfield-state.json` exists with `phase0` answers (Step 0 done).
- `phase-graph.json` is at `${CLAUDE_PLUGIN_ROOT}/skills/visual-companion/references/phase-graph.json`.

## Step 0 — Env-var rollback

If `GREENFIELD_VISUAL_COMPANION=0` is set, skip the visual companion and exit. The caller (`start` skill) then dispatches the linear wizard:

```bash
if [ "${GREENFIELD_VISUAL_COMPANION:-1}" = "0" ]; then
  echo "Visual companion disabled via env var. Falling through to linear wizard."
  exit 0
fi
```

## Step 1 — Detect Python 3, fall through if missing

Run:

```bash
command -v python3 >/dev/null 2>&1 \
  || (command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q '^Python 3') \
  || echo "no-python3"
```

If output is `no-python3`, write `.claude/greenfield-state.json` checkpoint `phase: "context-gathering-linear"`, print a one-line notice, and exit cleanly. The `start` skill catches this and dispatches the linear wizard.

## Step 2 — Render initial status map

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-phase-status.sh" \
  --graph "${CLAUDE_PLUGIN_ROOT}/skills/visual-companion/references/phase-graph.json" \
  --state .claude/greenfield-state.json \
  > .claude/greenfield-ui-state.json.tmp
mv .claude/greenfield-ui-state.json.tmp .claude/greenfield-ui-state.json
```

## Step 3 — Spawn the server

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/serve-companion.sh" \
  --state .claude/greenfield-ui-state.json \
  --intent .claude/greenfield-ui-intent.json \
  --port-file .claude/greenfield-ui-port.txt \
  --pid-file .claude/greenfield-ui-server.pid
```

If exit code is 4 (Python missing) or 5 (port bind failure), record the failure in greenfield-state.json and fall through to linear wizard.

Tell the user (verbatim):

```
Visual companion is open at <URL>. Click an AVAILABLE phase in the browser to start it.
You can also type a phase name here if you'd rather use the CLI.
```

## Step 4 — Wait-for-intent loop

Loop until completionPolicy says we're done:

1. Check `.claude/greenfield-ui-intent.json` exists. If yes, read it and `rm` it.
2. Otherwise, check `.claude/greenfield-ui-state.json` — if `.completionPolicy.canAdvanceToScaffold == true`, break out. Go to Step 5.
3. Otherwise `sleep 2` and ask the user every 30s if they'd like to type a phase name (avoids spam).
4. When an intent or text input arrives, set `currentPhase` in `.claude/greenfield-state.json`, set `contextGatheringMode: "single-phase"`, and invoke `context-gathering` via the Skill tool.
5. On phase completion (synthesis approved or skipped), unset `currentPhase` and re-run the resolver to refresh `.claude/greenfield-ui-state.json`. Loop.

Every state-file mutation uses `.tmp` + `mv` atomic write.

## Step 5 — Shutdown

When the loop exits:

1. POST `/shutdown` to the server (read PORT from `.claude/greenfield-ui-port.txt`):
   ```bash
   PORT=$(cat .claude/greenfield-ui-port.txt 2>/dev/null) && \
     curl -sS -X POST "http://localhost:$PORT/shutdown" >/dev/null 2>&1 || true
   ```
2. If server still alive after 1s, `kill $(cat .claude/greenfield-ui-server.pid)`.
3. Remove `.claude/greenfield-ui-port.txt`, `.claude/greenfield-ui-server.pid`, `.claude/greenfield-ui-intent.json`.
4. Leave `.claude/greenfield-ui-state.json` in place (handy for `/greenfield:check`).
5. Update greenfield-state.json: `phase: "phase-1.7-grill-spec"`. Return control to `start`.

## Error handling

| Trigger | Action |
|---|---|
| Python missing | Fall through to linear wizard. |
| Port bind failure | Fall through to linear wizard. |
| SSH session detected | Companion still spawns; user gets `ssh -L` hint. |
| Browser closed mid-session | Loop continues; user can type phase names or re-open. |
| Server pid stale | `serve-companion.sh` re-spawns automatically. |
| Step 0 inconsistency surfaced mid-phase | Phase Q-bank prints warning; user can re-run `/greenfield:pickup --reset phase0`. |

## Resume from pickup

`/greenfield:pickup` invokes this skill with the existing greenfield-state.json. The skill respawns the server (new port if needed), re-renders the status map, re-enters the wait-for-intent loop.

## Files this skill touches

- READS: `.claude/greenfield-state.json`, `${CLAUDE_PLUGIN_ROOT}/skills/visual-companion/references/phase-graph.json`
- WRITES: `.claude/greenfield-ui-state.json`, `.claude/greenfield-ui-port.txt`, `.claude/greenfield-ui-server.pid`
- READS (transient): `.claude/greenfield-ui-intent.json` (rm after read)
- INVOKES: `context-gathering` (single-phase mode), `serve-companion.sh`, `resolve-phase-status.sh`

## Key Rules

- Never the only path. Linear wizard is always reachable.
- Single source of truth is `greenfield-state.json`; UI state is derived.
- `serve-companion.sh` exit 4 means Python missing; 5 means port bind failed. Treat both as "fall through to linear".
- Don't block the loop on browser activity. Every 30s, offer CLI override.
- Atomic writes mandatory (`.tmp` + `mv`).
- See `references/escape-hatch.md` for the manual SSH workflow.
