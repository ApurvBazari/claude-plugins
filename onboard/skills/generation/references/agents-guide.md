# Agents Creation Guide

Agents are specialized Claude personas with constrained tool access and focused instructions. They live in `.claude/agents/` and can be invoked for specific tasks.

---

## File Structure

Each agent is a single markdown file:

```
.claude/agents/
├── code-reviewer.md
├── tdd-test-writer.md
├── security-checker.md
└── documentation-writer.md
```

## Agent File Format

Every generated agent opens with YAML frontmatter between `---` markers. The body is free-form instructions. The two fields `name` and `description` are required by Claude Code; the others are optional and emitted only when archetype inference produces concrete values.

```markdown
---
name: code-reviewer
description: Proactively reviews code changes for quality, conventions, and potential issues.
tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)
model: sonnet
effort: medium
color: blue
disallowedTools: Write, Edit
permissionMode: default
---

# Code Reviewer

Reviews code changes for quality, conventions, and potential issues.

## Instructions

Detailed instructions for the agent's behavior, focus areas, and output format.
```

## Frontmatter Reference

Canonical spelling matches the Claude Code subagent docs (https://code.claude.com/docs/en/sub-agents.md). Fields are case-sensitive; omit any field when inference produces no concrete value (emit nothing rather than `null` / `""` / `[]`).

| Field | Type | Required | Default | Purpose |
|---|---|---|---|---|
| `name` | string | **Yes** | — | Unique identifier; lowercase letters and hyphens; matches the filename. |
| `description` | string | **Yes** | — | When Claude should delegate to this subagent. Prefix with "Proactively …" / "Use this agent proactively when …" to encode auto-invocation intent (this IS the `proactive` convention — there is no `proactive` frontmatter field). |
| `tools` | list \| string | no | inherits all tools | Tools the subagent can use. Comma-separated string or YAML list. Restrict to minimum needed. |
| `disallowedTools` | list \| string | no | — | Tools to deny, removed from inherited or specified list. Archetype-level disallow wins over posture broadening for semantic protection (e.g., reviewer never writes). |
| `model` | string | no | `inherit` | `sonnet` / `opus` / `haiku` / `inherit` / full ID (e.g. `claude-opus-4-6`). Pick a tier when cost/quality tradeoff differs from session defaults. |
| `permissionMode` | string | no | `default` | `default` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions` / `plan`. Only emit when the wizard's `preApprovalPosture` specifies a non-default mode. |
| `maxTurns` | integer | no | — | Cap on agentic turns. Emit for validator archetype (default `2`) — keeps fast gates fast. |
| `effort` | string | no | session effort | `low` / `medium` / `high` / `max` (Opus 4.6 only). Thinking budget override. |
| `isolation` | string | no | session (default) | Only legal value: `worktree`. Runs the subagent in a temporary git worktree with isolated repo copy. Omit for default session isolation. |
| `color` | string | no | — | Display color in task list and transcript. Must be one of: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`. No other values accepted. |
| `background` | boolean | no | `false` | `true` runs the subagent as a background task. Reserved — no archetype currently defaults it; only reachable via wizard tweak. |

**Rules for generated agents**:

1. **Always emit `name` + `description`.** These are the only non-negotiable fields.
2. **Encode `proactive` intent via `description` prefix**, not a frontmatter field. `proactive` is not a valid Claude Code subagent frontmatter key.
3. **Emit other fields only when inference produces a concrete value** — never emit empty strings or empty lists. An omitted field preserves pre-feature behavior exactly.
4. **Validate enum values before writing.** `color` must be in the 8-color set; `effort` must be in `{low, medium, high, max}`; `isolation` must be `worktree` or omitted; `model` must be in the allowed set. Invalid values are generation bugs and must be dropped with a warning rather than written.
5. **Skip `isolation: worktree` in non-git directories.** The harness would fail at invocation time. Detect with `git rev-parse --is-inside-work-tree` equivalent and drop the field with a warning.

### Per-archetype defaults

The generator classifies each candidate agent into one of five archetypes based on agent purpose + generation rationale (team size, security signal, stack fit), then applies these defaults. Wizard-level overrides (`defaultModel`, `defaultEffort`, `preApprovalPosture`, `defaultIsolation`) refine them before user confirmation.

| Archetype   | Signals                                                  | `tools`                                                  | `disallowedTools` | `model`   | `effort`  | `isolation` | `color`  | `maxTurns` | Description prefix                           |
|-------------|----------------------------------------------------------|----------------------------------------------------------|-------------------|-----------|-----------|-------------|----------|------------|----------------------------------------------|
| reviewer    | "review", "audit"; commit-adjacent; code-quality framing | `Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)`    | `Write, Edit`     | `sonnet`  | `medium`  | —           | `blue`   | —          | "Proactively reviews …"                      |
| validator   | "validate", "lint", "typecheck", "test"; pre-commit gate | `Read, Glob, Grep, Bash`                                 | `Write, Edit`     | `haiku`   | `low`     | —           | `green`  | `2`        | "Use this agent proactively when …"          |
| generator   | "create", "generate", "scaffold"; writes new files       | `Read, Write, Edit, Glob, Grep, Bash`                    | —                 | `sonnet`  | `medium`  | `worktree`  | `purple` | —          | —                                            |
| architect   | "design", "plan", "architect"; multi-phase deep work     | `Read, Glob, Grep`                                       | `Write, Edit`     | `opus`    | `high`    | —           | `cyan`   | —          | —                                            |
| researcher  | "explore", "investigate", "audit" with no writes         | `Read, Glob, Grep`                                       | `Write, Edit`     | `inherit` | `low`     | —           | `yellow` | —          | —                                            |

**Archetype inference fallback**: when signals are ambiguous, classify as `researcher` (least-surprising read-only defaults). Record a `agentStatus.warnings[]` entry noting the fallback.

**Posture clamp** (applied after archetype lookup, via `wizardAnswers.agentTuning.preApprovalPosture`):

- `minimal` — force `permissionMode: default`; keep archetype `disallowedTools` as-is (reviewer/validator/architect/researcher) or add `Write, Edit` (generator, overriding its write access).
- `standard` — default. Leave archetype output untouched.
- `permissive` — may add `permissionMode: acceptEdits` for generator archetype only. Archetype-defined `disallowedTools` are still preserved for semantic protection (reviewers never write).

**Isolation default** (`wizardAnswers.agentTuning.defaultIsolation`):

- `worktree-for-generators` (default in "tuned" mode) — emit `isolation: worktree` on `generator` archetype only. Skip in non-git dirs.
- `off` — never emit `isolation`; rely on session defaults.

### Example frontmatter blocks

**Reviewer archetype:**

```yaml
---
name: code-reviewer
description: Proactively reviews code changes for quality, conventions, and potential issues. Use after writing or modifying code.
tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)
disallowedTools: Write, Edit
model: sonnet
effort: medium
color: blue
---
```

**Validator archetype (with `maxTurns` cap):**

```yaml
---
name: security-checker
description: Use this agent proactively when sensitive files are edited. Audits diffs for credential leaks, unsafe input handling, and privilege issues.
tools: Read, Glob, Grep, Bash
disallowedTools: Write, Edit
model: haiku
effort: low
color: green
maxTurns: 2
---
```

**Generator archetype (with worktree isolation):**

```yaml
---
name: tdd-test-writer
description: Writes failing tests first, then guides minimal implementation to pass them. Follows red-green-refactor.
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
effort: medium
isolation: worktree
color: purple
---
```

**Architect archetype:**

```yaml
---
name: architecture-reviewer
description: Deep design review for multi-phase changes. Analyzes dependency graphs, interface contracts, and cross-cutting concerns before implementation.
tools: Read, Glob, Grep
disallowedTools: Write, Edit
model: opus
effort: high
color: cyan
---
```

**Researcher archetype:**

```yaml
---
name: documentation-writer
description: Generates and maintains project documentation. Reads code directly to avoid outdated docs.
tools: Read, Glob, Grep
disallowedTools: Write, Edit
model: inherit
effort: low
color: yellow
---
```

---

## Common Agents

### Code Reviewer (reviewer archetype)

**Purpose**: Reviews code changes for quality, consistency, and potential issues.
**When to generate**: Always. Valuable even for solo developers for self-review and consistency checks.

```markdown
---
name: code-reviewer
description: Proactively reviews code changes for quality, conventions, and potential issues. Use after writing or modifying code.
tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)
disallowedTools: Write, Edit
model: sonnet
effort: medium
color: blue
---

# Code Reviewer

Reviews code changes for quality, conventions, and potential issues.

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

### TDD Test Writer (generator archetype)

**Purpose**: Writes failing tests first, then guides minimal implementation to pass them.
**When to generate**: Skip if `superpowers` plugin is installed (it handles TDD via `superpowers:test-driven-development`). Generate only when superpowers is NOT installed.

```markdown
---
name: tdd-test-writer
description: Writes failing tests first, then guides minimal implementation to pass them. Follows red-green-refactor for every change.
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
effort: medium
isolation: worktree
color: purple
---

# TDD Test Writer

Writes failing tests first, then guides minimal implementation to pass them.
Follows the red-green-refactor cycle for every change.

## Instructions

Follow the red-green-refactor cycle for every change:

1. Read the feature requirements or bug description
2. Design test cases: happy path, edge cases, error cases
3. Write the FIRST failing test
4. Run the test — verify it fails for the expected reason
5. Write the minimal code to make it pass
6. Run the test — verify it passes
7. Refactor if needed (keep tests green)
8. Repeat for the next test case

### Critical Rules
- NEVER write implementation code before a failing test exists
- Each test should test ONE behavior
- Write the simplest code to pass — no premature optimization
- If a test passes immediately, it's testing existing behavior — revise it
- Co-locate test files with source (or follow project convention)
- Use descriptive test names that explain the expected behavior

### Output
- The test file(s) created (RED phase)
- The implementation that passes them (GREEN phase)
- Any refactoring applied (REFACTOR phase)
- Summary of what's covered and what edge cases remain
```

### Security Checker (validator archetype)

**Purpose**: Audits code for security vulnerabilities.
**When to generate**: Security sensitivity is "elevated" or "high".

```markdown
---
name: security-checker
description: Use this agent proactively when sensitive files are edited. Audits diffs for credential leaks, unsafe input handling, and privilege issues.
tools: Read, Glob, Grep, Bash
disallowedTools: Write, Edit
model: haiku
effort: low
color: green
maxTurns: 2
---

# Security Checker

Audits code for security vulnerabilities and best practice violations.

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

### Documentation Writer (researcher archetype)

**Purpose**: Generates and updates project documentation.
**When to generate**: Large teams (6+) or when docs are a pain point.

```markdown
---
name: documentation-writer
description: Generates and maintains project documentation. Reads code directly to avoid outdated docs. Documents the "why" not just the "what".
tools: Read, Glob, Grep
disallowedTools: Write, Edit
model: inherit
effort: low
color: yellow
---

# Documentation Writer

Generates and maintains project documentation.

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

**Note on researcher tools**: the archetype defaults to read-only tools. Writer agents that need to emit docs files should be classified as `generator` instead — the archetype taxonomy separates read-only analysis from write-enabled scaffolding.

### Architecture Reviewer (architect archetype)

**Purpose**: Deep design review for multi-phase changes.
**When to generate**: Large teams (6+) or explicit architectural pain point.

```markdown
---
name: architecture-reviewer
description: Deep design review for multi-phase changes. Analyzes dependency graphs, interface contracts, and cross-cutting concerns before implementation.
tools: Read, Glob, Grep
disallowedTools: Write, Edit
model: opus
effort: high
color: cyan
---

# Architecture Reviewer

Reviews proposed architectural changes before implementation.

## Instructions

1. Read the design proposal or diff
2. Map cross-cutting concerns (logging, auth, caching, error handling)
3. Identify dependency graph impact
4. Flag interface contract breaks
5. Highlight risks that implementation alone won't surface

### Output Format
- **Architectural Impact**: systems touched
- **Contract Risks**: interface breaks or compatibility concerns
- **Recommendations**: changes needed before implementation
```

### Cross-Package Impact Reviewer (reviewer archetype, Monorepo Only)

**Purpose**: Reviews changes for cross-package impact in monorepo setups.
**When to generate**: Monorepo detected (workspaces, Turborepo, Nx, Lerna).

```markdown
---
name: cross-package-reviewer
description: Proactively reviews monorepo changes for cross-package side effects. Checks dependency graphs, shared types, API contracts, build order, and test scope.
tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)
disallowedTools: Write, Edit
model: sonnet
effort: medium
color: blue
---

