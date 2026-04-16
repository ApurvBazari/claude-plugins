---
name: generation
description: Core artifact generator for Claude tooling (CLAUDE.md, rules, skills, agents, hooks). Internal building block invoked by the config-generator agent during /onboard:init and /onboard:generate — not user-invocable.
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
7. **Output styles** (always — built-in styles are universal, emitted custom style is project-specific): Add an `### Output styles` subsection. List the three built-ins (`Default` / `Explanatory` / `Learning`) with one-line descriptions. If `outputStyleStatus.generated[]` is non-empty, also list the emitted custom style with its path and one-line purpose. State the activation path: open `/config` and pick from the menu, OR set `"outputStyle": "<name>"` in `.claude/settings.local.json`. Include the new-session caveat (changes take effect in the next new session). Do NOT reference built-in styles as files — they're Anthropic-provided. When `outputStyleStatus.generated[]` is empty, still emit the subsection to surface the built-ins.
8. **Built-in Claude Code skills** (always — these are Anthropic-provided, not plugin-dependent): Add a `### Built-in Claude Code skills` subsection wrapped in `<!-- onboard:builtin-skills:start -->` / `<!-- onboard:builtin-skills:end -->` markers. For each skill in `builtInSkillsStatus.generated[]`, emit: skill name, one-line description, and a project-specific example from `references/built-in-skills-catalog.md` (matched to detected stack). Use the same narrative voice as other Plugin Integration subsections — answer "when would you use this on your project?" not just list names. Place this as the **last subsection** inside Plugin Integration, after Output styles. When `builtInSkillsStatus.generated[]` is empty, do not emit the subsection (no stub). When `effectivePlugins` is empty, emit as a standalone `## Built-in Claude Code skills` section with the same `<!-- onboard:builtin-skills:start/end -->` markers, placed after the last onboard-generated section (identified by maintenance header). See "Built-in Claude Code Skills — Phase 7d" below for the full emission spec.

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

**Marker wrapping (required)**: the block MUST be wrapped in section markers that also encode the directory role. This lets `onboard:update` and `onboard:evolve` refresh the block on plugin drift without re-running scaffold-analyzer:

```markdown
<!-- onboard:skill-recommendations:start role="parser" -->
## Skill recommendations

[...generated guidance for this role with current effectivePlugins...]
<!-- onboard:skill-recommendations:end -->
```

The `role` attribute value must match one of the identified directory roles (`domain`, `parser`, `data-layer`, `compose-ui`, `api`, `tests`, `scripts`, etc.). Drift handlers read this attribute to regenerate the block against the current plugin mix without needing to re-classify the directory.

**Rules**:

1. **Only add the block when** an installed plugin's capability meaningfully applies to the directory's role. Never stub "Skill recommendations: none". Directories with no matching plugin capability get no block (and no markers).
2. **Derive mapping from** (a) directory role (identified by config-generator: `domain`, `parser`, `data-layer`, `compose-ui`, `api`, `tests`, `scripts`, etc.), and (b) `effectiveCoveredCapabilities`.
3. **Brainstorming first** (when superpowers is installed): every annotation that invites new code creation must reference `/superpowers:brainstorming` as the entry point — e.g., *"Before adding a new Parser, run `/superpowers:brainstorming` to explore approaches."*
4. **Be specific** about *when* to invoke each skill. Vague references like "use feature-dev" are not helpful; *"use `feature-dev:code-architect` when drafting a new Parser contract, then TDD via `superpowers:test-driven-development`"* is.
5. **Don't repeat root** — the subdirectory block assumes the reader has already seen the root Plugin Integration section.
6. **Never touch content outside the markers** — drift-time refresh operates only on the delimited region.

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

Every generated `SKILL.md` carries YAML frontmatter. The generator computes the full surface — `name`, `description`, `user-invocable` / `disable-model-invocation`, plus up to six additional fields (`allowed-tools`, `model`, `effort`, `paths`, `context`, `agent`) — based on archetype inference, wizard-level defaults, and a per-skill developer confirmation step.

**Step 1 — Classify each candidate into an archetype.** Use the draft description + generation rationale (pain point / stack / workflow gap). Five archetypes live in `references/skills-guide.md` § Per-archetype defaults: `research-only`, `scaffolder`, `reviewer`, `orchestrator`, `workflow-specific`. Classification signals are documented in that table and must not be restated here.

**Step 2 — Compose archetype defaults with wizard tuning.** Read `wizardAnswers.skillTuning` (may be absent — treat absence as `{ mode: "defaults" }`):

| `skillTuning.mode` | Effect on archetype output |
|---|---|
| `defaults` (or absent) | Emit archetype values as-is. Wherever the archetype says `inherit` for `model` / `effort`, keep it literal so the final `SKILL.md` omits the field (omitting preserves pre-feature behavior exactly). |
| `tuned` | Replace any `inherit` model/effort with `skillTuning.defaultModel` / `defaultEffort` (unless those are also `inherit`). Apply `preApprovalPosture` clamp to `allowed-tools`: `minimal` strips `Write`/`Edit`/`Bash(*)`, `standard` leaves untouched, `permissive` broadens `Bash(...)` scoping to detected runners (e.g., add `Bash(npm run *:*)`, `Bash(pnpm *:*)` for Node projects). |

**Step 3 — Validation pass (must run before Step 4).** Each computed frontmatter object must pass these checks; failures drop the offending field (never the whole skill) and append to `skillStatus.warnings`:

| Check | Action on fail |
|---|---|
| `context: fork` requires a non-empty `agent` that exists in `.claude/agents/` or `effectivePlugins` | Demote to no-fork (drop both fields); warn `context-agent-missing` |
| `paths` globs match at least one file in the repo today | Still emit; tag `skillStatus.frontmatterFields.<skill>.pathsWarning = "no-match"` (visible warning only; not a failure) |
| All keys are hyphenated canonical spelling | **Generation bug — fail the skill emission loudly** with a clear error. Underscore keys are silently ignored by Claude Code and must never be written. |
| `model` / `effort` values match the allowed enum | Drop the field; warn `invalid-<field>-value` |

**Step 4 — Batched confirmation (always runs).** Before writing any `SKILL.md`, present a single table summarizing every candidate skill and its computed frontmatter. Use `AskUserQuestion` with options:

- **Accept all** — default. Guarantees Quick Mode / headless (including `callerExtras.disableSkillTuning: true`) passes through without re-prompting.
- **Tweak skill N** — re-prompt only that skill's fields (which to change: model / effort / allowed-tools / paths / context+agent). Other skills proceed with their accepted values. Mark tweaked fields `source: "user-tweaked"`.
- **Skip skill N** — record `skillStatus.skipped[] = [{ "skill": "<name>", "reason": "user-declined-confirmation" }]`. Skipped skills are not written, not snapshotted, and not included in `skillStatus.generated[]`.

**Headless passthrough**: when `callerExtras.disableSkillTuning` is `true`, skip Step 4 entirely and emit with the inferred-plus-tuned values. Record each skill's `frontmatterFields.<name>.source = "inferred"` or `"wizard-default"` per Step 2. This mirrors the `callerExtras.disableMCP` escape hatch in Phase 7a.

**Step 5 — Write `SKILL.md` files.** Emit only fields that have concrete values — never emit empty strings or empty lists. Omitted fields preserve pre-feature-equivalent behavior exactly and keep pre-upgrade fixtures byte-identical.

**Step 6 — Write drift snapshot.** Append `.claude/onboard-skill-snapshot.json` (or create it if absent) with the exact emitted frontmatter block per skill. Same pattern as `.claude/onboard-mcp-snapshot.json` — pure JSON, no maintenance header, consumed by `onboard:update` / `onboard:evolve` as the drift baseline.

```jsonc
{
  "react-component": {
    "allowed-tools": ["Read", "Grep", "Glob", "Write", "Edit"],
    "effort": "medium",
    "paths": ["src/components/**/*.tsx"]
  },
  "pr-summarizer": {
    "allowed-tools": ["Read", "Grep", "Glob", "Bash(git diff:*)", "Bash(git log:*)"],
    "model": "sonnet",
    "effort": "medium",
    "context": "fork",
    "agent": "code-reviewer"
  }
}
```

**Step 7 — Populate `skillStatus`.** Add to `onboard-meta.json` alongside `hookStatus` and `mcpStatus`:

