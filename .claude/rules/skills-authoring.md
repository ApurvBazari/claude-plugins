---
paths:
  - "**/skills/**"
---

# Skill Authoring

## File Structure

```
skills/<skill-name>/
├── SKILL.md          ← main instructions
└── references/       ← supporting docs (optional)
    ├── guide-1.md
    └── guide-2.md
```

## SKILL.md Sections

Every skill must include these sections in order:

1. **H1 title**: `# /plugin:skill-name — Short Description`
2. **Guard section** (if config-dependent): read config, exit with setup instructions if missing
3. **Overview**: brief introduction shown to user
4. **Numbered steps**: `## Step N: Action` — each step is a discrete action
5. **Key Rules**: `## Key Rules` — bulleted list of invariants and constraints

## Writing Style

- Use present tense imperative: "Run", "Check", "Present" — not "Running", "Checking"
- Address Claude directly: "You are running..." or "Tell the developer:"
- Use blockquotes (`>`) for text that should be shown verbatim to the user
- Use code blocks for CLI output, config examples, and progress displays

## Guard Pattern

Skills that depend on configuration should start with:

```markdown
## Guard

Read `<config-file>` in the project root. If not found:

> Run `/<plugin>:<setup-command>` first to configure your project.

Stop and do not proceed.
```

## Tables for Multi-Tool Support

When a skill supports multiple tools/runners, use a table mapping each tool to its specific commands:

| Runner | Command | Flags |
|--------|---------|-------|
| tool-a | `cmd-a` | `--flag` |
| tool-b | `cmd-b` | `--other` |

## References

- Place supporting docs in `references/` subdirectory
- Reference files should be focused on one topic each
- Skills load their references automatically — no explicit import needed
