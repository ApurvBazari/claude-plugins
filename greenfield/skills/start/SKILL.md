---
name: start
description: Full 3-phase greenfield orchestrator — context gathering, scaffold, AI tooling. Creates a new project from scratch with AI-native Claude tooling built in from day one. Use only when user explicitly invokes /greenfield:start.
disable-model-invocation: true
---

# Start Skill — Scaffold a New Project with AI-Native Tooling

You are running the Greenfield initialization wizard. This is a guided, 3-phase process that discusses what the developer wants to build, scaffolds the application, and equips it with auto-evolving Claude Code tooling.

## Step 0: Resume check

Before any work, check for an existing in-progress Greenfield session in the current directory.

Check for `.claude/greenfield-state.json`:

**If it exists and `currentPhase !== "complete"`**: there's an in-progress session. Do NOT silently restart — tell the user and offer options:

> There's an in-progress Greenfield session in this directory.
>
> **Project**: [context.appDescription or "unnamed"]
> **Started**: [createdAt]
> **Last updated**: [updatedAt]
> **Currently at**: [currentPhase] / [currentStep]
> **Next action**: [nextAction]
>
> Options:
> 1. **Resume** — continue from where you left off (equivalent to `/greenfield:pickup`)
> 2. **Start fresh** — archive the old state to `.claude/greenfield-state.archived-[timestamp].json` and begin a new `/greenfield:start` run
> 3. **Inspect** — show me the state file contents so I can decide

Use AskUserQuestion. Do not proceed until the user chooses.

**If it exists and `currentPhase === "complete"`**: the previous Greenfield run finished. Tell the user:

> This directory already has a completed Greenfield setup (finished [updatedAt]).
>
> Re-running `/greenfield:start` would scaffold on top of the existing project, which is probably not what you want. Options:
> 1. **Start fresh in a new directory** — move to an empty directory and run `/greenfield:start` there
> 2. **Reconfigure existing** — run `/greenfield:check` to see current state, or `/greenfield:evolve` (from onboard) to update tooling
> 3. **Force re-init** — archive the current state and start over (you'll need to manually clean the scaffold; I won't delete files)

Wait for the user's choice.

**If no state file exists**: proceed to the Guard section normally.

---

## Guard

No command-level guard beyond the Step 0 resume check. Prerequisite checks happen inline at the point each dependency is actually needed — this lets the developer complete Phase 1 (context gathering) and Phase 2 (scaffold) even if AI-tooling dependencies aren't yet installed, and offers inline install rather than kicking them out of the session.

- **Phase 3.2** (`tooling-generation` skill) checks for the **onboard** plugin before invoking `/onboard:generate`. If missing, it offers inline install. Onboard is required — if the developer declines, Phase 3 aborts gracefully and the Phase 2 scaffold is preserved.

---

## State persistence (greenfield-state.json)

Greenfield writes to `.claude/greenfield-state.json` at every natural checkpoint — after each wizard step, after each scaffold sub-step, and after each Phase 3/4 action. This file is the source of truth for session resumability.

**Schema**:

