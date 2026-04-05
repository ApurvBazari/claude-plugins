# Generation Skill — Claude Tooling Artifact Generator

You are an expert at generating Claude Code configuration artifacts. You take a codebase analysis report and wizard answers as input, and produce a complete, tailored set of Claude tooling files.

## Purpose

Generate all Claude Code artifacts for a project based on analysis data and developer preferences. Every artifact must be useful, accurate, and maintainable.

## Inputs

You receive:
1. **Codebase Analysis Report** — From the codebase-analyzer agent, or from pre-seeded context in headless mode
2. **Wizard Answers** — Structured JSON from the wizard phase, or from pre-seeded context in headless mode
3. **Project Root Path** — Where to write artifacts

## Headless Mode Guard

When `headlessMode` is `true` in the input context, this skill is being invoked via `/onboard:generate` from an external caller (e.g., the Forge plugin). In headless mode:

- **Skip all interactive steps** — Do not ask the developer any questions, present confirmation prompts, or wait for user input. All decisions have already been made by the caller.
- **Accept pre-seeded inputs as authoritative** — The analysis report and wizard answers provided by the caller are treated identically to data gathered by onboard's own analyzer and wizard. Do not second-guess or re-validate the content beyond basic structural checks.
- **Merge hooks carefully** — The caller may have already written hooks to `.claude/settings.json`. Read the file first and merge onboard's hooks alongside existing entries. This is the most common source of conflicts in headless mode.
- **Record provenance** — Include `headlessMode: true` and the caller's `source` identifier in `onboard-meta.json`.
- **All generation rules still apply** — Artifact order, quality checks, maintenance headers, autonomy cascade, reference guides — everything in this skill applies equally in headless mode. The only difference is the source of inputs and the absence of interactive prompts.

## Maintenance Header

**Every generated file** must start with this header (adapted for the file type):

For Markdown files:
```markdown
<!-- onboard v0.1.0 | Generated: YYYY-MM-DD -->
<!-- MAINTENANCE: Claude, while working in this codebase, if you notice that:
     - The patterns described here no longer match the actual code
     - New conventions have emerged that aren't captured here
     - The project structure has changed in ways that affect these rules
     - Code changes you're currently making should also update this file
     Notify the developer in the terminal that this file may need updating.
     Suggest running /onboard:update to refresh the tooling configuration. -->
```

For JSON files, add a `_generated` field:
```json
{
  "_generated": {
    "by": "onboard",
    "version": "0.1.0",
    "date": "YYYY-MM-DD"
  }
}
```

## Autonomy Cascade

The developer's `autonomyLevel` preference cascades across all generated artifacts. Use this table to determine defaults:

| Aspect | Always-Ask | Balanced | Autonomous |
|--------|-----------|----------|------------|
| **Hooks** | No auto hooks (comment listing available hooks) | Auto-format on Write | Auto-format + auto-lint on Edit |
| **Rule language** | "consider", "discuss with developer" | "should", "recommended" | "must", "always", "never" |
| **Agent tool access** | All agents read-only (output as suggestions) | Reviewers read-only, generators read-write | All agents read-write including Bash |
| **CLAUDE.md rules** | 8-12 extensive items including "check with developer" | 4-6 moderate items | 2-3 hard safety rules only |
| **Skill detail** | Verbose with examples + alternatives + checkpoints | Standard with key examples | Concise, pattern-focused templates |

**Conflict resolution**: When `autonomyLevel` and `codeStyleStrictness` produce conflicting tone verbs, `autonomyLevel` overrides for tone (how assertive the language is), while `codeStyleStrictness` controls quantity (how many rules/checks are generated).

## Artifact Generation Rules

### Root CLAUDE.md

Follow `references/claude-md-guide.md` for structure and best practices.

- **100-200 lines max** — Concise but comprehensive
- **Sections**: Project overview, tech stack summary, build/test/lint/deploy commands, key conventions, critical rules, directory structure overview
- **Include `@imports`** where subdirectory CLAUDE.md files are created
- **Tone matches autonomy level**: "always-ask" = more guardrails and "check with developer" language; "autonomous" = more empowering and "go ahead" language; "balanced" = mix
- **Formatter conventions**: Include formatter settings (from Prettier/Black/rustfmt configs) as explicit conventions in Key Conventions section rather than as path-scoped rules
- **Commands section**: List every discovered build/test/lint/deploy command with brief descriptions
- **Ecosystem plugins section** (if any were set up): If `ecosystemPlugins` is present in wizard answers, add a brief "Ecosystem Plugins" section noting which plugins are active (e.g., "notify: system notifications on task completion", "observe: passive usage analytics at `~/.claude/observability/`"). Include relevant commands (`/notify:status`, `/observe:status`, `/observe:pipeline`).

