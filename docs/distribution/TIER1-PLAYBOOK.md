# Tier 1 Distribution Playbook

**Purpose:** A step-by-step playbook for Claude Code to execute plugin submissions to 9 community directories on behalf of the repo owner.

**How to invoke:**
```
Please execute the Tier 1 distribution playbook at docs/distribution/TIER1-PLAYBOOK.md.
Start with Phase 0 (preflight checks) and stop after each phase for my review before proceeding.
```

---

## Context for the executing agent

You are helping the owner of `github.com/ApurvBazari/claude-plugins` get three plugins listed across 9 community directories.

**Plugins in scope (all three):**

1. **onboard** (v1.10.0) — Analyzes existing codebases and generates tailored Claude tooling
2. **forge** (v1.1.0) — Greenfield project scaffolder for Claude Code
3. **notify** (v1.1.0) — Cross-platform system notifications for Claude Code

**Owner GitHub handle:** `ApurvBazari`
**Repo URL:** `https://github.com/ApurvBazari/claude-plugins`
**Author attribution:** `Apurv Bazari`
**License:** MIT (all plugins)

**Hard constraints:**
- Do NOT authenticate as the user anywhere
- Do NOT push to GitHub without explicit user confirmation
- Do NOT open PRs without showing the user the exact diff first
- After each phase, STOP and wait for user approval before proceeding to the next
- If a target repo's CONTRIBUTING.md conflicts with this playbook, CONTRIBUTING.md wins — surface the conflict to the user

---

## Phase 0: Preflight Checks

Run these checks BEFORE doing any submission work. If any fails, stop and surface the failure to the user.

### 0.1 Verify GitHub CLI is installed and authenticated

```bash
gh --version
gh auth status
```

If not authenticated: "GitHub CLI is not authenticated. Please run `gh auth login` and then re-invoke this playbook."

### 0.2 Verify the repo state

```bash
cd /Users/apurvbazari/Desktop/projects/claude-plugins
git status
git branch --show-current
git log -1 --oneline
```

Expected: Clean working tree, on `main` branch, latest commit visible.

### 0.3 Verify the latest changes are pushed

```bash
git fetch origin
git log origin/main..HEAD --oneline
```

Expected: No output. If there are unpushed commits, ask: "You have unpushed commits. Should I push them to origin/main before starting submissions?"

### 0.4 Verify repo hygiene

```bash
gh repo view ApurvBazari/claude-plugins --json description,repositoryTopics,stargazerCount,forkCount,hasIssuesEnabled
gh release list --repo ApurvBazari/claude-plugins
```

Surface any missing items:
- [ ] Repo description is set
- [ ] Topics include `claude-code`, `claude-plugin`, `ai-tooling`
- [ ] At least one release exists
- [ ] Issues are enabled (some directories check this)

### 0.5 Verify plugin manifests match this playbook

```bash
cat .claude-plugin/marketplace.json | jq '.plugins[] | {name, version}'
cat onboard/.claude-plugin/plugin.json | jq '{name, version, description}'
cat forge/.claude-plugin/plugin.json | jq '{name, version, description}'
cat notify/.claude-plugin/plugin.json | jq '{name, version, description}'
```

Expected versions: onboard 1.10.0, forge 1.1.0, notify 1.1.0. If mismatched, ask the user whether to update the playbook or the manifests.

### 0.6 Create working directory

```bash
mkdir -p ~/tmp/plugin-submissions
cd ~/tmp/plugin-submissions
```

This is where forks will be cloned — keep them outside the main repo to avoid git confusion.

### Phase 0 Exit Criteria

STOP. Report preflight results. Do NOT proceed to Phase 1 without explicit user approval.

---

## Canonical Plugin Descriptions

Use these exact strings across all submissions.

### onboard

**One-line (for list entries):**
```
**onboard** — Analyzes existing codebases and generates tailored Claude tooling (CLAUDE.md, path-scoped rules, skills, agents, hooks, CI/CD). Includes `/onboard:evolve` drift detection and plugin-aware generation. By [@ApurvBazari](https://github.com/ApurvBazari).
```

**Medium (for larger description fields):**
```
End-to-end Claude tooling generator for existing codebases. Performs deep analysis (languages, frameworks, enforced configs), runs an interactive wizard, then generates CLAUDE.md files, path-scoped rules derived from your actual lint/format configs, project-specific skills and agents, hook configuration, PR templates, and CI/CD — tailored to your project's detected patterns rather than generic templates. Includes `/onboard:evolve` for drift detection and plugin-aware generation that skips agents whose capabilities are already covered by installed plugins (superpowers, feature-dev, etc). Supports monorepos, mixed-language projects, and headless invocation by other plugins.
```

