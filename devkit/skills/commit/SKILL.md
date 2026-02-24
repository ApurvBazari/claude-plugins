# /devkit:commit — Create a Commit

You are helping the developer create a well-structured git commit. Follow their configured commit style and conventions.

## Guard

Read `.claude/devkit.json` in the project root. If not found:

> Run `/devkit:setup` first to configure your project.

Stop and do not proceed.

## Config

Extract from `devkit.json`:
- `commitStyle` — determines commit message format
- `tooling.packageManager` — for context

## Step 1: Assess Changes

Run these in parallel:

```bash
git status
git diff --staged
git diff
git log --oneline -5
```

### If nothing to commit

> No changes detected. Nothing to commit.

Stop.

### If there are unstaged changes but nothing staged

Present the unstaged changes and ask:

> I see unstaged changes but nothing staged. Would you like me to:
> 1. Stage all changes and commit
> 2. Let you pick which files to stage
> 3. Cancel

If they choose option 1, run `git add -A`. If option 2, present the file list and let them select. Stage only the selected files with `git add <file1> <file2> ...`.

### If there are staged changes

Proceed with the staged changes. If there are also unstaged changes, mention them:

> Note: There are also unstaged changes that won't be included in this commit. Proceeding with staged changes only.

## Step 2: Analyze Changes

Read the staged diff carefully. Determine:

1. **Nature of change** — new feature, enhancement, bug fix, refactor, test, docs, chore, style, perf, ci, build
2. **Scope** — auto-detect from the directories of changed files (e.g., if all changes are in `src/auth/`, scope is `auth`)
3. **Summary** — concise description of what changed and why

## Step 3: Draft Commit Message

Format the message based on `commitStyle`:

### conventional
```
<type>(<scope>): <description>

<optional body — only if changes are complex>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `perf`, `chore`, `ci`, `build`

Scope: auto-detected from changed file directories. If changes span multiple directories, use the most relevant common ancestor or omit scope.

### simple
```
<type>: <description>

<optional body>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Same type list, no scope.

### ticket
```
<TICKET-ID>: <description>

<optional body>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Look for a ticket ID in the current branch name (e.g., `feature/JIRA-123-add-login` → `JIRA-123`). If no ticket ID found in the branch name, ask the user.

### freeform
```
<description>

<optional body>

Co-Authored-By: Claude <noreply@anthropic.com>
```

No enforced format. Write a clear, descriptive message.

## Step 4: Present & Confirm

Show the proposed commit message:

> **Proposed commit:**
> ```
> <commit message>
> ```
>
> **Files included:**
> - <file list with change summary>
>
> Proceed with this commit? [Y/edit]

If the user wants to edit, let them modify the message. If they confirm, create the commit.

## Step 5: Create Commit

Use a heredoc to pass the message:

```bash
git commit -m "$(cat <<'EOF'
<commit message>
EOF
)"
```

After the commit completes, run `git status` to verify success.

If the commit fails (e.g., pre-commit hook failure), report the error. Do NOT amend — fix the issue and create a new commit.

## Key Rules

- **Never amend existing commits** unless the user explicitly asks
- **Never force push** unless the user explicitly asks
- **Never skip hooks** (no `--no-verify`)
- **Always include Co-Authored-By** footer
- **Always confirm** before committing
- **Use heredoc** for commit messages to handle special characters
