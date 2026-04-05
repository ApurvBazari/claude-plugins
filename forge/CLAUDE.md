# forge — Internal Conventions

Scaffolds new projects with AI-native, auto-evolving Claude Code tooling. Three-phase flow: Context Gathering → Scaffold → AI Tooling.

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
Phase 3: AI Tooling ──→ tooling-generation skill
     │                    ├── invoke /onboard:generate (headless)
     │                    ├── generate CI/CD pipelines
     │                    └── add auto-evolution hooks
     │
     ├── Plugin Discovery ──→ plugin-discovery skill (interactive checklist)
     │
     ▼
Handoff ──→ summary of what was created + next steps
```

## Dependency on Onboard

Forge delegates Claude tooling generation to onboard's headless mode (`/onboard:generate`). Forge gathers context, scaffolds the app, then passes pre-seeded context to onboard for CLAUDE.md, rules, skills, agents, and hooks generation.

Forge handles CI/CD pipelines, auto-evolution hooks, git branching, and plugin discovery independently — these are not part of onboard's scope.

## Skill Hierarchy

- `context-gathering/SKILL.md` — Phase 1: adaptive state-machine wizard (32 questions, developer answers 8-22)
- `scaffolding/SKILL.md` — Phase 2: execute scaffold, git setup, verify Hello World
- `tooling-generation/SKILL.md` — Phase 3a: invoke onboard headless, generate CI/CD, add hooks
- `plugin-discovery/SKILL.md` — Phase 3b: curated catalog + web search, interactive checklist
- `evolve/SKILL.md` — apply pending drift updates from forge-drift.json

## Agent

- `stack-researcher.md` — web search agent (sonnet) for researching tech stacks during Phase 1

## Script Conventions

- Scripts are bundled with Forge and copied into scaffolded projects
- POSIX-compatible: must work on macOS (BSD) and Linux (GNU)
- ShellCheck-clean: all scripts must pass `shellcheck`
- `audit-tooling.sh` is copied to `.github/scripts/` in the generated project
- `detect-*.sh` scripts are copied to `.claude/scripts/` in the generated project

## Key Patterns

- Adaptive wizard: each answer updates a context object, subsequent questions check preconditions
- Web research: stack-researcher agent searches for latest versions and best practices before scaffolding
- Merge-aware: settings.json hooks are always merged, never overwritten
- Forge metadata: `.claude/forge-meta.json` records all context, decisions, and generated artifacts
- Drift ledger: `.claude/forge-drift.json` accumulates changes detected by FileChanged hooks
- Provenance: all generated files trace back to forge-meta.json for auditability
