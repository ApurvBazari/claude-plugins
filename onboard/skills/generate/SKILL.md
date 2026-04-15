---
name: generate
description: Headless Claude tooling generation for programmatic callers (e.g., the forge plugin). Consumes a pre-seeded context JSON containing analysis, wizard answers, and plugin data; skips interactive phases; returns hookStatus telemetry. Not user-invocable.
user-invocable: false
---

# Generate Skill — Headless Tooling Generation

You are running the onboard headless generation skill. This generates Claude tooling artifacts from pre-seeded context without running the interactive wizard or codebase analysis.

This skill is designed for programmatic consumers (e.g., the Forge plugin) that have already gathered project context through their own workflow and need onboard's generation capabilities directly.

**Plugin detection fallback**: If `callerExtras.installedPlugins` is absent in the provided context, the generation skill probes the filesystem using the shared procedure in `../generation/references/plugin-drift-detection.md` § Probe Procedure (generate runs probe-only — no baseline diff). This means headless callers that don't compile plugin data will still get Plugin Integration output if plugins are installed.

---

## Step 1: Read Context Input

The caller must provide a context JSON object in the conversation. This object contains all the information that the wizard and analyzer would normally produce.

### Required Context Structure

```json
{
  "source": "string — identifier of the calling plugin (e.g., 'forge')",
  "version": "string — semver of the context format",
  "projectPath": "string — absolute path to the project root",

  "analysis": {
    "structure": {
      "totalFiles": "number",
      "totalDirs": "number",
      "directoryTree": "string — directory tree output",
      "keyFiles": ["string — notable config/entry files"],
      "entryPoints": ["string — main entry point files"],
      "monorepo": "boolean"
    },
    "stack": {
      "languages": [{"name": "string", "percentage": "number"}],
      "frameworks": [{"name": "string", "version": "string"}],
      "buildTools": ["string"],
      "testingSetup": {
        "framework": "string",
        "configFile": "string",
        "testFileCount": "number"
      },
      "linters": [{"name": "string", "configFile": "string"}],
      "formatters": [{"name": "string", "configFile": "string"}],
      "cicd": ["string — CI/CD tools detected"],
      "packageManager": "string"
    },
    "complexity": {
      "score": "number (0-100)",
      "category": "string — small | medium | large | enterprise",
      "fileCount": "number",
      "locEstimate": "number"
    },
    "configs": {
      "typescript": "object — parsed tsconfig settings (optional)",
      "eslint": "object — parsed eslint config (optional)",
      "prettier": "object — parsed prettier config (optional)"
    }
  },

  "wizardAnswers": {
    "projectDescription": "string",
    "teamSize": "string — solo | small (2-5) | medium (6-15) | large (15+)",
    "projectMaturity": "string — new | early | established | legacy",
    "primaryTasks": ["string"],
    "codeReviewProcess": "string — none | informal | formal-pr",
    "branchingStrategy": "string — trunk-based | gitflow | feature-branches",
    "deployFrequency": "string — continuous | daily | weekly | manual | none",
    "testingPhilosophy": "string — always 'tdd' (hard-wired, included for schema compatibility)",
    "codeStyleStrictness": "string — relaxed | moderate | strict",
    "securitySensitivity": "string — standard | elevated | high",
    "autonomyLevel": "string — always-ask | balanced | autonomous",
    "painPoints": {
      "timeSinks": "string (optional)",
      "errorProne": "string (optional)",
      "automationWishes": "string (optional)"
    },
    "frontendPatterns": "object (optional — same shape as wizard output)",
    "backendPatterns": "object (optional — same shape as wizard output)",
    "devopsPatterns": "object (optional — same shape as wizard output)",
    "advancedHookEvents": "string[] (optional) — event names the developer explicitly selected in wizard Phase 5.1. Empty array = suppress inference. Absent = inference runs. See generation/SKILL.md § Advanced Event Hooks § Wizard opt-in plumbing.",
    "advancedHookTypes": "object (optional) — map<eventName, 'command'|'prompt'|'agent'|'http'> from wizard Phase 5.1.1. Selects the execution type per event. Only keys for judgment-capable events (UserPromptSubmit, Stop, TaskCreated, TaskCompleted, Elicitation) are honored; others ignored. Absent = use per-event defaults + inference rules. See generation/SKILL.md § Hook Type Validation.",
    "advancedHookTypeExtras": "object (optional) — map<eventName, {agentRef?, httpUrl?, promptRef?, promptInline?}> from wizard Phase 5.1.1 follow-up exchange. Provides the required auxiliary field for prompt/agent/http types. Missing aux for a selected type → validation failure per the skip-reason table.",
    "skillTuning": "object (optional) — { mode: 'defaults' | 'tuned', defaultModel?, defaultEffort?, preApprovalPosture? } from wizard Phase 5.2. Shapes the archetype-inferred skill frontmatter. Absent or mode='defaults' emits archetype defaults only. mode='tuned' refines model/effort/allowed-tools via the three project-level settings. See generation/SKILL.md § Skills § Skill Frontmatter Emission.",
    "agentTuning": "object (optional) — { mode: 'defaults' | 'tuned', defaultModel?, defaultEffort?, preApprovalPosture?, defaultIsolation? } from wizard Phase 5.3. Shapes the archetype-inferred agent frontmatter. Absent or mode='defaults' emits archetype defaults only. mode='tuned' refines model/effort/disallowedTools/permissionMode/isolation via the four project-level settings. See generation/SKILL.md § Agents § Agent Frontmatter Emission."
  },

  "modelChoice": "string — sonnet | opus | haiku",

  "ecosystemPlugins": {
    "notify": "boolean"
  },

  "enriched": {
    "enableCICD": "boolean — generate CI/CD pipelines if project has no existing CI",
    "enableHarness": "boolean — generate harness artifacts (progress.md, HARNESS-GUIDE.md)",
    "enableEvolution": "boolean — add auto-evolution hooks for drift detection",
    "enableSprintContracts": "boolean — generate sprint contract infrastructure",
    "enableTeams": "boolean — add agent team support (quality hooks, env var)",
    "enableVerification": "boolean — set up feature-evaluator agent access",
    "willDeploy": "boolean — whether the project will be deployed (gates CI/CD)",
    "ciAuditAction": "string — auto-fix-pr | comment-only | create-issue",
    "prReviewTrigger": "string — auto | on-demand | auto-with-skip",
    "autoEvolutionMode": "string — auto-update | manual | notify-only",
    "verificationStrategy": "string — browser-automation | api-testing | cli-execution | test-runner | combination",
    "deployTarget": "string — vercel | aws | docker | railway | etc."
  },

  "callerExtras": {
    "description": "object — opaque extra context from the caller, passed through to metadata",
    "installedPlugins": ["string — plugin names installed by the caller"],
    "coveredCapabilities": ["string — capabilities covered by installed plugins"],
    "allowPluginReferences": "boolean (optional) — permit rules/skills to reference installed plugins instead of duplicating their guidance. Defaults to true when installedPlugins is non-empty.",
    "allowHttpHooks": "boolean (optional) — OFF by default. When false, any qualityGates entry with hookType='http' is refused at generation time (skip reason 'http-not-opted-in'). When true, http entries are allowed provided they supply a valid httpUrl. Never auto-inferred — callers opt in explicitly.",
    "disableMCP": "boolean (optional) — when true, skip Phase 7a MCP emission entirely (no .mcp.json, no .claude/onboard-mcp-snapshot.json). Use when the scaffold template already ships its own MCP config. Defaults to false.",
    "disableSkillTuning": "boolean (optional) — when true, suppress the per-skill batched confirmation step during generation. Archetype + wizard defaults are emitted directly. Use for fully non-interactive headless flows. Defaults to false.",
    "disableAgentTuning": "boolean (optional) — when true, suppress the per-agent batched confirmation step during generation. Archetype + wizard defaults are emitted directly. Use for fully non-interactive headless flows. Defaults to false.",
    "qualityGates": {
      "description": "object (optional) — boundary-enforcement hook spec. Onboard translates these into .claude/settings.json hook entries. See generation/SKILL.md § Quality-Gate Hooks for the full schema.",
      "_perEntryTypeFields_": "EVERY entry in sessionStart/preCommit/featureStart/postFeature/sessionEnd/userPromptSubmit/preCompact/subagentStart/taskCreated/taskCompleted/fileChanged/configChange/elicitation accepts these 7 OPTIONAL fields for type selection (documented once here, honored uniformly): { hookType: 'command'|'prompt'|'agent'|'http' (default per generation/SKILL.md § Per-event defaults), promptRef: path to .claude/hooks/*.prompt.md, promptInline: inline prompt text (exactly one of promptRef/promptInline required when hookType='prompt'), agentRef: agent name required when hookType='agent', httpUrl: https-only URL required when hookType='http', httpHeaders: {k:v} optional http headers supporting ${VAR} expansion, timeout: positive int ms override (defaults: command 5000, prompt 15000, agent 60000, http 5000) }. See generation/SKILL.md § Hook Type Validation for the full rule set and skip reasons.",
      "sessionStart": [
        {
          "type": "reminder",
          "message": "string — ≤ 1 line; concatenated + truncated to 3 lines total across all entries",
          "condition": "string (optional) — e.g., 'superpowers-installed'; entry is dropped if condition fails"
        }
      ],
      "preCommit": [
        {
          "skill": "string — e.g., 'code-review:code-review'",
          "triggerOn": "string — 'commit'",
          "mode": "string — 'blocking' (exit 2, default) or 'advisory' (exit 0)"
        }
      ],
      "featureStart": [
        {
          "type": "reminder",
          "criticalDirs": ["string — directory path prefix, e.g., 'domain/parser/'"],
          "message": "string — reminder text, {dir} is substituted"
        }
      ],
      "postFeature": [
        {
          "skill": "string — e.g., 'claude-md-management:revise-claude-md'",
          "triggerOn": "string — 'session-end'",
          "mode": "string — 'advisory' (default for postFeature)"
        }
      ],
      "sessionEnd": [
        {
          "type": "reminder",
          "message": "string (optional) — surfaced to stderr at session end; omit for the default safe no-op stub"
        }
      ],
      "userPromptSubmit": [
        {
          "type": "reminder",
          "condition": "string (optional) — e.g., 'security-high' or 'hookify-installed'; entry dropped if condition fails"
        }
      ],
      "preCompact": [
        {
          "matcher": "string — 'manual' | 'auto' (default: 'auto')",
          "mode": "string — 'advisory' (default, only value currently supported)"
        }
      ],
      "subagentStart": [
        {
          "type": "audit",
          "condition": "string (optional) — e.g., 'teams-enabled'"
        }
      ],
      "taskCreated": [
        {
          "mode": "string — 'advisory' (default) or 'blocking'",
          "minSubjectLength": "number (optional) — default 10"
        }
      ],
      "taskCompleted": [
        {
          "mode": "string — 'advisory' (default) or 'blocking'",
          "testCommand": "string (optional) — shell command; falls through to advisory if unset"
        }
      ],
      "fileChanged": [
        {
          "matcher": "string — filename glob (e.g., 'package-lock.json|Cargo.lock')",
          "message": "string (optional) — stderr notice; default uses generic advisory"
        }
      ],
      "configChange": [
        {
          "matcher": "string — 'user_settings' | 'project_settings' | 'local_settings' | 'policy_settings' | 'skills' (default: 'project_settings')"
        }
      ],
      "elicitation": [
        {
          "matcher": "string (optional) — MCP server name; omit for all servers"
        }
      ]
    },
    "phaseSkills": {
      "description": "object (optional) — per-phase recommended skills for multi-phase builds. Onboard uses this to compose Plugin Integration CLAUDE.md narrative and subdirectory skill annotations.",
      "research": ["string — skill identifiers, e.g., 'superpowers:brainstorming'"],
      "planning": ["string"],
      "feature": ["string"],
      "review": ["string"],
      "commit": ["string"],
      "post-phase": ["string"]
    }
  }
}
```