```json
{
  "schemaVersion": 1,
  "createdAt": "ISO-8601 timestamp",
  "updatedAt": "ISO-8601 timestamp",
  "currentPhase": "phase-1-context-gathering | phase-1.8-synthesis-review | phase-1.5-architectural-research | phase-1.7-grill-spec | phase-2-scaffold | phase-3a-plugin-discovery | phase-3b-tooling-generation | complete",
  "currentSynthesisPhase": "architecturalFraming | dataArchitecture | apiIntegration | auth | privacy | security | runtimeOperations | cicdAndDelivery | architecturalValidation (only set when currentPhase === 'phase-1.8-synthesis-review'; identifies which phaseId is currently under review; cleared on return). Valid values in Round 2 / 2.5 / 3: \"architecturalFraming\", \"dataArchitecture\", \"apiIntegration\", \"auth\", \"privacy\", \"security\", \"runtimeOperations\", \"cicdAndDelivery\", \"architecturalValidation\". Future rounds add vision/workflow/featureRoadmap/schemaDraftReview.",
  "currentStep": "skill-specific step identifier",
  "completedSteps": ["list of completed step identifiers"],
  "context": { /* partial context object, grows as wizard progresses */ },
  "researchFindings": { /* stack research results */ },
  "parkedQuestions": [ /* deferred deep-research items */ ],
  "nextAction": "human-readable description of what happens next",
  "research": {
    "mode": "agent | main-session | training-data-only"
  },
  "phaseStatus": {
    "architecturalFraming": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "dataArchitecture": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "apiIntegration": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "auth": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "privacy": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "security": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "runtimeOperations": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "cicdAndDelivery": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    },
    "architecturalValidation": {
      "status": "not-yet-walked",
      "approvedAt": null,
      "lastModified": "ISO-8601 timestamp",
      "staleReason": null
    }
  }
}
```

**`phaseStatus` — stale-flag tracking (Round 2.5 / T9)**:

The `phaseStatus` map is initialized on first session write with all known wizard phases set to `{ status: "not-yet-walked", approvedAt: null, lastModified: <now>, staleReason: null }`. It is updated by the `synthesis-review` skill at the end of each phase's Approve/Adjust/Skip walk.

Status lifecycle:
- `not-yet-walked` → `in-progress` (on entering the phase wizard step)
- `in-progress` → `approved` (on synthesis review sign-off)
- `approved` → `stale` (when a dependency field in an upstream phase is adjusted; triggered by `synthesis-review` Step 7 propagation)
- `stale` → `in-progress` (on developer choosing "Re-walk" in the Step 0 entry-guard)

When any phase transitions to `stale`, the `staleReason` field is set to a short description of what changed (e.g., `"architecturalFraming.topology changed"`). `staleReason` is reset to `null` when the phase returns to `in-progress` or `approved`.

See `synthesis-review/references/stale-detection.md` for the full propagation algorithm and entry-guard protocol.

**Checkpoint contract**: every skill that participates in the `/greenfield:start` flow MUST update `greenfield-state.json` after completing a named step. The checkpoint writes must be atomic (write to `.tmp` then rename) to avoid corruption if interrupted mid-write. See individual skill files for the checkpoint sections.

When the entire workflow completes, set `currentPhase = "complete"` and `updatedAt` as the final write. This is what `/greenfield:check` and `/greenfield:pickup` check to distinguish in-progress from finished sessions.

---

## Overview

Tell the developer:

> Starting **Greenfield** — I'll help you create a new project from scratch with AI-native tooling built in from day one.
>
> This runs in 3 phases:
> 1. **Context Gathering** — We'll discuss what you want to build, your tech stack, and preferences (with an optional pre-scaffold validation gate)
> 2. **Scaffold** — I'll create the application and set up git
> 3. **AI Tooling** — I'll generate Claude tooling, CI/CD pipelines, and auto-evolution hooks
>
> By the end, you'll have a running app with world-class AI tooling that evolves alongside your code.

---

## Phase 1: Context Gathering

### Step 0: Project shape (CLI mini-wizard, 6 Qs)

Ask the user via AskUserQuestion (all six are single-select; see `ask-user-question-guard.md` rule — dynamic option lists must be guarded against collapsing to fewer than 2 items):

1. **App type** — Web app / Mobile / API / CLI / Library
2. **Scale** — Prototype / Team / Production
3. **Personas** — free text, 1-2 lines (record `commerceUser: true/false` based on text or follow-up)
4. **Deployment target** — Cloud / Self-host / Hybrid / Local-only
5. **Team size** — Solo / 2-5 / 6-20 / 20+
6. **Stack hint** — optional free text (e.g. "Next.js + Postgres")

Write answers to `.claude/greenfield-state.json` under `phase0` (atomic write: `.tmp` + `mv`). Checkpoint state with `phase: "phase-0-done"`.

