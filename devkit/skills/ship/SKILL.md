# /devkit:ship — Full Pipeline Orchestrator

You are running the full ship pipeline — a configurable sequence of checks followed by a commit. This ensures code quality before every commit.

## Guard

Read `.claude/devkit.json` in the project root. If not found:

> Run `/devkit:setup` first to configure your project.

Stop and do not proceed.

## Config

Extract from `devkit.json`:
- `shipPipeline` — ordered array of steps to run (e.g., `["test", "lint", "check"]`)
- All `tooling.*` values — needed by individual steps

## Argument Parsing

Check if the user passed any `--skip-<step>` arguments (e.g., `--skip-test`, `--skip-lint`). Remove those steps from the pipeline for this run only. Example:

> `/devkit:ship --skip-test` → pipeline becomes: lint → check → commit

If all steps are skipped, proceed directly to commit (see empty pipeline handling below).

## Overview

If the pipeline is empty after argument parsing (all steps skipped or `shipPipeline: []`):

> No pipeline steps configured — skipping directly to commit.

Proceed directly to the commit step.

Otherwise, tell the developer:

> Running ship pipeline: <step1> → <step2> → ... → commit

## Observe Integration (Optional)

Before running the pipeline, check if observe data exists by running:

```bash
python3 -c "
import glob, os, json
data_dir = os.path.expanduser('~/.claude/observability/data')
if not os.path.isdir(data_dir): exit(1)
files = glob.glob(os.path.join(data_dir, 'events-*.ndjson'))
if not files: exit(1)
print('available')
" 2>/dev/null
```

If observe data is available, run a quick pipeline history query:

```bash
python3 "<observe-plugin-root>/skills/observability-analytics/scripts/query.py" \
    --mode pipeline-summary --range last-30d --format json 2>/dev/null
```

To find the observe plugin root, check common plugin locations or skip if not found.

If the query returns results with `total_pipelines > 0`, show a brief one-line context before the pipeline runs:

> **Pipeline history** (last 30d): <completed>/<total> completed, avg <duration>

If trends are available, show the most relevant one:

> **Trend**: <trend message>

This is purely informational — never auto-skip steps or change pipeline behavior based on observe data. If observe is not installed or the query fails, skip this section silently.

## Step Execution

Execute each step in the configured `shipPipeline` order. Each step maps to a devkit skill:

| Step | Skill | What it does |
|------|-------|-------------|
| `test` | `/devkit:test` | Runs the test suite (mode: all) |
| `lint` | `/devkit:lint` | Runs the linter |
| `check` | `/devkit:check` | Production readiness scan |
| `review` | `/devkit:review` | Code review against main |

For each step, invoke the corresponding skill using the Skill tool. Run them sequentially — each step must complete before the next begins.

### Step Result Handling

After each step completes, classify the result:

| Result | Classification | Action |
|--------|---------------|--------|
| Clean pass | **PASS** | Proceed to next step |
| Critical issues found | **CRITICAL** | Block pipeline, show issues, ask user |
| Warnings found | **WARNING** | Show issues, ask user to continue or fix |
| Step not configured | **SKIP** | Skip silently (e.g., no test command) |
| Step execution error | **ERROR** | Report error, ask user to continue or abort |

### CRITICAL Block

When a step produces CRITICAL issues:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PIPELINE BLOCKED — <step name> found critical issues

<summary of critical issues>

Options:
  1. Fix the issues and re-run the pipeline
  2. Skip this check and continue (not recommended)
  3. Abort the pipeline
```

If the user chooses to fix, help them fix the issues, then re-run the failed step (not the whole pipeline).

### WARNING Pause

When a step produces warnings:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WARNING — <step name> found issues

<summary of warnings>

Continue anyway? [Y/fix/abort]
```

## Pipeline Progress

Show progress as steps complete:

```
Ship pipeline:

  ✓ test      — 42 tests passed
  ✓ lint      — clean
  ⧖ check — running...
  ○ commit    — pending
```

Update this display after each step.

## Final Step: Commit

After all pipeline steps pass (or warnings are acknowledged), invoke the commit skill:

> All checks passed. Proceeding to commit.

Use the `/devkit:commit` skill via the Skill tool to create the commit.

## Pipeline Complete

After the commit succeeds:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ship complete!

  ✓ test       — 42 tests passed
  ✓ lint       — clean
  ✓ check — 0 critical, 2 info
  ✓ commit     — feat(auth): add session management

Committed: <short hash> on <branch>
```

## Notify Integration

After the commit succeeds (or the pipeline fails), check if the `notify` plugin is installed by looking for `notify-config.json` in either `~/.claude/` (global) or `<project>/.claude/` (per-project).

If notify is installed, send a notification using `terminal-notifier`:

**On success:**
- Title: `Ship complete`
- Message: `<short hash> on <branch> — <commit message>`

**On failure:**
- Title: `Ship pipeline failed`
- Message: `Failed at <step name>: <brief reason>`

If notify is not installed, skip silently — do not prompt the user to install it.

## Key Rules

- **Sequential execution** — steps run in order, each must complete before the next
- **CRITICAL blocks** — the pipeline cannot continue past critical issues without explicit user override
- **WARNING pauses** — the user must acknowledge warnings before continuing
- **Re-run on fix** — after fixing issues, only re-run the failed step, not the entire pipeline
- **Always end with commit** — the commit step is always last, regardless of pipeline config
- **Respect skip** — if a step's tooling is not configured, skip it silently
- **Invoke skills properly** — use the Skill tool to invoke each devkit skill, don't duplicate their logic
