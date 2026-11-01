# AskUserQuestion Single-Option Guard

Shipped with onboard so every skill can follow it at runtime.

When a `multiSelect: true` call to `AskUserQuestion` has only **one** candidate in its `options` list, the tool call fails with `Invalid tool parameters` — the schema requires `options.minItems: 2`. Wizards that build option lists dynamically (from detection scripts, wizard state, or caller extras) MUST guard against this case before invoking the tool.

## Decision tree

```
options = build_dynamic_options(...)

if len(options) == 0:
  ┗ SKIP the question entirely — nothing to ask.

elif len(options) == 1:
  ├─ standalone question (e.g. one wizard detection group asked on its own)
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
  └─ batched multi-group approval (e.g. `/onboard:update`'s batched approval)
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
| Batched multi-group approval (`/onboard:update`'s batched approval) | single AskUserQuestion with per-group multi-selects | same envelope; affected group padded |

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

## Where onboard applies it

Every onboard `AskUserQuestion` call that builds its options from detection results, wizard state or a
caller's list: the wizard's LSP, built-in-skill and MCP-plugin groups, `update`'s batched approval,
`evolve`'s offers, and the install offer in `plugin-install-consent.md`. A call whose options are a
fixed list of two or more needs no guard; say so in a short **Guard Usage** note beside the call.