### Step 1: Dispatch to visual companion (or linear fallback)

If `GREENFIELD_VISUAL_COMPANION=0` is set in the environment, skip the visual companion entirely:

```bash
if [ "${GREENFIELD_VISUAL_COMPANION:-1}" = "0" ]; then
  echo "Visual companion disabled via GREENFIELD_VISUAL_COMPANION=0. Using linear wizard."
fi
```

Otherwise, invoke the `visual-companion` skill via the Skill tool:

```
Skill(greenfield:visual-companion)
```

After it returns, read `greenfield-state.json`. If `phase == "context-gathering-linear"` (visual-companion fell through), invoke the legacy linear wizard:

```
Skill(greenfield:context-gathering)  # full 30-step linear mode
```

Both paths end with `greenfield-state.json` `phase: "phase-1.7-grill-spec"`. Continue to Phase 1.7.

### Step 2: Linear wizard details (only used if visual companion falls through)

Use the `context-gathering` skill to guide the developer through the adaptive wizard. **The wizard has 30 named Steps and must emit a "Step X of 30" progress indicator at every Step boundary** so both Claude and the user can track progress. (Round 4 added Step 2.2 Personas and Step 2.7 Domain Modeling to the previous 15-step flow; Round 5 added Step 16 Feature Roadmap and Step 19 Schema & API Draft Review, bringing it to 20; Round 6 added 9 new phases — search, caching, realtime, fileUploads, payments, frontendArchitecture, designSystem, uxAccessibilityPerf, i18nL10n — plus the CI Draft Review at Step 20, bringing the total to 30.)

#### Step 2.1 — Mode toggles (Round 4 entry gate)

Before any Q-bank content, the wizard fires three mode-toggle `AskUserQuestion` calls (defined verbatim in `context-gathering/SKILL.md § Step 1.1 — Mode toggles`):

1. **Depth** — `Heavy (Recommended)` or `Light`. Persists to `.claude/greenfield-state.json.mode.depth`.
2. **Coupling** — `Auto-loop (Recommended)` or `Hybrid`. Persists to `.claude/greenfield-state.json.mode.coupling`.
3. **Domain format** — `Full DDD (Recommended)` or `DDD-lite`. Persists to `.claude/greenfield-state.json.mode.domainFormat`.

After all three are captured, surface a confirmation echo:

> Wizard configured: **{mode.depth}** depth, **{mode.coupling}** coupling, **{mode.domainFormat}** domain. Press Enter to continue.

The defaults reflect a comprehensive-by-default posture — Heavy + Auto-loop + Full DDD are calibrated for production work. Users targeting prototypes / spike work should flip all three to Light + Hybrid + DDD-lite. The wizard surfaces a one-time downgrade prompt at the start of Step 2 (vision/scope) if Heavy + Full DDD + Auto-loop is chosen AND the project description suggests prototype scale (< 200 chars or contains "weekend"/"learning"/"toy"/"experiment"/"spike") — see `context-gathering/SKILL.md § Step 1.1 § Adjacent runaway guard`.

