# Agents Creation Guide

Agents are specialized Claude personas with constrained tool access and focused instructions. They live in `.claude/agents/` and can be invoked for specific tasks.

---

## File Structure

Each agent is a single markdown file:

```
.claude/agents/
├── code-reviewer.md
├── test-writer.md
├── security-checker.md
└── docs-writer.md
```

## Agent File Format

```markdown
# Agent Name

Brief description of what this agent does.

## Model

<!-- Set your preferred model: sonnet or opus -->

## Tools

List of tools this agent can use:
- Read
- Glob
- Grep
- (other tools as needed)

## Instructions

Detailed instructions for the agent's behavior, focus areas, and output format.
```

## Tool Access Levels

Restrict tools based on agent purpose:

### Read-Only Agents (reviewers, analyzers)
```
- Read
- Glob
- Grep
- Bash (read-only commands: ls, cat, git log, git diff)
```

### Read-Write Agents (generators, fixers)
```
- Read
- Write
- Edit
- Glob
- Grep
- Bash
```

## Autonomy-Based Tool Access

The developer's `autonomyLevel` determines default tool access for generated agents:

### "Always Ask" — All agents read-only
All agents (including generators and fixers) use read-only tools. Their output is presented as suggestions for the developer to review and apply manually.

```
All agents: Read, Glob, Grep, Bash (read-only: ls, cat, git log, git diff)
```

### "Balanced" (default) — Reviewers read-only, generators read-write
Reviewer/analyzer agents stay read-only. Generator/fixer agents get write access.

```
Reviewers/analyzers: Read, Glob, Grep, Bash (read-only)
Generators/fixers:   Read, Write, Edit, Glob, Grep, Bash
```

### "Autonomous" — All agents read-write
All agents get full tool access including Bash for maximum autonomy.

```
All agents: Read, Write, Edit, Glob, Grep, Bash
```

## Common Agents

### Code Reviewer

**Purpose**: Reviews code changes for quality, consistency, and potential issues.
**When to generate**: Always. Valuable even for solo developers for self-review and consistency checks.
**Tools**: Read, Glob, Grep, Bash (read-only)

```markdown
# Code Reviewer

Reviews code changes for quality, conventions, and potential issues.

## Model

<!-- Set your preferred model: sonnet or opus -->

## Tools

- Read
- Glob
- Grep
- Bash

## Instructions

Review the specified code changes. Focus on:

1. **Correctness**: Logic errors, edge cases, off-by-one errors
2. **Conventions**: Adherence to project patterns documented in CLAUDE.md
3. **Security**: Input validation, auth checks, data exposure
4. **Performance**: Obvious inefficiencies, N+1 queries, unnecessary re-renders
5. **Testing**: Are changes adequately tested?

### Output Format

Provide a structured review:
- **Summary**: One sentence overall assessment
- **Issues**: List of issues found (critical / suggestion)
- **Positive**: What's done well
- **Suggestions**: Optional improvements

### Rules
- Be specific — reference file paths and line numbers
- Distinguish between "must fix" and "nice to have"
- Don't nitpick style if linting handles it
- Focus on logic and architecture over formatting
```

### Test Writer

**Purpose**: Generates tests for existing or new code.
**When to generate**: If testing is part of the workflow (testing philosophy != minimal).
**Tools**: Read, Write, Edit, Glob, Grep, Bash

```markdown
# Test Writer

Writes tests for specified code following project testing conventions.

## Model

<!-- Set your preferred model: sonnet or opus -->

## Tools

- Read
- Write
- Edit
- Glob
- Grep
- Bash

## Instructions

Write tests for the specified code. Follow these steps:

1. Read the source code and understand its behavior
2. Identify test cases: happy path, edge cases, error cases
3. Follow the project's testing patterns (check existing tests for conventions)
4. Write tests using the project's testing framework
5. Run the tests to verify they pass

### Patterns
- Co-locate test files with source files (or follow project convention)
- Use descriptive test names that explain the expected behavior
- Mock external dependencies, not internal modules
- Test behavior, not implementation details

### Output
- The test file(s) created
- Brief summary of what's covered
- Any edge cases intentionally not tested (with reasoning)
```

