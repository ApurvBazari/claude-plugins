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
<!-- onboard v0.1.0 | Generated: YYYY-MM-DD -->
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
    "version": "0.1.0",
    "date": "YYYY-MM-DD"
  }
}
```

## Autonomy Cascade

The developer's `autonomyLevel` preference cascades across all generated artifacts. Use this table to determine defaults:

| Aspect | Always-Ask | Balanced | Autonomous |
|--------|-----------|----------|------------|
| **Hooks** | No auto hooks (comment listing available hooks) | Auto-format on Write | Auto-format + auto-lint on Edit |
| **Rule language** | "consider", "discuss with developer" | "should", "recommended" | "must", "always", "never" |
| **Agent tool access** | All agents read-only (output as suggestions) | Reviewers read-only, generators read-write | All agents read-write including Bash |
| **CLAUDE.md rules** | 8-12 extensive items including "check with developer" | 4-6 moderate items | 2-3 hard safety rules only |
| **Skill detail** | Verbose with examples + alternatives + checkpoints | Standard with key examples | Concise, pattern-focused templates |

**Conflict resolution**: When `autonomyLevel` and `codeStyleStrictness` produce conflicting tone verbs, `autonomyLevel` overrides for tone (how assertive the language is), while `codeStyleStrictness` controls quantity (how many rules/checks are generated).

## Artifact Generation Rules

### Root CLAUDE.md

Follow `references/claude-md-guide.md` for structure and best practices.

- **100-200 lines max** — Concise but comprehensive (excluding regeneratable sections like Plugin Integration)
- **Sections**: Project overview, tech stack summary, build/test/lint/deploy commands, key conventions, critical rules, directory structure overview
- **Include `@imports`** where subdirectory CLAUDE.md files are created
- **Tone matches autonomy level**: "always-ask" = more guardrails and "check with developer" language; "autonomous" = more empowering and "go ahead" language; "balanced" = mix
- **Formatter conventions**: Include formatter settings (from Prettier/Black/rustfmt configs) as explicit conventions in Key Conventions section rather than as path-scoped rules
- **Commands section**: List every discovered build/test/lint/deploy command with brief descriptions
- **Ecosystem plugins section** (if any were set up): If `ecosystemPlugins` is present in wizard answers, add a brief "Ecosystem Plugins" section noting which plugins are active (e.g., "notify: system notifications on task completion", "observe: passive usage analytics at `~/.claude/observability/`"). Include relevant commands (`/notify:status`, `/observe:status`, `/observe:pipeline`).
- **Plugin Integration section** (if `callerExtras.installedPlugins` is non-empty): Generate a dedicated `## Plugin Integration` section that documents the installed Claude Code plugins and how to use them on this specific project. See "Plugin Integration Section Generation" below for the full spec.

#### Plugin Integration Section Generation

When `callerExtras.installedPlugins.length > 0`, emit a `## Plugin Integration` section into the root CLAUDE.md. This section must be delimited by section markers so it can be safely regenerated by `/onboard:update` without clobbering user edits elsewhere in the file:

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

**Backward compat**: When `callerExtras` is absent entirely (onboard invoked via standalone `/onboard:init` rather than forge headless mode), skip this section. Do not generate a stub or placeholder.

### Subdirectory CLAUDE.md Files

Follow `references/claude-md-guide.md` for content guidance.

- **Create when all three criteria are met**: (1) directory contains a meaningful share of source files, (2) has distinct conventions not covered by root, (3) represents an architectural boundary
- **File share thresholds scaled by project size**:
  - Small projects (<100 source files): directory has >20% of total source files
  - Medium projects (100-500 source files): directory has >10% of total source files
  - Large projects (>500 source files): directory has >5% of total source files
- **Monorepo packages are automatic candidates** — each package is an architectural boundary by definition
- **Typical candidates**: `src/components/`, `src/api/`, `src/lib/`, `app/`, `tests/`, `scripts/`, per-package in monorepos
- **Always confirm** candidate directories with the developer before creating subdirectory CLAUDE.md files
- **Content**: Conventions specific to that directory, patterns to follow, common mistakes to avoid
- **Keep short** — 30-80 lines each

#### Per-Directory Skill Annotations (Plugin-Aware)

When `callerExtras.installedPlugins.length > 0`, extend each generated subdirectory CLAUDE.md with a `## Skill recommendations` block that maps the directory's role to installed-plugin skills. The block is additive — it supplements the directory's conventions, it does not replace them.

**Rules**:

1. **Only add the block when** an installed plugin's capability meaningfully applies to the directory's role. Never stub "Skill recommendations: none". Directories with no matching plugin capability get no block.
2. **Derive mapping from** (a) directory role (identified by config-generator: `domain`, `parser`, `data-layer`, `compose-ui`, `api`, `tests`, `scripts`, etc.), and (b) `callerExtras.coveredCapabilities`.
3. **Brainstorming first** (when superpowers is installed): every annotation that invites new code creation must reference `/superpowers:brainstorming` as the entry point — e.g., *"Before adding a new Parser, run `/superpowers:brainstorming` to explore approaches."*
4. **Be specific** about *when* to invoke each skill. Vague references like "use feature-dev" are not helpful; *"use `feature-dev:code-architect` when drafting a new Parser contract, then TDD via `superpowers:test-driven-development`"* is.
5. **Don't repeat root** — the subdirectory block assumes the reader has already seen the root Plugin Integration section.

