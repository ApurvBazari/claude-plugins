---
description: Run pre-completion checklist after finishing a plugin feature — validates, checks docs, suggests commit
user_invocable: true
---

# /feature-done — Feature Completion Checklist

Run this before considering a plugin feature complete. Validates the plugin, checks documentation, and suggests a commit.

## Step 1: Run Validation

Invoke the `/validate` skill to run all quality checks. If any check returns FAIL, stop and report the failures — they must be fixed before proceeding.

If only WARNs are present, note them and continue.

## Step 2: Check Documentation

Review the git diff to identify what changed. For each modified plugin:

1. **README.md**: If user-facing behavior changed (new skill, new command, changed arguments), verify README is updated
2. **Plugin CLAUDE.md**: If internal conventions changed (new patterns, new architecture), verify the subdirectory CLAUDE.md is updated
3. **CHANGELOG.md**: Verify there's an entry for this change

Report any missing documentation updates as items to address.

## Step 3: Version Check

If plugin code changed (not just docs):
- Check if `plugin.json` version was bumped
- Check if `marketplace.json` version was updated to match
- If not bumped, suggest a version bump (patch for fixes, minor for features)

## Step 4: Git Status Review

Run `git status` and review:
- Are there untracked files that should be committed?
- Are there files that should NOT be committed (temporary files, local configs)?
- Is the working tree clean enough for a commit?

## Step 5: Suggest Commit

Based on the changes, suggest a conventional commit message:

```
type(scope): description

- type: feat, fix, refactor, docs, chore
- scope: plugin name (onboard, forge, notify) or repo-level
- description: concise "why" in imperative mood
```

Present the suggested message and ask if the user wants to commit.

## Key Rules

- Always run /validate first — it's the foundation
- Don't auto-commit — suggest and let the user decide
- Version bumps are mandatory for code changes, optional for doc-only changes
- One logical change per commit — if multiple plugins changed independently, suggest separate commits
