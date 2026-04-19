---
name: init
description: Full 3-phase forge orchestrator — context gathering, scaffold, AI tooling. Creates a new project from scratch with AI-native Claude tooling built in from day one. Use only when user explicitly invokes /forge:init.
disable-model-invocation: true
---

# Init Skill — Scaffold a New Project with AI-Native Tooling

You are running the Forge initialization wizard. This is a guided, 3-phase process that discusses what the developer wants to build, scaffolds the application, and equips it with auto-evolving Claude Code tooling.

## Step 0: Resume check

Before any work, check for an existing in-progress Forge session in the current directory.

Check for `.claude/forge-state.json`:

**If it exists and `currentPhase !== "complete"`**: there's an in-progress session. Do NOT silently restart — tell the user and offer options:

> There's an in-progress Forge session in this directory.
>
> **Project**: [context.appDescription or "unnamed"]
> **Started**: [createdAt]
> **Last updated**: [updatedAt]
> **Currently at**: [currentPhase] / [currentStep]
> **Next action**: [nextAction]
>
> Options:
> 1. **Resume** — continue from where you left off (equivalent to `/forge:resume`)
> 2. **Start fresh** — archive the old state to `.claude/forge-state.archived-[timestamp].json` and begin a new `/forge:init` run
> 3. **Inspect** — show me the state file contents so I can decide

Use AskUserQuestion. Do not proceed until the user chooses.

**If it exists and `currentPhase === "complete"`**: the previous Forge run finished. Tell the user:

> This directory already has a completed Forge setup (finished [updatedAt]).
>
> Re-running `/forge:init` would scaffold on top of the existing project, which is probably not what you want. Options:
> 1. **Start fresh in a new directory** — move to an empty directory and run `/forge:init` there
> 2. **Reconfigure existing** — run `/forge:status` to see current state, or `/forge:evolve` (from onboard) to update tooling
> 3. **Force re-init** — archive the current state and start over (you'll need to manually clean the scaffold; I won't delete files)

Wait for the user's choice.

**If no state file exists**: proceed to the Guard section normally.

---

## Guard

No command-level guard beyond the Step 0 resume check. Prerequisite checks happen inline at the point each dependency is actually needed — this lets the developer complete Phase 1 (context gathering) and Phase 2 (scaffold) even if AI-tooling dependencies aren't yet installed, and offers inline install rather than kicking them out of the session.

- **Phase 3.2** (`tooling-generation` skill) checks for the **onboard** plugin before invoking `/onboard:generate`. If missing, it offers inline install. Onboard is required — if the developer declines, Phase 3 aborts gracefully and the Phase 2 scaffold is preserved.

---

## State persistence (forge-state.json)

Forge writes to `.claude/forge-state.json` at every natural checkpoint — after each wizard step, after each scaffold sub-step, and after each Phase 3/4 action. This file is the source of truth for session resumability.

**Schema**:

```json
{
  "version": 1,
  "createdAt": "ISO-8601 timestamp",
  "updatedAt": "ISO-8601 timestamp",
  "currentPhase": "phase-1-context-gathering | phase-1.5-architectural-research | phase-2-scaffold | phase-3a-plugin-discovery | phase-3b-tooling-generation | complete",
  "currentStep": "skill-specific step identifier",
  "completedSteps": ["list of completed step identifiers"],
  "context": { /* partial context object, grows as wizard progresses */ },
  "researchFindings": { /* stack research results */ },
  "parkedQuestions": [ /* deferred deep-research items */ ],
  "nextAction": "human-readable description of what happens next",
  "research": {
    "mode": "agent | main-session | training-data-only"
  }
}
```

**Checkpoint contract**: every skill that participates in the `/forge:init` flow MUST update `forge-state.json` after completing a named step. The checkpoint writes must be atomic (write to `.tmp` then rename) to avoid corruption if interrupted mid-write. See individual skill files for the checkpoint sections.

When the entire workflow completes, set `currentPhase = "complete"` and `updatedAt` as the final write. This is what `/forge:status` and `/forge:resume` check to distinguish in-progress from finished sessions.

---

## Overview

Tell the developer:

