# Phase 4 Findings — Drift Lifecycle (`/onboard:update`)

Date: 2026-04-16
Target: test-nextjs (post-Phase 2 init + 4 mutations applied)

## Verification Results

**7 pass, 2 warnings, 0 failures.**

## What worked

| Mutation | Expected | Result |
|---|---|---|
| Deleted 3 rule files (testing, components, prisma) | Detect as Artifact Gap, offer regenerate | PASS — all 3 regenerated on "all" approval |
| Edited code-reviewer agent model → haiku | Classify as user-edit, preserve | PASS — haiku preserved, snapshot updated |
| Added @anthropic-ai/sdk to package.json | Flag /claude-api as newly relevant | PASS — detected, added to CLAUDE.md tech stack + builtInSkillsStatus |
| Added src/main.rs (Rust file) | Flag rust-analyzer-lsp as newLanguage | PARTIAL — detected and mentioned in report, but LSP was offered as optional (not auto-flagged) |

## Bonus behaviors (not in mutations but observed)

- Update proactively offered `$schema` addition to settings.json (best practice)
- Update proactively offered `permissions.deny` for `.env` files (security)
- Created `onboard-skill-snapshot.json` baseline (missing from init due to F3)
- Created `onboard-builtin-skills-snapshot.json` baseline (missing from init due to F5)
- Added `builtInSkillsStatus` to onboard-meta.json with detection signals
- Added `updateHistory` array tracking all 10 changes

## Warnings

1. Output style body edit not testable — no output styles generated in Phase 2 (F3)
2. `builtInSkillsStatus` created by update but doesn't use the exact key format the verify script checks for

## Observations

- Update detected the agent frontmatter drift correctly via the agent snapshot (even though agents lack YAML frontmatter — the snapshot records the intended fields)
- Update fetched live Claude Code docs (code.claude.com) to check for best practice gaps — proactive behavior
- The update report is comprehensive and well-structured with tables
- Update used the same inline text question pattern as init (O2) — "Which updates would you like me to apply? (all / specific numbers / none)" instead of AskUserQuestion multiSelect
- No colors on the Explore agents (O1 carries forward)

## Overall Assessment

The drift lifecycle works well. The update subsystem correctly:
- Detects missing artifacts (Artifact Gap)
- Classifies user edits (preserves them)
- Detects new dependencies and language files
- Establishes missing snapshots retroactively
- Proactively suggests best practice improvements
- Maintains an updateHistory audit trail

The main gaps are consequences of init-phase failures (F1-F5), not update-phase bugs.
