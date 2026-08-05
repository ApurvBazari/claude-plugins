# lens — Internal Conventions

Intent-grounded review companion. lens reviews the current session's diff **against its own spec and plan**, adversarially verifies the findings, and renders an interactive review document. It runs inside the live session that produced the code — the wedge a diff-only reviewer can't reach: *did this build what was actually asked, and follow the plan?*

Closest existing plugin in shape is `walkthrough/` (skill-driven, heavy lifting in `references/`, an internal `user-invocable:false` building block, in-repo settings file, no compiled code). lens is the **brain**; `walkthrough` is the **eyes**.

## Locked design dimensions

| Dimension | Choice | Reason |
|---|---|---|
| **Name / slash** | `lens` → `/lens:review [target]` | One verb; the optional arg overrides the diff scope |
| **What it judges** | Diff **against intent** (spec + plan), in-session | The failure diff-only review can't catch: a clean build of the wrong spec |
| **Engine/render split** | data-only engine → review-findings JSON → renderer | Vicario-ready: the engine is a reusable judgment core with no I/O of its own |
| **Brain / eyes** | lens judges; `walkthrough:render` renders | Separation of concerns; lens degrades to markdown if walkthrough is absent |
| **Read-only contract** | Never commits, edits, stages, or blocks | The human decides; lens only reads + emits an artifact |
| **Storage** | `.claude/lens/`, in-repo, gitignore prompt on first run | Mirrors walkthrough/handoff's in-repo + gitignore-by-default privacy model |

## Engine / render split (vicario-ready)

lens is split into a **data-only engine** and a **renderer**, so the judgment core can be reused (e.g. by vicario) independent of how the result is displayed.

```
┌──────────────────────────────┐     review-findings JSON      ┌──────────────────────────────┐
│  lens-engine  (skills/engine)│ ───────────────────────────→  │  lens-render (in skills/review)│
│  user-invocable:false        │   (the contract; writes none) │  build review-model → render   │
│  scope→intent→analyze→verify │                               │  via walkthrough:render        │
│  →dedup→rank → RETURN JSON    │                               │  (markdown fallback if absent) │
│  writes nothing, never prompts│                               │  ONLY writes: artifact + state │
└──────────────────────────────┘                               └──────────────────────────────┘
```

- **`lens-engine`** (`skills/engine`, internal, `user-invocable: false`, data-only): runs scope → intent → analyze → verify → dedup → rank and **returns** a `review-findings` JSON object. It writes nothing and never prompts the user. This is the reusable judgment core.
- **`lens-render`** (inside `skills/review`): consumes that JSON, builds a review-model (narrative + adherence + findings + risk + annotated hunks + overall verdict), and invokes `walkthrough:render` to produce the artifact — with a markdown fallback when walkthrough is absent.

The full input/return contract for both halves is declared once, in `skills/engine/references/engine-api.md`.

## The pipeline (`/lens:review [target]`, 4 engine stages + 3 review stages, all in-session)

```
Engine — 4 stages, data-only (writes nothing, returns review-findings JSON):
1 SCOPE  →  2 INTENT  →  3 ANALYZE  →  4 VERIFY
 diff       spec+plan    finder        adversarial refute · dedup · rank ·
 target     → intent      registry      assemble review-findings JSON → RETURN
            record       (parallel)

Review skill — 3 stages (reconcile → render → report):
 build the review-model → walkthrough:render (markdown fallback) → .claude/lens/
```