# Cross-Package Impact Reviewer

Reviews code changes for cross-package side effects in monorepo setups.

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

---

## Autonomy-Based Tool Access

The developer's `autonomyLevel` still refines the per-archetype `tools` list:

### "Always Ask" — All agents read-only
All agents (including generators) use read-only tools. Their output is presented as suggestions for the developer to review and apply manually. Drop `Write`, `Edit`, and unscoped `Bash` from every archetype.

### "Balanced" (default) — Archetype defaults apply
Reviewers/validators/architects/researchers stay read-only. Generators get write access as defined by the archetype.

### "Autonomous" — All agents read-write
All agents get full tool access. Generator archetype keeps its default `isolation: worktree` for safety. Other archetypes gain `Write, Edit, Bash` but keep their archetype-level `disallowedTools` unless explicitly overridden.

---

## Frontmatter Emission Rules

1. **Classify each candidate agent** into one of the five archetypes in § Per-archetype defaults before computing any frontmatter field. Use the agent's purpose description and generation rationale (team size, security, stack fit). Ambiguous cases fall back to `researcher`.

2. **Apply wizard project-level defaults** next — `wizardAnswers.agentTuning.defaultModel`, `defaultEffort`, `preApprovalPosture`, `defaultIsolation` — to refine the archetype output. Never blindly emit `inherit`; when the wizard set a concrete default (e.g., `sonnet`), replace `inherit` with that value.

