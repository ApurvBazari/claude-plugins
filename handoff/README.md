# handoff

> Part of [`claude-plugins`](../README.md) — see also [`onboard`](../onboard/) and [`notify`](../notify/).

Save the directive of a wrap-up session, then surface it at the start of the next one. Replaces the manual "paste a prompt into the new window" workflow with an auto-save + confirm-on-resume loop.

## Install

```bash
claude plugin install handoff@apurvbazari-plugins
```

That's it. Nothing else to configure — the SessionStart hook ships inside the plugin and activates automatically.

## Skills

All skills are invoked as `/handoff:<name>`. Two are auto-invokable (`save`, `pickup`); two require explicit invocation (`check` is auto-invokable but read-only; `discard` is destructive).

### `/handoff:save`

Auto-invokes when you say a wrap-up phrase like *"save handoff"*, *"pick this up later"*, *"continue in new session"*, or *"I'll come back to this"*. Surfaces an AskUserQuestion to confirm before writing — false positives cost one click. The slash form is the no-confirm fallback.

The skill writes a directive (what the next session should pick up) to `.claude/handoff/active.md` with frontmatter capturing `saved-at`, `saved-at-sha`, `saved-at-branch`, and `saved-from-cwd`. On the first save in a repo, it prompts to add `.claude/handoff/` to `.gitignore`.

### `/handoff:pickup`

Auto-invokes after the SessionStart hook surfaces a saved handoff. Asks via AskUserQuestion:

| Choice | What happens |
|---|---|
| **Execute** | I act on the directive, then archive the file to `.claude/handoff/archive/consumed-<ts>.md` |
| **Edit** | Open the directive in `$EDITOR`, re-surface for another confirm |
| **Discard** | Archive to `.claude/handoff/archive/discarded-<ts>.md` without acting |
| **Save for later** | Leave the file in place; snooze for 24h so the next session-start doesn't re-surface immediately |

### `/handoff:check` *(read-only)*

Show whether a saved handoff exists, its age, the saved-at SHA/branch, and how far the repo has moved past it (commits, branch changes). Useful as a sanity check before a session-start, or to diagnose "why isn't this surfacing?".

### `/handoff:discard` *(destructive — user-invoked only)*

Archive the active handoff without acting on it. Same effect as picking **Discard** in `/handoff:pickup`, but invocable from anywhere.

## SessionStart hook

The plugin registers a SessionStart hook (`hooks/session-start.sh`) automatically — no setup step. On every session start:

1. Read `.claude/handoff/active.md` if present. If absent, exit silent.
2. Parse frontmatter (`saved-at`, `saved-at-sha`, `saved-at-branch`, `saved-from-cwd`).
3. Compute age in days, commits past `saved-at-sha`, branch change.
4. **Stale auto-archive**: if older than the configured `stale-day-threshold` (default 90 days), move to `.claude/handoff/archive/expired-<ts>.md` and surface a one-line note.
5. **Snooze check**: if `deferred-at` is within `deferral-snooze-hours` (default 24), exit silent.
6. Otherwise, emit `additionalContext` to the session: routing instruction + metadata + directive wrapped in `<untrusted-source>` framing.

Claude then invokes `/handoff:pickup`, which presents the four-option AskUserQuestion.

## Configuration

Optional settings file at `.claude/handoff/settings.md`. If absent, defaults apply. Frontmatter:

```yaml
---
stale-commit-threshold: 3        # commits past saved-at-sha → tag as "progress made"
stale-day-threshold: 90          # days past saved-at → silent auto-archive
deferral-snooze-hours: 24        # hours to suppress re-surface after "Save for later"
gitignore-prompt: ask            # ask | never
archive-retention: 10            # cap on archive/ file count (special: 0, "unlimited")
trigger-phrases:                 # additions/overrides for save NL trigger
  - "save handoff"
  - "pick this up later"
  - "continue in new session"
  - "handoff this"
  - "I'll come back to this"
---
```

Edit the file directly — changes take effect on the next save / SessionStart.

## Storage model

| Path | Purpose |
|---|---|
| `.claude/handoff/active.md` | The active handoff. One per repo (single-slot). |
| `.claude/handoff/archive/consumed-<ts>.md` | Archived after Execute. |
| `.claude/handoff/archive/discarded-<ts>.md` | Archived after Discard or `/handoff:discard`. |
| `.claude/handoff/archive/expired-<ts>.md` | Archived after `stale-day-threshold` exceeded. |
| `.claude/handoff/settings.md` | Optional user-editable settings. |

Add `.claude/handoff/` to `.gitignore` (the first save offers to do this for you).

## Upgrading from 0.1.x

`0.2.0` moves every artifact into a dedicated `.claude/handoff/` directory.
Plugin code only knows the new layout — there is no automatic detection of
0.1.x files. Run this one-liner once per repo to migrate:

```bash
mkdir -p .claude/handoff/archive
[ -f .claude/handoff.md ]          && mv .claude/handoff.md          .claude/handoff/active.md
[ -f .claude/handoff-settings.md ] && mv .claude/handoff-settings.md .claude/handoff/settings.md
mv .claude/handoff.consumed-*.md   .claude/handoff/archive/ 2>/dev/null || true
mv .claude/handoff.discarded-*.md  .claude/handoff/archive/ 2>/dev/null || true
mv .claude/handoff.expired-*.md    .claude/handoff/archive/ 2>/dev/null || true
```

Then update `.gitignore` — replace the line

```
.claude/handoff*.md
```

with

```
.claude/handoff/
```

If you forget the gitignore step, the next save offers to add the new pattern.

## Trust model

The SessionStart hook wraps directive content in `<untrusted-source>` tags. The directive is presented as data describing user intent, not as instructions to act on. The four-option AskUserQuestion flow ensures the user confirms any action — even on Execute, I treat the directive as guidance for *me* to apply judgement, not commands to mechanically run.

If you don't recognize a saved handoff in your repo (e.g., someone else committed it), pick **Discard** and investigate. With `.claude/handoff/` in `.gitignore`, this is unlikely — but defense-in-depth matters for a publicly-installable plugin.

## Edge cases

- **No `.claude/handoff/` directory** → save creates it (`mkdir -p`). Resume hook exits silent if no `active.md`.
- **`saved-at-sha` no longer exists** (force-push, deleted branch) → hook degrades gracefully — surfaces with `(progress: unknown)`.
- **Two Claude sessions in the same repo** → both surface the same handoff; first to **Execute** or **Discard** wins (file is moved). Best-effort; document only.
- **`cd` into a different project mid-session** → the surfaced handoff was captured for the original project. I verify `pwd` against `saved-from-cwd` before acting on Execute.
- **`archive-retention: 0`** → every archive write immediately deletes its file. The hook's expired sweep still moves the file into `archive/` first, so progress messages remain accurate; the file is then removed before the hook returns.
- **NL trigger fires mid-edit** → confirm step ("Save handoff now? [Save / Edit / Cancel]") makes Cancel zero-cost.

## Why this plugin exists

Long Claude Code sessions often end with the user typing a paragraph into the *next* session window to continue the work. That paragraph is reproducible — it's just "the directive of where we left off". This plugin captures it at end-of-session and surfaces it at the start of the next, removing the copy-paste step.

The five locked design choices (auto-save-with-confirm, single active slot, directive-only content, four-option resume flow, surface-and-confirm trust model) are documented in [`handoff/CLAUDE.md`](./CLAUDE.md).

## License

[MIT](../LICENSE)