> Starting **Forge** — I'll help you create a new project from scratch with AI-native tooling built in from day one.
>
> This runs in 3 phases:
> 1. **Context Gathering** — We'll discuss what you want to build, your tech stack, and preferences
> 2. **Scaffold** — I'll create the application and set up git
> 3. **AI Tooling** — I'll generate Claude tooling, CI/CD pipelines, and auto-evolution hooks
>
> By the end, you'll have a running app with world-class AI tooling that evolves alongside your code.

---

## Phase 1: Context Gathering

Use the `context-gathering` skill to guide the developer through the adaptive wizard. **The wizard has 8 named Steps and must emit a "Step X of 8" progress indicator at every Step boundary** so both Claude and the user can track progress.

The skill handles:
- Project vision (what they want to build)
- Tech stack discussion + web research via the `stack-researcher` agent
- Project details (database, auth, deploy, monitoring, etc.)
- Workflow preferences (testing, style, security, autonomy)
- CI/CD and auto-evolution preferences
- **Feature decomposition** (mandatory — downstream phases depend on it)
- Confirmation summary
- Phase 1.5 Architectural Research (conditional — only if parked questions exist)

**Scope-creep protection**: if a wizard question triggers deep architectural research (e.g., "which on-device LLM tier"), the skill offers three paths: **Park it** (capture placeholder, continue wizard, deep-dive later), **Deep-dive now** (pause wizard), or **Take a default**. See `context-gathering/SKILL.md` for the full protocol. Never let a single question derail the wizard into hours of research without user acknowledgment.

### Phase 1.5: Architectural Research (conditional)

If any questions were parked during Phase 1, run the new Step 8 of the context-gathering skill: a dedicated research sub-phase that resolves parked questions before scaffolding. This keeps Phase 1 focused and time-boxed while ensuring scaffold decisions are well-researched.

If no questions were parked (which should be the common case for well-scoped projects), skip Phase 1.5 entirely and go directly to Phase 2.

**Key reminders:**
- One question at a time — don't overwhelm
- Spawn the `stack-researcher` agent after learning the tech stack, but **expect failures**: sub-agents run in a separate permission sandbox and web tools may be silently denied. See the "Handling the two possible agent outcomes" section in `context-gathering/SKILL.md` for the fallback protocol (run research in main session with user-approved WebFetch calls). **Never let research silently fail** — always either complete it or explicitly tell the user you're falling back to a degraded mode.
- Skip questions that don't apply (the skill's question bank has conditions)
- Present recommendations with reasoning, especially for stack and deploy choices
- Get explicit confirmation before moving to Phase 2

After the wizard completes, you have the full context object.

---

## Phase 2: Scaffold

Use the `scaffolding` skill to create the application.

The skill handles:
- Pre-scaffold validation (empty dir, CLIs installed, git ready)
- Executing the scaffold (CLI tool, from scratch, template, OR walking skeleton — per Phase 1 decision)
- Post-scaffold additions (.env, Docker, monorepo config, i18n, etc.)
- Git setup (init, branches, remote, branch protection)
- Hello World verification (start dev server, confirm it works)
- Saving `.claude/forge-meta.json`

### Phase ordering branches on `scaffoldMode`

**If `context.scaffoldMode === "full"` (the default for most stacks)**:

```
Phase 1 → Phase 2 (full scaffold) → Phase 3 (AI tooling) → Handoff
```

This is the original forge flow. The full scaffold exists before AI tooling runs, onboard analyzes it once, and the run completes.

**If `context.scaffoldMode === "walking-skeleton"`**:

```
Phase 1 → Phase 2a (walking skeleton — Path D in scaffolding skill)
       → Phase 3 (AI tooling against walking skeleton)
       → Phase 2b (expand scaffold under AI-tooling guidance)
       → Handoff
```

This is the new flow for complex architectures (native mobile, custom backends, etc.) where forge's AI tooling benefits from being in place *before* the main build happens. The walking skeleton gives onboard one example of each pattern to derive rules from; Phase 2b then expands the skeleton into a fuller scaffold with each addition guided by the generated CLAUDE.md and hooks.

Inform the developer before starting Phase 2:

> Scaffolding your project... [If full:] This will create the complete application, set up git, and verify everything runs. [If walking skeleton:] This will create a minimal walking skeleton — one of each architectural element — so the AI tooling (Phase 3) can analyze real patterns. After AI tooling is in place, we'll come back to expand the scaffold (Phase 2b).

After Phase 2 (or Phase 2a) completes, confirm:

