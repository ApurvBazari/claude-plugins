---
paths:
  - "**/commands/**"
---

# Command Authoring

## File Format

Commands are single markdown files: `commands/<command-name>.md`

## Structure

1. **H1 title**: `# /plugin:command — Short Description`
2. **Overview**: brief explanation shown to user, often as a blockquote
3. **Phase/step flow**: numbered phases or steps describing the workflow
4. **Delegation**: reference skills and agents that implement the logic

## Orchestration Role

Commands orchestrate — they coordinate skills and agents but do not duplicate their logic.

```
/onboard:init (command)
     │
     ├── spawns codebase-analyzer agent
     ├── invokes wizard skill
     ├── spawns config-generator agent
     └── presents handoff
```

When a command delegates to a skill, invoke it via the Skill tool. When it delegates to an agent, spawn it as a subagent. Do not copy-paste skill instructions into commands.

## User Communication

- Use blockquotes (`>`) for messages shown verbatim to the user
- Include status updates between phases: "Analyzing...", "Generating..."
- Present confirmations before proceeding to destructive or irreversible phases

## Naming

- File name: `kebab-case.md` (e.g., `init.md`, `setup.md`, `status.md`)
- H1 format: `/plugin:command — Human-Readable Description`
- Keep command names short — they're typed by users
