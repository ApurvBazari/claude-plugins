# Finder registry — the 3 tiers

The engine's ANALYZE stage draws findings from a **3-tier registry**. Every tier emits the **same
`review-findings` contract**, every tier's output is adversarially verified by the `verifier` in the
VERIFY stage, and **read-only is ENFORCED at the dispatch boundary** for all tiers. The tiers differ only
in where the finder comes from and how read-only is guaranteed.

## Tier 1 — Built-in

Lens's own 5 finder agents (`lens/agents/`). Always on; findings-only by construction (each is authored
with read-only tools and emits findings, never edits).

| Finder | Dimension |
|---|---|
| `spec-adherence` | `requirements` |
| `plan-adherence` | `requirements` |
| `correctness` | `correctness` |
| `risk-classify` | `risk` |
| `test-gaps` | `test` |

`spec-adherence` / `plan-adherence` are the **wedge** (did this build what was asked + follow the plan?)
and both tag `requirements`; their category lives in `label` (`spec-gap`, `scope-creep`, `plan-deviation`,
…). `test-gaps` owns the **missing-test** half of the `test` dimension.

## Tier 2 — Adapter

Five **read-only external adapters**, auto-detected at runtime and **skipped SILENTLY when the source
plugin is absent** — the degrade-if-absent pattern from `.claude/rules/plugin-structure.md` §
Self-Contained Plugins (check for the provider at runtime; skip if missing, never error). Each maps a
foreign producer onto one closed `dimension`, with scoping:

| Adapter (producer) | Dimension | Scoping |
|---|---|---|
| `silent-failure-hunter` | `silent-failure` | full |
| `type-design-analyzer` | `types` | full |
| `comment-analyzer` | `comment` | full |
| `pr-test-analyzer` | `test` | **brittle/overfit + behavioral-delta ONLY** — lens's built-in `test-gaps` owns "missing test" |
| `feature-dev:code-reviewer` | `correctness` | a capability-locked read-only **2nd opinion** |

**Read-only enforcement (per adapter).** Only two adapters are inherently locked:

- `feature-dev:code-reviewer` — locked by its **tool allowlist** (no write tools).
- `comment-analyzer` — locked by **instruction** (findings-only by design).

The other three (`silent-failure-hunter`, `type-design-analyzer`, `pr-test-analyzer`) **inherit write
tools** from their source plugin and therefore **MUST be constrained to findings-only at the dispatch
boundary** — the dispatch wrapper instructs them to produce findings only: no edits, no commits, no
staging. There is no write path through any adapter.

## Tier 3 — Project

Per-project custom finders, registered in `.claude/lens/settings.md` as YAML entries:

```yaml
finders:
  - agent: my-custom-finder      # an agent under .claude/agents/
    dimension: security          # one of the closed enum
    label: injection-audit       # free-form sub-category
    readonly: true               # must be true; enforced at dispatch
```

The engine reads this registry and dispatches the named `.claude/agents/` finders, **read-only-enforced at
the dispatch boundary** like the adapter tier. (Authoring contract: see `finder-contract.md`.)

## Normalization (all tiers)

Every tier's raw output is normalized into the `review-findings` shape before dedup/verify:

- `dimension` stays the **closed 9-value enum** (`requirements`, `correctness`, `security`, `types`,
  `silent-failure`, `simplify`, `test`, `risk`, `comment`). Never invent a dimension. Note: `security` and
  `simplify` are **contract-only dimensions** in v1 — no built-in finder or adapter emits them (`simplify`
  is vicario-inherited; `security` can be produced by a `correctness` finder or a project-tier finder).
- **Finer categories go in `label`** (a single free-form string) and/or `tags[]` (a free-form list) —
  e.g. an adapter's native category like `brittle-test` becomes `label:"brittle-test"`, `dimension:"test"`.
- `verified` is normalized to `false` on intake (the VERIFY stage owns the flip); `source` records the
  producing finder/adapter for provenance and dedup merging.
