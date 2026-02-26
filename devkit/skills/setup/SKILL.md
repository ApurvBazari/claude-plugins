# /devkit:setup — Project Setup Wizard

You are running the devkit setup wizard. This configures the devkit for the current project by detecting tooling, verifying with the user, and writing a config file.

## Overview

Tell the developer:

> Starting **devkit** setup — I'll scan your project to detect tooling, then walk you through a quick verification before saving your config.

---

## Step 1: Check for Existing Config

Read `.claude/devkit.json` in the project root.

**If it exists:**

> I found an existing devkit configuration (created <date from _generated.date>).
>
> Would you like to:
> 1. **Reconfigure** — Re-detect and update settings
> 2. **Cancel** — Keep the current config

If "Cancel", stop. If "Reconfigure", continue.

**If not found**, proceed directly.

---

## Step 2: Auto-Detect Tooling

Spawn the `tooling-detector` agent to scan the project. While waiting:

> Scanning your project for tooling...

---

## Step 3: Present Detected Tooling

Once detection completes, present results for verification:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Detected configuration:

  Package manager:  <name>         (from <evidence>)
  Test command:     <command>      (<runner> from <evidence>)
  Lint command:     <command>      (<linter> from <evidence>)
  Build command:    <command>      (from <evidence>)
  Formatter:        <name>         (from <evidence>)

? Confirm tooling? [Y/edit]
```

If the user says "Y" or confirms, accept as-is. If they want to edit, let them modify any values. If a tool was not detected, show "Not detected" and let the user fill it in or leave blank.

---

## Step 4: Commit Style Selection

Present the commit style options with the detected default:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commit style:

  1. Conventional Commits (recommended)     — feat(scope): description
  2. Simple prefix                          — feat: description (no scope)
  3. Ticket-prefixed                        — JIRA-123: description
  4. Freeform                               — no enforced format

  Detected: <style> (from git history analysis, <confidence> confidence)

? Confirm commit style? [1/2/3/4]
```

Accept the user's choice. Default to the detected style if they just confirm.

---

## Step 5: Ship Pipeline Configuration

Present the pipeline steps:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ship pipeline (steps to run before commit):

  [x] test
  [x] lint
  [x] check
  [ ] review (optional — adds code review step)

? Confirm pipeline? [Y/edit]
```

If the user edits, let them toggle steps on/off or reorder. The pipeline determines what `/devkit:ship` runs.

Only show steps for which the user has tooling configured. If no test command was detected and the user didn't provide one, don't include `test` by default.

---

## Step 5.5: Base Branch Detection

Auto-detect the default branch:

```bash
git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'
```

If detection fails (no remote, no origin), fall back to checking which of `main` or `master` exists locally. Store the result as `baseBranch` in the config. This is used by `/devkit:review` and `/devkit:pr`.

---

## Step 6: PR Template

Check for an existing PR template:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PR template:

  Found: .github/pull_request_template.md
  Using your existing PR template.

? Confirm? [Y/edit]
```

If no template found:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PR template:

  No existing template found.
  Will use the built-in devkit template.

? Confirm? [Y/edit]
```

The `prTemplate` config value is `"existing"` if a template was found, or `"builtin"` if using the default.

---

## Step 7: Write Config

Create `.claude/devkit.json` with all verified values:

```json
{
  "_generated": {
    "by": "devkit",
    "version": "0.1.0",
    "date": "<current date YYYY-MM-DD>"
  },
  "tooling": {
    "packageManager": "<detected or user-provided>",
    "testCommand": "<command or null>",
    "testRunner": "<runner name or null>",
    "lintCommand": "<command or null>",
    "linter": "<linter name or null>",
    "buildCommand": "<command or null>",
    "formatter": "<formatter name or null>"
  },
  "commitStyle": "<conventional | simple | ticket | freeform>",
  "baseBranch": "<detected default branch — main, master, develop, etc.>",
  "shipPipeline": ["<steps selected by user in Step 5, in order>"],
  "prTemplate": "<existing | builtin>"
}
```

Omit null tooling fields entirely rather than writing null values.

Ensure the `.claude/` directory exists before writing.

---

## Step 8: Confirmation

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Setup complete! Config saved to .claude/devkit.json

Available skills:
  /devkit:commit       Create a commit following your configured style
  /devkit:review       Code review against main
  /devkit:lint         Run linter with auto-fix
  /devkit:test         Run tests (all/coverage/watch/specific)
  /devkit:check   Production readiness scan
  /devkit:pr    Create PR with pre-flight checks
  /devkit:ship         Full pipeline: <pipeline steps> → commit
```

Show the actual pipeline steps from the user's config in the ship description.
