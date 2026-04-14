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

When `headlessMode` is `true` in the input context, this skill is being invoked via `/onboard:generate` from an external caller (e.g., the Forge plugin). In headless mode:

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
- **Ecosystem plugins section** (if any were set up): If `ecosystemPlugins` is present in wizard answers, add a brief "Ecosystem Plugins" section noting which plugins are active (e.g., "notify: system notifications on task completion"). Include relevant commands (`/notify:status`).
- **Plugin Integration section** (if `effectivePlugins` is non-empty): Generate a dedicated `## Plugin Integration` section that documents the installed Claude Code plugins and how to use them on this specific project. See "Plugin Integration Section Generation" below for the full spec.

#### Plugin Integration Section Generation

When `effectivePlugins.length > 0`, emit a `## Plugin Integration` section into the root CLAUDE.md. This section must be delimited by section markers so it can be safely regenerated by `/onboard:update` without clobbering user edits elsewhere in the file:

```markdown
<!-- onboard:plugin-integration:start -->
## Plugin Integration

This project uses the following Claude Code plugins. Use them consistently.

### Research & brainstorming (MANDATORY first step for any new feature)
...
### Core discipline (applies to all phases after research)
...
### Per-feature workflow
...
### Commit discipline
...
### Quality gates
...
### Ecosystem
...
<!-- onboard:plugin-integration:end -->
```

**Content rules**:

1. **Research & brainstorming** (always first subsection when `superpowers` is in `installedPlugins`):
   - Document `/superpowers:brainstorming` as the hard-gated first step for any new feature
   - Reference `/superpowers:dispatching-parallel-agents` for parallel web research
   - Reference `context7` only if it's in `installedPlugins` (never fabricate)
   - Include the "design can be a few sentences for trivial work" caveat so developers don't feel trapped
   - Point at where research outputs are saved (e.g., `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`)
2. **Core discipline** — `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `superpowers:systematic-debugging` (only include ones whose plugin is installed)
3. **Per-feature workflow** — `feature-dev:code-architect`, `code-explorer`, `code-reviewer` (only if `feature-dev` is installed)
4. **Commit discipline** — `/commit`, `/commit-push-pr` (only if `commit-commands` is installed)
5. **Quality gates** — `code-review:code-review`, `pr-review-toolkit:review-pr`, `claude-md-management:revise-claude-md` (only ones whose plugin is installed)
6. **Ecosystem** — `hookify`, `security-guidance` (only ones whose plugin is installed)

**Graceful degradation (EC8)**: When `superpowers` is NOT in `installedPlugins`, the "Research & brainstorming" subsection falls back to a generic version that recommends built-in `WebSearch`/`WebFetch` and a manual-discussion protocol. Do **not** reference `/superpowers:brainstorming` in the fallback — it would be a broken command. Add a note suggesting users install superpowers for the full experience.

**Tone**: rich narrative voice, not a bulleted list of plugin names. Every subsection should answer "when do I use this?" tied to the project's actual tech stack.

**When `effectivePlugins` is empty**: Skip this section entirely. Do not generate a stub or placeholder.

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

#### Per-Directory Skill Annotations (Plugin-Aware)

When `effectivePlugins.length > 0`, extend each generated subdirectory CLAUDE.md with a `## Skill recommendations` block that maps the directory's role to installed-plugin skills. The block is additive — it supplements the directory's conventions, it does not replace them.

**Rules**:

1. **Only add the block when** an installed plugin's capability meaningfully applies to the directory's role. Never stub "Skill recommendations: none". Directories with no matching plugin capability get no block.
2. **Derive mapping from** (a) directory role (identified by config-generator: `domain`, `parser`, `data-layer`, `compose-ui`, `api`, `tests`, `scripts`, etc.), and (b) `effectiveCoveredCapabilities`.
3. **Brainstorming first** (when superpowers is installed): every annotation that invites new code creation must reference `/superpowers:brainstorming` as the entry point — e.g., *"Before adding a new Parser, run `/superpowers:brainstorming` to explore approaches."*
4. **Be specific** about *when* to invoke each skill. Vague references like "use feature-dev" are not helpful; *"use `feature-dev:code-architect` when drafting a new Parser contract, then TDD via `superpowers:test-driven-development`"* is.
5. **Don't repeat root** — the subdirectory block assumes the reader has already seen the root Plugin Integration section.

**Example annotations**:

- `domain/parser/CLAUDE.md` → *"When adding a new parser implementation, run `/superpowers:brainstorming` first to confirm the design with the user, then use `feature-dev:code-architect` to draft the contract, then `superpowers:test-driven-development` for the test harness."*
- `ui/compose/CLAUDE.md` → *"For new screens, run `/superpowers:brainstorming` to explore layouts, then `frontend-design:frontend-design` to avoid generic AI aesthetics. Follow TDD via `superpowers:test-driven-development`."*
- `data/db/CLAUDE.md` → *"Schema changes must update Room's exported schemas; run `/code-review:code-review` before committing migrations."*

