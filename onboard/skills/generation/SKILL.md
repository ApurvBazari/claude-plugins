---
name: generation
description: Invoked by the config-generator agent during /onboard:start and /onboard:generate to produce the Claude tooling artifacts. Internal building block; not user-invocable.
user-invocable: false
---

# Generation Skill — Claude Tooling Artifact Generator

You are an expert at generating Claude Code configuration artifacts. You take a codebase analysis report and wizard answers as input, and produce a complete, tailored set of Claude tooling files.

## Purpose

Generate all Claude Code artifacts for a project based on analysis data and developer preferences. Every artifact must be useful, accurate, and maintainable.

## Inputs

You receive:
1. **Codebase Analysis Report** — From the codebase-analyzer agent, or from pre-seeded context in headless mode
2. **Wizard Answers** — Structured JSON from the wizard phase, or from pre-seeded context in headless mode
3. **Project Root Path** — Where to write artifacts

## Headless Mode Guard

When `headlessMode` is `true` in the input context, this skill is being invoked via `/onboard:generate` from an external caller. In headless mode:

- **Skip all interactive steps** — Do not ask the developer any questions, present confirmation prompts, or wait for user input. All decisions have already been made by the caller.
- **Accept pre-seeded inputs as authoritative** — The analysis report and wizard answers provided by the caller are treated identically to data gathered by onboard's own analyzer and wizard. Do not second-guess or re-validate the content beyond basic structural checks.
- **Merge hooks carefully** — The caller may have already written hooks to `.claude/settings.json`. Read the file first and merge onboard's hooks alongside existing entries. This is the most common source of conflicts in headless mode.
- **Record provenance** — Include `headlessMode: true` and the caller's `source` identifier in `onboard-meta.json`.
- **All generation rules still apply** — Artifact order, quality checks, maintenance headers, autonomy cascade, reference guides — everything in this skill applies equally in headless mode. The only difference is the source of inputs and the absence of interactive prompts.

## Maintenance Header

**Every generated file** must start with this header (adapted for the file type):

For Markdown files:
```markdown
<!-- onboard v{VERSION} | Generated: YYYY-MM-DD -->
<!-- MAINTENANCE: Claude, while working in this codebase, if you notice that:
     - The patterns described here no longer match the actual code
     - New conventions have emerged that aren't captured here
     - The project structure has changed in ways that affect these rules
     - Code changes you're currently making should also update this file
     Notify the developer in the terminal that this file may need updating.
     Suggest running /onboard:update to refresh the tooling configuration. -->
```

For JSON files, add a `_generated` field:
```json
{
  "_generated": {
    "by": "onboard",
    "version": "{VERSION}",
    "date": "YYYY-MM-DD"
  }
}
```

