# Render Adapter — Research Dossier → Walkthrough `session-model` (v3)

Loaded by `../SKILL.md` **only when the optional HTML render runs** — the `walkthrough` plugin is present at synthesis time AND `artifacts.location ∈ {committed, local}`. Maps the synthesized `research` dossier to a `walkthrough` **`session-model`** (schema: `walkthrough/skills/create/references/session-model.md`; render contract: `walkthrough/skills/render/references/render-contract.md`) so `walkthrough:render` can emit one self-contained interactive HTML. Mirrors the proven `lens → review-model-assembly.md → walkthrough:render` handoff.

## When this runs
First-onboard or re-research synthesis, walkthrough installed, `location ∈ {committed, local}`. On `location:"none"` or walkthrough absent, the render is skipped (markdown stays canonical) — see `../SKILL.md` Step 7. onboard never writes the HTML itself; `walkthrough:render` owns it.

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
