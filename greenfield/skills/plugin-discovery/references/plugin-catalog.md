# Curated Plugin Catalog

Vetted Claude Code plugins organized by category with matching rules. Use this catalog to generate recommendations based on the developer's project context.

## Marketplace column schema

Every plugin row has a **Marketplace** column with the install identifier and marketplace-add source. Format:

```
`<plugin-name>@<marketplace-name>` _(add: `<owner/repo or URL>`; <optional attribution>)_
```

The `plugin-discovery` skill parses this column directly to drive the install sequence:
1. Collect each unique `add: <source>` value → run `claude plugin marketplace add <source>` (idempotent).
2. For each selected plugin → run `claude plugin install <plugin-name>@<marketplace-name> --scope user`.

Entries marked `@TODO-verify-marketplace` are awaiting first-use verification — the skill must flag these to the user as "marketplace source unconfirmed; verify or skip" rather than attempt blind install.

## Universal Plugins (always recommend)

| Plugin | Marketplace | What it does | Key commands |
|---|---|---|---|
| **superpowers** | `superpowers@claude-plugins-official` _(add: `anthropics/claude-plugins-official`; community origin: obra)_ | Planning, TDD, debugging, code review, parallel agents | `/plan`, `/tdd`, `/debug` |
| **commit-commands** | `commit-commands@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Git workflow automation | `/commit`, `/commit-push-pr` |
| **security-guidance** | `security-guidance@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Hook-based security warnings on file edits | (passive hook) |
| **hookify** | `hookify@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Create behavioral guardrails from natural language | `/hookify` |
| **claude-md-management** | `claude-md-management@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Audit and improve CLAUDE.md quality over time | `/revise-claude-md` |
| **notify** | `notify@apurvbazari-plugins` _(add: `apurvbazari/claude-plugins`)_ | Cross-platform system notifications when Claude finishes tasks or needs attention | `/notify:setup`, `/notify:status` |

### Planning Rigor (Universal)

These plugins reinforce the discipline of *thinking before coding* — both for greenfield's own pre-scaffold gate and for downstream feature work in the scaffolded project.

| Plugin | Marketplace | What it does | Key skills |
|---|---|---|---|
| **grill-me** (mattpocock-skills) | `grill-me@TODO-verify-marketplace` _(add source unverified; upstream: mattpocock)_ | Relentless interview that walks every decision branch in a plan until shared understanding is reached. Drives greenfield's Phase 1.7 grill-spec gate when installed. | `grill-me` |
| **andrej-karpathy-skills** | `andrej-karpathy-skills@TODO-verify-marketplace` _(add source unverified; upstream: forrestchang)_ | Bakes Karpathy's 4 LLM-coding principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) into Claude Code as a CLAUDE.md-merge skill | `karpathy-guidelines` |

## Stack-Conditional Plugins

### Frontend (hasFrontend = true)

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **frontend-design** | `frontend-design@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Any frontend project | Creative, production-grade UI development |
| **playwright** | `playwright@claude-plugins-official` _(add: `anthropics/claude-plugins-official`; upstream: Microsoft)_ | Web app + testing enabled | Browser automation and E2E testing |

### API / Backend (hasAPI = true OR hasBackend = true)

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **feature-dev** | `feature-dev@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Any project with features to build | Guided 7-phase feature development |

### Database (hasDatabase = true)

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **context7** | `context7@claude-plugins-official` _(add: `anthropics/claude-plugins-official`; upstream: Upstash)_ | Uses ORM or external libraries | Up-to-date, version-specific docs lookup |

### Security (securitySensitivity = "elevated" OR "high")

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **Trail of Bits skills** | `trail-of-bits-skills@TODO-verify-marketplace` _(add source unverified; upstream: Trail of Bits)_ | Elevated+ security | Professional security auditing (CodeQL, Semgrep) |

## Workflow-Conditional Plugins

### Version Control (willDeploy = true)

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **github** | `github@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Uses GitHub | Full GitHub API: PRs, issues, Actions, releases |
| **gitlab** | `gitlab@TODO-verify-marketplace` _(add source unverified; not yet present in `claude-plugins-official` at last check)_ | Uses GitLab | Full GitLab API: MRs, CI/CD, issues |

### Code Review (hasTeam = true)

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **code-review** | `code-review@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Team project | Multi-agent confidence-scored code review |
| **pr-review-toolkit** | `pr-review-toolkit@claude-plugins-official` _(add: `anthropics/claude-plugins-official`)_ | Team + formal PR process | Specialized review agents (tests, types, errors) |

### Documentation Rigor (hasDocsDiscipline = true)

For projects following an ADR-driven or structured design-doc `docs/` discipline.

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **grill-with-docs** (mattpocock-skills) | `grill-with-docs@TODO-verify-marketplace` _(add source unverified; upstream: mattpocock)_ | hasDocsDiscipline = true | Requirements interview that maintains ADRs and CONTEXT.md alongside design decisions |

