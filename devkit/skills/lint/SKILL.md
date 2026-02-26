# /devkit:lint — Run Linter with Auto-Fix

You are helping the developer run their linter, understand the results, and optionally auto-fix issues.

## Guard

Read `.claude/devkit.json` in the project root. If not found:

> Run `/devkit:setup` first to configure your project.

Stop and do not proceed.

## Config

Extract from `devkit.json`:
- `tooling.lintCommand` — the lint command to run
- `tooling.linter` — the linter name (for parsing output)

If `lintCommand` is not configured:

> No lint command configured. Run `/devkit:setup` to set one up, or tell me what command to use.

Stop.

## Step 1: Run Linter

Run the configured lint command:

```bash
<lintCommand>
```

Capture both stdout and stderr. Note the exit code.

## Step 2: Parse Results

If the linter exits cleanly (exit code 0):

> Linting passed — no issues found.

Stop.

If there are issues, categorize them:

### Error Categories

| Category | Description | Priority |
|----------|-------------|----------|
| **Errors** | Code that will break or has bugs | CRITICAL |
| **Warnings** | Potential issues or style violations | MODERATE |
| **Info** | Suggestions and best practices | LOW |

Present a summary:

```
Lint results:

  Errors:    <count>
  Warnings:  <count>
  Info:      <count>

Top issues:
  1. <rule-name> — <count> occurrences — <brief description>
  2. <rule-name> — <count> occurrences — <brief description>
  3. <rule-name> — <count> occurrences — <brief description>
```

## Step 3: Offer Auto-Fix

If the linter supports auto-fix, offer it:

> Would you like me to auto-fix what I can?
>
> **Auto-fixable**: <count> issues (<list top rules>)
> **Manual fixes needed**: <count> issues

Determine the auto-fix command based on the linter:

| Linter | Auto-Fix Command |
|--------|-----------------|
| eslint | `<lintCommand> --fix` |
| biome | `<packageManager> biome check --write` |
| ruff | `<packageManager> ruff check --fix` |
| rubocop | `<lintCommand> -A` |
| golangci-lint | `golangci-lint run --fix` |
| clippy | `cargo clippy --fix` |

If the user confirms, run the auto-fix command.

## Step 4: Re-Check After Fix

After auto-fix, re-run the lint command to check remaining issues:

```bash
<lintCommand>
```

If issues remain, present them:

> Auto-fix resolved <count> issues. Remaining issues need manual fixes:
>
> <list remaining issues with file paths and line numbers>

If all clean:

> All lint issues resolved.

## Step 5: Manual Fix Assistance

If there are remaining issues and the user wants help, read the affected files and suggest fixes. Present each fix for user approval before applying.

## Key Rules

- **Always run the configured command** — never substitute a different linter
- **Present results before fixing** — let the user see what's wrong first
- **Confirm before auto-fixing** — auto-fix can change code, get permission
- **Re-check after fixing** — verify the fix didn't introduce new issues
