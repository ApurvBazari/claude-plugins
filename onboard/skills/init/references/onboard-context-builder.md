# Onboard Context Builder — Init-Path Reference

Canonical procedure for building the headless-generation context object from `/onboard:init` wizard answers + analysis + plugin detection. Produces the same shape forge emits via `forge-onboard-context.json`, so init and forge share **one** dispatch contract into `Skill(onboard:generate) → config-generator` agent.

## Why this reference exists

The 2026-04-17 release-gate sweep found 7 blocker-class bugs (B1, B5, B6, B8, B10, B12, B13) clustered in init's context construction. Phase 5 (forge) ran the same generator and produced zero bugs — proving the generator is correct when given a properly-formed context.

**Root cause**: init was assembling a *subset* of the expected `callerExtras` structure and passing it via an ad-hoc prompt to the `config-generator` agent. Fields the generator expected but didn't receive fell into "absent-field" skip branches (MCP skipped, snapshot coupling broken, plugin detection shallow, LSP silently dropped, CLAUDE.md sections missing).

**Fix**: all init preset paths (Custom / Standard / Minimal) call the procedure below to emit the full shape. Stub mode (Phase 0, empty-repo) emits a canonical-shape variant per `../references/empty-repo-stub-procedure.md`. Dispatch goes through `Skill(onboard:generate)` — the same path forge uses — so validation + agent dispatch live in one place.

## When to invoke this procedure

Called from `init/SKILL.md` Phase 2.6, after Phase 1 Analysis, Phase 2 Wizard, and Phase 2.5 Plugin Detection have completed. Returns the fully-populated context object. Init then passes the object to `Skill(onboard:generate)` in Phase 3.

## Inputs

From prior phases (already in conversation context):

| Source | Field | Used for |
|---|---|---|
| Phase 1 Analysis report | `analysis` object (stack, complexity, configs, structure) | `context.analysis` |
| Phase 2 Wizard | `wizardAnswers` (preset-branched shape — see `wizard/SKILL.md`) | `context.wizardAnswers` |
| Phase 2 Wizard | `wizardStatus` (canonical 5-subkey telemetry) | Mirrored into `onboard-meta.json` post-generation |
| Phase 2.5 Plugin Detection | `installedPlugins[]`, `coveredCapabilities[]`, `pluginSurfaces{}` | `context.callerExtras.*` |
| Resolved at runtime | `projectPath` (absolute) | `context.projectPath` |
| Resolved at runtime | `modelChoice` (per init SKILL.md § 3.1) | `context.modelChoice` |

## Output schema — context object passed to `Skill(onboard:generate)`

Matches `generate/SKILL.md` Step 1 § Required Context Structure. All fields populated; no `undefined` / absent top-level keys.

