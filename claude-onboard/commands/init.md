# /claude-onboard:init — Interactive Onboarding Wizard

You are running the claude-onboard initialization wizard. This is a guided, 4-phase process that analyzes a developer's codebase and generates complete Claude tooling infrastructure.

## Overview

Tell the developer:

> Starting **claude-onboard** — I'll analyze your codebase, walk you through some questions about your project and workflow, then generate a complete Claude Code setup tailored to your project.
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
> 1. **Update** — Check your existing setup against latest best practices (`/claude-onboard:update`)
> 2. **Start fresh** — Replace the existing setup with a new one generated from scratch
> 3. **Cancel** — Keep everything as-is

Wait for the developer's choice. If they choose "Update", redirect them to run `/claude-onboard:update`. If "Cancel", stop. If "Start fresh", continue but note that existing files will be overwritten.

**If minimal or no Claude config exists**, proceed directly to analysis.

### Step 1.2: Run Analysis

Spawn the `codebase-analyzer` agent to perform deep analysis. The agent will:
- Run the three shell scripts (analyze-structure.sh, detect-stack.sh, measure-complexity.sh)
- Perform deep exploration of key configuration files
- Check testing setup, CI/CD, conventions
- Produce a structured analysis report

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

Spawn the `config-generator` agent with:
- The full analysis report
- The wizard answers (as structured JSON)
- The project root path
- The current date for maintenance headers

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
> - Run `/claude-onboard:status` anytime to check the health of your setup
> - Run `/claude-onboard:update` periodically to align with latest Claude best practices
> - All generated files have maintenance headers — Claude will let you know when they need updating

### Step 4.4: Closing

> Your project is now set up for AI-assisted development with Claude Code. Happy coding!
