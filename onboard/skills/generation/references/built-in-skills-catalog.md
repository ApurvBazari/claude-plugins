# Built-in Skills Catalog

Maps project characteristics to Anthropic-provided built-in Claude Code skills used by Phase 7d of the generation pipeline. These skills are available in every Claude Code session — no plugin install required.

When `onboard:init` runs, wizard Phase 5.7 presents a checkbox list of recommended built-in skills. Accepted entries are documented in the generated CLAUDE.md with project-specific usage examples.

See `lsp-plugin-catalog.md` for the sibling LSP catalog pattern and `mcp-guide.md` for the MCP catalog pattern.

## Catalog

### Core skills (always recommended)

These four skills are universally useful and always pre-checked in the wizard.

| Skill | Description | When to use |
|---|---|---|
| `/loop` | Run a prompt or slash command on a recurring interval (e.g., `/loop 5m /foo`). Omit the interval to let the model self-pace. | Polling deploy status, watching CI, monitoring test runs during refactoring, recurring health checks. |
| `/simplify` | Review recently changed code for reuse, quality, and efficiency, then fix any issues found. | After landing a feature branch, before opening a PR, post-refactor cleanup. |
| `/debug` | Systematic debugging of bugs and test failures — traces root causes, proposes targeted fixes. | When a test fails, a stack trace appears, or behavior diverges from expectations. |
| `/pr-summary` | Summarize pull request changes for review — generates concise descriptions of what changed and why. | Before submitting a PR, when reviewing someone else's PR, or when catching up on merged work. |

### Extra skills (conditionally recommended)

These five skills are recommended when project signals suggest they'd be useful. Each has a detection signal derived from the codebase analysis report. In the wizard, they're pre-checked when the signal fires and unchecked otherwise.

| Skill | Description | Detection signal | Analysis report field |
|---|---|---|---|
| `/schedule` | Create, update, list, or run scheduled remote agents (triggers) that execute on a cron schedule. | CI/CD detected OR deploy frequency > none | `analysisReport.stack.ciCd` non-empty, OR `wizardAnswers.deployFrequency !== "none"` |
| `/claude-api` | Build, debug, and optimize Claude API / Anthropic SDK applications. | `anthropic` or `@anthropic-ai/sdk` in dependencies | `analysisReport.stack.dependencies` contains `anthropic` or `@anthropic-ai/sdk` |
| `/explain-code` | Deep code explanation with context — traces execution paths, explains design decisions. | Complexity score ≥ medium OR >200 source files | `analysisReport.complexity.overall >= "medium"` OR `analysisReport.structure.sourceFileCount > 200` |
| `/codebase-visualizer` | Visualize codebase architecture — generates diagrams of component relationships and data flows. | >200 source files OR monorepo structure | `analysisReport.structure.sourceFileCount > 200` OR `analysisReport.structure.monorepo === true` |
| `/batch` | Batch operations across multiple files — run the same prompt or transformation across a set of targets. | >50 source files | `analysisReport.structure.sourceFileCount > 50` |

## Stack-specific example templates

When generating the CLAUDE.md subsection, pick the example that best matches the project's primary detected stack (highest file count). If multiple stacks are detected, use the primary. If no specific stack matches, use the general fallback.

### Frontend (React, Next.js, Vue, Svelte, Angular)

| Skill | Example |
|---|---|
| `/loop` | `/loop 5m npm run dev` to watch for HMR errors or build failures during development. |
| `/simplify` | After adding a new component, run `/simplify` to catch prop-drilling, duplicate handlers, or missed memoization. |
| `/debug` | Paste a React error boundary stack trace and run `/debug` to trace the component tree to the source. |
| `/pr-summary` | Run `/pr-summary` before requesting review on a UI feature branch to auto-generate a summary of component and style changes. |
| `/schedule` | Schedule a nightly Lighthouse audit agent to track performance regressions across deploys. |
| `/claude-api` | Use when building AI-powered UI features that call the Anthropic SDK from API routes. |
| `/explain-code` | Run on complex hooks, context providers, or state management logic to understand data flow. |
| `/codebase-visualizer` | Generate a component dependency graph to understand the render tree and shared state boundaries. |
| `/batch` | Refactor all form components to use the new validation library, or migrate CSS modules to Tailwind across all pages. |

### Backend (Node/Express, Python/FastAPI/Django, Go, Rust, Ruby/Rails)

