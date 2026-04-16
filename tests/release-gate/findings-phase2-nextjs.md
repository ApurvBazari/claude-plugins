# Phase 2 Findings — test-nextjs `/onboard:init`

Date: 2026-04-16
Profile: Custom (full wizard, all options enabled)

## Verification Results

**14 pass, 13 warn, 6 fail** out of 33 checks.

### Failures (blocking)

| ID | Issue | PR | Details |
|---|---|---|---|
| F1 | `.mcp.json` not generated | #35 | Expected context7 + vercel + prisma entries. File missing entirely. |
| F2 | Agent YAML frontmatter missing | #36 | 5 agents generated, 0 with `---` frontmatter. All in markdown-sections format. |
| F3 | Output styles phase skipped | #37 | No `.claude/output-styles/` directory. No snapshot. No telemetry key. |
| F4 | LSP phase skipped | #38 | No `.claude/onboard-lsp-snapshot.json`. No CLAUDE.md LSP section. No telemetry key. |
| F5 | Built-in skills phase skipped | #39 | No `.claude/onboard-builtin-skills-snapshot.json`. No CLAUDE.md section. No telemetry key. |
| F6 | MCP snapshot missing | #35 | No `.claude/onboard-mcp-snapshot.json`. |

### Root cause hypothesis

Wizard ran out of exchange budget and deferred agent tuning, output style, LSP, and built-in skills to "smart defaults." The generation pipeline's deferred-defaults path appears to skip the corresponding generation phases entirely rather than applying defaults. The MCP phase (#35) should have fired regardless of wizard choices since it's signal-driven, not wizard-gated.

### Warnings (non-blocking)

- `mcp-setup.md` missing (consequence of F1)
- 5 of 6 snapshots missing (consequences of F1, F3-F5)
- 3 telemetry keys missing (outputStyleStatus, lspStatus, builtInSkillsStatus)
- CLAUDE.md missing built-in skills, LSP, and output style sections

## UX Observations

| ID | Issue | Severity | Details |
|---|---|---|---|
| O1 | Plugin agents lack frontmatter + color | Medium | `onboard/agents/codebase-analyzer.md`, `config-generator.md`, `feature-evaluator.md` and `forge/agents/scaffold-analyzer.md`, `stack-researcher.md` — all in markdown-sections format, no `color` field. Agents run without color labels in the UI. |
| O2 | AskUserQuestion not used consistently | Medium | Wizard falls back to inline text questions instead of structured option buttons. UX is "type 2" instead of click-to-select. |
| O3 | Multi-select not specified where needed | Medium | "Which advanced hook events?" needs `multiSelect: true` but appears as sequential single choices. |
| O4 | Config-generator lacks step progress | Low | No TaskCreate/TaskUpdate usage. User sees "Initializing..." then sudden completion. Feature-dev shows numbered progress by comparison. |
| O5 | Notify setup offered when globally configured | Medium | Wizard doesn't check for existing global `~/.claude/notify-config.json` or global hook entries before offering project-local notify setup. |
| O6 | `/onboard:init` autocomplete discovery | Low | Command only appears when typing `/init`, not when typing `/onboard:init`. Likely a Claude Code autocomplete prefix matching behavior, not a plugin bug. |

## What worked well

- Analysis phase (codebase-analyzer) correctly detected Next.js + Prisma + Vercel + Supabase stack
- Wizard captured all preferences through 6 exchange rounds
- Hook schema uses correct nested format (PR #32 fix applied)
- 7 hook events configured, including 3 expanded events (UserPromptSubmit, PreCompact, TaskCompleted)
- 23 artifacts generated and verified on disk by the agent
- Notify plugin setup completed (hooks + config + script copied)
- Session started cleanly after generation