```jsonc
{
  "source": "onboard:init",
  "version": "1.10.0",               // init-path context-format version; tracks the init refactor, not onboard's plugin version
  "projectPath": "/abs/path/to/project",

  "analysis": { /* Phase 1 report — same shape config-generator expects */ },

  "wizardAnswers": { /* Phase 2 canonical shape; see wizard/SKILL.md § Canonical Output */ },

  "modelChoice": "claude-opus-4-7[1m]",  // resolved per init SKILL.md § 3.1

  "ecosystemPlugins": { "notify": true },  // or false; comes from wizardAnswers.ecosystemPlugins

  "enriched": {
    "enableCICD":           <boolean>,  // derived: wizardAnswers.willDeploy && wizardAnswers.ciPreference !== "none"
    "enableHarness":        false,      // init-path default; forge sets true for scaffolded projects
    "enableEvolution":      true,       // default on; overridden only when wizardAnswers.evolutionPref === "none"
    "enableSprintContracts": false,     // init-path default; forge-specific enriched artifact
    "enableTeams":          <boolean>,  // derived: wizardAnswers.teamSize !== "solo" && wizardAnswers.isProduction === true
    "enableVerification":   true,       // default on
    "willDeploy":           <boolean>,  // from wizardAnswers
    "ciAuditAction":        "auto-fix-pr | comment-only | create-issue",  // from wizardAnswers.ciAuditAction, default "comment-only"
    "prReviewTrigger":      "auto | on-demand | auto-with-skip",          // from wizardAnswers, default "on-demand"
    "autoEvolutionMode":    "auto-update | manual | notify-only",          // from wizardAnswers, default "manual"
    "verificationStrategy": "browser-automation | api-testing | cli-execution | test-runner | combination",  // default "combination"
    "deployTarget":         "vercel | aws | docker | railway | other | none"  // from wizardAnswers
  },

  "callerExtras": {
    "installedPlugins":    [ /* from Phase 2.5 deep probe */ ],
    "coveredCapabilities": [ /* derived from installedPlugins per plugin-detection-guide.md */ ],
    "pluginSurfaces":      { /* from Phase 2.5 surface probe — see plugin-surface-probe.md */ },
    "allowPluginReferences": true,       // default true when installedPlugins is non-empty
    "allowHttpHooks":        false,      // opt-in only; init never auto-enables http hooks

    // Phase 7 family — SKIP-PHASE flags (init default: never skip)
    "disableMCP":            false,      // init ALWAYS runs Phase 7a — this is the B1 fix
    "disableLSP":            false,      // init runs Phase 7c when LSP candidates exist
    "disableBuiltInSkills":  false,      // init runs Phase 7d; output is status:"documented" (see C1.6)

    // Phase 7 family — SUPPRESS-PROMPT flags (init default: never suppress interactive confirmation)
    "disableSkillTuning":    false,      // init keeps Phase 7 batched confirmation ON (interactive mode)
    "disableAgentTuning":    false,      // same
    "disableOutputStyleTuning": false,   // same

    // Phase 7c + 7d explicit selections (from wizard)
    "lspPlugins":            [ /* wizardAnswers.lspPlugins — empty array means "declined all" */ ],
    "builtInSkills":         [ /* wizardAnswers.builtInSkills — empty array means "declined all" */ ],

    // Boundary-enforcement hooks
    "qualityGates": { /* derived per plugin-detection-guide.md § qualityGates Derivation */ },

    // Per-phase routing
    "phaseSkills":  { /* derived per plugin-detection-guide.md § phaseSkills Derivation */ }
  }
}
```

## Construction rules — step by step

### Step 1: Populate top-level identity fields

- `source` → literal `"onboard:init"`
- `version` → literal `"1.10.0"` (the init-path context-format version; bump in sync with init refactor releases, NOT with every onboard patch)
- `projectPath` → resolved via `pwd` (init runs in the project root)

### Step 2: Carry forward analysis + wizard outputs

- `analysis` → pass through the full Phase 1 report object
- `wizardAnswers` → pass through the Phase 2 canonical object (post-wizard finalize)
- `ecosystemPlugins` → copy from `wizardAnswers.ecosystemPlugins`

### Step 3: Resolve the model choice

Use the resolution order in `init/SKILL.md § 3.1`:

```
modelChoice = wizardAnswers.skillTuning?.defaultModel
            ?? wizardAnswers.model
            ?? presetDefaultModel(wizardAnswers.selectedPreset)
            ?? "claude-opus-4-7[1m]"
```

### Step 4: Derive the `enriched` flags

| Flag | Derivation | Init-path default |
|---|---|---|
| `enableCICD` | `wizardAnswers.willDeploy && wizardAnswers.ciPreference !== "none"` | varies |
| `enableHarness` | — | **false** (harness is forge-specific; not emitted in init) |
| `enableEvolution` | — | **true** (always on; adds drift-detection hooks) |
| `enableSprintContracts` | — | **false** (forge-specific) |
| `enableTeams` | `wizardAnswers.teamSize !== "solo" && wizardAnswers.isProduction` | varies |
| `enableVerification` | — | **true** (always on) |
| `willDeploy` | `wizardAnswers.willDeploy` | varies |
| `ciAuditAction` | `wizardAnswers.ciAuditAction ?? "comment-only"` | `"comment-only"` |
| `prReviewTrigger` | `wizardAnswers.prReviewTrigger ?? "on-demand"` | `"on-demand"` |
| `autoEvolutionMode` | `wizardAnswers.autoEvolutionMode ?? "manual"` | `"manual"` |
| `verificationStrategy` | `wizardAnswers.verificationStrategy ?? "combination"` | `"combination"` |
| `deployTarget` | `wizardAnswers.deployTarget ?? "none"` | `"none"` |

### Step 5: Build `callerExtras` — the load-bearing section

#### Plugin detection outputs

- `installedPlugins` → from Phase 2.5 deep probe (sibling + marketplace cache per `../generation/references/plugin-detection-guide.md`)
- `coveredCapabilities` → derived from `installedPlugins` per `../generation/references/plugin-detection-guide.md § coveredCapabilities Derivation`
- `pluginSurfaces` → from Phase 2.5 surface probe per `../generation/references/plugin-surface-probe.md`

