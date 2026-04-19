---
name: init
description: Full interactive onboarding wizard — analyzes the codebase, gathers developer preferences through adaptive Q&A, then generates a complete tailored Claude Code tooling setup (CLAUDE.md, rules, skills, agents, hooks, metadata). Use only when the user explicitly invokes /onboard:init.
disable-model-invocation: true
---

# Init Skill — Interactive Onboarding Wizard

You are running the onboard init skill. This is a guided, 4-phase process that analyzes a developer's codebase and generates complete Claude tooling infrastructure.

## Overview

Tell the developer:

> Starting **onboard** — I'll analyze your codebase, walk you through some questions about your project and workflow, then generate a complete Claude Code setup tailored to your project.
>
> This runs in 4 phases:
> 1. **Automated Analysis** — I'll scan your codebase (read-only)
> 2. **Interactive Wizard** — I'll ask about your workflow and preferences
> 3. **Generation** — I'll create all Claude tooling artifacts
> 4. **Handoff** — I'll explain everything that was generated

---

## Phase 0: Empty-Repo Guard

Runs **before** Phase 1 Analysis. Detects repositories with no source code and routes them to a minimal, canonical-shape stub instead of running the full analysis + wizard. Closes 2026-04-17 release-gate findings B14, B15, B16.

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

- `SRC_COUNT > 0` → source code exists → **skip Phase 0 entirely**, fall through to Phase 1 Analysis. Most common case.
- `SRC_COUNT == 0` → empty repo → proceed to Step 0.2.

### Step 0.2: Detect prior stub (auto-promote)

If `.claude/onboard-meta.json` already exists AND `jq -r '.mode // empty'` returns `"stub-empty-repo"` AND `SRC_COUNT > 0`: auto-promote. Skip Phase 0 entirely; run Phase 1 Analysis → Phase 2 Wizard → Phase 3 Generation. Full generation overwrites the stub artifacts. Append an `updateHistory` entry to the new `onboard-meta.json` noting the `"stub → full"` promotion.

If prior stub exists AND `SRC_COUNT == 0` (user ran init twice on empty dir): default to no-op — inform the developer a stub already exists, skip re-write.

### Step 0.3: Present the 3-option menu

For empty repos without a prior stub, use `AskUserQuestion` (single-select, header: `"Empty repo"`):

> This repository has no source code yet. How would you like to proceed?
>
> - **Abort** — stop here. Suggestion: run `/forge:init` to scaffold a project and generate tooling in one step.
> - **Placeholder only** — write a minimal CLAUDE.md placeholder (no `.claude/` directory). Useful if you want to set up Claude context before the code exists but don't want a formal tooling setup.
> - **Generate canonical stub** (default) — create CLAUDE.md, `.claude/settings.json`, and `.claude/onboard-meta.json` in canonical schema with stub-mode markers. Re-run `/onboard:init` later to upgrade to full tooling.

Default: **Generate canonical stub**.

**Single-option guard** (per `.claude/rules/ask-user-question-guard.md`): the menu has 3 options → no guard needed.

### Step 0.4: Execute the selected path

- **Abort** → stop the skill. No files written. Optionally invoke `/forge:init` if the developer explicitly asks.
- **Placeholder only** → write CLAUDE.md with the placeholder content from the stub procedure (below) but SKIP the `.claude/` directory. Return minimal handoff. Do not proceed to further phases.
- **Generate canonical stub** (default) → follow `references/empty-repo-stub-procedure.md`. It prescribes: the 3 files, the canonical `onboard-meta.json` schema with all 7 Phase 7 status keys set to `status: "skipped"` + `reason: "stub-mode-no-code"`, dynamic `pluginVersion` resolution (no hardcoded literals), and the 3-file atomic write order.