3. **Clamp tools per posture and autonomy** after archetype + wizard overrides are composed. `disallowedTools` from the archetype always wins (semantic protection). Posture `minimal` cannot grant tools the archetype forbids.

4. **Validate before writing**:
   - `color` must be in `{red, blue, green, yellow, purple, orange, pink, cyan}`. Invalid → drop field, warn `invalid-color-value`.
   - `effort` must be in `{low, medium, high, max}`. Invalid → drop field, warn `invalid-effort-value`.
   - `isolation` must be `worktree` or omitted. Any other value → drop, warn `invalid-isolation-value`.
   - `model` must match the allowed set (or be a full model ID). Invalid → drop, warn `invalid-model-value`.
   - `isolation: worktree` requires a git repository. If the target is non-git → drop field, warn `isolation-non-git-dir`.

5. **Present a batched confirmation table** before writing any agent file. Developer options: *Accept all* (default, keeps headless + quick-mode paths byte-stable), *Tweak agent N*, *Skip agent N*. Skipped agents record `agentStatus.skipped[].reason = "user-declined-confirmation"`.

6. **Write the drift snapshot** at `.claude/onboard-agent-snapshot.json` mirroring only the emitted frontmatter (one object per agent name). Pure JSON, no maintenance header. Consumed by `onboard:update` / `onboard:evolve` as the drift baseline.

7. **Omitting a field is explicit**. When inference produces no concrete value, omit the field rather than emitting `null`, `""`, or `[]`. This keeps pre-feature-equivalent agents byte-identical to historical output.

---

## Generation Guidelines

1. **Scale with team size**:
   - Solo + superpowers installed: 1 agent (code-reviewer only — superpowers handles TDD)
   - Solo + no superpowers: 2 agents (code-reviewer, tdd-test-writer)
   - Small team (2-5): 2-3 agents (add security-checker if elevated security)
   - Medium+ team (6+): 3-4 agents (add documentation-writer, architecture-reviewer, cross-package reviewer for monorepos)
2. **Classify into archetype first** — Archetype → fields → validation → batched confirmation → emit.
3. **Restrict tools to minimum needed** — Use archetype `tools` + `disallowedTools` defaults; only broaden via explicit wizard tuning or autonomy-level elevation.
4. **Tailor instructions to the project** — Reference actual frameworks, patterns, and conventions in the body of the agent file.
5. **Include the maintenance header** in agent body (not frontmatter).
6. **Name agent files descriptively** — `code-reviewer.md`, not `agent1.md`. The `name` frontmatter field must match the filename stem.
