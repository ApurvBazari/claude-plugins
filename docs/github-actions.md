# GitHub Actions CI — Claude Code Integration

## Overview

This repo uses Claude Code GitHub Actions to automatically review PRs and provide interactive assistance via comments. Three capabilities are available:

- **Auto PR review** — every PR gets a code review from Claude (Opus)
- **Interactive help** — comment `@claude` for fast Sonnet assistance or `@claude-opus` for deeper Opus analysis
- **Security review** — comment `@claude security-review` for a focused security audit

## Prerequisites

1. **Claude GitHub App** — must be installed on the repository ([install link](https://github.com/apps/claude))
2. **OAuth token** — generated via `claude setup-token` (Claude Max subscription required), stored as the GitHub Actions secret `CLAUDE_CODE_OAUTH_TOKEN`

### Setting up the token

```bash
claude setup-token
```

Copy the token and add it as a repository secret:

**Settings → Secrets and variables → Actions → New repository secret**
- Name: `CLAUDE_CODE_OAUTH_TOKEN`
- Value: the token from `claude setup-token`

## Workflows

| Workflow | Job | Trigger | Model | Max Turns |
|----------|-----|---------|-------|-----------|
| `claude.yml` | `pr-review` | PR opened/synced | Opus 4.6 | 5 |
| `claude.yml` | `claude-sonnet` | `@claude` comment | Sonnet 4.6 | 10 |
| `claude.yml` | `claude-opus` | `@claude-opus` comment | Opus 4.6 | 10 |
| `security-review.yml` | `security-review` | `@claude security-review` comment | Opus 4.6 | 5 |

## Usage

### Automatic PR review

Open or push to a PR — Claude reviews the changes automatically.

### Interactive assistance

Comment on any PR:

```
@claude what does the onboard plugin do?
```

For complex questions requiring deeper analysis:

```
@claude-opus explain the architecture of the notify plugin
```

### Security review

```
@claude security-review
```

Produces a structured audit covering OWASP Top 10, plugin-specific concerns (shell injection, manifest integrity, credential handling), and general security best practices.

## Customization

### Changing models

Edit `claude_args` in the workflow file:

```yaml
claude_args: "--model claude-sonnet-4-6 --max-turns 5"
```

Available models: `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`

### Adjusting max turns

Increase `--max-turns` for more complex tasks (higher token usage).

### Adding tools

Use the `allowed_tools` input on the action to grant access to MCP tools or additional CLI capabilities.

## Token Management

- OAuth tokens from `claude setup-token` are valid for **1 year**
- Set a calendar reminder to refresh before expiry
- To refresh: run `claude setup-token` again and update the GitHub secret
- If CI jobs fail with auth errors, the token has likely expired
