# Built-in Skills Catalog

Maps project characteristics to Anthropic-provided built-in Claude Code commands and bundled skills used by emission Step 4 of the generation pipeline. These ship with Claude Code — no plugin install required. Every entry here is listed in the Claude Code commands reference (https://code.claude.com/docs/en/commands); never add a name that is only an example in the docs.

When `onboard:start` runs, wizard Step 7 presents a checkbox list of recommended built-in skills. Accepted entries are documented in the generated CLAUDE.md with project-specific usage examples.

See `lsp-plugin-catalog.md` for the sibling LSP catalog pattern and `mcp-guide.md` for the MCP catalog pattern.

## Catalog

### Core skills (always recommended)

These four are useful on every project and always pre-checked in the wizard.

| Skill | Description | When to use |
|---|---|---|
| `/loop` | Run a prompt repeatedly while the session stays open (e.g., `/loop 5m check the deploy`). Omit the interval to let Claude self-pace. | Polling deploy status, watching CI, monitoring test runs during refactoring, recurring health checks. |
| `/simplify` | Review the changed code for cleanup opportunities (reuse, simplification, efficiency, abstraction level) and apply the fixes. Doesn't look for bugs. | After landing a feature branch, before opening a PR, post-refactor cleanup. |
| `/code-review` | Review the current diff, or a PR, branch or path, for correctness bugs. `--fix` applies the findings. | Before committing or opening a PR, and when reviewing someone else's branch. |
| `/debug` | Turn on debug logging for the session and troubleshoot Claude Code itself (hooks, MCP servers, plugins) by reading the session debug log. | When a generated hook doesn't fire, an MCP server won't connect, or a plugin misbehaves. |

### Extra skills (conditionally recommended)

These four are recommended when project signals suggest they'd be useful. Each has a detection signal derived from the codebase analysis report. In the wizard, they're pre-checked when the signal fires and unchecked otherwise.

| Skill | Description | Detection signal | Analysis report field |
|---|---|---|---|
| `/schedule` | Create, update, list, or run cloud scheduled tasks (formerly routines): Claude runs a prompt on a cron schedule in the cloud. | CI/CD detected OR deploy frequency > none | `analysisReport.stack.ciCd` non-empty, OR `wizardAnswers.deployFrequency !== "none"` |
| `/claude-api` | Load Claude API and Anthropic SDK reference material for the project's language. | `anthropic` or `@anthropic-ai/sdk` in dependencies | `analysisReport.stack.dependencies` contains `anthropic` or `@anthropic-ai/sdk` |
| `/security-review` | Analyze the changes on the current branch for security vulnerabilities. | Complexity score ≥ medium OR >200 source files | `analysisReport.complexity.overall >= "medium"` OR `analysisReport.structure.sourceFileCount > 200` |
| `/batch` | Orchestrate a large change across the codebase in parallel: plan it as independent units, then run one background agent per unit in its own worktree. | >50 source files | `analysisReport.structure.sourceFileCount > 50` |

## Stack-specific example templates

When generating the CLAUDE.md subsection, pick the example that best matches the project's primary detected stack (highest file count). If multiple stacks are detected, use the primary. If no specific stack matches, use the general fallback.

### Frontend (React, Next.js, Vue, Svelte, Angular)

| Skill | Example |
|---|---|
| `/loop` | `/loop 5m npm run dev` to watch for HMR errors or build failures during development. |
| `/simplify` | After adding a new component, run `/simplify` to catch prop-drilling, duplicate handlers, or missed memoization. |
| `/code-review` | Run `/code-review` before requesting review on a UI feature branch to catch broken props, missed effect cleanups, and unhandled loading states. |
| `/debug` | If the generated format-on-save hook stops firing, run `/debug` and read the session log to see why. |
| `/schedule` | Schedule a nightly Lighthouse audit to track performance regressions across deploys. |
| `/claude-api` | Use when building AI-powered UI features that call the Anthropic SDK from API routes. |
| `/security-review` | Run on a branch that touches auth flows, cookies, or user-supplied HTML before merging. |
| `/batch` | Refactor all form components to use the new validation library, or migrate CSS modules to Tailwind across all pages. |

### Backend (Node/Express, Python/FastAPI/Django, Go, Rust, Ruby/Rails)

| Skill | Example |
|---|---|
| `/loop` | `/loop 5m curl -s localhost:3000/health` to poll the local dev server while debugging a crash loop. |
| `/simplify` | After landing a new API endpoint, run `/simplify` to consolidate middleware, reduce error-handling duplication. |
| `/code-review` | Run `/code-review` on a branch with new API routes or migrations to catch missing error handling and edge cases. |
| `/debug` | If an MCP server from `.mcp.json` won't connect, run `/debug` and read the session log for the failure. |
| `/schedule` | Schedule a weekly dependency audit to check for known vulnerabilities and outdated packages. |
| `/claude-api` | Use when building AI-powered API endpoints that proxy or orchestrate Anthropic SDK calls. |
| `/security-review` | Run on changes to auth middleware, query builders, or input validation before merging. |
| `/batch` | Add input validation to all API endpoints, or update all database queries to use parameterized statements. |

### CLI / tooling (CLIs, scripts, dev tools, build systems)

| Skill | Example |
|---|---|
| `/loop` | `/loop 2m make test` to continuously run the test suite while iterating on a fix. |
| `/simplify` | After adding a new subcommand, run `/simplify` to consolidate flag parsing and reduce boilerplate. |
| `/code-review` | Run `/code-review` on a new subcommand to catch flag-parsing and exit-code bugs before release. |
| `/debug` | If a generated pre-commit hook blocks unexpectedly, run `/debug` and read the session log to see which hook ran. |
| `/schedule` | Schedule a bi-weekly tooling audit to flag deprecated dependencies or unused scripts. |
| `/claude-api` | Use when building CLI tools that interact with the Claude API for code generation or analysis. |
| `/security-review` | Run on changes that shell out, read config files, or handle credentials. |
| `/batch` | Rename a flag across all subcommands, or update all script shebangs to use `#!/usr/bin/env bash`. |

### General (fallback — no specific stack match)

| Skill | Example |
|---|---|
| `/loop` | `/loop 5m npm test` to watch for regressions while refactoring across multiple files. |
| `/simplify` | After landing a feature, run `/simplify` to clean up before opening a PR. |
| `/code-review` | Run `/code-review` before committing to catch correctness bugs in the current diff. |
| `/debug` | If a hook or MCP server onboard generated misbehaves, run `/debug` and read the session log. |
| `/schedule` | Schedule a recurring cloud task to audit code quality or check for dependency updates. |
| `/claude-api` | Use when building features that integrate with the Anthropic SDK. |
| `/security-review` | Run on a branch before merging to check the changes for security vulnerabilities. |
| `/batch` | Apply the same refactoring pattern across all files matching a convention (e.g., update all test fixtures). |

## Detection notes

- **Core skills have no detection signal** — they're universally useful and always pre-checked. The wizard still lets developers uncheck them.
- **Extra skill detection is additive** — detecting a signal means the skill is pre-checked, not that it's forced. Developers can always add extras that weren't auto-detected.
- **No new probe script needed** — all detection signals reference fields already present in the recon analysis report (native script-free recon — see `../../../../agents/codebase-analyzer.md`).
- **Stack category for examples** is determined by the primary detected stack (highest source file count). When the analysis report identifies multiple frameworks, use the primary.

## Adding a new built-in skill

When Anthropic ships a new built-in skill worth recommending:

0. Confirm it is listed in the Claude Code commands reference (https://code.claude.com/docs/en/commands) as a command or bundled skill. A skill that only appears as an example in the skills docs is not built in.
1. Add a row to the appropriate catalog table (core or extra) with the skill name, description, and detection signal.
2. Add stack-specific example rows to all four template tables.
3. If the skill is an extra, add the detection signal field reference.
4. Bump onboard minor version.
5. No changes needed in `../../../wizard/SKILL.md` or `../../SKILL.md` — both consume the catalog generically via the tier classification.

## Removing a built-in skill

If Anthropic deprecates or removes a built-in skill:

1. Remove the row from the catalog table.
2. Remove the corresponding example rows from all four template tables.
3. The drift handler in `../../../update/SKILL.md` Step 4b.9 will classify the skill as `staleCandidate` on the next run.
4. Bump onboard minor version.
