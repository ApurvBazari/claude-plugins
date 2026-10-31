# Changelog

## 1.1.0 — 2026-10-31

### Changed
- **The SessionStart hook only announces a saved handoff; it no longer prints the file.** It checks that `.claude/handoff/active.md` exists and is not snoozed, then emits one fixed notice that routes to `/handoff:pickup`. The notes, frontmatter and progress signals never reach Claude's context from the hook. Before, the hook printed the directive inside `<untrusted-source>` tags and the frontmatter values in a "trusted" block, unescaped — so a handoff committed to a cloned repository could close the tag or plant text in the trusted block. The new hook has no shell variables, no command substitution and calls no other file, which is what Anthropic's plugin directory requires of hook scripts in a plugin that lives in a subfolder of its repository.
- **`/handoff:pickup` now does what the hook used to do.** It reads the file, computes progress (commits since the save, branch change, age), archives a handoff older than `stale-day-threshold` as `expired`, shows the notes as data, and warns when the handoff file is committed to git (someone else may have written it). The four-option flow is unchanged.
- **Snooze is a marker file.** "Save for later" (new `scripts/snooze.sh`) still writes `deferred-at`, and now sets `.claude/handoff/snooze-until`'s modification time to the end of the window (`deferral-snooze-hours`, default 24, capped at one year). The hook stays quiet while that time is in the future. A `deferred-at` without the marker no longer snoozes: a handoff you snoozed with 1.0.x is offered once more at the next session start.
- **One archive path.** New `scripts/archive-active.sh` moves the active handoff to `archive/<consumed|discarded|expired>-<ts>.md`, clears the snooze marker and applies `archive-retention`. Pickup and `/handoff:discard` both use it.
- **`/handoff:save` says what it writes** in its description (`.claude/handoff/active.md`, and `.gitignore` when you accept), clears an old snooze marker so a new handoff is offered at the next session start, and now offers to create `.gitignore` when the project is a git repository without one.
- **`/handoff:check`** reads the snooze from the marker with the same test as the hook, and reports whether the handoff file is committed to git.
- Hook command quotes the whole path: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"`.
- Manifest adds `homepage`, `documentationUrl`, `supportUrl`, `privacyPolicyUrl` and `author.url`; the plugin folder now ships its own `LICENSE`. The README now starts with what the plugin reads, writes and sends, and where it works.

### Removed
- `hf_get_body` from `scripts/handoff-lib.sh` (nothing extracts the body in shell any more).

### Added
- **Listing icon and display name.** A 512 px PNG icon for Anthropic's plugin directory, drawn from what handoff does (its SVG source sits beside it in the assets folder), and the display name "Handoff".

## 1.0.3 — 2026-09-15

### Changed
- **Plugin-root `CLAUDE.md` renamed to `CONVENTIONS.md`.** Claude Code never loads a `CLAUDE.md` at a plugin root as project context, so the file was inert weight in the shipped payload and `claude plugin validate --strict` flagged it on every plugin. The content is unchanged — it is the internal conventions doc for developing this plugin — it just no longer claims a filename the runtime reserves for project context. `handoff` now passes `claude plugin validate --strict` clean.

## 1.0.2 — 2026-07-03

### Fixed
- Hook timeout was `3000` (read as 50 minutes; the unit is seconds) — now `10s` so a hung hook can't block session start. (H1)
- `compute-progress.sh` mis-read frontmatter when the directive body contained a `---` horizontal rule (naive toggle parser); it now shares one correct reader with the hook and prune. (H2, H7)
- `merge-fm-key.sh` silently no-op'd on a file with no frontmatter (a "Save for later" snooze could be lost with no error); it now exits non-zero with a message. (H3)
- pickup **Edit** no longer tries to spawn `$EDITOR` (which hangs a non-interactive session) — it revises the directive conversationally, mirroring save. (H4)
- `archive-retention: null` (and `-1`) now normalize to `unlimited` consistently across the check display and the prune behavior (they previously disagreed — check showed `10`, prune kept everything). (H6)
- Hook: a future `deferred-at` no longer suppresses the handoff forever; the stale auto-archive note is only emitted when the archive move actually succeeds. (H9)

### Changed
- Frontmatter reading, body extraction, ISO parsing, and retention normalization consolidated into one shared `handoff/scripts/handoff-lib.sh`, sourced by the hook, `compute-progress.sh`, and `prune-archive.sh` (removes three divergent parser copies). (H7)

### Removed
- The `trigger-phrases` setting from the docs — it was never read by any code. The save skill auto-invokes via its skill `description`, not a configurable phrase list. (H5)

### Tests
- New: shared-lib unit tests, cross-script frontmatter agreement, retention agreement (check vs prune), hook snooze paths (incl. future-deferred), settings-override coverage; hooks.json timeout ceiling assertion.

## 1.0.1 — 2026-06-11
- fix: quote ${CLAUDE_PLUGIN_ROOT} in the SessionStart hook command (OR-01 exit-127 guard).
- fix: SK-04 save/pickup/discard descriptions; set -euo pipefail on merge-fm-key.sh; widen compute-progress.sh BSD-date fallback.

## 1.0.0
- Stability milestone — handoff is promoted to 1.0.0. The public surface (the four skills `save` / `pickup` / `check` / `discard`, the SessionStart resume hook, and the `.claude/handoff/` folder layout) is now considered stable; breaking changes from here bump the major version. No functional changes since 0.2.0.

## 0.2.0
- Folder-layout migration: handoffs now live under `.claude/handoff/` (an `active.md` plus an archive) instead of a single flat file. Adds a staleness threshold that auto-archives old handoffs and a retention cap. (#56)
- Progressive-disclosure refactor: SKILL.md set slimmed with detail pushed into references; the resume path routes through `/handoff:pickup` with the four-option flow (Execute / Edit / Discard / Save-for-later), and `/handoff:check` provides a read-only inspector. (#56)
- SessionStart hook surfaces a saved handoff at the next session start; directive content is wrapped in untrusted-source framing so routing/metadata is trusted but the directive itself is treated as data.

## 0.1.0
- Initial release. `/handoff:save` captures session intent (auto-invoked on end-of-session phrases, confirmed via `AskUserQuestion` before writing); a SessionStart hook surfaces the saved handoff in the next session. User- and intent-invokable.