**Version resolution**: `{VERSION}` must be read at generation time from `<plugin-root>/.claude-plugin/plugin.json` → `version` field. The plugin root is the directory containing the onboard skill (accessible via `${CLAUDE_PLUGIN_ROOT}` in hook scripts, or by navigating up from the generation skill's location). Never hardcode the version string — always read it from the manifest. Example: if `plugin.json` contains `"version": "1.0.1"`, the maintenance header becomes `<!-- onboard v1.0.1 | Generated: 2026-04-14 -->` and the JSON field becomes `"version": "1.0.1"`.

## Autonomy Cascade

The developer's `autonomyLevel` preference cascades across all generated artifacts. Use this table to determine defaults:

| Aspect | Always-Ask | Balanced | Autonomous |
|--------|-----------|----------|------------|
| **Format/Lint Hooks** | No auto hooks (comment listing available hooks) | Auto-format on Write | Auto-format + auto-lint on Edit |
| **Quality-Gate Hooks** | Profile-dependent, all advisory mode (see Standalone Quality-Gate Hooks) | Profile-dependent, preCommit blocking rest advisory (see Standalone Quality-Gate Hooks) | Profile-dependent, preCommit + featureStart blocking rest advisory (see Standalone Quality-Gate Hooks) |
| **Rule language** | "consider", "discuss with developer" | "should", "recommended" | "must", "always", "never" |
| **Agent tool access** | All agents read-only (output as suggestions) | Reviewers read-only, generators read-write | All agents read-write including Bash |
| **CLAUDE.md rules** | 8-12 extensive items including "check with developer" | 4-6 moderate items | 2-3 hard safety rules only |
| **Skill detail** | Verbose with examples + alternatives + checkpoints | Standard with key examples | Concise, pattern-focused templates |

**Conflict resolution**: When `autonomyLevel` and `codeStyleStrictness` produce conflicting tone verbs, `autonomyLevel` overrides for tone (how assertive the language is), while `codeStyleStrictness` controls quantity (how many rules/checks are generated).

## Artifact Generation Rules

### Effective Plugin List Resolution

Before generating any artifacts, resolve the effective plugin list. This determines whether plugin-aware features (Plugin Integration section, per-directory skill annotations, plugin-aware agent skipping, plugin-referencing quality-gate hooks) are generated.

1. If `callerExtras.installedPlugins` is present and non-empty → use it as `effectivePlugins` (headless mode — caller-provided data is authoritative)
2. Else if `detectedPlugins.installedPlugins` is present and non-empty → use it as `effectivePlugins` (standalone mode — self-detected via `references/plugin-detection-guide.md`)
3. Else → `effectivePlugins` is empty (no plugins available)

Similarly resolve:
- `effectiveCoveredCapabilities` from `callerExtras.coveredCapabilities` or `detectedPlugins.coveredCapabilities`
- `effectiveQualityGates` from `callerExtras.qualityGates` or `detectedPlugins.qualityGates`
- `effectivePhaseSkills` from `callerExtras.phaseSkills` or `detectedPlugins.phaseSkills`

Record the resolution source as `pluginSource`: `"callerExtras"` | `"self-detected"` | `"none"`.

Throughout this skill, **every reference to `callerExtras.installedPlugins` should be read as `effectivePlugins`**, and similarly for the other resolved fields. The source is transparent to generation logic — all downstream rules apply identically regardless of how the plugin list was obtained.

### Root CLAUDE.md

Follow `references/claude-md-guide.md` for structure and best practices.

- **100-200 lines max** — Concise but comprehensive (excluding regeneratable sections like Plugin Integration)
- **Sections**: Project overview, tech stack summary, build/test/lint/deploy commands, key conventions, critical rules, directory structure overview
- **Include `@imports`** where subdirectory CLAUDE.md files are created
- **Tone matches autonomy level**: "always-ask" = more guardrails and "check with developer" language; "autonomous" = more empowering and "go ahead" language; "balanced" = mix
- **Formatter conventions**: Include formatter settings (from Prettier/Black/rustfmt configs) as explicit conventions in Key Conventions section rather than as path-scoped rules
- **Commands section**: List every discovered build/test/lint/deploy command with brief descriptions
- **Ecosystem plugins section** (if any were set up): If `ecosystemPlugins` is present in wizard answers, add a brief "Ecosystem Plugins" section noting which plugins are active (e.g., "notify: system notifications on task completion"). Include relevant commands (`/notify:check`).
- **Plugin Integration section** (if `effectivePlugins` is non-empty): Generate a dedicated `## Plugin Integration` section that documents the installed Claude Code plugins and how to use them on this specific project. See "Plugin Integration Section + Per-Directory Skill Annotations" below for the full spec.

#### Plugin Integration Section + Per-Directory Skill Annotations

When `effectivePlugins.length > 0`, emit a marker-delimited `## Plugin Integration` section into the root CLAUDE.md, and extend each generated subdirectory CLAUDE.md with a `## Skill recommendations` block. The full spec — the `<!-- onboard:plugin-integration:start/end -->` template, the surface-verification invariant, the R1-R6 disambiguation rules, the 8 content rules, graceful degradation (EC8), and the per-directory skill-annotation marker format — is in `references/plugin-integration-section.md`. Apply it verbatim; the emitted markers and template text are load-bearing for `/onboard:update` regeneration.

### Subdirectory CLAUDE.md Files

Follow `references/claude-md-guide.md` for content guidance.
- **Create when all three criteria are met**: (1) directory contains a meaningful share of source files, (2) has distinct conventions not covered by root, (3) represents an architectural boundary
- **File share thresholds scaled by project size and profile**:

  | Project size | Minimal profile | Standard profile | Comprehensive profile |
  |---|---|---|---|
  | Small (<100 files) | >40% | >20% | >10% |
  | Medium (100-500 files) | >20% | >10% | >5% |
  | Large (>500 files) | >10% | >5% | >2.5% |

  Standard profile uses the base thresholds. Comprehensive profile halves them (more subdirectory CLAUDE.md files for deeper coverage). Minimal profile doubles them (fewer candidates). When profile is "custom", use the standard thresholds unless the developer explicitly requests more or fewer coverage.
- **Monorepo packages are automatic candidates** — each package is an architectural boundary by definition
- **Recognized architecture pattern layers are automatic candidates** — same treatment as monorepo packages. When the analysis report identifies an architecture pattern (e.g., "Clean Architecture" in the Project Structure or Architecture sections), or when directory names match known patterns, those layer directories qualify by architectural role regardless of file-share thresholds. Known patterns:
  - **Clean Architecture**: `data/`, `domain/`, `presentation/`, `service/`, `di/` (or `injection/`)
  - **MVVM/MVC/MVP**: `model/` (or `models/`), `view/` (or `views/`), `viewmodel/` (or `viewmodels/`), `controller/` (or `controllers/`), `presenter/` (or `presenters/`)
  - **Hexagonal**: `ports/`, `adapters/`, `core/`
  - **Feature-based**: each feature module directory (identified by analysis report's module boundaries)
  - **Backend layered**: `controllers/`, `services/`, `repositories/`, `middleware/`

  Pattern matching is case-insensitive and works at any nesting depth (e.g., `app/src/main/java/com/example/data/` matches the `data/` pattern). If the analysis report explicitly identifies the architecture pattern, use that to determine which directories are layer candidates. If the report does not name the pattern, fall back to directory name matching against the patterns above. When both architecture patterns and file-share thresholds identify the same directory, it is just one candidate (no duplicates).
- **Typical candidates**: `src/components/`, `src/api/`, `src/lib/`, `app/`, `tests/`, `scripts/`, per-package in monorepos
- **Architecture-pattern candidates**: `data/`, `domain/`, `presentation/`, `service/`, `di/`, `model/`, `view/`, `viewmodel/`, `controller/`, `ports/`, `adapters/`, `core/`, `repositories/`, `middleware/` (when detected as part of a recognized architecture pattern)
- **Always confirm** candidate directories with the developer before creating subdirectory CLAUDE.md files
- **Content**: Conventions specific to that directory, patterns to follow, common mistakes to avoid
- **Keep short** — 30-80 lines each

### Path-Scoped Rules (.claude/rules/*.md)

Follow `references/rules-guide.md` for patterns and YAML frontmatter.

- **YAML frontmatter** with `paths:` filter for scoping
- **Only generate rules relevant to the detected stack**
- **Categories**:
  - `testing.md` — Test patterns, what to test, coverage expectations
  - `api.md` — API endpoint conventions, validation, error handling (if backend)
  - `components.md` — Component patterns, naming, structure (if frontend)
  - `security.md` — Security rules (if elevated/high security)
  - `styling.md` — Styling conventions (if specific approach detected)
- **Config-derived rules**: When the analysis report includes a `Config & Pattern Analysis` section, use the extracted configs and observed patterns to generate rules that reflect the project's actual enforced standards. Follow the "Deriving Rules from Config Analysis" section in `references/rules-guide.md`. Never generate generic template rules when project-specific config data is available.
- **Rule strictness matches `codeStyleStrictness`**: relaxed = guidelines, moderate = should, strict = must
- **Plugin cross-references** (`allowPluginReferences` flag): When `effectivePlugins` is non-empty, rules MAY reference installed plugins instead of duplicating their guidance. For example, `testing.md` can say *"This project uses `superpowers:test-driven-development` — follow its red/green/refactor loop"* instead of restating TDD guidance inline. This is controlled by a generation flag `allowPluginReferences: true` (default `true` when `effectivePlugins` is non-empty, else `false`). Before referencing a plugin, verify it's in `effectivePlugins` — never create dangling refs. If a rule references a plugin and that plugin is later uninstalled, `/onboard:update` should refresh the rule to its standalone version.

### Skills (.claude/skills/)

Follow `references/skills-guide.md` for SKILL.md structure AND § Frontmatter Reference for the full field surface the generator emits.

- **Stack-specific**: e.g., React component skill, Django model skill, Go package skill
- **Workflow-specific**: Based on detected patterns and pain points
- **Each skill** has `SKILL.md` and optional `references/` directory
- **Focus on the 2-3 most valuable skills** based on pain points and primary tasks

### Skill Selection Priority

When choosing which 2-3 skills to generate, use this weighting:

1. **Pain point match** (highest) — Skill directly addresses a developer-reported pain point
2. **Detected stack fit** — Skill matches a framework/tool found in analysis (e.g., React component skill for React projects)
3. **Workflow gap** — Skill fills a gap in the development workflow (e.g., deployment skill when deploy is manual)

**Combined scoring**: A skill that matches both a pain point AND the detected stack gets the highest combined score. When more than 3 candidate skills exist, pain point matches always win over stack-based candidates.

### Skill Frontmatter Emission

Every generated `SKILL.md` carries YAML frontmatter — `name`, `description`, `user-invocable`/`disable-model-invocation`, plus up to six optional fields (`allowed-tools`, `model`, `effort`, `paths`, `context`, `agent`). The full 7-step emission procedure (archetype classification, wizard-tuning composition, validation pass, batched confirmation, write, drift snapshot, `skillStatus` telemetry) plus the verbatim snapshot/`skillStatus` JSON shapes and `source` provenance values are in `references/skill-frontmatter-emission.md`. Follow it verbatim.

### Agents (.claude/agents/)

Follow `references/agents-guide.md` for agent file structure, archetypes, and frontmatter reference.

**Scale with team size**:
- Solo + superpowers installed: 1 agent (code-reviewer only — superpowers handles TDD)
- Solo + no superpowers: 2 agents (code-reviewer, tdd-test-writer)
- Small team (2-5): 2-3 agents (add security-checker if elevated security)
- Medium+ team (6+): 3-4 agents (add documentation-writer, architecture-reviewer, cross-package reviewer for monorepos)

Each agent is a single markdown file with YAML frontmatter and free-form instructions body. The `name` frontmatter field must match the filename stem.

#### Plugin-Aware Agent Generation (Headless Mode)

When `effectiveCoveredCapabilities` is non-empty, **skip agents whose capability is already covered by an installed plugin**. Project-level agents in `.claude/agents/` take priority over plugin agents, so generating a generic `code-reviewer.md` would shadow a superior plugin implementation.

**Capability → Agent skip map:**

| If `coveredCapabilities` includes | Skip generating |
|---|---|
| `code-review` | `code-reviewer.md` |
| `test-generation` | `tdd-test-writer.md` |
| `security-audit` | `security-checker.md` |
| `feature-development` | `feature-builder.md` |
| `documentation` | `documentation-writer.md` |

**What to generate instead**: Focus on gap-filling, project-specific agents that no plugin covers — e.g., a `db-migration.md` agent for Prisma projects, or a stack-specific scaffolding agent. These provide value that generic plugins cannot.

**When `effectiveCoveredCapabilities` is empty**: Generate all agents as usual.

### Agent Frontmatter Emission

Every generated agent file carries YAML frontmatter — `name`, `description`, plus up to nine optional fields (`tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `effort`, `isolation`, `color`, `background`). The full 7-step emission procedure (archetype classification, wizard-tuning composition, validation pass incl. the HARD-FAIL frontmatter check, batched confirmation, write, re-read drift snapshot, `agentStatus` telemetry) plus the verbatim snapshot/`agentStatus` JSON shapes and `source`/`skipped.reason` values are in `references/agent-frontmatter-emission.md`. Follow it verbatim.

### Plugin-Aware TDD Workflow + Recommended Plugins

All projects use TDD (red-green-refactor); generation adapts to which workflow plugins are installed (resolve via `effectivePlugins`). The superpowers×feature-dev strategy matrix, the key principles, the plugin-recommendation message shown during generation, and the verbatim `## Recommended Plugins` CLAUDE.md template (emitted only when plugins are missing) are in `references/tdd-workflow-and-recommended-plugins.md`. Emit the `## Recommended Plugins` block verbatim.

### MCP Servers (.mcp.json) — Phase 7a

Follow `references/mcp-guide.md` for emission rules, catalog, and transport shapes. The Phase-7a generation contract — the 4 firing paths (A/B/C/SKIP), inputs, telemetry contract, the 8 emission steps (detect → pre-existing check → write `.mcp.json` → snapshot → `mcpStatus` → `mcp-setup.md` → auto-install → stdout summary), the verbatim `mcpStatus` JSON shape, and the Auto-install Plugins sub-procedure — is in `references/phase-7a-mcp.md`. Apply it verbatim. Runs after Recommended Plugins copy and before Hooks.

### Output Styles (.claude/output-styles/) — Phase 7b

Follow `references/output-styles-guide.md` (archetype inference, frontmatter schema, `settings.local.json` merge rules) and `references/output-styles-catalog.md` (5 body templates). The Phase-7b generation contract — the 5 firing paths, inputs, telemetry contract, the 11 emission steps, the `settings.local.json` 4-case merge table, and the verbatim snapshot/`outputStyleStatus` JSON shapes plus enum values — is in `references/phase-7b-output-styles.md`. Apply it verbatim. Runs after Phase 7a and before Hooks.

### LSP Plugin Recommendations — Phase 7c

Follow `references/lsp-plugin-catalog.md` for the 12-entry language→plugin mapping. The Phase-7c generation contract — the 5 firing paths, inputs, telemetry contract, the 7 emission steps (detect via `detect-lsp-signals.sh` → resolve selected → CLAUDE.md subsection → metadata-first install → snapshot → `lspStatus` schema → stdout summary), and the verbatim snapshot/`lspStatus` JSON shapes — is in `references/phase-7c-lsp.md`. Apply it verbatim. Onboard emits NO project-level `.lsp.json`. Runs after Phase 7b and before Hooks.

### Built-in Claude Code Skills — Phase 7d

Follow `references/built-in-skills-catalog.md` for the 9-skill catalog, tier classification, detection signals, and stack-specific example templates. The Phase-7d generation contract — the 4 firing paths, inputs, telemetry contract (primary user of the `"documented"` status), the 7 emission steps (detect → resolve accepted → placement path → compose subsection → snapshot → telemetry → stdout summary), and the verbatim snapshot/`builtInSkillsStatus` JSON shapes plus `<!-- onboard:builtin-skills:start/end -->` marker rules — is in `references/phase-7d-builtin-skills.md`. Apply it verbatim. Runs after Phase 7c and before Hooks.

### Hooks (.claude/settings.json)

Follow `references/hooks-guide.md` for hook configuration.

- **Merge with existing settings.json** if one exists — never overwrite
- **Common hooks**:
  - Auto-format on Write (if formatter detected: prettier, black, rustfmt, gofmt)
  - Lint check on Edit (if linter detected: eslint, ruff, clippy)
- **Only add hooks for tools that are actually installed and configured**

#### Quality-Gate, Standalone, Advanced-Event, and Utility Hooks

When `effectiveQualityGates` is present (or, in the standalone case, derived from `selectedPreset` + `autonomyLevel`), generate boundary-enforcement hooks that reinforce the CLAUDE.md Plugin Integration discipline. The complete hook-generation spec is in `references/hooks-generation.md` — apply it verbatim. It covers:

- **Quality-Gate Hooks** — the 4 hook categories (sessionStart / preCommit / featureStart / postFeature), mode semantics, autonomyLevel downgrade, plugin-availability checks, merge semantics, and the full `hookStatus` telemetry scope + the verbatim canonical `hookStatus` JSON shape (including the `<Event>[:<Matcher>][:<Type>]` key format and counting rules).
- **O6 — SessionStart reminder hook** — the verbatim `plugin-integration-reminder.sh` script template (with adaptive suppression) + settings.json entry.
- **O7 — Feature-start detector PreToolUse hook** — the 8 mandatory behavioral invariants, the verbatim `feature-start-detector.sh` reference implementation (incl. the worktree-offer addon), the settings.json entry, regex construction, skip conditions, and the load-bearing shell-options rationale.
- **Standalone Quality-Gate Hooks** (no plugins) — profile/autonomy mode tables, standalone hook content, script conventions, telemetry, merge behavior.
- **Advanced Event Hooks** (9 events) — input sources, per-event inference rules, per-event type defaults, the 11-rule Hook Type Validation table, artifact-per-type table, generation rules, and wizard opt-in plumbing.
- **Utility Hooks** (non-telemetry) — the WorktreeCreate init.sh auto-runner.

All script templates referenced there resolve to `references/hooks-guide.md` § templates. Preserve every emitted script and JSON shape verbatim.

### Collaboration Artifacts

Follow `references/collaboration-guide.md` for templates and conventions.

**Always generate** regardless of team size — solo developers benefit from consistency:

- **PR Template** (`.github/PULL_REQUEST_TEMPLATE.md`) — Structured PR template with summary, type-of-change checkboxes, and checklist. Add stack-specific items based on analysis. Add security items if `securitySensitivity` is elevated/high. Include a note for the developer to customize after reviewing.
- **Commit Conventions** (`.claude/rules/commit-conventions.md`) — Path-scoped rule (`paths: **`) for Conventional Commits format. Strictness of language matches `codeStyleStrictness`.
- **Shared vs Local Settings Guidance** — Include a section in root CLAUDE.md explaining `.claude/settings.json` (shared, committed) vs `.claude/settings.local.json` (personal, gitignored).
- **Gitignore Entry** — If `.gitignore` exists in the project root, append these entries (if not already present): `.claude/settings.local.json` (personal settings) and `CLAUDE.md.pre-onboard` (backup files left by merge-aware CLAUDE.md generation). This ensures personal settings and onboard backup artifacts are never committed.

### Metadata (.claude/onboard-meta.json)

Always generate this file with:
- Plugin version
- Timestamp
- Wizard answers (structured)
- List of generated artifacts
- Model recommendation and whether user approved
- Plugin detection results: `detectedPlugins` object — always populated from `effectivePlugins`, `effectiveCoveredCapabilities`, `effectiveQualityGates`, `effectivePhaseSkills` (resolved per § Effective Plugin List Resolution). Populate regardless of `pluginSource` so that `onboard:update` has a single canonical baseline to diff against. When `effectivePlugins` is empty, write `detectedPlugins: { installedPlugins: [], coveredCapabilities: [], qualityGates: {}, phaseSkills: {} }` — do not omit the field.
- Plugin source: `pluginSource` — `"callerExtras"` | `"self-detected"` | `"none"` — records how the effective plugin list was resolved (headless callers still get `detectedPlugins` mirrored for drift-detection continuity)

## Quality Checklist

Before finishing generation, run the full pre-exit verification checklist in `references/quality-checklist.md` — every item must pass. It ends with the **pre-exit self-audit**: all 4 Phase 7 telemetry keys (`mcpStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`) must exist in `onboard-meta.json`, or hard-fail before returning.

## Extended Generation (Enriched Mode)

When the wizard or headless context includes extended preferences (CI/CD, harness, evolution, verification), generate these additional artifacts. These are universally useful — not limited to any specific caller.

### CI/CD Pipelines (if `willDeploy` and no existing CI/CD detected)

Follow `references/ci-cd-templates.md`:
- `.github/workflows/ci.yml` — application CI (lint, test, build, deploy)
- `.github/workflows/tooling-audit.yml` — structural drift checks + semantic analysis
- `.github/workflows/pr-review.yml` — AI-powered PR review (claude-code-action)
- `.github/scripts/audit-tooling.sh` — bundled audit script
- `.github/dependabot.yml` or `renovate.json` (if automated dep management)

### Harness Artifacts (if `enableHarness`)

Follow `references/harness-design.md`:
- `docs/progress.md` — cross-session progress tracker
- `docs/HARNESS-GUIDE.md` — multi-session development guide
- `docs/verification-reports/` — directory for evaluator reports
- Session startup protocol reference in CLAUDE.md
- Test immutability rule in CLAUDE.md
- Context anxiety mitigation in CLAUDE.md

### Auto-Evolution Hooks (if `enableEvolution`)

Follow `references/evolution-hooks-guide.md`:
- FileChanged hooks for drift detection
- SessionStart hook for drift summary
- Copy detection scripts to `.claude/scripts/`
- Initialize `.claude/greenfield-drift.json`

### Sprint Contracts (if `enableSprintContracts`)

Follow `references/sprint-contracts.md`:
- `docs/sprint-contracts/` directory
- First sprint contract (negotiated or auto-generated)

### Agent Teams (if `enableTeams`)

Follow `references/agent-teams-guide.md`:
- Team quality hooks (TaskCreated, TaskCompleted)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json
- TDD Feature Development team composition (always included when teams enabled)

### TDD Workflow Artifacts (Always Generated)

TDD is the standard testing approach for all onboarded projects. These artifacts are always generated, adapting content based on installed plugins (see Plugin-Aware TDD Workflow above):

1. **CLAUDE.md "Development Workflow" section** — Describes the combined feature-dev + superpowers TDD phased approach. Adapts references based on installed plugins.
2. **testing.md rule** — Mandates red-green-refactor with the Iron Law. Content varies by plugin availability (see `references/rules-guide.md` TDD Testing Rule section).
3. **Standalone TDD skill** (only if superpowers NOT installed) — Generate `.claude/skills/tdd-workflow/SKILL.md` with red-green-refactor cycle, verification checklist, and common rationalizations.
4. **TDD test-writer agent** (only if superpowers NOT installed) — Generate `.claude/agents/tdd-test-writer.md` following `references/agents-guide.md` TDD variant.
5. **TDD Feature Development team** (only if `enableTeams`) — Follow `references/agent-teams-guide.md` TDD team composition.
6. **PR template** — Checklist includes "Tests written first (TDD), all pass".
7. **Plugin recommendations** — If superpowers or feature-dev is missing, add "Recommended Plugins" section to CLAUDE.md with install commands.

## Round 4 — Personas, Domain Model, Risk Reconciliation, mode, risks

Onboard 2.0 alpha.5+ accepts up to 11 phase blocks plus a top-level `risks[]` array and a `mode` block. The R4 additions (`phases.personas`, `phases.domainModel`, `risks[]`, `mode`) are all **optional** — if absent, generation behaves identically to alpha.4 (layered, not gated). The full per-block generation behaviors (persona-aware agents, entity-aware schemas/routes, `docs/risks.md` emission, `mode.coupling`/`mode.depth` gating), the mandatory backward-compatibility rules, and the state-shape contract for upstream callers are in `references/round-4-phase-blocks.md`. Apply it verbatim.

## Round 5 — deterministic outputs from featureRoadmap + schemaDraftReview

When the v2 context carries populated R5 phases, onboard writes the feature roadmap artifacts (`docs/feature-list.json`, `docs/sprint-contracts/sprint-1.json`) and schema/contract files **deterministically** instead of via interactive prompts; pre-R5 contexts fall back to the interactive flow. The run conditions, the verbatim `docs/feature-list.json` + `sprint-1.json` field maps, the schema/contract output-path resolution table (db/api/event × language × outputStrategy), atomic-write rules, backward-compatibility, and failure modes are in `references/round-5-deterministic-outputs.md`. Apply it verbatim.

## Reference Files

### Core (always used)
- `references/claude-md-guide.md` — CLAUDE.md structure and best practices
- `references/rules-guide.md` — Path-scoped rules patterns
- `references/hooks-guide.md` — Hook configuration patterns (format, lint)
- `references/mcp-guide.md` — MCP server emission rules, catalog, drift handling
- `references/skills-guide.md` — Skill creation patterns
- `references/agents-guide.md` — Agent creation patterns
- `references/collaboration-guide.md` — PR template, commit conventions
- `references/aci-design-guide.md` — Agent-Computer Interface best practices (tool design, error handling, ground truth)

### Extended (used when enriched features enabled)
- `references/harness-design.md` — Long-running development harness pattern
- `references/ci-cd-templates.md` — GitHub Actions pipeline templates
- `references/evolution-hooks-guide.md` — Auto-evolution hook patterns
- `references/sprint-contracts.md` — Sprint contract format and negotiation
- `references/agent-teams-guide.md` — Agent team compositions and quality hooks
- `references/worktree-workflow.md` — Proactive worktree workflow using Claude Code native tools (EnterWorktree/ExitWorktree)

### Emission specs (verbatim — extracted from this skill)
These carry the verbatim artifact templates and long emission enumerations for the stubbed sections above. Load the matching one when generating that artifact:
- `references/plugin-integration-section.md` — `## Plugin Integration` section + per-directory Skill recommendations
- `references/skill-frontmatter-emission.md` — 7-step SKILL.md frontmatter emission + `skillStatus`
- `references/agent-frontmatter-emission.md` — 7-step agent frontmatter emission + `agentStatus`
- `references/tdd-workflow-and-recommended-plugins.md` — plugin-aware TDD matrix + `## Recommended Plugins` template
- `references/phase-7a-mcp.md` — MCP `.mcp.json` emission (Phase 7a) + auto-install
- `references/phase-7b-output-styles.md` — output-styles emission (Phase 7b) + settings.local.json merge
- `references/phase-7c-lsp.md` — LSP plugin recommendations (Phase 7c)
- `references/phase-7d-builtin-skills.md` — built-in Claude Code skills (Phase 7d)
- `references/hooks-generation.md` — quality-gate / O6 / O7 / standalone / advanced-event / utility hooks + `hookStatus`
- `references/quality-checklist.md` — pre-exit generation verification checklist
- `references/round-4-phase-blocks.md` — personas / domainModel / risks / mode generation behaviors
- `references/round-5-deterministic-outputs.md` — deterministic feature-list / sprint-1 / schema-contract writes

## Key Rules

- **Headless mode prohibits all interactive prompts** — when `headlessMode: true`, every decision has been pre-made by the caller. Never ask the developer a question, show a confirmation prompt, or wait for input. Treat caller inputs as authoritative.
- **Version string is always read from `plugin.json`, never hardcoded** — the maintenance header `{VERSION}` must be resolved at generation time from the manifest. A hardcoded literal will become stale without warning.
- **`settings.json` is always read before writing** — hooks are merged alongside existing entries, never overwriting the file. This is the most common headless-mode conflict source.
- **Plugin-covered capabilities are never re-generated** — before generating any agent, check `coveredCapabilities`. An agent that shadows an installed plugin must be skipped entirely, not generated with a note.
- **Standalone TDD artifacts are conditional on `superpowers` absence** — the standalone TDD skill and TDD test-writer agent are only generated when the superpowers plugin is not installed. Never generate both; they conflict.
