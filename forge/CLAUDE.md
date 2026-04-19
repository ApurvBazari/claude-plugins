# forge — Internal Conventions

Scaffolds new projects with AI-native, auto-evolving Claude Code tooling. Three-phase flow: Context Gathering → Scaffold → AI Tooling. Delegates tooling generation to onboard's enriched headless mode.

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
     │
     └── Handoff ──→ summary + next steps
```

## Dependency on Onboard

Forge is a thin orchestrator. Onboard does ALL tooling generation via its `generate` skill (invoked through the Skill tool as `onboard:generate`):
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

## Skills

User-facing skills (show in `/forge:` autocomplete):

- `init/SKILL.md` — full 3-phase flow (context → scaffold → AI tooling). Checks for in-flight state at startup and offers resume. (`disable-model-invocation: true`)
- `resume/SKILL.md` — resume an in-progress forge session from the last checkpoint in `.claude/forge-state.json` (auto-invocable)
- `status/SKILL.md` — project health check; also reports in-flight session state if present (auto-invocable)

Internal building blocks (`user-invocable: false`):

- `context-gathering/SKILL.md` — Phase 1 adaptive wizard
- `scaffolding/SKILL.md` — Phase 2 scaffold execution
- `plugin-discovery/SKILL.md` — Phase 3a plugin catalog match + install
- `tooling-generation/SKILL.md` — Phase 3b delegation to `onboard:generate`

Note: `/forge:verify`, `/forge:evolve` are now `/onboard:verify`, `/onboard:evolve` (universally available, not Forge-specific).

## Script Conventions

- `detect-scaffold-cli.sh` — the only Forge-specific script (checks available scaffold CLIs)
- All other scripts (drift detection, audit) live in onboard

## Key Patterns

- Adaptive wizard: each answer updates a context object, subsequent questions check preconditions
- Wizard scope protection: "Park it" escape hatch for deep-research questions, optional Phase 1.5 Architectural Research sub-phase
- Progress indicator: every wizard Step emits "Step X of 8" so sessions can't silently derail
- Web research: stack-researcher agent searches for latest versions and best practices before scaffolding, with main-session fallback when sub-agent web tools are denied
- Feature decomposition: mandatory — downstream phases depend on `docs/feature-list.json` existing
- Plugin-aware generation: coveredCapabilities passed to onboard, prevents agent shadowing
- Forge metadata: `.claude/forge-meta.json` records all context, decisions, and generated artifacts (post-scaffold). Schema is the single source of truth at `forge/skills/tooling-generation/references/forge-meta.schema.json` — tooling-generation Step 4 validates against it before write. As of the 2026-04-16 release-gate L5 alignment, everything lives under `generated.toolingFlags` (tooling/cicd/harness/installedPlugins/coveredCapabilities/qualityGates/phaseSkills + the seven status mirrors). The earlier `generated.tooling` / `generated.cicd` / `generated.harness` sibling keys are removed; old-shape projects heal on next regeneration (no auto-migration).
- **Forge state: `.claude/forge-state.json` persists in-flight progress** for `/forge:resume`. Checkpoint after every skill Step. Atomic write via `.tmp` + rename.
- **Scaffold modes**: `full` (default — complete scaffold, then AI tooling) vs `walking-skeleton` (minimal scaffold → AI tooling → expand). Walking skeleton is for stacks without a mature CLI or with complex architecture.

## Platform Coverage

Forge's approach varies by stack maturity. Be honest about which stacks are verified vs experimental:

| Stack family | Forge approach | Mode | Confidence |
|---|---|---|---|
| Next.js App Router | `create-next-app` CLI + onboard patterns | `full` | Verified |
| Python FastAPI | `uv init` or manual scaffold + onboard | `full` | Verified |
| Go HTTP services | `go mod init` + project layout template | `full` | Verified |
| React (Vite), Vue, Svelte | Framework CLI + onboard | `full` | Works |
| Express, NestJS | Framework CLI + onboard | `full` | Works |
| Rust (Axum, Actix) | `cargo new` + layout guidance | `full` | Works |
| Ruby on Rails | `rails new` | `full` | Works |
| Monorepo (Turborepo, Nx, pnpm) | Tool-specific init + workspace setup | `full` | Works |
| **Android (Kotlin + Compose)** | No CLI; anchor to sibling project if available, else walking skeleton | `walking-skeleton` | **Experimental** |
| **iOS (Swift + SwiftUI)** | No CLI; walking skeleton with SPM setup | `walking-skeleton` | **Experimental** |
| Desktop (Tauri, Electron) | Partial CLI coverage; may use walking skeleton | Either | Experimental |
| Game engines (Unity, Godot, Bevy) | No standard forge path; walking skeleton per engine | `walking-skeleton` | Experimental |
| Custom / unusual stacks | Research-driven walking skeleton | `walking-skeleton` | Experimental |

**Rule of thumb**: if the stack has an official `create-*` or `init` CLI that produces a runnable starter app, use `full` mode. If it doesn't, or if the architecture is substantially different from a web/server project, use `walking-skeleton`.

## Anti-patterns to avoid

- **Silent failure on research** — if `stack-researcher` can't reach the web, fall back to main-session research with user-visible permission prompts. Never quietly fail and pretend you researched.
- **Skipping feature decomposition** — it's mandatory. Downstream phases depend on `docs/feature-list.json` existing.
- **Re-invoking onboard on partial output** — if a forge session was killed mid-`/onboard:generate`, ask before retrying (onboard's state file may be inconsistent).
- **Auto-cleaning partial scaffolds** — never delete files the user might want to inspect. Always ask first.
- **Writing state directly** — always write to `forge-state.json.tmp` then rename, to avoid corruption on interrupt.