The skill handles:
- Project vision (what they want to build)
- Tech stack discussion + web research via the `stack-researcher` agent
- Project details (database, auth, deploy, monitoring, etc.)
- Workflow preferences (testing, style, security, autonomy)
- CI/CD and auto-evolution preferences (Step 5 — expanded in greenfield 3.0 to 17 questions covering provider, gates, env ladder, secrets, notifications, build matrix, caching, release pipeline, deploy cadence)
- **Phase 1.8 synthesis review** — runs inline at the end of each major step that has a synthesis template. Round 2 / 2.5 / 3 wires it for architecturalFraming (Step 2.5 — Architectural Framing), dataArchitecture (Step 3 — Data Architecture), apiIntegration (Step 4 — API & Integration), auth (Step 5 — Auth & Identity), privacy (Step 6 — Privacy & Data Governance), security (Step 7 — Security), runtimeOperations (Step 8 — Runtime Operations), cicdAndDelivery (Step 11 — CI/CD), and architecturalValidation (Step 15 — final cross-phase sign-off). Each pass renders the corresponding HTML in the scaffolded project (`docs/adr/architectural-framing.html`, `docs/adr/data-architecture.html`, `docs/adr/api-integration.html`, `docs/adr/auth.html`, `docs/adr/privacy.html`, `docs/adr/security.html`, `docs/adr/runtime-operations.html`, `docs/adr/cicd-and-delivery.html`, `docs/adr/architectural-validation.html`), walks the developer through Approve/Adjust/Skip per section, then returns to the next wizard step. Future rounds add vision/workflow/featureRoadmap/schemaDraftReview.
- **Feature decomposition** (mandatory — downstream phases depend on it)
- Confirmation summary
- Phase 1.5 Architectural Research (conditional — only if parked questions exist)

**Scope-creep protection**: if a wizard question triggers deep architectural research (e.g., "which on-device LLM tier"), the skill offers three paths: **Park it** (capture placeholder, continue wizard, deep-dive later), **Deep-dive now** (pause wizard), or **Take a default**. See `context-gathering/SKILL.md` for the full protocol. Never let a single question derail the wizard into hours of research without user acknowledgment.

### Phase 1.5: Architectural Research (conditional)

If any questions were parked during Phase 1, run the new Step 8 of the context-gathering skill: a dedicated research sub-phase that resolves parked questions before scaffolding. This keeps Phase 1 focused and time-boxed while ensuring scaffold decisions are well-researched.

If no questions were parked (which should be the common case for well-scoped projects), skip Phase 1.5 entirely and go directly to Phase 1.7.

### Phase 1.7: Pre-scaffold Spec Grilling (optional)

Use the `grill-spec` skill. It's a validation gate that walks every spec decision branch — scope, stack alignment, feature conflicts, missing dependencies, security alignment — and forces explicit resolution of any contradictions before scaffolding starts.

The skill is opt-in by default for non-production projects (the user is offered "Run pre-scaffold validation? (Recommended) / Skip"). For production projects (`isProduction: true`) the gate runs by default; the user can still opt out per-run.

Behavior:
- grill-spec invokes the greenfield-owned `greenfield/skills/adjust-dialog/` skill for its 5-category adversarial walk.
- If adjust-dialog is unavailable, grill-spec falls back to an inline minimal pattern (`grill-spec/references/inline-grill-fallback.md`).
- Either way, the spec is hardened in `greenfield-state.json.context` before Phase 2 starts.
- The skill can route back to Phase 1.5 if grilling exposes a question that warrants deep research.

After Phase 1.7 completes (or is skipped), `currentPhase` is set to `"phase-2-scaffold"` and control returns here.

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
- Saving `.claude/greenfield-meta.json`

### Phase ordering branches on `scaffoldMode`

**If `context.scaffoldMode === "full"` (the default for most stacks)**:

```
Phase 1 → Phase 2 (full scaffold) → Phase 3 (AI tooling) → Handoff
```

This is the original greenfield flow. The full scaffold exists before AI tooling runs, onboard analyzes it once, and the run completes.

**If `context.scaffoldMode === "walking-skeleton"`**:

```
Phase 1 → Phase 2a (walking skeleton — Path D in scaffolding skill)
       → Phase 3 (AI tooling against walking skeleton)
       → Phase 2b (expand scaffold under AI-tooling guidance)
       → Handoff
```

This is the new flow for complex architectures (native mobile, custom backends, etc.) where greenfield's AI tooling benefits from being in place *before* the main build happens. The walking skeleton gives onboard one example of each pattern to derive rules from; Phase 2b then expands the skeleton into a fuller scaffold with each addition guided by the generated CLAUDE.md and hooks.

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
5. Saves updated `greenfield-meta.json` with the expanded file list

