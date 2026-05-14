# greenfield — Internal Conventions

Scaffolds new projects with AI-native, auto-evolving Claude Code tooling. Three-phase flow: Context Gathering → Scaffold → AI Tooling. Delegates tooling generation to onboard's enriched headless mode.

## Architecture

```
/greenfield:start
     │
     ▼
Phase 1: Context Gathering ──→ context-gathering skill (adaptive wizard)
     │                            ├── stack-researcher agent (WebSearch)
     │                            └── synthesis-review skill (Phase 1.8 — invoked inline at end of each major step;
     │                                                         Round 2 / 2.5 / 3: Step 2.5 → architecturalFraming, Step 3 → dataArchitecture, Step 4 → apiIntegration, Step 5 → auth, Step 6 → privacy, Step 7 → security, Step 8 → runtimeOperations, Step 11 → cicdAndDelivery, Step 15 → architecturalValidation)
     │
     ├── Phase 1.5 (conditional): Architectural Research — resolves parked questions
     │
     ▼
Phase 1.7: Pre-Scaffold Spec Grilling ──→ grill-spec skill
     │                                       ├── adjust-dialog skill (5-category adversarial walk)
     │                                       └── Else: inline fallback (if adjust-dialog unavailable)
     │                                       Cross-checks against context.syntheses.* (Round 2.5 / 3: architecturalFraming, dataArchitecture, apiIntegration, auth, privacy, security, runtimeOperations, cicdAndDelivery, architecturalValidation)
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
     ├── Greenfield-only artifacts:
     │   ├── init.sh (stack-specific env bootstrap)
     │   └── docs/feature-list.json (from Phase 1 decomposition)
     │
     └── Handoff ──→ summary + next steps
```

## Dependency on Onboard

Greenfield is a thin orchestrator. Onboard does ALL tooling generation via its `generate` skill (invoked through the Skill tool as `onboard:generate`):
- Core: CLAUDE.md, rules, skills, agents, hooks, PR template
- Enriched: CI/CD pipelines, harness guide, evolution hooks, sprint contracts, team support

Greenfield only generates two artifacts that require scaffold-specific knowledge:
- `init.sh` — stack-specific install + dev server command (from scaffold output)
- `docs/feature-list.json` — feature decomposition from Phase 1 app description

## Skill Hierarchy

- `context-gathering/SKILL.md` — Phase 1: adaptive state-machine wizard (3.0 Round 2 / 2.5 / 3 / 4: 17 wizard steps (1–15 + Round 4 inserts at 2.2 + 2.7); Step 2.2 = Personas / personas (16 Qs heavy / 4 Qs light — Round 4), Step 2.5 = Architectural Framing / architecturalFraming (4 Qs — topology, deploymentShape, scaleTarget, boundaryNotes), Step 2.7 = Domain Modeling / domainModel (11 Qs Full DDD / ~8 DDD-lite / ~6 Light — Round 4), Step 3 = Data Architecture / dataArchitecture (12 Qs), Step 4 = API & Integration / apiIntegration (10 Qs), Step 5 = Auth & Identity / auth, Step 6 = Privacy & Data Governance / privacy, Step 7 = Security / security, Step 8 = Runtime Operations / runtimeOperations, Step 11 = CI/CD & Delivery / cicdAndDelivery (17 Qs from Round 1), Step 15 = Architectural Validation / architecturalValidation (1–2 Qs — final cross-phase sign-off). Round 4 mode toggles (depth / coupling / domainFormat) set at Step 1.1 and gate downstream Q counts. Total ~120 Qs heavy / ~65 Qs light depending on stack + deploy + persona/entity loop counts.)
- `synthesis-review/SKILL.md` — Phase 1.8: per-phase synthesis review. Renders `docs/adr/<topic-kebab>.html` in the scaffolded project, walks Approve/Adjust/Skip per section, writes `dependencies.json` sidecar, installs freshness hook. Invoked inline by `context-gathering` at the end of each major step that has a synthesis template (Round 2 / 2.5 / 3: architecturalFraming at Step 2.5, dataArchitecture at Step 3, apiIntegration at Step 4, auth at Step 5, privacy at Step 6, security at Step 7, runtimeOperations at Step 8, cicdAndDelivery at Step 11, architecturalValidation at Step 15)
- `grill-spec/SKILL.md` — Phase 1.7: pre-scaffold validation gate (5-category decision-tree walk via `greenfield/skills/adjust-dialog/`; falls back to inline if unavailable). Cross-checks against `context.syntheses.*`
- `scaffolding/SKILL.md` — Phase 2: execute scaffold, git setup, verify Hello World
- `tooling-generation/SKILL.md` — Phase 3: prepare context, call enriched onboard, generate init.sh + feature-list.json
- `plugin-discovery/SKILL.md` — Phase 3 (first step): curated catalog + web search, install plugins, compile capabilities

## Agents

- `stack-researcher.md` — web search agent (sonnet) for researching tech stacks during Phase 1
- `scaffold-analyzer.md` — read-only agent that scans the freshly scaffolded project for onboard context

## Skills

User-facing skills (show in `/greenfield:` autocomplete):

