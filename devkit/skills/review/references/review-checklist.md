# Review Checklist by Category

## Code Quality & Style

### JavaScript / TypeScript
- Prefer `const` over `let`, avoid `var`
- Use strict equality (`===`)
- Avoid `any` type in TypeScript — use proper types or generics
- Prefer async/await over raw promises
- Check for proper error handling in async code (try/catch or .catch)
- Avoid deeply nested callbacks
- Check for proper cleanup in effects/subscriptions (React useEffect, event listeners)

### Python
- Follow PEP 8 naming conventions
- Use type hints for function signatures
- Prefer list/dict comprehensions over manual loops where readable
- Check for proper context managers (`with` for files, connections)
- Avoid mutable default arguments
- Use `pathlib` over `os.path` for path manipulation

### Go
- Check error returns — every error must be handled or explicitly ignored
- Use meaningful variable names (not single letters except in short loops)
- Follow Go naming conventions (exported = PascalCase, unexported = camelCase)
- Check for goroutine leaks — ensure goroutines can exit
- Use `context.Context` for cancellation propagation

### Rust
- Check for proper error handling (Result/Option, avoid unwrap in production code)
- Verify ownership and borrowing patterns are correct
- Check for proper use of lifetimes
- Prefer iterators over manual indexing
- Check for proper Send/Sync bounds on concurrent code

### Ruby
- Follow Ruby style guide conventions
- Check for proper use of blocks, procs, and lambdas
- Verify ActiveRecord query efficiency (avoid N+1)
- Check for proper error handling (begin/rescue)

## Security (OWASP Top 10)

### Injection
- SQL: parameterized queries only, no string concatenation
- XSS: output encoding, sanitize user input before rendering
- Command injection: no shell exec with user input, use parameterized APIs
- Path traversal: validate and sanitize file paths

### Authentication & Authorization
- Password handling: hashing with bcrypt/argon2, never plaintext
- Session management: secure cookies, proper expiry
- Access control: check permissions on every protected route
- Token handling: proper validation, expiry, refresh flow

### Sensitive Data
- No secrets in code (API keys, passwords, tokens)
- No PII in logs
- Proper encryption for data at rest and in transit
- Check .gitignore for sensitive files

### Dependencies
- Check for known vulnerabilities in new dependencies using the appropriate audit tool:
  - **npm/pnpm/yarn**: `npm audit` / `pnpm audit` / `yarn audit`
  - **Python**: `pip-audit` or `safety check`
  - **Go**: `govulncheck ./...`
  - **Rust**: `cargo audit`
  - **Ruby**: `bundle audit`
- Avoid unnecessary new dependencies
- Pin dependency versions appropriately

## Test Coverage

### What to Check
- New public functions/methods have tests
- Error paths are tested (not just happy path)
- Edge cases: null, empty, boundary values, large inputs
- Async behavior is tested with proper awaits/assertions
- Mocks are used appropriately (not mocking everything)
- Test names describe the behavior being tested

### Red Flags
- Tests that assert implementation details (brittle)
- Tests with no assertions
- Commented-out tests
- Tests that depend on external services without mocks
- Flaky test patterns (timing, order-dependent)

## Performance & Correctness

### Database
- N+1 query patterns
- Missing indexes for frequent queries
- Unbounded queries (no LIMIT)
- Proper connection pooling

### Memory & Resources
- Large data structures held in memory unnecessarily
- Missing cleanup (close, dispose, unsubscribe)
- Unbounded caches or growing collections

### Concurrency
- Race conditions on shared state
- Proper locking/synchronization
- Deadlock potential
- Promise/future error handling

### API Design
- Proper HTTP status codes
- Consistent error response format
- Input validation at boundaries
- Rate limiting considerations