> Your [app / walking skeleton] is scaffolded and running. [Dev server verified at localhost:PORT]
> Git initialized with [branching strategy].
> Moving to AI tooling setup...

### Phase 2b: Expand Scaffold (walking-skeleton mode only)

This sub-phase runs AFTER Phase 3 (AI tooling) in walking-skeleton mode. It re-invokes the `scaffolding` skill in "expand" mode, which:

1. Reads the generated CLAUDE.md, path-scoped rules, and hooks from Phase 3
2. Reads `docs/feature-list.json` to know what features to add
3. Expands the walking skeleton by adding one feature at a time, respecting the conventions in the generated rules
4. Runs tests after each expansion to verify nothing broke
5. Saves updated `forge-meta.json` with the expanded file list

Phase 2b is a single checkpoint in `forge-state.json` (`currentPhase: "phase-2b-expand-scaffold"`) so it's resumable. Expansion can stop at any time — the scaffolded project is always usable.

---

## Phase 3: AI Tooling

### Step 3.1: Plugin Discovery (MUST run first)

Use the `plugin-discovery` skill which:
- Matches curated catalog against project context
- Presents an interactive checklist of recommended plugins
- Optionally searches the web for additional plugins
- Installs selected plugins
- **Compiles `coveredCapabilities`** — the list of capabilities covered by installed plugins

This step MUST complete before Step 3.2 because onboard needs `coveredCapabilities` to avoid generating agents that shadow installed plugins. The plugin-discovery skill returns both `installedPlugins` and `coveredCapabilities` for use in the next step.

### Step 3.2: Generate Claude Tooling

Use the `tooling-generation` skill, passing it the `installedPlugins` and `coveredCapabilities` from Step 3.1. The skill:
- Spawns the `scaffold-analyzer` agent to scan the scaffolded project
- Maps Phase 1 context + analysis + `coveredCapabilities` to onboard's format
- Invokes `/onboard:generate` (headless) for CLAUDE.md, rules, skills, agents, hooks
- Onboard skips agents for capabilities already covered by installed plugins
- Presents a brief summary for optional developer review

### Step 3.3: Generate CI/CD Pipelines

The tooling-generation skill also handles:
- Application CI pipeline (lint → test → build → deploy)
- Tooling audit pipeline (structural checks + semantic analysis)
- PR review pipeline (claude-code-action)
- Dependency management (Dependabot/Renovate)
- Auto-evolution hooks (FileChanged + SessionStart)
- Agent team quality hooks (if production team project)

**Skip CI/CD entirely if the developer chose not to deploy.**

### Step 3.4: Update CLAUDE.md with Plugin References