```jsonc
{
  "skillStatus": {
    "planned": ["react-component", "pr-summarizer", "deploy-runner"],
    "generated": ["react-component", "pr-summarizer"],
    "skipped": [{ "skill": "deploy-runner", "reason": "user-declined-confirmation" }],
    "frontmatterFields": {
      "react-component": {
        "allowed-tools": ["Read", "Grep", "Glob", "Write", "Edit"],
        "effort": "medium",
        "paths": ["src/components/**/*.tsx"],
        "source": "inferred"
      },
      "pr-summarizer": {
        "allowed-tools": ["Read", "Grep", "Glob", "Bash(git diff:*)", "Bash(git log:*)"],
        "model": "sonnet",
        "effort": "medium",
        "context": "fork",
        "agent": "code-reviewer",
        "source": "user-tweaked"
      }
    },
    "existedPreOnboard": [],
    "warnings": []
  }
}
```

**`source` values** (per-skill provenance):

- `inferred` — archetype defaults only, wizard was in `defaults` mode.
- `wizard-default` — archetype defaults composed with `skillTuning.mode === "tuned"` values.
- `user-confirmed` — developer chose "Accept all" in Step 4 with at least one wizard-level override applied.
- `user-tweaked` — developer used "Tweak skill N" and edited at least one field. `onboard:update` preserves user-tweaked fields on regenerate.

**`existedPreOnboard`** lists skill directory names that already existed on disk before this generation run. Those skills are never rewritten and never enter the snapshot — they're flagged so `onboard:update` can distinguish user-owned skills from generator-owned ones.

**Scope reminder**: `skillStatus` tracks **only** skills emitted by this generator phase. Skills shipped by plugins (via plugin markets) and hand-authored skills that predate onboard are out of scope — the `existedPreOnboard` list names them but does not attempt to track their frontmatter state.

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

Every generated agent file carries YAML frontmatter. The generator computes the full surface — `name`, `description`, plus up to nine additional fields (`tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `effort`, `isolation`, `color`, `background`) — based on archetype inference, wizard-level defaults, and a per-agent developer confirmation step. `proactive` is not a frontmatter field; the convention is encoded via a `description` prefix per the archetype table.

**Step 1 — Classify each candidate into an archetype.** Use the agent's purpose description + generation rationale (team size, security signal, stack fit). Five archetypes live in `references/agents-guide.md` § Per-archetype defaults: `reviewer`, `validator`, `generator`, `architect`, `researcher`. Classification signals are documented in that table and must not be restated here. Ambiguous cases fall back to `researcher` and append an entry to `agentStatus.warnings` (`archetype-inference-fallback`).

**Step 2 — Compose archetype defaults with wizard tuning.** Read `wizardAnswers.agentTuning` (may be absent — treat absence as `{ mode: "defaults" }`):

| `agentTuning.mode` | Effect on archetype output |
|---|---|
| `defaults` (or absent) | Emit archetype values as-is. Wherever the archetype says `inherit` for `model` / `effort`, keep it literal so the final agent file omits the field (omitting preserves pre-feature behavior exactly). |
| `tuned` | Replace any `inherit` model/effort with `agentTuning.defaultModel` / `defaultEffort` (unless those are also `inherit`). Apply `preApprovalPosture` clamp: `minimal` forces `permissionMode: default` and keeps archetype `disallowedTools`; `standard` leaves archetype output untouched; `permissive` may add `permissionMode: acceptEdits` on generator only. Apply `defaultIsolation`: `worktree-for-generators` emits `isolation: worktree` on generator archetype only; `off` never emits `isolation`. |

Archetype-defined `disallowedTools` always win for semantic protection (reviewer/validator/architect/researcher never get `Write`/`Edit`, regardless of posture). Autonomy-level elevation (e.g. `autonomyLevel: "autonomous"`) may broaden `tools` but does not override `disallowedTools`.

**Step 3 — Validation pass (must run before Step 4).** Each computed frontmatter object must pass these checks; failures drop the offending field (never the whole agent) and append to `agentStatus.warnings`:

| Check | Action on fail |
|---|---|
| `color` in `{red, blue, green, yellow, purple, orange, pink, cyan}` | Drop field; warn `invalid-color-value` |
| `effort` in `{low, medium, high, max}` | Drop field; warn `invalid-effort-value` |
| `isolation` equals `worktree` or omitted (no other values accepted) | Drop field; warn `invalid-isolation-value` |
| `model` in `{sonnet, opus, haiku, inherit}` or a full model ID | Drop field; warn `invalid-model-value` |
| `permissionMode` in `{default, acceptEdits, auto, dontAsk, bypassPermissions, plan}` | Drop field; warn `invalid-permissionMode-value` |
| `isolation: worktree` requires a git repository | Drop field; warn `isolation-non-git-dir` |
| `name` matches the agent filename stem (kebab-case) | **Generation bug — fail the agent emission loudly** |
| `maxTurns` is a positive integer | Drop field; warn `invalid-maxTurns-value` |

**Step 4 — Batched confirmation (always runs).** Before writing any agent file, present a single table summarizing every candidate agent and its computed frontmatter. Use `AskUserQuestion` with options:

- **Accept all** — default. Guarantees Quick Mode / headless (including `callerExtras.disableAgentTuning: true`) passes through without re-prompting.
- **Tweak agent N** — re-prompt only that agent's fields (which to change: model / effort / tools / disallowedTools / color / isolation / maxTurns / permissionMode). Other agents proceed with their accepted values. Mark tweaked fields `source: "user-tweaked"`.
- **Skip agent N** — record `agentStatus.skipped[] = [{ "agent": "<name>", "reason": "user-declined-confirmation" }]`. Skipped agents are not written, not snapshotted, and not included in `agentStatus.generated[]`.

**Headless passthrough**: when `callerExtras.disableAgentTuning` is `true`, skip Step 4 entirely and emit with the inferred-plus-tuned values. Record each agent's `frontmatterFields.<name>.source = "inferred"` or `"wizard-default"` per Step 2. This mirrors the `callerExtras.disableSkillTuning` escape hatch.

**Step 5 — Write agent files.** Emit only fields that have concrete values — never emit empty strings or empty lists. Omitted fields preserve pre-feature-equivalent behavior exactly and keep pre-upgrade fixtures byte-identical. The description prefix convention (for encoding `proactive` intent per the archetype table) is applied inline in the final description string, not as a separate field.

**Step 6 — Write drift snapshot.** Append `.claude/onboard-agent-snapshot.json` (or create it if absent) with the exact emitted frontmatter block per agent. Same pattern as `.claude/onboard-skill-snapshot.json` — pure JSON, no maintenance header, consumed by `onboard:update` / `onboard:evolve` as the drift baseline.

```jsonc
{
  "code-reviewer": {
    "tools": "Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)",
    "disallowedTools": "Write, Edit",
    "model": "sonnet",
    "effort": "medium",
    "color": "blue"
  },
  "security-checker": {
    "tools": "Read, Glob, Grep, Bash",
    "disallowedTools": "Write, Edit",
    "model": "haiku",
    "effort": "low",
    "color": "green",
    "maxTurns": 2
  }
}
```

**Step 7 — Populate `agentStatus`.** Add to `onboard-meta.json` alongside `hookStatus`, `mcpStatus`, and `skillStatus`:

```jsonc
{
  "agentStatus": {
    "planned": ["code-reviewer", "tdd-test-writer", "security-checker"],
    "generated": ["code-reviewer", "security-checker"],
    "skipped": [{ "agent": "tdd-test-writer", "reason": "covered-by-plugin:superpowers" }],
    "frontmatterFields": {
      "code-reviewer": {
        "tools": "Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)",
        "disallowedTools": "Write, Edit",
        "model": "sonnet",
        "effort": "medium",
        "color": "blue",
        "source": "inferred"
      },
      "security-checker": {
        "tools": "Read, Glob, Grep, Bash",
        "disallowedTools": "Write, Edit",
        "model": "haiku",
        "effort": "low",
        "color": "green",
        "maxTurns": 2,
        "source": "user-tweaked"
      }
    },
    "existedPreOnboard": [],
    "warnings": []
  }
}
```

**`source` values** (per-agent provenance):

- `inferred` — archetype defaults only, wizard was in `defaults` mode.
- `wizard-default` — archetype defaults composed with `agentTuning.mode === "tuned"` values.
- `user-confirmed` — developer chose "Accept all" in Step 4 with at least one wizard-level override applied.
- `user-tweaked` — developer used "Tweak agent N" and edited at least one field. `onboard:update` preserves user-tweaked fields on regenerate.

**`existedPreOnboard`** lists agent filenames (without extension) that already existed on disk before this generation run. Those agents are never rewritten and never enter the snapshot — they're flagged so `onboard:update` can distinguish user-owned agents from generator-owned ones.

**`skipped.reason` values**:
- `user-declined-confirmation` — Step 4 "Skip agent N" choice.
- `covered-by-plugin:<plugin-name>` — the capability map in `#### Plugin-Aware Agent Generation` matched an installed plugin.
- `capability-not-needed` — archetype signal didn't fire for this project (e.g., security-checker skipped on `securitySensitivity: standard`).

**Scope reminder**: `agentStatus` tracks **only** agents emitted by this generator phase. Agents shipped by plugins (via plugin markets) and hand-authored agents that predate onboard are out of scope — the `existedPreOnboard` list names them but does not attempt to track their frontmatter state.

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

### MCP Servers (.mcp.json) — Phase 7a

Follow `references/mcp-guide.md` for emission rules, catalog, and transport shapes.

**When to run**: After Recommended Plugins copy is resolved and before Hooks are merged. Phase 7a runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — wizard answer** | `wizardAnswers` contains MCP server preferences (rare; MCP is signal-driven, not wizard-gated) | Emit per wizard. |
| **Path B — Quick Mode default** | wizard absent AND no candidate signals | Emit `mcpStatus: { status: "skipped", reason: "no-candidates" }`. No `.mcp.json`, no snapshot. |
| **Path C — signal-driven (default)** | `scripts/detect-mcp-signals.sh` returns ≥1 candidate | Emit `.mcp.json` + snapshot + telemetry. **This path fires regardless of wizard or headless mode** unless `callerExtras.disableMCP === true`. |
| **Path SKIP — caller-disabled** | `callerExtras.disableMCP === true` | No `.mcp.json`, no snapshot. Telemetry: `mcpStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [] }`. **Telemetry IS still written.** |

**Inputs**:
- `analysis.stack` — frameworks, deps, config-file fingerprints
- `callerExtras.disableMCP` (optional, headless) — see Path SKIP above
- Output of `scripts/detect-mcp-signals.sh <project-root>` — canonical signal list

**Telemetry contract**: `mcpStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | skipped | declined | failed`) per the Default behavior matrix in `generate/SKILL.md`.

