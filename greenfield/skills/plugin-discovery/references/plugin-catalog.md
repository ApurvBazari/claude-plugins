# Curated Plugin Catalog

Vetted Claude Code plugins organized by category with matching rules. Use this catalog to generate recommendations based on the developer's project context.

## Universal Plugins (always recommend)

| Plugin | Source | What it does | Key commands |
|---|---|---|---|
| **superpowers** | Community (obra) | Planning, TDD, debugging, code review, parallel agents | `/plan`, `/tdd`, `/debug` |
| **commit-commands** | Official (Anthropic) | Git workflow automation | `/commit`, `/commit-push-pr` |
| **security-guidance** | Official (Anthropic) | Hook-based security warnings on file edits | (passive hook) |
| **hookify** | Official (Anthropic) | Create behavioral guardrails from natural language | `/hookify` |
| **claude-md-management** | Official (Anthropic) | Audit and improve CLAUDE.md quality over time | `/revise-claude-md` |
| **notify** | In-repo (apurvbazari) | Cross-platform system notifications when Claude finishes tasks or needs attention | `/notify:setup`, `/notify:status` |

## Stack-Conditional Plugins

### Frontend (hasFrontend = true)

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **frontend-design** | Official (Anthropic) | Any frontend project | Creative, production-grade UI development |
| **playwright** | Official directory (Microsoft) | Web app + testing enabled | Browser automation and E2E testing |

### API / Backend (hasAPI = true OR hasBackend = true)

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **feature-dev** | Official (Anthropic) | Any project with features to build | Guided 7-phase feature development |

### Database (hasDatabase = true)

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **context7** | Official directory (Upstash) | Uses ORM or external libraries | Up-to-date, version-specific docs lookup |

### Security (securitySensitivity = "elevated" OR "high")

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **Trail of Bits skills** | Community | Elevated+ security | Professional security auditing (CodeQL, Semgrep) |

## Workflow-Conditional Plugins

### Version Control (willDeploy = true)

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **github** | Official directory (GitHub) | Uses GitHub | Full GitHub API: PRs, issues, Actions, releases |
| **gitlab** | Official directory (GitLab) | Uses GitLab | Full GitLab API: MRs, CI/CD, issues |

### Code Review (hasTeam = true)

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **code-review** | Official (Anthropic) | Team project | Multi-agent confidence-scored code review |
| **pr-review-toolkit** | Official (Anthropic) | Team + formal PR process | Specialized review agents (tests, types, errors) |

### Testing (testingPhilosophy = "tdd")

| Plugin | Source | Condition | What it does |
|---|---|---|---|
| **superpowers** | Community (obra) | TDD selected | Includes TDD workflow skill (already in universal) |

## Matching Algorithm

For each plugin in the catalog:

1. Check its condition against the project context
2. If condition matches, add to recommendations
3. Tag as "recommended" (universal) or "matches: [reason]" (conditional)
4. Deduplicate (superpowers appears in both universal and TDD)

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