**Graceful degradation**: If `effectivePlugins` is empty, generate subdirectory CLAUDE.md files as usual without the Skill recommendations block. See `references/claude-md-guide.md` for the block format and additional examples.

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

Follow `references/skills-guide.md` for SKILL.md structure.

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

### Agents (.claude/agents/)

Follow `references/agents-guide.md` for agent file structure.

- **Model field left empty** — Comment says "set your preferred model"
- **Scale with team size**:
  - Solo + superpowers installed: 1 agent (code-reviewer only — superpowers handles TDD)
  - Solo + no superpowers: 2 agents (code-reviewer, tdd-test-writer)
  - Small team: 2-3 agents (add security-checker if elevated security)
  - Large team: 3-4 agents (add documentation-writer, architecture-reviewer)
- **Each agent** is a single markdown file with clear instructions, allowed tools, and purpose

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

### Plugin-Aware TDD Workflow

All projects use TDD (red-green-refactor). Generation adapts based on which workflow plugins are installed. Resolve installed plugins from `effectivePlugins` (see Effective Plugin List Resolution above).

| superpowers? | feature-dev? | Strategy |
|---|---|---|
| Yes | Yes | Reference both: `superpowers:test-driven-development` for implementation, `feature-dev` phases for discovery/design/review. No standalone TDD artifacts. TDD Feature Development team if teams enabled. |
| Yes | No | Reference superpowers TDD skill in CLAUDE.md + testing.md. Standalone workflow guidance for discovery/design/review phases. Recommend installing feature-dev. |
| No | Yes | Reference feature-dev for phases 1-4 & 6. Generate standalone TDD skill + TDD test-writer agent. Recommend installing superpowers. |
| No | No | Recommend both plugins. Fully self-contained: standalone TDD skill, TDD test-writer, inline workflow guidance. |

**Key principles**:
- Never duplicate what an installed plugin provides
- When a plugin is missing, recommend it AND generate standalone fallback
- Add "Recommended Plugins" section to CLAUDE.md when any plugin is missing
- When superpowers is installed, its TDD skill is authoritative — do not generate a competing `.claude/skills/tdd-workflow/SKILL.md`

**Plugin recommendation message** (shown during generation when plugins are missing):

> For the best TDD workflow, install these plugins:
>
> - **superpowers** (`obra/superpowers`) — Full TDD skill with red-green-refactor enforcement, verification gates, and anti-pattern detection. Install: `claude plugins add obra/superpowers`
> - **feature-dev** (official Anthropic plugin) — Structured feature development with code-explorer, code-architect, and code-reviewer agents. Install: `claude plugins add anthropic/feature-dev`
>
> Generating standalone TDD artifacts as fallback...

Only show recommendations for plugins that are actually missing. If both are installed, skip this entirely.

**CLAUDE.md "Recommended Plugins" section** (only when plugins are missing):

```markdown
## Recommended Plugins

This project uses TDD. Install these plugins for the best workflow:

- **superpowers** (`obra/superpowers`) — Full TDD skill with red-green-refactor
  enforcement, verification gates, and testing anti-patterns guide.
- **feature-dev** (official Anthropic plugin) — Structured feature development
  with code-explorer, code-architect, and code-reviewer agents.

After installing, re-run `/onboard:init` to upgrade from standalone TDD
artifacts to the integrated plugin-based workflow.
```

### Hooks (.claude/settings.json)

Follow `references/hooks-guide.md` for hook configuration.

- **Merge with existing settings.json** if one exists — never overwrite
- **Common hooks**:
  - Auto-format on Write (if formatter detected: prettier, black, rustfmt, gofmt)
  - Lint check on Edit (if linter detected: eslint, ruff, clippy)
- **Only add hooks for tools that are actually installed and configured**

#### Quality-Gate Hooks (from `effectiveQualityGates`)

When `effectiveQualityGates` is present (from either `callerExtras.qualityGates` in headless mode or `detectedPlugins.qualityGates` in standalone mode with detected plugins), generate boundary-enforcement hooks that reinforce the CLAUDE.md Plugin Integration discipline. Four hook categories are supported, each driven by a field on the `qualityGates` object:

| Field | Event | Default mode | What it does |
|---|---|---|---|
| `sessionStart` | `SessionStart` | `advisory` | Emit a ≤ 3-line reminder at session start pointing to brainstorming + root CLAUDE.md § Plugin Integration |
| `preCommit` | `Stop` / `PreToolUse:Bash(git commit*)` | `blocking` | Run `code-review` / `verification-before-completion` before any commit lands; fail hard if issues found |
| `featureStart` | `PreToolUse:Write` | `advisory` | Non-blocking reminder when Claude creates a new file in a `criticalDirs` path (see O7) |
| `postFeature` | `Stop` / session-end | `advisory` | Nudge toward `claude-md-management:revise-claude-md` at phase end |