**Step 1 — Detect candidates**. Run the detection script; parse JSON output. Candidates marked `confidence: "always"` (context7) emit unconditionally. Candidates marked `confidence: "high"` emit when the signal evaluates unambiguously (see `references/mcp-guide.md` § Confidence Tiers). Dedupe by server name.

**Step 2 — Pre-existing file check**. If `.mcp.json` already exists at project root:
- Do NOT overwrite
- Record `mcpStatus.existedPreOnboard: true` and `mcpStatus.preservedFile: ".mcp.json"`
- Still emit `.claude/rules/mcp-setup.md` describing servers we *would* have emitted, so the user can reconcile manually
- Skip the write in Step 3 and Step 4

**Step 3 — Write `.mcp.json`**. Use the schema in `references/mcp-guide.md` § Config Shape. Secret references use the `${VAR}` substitution form — never inline real values.

**Step 4 — Write drift snapshot**. Write `.claude/onboard-mcp-snapshot.json` with the exact contents of `.mcp.json` as written. This is the baseline that `onboard:update` / `onboard:evolve` diff against. Do not include a maintenance header — the snapshot is pure JSON consumed by tooling.

**Step 5 — Populate `mcpStatus`**. Add to `onboard-meta.json` alongside `hookStatus`:
```jsonc
{
  "mcpStatus": {
    "planned": ["context7", "vercel"],
    "generated": ["context7", "vercel"],
    "skipped": [{ "server": "github", "reason": "no-github-workflows-detected" }],
    "autoInstalled": [],
    "autoInstallFailed": [],
    "existedPreOnboard": false
  }
}
```

**Step 6 — Write `.claude/rules/mcp-setup.md`** (conditional on at least one server requiring auth OR on `existedPreOnboard: true`). Use the template in `references/mcp-guide.md` § mcp-setup.md Template. Include per-server env-var requirements and OAuth steps. Omit when no auth is needed and no pre-existing file existed.

**Step 7 — Auto-install matching plugins** (after Phase 8 metadata is written, see § Auto-install Plugins below). Running after metadata ensures telemetry is persisted even if install fails.

**Step 8 — Post-emit stdout summary**. Print a terse block listing each emitted server and any pending auth steps. See `references/mcp-guide.md` § Post-emit Summary.

#### Auto-install Plugins

After the metadata file is written in Phase 8, invoke `scripts/install-plugins.sh <plugin1> <plugin2> ...` for each server's `plugin` field (if present). The script:

1. Probes `claude plugin list --json` once
2. Skips plugins already installed
3. Calls `claude plugin install <plugin>` for each remaining plugin
4. Logs failures to stdout but always exits 0 — install layer must never fail Phase 7a

On completion, update `mcpStatus.autoInstalled` and `mcpStatus.autoInstallFailed` in `onboard-meta.json` (re-write the single field; do not touch other keys).

### Output Styles (.claude/output-styles/) — Phase 7b

Follow `references/output-styles-guide.md` for archetype inference, frontmatter schema, and `settings.local.json` merge rules. Follow `references/output-styles-catalog.md` for the 5 body templates.

**When to run**: After Phase 7a (MCP) and before Hooks are merged. Phase 7b runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — wizard answer** | `wizardAnswers.outputStyleTuning` present with `mode: "tuned"` | Use wizard's archetype override + activation default. Run Step 6 batched confirmation unless headless. |
| **Path B — Quick Mode default** | wizard absent OR `mode: "defaults"` | Infer top-priority archetype from signals (Steps 1+3). Emit catalog defaults + snapshot + telemetry `status: "emitted"`. **No silent no-op.** |
| **Path SUPPRESS — tuning disabled** | `callerExtras.disableOutputStyleTuning === true` | Same as Path B but skip Step 6 batched confirmation entirely. Artifacts ARE generated. Telemetry: `outputStyleStatus: { status: "emitted", source: "inferred", ... }`. |
| **Path DECLINED** | wizard `archetypeOverride === "skip-emit"` | No file written. Telemetry: `outputStyleStatus: { status: "declined", reason: "skip-emit-selected" }`. |
| **Path NO-CANDIDATES** | candidate set empty after Steps 1+2 | No file written. Telemetry: `outputStyleStatus: { status: "skipped", reason: "archetype-not-fired" }`. |

**Inputs**:
- `analysis.*` — existing wizard + analysis signals (teamSize, projectMaturity, primaryTasks, securitySensitivity, deployFrequency, painPoints, project description)
- `wizardAnswers.outputStyleTuning` (optional) — `{ mode, archetypeOverride?, activationDefault? }`. Treat absence as `{ mode: "defaults" }`
- `callerExtras.disableOutputStyleTuning` (optional, headless) — see Path SUPPRESS above

**Telemetry contract**: `outputStyleStatus` MUST be present in `onboard-meta.json` after every generation. The SUPPRESS-PROMPT-ONLY family (`disableOutputStyleTuning`) MUST NOT collapse to `status: "skipped"` — that's the SKIP-PHASE family's behavior, and Phase 7b has no SKIP-PHASE flag.

**Step 1 — Classify firing archetypes.** Evaluate the 5 firing conditions from `output-styles-guide.md` § Archetype inference. Record the full firing set — even archetypes that won't be chosen — in `outputStyleStatus.planned[]` for telemetry.

**Step 2 — Apply wizard override.** Read `wizardAnswers.outputStyleTuning.archetypeOverride`:

| Override value | Effect |
|---|---|
| absent / `"inherit"` | Use Step 1 firing set unchanged; pick top priority in Step 3 |
| `onboarding` / `teaching` / `production-ops` / `research` / `solo` | Force that archetype as the sole candidate, regardless of Step 1 firing set. Mark `source: "user-tweaked"` |
| `"skip-emit"` | Record `outputStyleStatus.skipped = [{ reason: "skip-emit-selected" }]`; exit Phase 7b without emitting any file. Do NOT populate snapshot. Do NOT touch settings.local.json |

