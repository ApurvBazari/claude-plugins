# Collaboration Artifacts Guide

Collaboration artifacts standardize how developers (and Claude) work together in a codebase. These are **always generated** regardless of team size — solo developers benefit from consistency, and teams benefit from shared conventions.

---

## PR Template

**File**: `.github/PULL_REQUEST_TEMPLATE.md`

Generate a pull request template that structures code reviews:

```markdown
## Summary

<!-- Brief description of what this PR does and why -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Refactor (code change that neither fixes a bug nor adds a feature)
- [ ] Documentation update
- [ ] Dependency update
- [ ] CI/CD change

## Checklist

- [ ] I have performed a self-review of my own code
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing unit tests pass locally
- [ ] I have checked for any warnings or errors introduced
```

### Stack-Specific Checklist Items

Add to the checklist based on detected stack:

| Stack Signal | Additional Checklist Item |
|-------------|--------------------------|
| Database/ORM detected | `- [ ] Database migrations are reversible` |
| Frontend framework detected | `- [ ] UI changes tested across target browsers` |
| API routes detected | `- [ ] API changes are backward compatible (or versioned)` |
| i18n libraries detected | `- [ ] New strings are internationalized` |
| Monorepo detected | `- [ ] Cross-package impacts have been reviewed` |

### Security Items (if `securitySensitivity` is elevated or high)

Add to the checklist:
```markdown
- [ ] No secrets or credentials are included in this PR
- [ ] Input validation is in place for new endpoints/forms
- [ ] Security implications have been considered
```

**Note**: Include a comment in the generated template: `<!-- Customize this template to match your team's review process -->`

---

## Commit Conventions

**File**: `.claude/rules/commit-conventions.md`

Generate a path-scoped rule for commit message conventions:

```yaml
---
paths:
  - "**"
---
```

### Convention Format

Use Conventional Commits: `type(scope): description`

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`

### Strictness Mapping

Adapt the rule language to the developer's `codeStyleStrictness`:

| Strictness | Language |
|-----------|---------|
| Relaxed | "Suggest using conventional commit format: `type: description`" |
| Moderate | "Follow conventional commit format: `type(scope): description`" |
| Strict | "All commits must use conventional commit format: `type(scope): description` with a scope" |

---

## Shared vs Local Settings

Include guidance in the generated root CLAUDE.md explaining the two settings files:

### `.claude/settings.json` (Shared — commit to repo)

Team-wide hooks and permissions that apply to all developers:
- Auto-format hooks
- Lint check hooks
- Shared tool permissions

### `.claude/settings.local.json` (Personal — gitignored)

Individual developer preferences:
- Personal hook overrides
- Individual tool permission adjustments
- Developer-specific configurations

### What to Include in Root CLAUDE.md

Add a section like:

```markdown
## Claude Settings

- **Shared settings** (`.claude/settings.json`): Team hooks and permissions — committed to repo
- **Personal settings** (`.claude/settings.local.json`): Your individual overrides — gitignored
- Personal settings merge with and override shared settings
```