1. **SCOPE** — resolve the diff target. Default: working tree + this branch's commits vs the merge-base with the default branch; `[target]` overrides. Empty diff or no repo → the engine flags an **empty scope** rather than erroring or prompting, and `review` keys on that flag to report "nothing to review" and exit gracefully after Step 2, marking unreached stages `deleted`. The flag's field name and shape, and the *nothing-to-review vs found-nothing* discriminator rule, are declared in `skills/engine/references/engine-api.md`.
2. **INTENT** — build an **intent record** that may span **multiple specs/plans**, selected **diff-correlated**: explicit args win; else every `docs/superpowers/specs/` + `docs/superpowers/plans/` file Added or Modified in the diff (prefer Added; modified-only → degraded); else the latest-only fallback; else reconstruct from the transcript (degraded).
3. **ANALYZE** — dispatch finder subagents in parallel (see § Finder registry). Built-in finders are spec-adherence + plan-adherence (the wedge → `requirements` dimension; **fanned out one per spec/plan**, each tagging output with `sourceSpec`/`sourcePlan`), correctness, risk-classify, and test-gaps. All emit the same `review-findings` contract; read-only is **enforced at the boundary**.
4. **VERIFY** — adversarial refute pass. Each candidate finding goes to `n` independent skeptic agents prompted to **refute** it against real source, and the engine resolves their votes by the named rule `huginn-quorum-v1` — what a panel of that size does with a refute, and which findings that leaves standing, are declared at `skills/engine/references/pipeline.md` §5 and not restated here. A finding that **errors mid-verify is kept** as `"unverified — flagged"` — never silently dropped. VERIFY then **dedups** across finders, **ranks**, and **assembles** the survivors into the `review-findings` JSON with within-run-stable ids, and **returns** it. The engine writes nothing.

Building the review-model and invoking `walkthrough:render` (or the markdown fallback) to an output path under `.claude/lens/` is the **review skill's render stage** (reconcile → render → report) — **not an engine stage**. (This is why the engine is data-only: it returns the contract; the review half turns it into the artifact.)

## In-session task list

`/lens:review` surfaces its progress as a harness task list (the same mechanism `/onboard:start` uses):
one `TaskCreate` per pipeline stage — `setup`\* · `scope` · `intent` · `analyze` · `verify` · `reconcile` ·
`render` · `report` (`setup` only on the first review in a repo). `review` owns the list and transitions
its own stages; it hands the engine `taskIds = { scope, intent, analyze, verify }` so the engine flips
those four as it runs (handed none, the engine is task-silent — its data-only contract is preserved). The
dispatched finder/verifier subagents are task-blind. It is **in-session visibility only** — no durable
run-progress, no cross-session resume (a review is single-shot). Only the standalone path tracks; a
programmatic orchestrator drives `lens:engine` directly and hands it no `taskIds`, so no list exists. See
`skills/review/references/task-tracking.md`.

## Brain / eyes boundary

lens = the brain (judges); `walkthrough` = the eyes (renders). **Neither imports the other.** Per `.claude/rules/plugin-structure.md` (§ Self-Contained Plugins), lens checks for walkthrough at runtime and skips silently if absent:

- walkthrough present → lens invokes `walkthrough:render` (its internal `user-invocable:false` skill) with the pre-synthesized review-model → interactive HTML review.
- walkthrough absent → lens degrades to the **markdown fallback** (same content, plainer artifact). lens is fully usable without walkthrough installed.

lens does not call walkthrough's `create` / `update` / `document` skills — only `render`, which is the programmatic entrypoint walkthrough exposes for exactly this.

## Read-only contract

lens **reads** the diff + source, **produces** an artifact, and the **human decides**. It never commits, edits, stages, or blocks — there is no write path through any finder, adapter, or verify agent. The **only** writes lens performs are:

1. the rendered review artifact (HTML via walkthrough, or the markdown fallback), and
2. `.claude/lens/review-state.json`.

Read-only is **enforced at the finder boundary**: every finder and adapter emits findings only. Adapters that inherit write tools from their source plugin must be explicitly instructed to operate findings-only (see § Finder registry).

**Untrusted intent content.** The intent doc handed to the adherence agents (injected `content` or a read spec/plan file) is wrapped in `<untrusted-user-input>` fences at dispatch (engine `skills/engine/references/pipeline.md` §3) — data, not instructions. Following onboard's *framing, not filtering* model: `\r` is stripped, but content is **not** length-capped (injectedIntent is verbatim by contract) and **not** content-filtered; the read-only finder toolset (`Read/Grep/Glob`) is the backstop.

## Error posture

lens keeps its 1.4.3 **degrade-by-default** posture for everything it cannot control: partial coverage is
reported through `degraded` + `degradedReasons[]` + `summary`, never through a raised error. 1.5.0 adds one
narrow **pre-flight hard-fail channel**, bounded by two named invariants declared in
`skills/engine/references/engine-api.md` § Errors — **I-1** (an error may be raised only in pre-flight,
before the first finder is dispatched) and **I-2** (errors are raised only on an input introduced in 1.5.0,
so a 1.4.3-shaped call can never receive one). The envelope shape and the closed error-code registry are
not restated here — § Errors is their one declared home.