**`qualityGates` semantics** (in brief — full spec in `generation/SKILL.md`):

- `mode: "blocking"` → generated hook script exits 2 with stderr feedback. Claude cannot proceed without addressing the block. Default for `preCommit`.
- `mode: "advisory"` → generated hook script exits 0 with stdout. Claude sees the message and continues. Default for everything else.
- **autonomyLevel downgrade**: callers are expected to downgrade `preCommit[].mode` to `"advisory"` when `wizardAnswers.autonomyLevel === "always-ask"`. Onboard honors whatever mode it receives — it does not second-guess the caller's autonomy derivation.
- **Plugin availability**: onboard checks that each referenced skill's plugin is in `installedPlugins` before writing a hook entry. Missing → entry is dropped + warning recorded in `onboard-meta.json`.
- **Advanced event fields** (`sessionEnd`, `userPromptSubmit`, `preCompact`, `subagentStart`, `taskCreated`, `taskCompleted`, `fileChanged`, `configChange`, `elicitation`) are all optional. Each accepts either an explicit array or is inferred from wizard answers and analyzer signals — see `generation/SKILL.md` § Advanced Event Hooks for the per-event inference rules. Matcher-incompatible events (see `references/hooks-guide.md` § Matcher Compatibility) must have no `matcher` field in the generated settings entry regardless of what the caller passes.
- **Hook type selection** (per-entry `hookType` + aux fields — see `_perEntryTypeFields_` above) is optional on every entry. Absent → per-event default applies (see `generation/SKILL.md` § Advanced Event Hooks § Per-event defaults). The 10 validation rules in `generation/SKILL.md` § Hook Type Validation drop invalid entries with a structured `skipped` reason — they never fail the whole generation.
- **HTTP opt-in**: `callerExtras.allowHttpHooks` must be `true` for any `hookType: "http"` entry to be emitted. Omitting it (or setting `false`) causes http entries to be skipped with reason `http-not-opted-in`. Non-https URLs are always refused with reason `insecure-http-url`.