**Example annotations**:

- `domain/parser/CLAUDE.md` → *"When adding a new parser implementation, run `/superpowers:brainstorming` first to confirm the design with the user, then use `feature-dev:code-architect` to draft the contract, then `superpowers:test-driven-development` for the test harness."*
- `ui/compose/CLAUDE.md` → *"For new screens, run `/superpowers:brainstorming` to explore layouts, then `frontend-design:frontend-design` to avoid generic AI aesthetics. Follow TDD via `superpowers:test-driven-development`."*
- `data/db/CLAUDE.md` → *"Schema changes must update Room's exported schemas; run `/code-review:code-review` before committing migrations."*

**Graceful degradation**: If `callerExtras.installedPlugins` is empty or `callerExtras` is absent, generate subdirectory CLAUDE.md files as usual without the Skill recommendations block. See `references/claude-md-guide.md` for the block format and additional examples.

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
- **Plugin cross-references** (headless mode, `allowPluginReferences` flag): When `callerExtras.installedPlugins` is non-empty, rules MAY reference installed plugins instead of duplicating their guidance. For example, `testing.md` can say *"This project uses `superpowers:test-driven-development` — follow its red/green/refactor loop"* instead of restating TDD guidance inline. This is controlled by a new generation flag `allowPluginReferences: true` (default `true` when `installedPlugins` is non-empty, else `false`). Before referencing a plugin, verify it's in `installedPlugins` — never create dangling refs. If a rule references a plugin and that plugin is later uninstalled, `/onboard:update` should refresh the rule to its standalone version.

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

When `callerExtras.coveredCapabilities` is present in the headless context, **skip agents whose capability is already covered by an installed plugin**. Project-level agents in `.claude/agents/` take priority over plugin agents, so generating a generic `code-reviewer.md` would shadow a superior plugin implementation.

**Capability → Agent skip map:**

| If `coveredCapabilities` includes | Skip generating |
|---|---|
| `code-review` | `code-reviewer.md` |
| `test-generation` | `tdd-test-writer.md` |
| `security-audit` | `security-checker.md` |
| `feature-development` | `feature-builder.md` |
| `documentation` | `documentation-writer.md` |

**What to generate instead**: Focus on gap-filling, project-specific agents that no plugin covers — e.g., a `db-migration.md` agent for Prisma projects, or a stack-specific scaffolding agent. These provide value that generic plugins cannot.