| Skill | Example |
|---|---|
| `/loop` | `/loop 5m curl -s localhost:3000/health` to poll the local dev server while debugging a crash loop. |
| `/simplify` | After landing a new API endpoint, run `/simplify` to consolidate middleware, reduce error-handling duplication. |
| `/debug` | Paste a 500 error response with stack trace and run `/debug` to trace through middleware, services, and DB layers. |
| `/pr-summary` | Run `/pr-summary` to auto-generate a summary of API route changes, migration files, and config updates. |
| `/schedule` | Schedule a weekly dependency-audit agent to check for known vulnerabilities and outdated packages. |
| `/claude-api` | Use when building AI-powered API endpoints that proxy or orchestrate Anthropic SDK calls. |
| `/explain-code` | Run on complex query builders, auth middleware chains, or transaction-handling code to understand the flow. |
| `/codebase-visualizer` | Generate a service dependency graph showing how controllers, services, and repositories connect. |
| `/batch` | Add input validation to all API endpoints, or update all database queries to use parameterized statements. |

### CLI / tooling (CLIs, scripts, dev tools, build systems)

| Skill | Example |
|---|---|
| `/loop` | `/loop 2m make test` to continuously run the test suite while iterating on a fix. |
| `/simplify` | After adding a new subcommand, run `/simplify` to consolidate flag parsing and reduce boilerplate. |
| `/debug` | Paste a failing CI log and run `/debug` to trace the failure through build steps and script invocations. |
| `/pr-summary` | Run `/pr-summary` to summarize changes across scripts, configs, and build definitions. |
| `/schedule` | Schedule a bi-weekly tooling-audit agent to flag deprecated dependencies or unused scripts. |
| `/claude-api` | Use when building CLI tools that interact with the Claude API for code generation or analysis. |
| `/explain-code` | Run on complex build scripts, Makefile targets, or pipeline definitions to understand the build flow. |
| `/codebase-visualizer` | Generate a module dependency graph to understand how packages and internal libraries connect. |
| `/batch` | Rename a flag across all subcommands, or update all script shebangs to use `#!/usr/bin/env bash`. |

### General (fallback — no specific stack match)

| Skill | Example |
|---|---|
| `/loop` | `/loop 5m npm test` to watch for regressions while refactoring across multiple files. |
| `/simplify` | After landing a feature, run `/simplify` to clean up before opening a PR. |
| `/debug` | Paste a stack trace and run `/debug` to systematically trace the root cause. |
| `/pr-summary` | Run `/pr-summary` before requesting review to auto-generate a concise change summary. |
| `/schedule` | Schedule a recurring agent to audit code quality or check for dependency updates on a cron schedule. |
| `/claude-api` | Use when building features that integrate with the Anthropic SDK. |
| `/explain-code` | Run on any complex function or module to get a detailed explanation of its logic and design. |
| `/codebase-visualizer` | Generate a high-level architecture diagram showing how the major modules connect. |
| `/batch` | Apply the same refactoring pattern across all files matching a convention (e.g., update all test fixtures). |

## Detection notes

- **Core skills have no detection signal** — they're universally useful and always pre-checked. The wizard still lets developers uncheck them.
- **Extra skill detection is additive** — detecting a signal means the skill is pre-checked, not that it's forced. Developers can always add extras that weren't auto-detected.
- **No new probe script needed** — all detection signals reference fields already present in the codebase analysis report (from `analyze-structure.sh`, `detect-stack.sh`, and `measure-complexity.sh`).
- **Stack category for examples** is determined by the primary detected stack (highest source file count). When the analysis report identifies multiple frameworks, use the primary.

## Adding a new built-in skill

When Anthropic ships a new built-in skill worth recommending:

1. Add a row to the appropriate catalog table (core or extra) with the skill name, description, and detection signal.
2. Add stack-specific example rows to all four template tables.
3. If the skill is an extra, add the detection signal field reference.
4. Bump onboard minor version.
5. No changes needed in `wizard/SKILL.md` or `generation/SKILL.md` — both consume the catalog generically via the 9-skill count and tier classification.

## Removing a built-in skill

If Anthropic deprecates or removes a built-in skill:

1. Remove the row from the catalog table.
2. Remove the corresponding example rows from all four template tables.
3. The drift handler in `update/SKILL.md` Step 4b.9 will classify the skill as `staleCandidate` on the next run.
4. Bump onboard minor version.
