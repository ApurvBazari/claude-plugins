# Worktree Workflow

Recommended development pattern for feature isolation using Claude Code's native `EnterWorktree` / `ExitWorktree` tools. Each feature is developed in an isolated worktree, keeping main clean and enabling easy rollback.

This pattern is **proactively offered by the feature-start detector hook, not enforced**. The developer decides per-feature whether to accept the offer, and their preference is remembered.

## How Claude Code Worktrees Work

`EnterWorktree` creates an isolated copy of the project at `.claude/worktrees/<name>/` with a new branch from HEAD. The entire Claude session switches into the worktree. Key benefits over raw `git worktree add`:

- **Auto-cleanup**: `ExitWorktree(action: "remove")` deletes worktree + branch in one step
- **Secret propagation**: `.worktreeinclude` copies gitignored files (`.env`, credentials) automatically
- **Session continuity**: `/resume` works across worktrees — pick up where you left off
- **Crash safety**: orphaned worktrees are prompted for cleanup on next session
- **Nesting guard**: tool refuses if already inside a worktree

## Single Developer Workflow

### Starting a Feature

When the feature-start detector fires and you accept the worktree offer:

```
EnterWorktree(name: "F001-user-dashboard")
```

This creates:
- Worktree at `.claude/worktrees/F001-user-dashboard/`
- New branch from HEAD
- Copies all `.worktreeinclude` patterns into the worktree
- Switches the session into the worktree
- `WorktreeCreate` hook runs `init.sh` automatically (if it exists)

### Working on the Feature

```bash
# Implement the feature (one feature at a time)
# Commit as you go with descriptive messages
git add -A && git commit -m "feat: add dashboard layout with navigation"
git add -A && git commit -m "feat: add dashboard data fetching"
```

### Verifying the Feature

```bash
# Run /onboard:verify to independently test
# (evaluator runs in its own isolated worktree)
/onboard:verify F001
```

### Completing the Feature

**Option A — Keep worktree for merge (recommended):**

```
ExitWorktree(action: "keep")
```

Session returns to original directory. The worktree and branch remain on disk. Merge the branch to main manually or via PR, then clean up:

```bash
git merge <worktree-branch-name>
git worktree remove .claude/worktrees/F001-user-dashboard
git branch -d <worktree-branch-name>
```

**Option B — Remove worktree (feature already merged or abandoned):**

```
ExitWorktree(action: "remove")
```

Deletes the worktree directory and branch. Refuses if there are uncommitted changes unless `discard_changes: true`.

### Rolling Back a Feature

```
ExitWorktree(action: "remove", discard_changes: true)
```

Force-removes the worktree and branch. Main is untouched — start fresh with a different approach.

## Agent Team Workflow

When using agent teams, worktrees prevent file conflicts between teammates.

### Sprint Setup (Lead)

```
                    main
                      │
              sprint/sprint-1 (integration)
                 │    │    │
          feat/F001  feat/F002  feat/F003
          (API)      (UI)       (Tests)
```

The lead creates a sprint integration branch, then each teammate session calls:

```
EnterWorktree(name: "F001-auth-api")
EnterWorktree(name: "F002-auth-ui")
EnterWorktree(name: "F003-auth-tests")
```

Each teammate works in its own worktree. The `WorktreeCreate` hook runs `init.sh` automatically in each.

### Dependency Resolution

When Teammate B depends on Teammate A's output:

1. Teammate A finishes, pushes its branch
2. Lead merges Teammate A's branch into `sprint/sprint-1`
3. Teammate B (in its worktree): `git pull origin sprint/sprint-1`
4. Teammate B now has Teammate A's work and can build on it

### Conflict Resolution

The **lead resolves all merge conflicts**, not teammates:

1. Lead merges feat/F001 into sprint/sprint-1 (clean)
2. Lead merges feat/F002 into sprint/sprint-1 — CONFLICT
3. Lead resolves: combines both changes
4. Lead pushes resolved sprint/sprint-1
5. Remaining teammates pull updated sprint/sprint-1

**Prevention by design**: Tasks should specify file ownership paths. No two tasks in the same sprint should have overlapping owned paths.

### Sprint Completion

1. All teammate branches merged into sprint/sprint-1
2. Run `/onboard:verify --sprint 1` against the integration branch
3. If all pass: merge sprint/sprint-1 into main
4. Clean up — each teammate session calls `ExitWorktree(action: "remove")`

## Worktree Naming Convention

When `docs/feature-list.json` exists (forge-scaffolded projects), use feature IDs:

```
EnterWorktree(name: "F001-user-dashboard")
EnterWorktree(name: "F002-api-endpoints")
```

Naming rules (from `EnterWorktree` spec):
- Letters, digits, dots, underscores, dashes allowed per segment
- Slashes act as segment separators (creates nested paths)
- Max 64 characters total
- Feature IDs (`F001`) + kebab-cased names naturally fit within limits

When no `feature-list.json` exists, ask the developer for a short descriptive name.

## .worktreeinclude

Create a `.worktreeinclude` file at the project root to copy gitignored files into new worktrees:

```
.env
.env.local
config/secrets.json
```

Only files that match the pattern **AND** are already gitignored will be copied. This prevents worktree environments from missing database URLs, API keys, and other config that isn't in git.

## Preference Persistence

The feature-start detector reads `.claude/session-state/worktree-preference` to decide whether to offer worktree creation:

| Value | Behavior |
|-------|----------|
| `ask` (default if file missing) | Claude asks the developer each time, then saves their answer |
| `always` | Claude proactively creates a worktree without asking |
| `never` | Worktree offer is suppressed entirely |

Set preference manually:

```bash
echo "always" > .claude/session-state/worktree-preference
```

Or let Claude save it after the developer responds to the first offer.

## What to Add to CLAUDE.md

```markdown
## Worktree Workflow (Proactive)

Claude offers worktree isolation when you start feature work in a critical directory.

**How it works**:
1. The feature-start detector fires when a new file is created in a critical directory
2. If your worktree preference allows it, Claude offers to create a worktree
3. If `docs/feature-list.json` exists, Claude suggests a name from the feature ID (e.g., `F001-user-dashboard`)
4. Claude calls `EnterWorktree(name: "...")` — the session moves into the isolated worktree
5. The `WorktreeCreate` hook runs `init.sh` automatically to bootstrap the environment
6. When done: `ExitWorktree(action: "keep")` to preserve for merge, or `"remove"` to clean up

**Worktree preference** (saved in `.claude/session-state/worktree-preference`):
- `ask` — prompt each time (default)
- `always` — auto-create without asking
- `never` — suppress worktree offers

**Naming**: Use feature IDs from `docs/feature-list.json` when available (e.g., `F001-user-dashboard`).

**Secrets**: Add sensitive config patterns to `.worktreeinclude` so they're copied into worktrees automatically.
```

## When NOT to Use Worktrees

- Trivial one-line fixes (just commit to a branch directly)
- Hotfixes that need to land immediately
- Documentation-only changes
- Already inside a worktree (Claude Code refuses nested worktrees)
- The developer explicitly decides not to (their choice — say "never" when offered)
