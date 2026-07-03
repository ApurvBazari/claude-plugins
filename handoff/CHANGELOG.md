# Changelog

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
