# Skills Creation Guide

Skills are reusable knowledge packages that Claude can reference when performing specific types of tasks. They live in `.claude/skills/` and give Claude domain expertise for your project.

---

## Directory Structure

```
.claude/
└── skills/
    ├── react-component/
    │   ├── SKILL.md              # Skill definition and instructions
    │   └── references/
    │       └── component-template.md  # Reference material
    ├── api-endpoint/
    │   ├── SKILL.md
    │   └── references/
    │       └── endpoint-patterns.md
    └── deploy/
        └── SKILL.md
```

## SKILL.md Structure

```markdown
---
name: <skill-name>
description: One or two sentences — what the skill does AND when to invoke it.
# Optional frontmatter fields — see § Frontmatter Reference below for the full list.
---

# Skill Name

Brief description of what this skill helps Claude do.

## When to Use

Describe the trigger conditions — when should Claude activate this skill?

## Instructions

Step-by-step instructions for Claude when performing this type of task.

## Patterns

Code patterns and conventions specific to this skill in this project.

## Examples

Concrete examples of correct output.

## Anti-Patterns

What to avoid.

## References

List reference files if any:
- `references/filename.md` — Description
```

## Frontmatter Reference

Every generated `SKILL.md` opens with YAML frontmatter between `---` markers. Canonical spelling is **hyphenated** — underscore variants (e.g., `allowed_tools`, `user_invocable`) are silently ignored by Claude Code and must never be emitted. A pre-write lint pass rejects any underscore-form key as a generation bug.

| Field | Type | Required | Default | Purpose |
|---|---|---|---|---|
| `name` | string | no | derived from directory | lowercase, hyphens, max 64 chars; forms `/<plugin>:<name>` |
| `description` | string | recommended | — | the trigger signal for model auto-invocation; front-load trigger phrases |
| `user-invocable` | boolean | no | `true` | `false` hides the skill from `/<plugin>:` autocomplete (internal building blocks) |
| `disable-model-invocation` | boolean | no | `false` | `true` means only the user can trigger — Claude won't auto-invoke (destructive / setup skills) |
| `allowed-tools` | list | no | — | **pre-approval** list — Claude can use these tools without per-call permission prompts while the skill is active. Omitting the field preserves default session permissions; it does NOT restrict tool access |
| `model` | string | no | session model | `sonnet` / `opus` / `haiku` / `inherit` — pick a tier when the skill's cost/quality tradeoff differs from session defaults |
| `effort` | string | no | session effort | `low` / `medium` / `high` — thinking budget override |
| `paths` | list | no | — | glob patterns; when set, the skill auto-activates only when the active file path matches |
| `context` | string | no | — | set to `fork` to run the skill in an isolated subagent (fresh context, no conversation history). Requires `agent` |
| `agent` | string | no | `general-purpose` | subagent type to use when `context: fork` — must reference an agent that exists in `.claude/agents/` or an installed plugin |

**Rules for generated skills**:

1. **Always emit `name` + `description`.** These are the only two fields that are non-negotiable.
2. **Emit `user-invocable: false` or `disable-model-invocation: true`** per the category rules in the repo's skill frontmatter policy — not covered by the archetype inference.
3. **Emit the other six fields only when inference produces a concrete value** — never emit empty strings or empty lists. An omitted field preserves pre-feature behavior exactly.
4. **Reject underscore misspellings** before writing. A key like `allowed_tools` in the computed frontmatter is a generation bug — surface it loudly rather than silently letting Claude Code ignore it.

### Per-archetype defaults

The generator classifies each candidate skill into one of five archetypes based on the draft description + generation rationale, then applies these defaults. Wizard-level overrides (`defaultModel`, `defaultEffort`, `preApprovalPosture`) refine them before user confirmation.

