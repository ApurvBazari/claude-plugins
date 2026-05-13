# Greenfield 3.0 Round 2.5 — Foundation Pass Design

- **Branch:** `feat/greenfield-1.2`
- **Date:** 2026-05-13
- **Inherits from:** Rounds 1+2 (shipped at `greenfield@3.0.0-alpha.2` / `onboard@2.0.0-alpha.2`); `project_greenfield_3_0_design.md` memory entry; ROUND 2.5 LOCKED Discussion Log entry
- **Estimated files touched:** ~55-65 unique files across `greenfield/`, `onboard/`, root marketplace, and root CLAUDE.md
- **Target versions on completion:** `greenfield@3.0.0-alpha.3`, `onboard@2.0.0-alpha.3`

## Summary

Round 2.5 is a foundation pass that retrofits Rounds 1+2 with 8 cross-cutting structural decisions before Round 3 begins P6 Auth/Security + P7 Workflow expansion. It is intentionally not a "phase round" — there is no new phase being designed here. The goal is to eliminate the cost of carrying the wrong defaults, names, formats, dependency-tracking semantics, and Adjust-dialog dependency through four more rounds of work.

The 8 decisions came out of an honest-assessment session that asked "is this plugin going to be useful — and what's structurally broken?" Each decision changes every round's deliverables; locking them now is cheaper than relitigating mid-Round-4.

## Scope

**In scope (Round 2.5 deliverables):**

1. Rename all P-code identifiers to topic names in schema, code, filenames, dependency refs (PRE-1)
2. Insert new Step 2.5 (Architectural Framing) + rename Step 10 → Step 11 (Architectural Validation); wizard count 10 → 11 (PRE-2)
3. Remove `mattpocock-skills` plugin from the marketplace; clean up greenfield catalog and grill-spec references (PRE-3)
4. Build greenfield-owned `adjust-dialog` skill (5-category adversarial walk); replace mattpocock-skills:grill-me usage in synthesis-review (PRE-4)
5. Implement stale-flag mechanism: state JSON phaseStatus map, dependency-graph traversal, phase entry-guard, field-level diff capture in Adjust (PRE-5)
6. Add `default:` derivation rules to every Q in question-bank.md; defaults are stack-derived with greenfield-opinionated fallback (PRE-6)
7. Move scaffolded-project synthesis output directory from `docs/architecture/` → `docs/adr/` (PRE-7)
8. Document state JSON migration policy (hard cutover during alpha; migrations from stable) (PRE-8)
9. Author markdown companion templates for every existing HTML synthesis template (Round 1+2 retrofit) (PRE-9)

**Out of scope (do NOT relitigate — locked Round 1, 2, or 2.5 decisions):**

- 15-phase wizard structure
- Phase 1.8 synthesis-review pattern
- Plugin lifecycle (P7.5 picks, P10 installs)
- Adaptive skipping mechanism
- Hard cutover migration policy (no v1→v2 helpers, no greenfield 2.x maintenance branch)
- Pre-commit freshness hook pattern (path target changes per PRE-7; logic unchanged)
- onboard:generate v1 rejection contract
- Round 3-6 phase designs (P6, P7, P0, P0.5, P1, P5, P8.5, P9, P10.5)
- Non-GHA CI provider templates (Round 6)
- Replacement for the dropped 7 non-grill-me mattpocock-skills skills (triage, prototype, zoom-out, grill-with-docs, improve-codebase-architecture, handoff, setup) — users wanting those install upstream directly
- State JSON migration framework implementation (Decision 8 stubs it; full migrations land post-GA)

## Locked design decisions

These 8 decisions are referenced throughout the PRE-task sections.

