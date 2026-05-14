# Greenfield 3.0 Round 4 — Overview

> **Round status:** Implementation in progress (started 2026-05-14). All 28 tasks T6–T28 landed; T29–T31 (integration smoke + final pass) pending.
> **Spec:** `docs/superpowers/specs/2026-05-14-greenfield-3.0-round4-design.md`
> **Plan:** `docs/superpowers/plans/2026-05-14-greenfield-3.0-round4-implementation.md`
> **Target versions:** `greenfield@3.0.0-alpha.5`, `onboard@2.0.0-alpha.5`
> **Branch:** `feat/greenfield-1.3` (will merge into `develop` via PR after T31 integration smoke).

## What Round 4 adds

- **2 new wizard phases** — Personas (Step 2.2, 16 Qs heavy / 4 light), Domain Modeling (Step 2.7, 11 Qs Full DDD / ~8 DDD-lite / ~6 Light).
- **Distributed risk capture** — 10 inline `Q_RISK` entries (8 architectural phases + 2 discovery phases). Each phase's final Q collects to a shared top-level `risks[]` array.
- **Risk Reconciliation section** — new front section in `architectural-validation.html` (Step 15). Buckets risks by reconciliation status (mitigated / partial / accepted-explicit / open-followup / out-of-scope / user-declared-none) and surfaces top follow-ups as `feature-list.json` risk-followup cards.
- **3 wizard-level mode toggles** — `mode.depth` (heavy/light), `mode.coupling` (auto-loop/hybrid), `mode.domainFormat` (full-ddd/ddd-lite). All set at Step 1.1 with comprehensive-by-default Recommended defaults.
- **Auto-loop mechanic** — downstream architectural phases (auth, privacy, data, api, security, runtimeOps) iterate per persona or per entity when `mode.coupling == "auto-loop"`. Hybrid mode collapses `loopMode: hybrid-only` Qs to single static prompts.
- **Schema additions** — additive, non-hard-cutover bump. Auto-migrating from alpha.4 via the `/greenfield:pickup` migration shim.

## Round 4 commit log

(Populated from `git log feat/greenfield-1.3 ^develop --oneline` as of 2026-05-14, 29 commits total:)

```
255217b docs(greenfield + onboard): CLAUDE.md R4 — Steps 2.2/2.7, mode toggles, Q-bank flags
bc073cf feat(onboard): generation SKILL R4 — handle personas, domainModel, risks, mode (optional/backward-compat)
5132418 refactor(greenfield): demote Q1.2 users-Q to pointer; preserve as vision.users[] legacy (R4 T24)
86f6f87 feat(greenfield): CHECK-R4-1..8 cross-phase invariants + grill-spec wiring + Q-bank flag docs
ecc7be5 feat(greenfield): check + tooling-generation R4 + back-fill script stub
d6f46ab feat(greenfield): pickup R4 — mid-wizard Adjust mode, drift detection, alpha.4→alpha.5 migration shim
daba25d feat(greenfield): start R4 — Step 1.1 mode-toggle invocation block
e3220de feat(greenfield): synthesis-review R4 — personas + domain templates, sourceRef rendering, back-fill
0f48f03 refactor(greenfield): renumber wizard progress indicators 15 → 17 (R4 cross-file pass)
772c017 feat(greenfield): context-gathering R4 — mode toggles, Step 2.2/2.7, auto-loop state machine
25abbb0 fix(greenfield): domain-model synthesis templates — align field names to Q-bank
615ce07 feat(greenfield): inline-risk Q-bank doc + section-prompts for personas + domainModel
3116c45 feat(greenfield): risk reconciliation section template + shared risks deps example
5523685 feat(greenfield): domain-model synthesis templates — HTML + MD + dependencies example
6615de2 feat(greenfield): personas synthesis templates — HTML + MD + dependencies example
bce70f4 feat(greenfield): cicd Q-bank — migrate R3 (Q5.1–Q5.17 → CICD.Q1–Q17) + add showInLight/Q_RISK
a7aa1a9 feat(greenfield): runtime-operations Q-bank — migrate R3 (Ops.Q1–Q14) + add showInLight/Q_RISK/hybrid-only persona loops
523fea9 feat(greenfield): security Q-bank — migrate R3 (Sec.Q1–Q13) + add showInLight/Q_RISK/hybrid-only loops
f02a3e7 feat(greenfield): privacy Q-bank — migrate R3 (Gate + Q1–Q11) + add showInLight/Q_RISK/persona auto-loop
6d6ea9e feat(greenfield): auth Q-bank — migrate R3 (Auth.Q1–Q12) + add showInLight/Q_RISK/persona auto-loop
3acc646 feat(greenfield): api-integration Q-bank — migrate R3 (P4.Q1–Q10) + add showInLight/Q_RISK/auto-loop tags
653deda feat(greenfield): data-architecture Q-bank — migrate R3 (P3.Q1–Q12) + add showInLight/Q_RISK/auto-loop tags
127e608 feat(greenfield): architectural-framing Q-bank — migrate R3 + add showInLight/Q_RISK
8a9afdb feat(greenfield): domain-model Q-bank (11 Qs / Full DDD + DDD-lite + Light) — Step 2.7
639d507 fix(greenfield): personas Q-bank — convention cleanup (isRiskCapture on all Qs, type canonicalization, Q1/Q6/Q9/Q10/Q11 polish)
c92ad95 feat(greenfield): personas Q-bank (12 Qs heavy / 4 light) — Step 2.2
a7d3ef7 feat(greenfield): dependencies-schema R4 — extend phase + path pattern, add sourceRef
433477f fix(onboard): update context-shape-v2 dependencies pattern — domain→domainModel, risk→risks
a1de704 feat(onboard): context-shape-v2 R4 — mode block, personas, domainModel, riskReconciliation, risks[]
```

