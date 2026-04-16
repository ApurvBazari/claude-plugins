# onboard — Internal Conventions

Interactive wizard that analyzes codebases and generates complete Claude tooling infrastructure. Supports both standalone use (`/onboard:init`) and headless mode for programmatic consumers like Forge.

## Phased Architecture

```
/onboard:init
     │
     ▼
Phase 1: Analysis ──→ codebase-analyzer agent (read-only)
     │                   ├── analyze-structure.sh
     │                   ├── detect-stack.sh
     │                   └── measure-complexity.sh
     ▼
Phase 2: Wizard ──→ wizard skill (adaptive Q&A, presets)
     │
     ▼
Phase 3: Generation ──→ config-generator agent (write)
     │                   ├── Core: CLAUDE.md, rules, skills, agents, hooks
     │                   └── Enriched: CI/CD, harness, evolution, teams (if enabled)
     ▼
Phase 4: Handoff ──→ explains generated artifacts, suggests next steps
```

## Agent Handoff Pattern

- `codebase-analyzer` runs first (read-only) — produces structured analysis report
- Report stays in conversation context — NOT written to a file
- `config-generator` runs second (write) — receives analysis + wizard answers via prompt
- `feature-evaluator` is available for independent feature testing (spawned by `/onboard:verify`)

## Headless Mode (`onboard:generate`)

External plugins (e.g., Forge) invoke the `generate` skill via the Skill tool, skipping the wizard and analysis. The skill is `user-invocable: false` so it doesn't clutter the user's slash menu.

```
generate skill (headless)
     │
     ▼
Pre-seeded context JSON ──→ config-generator agent (write)
     │                        ├── Core artifacts (always)
     │                        └── Enriched artifacts (based on enriched flags)
     ▼
Results report ──→ lists generated artifacts
```

- Context JSON includes `analysis`, `wizardAnswers`, `enriched` flags, and `callerExtras`
- `enriched` flags control: CI/CD, harness, evolution hooks, sprint contracts, teams, verification
- Plugin-aware: `callerExtras.coveredCapabilities` prevents agent shadowing

## Generation Tiers

### Core (always generated)
- Root CLAUDE.md (100-200 lines)
- Subdirectory CLAUDE.md files (if justified)
- Path-scoped rules (.claude/rules/*.md)
- Project-specific skills (.claude/skills/)
- Agents (.claude/agents/) — plugin-aware, skips covered capabilities
- PostToolUse hooks (format, lint)
- PR template + commit conventions
- onboard-meta.json

### Enriched (when enabled via wizard or headless flags)
- CI/CD pipelines (GitHub Actions: ci, tooling-audit, pr-review)
- Harness artifacts (docs/progress.md, docs/HARNESS-GUIDE.md)
- Auto-evolution hooks (FileChanged + SessionStart) + drift detection scripts
- Sprint contracts (docs/sprint-contracts/)
- Agent team support (quality hooks, env var)

## Skill Hierarchy

User-facing skills (show in `/onboard:` autocomplete):

- `init/SKILL.md` — full interactive wizard + generation (`disable-model-invocation: true`)
- `update/SKILL.md` — align with latest best practices (`disable-model-invocation: true`)
- `status/SKILL.md` — tooling health check (auto-invocable)
- `verify/SKILL.md` — independent feature verification via feature-evaluator agent (auto-invocable)
- `evolve/SKILL.md` — apply pending tooling drift updates (auto-invocable)

Internal building blocks (`user-invocable: false` — hidden from menu):

- `generate/SKILL.md` — headless generation API, invoked by forge via Skill tool
- `wizard/SKILL.md` — drives the interactive Q&A (presets: Minimal/Standard/Comprehensive/Custom)
- `analysis/SKILL.md` — tech stack pattern matching, model recommendations
- `generation/SKILL.md` — artifact generation logic, core + enriched modes

## Script Conventions

- Scripts are supplementary — if they fail, the wizard continues with deep exploration only
- POSIX-compatible: must work on macOS (BSD) and Linux (GNU)
- Analysis scripts: `analyze-structure.sh`, `detect-stack.sh`, `measure-complexity.sh`
- Evolution scripts: `detect-dep-changes.sh`, `detect-config-changes.sh`, `detect-structure-changes.sh`
- CI audit script: `audit-tooling.sh`

## Reference Organization

`generation/references/` is the single source of truth:

**Core guides**: claude-md-guide, rules-guide, hooks-guide, skills-guide, agents-guide, collaboration-guide
**Catalog guides**: mcp-guide, output-styles-guide, output-styles-catalog, lsp-plugin-catalog, built-in-skills-catalog
**Extended guides**: harness-design, ci-cd-templates, evolution-hooks-guide, sprint-contracts, agent-teams-guide, worktree-workflow

## Key Patterns

- Maintenance headers on all generated artifacts (version + date)
- Quick Mode: infers wizard answers from analysis results + one autonomy question
- Preset path: pre-filled values for Minimal/Standard/Comprehensive profiles
- Script failure fallback: log failure, continue with codebase exploration only
- Plugin-aware agent generation: check coveredCapabilities before generating agents
- Merge-aware hooks: always read settings.json first, never overwrite