| # | Item | Decision |
|---|---|---|
| 1 | Lite mode / on-ramp | Defaults-driven skip. Every Q has a smart default; Enter accepts, type to override. Synthesis HTMLs still produced. Adjust loop still offered. |
| 2 | Defaults source | Stack-derived from earlier answers; greenfield-opinionated fallback when no stack signal. |
| 3 | Synthesis format | Hybrid — independently authored markdown details + HTML executive summary per phase. Drift-check hook between the two. |
| 4 | Approval semantics (late Adjust) | Stale-flag with explicit re-walk choice. Downstream phases marked stale on dependency-field changes. |
| 5 | Naming consistency | Topic names everywhere in schema/code/filenames/dependency refs. User-facing prompts retain "Step N: Topic Name" form. |
| 6 | Architectural Research positioning | Split: early Architectural Framing (Step 2.5) + late Architectural Validation (renamed Step 11). Wizard count 10 → 11. |
| 7 | Adjust dialog | Greenfield-owned `adjust-dialog` skill (5-category adversarial). Remove `mattpocock-skills` from marketplace. |
| 8 | Synthesis directory | `docs/adr/` in scaffolded projects (was `docs/architecture/`). |

Plus state-JSON evolution policy: hard cutover during alpha; migrations from 3.0.0 stable onward.

## Architecture & data flow (post-Round-2.5)

```
/greenfield:start
     │
     ▼
Phase 1: Context Gathering
     │
     ├── Step 1 of 11: Vision (P0)
     ├── Step 2 of 11: Stack (P2)
     │
     ├── Step 2.5 of 11: Architectural Framing            ─── ★ NEW (PRE-2)
     │       ├── Q (monolith/microservices/modular)
     │       ├── Q (deployment topology)
     │       ├── Q (scale target)
     │       └── synthesis-review(phaseId: "architecturalFraming")
     │              └── outputs:
     │                    docs/adr/architectural-framing.md    ← PRE-7
     │                    docs/adr/architectural-framing.html  ← PRE-7
     │
     ├── Step 3 of 11: Data Architecture                   ─── renamed (PRE-1)
     │       └── synthesis-review(phaseId: "dataArchitecture")
     │              └── outputs: data-architecture.{md,html}
     │
     ├── Step 4 of 11: API & Integration                   ─── renamed (PRE-1)
     │       └── synthesis-review(phaseId: "apiIntegration")
     │              └── outputs: api-integration.{md,html}
     │
     ├── Step 5 of 11: Remaining Project Details          (residual, Round 3-6 territory)
     ├── Step 6 of 11: Workflow                           (Round 3)
     ├── Step 7 of 11: CI/CD & Delivery                   ─── renamed (PRE-1)
     │       └── synthesis-review(phaseId: "cicdAndDelivery")
     │              └── outputs: cicd-and-delivery.{md,html}
     │
     ├── Step 8 of 11: Plugin Discovery
     ├── Step 9 of 11: Confirmation
     ├── Step 10 of 11: Plugin Install
     └── Step 11 of 11: Architectural Validation          ─── renamed (PRE-2)
             └── synthesis-review(phaseId: "architecturalValidation")
                    └── reads: ALL prior phase syntheses
                    └── outputs: architectural-validation.{md,html}
     │
     ▼
Phase 1.7: grill-spec ─── cross-checks ALL syntheses with topic names
     ▼
Phase 1.8: synthesis-review                ─── enhanced with:
     ├── Stale-flag check on entry (PRE-5)
     ├── Default-display per Q (PRE-6)
     ├── Adjust → greenfield/skills/adjust-dialog (PRE-4)
     ├── Adjust captures field-diff (PRE-5)
     └── Approval propagates stale-flags to dependents (PRE-5)
     ▼
Phase 2: Scaffold
     ▼
Phase 3: onboard:generate                  ─── consumes topic-name schema
```

## PRE-1 — Rename pass (Decision 5)

**Goal:** Drop P-codes from every internal identifier. User-facing prompts keep "Step N: Topic Name" form.

**Rename mapping:**

