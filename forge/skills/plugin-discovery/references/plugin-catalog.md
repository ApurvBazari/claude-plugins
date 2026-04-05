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

## Catalog Freshness

This catalog is a point-in-time snapshot. For discovering new plugins not listed here, use the web search step in the plugin-discovery skill. Update this catalog periodically as the ecosystem evolves.
