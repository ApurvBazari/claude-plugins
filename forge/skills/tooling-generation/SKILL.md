---
name: tooling-generation
description: Forge Phase 3 — prepares scaffold context and delegates to onboard's headless generate skill for CLAUDE.md, rules, skills, agents, hooks, CI/CD, and evolution infrastructure. Internal building block invoked by forge init — not user-invocable.
user-invocable: false
---

# Tooling Generation Skill — Delegate to Enriched Onboard

You are executing Phase 3 of Forge: generating all AI tooling, CI/CD, harness, and evolution infrastructure by delegating to onboard's enriched headless mode. Forge prepares the context; onboard generates the artifacts.

## Guard: onboard prerequisite

This skill cannot do its job without the **onboard** plugin — onboard owns all generation. Check if onboard is installed before doing any work:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../onboard/skills/generate/SKILL.md" 2>/dev/null
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

### Resolve the onboard plugin version (runtime — never hardcode)

Before building the headless context, **read onboard's actual installed version at runtime**. Do not bake a literal version string into the context — the 2026-04-16 release-gate Phase 5 test (finding FO6) found `forge-meta.json` recorded `pluginVersion: "1.2.0"` even though the installed onboard was at 1.9.0, leading to stale snapshots and version checks.

Resolution order (CLI-first, sibling-path fallback, hard-fail otherwise):

```bash
ONBOARD_VERSION=""

# 1. CLI-first: prefer the official Claude Code CLI when available
if command -v claude >/dev/null 2>&1; then
  ONBOARD_VERSION=$(claude plugins info onboard --format json 2>/dev/null | jq -r '.version // empty')
fi

# 2. Sibling-path fallback for the claude-plugins marketplace layout
#    ($CLAUDE_PLUGIN_ROOT here is forge's plugin root, so onboard is a sibling)
if [ -z "$ONBOARD_VERSION" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/../onboard/.claude-plugin/plugin.json" ]; then
  ONBOARD_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/../onboard/.claude-plugin/plugin.json")
fi

# 3. Hard-fail if neither resolved (shouldn't happen — Guard already checked onboard exists)
if [ -z "$ONBOARD_VERSION" ]; then
  echo "ERROR: Cannot resolve onboard plugin version. Reinstall onboard: claude plugins install onboard" >&2
  exit 1
fi
```