| Archetype | Signals | `allowed-tools` | `model` | `effort` | `paths` | `context` | `agent` |
|---|---|---|---|---|---|---|---|
| research-only | "analyze", "audit", "review"; no write verbs | `Read, Grep, Glob` | inherit | low | — | — | — |
| scaffolder | "create", "generate", "scaffold"; stack-specific | `Read, Grep, Glob, Write, Edit` | inherit | medium | stack glob (e.g. `src/**/*.tsx`) | — | — |
| reviewer | commit-adjacent review | `Read, Grep, Glob, Bash(git diff:*), Bash(git log:*)` | sonnet | medium | — | fork | `code-reviewer` (if present) |
| orchestrator | spawns subagents, multi-phase | `Read, Grep, Glob, Write, Edit, Task` | opus | high | — | — | — |
| workflow-specific | deploy / migrate / test-runner | `Read, Grep, Glob, Bash(<runner>:*)` | inherit | medium | — | — | — |

**Posture clamp** (applied after archetype lookup):

- `minimal` — strip `Write`, `Edit`, `Bash(*)` from `allowed-tools`. Leaves only read-surface tools.
- `standard` — default. Leaves archetype output untouched.
- `permissive` — broaden `Bash(...)` scoping to include detected runners (e.g., add `Bash(npm run *:*), Bash(pnpm *:*)` for Node projects).

### Example frontmatter blocks

**Research-only (reviewer-archetype):**

```yaml
---
name: pr-summarizer
description: Summarize the diff against main — sections for API changes, test coverage, risk areas. Trigger on "summarize PR", "what changed", "diff summary".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git diff:*)
  - Bash(git log:*)
model: sonnet
effort: medium
context: fork
agent: code-reviewer
---
```

**Scaffolder (frontend):**

```yaml
---
name: react-component
description: Create a new React functional component with co-located tests and type-safe props. Trigger on "create component", "new component", "add component".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
effort: medium
paths:
  - src/components/**/*.tsx
  - src/features/**/*.tsx
---
```

## Common Skills by Stack

### React Component Skill

```markdown
---
name: react-component
description: Create a new React component following this project's conventions — TypeScript, co-located test, named export. Trigger on "create component", "new component", "scaffold component".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
effort: medium
paths:
  - src/components/**/*.tsx
  - src/features/**/*.tsx
---

# React Component Creation

Creates new React components following project conventions.

## When to Use
When asked to create a new React component or UI element.

## Instructions
1. Create component file at the appropriate location based on type:
   - Shared components: `src/components/{ComponentName}.tsx`
   - Feature components: `src/features/{feature}/{ComponentName}.tsx`
2. Create co-located test file: `{ComponentName}.test.tsx`
3. Follow the component template pattern below

## Component Pattern
- Functional component with TypeScript
- Props interface named `{ComponentName}Props`
- Named export (not default)
- Destructured props in function signature

## Test Pattern
- Use React Testing Library
- Test rendering, user interactions, and edge cases
- Mock external dependencies, not internal components

## Anti-Patterns
- Don't use `any` for props — define a proper `{ComponentName}Props` interface
- Don't use `useEffect` for derived state — compute it during render
- Don't fetch data inside components — use server components or data-fetching hooks
```

### API Endpoint Skill

```markdown
---
name: api-endpoint
description: Create a new API endpoint with input validation, structured error handling, and tests. Trigger on "add endpoint", "new route", "create handler".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
effort: medium
paths:
  - src/api/**/*.ts
  - src/routes/**/*.ts
---

# API Endpoint Creation

Creates new API endpoints following project conventions.

## When to Use
When asked to create a new API route, endpoint, or handler.

## Instructions
1. Create route file at the appropriate location
2. Add input validation schema
3. Implement handler with error handling
4. Add tests for success and error cases
5. Update API documentation if it exists

## Endpoint Pattern
- Validate input with Zod/Pydantic schema
- Return consistent response format
- Handle errors with try-catch and structured error responses
- Log errors server-side

## Anti-Patterns
- Don't return raw error objects to clients — always map to structured error responses
- Don't mix validation logic into handlers — use a schema layer (Zod/Pydantic)
- Don't use string concatenation for SQL — always use parameterized queries
```

### Database Migration Skill

```markdown
---
name: db-migration
description: Author a safe database migration with up and down halves and a guarded destructive-change warning. Trigger on "migration", "schema change", "alter table".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - Bash(npx prisma migrate:*)
effort: medium
---

# Database Migration

Creates and manages database migrations safely.

## When to Use
When asked to modify the database schema.

## Instructions
1. Create migration file using the project's migration tool
2. Write both up and down migrations
3. Test migration on development database
4. Warn developer about destructive operations (dropping columns, tables)

## Safety Rules
- Never drop columns/tables without explicit developer approval
- Always provide a rollback migration
- Test data preservation for column type changes
```