**Mode semantics**:
- `mode: "blocking"` → generated hook script exits **2** with stderr feedback. Claude sees the block as a tool error and cannot complete the action without addressing it.
- `mode: "advisory"` → generated hook script exits **0** with stdout. Claude sees the message in-transcript but continues.

**Defaults by field**: `preCommit` → `blocking`; everything else → `advisory`.

**autonomyLevel downgrade**: When the mapped `autonomyLevel` is "always-ask" (exploratory equivalent), downgrade all `preCommit[].mode` values to `advisory`. Standard/autonomous retain blocking. This downgrade is mechanical — no heuristics.

**Plugin availability check**: Before generating a hook entry for a `preCommit` / `postFeature` skill reference, verify the referenced plugin is actually in `effectivePlugins`. If missing, skip that hook entry silently and append a warning to `onboard-meta.json` under `warnings[]`. Never fail the generation.

**Merge semantics**: All quality-gate hooks merge into `.claude/settings.json` following the existing merge strategy (see `references/hooks-guide.md` § Settings Merge Strategy). If a hook with the same matcher/event already exists, skip don't duplicate.

**Hook Status Telemetry**: While walking through the 4 hook categories (`sessionStart`, `preCommit`, `featureStart`, `postFeature`), onboard MUST record what was planned, what was actually generated, and what was skipped (and why) into a structured `hookStatus` object. This object is:

1. Returned from `/onboard:generate` in the result summary (see `onboard/commands/generate.md` § Step 5)
2. Recorded inside `.claude/onboard-meta.json` under the top-level `hookStatus` key
3. Mirrored by forge into `.claude/forge-meta.json.generated.toolingFlags.hookStatus` (see `forge/skills/tooling-generation/SKILL.md` § Step 4)

This telemetry enables `/forge:status` to report "X/Y hooks wired" and lays the foundation for future adaptive behaviors (e.g. suppress SessionStart reminder after the user dismissed it N times).

**Scope boundary** (load-bearing — read this carefully): `hookStatus` tracks **only** hooks derived from `callerExtras.qualityGates`. Pre-existing format/lint hooks (Prettier, ESLint, Black, rustfmt, etc.), forge-internal hooks (like `forge-evolution-check.sh`), and any other non-Plugin-Integration hooks are **out of scope** for this telemetry. They still get written to `.claude/settings.json` via the normal merge path, but they do **not** appear in `hookStatus.planned` or `hookStatus.generated`. This keeps Plugin Integration Coverage reporting clean — `/forge:status` should never show a confusing "wired 2 hooks but planned 0" because format hooks inflated the count.

The mental model: `hookStatus` answers "how well did the Plugin Integration contract land?", not "how many shell hooks does this project have total?".

**Canonical `hookStatus` shape** (the source of truth — all downstream consumers use this exact layout):

```jsonc
"hookStatus": {
  "planned": {
    "SessionStart": 1,               // count of planned hooks per event key
    "PreToolUse:Write": 1,           // keys use <Event>[:<Matcher>] format
    "PreToolUse:Bash": 2,            // multiple entries possible (e.g. 2 preCommit scripts)
    "Stop": 1
  },
  "generated": {
    // list-of-script-basenames per event key (NOT a count map).
    // Richer than a count: you can see which script is wired to which event without
    // cross-referencing .claude/settings.json.
    "SessionStart":     ["plugin-integration-reminder.sh"],
    "PreToolUse:Write": ["feature-start-detector.sh"],
    "PreToolUse:Bash":  [
      "pre-commit-code-review.sh",
      "pre-commit-verification-before-completion.sh"
    ],
    "Stop":             ["post-feature-revise-claude-md.sh"]
  },
  "skipped": [                       // one entry per hook that was planned but NOT generated
    {
      "event": "Stop",               // event:matcher key from `planned`
      "skill": "claude-md-management:revise-claude-md",
      "reason": "plugin-not-installed"
    }
  ],
  "warnings": [                      // free-text warnings emitted during hook generation
    "featureStart.criticalDirs was empty; detector hook not generated"
  ],
  "downgradeApplied": {              // OPTIONAL — only present when autonomyLevel forced a mode change
    "rule": "autonomyLevel=always-ask → preCommit[].mode=advisory",
    "affectedEntries": ["code-review:code-review", "superpowers:verification-before-completion"]
  }
}
```

