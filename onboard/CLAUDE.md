# onboard — Internal Conventions

Interactive wizard that analyzes codebases and generates complete Claude tooling infrastructure. Supports both standalone use (`/onboard:start`) and headless mode for programmatic consumers like Greenfield.

## Phased Architecture

```
/onboard:start
     │
     ▼
Phase 0: Empty-Repo Guard ──→ SRC_COUNT == 0?
     │                            ├── yes → 3-option menu (abort / placeholder / canonical stub)
     │                            │          └── stub path follows init/references/empty-repo-stub-procedure.md
     │                            └── no  → fall through to Phase 1
     ▼
Phase 1: Analysis ──→ codebase-analyzer agent (read-only)
     │                   ├── analyze-structure.sh
     │                   ├── detect-stack.sh
     │                   └── measure-complexity.sh
     ▼
Phase 2: Wizard ──→ wizard skill (adaptive Q&A, presets)
     │
     ▼
Phase 2.5: Plugin Detection ──→ deep probe (siblings + marketplace cache)
     │                          + plugin-surface-probe (closes G.3)
     ▼
Phase 2.6: Build Onboard Context ──→ init/references/onboard-context-builder.md
     │                                (same greenfield-shaped callerExtras greenfield emits)
     ▼
Phase 3: Generation ──→ Skill(onboard:generate)  [same contract as greenfield]
     │                   └── config-generator agent (write)
     │                       ├── Core: CLAUDE.md, rules, skills, agents, hooks
     │                       ├── Enriched: CI/CD, harness, evolution, teams (if enabled)
     │                       └── Pre-exit self-audit on 7 Phase 7 telemetry keys
     ▼
Phase 4: Handoff ──→ explains generated artifacts, suggests next steps
```

## Agent Handoff Pattern

- `codebase-analyzer` runs first (read-only) — produces structured analysis report
- Report stays in conversation context — NOT written to a file
- `config-generator` runs second (write) — receives analysis + wizard answers via prompt
- `feature-evaluator` is available for independent feature testing (spawned by `/onboard:verify`)


## Headless Mode (`onboard:generate`) — v2-only as of 2.0.0-alpha.1

External plugins (e.g., Greenfield 3.0+) invoke the `generate` skill via the Skill tool, skipping the wizard and analysis. The skill is `user-invocable: false` so it doesn't clutter the user's slash menu.

```
generate skill (v2-only, headless)
     │
     ├── Step 0: version detection — REJECTS v1 input outright
     │       (v1 callers must pin to onboard 1.10.0; no migration helper ships)
     │
     ▼
v2 context JSON ──→ Step 1.5 maps v2 → internal format
     │              + renders GHA workflow templates from phases.P8.cicd
     │              + renders sprint-contracts from phases.P8.cicd.envLadder
     │              + composes evolution-wiring qualityGates entries
     │              + injects all rendered artifacts into agent prompt
     │
     ▼
config-generator agent ──→ writes the rendered artifacts + standard generation
     │                       ├── Core artifacts (always)
     │                       └── Enriched artifacts (based on internal enriched flags)
     ▼
Results report ──→ lists generated artifacts + telemetry
```

### v2 context shape

The canonical schema lives at `skills/generate/references/context-shape-v2.json` (draft-07 JSON Schema). Top-level structure:

```jsonc
{
  "version": 2,
  "source": "greenfield",
  "projectPath": "/abs/path/to/project",
  "callerExtras": { "installedPlugins": [], "coveredCapabilities": [] },
  "phases": {
    "P2": { "stack": { ... } },
    "P8": {                              // ★ fully specified in Round 1
      "cicd": { "provider", "triggers", "requiredPreMergeChecks", "coverage",
                 "envLadder", "autoDeploy", "deployCadence", "rollback",
                 "secrets", "notifications", "buildMatrix", "caching",
                 "timeBudget", "releasePipeline" },
      "_v1_carryover": { "ciAuditAction", "autoEvolutionMode", "prReviewTrigger" }
    },
    // P0, P0.5, P1, P3, P4, P5, P6, P7, P8.5, P9, P10, P10.5
    // each carry { "_status": "deferred-to-round-N" } in Round 1 alpha
  },
  "syntheses": {
    // Round 1 live: "P8" (cicdAndDelivery)
    // Round 2 live: "P2.5" (architecturalFraming), "P3" (dataArchitecture), "P4" (apiIntegration)
    // Round 2.5 live: above + "P11" (architecturalValidation)
    // Round 3 live: above + "P5" (auth), "P6" (privacy), "P7" (security), "P8b" (runtimeOperations)
    //   cicdAndDelivery renumbered to Step 11; architecturalValidation renumbered to Step 15
    "P8": { "approvedAt", "adjustments[]" }
  },
  "dependencies": { "P8": ["P0.willDeploy", "P0.teamSize", ...] }
}
```

### Hard cutover policy

Onboard 2.x rejects v1 input outright. There is no migration helper. v1 callers (greenfield 2.x, any direct callers built before greenfield 3.0) must stay on onboard 1.10.0 for the lifetime of their session. Documented at length in `CHANGELOG-2.0.md`.

The rejection contract is enforced at the top of `skills/generate/SKILL.md § Step 0` — never silent, never partial. The error message is parseable by callers for routing.

### v2-specific templates (Round 1 — Round 3 complete)

Rounds 1–3 are complete. Round 1 wired CI/CD (P8). Rounds 2 / 2.5 wired architectural synthesis phases (architecturalFraming, dataArchitecture, apiIntegration, architecturalValidation). Round 3 adds auth, privacy, security, runtimeOperations synthesis phases (Steps 5–8 in the greenfield wizard; cicdAndDelivery renumbered to Step 11; architecturalValidation renumbered to Step 15).

- `skills/generate/references/cicd-templates/github-actions/*.yml.tmpl` — 4 GHA workflow templates rendered from P8 fields. Round 1 ships GHA only; non-GHA providers in Round 6.
- `skills/generate/references/sprint-contracts-template.json` — sprint contract structure consuming `phases.P8.cicd.envLadder` for `deploymentTargets`.
- `skills/generate/references/evolution-wiring.md` — mapping rules from `phases.P8.cicd.notifications` to project-side `.claude/hooks/notify-on-*.sh` scripts.

### Plugin-aware generation

- `callerExtras.coveredCapabilities` prevents agent shadowing (unchanged from v1)
- The config-generator agent is unmodified by Round 1 — the existing v1-shaped agent prompt is preserved as the internal contract; only the OUTSIDE (caller-facing schema) is new

### Future onboard 2.x changes

The v2 root shape (with deferred phase stubs) is stable. Future minor versions (2.1, 2.2, ...) fill in deferred phases as greenfield Rounds 2-6 land, without breaking the root schema. See `CHANGELOG-2.0.md § Future onboard 2.x changes` for the non-binding roadmap.

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

- `start/SKILL.md` — full interactive wizard + generation (`disable-model-invocation: true`)
- `update/SKILL.md` — align with latest best practices (`disable-model-invocation: true`)
- `check/SKILL.md` — tooling health check (auto-invocable)
- `verify/SKILL.md` — independent feature verification via feature-evaluator agent (auto-invocable)
- `evolve/SKILL.md` — apply pending tooling drift updates (auto-invocable)

Internal building blocks (`user-invocable: false` — hidden from menu):

- `generate/SKILL.md` — headless generation API, invoked by greenfield via Skill tool
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