| Before (P-code) | After (topic name) |
|---|---|
| `p3Data` (schema key) | `dataArchitecture` |
| `p4Api` (schema key) | `apiIntegration` |
| `p8Cicd` (schema key) | `cicdAndDelivery` |
| `P3` (phase ID, dependency ref) | `dataArchitecture` |
| `P4` (phase ID, dependency ref) | `apiIntegration` |
| `P8` (phase ID, dependency ref) | `cicdAndDelivery` |
| `phase-3-data` (state-transition value) | `data-architecture` |
| `phase-4-api` | `api-integration` |
| `phase-8-cicd` | `cicd-and-delivery` |
| `p3-data.html` (filename) | `data-architecture.html` |
| `p4-api.html` | `api-integration.html` |
| `p8-cicd.html` | `cicd-and-delivery.html` |
| `p3-data-dependencies.json.example` | `data-architecture-dependencies.json.example` |
| `p4-api-dependencies.json.example` | `api-integration-dependencies.json.example` |
| `p8-cicd-dependencies.json.example` | `cicd-and-delivery-dependencies.json.example` |

Deferred phase status keys (`p0Status`, `p5Status`, `p6Status`, etc.) are renamed by topic where the topic exists; deferred entries without a name yet (e.g. `P0` Vision) become `vision` (topic name from the gap-analysis).

**Files (~18):**

```
onboard/skills/generate/references/context-shape-v2.json    (schema key renames)
onboard/skills/generate/SKILL.md                            (mirror schema renames in inline examples + Step 0/Step 1.5)
greenfield/skills/synthesis-review/SKILL.md                 (phase ID refs in instructions)
greenfield/skills/synthesis-review/references/section-prompts.md
greenfield/skills/synthesis-review/references/dependencies-schema.json
greenfield/skills/synthesis-review/references/templates/p3-data.html
                                                            → data-architecture.html
greenfield/skills/synthesis-review/references/templates/p4-api.html
                                                            → api-integration.html
greenfield/skills/synthesis-review/references/templates/p8-cicd.html
                                                            → cicd-and-delivery.html
greenfield/skills/synthesis-review/references/templates/p3-data-dependencies.json.example
                                                            → data-architecture-dependencies.json.example
greenfield/skills/synthesis-review/references/templates/p4-api-dependencies.json.example
                                                            → api-integration-dependencies.json.example
greenfield/skills/synthesis-review/references/templates/p8-cicd-dependencies.json.example
                                                            → cicd-and-delivery-dependencies.json.example
greenfield/skills/context-gathering/references/question-bank.md   (Q5.4-Q5.17, P3, P4 section P-code refs)
greenfield/skills/context-gathering/SKILL.md                       (state-transition values)
greenfield/skills/init/SKILL.md                                    (state-transitions enum)
greenfield/skills/resume/SKILL.md                                  (state-transitions enum)
greenfield/skills/status/SKILL.md                                  (phase display labels)
greenfield/skills/grill-spec/SKILL.md                              (cross-check phase refs)
greenfield/CLAUDE.md                                                (topology diagram)
docs/greenfield-overview.html                                      (current-state diagram; preserve historical log refs)
```

**Note:** Historical log entries in `docs/greenfield-overview.html` (Round 1 LOCKED, Round 2 LOCKED, etc.) keep their original P-code references — they are historical records. Only the current-state architecture diagrams at the top of the doc update.

## PRE-2 — Architectural Research split (Decision 6)

**Goal:** Insert early Architectural Framing (Step 2.5) and rename existing Step 10 to Architectural Validation (Step 11).

**Step 2.5 question bank (3-5 questions):**

| ID | Topic | Type | Writes to |
|---|---|---|---|
| AF.Q1 | Service topology | choice: monolith / modular-monolith / microservices / serverless | `architecturalFraming.topology` |
| AF.Q2 | Deployment shape | choice: single-region / multi-region / edge-distributed / on-prem | `architecturalFraming.deploymentShape` |
| AF.Q3 | Scale target | choice: hobby / startup / production-scale / enterprise | `architecturalFraming.scaleTarget` |
| AF.Q4 | Boundary expectations | open w/ recommendations | `architecturalFraming.boundaryNotes` (loose) |

**Step 11 (renamed Architectural Validation):** runs after all prior phases. Reads every approved synthesis and produces a final cross-check report. New synthesis sections cover: (1) consistency across phases, (2) framing-vs-final divergence, (3) unresolved contradictions, (4) sign-off summary.

**Files (~16):**