## Smoke tests

Round 4 ships with two manual smoke-test artifacts under `tests/round-4/`:

- **`auto-loop-fixture.json`** — mock alpha.5 state with `mode.coupling = "auto-loop"`, 2 primary personas (Sara, Carl), 2 entities (Audit aggregate-root + Finding owned). Used to verify auto-loop fires per persona/entity in downstream phases.
- **`auto-loop-smoke.sh`** — manual test driver. Validates fixture structure (8 automated checks: JSON-parse, schemaVersion, mode, persona count, entity count, aggregate-root flag, upstream phase status, downstream phase status) and documents the manual verification steps the operator runs in a real Claude Code session.
- **`migration-alpha4-fixture.json`** + **`migration-test.sh`** (T30) — mock alpha.4 state for verifying the `/greenfield:pickup` migration shim deterministically lifts to alpha.5 with safe defaults.

Run the automated portion:

```bash
bash tests/round-4/auto-loop-smoke.sh
bash tests/round-4/migration-test.sh
```

Manual verification steps follow the `[MANUAL VERIFICATION STEPS]` section in each script's output.

## Files added / modified

**New (greenfield):**
- `greenfield/skills/context-gathering/references/personas.q-bank.md`
- `greenfield/skills/context-gathering/references/domain-model.q-bank.md`
- `greenfield/skills/context-gathering/references/architectural-framing.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/data-architecture.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/api-integration.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/auth.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/privacy.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/security.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/runtime-operations.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/cicd.q-bank.md` (migrated)
- `greenfield/skills/context-gathering/references/inline-risk.q-bank.md` (cross-cutting)
- `greenfield/skills/synthesis-review/references/templates/personas.html`, `personas.md`, `personas-dependencies.json.example`
- `greenfield/skills/synthesis-review/references/templates/domain-model.html`, `domain-model.md`, `domain-model-dependencies.json.example`
- `greenfield/skills/synthesis-review/references/templates/arch-val-risk-reconciliation-section.html`, `risks-dependencies.json.example`
- `greenfield/skills/grill-spec/references/check-r4-invariants.md`
- `greenfield/scripts/back-fill-downstream-section.sh`

**Modified (greenfield):**
- `greenfield/CLAUDE.md` — architecture diagram, Skill Hierarchy, Key Patterns
- `greenfield/skills/start/SKILL.md` — Step 1.1 mode-toggle invocation
- `greenfield/skills/context-gathering/SKILL.md` — Step 1 backward-compat note, Step 1.1 mode toggles, Step 2.2 + Step 2.7 state-machine rows, Auto-loop mechanic + Render hooks sections, Q1.2 demotion note
- `greenfield/skills/synthesis-review/SKILL.md` — per-phase template index table, sourceRef rendering, Back-fill mechanic
- `greenfield/skills/pickup/SKILL.md` — Adjust mode, persona/entity drift detection, alpha.4 → alpha.5 state migration shim
- `greenfield/skills/check/SKILL.md` — Round 4 health-check assertions
- `greenfield/skills/tooling-generation/SKILL.md` — Round 4 onboard pass-through
- `greenfield/skills/grill-spec/SKILL.md` — CHECK-R4-* wiring
- `greenfield/skills/context-gathering/references/question-bank.md` — Q1.2 demotion, Round 4 Q-bank flag reference appendix

**Modified (onboard):**
- `onboard/skills/generate/references/context-shape-v2.json` — mode block, personas, domainModel, riskReconciliation, risks[]
- `onboard/skills/generate/references/dependencies-schema.json` — phase enum extended, path pattern extended, sourceRef added
- `onboard/skills/generation/SKILL.md` — Round 4 phase handling
- `onboard/CLAUDE.md` — Round 4 phase additions

## Lessons + adjustments

(Populated post-execution — particularly mid-execution drift items.)

### Template-lock checkpoint findings (post-Phase D)

1. **Domain-model template field renames** (committed in `25abbb0`): `events` → `domainEvents`, `antiCorruptionLayers` → `antiCorruption` to match Q-bank `Stores to:` paths.
2. **personas.primary[].context.device[] is an array** but template renders as scalar — state machine (T17 § Render hooks) pre-joins to `deviceLabel` scalar.
3. **personas.antiPersona per-persona vs personas.antiPersonas top-level** — state machine aggregates per-persona into top-level (T17 § Render hooks).
4. **domain entity.ownedBy + entity.description** referenced by template but not captured by Q-bank — Mustache renders empty (acceptable degrade); deferred to a future Q-bank extension.

### Q1.2 demotion (T24)

The legacy users-Q in Step 1 (Q1.2 "Who is this for?") was demoted to a pointer; alpha.4 sessions with `vision.users[]` populated get a conversion prompt at Step 2.2 entry.

### `hybrid-only` naming surprise (documented in question-bank.md § Round 4 Q-bank flag reference)

`loopMode: "hybrid-only"` semantically means "skip the loop in hybrid mode" — a clearer name would have been `hybrid-skip`. Spec is locked; documented in CLAUDE.md and Q-bank flag reference.
