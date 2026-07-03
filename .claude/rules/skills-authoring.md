---
paths:
  - "**/skills/**"
---

# Skill Authoring

## File Structure

```
skills/<skill-name>/
├── SKILL.md          ← main instructions (required)
└── references/       ← supporting docs (optional)
    ├── guide-1.md
    └── guide-2.md
```

A single-file skill (just `SKILL.md` with no `references/`) is fine when there's nothing to colocate — the directory is still required (Claude Code discovers skills by scanning `skills/<name>/SKILL.md`).

## Frontmatter

Every SKILL.md must open with YAML frontmatter between `---` markers. Canonical spelling is **hyphenated** (underscore variants are silently ignored):

```yaml
---
name: my-skill
description: One or two sentences — what the skill does AND when to invoke it. Used by Claude to decide auto-invocation.
user-invocable: true          # (default) shows in /plugin: autocomplete
disable-model-invocation: true # (optional) only the user can trigger — Claude won't auto-invoke
---
```

- `name` — lowercase letters, numbers, hyphens, max 64 chars. If omitted, derives from the directory name. The slash entry becomes `/<plugin>:<name>`.
- `description` — the trigger signal for model auto-invocation. Front-load the use case (trigger phrases users would say). Capped at 1,536 chars combined with `when_to_use`.
- `user-invocable: false` — hide from the `/` menu. Use for internal building blocks (wizards, analysis skills) that other skills invoke via the Skill tool.
- `disable-model-invocation: true` — Claude won't auto-trigger on description match. Use for destructive or setup skills (`init`, `update`, `uninstall`).

See `CLAUDE.md` § Skill Frontmatter Categories for the repo's per-skill policy.

## SKILL.md Sections

Every skill must include these sections in order, after the frontmatter:

1. **H1 title**: `# Descriptive Name — Short Description` (e.g., `# Wizard Skill — Interactive Onboarding Flow`). Do NOT put the slash form (`/plugin:name`) in the H1 — the slash is derived from the `name` frontmatter.
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

> Run `/<plugin>:<setup-skill>` first to configure your project.

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
