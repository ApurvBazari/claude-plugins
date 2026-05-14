# Greenfield 3.0 Round 3 — Implementation Plan

This is a navigational pointer. The canonical implementation plan lives at:

`docs/superpowers/plans/2026-05-14-greenfield-3.0-round3-implementation.md`

## Quick reference

- **Phase A** — Schema (T1–T5): 4 new phase blocks in `context-shape-v2.json` (auth, privacy, security, runtimeOperations) + top-level description.
- **Phase B** — Synthesis templates (T6–T10): HTML + MD + dependencies.json.example trio per phase, plus section-prompts.md extensions.
- **Phase C** — Question bank (T11–T16): 50 new Qs across Auth/Privacy/Security/Runtime Ops; migrate Q3.3/Q3.6/Q3.9/Q4.5; reduce P4.Q7; consolidate default-derivation catalog.
- **Phase D** — Orchestrator wiring (T17–T23): insert Steps 5–8 in context-gathering/SKILL.md; renumber existing Steps 5–11 → 9–15; extend state-transitions tables; wire synthesis-review.
- **Phase E** — Cross-phase + grill-spec + pickup (T24–T26): 4 new CHECK-R3-* invariants; skip-cascade reversal; CLAUDE.md + start/check updates.
- **Phase F** — Docs (T27–T28): ROUND 3 LOCKED entry in `docs/greenfield-overview.html`; this pointer doc.
- **Phase G** — Release (T29–T31): version bumps to alpha.4; marketplace.json + CHANGELOG sync; `/validate` + final smoke test.

## Companion docs

- **Design spec:** `docs/superpowers/specs/2026-05-14-greenfield-3.0-round3-design.md` — design rationale + 5 locked decisions + edge cases.
- **Derivation rules catalog:** `docs/greenfield-3.0-round3/phase-q-derivation-rules.md` — single-source catalog of all 50 stack-derived default rules.

## Branch + versioning

All Round 3 commits land on `feat/greenfield-1.2`. Versions on completion: `greenfield@3.0.0-alpha.4` + `onboard@2.0.0-alpha.4`. Hard cutover from alpha.3 per Round 2.5 Decision 8.
