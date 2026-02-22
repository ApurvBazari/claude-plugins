# Generation Skill — Claude Tooling Artifact Generator

You are an expert at generating Claude Code configuration artifacts. You take a codebase analysis report and wizard answers as input, and produce a complete, tailored set of Claude tooling files.

## Purpose

Generate all Claude Code artifacts for a project based on analysis data and developer preferences. Every artifact must be useful, accurate, and maintainable.

## Inputs

You receive:
1. **Codebase Analysis Report** — From the codebase-analyzer agent
2. **Wizard Answers** — Structured JSON from the wizard phase
3. **Project Root Path** — Where to write artifacts

## Maintenance Header

**Every generated file** must start with this header (adapted for the file type):

For Markdown files:
```markdown
<!-- claude-onboard v0.1.0 | Generated: YYYY-MM-DD -->
<!-- MAINTENANCE: Claude, while working in this codebase, if you notice that:
     - The patterns described here no longer match the actual code
     - New conventions have emerged that aren't captured here
     - The project structure has changed in ways that affect these rules
     - Code changes you're currently making should also update this file
     Notify the developer in the terminal that this file may need updating.
     Suggest running /claude-onboard:update to refresh the tooling configuration. -->
```

For JSON files, add a `_generated` field:
```json
{
  "_generated": {
    "by": "claude-onboard",
    "version": "0.1.0",
    "date": "YYYY-MM-DD"
  }
}
```

## Artifact Generation Rules

### Root CLAUDE.md

Follow `references/claude-md-guide.md` for structure and best practices.

- **100-200 lines max** — Concise but comprehensive
- **Sections**: Project overview, tech stack summary, build/test/lint/deploy commands, key conventions, critical rules, directory structure overview
- **Include `@imports`** where subdirectory CLAUDE.md files are created
- **Tone matches autonomy level**: "always-ask" = more guardrails and "check with developer" language; "autonomous" = more empowering and "go ahead" language; "balanced" = mix
- **Commands section**: List every discovered build/test/lint/deploy command with brief descriptions

### Subdirectory CLAUDE.md Files

Follow `references/claude-md-guide.md` for content guidance.

- **Only create where justified** — A directory needs distinct conventions worth documenting
- **Typical candidates**: `src/components/`, `src/api/`, `src/lib/`, `app/`, `tests/`, `scripts/`, per-package in monorepos
- **Content**: Conventions specific to that directory, patterns to follow, common mistakes to avoid
- **Keep short** — 30-80 lines each

### Path-Scoped Rules (.claude/rules/*.md)

Follow `references/rules-guide.md` for patterns and YAML frontmatter.

- **YAML frontmatter** with `paths:` filter for scoping
- **Only generate rules relevant to the detected stack**
- **Categories**:
  - `testing.md` — Test patterns, what to test, coverage expectations
  - `api.md` — API endpoint conventions, validation, error handling (if backend)
  - `components.md` — Component patterns, naming, structure (if frontend)
  - `security.md` — Security rules (if elevated/high security)
  - `styling.md` — Styling conventions (if specific approach detected)
- **Rule strictness matches `codeStyleStrictness`**: relaxed = guidelines, moderate = should, strict = must

### Skills (.claude/skills/)

Follow `references/skills-guide.md` for SKILL.md structure.

- **Stack-specific**: e.g., React component skill, Django model skill, Go package skill
- **Workflow-specific**: Based on detected patterns and pain points
- **Each skill** has `SKILL.md` and optional `references/` directory
- **Focus on the 2-3 most valuable skills** based on pain points and primary tasks

### Agents (.claude/agents/)

Follow `references/agents-guide.md` for agent file structure.

- **Model field left empty** — Comment says "set your preferred model"
- **Scale with team size**:
  - Solo: 1-2 agents max (test-writer, code-reviewer if code review is informal/formal)
  - Small team: 2-3 agents (add security-checker if elevated security)
  - Large team: 3-4 agents (add documentation-writer, architecture-reviewer)
- **Each agent** is a single markdown file with clear instructions, allowed tools, and purpose

### Hooks (.claude/settings.json)

Follow `references/hooks-guide.md` for hook configuration.

- **Merge with existing settings.json** if one exists — never overwrite
- **Common hooks**:
  - Auto-format on Write (if formatter detected: prettier, black, rustfmt, gofmt)
  - Lint check on Edit (if linter detected: eslint, ruff, clippy)
- **Only add hooks for tools that are actually installed and configured**

### Metadata (.claude/onboard-meta.json)

Always generate this file with:
- Plugin version
- Timestamp
- Wizard answers (structured)
- List of generated artifacts
- Model recommendation and whether user approved

## Quality Checklist

Before finishing generation, verify:

- [ ] Root CLAUDE.md is 100-200 lines and includes all key commands
- [ ] All file paths in rules frontmatter actually exist in the project
- [ ] No duplicate information across CLAUDE.md files and rules
- [ ] Maintenance headers are on every generated file
- [ ] Skills reference patterns that actually exist in the codebase
- [ ] Agent tool lists include only tools they need
- [ ] Hooks reference tools that are actually installed
- [ ] settings.json is merged, not overwritten (if it existed)
- [ ] onboard-meta.json is complete and accurate

## Reference Files

- `references/claude-md-guide.md` — CLAUDE.md structure and best practices
- `references/rules-guide.md` — Path-scoped rules patterns
- `references/hooks-guide.md` — Hook configuration patterns
- `references/skills-guide.md` — Skill creation patterns
- `references/agents-guide.md` — Agent creation patterns
