# Path-Scoped Rules Guide

Rules are markdown files in `.claude/rules/` that apply to specific file paths. They give Claude targeted instructions when working on matching files.

---

## File Structure

```
.claude/
└── rules/
    ├── testing.md          # Rules for test files
    ├── api.md              # Rules for API routes/endpoints
    ├── components.md       # Rules for UI components
    ├── security.md         # Security-sensitive file rules
    └── styling.md          # Styling convention rules
```

## YAML Frontmatter

Every rule file starts with YAML frontmatter that specifies which file paths it applies to:

```yaml
---
paths:
  - "src/components/**"
  - "src/ui/**"
---
```

### Path Pattern Syntax
- `**` — Matches any number of directories
- `*` — Matches any single directory or filename segment
- Paths are relative to project root
- Multiple paths can be listed

### Examples
```yaml
# Match all test files
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"

# Match API routes
paths:
  - "src/api/**"
  - "src/routes/**"
  - "app/api/**"

# Match Python test files
paths:
  - "tests/**"
  - "**/test_*.py"

# Match Go test files
paths:
  - "**/*_test.go"

# Match specific directories
paths:
  - "src/components/**"
  - "src/hooks/**"
```

## Rule Content

After the frontmatter, write clear instructions for Claude when working on matching files.

### Testing Rules Example

```yaml
---
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
---

# Testing Rules

## Test Structure
- Use `describe` blocks grouped by function/component being tested
- Use clear test names: `it('should return empty array when no items match filter')`
- Follow Arrange-Act-Assert pattern

## What to Test
- Test behavior, not implementation details
- Test edge cases: empty inputs, null values, boundary conditions
- Test error cases: invalid inputs, network failures, permission errors

## What NOT to Test
- Don't test third-party library internals
- Don't test simple getters/setters
- Don't write snapshot tests for dynamic content

## Mocking
- Mock external APIs and services, never internal modules
- Use `vi.mock()` for module-level mocks
- Prefer dependency injection over mocking where possible

## Coverage
- Aim for meaningful coverage, not 100%
- Critical paths (auth, payments, data mutations) must have tests
```

### API Rules Example

```yaml
---
paths:
  - "src/api/**"
  - "app/api/**"
---

# API Route Rules

## Request Handling
- Validate all request inputs with Zod schemas
- Return consistent error response format: `{ error: string, code: string }`
- Use appropriate HTTP status codes

## Error Handling
- Catch all errors and return structured responses
- Never leak internal error details to clients
- Log errors server-side with request context

## Authentication
- All non-public routes must check authentication
- Use middleware for auth checks, not inline code

## Response Format
- Always return JSON
- Include pagination metadata for list endpoints
- Use consistent field naming (camelCase)
```

### Component Rules Example

```yaml
---
paths:
  - "src/components/**"
---

# Component Rules

## File Structure
- One component per file
- Co-locate tests: `ComponentName.test.tsx`
- Co-locate styles if component-specific

## Naming
- PascalCase for component names and files
- Props interface: `{ComponentName}Props`

## Patterns
- Functional components only, no class components
- Destructure props in function signature
- Use `forwardRef` when the component wraps a native element

## Accessibility
- All interactive elements need accessible names
- Use semantic HTML elements
- Include keyboard navigation support
```

### Security Rules Example

```yaml
---
paths:
  - "src/**"
---

# Security Rules

## Input Validation
- Never trust user input — validate and sanitize everything
- Use parameterized queries, never string concatenation for SQL
- Validate file uploads: type, size, content

## Secrets
- Never hardcode secrets, API keys, or credentials
- Use environment variables for all sensitive configuration
- Never log sensitive data (passwords, tokens, PII)

## Authentication
- Hash passwords with bcrypt (cost factor ≥12)
- Use short-lived tokens with refresh rotation
- Implement rate limiting on auth endpoints

## Output
- Sanitize all output to prevent XSS
- Set appropriate security headers (CSP, HSTS, etc.)
- Never expose stack traces or internal errors to users
```

## Strictness Levels

Adapt rule language based on the developer's code style strictness preference:

### Relaxed
- Use "prefer", "consider", "when possible"
- Focus on critical rules only, skip style preferences
- Fewer rules overall

### Moderate (default)
- Use "should", "recommended", "follow"
- Cover important conventions and patterns
- Skip trivial style preferences

### Strict
- Use "must", "always", "never"
- Comprehensive coverage of conventions
- Include style preferences and formatting rules

## Generation Guidelines

1. **Only generate rules for detected patterns** — Don't create API rules if there's no API
2. **Path patterns must match real paths** — Verify directories exist before using them
3. **Don't duplicate CLAUDE.md content** — Rules add specifics, CLAUDE.md gives overview
4. **Keep each rule file focused** — One concern per file
5. **Include examples** — Show what good code looks like in this project
