# Handoff Narration — Phase 7 Education & Handoff

Single source of truth for the developer-facing narration in `/onboard:start` Phase 7. The orchestrator drives the Phase 7 task transitions and the `currentPhase` finalize in `../SKILL.md`; this reference is the education text delivered in order: Explain Key Artifacts → Quick Start Suggestions → Next Steps → Closing.

## Explain Key Artifacts

Briefly explain the most important generated artifacts:

> **What to know about your new setup:**
>
> **CLAUDE.md** — This is your main project context file. Claude reads it every session to understand your project. Review it and tweak anything that doesn't feel right.
>
> **Path-scoped rules** — These activate automatically when Claude works on matching files. For example, your testing rules apply whenever Claude touches test files.
>
> **Skills** — These give Claude expertise for specific tasks in your project. Try asking Claude to [relevant task based on generated skills].
>
> **Agents** — Specialized Claude personas. Try running your [agent name] agent on a recent change.
>
> **Hooks** — Auto-formatting and linting happen in the background. You don't need to think about these.

## Quick Start Suggestions

Based on what was generated, suggest what to try first:

> **Try these first:**
> 1. Open a file in your project and notice how Claude now has context about your conventions
> 2. [Stack-specific suggestion, e.g., "Ask Claude to create a new React component and see how it follows your patterns"]
> 3. [Pain-point based suggestion, e.g., "Ask Claude to write tests for a module you mentioned is error-prone"]

## Next Steps

> **Next steps:**
> - Review `CLAUDE.md` and adjust anything that doesn't match your preferences
> - Review the research artifacts in `docs/onboard/` (or `.claude/onboard-research.json` if you chose local/none) — the dossier, architecture map, risk register, and glossary.
> - Run `/onboard:check` anytime to check the health of your setup
> - Run `/onboard:update` periodically to align with latest Claude best practices
> - All generated files have maintenance headers — Claude will let you know when they need updating

If ecosystem plugins were set up, add:
> - Run `/notify:check` to verify notifications are working

## Closing

> Your project is now set up for AI-assisted development with Claude Code. Happy coding!