If all three probes yielded zero plugins: `installedPlugins: []`, `coveredCapabilities: []`, `pluginSurfaces: {}`, `allowPluginReferences: false`. This is a valid state — subsequent Phase 7 blocks still fire and still emit their telemetry.

#### Opt-in fields

- `allowPluginReferences` → `true` when `installedPlugins.length > 0`, else `false`
- `allowHttpHooks` → `false` always in init-path; hook emission refuses http-type entries. Users who want http hooks must opt in via an advanced wizard answer (not yet exposed in any preset).

#### Phase 7 SKIP-PHASE flags — init-path defaults

**Critical for closing B1**: init passes these flags **explicitly as false**. Omitting the field would default to false at the generator, but passing explicitly makes the contract auditable.

- `disableMCP` → **`false`** (always). Phase 7a's signal-driven path fires; `.mcp.json` emitted when `detect-mcp-signals.sh` returns ≥ 1 candidate. Pre-fix bug: init's absent callerExtras meant the generator never ran Phase 7a → `reason: "no-candidates"` despite signals being present.
- `disableLSP` → **`false`**. Phase 7c runs if `lspPlugins` array from wizardAnswers is non-empty OR Quick Mode fallback enumerates candidates.
- `disableBuiltInSkills` → **`false`**. Phase 7d runs; output is `builtInSkillsStatus.status: "documented"` (CLAUDE.md subsection, no separate snapshot file — see C1.6).

#### Phase 7 SUPPRESS-PROMPT flags — init-path defaults

Init is interactive by definition; never suppress confirmation prompts.

- `disableSkillTuning` → **`false`** (Phase 7 skill batched confirmation runs)
- `disableAgentTuning` → **`false`** (Phase 7 agent batched confirmation runs)
- `disableOutputStyleTuning` → **`false`** (Phase 7b batched confirmation runs)

#### Explicit selection arrays

- `lspPlugins` → `wizardAnswers.lspPlugins` (empty array = "detected but declined"; absent = "no detection")
- `builtInSkills` → `wizardAnswers.builtInSkills` (same semantics)

#### Quality gates + phase skills

Derive per `../generation/references/plugin-detection-guide.md § qualityGates Derivation` + `§ phaseSkills Derivation`. Honor autonomyLevel downgrade for `preCommit[].mode`:

| `wizardAnswers.autonomyLevel` | Downgrade |
|---|---|
| `"always-ask"` (exploratory) | ALL `preCommit[].mode` → `"advisory"` |
| `"balanced"` | keep seeded (`"blocking"`) |
| `"autonomous"` | keep seeded (`"blocking"`) |

Filter out any entry whose plugin is not in `installedPlugins` — don't fabricate refs.

### Step 6: Validate before dispatch

Verify before invoking `Skill(onboard:generate)`:

1. `source` non-empty — always `"onboard:init"` from Step 1
2. `projectPath` absolute + exists on disk
3. `analysis.stack.languages` has at least one entry (empty repo case is handled by Phase 0 stub procedure, not this builder)
4. `wizardAnswers.autonomyLevel` ∈ `{always-ask, balanced, autonomous}`
5. `wizardAnswers.projectDescription` non-empty
6. `callerExtras.installedPlugins` is an array (possibly empty, never undefined)
7. `callerExtras.pluginSurfaces` is an object (possibly empty `{}`)

If any check fails, report to the user:

> Init-path context-builder validation failed: `<field>` is missing or invalid.
> This is a bug — please report with the wizard transcript.

Do NOT proceed to dispatch with invalid context.

## Dispatch contract

After Step 6 passes, init's Phase 3 invokes `Skill(onboard:generate)` with the context object as the single argument. The generate skill validates again (same contract as forge), then dispatches `Agent(config-generator)` with `dispatchedAsAgent: true`.

```
init Phase 3
  │
  ▼
Skill(onboard:generate)
  │ (validates callerExtras; builds agent prompt)
  ▼
Agent(config-generator)
  │ (runs full generation pipeline including Phase 7a/b/c/d)
  │ (writes artifacts + snapshots + onboard-meta.json)
  │ (runs pre-exit self-audit for all 7 Phase 7 status keys)
  ▼
Structured JSON response back through the Skill chain
  │
  ▼
init Phase 3.3: Report Generation Results (list files written)
```

