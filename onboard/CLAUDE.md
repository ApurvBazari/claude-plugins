# onboard — Internal Conventions

Interactive wizard that analyzes codebases and generates complete Claude tooling infrastructure. The `onboard:generate` skill is an internal generation step reused by `/onboard:update` and `/onboard:evolve` — not an external API.

## Phased Architecture

```
/onboard:start
     │
     ▼
Phase 0: Empty-Repo Guard ──→ SRC_COUNT == 0?
     │                            ├── yes → 3-option menu (abort / placeholder / canonical stub)
     │                            │          └── stub path follows skills/start/references/empty-repo-stub-procedure.md
     │                            └── no  → fall through to Phase 1
     ▼
Phase 1: Recon ──→ codebase-analyzer agent (read-only, script-free)
     │              └── native Glob/Grep/Read + git one-liners → emits reconHints
     ▼
Phase 2: Research
     │   ├── Step: profile-select ──→ Minimal / Standard / Comprehensive (sets research depth + gen scope)
     │   └── Step: deep-research ──→ Skill(onboard:research)
     │                                └── dossier + 4 artifacts:
     │                                    research-dossier, architecture, risk-register, glossary
     ▼
Phase 3: Grounded Wizard ──→ confirm/override from research.wizardInferences
     │                        └── autonomyLevel always cold (never inferred)
     ▼
Phase 4: Plugin Detection & Context
     │   ├── Step: plugin-detection ──→ deep probe (siblings + marketplace cache)
     │   ├── Step: probe-plugin-surfaces ──→ + plugin-surface-probe (closes G.3)
     │   └── Step: build-v3-context ──→ skills/start/references/onboard-context-builder.md
     │                                   └── version: 3 + research block
     ▼
Phase 5: Plan → Preview → HARD GATE ──→ Skill(onboard:generate {mode:plan})
     │   ├── Step: plan ──→ generationManifest (nothing written)
     │   ├── Step: preview ──→ previewModel (research + blueprint) → walkthrough:render
     │   └── Step: gate ──→ Approve → write │ Adjust → re-plan │ Cancel → nothing
     ▼
Phase 6: Generation (post-gate) ──→ Skill(onboard:generate {mode:"write"})
     │                   └── config-generator agent (write)
     │                       ├── Core: CLAUDE.md, rules, skills, agents, hooks
     │                       ├── v3: consumes research → sharpens artifacts + seeds docs/feature-list.json
     │                       ├── Enriched: CI/CD, harness, evolution, teams (if enabled)
     │                       └── Pre-exit self-audit on the 7 generation-phase telemetry keys
     ▼
Phase 7: Handoff ──→ explains generated artifacts, suggests next steps
```

## Agent Handoff Pattern

- `codebase-analyzer` runs first (read-only) — produces structured analysis report
- Report stays in conversation context — NOT written to a file
- `config-generator` runs second (write) — receives analysis + wizard answers via prompt
- `feature-evaluator` is available for independent feature testing (spawned by `/onboard:verify`)

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

### Enriched (when enabled via wizard)
- CI/CD pipelines (GitHub Actions: ci, tooling-audit, pr-review)
- Harness artifacts (docs/progress.md, docs/HARNESS-GUIDE.md)
- Auto-evolution hooks (FileChanged + SessionStart) + drift detection scripts
- Sprint contracts (docs/sprint-contracts/)
- Agent team support (quality hooks, env var)

## Skill Hierarchy

User-facing skills (show in `/onboard:` autocomplete):

- `skills/start/SKILL.md` — full interactive wizard + generation (`disable-model-invocation: true`)
- `skills/update/SKILL.md` — align with latest best practices (`disable-model-invocation: true`)
- `skills/adopt/SKILL.md` — retrofit foreign hand-crafted tooling into an onboard baseline; writes meta + snapshots only, never modifies a hand-crafted file (`disable-model-invocation: true`)
- `skills/check/SKILL.md` — tooling health check (auto-invocable)
- `skills/verify/SKILL.md` — independent feature verification via feature-evaluator agent (auto-invocable)
- `skills/evolve/SKILL.md` — apply pending tooling drift updates (auto-invocable)

Internal building blocks (`user-invocable: false` — hidden from menu):

- `skills/generate/SKILL.md` — internal generation step, invoked via Skill tool
- `skills/wizard/SKILL.md` — drives the grounded confirm/override surface (research-seeded)
- `skills/research/SKILL.md` — the v3 research engine (fan-out specialists → verify → synthesize dossier)
- `skills/analysis/SKILL.md` — tech stack pattern matching, model recommendations
- `skills/generation/SKILL.md` — artifact generation logic, core + enriched modes

## Script Conventions

- Scripts are supplementary — if a detection / evolution / audit script fails, the flow degrades gracefully (logs and continues)
- POSIX-compatible: must work on macOS (BSD) and Linux (GNU)
- Recon is **script-free** (native Glob/Grep/Read + git one-liners) as of v3.
- Evolution scripts: `detect-dep-changes.sh`, `detect-config-changes.sh`, `detect-structure-changes.sh`
- CI audit script: `audit-tooling.sh`

## Reference Organization

`generation/references/` is the single source of truth:

**Core guides**: claude-md-guide, rules-guide, hooks-guide, skills-guide, agents-guide, collaboration-guide
**Catalog guides**: mcp-guide, output-styles-guide, output-styles-catalog, lsp-plugin-catalog, built-in-skills-catalog
**Extended guides**: harness-design, ci-cd-templates, evolution-hooks-guide, sprint-contracts, agent-teams-guide, worktree-workflow

## Key Patterns

- Maintenance headers on all generated artifacts (version + date)
- Grounded wizard: confirm/override surface seeded by research.wizardInferences; autonomyLevel always cold; three profiles (Minimal/Standard/Comprehensive) set research depth + gen scope (no Custom).
- Plugin-aware agent generation: check coveredCapabilities before generating agents
- Merge-aware hooks: always read settings.json first, never overwrite
- v3 research consumption: when a `research` dossier is present, generation sharpens CLAUDE.md/rules/skills/agents/subdir from verified claims and seeds the verify backlog (`docs/feature-list.json`, seed-if-absent). Absent research → byte-identical to the non-research path.
- v3 re-research (update/evolve): on a staleness signal, `update`/`evolve` re-run `onboard:research` scoped (auto-escalating to full), merge it into the prior dossier, and regenerate merge-aware (customization floor + marker surgery + progress-preserving backlog merge). `evolve` runs the scoped path silently and defers full-escalation to `update`; `check` detects + recommends (read-only). Absent a staleness signal → byte-identical to the snapshot-replay path.
- Provenance + retrofit: `/onboard:adopt` synthesizes a `mode:"retrofit"` baseline from pre-existing tooling, tracking each artifact `origin:"adopted"` in `onboard-meta.json.artifactProvenance`; `update` treats adopted artifacts as diffable-with-caution and defers all modernization (e.g. adding maintenance headers) to per-item approval. An absent `artifactProvenance` map means all-generated (backward-compatible).
