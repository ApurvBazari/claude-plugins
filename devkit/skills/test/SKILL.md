# /devkit:test — Run Tests

You are helping the developer run their test suite with various modes and understand the results.

## Guard

Read `.claude/devkit.json` in the project root. If not found:

> Run `/devkit:setup` first to configure your project.

Stop and do not proceed.

## Config

Extract from `devkit.json`:
- `tooling.testCommand` — the test command to run
- `tooling.testRunner` — the runner name (for parsing output and mode flags)
- `tooling.packageManager` — for constructing commands

If `testCommand` is not configured:

> No test command configured. Run `/devkit:setup` to set one up, or tell me what command to use.

Stop.

## Step 1: Mode Selection

If the user didn't specify a mode, ask:

> How would you like to run tests?
>
> 1. **All** — run the full test suite
> 2. **Coverage** — run with coverage report
> 3. **Watch** — run in watch mode (re-runs on file changes)
> 4. **Specific** — run a specific test file or pattern

If the user's message already implies a mode (e.g., "run tests for auth" → specific, "check coverage" → coverage), use that mode directly.

## Step 2: Build Command

Construct the test command based on the mode and runner:

### All

```bash
<testCommand>
```

### Coverage

| Runner | Coverage Command |
|--------|-----------------|
| vitest | `<testCommand> --coverage` |
| jest | `<testCommand> --coverage` |
| pytest | `<testCommand> --cov` |
| go test | `go test -cover ./...` |
| cargo test | `cargo tarpaulin` (if installed) or `cargo test` |
| rspec | `<testCommand> --format documentation` |

### Watch

| Runner | Watch Command |
|--------|--------------|
| vitest | `<testCommand> --watch` |
| jest | `<testCommand> --watch` |
| pytest | `<testCommand> -f` (with pytest-watch) or `ptw` |
| go test | Not natively supported — inform user |
| cargo test | `cargo watch -x test` (if installed) |

### Specific

Ask the user which test(s) to run. Accept:
- A file path: `<testCommand> <path>`
- A test name pattern: build runner-specific filter flag

| Runner | Filter Flag |
|--------|------------|
| vitest | `<testCommand> <pattern>` |
| jest | `<testCommand> --testPathPattern <pattern>` |
| pytest | `<testCommand> -k <pattern>` or `<testCommand> <path>` |
| go test | `go test -run <pattern> ./...` |
| cargo test | `cargo test <pattern>` |
| rspec | `<testCommand> <path>` |

## Step 3: Run Tests

Execute the constructed command:

```bash
<command>
```

Use a timeout appropriate for the mode:
- All/Coverage: 5 minutes (300000ms)
- Watch: inform user this runs continuously, they can interrupt
- Specific: 2 minutes (120000ms)

## Step 4: Parse & Present Results

### If all tests pass

> All tests passed (<count> tests in <time>).

For coverage mode, also show:

> **Coverage summary:**
>
> | Category | Coverage |
> |----------|----------|
> | Statements | XX% |
> | Branches | XX% |
> | Functions | XX% |
> | Lines | XX% |
>
> <note any files with low coverage if visible in output>

### If tests fail

Present a structured failure report:

```
Test results: <passed>/<total> passed, <failed> failed

Failed tests:

  1. <test name>
     File: <path>:<line>
     Error: <assertion or error message>

  2. <test name>
     File: <path>:<line>
     Error: <assertion or error message>
```

## Step 5: Failure Assistance

If tests failed, offer help:

> Would you like me to investigate the failures? I can:
> 1. Read the failing test files and source code to diagnose the issue
> 2. Suggest fixes
> 3. Re-run just the failing tests after fixes

If the user wants help, read the relevant test and source files, diagnose the issue, and suggest fixes. Present fixes for approval before applying.

After applying fixes, re-run only the failing tests to verify.

## Key Rules

- **Always run the configured command** — never substitute a different test runner
- **Never modify test files** without user approval
- **Report results clearly** — developers need to see what failed and why
- **For watch mode** — inform the user how to stop (Ctrl+C) and that you'll monitor output
- **Respect timeouts** — don't let tests run indefinitely
