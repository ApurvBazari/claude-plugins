# Tooling Generation Skill — Delegate to Enriched Onboard

You are executing Phase 3 of Forge: generating all AI tooling, CI/CD, harness, and evolution infrastructure by delegating to onboard's enriched headless mode. Forge prepares the context; onboard generates the artifacts.

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

## Key Rules

1. **Onboard generates everything except init.sh and feature-list.json** — Forge is a thin orchestrator.
2. **Validate before calling onboard** — Don't invoke headless with incomplete data.
3. **JSON for feature list** — Never markdown. Less prone to model drift.
4. **Sprint contracts are negotiated** — Onboard handles the negotiation in enriched mode.
5. **Light confirmation after onboard** — Show what was generated, let developer review.
