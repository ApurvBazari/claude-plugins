# /devkit:check — Production Readiness Scan

You are scanning the codebase for production readiness issues — debug artifacts, security concerns, performance problems, and code quality red flags.

## Guard

Read `.claude/devkit.json` in the project root. If not found:

> Run `/devkit:setup` first to configure your project.

Stop and do not proceed.

## Config

Extract from `devkit.json`:
- `tooling.linter` — for context on what's already caught by linting
- `tooling.testRunner` — for test-related checks

## Step 1: Scan Categories

Run grep-based scans across the codebase using patterns from `references/check-patterns.md`. Scan in these categories:

### Category 1: Debug Artifacts

Search for debug code that shouldn't ship to production:

- `console.log`, `console.debug`, `console.warn` (JS/TS)
- `debugger` statements (JS/TS)
- `print()` debug statements (Python — distinguish from legitimate logging)
- `println!` debug statements (Rust — distinguish from legitimate output)
- `fmt.Println` debug statements (Go)
- `binding.pry`, `byebug` (Ruby)
- `TODO`, `FIXME`, `HACK`, `XXX` comments
- `@ts-ignore`, `@ts-nocheck`, `eslint-disable` without explanation
- Commented-out code blocks (>3 consecutive commented lines)

**Exclusions**: Ignore files in `node_modules/`, `vendor/`, `dist/`, `build/`, `.git/`, test files, and config files where console/print usage is expected (scripts, CLI tools, logger setup).

### Category 2: Security

Search for security issues:

- Hardcoded secrets: API keys, tokens, passwords, connection strings
- `.env` files committed (check git status)
- Insecure HTTP URLs (should be HTTPS)
- SQL string concatenation (potential injection)
- `eval()`, `exec()`, `Function()` with dynamic input
- Disabled security features (`csrf_exempt`, `@no_auth`, `verify=False`)
- Overly permissive CORS (`Access-Control-Allow-Origin: *` in production config)
- Sensitive data in logs

### Category 3: Performance

Search for performance red flags:

- Synchronous file I/O in async contexts
- Missing pagination on list endpoints
- Unbounded queries (SELECT without LIMIT)
- Large bundle imports (importing entire libraries when a sub-module would work)
- Missing image optimization
- N+1 query patterns (loading relations in loops)
- Missing caching headers

### Category 4: Code Quality

Search for code quality issues:

- Empty catch blocks (swallowed errors)
- Functions with >50 lines (complexity)
- Files with >500 lines (should be split)
- Deeply nested conditionals (>3 levels)
- Magic numbers without constants
- Missing error handling on external calls (API, DB, file system)

## Step 2: Run Scans

For each category, use Grep to search the codebase. Apply the exclusion patterns (test files, node_modules, vendor, dist, build).

Collect all findings with:
- File path and line number
- The matched content
- Category and severity

## Step 3: Classify Findings

Classify each finding:

| Severity | Criteria | Action |
|----------|----------|--------|
| **CRITICAL** | Security vulnerability, data leak, broken functionality | Must fix |
| **WARNING** | Debug artifacts, performance issues, quality concerns | Should fix |
| **INFO** | Minor items, TODOs, suggestions | Optional |

## Step 4: Present Report

```
Production Readiness Scan

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL (<count>)

  [Security] Hardcoded API key
    src/config/api.ts:23 — API_KEY = "sk-..."
    → Move to environment variable

  [Security] SQL injection risk
    src/db/queries.ts:45 — `SELECT * FROM users WHERE name = '${name}'`
    → Use parameterized queries

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WARNING (<count>)

  [Debug] console.log statements
    src/auth/login.ts:12
    src/api/handler.ts:34, 67
    → Remove before shipping

  [Performance] Unbounded query
    src/db/users.ts:89 — SELECT * FROM orders WHERE user_id = ?
    → Add LIMIT clause

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INFO (<count>)

  [Quality] TODO comments
    src/utils/parser.ts:15 — TODO: optimize this
    src/auth/session.ts:78 — FIXME: handle edge case

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Summary: <X> critical, <Y> warnings, <Z> info
Files scanned: <count>
```

## Step 5: Offer Fixes

If there are critical or warning issues:

> Would you like me to fix any of these issues?
>
> **Auto-fixable**: <list items that can be fixed programmatically>
> **Manual review needed**: <list items needing human judgment>

For auto-fixable items (like removing console.logs, moving secrets to env vars), present each fix for approval before applying.

## Key Rules

- **Exclude test files and vendor code** — these are not production code
- **Minimize false positives** — only flag patterns that are genuinely concerning
- **Context matters** — a `console.log` in a CLI tool's main output is fine; in an API handler it's not
- **Be specific** — always cite exact file paths and line numbers
- **Don't duplicate linter findings** — if the project has eslint configured with `no-console`, don't flag console.logs (the linter catches those)
