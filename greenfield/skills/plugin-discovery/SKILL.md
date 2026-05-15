---
name: plugin-discovery
description: Greenfield Phase 3a — matches curated plugin catalog against project context, presents checklist, installs selected plugins, compiles coveredCapabilities. Internal building block invoked by greenfield init — not user-invocable.
user-invocable: false
---

# Plugin Discovery Skill — Ecosystem Search & Install

You are executing Phase 3b of Greenfield: discovering and installing Claude Code plugins that complement the developer's project. This is the one interactive step in Phase 3.

## Invocation mode

This skill operates in two modes determined by the caller:

| Mode | Purpose | Reads | Writes |
|---|---|---|---|
| `recommendation` | Suggest plugins; user picks; no install | `phases.{auth, privacy, security, runtimeOperations, cicdAndDelivery, search, caching, realtime, fileUploads, payments, frontendArchitecture, designSystem, uxAccessibilityPerf, i18nL10n}` | `phases.pluginRecommendation.{suggested, selected, rationale}` |
| `install` | Read picks; actually run `/plugin marketplace install` | `phases.pluginRecommendation.{selected, frontendAddenda}` | `phases.pluginInstall.{installed, failed, skipped}` |

The wizard caller passes mode via the Skill tool input (the conversational caller pattern). When invoking:

```
plugin-discovery (mode=recommendation)
plugin-discovery (mode=install)
```

If mode is omitted, default to `recommendation` (read-only behavior — safest default).

Note: in `recommendation` mode, any `installCommand` fields in `references/plugin-catalog.md` are ignored — recommendation mode only matches capabilities and returns suggestions to the caller. Install commands are consumed exclusively by `install` mode.

## Purpose

Recommend and install Claude Code plugins based on the developer's tech stack, workflow preferences, and project type. Combine curated catalog matching with optional web search.

## Inputs

You receive the complete Phase 1 context object including: stack, team size, security sensitivity, testing philosophy, and all project details.

### Mode: recommendation

[scan catalog + match capabilities — no install]
1. Read `references/plugin-catalog.md` + state phases listed above.
2. Match phases to plugin capabilities (e.g., auth.strategy=hosted + provider=clerk → suggest `vercel:auth` or `clerk:nextjs` plugin).
3. Compile `{suggested: [...], rationale: "..."}` and return to caller.
4. Caller writes `phases.pluginRecommendation`.

### Mode: install

[read pluginRecommendation → invoke /plugin marketplace install per entry]
1. Read `phases.pluginRecommendation.selected ∪ frontendAddenda`.
2. For each entry, run `/plugin marketplace install <id>`. Capture stdout + exit code.
3. Build `{installed: [...], failed: [{id, reason}], skipped: [...]}`.
4. Return to caller; caller writes `phases.pluginInstall`.

---

The remainder of this skill (Steps 1–5 below) is the detailed reference for both modes. `recommendation` mode runs Steps 1–3 and returns suggestions without installing. `install` mode runs Steps 4–5 starting from the caller-provided `pluginRecommendation.selected` list.

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

**Single-option guard** (per `.claude/rules/ask-user-question-guard.md`): if the matched plugin set collapses to exactly 1 plugin (small project, narrow stack), the multiSelect fails schema validation on first try. In that case, convert to a single-select yes/no — "Install `<plugin-name>`?" — rather than padding with `None / Skip`. Rationale: plugin-discovery is a standalone question, not part of a batched approval. A `None` option in a 1-plugin discovery read is pure noise. When the candidate list is empty (no catalog matches), skip the question entirely and continue to Step 3.

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

Use the shell-level Claude Code CLI — `/plugin` slash commands cannot be invoked from a skill, but `claude plugin …` Bash commands can.

### 4.1 — Build the install plan

For each plugin in the user's selected set, read its row in `references/plugin-catalog.md` and extract:
- `installId` — the `<name>@<marketplace>` token inside backticks in the Marketplace column.
- `marketplaceSource` — the value after `add: \`` in the same cell.

Filter out any plugin whose `installId` ends in `@TODO-verify-marketplace`. For each filtered-out plugin, tell the user:

> Skipping `<plugin-name>` — its marketplace source is unverified in the catalog. To install manually, see the catalog row and verify the source repo, then re-run plugin discovery.

### 4.2 — Add marketplaces (idempotent)

Collect the unique set of `marketplaceSource` values from the plan. For each one, run:

```bash
claude plugin marketplace add <marketplaceSource>
```

Record exit code. A non-zero exit blocks every plugin that depends on this marketplace — mark those plugins as `installStatus: "marketplace-add-failed"` and continue with the remaining marketplaces.