```
greenfield/skills/context-gathering/SKILL.md           (insert Step 2.5 in flow; rename Step 10 → Step 11; "of 10" → "of 11")
greenfield/skills/context-gathering/references/question-bank.md
                                                       (new section "Architectural Framing"; rename old Step 10 section)
greenfield/skills/synthesis-review/references/templates/architectural-framing.html       NEW
greenfield/skills/synthesis-review/references/templates/architectural-framing.md         NEW (PRE-3 hybrid format)
greenfield/skills/synthesis-review/references/templates/architectural-framing-dependencies.json.example  NEW
greenfield/skills/synthesis-review/references/templates/architectural-validation.html    NEW
greenfield/skills/synthesis-review/references/templates/architectural-validation.md      NEW (PRE-3 hybrid format)
greenfield/skills/synthesis-review/references/templates/architectural-validation-dependencies.json.example  NEW
greenfield/skills/synthesis-review/references/section-prompts.md            (add section rules for both new templates)
onboard/skills/generate/references/context-shape-v2.json                    (add architecturalFraming + architecturalValidation phase definitions)
onboard/skills/generate/SKILL.md                                            (handle new phase keys)
greenfield/skills/init/SKILL.md                                              (state-transitions: add framing + validation)
greenfield/skills/resume/SKILL.md                                            (state-transitions update)
greenfield/skills/status/SKILL.md                                            (display new phases)
greenfield/skills/grill-spec/SKILL.md                                        (cross-check syntheses now include framing + validation)
greenfield/CLAUDE.md                                                         (wizard topology now 11 steps)
```

## PRE-3 — Remove mattpocock-skills from marketplace (Decision 7)

**Goal:** Delete the vendored 4th plugin entirely. Marketplace returns to 3 active plugins (or 4 once handoff merges from `feat/handoff-plugin`).

**Files (~7):**

```
DELETE: mattpocock-skills/                              (entire directory)
.claude-plugin/marketplace.json                         (remove entry)
CLAUDE.md (root)                                        (drop mattpocock-skills from architecture diagram + plugin count)
greenfield/skills/grill-spec/SKILL.md                   (remove mattpocock-skills:grill-me as preferred path; reference greenfield/skills/adjust-dialog instead)
greenfield/skills/synthesis-review/references/adjust-dialog-protocol.md
                                                        (rewrite: point to greenfield/skills/adjust-dialog; remove brainstorming → grill-me two-stage)
greenfield/skills/plugin-discovery/* (catalog references)
                                                        (remove mattpocock-skills rows from curated catalog; review forrestchang:andrej-karpathy-skills and grill-with-docs entries too)
greenfield/skills/context-gathering/references/question-bank.md
                                                        (re-evaluate hasDocsDiscipline + wantsValidationGate flags; remove if mattpocock-tied)
```

## PRE-4 — Build greenfield/skills/adjust-dialog/ (Decision 7)

**Goal:** A 5-category adversarial walk owned by greenfield. Replaces the mattpocock-skills:grill-me dependency in synthesis-review's Adjust path.

**5 categories:** Scope, Assumptions, Alternatives, Risks, Dependencies. Each category is a short structured probe (1-3 questions) that the dialog walks the dev through when they pick "Adjust" on a synthesis section. The categories are uniform across all phases — only the inputs (the section content being adjusted) vary.

**Files (~9):**

```
greenfield/skills/adjust-dialog/SKILL.md                          NEW (orchestrator)
greenfield/skills/adjust-dialog/references/scope-questions.md     NEW
greenfield/skills/adjust-dialog/references/assumptions-questions.md   NEW
greenfield/skills/adjust-dialog/references/alternatives-questions.md  NEW
greenfield/skills/adjust-dialog/references/risks-questions.md     NEW
greenfield/skills/adjust-dialog/references/dependencies-questions.md  NEW
greenfield/skills/adjust-dialog/references/dialog-protocol.md     NEW (how to compose the 5 categories + field-diff capture)
greenfield/skills/synthesis-review/SKILL.md                       (replace Adjust path: call adjust-dialog via Skill tool)
greenfield/.claude-plugin/plugin.json                              (no version bump yet; alpha.3 bumps at end of Round 2.5)
```