**Step 3 — Resolve priority.** From the candidate set produced by Steps 1+2, apply priority: `production-ops > onboarding > teaching > research > solo`. Emit ONLY the top match. If the candidate set is empty (no archetype fired, no override), record `outputStyleStatus.skipped = [{ reason: "archetype-not-fired" }]` and exit without emission.

**Step 4 — Pre-existing file check.** Probe `.claude/output-styles/` for a file matching the target filename (e.g., `operator.md` for `production-ops`). If present:
- Do NOT overwrite
- Add the filename stem to `outputStyleStatus.existedPreOnboard[]`
- Do NOT write a snapshot entry for this style
- Skip Steps 6–8 for this style
- Continue to Step 9 (telemetry) so the skip is visible

**Step 5 — Compose frontmatter.** Combine catalog defaults from `output-styles-catalog.md` with internal tracking fields:

| Field | Source |
|---|---|
| `name` | Filename stem (e.g., `operator`) |
| `description` | Catalog description verbatim (no project substitution) |
| `keep-coding-instructions` | `true` (all 5 archetypes) |
| `archetype` | The chosen archetype string |
| `source` | `inferred` (Step 1+3 only), `wizard-default` (`tuned` mode with `inherit` override), `user-tweaked` (explicit override), `user-confirmed` (accepted in Step 6 batched confirmation) |

**Step 6 — Batched confirmation.** Present a single `AskUserQuestion` with:
- One row showing: archetype, target path, activation default
- Options: **Accept** (default), **Override archetype** (re-prompt with the 7-option archetype list), **Skip emit** (record `{reason: "user-declined-confirmation"}` and exit)

**Headless passthrough**: when `callerExtras.disableOutputStyleTuning` is `true`, skip Step 6 entirely and emit with the Step 5 frontmatter as-is. Mirrors the `callerExtras.disableMCP` and `callerExtras.disableSkillTuning` patterns.

**Step 7 — Write the style file.** Emit `.claude/output-styles/<name>.md` with the frontmatter from Step 5 followed by the catalog body template. Project-specific markers (`<angle-bracket>` placeholders) are filled from `analysis.*`; drop the parent sentence when a marker can't be filled cleanly.

**Step 8 — Write drift snapshot.** Write (or create if absent) `.claude/onboard-output-style-snapshot.json` with ONE entry per emitted style. Snapshot tracks frontmatter fields only — body edits never trigger drift. Pure JSON, no maintenance header. Multi-run accumulation: append, never prune (see `output-styles-guide.md` § Snapshot contract § Multi-run accumulation).

```jsonc
{
  "operator": {
    "name": "operator",
    "description": "Terse production voice for security-sensitive and infrastructure-critical work...",
    "keep-coding-instructions": true,
    "archetype": "production-ops",
    "source": "inferred"
  }
}
```

**Step 9 — Apply `settings.local.json` merge** (only if `wizardAnswers.outputStyleTuning.activationDefault === "write-to-settings"`). Apply the 4-case merge from `output-styles-guide.md` § settings.local.json merge rules:

| Case | Action | Telemetry |
|---|---|---|
| File missing | Warn, do NOT create | `settingsLocalWritten: false`, `settingsLocalWarning: "file-missing"` |
| Key absent | Read-modify-write: add `"outputStyle": "<emitted-name>"`, preserve all other keys | `settingsLocalWritten: true`, `settingsLocalWarning: null` |
| Key present, same value | No-op | `settingsLocalWritten: false`, `settingsLocalWarning: "already-set-to-same"` |
| Key present, different value | Block, warn | `settingsLocalWritten: false`, `settingsLocalWarning: "conflict:<existing-value>"` |

Invariants: never create `settings.local.json` from scratch, never overwrite an existing `outputStyle` value, write value as a JSON-quoted string (strict JSON).

**Step 10 — Populate `outputStyleStatus`.** Add to `onboard-meta.json` alongside `mcpStatus` and `skillStatus`:

```jsonc
{
  "outputStyleStatus": {
    "planned": ["operator"],
    "generated": ["operator"],
    "skipped": [],
    "frontmatterFields": {
      "operator": {
        "name": "operator",
        "description": "...",
        "keep-coding-instructions": true,
        "archetype": "production-ops",
        "source": "inferred"
      }
    },
    "activationDefault": "none",
    "settingsLocalWritten": false,
    "settingsLocalWarning": null,
    "existedPreOnboard": [],
    "warnings": []
  }
}
```

**`skipped[].reason` values**: `user-declined-confirmation` | `archetype-not-fired` | `skip-emit-selected` | `caller-disabled`.
**`source` values**: `inferred` | `wizard-default` | `user-confirmed` | `user-tweaked`.
**`settingsLocalWarning` values**: `null` | `"file-missing"` | `"already-set-to-same"` | `"conflict:<existing-value>"`.

**Step 11 — Post-emit stdout summary.** Print a terse block: the emitted style, activation default, any settings.local.json warning, any pre-existing file we preserved. Keep it under 5 lines — most of the useful detail lives in `onboard-meta.json`.

### LSP Plugin Recommendations — Phase 7c

Follow `references/lsp-plugin-catalog.md` for the 12-entry language→plugin mapping. Phase 7c recommends and installs official marketplace LSP plugins based on detected source-file presence. Onboard does NOT emit any project-level `.lsp.json` — installing the right plugin is the complete story (LSP config ships inside each plugin's manifest).

**When to run**: After Phase 7b (Output Styles) and before Hooks. Runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — explicit caller list** | `callerExtras.lspPlugins` is a non-null array | Use it verbatim as the accepted list. Empty array = "detected but declined all" → `lspStatus: { status: "declined", accepted: [] }`. |
| **Path A — wizard answer** | `wizardAnswers.lspPlugins` present | Use wizard's accepted list. Same `declined` semantics if empty. |
| **Path B — Quick Mode default** | wizard answer absent AND callerExtras list absent AND detection found candidates | Accept ALL detected plugins. Emit + snapshot + telemetry `status: "emitted"`. |
| **Path NO-CANDIDATES** | `detect-lsp-signals.sh` returns empty array | No install, no snapshot. Telemetry: `lspStatus: { status: "skipped", reason: "detection-empty", planned: [], generated: [] }`. |
| **Path SKIP — caller-disabled** | `callerExtras.disableLSP === true` | No script run, no install, no snapshot. Telemetry: `lspStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [] }`. **Telemetry IS still written.** |

**Inputs**:
- `callerExtras.disableLSP` (optional, headless) — see Path SKIP above; forge passes `true` by default for placeholder code in scaffolds
- `callerExtras.lspPlugins` (optional, headless) — see Path A above
- `wizardAnswers.lspPlugins` (optional) — see Path A above
- Output of `scripts/detect-lsp-signals.sh "$PROJECT_ROOT"` — JSON array sorted by fileCount desc

**Telemetry contract**: `lspStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | skipped | declined | failed`) per the Default behavior matrix in `generate/SKILL.md`.

**Step 1 — Detect candidate plugins.** Run `scripts/detect-lsp-signals.sh "$PROJECT_ROOT"`. Output is a JSON array sorted by fileCount desc, e.g.:

```json
[
  {"language":"typescript","plugin":"typescript-lsp","fileCount":1247,"extensions":[".ts",".tsx","..."]},
  {"language":"rust","plugin":"rust-analyzer-lsp","fileCount":312,"extensions":[".rs"]}
]
```

Empty array → nothing to recommend. Emit `lspStatus: { planned: [], generated: [] }` and skip the remaining steps.

**Step 2 — Resolve selected plugins.**

- If `callerExtras.lspPlugins` is a non-null array → use it verbatim as the accepted list (headless path; forge supplies an explicit list or nothing).
- Else if `wizardAnswers.lspPlugins` exists (from wizard Phase 5.6) → use that as the accepted list.
- Else → use all detected plugins as the accepted list (autonomous Quick Mode path).

Always preserve the full detected list as `recommended`, independent of what was accepted.

**Step 3 — Compose CLAUDE.md "LSP support" subsection.** Append a small subsection under Plugin Integration in the root CLAUDE.md listing the accepted plugins and their language-server binary install prereqs (from `lsp-plugin-catalog.md`). Keep it under 10 lines. When `accepted` is empty but `recommended` is non-empty, list the recommended ones with a "not installed — run `/onboard:evolve` to install" note instead.

**Step 4 — Metadata-first ordering (mirrors Phase 7a).** Install AFTER metadata is written in Phase 8:

