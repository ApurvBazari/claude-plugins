# Prod-Check Grep Patterns

Patterns to search for during production readiness scans. Use with Grep tool, excluding `node_modules/`, `vendor/`, `dist/`, `build/`, `.git/`, and test files.

## Debug Artifacts

| Pattern | Language | Notes |
|---------|----------|-------|
| `console\.(log\|debug\|warn)` | JS/TS | Exclude logger setup files |
| `\bdebugger\b` | JS/TS | Always a debug artifact |
| `\bprint\(` | Python | Distinguish from logging |
| `\bprintln!\(` | Rust | Distinguish from intended output |
| `\bfmt\.Print` | Go | Distinguish from intended output |
| `\bbinding\.pry\b` | Ruby | Always a debug artifact |
| `\bbyebug\b` | Ruby | Always a debug artifact |
| `\bTODO\b\|FIXME\|HACK\|XXX` | All | Check comment context |
| `@ts-ignore\|@ts-nocheck\|eslint-disable` | TS/JS | Flag if no explanation comment |

## Security

| Pattern | Category | Notes |
|---------|----------|-------|
| `(api[_-]?key\|secret\|password\|token)\s*[:=]\s*['"][^'"]{8,}` | Hardcoded secrets | Check if it's a placeholder |
| `-----BEGIN (RSA\|DSA\|EC\|OPENSSH) PRIVATE KEY` | Private keys | Always critical |
| `http://(?!localhost\|127\.0\.0\.1\|0\.0\.0\.0)` | Insecure HTTP | Exclude local dev URLs |
| `eval\(\|exec\(\|Function\(` | Code execution | Check for dynamic input |
| `csrf_exempt\|@no_auth\|verify\s*=\s*False` | Disabled security | Context-dependent |
| `Access-Control-Allow-Origin.*\*` | Permissive CORS | Check if production config |

## Performance

| Pattern | Category | Notes |
|---------|----------|-------|
| `SELECT\s+\*\s+FROM(?!.*LIMIT)` | Unbounded query | Multi-line check needed |
| `readFileSync\|writeFileSync` | Sync I/O in async | Check if in async context |
| `import\s+\w+\s+from\s+['"]lodash['"]` | Full library import | Should use lodash/specific |
| `import\s+\*\s+as` | Wildcard import | May prevent tree-shaking |

## Code Quality

| Pattern | Category | Notes |
|---------|----------|-------|
| `catch\s*\([^)]*\)\s*\{\s*\}` | Empty catch | Swallowed error |
| `catch\s*\{[\s]*\}` | Empty catch (alt) | Language variants |
| `(?:0x[0-9a-f]+\|[0-9]{4,})(?!\s*[;,\])])` | Magic numbers | Many false positives — use judgment |
