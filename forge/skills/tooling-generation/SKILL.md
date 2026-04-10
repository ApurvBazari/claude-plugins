# Tooling Generation Skill — Delegate to Enriched Onboard

You are executing Phase 3 of Forge: generating all AI tooling, CI/CD, harness, and evolution infrastructure by delegating to onboard's enriched headless mode. Forge prepares the context; onboard generates the artifacts.

## Guard: onboard prerequisite

This skill cannot do its job without the **onboard** plugin — onboard owns all generation. Check if onboard is installed before doing any work:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../onboard/commands/generate.md" 2>/dev/null
```

**If the probe finds the file**, onboard is present — proceed to Step 1.

**If the probe returns nothing**, onboard is missing. Tell the developer:

> The **onboard** plugin is required for AI tooling generation. It generates your CLAUDE.md, path-scoped rules, project-specific skills, agents, hooks, CI/CD pipelines, harness artifacts, and evolution hooks.
>
> It's not installed yet. Install it now? (runs: `claude plugin install onboard`)

Use AskUserQuestion with two options:
- **Install now (Recommended)** — run the install command via Bash, then continue
- **Abort Phase 3** — stop here; the Phase 2 scaffold stays intact for recovery

### If the developer chooses to install

1. Run `claude plugin install onboard` via the Bash tool.
2. Re-run the detection probe above.
3. **On success** — continue to Step 1. If `/onboard:generate` isn't immediately available in this session (Claude Code sometimes needs a reload for newly installed slash commands), tell the developer: "Onboard is installed, but its commands may not be available until you restart the session. If Phase 3.2 fails to invoke `/onboard:generate`, restart Claude Code and rerun `/forge:init` — it will detect the existing scaffold."
4. **On install failure** — surface the underlying error verbatim (network, marketplace not added, auth issue). Then abort Phase 3 using the same message as the decline path below.

### If the developer declines or install fails

Abort Phase 3 with a clear recovery message:

> Stopping Phase 3. Your scaffolded app is **intact at `[project path from Phase 2]`** — nothing was rolled back.
>
> To recover:
> 1. Install onboard manually: `claude plugin install onboard`
> 2. Run `/onboard:init` directly on the scaffolded project to generate AI tooling
> 3. (Optional) Rerun `/forge:init` later for the full 4-phase experience
>
> Your scaffold and git history are preserved. No cleanup needed.

Do not delete files. Do not touch git. Do not call onboard. Signal abort back to `/forge:init` — the command will skip Phases 3.3, 3.4, and 4 and go straight to a minimal Handoff that reports what was scaffolded and how to recover.

---

## Purpose

Pass the complete Phase 1 context to onboard headless with enriched flags enabled. Onboard handles ALL generation — CLAUDE.md, rules, skills, agents, hooks, CI/CD, harness, evolution, sprint contracts, and team support. Forge only generates two artifacts itself: `init.sh` and `docs/feature-list.json` (both require scaffold-specific knowledge that onboard doesn't have).

## Inputs

You receive:
1. The complete Phase 1 context object (from context-gathering skill)
2. The scaffolded project (from Phase 2)
3. The `installedPlugins` and `coveredCapabilities` (from plugin-discovery skill)

## Step 1: Prepare Onboard Context

### Build the analysis object

Spawn the `scaffold-analyzer` agent to scan the freshly scaffolded project. The agent produces the structured `analysis` object matching onboard's expected format.

### Map wizard answers

| Forge field | Onboard field | Notes |
|---|---|---|
| `appDescription` | `projectDescription` | Direct map |
| `teamSize` | `teamSize` | Direct map |
| `primaryTasks` | `primaryTasks` | Direct map |
| `branchingStrategy` | `branchingStrategy` | Direct map |
| `deployFrequency` | `deployFrequency` | Direct map |
| `testingPhilosophy` | `testingPhilosophy` | Direct map |
| `codeStyleStrictness` | `codeStyleStrictness` | Direct map |
| `securitySensitivity` | `securitySensitivity` | Direct map |
| `autonomyLevel` | `autonomyLevel` | Direct map |
| `painPoints` | `painPoints` | Direct map |
| `frontendPatterns` | `frontendPatterns` | If frontend project |
| `backendPatterns` | `backendPatterns` | If backend project |
| (inferred) | `projectMaturity` | Always "new" for scaffolded projects |

### Set enriched flags

Based on Phase 1 context, set the `enriched` object:

```json
{
  "enriched": {
    "enableCICD": true,          // false if willDeploy === false
    "enableHarness": true,       // always true for Forge projects
    "enableEvolution": true,     // always true
    "enableSprintContracts": true, // always true for Forge
    "enableTeams": false,        // true if isProduction && hasTeam
    "enableVerification": true,  // always true
    "willDeploy": true,          // from Phase 1
    "ciAuditAction": "auto-fix-pr", // from Phase 1
    "prReviewTrigger": "auto",   // from Phase 1
    "autoEvolutionMode": "manual", // from Phase 1
    "verificationStrategy": "combination", // from Phase 1
    "deployTarget": "vercel"     // from Phase 1
  }
}
```

### Set caller extras

```json
{
  "callerExtras": {
    "installedPlugins": ["superpowers", "feature-dev", ...],
    "coveredCapabilities": ["code-review", "test-generation", ...]
  }
}
```

### Validate

Before calling onboard, verify required fields:
- `analysis.stack.languages` — at least one language
- `wizardAnswers.projectDescription` — non-empty
- `wizardAnswers.autonomyLevel` — one of: always-ask, balanced, autonomous
- `projectPath` — absolute path that exists

Defaults for optional fields: teamSize→"solo", testingPhilosophy→"write-after", codeStyleStrictness→"moderate", securitySensitivity→"standard", projectMaturity→"new".

## Step 2: Invoke Onboard Headless

Call `/onboard:generate` with the prepared context. Onboard now generates EVERYTHING:

**Core (always):**
- Root CLAUDE.md (with harness sections: session protocol, test immutability, context management)
- Subdirectory CLAUDE.md files
- Path-scoped rules
- Project-specific skills
- Agents (plugin-aware — skips shadowed capabilities)
- PostToolUse hooks (format, lint)
- PR template
- onboard-meta.json

**Enriched (based on flags):**
- CI/CD pipelines (if enableCICD)
- Harness artifacts: docs/progress.md, docs/HARNESS-GUIDE.md (if enableHarness)
- Auto-evolution hooks + scripts (if enableEvolution)
- Sprint contracts infrastructure (if enableSprintContracts)
- Agent team support (if enableTeams)

Present a brief summary after generation. Offer optional review.

## Step 3: Forge-Specific Artifacts

These two artifacts require scaffold-specific knowledge that only Forge has:

### 3.1: `init.sh` (project root)

Generate a stack-specific environment bootstrap script using the install and dev commands from the scaffolded project. Made executable.

For CLI tools: simpler script that installs deps and runs a smoke test.

### 3.2: `docs/feature-list.json`

Write the feature list from Phase 1 feature decomposition. JSON format with sprints, features, steps, `passes: false`.

If developer skipped feature decomposition: generate a minimal 3-5 feature list.

## Step 4: Update Forge Metadata

Update `.claude/forge-meta.json` with:
- `generated.tooling`: from onboard's response
- `generated.cicd`: from onboard's response
- `generated.harness`: init.sh + feature-list.json + onboard's harness artifacts
- `context.verificationStrategy`: the chosen approach
- `costs.forgeInit`: estimated token usage

## Checkpoint Protocol (for resume support)

This skill MUST write `.claude/forge-state.json` after each Step so `/forge:resume` can pick up mid-generation if the session is interrupted. See `commands/init.md` for the full state schema.

### When to checkpoint

| After Step | Write to state file |
|---|---|
| Step 1 (Prepare Onboard Context) | `completedSteps: [..., "tooling-context-prepared"]`, `currentStep: "onboard-invoke"` |
| Step 2 (Invoke Onboard Headless) | Add `"onboard-invoke"`, `currentStep: "forge-artifacts"`, `generated.tooling: [...]` |
| Step 3 (Forge-Specific Artifacts) | Add `"forge-artifacts"`, `currentStep: "tooling-metadata"`, `generated.harness: [...]` |
| Step 4 (Update Forge Metadata) | Add `"tooling-metadata"`, `currentPhase: "phase-4-lifecycle-setup"`, `currentStep: "lifecycle-check"` (handoff to lifecycle-setup) |

### Critical: onboard is expensive and time-consuming
Step 2 (invoking `/onboard:generate`) is the single longest-running step in all of forge — it can take many minutes and generates dozens of files. If the session is killed during this step, the next resume will see `onboard-invoke` as NOT complete and must handle it carefully:

- Check whether onboard left any artifacts on disk (look for `CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, etc.).
- If partial onboard output exists, ask the user: "Onboard was interrupted mid-generation. Should I (a) delete the partial output and retry from scratch, (b) run `/onboard:generate` in recovery mode if it supports it, or (c) fast-forward past this step and assume what's there is good enough?"
- Never silently retry onboard on top of its own partial output — that can cause corruption or duplicate rules.

### Atomic write
Same protocol as other skills: write to `.claude/forge-state.json.tmp`, then `mv` to `.claude/forge-state.json`.

### Resume entry contract
When invoked via `/forge:resume`, check `completedSteps` and skip anything already done. Do NOT re-invoke `/onboard:generate` if `onboard-invoke` is in `completedSteps`.

## Key Rules

1. **Onboard generates everything except init.sh and feature-list.json** — Forge is a thin orchestrator.
2. **Validate before calling onboard** — Don't invoke headless with incomplete data.
3. **JSON for feature list** — Never markdown. Less prone to model drift.
4. **Sprint contracts are negotiated** — Onboard handles the negotiation in enriched mode.
5. **Light confirmation after onboard** — Show what was generated, let developer review.
6. **Checkpoint after every Step** — Always write `forge-state.json` at Step boundaries so resume works. Onboard's long runtime makes checkpointing critical.
