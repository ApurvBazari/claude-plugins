# ACI Design Guide — Agent-Computer Interface Best Practices

From Anthropic's "Building Effective Agents": "We spent more time optimizing our tools than the overall prompt." Tool interface design is the highest-leverage implementation detail for agent quality.

This guide is used in two ways:
1. **By the config-generator**: when generating agent definitions for projects
2. **By generated projects**: a condensed version is included in CLAUDE.md so developers writing custom agents follow these principles

## Principles

### 1. Poka-Yoke Design (Make Mistakes Structurally Impossible)

Structure tool arguments so errors can't happen:

| Bad (error-prone) | Good (error-proof) |
|---|---|
| Relative file paths (`./src/index.ts`) | Absolute file paths (`/Users/dev/project/src/index.ts`) |
| Free-text format ("edit line 5") | Structured arguments (`{"file": "...", "line": 5, "replacement": "..."}`) |
| Implicit state ("the current file") | Explicit references ("the file at /path/to/file.ts") |
| "Find and replace X with Y" | "In file Z, replace exact string X with Y" |

When generating agent instructions, always prefer explicit, unambiguous references over implicit context.

### 2. Tool Documentation Quality

Write tool usage instructions with the same rigor as docstrings for junior developers:

```markdown
## Tools

- **Read** — Read file contents. Always use absolute paths.
  Example: `Read /Users/dev/project/src/app.ts`
  Edge case: Returns error if file doesn't exist — check with Glob first.

- **Bash** — Execute shell commands. Only use for read-only commands.
  Example: `curl -s http://localhost:3000/api/health`
  Edge case: Commands that hang (dev servers) — always use timeout or background.
  WARNING: Never use for `rm`, `mv`, or other destructive commands.
```

Include: example usage, edge cases, input format requirements, and explicit boundaries.

### 3. Error Handling Patterns

Every agent should handle these common failures:

```markdown
### Error Handling

- **File not found**: Check file exists (Glob) before reading. If missing, report
  the expected file path and what was looking for it.
- **Command fails**: Capture both stdout and stderr. Report the exit code and
  error message. Do NOT retry silently — report the failure.
- **Timeout**: For any operation that could hang (dev server start, network request),
  use a timeout. Report if timeout exceeded.
- **Malformed input**: If reading JSON/YAML, validate structure before processing.
  Report specific parse errors, not generic "invalid input."
- **Permission denied**: Report the file/command and the permission error.
  Do not attempt workarounds (sudo, chmod).
```

### 4. Format Optimization

Choose formats that match what models see in training data:

| Avoid | Prefer | Why |
|---|---|---|
| Code inside JSON (requires escaping) | Code in markdown fences | Models handle fenced code naturally |
| Diffs with line numbers | Full file content or targeted edits | Diffs require counting, which models do poorly |
| Complex nested structures | Flat key-value pairs | Less cognitive load for models |

### 5. Ground Truth at Every Step

Agents must verify reality after each action — never assume code works from reading it:

```markdown
After writing code:
  → Run the build/compile command to verify no syntax errors
After creating an API endpoint:
  → curl the endpoint to verify it responds
After modifying the database:
  → Query the database to verify the change took effect
After UI changes:
  → Navigate to the page to verify it renders
```

"It's crucial for the agents to gain ground truth from the environment at each step."

### 6. Input Validation Before Acting

Agents should validate their inputs before taking action:

```markdown
Before reading feature-list.json:
  1. Check file exists (Glob)
  2. Read file
  3. Parse JSON — if malformed, report error with line number
  4. Validate required fields (id, description, steps, passes)
  5. If any feature has empty steps array, flag it

Before running init.sh:
  1. Check file exists and is executable
  2. Check required commands are available (node, python, etc.)
  3. Run with timeout (30s default)
  4. Capture stdout/stderr for diagnosis if it fails
```

## Condensed Version for Generated Projects

Include this in generated CLAUDE.md (or docs/HARNESS-GUIDE.md):

```markdown
## Writing Custom Agents

When creating agents in .claude/agents/:

1. **Use absolute paths** — never relative. Prevents errors after directory changes.
2. **Document tools clearly** — include example usage and edge cases for each tool.
3. **Handle errors explicitly** — check files exist before reading, validate JSON before parsing, use timeouts for network/server operations.
4. **Verify reality** — after every action, check the result. Don't assume code works from reading it. Run the build, curl the endpoint, navigate the page.
5. **Restrict tool access** — only grant tools the agent actually needs. Read-only agents should not have Write/Edit.
```
