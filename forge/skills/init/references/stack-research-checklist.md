# Stack Research Checklist

Single source of truth for the research questions answered during forge Phase 1 Step 2 (Tech Stack). Both the `stack-researcher` agent and `context-gathering/SKILL.md` (when running in main-session fallback mode) follow this checklist verbatim — keeping one document avoids drift between the agent prompt and the inline fallback.

When invoked, run all sections in order against the user's stack inputs. Skip a section only if it's clearly not applicable (e.g., skip "Frontend ecosystem" for a backend-only API).

---

## 0. Probe (run FIRST — folds into the actual research, zero overhead)

**Probe = the first real research call**: invoke `WebFetch` against the npm registry for the first detected stack package. For example, if the user said "Next.js", fetch `https://registry.npmjs.org/next`. If the call returns a JSON body containing `versions`, web access works — proceed with the rest of the checklist using the response data already in hand.

If the call fails (denied, network error, empty body), **emit the sentinel response** (see Output § Sentinel) and stop. Do NOT spend further turns trying to work around the limitation; the calling skill will fall back to main-session research.

This probe-first-call approach has **zero overhead when web works** — the failed-call path is the only cost, and that path was going to fail anyway.

---

## 1. Current Version

For each framework / library in the stack:
- Latest stable version (with release date — flag if < 1 month old, since CLIs may not support it yet).
- Recent major-version changes that affect scaffold defaults.

Source preference: official package registry (`registry.npmjs.org`, `pypi.org`, `crates.io`, `pkg.go.dev`) → official docs site → GitHub releases.

## 2. Official Scaffold CLI

For each framework that has an official CLI:
- Command + most-current flags (e.g., `pnpm create next-app@latest . --ts --tailwind --eslint --app --turbopack`).
- Whether it has interactive mode AND accepts all options as flags (forge needs the all-flags variant for headless).
- Default choices made (TypeScript on/off, linting, styling, app router vs pages, etc.).

If no official CLI exists, document the conventional alternative (e.g., manual `cargo new` + community template, or `uv init` for Python).

## 3. Recommended Project Structure

Fetch the framework's official getting-started guide. Extract:
- Standard directory layout (top-level + first nested level).
- Key configuration files and their purposes.
- Entry-point files.
- Naming conventions (kebab-case, PascalCase, snake_case).

## 4. Best Practices (current year)

Search current-year guidance:
- Recommended patterns (e.g., Server Components for Next.js, async handlers for FastAPI).
- Configuration defaults to set at scaffold time (e.g., `strict: true` in tsconfig, `pyproject.toml` strict-typing flags).
- Anti-patterns to avoid.
- Migration notes if upgrading from a previous major version.

## 5. Companion Ecosystem

Find current-consensus companion libraries:
- Testing: which test runner pairs best.
- ORM / database client.
- Auth library (if applicable).
- Styling approach (frontend).
- State management (frontend).

Pick the option(s) you'd recommend, and note community alternatives so the developer can override.

## 6. Known Issues & Environment Requirements

- Recent breaking changes or migration pitfalls.
- Deprecated APIs the scaffold should avoid.
- Environment requirements (Node version, Python version, Rust toolchain channel, etc.).

## 7. Deployment Recommendations

- Official deployment target if any (e.g., "Next.js is built by Vercel").
- Community-recommended alternatives.
- Framework-specific deployment considerations (build output format, edge vs serverless, container baseline).

---

## Output

### Success — return a structured Markdown report

```
# Stack Research Report

## [Framework Name] v[version]
- **Latest stable**: [version] (released [date])
- **Scaffold CLI**: `[command with flags]`
- **Node/Python/Rust version required**: [version]

### Recommended Project Structure
[Directory tree or short description]

### Best Practices
- [Practice 1]
- [Practice 2]

### Companion Libraries
| Category | Recommended | Why |
|---|---|---|
| Testing | [library] | [reason] |
| ORM | [library] | [reason] |
| Auth | [library] | [reason] |
| Styling | [library] | [reason] |

### Known Issues
- [Issue 1]

### Deployment
- **Recommended**: [platform] — [reason]
- **Alternatives**: [platform 1], [platform 2]

### Sources
- [URL 1]
- [URL 2]
```

Be specific and factual. Only report what you actually find. If something is uncertain or varies by use case, say so.

### Sentinel — failure / no web access

When the probe in § 0 fails OR any subsequent research call returns an unrecoverable error (denied, network unreachable), emit this exact JSON object as the entire response:

```json
{
  "status": "STACK_RESEARCH_REQUIRES_MAIN_SESSION",
  "reason": "WebFetch denied (probe to npm registry failed)",
  "fallback": "Re-run stack research inline in main session per references/stack-research-checklist.md"
}
```

The string `STACK_RESEARCH_REQUIRES_MAIN_SESSION` is the literal marker the calling skill greps for. Do not paraphrase, translate, or wrap it. The `reason` field can vary; only `status` matters for routing.

The calling skill (`context-gathering/SKILL.md` Step 2) detects this sentinel and re-runs the checklist inline using main-session WebSearch/WebFetch (where per-call permission prompts reach the user directly). It does NOT re-dispatch the agent — that would just loop.
