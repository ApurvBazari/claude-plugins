# handoff — Internal Conventions

Save and resume session handoffs. Closest existing plugin in shape is `notify/` (small, skill + hook + optional settings file).

## Locked design dimensions

| Dimension | Choice | Reason |
|---|---|---|
| **Storage** | `.claude/handoff/active.md (single active slot, in-repo, with archive/ subfolder)` | Single-source-of-truth, simple, gitignore handles privacy |
| **Save trigger** | NL detection → confirm via AskUserQuestion → write | Auto-save with a confirm gate; false positives are zero-cost |
| **Resume flow** | SessionStart hook surfaces → Claude invokes `/handoff:pickup` → 4-option AskUserQuestion (Execute / Edit / Discard / Save-for-later) | User stays in control; no implicit action on directive |
| **Content** | Directive prose only — no embedded state (commits, branches, tasks) | State is derivable from git/memory/files at resume time; directive captures intent only |
| **Trust model** | `<untrusted-source>` framing + surface-and-confirm | Defense in depth for marketplace distribution |

## Hook event model

Single hook: `SessionStart` (any source — startup / resume / clear / compact).

Hook is registered via `hooks/hooks.json` at plugin root with `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh`. Claude Code auto-discovers and activates it when the plugin is installed; no setup wizard required.

### Hook output contract

