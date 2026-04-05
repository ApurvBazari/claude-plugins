# forge — Internal Conventions

Scaffolds new projects with AI-native, auto-evolving Claude Code tooling. Three-phase flow: Context Gathering → Scaffold → AI Tooling. Delegates all tooling generation to onboard's enriched headless mode.

## Architecture

```
/forge:init
     │
     ▼
Phase 1: Context Gathering ──→ context-gathering skill (adaptive wizard)
     │                            └── stack-researcher agent (WebSearch)
     ▼
Phase 2: Scaffold ──→ scaffolding skill (execute scaffold + git setup)
     │
     ▼
Phase 3: AI Tooling
     ├── Plugin Discovery ──→ plugin-discovery skill (checklist → install)
     │                         └── compiles coveredCapabilities
     ├── Onboard Headless ──→ /onboard:generate (enriched mode)
     │                         ├── Core: CLAUDE.md, rules, skills, agents, hooks
     │                         └── Enriched: CI/CD, harness, evolution, teams, verification
     ├── Forge-only artifacts:
     │   ├── init.sh (stack-specific env bootstrap)
     │   └── docs/feature-list.json (from Phase 1 decomposition)
     └── Handoff ──→ summary + next steps
```

## Dependency on Onboard

Forge is a thin orchestrator. Onboard does ALL tooling generation:
- Core: CLAUDE.md, rules, skills, agents, hooks, PR template
- Enriched: CI/CD pipelines, harness guide, evolution hooks, sprint contracts, team support

Forge only generates two artifacts that require scaffold-specific knowledge:
- `init.sh` — stack-specific install + dev server command (from scaffold output)
- `docs/feature-list.json` — feature decomposition from Phase 1 app description

## Skill Hierarchy

- `context-gathering/SKILL.md` — Phase 1: adaptive state-machine wizard (33 questions, developer answers 8-22)
- `scaffolding/SKILL.md` — Phase 2: execute scaffold, git setup, verify Hello World
- `tooling-generation/SKILL.md` — Phase 3: prepare context, call enriched onboard, generate init.sh + feature-list.json
- `plugin-discovery/SKILL.md` — Phase 3 (first step): curated catalog + web search, install plugins, compile capabilities

## Agents

- `stack-researcher.md` — web search agent (sonnet) for researching tech stacks during Phase 1
- `scaffold-analyzer.md` — read-only agent that scans the freshly scaffolded project for onboard context

## Commands

- `/forge:init` — full 3-phase flow (context → scaffold → tooling)
- `/forge:status` — project health check (delegates to onboard:status + checks forge-meta.json)

Note: `/forge:verify`, `/forge:evolve` are now `/onboard:verify`, `/onboard:evolve` (universally available, not Forge-specific).

## Script Conventions

- `detect-scaffold-cli.sh` — the only Forge-specific script (checks available scaffold CLIs)
- All other scripts (drift detection, audit) live in onboard

## Key Patterns

- Adaptive wizard: each answer updates a context object, subsequent questions check preconditions
- Web research: stack-researcher agent searches for latest versions and best practices before scaffolding
- Feature decomposition: hybrid approach — auto-generated from app description, developer validates during confirmation
- Plugin-aware generation: coveredCapabilities passed to onboard, prevents agent shadowing
- Forge metadata: `.claude/forge-meta.json` records all context, decisions, and generated artifacts
