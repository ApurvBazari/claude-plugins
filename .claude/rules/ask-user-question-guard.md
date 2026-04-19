---
paths:
  - "onboard/**"
  - "forge/**"
  - "notify/**"
---

# AskUserQuestion Single-Option Guard

When a `multiSelect: true` call to `AskUserQuestion` has only **one** candidate in its `options` list, the tool call fails with `Invalid tool parameters` — the schema requires `options.minItems: 2`. Wizards that build option lists dynamically (from detection scripts, wizard state, or caller extras) MUST guard against this case before invoking the tool.

## Root cause

Verified across 4 release-gate reproductions (2026-04-17 findings B3, B9, F1 in init ×3 and update ×1): any multiSelect where the candidate list collapses to a single entry hits the schema violation on first try. Callers then fall back to sequential single-select calls — content preserved but the batched-approval contract (M2 sweep) is broken.

## Decision tree

```
options = build_dynamic_options(...)

if len(options) == 0:
  ┗ SKIP the question entirely — nothing to ask.

elif len(options) == 1:
  ├─ standalone question (wizard Phase 5.5 / 5.6 / 5.7 etc.)
  │    → convert to single-select yes/no:
  │       AskUserQuestion({
  │         question: "Configure <the-only-candidate>?",
  │         multiSelect: false,
  │         options: [
  │           { label: "Yes (Recommended)", description: "<signal>" },
  │           { label: "No",                 description: "Skip this" }
  │         ]
  │       })
  │
  └─ batched multi-group approval (e.g., /onboard:update Phase 4b)
       → pad that group with an explicit None option:
          options = [
            { label: <the-only-candidate>, description: "..." },
            { label: "None / Skip",
              description: "Do not include anything from this group" }
          ]
          keep multiSelect: true; keep the single-call envelope

elif len(options) >= 2:
  ┗ pass through — no guard needed.
```

## When to use which branch

| Caller shape | Shape today | After guard |
|---|---|---|
| Standalone single-step question | multiSelect with dynamic list | single-select yes/no |
| Batched multi-group approval (update skill Phase 4b) | single AskUserQuestion with per-group multi-selects | same envelope; affected group padded |

The **padded-None** branch preserves the single-call contract that the update skill depends on (one AskUserQuestion, one user interaction, multiple approvals). The **yes/no** branch is a better UX for one-off questions because "pick 1 of 1" is an awkward phrasing.

## Downstream semantics — `None / Skip` selection

When the user selects `None / Skip` in a padded group, callers MUST treat the selection as **empty-array-equivalent** for that group:
- Telemetry: record `status: "declined"` with `reason: "user-skipped-padded-group"`.
- Generated artifacts: do not reference the dropped candidate in CLAUDE.md / snapshots / meta.
- If the user selects both the real candidate AND `None / Skip` (allowed by the multiSelect form), treat as user error → prefer the real candidate (drop None) and surface a gentle note in the generation log.

## Anti-patterns

❌ **Blindly invoking AskUserQuestion without a length check:**

```
options = detect_lsp_signals()  # returns 1 candidate
AskUserQuestion(options: options, multiSelect: true)  # fails
```

❌ **Silent fallback to sequential single-selects** (breaks M2 batched-approval contract):

```
if len(options) == 1:
  # degrade to 3 separate AskUserQuestion calls — don't do this
```

❌ **Hardcoding extra "None" option always** (adds UX noise when len ≥ 2):

```
options = candidates + [{label: "None / Skip"}]  # append unconditionally
```

Only append `None / Skip` when `len(candidates) == 1` AND the caller is a batched approval.

## Canonical callers (must consult this rule)

- `onboard/skills/wizard/SKILL.md` — Phase 5.5 ecosystem plugins, Phase 5.6 LSP, Phase 5.7 built-in skills.
- `onboard/skills/update/SKILL.md` — Phase 4b batched approval (padded-None branch).
- `forge/skills/context-gathering/SKILL.md` — any dynamically-sized option list (audit on first use).
- `notify/skills/*` — any wizard-like step (audit on first use).

When adding a new skill that uses `AskUserQuestion` with dynamic options, reference this rule in a brief § Guard Usage note alongside the call.
