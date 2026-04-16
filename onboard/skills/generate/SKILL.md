---
name: generate
description: Headless Claude tooling generation for programmatic callers (e.g., the forge plugin). Consumes a pre-seeded context JSON containing analysis, wizard answers, and plugin data; skips interactive phases; returns hookStatus telemetry. Not user-invocable.
user-invocable: false
---

# Generate Skill — Headless Tooling Generation

You are running the onboard headless generation skill. This generates Claude tooling artifacts from pre-seeded context without running the interactive wizard or codebase analysis.

This skill is designed for programmatic consumers (e.g., the Forge plugin) that have already gathered project context through their own workflow and need onboard's generation capabilities directly.

<EXTREMELY-IMPORTANT>
**DISPATCH CONTRACT — READ BEFORE TOUCHING ANYTHING**

This skill's ONLY job is to dispatch the `config-generator` agent with a pre-seeded context. It MUST NOT call the Write or Edit tool from its own execution context, ever.

```
generate skill (this file)              config-generator agent
─────────────────────                   ──────────────────────
1. Read context input                   1. (dispatched by generate)
2. Validate                             2. Run full generation pipeline
3. Map to onboard format                3. Emit ALL artifacts
4. Build agent prompt                   4. Self-audit telemetry
5. DISPATCH AGENT  ───────────────────► 5. Return structured JSON response
6. Parse JSON response, return summary
```

**FORBIDDEN patterns** (every one observed in the 2026-04-16 release-gate forge run):

- `FORBIDDEN`: Writing CLAUDE.md inline via Write tool from this skill's execution context.
- `FORBIDDEN`: Calling Write or Edit tools from this skill at all (any file).
- `FORBIDDEN`: Skipping the agent dispatch and running generation pipeline steps directly.
- `FORBIDDEN`: Treating this skill as a Write-tool wrapper.

**REQUIRED pattern**:

- `REQUIRED`: A single Agent dispatch with `subagent_type: "config-generator"` and the pre-seeded context object (Step 3 below).

If you find yourself reaching for the Write tool while executing this skill, STOP — that is the bug this contract is designed to prevent. The artifacts must be written by the dispatched agent, not by this skill.