## PRE-5 — Stale-flag mechanism (Decision 4)

**Goal:** When a phase is Adjusted, downstream phases that read the changed fields are marked stale. On next entry, the wizard prompts "X references Y which changed — re-walk X? Y/n".

**State JSON additions:**

```jsonc
{
  "phaseStatus": {
    "dataArchitecture":  { "status": "approved", "approvedAt": "...", "lastModified": "..." },
    "apiIntegration":    { "status": "stale",    "approvedAt": "...", "staleReason": "dataArchitecture.databaseHost changed", "lastModified": "..." },
    "cicdAndDelivery":   { "status": "approved", "approvedAt": "...", "lastModified": "..." }
  }
}
```

**Stale propagation:** When `dataArchitecture.databaseHost` changes (captured in Adjust's field-level diff), iterate all phases whose `dependencies.json` lists `dataArchitecture.databaseHost` and set their status to `stale`. Phase entry-guards check status on entry and prompt re-walk.

**Files (~10):**

```
greenfield/skills/synthesis-review/SKILL.md                  (add stale-check entry-guard; add field-diff capture in Adjust path; add propagation step on approval)
greenfield/skills/synthesis-review/references/stale-detection.md          NEW (graph traversal logic)
greenfield/skills/synthesis-review/references/dependencies-schema.json    (extend with stale tracking fields)
greenfield/skills/init/SKILL.md                              (state schema: phaseStatus map; emit on first run)
greenfield/skills/resume/SKILL.md                            (read phaseStatus on resume; surface stale phases prominently)
greenfield/skills/status/SKILL.md                            (display phaseStatus, with stale phases highlighted)
greenfield/skills/context-gathering/SKILL.md                 (entry-guard logic when re-entering a phase)
Retrofit Round 1+2 syntheses with stale-check guards:
  greenfield/skills/synthesis-review/references/templates/data-architecture.{md,html}
  greenfield/skills/synthesis-review/references/templates/api-integration.{md,html}
  greenfield/skills/synthesis-review/references/templates/cicd-and-delivery.{md,html}
```

## PRE-6 — Default-value derivation (Decisions 1+2)

**Goal:** Every Q in `question-bank.md` gets a `default:` rule. Stack-derived when possible (reading prior P-code answers); greenfield-opinionated fallback otherwise.

**Pattern per Q:**

```yaml
Q3.4 — ORM / data access layer
  ...
  default:
    derive_from: [P2.stack.language, P2.stack.framework]
    rules:
      - if: P2.stack.language == "typescript" and P2.stack.framework startswith "next"
        value: prisma
      - if: P2.stack.language == "typescript"
        value: drizzle
      - if: P2.stack.language == "python" and P2.stack.framework == "django"
        value: active-record
      - if: P2.stack.language == "python"
        value: sqlalchemy
      - if: P2.stack.language == "go"
        value: gorm
    fallback: raw-sql
```

**Files (~5):**

```
greenfield/skills/context-gathering/references/question-bank.md
                                                        (every Q gets a default: block — large file rewrite)
greenfield/skills/context-gathering/SKILL.md             (default-display logic: show "[default: X]" prompt; Enter accepts)
greenfield/skills/context-gathering/references/defaults-derivation.md   NEW (derivation rules format; fallback policy)
greenfield/skills/synthesis-review/SKILL.md              (note when a default was accepted vs explicitly chosen)
docs/greenfield-overview.html                            (note defaults-driven skip in architecture diagram)
```

## PRE-7 — Move synthesis dir docs/architecture/ → docs/adr/ (Decision 8)

**Goal:** Scaffolded projects emit synthesis outputs to `docs/adr/`, not `docs/architecture/`. Matches industry ADR convention.

**Files (~5):**

```
greenfield/skills/synthesis-review/SKILL.md              (output path: docs/adr/)
greenfield/skills/synthesis-review/references/pre-commit-freshness-hook.sh.tmpl
                                                          (watch docs/adr/ instead)
greenfield/skills/synthesis-review/references/section-prompts.md   (any inline path refs)
greenfield/CLAUDE.md                                      (scaffolded output path)
onboard/skills/generate/SKILL.md                          (if it emits any reference to docs/architecture)
```

**Important:** Greenfield's own *plugin-repo* documentation stays at `docs/` (not `docs/adr/`). This change only affects what scaffolded projects emit.

## PRE-8 — State JSON migration policy doc

**Goal:** Document the alpha-vs-stable policy and stub the migration framework for post-GA.

**Policy:**

- During `3.0.0-alpha.X` releases: schema changes are allowed without migration. CHANGELOG must call out breaking changes. In-flight greenfield sessions die and must restart. Users are informed via the bump-warning that they may need to restart.
- From `3.0.0` stable onward: every schema change ships a migration function. Old state JSON is auto-upgraded on resume.

**Files (~3):**

```
greenfield/skills/init/references/state-schema-evolution.md    NEW
greenfield/CHANGELOG-3.0.md                                    NEW or extend
greenfield/skills/resume/SKILL.md                              (note: alpha state JSONs may be incompatible across versions; resume must check version field)
```

## PRE-9 — Synthesis MD companion templates (Decision 3)

**Goal:** For every existing HTML synthesis template, author a markdown companion. Both files are committed; both must be updated on Adjust. Drift-check hook flags when only one was edited.

**Files (~5):**

```
greenfield/skills/synthesis-review/references/templates/cicd-and-delivery.md   NEW
greenfield/skills/synthesis-review/references/templates/data-architecture.md   NEW
greenfield/skills/synthesis-review/references/templates/api-integration.md     NEW
greenfield/skills/synthesis-review/references/md-html-drift-check.sh.tmpl      NEW (pre-commit hook fragment for scaffolded projects)
greenfield/skills/synthesis-review/SKILL.md                                    (Adjust path: instruct to update both files; output path emits both)
```

**Note:** PRE-2's new `architectural-framing` and `architectural-validation` templates ship with both formats from the start. PRE-9 only retrofits Round 1+2 templates.

## Ordering & dependencies between PRE-tasks

```
                          ┌──────────────────────────────┐
                          │ PRE-3 (remove mattpocock)    │
                          │ PRE-8 (state evolution doc)  │
                          └──────┬───────────────────────┘
                                 │
                                 ▼
                          ┌──────────────────────────────┐
                          │ PRE-1 (rename pass)          │
                          └──────┬───────────────────────┘
                                 │
                ┌────────────────┼────────────────┐
                ▼                ▼                ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │ PRE-2        │ │ PRE-7        │ │ PRE-4        │
        │ (arch split) │ │ (docs/adr)   │ │ (adjust-dlg) │
        └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
               │                │                │
               └────────────────┼────────────────┘
                                ▼
                          ┌──────────────────────────────┐
                          │ PRE-5 (stale-flag)           │
                          │ PRE-9 (MD companions)        │
                          └──────┬───────────────────────┘
                                 │
                                 ▼
                          ┌──────────────────────────────┐
                          │ PRE-6 (defaults)             │
                          └──────────────────────────────┘
```

**Rationale:**

- PRE-3 first because removing mattpocock-skills clears the slate; later PRE-tasks don't need to reason about the dependency.
- PRE-8 is independent and can land anywhere — sequenced early because it's small and unblocks no others.
- PRE-1 next because every subsequent PRE-task uses topic-name identifiers.
- PRE-2, PRE-7, PRE-4 can run in parallel — each depends on PRE-1's renaming.
- PRE-5 depends on PRE-4 (Adjust dialog captures field-level diff) and PRE-1 (schema uses topic names for dependency refs).
- PRE-9 depends on PRE-1 (file naming) and PRE-7 (docs/adr destination).
- PRE-6 last because Q template format finalizes after PRE-1 (Q identifier scheme) and PRE-5 (stale-tracking changes the Q model slightly).

## File inventory (consolidated, with overlap noted)

Approximate **unique file count: ~55-65**. The following files are touched by multiple PRE-tasks:

| File | Touched by |
|---|---|
| `greenfield/skills/synthesis-review/SKILL.md` | PRE-1, PRE-4, PRE-5, PRE-6, PRE-7, PRE-9 |
| `greenfield/skills/context-gathering/SKILL.md` | PRE-1, PRE-2, PRE-5, PRE-6 |
| `greenfield/skills/context-gathering/references/question-bank.md` | PRE-1, PRE-2, PRE-3, PRE-6 |
| `greenfield/skills/init/SKILL.md` | PRE-1, PRE-2, PRE-5 |
| `greenfield/skills/resume/SKILL.md` | PRE-1, PRE-2, PRE-5, PRE-8 |
| `greenfield/skills/status/SKILL.md` | PRE-1, PRE-2, PRE-5 |
| `greenfield/skills/grill-spec/SKILL.md` | PRE-1, PRE-2, PRE-3 |
| `greenfield/skills/synthesis-review/references/section-prompts.md` | PRE-1, PRE-2, PRE-7 |
| `greenfield/CLAUDE.md` | PRE-1, PRE-2, PRE-6, PRE-7 |
| `onboard/skills/generate/references/context-shape-v2.json` | PRE-1, PRE-2 |
| `onboard/skills/generate/SKILL.md` | PRE-1, PRE-2, PRE-7 |

These files will see multiple commits across Round 2.5 — that's fine; each PRE-task lands as its own commit.

## Commit plan

```
Round 2.5 commits (suggested ordering, ~12 commits):

  refactor(mattpocock-skills)!: remove vendored plugin from marketplace [PRE-3]
  docs(greenfield-3.0): state JSON schema evolution policy [PRE-8]
  refactor(greenfield)!: rename P3/P4/P8 to topic names everywhere [PRE-1, part 1: schema + templates]
  refactor(greenfield)!: rename P-codes in user-facing skills + state transitions [PRE-1, part 2: skills + flow]
  feat(greenfield): add Architectural Framing (Step 2.5) [PRE-2, part 1]
  feat(greenfield): rename Step 10 → Architectural Validation (Step 11) [PRE-2, part 2]
  feat(greenfield): move scaffolded synthesis output to docs/adr/ [PRE-7]
  feat(greenfield): add greenfield-owned adjust-dialog skill [PRE-4]
  feat(greenfield): wire stale-flag mechanism with field-level diff [PRE-5]
  feat(greenfield): add markdown companion templates for synthesis [PRE-9]
  feat(greenfield): add stack-derived defaults to every Q [PRE-6]
  chore: bump greenfield to 3.0.0-alpha.3 and onboard to 2.0.0-alpha.3
```

## Verification approach

**Per-PRE-task verification:**

- PRE-1: `grep -r "P3\|P4\|P8\|p3Data\|p4Api\|p8Cicd\|phase-3-data\|phase-4-api\|phase-8-cicd" greenfield/ onboard/` returns only historical log references (in `docs/greenfield-overview.html`).
- PRE-2: `/greenfield:start` drives the new Step 2.5 + Step 11; both synthesis pairs render; dependency graph includes architectural-framing as a parent of dataArchitecture etc.
- PRE-3: `claude plugin list --json` no longer shows mattpocock-skills; root CLAUDE.md says "Three plugins" (or "Four" if handoff merged); validate hook passes.
- PRE-4: Manual Adjust drive-through on a Round 2 synthesis (data-architecture); adjust-dialog skill runs all 5 categories; field-level diff is captured into state JSON.
- PRE-5: Adjust `dataArchitecture.databaseHost` after `cicdAndDelivery` is approved → state JSON shows `cicdAndDelivery.status: "stale"`; re-entering wizard prompts re-walk; declining re-walk preserves stale-flag for next session.
- PRE-6: Drive-through with all defaults accepted (no typed answers) completes the wizard in <5 min; produces a working scaffold; synthesis HTMLs still rendered.
- PRE-7: Scaffolded project has `docs/adr/` directory, not `docs/architecture/`; freshness pre-commit hook watches the new path.
- PRE-8: CHANGELOG-3.0.md explicitly notes hard-cutover policy; resume skill checks state version field and fails clearly on incompatible versions.
- PRE-9: Round 1+2 templates have both `.md` and `.html` versions; drift-check hook fires when only one is edited.

**End-to-end verification:**

After all 9 PRE-tasks land, run `/greenfield:start` and complete a wizard session for a hypothetical Next.js + Postgres + Prisma SaaS:

1. Accept all defaults (Enter-through) → completes in <5 min, produces synthesis pairs in `docs/adr/`.
2. Re-run wizard, override 2-3 answers, drive through with Adjust on one section → adjust-dialog runs, field-diff captured, stale-flag propagation works.
3. `onboard:generate` accepts the new topic-name schema; emits CI/CD templates correctly.
4. `/greenfield:check` reports all phases approved; topology shows 11 steps.

## Edge cases

1. **Resume from alpha.2 state JSON after alpha.3 ships:** State will be incompatible (rename pass + phaseStatus addition). PRE-8 documents this; resume fails with a clear migration-not-available error pointing user to restart.
2. **Adjust on a phase that has no downstream dependencies:** Stale-flag propagation iterates over an empty set; no other phases marked stale. Verified manually.
3. **Defaults derivation falls back when prior P-code answers don't exist (e.g. dev jumped to P3 before P2):** Greenfield-opinionated fallback fires; no error.
4. **mattpocock-skills uninstall fails on a user's machine:** `claude plugin uninstall` is user-side; PRE-3 only removes from marketplace. Users with the plugin installed keep it; CLAUDE.md update is informational.
5. **Drift between MD and HTML synthesis files:** PRE-9's drift-check hook fires on commit; warns but does not block (matches freshness hook pattern).
6. **Architectural Framing answer contradicts a later phase's answer:** Stale-flag mechanism catches this via dependency graph (PRE-5). Validation pass at Step 11 catches what stale-flagging missed.

## Rollback path

If Round 2.5 needs reverting mid-flight, each PRE-task is its own commit; `git revert <commit>` rolls back that PRE-task only. The dependency graph in §"Ordering" determines which subsequent PREs must also revert.

Worst case: full Round 2.5 rollback returns the branch to alpha.2 state. PR #50 already covers Rounds 1+2 — reverting Round 2.5 just removes commits from PR #50 without affecting the inherited Round 1+2 work.

## Risks

1. **PRE-1 rename pass introduces a regression in onboard's v2 schema consumption.** Mitigation: PRE-1 part 1 (schema + templates) lands separately from part 2 (skills + flow); each part is independently verified before the next.
2. **PRE-4 adjust-dialog skill is less rigorous than mattpocock-skills:grill-me.** Mitigation: build the 5-category protocol with explicit question banks per category; treat it as a first-class skill, not a fallback. Verify by running it on a hand-picked Round 2 synthesis that we already adjusted with grill-me, and compare depth.
3. **PRE-5 stale-flag propagation logic has a bug that flags everything.** Mitigation: write dependency graph traversal as a pure function; test it on the Round 1+2 dependencies.json examples before wiring to synthesis-review.
4. **PRE-6 defaults are wrong for some stack combinations.** Mitigation: defaults are advisory (Enter to accept, type to override). Bad defaults cost the dev one keystroke per Q, not a wrong scaffold.
5. **PRE-3 mattpocock-skills removal breaks something we don't realize.** Mitigation: grep for all `mattpocock-skills` references before deletion; verify none remain except in historical doc entries.

## Out of scope — explicit deferrals

- Mattpocock-skills replacement plugin (the 7 non-grill-me skills are upstream-only post-removal).
- Migration framework implementation (Decision 8 stubs the docs; full migration code lands post-GA).
- Round 3 P6/P7 design work (starts immediately after Round 2.5 lands).
- UX polish on the defaults-driven skip (per-phase "accept all remaining" shortcut, etc.) — Round 2.5 ships per-Q Enter-to-accept; bulk shortcuts are a Round 4+ enhancement if needed.
- Plugin discovery catalog re-curation beyond removing mattpocock rows.
- Visual styling pass on the new HTML executive summary templates beyond what's needed for parity with Round 1+2 templates.
- Non-GHA CI provider templates (Round 6).
- Telemetry / instrumentation (no Round in scope yet; flagged in honest-assessment as a gap).