1. Add `lspStatus` placeholder to `onboard-meta.json`: `{ planned: [...], generated: [...], accepted: [...], autoInstalled: [], autoInstallFailed: [], skipped: [...] }` with install fields empty.
2. Wait for Phase 8's metadata write to complete.
3. Invoke `scripts/install-plugins.sh <plugin1> <plugin2> ...` with the accepted list.
4. Update `onboard-meta.json.lspStatus.autoInstalled` and `.autoInstallFailed` from the install script's JSON output (single-field read-modify-write; don't touch other keys).

Rationale: if `claude plugin install` hangs or errors, telemetry must already be persisted. Same contract as Phase 7a.

**Step 5 — Write `.claude/onboard-lsp-snapshot.json`.** Pure JSON, no maintenance header — this is the drift baseline for `update` Step 4b.8 and `evolve` Step 2g:

```json
{
  "recommended": ["typescript-lsp", "rust-analyzer-lsp", "pyright-lsp"],
  "accepted": ["typescript-lsp", "rust-analyzer-lsp"]
}
```

Both arrays are sorted alphabetically for stable diffs. Add the snapshot path to `generatedArtifacts`.

**Step 6 — lspStatus telemetry schema.**

```json
"lspStatus": {
  "planned": ["typescript-lsp", "rust-analyzer-lsp", "pyright-lsp"],
  "accepted": ["typescript-lsp", "rust-analyzer-lsp"],
  "generated": ["typescript-lsp", "rust-analyzer-lsp"],
  "skipped": [{"plugin": "pyright-lsp", "reason": "user-declined"}],
  "autoInstalled": ["typescript-lsp"],
  "autoInstallFailed": [],
  "alreadyInstalled": ["rust-analyzer-lsp"]
}
```

**`skipped[].reason` values**: `user-declined` | `caller-disabled` | `detection-empty`.

**Step 7 — Post-emit stdout summary.** Print a terse block listing accepted plugins, any auto-install failures, and any language-server binaries the user still needs to install manually (per catalog). Keep under 6 lines.

### Built-in Claude Code Skills — Phase 7d

Follow `references/built-in-skills-catalog.md` for the 9-skill catalog, tier classification (core vs extra), detection signals, and stack-specific example templates.

**When to run**: After Phase 7c (LSP) and before Hooks. Runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — explicit caller list** | `callerExtras.builtInSkills` present | Use it verbatim as the accepted list. Empty array = "candidates existed but declined all" → `builtInSkillsStatus: { status: "declined", accepted: [] }`. |
| **Path A — wizard answer** | `wizardAnswers.builtInSkills` present | Use wizard's accepted list. Same `declined` semantics if empty. |
| **Path B — Quick Mode default** | wizard absent AND callerExtras list absent | Accept the full candidate list (4 core + N fired extras). Emit + snapshot + telemetry `status: "emitted"`. **Built-in skills' core tier always fires; this path NEVER produces an empty result.** |
| **Path SKIP — caller-disabled** | `callerExtras.disableBuiltInSkills === true` | No CLAUDE.md subsection, no snapshot. Telemetry: `builtInSkillsStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [] }`. **Telemetry IS still written.** |

**Inputs**:
- `callerExtras.disableBuiltInSkills` (optional, headless) — see Path SKIP above; forge passes `true` by default for placeholder code in scaffolds
- `callerExtras.builtInSkills` (optional, headless) — see Path A above
- `wizardAnswers.builtInSkills` (optional) — see Path A above

**Telemetry contract**: `builtInSkillsStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | skipped | declined | failed`) per the Default behavior matrix in `generate/SKILL.md`.

**Suppression**: Skip entirely when `callerExtras.disableBuiltInSkills: true` (forge default — scaffolded projects have placeholder code so detection signals are premature). When skipped, still emit a `builtInSkillsStatus` entry in meta.json:

```json
{
  "builtInSkillsStatus": {
    "planned": [],
    "generated": [],
    "skipped": [{ "skill": "*", "reason": "caller-disabled" }],
    "warnings": [],
    "detectionSignals": {}
  }
}
```

**Step 1 — Detect candidates.** Run detection against the codebase analysis report:

- **Core skills** (`/loop`, `/simplify`, `/debug`, `/pr-summary`): always candidates. No detection signal needed.
- **Extra skills**: check each signal per the catalog's "Detection signal" and "Analysis report field" columns. Record which signals fired and which did not.

Build the full candidate list: 4 core + N extras (0-5) whose signals fired. Record as `planned[]`.

**Step 2 — Resolve accepted list.** Determine which skills to generate from the candidate list:

- If `callerExtras.builtInSkills` is present → use it verbatim as the accepted list (headless mode). An empty array means "declined all".
- Else if `wizardAnswers.builtInSkills` is present → use it as the accepted list.
- Else (Quick Mode / absent field) → accept the full candidate list (all core + fired extras).

Record as `generated[]`. Skills in `planned[]` but not in `generated[]` go into `skipped[]` with `reason: "user-declined"`.

**Step 3 — Determine placement path.**