### 4.3 — Install plugins

For each plugin whose marketplace was added successfully:

```bash
claude plugin install <installId> --scope user
```

Record exit code per plugin. Non-zero exit → `installStatus: "install-failed"`. Continue with the next plugin; do not abort the batch.

The default scope is `user` (matches `/plugin install`'s slash default). A future enhancement may expose scope as a wizard knob; for now, hardcode `user`.

### 4.4 — Prompt the user to reload

After all installs complete (success or failure), tell the user:

> Plugins installed. Their skills, agents, and hooks won't be active in this session until you run `/reload-plugins` (or restart Claude Code). I'll verify the installs after you confirm.

Then use `AskUserQuestion` with two options:
- **"I've run /reload-plugins"** → proceed to Step 4b
- **"Skip reload — continue without verification"** → proceed to Step 5 with every installed plugin marked `verified: false`

Do NOT attempt to invoke `/reload-plugins` yourself — it's a slash command and not callable from a skill.

## Step 4b: Verify Installation

(Skipped if the user chose "Skip reload" in 4.4.)

Run:

```bash
claude plugin list --json
```

Parse the JSON. The output shape is an array of objects with these fields (verified against Claude Code CLI as of 2026-05-12):

```json
{
  "id": "<plugin-name>@<marketplace>",
  "version": "x.y.z",
  "scope": "user|project|local",
  "enabled": true,
  "installPath": "/Users/.../<marketplace>/<plugin>/<version>",
  "installedAt": "ISO-8601",
  "lastUpdated": "ISO-8601"
}
```

For each plugin in the install plan, find the entry whose `id` matches its `installId`. Verification passes when **all** of:
- An entry exists
- `enabled === true`
- `version` is non-empty
- `scope` matches the requested scope (`user` by default)

For each plugin set `verified: true|false` accordingly. Plugins that fail verification keep `installStatus: "install-failed"` or get the new status `installStatus: "not-loaded"`.

If `claude plugin list --json` itself errors (non-zero exit or unparseable JSON), tell the user:

> Couldn't read the plugin list — verification skipped. Installed plugins will be passed downstream as unverified.

Mark every plugin `verified: false` and continue.

### Optional: deeper skill-resolution check

For each plugin that passed the `enabled` check, also confirm its child skills are loadable:

```bash
claude plugin details <installId>
```

The output lists component inventory (skills, agents, commands, hooks). If the plugin's expected skills (per the catalog's "Key skills/commands" column) are not present in the inventory, downgrade `verified` to `false` and note `notLoadedSkills: [...]` in the per-plugin record. This catches the "plugin installed but child skill has broken frontmatter" failure mode.

## Step 5: Compile Covered Capabilities

After verification, build the `coveredCapabilities` list using the capability mapping table in `references/plugin-catalog.md`:

1. For each plugin where `verified === true`, look up its capabilities in the "Capability Mapping" table.
2. Combine all capabilities into a deduplicated list.
3. Return to the calling skill (tooling-generation):
   - `installedPlugins[]` — array of objects `{ name, installId, installStatus, verified, version }` for every plugin that was *attempted* (so onboard can see failures, not just successes)
   - `coveredCapabilities[]` — capability strings from verified plugins only

**Why "verified only" for capabilities**: passing capability strings from an unverified install would tell onboard to skip generating agents that — if the plugin is actually broken — leaves the project with no coverage at all. Better to over-generate and let the user manually skip than to under-generate and ship gaps.

This data is passed to onboard headless via `callerExtras`. Without this step, onboard would generate generic agents that shadow the superior plugin versions.

## Key Rules

1. **Never install without consent** — Always present the checklist and wait for selection.
2. **Curated quality first** — The catalog contains vetted plugins. Web search results need quality filtering.
3. **Explain why** — Every recommendation should explain what matched in the developer's context.
4. **Handle failures gracefully** — Plugin install failures are per-plugin, never batch-fatal. Marketplace-add failures cascade only within their own marketplace.
5. **Don't over-recommend** — 5-8 plugins is a good range. Don't overwhelm with 15+ suggestions.
6. **Verify before trusting** — A successful `claude plugin install` exit code only means the install command ran. It doesn't mean the plugin loaded. Step 4b's `enabled === true` check is the actual proof.
7. **Never invoke slash commands from this skill** — `/plugin install` and `/reload-plugins` are user-only. Always use the `claude plugin …` Bash form for installs; always ask the user to type `/reload-plugins` themselves.
8. **Skip TODO marketplaces, don't guess** — Plugins with `@TODO-verify-marketplace` in the catalog must be skipped with a clear user-facing message, never installed blindly.
