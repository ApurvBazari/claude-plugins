# handoff — Internal Conventions

Save and resume session handoffs. Closest existing plugin in shape is `notify/` (small, skills + one hook + optional settings file).

## Locked design dimensions

| Dimension | Choice | Reason |
|---|---|---|
| **Storage** | `.claude/handoff/active.md` (single active slot, in-repo, with an `archive/` subfolder) | Single source of truth, simple, gitignore handles privacy |
| **Save trigger** | NL detection → confirm via AskUserQuestion → write | Auto-save with a confirm gate; false positives are zero-cost |
| **Resume flow** | SessionStart hook announces → Claude invokes `/handoff:pickup` → pickup reads the file → 4-option AskUserQuestion (Execute / Edit / Discard / Save-for-later) | User stays in control; no implicit action on the notes |
| **Content** | Directive prose only — no embedded state (commits, branches, tasks) | State is derivable from git/memory/files at resume time; the directive captures intent only |
| **Trust model** | The hook never prints the file; pickup shows it as data; surface-and-confirm | A handoff can arrive with a clone, so its text is never placed in context as instructions |

## Hook event model

Single hook: `SessionStart` (any source — startup / resume / clear / compact).

Registered in `hooks/hooks.json` as `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"` (the whole path quoted once). Claude Code activates it when the plugin is enabled; no setup step.

### The hook is announce-only

`hooks/session-start.sh` decides one thing — is there an unsnoozed handoff? — and prints either nothing or one fixed JSON line:

```json
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"A saved handoff exists at .claude/handoff/active.md in this project. Run /handoff:pickup now. …"}}
```

The text is a constant. It does not depend on the file's contents, so nothing a file author writes can reach Claude through the hook.

### Directory rules the hook script must keep

The plugin lives in a subfolder of its repository. Anthropic's plugin directory then holds a plugin for a reviewer ("Scripts the validator couldn't follow") when a script a hook runs contains:

- a shell variable other than `${CLAUDE_PLUGIN_ROOT}` — including `$PWD`, `$1`, `$?`
- command substitution (`$(…)` or backticks)
- a call to another file in the plugin, or sourcing one
- a package launcher or package install