**Counting rules**:
- `planned[event]` = **integer** — number of entries in `callerExtras.qualityGates.<field>[]` that map to that event (e.g. `qualityGates.preCommit[]` length contributes to `PreToolUse:Bash` because pre-commit hooks attach to Bash tool calls). **Only counts qualityGates-derived hooks, never format/lint/forge-internal.**
- `generated[event]` = **array of script basenames** (relative to `.claude/hooks/`) for hooks actually written to `.claude/settings.json` **from the qualityGates spec**. Not the total event count in settings.json — exclude format/lint/forge-internal scripts.
- `skipped[]` = a record for every entry in `planned` that did NOT produce a corresponding `generated` entry, with the reason (`plugin-not-installed`, `condition-unsatisfied`, `empty-critical-dirs`, etc.).
- `warnings[]` = operator-facing messages (not user-facing) about soft issues during generation.
- `downgradeApplied` (optional) = records the autonomyLevel-aware preCommit mode downgrade rule when it fires. Only present when the downgrade actually ran — absent means no downgrade was applied. Gives downstream tooling (status reports, adaptive suppression) provenance without re-deriving.
- **Invariant**: for every event key, `planned[event] - len(generated[event]) == (number of skipped[] entries whose `event` matches)`. If this doesn't balance, the telemetry is broken — treat as a generation bug.

See `references/hooks-guide.md` for generated script templates, ShellCheck requirements, and concrete examples of sessionStart + featureStart + preCommit hooks.

#### O6 — SessionStart reminder hook

When `qualityGates.sessionStart` is non-empty AND at least one entry's `condition` resolves to `true` (e.g., `"superpowers-installed"` + superpowers is in `installedPlugins`), generate:

1. A ShellCheck-clean script at `<project>/.claude/hooks/plugin-integration-reminder.sh`:

   ```bash
   #!/usr/bin/env bash
   set -u  # no -e / -o pipefail — see "Shell options for hook scripts" below

   # Generated by onboard — plugin integration session-start reminder
   # Advisory only. Always exits 0.
   # Adaptive: suppresses to 1-line pointer after 5 fires without brainstorming.

   counter_file=".claude/session-state/plugin-integration-reminder-count"
   state_dir=".claude/session-state"

   # Ensure state directory exists
   mkdir -p "$state_dir"

   # Read current counter (0 if file missing)
   count=0
   if [ -f "$counter_file" ]; then
     count=$(cat "$counter_file" 2>/dev/null || echo 0)
     # Reset if brainstorming happened since last reminder
     if find "$state_dir" -maxdepth 1 -name 'brainstormed-*' -newer "$counter_file" -print -quit 2>/dev/null | grep -q .; then
       count=0
     fi
   fi

   # Emit reminder (full or abbreviated)
   if [ "$count" -lt 5 ]; then
     echo "Session reminder: Starting new feature work? Begin with /superpowers:brainstorming."
     echo "See root CLAUDE.md § Plugin Integration for the full workflow."
   else
     echo "See CLAUDE.md § Plugin Integration."
   fi

   # Increment and persist counter
   count=$((count + 1))
   echo "$count" > "$counter_file"
   exit 0
   ```

2. A SessionStart entry in `<project>/.claude/settings.json`:

   ```jsonc
   {
     "hooks": {
       "SessionStart": [
         {
           "hooks": [
             { "type": "command", "command": ".claude/hooks/plugin-integration-reminder.sh", "timeout": 5000 }
           ]
         }
       ]
     }
   }
   ```

**Reminder text composition**: concatenate all qualifying `sessionStart[].message` values, then truncate to ≤ 3 lines total (one greeting + one brainstorming cue + one pointer to CLAUDE.md). Never emit more than 3 lines regardless of how many entries exist (EC11). The abbreviated (suppressed) form emits exactly 1 line.

**Adaptive suppression**: the generated script tracks how many consecutive sessions the reminder has fired without the user running brainstorming. After 5 fires, it switches to a 1-line pointer (`"See CLAUDE.md § Plugin Integration."`) to reduce noise. The counter resets to 0 when a `brainstormed-*` marker file newer than the counter file is detected in `.claude/session-state/`, meaning brainstorming happened since the last reminder. This prevents fatigue while keeping the nudge alive for users who do follow it.

- **Counter file**: `.claude/session-state/plugin-integration-reminder-count` — a single integer
- **Threshold**: 5 (hardcoded — sessions 1-5 get the full reminder, session 6+ gets the abbreviated form)
- **Reset trigger**: any `brainstormed-$SESSION_ID` marker file newer than the counter file

**Skip conditions**:
- No qualifying entries → do not write the script or the settings.json entry.
- `superpowers` not installed → the default "superpowers-installed" condition fails; the entry is dropped.

**Script requirements**:
- `#!/usr/bin/env bash` + `set -u` (NOT `set -euo pipefail` — see "Shell options for hook scripts" in O7 for why)
- `shellcheck -x` must pass
- Keep under 25 lines total (excluding comments) — adaptive suppression logic requires more lines than the original static reminder
- Reference pattern: `.claude/hooks/post-edit.sh` in the repo root

