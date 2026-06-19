<!-- Extracted from ../../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Plugin-Aware TDD Workflow + Recommended Plugins

### Plugin-Aware TDD Workflow

All projects use TDD (red-green-refactor). Generation adapts based on which workflow plugins are installed. Resolve installed plugins from `effectivePlugins` (see Effective Plugin List Resolution above).

| superpowers? | feature-dev? | Strategy |
|---|---|---|
| Yes | Yes | Reference both: `superpowers:test-driven-development` for implementation, `feature-dev` phases for discovery/design/review. No standalone TDD artifacts. TDD Feature Development team if teams enabled. |
| Yes | No | Reference superpowers TDD skill in CLAUDE.md + testing.md. Standalone workflow guidance for discovery/design/review phases. Recommend installing feature-dev. |
| No | Yes | Reference feature-dev for phases 1-4 & 6. Generate standalone TDD skill + TDD test-writer agent. Recommend installing superpowers. |
| No | No | Recommend both plugins. Fully self-contained: standalone TDD skill, TDD test-writer, inline workflow guidance. |

**Key principles**:
- Never duplicate what an installed plugin provides
- When a plugin is missing, recommend it AND generate standalone fallback
- Add "Recommended Plugins" section to CLAUDE.md when any plugin is missing
- When superpowers is installed, its TDD skill is authoritative — do not generate a competing `.claude/skills/tdd-workflow/SKILL.md`

**Plugin recommendation message** (shown during generation when plugins are missing):

> For the best TDD workflow, install these plugins:
>
> - **superpowers** (`obra/superpowers`) — Full TDD skill with red-green-refactor enforcement, verification gates, and anti-pattern detection. Install: `claude plugins add obra/superpowers`
> - **feature-dev** (official Anthropic plugin) — Structured feature development with code-explorer, code-architect, and code-reviewer agents. Install: `claude plugins add anthropic/feature-dev`
>
> Generating standalone TDD artifacts as fallback...

Only show recommendations for plugins that are actually missing. If both are installed, skip this entirely.

**CLAUDE.md "Recommended Plugins" section** (only when plugins are missing):

```markdown
## Recommended Plugins

This project uses TDD. Install these plugins for the best workflow:

- **superpowers** (`obra/superpowers`) — Full TDD skill with red-green-refactor
  enforcement, verification gates, and testing anti-patterns guide.
- **feature-dev** (official Anthropic plugin) — Structured feature development
  with code-explorer, code-architect, and code-reviewer agents.

After installing, re-run `/onboard:start` to upgrade from standalone TDD
artifacts to the integrated plugin-based workflow.
```