After all generation is complete, update the project's CLAUDE.md with:
- Installed plugins section (what's available, key commands)
- Agent team guide section (if team hooks were generated)

---

## Handoff

After all phases complete, present the completion summary:

> **Forge complete!**
>
> **Project**
> - [app name] scaffolded with [framework version]
> - Dev server verified at http://localhost:[port]
> - Git: [branching strategy], pushed to [remote or "local only"]
>
> **AI Tooling**
> - CLAUDE.md ([N] lines)
> - [N] path-scoped rules
> - [N] skills, [N] agents
> - [N] hooks (format, lint, drift detection)
>
> **CI/CD** [if applicable]
> - Application pipeline (ci.yml)
> - Tooling audit pipeline (tooling-audit.yml)
> - PR review pipeline (pr-review.yml)
>
> **Plugins Installed**
> - [list installed plugins with key commands]
>
> **Development Harness**
> - `init.sh` — run at the start of every session to bootstrap your environment
> - `docs/feature-list.json` — [N] features across [N] sprints (all starting as failing)
> - `docs/progress.md` — cross-session progress tracker
> - `docs/sprint-contracts/sprint-1.json` — Sprint 1 completion criteria (negotiated)
> - Session startup protocol + worktree workflow in CLAUDE.md
>
> **What to do next:**
> 1. Review CLAUDE.md — it captures your project's architectural decisions and conventions
> 2. Start your next session: `bash init.sh` → read progress → pick a feature from Sprint 1
> 3. Use worktrees for isolation: `EnterWorktree(name: "F001-[name]")` — see CLAUDE.md § Worktree Workflow
> 4. After implementing a feature, run `/onboard:verify F001` for independent evaluation
> 5. When Sprint 1 features are done, run `/onboard:verify --sprint 1` to check the sprint contract
> 6. Your tooling evolves — [auto-updates / run /onboard:evolve when notified] to keep AI tooling current
> 7. Check health — run `/forge:status` anytime to verify tooling is in sync

---

## Error Handling

Every phase has its own failure modes. The table below is the authoritative per-phase × per-failure × per-recovery matrix. Developer should always be able to inspect what happened — **never auto-clean partial state**.

### Phase 0: Resume check

| Failure | Cause | Recovery |
|---|---|---|
| `forge-state.json` is corrupt | Killed mid-write (shouldn't happen with atomic `.tmp` rename pattern), disk error, manual edit | Show raw contents, ask user to fix or delete. Never auto-delete. |
| `forge-state.json` schema mismatch | Old version of forge wrote the file | Show migration path (or tell user to delete and restart). Do not silently rewrite. |
| User chooses "Start fresh" but state file has valuable context | — | Archive to `.claude/forge-state.archived-[timestamp].json` before clearing. Never silently overwrite. |

### Phase 1: Context Gathering

| Failure | Cause | Recovery |
|---|---|---|
| Developer abandons mid-wizard (Ctrl-C, session killed) | Unexpected | State is already checkpointed per-step. `/forge:resume` picks up at the last completed Step. |
| Stack researcher sub-agent denied web tools | Permission sandbox isolation | Fall back to main-session research with user-approved WebFetch. See `context-gathering/SKILL.md` Step 2 "Outcome B". |
| User denies main-session web access too | Policy choice | Degrade to training-data-only mode with explicit warning. Mark `research.mode = "training-data-only"` in state. |
| Deep-research rabbit hole detected | Scope creep on a single question | "Park it" escape hatch presents Park / Deep-dive / Default options. Never silently continue a 30+ minute research session. |
| Feature decomposition skipped | Developer said "skip" | NOT allowed — generate a skeletal 3-5 feature list and continue. Downstream phases require this file. |

### Phase 2: Scaffold

| Failure | Cause | Recovery |
|---|---|---|
| Required CLI missing (npm, cargo, etc.) | Environment issue | Show install command; wait; don't auto-install. |
| External CLI scaffold fails mid-execution | Network, bad flags, permission | Leave partial files, show error, offer: retry with different flags / switch to Path B from-scratch / abort. |
| Git init fails | git not installed, or already a repo | Show error, offer manual resolution. Don't abort the whole phase. |
| Hello World verification fails | Build succeeds but app doesn't start | Report the error but don't block Phase 3. Developer can debug separately. |
| Session killed mid-scaffold | — | `/forge:resume` detects inconsistency between state file and filesystem. User chooses: inspect, clean-and-retry, or abort. |
| Walking skeleton Path D fails | Stack-specific | Revert to Path B (from scratch) with guidance, or ask user to describe architectural layers manually. |

### Phase 3: AI Tooling

| Failure | Cause | Recovery |
|---|---|---|
| Onboard plugin missing | Not installed | Offer inline install. If declined or install fails, abort Phase 3 with a recovery message pointing to the intact Phase 2 scaffold and suggesting `/onboard:init` manual recovery. Skip Phases 3.3, 3.4, 4 and go to minimal Handoff. |
| Onboard invocation errors after being present | Bug in onboard, bad input | Report the error. Partial CI/CD and hooks can still be generated independently. Continue with what works. |
| Session killed mid-`/onboard:generate` | Long-running step | `/forge:resume` detects partial output. User chooses: delete and retry / retry in recovery mode if supported / fast-forward past. Never silently retry on top of partial output. |
| Plugin discovery fails (catalog unreadable) | Plugin dev issue | Fall back to a hardcoded list of "always install" plugins (superpowers, commit-commands, claude-md-management) and continue. |


### Universal rules

- **Never auto-clean partial state.** Let the developer inspect.
- **Always checkpoint before risky operations.** `forge-state.json` must be current before any destructive step.
- **Never force git operations.** No force-push, no branch deletion without explicit confirmation.
- **Never call a sub-tool silently when it can fail.** Always wrap in try/handle-error and surface meaningful messages.
- **Always offer a resume path.** Even on abort, leave `forge-state.json` in place so `/forge:resume` works later.