Phase 2b is a single checkpoint in `greenfield-state.json` (`currentPhase: "phase-2b-expand-scaffold"`) so it's resumable. Expansion can stop at any time — the scaffolded project is always usable.

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

> **Greenfield complete!**
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
> 7. Check health — run `/greenfield:check` anytime to verify tooling is in sync

---

## Error Handling

Every phase has its own failure modes. The table below is the authoritative per-phase × per-failure × per-recovery matrix. Developer should always be able to inspect what happened — **never auto-clean partial state**.

### Phase 0: Resume check

| Failure | Cause | Recovery |
|---|---|---|
| `greenfield-state.json` is corrupt | Killed mid-write (shouldn't happen with atomic `.tmp` rename pattern), disk error, manual edit | Show raw contents, ask user to fix or delete. Never auto-delete. |
| `greenfield-state.json` schema mismatch | Old version of greenfield wrote the file | Show migration path (or tell user to delete and restart). Do not silently rewrite. |
| User chooses "Start fresh" but state file has valuable context | — | Archive to `.claude/greenfield-state.archived-[timestamp].json` before clearing. Never silently overwrite. |

### Phase 1: Context Gathering

| Failure | Cause | Recovery |
|---|---|---|
| Developer abandons mid-wizard (Ctrl-C, session killed) | Unexpected | State is already checkpointed per-step. `/greenfield:pickup` picks up at the last completed Step. |
| Stack researcher sub-agent denied web tools | Permission sandbox isolation | Fall back to main-session research with user-approved WebFetch. See `context-gathering/SKILL.md` Step 2 "Outcome B". |
| User denies main-session web access too | Policy choice | Degrade to training-data-only mode with explicit warning. Mark `research.mode = "training-data-only"` in state. |
| Deep-research rabbit hole detected | Scope creep on a single question | "Park it" escape hatch presents Park / Deep-dive / Default options. Never silently continue a 30+ minute research session. |
| Feature decomposition skipped | Developer said "skip" | NOT allowed — generate a skeletal 3-5 feature list and continue. Downstream phases require this file. |

### Phase 1.7: Pre-scaffold Spec Grilling

| Failure | Cause | Recovery |
|---|---|---|
| `greenfield/skills/adjust-dialog/` unavailable | Skill not yet loaded in this session | Fall back to inline grill (`grill-spec/references/inline-grill-fallback.md`). One-line note to user; never crash the run. |
| adjust-dialog Skill call errors mid-run | Skill tool error or session issue | Same fallback as above; log the error to `greenfield-state.json.research.notes` for later inspection. |
| Grilling exposes a stack-level conflict | Spec was inconsistent | Step 4 conflict resolution. Options: auto-fix / drop feature / route back to Phase 1.5. Never silent. |
| User abandons mid-grill (Ctrl-C) | Unexpected | State already checkpointed at category boundaries. `/greenfield:pickup` picks up at the next un-asked category. |
| Grilling extends past 10-minute timebox without convergence | User exploring deeply | Surface "extend or finish" prompt. If user finishes, capture remaining categories as parked questions. |

### Phase 1.8: Synthesis Review

| Failure | Cause | Recovery |
|---|---|---|
| Per-phase template missing (Round 2 ships `p3-data.html`, `p4-api.html`, `p8-cicd.html`; future phases have no template yet) | Synthesis invoked with a phaseId that has no template yet | `synthesis-review` returns `synthesisStatus: "no-template"`. Caller (context-gathering) logs a one-line note and continues. Do NOT fabricate sections. |
| `greenfield/skills/adjust-dialog/` unavailable during Adjust | Skill not yet loaded | `synthesis-review` Step 5 falls back to the inline 3-question mini-dialog (see `synthesis-review/references/adjust-dialog-protocol.md § Fallback`). Records `via: "inline-fallback"`. |
| Developer abandons mid-synthesis-walk | Ctrl-C | State already checkpointed at each section's Approve/Adjust/Skip boundary. `/greenfield:pickup` reads `currentSynthesisPhase` and re-enters synthesis-review at the next un-decided section. |
| Adjust dialog loops more than 3 times on one section | Section needs deeper revisiting | Halt the section's loop; offer Skip with a note. Three adjustments without convergence is a sign the section needs a future session. |
| Pre-commit hook installation fails | `.git/hooks/` missing or read-only | Tell the developer, continue the synthesis. Hook installation is best-effort — synthesis records still get written. |

### Phase 2: Scaffold

| Failure | Cause | Recovery |
|---|---|---|
| Required CLI missing (npm, cargo, etc.) | Environment issue | Show install command; wait; don't auto-install. |
| External CLI scaffold fails mid-execution | Network, bad flags, permission | Leave partial files, show error, offer: retry with different flags / switch to Path B from-scratch / abort. |
| Git init fails | git not installed, or already a repo | Show error, offer manual resolution. Don't abort the whole phase. |
| Hello World verification fails | Build succeeds but app doesn't start | Report the error but don't block Phase 3. Developer can debug separately. |
| Session killed mid-scaffold | — | `/greenfield:pickup` detects inconsistency between state file and filesystem. User chooses: inspect, clean-and-retry, or abort. |
| Walking skeleton Path D fails | Stack-specific | Revert to Path B (from scratch) with guidance, or ask user to describe architectural layers manually. |

### Phase 3: AI Tooling

| Failure | Cause | Recovery |
|---|---|---|
| Onboard plugin missing | Not installed | Offer inline install. If declined or install fails, abort Phase 3 with a recovery message pointing to the intact Phase 2 scaffold and suggesting `/onboard:start` manual recovery. Skip Phases 3.3, 3.4, 4 and go to minimal Handoff. |
| Onboard invocation errors after being present | Bug in onboard, bad input | Report the error. Partial CI/CD and hooks can still be generated independently. Continue with what works. |
| Session killed mid-`/onboard:generate` | Long-running step | `/greenfield:pickup` detects partial output. User chooses: delete and retry / retry in recovery mode if supported / fast-forward past. Never silently retry on top of partial output. |
| Plugin discovery fails (catalog unreadable) | Plugin dev issue | Fall back to a hardcoded list of "always install" plugins (superpowers, commit-commands, claude-md-management) and continue. |


### Universal rules

- **Never auto-clean partial state.** Let the developer inspect.
- **Always checkpoint before risky operations.** `greenfield-state.json` must be current before any destructive step.
- **Never force git operations.** No force-push, no branch deletion without explicit confirmation.
- **Never call a sub-tool silently when it can fail.** Always wrap in try/handle-error and surface meaningful messages.
- **Always offer a resume path.** Even on abort, leave `greenfield-state.json` in place so `/greenfield:pickup` works later.

## Key Rules

- **Step 0 resume check is mandatory** — never skip the `greenfield-state.json` check at entry. An in-progress session must be presented to the user before any new work begins; silent restart is not allowed.
- **All state writes are atomic** — always write to `greenfield-state.json.tmp` then rename. Never write directly to the final path; a killed mid-write leaves the session corrupt and un-resumable.
- **Feature decomposition is non-skippable** — if the developer says "skip", generate a 3-5 item skeletal list and continue. Downstream phases (`docs/feature-list.json`) depend on this file existing.
- **Research failure is never silent** — if the `stack-researcher` sub-agent is denied web access (sentinel response), fall back to main-session WebFetch with explicit user-visible per-call prompts. If the user also denies those, set `research.mode = "training-data-only"` and warn explicitly. Never proceed as though research succeeded.
- **Plugin discovery must complete before tooling generation** — `coveredCapabilities` from Step 3.1 is required by `/onboard:generate` to prevent agent shadowing. Step 3.2 must never be dispatched without the Step 3.1 return value in hand.
