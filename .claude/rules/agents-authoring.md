---
paths:
  - "**/agents/**"
---

# Agent Authoring

## File Format

Each agent is a single markdown file: `agents/<agent-name>.md`

## Required Sections

1. **H1 title**: `# Agent Name — Short Description`
2. **Role description**: one paragraph explaining what this agent does and when to invoke it
3. **Tools section**: `## Tools` — list of allowed tools
4. **Instructions**: `## Instructions` — numbered steps for the agent to follow
5. **Output Format**: `## Output Format` — structured format for the agent's response

## Tool Access Principle

- **Read-only agents** (analyzers, reviewers): `Read`, `Glob`, `Grep`, `Bash` (read-only commands only)
- **Write agents** (generators, scaffolders): `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`

Default to read-only. Only grant write access when the agent's purpose requires creating or modifying files.

## Agent vs Skill

- **Agents** are spawned as subprocesses — they have their own context and tool access
- **Skills** are instructions loaded into the main conversation
- Use agents for: deep analysis, isolated generation, tasks that benefit from a separate context
- Use skills for: interactive workflows, multi-step processes that need user input

## Naming

- File name: `kebab-case.md` (e.g., `codebase-analyzer.md`, `tooling-detector.md`)
- H1 title: human-readable name (e.g., `# Codebase Analyzer`)
- Keep names descriptive of the agent's role, not its implementation