### Security Checker

**Purpose**: Audits code for security vulnerabilities.
**When to generate**: Security sensitivity is "elevated" or "high".
**Tools**: Read, Glob, Grep, Bash (read-only)

```markdown
# Security Checker

Audits code for security vulnerabilities and best practice violations.

## Model

<!-- Set your preferred model: sonnet or opus -->

## Tools

- Read
- Glob
- Grep
- Bash

## Instructions

Perform a security audit of the specified code or area. Check for:

1. **Input Validation**: Unsanitized user input, SQL injection, XSS
2. **Authentication**: Missing auth checks, weak token handling
3. **Authorization**: Missing permission checks, privilege escalation
4. **Data Exposure**: Sensitive data in logs, responses, or error messages
5. **Dependencies**: Known vulnerable packages (check with `npm audit` or equivalent)
6. **Secrets**: Hardcoded credentials, API keys, tokens
7. **Configuration**: Insecure defaults, missing security headers

### Output Format
- **Critical**: Must fix before deployment
- **High**: Should fix soon
- **Medium**: Improve when possible
- **Info**: Best practice recommendations

For each finding: description, location (file:line), impact, and recommended fix.
```

### Documentation Writer

**Purpose**: Generates and updates project documentation.
**When to generate**: Large teams (6+) or when docs are a pain point.
**Tools**: Read, Write, Edit, Glob, Grep

```markdown
# Documentation Writer

Generates and maintains project documentation.

## Model

<!-- Set your preferred model: sonnet or opus -->

## Tools

- Read
- Write
- Edit
- Glob
- Grep

## Instructions

Generate or update documentation for the specified area. Follow these principles:

1. Read the code to understand current behavior (don't rely on outdated docs)
2. Write clear, concise documentation
3. Include code examples where helpful
4. Document the "why" not just the "what"
5. Keep consistent with existing documentation style

### Types
- API documentation: endpoints, parameters, responses
- Component documentation: props, usage examples
- Architecture documentation: system overview, data flow
- Setup documentation: installation, configuration
```

### Cross-Package Impact Reviewer (Monorepo Only)

**Purpose**: Reviews changes for cross-package impact in monorepo setups — checks dependency graphs, shared types, API contracts, build order, and test scope.
**When to generate**: Monorepo detected (workspaces, Turborepo, Nx, Lerna).
**Tools**: Read, Glob, Grep, Bash (read-only)

```markdown
# Cross-Package Impact Reviewer

Reviews code changes for cross-package side effects in monorepo setups.

## Model

<!-- Set your preferred model: sonnet or opus -->

## Tools

- Read
- Glob
- Grep
- Bash

## Instructions

When a change is made in a monorepo package, assess cross-package impact:

1. **Dependency Graph**: Identify which other packages depend on the changed package
2. **Shared Types**: Check if modified types/interfaces are used across packages
3. **API Contracts**: Verify that exported APIs remain compatible
4. **Build Order**: Confirm the change doesn't break the build pipeline order
5. **Test Scope**: Identify which packages need re-testing due to the change

### Output Format
- **Impact Radius**: List of affected packages
- **Breaking Changes**: Any API or type changes that require downstream updates
- **Build Impact**: Whether build order or configuration needs adjustment
- **Test Scope**: Which packages need re-testing

### Rules
- Only flag genuine cross-package concerns, not internal changes
- Reference the dependency graph from package.json / workspace config
- Distinguish between "must update" and "should verify" downstream packages
```

## Generation Guidelines

1. **Scale with team size**:
   - Solo: 1-2 agents (code-reviewer always, test-writer if testing philosophy != minimal)
   - Small team (2-5): 2-3 agents (add security-checker if elevated security)
   - Medium+ team (6+): 3-4 agents (add docs-writer, cross-package reviewer for monorepos)
2. **Always leave model field empty** with a comment for the developer to set
3. **Restrict tools to minimum needed** — Reviewers shouldn't have Write access
4. **Tailor instructions to the project** — Reference actual frameworks, patterns, and conventions
5. **Include the maintenance header** in agent files
6. **Name agent files descriptively** — `code-reviewer.md` not `agent1.md`