### Deployment Skill

```markdown
---
name: deploy
description: Walk through the project's deploy workflow — build, test, release check. Trigger on "deploy", "ship", "release".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(npm run build:*)
  - Bash(npm test:*)
  - Bash(git status:*)
model: sonnet
effort: medium
---

# Deployment Process

Guides through the project's deployment workflow.

## When to Use
When asked to deploy, prepare for deployment, or troubleshoot deployment issues.

## Instructions
1. Run build and verify it succeeds
2. Run test suite and verify all pass
3. Check for uncommitted changes
4. Follow the project's deployment process
```

## Generation Guidelines

1. **Generate 2-3 skills max** — Focus on the most valuable ones based on pain points and primary tasks
2. **Stack-specific skills take priority** — A React project needs a component skill more than a generic refactoring skill
3. **Reference real project patterns** — Skills should encode how THIS project does things, not generic patterns
4. **Include anti-patterns** — Knowing what NOT to do is as valuable as knowing what to do
5. **Keep skills focused** — One task type per skill
6. **Add references only when needed** — If the skill is self-contained in SKILL.md, no references directory needed
7. **Use the maintenance header** — So Claude knows to flag when the skill drifts from actual code patterns

## Autonomy-Based Detail Level

Adapt the verbosity and structure of generated skills based on the developer's `autonomyLevel`:

### "Always Ask" — Verbose with checkpoints
- Include detailed step-by-step instructions with examples at each step
- Add alternative approaches: "Option A: ..., Option B: ..."
- Include checkpoints: "Pause and confirm with the developer before proceeding to step N"
- Provide rationale for each pattern choice

### "Balanced" — Standard with key examples
- Clear step-by-step instructions
- Include 1-2 key examples for non-obvious patterns
- No checkpoints — trust Claude's judgment for standard tasks
- Brief rationale for important pattern choices only

### "Autonomous" — Concise pattern templates
- Minimal instructions — focus on patterns and templates
- Show the target output format, not the reasoning process
- No alternatives or checkpoints
- Trust Claude to apply patterns correctly based on context

## Frontmatter Emission Rules

1. **Classify each candidate skill** into one of the five archetypes in § Frontmatter Reference § Per-archetype defaults before computing any frontmatter field. Use the draft description and the skill's generation rationale (pain point / stack / workflow gap).
2. **Apply wizard project-level defaults** next — `wizardAnswers.skillTuning.defaultModel`, `defaultEffort`, `preApprovalPosture` — to refine the archetype output. Never blindly emit `inherit`; when the wizard set a concrete default (e.g., `sonnet`), replace `inherit` with that value.
3. **Clamp `allowed-tools` per posture** after archetype + wizard overrides are composed. Never emit a list that contradicts the posture (e.g., `minimal` posture with `Write` in the list is a bug).
4. **Validate before writing**:
   - `context: fork` requires `agent`. If the referenced agent is not in `.claude/agents/` or `effectivePlugins`, demote to no-fork and append a warning to `skillStatus.warnings`.
   - `paths` entries are globs. Warn when none match any file in the repo today, but still emit (developer may add files later).
   - Reject underscore-form keys pre-write — this is a generation bug, not a silent fix.
5. **Present a batched confirmation table** before writing any `SKILL.md`. Developer options: *Accept all* (default, keeps headless + quick-mode paths byte-stable), *Tweak skill N*, *Skip skill N*. Skipped skills record `skillStatus.skipped[].reason = "user-declined-confirmation"`.
6. **Write the drift snapshot** at `.claude/onboard-skill-snapshot.json` mirroring only the emitted frontmatter (one object per skill name). This is the diff baseline for `/onboard:update` and `/onboard:evolve`.
7. **Omitting a field is explicit**. When inference produces no concrete value, omit the field rather than emitting `null`, `""`, or `[]`. This keeps pre-feature-equivalent skills byte-identical to historical output.