- If `effectivePlugins` is non-empty → emit as `### Built-in Claude Code skills` subsection inside `<!-- onboard:plugin-integration:start/end -->`, after the `### Output styles` subsection (content rule #7), before the Plugin Integration closing marker.
- If `effectivePlugins` is empty → emit as a standalone `## Built-in Claude Code skills` section, placed after the last onboard-generated section (identified by maintenance header), before any user-added trailing content.

In both cases, wrap the content in `<!-- onboard:builtin-skills:start -->` / `<!-- onboard:builtin-skills:end -->` markers. The markers are always present regardless of placement path — this makes all drift handlers marker-based.

**Step 4 — Compose the subsection.** For each skill in `generated[]`:

1. Look up the skill in the catalog to get the one-line description.
2. Select the stack-specific example from the catalog's four template tables (frontend / backend / CLI / general), picking the table that matches the project's primary detected stack (highest source file count). If no specific stack matches, use the general fallback.
3. Emit in this format:

```markdown
- `/skill-name` — one-line description.
  Example: project-specific example from catalog.
```

Use rich narrative voice matching the project's autonomy level (per the Tone rules). The subsection header should briefly explain what built-in skills are: "These Anthropic-provided skills are available in every Claude Code session — no plugin install required."

**Step 5 — Write drift snapshot.** Write `.claude/onboard-builtin-skills-snapshot.json`:

```json
{
  "recommended": ["/batch", "/debug", "/loop", "/pr-summary", "/schedule", "/simplify"],
  "accepted": ["/debug", "/loop", "/pr-summary", "/schedule", "/simplify"]
}
```

Plain JSON, no `_generated` header — matches LSP snapshot format. Both arrays sorted alphabetically. Add the snapshot path to `generatedArtifacts` in `onboard-meta.json`.

**Step 6 — Record telemetry.** Add `builtInSkillsStatus` to `onboard-meta.json` alongside `hookStatus`, `mcpStatus`, `skillStatus`, `agentStatus`, `outputStyleStatus`, and `lspStatus`:

```json
{
  "builtInSkillsStatus": {
    "planned": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule", "/batch"],
    "generated": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"],
    "skipped": [{ "skill": "/batch", "reason": "user-declined" }],
    "warnings": [],
    "detectionSignals": {
      "/schedule": "ci-cd-detected",
      "/batch": "source-file-count:247"
    }
  }
}
```

`detectionSignals` only records extras whose signal fired (they appear in `planned`). Core skills don't need detection entries since they're always included.

**`skipped[].reason` values**: `user-declined` | `caller-disabled` | `detection-empty`.

**Step 7 — Post-emit stdout summary.** Print a terse block listing accepted skills and the placement path (inside Plugin Integration or standalone). Keep under 4 lines.

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

1. Returned from `/onboard:generate` in the result summary (see `onboard/skills/generate/SKILL.md` § Step 5)
2. Recorded inside `.claude/onboard-meta.json` under the top-level `hookStatus` key
3. Mirrored by forge into `.claude/forge-meta.json.generated.toolingFlags.hookStatus` (see `forge/skills/tooling-generation/SKILL.md` § Step 4)

This telemetry enables `/forge:status` to report "X/Y hooks wired" and lays the foundation for future adaptive behaviors (e.g. suppress SessionStart reminder after the user dismissed it N times).

**Scope boundary** (load-bearing — read this carefully): `hookStatus` tracks **only** hooks derived from `callerExtras.qualityGates`. Pre-existing format/lint hooks (Prettier, ESLint, Black, rustfmt, etc.), forge-internal hooks (like `forge-evolution-check.sh`), and any other non-Plugin-Integration hooks are **out of scope** for this telemetry. They still get written to `.claude/settings.json` via the normal merge path, but they do **not** appear in `hookStatus.planned` or `hookStatus.generated`. This keeps Plugin Integration Coverage reporting clean — `/forge:status` should never show a confusing "wired 2 hooks but planned 0" because format hooks inflated the count.

The mental model: `hookStatus` answers "how well did the Plugin Integration contract land?", not "how many shell hooks does this project have total?".

**Scope extension — advanced event hooks**: hooks emitted from the Advanced Event Hooks section (SessionEnd, UserPromptSubmit, PreCompact, SubagentStart, TaskCreated, TaskCompleted, FileChanged, ConfigChange, Elicitation) ARE counted in `hookStatus`. They are part of the Plugin Integration contract when the caller requested them via `callerExtras.qualityGates.<event>[]` OR when the wizard's `advancedHookEvents` opt-in selected them. When the inference rules fire them implicitly (see per-event triggers), they are also tracked — the scope boundary is "did a caller or wizard answer ask for this?" not "did the user type a yes". Format/lint hooks and utility hooks (WorktreeCreate init-runner) remain out of scope.

**Canonical `hookStatus` shape** (the source of truth — all downstream consumers use this exact layout):

**Key format**: `<Event>[:<Matcher>][:<Type>]` where:
- `<Event>` is the Claude Code event name (e.g., `SessionStart`, `TaskCompleted`).
- `<Matcher>` is the event's matcher value (tool name, filename glob, MCP server, etc.). Omitted for matcher-incompatible events.
- `<Type>` is the hook type (`prompt`, `agent`, or `http`). **Omitted entirely when type is `command`** — this keeps every pre-upgrade fixture byte-identical.
- When matcher is absent but type is present, the double colon is preserved: `Elicitation::http`. This is intentional — it signals "no matcher, but non-default type" unambiguously.

```jsonc
"hookStatus": {
  "planned": {
    "SessionStart":              1,  // command, no matcher, no type suffix
    "PreToolUse:Write":          1,  // command, matcher present
    "PreToolUse:Bash":           2,  // command, matcher present, 2 entries
    "Stop":                      1,  // command
    "SessionEnd":                1,  // command
    "PreCompact:auto":           1,  // command, matcher present
    "FileChanged:package-lock.json|Cargo.lock": 1,  // command with glob matcher
    // Non-command types surface the :<Type> suffix:
    "UserPromptSubmit:prompt":   1,  // prompt type, no matcher
    "TaskCompleted:agent":       1,  // agent type, no matcher
    "Elicitation::http":         1   // http type, no matcher (double colon preserves position)
    // With both matcher AND non-command type:
    // "Elicitation:vercel:http": 1
  },
  "generated": {
    // Value type varies by hook type — see § Artifact per type:
    //   command → script basename     (.claude/hooks/<name>.sh)
    //   prompt  → prompt filename     (.claude/hooks/<name>.prompt.md) OR inline-snippet fallback (first 50 chars + '…')
    //   agent   → agent name
    //   http    → URL
    "SessionStart":     ["plugin-integration-reminder.sh"],
    "PreToolUse:Write": ["feature-start-detector.sh"],
    "PreToolUse:Bash":  [
      "pre-commit-code-review.sh",
      "pre-commit-verification-before-completion.sh"
    ],
    "Stop":             ["post-feature-revise-claude-md.sh"],
    "SessionEnd":       ["session-end.sh"],
    "PreCompact:auto":  ["pre-compact-checkpoint.sh"],
    "FileChanged:package-lock.json|Cargo.lock": ["file-changed-notice.sh"],
    "UserPromptSubmit:prompt":   ["user-prompt-secret-scan.prompt.md"],
    "TaskCompleted:agent":       ["code-reviewer"],
    "Elicitation::http":         ["https://audit.internal/claude-elicitation"]
  },
  "skipped": [                       // one entry per hook that was planned but NOT generated
    {
      "event": "Stop",               // matches a key in planned{} (including any :Type suffix)
      "skill": "claude-md-management:revise-claude-md",
      "reason": "plugin-not-installed"
    },
    {
      "event": "Elicitation::http",
      "reason": "http-not-opted-in"  // callerExtras.allowHttpHooks was not true
    }
  ],
  "warnings": [                      // free-text warnings emitted during hook generation
    "featureStart.criticalDirs was empty; detector hook not generated",
    "Elicitation:http entry dropped — set callerExtras.allowHttpHooks: true to enable"
  ],
  "downgradeApplied": {              // OPTIONAL — only present when autonomyLevel forced a mode change
    "rule": "autonomyLevel=always-ask → preCommit[].mode=advisory",
    "affectedEntries": ["code-review:code-review", "superpowers:verification-before-completion"]
  }
}
```

**Counting rules**:
- `planned[key]` = **integer** — number of entries in `callerExtras.qualityGates.<field>[]` that map to that exact `<Event>[:<Matcher>][:<Type>]` key. Entries sharing an event but differing in type count as separate keys (e.g., `TaskCompleted` and `TaskCompleted:agent` are distinct). **Only counts qualityGates-derived hooks, never format/lint/forge-internal.**
- `generated[key]` = **array** of artifact references for hooks actually written to `.claude/settings.json` from the qualityGates spec. Value semantics depend on type (see § Artifact per type under Advanced Event Hooks).
- `skipped[]` = a record for every entry in `planned` that did NOT produce a corresponding `generated` entry. The `event` field must match a `planned` key verbatim (including type suffix). Reasons include `plugin-not-installed`, `condition-unsatisfied`, `empty-critical-dirs`, plus the 11 type-validation reasons listed in § Hook Type Validation.
- `warnings[]` = operator-facing messages (not user-facing) about soft issues during generation.
- `downgradeApplied` (optional) = records the autonomyLevel-aware preCommit mode downgrade rule when it fires. Only present when the downgrade actually ran — absent means no downgrade was applied. Gives downstream tooling (status reports, adaptive suppression) provenance without re-deriving.
- **Invariant**: for every event key, `planned[key] - len(generated[key]) == (number of skipped[] entries whose `event` matches that key exactly)`. If this doesn't balance, the telemetry is broken — treat as a generation bug.
- **Backward compat**: for pre-upgrade callers (no `hookType` fields, no `allowHttpHooks`), every key in `planned` / `generated` has NO type suffix — the shape is byte-identical to pre-upgrade fixtures. Type suffixes only appear when a caller/wizard explicitly used a non-command type.

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

#### Advanced Event Hooks (from `qualityGates.<advanced-event>` or wizard opt-in)

In addition to the four core quality-gate categories (sessionStart / preCommit / featureStart / postFeature), onboard emits hooks for nine advanced Claude Code events when the caller requests them or the wizard's advanced-hook step selects them. All templates live in `references/hooks-guide.md` § Advanced Event Templates — this section covers the generation contract only.

##### Input sources (in priority order)

1. **Caller-provided**: `callerExtras.qualityGates.<event>[]` where `<event>` is one of `sessionEnd`, `userPromptSubmit`, `preCompact`, `subagentStart`, `taskCreated`, `taskCompleted`, `fileChanged`, `configChange`, `elicitation`. See `skills/generate/SKILL.md` § Required Context Structure for the per-field shape.
2. **Wizard opt-in**: `wizardAnswers.advancedHookEvents[]` — array of event names the developer selected in the wizard's optional advanced-hooks step. Maps 1:1 to the caller schema keys (lowercase first letter, e.g., `sessionEnd`, not `SessionEnd`).
3. **Inference**: when neither source is present, apply the per-event inference rules below. Inference runs last and never overrides an explicit empty selection.

##### Per-event inference rules

| Event | Inference trigger | Template script (in `references/hooks-guide.md`) |
|---|---|---|
| `SessionEnd` | Always emit (safe cleanup stub) | `session-end.sh` |
| `UserPromptSubmit` | `wizardAnswers.securitySensitivity === "high"` OR `hookify` in `effectivePlugins` | `user-prompt-preflight.sh` |
| `PreCompact` | `wizardAnswers.autonomyLevel ∈ {balanced, autonomous}` AND `analysis.complexity.fileCount > 500` — matcher `"auto"` | `pre-compact-checkpoint.sh` |
| `SubagentStart` | `enriched.enableTeams === true` | `subagent-start-audit.sh` |
| `TaskCreated` | `enriched.enableTeams === true` | `task-created-check.sh` |
| `TaskCompleted` | `enriched.enableTeams === true` AND analyzer detected a test command — replace the `__TEST_CMD__` placeholder in the template with the literal command (e.g. `npm test`, `pytest -q`). Skip this hook entirely if no test command was detected. | `task-completed-verify.sh` |
| `FileChanged` | `enriched.enableEvolution === true` — use the drift-detection matcher set from `references/evolution-hooks-guide.md`; fall back to the generic lockfile matcher when the caller supplies no explicit matcher | `file-changed-notice.sh` or the drift scripts from evolution-hooks-guide |
| `ConfigChange` | Analyzer detected `.claude/settings.json` OR `.claude/rules/` under git version control (`versionControlledClaude === true`) — matcher `"project_settings"` | `config-change-warn.sh` |
| `Elicitation` | `.mcp.json` present in the repo OR analyzer reports MCP servers in the stack — omit matcher unless caller names specific servers | `elicitation-audit.sh` |

##### Per-event defaults (hook type)

When neither the caller's `qualityGates.<event>[].hookType` nor `wizardAnswers.advancedHookTypes[<event>]` is set, generation applies these per-event defaults. The third column shows the inference-path upgrade — when the listed condition fires, the default type is upgraded from `command` to the listed alternative (still overridable by the caller/wizard).

| Event | Default type | Inference-path upgrade (auto-fires when silent) |
|---|---|---|
| `SessionStart` | `command` | — |
| `SessionEnd` | `command` | — |
| `UserPromptSubmit` | `command` | → `prompt` (using shipped `default-prompts/user-prompt-secret-scan.md`) when `wizardAnswers.securitySensitivity === "high"` |
| `PreToolUse` / `PostToolUse` | `command` (**locked** — `prompt`/`agent` refused with `unsupported-type-for-event`) | none |
| `Stop` | `command` | — |
| `PreCompact` | `command` | — |
| `SubagentStart` | `command` | — |
| `TaskCreated` | `command` | — (wizard offers `prompt` as manual upgrade only) |
| `TaskCompleted` | `command` | → `agent` when `enriched.enableTeams === true` AND caller supplies `qualityGates.taskCompleted[].agentRef` |
| `FileChanged` | `command` | — |
| `ConfigChange` | `command` | — |
| `Elicitation` | `command` | → `http` when caller supplies `qualityGates.elicitation[].httpUrl` AND `callerExtras.allowHttpHooks === true` |

**Inference-path safety invariants**:
- `UserPromptSubmit` → `prompt` never fires if the wizard/caller explicitly set `hookType: "command"` for that event. Explicit beats inferred.
- `TaskCompleted` → `agent` requires BOTH `enableTeams` AND an `agentRef`. Missing the ref → stay on `command` (never guess which agent to use).
- `Elicitation` → `http` requires BOTH `httpUrl` AND `allowHttpHooks`. Missing either → stay on `command`.
- No `http` path is ever emitted purely from analyzer signals — always requires explicit caller consent (`allowHttpHooks: true`).

##### Hook Type Validation

Each entry passes through this 11-rule validator before the settings.json write. Failures drop the offending entry into `hookStatus.skipped[]` with a structured reason and continue generation. They never abort the run.

| Skip reason | Condition | Remediation hint recorded in `warnings[]` |
|---|---|---|
| `missing-prompt-source` | `hookType="prompt"` but neither `promptRef` nor `promptInline` supplied | "Provide `promptRef` (path) or `promptInline` (text) for prompt-type hooks" |
| `ambiguous-prompt-source` | `hookType="prompt"` with BOTH `promptRef` AND `promptInline` | "Pick exactly one of `promptRef` / `promptInline`" |
| `prompt-file-not-found` | `hookType="prompt"` + `promptRef` points to a file that does not exist | "Create the prompt file at the supplied path or switch to `promptInline`" |
| `missing-agentRef` | `hookType="agent"` but `agentRef` is absent or empty | "Provide `agentRef` naming the agent (e.g. `code-reviewer`)" |
| `missing-httpUrl` | `hookType="http"` but `httpUrl` is absent or empty | "Provide `httpUrl` (https-only)" |
| `unsupported-type-for-event` | `hookType ∈ {prompt, agent}` on `PreToolUse` or `PostToolUse` | "Use `command` type for per-tool-call events" |
| `http-not-opted-in` | `hookType="http"` without `callerExtras.allowHttpHooks === true` | "Set `callerExtras.allowHttpHooks: true` to enable http-type hooks" |
| `insecure-http-url` | `hookType="http"` with URL not starting with `https://` | "Use https; non-https URLs are refused even for loopback" |
| `agent-not-found` | `hookType="agent"` + `agentRef` referencing an agent whose plugin is not in `effectivePlugins` | "Install the agent's plugin or switch to a `command` hook" |
| `invalid-timeout` | `timeout` field present but not a positive integer | "Timeout must be a positive integer in milliseconds" |
| `high-frequency-event-unsuitable-for-agent` | `hookType="agent"` on `UserPromptSubmit` (fires on every prompt; agent latency makes the session unusable) | "Use `prompt` type instead, or keep `command` for low-latency checks" |

**Invariant**: every `skipped[]` entry counts against the event's `planned[eventKey]` in the same way existing skips do. The `planned − len(generated) == count(skipped)` invariant still balances per key.

##### Artifact per type

| Type | `generated[<key>]` array value | Physical file | Plugin-level source of truth |
|---|---|---|---|
| `command` | script basename (e.g., `session-end.sh`) | `${project}/.claude/hooks/<name>.sh` | template in `references/hooks-guide.md` |
| `prompt` | prompt filename (e.g., `user-prompt-secret-scan.prompt.md`) | `${project}/.claude/hooks/<name>.prompt.md` (copied verbatim from `promptRef` file OR written from `promptInline` text if >1 line) | optional default in `references/default-prompts/` |
| `agent` | agent name (e.g., `code-reviewer`) | no new file — references existing agent via `type: "agent"` settings entry | `effectivePlugins` provides the agent |
| `http` | URL (e.g., `https://audit.internal/e`) | no new file — URL lives inline in `settings.json` | caller-supplied |

**`promptInline` special case**: if `promptInline` is 1 line AND ≤200 chars, embed directly in `settings.json` `prompt` field (no sidecar file). Otherwise always write a `.prompt.md` sidecar and reference it via file-read at generation time. `generated[<key>]` records the sidecar filename when present; else the inline text's first 50 chars followed by `…`.

##### Generation rules

1. **Matcher-incompatible events MUST NOT emit a `matcher` field** in the settings entry. Applies to: `SessionEnd`, `UserPromptSubmit`, `SubagentStart`, `TaskCompleted`. See `references/hooks-guide.md` § Matcher Compatibility for the authoritative table. Silently ignoring an extraneous matcher is not acceptable — the generated JSON must be honest.
2. **Matcher-capable events MUST scope narrowly**. `PreCompact` defaults to `"auto"` (manual compactions stay quiet). `FileChanged` must specify a filename glob — omitting the matcher means "watch every file" and produces avoidable noise. `ConfigChange` defaults to `"project_settings"`. `Elicitation` omits the matcher only when the caller explicitly intends to audit every MCP server.
3. **All advanced events are advisory by default** — the generated scripts always `exit 0`. The caller may upgrade `taskCreated` / `taskCompleted` to `mode: "blocking"` explicitly; all other events ignore `mode` (only advisory is supported because Claude Code does not honor `exit 2` on them).
4. **Script generation**: copy the corresponding template from `references/hooks-guide.md` § Advanced Event Templates into `<project>/.claude/hooks/<script-name>`, make executable (`chmod +x`), verify `shellcheck -x` passes. Do NOT re-author the templates inline — the guide is authoritative.
5. **Merge semantics**: same as quality-gate hooks — read existing `.claude/settings.json`, append the new hook entry under its event key, skip if a hook with the same matcher already exists. Never overwrite.
6. **hookStatus telemetry**: every advanced event hook that is planned, generated, or skipped MUST appear in `hookStatus` under the `<Event>[:<Matcher>][:<Type>]` key. The type suffix is **omitted when type is `command`** (backward compatible — existing fixtures are unchanged). Examples: `"PreCompact:auto"` (command, no suffix), `"UserPromptSubmit:prompt"` (no matcher → single colon before type), `"Elicitation::http"` (no matcher + non-command type → double colon preserves position), `"FileChanged:package-lock.json|Cargo.lock"` (command with matcher). The canonical-shape invariant — `planned[event] - len(generated[event]) == count(skipped where event matches)` — applies equally.
7. **Plugin availability**: when an advanced event's inference condition references an installed plugin (e.g., `hookify` for `UserPromptSubmit`), verify the plugin is in `effectivePlugins` before emitting. Missing → record in `hookStatus.skipped[]` with reason `plugin-not-installed`.
8. **Type selection**: apply the per-event default (§ Per-event defaults above) unless the caller/wizard explicitly sets `hookType`. Then run the 11-rule validator (§ Hook Type Validation). A rejected entry records `skipped[]` with the structured reason and NEVER falls back to `command` silently — the caller must see the rejection in telemetry.
9. **Prompt sidecar file**: when `hookType="prompt"` + `promptRef`, copy the source file to `${project}/.claude/hooks/<slug>.prompt.md`. When `hookType="prompt"` + `promptInline` >1 line OR >200 chars, write the inline text to the same sidecar path and reference it. When `promptInline` fits inline, embed directly in settings.json.
10. **Timeout**: if caller supplied `timeout`, use it (after positive-integer validation). Else apply the type default: command 5000, prompt 15000, agent 60000, http 5000 ms.

##### Wizard opt-in plumbing

When `wizardAnswers.advancedHookEvents` is present and non-empty, it takes priority over the inference rules for exactly the events it names. Events not in the array fall back to inference. An empty-but-present array (`[]`) means "user said no to all advanced events" — inference is suppressed entirely for that run (the one exception to rule 3 in Input sources above).

`wizardAnswers.advancedHookTypes` (optional) supplies per-event type selection from Phase 5.1.1. Only judgment-capable events (`userPromptSubmit`, `stop`, `taskCreated`, `taskCompleted`, `elicitation`) honor this field; other event keys are ignored silently. `wizardAnswers.advancedHookTypeExtras` supplies the auxiliary field (`agentRef`, `httpUrl`, `promptRef`, `promptInline`) required by the chosen type — same validator applies.

Mapping from wizard names (camelCase) to hookStatus keys (`Event[:Matcher][:Type]`, type suffix omitted for `command`):

| Wizard name | Default type | hookStatus key examples |
|---|---|---|
| `sessionEnd` | command | `SessionEnd` |
| `userPromptSubmit` | command (→ prompt on security-high) | `UserPromptSubmit`, `UserPromptSubmit:prompt` |
| `preCompact` | command | `PreCompact:auto` |
| `subagentStart` | command | `SubagentStart` |
| `taskCreated` | command | `TaskCreated`, `TaskCreated:prompt` (wizard upgrade), `TaskCreated:http` (wizard upgrade) |
| `taskCompleted` | command (→ agent on teams + agentRef) | `TaskCompleted`, `TaskCompleted:agent`, `TaskCompleted:prompt`, `TaskCompleted:http` |
| `fileChanged` | command | `FileChanged:<matcher>` (matcher derived from analyzer signals or defaulted to lockfiles) |
| `configChange` | command | `ConfigChange:project_settings` |
| `elicitation` | command (→ http on httpUrl + allowHttpHooks) | `Elicitation`, `Elicitation:<mcp-server>`, `Elicitation::http`, `Elicitation:<mcp>:http` |

##### Scope note

Advanced event hooks complement — they do not replace — the core four quality-gate categories. SessionStart (plugin integration reminder), preCommit (commit gating), featureStart (new-file detector), and postFeature (phase-end nudge) continue to fire under their existing rules. Advanced event hooks are additive.

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
- Plugin detection results: `detectedPlugins` object — always populated from `effectivePlugins`, `effectiveCoveredCapabilities`, `effectiveQualityGates`, `effectivePhaseSkills` (resolved per § Effective Plugin List Resolution). Populate regardless of `pluginSource` so that `onboard:update` has a single canonical baseline to diff against. When `effectivePlugins` is empty, write `detectedPlugins: { installedPlugins: [], coveredCapabilities: [], qualityGates: {}, phaseSkills: {} }` — do not omit the field.
- Plugin source: `pluginSource` — `"callerExtras"` | `"self-detected"` | `"none"` — records how the effective plugin list was resolved (headless callers still get `detectedPlugins` mirrored for drift-detection continuity)

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
- [ ] onboard-meta.json records pluginSource
- [ ] onboard-meta.json.detectedPlugins is populated unconditionally (from effectivePlugins resolution), including headless runs — empty object is valid but the field must exist
- [ ] If both plugins installed: no "Recommended Plugins" section in CLAUDE.md
- [ ] CLAUDE.md "Development Workflow" references match actually installed plugins (no dangling refs)
- [ ] PR template includes TDD checklist item ("Tests written first, all pass")
- [ ] No stale references to `minimal`, `write-after`, or `comprehensive` testing philosophies
- [ ] Phase 7a ran before Hooks section (when any MCP candidate fires)
- [ ] `.mcp.json` is pure JSON (no comments) and uses `${VAR}` form for secrets
- [ ] Pre-existing `.mcp.json` was NOT overwritten (check for `mcpStatus.existedPreOnboard`)
- [ ] `.claude/onboard-mcp-snapshot.json` matches what was written to `.mcp.json`
- [ ] `onboard-meta.json.mcpStatus` populated alongside `hookStatus` (with `status` enum value)
- [ ] `.claude/rules/mcp-setup.md` emitted when any server needs auth OR pre-existing file detected
- [ ] Auto-install ran after metadata write (never before)
- [ ] `callerExtras.disableMCP: true` skips artifact writes BUT still emits `mcpStatus: { status: "skipped", reason: "caller-disabled" }` (SKIP-PHASE family contract)
- [ ] Phase 7b ran after Phase 7a and before Hooks
- [ ] Emitted output-style file is at `.claude/output-styles/<archetype-name>.md` with matching `name` frontmatter
- [ ] Pre-existing output-style file was NOT overwritten (check for `outputStyleStatus.existedPreOnboard[]`)
- [ ] `.claude/onboard-output-style-snapshot.json` contains frontmatter-only entry for the emitted style
- [ ] `onboard-meta.json.outputStyleStatus` populated alongside `mcpStatus` (with `status` enum value)
- [ ] `settings.local.json` was NOT created from scratch (Case 1 warns only)
- [ ] Existing `outputStyle` in `settings.local.json` was NOT overwritten (Cases 3/4 warn only)
- [ ] `callerExtras.disableOutputStyleTuning: true` ONLY suppresses Step 6 batched confirmation; artifacts + snapshot + `outputStyleStatus: { status: "emitted", source: "inferred" }` are STILL produced (SUPPRESS-PROMPT family contract)
- [ ] CLAUDE.md Plugin Integration includes the `### Output styles` subsection (built-ins + emitted custom + activation path)
- [ ] Phase 7c (LSP) emitted `lspStatus` regardless of firing path — `status` is one of: `emitted`, `skipped`, `declined`
- [ ] `callerExtras.disableLSP: true` skips artifact writes BUT still emits `lspStatus: { status: "skipped", reason: "caller-disabled" }` (SKIP-PHASE family contract)
- [ ] Phase 7d ran after Phase 7c (LSP) and before Hooks section
- [ ] `<!-- onboard:builtin-skills:start/end -->` markers present in CLAUDE.md (inside Plugin Integration or standalone)
- [ ] `.claude/onboard-builtin-skills-snapshot.json` contains `recommended` and `accepted` arrays (plain JSON, no `_generated`)
- [ ] `onboard-meta.json.builtInSkillsStatus` populated alongside `hookStatus`, `mcpStatus`, `skillStatus`, `agentStatus`, `outputStyleStatus`, `lspStatus` (with `status` enum value)
- [ ] `callerExtras.disableBuiltInSkills: true` skips artifact writes BUT still emits `builtInSkillsStatus: { status: "skipped", reason: "caller-disabled" }` (SKIP-PHASE family contract)
- [ ] CLAUDE.md includes `### Built-in Claude Code skills` subsection (or standalone `## Built-in Claude Code skills` section when no plugins) with project-specific examples
- [ ] **Pre-exit self-audit**: all 4 Phase 7 telemetry keys (`mcpStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`) exist in `onboard-meta.json` — missing key = hard-fail before returning

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
