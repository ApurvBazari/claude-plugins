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

## Deriving Rules from Config Analysis

**Principle**: Generated rules should capture the project's actual enforced standards and extend them with architectural intent that linters can't check.

### From linter configs → path-scoped rules

Extract enforced rules (error severity) and translate them into Claude-understandable guidance:
- ESLint `no-unused-vars: error` → "Remove unused variables and imports before committing"
- `@typescript-eslint/naming-convention` configured → state the exact convention explicitly
- `react-hooks/exhaustive-deps: warn` → "Review hook dependency arrays — the project warns on missing deps"
- Ruff `select = ["E", "F", "I"]` → "Follow pycodestyle, pyflakes, and isort rules"

### From formatter configs → CLAUDE.md conventions (NOT rules)

Formatter settings are auto-fixed, so they don't need rules enforcement. Document them in CLAUDE.md so Claude writes code that already matches the formatter:
- Prettier `singleQuote: true, semi: false` → add to CLAUDE.md Key Conventions: "Use single quotes, no semicolons (auto-formatted by Prettier)"
- Black `line-length = 88` → add to CLAUDE.md: "Line length limit is 88 characters (enforced by Black)"
- rustfmt `max_width = 100` → add to CLAUDE.md: "Max line width is 100 (enforced by rustfmt)"

### From tsconfig/mypy/strict settings → type safety rules

- `strict: true` → "Never use `any` type — use `unknown` and narrow. Always handle potential `null`/`undefined`"
- `paths` aliases → "Use path aliases (e.g., `@/components`) instead of relative imports deeper than 2 levels"
- `mypy strict` → "All functions must have type annotations. No `# type: ignore` without a comment explaining why"

### From observed patterns → architectural rules

- Barrel exports detected → "Export public API through index files; do not import from internal module files directly"
- Custom error classes detected → "Throw domain-specific error classes (e.g., `NotFoundError`, `ValidationError`), not raw strings"
- Layer boundary pattern → "Services must not import from controllers. Components must not import from pages"
- Tailwind utility-only → "Use Tailwind utility classes. Do not create custom CSS files unless for complex animations"

### Anti-duplication principle

Never create rules that simply restate what a formatter auto-fixes. Rules should cover what tools CANNOT enforce: architectural patterns, naming intent, error handling philosophy, component composition patterns, import boundaries.

---

## Connecting Strictness to Autonomy

When both `codeStyleStrictness` and `autonomyLevel` are set, use this matrix to determine rule tone and density:

| | Relaxed | Moderate | Strict |
|---|---------|----------|--------|
| **Always-Ask** | "consider", few rules, "discuss with developer" | "should", moderate rules, "check first" | "must", many rules, "verify with developer" |
| **Balanced** | "prefer", minimal rules | "should", standard rules | "must", comprehensive rules |
| **Autonomous** | "prefer", minimal rules, no checkpoints | "follow", standard rules, no checkpoints | "must"/"always", comprehensive rules, no checkpoints |

**Key principle**: Autonomy controls **tone** (how assertive and whether to include "check with developer" language). Strictness controls **quantity** (how many rules and how much coverage). A "strict + autonomous" project gets many rules but with assertive language and no confirmation checkpoints.

## Generation Guidelines

1. **Only generate rules for detected patterns** — Don't create API rules if there's no API
2. **Path patterns must match real paths** — Verify directories exist before using them
3. **Don't duplicate CLAUDE.md content** — Rules add specifics, CLAUDE.md gives overview
4. **Keep each rule file focused** — One concern per file
5. **Include examples** — Show what good code looks like in this project
