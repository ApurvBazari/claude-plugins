# Agent Teams Guide

How to generate agent team support for scaffolded projects. Agent teams let multiple Claude Code instances work together on complex tasks — a team lead delegates to teammates who work in parallel with a shared task list.

## When to Generate Team Support

| Project type | Generate team support? |
|---|---|
| CLI tool / side project | No — individual agents sufficient |
| Production solo dev | Optional — generate guide only, developer opts in |
| Production team (2-5) | Yes — generate guide + quality hooks |
| Production team (5+) or complex stack | Yes — generate guide + quality hooks + example team compositions |

Check `wizardAnswers.teamSize` and `analysis.complexity.category` to decide.

## What to Generate

### 1. Enable Agent Teams in Settings

Add to `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Merge with existing settings — don't overwrite.

### 2. Team Quality Hooks

Add to `.claude/settings.json` hooks:

```json
{
  "hooks": {
    "TaskCreated": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'INPUT=$(cat); SUBJECT=$(echo \"$INPUT\" | grep -o '\"task_subject\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' | head -1 | sed '\"'\"'s/.*: *\"//;s/\"//g'\"'\"'); if [ ${#SUBJECT} -lt 10 ]; then echo \"Task subject must be descriptive (at least 10 characters). Got: $SUBJECT\" >&2; exit 2; fi; exit 0'"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[TEST_COMMAND] 2>&1 || { echo 'Tests must pass before completing a task. Fix failing tests.' >&2; exit 2; }"
          }
        ]
      }
    ]
  }
}
```

Replace `[TEST_COMMAND]` with the actual test command from the project (e.g., `npm test`, `pytest`, `go test ./...`).

### 3. Team Compositions in CLAUDE.md

Add a "Team Workflows" section to the generated CLAUDE.md:

```markdown
## Team Workflows

This project supports agent teams for complex tasks. Enable with:
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (already configured in settings.json)

### Feature Development Team
For building multi-part features:
- **Lead**: orchestrates work, breaks feature into tasks
- **[plugin] feature-dev:code-explorer**: analyzes existing patterns
- **[plugin] feature-dev:code-architect**: designs the architecture
- **Teammate**: implements based on architecture (file ownership: [stack-specific paths])
- **[plugin] pr-review-toolkit:code-reviewer**: reviews output

### Review Team
For comprehensive PR review:
- **Lead**: coordinates review focus areas
- **[plugin] pr-review-toolkit agents**: code-reviewer, pr-test-analyzer, silent-failure-hunter (parallel)

### Refactor Team
For large-scale refactoring:
- **Lead**: plans the refactor, breaks into migration tasks
- **[plugin] feature-dev:code-explorer**: maps dependencies
- **Teammate 1**: migrates module A (file ownership: src/moduleA/)
- **Teammate 2**: migrates module B (file ownership: src/moduleB/)
- **[plugin] superpowers:verification**: verifies tests pass after each migration
```

### 4. Adapting Compositions to Installed Plugins

The team compositions MUST reference actual installed plugins. Use `callerExtras.installedPlugins` to determine which plugin agents are available:

| If installed | Reference in team compositions |
|---|---|
| `feature-dev` | `feature-dev:code-explorer`, `feature-dev:code-architect`, `feature-dev:code-reviewer` |
| `code-review` | `code-review` command for orchestrated review |
| `pr-review-toolkit` | Individual agents: `code-reviewer`, `pr-test-analyzer`, `silent-failure-hunter`, `type-design-analyzer`, `comment-analyzer`, `code-simplifier` |
| `superpowers` | Skills: `test-driven-development`, `systematic-debugging`, `writing-plans`, `verification-before-completion` |
| `security-guidance` | Passive hook (no agent reference needed) |

If a plugin is NOT installed, omit it from team compositions. Replace with a note: "Consider installing [plugin] for [capability]."

### 5. Gap-Filling Project Agents for Teams

If the project needs capabilities not covered by any installed plugin, generate project-specific agents that can serve as teammates:

**Stack-specific examples:**

| Project has | No plugin covers | Generate agent |
|---|---|---|
| Prisma/Drizzle database | DB migration workflow | `db-migration.md` — handles schema changes, migration generation, seed data |
| API with OpenAPI | API documentation | `api-docs-generator.md` — generates/updates OpenAPI spec from routes |
| Monorepo | Cross-package coordination | `package-coordinator.md` — ensures changes are consistent across packages |
| i18n enabled | Translation management | `i18n-checker.md` — validates translation completeness across locales |

These agents should be designed as team-ready: clear file ownership boundaries, focused responsibilities, appropriate tool restrictions.

## Agent Definition Format for Teammates

When generating agents that may be used as teammates, include these frontmatter fields:

```markdown
---
name: db-migration
description: Handles database schema changes, migration generation, and seed data management
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
model: sonnet
color: purple
---
```

Key considerations:
- **model: sonnet** — recommended for teammates (cost-effective)
- **color** — assign distinct colors so teammates are visually distinguishable
- **tools** — be specific; restrict to what the agent actually needs
- **description** — must clearly state when to delegate to this agent (Claude uses this to auto-delegate)

## Best Practices

1. **3-5 teammates per team** — more adds coordination overhead without proportional benefit
2. **5-6 tasks per teammate** — keeps everyone productive without overloading
3. **File ownership** — each teammate should own different files to avoid overwrites
4. **Sonnet for teammates** — reserve Opus for the lead if complex reasoning needed
5. **Task dependencies** — use dependencies to enforce ordering (e.g., tests after implementation)
6. **Quality hooks enforce standards** — TaskCompleted hook requiring passing tests prevents sloppy work
7. **Reference plugin agents by name** — don't recreate what plugins already provide