So the hook uses only fixed paths relative to its working directory (Claude Code runs hooks in the session's current directory), `[[ -f … ]]`, `find … -newermt now`, `grep -q` and `printf`. `tests/handoff/test_hook_static_rules.sh` pins this. Anything that needs a variable belongs in a script the **pickup skill** runs — skill-run scripts are not part of that check.

## Stale handling (R4 Option E — git activity + time backstop)

`scripts/compute-progress.sh` computes the signals; `/handoff:pickup` acts on them.

| Signal | Source | Threshold (default) |
|---|---|---|
| `commits_past` | `git rev-list --count <saved-at-sha>..HEAD` | ≥ 3 → tag `progress-made` |
| `branch_changed` | `git branch --show-current` vs frontmatter `saved-at-branch` | `yes` → tag `branch-changed` |
| `days_old` / `stale` | now vs frontmatter `saved-at` | ≥ 90 → pickup archives as `archive/expired-<ts>.md` with a one-line note |

The first two are tags shown to the user; they don't change behavior. The third is a hard cap, applied by pickup before the 4-option prompt. Thresholds are overridable in `.claude/handoff/settings.md` (`stale-commit-threshold`, `stale-day-threshold`); non-integers fall back to the default.

## Snooze mechanism

"Save for later" runs `scripts/snooze.sh`, which:

1. writes `deferred-at: <now>` into the handoff frontmatter (a record, kept for `/handoff:check`), and
2. sets the modification time of `.claude/handoff/snooze-until` to now + `deferral-snooze-hours` (default 24, capped at 8760).

The hook stays silent while that marker's mtime is in the future (`find … -newermt now`). `compute-progress.sh` uses the same test, so `/handoff:check` and the hook cannot disagree. If `find` cannot evaluate the test, the hook announces — it fails open, never silently hiding a handoff.

A `deferred-at` without the marker never snoozes (this also covers the H9 case: a future `deferred-at` cannot suppress the handoff forever). A new save, an Edit, and every archive remove the marker.

## Gitignore handling (R3 hybrid)

On the first save in a repo, the save skill:

1. Skips if the project is not a git repository, or if `.gitignore` already contains `.claude/handoff/`.
2. Otherwise asks via AskUserQuestion: **Add pattern automatically / Skip (I'll add it) / Don't ask again**. When `.gitignore` does not exist yet, **Add** creates it.
3. Persists a skip in `.claude/handoff/settings.md` frontmatter (`gitignore-prompt: never`).

## Archive retention

A single integer cap (`archive-retention`, default 10) limits the total file count across `.claude/handoff/archive/`. Consumed, discarded and expired archives share one budget.

Every archive goes through `scripts/archive-active.sh <root> <consumed|discarded|expired>`, which moves the file, clears the snooze marker, then runs `scripts/prune-archive.sh`. Callers: pickup (Execute, Discard, stale) and `/handoff:discard`.

| Value | Behavior |
|---|---|
| `0` | every archive write is followed by removal of all files in `archive/` |
| `unlimited` (or `-1`, `null`) | prune is skipped |
| any positive integer | newest N files survive (mtime ordering); the rest are deleted |

The retention prompt fires on first save only — its trigger is the absence of the `archive-retention` key in `.claude/handoff/settings.md`. The four options (Default 10 / 5 / 20 / Don't ask again) all write a definite key; "Default 10" and "Don't ask again" produce the same effective value.

## Cwd guard (R8)

The save skill records `saved-from-cwd`. Pickup compares it with the current directory (`cwd_match` from `compute-progress.sh`) and asks the user to reconfirm on a mismatch before the 4-option prompt.

## NL trigger (save)

The save skill auto-invokes when the user says a wrap-up phrase ("save handoff", "pick this up later", "continue in a new session", "I'll come back to this", …). This is driven by the skill's `description` frontmatter; there is no phrase list in code. Because the save flow is gated by an AskUserQuestion confirm, loose matching is harmless — false positives cost one click.

## Skills

User-facing skills (show in `/handoff:` autocomplete):

- `save/SKILL.md` — auto-invokable on NL trigger; confirms via AskUserQuestion before writing.
- `pickup/SKILL.md` — auto-invokable when the hook announces a handoff; reads the file, archives stale ones, presents the 4-option flow.
- `check/SKILL.md` — auto-invokable; read-only inspector.
- `discard/SKILL.md` — `disable-model-invocation: true`; explicit discard.

No internal building blocks (no `user-invocable: false` skills).

## Scripts

| Script | Run by | Style |
|---|---|---|
| `hooks/session-start.sh` | the SessionStart hook | announce-only; see the directory rules above; always `exit 0` |
| `scripts/compute-progress.sh` | pickup, check | emits `key=value` lines via `printf '%q'` (eval-safe); always `exit 0` |
| `scripts/archive-active.sh` | pickup, discard | utility (`set -euo pipefail`); prints the archive path |
| `scripts/snooze.sh` | pickup (Save for later) | utility; prints `snoozed-until=<iso>` |
| `scripts/merge-fm-key.sh` | save, snooze.sh | utility; fails loudly on a file with no frontmatter |
| `scripts/prune-archive.sh` | archive-active.sh | hook style (no `set -e`) |
| `scripts/handoff-lib.sh` | sourced by compute-progress, prune-archive, snooze | pure functions; frontmatter reader, ISO parser, retention normalizer |

All scripts: `#!/usr/bin/env bash`, ShellCheck-clean, BSD and GNU compatible (`date -d @…` / `date -r …`, `stat -c %Y` / `stat -f %m`, `touch -d <ISO>`). Frontmatter is parsed with awk — no YAML library.

## Threat model recap

Defense layers, in order:

1. **Announce-only hook** — the file's text never enters context from the hook.
2. **Pickup shows the notes as data** and flags a handoff that is committed to git.
3. **Resume confirm flow** — the user picks Execute / Edit / Discard / Save-for-later before anything happens (locked dimension 3); risky steps still need the user's normal confirmation.
4. **Cwd verification** before the prompt (R8).
5. **Gitignore prompt** on first save (R3) — makes an accidental commit unlikely.

| Vector | Mitigation |
|---|---|
| A handoff arrives with a clone or a pull | The hook only says a file exists; pickup shows it as data, warns that it is tracked by git, and waits for the user's choice |
| Hostile frontmatter or settings values | `compute-progress.sh` validates thresholds and emits everything via `printf '%q'`; tests pin `$(…)` / backtick canaries |
| User on a multi-tenant machine | uid implicit via filesystem permissions on `~/.claude` and the project dir — standard Unix semantics |
| Compromised local editor injects content | Out of scope — anyone with write access to `.claude/` can already inject anywhere |

Stronger options (file integrity checks, signatures) were considered and declined: surface-and-confirm is the real defense; cryptographic checks add complexity for negligible gain.
