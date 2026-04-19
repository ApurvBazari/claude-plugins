# Plugin Integration Rules for Evolve

Distilled rules for regenerating the Plugin Integration section in CLAUDE.md and quality-gate hooks during `/onboard:evolve` and `/onboard:update`.

**Related references**:
- `../../generation/references/plugin-drift-detection.md` — shared probe + diff procedure (baseline resolution, output schema, presentation). Used by update, evolve, and generate.
- `../../generation/references/plugin-detection-guide.md` — canonical probe list, capability mappings, and derivation rules for `coveredCapabilities`, `qualityGates`, `phaseSkills`.
- This document — **application** rules: CLAUDE.md section markers, subsection content, tone.

## Known Plugin Probe List

See `../../generation/references/plugin-detection-guide.md` for the canonical probe list, probe command, capability mappings, and derivation rules for `coveredCapabilities`, `qualityGates`, and `phaseSkills`.

Also probe any plugin in `previousPlugins` that isn't in the known list (custom/third-party plugins).

## Section Marker Template

The Plugin Integration section in CLAUDE.md is always wrapped in these markers:

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

## Subsection Content Rules

Generate only subsections that have at least one installed plugin. Each subsection answers "when do I use this?" tied to the project's tech stack.

### 1. Research & brainstorming

**When**: `superpowers` is in `installedPlugins` (always first subsection).

- Document `/superpowers:brainstorming` as the hard-gated first step for any new feature
- Reference `/superpowers:dispatching-parallel-agents` for parallel web research
- Reference `context7` only if installed (never fabricate)
- Include "design can be a few sentences for trivial work" caveat
- Point at where research outputs are saved

**Graceful degradation**: When `superpowers` is NOT installed, fall back to a generic version recommending built-in `WebSearch`/`WebFetch` and a manual-discussion protocol. Do NOT reference `/superpowers:brainstorming` — it would be a broken command. Add a note suggesting users install superpowers for the full experience.

### 2. Core discipline

**When**: `superpowers` is in `installedPlugins`.

- `superpowers:test-driven-development`
- `superpowers:verification-before-completion`
- `superpowers:systematic-debugging`

Only include skills whose plugin is installed.

### 3. Per-feature workflow

**When**: `feature-dev` is in `installedPlugins`.

- `feature-dev:code-architect`, `code-explorer`, `code-reviewer`

### 4. Commit discipline

**When**: `commit-commands` is in `installedPlugins`.

- `/commit`, `/commit-push-pr`

### 5. Quality gates

**When**: any of `code-review`, `pr-review-toolkit`, `claude-md-management` is installed.

- `code-review:code-review` (if `code-review` installed)
- `pr-review-toolkit:review-pr` (if `pr-review-toolkit` installed)
- `claude-md-management:revise-claude-md` (if `claude-md-management` installed)

### 6. Ecosystem

**When**: any of `hookify`, `security-guidance` is installed.

- `hookify` — behavioral guardrails
- `security-guidance` — hook-based security warnings

## Tone

Rich narrative voice, not a bulleted list of plugin names. Every subsection should answer "when do I use this?" tied to the project's actual tech stack.

## qualityGates, phaseSkills, and coveredCapabilities Derivation

See `../../generation/references/plugin-detection-guide.md` for derivation rules, default templates, and autonomyLevel downgrade logic.

**Evolve-specific note**: When deriving `featureStart.criticalDirs` during evolve, preserve existing `criticalDirs` from `forge-meta.json` or `onboard-meta.json` — evolve does not re-derive directory roles. Read `autonomyLevel` from `forge-meta.json.context.autonomyLevel` or `onboard-meta.json.wizardAnswers.autonomyLevel`.
