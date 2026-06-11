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

## The pipeline (`/lens:review [target]`, 5 stages, all in-session)

```
1 SCOPE  →  2 INTENT  →  3 ANALYZE  →  4 VERIFY  →  5 ASSEMBLE
 diff       spec+plan    finder        adversarial   review-model
 target     → intent      registry      refute pass   → walkthrough:render
            record       (parallel)    (dedup)        → .claude/lens/
```

1. **SCOPE** — resolve the diff target. Default: working tree + this branch's commits vs the merge-base with the default branch; `[target]` overrides. Empty diff or no repo → tell the user, stop.
2. **INTENT** — locate the spec + plan and build an **intent record**. Priority: explicit args > `docs/superpowers/specs/` (latest) > the plan > the transcript. None found → reconstruct from the transcript and mark adherence `"reconstructed"`.
3. **ANALYZE** — dispatch finder subagents in parallel (see § Finder registry). Built-in finders are spec-adherence + plan-adherence (the wedge → `requirements` dimension), correctness, risk-classify, and test-gaps. All emit the same `review-findings` contract; read-only is **enforced at the boundary**.
4. **VERIFY** — adversarial refute pass. Each candidate finding goes to an independent skeptic agent prompted to **refute** it against real source; only unrefuted findings survive. Dedup across finders. A finding that **errors mid-verify is kept** as `"unverified — flagged"` — never silently dropped.
5. **ASSEMBLE** — build the review-model and invoke `walkthrough:render` (markdown fallback if absent) to an output path under `.claude/lens/`.

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

## The `review-findings` schema (the contract)

The engine emits, and the renderer consumes, a single canonical contract — `lens/schemas/review-findings.schema.json` (built in a later task). It is a versioned **field-additive superset of vicario's `review-findings.schema.json`**: lens's extra *fields* are additive/optional, so vicario's validator ignores them. **The `dimension` enum is the canonical 9-value shared contract** — vicario's six (`requirements|correctness|security|types|silent-failure|simplify`) plus lens's `test`/`risk`/`comment`. The target is a single shared enum that vicario adopts, so that every dimension will validate in both directions and no mapping layer is needed. **Until vicario widens its own enum to match (a tracked vicario-repo task), a lens finding tagged `test`/`risk`/`comment` will not validate against an un-updated vicario** — so the enum is co-owned and changes are coordinated across both repos.

- **Top-level:** `findings[]`, `recommendedEscalation` (`minor|moderate|major|critical`), `degraded` (bool), `summary` (optional).
- **Per finding — required:** `id`, `title`, `severity` (`critical|high|medium|low` — exactly vicario's enum; **no `info`**, which is a render-only chip role), `dimension`, `verified` (bool).
- **Per finding — optional:** `file`, `line`, `votes{total,couldNotRefute,refuted}`, and additive `claim`, `detail`, `suggestedFix`, `source`, `label`, `tags[]`.
- **`dimension` enum:** vicario's six (`requirements|correctness|security|types|silent-failure|simplify`) **plus** lens additions `test`, `risk`, `comment`.

The alignment invariant is **field-additive only**: never rename, re-type, or repurpose a vicario field; only add optional ones. The `dimension` enum is **co-owned** — its nine values are the shared contract both repos honor; add a new dimension only by updating both schemas in lockstep (never silently in one).

## The 3-tier finder registry

All finders emit the same `review-findings` contract; read-only is enforced at the boundary for every tier.

| Tier | Source | Read-only enforcement |
|---|---|---|
| **Built-in** | ships with lens — spec-adherence + plan-adherence (`requirements`), correctness, risk-classify, test-gaps | Authored findings-only by construction |
| **Adapter** | optional external tooling, runtime-detected, skipped silently if absent (the 5 read-only adapters below) | Most inherit write tools from their source → MUST be instructed findings-only |
| **Project-custom** | per-project finders registered in `.claude/lens/settings.md` | Constrained findings-only at the dispatch boundary |

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
| `.claude/lens/review-state.json` | prior findings + statuses for state-aware re-review (fixed / open / new + verdict trend) |
| `.claude/lens/<rendered review>` | the output artifact (HTML via walkthrough, or markdown fallback) |

## State-aware re-review

`.claude/lens/review-state.json` holds prior findings and their statuses. On a re-review of the same scope, the engine compares the new findings against the prior set to classify each as **fixed / still open / new**, and tracks the **verdict trend** across runs — so a second review shows progress, not just a fresh wall of findings.

## Markdown fallback + the `walkthrough:render` handoff

The renderer's happy path is `walkthrough:render`: lens passes the fully-built review-model (it does no HTML synthesis itself) to walkthrough's internal `render` skill, which inlines it into the house-style interactive document. When walkthrough is **not installed**, lens renders the same review-model to a self-contained **markdown report** instead — same content (narrative, adherence, findings, risk, hunks, verdict), plainer form. The fallback is what keeps lens independently installable: walkthrough is an enhancer, never a dependency.

## Skills (planned surface — built in later tasks)

- `review/SKILL.md` — the one user-facing skill (`/lens:review [target]`). Runs the 5-stage pipeline: delegates the judgment half to `engine`, then does the render half (`lens-render`: review-model → `walkthrough:render` / markdown fallback).
- `engine/SKILL.md` — **internal** (`user-invocable: false`), data-only judgment core: scope → intent → analyze → verify → dedup → rank → return `review-findings` JSON. Writes nothing, never prompts.
- `agents/` — six finder/verifier agents: the **five built-in finders** (`spec-adherence`, `plan-adherence`, `correctness`, `risk-classify`, `test-gaps`) that each emit `review-findings` tagged with their `dimension`, plus the **`verifier`** (the adversarial skeptic used by the VERIFY stage, emitting a per-finding refute **vote** `{id, refuted, reason, status}`; the engine aggregates these votes into the schema's `votes{total,couldNotRefute,refuted}` and resolves each finding's `verified` bool). `test-gaps` owns the `test` / missing-test dimension; the `pr-test-analyzer` adapter only covers brittle/overfit.

No hooks, no scripts, no compiled code — consistent with the marketplace's all-markdown + JSON convention.