#### O7 — Feature-start detector PreToolUse hook

When `qualityGates.featureStart` is non-empty AND `criticalDirs` is non-empty, generate a ShellCheck-clean script at `<project>/.claude/hooks/feature-start-detector.sh` and a matching PreToolUse:Write entry in `<project>/.claude/settings.json`.

##### Required behavioral invariants (MUST all be implemented)

The generated `feature-start-detector.sh` **MUST** satisfy every single invariant below. These are load-bearing for correctness — they are **not** suggestions, and they are **not** optional optimizations. **Do not simplify or omit them "for readability"**. If the reference implementation below feels long, the right answer is to keep it long, not to cut checks.

A generated detector script that is missing any of invariants 1-8 is a **bug** and must be regenerated.

1. **MUST parse `tool_name` and `tool_input.file_path` from stdin JSON** (PreToolUse payload contract). A `CLAUDE_TOOL_INPUT_FILE_PATH` env-var fallback is acceptable and encouraged for harness portability, but stdin parsing must work standalone. Use jq-preferred + sed/grep fallback so jq is not a hard dependency.
2. **MUST `exit 0` immediately if `tool_name != "Write"`.** This is a Write-only detector. Firing on Edit, Bash, or other tools would be a false positive.
3. **MUST `exit 0` immediately if the target file already exists on disk.** An existing file means this is an edit-in-place, not a feature-start. The hook must only fire when a genuinely new file is being created.
4. **MUST `exit 0` immediately if the target path matches any of these generated/tool-managed path patterns**:
   - `**/build/**`
   - `**/generated/**`
   - `**/.git/**`
   - `**/node_modules/**`
   - `**/.next/**`
   - `**/dist/**`
   - `**/target/**`
   - `**/.gradle/**`
   - `**/__pycache__/**`

   These paths are populated by build tools, package managers, or VCS, and can fire dozens or hundreds of times during a normal build cycle. Letting the hook fire on them would flood the transcript with meaningless reminders. This is **EC10 from the Plugin Integration spec** and is mandatory. Implement this as a `case` statement early in the script — before the critical-dir match — so the cost of the check is paid only for Write calls that aren't already filtered out.
5. **MUST `exit 0` immediately if the session marker `.claude/session-state/brainstormed-${CLAUDE_SESSION_ID}` exists.** Brainstorming has already fired in this session, so the reminder would be redundant and annoying. This is **EC8 from the Plugin Integration spec** and is mandatory.
   - If `CLAUDE_SESSION_ID` is unset, use the literal string `unknown` as the suffix. The resulting marker path `brainstormed-unknown` is unlikely to exist, so the hook fires conservatively. This false-positive cost is preferable to silently missing a reminder because the env var wasn't propagated.
   - **Do not skip this check** just because the session-state directory might not exist on first run — a missing directory means a missing marker, which correctly triggers the "hook fires" path.
6. **MUST match the target path against the critical-dir regex** constructed from `qualityGates.featureStart[].criticalDirs`. If no critical dir matches, `exit 0`. See "Regex construction" below for how to build the regex.
7. **MUST emit the reminder on stderr** (`>&2`, not stdout). Claude Code surfaces hook stderr in the transcript as a first-class signal, while stdout is appended less prominently. The reminder text must reference `/superpowers:brainstorming` and (when available) a relevant feature-dev skill.
8. **MUST `exit 0` after emitting the reminder.** This hook is **always advisory**, **never blocking**. **Never `exit 2`** from this script under any circumstance. Blocking a Write on a new file would make the hook unusable in practice and force users to bypass all hooks.

##### Reference implementation

Use this as the starting point. The `critical_regex` value and the reminder text are the only two things that should be customized per-project — everything else (all 8 invariants) must remain.

