# /devkit:pr — Create Pull Request

You are helping the developer create a pull request with pre-flight checks and a well-structured PR description.

## Guard

Read `.claude/devkit.json` in the project root. If not found:

> Run `/devkit:setup` first to configure your project.

Stop and do not proceed.

## Config

Extract from `devkit.json`:
- `tooling.testCommand` — for pre-flight test run
- `tooling.lintCommand` — for pre-flight lint check
- `tooling.buildCommand` — for pre-flight build check
- `prTemplate` — `"existing"` or `"builtin"`

## Step 1: Pre-Flight Checks

Verify the branch is ready for a PR:

```bash
git branch --show-current
git status
git log main..HEAD --oneline
git diff main...HEAD --stat
```

### Validations

1. **Not on main/master** — If on main, ask the user to create a branch first.
2. **Has commits** — If no commits ahead of main, nothing to PR.
3. **Clean working tree** — If there are uncommitted changes, warn:
   > You have uncommitted changes. Would you like to commit them first or create the PR without them?
4. **Up to date with remote** — Check if the branch is pushed:
   ```bash
   git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
   ```
   If not tracking a remote branch, note that we'll need to push.

## Step 2: Run Pre-Flight Checks

Run configured checks if available. These are not blocking — they're informational.

If `testCommand` is configured:
```bash
<testCommand>
```

If `lintCommand` is configured:
```bash
<lintCommand>
```

If `buildCommand` is configured:
```bash
<buildCommand>
```

Report results:

```
Pre-flight checks:

  Tests:  ✓ passed (42 tests)    OR  ✗ 3 failures    OR  — skipped (not configured)
  Lint:   ✓ clean                 OR  ✗ 5 warnings    OR  — skipped
  Build:  ✓ success               OR  ✗ failed        OR  — skipped
```

If any check fails:

> Pre-flight checks found issues. Would you like to:
> 1. Fix the issues first (recommended)
> 2. Create the PR anyway (issues will be noted)
> 3. Cancel

## Step 3: Analyze Changes

Read the full diff and commit history:

```bash
git log main..HEAD --format="%h %s"
git diff main...HEAD
```

Determine:

1. **PR type** — From branch name and commit messages:
   - `feature/*` or `feat:` commits → feature
   - `fix/*` or `fix:` commits → bugfix
   - `refactor/*` or `refactor:` commits → refactor
   - `docs/*` or `docs:` commits → docs
   - `chore/*` or `chore:` commits → chore
   - `test/*` or `test:` commits → test

2. **Summary** — What the changes accomplish (from reading the diff and commit messages)

3. **Key changes** — The most important modifications

## Step 4: Build PR Description

### If `prTemplate: "existing"`

Read the existing PR template file:
```bash
cat .github/pull_request_template.md
```

Fill in the template fields based on the change analysis. Keep the template structure intact.

### If `prTemplate: "builtin"`

Use the template from `references/pr-template.md`. Fill in all sections.

## Step 5: Draft PR

Present the PR for review:

```
PR Title: <title — short, under 70 chars>

PR Body:
---
<filled-in template>
---

Labels: <auto-detected labels>
Base branch: main
```

Auto-detect labels from the PR type:
- `feature` → feature
- `bugfix` → bugfix
- `refactor` → refactor
- `docs` → docs
- `chore` → chore
- `test` → test

> Does this look good? [Y/edit]

Let the user edit the title, body, or labels before creating.

## Step 6: Push & Create PR

If the branch isn't pushed to remote:

```bash
git push -u origin <branch-name>
```

Create the PR using `gh`:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<pr body>
EOF
)" --label "<labels>"
```

If `gh` is not installed, inform the user:

> `gh` CLI is not installed. You can create the PR manually at:
> `https://github.com/<org>/<repo>/compare/main...<branch>`
>
> Here's the PR description to copy:
> <show description>

## Step 7: Report

> PR created: <PR URL>
>
> **Pre-flight results**: <summary>
> **Changes**: <X files changed>, <Y insertions>, <Z deletions>
> **Commits**: <count> commits

## Key Rules

- **Never force push** — always regular push
- **Always show the PR for review** before creating
- **Respect existing templates** — fill them in rather than replacing
- **Pre-flight checks are informational** — the user decides whether to proceed
- **Include the PR URL** at the end so the user can access it immediately