Inject `$ONBOARD_VERSION` into the headless context as `meta.onboardVersion` for forge-side telemetry; onboard itself reads its own version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` when writing `pluginVersion` into `onboard-meta.json` (see `onboard/skills/generate/SKILL.md` § Step 5 for that contract). Do NOT pass `pluginVersion` in `callerExtras` — config-generator authoritatively reads it from disk so onboard upgrades flow through without forge changes.

The PR-version markers later in this skill (lines mentioning "Onboard 1.5.0", "Onboard 1.6.0", etc.) are an **historical audit trail** of which onboard release introduced each integration — they document when forge first started honoring a given onboard feature. Keep them as comments; the runtime source of truth for the live version is the resolution code above.

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

```jsonc
{
  "callerExtras": {
    "installedPlugins": ["superpowers", "feature-dev", ...],
    "coveredCapabilities": ["code-review", "test-generation", ...],
    "allowPluginReferences": true,   // default true when installedPlugins is non-empty

    // Headless passthrough flags — forge runs non-interactive. Always pass true.
    "disableSkillTuning": true,        // skip per-skill batched confirmation; rely on archetype + wizard defaults
    "disableAgentTuning": true,        // skip per-agent batched confirmation; rely on archetype + wizard defaults
    "disableOutputStyleTuning": true,  // skip Phase 7b batched confirmation; emit archetype-matched style directly
    "disableLSP": true,                // skip Phase 7c LSP prompt; scaffolded projects have placeholder code so file-presence signals are unreliable. Developer re-runs /onboard:evolve after adding real code.
    "disableBuiltInSkills": true,      // skip Phase 7d built-in skills prompt; scaffolded projects have placeholder code so detection signals (file counts, complexity, deps) are premature. Developer re-runs /onboard:evolve after adding real code.

    "qualityGates": {
      "sessionStart": [
        {
          "type": "reminder",
          "message": "Starting new feature work? Begin with /superpowers:brainstorming.",
          "condition": "superpowers-installed"
        }
      ],
      "preCommit": [
        { "skill": "code-review:code-review", "triggerOn": "commit", "mode": "blocking" },
        { "skill": "superpowers:verification-before-completion", "triggerOn": "commit", "mode": "blocking" }
      ],
      "featureStart": [
        {
          "type": "reminder",
          "criticalDirs": [],  // populated from scaffold-analyzer directory roles (see below)
          "message": "New file in {dir}. Consider /superpowers:brainstorming first."
        }
      ],
      "postFeature": [
        { "skill": "claude-md-management:revise-claude-md", "triggerOn": "session-end", "mode": "advisory" }
      ]
    },

    "phaseSkills": {
      "research":   ["superpowers:brainstorming", "superpowers:dispatching-parallel-agents", "context7"],
      "planning":   ["superpowers:writing-plans"],
      "feature":    ["feature-dev:code-architect", "superpowers:test-driven-development"],
      "review":     ["code-review:code-review", "pr-review-toolkit:review-pr"],
      "commit":     ["commit-commands:commit"],
      "post-phase": ["claude-md-management:revise-claude-md"]
    }
  }
}
```

### Derivation rules — `qualityGates` + `phaseSkills`

The two new fields are NOT blindly included — build them from Phase 1 context + actual installed plugins:

1. **Start from the defaults above**, then filter out any skill whose plugin is not in `installedPlugins`. Example: if `code-review` is not installed, drop `code-review:code-review` from `preCommit` and `phaseSkills.review`.

2. **`qualityGates.sessionStart` is seeded only if `superpowers` is in `installedPlugins`.** Without superpowers, the `"superpowers-installed"` condition fails and onboard drops the entry. You can optionally include a generic fallback entry without the condition, but keep the total message count small to respect the ≤ 3-line budget.

3. **`qualityGates.featureStart.criticalDirs`** is populated from scaffold-analyzer's identified directory roles. Map roles to paths:
   - `domain` → `domain/`, `lib/domain/`, `internal/domain/`
   - `parser` → `domain/parser/`, `src/parser/`, `internal/parser/`
   - `data-layer` → `data/`, `lib/data/`, `data/db/`
   - `compose-ui` → `ui/compose/`, `src/ui/`, `app/ui/`
   - `api` → `api/`, `src/api/`, `internal/api/`

   If scaffold-analyzer identifies no matching roles, pass an empty array. Onboard skips the featureStart hook entirely when `criticalDirs` is empty (no false positives).

4. **autonomyLevel downgrade — `preCommit[].mode`**:

   | `autonomyLevel` | Action on `preCommit[].mode` |
   |---|---|
   | `always-ask` (exploratory) | Downgrade ALL to `"advisory"` |
   | `balanced` (standard) | Keep as seeded (default `"blocking"`) |
   | `autonomous` (production) | Keep as seeded (default `"blocking"`) |

   This is mechanical — apply it in-place before sending callerExtras to onboard. Onboard honors whatever mode it receives and does not re-derive.

5. **Never fabricate plugin references**. If `superpowers`, `feature-dev`, `code-review`, `pr-review-toolkit`, `claude-md-management`, or `commit-commands` is missing from `installedPlugins`, drop all references to it from `qualityGates` and `phaseSkills`. Onboard also does plugin-availability checks, but filtering at the caller keeps the context clean and prevents confusing warnings in `onboard-meta.json`.

6. **Research phase is always seeded when `superpowers` is in `installedPlugins`** — brainstorming is treated as mandatory pre-work for any new feature, not optional. Its hard-gate is a feature, not a bug: it prevents drift between "what I asked for" and "what got built".

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

**MCP servers (automatic from stack signals):** Onboard emits `.mcp.json` and `.claude/onboard-mcp-snapshot.json` when detected signals match its catalog (e.g., Vercel projects get `vercel`, frontend stacks get `chrome-devtools-mcp`, all projects get `context7`). Matching plugins are auto-installed if not already present. Full rules in `onboard/skills/generation/references/mcp-guide.md`. If a scaffold template already ships its own `.mcp.json`, pass `callerExtras.disableMCP: true` in Step 1 to suppress onboard's emission.

**Skill frontmatter tuning (automatic from archetype classification):** Onboard 1.5.0 emits extended skill frontmatter — `allowed-tools`, `model`, `effort`, `paths`, `context`, `agent` — on every generated skill, composing archetype defaults with wizard-level tuning (`wizardAnswers.skillTuning`). A batched confirmation step runs by default to let the developer tweak per-skill. The snapshot lands at `.claude/onboard-skill-snapshot.json` for drift detection. Forge passes `callerExtras.disableSkillTuning: true` whenever forge is running headless and wants the confirmation suppressed; the generator still emits the full frontmatter using archetype + wizard defaults. Full rules in `onboard/skills/generation/references/skills-guide.md` § Frontmatter Reference.

**Agent frontmatter tuning (automatic from archetype classification):** Onboard 1.6.0 emits extended agent frontmatter — `tools`, `disallowedTools`, `model`, `effort`, `isolation`, `color`, `maxTurns`, `permissionMode` — on every generated agent, composing archetype defaults (reviewer/validator/generator/architect/researcher) with wizard-level tuning (`wizardAnswers.agentTuning`). A batched confirmation step runs by default to let the developer tweak per-agent. The snapshot lands at `.claude/onboard-agent-snapshot.json` for drift detection. Forge passes `callerExtras.disableAgentTuning: true` whenever forge is running headless and wants the confirmation suppressed; the generator still emits the full frontmatter using archetype + wizard defaults. Note: `proactive` is encoded via description prefix (it is not a frontmatter field); `isolation` only accepts `worktree` and is dropped in non-git directories. Full rules in `onboard/skills/generation/references/agents-guide.md` § Frontmatter Reference.

**Output style generation (automatic from archetype classification):** Onboard 1.7.0 emits one project-scoped custom output style at `.claude/output-styles/<name>.md` based on 5 archetypes (onboarding / teaching / production-ops / research / solo) inferred from existing wizard + analysis signals. Priority: production-ops > onboarding > teaching > research > solo. Built-in styles (Default / Explanatory / Learning) are Anthropic-provided and referenced in the generated CLAUDE.md Plugin Integration section — never re-emitted as files. A batched confirmation runs by default; the snapshot lands at `.claude/onboard-output-style-snapshot.json` for drift detection (frontmatter-only scope — body edits are free). Forge passes `callerExtras.disableOutputStyleTuning: true` whenever forge is running headless and wants the confirmation suppressed; the generator still emits the archetype-matched style. Full rules in `onboard/skills/generation/references/output-styles-guide.md`; 5 body templates in `output-styles-catalog.md`.

**LSP plugin recommendations (automatic from detected source files):** Onboard 1.8.0 detects project languages via `detect-lsp-signals.sh` and offers matching marketplace LSP plugins (`typescript-lsp`, `gopls-lsp`, `rust-analyzer-lsp`, etc. — 12-entry catalog) through wizard Phase 5.6. Forge passes `callerExtras.disableLSP: true` because freshly scaffolded projects have placeholder code that would trigger unreliable file-presence signals. The developer runs `/onboard:evolve` after adding real source files to trigger the prompt. Full rules in `onboard/skills/generation/references/lsp-plugin-catalog.md`. Surface this in the handoff message: "Run `/onboard:evolve` after adding source files to get LSP plugin recommendations."

**Built-in skill recommendations (automatic from codebase analysis):** Onboard 1.9.0 recommends built-in Claude Code skills (`/loop`, `/simplify`, `/debug`, `/pr-summary` as core; `/schedule`, `/claude-api`, `/explain-code`, `/codebase-visualizer`, `/batch` as conditional extras) through wizard Phase 5.7 and documents accepted skills in the generated CLAUDE.md with project-specific usage examples. Forge passes `callerExtras.disableBuiltInSkills: true` because freshly scaffolded projects have placeholder code — detection signals (file counts, complexity, dependency lists) are premature. The developer runs `/onboard:evolve` after adding real source files to trigger the prompt. Full rules in `onboard/skills/generation/references/built-in-skills-catalog.md`. Surface this in the handoff message: "Run `/onboard:evolve` after adding source files to get built-in skill recommendations."

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
- `generated.toolingFlags`: **the full `callerExtras` object built in Step 1 + the `hookStatus` object from onboard's response**. This persists `installedPlugins`, `coveredCapabilities`, `qualityGates`, `phaseSkills`, and `allowPluginReferences` so `/forge:status` can later report Plugin Integration Coverage without re-deriving them, and mirrors onboard's `hookStatus` telemetry so the coverage report can show planned-vs-generated-vs-skipped counts. Required by the `/forge:status` Step 4.5 coverage report. Shape:

  ```jsonc
  {
    "installedPlugins": ["superpowers", "code-review", ...],
    "coveredCapabilities": ["code-review", ...],
    "allowPluginReferences": true,
    "qualityGates": {
      "sessionStart": [ ... ],
      "preCommit":    [ ... ],
      "featureStart": [ ... ],
      "postFeature":  [ ... ]
    },
    "phaseSkills": {
      "research": [ ... ],
      "planning": [ ... ],
      "feature":  [ ... ],
      "review":   [ ... ],
      "commit":   [ ... ],
      "post-phase": [ ... ]
    },
    "hookStatus": {                          // NEW — mirrored from /onboard:generate response
      "planned":   { "SessionStart": 1, "PreToolUse:Write": 1, "PreToolUse:Bash": 2, "Stop": 1 },
      "generated": {                         // list-of-script-basenames per event key
        "SessionStart":     ["plugin-integration-reminder.sh"],
        "PreToolUse:Write": ["feature-start-detector.sh"],
        "PreToolUse:Bash":  ["pre-commit-code-review.sh", "pre-commit-verification-before-completion.sh"],
        "Stop":             ["post-feature-revise-claude-md.sh"]
      },
      "skipped":   [],
      "warnings":  [],
      "downgradeApplied": null              // optional — object with rule + affectedEntries when autonomyLevel forced a downgrade
    },
    "skillStatus": {                        // NEW in onboard 1.5.0 — mirrored from /onboard:generate response
      "planned":           ["react-component", "pr-summarizer"],
      "generated":         ["react-component", "pr-summarizer"],
      "skipped":           [],
      "frontmatterFields": { /* opaque — see onboard/skills/generation/SKILL.md § Skill Frontmatter Emission */ },
      "existedPreOnboard": [],
      "warnings":          []
    },
    "agentStatus": {                        // NEW in onboard 1.6.0 — mirrored from /onboard:generate response
      "planned":           ["code-reviewer", "tdd-test-writer"],
      "generated":         ["code-reviewer", "tdd-test-writer"],
      "skipped":           [],
      "frontmatterFields": { /* opaque — see onboard/skills/generation/SKILL.md § Agent Frontmatter Emission */ },
      "existedPreOnboard": [],
      "warnings":          []
    },
    "mcpStatus": {                          // NEW in onboard 1.4.0 — mirrored from /onboard:generate response
      "planned":           ["context7", "vercel"],
      "generated":         ["context7", "vercel"],
      "skipped":           [],
      "autoInstalled":     ["vercel"],
      "autoInstallFailed": [],
      "existedPreOnboard": false
    },
    "outputStyleStatus": {                  // NEW in onboard 1.7.0 — mirrored from /onboard:generate response
      "planned":             ["solo-minimal"],
      "generated":           ["solo-minimal"],
      "skipped":             [],
      "frontmatterFields":   { /* opaque — see onboard/skills/generation/SKILL.md § Output Styles */ },
      "activationDefault":   "none",
      "settingsLocalWritten": false,
      "settingsLocalWarning": null,
      "existedPreOnboard":   [],
      "warnings":            []
    },
    "lspStatus": {                          // NEW in onboard 1.8.0 — mirrored from /onboard:generate response
      "planned":           ["typescript-lsp", "pyright-lsp"],
      "accepted":          ["typescript-lsp"],
      "generated":         ["typescript-lsp"],
      "skipped":           [{ "plugin": "pyright-lsp", "reason": "caller-disabled" }],
      "autoInstalled":     [],
      "autoInstallFailed": [],
      "alreadyInstalled":  []
    },
    "builtInSkillsStatus": {                // NEW in onboard 1.9.0 — mirrored from /onboard:generate response
      "planned":           [],
      "generated":         [],
      "skipped":           [{ "skill": "*", "reason": "caller-disabled" }],
      "warnings":          [],
      "detectionSignals":  {}
    }
  }
  ```

  **Scope reminder**: `hookStatus` only tracks hooks derived from `callerExtras.qualityGates`. Format/lint hooks, forge-internal hooks, and any other non-Plugin-Integration hooks stay out of these counts even though they're written to `.claude/settings.json`. See `onboard/skills/generation/SKILL.md` § Hook Status Telemetry § Scope boundary for the rationale.

  **Write rules**:
  - Copy `installedPlugins`, `coveredCapabilities`, `allowPluginReferences`, `allowHttpHooks`, `qualityGates`, `phaseSkills` from the in-memory `callerExtras` object exactly as it was sent to `/onboard:generate` — including the autonomyLevel-downgraded `preCommit[].mode` values and any per-entry `hookType`/`promptRef`/`promptInline`/`agentRef`/`httpUrl`/`httpHeaders`/`timeout` fields. Do not re-derive.
  - Copy `hookStatus` verbatim from the `/onboard:generate` response object (see `onboard/skills/generate/SKILL.md` § Step 5). Do not reshape. `generated` values vary by hook type (script basename for `command`, prompt filename for `prompt`, agent name for `agent`, URL for `http`) — treat the value as an opaque string array.
  - **Invariant**: `toolingFlags.hookStatus.planned` keys should match what onboard expected to generate from `toolingFlags.qualityGates`. A mismatch signals a contract drift between forge and onboard.
  - **Key format passthrough**: hookStatus keys use `<Event>[:<Matcher>][:<Type>]` format. The `:<Type>` suffix is OMITTED when the hook type is `command` (backward compatible — pre-upgrade forge-meta.json fixtures remain byte-identical). Non-command types surface as e.g. `TaskCompleted:agent`, `UserPromptSubmit:prompt`, `Elicitation::http` (double colon when matcher is absent but type is non-default). Forge treats these keys as opaque strings and never parses them — parsing happens in downstream consumers (`/forge:status`, `/onboard:status`). See `onboard/skills/generation/SKILL.md` § Hook Status Telemetry for the full key-format contract.

- `context.verificationStrategy`: the chosen approach
- `costs.forgeInit`: estimated token usage

## Checkpoint Protocol (for resume support)

This skill MUST write `.claude/forge-state.json` after each Step so `/forge:resume` can pick up mid-generation if the session is interrupted. See `skills/init/SKILL.md` for the full state schema.

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
