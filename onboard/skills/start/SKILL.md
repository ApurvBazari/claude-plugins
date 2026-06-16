---
name: start
description: Use ONLY when the user explicitly runs /onboard:start. The full interactive onboarding wizard that sets up tailored Claude Code tooling for a project. Never auto-invoke.
disable-model-invocation: true
---

# Start Skill — Interactive Onboarding Wizard

You are running the onboard init skill. This is a guided, multi-phase process that analyzes a developer's codebase and generates complete Claude tooling infrastructure.

## Overview

Tell the developer:

> Starting **onboard** — I'll analyze your codebase, walk you through some questions about your project and workflow, then generate a complete Claude Code setup tailored to your project.
>
> This runs in these phases:
> 1. **Recon** — I scan your codebase (read-only, native tools)
> 2. **Profile** — you pick a depth/scope profile (Minimal / Standard / Comprehensive)
> 3. **Deep Research** — focused specialists investigate per dimension and I verify their findings, then write a research dossier + architecture map + risk register + glossary
> 4. **Grounded Wizard** — I show you what research inferred; you confirm or override
> 5. **Generation** — I create all Claude tooling artifacts
> 6. **Handoff** — I explain everything that was generated

---

## Step 0: Empty-Repo Guard

Runs **before** Step 1 Analysis. Detects repositories with no source code and routes them to a minimal, canonical-shape stub instead of running the full analysis + wizard. Closes 2026-04-17 release-gate findings B14, B15, B16.

### Step 0.1: Detect empty repository

Count source-code files (exclude `.git/`, dotfiles, `README*`, `LICENSE*`, `.gitignore`):

```bash
SRC_COUNT=$(find . -type f \
  -not -path './.git/*' \
  -not -name '.*' \
  -not -name 'README*' \
  -not -name 'LICENSE*' \
  | wc -l | tr -d ' ')
```

- `SRC_COUNT > 0` → source code exists → **skip Step 0 entirely**, fall through to Step 1 Analysis. Most common case.
- `SRC_COUNT == 0` → empty repo → proceed to Step 0.2.

### Step 0.2: Detect prior stub (auto-promote)

If `.claude/onboard-meta.json` already exists AND `jq -r '.mode // empty'` returns `"stub-empty-repo"` AND `SRC_COUNT > 0`: auto-promote. Skip Step 0 entirely; run Step 1 Analysis → Step 2 Wizard → Step 3 Generation. Full generation overwrites the stub artifacts. Append an `updateHistory` entry to the new `onboard-meta.json` noting the `"stub → full"` promotion.

If prior stub exists AND `SRC_COUNT == 0` (user ran init twice on empty dir): default to no-op — inform the developer a stub already exists, skip re-write.

### Step 0.3: Present the 3-option menu

For empty repos without a prior stub, use `AskUserQuestion` (single-select, header: `"Empty repo"`):

> This repository has no source code yet. How would you like to proceed?
>
> - **Abort** — stop here. Add source code first, then re-run `/onboard:start`.
> - **Placeholder only** — write a minimal CLAUDE.md placeholder (no `.claude/` directory). Useful if you want to set up Claude context before the code exists but don't want a formal tooling setup.
> - **Generate canonical stub** (default) — create CLAUDE.md, `.claude/settings.json`, and `.claude/onboard-meta.json` in canonical schema with stub-mode markers. Re-run `/onboard:start` later to upgrade to full tooling.

Default: **Generate canonical stub**.

**Single-option guard** (per `.claude/rules/ask-user-question-guard.md`): the menu has 3 options → no guard needed.

### Step 0.4: Execute the selected path

- **Abort** → stop the skill. No files written.
- **Placeholder only** → write CLAUDE.md with the placeholder content from the stub procedure (below) but SKIP the `.claude/` directory. Return minimal handoff. Do not proceed to further phases.
- **Generate canonical stub** (default) → follow `references/empty-repo-stub-procedure.md`. It prescribes: the 3 files, the canonical `onboard-meta.json` schema with all 7 Phase 7 status keys set to `status: "skipped"` + `reason: "stub-mode-no-code"`, dynamic `pluginVersion` resolution (no hardcoded literals), and the 3-file atomic write order.

