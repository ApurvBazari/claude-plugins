# Render Adapter — Research Dossier → Walkthrough `session-model` (v3)

Maps the synthesized `research` dossier — and the shared `previewModel` (see § previewModel) — to a `walkthrough` **`session-model`** (schema: `walkthrough/skills/create/references/session-model.md`; render contract: `walkthrough/skills/render/references/render-contract.md`) so `walkthrough:render` can emit one self-contained interactive HTML. The HTML render now happens at the onboard **pre-implementation gate** (`start` Step 2.9 / `update` Step 5.5 / `adopt` A5), which loads this adapter; research itself no longer renders standalone HTML (folded into the gate — see `../SKILL.md` Step 7.5). Mirrors the proven `lens → review-model-assembly.md → walkthrough:render` handoff.

## When this runs
At the pre-implementation gate (`start` Step 2.9 / `update` Step 5.5 / `adopt` A5), when `walkthrough` is installed and the render succeeds. If `walkthrough` is absent or the render fails, the gate degrades to an inline markdown gate (the gate itself is never skipped). onboard never writes the HTML itself; `walkthrough:render` owns it.

## Mapping

| `session-model` field | Source in the research dossier |
|---|---|
| `title` | `"<repo-name> — research-grounded onboarding"` |
| `summary` | One paragraph: depth, dimensions assessed, headline risks. |
| `typeTags` | `["onboarding", "research", "<depth>"]` |
| `sections[]` | One section per **assessed** dimension (`findings{}` keys): the dimension narrative + its claims as `components[]`. `architecture` leads. |
| `nodes[]` / `edges[]` | The architecture/data-flow diagram from the `architecture` dimension's component/boundary findings (component→component edges). Omit if `architecture` not assessed. |
| `findings[]` | The risk & test-gap register — one card per `security`/`risk`/`test-gap` claim: `{ title: statement, severity: priority→{1:high,2:medium,3:low}, category, file: firstEvidencePath }`. Filterable. |
| `files[]` (+ `risk`) | Distinct evidence files; `risk` set on files carrying a security/risk claim. |
| `details{}` | One detail surface per claim id: `{ kicker: dimension, heading: statement, summary: implication, where: evidence[], points: [confidence, verification status] }` — clickable `file:line` evidence. |
| `decisions[]` | Verifier transparency: `verifiedClaims` vs `droppedClaims` as a decision/accordion surface. |
| `openQuestions[]` | The seed ADRs (`status: proposed`) — decisions the team must ratify. |

## Assembly rules
- **Only assessed dimensions appear** — a not-assessed dimension has no `findings{}` key; skip it, never fabricate.
- Evidence `file:line` strings map to `details[].where[]` verbatim (clickable).
- Zero risk/test-gap/security claims → `findings[]` is empty (the cards section renders empty, not an error).
- The model is assembled in context and handed to `walkthrough:render`; no HTML is written by onboard.

## previewModel (the shared pre-implementation render input)

`previewModel` is the unified input rendered at the pre-implementation gate (start Step 2.9; update; adopt). Shape:

```jsonc
{
  "flow": "start" | "update" | "adopt",
  "research": { "architecture": ..., "risks": [...], "glossary": [...] } | null,
  "changes": [ /* generationManifest changes[] entries */ ],
  "decisions": { /* generationManifest decisions */ },
  "warnings": [ ... ]
}
```

Map it to a walkthrough `session-model` with these sections, in order:
1. **Overview** — one paragraph: flow + profile + what the gate is asking.
2. **What I learned** (only when `research` ≠ null) — architecture map, top risks, glossary highlights.
3. **What I'll build** — `changes[]` grouped by `tier`, each artifact a node titled by `path` with its `purpose` + `outline` + an `action`/`origin` badge.
4. **Key decisions** — `decisions` as a labelled list (model, autonomy, profile, hooks, MCP, LSP, plugin integration).
5. **Risks / warnings** — `warnings[]` plus research risks.

Populators: **start** fills `changes`/`decisions` from `generate(plan)`; **update** from its offer-set + re-research delta; **adopt** from its record-set. One adapter, three populators.