```bash
#!/usr/bin/env bash
set -u  # no -e / -o pipefail — see "Shell options for hook scripts" below

# Generated by onboard — feature-start detector
# Advisory only. Always exits 0. Non-blocking.
# Invariants: see onboard/skills/generation/SKILL.md § O7.

# Invariant 1 — parse stdin JSON with env var fallback
payload=""
if [ ! -t 0 ]; then
  payload="$(cat || true)"
fi

tool_name="${CLAUDE_TOOL_INPUT_TOOL_NAME:-}"
if [ -z "$tool_name" ] && [ -n "$payload" ]; then
  tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || \
              printf '%s' "$payload" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi

# Invariant 2 — Write-only
[ "$tool_name" != "Write" ] && exit 0

file_path="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -z "$file_path" ] && [ -n "$payload" ]; then
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || \
              printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$file_path" ] && exit 0

# Invariant 3 — new files only
[ -e "$file_path" ] && exit 0

# Invariant 4 — skip generated / build / tool-managed paths (EC10)
case "$file_path" in
  */build/*|*/generated/*|*/.git/*|*/node_modules/*|*/.next/*|*/dist/*|*/target/*|*/.gradle/*|*/__pycache__/*)
    exit 0
    ;;
esac

# Invariant 5 — skip if brainstorming already fired in this session (EC8)
marker=".claude/session-state/brainstormed-${CLAUDE_SESSION_ID:-unknown}"
[ -f "$marker" ] && exit 0

# Invariant 6 — match critical-dir regex (customize per-project from featureStart.criticalDirs)
critical_regex='(domain/parser/|ui/compose/|data/db/)'
if ! printf '%s' "$file_path" | grep -Eq "$critical_regex"; then
  exit 0
fi

# Invariants 7 + 8 — emit reminder to stderr, then exit 0 advisory
{
  echo "[onboard] New file in a domain-critical directory: $file_path"
  echo "[onboard] Consider /superpowers:brainstorming and the relevant feature-dev skill first."
} >&2

# Worktree offer (addon — fires only when brainstorm reminder also fires)
# Not a new invariant — additive output after invariant 7+8 message.
# Only generated when enableHarness is true in the generation context.
wt_pref="ask"
if [ -f ".claude/session-state/worktree-preference" ]; then
  wt_pref=$(cat ".claude/session-state/worktree-preference" 2>/dev/null || echo "ask")
fi

# Skip worktree offer if preference is "never" or already in a worktree
in_worktree=false
case "$PWD" in */.claude/worktrees/*) in_worktree=true ;; esac

if [ "$wt_pref" != "never" ] && [ "$in_worktree" = "false" ]; then
  {
    echo "[onboard] Worktree isolation recommended. Follow CLAUDE.md § Worktree Workflow to create one."
    if [ "$wt_pref" = "ask" ]; then
      echo "[onboard] Save preference: echo 'always' > .claude/session-state/worktree-preference"
    fi
  } >&2
fi

exit 0
```

##### Worktree offer addon (conditional — `enableHarness` only)

The worktree offer block (lines after invariant 7+8 in the reference implementation above) is **only generated when `enableHarness` is true** in the generation context. Non-harness projects skip this block entirely — the script ends at `exit 0` after the brainstorm reminder.

This addon is **additive to invariants 7+8**, not a replacement. The 8 invariants remain untouched and mandatory. The worktree offer fires only when all 8 invariants have already passed (i.e., the brainstorm reminder was emitted).

**Preference file contract**:
- Path: `.claude/session-state/worktree-preference`
- Values: `always` (auto-create without asking), `never` (suppress offer), `ask` (prompt each time — default if file missing)
- Written by Claude after the developer responds to the first offer, or manually via `echo "always" > .claude/session-state/worktree-preference`
- The hook only reads this file — it never writes it

**In-worktree detection**: `case "$PWD" in */.claude/worktrees/*)` detects if the session is already inside a Claude Code worktree. Claude Code stores worktrees at `.claude/worktrees/<name>/`, so this pattern is reliable. If already in a worktree, the offer is suppressed (Claude Code refuses nested worktrees anyway).

**Feature-list.json name lookup**: The hook does NOT parse `docs/feature-list.json` — that complexity belongs in the CLAUDE.md instructions, not in a shell script. The hook emits a generic "follow CLAUDE.md § Worktree Workflow" message. Claude reads the CLAUDE.md section, looks up the feature ID from `docs/feature-list.json` if it exists, constructs the name (e.g., `F001-user-dashboard`), and calls `EnterWorktree(name: "...")`.

##### PreToolUse entry in settings.json

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/feature-start-detector.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

Use `${CLAUDE_PROJECT_DIR}/.claude/hooks/...` (not bare `.claude/hooks/...`) so the hook is cwd-independent.

##### Regex construction

Escape each `criticalDirs` entry with regex-safe quoting, join with `|`, wrap in `()`.

Example: `["domain/parser/", "ui/compose/"]` → `(domain/parser/|ui/compose/)`

For paths containing regex metacharacters (unlikely in practice but possible), escape them before joining. The reference implementation uses POSIX-extended regex via `grep -Eq`.

##### Skip conditions (generator-level, not runtime)

These apply at generation time — if they're true, do not write the script or the settings.json entry at all:

- No `featureStart` entries in `qualityGates`
- `featureStart[].criticalDirs` is empty across all entries
- Plugin-availability check fails for a referenced skill → record in `hookStatus.skipped[]` (see B3 telemetry spec) and continue without generating

##### Script requirements