### Testing (testingPhilosophy = "tdd")

| Plugin | Marketplace | Condition | What it does |
|---|---|---|---|
| **superpowers** | `superpowers@claude-plugins-official` _(see Universal Plugins row above)_ | TDD selected | Includes TDD workflow skill (already in universal) |

## Matching Algorithm

For each plugin in the catalog:

1. Check its condition against the project context
2. If condition matches, add to recommendations
3. Tag as "recommended" (universal) or "matches: [reason]" (conditional)
4. Deduplicate (superpowers appears in both universal and TDD)

### Context flags

The catalog's condition expressions reference these context flags. Most are populated by `greenfield/skills/context-gathering/SKILL.md` from wizard answers; some have defaults.

| Flag | Source | Default | Used by |
|---|---|---|---|
| `hasFrontend`, `hasBackend`, `hasAPI`, `hasDatabase` | Inferred from Q1.1, Q3.7 | `false` | Stack-Conditional rows |
| `hasTeam` | Q3.1 (team size > 1) | `false` | Code Review row |
| `willDeploy` | Q3.4 (deploy target ≠ "none") | `false` | VCS row |
| `securitySensitivity` | Q4.4 | `"baseline"` | Security row |
| `testingPhilosophy` | Q4.3 | `"pragmatic"` | Testing row |
| `hasDocsDiscipline` | Q4.5 (workflow preferences) — `true` if user mentions ADRs, CONTEXT.md, or a structured design-doc workflow, OR if `hasTeam: true` AND `isProduction: true` | `false` | Documentation Rigor row |
| `wantsValidationGate` | Defaults to `true` for `isProduction: true` projects; user can opt out during the plugin-discovery checklist | `isProduction` | gates whether greenfield's Phase 1.7 grill-spec runs by default |

### Priority Order in Checklist

1. Universal plugins (recommended for all projects)
2. Stack-specific matches (ordered by relevance)
3. Workflow-specific matches

### Maximum Recommendations

Aim for 5-8 total recommendations. If more than 8 match, prioritize:
1. Universal plugins (always include)
2. Plugins matching multiple conditions
3. Official Anthropic plugins over community
4. Community plugins with high GitHub stars

## Capability Mapping

Each plugin covers specific capabilities. When a plugin is installed, its capabilities are added to the `coveredCapabilities` list, which tells onboard headless to skip generating agents for those capabilities.

| Plugin | Capabilities Covered |
|---|---|
| **superpowers** | `test-generation`, `debugging`, `planning`, `code-review` |
| **feature-dev** | `feature-development`, `code-review` |
| **code-review** | `code-review` |
| **pr-review-toolkit** | `code-review`, `code-simplification` |
| **security-guidance** | `security-audit` |
| **commit-commands** | `git-workflow` |
| **hookify** | `behavioral-guardrails` |
| **claude-md-management** | `documentation` |
| **frontend-design** | `ui-development` |
| **playwright** | `e2e-testing` |
| **context7** | `docs-lookup` |
| **Trail of Bits skills** | `security-audit` |
| **github** | `vcs-integration` |
| **gitlab** | `vcs-integration` |
| **notify** | `session-monitoring` |
| **mattpocock-skills (grill-me)** | `plan-validation` |
| **mattpocock-skills (grill-with-docs)** | `requirements-discovery`, `adr-maintenance` |
| **andrej-karpathy-skills** | `coding-discipline` |

> **Disambiguation note**: `superpowers` covers `planning` (the *generative* capability — drafting a plan). `mattpocock-skills:grill-me` covers `plan-validation` (the *critical* capability — stress-testing an existing plan). Both can coexist; they're complementary, not redundant.

### How to Build the coveredCapabilities List

After the developer selects plugins to install (Step 2 of plugin-discovery skill):

1. For each selected plugin, look up its capabilities in the table above
2. Combine all capabilities into a deduplicated list
3. Pass the list to the tooling-generation skill as `coveredCapabilities`
4. The tooling-generation skill passes it to onboard headless via `callerExtras`

Example: Developer installs `superpowers` + `feature-dev` + `security-guidance`:
```json
{
  "installedPlugins": ["superpowers", "feature-dev", "security-guidance"],
  "coveredCapabilities": ["test-generation", "debugging", "planning", "code-review", "feature-development", "security-audit"]
}
```

Result: onboard skips generating `code-reviewer.md`, `test-writer.md`, `security-checker.md`, and `feature-builder.md`. Only generates gap-filling, project-specific agents.

## Catalog Freshness

This catalog is a point-in-time snapshot. For discovering new plugins not listed here, use the web search step in the plugin-discovery skill. Update this catalog periodically as the ecosystem evolves.