**Keywords:** `codebase-analysis`, `claude-md`, `onboarding`, `ai-tooling`, `developer-tools`

### notify

**One-line:**
```
**notify** — Cross-platform system notifications for Claude Code. macOS (terminal-notifier) and Linux (notify-send), duration filtering, git context extraction, contextual messages. By [@ApurvBazari](https://github.com/ApurvBazari).
```

**Medium:**
```
Cross-platform system notifications for Claude Code hooks. Supports macOS (via terminal-notifier) and Linux (via notify-send) with graceful fallback handling. Includes duration filtering to suppress noisy short-lived events, automatic git context extraction (branch, repo name), and contextual message generation based on hook type. Drop-in for any Claude Code hook that should surface to the OS notification system.
```

**Keywords:** `notifications`, `hooks`, `macos`, `linux`, `terminal-notifier`

---

## Reusable PR Body Template (for list README PRs)

Use this template for Phase 1.1, 1.3, 2.1, 2.2, 2.3.

```markdown
## What

Adds plugins to the list:

- **onboard** — Analyzes existing codebases and generates tailored Claude tooling (CLAUDE.md, path-scoped rules, skills, agents, hooks, CI/CD). Includes `/onboard:evolve` drift detection.
- **notify** — Cross-platform system notifications for Claude Code hooks. macOS and Linux.
- **handoff** — Save and resume session handoffs across context boundaries.

## Why

- **onboard** produces actual Claude artifacts from codebase analysis (most existing tools only recommend).
- **notify** is a simple, reliable cross-platform notification helper for hooks.
- **handoff** captures intent at session end and surfaces it at the next session start.

All are MIT licensed, documented, and live at https://github.com/ApurvBazari/claude-plugins

## Checklist

- [x] Plugins follow standard Claude Code plugin structure
- [x] MIT licensed
- [x] Tested on macOS and Linux
- [x] README and CHANGELOG maintained
```

---

## Phase 1: The Big Three

### 1.1 — ComposioHQ/awesome-claude-plugins

**Type:** Pull Request
**Target:** `https://github.com/ComposioHQ/awesome-claude-plugins`

**Execution:**

```bash
cd ~/tmp/plugin-submissions

# Check for duplicate PR
gh pr list --repo ComposioHQ/awesome-claude-plugins --search "onboard forge" --state all
```

If a duplicate PR exists, STOP and surface to user.

```bash
# Fork and clone
gh repo fork ComposioHQ/awesome-claude-plugins --clone=true --remote=true
cd awesome-claude-plugins
git checkout -b add-onboard-forge-notify
```

**Pre-edit checks:**
1. Read `README.md` end-to-end
2. Read `CONTRIBUTING.md` if present
3. Check last 5 merged PRs for entry format: `gh pr list --repo ComposioHQ/awesome-claude-plugins --state merged --limit 5`
4. Identify the most appropriate section(s) for each plugin

**Edit README.md:**
- Add `**onboard** — ...` entry in Developer Tools / Workflows section
- Add `**forge** — ...` entry in same section or Scaffolding section
- Add `**notify** — ...` entry in Hooks or Notifications section
- Match existing formatting exactly (bullet style, bold name, em-dash separator)

**Commit and show diff:**

```bash
git add README.md
git diff --cached
git commit -m "Add onboard, forge, and notify plugins

- onboard: Codebase analysis + Claude tooling generation
- forge: Greenfield project scaffolder (delegates to onboard)
- notify: Cross-platform system notifications"
```

**STOP. Show user the commit and drafted PR body. Wait for approval.**

After approval:

```bash
git push origin add-onboard-forge-notify
gh pr create --repo ComposioHQ/awesome-claude-plugins \
  --title "Add onboard, forge, and notify plugins" \
  --body "[paste PR body from reusable template]"
```

Record the PR URL in the tracker.

---

### 1.2 — hesreallyhim/awesome-claude-code

**Type:** GitHub Issues (NOT PRs — maintainer rejects direct PRs; automation creates PRs from validated issues.)
**Target:** `https://github.com/hesreallyhim/awesome-claude-code`