- `#!/usr/bin/env bash` + `set -u` (NOT `set -euo pipefail` — see "Shell options for hook scripts" below). This matches `.claude/rules/shell-scripts.md`, which already says hook scripts must not use `set -e`.
- `shellcheck -x` must pass cleanly — zero warnings, zero errors
- Never `exit 2` — this hook is always advisory. Exit code other than 0 is a bug.
- Reference patterns: `.claude/hooks/validate-bash.sh` for stdin JSON parsing, `.claude/hooks/post-edit.sh` for the advisory exit pattern

##### Shell options for hook scripts (load-bearing)

Use `set -u` alone, **not** `set -euo pipefail`. Here's why this matters:

Hook scripts use the `cat 2>/dev/null || true` pattern to drain stdin when no payload is present (harness-invoked case, or when invoked interactively with no piped input). Under `set -e`:

- If the stdin source is a closed pipe, bash can exit with SIGPIPE (exit code 141) — the hook appears to "fail" even though the drain is intentional
- Any `grep` / `sed` pipeline that returns no matches (exit 1) would abort the whole script

Under `set -o pipefail`:

- Pipe failures inside conditional logic get promoted to script failures, breaking the jq-preferred + grep/sed fallback pattern (when jq succeeds but its stdout is empty, the next stage in the pipe sees nothing and reports a failure that pipefail surfaces as the script's exit code)

Using `set -u` alone:

- Still catches undefined-variable bugs (the actual safety we want)
- Leaves error handling to explicit checks inline (`[ -z "$var" ] && exit 0`)
- Works correctly with the stdin-drain and jq-fallback patterns the hooks rely on

**Rule**: hook scripts use `set -u`. Utility scripts (`scripts/*.sh`, `install*.sh`, analysis/detection tooling) use `set -euo pipefail`. This distinction is documented in `.claude/rules/shell-scripts.md` and is authoritative — this spec section only restates it for the generation-time audience.

#### Standalone Quality-Gate Hooks (when no plugins detected)

When `effectiveQualityGates` is NOT present AND `effectivePlugins` is empty — meaning no plugins were found either from a caller or from self-detection — derive default quality-gate hooks from the `selectedPreset` (profile) and `autonomyLevel` wizard answers. These hooks are simpler than their plugin-aware counterparts: they reference project rules from `.claude/rules/` and CLAUDE.md conventions rather than plugin skills.

##### Profile determines WHICH hooks

| Profile | SessionStart | preCommit | featureStart | postFeature |
|---------|-------------|-----------|--------------|-------------|
| minimal | — | — | — | — |
| standard | Yes | — | — | — |
| comprehensive | Yes | Yes | Yes | Yes |
| custom | Follow comprehensive if autonomyLevel ≠ "always-ask"; follow standard otherwise |

##### autonomyLevel determines MODE

| autonomyLevel | SessionStart | preCommit | featureStart | postFeature |
|---------------|-------------|-----------|--------------|-------------|
| always-ask | advisory | advisory | advisory | advisory |
| balanced | advisory | **blocking** | advisory | advisory |
| autonomous | advisory | **blocking** | **blocking** | advisory |

##### Standalone hook content (no plugin references)

These hooks reference project conventions rather than installed plugins:

- **SessionStart reminder**: Echo a 1-2 line reminder: "Review CLAUDE.md conventions and .claude/rules/ for path-specific guidance before starting work." No adaptive suppression counter — keep the script simple. Always `exit 0`.
- **preCommit hook**: Run the project's test command discovered during analysis (from CLAUDE.md § Build Commands → testing). Attach to `PreToolUse:Bash(git commit*)`. In blocking mode, exit 2 with stderr feedback if the test command fails. If no test command was detected during analysis, skip preCommit generation entirely and record in `hookStatus.skipped[]` with reason `"no-test-command-detected"`.
- **featureStart reminder**: Advisory when Claude creates a new file via `PreToolUse:Write` in a critical directory. Derive `criticalDirs` from the analysis report's identified architectural boundaries (top-level source directories). Use the same stdin-parsing and new-files-only pattern from O7 but without plugin or brainstorming references. Message: "Starting a new file in a key directory. Review CLAUDE.md and .claude/rules/ for conventions in this area."
- **postFeature nudge**: Attach to `Stop` event. Message: "Consider reviewing CLAUDE.md and .claude/rules/ to capture any new conventions from this work." Always advisory, always `exit 0`.

##### Standalone script conventions

Standalone hooks follow the same shell conventions as headless hooks:
- `#!/usr/bin/env bash` + `set -u` (not `set -euo pipefail` — see Shell Options section above)
- ShellCheck-clean (`shellcheck -x`)
- Advisory hooks always `exit 0`, blocking hooks `exit 2` with stderr on failure
- No plugin availability checks needed — no plugins are referenced
- No adaptive suppression (SessionStart) — always show the reminder
- No brainstorming or worktree concepts — those are plugin-specific

##### hookStatus telemetry for standalone hooks

Record standalone quality-gate hooks in `onboard-meta.json` under the same `hookStatus` key used by headless hooks. The shape is identical — `planned`, `generated`, `skipped`, `warnings`. The `skipped[].reason` for profile-excluded hooks is `"profile-excluded"`.

##### Merge behavior

Same as headless mode: read existing `.claude/settings.json` first, merge hook entries, never overwrite. If a hook with the same matcher/event already exists, skip (don't duplicate). Standalone quality-gate hooks coexist with format/lint hooks from the Autonomy Cascade — they use different events/matchers and do not conflict.

#### Utility Hooks (non-telemetry)

Utility hooks are generated alongside quality-gate hooks but are **NOT** tracked in `hookStatus`. They serve infrastructure purposes. They follow the same shell conventions (`set -u`, `shellcheck -x`, always `exit 0`).

##### WorktreeCreate hook — init.sh auto-runner

When `enableHarness` is true in the generation context, generate a `WorktreeCreate` hook that runs `init.sh` when the developer enters a worktree via `EnterWorktree`.

**What to generate**: The script and settings.json entry from `references/hooks-guide.md` § WorktreeCreate hook (init.sh auto-runner).

**Why this is not in hookStatus**: `hookStatus` tracks only quality-gate hooks derived from `callerExtras.qualityGates` (see scope boundary above). The WorktreeCreate hook is infrastructure — it bootstraps development environments, not Plugin Integration discipline.

**Merge behavior**: Same as all hooks — merge into existing `.claude/settings.json`. If a `WorktreeCreate` hook already exists, skip (don't duplicate).

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
- Plugin detection results: `detectedPlugins` object (only in standalone mode when plugins were self-detected)
- Plugin source: `pluginSource` — `"callerExtras"` | `"self-detected"` | `"none"` — records how the effective plugin list was resolved

## Quality Checklist

Before finishing generation, verify:

- [ ] Root CLAUDE.md is 100-200 lines and includes all key commands
- [ ] All file paths in rules frontmatter actually exist in the project
- [ ] No duplicate information across CLAUDE.md files and rules
- [ ] Maintenance headers are on every generated file
- [ ] Skills reference patterns that actually exist in the codebase
- [ ] Agent tool lists include only tools they need
- [ ] Hooks reference tools that are actually installed
- [ ] settings.json is merged, not overwritten (if it existed)
- [ ] onboard-meta.json is complete and accurate
- [ ] PR template exists with stack-appropriate checklist items
- [ ] Commit conventions rule matches `codeStyleStrictness` level
- [ ] Root CLAUDE.md includes shared vs local settings guidance
- [ ] Rules reflect actual config settings, not generic defaults
- [ ] Formatter-enforced settings are in CLAUDE.md Key Conventions, not duplicated in rules
- [ ] Observed codebase patterns are captured in architectural rules
- [ ] testing.md rule mandates test-first development (red-green-refactor)
- [ ] If superpowers installed: no standalone TDD skill generated (would conflict)
- [ ] If superpowers NOT installed: standalone TDD skill + TDD test-writer agent exist
- [ ] If any plugin missing: CLAUDE.md includes "Recommended Plugins" section with install commands
- [ ] Maintenance headers use version from plugin.json, not hardcoded values
- [ ] Architecture pattern layers from analysis report are included as subdirectory CLAUDE.md candidates
- [ ] File share thresholds reflect the selected profile (comprehensive = halved, minimal = doubled)
- [ ] Standalone quality-gate hooks match profile + autonomyLevel (comprehensive → all four, standard → SessionStart only, minimal → none)
- [ ] Standalone hooks do not reference plugin skills (no `/superpowers:*`, no `code-review:*`)
- [ ] Standalone preCommit hook uses project's actual test command from analysis
- [ ] effectivePlugins resolution works for all three scenarios: headless (callerExtras), standalone with plugins (self-detected), standalone without plugins (none)
- [ ] Plugin Integration section generates in standalone mode when plugins are self-detected
- [ ] Plugin-referencing quality-gate hooks generated when effectiveQualityGates is present (regardless of entry point)
- [ ] onboard-meta.json records pluginSource and detectedPlugins when applicable
- [ ] If both plugins installed: no "Recommended Plugins" section in CLAUDE.md
- [ ] CLAUDE.md "Development Workflow" references match actually installed plugins (no dangling refs)
- [ ] PR template includes TDD checklist item ("Tests written first, all pass")
- [ ] No stale references to `minimal`, `write-after`, or `comprehensive` testing philosophies

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
- Initialize `.claude/drift.json`

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

## Reference Files

### Core (always used)
- `references/claude-md-guide.md` — CLAUDE.md structure and best practices
- `references/rules-guide.md` — Path-scoped rules patterns
- `references/hooks-guide.md` — Hook configuration patterns (format, lint)
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