**Backward compat**: `callerExtras.qualityGates`, `phaseSkills`, `allowPluginReferences`, and `allowHttpHooks` are all optional. Callers that omit them get the pre-upgrade behavior (no quality-gate hooks, no Plugin Integration section, no plugin cross-references in rules, no http hooks). Callers that pass the legacy 4-field `qualityGates` shape (only `sessionStart` / `preCommit` / `featureStart` / `postFeature`) also get pre-upgrade behavior for the advanced event fields — they fall through to the inference rules in `generation/SKILL.md`. Callers that omit the new per-entry `hookType`/aux fields get `command`-type output identical to pre-upgrade behavior (every current fixture remains byte-identical).

### Validation

Verify the context has:
1. `source` — must be a non-empty string
2. `projectPath` — must be an absolute path that exists
3. `analysis.stack` — must have at least one language
4. `wizardAnswers.autonomyLevel` — must be one of: always-ask, balanced, autonomous
5. `wizardAnswers.projectDescription` — must be non-empty

If any required field is missing, report the error clearly:

> Headless generation failed: missing required field `[field name]`.
> The calling plugin must provide a complete context object.

Stop and do not proceed.

**Per-entry hook-type validation** — applied during generation, not at this step. Each `callerExtras.qualityGates.<event>[]` entry passes through the 10-rule validator in `generation/SKILL.md` § Hook Type Validation. Validation failures drop the offending entry and record a `skipped[]` entry with a structured reason; they never fail the overall generation. The complete skip-reason table (for authoritative reference):

