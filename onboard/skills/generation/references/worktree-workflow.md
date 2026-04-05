# Worktree Workflow

Recommended development pattern for feature isolation. Each feature is developed in an isolated git worktree, keeping main clean and enabling easy rollback.

This pattern is **recommended in CLAUDE.md, not enforced via hooks**. The developer decides per-feature whether to use a worktree or work directly on a branch.

## Single Developer Workflow

### Starting a Feature

```bash
# Create worktree for feature F001
git worktree add ../project-feat-F001 -b feat/F001-user-dashboard
cd ../project-feat-F001

# Run init.sh to bootstrap environment
bash init.sh
```

### Working on the Feature

```bash
# Implement the feature (one feature at a time)
# Commit as you go with descriptive messages
git add -A && git commit -m "feat: add dashboard layout with navigation"
git add -A && git commit -m "feat: add dashboard data fetching"
```

### Verifying the Feature

```bash
# Run /forge:verify to independently test
# (evaluator runs in its own isolated worktree)
/forge:verify F001
```

### Completing the Feature

```bash
# Return to main project directory
cd ../project

# Merge feature branch
git merge feat/F001-user-dashboard

# Clean up worktree and branch
git worktree remove ../project-feat-F001
git branch -d feat/F001-user-dashboard

# Update progress
# (Claude updates docs/progress.md and docs/feature-list.json)
```

### Rolling Back a Feature

```bash
# If approach isn't working, just remove the worktree
git worktree remove ../project-feat-F001 --force
git branch -D feat/F001-user-dashboard

# main is untouched — start fresh with a different approach
```

## Agent Team Workflow

When using agent teams, worktrees prevent file conflicts between teammates.

### Sprint Setup (Lead)

```bash
# Create sprint integration branch
git checkout -b sprint/sprint-1

# Create worktrees for each teammate
git worktree add ../project-feat-F001 -b feat/F001-auth-api
git worktree add ../project-feat-F002 -b feat/F002-auth-ui
git worktree add ../project-feat-F003 -b feat/F003-auth-tests
```

### During Sprint (Teammates)

Each teammate works in its own worktree. When a teammate completes:

1. Teammate commits and pushes its branch
2. **Lead** merges teammate branch → sprint integration branch
3. Other teammates pull integration branch to get latest shared state

```
                    main
                      │
              sprint/sprint-1 (integration)
                 │    │    │
          feat/F001  feat/F002  feat/F003
          (API)      (UI)       (Tests)
```

### Dependency Resolution

When Teammate B depends on Teammate A's output:

1. Teammate A finishes, pushes feat/F001
2. Lead merges feat/F001 → sprint/sprint-1
3. Teammate B (in its worktree): `git pull origin sprint/sprint-1`
4. Teammate B now has Teammate A's work and can build on it

### Conflict Resolution

The **lead resolves all merge conflicts**, not teammates:

1. Lead merges feat/F001 → sprint/sprint-1 (clean)
2. Lead merges feat/F002 → sprint/sprint-1 → CONFLICT in shared file
3. Lead resolves: combines both changes
4. Lead pushes resolved sprint/sprint-1
5. Remaining teammates pull updated sprint/sprint-1

**Prevention by design**: Tasks should specify file ownership paths. No two tasks in the same sprint should have overlapping owned paths.

### Sprint Completion

1. All teammate branches merged into sprint/sprint-1
2. Run `/forge:verify --sprint 1` against the integration branch
3. If all pass: merge sprint/sprint-1 → main
4. Clean up all worktrees and feature branches

## What to Add to CLAUDE.md

```markdown
## Worktree Workflow (Recommended)

Start each feature in an isolated git worktree:

  git worktree add ../project-feat-[ID] -b feat/[ID]-[name]
  cd ../project-feat-[ID]
  bash init.sh

Benefits: isolation from main, easy rollback, parallel work.

When done:
  cd ../project
  git merge feat/[ID]-[name]
  git worktree remove ../project-feat-[ID]
  git branch -d feat/[ID]-[name]
```

## When NOT to Use Worktrees

- Trivial one-line fixes (just commit to a branch directly)
- Hotfixes that need to land immediately
- Documentation-only changes
- The developer explicitly decides not to (their choice)