After either stub path completes, run a minimal handoff (see the stub procedure's § Post-write handoff section) and return — do NOT continue to Step 1 Analysis.

---

## Step 1: Automated Analysis

### Step 1.1: Check for Existing Claude Config

Before running analysis, check if the project already has Claude configuration:

```
Glob for: CLAUDE.md, .claude/**, .claude/settings.json
```

**If substantial Claude config exists** (root CLAUDE.md with >20 lines, or .claude/ directory with rules/skills/agents):

> I see this project already has Claude tooling set up:
> - [list what was found]

Ask via `AskUserQuestion` (single-select, header `"Existing config"`):

- **Adopt (Recommended)** — "Bring the existing tooling under onboard management without changing it, so `/onboard:update` works. Runs `/onboard:adopt`."
- **Update** — "Check the existing setup against latest best practices (`/onboard:update`)."
- **Start fresh** — "Replace the existing setup with a newly generated one (existing files will be overwritten)."
- **Cancel** — "Keep everything as-is."

Dispatch on the choice:
- **Adopt** → run the `adopt` skill (`Skill(onboard:adopt)`); when it returns, this start invocation is done (adopt owns the baseline). Do not continue into analysis/generation.
- **Update** → redirect the developer to run `/onboard:update`. Stop.
- **Start fresh** → continue to Step 1.2; note that existing files will be overwritten at generation.
- **Cancel** → stop.

**Guard Usage:** four fixed options (≥2), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

**If minimal or no Claude config exists**, proceed directly to analysis.

### Step 1.2: Run Analysis

Spawn the `codebase-analyzer` agent to perform deep analysis. The agent will:
- Perform script-free recon (native Glob/Grep/Read + git one-liners) per `../../agents/codebase-analyzer.md`
- Perform deep exploration of key configuration files
- Check testing setup, CI/CD, conventions
- Produce a structured analysis report

**Data handoff**: The analyzer agent's full structured report remains in the conversational context. Do not write it to a file — it will be passed to the config-generator agent via the conversation in Step 3. The analyzer also returns `reconHints = {detectedRoots, structureFacts}` — keep it in context for Step 1.5.

While waiting, inform the developer:

> Analyzing your codebase... This reads your project structure, detects your tech stack, and assesses complexity. Nothing is modified.

### Step 1.3: Present Analysis Summary

Once analysis completes, present a concise summary to the developer:

> Here's what I found:
>
> **Project type**: [type]
> **Languages**: [languages with file counts]
> **Key frameworks**: [frameworks with versions]
> **Testing**: [testing setup]
> **CI/CD**: [pipeline if detected]
> **Complexity**: [category] ([score]/100 — [file count] source files, [LOC] lines)
>
> Does this look accurate? Anything I missed or got wrong?

Wait for confirmation. Incorporate any corrections before proceeding.

### Step 1.4: Select Profile

After the recon summary is confirmed, ask the developer to pick a profile using `AskUserQuestion` (single-select, header: `"Profile"`). The profile sets **both** the research depth (Step 1.5) and the generation scope.

| Label | Description |
|---|---|
| `Minimal` | Solo / prototype / fast. Recon-only research (no specialists), relaxed style, 1 agent, format-only hooks. |
| `Standard (Recommended)` | Small teams / active projects. Core-4 research + verify, balanced autonomy, 3 agents, lint + SessionStart hooks. |
| `Comprehensive` | Larger / regulated. Full 7-specialist research + verify, strict style, all quality-gate hooks. |

Map the choice to `depth`: `Minimal → "minimal"`, `Standard → "standard"`, `Comprehensive → "comprehensive"`. Record it as `selectedPreset` for the grounded wizard + generation scope (per `../wizard/references/workflow-presets.md`). There is **no Custom profile** — the grounded wizard (Step 2) lets the developer override every field individually.

### Step 1.5: Deep Research

Dispatch the research engine with the chosen depth and the recon hints:

```
Skill(
  skill: "onboard:research",
  args: <stringified { projectPath: <cwd>, depth: <from Step 1.4>, reconHints: <from Step 1.2> }>
)
```

The engine fans out read-only specialists per dimension, adversarially verifies their claims, synthesizes the research dossier, **asks where the four human-readable artifacts should land** (committed / local / none), writes `.claude/onboard-research.json` (+ the four `docs/onboard/` files per that choice), and returns the validated `research-dossier` object.

Keep the returned dossier in conversation context: Step 2 reads `research.wizardInferences`, and Step 2.6 embeds the whole `research` object in the v3 context.

Inform the developer before dispatching:

> Researching your codebase in depth — focused specialists per dimension, with their findings verified against your code, producing a research dossier plus an architecture map, risk register, and glossary. This is read-only.

For `minimal` depth the engine dispatches no specialists and returns a minimal dossier quickly (the fast/cheap path).

---

## Step 2: Interactive Wizard

Use the `wizard` skill to run the **grounded confirm/override surface**. It reads `research.wizardInferences` from the Step 1.5 dossier and presents confirm/override cards (workflow fields), cold asks (`autonomyLevel` + intent + pain points), and tuning/detection cards — ~2–3 exchanges. There is no preset selection here (done in Step 1.4) and no Custom path.

After all questions are answered, present a summary:

> Here's a summary of everything I've gathered:
>
> **Project**: [description]
> **Model**: [model-id] ([source])
> **Team**: [size]
> **Primary work**: [tasks]
> **Workflow**: [review process, branching, deploy frequency]
> **[Stack-specific]**: [relevant details]
> **Pain points**: [time sinks, error-prone areas, automation wishes]
> **Preferences**: [testing, style, security, autonomy]
>
> Next I'll show you a full preview of what I'll build before anything is written.

---

## Step 2.5: Plugin Detection

Before generation, detect installed Claude Code plugins to enrich the output with plugin-aware features (Plugin Integration section, per-directory skill annotations, plugin-aware agent skipping, quality-gate hooks referencing plugin skills).

### Step 2.5.1: Probe Filesystem — canonical deep probe

Follow the canonical procedure in `../generation/references/plugin-detection-guide.md` § Known Plugin Probe List. The probe walks **both** locations to catch sibling installs AND marketplace-installed plugins:

1. `${CLAUDE_PLUGIN_ROOT}/../<plugin-name>/` (dev monorepo siblings)
2. `~/.claude/plugins/cache/*/<plugin-name>/[version/]` (marketplace installs, where `<version>` is often the literal string `"unknown"`)

Build `installedPlugins` from successful probes across the full catalog. Do not stop on a single miss — continue through every plugin in the catalog.

**Fallback when `CLAUDE_PLUGIN_ROOT` is unset**: the marketplace-cache probe still runs (keys off `$HOME`). Only fall back to "no plugins detected" when BOTH probe locations yield zero hits across the catalog.

### Step 2.5.2: Probe Plugin Surfaces

For each entry in `installedPlugins`, run the surface-probe procedure in `../generation/references/plugin-surface-probe.md` to classify the plugin as `command-or-skill`, `hooks-only`, or `agent-only`. The resulting `pluginSurfaces` map feeds the Plugin Integration template to prevent fabricated slash refs (e.g., `/security-guidance:security-review` for a hooks-only plugin — release-gate finding G.3, 2026-04-17).

### Step 2.5.3: Derive coveredCapabilities, qualityGates, phaseSkills

Apply the derivation rules in `../generation/references/plugin-detection-guide.md`:
- `coveredCapabilities` — combine per-plugin capabilities, deduplicated
- `qualityGates` — filter defaults by `installedPlugins`, then downgrade `preCommit[].mode` per `wizardAnswers.autonomyLevel`
- `phaseSkills` — filter defaults by `installedPlugins`; remove empty phases

### Step 2.5.4: Present Detection Results

If plugins were detected:

> **Detected Claude Code plugins:**
> - **[plugin name]** ([capabilities])
> - ...
>
> These will be integrated into your generated CLAUDE.md and quality-gate hooks.

If no plugins were detected:

> No Claude Code plugins detected. I'll generate standalone tooling.
> You can install plugins later and re-run `/onboard:start` to integrate them.

---

## Step 2.6: Build Onboard Context

Follow the canonical procedure in `references/onboard-context-builder.md` to assemble the single context object that Step 3 dispatches to `Skill(onboard:generate)`. The builder is the **single source of truth** for init context construction — every profile path (Minimal / Standard / Comprehensive) invokes it. Do not maintain profile-specific context builders; that was the drift that caused release-gate findings B1, B5, B6, B8, B10, B12, B13 (2026-04-17 sweep).

Inputs already in conversation context:

- Step 1 analysis report
- Step 1.5 research dossier (the `research` object)
- Step 2 wizard output (canonical `wizardAnswers` shape per `../wizard/SKILL.md` § Output § Canonical shape invariant)
- Step 2.5 plugin detection results (`installedPlugins`, `coveredCapabilities`, `pluginSurfaces`)
- Project root path (current working directory)

The builder emits a context object per the canonical schema. Key invariants:

- the builder emits **v3** (`version: 3`) and embeds the `research` object — see `references/onboard-context-builder.md`.
- All 7 callerExtras Phase-7 flags populated explicitly (`disableMCP`, `disableLSP`, `disableBuiltInSkills`, `disableSkillTuning`, `disableAgentTuning`, `disableOutputStyleTuning`, `allowHttpHooks`) — init-path defaults are `false` for all (Phase 7 blocks run fully; interactive confirmation runs).
- `callerExtras.installedPlugins` and `pluginSurfaces` populated from Step 2.5 probes.
- Every wizardAnswers field populated (including defaults for skipped fields per `../wizard/SKILL.md` § Skip Behavior).

Run the builder's validation step before proceeding to Step 3. If validation fails, refuse to dispatch — surface the error to the user with the offending field name.

---

## Step 2.7: Generation Plan (plan mode)

Dispatch generation in plan mode — it computes what it will write without writing:

```
Skill(onboard:generate, {mode:"plan", context})   // context from Step 2.6
```

The skill returns a `generationManifest` (validated vs `../../schemas/generation-manifest.json`): `changes[]` (path, action, purpose, outline, tier, origin) + `decisions` + `warnings`. **Nothing is written.** Keep the manifest in context.

If plan mode fails or the manifest fails validation, do NOT proceed — surface the error; let the developer retry or cancel.

## Step 2.8: Assemble the preview model

Build `previewModel` from the research dossier (Step 1.5) + the manifest (Step 2.7) per `../research/references/render-adapter.md` § previewModel: `flow:"start"`; `research` = architecture map + top risks + glossary from the dossier (null if research was minimal/empty); `changes`/`decisions`/`warnings` from the manifest.

---

## Step 2.9: Render + hard gate (review before implementation)

This is the review-before-implementation gate. **Nothing has been written yet.**

1. **Render.** Map `previewModel` → a walkthrough `session-model` per `../research/references/render-adapter.md`, then invoke `walkthrough:render` with `{ model, outputPath: ".claude/walkthrough/<YYYY-MM-DD-HHMM>-onboard-plan.html" }`.
   - **walkthrough absent** (render skill unavailable) → offer install via AskUserQuestion (single-select, header `"Walkthrough"`): **Install now (Recommended)** ("render this preview as an interactive page") / **Skip — markdown preview**.
     - Install now → `claude plugin install walkthrough@apurvbazari-plugins` via Bash; re-probe; success → render as above; failure → markdown fallback.
     - Skip / failure → **markdown gate**: present `previewModel` inline as markdown (Overview · What I learned · What I'll build grouped by tier with each artifact's purpose+outline · Key decisions · Risks). Optionally also write `.claude/onboard-plan.md`.
   - **`walkthrough:render` present but fails at runtime** → don't abort the gate; announce the degrade and fall through to the **markdown gate** above. (Invoking the skill is itself the presence test: an uninstalled skill surfaces as *absent* above; a runtime render error lands here.)
   - This degrades the HTML render only — never the gate.
2. **Gate.** AskUserQuestion (single-select, header `"Generate?"`):
   - **Approve & generate (Recommended)** → proceed to Step 3 (write mode).
   - **Adjust** → return to the Step 2 wizard summary to revise answers/profile, then re-run Step 2.6 → 2.7 → 2.8 → 2.9.
   - **Cancel** → stop. Write nothing. Print: "Cancelled — no files were created."
3. Only **Approve** advances to Step 3. Until then, nothing is written to disk.

**Guard Usage:** the install offer and the gate both use fixed-option single-selects (≥2 options), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

---

## Step 3: Generation via Skill(onboard:generate)

### Step 3.1: Model resolution (no separate prompt)

The model has already been chosen by this point — either because the developer tuned it in the grounded wizard (`wizardAnswers.skillTuning?.defaultModel`), or implicitly via the profile default (Minimal/Standard/Comprehensive use `claude-opus-4-7[1m]` per `../wizard/references/workflow-presets.md` § Exchange target (uniform across profiles)).

**Do NOT** ask "Which model would you like to use?" here. That used to be a separate post-summary question in earlier versions of start/SKILL.md — the duplicate prompt was findings A4 in the 2026-04-16 release-gate test.

Resolve the model from the wizard answers as follows:

```
chosenModel = wizardAnswers.skillTuning?.defaultModel
            ?? wizardAnswers.model
            ?? presetDefaultModel(wizardAnswers.selectedPreset)
            ?? "claude-opus-4-7[1m]"
```

The profile-default fallback is documented in `../wizard/references/workflow-presets.md`. The final fallback (`claude-opus-4-7[1m]`) covers any path where the wizard answers don't include a model (e.g., a future bug or the grounded wizard skipping the model-tuning card).

The wizard's summary already shows the chosen model — the developer has already seen and confirmed it. If they wanted to change it, they would have done so in the summary tweak step (or by editing `.claude/settings.json` after init).

The model choice is written into `context.modelChoice` by the Step 2.6 builder.

### Step 3.2: Dispatch to Skill(onboard:generate)

**Invoke `Skill(onboard:generate)` with the context object built in Step 2.6.** One contract, one validator, one agent-dispatch boundary.

```
Skill(onboard:generate, {mode:"write", context})   // context from Step 2.6 — the same object Step 2.7 planned from
```

By this point the developer has approved the plan at Step 2.9; write mode honors that plan (same artifact set + decisions).

The generate skill then:

1. Validates the context (see `../generate/SKILL.md` § Validation)
2. Dispatches `Agent(config-generator)` with `dispatchedAsAgent: true`
3. Runs the full generation pipeline (Phase 7a MCP, 7b Output Styles, 7c LSP, 7d Built-in Skills) per `../generation/SKILL.md`
4. Runs pre-exit self-audit verifying all 7 Phase 7 telemetry keys are present. The self-audit also covers the v3 research telemetry block:
   - **Research self-audit:** if `metadata.research.consumed === true`, verify the block is coherent — `.claude/onboard-research.json` exists; `claimsVerified`, `claimsDropped`, `specialistsRun`, `artifactLocation`, `artifactsWritten` are present; `artifactsWritten` paths match the on-disk docs for the recorded `artifactLocation`; and `htmlRendered` is non-null **iff** the `walkthrough` plugin was present at render time (null is correct when absent or `location:"none"`). If `consumed === false` (research-absent / stub mode), record the research key as `status:"skipped"` with a reason (mirrors the existing skipped-key convention). Surface any incoherence as a self-audit warning.
5. Returns a structured JSON response with `filesWritten`, `telemetry`, `auditPassed`, `warnings`

**Do NOT** call `Agent(config-generator)` directly from this skill — that breaks the contract boundary and bypasses the shared validation. Always dispatch via the Skill tool.

**Do NOT** call Write / Edit from this skill — the dispatched agent owns all writes (hard-fail safety net: config-generator checks `dispatchedAsAgent === true` and refuses to write if absent).

Before dispatching, inform the developer:

> Generating your Claude tooling... This will create the following artifacts:
> - Root CLAUDE.md
> - [Subdirectory CLAUDE.md files if applicable]
> - Path-scoped rules
> - Skills
> - Agents
> - Hook configuration
> - MCP servers (if stack signals detected)
> - Output style
> - LSP plugin integration (if source files detected)
> - Setup metadata

### Step 3.3: Report Generation Results

After generation completes, list every file that was created:

> Generation complete! Here's what was created:
>
> | File | Purpose |
> |---|---|
> | `CLAUDE.md` | Root project context (X lines) |
> | `src/components/CLAUDE.md` | Component conventions |
> | `.claude/rules/testing.md` | Testing rules for *.test.* files |
> | `.claude/rules/api.md` | API endpoint rules |
> | `.claude/skills/react-component/SKILL.md` | React component creation skill |
> | `.claude/agents/code-reviewer.md` | Code review agent |
> | `.claude/agents/test-writer.md` | Test generation agent |
> | `.claude/settings.json` | Hook configuration (auto-format, lint) |
> | `.claude/onboard-meta.json` | Setup metadata |

---

## Step 3.5: Ecosystem Setup

If the wizard answers include `ecosystemPlugins`, set up the requested plugins.

### Step 3.5.1: Resolve Requested Ecosystem Plugins

For each plugin the developer selected in the wizard (`ecosystemPlugins.notify`, etc.), verify it's installed. If it's missing, **offer inline install** — do not skip silently, because the developer explicitly asked for it.

For each requested plugin, probe the filesystem:

```bash
# Check if notify is available
ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null
```

Characteristic files per plugin:
- `notify` → `scripts/notify.sh`

**If the probe finds the file**, the plugin is installed — proceed to Step 3.5.2 (for notify).

**If the probe returns nothing**, the plugin is missing. Tell the developer:

> You selected the **<plugin>** plugin during the wizard, but it's not installed yet.
>
> Install it now? (runs: `claude plugin install <plugin>`)

Use AskUserQuestion with two options:
- **Install now (Recommended)** — run the install command via Bash, then continue
- **Skip setup** — don't configure this plugin; continue with the rest of the flow

**If the developer installs:**
1. Run `claude plugin install <plugin>` via the Bash tool.
2. Re-run the detection probe to verify.
3. **On success** — proceed to the corresponding setup step. If the plugin's slash commands/scripts aren't immediately available, note: "Plugin installed, but its scripts may not be on disk yet until you restart the session. If setup fails, restart Claude Code and rerun `/onboard:start`."
4. **On install failure** — surface the underlying error verbatim. Then emit the explicit skip message below and continue with the next requested plugin.

**If the developer skips or install fails**, emit a clear skip message (never silent):

> Skipping **<plugin>** setup. You can install it later with `claude plugin install <plugin>` and run its setup command directly (`/notify:setup`, etc.).

Then continue to the next requested plugin. Repeat for each entry in `ecosystemPlugins`.

**Edge case** — if a plugin was NOT requested in the wizard (`ecosystemPlugins.<plugin>` is `false` or absent), skip it entirely. Do not probe, do not prompt. This step only acts on what the developer explicitly asked for.

### Step 3.5.2: Set Up Notify (if requested and available)

If `ecosystemPlugins.notify` is `true` and notify is available, **first probe for pre-existing global configuration** before offering any project-local setup:

#### Detection probe (strict — both must match to count as configured)

```bash
HAS_GLOBAL_CONFIG=$( [ -f "$HOME/.claude/notify-config.json" ] && echo 1 || echo 0 )
HAS_GLOBAL_HOOK=$(jq -e '.hooks // {} | tostring | test("notify\\.sh") and test("notify-config\\.json")' "$HOME/.claude/settings.json" 2>/dev/null && echo 1 || echo 0)
```

Three states result:

| State | Condition | Action |
|---|---|---|
| `globalConfigured` | `HAS_GLOBAL_CONFIG=1` AND `HAS_GLOBAL_HOOK=1` | **Inform-only, no offer.** Print: "Global notify config detected at `~/.claude/notify-config.json` — your hooks will fire for this project automatically. No project-local setup needed." Skip steps 1-4 below. |
| `globalPartial` | One of the two probes is positive but not both | Print: "Global notify hooks detected but config is incomplete. Project-local setup will install the full config; consider running `/notify:setup` in a fresh session to repair the global install." Then proceed with steps 1-4 (default = no via AskUserQuestion). |
| `notConfigured` | Both probes are 0 | Proceed with steps 1-4 below as the original flow (default = yes). |

#### Project-local setup steps (only when `notConfigured` or developer accepts `globalPartial` offer)

1. Run notify's install script to check dependencies:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/install-notifier.sh"
   ```
2. Copy the notification script to the config scope:
   ```bash
   mkdir -p "$BASE_DIR/hooks"
   cp "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" "$BASE_DIR/hooks/notify.sh"
   chmod +x "$BASE_DIR/hooks/notify.sh"
   ```
3. Write `notify-config.json` to `$BASE_DIR/` — applying **inherit + override** precedence when global config exists:
   - Read `~/.claude/notify-config.json` (if present) as the base.
   - Layer the project-local default on top: only specified keys override the global; missing keys inherit the global value.
   - Example: if global has `events.stop.sound = "Glass"` and project-local doesn't override `sound`, the merged result keeps `"Glass"`.
   - Default project-local body (used when no global exists, or as the override layer):
     ```json
     {
       "version": "1.0.0",
       "events": {
         "stop": { "enabled": true, "message": "Task completed", "sound": "Hero", "minDurationSeconds": 0 },
         "notification": { "enabled": true, "matcher": "permission_prompt|idle_prompt", "message": "Needs your attention", "sound": "Glass" },
         "subagentStop": { "enabled": false, "message": "Subagent task completed", "sound": "Ping" }
       }
     }
     ```
4. Merge notify hooks into `$BASE_DIR/settings.json` (Stop, Notification, SubagentStop events)

Where `$BASE_DIR` is the same scope used for the generated Claude tooling (typically `$PWD/.claude` for per-project or `~/.claude` for global).

Report: `Notify plugin configured — you'll get system notifications when Claude finishes tasks.` (or, when `globalConfigured`, the inform-only line above.)

### Step 3.5.3: Report Ecosystem Setup

> **Ecosystem plugins set up:**
> - [list what was configured]
>
> You can customize these later:
> - Notify: edit `notify-config.json` or run `/notify:setup`

If no plugins were set up (none requested or none available), skip this report entirely.

---

## Step 4: Education & Handoff

### Step 4.1: Explain Key Artifacts

Briefly explain the most important generated artifacts:

> **What to know about your new setup:**
>
> **CLAUDE.md** — This is your main project context file. Claude reads it every session to understand your project. Review it and tweak anything that doesn't feel right.
>
> **Path-scoped rules** — These activate automatically when Claude works on matching files. For example, your testing rules apply whenever Claude touches test files.
>
> **Skills** — These give Claude expertise for specific tasks in your project. Try asking Claude to [relevant task based on generated skills].
>
> **Agents** — Specialized Claude personas. Try running your [agent name] agent on a recent change.
>
> **Hooks** — Auto-formatting and linting happen in the background. You don't need to think about these.

### Step 4.2: Quick Start Suggestions

Based on what was generated, suggest what to try first:

> **Try these first:**
> 1. Open a file in your project and notice how Claude now has context about your conventions
> 2. [Stack-specific suggestion, e.g., "Ask Claude to create a new React component and see how it follows your patterns"]
> 3. [Pain-point based suggestion, e.g., "Ask Claude to write tests for a module you mentioned is error-prone"]

### Step 4.3: Next Steps

> **Next steps:**
> - Review `CLAUDE.md` and adjust anything that doesn't match your preferences
> - Review the research artifacts in `docs/onboard/` (or `.claude/onboard-research.json` if you chose local/none) — the dossier, architecture map, risk register, and glossary.
> - Run `/onboard:check` anytime to check the health of your setup
> - Run `/onboard:update` periodically to align with latest Claude best practices
> - All generated files have maintenance headers — Claude will let you know when they need updating

If ecosystem plugins were set up, add:
> - Run `/notify:check` to verify notifications are working

### Step 4.4: Closing

> Your project is now set up for AI-assisted development with Claude Code. Happy coding!

## Key Rules

- **Never dispatch `config-generator` directly** — always go through `Skill(onboard:generate)`. Direct dispatch bypasses the shared validation contract and the `dispatchedAsAgent` safety net.
- **Empty-repo guard always runs first** — Step 0 fires before Step 1 Analysis, even if the user explicitly says "just analyze". A zero-source-count repo must hit the 3-option menu, not the wizard.
- **Settings.json is always merge-aware** — never overwrite `.claude/settings.json` outright. Read it first, merge hooks, then write. The file may already contain hooks from other sources.
- **Notify setup is inform-only when global config is already complete** — the `globalConfigured` detection (config + hook both present) means no project-local offer is made. Never re-setup what is already wired.
- **Halt and surface on context builder validation failure** — if Step 2.6 validation fails, refuse to dispatch and show the offending field. Never attempt generation with an incomplete or malformed context object.
