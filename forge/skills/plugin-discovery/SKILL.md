# Plugin Discovery Skill — Ecosystem Search & Install

You are executing Phase 3b of Forge: discovering and installing Claude Code plugins that complement the developer's project. This is the one interactive step in Phase 3.

## Purpose

Recommend and install Claude Code plugins based on the developer's tech stack, workflow preferences, and project type. Combine curated catalog matching with optional web search.

## Inputs

You receive the complete Phase 1 context object including: stack, team size, security sensitivity, testing philosophy, and all project details.

## Step 1: Match Curated Catalog

Read `references/plugin-catalog.md` and match plugins against the project context.

### Matching Rules

1. **Universal plugins** (always recommended): superpowers, commit-commands, security-guidance, hookify, claude-md-management
2. **Stack-conditional plugins**: match based on context flags (hasFrontend, hasAPI, securitySensitivity, etc.)
3. **Workflow-conditional plugins**: match based on preferences (testingPhilosophy, deployTarget, etc.)

For each matched plugin, note:
- Why it matches (which context field triggered it)
- Whether it's "recommended" (universal) or "matches your stack/workflow"
- Which **build phase** it most applies to (for phase-grouped presentation — see Step 2)

### Phase grouping for presentation

When presenting the interactive checklist in Step 2, group plugins by the build phase they most apply to. This is pedagogical — a plugin can appear in multiple groups if it's multi-purpose (e.g., superpowers is a meta-plugin). It still only gets installed once.

| Phase | Plugins |
|---|---|
| Research & brainstorming (mandatory first phase) | `superpowers` (brainstorming, dispatching-parallel-agents), `context7` |
| Core discipline (applies to all phases) | `superpowers` (TDD, verification, debugging), `claude-md-management`, `commit-commands` |
| Per-feature work | `feature-dev`, `code-review` |
| Review & PR | `code-review`, `pr-review-toolkit` |
| Engineering lifecycle (Phase 4) | `engineering` (from `knowledge-work-plugins` marketplace) |
| Behavioral guardrails | `hookify`, `security-guidance` |

## Step 2: Present Interactive Checklist

Present the matched plugins as a checklist using the AskUserQuestion tool with multiSelect.

**Grouping for the checklist UI**: render plugins under the phase headers from Step 1 (Research & brainstorming → Core discipline → Per-feature work → Review → Engineering → Guardrails). Superpowers and other multi-purpose plugins appear in every group they serve. The first phase header must be:

> **Research & brainstorming (mandatory first phase for any new feature work)**

Explicitly flag it as mandatory so developers understand why superpowers is the highest-priority recommendation.

Present the matched plugins with:

> Based on your stack and workflow, these Claude Code plugins would complement your setup. The order is phase-aware — Research phase first, then core discipline, then per-feature work.

For each plugin, show:
- Name
- What it does (one sentence)
- Why it matches (e.g., "[matches: Next.js]", "[matches: TDD]")

The developer selects which ones to install.

## Step 3: Optional Web Search

After the developer makes their selections, offer:

> Want me to search the ecosystem for additional plugins beyond my curated list?

If yes:
1. Search the web for "[stack] claude code plugin" and "claude code plugins [use case]"
2. Filter results for quality (look for GitHub stars, recent activity, documentation)
3. Present additional matches not already in the catalog
4. Developer selects from these too

If no, skip to Step 4.

## Step 4: Install Selected Plugins

For each selected plugin, install using the Claude Code plugin management commands:

```bash
claude plugin install [plugin-name]
```

Report success or failure for each installation.

## Step 5: Compile Covered Capabilities

After installation, build the `coveredCapabilities` list using the capability mapping table in `references/plugin-catalog.md`:

1. For each successfully installed plugin, look up its capabilities in the "Capability Mapping" table
2. Combine all capabilities into a deduplicated list
3. Return both `installedPlugins` (list of plugin names) and `coveredCapabilities` (list of capability strings) to the calling skill (tooling-generation)

This data is passed to onboard headless via `callerExtras`, telling it which agents to skip generating. Without this step, onboard would generate generic agents that shadow the superior plugin versions.

## Key Rules

1. **Never install without consent** — Always present the checklist and wait for selection.
2. **Curated quality first** — The catalog contains vetted plugins. Web search results need quality filtering.
3. **Explain why** — Every recommendation should explain what matched in the developer's context.
4. **Handle failures gracefully** — If a plugin fails to install, report the error and continue with others.
5. **Don't over-recommend** — 5-8 plugins is a good range. Don't overwhelm with 15+ suggestions.