| Skip reason | Condition |
|---|---|
| `missing-prompt-source` | `hookType="prompt"` but neither `promptRef` nor `promptInline` supplied |
| `ambiguous-prompt-source` | `hookType="prompt"` with BOTH `promptRef` AND `promptInline` |
| `prompt-file-not-found` | `hookType="prompt"` + `promptRef` points to non-existent file |
| `missing-agentRef` | `hookType="agent"` but `agentRef` is absent or empty |
| `missing-httpUrl` | `hookType="http"` but `httpUrl` is absent or empty |
| `unsupported-type-for-event` | `hookType ∈ {prompt, agent}` on `PreToolUse` or `PostToolUse` event |
| `http-not-opted-in` | `hookType="http"` without `callerExtras.allowHttpHooks === true` |
| `insecure-http-url` | `hookType="http"` with URL that does not start with `https://` |
| `agent-not-found` | `hookType="agent"` + `agentRef` referencing an agent whose plugin is not in `effectivePlugins` |
| `invalid-timeout` | `timeout` field present but not a positive integer |
| `high-frequency-event-unsuitable-for-agent` | `hookType="agent"` on `UserPromptSubmit` (fires on every prompt — agent latency makes it unusable) |

---

## Step 2: Map Context to Onboard Format

The headless context uses the same field names and values as the standard wizard output (see wizard skill's Output section). Map the context directly:

1. **Analysis report**: Construct the same structured report format that the codebase-analyzer agent produces, using the `analysis` object from the context. The config-generator agent expects sections like `## Languages`, `## Frameworks & Libraries`, `## Build System & Commands`, etc.

2. **Wizard answers**: The `wizardAnswers` object already matches the wizard skill's output format. Pass it through directly.

3. **Model choice**: Map `modelChoice` to the model recommendation format.

4. **Ecosystem plugins**: Pass `ecosystemPlugins` through for Phase 3.5 setup.

---

## Step 3: Generate Artifacts

Spawn the `config-generator` agent with the mapped context. Include in the agent prompt:

1. The analysis report (constructed from context in Step 2)
2. The wizard answers JSON (from context)
3. The model choice
4. The project root path
5. The current date for maintenance headers
6. A flag indicating headless mode: `"headlessMode": true, "source": "[source]"`

The config-generator agent follows the `generation` skill as usual. In headless mode, the only behavioral difference is:

- **Merge-aware hooks**: The caller may have already added hooks to `.claude/settings.json`. The generator must read existing settings first and merge, never overwrite. This applies in normal mode too, but is especially critical in headless mode since the caller may have set up its own hooks before invoking generation.

---

## Step 4: Ecosystem Setup

If `ecosystemPlugins` is present in the context, set up the requested plugins following the same process as Phase 3.5 in `/onboard:init`:

- Check plugin availability
- Set up notify (if requested and available)

---

## Step 5: Report Results

After generation completes, compile and return a results summary:

> **Headless generation complete** (source: [source])
>
> Generated artifacts:
> | File | Purpose |
> |---|---|
> | [list each file created] | [brief description] |
>
> Hook status: [N] planned, [M] generated, [K] skipped
>
> Metadata saved to `.claude/onboard-meta.json`

In addition to the human-readable summary, the results object returned to the caller MUST include a `hookStatus` object with the canonical shape documented in `skills/generation/SKILL.md` § Quality-Gate Hooks § Hook Status Telemetry. Callers (notably forge) rely on this field to persist hook wiring data in their own metadata files — do not omit it even when all hooks were generated successfully (in that case, `skipped: []` and `warnings: []`).

**Scope reminder**: `hookStatus` tracks **only** hooks derived from `callerExtras.qualityGates`. Format/lint hooks (Prettier, ESLint, etc.) and onboard-internal hooks (forge-evolution-check, etc.) are deliberately **excluded** from these counts — they still land in `.claude/settings.json` but do not appear in `hookStatus.planned` or `hookStatus.generated`. See SKILL.md § Hook Status Telemetry § Scope boundary for the full rationale.

Example results object shape:

```jsonc
{
  "source": "forge",
  "headlessMode": true,
  "artifactsGenerated": ["CLAUDE.md", ".claude/rules/...", ".claude/hooks/..."],
  "hookStatus": {
    "planned":   { "SessionStart": 1, "PreToolUse:Write": 1, "PreToolUse:Bash": 2, "Stop": 1 },
    "generated": {
      // list-of-script-basenames per event key — richer than a count map
      "SessionStart":     ["plugin-integration-reminder.sh"],
      "PreToolUse:Write": ["feature-start-detector.sh"],
      "PreToolUse:Bash":  ["pre-commit-code-review.sh", "pre-commit-verification-before-completion.sh"],
      "Stop":             ["post-feature-revise-claude-md.sh"]
    },
    "skipped":   [],
    "warnings":  [],
    "downgradeApplied": null  // optional — set to an object when autonomyLevel forced a preCommit mode downgrade
  },
  "skillStatus": {                             // new in onboard 1.5.0 — canonical shape in generation/SKILL.md § Skill Frontmatter Emission
    "planned":    ["react-component", "pr-summarizer"],
    "generated":  ["react-component", "pr-summarizer"],
    "skipped":    [],
    "frontmatterFields": {
      "react-component": {
        "allowed-tools": ["Read", "Grep", "Glob", "Write", "Edit"],
        "effort": "medium",
        "paths": ["src/components/**/*.tsx"],
        "source": "inferred"
      }
    },
    "existedPreOnboard": [],
    "warnings":  []
  }
}
```

The `onboard-meta.json` file records:
- `source`: the calling plugin identifier
- `headlessMode`: true
- `pluginVersion`: onboard version
- `lastRun`: current timestamp
- `wizardAnswers`: from context
- `generatedArtifacts`: list of files created
- `modelRecommendation`: from context
- `callerExtras`: passed through from context
- `hookStatus`: **new** — the same canonical-shape object returned in the results summary. Recording it in both places gives callers two independent provenance sources.
- `skillStatus`: **new in 1.5.0** — same canonical-shape object returned in the results summary. Parallel to `hookStatus` and `mcpStatus`. Drives skill frontmatter drift detection in `onboard:update` and `onboard:evolve`.

---

## Key Rules

1. **No interactive prompts** — This skill never asks the user questions. All context comes from the input.
2. **No analysis scripts** — The codebase-analyzer agent is not spawned. Analysis data comes from the context.
3. **No wizard** — The wizard skill is not invoked. Preferences come from the context.
4. **Merge, never overwrite** — Always read existing files (settings.json, .gitignore) before writing.
5. **Same generation quality** — The artifacts produced must be identical in quality to those from `/onboard:init`. The only difference is where the input data comes from.
6. **Transparent provenance** — The `onboard-meta.json` records that this was a headless generation and which plugin triggered it.