After either stub path completes, run a minimal handoff (see the stub procedure's § Post-write handoff section) and return — do NOT continue to Phase 1 Analysis.

---

## Phase 1: Automated Analysis

### Step 1.1: Check for Existing Claude Config

Before running analysis, check if the project already has Claude configuration:

```
Glob for: CLAUDE.md, .claude/**, .claude/settings.json
```

**If substantial Claude config exists** (root CLAUDE.md with >20 lines, or .claude/ directory with rules/skills/agents):

> I see this project already has Claude tooling set up:
> - [list what was found]
>
> Would you like to:
> 1. **Update** — Check your existing setup against latest best practices (`/onboard:update`)
> 2. **Start fresh** — Replace the existing setup with a new one generated from scratch
> 3. **Cancel** — Keep everything as-is

Wait for the developer's choice. If they choose "Update", redirect them to run `/onboard:update`. If "Cancel", stop. If "Start fresh", continue but note that existing files will be overwritten.

**If minimal or no Claude config exists**, proceed directly to analysis.

### Step 1.2: Run Analysis

Spawn the `codebase-analyzer` agent to perform deep analysis. The agent will:
- Run the three shell scripts (analyze-structure.sh, detect-stack.sh, measure-complexity.sh)
- Perform deep exploration of key configuration files
- Check testing setup, CI/CD, conventions
- Produce a structured analysis report

**Data handoff**: The analyzer agent's full structured report remains in the conversational context. Do not write it to a file — it will be passed to the config-generator agent via the conversation in Phase 3.

**Script failure fallback**: If any analysis script fails (permission denied, timeout, or unsupported environment), log the failure and continue with deep codebase exploration only. Do not block the wizard — the scripts provide supplementary data, not required data.

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

### Step 1.4: Choose Wizard Mode

After the analysis summary is confirmed, offer the developer a choice:

> How would you like to set up your Claude tooling?
>
> 1. **Quick setup** — I'll infer most settings from your codebase analysis and ask just a couple of key questions
> 2. **Guided walkthrough** (recommended) — I'll walk you through a short wizard to capture your preferences

If the developer chooses **Quick setup**, the wizard runs in Quick Mode (see wizard skill for inference rules). If they choose **Guided walkthrough**, proceed to Phase 2 (which includes preset selection).

---

## Phase 2: Interactive Wizard

Use the `wizard` skill to guide the developer through adaptive questions. The skill contains the full question bank, branching logic, and workflow presets.

The wizard starts with **preset selection** — offering Minimal, Standard, Comprehensive, or Custom profiles. If a preset is chosen, most questions are pre-answered and the wizard moves quickly to project description and confirmation.

Key reminders:
- **Offer presets first** to fast-track the wizard for developers who want quick setup
- **Group questions** to keep the Custom path to 5-6 exchanges
- **Reference analysis results** when asking questions
- **Skip questions** that the analysis already answered clearly
- **Adapt** based on prior answers
- **Be conversational**, not interrogative

After all questions are answered, present a summary:

> Here's a summary of everything I've gathered:
>
> **Project**: [description]
> **Team**: [size]
> **Primary work**: [tasks]
> **Workflow**: [review process, branching, deploy frequency]
> **[Stack-specific]**: [relevant details]
> **Pain points**: [time sinks, error-prone areas, automation wishes]
> **Preferences**: [testing, style, security, autonomy]
>
> Ready to generate your Claude tooling based on this? Or would you like to adjust anything?

Wait for confirmation before proceeding to generation.

---

## Phase 2.5: Plugin Detection

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
> You can install plugins later and re-run `/onboard:init` to integrate them.

---

## Phase 2.6: Build Onboard Context

Follow the canonical procedure in `references/onboard-context-builder.md` to assemble the single context object that Phase 3 dispatches to `Skill(onboard:generate)`. The builder is the **single source of truth** for init context construction — every preset path (Custom / Standard / Minimal / Comprehensive / Quick Mode) invokes it. Do not maintain preset-specific context builders; that was the drift that caused release-gate findings B1, B5, B6, B8, B10, B12, B13 (2026-04-17 sweep).

Inputs already in conversation context:

- Phase 1 analysis report
- Phase 2 wizard output (canonical `wizardAnswers` shape per `../wizard/SKILL.md` § Output § Canonical shape invariant)
- Phase 2.5 plugin detection results (`installedPlugins`, `coveredCapabilities`, `pluginSurfaces`)
- Project root path (current working directory)

The builder emits a context object shaped like `forge-onboard-context.json` (forge is the reference — its release-gate Phase 5 pass proves the shape works). Key invariants:

- All 7 callerExtras Phase-7 flags populated explicitly (`disableMCP`, `disableLSP`, `disableBuiltInSkills`, `disableSkillTuning`, `disableAgentTuning`, `disableOutputStyleTuning`, `allowHttpHooks`) — init-path defaults are `false` for all (Phase 7 blocks run fully; interactive confirmation runs).
- `callerExtras.installedPlugins` and `pluginSurfaces` populated from Phase 2.5 probes.
- Every wizardAnswers field populated (including defaults for skipped fields per `../wizard/SKILL.md` § Skip Behavior).

Run the builder's validation step before proceeding to Phase 3. If validation fails, refuse to dispatch — surface the error to the user with the offending field name.

---

## Phase 3: Generation via Skill(onboard:generate)

### Step 3.1: Model resolution (no separate prompt)

The model has already been chosen by this point — either explicitly through the wizard's Phase 5.2 (Custom preset), or implicitly via the preset default (Minimal/Standard/Comprehensive use `claude-opus-4-7[1m]` per `wizard/references/workflow-presets.md` § Per-preset exchange targets).

**Do NOT** ask "Which model would you like to use?" here. That used to be a separate post-summary question in earlier versions of init/SKILL.md and the wizard's Phase 5.2 also asked the same thing — the duplicate prompt was findings A4 in the 2026-04-16 release-gate test.

Resolve the model from the wizard answers as follows:

```
chosenModel = wizardAnswers.skillTuning?.defaultModel
            ?? wizardAnswers.model
            ?? presetDefaultModel(wizardAnswers.selectedPreset)
            ?? "claude-opus-4-7[1m]"
```

The preset-default fallback is documented in `wizard/references/workflow-presets.md`. The final fallback (`claude-opus-4-7[1m]`) covers any path where the wizard answers don't include a model (e.g., a future bug or a Quick Mode bail-out before Phase 5.2).

The wizard's Phase 6 summary already shows the chosen model — the developer has already seen and confirmed it. If they wanted to change it, they would have done so in the summary tweak step (or by editing `.claude/settings.json` after init).

The model choice is written into `context.modelChoice` by the Phase 2.6 builder.

### Step 3.2: Dispatch to Skill(onboard:generate)

**Invoke `Skill(onboard:generate)` with the context object built in Phase 2.6.** This is the same skill forge uses (via `forge:tooling-generation`) — one contract, one validator, one agent-dispatch boundary.

```
Skill(
  skill: "onboard:generate",
  args: <stringified context object from Phase 2.6>
)
```

The generate skill then:

1. Validates the context (same rules as forge — see `../generate/SKILL.md` § Validation)
2. Dispatches `Agent(config-generator)` with `dispatchedAsAgent: true`
3. Runs the full generation pipeline (Phase 7a MCP, 7b Output Styles, 7c LSP, 7d Built-in Skills) per `../generation/SKILL.md`
4. Runs pre-exit self-audit verifying all 7 Phase 7 telemetry keys are present
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

## Phase 3.5: Ecosystem Setup

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
3. **On success** — proceed to the corresponding setup step. If the plugin's slash commands/scripts aren't immediately available, note: "Plugin installed, but its scripts may not be on disk yet until you restart the session. If setup fails, restart Claude Code and rerun `/onboard:init`."
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

## Phase 4: Education & Handoff

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
> - Run `/onboard:status` anytime to check the health of your setup
> - Run `/onboard:update` periodically to align with latest Claude best practices
> - All generated files have maintenance headers — Claude will let you know when they need updating

If ecosystem plugins were set up, add:
> - Run `/notify:status` to verify notifications are working

### Step 4.4: Closing

> Your project is now set up for AI-assisted development with Claude Code. Happy coding!
