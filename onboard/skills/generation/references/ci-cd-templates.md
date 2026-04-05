# CI/CD Pipeline Templates

Patterns for generating GitHub Actions workflows. Compose the right combination based on Phase 1 context — do not copy templates verbatim. Adapt commands, Node/Python versions, and triggers to match the actual project.

## Pipeline 1: Application CI

### Structure

```yaml
name: CI
on:
  push:
    branches: [main]            # adjust for branching strategy
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - # setup language runtime
      - # install dependencies
      - # run linter

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - # setup language runtime
      - # install dependencies
      - # run tests (with coverage if configured)

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - # setup language runtime
      - # install dependencies
      - # run build

  deploy:
    needs: [build]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - # deploy to target platform
```

### Lint Commands by Stack

| Stack | Setup | Command |
|---|---|---|
| Node.js/TypeScript | `actions/setup-node@v4` | `npm run lint` / `npx eslint .` |
| Python | `actions/setup-python@v5` | `ruff check .` / `flake8` / `mypy .` |
| Go | `actions/setup-go@v5` | `golangci-lint run` |
| Rust | `dtolnay/rust-toolchain@stable` | `cargo clippy -- -D warnings` |
| Ruby | `ruby/setup-ruby@v1` | `bundle exec rubocop` |

### Test Commands by Stack

| Stack | Command | Coverage |
|---|---|---|
| Node.js (Vitest) | `npx vitest run` | `--coverage` |
| Node.js (Jest) | `npx jest` | `--coverage` |
| Python (pytest) | `pytest` | `--cov` |
| Go | `go test ./...` | `-coverprofile=coverage.out` |
| Rust | `cargo test` | via `cargo-tarpaulin` |
| Ruby (RSpec) | `bundle exec rspec` | via SimpleCov |

### Deploy Commands by Target

| Target | Action/Command |
|---|---|
| Vercel | `vercel deploy --prod --token=$VERCEL_TOKEN` or Vercel GitHub integration (auto) |
| AWS (CDK) | `npx cdk deploy --require-approval never` |
| Docker (registry) | `docker build -t [image] . && docker push [image]` |
| Railway | Railway GitHub integration (auto) |
| Fly.io | `flyctl deploy` |
| Cloudflare Pages | Cloudflare GitHub integration (auto) |

### Branching Strategy Adjustments

| Strategy | Push trigger | Deploy condition |
|---|---|---|
| Simple | `branches: [main]` | `github.ref == 'refs/heads/main'` |
| Gitflow-lite | `branches: [main, develop]` | main → production, develop → staging |
| Trunk-based | `branches: [main]` | `github.ref == 'refs/heads/main'` |

## Pipeline 2: Tooling Audit

```yaml
name: Tooling Audit
on:
  push:
    branches: [main]
    paths:
      - 'package.json'
      - 'pyproject.toml'
      - 'Cargo.toml'
      - 'go.mod'
      - 'tsconfig.json'
      - '.eslintrc*'
      - 'prettier.config.*'
      - '.prettierrc*'
      - 'src/**'
  schedule:
    - cron: '0 9 * * 1'   # weekly Monday 9am UTC
  workflow_dispatch:

jobs:
  structural-checks:
    runs-on: ubuntu-latest
    outputs:
      has_drift: ${{ steps.audit.outputs.has_drift }}
      report: ${{ steps.audit.outputs.report }}
    steps:
      - uses: actions/checkout@v4
      - name: Run tooling audit
        id: audit
        run: bash .github/scripts/audit-tooling.sh

  semantic-analysis:
    needs: [structural-checks]
    if: needs.structural-checks.outputs.has_drift == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          prompt: |
            Review the tooling drift report and suggest fixes.
            Read .claude/forge-meta.json for context.
            Drift: ${{ needs.structural-checks.outputs.report }}
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          claude_args: '--max-turns 5'
```

### Audit Action Variants

Based on `ciAuditAction` from Phase 1:

**auto-fix-pr**: Add a step after semantic-analysis that creates a PR with fixes.
**comment-only**: Use `github-script` action to comment on the commit.
**create-issue**: Use `gh issue create` to file a tracking issue.

## Pipeline 3: PR Review

```yaml
name: AI PR Review
on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]

jobs:
  review:
    if: |
      github.event_name == 'pull_request' ||
      contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          prompt: |
            Review this PR against project conventions in CLAUDE.md and .claude/rules/.
            Focus on: correctness, conventions, test coverage, security.
          trigger_phrase: '@claude'
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

### PR Review Trigger Variants

Based on `prReviewTrigger` from Phase 1:

**auto**: Trigger on `pull_request: [opened, synchronize]` — every PR gets reviewed.
**on-demand**: Only trigger on `issue_comment` containing `@claude`.
**auto-with-skip**: Auto-trigger but skip if PR has a `skip-review` label.

## Dependency Management

### Dependabot (`.github/dependabot.yml`)
```yaml
version: 2
updates:
  - package-ecosystem: "npm"    # or pip, cargo, gomod, bundler
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

### Renovate (`renovate.json`)
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "automerge": true,
  "automergeType": "pr",
  "matchUpdateTypes": ["minor", "patch"]
}
```

Choose Dependabot for simplicity, Renovate for auto-merge and more control.
