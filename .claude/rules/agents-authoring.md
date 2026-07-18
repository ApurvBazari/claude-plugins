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

## Frontmatter Fields

Beyond `name`/`description`/`color`, declare a machine-readable `tools` allowlist and a `model` per role:

- `tools:` — least-privilege list matching the prose `## Tools` section (read-only agents: `Read, Grep, Glob[, Bash]`; never `Write`/`Edit` unless the agent's purpose requires it).
- `model:` — `opus` for judgment/high-stakes/adversarial roles, `sonnet` for mechanical/well-specified scans.

This aligns hand-authored agents with the contract `onboard/agents/config-generator.md` already mandates for *generated* agents.

## References

An agent's supporting docs live in the plugin's flat, agent-owned `agents/references/*.md` — a sibling of the agent files, not inside any skill:

```
<plugin>/agents/
├── codebase-analyzer.md
└── references/
    └── tech-stack-patterns.md
```

- Cite them from the agent as a bare `references/<file>.md`. Keep the directory flat (no subfolders) — the depth belongs in `skills/<name>/references/`, which is skill-owned.
- Use this home when the consumer is an **agent**. A doc a skill loads stays under that skill's `references/`. Never point an agent at a skill's `references/` to borrow a file — if both need it, that is a signal the doc has two owners; pick the primary and cite across explicitly.
- `.github/scripts/check-references.sh` walks `agents/**/references/`, so a reference here is gated for integrity exactly like a skill-owned one.

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
