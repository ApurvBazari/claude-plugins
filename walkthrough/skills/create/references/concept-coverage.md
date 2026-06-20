# Concept Coverage Map — what the walkthrough can explain

The single source of truth for **which kinds of concept the walkthrough can render**. `components/index.md`
is the *component* catalog; this is the *concept* catalog that routes to it. Synthesis classifies each
concept it wants to convey into a `type` here, records it in the session model's `concepts[]` ledger
(`session-model.md`), and the **concept-fidelity gate** (`authoring-guide.md` § 1) routes it to the
registered renderer — or, for an uncovered type, to a logged bespoke (`authoring-guide.md` § 4). The gate
**never** force-fits a concept into a component not registered for its type.

After the 1.2.0 renderer work there are **zero ❌ rows**. A future concept-type with no faithful renderer
gets a new ⚠️/❌ row pointing at a bespoke recipe — so the "what to add next" backlog stays visible.

## The map

| Family | Concept-type | Trigger (how synthesis recognizes it) | Status | Renderer (component key) |
|---|---|---|---|---|
| Structure | `linear-process` | staged pipeline, straight chain, no branches | ✅ | flow |
| | `nonlinear-system` | services/layers connected free-form | ✅ | architecture map |
| | `module-dependency` | import/uses edges, shared leaves (a DAG) | ✅ | dependency graph |
| | `branching-logic` | labeled yes/no/condition edges, a tree, no cycles | ✅ | decision-tree |
| | `data-model` | entities with field lists, edges carry cardinality (1:N, N:M) | ✅ | erd |
| | `hierarchy` | strict one-parent containment, n levels | ✅ | htree |
| | `layering` | ordered vertical bands, each touches only neighbors | ✅ | lstack |
| Behavior | `state-machine` | states with cyclic / back-edge / self-loop / guarded transitions | ✅ | state diagram |
| | `message-exchange` | timed messages between 2+ actors over time | ✅ | sequence diagram |
| | `execution-phases` | phases of parallel/sequential steps with sources | ✅ | data-driven step timeline |
| | `causal-chain` | symptom → causes ruled in/out by evidence → root cause | ✅ | ladder |
| Time | `chronology` | a dated/ordered story to read top-to-bottom | ✅ | timeline |
| | `replayable-sequence` | an ordered sequence to step through | ✅ | stepper |
| Ideation | `concept-branching` | a central idea branching into sub-concepts | ✅ | mind map |
| | `mode-variation` | one structure shown in multiple modes/views | ✅ | morphing-mode / interactive explorer |
| Evaluation | `scored-decision` | options weighed on scored axes | ✅ | tabs + tradeoff bars |
| | `unscored-decision` | decisions without scored axes | ✅ | accordion checklist |
| | `option-comparison` | options compared across criteria | ✅ | comparison table |
| | `before-after` | a before/after pair | ✅ | diff panes |
| Quantity | `magnitudes` | many comparable magnitudes | ✅ | animated bar chart |
| | `headline-numbers` | a few headline numbers | ✅ | stat / metric cards |
| Artifacts | `file-set` | changed files | ✅ | file tree / filterable cards |
| | `code-snippet` | a verbatim code block with a filename | ✅ | annotated code block |
| Emphasis | `emphasis-point` | a single caveat/insight/constraint | ✅ | callout |
| | `label-value` | label→value pairs / edge cases / open questions | ✅ | key–value metadata grid |
| | `symbol-key` | a key explaining diagram symbols | ✅ | legend |
| Review (lens) | `reviewed-change` | a reviewed diff with inline finding pins | ✅ | annotated diff |
| | `finding-set` | severity-ranked review findings | ✅ | findings list |
| | `requirement-adherence` | spec items / plan steps met/partial/missing | ✅ | adherence panel |

## Disambiguation — telling close neighbors apart

The gate leans on these rules; the most specific matching rule wins (e.g. cycles → `state-machine`
beats tree → `branching-logic`):

- **`branching-logic` vs `state-machine` vs `linear-process`** — labeled yes/no/condition edges over a
  **tree with no cycles** → `branching-logic` (decision-tree). Any **cycle / back-edge / self-loop** →
  `state-machine`. A **straight chain with no branches** → `linear-process` (flow).
- **`hierarchy` vs `module-dependency`** — **strict one-parent containment** over n levels → `hierarchy`
  (htree). **import/uses edges with shared leaves** (a node has >1 parent) → `module-dependency` (dep graph).
- **`data-model` vs `nonlinear-system`** — nodes are **entities with field lists** and edges carry
  **cardinality** → `data-model` (erd). Otherwise → `nonlinear-system` (architecture map).
- **`layering` vs `nonlinear-system`** — **ordered vertical bands**, each layer touches only its
  neighbors → `layering` (lstack). **Free-form** connections → `nonlinear-system`.
- **`causal-chain` vs `linear-process`** — nodes carry **ruled-in/ruled-out evidence** semantics →
  `causal-chain` (ladder). **Neutral processing stages** → `linear-process` (flow).

## Uncovered concept → bespoke

If a concept matches no row, the gate routes it to a **bespoke** component (`authoring-guide.md` § 4),
records it in `concepts[]` with `bespoke: true` + a `bespokeReason`, and a new ⚠️/❌ row SHOULD be added
here naming the bespoke recipe — so the hole is visible and never silently force-fit.