**Hard-fail safety net**: The `config-generator` agent itself checks for `dispatchedAsAgent: true` in its context. If a caller bypasses dispatch (somehow invoking the agent's logic from the main session inline), the agent refuses to write anything and reports the violation. This is defense in depth — but it does NOT excuse violations of the contract above.
</EXTREMELY-IMPORTANT>

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
    "agentTuning": "object (optional) — { mode: 'defaults' | 'tuned', defaultModel?, defaultEffort?, preApprovalPosture?, defaultIsolation? } from wizard Phase 5.3. Shapes the archetype-inferred agent frontmatter. Absent or mode='defaults' emits archetype defaults only. mode='tuned' refines model/effort/disallowedTools/permissionMode/isolation via the four project-level settings. See generation/SKILL.md § Agents § Agent Frontmatter Emission.",
    "lspPlugins": "string[] (optional) — developer-accepted list of marketplace LSP plugins from wizard Phase 5.6. Empty array = 'detected but declined all'. Absent = Quick Mode / headless — full detected list is implicit accept. See generation/SKILL.md § LSP Plugin Recommendations — Phase 7c and generation/references/lsp-plugin-catalog.md.",
    "builtInSkills": "string[] (optional) — developer-accepted list of built-in Claude Code skill names from wizard Phase 5.7. Empty array = 'candidates existed but declined all'. Absent = Quick Mode / headless — full candidate list (core + fired extras) is implicit accept. See generation/SKILL.md § Built-in Claude Code Skills — Phase 7d and generation/references/built-in-skills-catalog.md."
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
    "disableMCP": "boolean (optional, SKIP-PHASE family) — when true, skip Phase 7a MCP emission entirely (no .mcp.json, no .claude/onboard-mcp-snapshot.json). Use when the scaffold template already ships its own MCP config. Defaults to false. MUST still emit telemetry: mcpStatus = { status: 'skipped', reason: 'caller-disabled' }.",
    "disableSkillTuning": "boolean (optional, SUPPRESS-PROMPT-ONLY family) — when true, suppress the per-skill batched confirmation step during generation. Archetype + wizard defaults are emitted directly (artifacts ARE generated). Use for fully non-interactive headless flows. Defaults to false. Phase ALWAYS emits: skill files + snapshot + telemetry status: 'emitted'.",
    "disableAgentTuning": "boolean (optional, SUPPRESS-PROMPT-ONLY family) — when true, suppress the per-agent batched confirmation step during generation. Archetype + wizard defaults are emitted directly (artifacts ARE generated). Use for fully non-interactive headless flows. Defaults to false. Phase ALWAYS emits: agent files + snapshot + telemetry status: 'emitted'.",
    "disableOutputStyleTuning": "boolean (optional, SUPPRESS-PROMPT-ONLY family) — when true, suppress the Phase 7b batched confirmation for output-style emission. The top-priority archetype is inferred from existing signals and the matching .claude/output-styles/<name>.md is emitted with catalog defaults. Use for fully non-interactive headless flows (e.g., forge scaffolding). Defaults to false. Phase ALWAYS emits: style file + snapshot + telemetry status: 'emitted'.",
    "disableLSP": "boolean (optional, SKIP-PHASE family) — when true, skip Phase 7c LSP plugin emission entirely (no detect-lsp-signals.sh run, no install-plugins.sh invocation, no .claude/onboard-lsp-snapshot.json). Use for scaffolded projects whose source files are still placeholders. Defaults to false. Forge passes true by default; users can rerun /onboard:evolve to prompt once real code exists. MUST still emit telemetry: lspStatus = { status: 'skipped', reason: 'caller-disabled' }.",
    "lspPlugins": "string[] (optional) — explicit list of marketplace LSP plugin names to install during Phase 7c. When present, skips the wizard prompt and treats the array as the accepted list verbatim. Pass an empty array to record 'detected but declined all'. When absent (and disableLSP is not true), wizard Phase 5.6 runs in interactive mode or defaults to the full detected list in Quick Mode / headless.",
    "disableBuiltInSkills": "boolean (optional, SKIP-PHASE family) — when true, skip Phase 7d built-in skills emission entirely (no CLAUDE.md subsection, no .claude/onboard-builtin-skills-snapshot.json). Use for scaffolded projects whose source files are still placeholders — detection signals are premature. Defaults to false. Forge passes true by default; users can rerun /onboard:evolve to prompt once real code exists. MUST still emit telemetry: builtInSkillsStatus = { status: 'skipped', reason: 'caller-disabled' }.",
    "builtInSkills": "string[] (optional) — explicit list of built-in Claude Code skill names to document in the generated CLAUDE.md during Phase 7d. When present, skips wizard Phase 5.7 and treats the array as the accepted list verbatim. Pass an empty array to record 'candidates existed but declined all'. When absent (and disableBuiltInSkills is not true), wizard Phase 5.7 runs in interactive mode or defaults to the full candidate list (core + fired extras) in Quick Mode / headless. See generation/references/built-in-skills-catalog.md for valid skill names.",
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

### Default behavior matrix — Phase 7 disable flags

There are **two distinct families** of `callerExtras` disable flags. They MUST NOT be conflated in implementation. Treating them identically is the bug that caused MCP, output-style, LSP, built-in skills, and snapshots to disappear from headless forge runs in the 2026-04-16 release-gate test.

| Flag | Family | Effect when `true` | Telemetry written | Artifacts written |
|---|---|---|---|---|
| `disableMCP` | **SKIP-PHASE** | Skip Phase 7a entirely | `mcpStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [], skipped: [...] }` | None |
| `disableLSP` | **SKIP-PHASE** | Skip Phase 7c entirely | `lspStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [], skipped: [...] }` | None |
| `disableBuiltInSkills` | **SKIP-PHASE** | Skip Phase 7d entirely | `builtInSkillsStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [], skipped: [...] }` | None |
| `disableSkillTuning` | **SUPPRESS-PROMPT** | Skip per-skill batched confirmation only | `skillStatus: { status: "emitted", source: "inferred", ... }` | Skill files + `onboard-skill-snapshot.json` |
| `disableAgentTuning` | **SUPPRESS-PROMPT** | Skip per-agent batched confirmation only | `agentStatus: { status: "emitted", source: "inferred", ... }` | Agent files (with YAML frontmatter) + `onboard-agent-snapshot.json` |
| `disableOutputStyleTuning` | **SUPPRESS-PROMPT** | Skip Phase 7b batched confirmation only | `outputStyleStatus: { status: "emitted", source: "inferred", ... }` | Output style file + `onboard-output-style-snapshot.json` |

**Telemetry status enum** (used in every Phase 7 status object):

| Value | Meaning |
|---|---|
| `"emitted"` | Phase ran, artifacts written, snapshot recorded. |
| `"skipped"` | Phase intentionally skipped (caller flag, no signal, no candidates). Telemetry still recorded so verify scripts can distinguish "intentional skip" from "silent bug". |
| `"declined"` | User explicitly declined in interactive flow (wizard answered "no" / empty array). |
| `"failed"` | Phase attempted but failed (e.g., script crash, write error). Triggers warning in `warnings[]` but never aborts the run. |

**Hard rule** (load-bearing): EVERY Phase 7 block MUST emit its telemetry status key in `onboard-meta.json`, even when status is `"skipped"`. Missing keys are bugs, not absences. The `config-generator` agent's pre-exit self-audit verifies all four keys (`mcpStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`) exist before returning. See `generation/SKILL.md` Phase 7 blocks for the per-phase Path A/B/C firing logic that ensures this invariant holds whether wizard answers are present, absent, or the SUPPRESS-PROMPT-ONLY flags are set.

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

## Step 3: Generate Artifacts (DISPATCH config-generator)

This is the ONLY action in this skill that produces artifacts. Use the Agent tool:

```
Agent({
  subagent_type: "config-generator",
  description: "Generate onboard artifacts from headless context",
  prompt: <prompt described below>
})
```

Include in the agent prompt:

1. The analysis report (constructed from context in Step 2)
2. The wizard answers JSON (from context)
3. The model choice
4. The project root path
5. The current date for maintenance headers
6. A flag indicating headless mode: `"headlessMode": true, "source": "[source]"`
7. A flag indicating the agent was dispatched (not running inline): `"dispatchedAsAgent": true`

**Do NOT** read the agent's instructions and execute them inline from this skill — that defeats the dispatch contract above. Use the Agent tool exactly once and let the agent run in its own context.

The config-generator agent follows the `generation` skill as usual. In headless mode, the behavioral differences are:

- **Merge-aware hooks**: The caller may have already added hooks to `.claude/settings.json`. The generator must read existing settings first and merge, never overwrite. This applies in normal mode too, but is especially critical in headless mode since the caller may have set up its own hooks before invoking generation.
- **Phase 7 SKIP-PHASE telemetry**: When `callerExtras.disableMCP` / `disableLSP` / `disableBuiltInSkills` is true, the corresponding Phase 7 block STILL writes its telemetry key to `onboard-meta.json` with `status: "skipped"` and `reason: "caller-disabled"`. The artifacts are not written, but verify scripts can distinguish "intentional skip" from "silent bug." See § Default behavior matrix above.
- **Phase 7 SUPPRESS-PROMPT-ONLY behavior**: When `callerExtras.disableSkillTuning` / `disableAgentTuning` / `disableOutputStyleTuning` is true, generation skips the batched user confirmation but **still emits artifacts + snapshots + telemetry with `status: "emitted"`**. These flags exist to make headless flows non-interactive, NOT to suppress generation.
- **Pre-exit self-audit**: The agent verifies all 4 Phase 7 telemetry keys exist in `onboard-meta.json` before returning. Missing key = hard-fail.

---

## Step 4: Ecosystem Setup

If `ecosystemPlugins` is present in the context, set up the requested plugins following the same process as Phase 3.5 in `/onboard:init`:

- Check plugin availability
- Set up notify (if requested and available)

---

## Step 5: Report Results (parse agent's structured JSON response)

The dispatched config-generator agent returns a structured JSON response. **Do not improvise** — this is a contract the calling skill (e.g., forge) parses to know what landed.

### Required JSON response shape

```jsonc
{
  "filesWritten": [
    { "path": "CLAUDE.md", "bytes": 4231 },
    { "path": ".claude/settings.json", "bytes": 1842 },
    { "path": ".mcp.json", "bytes": 612 }
    // ... one entry per file written
  ],
  "telemetry": {
    "hookStatus":          { "status": "emitted",  /* canonical shape per generation/SKILL.md */ },
    "skillStatus":         { "status": "emitted",  /* ... */ },
    "agentStatus":         { "status": "emitted",  /* ... */ },
    "mcpStatus":           { "status": "emitted",  /* ... */ },
    "outputStyleStatus":   { "status": "emitted",  /* ... */ },
    "lspStatus":           { "status": "skipped", "reason": "caller-disabled" },
    "builtInSkillsStatus": { "status": "emitted",  /* ... */ }
  },
  "auditPassed": true,    // result of pre-exit self-audit (config-generator step 9)
  "warnings": []
}
```

**Validation by this skill** (after agent returns):

1. `auditPassed === true` — if false, surface a hard error to the caller.
2. All 7 telemetry keys present with valid `status` enum values (`emitted | skipped | declined | failed`).
3. `filesWritten` non-empty (at minimum CLAUDE.md and onboard-meta.json should be present).

If validation fails, do NOT pretend success. Report the missing/invalid fields to the caller.

### Human-readable summary (rendered to user)

After validation passes, compile and return:

> **Headless generation complete** (source: [source])
>
> Generated artifacts:
> | File | Purpose |
> |---|---|
> | [list each file from filesWritten] | [brief description] |
>
> Telemetry: hookStatus=[status], skillStatus=[status], agentStatus=[status], mcpStatus=[status], outputStyleStatus=[status], lspStatus=[status], builtInSkillsStatus=[status]
>
> Metadata saved to `.claude/onboard-meta.json`

The full structured JSON response is what callers (notably forge) consume to mirror status into their own metadata files — pass it through verbatim alongside the human-readable summary.

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
- `pluginVersion`: onboard version — **MUST be read at runtime** from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` (this skill lives inside onboard, so `${CLAUDE_PLUGIN_ROOT}` resolves to onboard's plugin root). Never hardcode a literal version string. Callers must NOT supply `pluginVersion` in `callerExtras` — config-generator authoritatively reads it from disk so onboard upgrades automatically reflect in the meta file. The 2026-04-16 release-gate Phase 5 test (finding FO6) hit a stale literal `1.2.0` baked into the headless context even though onboard was at 1.9.0.
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
