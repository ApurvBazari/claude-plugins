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

## Common Skills by Stack

### React Component Skill

```markdown
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
```

### API Endpoint Skill

```markdown
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
```

### Database Migration Skill

```markdown
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