**When `coveredCapabilities` is absent**: Generate all agents as usual (backward compatible with standard `/onboard:init` and callers that don't provide capability data).

### Plugin-Aware TDD Workflow

All projects use TDD (red-green-refactor). Generation adapts based on which workflow plugins are installed. Resolve installed plugins from `callerExtras.installedPlugins` (headless mode) or fall back to "no plugins installed" (standard mode).

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

#### Quality-Gate Hooks (from `callerExtras.qualityGates`)

When `callerExtras.qualityGates` is present in headless mode, generate boundary-enforcement hooks that reinforce the CLAUDE.md Plugin Integration discipline. Four hook categories are supported, each driven by a field on the `qualityGates` object:

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

**Plugin availability check**: Before generating a hook entry for a `preCommit` / `postFeature` skill reference, verify the referenced plugin is actually in `callerExtras.installedPlugins`. If missing, skip that hook entry silently and append a warning to `onboard-meta.json` under `warnings[]`. Never fail the generation.

**Merge semantics**: All quality-gate hooks merge into `.claude/settings.json` following the existing merge strategy (see `references/hooks-guide.md` § Settings Merge Strategy). If a hook with the same matcher/event already exists, skip don't duplicate.

See `references/hooks-guide.md` for generated script templates, ShellCheck requirements, and concrete examples of sessionStart + featureStart + preCommit hooks.

#### O6 — SessionStart reminder hook

When `qualityGates.sessionStart` is non-empty AND at least one entry's `condition` resolves to `true` (e.g., `"superpowers-installed"` + superpowers is in `installedPlugins`), generate:

1. A ShellCheck-clean script at `<project>/.claude/hooks/plugin-integration-reminder.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # Generated by onboard — plugin integration session-start reminder
   # Advisory only. Always exits 0.

   echo "Session reminder: Starting new feature work? Begin with /superpowers:brainstorming."
   echo "See root CLAUDE.md § Plugin Integration for the full workflow."
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

**Reminder text composition**: concatenate all qualifying `sessionStart[].message` values, then truncate to ≤ 3 lines total (one greeting + one brainstorming cue + one pointer to CLAUDE.md). Never emit more than 3 lines regardless of how many entries exist (EC11).

**Skip conditions**:
- No qualifying entries → do not write the script or the settings.json entry.
- `superpowers` not installed → the default "superpowers-installed" condition fails; the entry is dropped.

**Script requirements**:
- `#!/usr/bin/env bash` + `set -euo pipefail`
- `shellcheck -x` must pass
- Keep under 10 lines total (excluding comments)
- Reference pattern: `.claude/hooks/post-edit.sh` in the repo root

#### O7 — Feature-start detector PreToolUse hook

When `qualityGates.featureStart` is non-empty AND `criticalDirs` is non-empty, generate:

1. A ShellCheck-clean script at `<project>/.claude/hooks/feature-start-detector.sh` that fires a reminder only when all of the following hold:
   - Tool being called is `Write` (matcher check)
   - Target file does **not** yet exist (new file creation, `! -f "$file_path"`)
   - Target path matches one of the `criticalDirs` patterns (regex union)
   - Target path does NOT match `**/build/**`, `**/generated/**`, or `**/.git/**` (EC10)
   - No session marker exists at `.claude/session-state/brainstormed-${CLAUDE_SESSION_ID}` (EC8 + brainstorming already fired)

   Template:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # Generated by onboard — feature-start detector
   # Advisory only. Always exits 0. Non-blocking.

   input=$(cat)

   # jq-preferred, grep/sed fallback (see hooks-guide.md parsing pattern)
   tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || \
               echo "$input" | grep -o '"tool_name": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
   [ "$tool_name" != "Write" ] && exit 0

   file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || \
               echo "$input" | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
   [ -z "$file_path" ] && exit 0

   # Only fire on new file creation
   [ -f "$file_path" ] && exit 0

   # Skip generated / build / git paths
   case "$file_path" in
     */build/*|*/generated/*|*/.git/*) exit 0 ;;
   esac

   # Critical-dir match (regex populated from qualityGates.featureStart[].criticalDirs)
   critical_regex='(domain/parser/|ui/compose/|data/db/)'
   if ! echo "$file_path" | grep -Eq "$critical_regex"; then
     exit 0
   fi

   # Skip if brainstorming already fired in this session
   marker=".claude/session-state/brainstormed-${CLAUDE_SESSION_ID:-unknown}"
   [ -f "$marker" ] && exit 0

   echo "Reminder: creating $file_path in a domain-critical directory."
   echo "Consider /superpowers:brainstorming and the relevant feature-dev skill first."
   exit 0
   ```

2. A PreToolUse entry in `<project>/.claude/settings.json`:

   ```jsonc
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write",
           "hooks": [
             { "type": "command", "command": ".claude/hooks/feature-start-detector.sh", "timeout": 5000 }
           ]
         }
       ]
     }
   }
   ```

**Regex construction**: escape each `criticalDirs` entry with regex-safe quoting, join with `|`, wrap in `()`. Example: `["domain/parser/", "ui/compose/"]` → `(domain/parser/|ui/compose/)`.

**Skip conditions**:
- No `featureStart` entries or empty `criticalDirs` → do not write the script or the settings.json entry.
- `$CLAUDE_SESSION_ID` unset → conservative default: the marker path resolves to `.../brainstormed-unknown` which likely doesn't exist, so the hook fires. Acceptable false-positive cost given the alternative (missed reminder) is worse.

**Script requirements**:
- `#!/usr/bin/env bash` + `set -euo pipefail`
- `shellcheck -x` must pass
- Never `exit 2` — this hook is **always** advisory
- Reference patterns: `.claude/hooks/validate-bash.sh` for stdin parsing, `.claude/hooks/post-edit.sh` for advisory exit

### Collaboration Artifacts

Follow `references/collaboration-guide.md` for templates and conventions.

**Always generate** regardless of team size — solo developers benefit from consistency:

- **PR Template** (`.github/PULL_REQUEST_TEMPLATE.md`) — Structured PR template with summary, type-of-change checkboxes, and checklist. Add stack-specific items based on analysis. Add security items if `securitySensitivity` is elevated/high. Include a note for the developer to customize after reviewing.
- **Commit Conventions** (`.claude/rules/commit-conventions.md`) — Path-scoped rule (`paths: **`) for Conventional Commits format. Strictness of language matches `codeStyleStrictness`.
- **Shared vs Local Settings Guidance** — Include a section in root CLAUDE.md explaining `.claude/settings.json` (shared, committed) vs `.claude/settings.local.json` (personal, gitignored).
- **Gitignore Entry** — If `.gitignore` exists in the project root, append `.claude/settings.local.json` to it (if not already present). This ensures personal settings are never committed.

### Metadata (.claude/onboard-meta.json)

Always generate this file with:
- Plugin version
- Timestamp
- Wizard answers (structured)
- List of generated artifacts
- Model recommendation and whether user approved

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
- `references/worktree-workflow.md` — Git worktree development pattern