## The `review-findings` schema (the contract)

The engine emits, and the renderer consumes, a single canonical contract — `lens/schemas/review-findings.schema.json`. It is a versioned **field-additive superset of vicario's `review-findings.schema.json`**: lens's extra *fields* are additive/optional, so vicario's validator ignores them. **The `dimension` enum is the canonical 9-value shared contract** — vicario's six (`requirements|correctness|security|types|silent-failure|simplify`) plus lens's `test`/`risk`/`comment`. The target is a single shared enum that vicario adopts, so that every dimension will validate in both directions and no mapping layer is needed. **Until vicario widens its own enum to match (a tracked vicario-repo task), a lens finding tagged `test`/`risk`/`comment` will not validate against an un-updated vicario** — so the enum is co-owned and changes are coordinated across both repos.

The exact field list — top-level, per-finding required/optional, and the `dimension` enum — is not restated here: `lens/schemas/review-findings.schema.json` is the machine contract, and `skills/engine/references/engine-api.md` is the declared programmatic surface it backs.

The alignment invariant is **field-additive only**: never rename, re-type, or repurpose a vicario field; only add optional ones. The `dimension` enum is **co-owned** — its nine values are the shared contract both repos honor; add a new dimension only by updating both schemas in lockstep (never silently in one).

**The invariant is about FIELDS, and 1.5.0 is where that distinction started to matter.** It binds the field set — no vicario field renamed, re-typed, repurposed or removed, and every lens extra optional — and it says nothing about **cross-field constraints**, which 1.5.0 adds three of (the `degraded` ⟺ `degradedReasons` biconditional, a set `emptyScope` flag forcing `findings[]` empty, and bounds on the `votes` counts — `total` ranged to `1..5`, and `total`/`couldNotRefute`/`refuted` floored at `0`). Those are **narrowings**: they reject documents the 1.4.3 schema accepted, and the biconditional in particular rejects *every* 1.4.3-produced return carrying `degraded: true`, because `degradedReasons` did not exist to satisfy it. A new cross-field rule is therefore **not** automatically covered by "field-additive" and must be judged, disclosed in `CHANGELOG.md`, and weighed against the round-trip claim below on its own terms.

**vicario vs matali.** vicario is the **schema-parity target** — the repo whose `review-findings` contract lens stays a field-additive superset of. The round-trip that still holds is the **lens → vicario** direction: lens's extra fields are optional, so vicario's validator ignores them (subject to the `dimension` enum note above). The **vicario → lens** direction is where the narrowings bite — a foreign or prior-run document is validated by rules its producer never knew about, so it can be rejected even though no field of it was ever renamed. **matali** is the **live consumer** — the orchestrator that dispatches lens's `engine`/`render-review` at runtime today. Parity with vicario is a compatibility invariant; matali is who actually calls lens now.

## The 3-tier finder registry

All finders emit the same `review-findings` contract; read-only is enforced at the boundary for every tier.

| Tier | Source | Read-only enforcement |
|---|---|---|
| **Built-in** | ships with lens — spec-adherence + plan-adherence (`requirements`), correctness, risk-classify, test-gaps | Authored findings-only by construction |
| **Adapter** | optional external tooling, runtime-detected, skipped silently if absent (the 5 read-only adapters below) | Most inherit write tools from their source → MUST be instructed findings-only |
| **Project-custom** | per-project finders registered in `.claude/lens/settings.md` — experimental — secondary to `injectedFinders` | Constrained findings-only at the dispatch boundary |

### The 5 read-only adapters (adapter tier)

Runtime-detected; skipped silently if the source plugin isn't installed. Each maps to a `review-findings` dimension:

| Adapter | Dimension |
|---|---|
| `silent-failure-hunter` | `silent-failure` |
| `type-design-analyzer` | `types` |
| `comment-analyzer` | `comment` |
| `pr-test-analyzer` | `test` |
| `feature-dev:code-reviewer` | `correctness` (2nd opinion) |

Most of these inherit write tools from their source plugin, so the dispatch wrapper must instruct them to produce **findings only** — no edits, no commits, no staging.

## Storage (`.claude/lens/`) + first-run setup

All lens files live under `.claude/lens/` (gitignored by default — review artifacts can contain session content). On the first review in a repo, lens does a one-time setup:

- **gitignore?** — offer to add `.claude/lens/` to `.gitignore` (default: yes).
- **default output path** — where rendered reviews are written.

Both choices persist to `.claude/lens/settings.md`. That file also holds the **project-custom finder registry** (the project tier above).

| Path | Purpose |
|---|---|
| `.claude/lens/settings.md` | gitignore choice + default output path + project-custom finder registry |
| `.claude/lens/review-state.json` | prior findings + statuses for state-aware re-review (fixed / open / new + severity trend) |
| `.claude/lens/<rendered review>` | the output artifact (HTML via walkthrough, or markdown fallback) |

## State-aware re-review

`.claude/lens/review-state.json` holds prior findings and their statuses. On a re-review of the same scope, the engine compares the new findings against the prior set to classify each as **fixed / still open / new**, and tracks the **severity trend** across runs — so a second review shows progress, not just a fresh wall of findings.

## Markdown fallback + the `walkthrough:render` handoff

The renderer's happy path is `walkthrough:render`: lens passes the fully-built review-model (it does no HTML synthesis itself) to walkthrough's internal `render` skill, which inlines it into the house-style interactive document. When walkthrough is **not installed**, lens renders the same review-model to a self-contained **markdown report** instead — same content (narrative, adherence, findings, risk, hunks, verdict), plainer form. The fallback is what keeps lens independently installable: walkthrough is an enhancer, never a dependency.

## Skills

lens has **four skills**: `review` (user-facing), `engine` (internal), `render-review` (internal), and
`capability` (internal). "lens-render" still names the **render role inside `skills/review`** for the
interactive `/lens:review` flow; `render-review` is the standalone, orchestrator-facing pure render
entrypoint — the externalized counterpart that completes the engine/render split for external consumers
(vicario/matali).

- `skills/review/SKILL.md` — the one user-facing skill (`/lens:review [target]`). Runs the full pipeline: delegates the 4-stage engine judgment (SCOPE→INTENT→ANALYZE→VERIFY) to `engine`, then owns the remaining 3 stages — `reconcile` → `render` → `report` (the `lens-render` half: review-model → `walkthrough:render` / markdown fallback). 8 harness tasks total (see § In-session task list).
- `skills/engine/SKILL.md` — **internal** (`user-invocable: false`), data-only judgment core: scope → intent → analyze → verify → dedup → rank → return `review-findings` JSON. Writes nothing, never prompts.
- `skills/render-review/SKILL.md` — **internal** (`user-invocable: false` — hidden from the user `/` menu, but **model-invocable**: an orchestrator's subagent dispatches it via the Skill tool, so it must NOT carry `disable-model-invocation`), the pure/stateless/write-once render entrypoint: it re-runs no finder, re-judges nothing, and writes exactly one file — the caller's. An orchestrator (matali) that owns persistence calls it after `engine`. Its inputs, its three possible returns, and the single path it may write are declared in `skills/engine/references/engine-api.md`.
- `skills/capability/SKILL.md` — **internal** (`user-invocable: false` — hidden from the user `/` menu, but **model-invocable**, so it must NOT carry `disable-model-invocation` either), the compatibility gate: reports the plugin version, the advertised `capabilities[]` token set, and `supports{}` — or a named-error miss when a requested token is absent. Declared in `skills/engine/references/engine-api.md` § lens:capability.
- `agents/` — six finder/verifier agent definitions: the **five built-in finder types** (`spec-adherence`, `plan-adherence`, `correctness`, `risk-classify`, `test-gaps`) that each emit `review-findings` tagged with their `dimension` — at runtime the 3 fixed finders run once while `spec-adherence`/`plan-adherence` fan out to one agent per spec / per plan (pipeline §3), plus the **`verifier`** (the adversarial skeptic used by the VERIFY stage, emitting a per-finding refute **vote** `{id, refuted, reason, status}`; the engine aggregates those votes and resolves each finding by the named rule `huginn-quorum-v1` — the tally shape and the resolution branches are declared at `skills/engine/references/pipeline.md` §5 and `skills/engine/references/engine-api.md`, not restated here). `test-gaps` owns the `test` / missing-test dimension; the `pr-test-analyzer` adapter only covers brittle/overfit.

No hooks, no scripts, no compiled code — consistent with the marketplace's all-markdown + JSON convention.
