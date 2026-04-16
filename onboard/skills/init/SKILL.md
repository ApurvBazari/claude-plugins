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

### Step 2.5.1: Check for callerExtras

If `callerExtras.installedPlugins` is present (headless mode via `/onboard:generate`), skip this phase entirely — the caller has already provided plugin data.

### Step 2.5.2: Probe Filesystem

For each plugin in the Known Plugin Probe List (see `generation/references/plugin-detection-guide.md`), run:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../<plugin-name>" 2>/dev/null
```

Build `installedPlugins` from successful probes. Derive `coveredCapabilities`, `qualityGates`, and `phaseSkills` per the detection guide's derivation rules, using `wizardAnswers.autonomyLevel` for the autonomyLevel downgrade.

**If `CLAUDE_PLUGIN_ROOT` is unset**: Skip detection, treat as "no plugins detected", and proceed to Phase 3 with standalone generation.

### Step 2.5.3: Present Detection Results

If plugins were detected:

> **Detected Claude Code plugins:**
> - **[plugin name]** ([capabilities])
> - ...
>
> These will be integrated into your generated CLAUDE.md and quality-gate hooks.

If no plugins were detected:

> No Claude Code plugins detected. I'll generate standalone tooling.
> You can install plugins later and re-run `/onboard:init` to integrate them.

### Step 2.5.4: Pass to Generation

Build the `detectedPlugins` object with `installedPlugins`, `coveredCapabilities`, `qualityGates`, and `phaseSkills`. Include it in the data passed to the config-generator agent in Phase 3, alongside the analysis report and wizard answers.

---

## Phase 3: Generation

### Step 3.1: Model Recommendation

Before generating artifacts, present the model recommendation based on the analysis skill's model-recommendations.md logic:

> Based on your project ([complexity category], [file count] files, [LOC] lines, [language count] languages):
>
> **Recommended model**: [Sonnet/Opus]
> **Reasoning**:
> - [bullet 1]
> - [bullet 2]
> - [bullet 3]
>
> [If both are viable]: You could also consider [other model] because [trade-off].
>
> Which model would you like to use? You can always change this later.

Wait for the developer to choose. Record their choice.

### Step 3.2: Generate Artifacts

Spawn the `config-generator` agent via the Agent tool (`subagent_type: "config-generator"`). Include the following in the agent prompt — all of this is already available in the conversational context from prior phases:
- The full analysis report (from Phase 1)
- The wizard answers as structured JSON (from Phase 2) — includes `advancedHookEvents` when the developer opted in at Phase 5.1; generation reads this to drive `Advanced Event Hooks` emission (see `generation/SKILL.md` § Advanced Event Hooks)
- The `detectedPlugins` object (from Phase 2.5) — if no plugins were detected, pass an empty object so the generation skill resolves `effectivePlugins` as empty
- The chosen model (from Step 3.1)
- The project root path
- The current date for maintenance headers
- A flag indicating the agent was dispatched (not running inline): `"dispatchedAsAgent": true` — config-generator hard-fails Step 0 if absent

**REQUIRED**: this MUST be a single Agent dispatch. Do NOT execute the agent's instructions inline from this skill (init), and do NOT call Write/Edit from this skill — config-generator owns all writes (same dispatch contract as `onboard:generate`).

Inform the developer:

> Generating your Claude tooling... This will create the following artifacts:
> - Root CLAUDE.md
> - [Subdirectory CLAUDE.md files if applicable]
> - Path-scoped rules
> - Skills
> - Agents
> - Hook configuration
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
