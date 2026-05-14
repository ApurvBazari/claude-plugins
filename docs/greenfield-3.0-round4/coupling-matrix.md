# Round 4 — Coupling Matrix

This document is the authoritative reference for which Q-bank Qs auto-loop, what they loop over, and what loopMode they use. The matrix below is reproduced from the per-phase Q-bank `> **Coupling:**` header lines (T6–T12).

## Matrix

| Phase | Q ID (per-phase) | loopOver | loopMode | Auto-loop fires? | Hybrid fires? |
|---|---|---|---|---|---|
| personas | (no auto-loop; structure-loops over Q1 count) | — | — | — | — |
| domainModel | (no auto-loop; structure-loops over Q1 BCs) | — | — | — | — |
| architecturalFraming | (no auto-loop) | — | — | — | — |
| dataArchitecture | Data.Q5 (migrations tool/mode) | `domainModel.entities` | `always` | yes | yes |
| dataArchitecture | Data.Q8 (caching) | `domainModel.entities` | `always` | yes | yes |
| apiIntegration | Api.Q2 (API style — CRUD surface) | `domainModel.entities` | `always` | yes | yes |
| apiIntegration | Api.Q7 (async pattern) | `domainModel.entities` | `hybrid-only` | yes | no (static once) |
| auth | Auth.Q5 (authorization model — role/permission) | `personas.primary` | `always` | yes | yes |
| privacy | Privacy.Q11 (data-access scope) | `personas.primary` | `always` | yes | yes |
| security | Sec.Q4 (threat model) | `personas.primary` | `hybrid-only` | yes | no |
| security | Sec.Q3 (attack surface / scanning) | `domainModel.entities` | `hybrid-only` | yes | no |
| runtimeOperations | Ops.Q7 (alert routing) | `personas.primary` | `hybrid-only` | yes | no |
| runtimeOperations | Ops.Q8 (SLO targets) | `personas.primary` | `hybrid-only` | yes | no |
| cicdAndDelivery | (no auto-loop — pipeline-level) | — | — | — | — |

## Semantics

- **`loopMode: always`** — the Q loops in BOTH `mode.coupling == "auto-loop"` AND `mode.coupling == "hybrid"`. Used for foundational per-iteration decisions where static answers don't make sense (e.g., per-persona authorization roles, per-entity migration files).
- **`loopMode: hybrid-only`** — the Q loops ONLY when `mode.coupling == "auto-loop"`. Under `mode.coupling == "hybrid"`, the Q fires ONCE as a static prompt with a hybrid-fallback prompt template. Used for valuable-but-optional per-iteration decisions (e.g., per-persona threat model, per-persona SLO targets).
- **Misnomer warning:** the name `hybrid-only` reads ambiguously — it actually means "skip the loop in hybrid mode." A clearer name in retrospect would be `hybrid-skip`. The spec is locked at `hybrid-only`. Documented in `context-gathering/references/question-bank.md § Round 4 Q-bank flag reference`.

## Why these specific Qs were tagged

The coupling decisions reflect domain-modeling intuition:

- **Per-entity decisions** (always): migrations (Data.Q5), caching (Data.Q8), CRUD surface (Api.Q2) — each entity needs its own decision at the data + API layer.
- **Per-entity decisions** (hybrid-only): async pattern (Api.Q7), attack surface (Sec.Q3) — valuable per-entity but a single project-wide default usually suffices in hybrid mode.
- **Per-persona decisions** (always): authorization roles (Auth.Q5), data-access scope (Privacy.Q11) — every persona's permissions and data access are typically distinct.
- **Per-persona decisions** (hybrid-only): threat model (Sec.Q4), alert routing (Ops.Q7), SLO targets (Ops.Q8) — per-persona modeling is rigorous but a project-wide answer is acceptable in hybrid.

## Cross-references

- `greenfield/skills/context-gathering/references/question-bank.md § Round 4 Q-bank flag reference` — flag semantics.
- `greenfield/skills/context-gathering/SKILL.md § Auto-loop mechanic` — runtime behavior of the loop dispatch.
- `greenfield/skills/synthesis-review/SKILL.md § sourceRef rendering` — how looped answers carry provenance to synthesis HTML.
- Each per-phase Q-bank's `> **Coupling:**` header line — the authoritative tag source.
