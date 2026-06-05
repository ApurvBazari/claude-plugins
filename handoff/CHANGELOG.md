# Changelog

## 1.0.0
- Stability milestone — handoff is promoted to 1.0.0. The public surface (the four skills `save` / `pickup` / `check` / `discard`, the SessionStart resume hook, and the `.claude/handoff/` folder layout) is now considered stable; breaking changes from here bump the major version. No functional changes since 0.2.0.

## 0.2.0
- Folder-layout migration: handoffs now live under `.claude/handoff/` (an `active.md` plus an archive) instead of a single flat file. Adds a staleness threshold that auto-archives old handoffs and a retention cap. (#56)
- Progressive-disclosure refactor: SKILL.md set slimmed with detail pushed into references; the resume path routes through `/handoff:pickup` with the four-option flow (Execute / Edit / Discard / Save-for-later), and `/handoff:check` provides a read-only inspector. (#56)
- SessionStart hook surfaces a saved handoff at the next session start; directive content is wrapped in untrusted-source framing so routing/metadata is trusted but the directive itself is treated as data.

## 0.1.0
- Initial release. `/handoff:save` captures session intent (auto-invoked on end-of-session phrases, confirmed via `AskUserQuestion` before writing); a SessionStart hook surfaces the saved handoff in the next session. User- and intent-invokable.