**Critical rules:**
- Maintainer is publicly frustrated with low-effort submissions (ref: Issue #1000, March 2026)
- MUST use their issue template format exactly
- ONE plugin per issue
- Required fields must all be filled — do not skip any

**Pre-flight:**

```bash
# Check for duplicate issues
gh issue list --repo hesreallyhim/awesome-claude-code --search "onboard" --state all
gh issue list --repo hesreallyhim/awesome-claude-code --search "forge" --state all
gh issue list --repo hesreallyhim/awesome-claude-code --search "ApurvBazari" --state all
```

If duplicates exist, STOP.

**Also fetch their current issue template to ensure field names match:**

```bash
curl -s https://raw.githubusercontent.com/hesreallyhim/awesome-claude-code/main/.github/ISSUE_TEMPLATE/submit-resource.yml
```

If fields differ from what's in this playbook, update the issue bodies accordingly.

**Issue 1 — onboard:**

Title: `[Resource]: onboard — Claude tooling generator for existing codebases`

Body fields (from their template):
- **Display Name:** onboard
- **Category:** Plugins
- **Sub-Category:** (whatever best matches — check their category list; likely "Plugins: Developer Tools")
- **Primary Link:** https://github.com/ApurvBazari/claude-plugins
- **Author Name:** Apurv Bazari
- **Author Link:** https://github.com/ApurvBazari
- **License:** MIT
- **Description:** [use medium description from canonical descriptions section]
- **Active Development:** Yes
- **How to use it:** `Install the marketplace with \`claude marketplace add https://github.com/apurvbazari/claude-plugins\`, then \`claude plugin install onboard\`. Run \`/onboard:init\` in any existing project. The wizard gathers context, then generates tailored Claude tooling (CLAUDE.md, rules, skills, agents, hooks, CI/CD). Run \`/onboard:evolve\` later to detect drift as your codebase changes.`
- **Example Usage:** `Clone any medium-sized TypeScript/Next.js project. Run \`/onboard:init\`. The codebase analyzer detects the stack, reads your ESLint/Prettier/TSConfig enforced rules, and asks about pain points and workflow preferences. It generates: a root CLAUDE.md (100-200 lines with build/test/lint commands), subdirectory CLAUDE.md files for key directories, path-scoped rules that match your actual enforced configs, a project-specific code-reviewer agent, and auto-format + lint hooks wired to your detected tooling.`
- **My resource provides genuine value to Claude Code users:** Yes
- **All provided links are working and publicly accessible:** Yes

**Issue 2 — forge:**

Title: `[Resource]: forge — Greenfield project scaffolder for Claude Code`

Same template, substitute forge's descriptions and this usage example:

- **How to use it:** `Install the marketplace, then \`claude plugin install forge\`. Run \`/forge:init\` and describe what you want to build. The 4-phase wizard gathers context, scaffolds the app, delegates to onboard for AI tooling generation, then sets up CI/CD and lifecycle docs. Supports resume from any interruption via \`.claude/forge-state.json\`.`
- **Example Usage:** `Run \`/forge:init\` and say "a task management app with real-time collaboration". Forge asks about tech stack, database, auth, deployment target, and workflow preferences. It researches the chosen stack via web search, scaffolds using the official CLI, delegates to onboard for Claude tooling (CLAUDE.md, rules, skills, agents, hooks), and sets up CI/CD pipelines. The developer ends with a running app and Claude Code that deeply understands their project conventions.`

**Issue 3 — notify:**

Title: `[Resource]: notify — Cross-platform system notifications for Claude Code`

Same template, substitute notify's descriptions and this usage example:

- **How to use it:** `Install the marketplace, then \`claude plugin install notify\`. The plugin registers hooks that fire system notifications on task completion, stop events, and notifications. Duration threshold is configurable to avoid notification spam for quick operations.`
- **Example Usage:** `After installation, when Claude Code finishes a long-running task (like a test suite or build), a native system notification appears: "forge: Build completed in 2m 14s". Duration filtering ensures quick commands don't spam notifications. Git branch and repo name are included automatically for context when working across multiple projects.`

**STOP. Show user all three issue bodies. Wait for approval.**

After approval:

```bash
gh issue create --repo hesreallyhim/awesome-claude-code --title "..." --body "..."
```

Record all three issue URLs in the tracker.

---

### 1.3 — rohitg00/awesome-claude-code-toolkit

**Type:** Pull Request
**Target:** `https://github.com/rohitg00/awesome-claude-code-toolkit`

Same execution pattern as Phase 1.1. Fork, branch `add-onboard-forge-notify`, edit README (find the Plugins section — this toolkit tracks 176+ plugins), commit, push, PR.

Use the reusable PR body template.

**STOP before pushing. Show diff and PR body.**

---

### Phase 1 Exit Criteria

Report to user:
- PRs opened (Phase 1.1, 1.3) with URLs
- Issues opened (Phase 1.2) with URLs
- Any failures or deviations from playbook
- Update `docs/distribution/SUBMISSION-TRACKER.md`

Wait for user approval before Phase 2.

---

## Phase 2: Remaining Awesome-Lists

### 2.1 — ccplugins/awesome-claude-code-plugins
### 2.2 — jmanhype/awesome-claude-code
### 2.3 — GiladShoham/awesome-claude-plugins

**Pattern:** Identical to Phase 1.1 and 1.3 (fork, branch, edit README, commit, push, PR).

**For each:**
1. `gh pr list` to check for duplicate submissions
2. Fork and clone
3. Read README + CONTRIBUTING.md
4. Check recent merged PRs for format
5. Add all three plugin entries
6. Commit with standard message
7. STOP, show diff to user
8. After approval, push and create PR using reusable template

### Phase 2 Exit Criteria

Report 3 PRs opened. Update tracker. Wait for approval.

---

## Phase 3: Auto-Discovery and Web Forms

### 3.1 — quemsah/awesome-claude-plugins

**Type:** Auto-discovery (n8n workflows scan GitHub for valid plugin manifests)

```bash
# Verify preconditions for auto-discovery
cat .claude-plugin/marketplace.json | jq empty && echo "marketplace.json valid"

for plugin in onboard forge notify; do
  echo "=== $plugin ==="
  cat "$plugin/.claude-plugin/plugin.json" | jq '{name, version, description}'
done

gh repo view ApurvBazari/claude-plugins --json isPrivate,repositoryTopics
```

**If all checks pass:** Mark this row as "Auto-discovery — preconditions met" in the tracker. No submission action.

**If any check fails:** Report to user and stop.

### 3.2 — claudemarketplaces.com (manual)
### 3.3 — claudepluginhub.com (auto + optional manual)
### 3.4 — awesome-skills.com (likely manual)

These cannot be automated — they require web form submission by the user.

**Action:** Write a consolidated file at `docs/distribution/MANUAL-SUBMISSIONS.md` with:

- For each of 3.2, 3.3, 3.4: site URL, note about whether form is required or auto-discovery
- Prefilled text blocks the user can copy-paste (marketplace name, URL, description, per-plugin medium descriptions, author, email placeholder)
- Any known quirks

### Phase 3 Exit Criteria

Report auto-discovery status. Confirm MANUAL-SUBMISSIONS.md is written. Update tracker.

---

## Phase 4: Tracking

Generate/update `docs/distribution/SUBMISSION-TRACKER.md` continuously throughout execution. Template:

```markdown
# Submission Tracker

Last updated: YYYY-MM-DD HH:MM

| # | Directory | Type | Submission URL | Submitted | Merged/Approved | Notes |
|---|---|---|---|---|---|---|
| 1 | ComposioHQ/awesome-claude-plugins | PR | | | | |
| 2 | hesreallyhim/awesome-claude-code (onboard) | Issue | | | | |
| 3 | hesreallyhim/awesome-claude-code (forge) | Issue | | | | |
| 4 | hesreallyhim/awesome-claude-code (notify) | Issue | | | | |
| 5 | rohitg00/awesome-claude-code-toolkit | PR | | | | |
| 6 | ccplugins/awesome-claude-code-plugins | PR | | | | |
| 7 | jmanhype/awesome-claude-code | PR | | | | |
| 8 | GiladShoham/awesome-claude-plugins | PR | | | | |
| 9 | quemsah/awesome-claude-plugins | Auto | N/A | | | Auto-discovery |
| 10 | claudemarketplaces.com | Manual | | | | User-submitted |
| 11 | claudepluginhub.com | Auto+Manual | | | | |
| 12 | awesome-skills.com | Manual | | | | User-submitted |
```

Update after every PR/issue creation.

---

## General Rules for the Executing Agent

1. Never force-push. Use `git push origin <branch>` only.
2. Never submit to the user's own repo without review.
3. Never authenticate as the user anywhere — use existing `gh auth` only.
4. If a CONTRIBUTING.md conflicts with this playbook, CONTRIBUTING.md wins — surface conflict.
5. If any step fails, STOP and ask. Don't improvise.
6. Show diffs before committing. Always.
7. Show PR/issue bodies before opening. Always.
8. Keep descriptions honest. Don't oversell.
9. Respect rate limits. If rate-limited, pause and report.
10. Always check for duplicate submissions before opening (`gh pr list`, `gh issue list`).
11. Work outside the main repo — use `~/tmp/plugin-submissions` for forks.
12. After each phase, update the tracker before stopping.

---

## Expected Runtime

- Phase 0: 5 min
- Phase 1: 30-45 min (with approval pauses)
- Phase 2: 20-30 min
- Phase 3: 10 min
- Phase 4: ongoing (5 min per update)

**Total: ~60-90 min**

## Resume Semantics

If interrupted, read `docs/distribution/SUBMISSION-TRACKER.md`. Continue from the first row without a "Submitted" date. Do not re-run completed submissions.