The hook emits a single JSON object to stdout per the Claude Code `additionalContext` contract:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<routing-instruction + metadata + directive>"
  }
}
```

The `additionalContext` value contains, in order:

1. **Routing instruction (trusted)** — plain text telling Claude to invoke `/handoff:pickup`. NOT inside `<untrusted-source>`.
2. **Metadata (trusted)** — saved-at timestamps, SHA, branch, cwd, progress tags. NOT inside `<untrusted-source>`.
3. **Directive content (untrusted)** — wrapped in `<untrusted-source description="user-saved handoff directive">…</untrusted-source>`.

Splitting trusted vs untrusted matters: an attacker who lands a malicious `.claude/handoff/active.md` can only influence directive content, not the routing instruction. The framing ensures Claude treats the directive as data describing user intent, not instructions to run.

## Stale handling (R4 Option E — git-activity + time backstop)

Hook computes three progress signals:

| Signal | Source | Trigger threshold (default) |
|---|---|---|
| `commits-past-saved-at` | `git rev-list --count <saved-at-sha>..HEAD` | ≥ 3 → tag as "progress made" |
| `branch-changed` | `git branch --show-current` vs frontmatter `saved-at-branch` | true → tag as "branch changed" |
| `days-old` | now vs frontmatter `saved-at` | ≥ 90 → silent auto-archive to `handoff.expired-<ts>.md` |

The first two are *surface tags* (shown to the user via metadata) — they don't change behavior, they just inform the user's choice in the 4-option AskUserQuestion. The third is a hard cap.

Thresholds are overridable in `.claude/handoff/settings.md` frontmatter (`stale-commit-threshold`, `stale-day-threshold`).

## Snooze mechanism

After "Save for later", the pickup skill writes `deferred-at: <iso8601>` into the existing handoff frontmatter. Hook on next SessionStart:

- If `deferred-at` within `deferral-snooze-hours` (default 24): exit silent (no surface).
- Else: surface as usual.

Prevents the "I deferred this 10 minutes ago, stop nagging" annoyance without permanent suppression.

## Gitignore handling (R3 hybrid)

On the first save in a repo, the save skill:

1. Check if `.gitignore` exists.
2. If yes, check whether it already matches `.claude/handoff/`.
3. If not matched, ask via AskUserQuestion: **Add pattern automatically / Skip (I'll add it) / Don't ask again**.
4. Persist choice in `.claude/handoff/settings.md` frontmatter (`gitignore-prompt: ask | never`).

If `.gitignore` doesn't exist at all (rare for an in-repo case), skip the prompt entirely — no risk of accidental commit if there's no repo.

## Archive retention

A single integer cap (`archive-retention`, default 10) limits the total file
count across `.claude/handoff/archive/`. The cap applies uniformly to
consumed / discarded / expired archives — they share one budget.

Pruning is performed by `handoff/scripts/prune-archive.sh`, invoked from:

- the SessionStart hook immediately after the stale auto-archive sweep, and
- the pickup / discard skills immediately after writing any archive file.

Special values:

| Value | Behavior |
|---|---|
| `0` | every archive write is followed by removal of all files in `archive/` |
| `unlimited` (or `-1`) | prune is skipped |
| any positive integer | newest N files survive (mtime ordering); the rest are deleted |

The retention prompt fires on first save only — its trigger is the absence
of the `archive-retention` key in `.claude/handoff/settings.md`. The four
options (Default 10 / 5 / 20 / Don't ask again) all write a definite key;
"Default 10" and "Don't ask again" produce the same effective value.

## Cwd guard (R8)

The hook captures `cwd` at fire time (from the SessionStart stdin JSON). The save skill captures `saved-from-cwd` in the frontmatter. On Execute, I verify the current `pwd` matches `saved-from-cwd` before acting — if it differs, ask the user to reconfirm.

This catches the "I `cd`'d into a different project mid-session" case without adding a second hook.

## Trigger phrases

Default whitelist (lowercase, substring match against the most recent user message):

- "save handoff"
- "pick this up later"
- "continue in new session"
- "continue in a new session"
- "handoff this"
- "I'll come back to this"
- "I'll continue next session"
- "save for later"

The skill auto-invokes when a phrase matches. User can extend / override the list in `.claude/handoff/settings.md` frontmatter (`trigger-phrases`).

Because the save flow is gated by an AskUserQuestion confirm, the whitelist can be relatively loose without causing harm — false positives are zero-cost.

## Skills

User-facing skills (show in `/handoff:` autocomplete):

- `save/SKILL.md` — auto-invokable on NL trigger; confirms via AskUserQuestion before writing.
- `pickup/SKILL.md` — auto-invokable when hook surfaces metadata; presents the 4-option flow.
- `check/SKILL.md` — auto-invokable; read-only inspector.
- `discard/SKILL.md` — `disable-model-invocation: true`; explicit discard.

No internal building blocks (no `user-invocable: false` skills). Hook script is the only non-skill executable.

## Script safety (R6)

`hooks/session-start.sh` follows hook-script conventions:

- `#!/usr/bin/env bash`
- `set -uo pipefail` (NOT `-e` — we exit 0 on internal errors)
- Always `exit 0` unless explicitly aborting with a logged reason
- All file reads guarded with `[[ -f … ]]` first
- Frontmatter parsed with awk (no YAML library dependency)
- JSON emitted via `jq` if available, plain-text fallback otherwise
- ShellCheck-clean

## JSON / frontmatter parsing

Hook uses jq-with-fallback pattern matching `notify/`'s `json_get()` style. Frontmatter parsing uses a simple awk extractor for known keys — no YAML library dependency.

## Threat model recap

Defense layers, in order:

1. **`<untrusted-source>` framing** wraps the directive content (R9 mitigation A).
2. **Resume confirm flow** — user picks Execute / Edit / Discard / Save-for-later before I act (locked dimension 3).
3. **Cwd verification** on Execute (R8 mitigation A).
4. **Gitignore prompt** on first save (R3 hybrid) — makes accidental commit unlikely.

Threat vectors and mitigations:

| Vector | Mitigation |
|---|---|
| Attacker lands malicious handoff via PR | Gitignore-by-default removes the file from review surface; even if committed, surface-and-confirm + untrusted-source framing prevent silent execution |
| User on multi-tenant machine | uid implicit via filesystem permissions on `~/.claude` and project dir — not enforced by the plugin, but standard Unix semantics |
| Compromised local editor injects content | Out of scope — anyone with write to `.claude/` can already inject anywhere |

R9 stronger options (file integrity checks, signatures) considered and declined: surface-and-confirm is the real defense; cryptographic checks add complexity for negligible gain.