### Subdirectory CLAUDE.md Files

Follow `references/claude-md-guide.md` for content guidance.

- **Create when all three criteria are met**: (1) directory contains a meaningful share of source files, (2) has distinct conventions not covered by root, (3) represents an architectural boundary
- **File share thresholds scaled by project size**:
  - Small projects (<100 source files): directory has >20% of total source files
  - Medium projects (100-500 source files): directory has >10% of total source files
  - Large projects (>500 source files): directory has >5% of total source files
- **Monorepo packages are automatic candidates** — each package is an architectural boundary by definition
- **Typical candidates**: `src/components/`, `src/api/`, `src/lib/`, `app/`, `tests/`, `scripts/`, per-package in monorepos
- **Always confirm** candidate directories with the developer before creating subdirectory CLAUDE.md files
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
- **Config-derived rules**: When the analysis report includes a `Config & Pattern Analysis` section, use the extracted configs and observed patterns to generate rules that reflect the project's actual enforced standards. Follow the "Deriving Rules from Config Analysis" section in `references/rules-guide.md`. Never generate generic template rules when project-specific config data is available.
- **Rule strictness matches `codeStyleStrictness`**: relaxed = guidelines, moderate = should, strict = must

### Skills (.claude/skills/)

Follow `references/skills-guide.md` for SKILL.md structure.

- **Stack-specific**: e.g., React component skill, Django model skill, Go package skill
- **Workflow-specific**: Based on detected patterns and pain points
- **Each skill** has `SKILL.md` and optional `references/` directory
- **Focus on the 2-3 most valuable skills** based on pain points and primary tasks

### Skill Selection Priority

When choosing which 2-3 skills to generate, use this weighting:

1. **Pain point match** (highest) — Skill directly addresses a developer-reported pain point
2. **Detected stack fit** — Skill matches a framework/tool found in analysis (e.g., React component skill for React projects)
3. **Workflow gap** — Skill fills a gap in the development workflow (e.g., deployment skill when deploy is manual)

**Combined scoring**: A skill that matches both a pain point AND the detected stack gets the highest combined score. When more than 3 candidate skills exist, pain point matches always win over stack-based candidates.

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

### Collaboration Artifacts

Follow `references/collaboration-guide.md` for templates and conventions.

**Always generate** regardless of team size — solo developers benefit from consistency:

- **PR Template** (`.github/PULL_REQUEST_TEMPLATE.md`) — Structured PR template with summary, type-of-change checkboxes, and checklist. Add stack-specific items based on analysis. Add security items if `securitySensitivity` is elevated/high. Include a note for the developer to customize after reviewing.
- **Commit Conventions** (`.claude/rules/commit-conventions.md`) — Path-scoped rule (`paths: **`) for Conventional Commits format. Strictness of language matches `codeStyleStrictness`.
- **Shared vs Local Settings Guidance** — Include a section in root CLAUDE.md explaining `.claude/settings.json` (shared, committed) vs `.claude/settings.local.json` (personal, gitignored).
- **Gitignore Entry** — If `.gitignore` exists in the project root, append `.claude/settings.local.json` to it (if not already present). This ensures personal settings are never committed.

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
- [ ] PR template exists with stack-appropriate checklist items
- [ ] Commit conventions rule matches `codeStyleStrictness` level
- [ ] Root CLAUDE.md includes shared vs local settings guidance
- [ ] Rules reflect actual config settings, not generic defaults
- [ ] Formatter-enforced settings are in CLAUDE.md Key Conventions, not duplicated in rules
- [ ] Observed codebase patterns are captured in architectural rules

## Reference Files

- `references/claude-md-guide.md` — CLAUDE.md structure and best practices
- `references/rules-guide.md` — Path-scoped rules patterns
- `references/hooks-guide.md` — Hook configuration patterns
- `references/skills-guide.md` — Skill creation patterns
- `references/agents-guide.md` — Agent creation patterns
- `references/collaboration-guide.md` — PR template, commit conventions, shared/local settings