**Do not** pass `dispatchedAsAgent: true` from init — that flag is the generate skill's responsibility. Init's only job is building the context and invoking the Skill tool.

## Default values table — for Quick Mode / preset fallbacks

When a wizard preset omits a field, the builder fills in these defaults. The objective is **never** to pass `undefined` to the generator:

| Field | Default |
|---|---|
| `wizardAnswers.teamSize` | `"solo"` |
| `wizardAnswers.testingPhilosophy` | `"tdd"` (hard-wired per generate/SKILL.md contract) |
| `wizardAnswers.codeStyleStrictness` | `"moderate"` |
| `wizardAnswers.securitySensitivity` | `"standard"` |
| `wizardAnswers.projectMaturity` | `"new"` if analysis has < 50 files, else `"early"` |
| `wizardAnswers.autonomyLevel` | `"balanced"` |
| `wizardAnswers.willDeploy` | `true` |
| `wizardAnswers.painPoints` | `{ timeSinks: "", errorProne: "", automationWishes: "" }` |
| `wizardAnswers.lspPlugins` | full detected list from `detect-lsp-signals.sh` |
| `wizardAnswers.builtInSkills` | `["/loop", "/simplify", "/debug", "/pr-summary"]` + detected extras |
| `wizardAnswers.skillTuning` | `{ mode: "defaults" }` |
| `wizardAnswers.agentTuning` | `{ mode: "defaults" }` |
| `wizardAnswers.outputStyleTuning` | `{ mode: "defaults" }` |

Every default is populated explicitly — downstream generation should never need to guess.

## Edge cases

1. **Empty wizard (Quick Mode bail-out)** — wizard ran only Phase 1-1.4, no detailed answers. Builder fills in all defaults from the table above. `wizardStatus.presetUsed = "quick-mode"`. Still produces a valid context.

2. **No plugins detected at all** — `installedPlugins: []`, `coveredCapabilities: []`, `pluginSurfaces: {}`, `allowPluginReferences: false`. `qualityGates.*` entries drop all plugin-referencing items → likely empty arrays. Generator's Phase 5 Plugin Integration block emits "No plugins detected" narrative.

3. **Plugin installed but hooks-only** (e.g., `security-guidance`) — `pluginSurfaces.security-guidance.type: "hooks-only"`. claude-md-guide's Plugin Integration template emits hook narrative, not a fabricated slash ref (see `../generation/references/plugin-surface-probe.md` + `claude-md-guide.md`). Closes G.3.

4. **wizardAnswers includes `skillTuning.mode: "tuned"`** — builder passes the tuning object through; config-generator composes archetype defaults with the tuning overrides. `disableSkillTuning` stays `false` regardless of `mode` value.

5. **`lspPlugins: []` (detected but all declined)** — valid state. `disableLSP: false` still. Generator's Phase 7c emits `lspStatus.status: "declined"` with empty `planned[]` / `generated[]`.

6. **User-edit preservation on re-run** — if `.claude/onboard-meta.json` already exists from a prior run, the builder still runs fresh. Generator handles merge semantics. Do NOT read prior onboard-meta to pre-populate context fields — source of truth is this run's wizard + analysis.

7. **Plugin cache directory permissions prevent probe** — one of the two probes fails silently per `plugin-detection-guide.md § CLAUDE_PLUGIN_ROOT Fallback`. Builder treats the failed probe as "no matches." Continues. Records the failure in a `probeContext` field for telemetry.

## Key rules

1. **Single source of truth**: every init preset (Custom / Standard / Minimal) calls THIS procedure. Do not maintain preset-specific context builders — that's the drift that caused the original bugs.
2. **Populate all top-level keys** — never leave `callerExtras.disableMCP` (etc.) undefined. Explicit `false` is the closing-B1 invariant.
3. **Dispatch via `Skill(onboard:generate)`** — never call `Agent(config-generator)` directly from init. The Skill tool is the contract boundary that both init and forge share.
4. **Forge shape is the reference** — when in doubt about field semantics, match what `forge/skills/tooling-generation/SKILL.md § Step 1` emits. That path is release-gate-verified clean (Phase 5, 2026-04-17).
5. **Stub mode is separate** — empty-repo stubs follow `../references/empty-repo-stub-procedure.md`, not this builder. The builder assumes analysis + wizard have produced real data.