- `start/SKILL.md` — full 3-phase flow (context → scaffold → AI tooling). Checks for in-flight state at startup and offers resume. (`disable-model-invocation: true`)
- `pickup/SKILL.md` — resume an in-progress greenfield session from the last checkpoint in `.claude/greenfield-state.json` (auto-invocable)
- `check/SKILL.md` — project health check; also reports in-flight session state if present (auto-invocable)

Internal building blocks (`user-invocable: false`):

- `context-gathering/SKILL.md` — Phase 1 adaptive wizard
- `synthesis-review/SKILL.md` — Phase 1.8 per-phase synthesis review (Round 2 / 2.5 / 3: architecturalFraming at Step 2.5, dataArchitecture at Step 3, apiIntegration at Step 4, auth at Step 5, privacy at Step 6, security at Step 7, runtimeOperations at Step 8, cicdAndDelivery at Step 11, architecturalValidation at Step 15)
- `grill-spec/SKILL.md` — Phase 1.7 pre-scaffold validation gate
- `scaffolding/SKILL.md` — Phase 2 scaffold execution
- `plugin-discovery/SKILL.md` — Phase 3a plugin catalog match + install
- `tooling-generation/SKILL.md` — Phase 3b delegation to `onboard:generate`

Note: `/greenfield:verify`, `/greenfield:evolve` are now `/onboard:verify`, `/onboard:evolve` (universally available, not Greenfield-specific).

## Script Conventions

- `detect-scaffold-cli.sh` — the only Greenfield-specific script (checks available scaffold CLIs)
- All other scripts (drift detection, audit) live in onboard

## Key Patterns

- Adaptive wizard: each answer updates a context object, subsequent questions check preconditions
- Wizard scope protection: "Park it" escape hatch for deep-research questions, optional Phase 1.5 Architectural Research sub-phase
- Progress indicator: every wizard Step emits "Step X of 17" so sessions can't silently derail (17 = 15 R3 steps + Round 4 Step 2.2 Personas + Step 2.7 Domain Modeling)
- Web research: stack-researcher agent searches for latest versions and best practices before scaffolding, with main-session fallback when sub-agent web tools are denied
- Feature decomposition: mandatory — downstream phases depend on `docs/feature-list.json` existing
- Plugin-aware generation: coveredCapabilities passed to onboard, prevents agent shadowing
- Greenfield metadata: `.claude/greenfield-meta.json` records all context, decisions, and generated artifacts (post-scaffold). Schema is the single source of truth at `greenfield/skills/tooling-generation/references/greenfield-meta.schema.json` — tooling-generation Step 4 validates against it before write. As of the 2026-04-16 release-gate L5 alignment, everything lives under `generated.toolingFlags` (tooling/cicd/harness/installedPlugins/coveredCapabilities/qualityGates/phaseSkills + the seven status mirrors). The earlier `generated.tooling` / `generated.cicd` / `generated.harness` sibling keys are removed; old-shape projects heal on next regeneration (no auto-migration).
- **Greenfield state: `.claude/greenfield-state.json` persists in-flight progress** for `/greenfield:pickup`. Checkpoint after every skill Step. Atomic write via `.tmp` + rename.
- **Scaffold modes**: `full` (default — complete scaffold, then AI tooling) vs `walking-skeleton` (minimal scaffold → AI tooling → expand). Walking skeleton is for stacks without a mature CLI or with complex architecture.

## Platform Coverage

Greenfield's approach varies by stack maturity. Be honest about which stacks are verified vs experimental:

| Stack family | Greenfield approach | Mode | Confidence |
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
| Game engines (Unity, Godot, Bevy) | No standard greenfield path; walking skeleton per engine | `walking-skeleton` | Experimental |
| Custom / unusual stacks | Research-driven walking skeleton | `walking-skeleton` | Experimental |

**Rule of thumb**: if the stack has an official `create-*` or `init` CLI that produces a runnable starter app, use `full` mode. If it doesn't, or if the architecture is substantially different from a web/server project, use `walking-skeleton`.

## Anti-patterns to avoid

- **Silent failure on research** — if `stack-researcher` can't reach the web, fall back to main-session research with user-visible permission prompts. Never quietly fail and pretend you researched.
- **Skipping feature decomposition** — it's mandatory. Downstream phases depend on `docs/feature-list.json` existing.
- **Silently skipping Phase 1.8 synthesis review** — synthesis is the no-surprises gate that catches contradictions while per-phase context is still fresh. If a synthesis template exists for a phase, you MUST run it; if it's missing, return `synthesisStatus: "no-template"` cleanly rather than fabricating sections.
- **Re-invoking onboard on partial output** — if a greenfield session was killed mid-`/onboard:generate`, ask before retrying (onboard's state file may be inconsistent).
- **Auto-cleaning partial scaffolds** — never delete files the user might want to inspect. Always ask first.
- **Writing state directly** — always write to `greenfield-state.json.tmp` then rename, to avoid corruption on interrupt.
- **Modifying synthesis HTMLs in scaffolded projects without re-running synthesis-review** — these are living architecture records. Hand-edits create drift the freshness hook will flag but can't reverse. Use `/greenfield:pickup` and restart the relevant phase if a synthesis record needs revision.
