# Manual intent-file editing (SSH / headless escape hatch)

When the browser can't reach the companion (SSH without port-forward, dev container, headless server) the user can drive the wait-for-intent loop by editing the intent file directly.

## Workflow

1. Look at `.claude/greenfield-ui-state.json` to see which phases are `AVAILABLE`.
2. Write a one-line intent file:
   ```bash
   echo '{"action":"activate","phase":"dataArchitecture"}' > .claude/greenfield-ui-intent.json
   ```
3. Claude's loop picks it up within ~2 seconds and invokes the phase's Q-bank.

## Schema

```jsonc
{
  "action": "activate",
  "phase": "<phase-key from phase-graph.json>",
  "ts": <unix seconds, optional>
}
```

Any other shape is rejected.

## Why this exists

- SSH without `ssh -L` port-forwarding.
- Dev containers / CI sandboxes that block browser launch.
- Recovering from a server crash without restarting `/greenfield:pickup`.

`/greenfield:check` honours a manually-written intent file the same as a browser-driven click.
