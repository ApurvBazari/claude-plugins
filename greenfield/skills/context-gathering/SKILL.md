---
name: context-gathering
description: Greenfield Phase 1 — adaptive wizard that gathers project vision, tech stack, features, and preferences through 17 named Steps. Internal building block invoked by greenfield init — not user-invocable.
user-invocable: false
---

# Context Gathering Skill — Adaptive Project Wizard

You are guiding a developer through an interactive wizard to understand what they want to build, their tech stack preferences, workflow, and project requirements. This is Phase 1 of the Greenfield plugin.

## Purpose

Gather all context needed to scaffold a project and generate AI tooling. Every decision for Phase 2 (scaffolding) and Phase 3 (AI tooling) flows from the answers collected here.

## Default Rendering Contract

Every question in `references/question-bank.md` has a `**Default**:` block. The wizard uses this to prefill answers and enable Enter-to-accept. See `references/defaults-derivation.md` for the full format spec and precedence rules.

**How to display a question with a default**:

Derive the default at render time (stack-derived rules are evaluated against current context; see derivation rules in the question's `**Default**:` block). Then append `[default: <value>]` to the question prompt before displaying it. Example:

> What's your service topology?
>
> 1. Monolith (single deployable unit)
> 2. Modular monolith (internal modules, single deploy)
> 3. Microservices (independent services, independent deploys)
> 4. Serverless (function-per-endpoint, no persistent server)
>
> [default: Monolith]

**Accepting a default**: if the developer presses Enter or replies with an empty string:
- Record the default value in `context.phases.*` at the appropriate field.
- Log `context.defaultsAccepted[questionId] = true`.
- Move to the next question.

**Overriding a default**: if the developer types any non-empty response:
- Parse and record the typed value in `context.phases.*`.
- Log `context.defaultsAccepted[questionId] = false`.
- Move to the next question.

**Open-ended skip** (questions marked `(skip with Enter)` in their Default block): Enter produces `null` or `""` — not the string "skip". Do not add a `defaultsAccepted` entry for these questions.

The `defaultsAccepted` map is written to `greenfield-state.json` as part of the normal context checkpoint and is used by synthesis-review to annotate which values were accepted defaults vs explicit developer choices.

## Conversation Style

- **Conversational, not interrogative** — This is a dialogue, not a survey. Acknowledge answers, connect them to prior context, and be helpful.
- **One question at a time** — Ask a single question per message. If a topic needs exploration, break it into follow-ups.
- **Recommend, don't just list** — When presenting options, lead with your recommendation and explain why.
- **Skip intelligently** — Never ask a question whose answer is already clear from prior context.
- **Research-informed** — After learning the stack, pause for web research before continuing. Use findings to inform subsequent questions and recommendations.
- **Default-first** — Every question has a smart default. Display it with `[default: X]`; Enter accepts. This keeps the wizard fast for developers who agree with greenfield's opinions and still allows full customization for those who don't.

## Planner Scope Principle

From Anthropic's harness design: "If the planner tried to specify granular technical details upfront and got something wrong, the errors in the spec would cascade into the downstream implementation."

Phase 1 acts as the **Planner** in the three-agent pattern. It should:
- Focus on WHAT to build (product features, user flows, requirements)
- Capture high-level technical decisions (framework, language, database type)
- Let the Generator (implementation sessions) figure out HOW (specific patterns, file organization, internal architecture)
- Be ambitious about scope — suggest features beyond the minimum viable product

Do NOT over-prescribe:
- Don't specify internal code architecture (folder structure beyond top-level, specific design patterns)
- Don't dictate implementation approaches for individual features
- Don't make granular technical decisions that could cascade if wrong (specific library APIs, internal data structures)

## Adaptive State Machine

Maintain a running context object that tracks what you know. See `references/question-bank.md` for the complete question catalog with conditions and downstream effects.

### Context Object

```json
{
  "appType": null,
  "appDescription": null,
  "hasBackend": false,
  "hasFrontend": false,
  "isLocal": false,
  "isProduction": false,
  "hasTeam": false,
  "willDeploy": false,
  "hasDatabase": false,
  "hasAPI": false,
  "defaultsAccepted": {}
}
```

Update this after every answer. Before asking each question, check its condition in the question bank. If the condition is not met, skip silently. After each answer, update `defaultsAccepted[questionId]` with `true` (Enter accepted default) or `false` (developer typed an override). Questions with `(skip with Enter)` defaults are not tracked in `defaultsAccepted`.

## Progress Indicator Protocol

At the start of every Step (and whenever the user asks "where are we?"), emit a one-line progress indicator so both Claude and the user can see wizard progress:

> **Wizard progress: Step [X] of 17 — [step name]**
> Completed: [list of step names from completedSteps]
> Up next: [name of the next step, if known]

This is NOT optional. Long sessions derail without this anchor.

## Deep Research Park — the scope-creep escape hatch

Some questions in this wizard can trigger deep architectural research that takes significant time (30+ minutes). Examples from real sessions:
- "Which on-device LLM tier for an Android finance tracker?"
- "How should we structure a multi-tenant database for a SaaS?"
- "What's the best real-time sync architecture for a collaborative editor?"

The wizard is NOT the place for deep research. If you (Claude) detect a question that requires it, **STOP and offer the user a choice** before going deeper:

> This question is deeper than a typical wizard question. I can handle it three ways:
>
> 1. **Park it** (recommended if you're not sure) — I capture a placeholder answer with a default assumption, we continue the wizard to the end, then after Phase 1 completes we enter a dedicated "Architectural Research" sub-phase to deep-dive on all parked questions with full attention. This keeps the wizard short and focused.
> 2. **Deep-dive now** — I pause the wizard, research this thoroughly (may take 20-40 minutes), then resume the wizard where we left off. Good if the decision blocks everything else.
> 3. **Take a default** — I pick the most common reasonable answer and move on. Good if you don't actually care about the decision and just want to ship.

Use `AskUserQuestion` with these three options. On "Park it":
- Capture the question, your best-effort placeholder answer, and a one-sentence "why this needs research" note into `parkedQuestions[]` in `greenfield-state.json`
- Continue the wizard with the placeholder
- At end of Phase 1, if `parkedQuestions.length > 0`, enter **Phase 1.5: Architectural Research** (new optional sub-phase, see below)

On "Deep-dive now": do the research inline, capture findings to `researchFindings`, then resume the wizard.

On "Take a default": note the default choice and any assumptions made, then move on.

## Signs of derailment (stop and course-correct)

If any of these happen, you've lost the wizard thread:
- More than 10 back-and-forth messages inside a single Step
- You've started doing WebFetch calls not explicitly for stack research
- The user has asked "where were we?" or similar
- You're about to spawn a research agent for a question that wasn't part of the Tech Stack step

When you notice any of these, STOP and:
1. Summarize what context has been gathered so far
2. Explicitly name the current Step and how many questions remain in it
3. Offer the "Park it" escape hatch if a research rabbit hole is brewing
4. Checkpoint to `greenfield-state.json` immediately (don't wait for Step completion)

## Flow

### Step 1 of 17: Project Vision (Category 1)

Emit the progress indicator. Then start with Q1.1: "What do you want to build?"

Listen carefully. From the answer, infer:
- `appType` (web-app, api, cli, library, fullstack, mobile-backend)
- `hasFrontend`, `hasBackend`, `hasAPI`

**Q1.2 (legacy, Round 4 demoted):** Q1.2 "Who is this for? What problem does it solve?" was demoted to a pointer in Round 4 — the structured Personas capture at Step 2.2 supersedes it. **Do not ask Q1.2 in new wizard runs.** Skip directly from Q1.1 → Step 1.1 mode toggles.

**Backward-compat for alpha.4 sessions:** if `.claude/greenfield-state.json` has `vision.users[]` populated (from a pre-R4 alpha.4 wizard run that the pickup migration shim restored), surface to the user at Step 2.2 entry:

> Migrated from Step 1 of alpha.4 wizard: `{{vision.users|join(', ')}}`. Want to restructure these into the new Personas format?

Default: Yes. If user accepts, use the legacy strings as draft `personas.primary[].name` values; Q2-Q8 of Step 2.2 then enrich each. If declined, preserve `vision.users[]` as-is in state (Q_RISK auto-loop in Step 5+ falls back to top-level users-of-app description rather than per-persona loops).

### Step 1.1 — Mode toggles

After intro narration, capture three mode dimensions via batched AskUserQuestion. All three have ≥ 2 static options — no `ask-user-question-guard.md` padded-None branch needed (single batched call, three single-select questions).

**Defaults reflect a comprehensive-by-default posture.** Lighter modes are explicit opt-ins.

**Question 1 — Depth**

```
"Wizard depth — comprehensive or stripped-down?"
  • Heavy (Recommended) — ~120 Qs total, comprehensive for production projects
  • Light                — ~65 Qs total, stripped for prototypes / spike work
```

Persist as `mode.depth` (`"heavy"` | `"light"`).

**Question 2 — Coupling**

```
"Coupling between discovery (personas/domain) and architecture — tight or loose?"
  • Auto-loop (Recommended) — every architectural phase iterates per persona AND per entity
  • Hybrid                   — only `loopMode: always` Qs loop; `loopMode: hybrid-only` Qs fire static once
```

Persist as `mode.coupling` (`"auto-loop"` | `"hybrid"`).

**Question 3 — Domain format**

```
"Domain modeling depth — full DDD or lite?"
  • Full DDD (Recommended) — bounded contexts + entities + value objects + domain events + ubiquitous language + anti-corruption layers
  • DDD-lite               — drops value objects, domain events, anti-corruption (Steps 2.7 Q6, Q7, Q10 skip)
```

Persist as `mode.domainFormat` (`"full-ddd"` | `"ddd-lite"`).

**Adjacent runaway guard** — if the user picks Heavy + Full DDD + Auto-loop AND the project description (from Step 1) is < 200 chars OR contains any of {"weekend", "learning", "toy", "experiment", "spike"} (case-insensitive), surface ONE-TIME prompt at the start of Step 2 (vision/scope):

> "Heavy + Full DDD + Auto-loop is calibrated for production projects. Your description suggests a smaller-scale effort. Switch to Light + DDD-lite + Hybrid? (Yes / No, keep current)"

Persist any switch to `mode.*` and append an audit entry to `greenfield-meta.json.audit[]`.

### Step 2 of 17: Tech Stack (Category 2)

Emit the progress indicator. Ask Q2.1 about their stack preference. If they know, ask Q2.2 for details.

**Research pause**: After gathering the stack, dispatch the `stack-researcher` agent with a clear research brief. The agent's first action is a real npm-registry call (zero overhead when web works) — if that fails, the agent immediately returns the sentinel `STACK_RESEARCH_REQUIRES_MAIN_SESSION` (see `greenfield/agents/stack-researcher.md` § Sentinel and `greenfield/skills/start/references/stack-research-checklist.md` § 0 / § Output).

**Handling the two possible agent outcomes**:

#### Outcome A — Agent returns a full research report
Proceed normally. Present findings naturally: *"I looked into [framework] — the current stable version is [X]. The official scaffold CLI `[command]` now supports [features]. I'd recommend using that."*

#### Outcome B — Agent returns the sentinel (sub-agent web access denied)

Detect by greping the agent's response for the literal string `STACK_RESEARCH_REQUIRES_MAIN_SESSION`. Do NOT silently fail; do NOT re-dispatch the agent (that would loop). Instead, **fall back to main-session research using the shared checklist**:

1. Tell the user what happened, concisely:
   > "The background research agent doesn't have web access in this session. I'll run the same research checklist in our main conversation so you can see and approve each web call."

2. Read `greenfield/skills/start/references/stack-research-checklist.md` and run sections 1-7 inline using main-session `WebSearch` and `WebFetch`. Per-call permission prompts will appear to the user; ask them to approve so research can proceed. The checklist is the single source of truth shared with the agent — following it inline produces the same report shape.

3. If the user denies web access entirely, offer a degraded path:
   > "Without web research, I'll use my training data to make stack recommendations, but please verify versions and scaffold CLIs manually before we proceed with scaffolding — my knowledge may be months out of date."

4. Checkpoint the fallback mode in `greenfield-state.json` under `research.mode = "main-session" | "training-data-only"` so downstream skills know the research provenance.

5. **Hard-failure path**: if main-session retries also fail (network down, all per-call permissions denied), surface a clear error to the user — do NOT silently proceed with empty research. Greenfield's downstream phases need at least the basic stack metadata.

Wait for research results (either via agent or main session). Then ask Q2.3 about the scaffold approach, informed by the research findings.

### Step 2.2 — Personas

- **Q-bank:** `personas.q-bank.md` (16 Qs heavy / 4 light)
- **Loop structure:**
  - Q1 sets primary persona count → Q2–Q8 loop once per primary persona
  - Q9 asks whether secondary personas exist → Q10–Q11 loop once per secondary
  - Q12 captures anti-pattern notes (top-level)
  - Q_RISK fires once at end
- **Skip path:** if user opts "Capture anti-personas only" at Q1, set `personas.skipped: true` and jump to Q12 + Q_RISK
- **Persona aggregation rules:** after Q2–Q8 loop completes for all primary personas, derive `personas.antiPersonas[]` by collecting every non-empty `personas.primary[*].antiPersona` value (de-duplicated, preserve insertion order). Both paths coexist: per-persona for capture provenance, top-level for synthesis rendering.
- **On phase completion:**
  1. Write `docs/adr/personas.html` + `personas.md` via synthesis-review (template variables include the aggregated `personas.antiPersonas[]` and a pre-rendered `context.deviceLabel` scalar for each persona — see § Render hooks)
  2. Write `docs/adr/personas.dependencies.json`
  3. Append `Persona.Q_RISK` answer to top-level `risks[]` array (id auto-assigned `R-PERSONAS-1`)
  4. Checkpoint state to `.claude/greenfield-state.json`
- **State-machine constraint:** auto-loop downstream phases (Step 5 auth, Step 6 privacy, Step 7 security, Step 8 runtimeOps) MUST observe `personas.primary[]` length when iterating any Q with `loopOver: personas.primary`. If length is 0 (user skipped), downstream loops skip too.

### Step 2.5 of 17: Architectural Framing

Emit the progress indicator. This step gathers the early architectural decisions that inform all detailed phases (P3–P9): service topology, deployment shape, and scale target. Ask questions AF.Q1–AF.Q4 from `references/question-bank.md § Step 2.5: Architectural Framing` in order.

**Stale entry-guard** (check before any wizard prompt fires for this step): read `context.phaseStatus.architecturalFraming.status`. If it is `"stale"`, this guard triggers before the synthesis-review skill is invoked — it is handled inside `synthesis-review` Step 0 when re-entry is attempted. If `completedSteps` already contains `"step-2.5-architectural-framing"` AND `phaseStatus.architecturalFraming.status === "stale"`, skip re-asking the wizard questions (the answers are still in `context.phases.architecturalFraming`) and proceed directly to the synthesis-review call, which will surface the Step 0 re-walk prompt.

**Data layout** — answers populate `context.phases.architecturalFraming.*` directly. The 3 required enum-locked fields are `topology`, `deploymentShape`, `scaleTarget`; `boundaryNotes` is a loose string.

Tell the developer:

> Step 2.5 of 17: Architectural Framing. Before we dive into data, APIs, and CI/CD, I want to lock in three foundational choices — service topology, deployment shape, and scale target — so the detailed phases inherit consistent assumptions. 4 questions; the last is open-ended.

#### Architectural Framing questions (AF.Q1–AF.Q4)

Ask each question from `references/question-bank.md § Step 2.5: Architectural Framing` in order. Honor the conditions.

| Q | Topic | Writes to (under `context.phases.architecturalFraming`) |
|---|---|---|
| AF.Q1 | Service topology | `topology` (required, enum) |
| AF.Q2 | Deployment shape | `deploymentShape` (required, enum) |
| AF.Q3 | Scale target | `scaleTarget` (required, enum) |
| AF.Q4 | Boundary expectations | `boundaryNotes` (loose string) |

**Adaptive skipping**: if `appType: cli`, skip AF.Q2 (deploymentShape) but still ask AF.Q1, AF.Q3, and AF.Q4. If `willDeploy = false`, default `deploymentShape` to `"single-region"` and note the default rather than asking.

**State checkpointing**: after each answered question, write to `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-2.5-architectural-framing"`.

#### Phase 1.8: synthesis review (after AF.Q4, or after the last applicable question if skipping fired)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "architecturalFraming"`. The skill:

1. Sets `greenfield-state.json.currentPhase` to `phase-1.8-synthesis-review` and `currentSynthesisPhase: "architecturalFraming"`.
2. Renders `docs/adr/architectural-framing.html` in the scaffolded project using the 3-section template.
3. Walks the developer through Approve/Adjust/Skip per section.
4. Writes `context.syntheses.architecturalFraming = { approvedAt, adjustments[] }`.
5. Writes `docs/adr/architectural-framing-dependencies.json` from the wizard-collected dependency edges.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `architectural-framing.html` ships in Round 2.5), tell the developer and continue to Step 2.7.

### Step 2.7 — Domain Modeling

- **Q-bank:** `domain-model.q-bank.md` (11 Qs Full DDD / ~8 DDD-lite / ~6 Light)
- **Loop structure:**
  - Q1 sets bounded-context list → Q2 loops once per BC (responsibility)
  - Q3 loops once per BC (entities under that BC; each entity captured with `id`, `contextId`, `isAggregateRoot`)
  - Q4 + Q5 nested-loop per entity (aggregate-root flag, relationships)
  - Q6 (value objects), Q7 (domain events), Q10 (anti-corruption) are **mode-gated** — skip when `mode.domainFormat == "ddd-lite"` OR `mode.depth == "light"`
  - Q8 captures cross-context relationships (top-level)
  - Q9 captures ubiquitous language glossary (top-level)
  - Q_RISK fires once at end
- **Mode-gated rendering:** synthesis HTML/MD render mode-gated sections as `(deferred — DDD-lite mode)` or `(deferred — Light mode)` placeholders (handled by synthesis-review skill; no action needed here).
- **Deferred fields:** owned-entity rendering (`↳` indentation in synthesis) and entity descriptions are deferred; entities render flat in synthesis until a follow-up round extends Q3.
- **On phase completion:**
  1. Write `docs/adr/domain-model.html` + `domain-model.md` via synthesis-review
  2. Write `docs/adr/domain-model.dependencies.json`
  3. Append `Domain.Q_RISK` answer to `risks[]` (id `R-DOMAINMODEL-1`)
  4. Checkpoint state
- **State-machine constraint:** auto-loop downstream phases that loop over entities (Step 3 dataArchitecture, Step 4 apiIntegration, Step 7 security `attack-surface`) MUST observe `domainModel.entities[]` length. If length is 0 (no entities — possible in a pure-API project or a project with auth-only scope), downstream entity loops skip too.

### Step 3 of 17: Data Architecture

This step is Round 2's first new phase. Captures data-layer decisions via P3.Q1–P3.Q12 and closes with an inline Phase 1.8 synthesis-review pass.

**Stale entry-guard** (check before any wizard prompt fires for this step): if `completedSteps` already contains `"step-3-data-architecture"` AND `context.phaseStatus.dataArchitecture.status === "stale"`, skip re-asking the wizard questions and proceed directly to the synthesis-review call. Synthesis-review Step 0 will surface the re-walk prompt to the developer.

**Data layout** — answers populate `context.phases.dataArchitecture.*` directly (no v1 carryover). The 4 required enum-locked fields are `databaseHost`, `orm`, `migrationsTool`, `multiTenancy`; remaining fields are loose strings.

Tell the developer:

> Step 3 of 17: Data Architecture. I'll ask about your data layer — database engine, ORM, migrations, multi-tenancy, caching, file storage. About 12 questions. Some may be skipped based on your earlier answers.

#### Data Architecture questions (Q3.1–Q3.12)

Ask each question from `references/question-bank.md § Step 3: Data Architecture` in order. Honor the conditions. Write each answer to its destination field under `context.phases.dataArchitecture`.

| Q | Topic | Writes to (under `context.phases.dataArchitecture`) |
|---|---|---|
| P3.Q1 | DB needed? (gate) | gate flag |
| P3.Q2 | Engine | `engine` (loose) |
| P3.Q3 | Hosting model | `databaseHost` (required, enum) |
| P3.Q4 | ORM | `orm` (required, enum) |
| P3.Q5 | Migration tool + mode | `migrationsTool` (required) + `migrationsMode` (loose) |
| P3.Q6 | Multi-tenancy | `multiTenancy` (required, enum) |
| P3.Q7 | Search | `search` (loose) |
| P3.Q8 | Cache + invalidation | `cache` + `cacheInvalidation` (loose) |
| P3.Q9 | File storage | `fileStorage` (loose) |
| P3.Q10 | Codegen | `codegen[]` (loose array) |
| P3.Q11 | Backup | `backup` (loose) |
| P3.Q12 | Compliance | `compliance` (loose) |

**Adaptive skipping**: if P3.Q1 = "No persistent data", skip Q2–Q7 but still ask Q8 (in-memory cache), Q9 (FS storage), Q10 (codegen), Q12 (compliance). If `appType: cli`, skip the entire phase.

**State checkpointing**: after each answered question, write to `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`.

#### Phase 1.8: synthesis review (after P3.Q12, or after the last applicable question if any skipping fired)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "dataArchitecture"`. This is Round 2's first synthesis pass. The skill:

1. Sets `greenfield-state.json.currentPhase` to `phase-1.8-synthesis-review` and `currentSynthesisPhase: "dataArchitecture"`.
2. Renders `docs/adr/data-architecture.html` in the scaffolded project using the 7-section template.
3. Walks the developer through Approve/Adjust/Skip per section.
4. Writes `context.syntheses.dataArchitecture = { approvedAt, adjustments[] }`.
5. Writes `docs/adr/data-architecture-dependencies.json` from the wizard-collected dependency edges.

If the developer adjusts any dataArchitecture field via the Adjust dialog, the updated value lives in `context.phases.dataArchitecture.<field>` directly.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `data-architecture.html` ships in Round 2), tell the developer and continue to Step 4.

### Step 4 of 17: API & Integration

This step is Round 2's second new phase. Captures API surface decisions via P4.Q1–P4.Q10 and closes with an inline Phase 1.8 synthesis-review pass.

**Stale entry-guard**: if `completedSteps` already contains `"step-4-api-integration"` AND `context.phaseStatus.apiIntegration.status === "stale"`, skip re-asking wizard questions and proceed directly to synthesis-review (which handles the re-walk prompt in Step 0).

**Data layout** — answers populate `context.phases.apiIntegration.*` directly. The 3 required enum-locked fields are `style`, `versioningPolicy`, `asyncPattern`; remaining fields are loose strings or arrays.

Tell the developer:

> Step 4 of 17: API & Integration. I'll ask about your API surface — style (REST/GraphQL/tRPC), versioning, rate limits, async patterns, real-time, webhooks, external services. About 10 questions; some skipped based on whether you expose an API.

#### API & Integration questions (Q4.1–Q4.10)

Ask each question from `references/question-bank.md § Step 4: API & Integration` in order. Honor the conditions.

| Q | Topic | Writes to (under `context.phases.apiIntegration`) |
|---|---|---|
| P4.Q1 | API exposed? (gate) | gate flag |
| P4.Q2 | Style | `style` (required, enum) |
| P4.Q3 | Documentation | `documentation` (loose) |
| P4.Q4 | Versioning | `versioningPolicy` (required, enum) |
| P4.Q5 | Rate limit | `rateLimit` (loose) |
| P4.Q6 | Pagination | `pagination` (loose) |
| P4.Q7 | Async pattern | `asyncPattern` (required, enum) |
| P4.Q8 | Real-time | `realtime` (loose) |
| P4.Q9 | Webhooks | `webhooks` (loose) |
| P4.Q10 | External services | `externalServices[]` (loose array) |

**Adaptive skipping**: if `appType: cli` OR (`!hasBackend && !hasFrontend`), skip the entire phase. If P4.Q1 = "No", skip Q2–Q9 but still ask Q10. If `!willDeploy`, skip Q4 (versioning) and Q5 (rate limit).

**State checkpointing**: set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-4-api-integration"`.

#### Phase 1.8: synthesis review (after P4.Q10, or after the last applicable question)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "apiIntegration"`. The skill:

1. Sets `currentSynthesisPhase: "apiIntegration"`.
2. Renders `docs/adr/api-integration.html` using the 6-section template.
3. Walks Approve/Adjust/Skip per section.
4. Writes `context.syntheses.apiIntegration = { approvedAt, adjustments[] }`.
5. Writes `docs/adr/api-integration-dependencies.json`.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `api-integration.html` ships in Round 2), tell the developer and continue to Step 5.

### Step 5 of 17: Auth

Emit the progress indicator. This step gathers identity and access control decisions: strategy, identity providers, session model, MFA, authorization, tenancy, service-to-service auth, lifecycle, recovery, password policy, audit log, enforcement point. About 12 questions; some may be skipped based on `auth.strategy` and earlier framing/data/api answers.

**Stale entry-guard** (check before any wizard prompt fires for this step): if `completedSteps` already contains `"step-5-auth"` AND `context.phaseStatus.auth.status === "stale"`, skip re-asking the wizard questions and proceed directly to the synthesis-review call. Synthesis-review Step 0 will surface the re-walk prompt.

Tell the developer (verbatim):

> Step 5 of 17: Auth. I'll ask about authentication strategy, identity providers, session model, MFA, authorization, and audit. About 12 questions. Some may be skipped based on your earlier framing and data decisions.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 5: Auth` in order (Auth.Q1 through Auth.Q12). Honor the conditions. Write each answer to its destination field under `context.phases.auth`.

**State checkpointing**: after each answered question, write to `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-5-auth"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "auth")
```

This will render `docs/adr/auth.md` + `docs/adr/auth.html` and walk the developer through approve/adjust/skip for each section. Returns control here with `phaseStatus.auth.status` updated.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `auth.html`/`.md` ship in Round 3 commit `ccffdd6`), tell the developer and continue to Step 6.

---

### Step 6 of 17: Privacy

Emit the progress indicator. This step classifies the data and gates regulatory scope. If `auth.strategy = 'none'`, the wizard fires a single-Q gate FIRST. If the gate returns "No data collected", Privacy synthesis is rendered as an n/a stub and Q1-Q11 are skipped.

**Stale entry-guard**: if `completedSteps` already contains `"step-6-privacy"` AND `context.phaseStatus.privacy.status === "stale"`, skip re-asking the wizard questions and proceed directly to the synthesis-review call.

**Skip-cascade gate (only if `auth.strategy === 'none'`):**

Ask the Privacy.Gate question first (from `references/question-bank.md § Step 6: Privacy > Privacy.Gate`):

> Do you collect any user data at all — emails, IPs, behavioral analytics, contact form submissions?

If the answer is "No":
- Set `context.phases.privacy.synthesisStatus = "n/a"`
- Set `context.phaseStatus.privacy.status = "skipped"` (NOT "complete" — required so the skip-cascade reversal logic in `pickup` can detect a later un-skip when auth.strategy changes)
- Skip Q1-Q11 entirely
- Invoke `Skill(synthesis-review, phaseId: "privacy")` — synthesis-review will render the n/a stub template and confirm with developer
- Proceed to Step 7

If the answer is "Yes":
- Set `context.phases.privacy.synthesisStatus = "complete"`
- Continue to Q1-Q11 below

**If `auth.strategy !== 'none'`**, skip the gate entirely and start at Q1.

Tell the developer (verbatim, after the gate decision):

> Step 6 of 17: Privacy. I'll ask about regulatory scope, PII inventory, consent, retention, deletion, DSAR, and data residency. About 11 questions; some may be skipped based on regulations and data architecture.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 6: Privacy` (Privacy.Q1 through Privacy.Q11, excluding Privacy.Gate which already ran) in order. Honor the conditions. Write each answer to its destination field under `context.phases.privacy`.

**State checkpointing**: after each answered question, write `greenfield-state.json.tmp` and rename atomically. Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-6-privacy"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "privacy")
```

If `synthesisStatus: "n/a"` was set by the gate, synthesis-review uses the stub template; otherwise it renders the full template.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `privacy.html`/`.md` ship in Round 3 commit `298ed81`), tell the developer and continue to Step 7.

---

### Step 7 of 17: Security

Emit the progress indicator. This step covers application security posture: sensitivity tier, secret management, vulnerability scanning, threat model, encryption, headers, input validation, audit retention, IR pointer, pentest cadence, VDP, supply chain. About 13 questions; some may be skipped based on `security.sensitivityTier` and `architecturalFraming.scaleTarget`.

**Stale entry-guard**: if `completedSteps` already contains `"step-7-security"` AND `context.phaseStatus.security.status === "stale"`, skip re-asking wizard questions and proceed directly to the synthesis-review call.

Tell the developer (verbatim):

> Step 7 of 17: Security. I'll ask about sensitivity tier, secret management, vulnerability scanning, threat model, encryption, audit logging, incident response, and supply chain. About 13 questions. Some may be skipped for hobby-scale projects.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 7: Security` (Sec.Q1 through Sec.Q13) in order. Honor the conditions. Write each answer to its destination field under `context.phases.security`.

**State checkpointing**: set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-7-security"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "security")
```

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `security.html`/`.md` ship in Round 3 commit `4288039`), tell the developer and continue to Step 8.

---

### Step 8 of 17: Runtime Operations

Emit the progress indicator. This step covers background jobs, observability, alerting, feature flags, maintenance mode, health checks, runbooks, incident process, and on-call. About 14 questions; Ops.Q1-Q3 (jobs/retry/scheduling) skip when `apiIntegration.asyncPattern='none'`. Ops.Q8 (SLO) skips for non-production scale targets. Ops.Q12, Ops.Q14 auto-skip for hobby.

**Stale entry-guard**: if `completedSteps` already contains `"step-8-runtime-ops"` AND `context.phaseStatus.runtimeOperations.status === "stale"`, skip re-asking wizard questions and proceed directly to the synthesis-review call.

Tell the developer (verbatim):

> Step 8 of 17: Runtime Operations. I'll ask about background jobs, observability (metrics/traces/logs), alerting, feature flags, maintenance mode, health checks, runbooks, and incident response. About 14 questions. Some are skipped for hobby projects or no-async-work setups.

Then run the wizard.

Ask each question from `references/question-bank.md § Step 8: Runtime Operations` (Ops.Q1 through Ops.Q14) in order. Honor the conditions. Write each answer to its destination field under `context.phases.runtimeOperations`.

**State checkpointing**: set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-8-runtime-ops"`.

**At end of step**, invoke synthesis-review inline:

```
Skill(synthesis-review, phaseId: "runtimeOperations")
```

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `runtime-operations.html`/`.md` ship in Round 3 commit `abcd928`), tell the developer and continue to the residual step (Step 9 after T21 renumbering).

---

### Step 9 of 17: Remaining Project Details (residual)

This step holds the 13 Category 3 questions that have NOT been re-homed to Data Architecture or API & Integration in Round 2. They stay here as transitional content until Rounds 3–6 re-home them to vision/frontend/authSecurity/workflow. See `references/question-bank.md § Category 3 (residual)` for the full question list.

Tell the developer:

> Step 9 of 17: Remaining Project Details. A few miscellaneous questions about scale, auth, deploy target, monitoring, environment, dependencies, accessibility, performance, i18n, monorepo, and styling. Skipped if not relevant to your stack.

Ask Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 in order from `references/question-bank.md § Category 3 (residual)`. Honor existing conditions. No synthesis review for this step (it's residual; full split planned for Rounds 3–6).

State checkpoint: `currentStep: "step-9-residual"`.

Emit the progress indicator. Work through the residual Category 3 questions adaptively. The question bank specifies conditions for each — only ask what's relevant.

**Scaffold mode question (new, ask once)** — after capturing the basic project details but before asking about deploy, ask:

> **Scaffold mode**: How much should I scaffold in Phase 2?
>
> 1. **Full scaffold** (recommended for most projects) — I scaffold the complete starter app using the official CLI (or from scratch for stacks without one). Phase 3 AI tooling runs against the finished scaffold. Best for Next.js, FastAPI, Go, Rust, and any stack with a `create-*` CLI tool.
> 2. **Walking skeleton** — I scaffold only one representative of each architectural pattern (one entity, one DAO, one route, one test, one service), enough for the AI tooling to derive project-specific rules from. Then Phase 3 generates CLAUDE.md and hooks from those patterns. Then Phase 2b expands the scaffold under AI-tooling guidance. Best for native mobile (Android/iOS), custom backends, complex architectures, or stacks without a mature CLI.
> 3. **Not sure, pick for me** — I look at your stack and recommend. Default: full scaffold.

Capture the answer as `context.scaffoldMode = "full" | "walking-skeleton"`.

**Auto-recommendation logic** if user picks option 3:
- If stack has a well-maintained official CLI (`create-next-app`, `npm create vite`, `uv init`, `cargo new`, `go mod init` + template, etc.) → recommend `full`
- If stack is native mobile (Android Kotlin, iOS Swift) → recommend `walking-skeleton`
- If stack is an unusual combination or user explicitly said "something custom" → recommend `walking-skeleton`
- Explain the recommendation and wait for confirmation.

Key branching points:
- Q3.1 (scale) → updates `isProduction`, `hasTeam`
- Q3.4 (deploy) → if "Not deploying", sets `willDeploy = false` and skips all CI/CD questions

For frontend projects, also ask Q3.F1 (styling) and Q3.F2 (component library).

Also capture during this step (can be inferred or asked directly):
- **`primaryTasks`**: What will the developer mostly do? (feature dev, bug fixes, maintenance, refactoring). Infer from project maturity + type, or ask.
- **`deployFrequency`**: How often will they deploy? (continuous, daily, weekly, manual, none). Ask alongside Q3.4 if deploying.
- **`frontendPatterns`**: If frontend project — component library, state management, styling, routing. Partially captured by Q3.F1/Q3.F2, fill in the rest from stack research.
- **`backendPatterns`**: If backend project — auth (from Q3.3), error handling. Compose from existing answers.

### Step 9.5 of 17: Pain Points (always ask)

Emit the progress indicator. Ask about where Claude can help most:
- "What takes the most time in your development workflow?"
- "What areas of code are most error-prone?"
- "What would you most want automated?"

Capture as:
```json
{
  "painPoints": {
    "timeSinks": "...",
    "errorProne": "...",
    "automationWishes": "..."
  }
}
```

This feeds directly into onboard's skill and agent selection — skills matching pain points get highest priority.

### Step 10 of 17: Workflow Preferences (Category 4)

Emit the progress indicator. Ask Q4.1 through Q4.5. For Q4.1 (branching), recommend based on team size from Q3.1.

Q4.6 (releases) is only asked for production apps.

**Q4.7: Verification strategy** (always ask). Based on the stack research, present the available verification approaches:

> Based on your stack, here are the ways features can be independently verified:
>
> 1. **Browser automation** (Playwright MCP) — for UI features, user flows
> 2. **API testing** (curl/HTTP) — for endpoints, server actions
> 3. **CLI execution** — for command-line tools
> 4. **Test runner** ([detected framework]) — for integration/unit tests
> 5. **Combination** (recommended for fullstack) — adapts per feature type
>
> Which approach works for your project?

Store the choice as `verificationStrategy` in the context object. This configures the feature-evaluator agent.

### Step 11 of 17: CI/CD & Auto-Evolution (Category 5 / cicdAndDelivery)

Emit the progress indicator. **Skip Q5.1, Q5.3, and Q5.4–Q5.17 entirely if `willDeploy = false`** — only Q5.2 (auto-evolution mode) applies to local projects.

This step has two halves: the v1 carryover questions (Q5.1–Q5.3) and the expanded CI/CD & Delivery question set added in greenfield 3.0 Round 1 (Q5.4–Q5.17 — 14 new questions covering CI provider, gates, env ladder, secrets, notifications, build matrix, caching, release pipeline, and deploy cadence).

**Data layout** — the three v1 questions populate flat top-level context fields (`ciAuditAction`, `autoEvolutionMode`, `prReviewTrigger`) for back-compat AND are mirrored into `context.phases.cicdAndDelivery._v1_carryover.*`. The 14 new questions populate `context.phases.cicdAndDelivery.cicd.*` directly. Both forms coexist in greenfield-state.json during Round 1; the v1 flat fields are deprecated and slated for removal in Round 6.

#### v1 carryover (Q5.1–Q5.3)

Ask Q5.1 (audit behavior), Q5.2 (auto-evolution mode), Q5.3 (PR review trigger). On answer, write to both the top-level field AND `context.phases.cicdAndDelivery._v1_carryover.<field>`.

#### CI/CD & Delivery expansion (Q5.4–Q5.17)

Walk these in order. Conditions in the question-bank gate each one — most are `willDeploy`, some additionally require an answer to a prior question (e.g., Q5.7 only fires if Q5.6 selected "Coverage"). Skip silently where the condition is not met.

| Q | Topic | Writes to (under `context.phases.cicdAndDelivery.cicd`) |
|---|---|---|
| Q5.4 | CI provider | `provider` |
| Q5.5 | CI triggers | `triggers[]` |
| Q5.6 | Required pre-merge checks | `requiredPreMergeChecks[]` |
| Q5.7 | Coverage threshold + scope + blocking | `coverage.{threshold,scope,blocking}` |
| Q5.8 | Environment ladder | `envLadder[]` |
| Q5.9 | Auto-deploy strategy | `autoDeploy` |
| Q5.10 | Deploy cadence | `deployCadence` |
| Q5.11 | Rollback strategy + automation | `rollback.{strategy,automation}` |
| Q5.12 | Secret manager + rotation | `secrets.{manager,rotation}` |
| Q5.13 | Notifications channels + events | `notifications.{channels[],events[]}` |
| Q5.14 | Build matrix | `buildMatrix.{os[],languageVersions,parallelization}` |
| Q5.15 | Caching strategy | `caching.{deps,build,dockerLayers,remote}` |
| Q5.16 | CI time budget | `timeBudget.{perPipelineMinutes,blockingThresholdMinutes}` |
| Q5.17 | Release pipeline | `releasePipeline.{separate,triggeredBy,convention}` |

If the developer answers Q5.4 with anything other than `"github-actions"`, capture the value but tell them:

> Heads-up — Round 1 only generates GitHub Actions workflow templates. Your `provider` answer is captured but won't drive workflow generation until Round 6. The synthesis review will flag this.

#### Stale entry-guard for cicdAndDelivery

Before asking Q5.1 (or the first applicable question): if `completedSteps` already contains `"step-11-cicd"` AND `context.phaseStatus.cicdAndDelivery.status === "stale"`, skip re-asking Q5.1–Q5.17 and proceed directly to the synthesis-review call below. Synthesis-review Step 0 will surface the re-walk prompt.

#### Phase 1.8: synthesis review (after Q5.17, or after Q5.1/Q5.2/Q5.3 if `willDeploy = false`)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "cicdAndDelivery"`. This is Round 1's only synthesis pass. The skill:

1. Sets `greenfield-state.json.currentPhase` to `phase-1.8-synthesis-review` and `currentSynthesisPhase: "cicdAndDelivery"`.
2. Renders `<targetProjectRoot>/docs/adr/cicd-and-delivery.html` from the template.
3. Walks the developer through 8 sections of Approve/Adjust/Skip.
4. Writes `context.syntheses.cicdAndDelivery = { approvedAt, adjustments[] }`.
5. Returns control here. Set `currentPhase` back to `phase-1-context-gathering` and `currentStep` to `step-12-feature-decomp`.

If the developer adjusts any cicdAndDelivery field via the Adjust dialog, the updated value is in `context.phases.cicdAndDelivery.cicd.<field>` — the v1 carryover mirrors do NOT update (they preserve the original answer).

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen in Round 1 since `cicd-and-delivery.html` ships in this commit), tell the developer and continue to Step 12.

### Step 12 of 17: Feature Decomposition (Harness Preparation) — REQUIRED

Emit the progress indicator. **This step is mandatory** — downstream phases (tooling generation, onboard's harness mode) depend on a feature list existing. Do NOT skip this silently. If the user explicitly declines feature decomposition, generate a minimal 3-5 feature skeleton from the app description so the JSON file still exists.

Before the confirmation step, decompose the app description into testable features. This feeds the harness design's `feature-list.json`.

1. From `appDescription` and all gathered context, generate a sprint-organized feature list
2. Each feature must be concrete, testable, and have verification steps
3. Sprint 1 is always the minimal viable foundation
4. Scale depth by project type: CLI (5-10 features), web app (15-25), production (30-50)
5. **AI feature weaving**: Look for opportunities to suggest AI-powered capabilities that enhance the app. Examples:
   - Task manager → AI task prioritization, smart categorization
   - E-commerce → AI product recommendations, search enhancement
   - Content app → AI writing assistance, auto-tagging, summarization
   - Dashboard → AI anomaly detection, predictive analytics
   - Social app → AI content moderation, smart feeds
   Present AI features as optional suggestions — the developer decides whether to include them.

Include the feature breakdown in the confirmation summary (see below). The developer can adjust, add, remove, but NOT skip entirely — a skeletal decomposition must exist. If the developer says "skip", generate a minimal 3-5 feature list yourself from the app description, present it as "I generated a starter decomposition you can refine later", and proceed.

**Pre-Phase-1.5 check**: before handing off to Step 13, if `parkedQuestions.length > 0`, inform the user:

> Before we wrap Phase 1, note: you parked **N** questions for deeper research earlier. When we finish the wizard, I'll enter a short "Architectural Research" sub-phase to deep-dive on those before we scaffold. If you'd rather skip that and just go with the placeholder answers, say "skip research" now.

### Step 13 of 17: Confirmation (Category 7)

Emit the progress indicator. Present a structured summary of everything gathered:

> **Here's everything we've discussed:**
>
> **App**: [description]
> **Stack**: [framework(s) + version(s)]
> **Scaffold**: [method — CLI / from-scratch / template]
> **Database**: [type or none]
> **Auth**: [strategy or none]
> **Deploy**: [target or local-only]
> **Team**: [size]
> **Branching**: [strategy]
> **Testing**: [philosophy]
> **Style**: [strictness]
> **Security**: [sensitivity]
> **CI/CD**: [audit behavior + PR review trigger] (or "N/A — local project")
> **Auto-evolution**: [mode]
>
> **Initial Feature Breakdown** ([N] features across [N] sprints):
> Sprint 1 — [name]: [feature list summary]
> Sprint 2 — [name]: [feature list summary]
> ...
>
> Ready to scaffold? Or want to adjust the features/settings?
>
> **Next**: After confirmation, I'll [if `parkedQuestions.length > 0`: run Phase 1.5 architectural research, then] run Phase 1.7 pre-scaffold validation (a quick ~5-min grill that catches contradictions before scaffolding). You can opt out at the gate if your spec already feels solid.

Wait for confirmation before returning.

### Step 14 of 17: Phase 1.5 Architectural Research (conditional)

Emit the progress indicator **only if** `parkedQuestions.length > 0` AND the user didn't say "skip research". Otherwise skip Step 14 and go straight to Step 15.

This is a dedicated sub-phase for deep research on questions parked during the wizard. The goal is to produce informed answers for parkedQuestions BEFORE scaffolding begins, so downstream phases aren't building on placeholder assumptions.

For each parked question:

1. State the question and the placeholder answer from the wizard
2. Run the research — use `stack-researcher` agent if it's a tech-stack question; use main-session WebSearch/WebFetch for architectural questions; use both if needed
3. Report findings to the user with sources
4. Confirm the final answer (user can accept your research, override with a different decision, or defer even further)
5. Update `context` with the final answer
6. Save to `researchFindings.parkedResearch[questionId]` in `greenfield-state.json`
7. Remove the question from `parkedQuestions[]`

Checkpoint after each parked question is resolved. This keeps the research phase resumable too.

**Research scope guardrails** to prevent derailment:
- Time-box each parked question to ~20 minutes of research
- If research hits its time box without a clear answer, present what was found and let the user decide
- Don't spawn new parked questions during architectural research — flag them for post-Phase-1.5 decisions instead

When all parked questions are resolved, proceed to Step 15: Architectural Validation.

### Step 15 of 17: Architectural Validation

Emit the progress indicator. This is the final wizard step — a cross-phase sign-off pass that reads from all approved phase syntheses to detect contradictions and drift since they were captured.

**Purpose**: Step 2.5 (Architectural Framing) captured early architectural assumptions. By the time we reach Step 15, the developer has answered ~73 wizard questions across Data Architecture, API & Integration, CI/CD, and all residual phases. This step checks whether the final approved values are still consistent with the framing decisions and with each other.

**Run condition**: always — even if no parked questions existed (this is not conditional like Step 14). Step 15 runs after Step 14 completes (or is skipped if no parked questions).

Tell the developer:

> Step 15 of 17: Architectural Validation. Before we scaffold, I'll cross-check all your approved synthesis records for contradictions and drift since your early framing decisions. This is a sign-off step — you'll review what was found and either approve the full spec, note divergences, or send it back for rework.

**Cross-validation checks to perform** (read from `context.syntheses.*` and `context.phases.*`):

1. **Framing → Data Architecture**: does `architecturalFraming.topology` still hold given `dataArchitecture.databaseHost`, `.orm`, `.migrationsTool`? (e.g., serverless + orm-native migrations contradict; microservices + embedded DB contradict)
2. **Framing → API & Integration**: does `architecturalFraming.topology` hold given `apiIntegration.asyncPattern`? (serverless + queue-and-worker contradict)
3. **Framing → CI/CD**: does `architecturalFraming.scaleTarget` align with `cicdAndDelivery.cicd.envLadder` and `releasePipeline.convention`? (hobby + full release pipeline is unusual)
4. **Data ↔ API**: does `dataArchitecture.cache` include a broker if `apiIntegration.asyncPattern === "queue-and-worker"`?
5. **Any synthesis unapproved**: if any major phase synthesis was skipped entirely (not Approve/Adjust/Skip-per-section but the entire synthesis-review was bypassed), note it here.

**Ask AV.Q1** (from `references/question-bank.md § Step 11: Architectural Validation`):

> After reviewing the cross-phase validation findings above, what is your sign-off status?

Options:
- "Approved — everything looks consistent" → `signOffStatus: "approved"`
- "Approved with noted divergences — proceed with caution notes" → `signOffStatus: "approved-with-noted-divergences"` (triggers AV.Q2)
- "Requires rework — send back to address contradictions" → `signOffStatus: "requires-rework"` (routes back to the relevant wizard step via `/greenfield:pickup`)

**AV.Q2** (conditional — only if `signOffStatus` is `"approved-with-noted-divergences"` or `"requires-rework"`):

> What's the final note for future maintainers about the divergences or rework needed?

Capture as `context.phases.architecturalValidation.finalNotes` (free text).

**On `requires-rework`**: set `currentPhase: "phase-1-context-gathering"`, add the rework scope to `parkedQuestions[]`, write checkpoint, and offer `/greenfield:pickup` for the relevant step. Do NOT proceed to Output.

**On `approved` or `approved-with-noted-divergences`**: invoke the `synthesis-review` skill via the Skill tool with `phaseId: "architecturalValidation"`. The skill:

1. Sets `currentSynthesisPhase: "architecturalValidation"`.
2. Renders `docs/adr/architectural-validation.html` using the validation template.
3. Records `context.syntheses.architecturalValidation = { approvedAt, adjustments[] }`.
4. Returns control here.

Then set `currentPhase: "phase-2-scaffold"` in the state file and hand off to the scaffolding skill.

## Auto-loop mechanic

For each Q-bank entry Q being asked during state-machine traversal:

1. **If Q lacks `loopOver`:** fire Q once (static). Move to next Q.
2. **If Q has `loopOver`** (valid values: `personas.primary`, `personas.secondary`, `domainModel.entities`):
   - Read `mode.coupling` from `.claude/greenfield-state.json.mode.coupling`.
   - **If `mode.coupling == "auto-loop"`:** fire Q once per item in the source collection. Set the iteration context variable (`{{persona}}` or `{{entity}}`) to the current item.
   - **If `mode.coupling == "hybrid"`:**
     - If `Q.loopMode == "always"`: fire Q once per item (still loops in hybrid mode).
     - Else (`Q.loopMode == "hybrid-only"` or omitted): fire Q ONCE as a static prompt; user types free-form. Use the Q's "Prompt (hybrid fallback)" template if the Q provides one (security.q-bank.md and runtime-operations.q-bank.md both define hybrid-fallback prompts for their hybrid-only loops).
3. **For each looped fire**, render `Q.promptTemplate` with `{{persona.id}}` / `{{entity.id}}` etc. substituted from the iteration context.
4. **For each looped answer**, write a `derivedFrom` field to the synthesis output AND a `sourceRef: { phase, id }` field to the dependencies.json sidecar (synthesis-review consumes this; T19 wires the rendering).

### Loop progress indicator

When firing a looped Q, render the wizard header:

```
─────────────────────────────────────────
  Step 5 — Auth         [Persona 1 of 2]
─────────────────────────────────────────
```

After every loop iteration completes, the state machine checkpoints state (`.claude/greenfield-state.json`) so `/greenfield:pickup` can resume mid-loop precisely.

### Loop hard-cap

If a single phase's loop iteration count > 200 Qs (e.g., 5 personas × 6 entities × 8 looped Qs = 240), the wizard surfaces a soft warning: *"You may have too many personas/entities — consider consolidating before continuing."* and logs `degradation: { phase, reason: "loop-cap-exceeded", count: <n> }` to the state file. The user can opt to continue or run `/greenfield:pickup → Adjust mode → consolidate`.

## Render hooks

The state machine pre-computes derived scalars before passing context to synthesis-review:

| Hook | Source path | Derived path | Transformation |
|---|---|---|---|
| persona-device-label | `personas.primary[].context.device[]` (array) | `personas.primary[].context.deviceLabel` (scalar) | Comma-joined (e.g., `["phone", "tablet"]` → `"phone, tablet"`) |
| anti-personas-aggregate | `personas.primary[].antiPersona` (per-persona) | `personas.antiPersonas[]` (top-level array) | Collect non-empty values, de-duplicate, preserve order |
| risks-by-status | `risks[]` | `risks.byStatus.{mitigated,partial,acceptedExplicit,openFollowup,outOfScope}[]` + `.length` per bucket | Group by `risk.reconciliation.status`; used by `arch-val-risk-reconciliation-section.html` (T15) |
| risks-distinct-phase-count | `risks[]` | `risks.distinctPhaseCount` (scalar) | Count of distinct `risk.originatingPhase` values |

Synthesis-review reads from the derived paths first, falls back to source paths if a derived value isn't present (e.g., for legacy alpha.4 contexts after migration shim).

## Output

**Sanitisation downstream** — free-text fields captured here (`appDescription`, `painPoints.timeSinks`, `painPoints.errorProne`, `painPoints.automationWishes`, and any future free-text wizard field) are sanitised by `greenfield/skills/tooling-generation/SKILL.md § Sanitise free-text wizard answers` before dispatch to `/onboard:generate`. The sanitiser applies a 5000-character length cap and strips `\r` — defence-in-depth pairing with the `<untrusted-user-input>` framing that `onboard/skills/generate/SKILL.md § Validate` wraps around the values at agent-prompt build time. Context-gathering itself stores raw answers verbatim; do not pre-sanitise here.

After the wizard completes, compile all answers into a structured context object:

```json
{
  "appDescription": "string",
  "appType": "string",
  "stack": {
    "framework": "string",
    "version": "string",
    "language": "string",
    "additional": []
  },
  "scaffoldMethod": "cli | from-scratch | template",
  "scaffoldCLI": "string (if cli method)",
  "scaffoldFlags": "string (if cli method)",
  "database": { "type": "string", "orm": "string" },
  "auth": { "strategy": "string", "provider": "string" },
  "deployTarget": "string",
  "deployFrequency": "continuous | daily | weekly | manual | none",
  "teamSize": "string",
  "primaryTasks": ["feature-dev", "bug-fixes", "maintenance", "refactoring"],
  "branchingStrategy": "string",
  "testingPhilosophy": "string",
  "codeStyleStrictness": "string",
  "securitySensitivity": "string",
  "autonomyLevel": "string",
  "painPoints": {
    "timeSinks": "string",
    "errorProne": "string",
    "automationWishes": "string"
  },
  "frontendPatterns": {
    "componentLibrary": "string",
    "stateManagement": "string",
    "styling": "string",
    "routing": "string"
  },
  "backendPatterns": {
    "apiStyle": "string",
    "orm": "string",
    "auth": "string",
    "errorHandling": "string"
  },
  "monitoring": [],
  "apiStyle": "string",
  "apiDocs": "string",
  "envStrategy": "string",
  "dockerStrategy": "string",
  "depManagement": "string",
  "a11yLevel": "string",
  "perfTargets": "string",
  "i18n": "string",
  "isMonorepo": false,
  "monorepoPackages": [],
  "codegenTools": [],
  "storageStrategy": "string",
  "backgroundJobs": "string",
  "stylingApproach": "string",
  "componentLibrary": "string",
  "releaseStrategy": "string",
  "ciAuditAction": "string",
  "autoEvolutionMode": "string",
  "prReviewTrigger": "string",
  "phases": {
    "architecturalFraming": {
      "topology": "monolith | modular-monolith | microservices | serverless",
      "deploymentShape": "single-region | multi-region | edge-distributed | on-prem",
      "scaleTarget": "hobby | startup | production-scale | enterprise",
      "boundaryNotes": "optional free-text"
    },
    "dataArchitecture": {
      "databaseHost": "managed-rdbms",
      "orm": "prisma",
      "migrationsTool": "orm-native",
      "multiTenancy": "none",
      "engine": "postgresql",
      "cache": "redis",
      "fileStorage": "cloud-s3-like",
      "codegen": ["prisma-generate"]
    },
    "apiIntegration": {
      "style": "rest",
      "versioningPolicy": "url-path",
      "asyncPattern": "queue-and-worker",
      "documentation": "openapi-swagger",
      "rateLimit": "fixed-window-redis"
    },
    "architecturalValidation": {
      "signOffStatus": "approved | approved-with-noted-divergences | requires-rework",
      "divergences": [],
      "unresolvedContradictions": [],
      "finalNotes": ""
    },
    "cicdAndDelivery": {
      "cicd": {
        "provider": "github-actions | gitlab-ci | circleci | buildkite | jenkins | none",
        "triggers": ["push-to-main", "every-pr", "scheduled", "manual", "tag"],
        "requiredPreMergeChecks": ["lint", "typecheck", "unit", "integration", "e2e", "security-scan", "coverage", "build"],
        "coverage": { "threshold": "number | null", "scope": "global | per-package | per-file", "blocking": "boolean" },
        "envLadder": ["dev", "staging", "preview", "prod"],
        "autoDeploy": "auto-on-merge | manual-button | scheduled | tag-triggered | none",
        "deployCadence": "continuous | daily | weekly | manual | none",
        "rollback": { "strategy": "redeploy-previous-sha | blue-green | canary | none", "automation": "boolean" },
        "secrets": { "manager": "provider-stored | oidc-to-cloud | vault | 1password | doppler | manual", "rotation": "manual | scheduled | on-incident" },
        "notifications": { "channels": ["slack", "discord", "email", "github-checks"], "events": ["build-failure", "deploy-success", "deploy-failure", "security-alert"] },
        "buildMatrix": { "os": ["ubuntu-latest"], "languageVersions": "single | multi", "parallelization": "auto | off | number" },
        "caching": { "deps": "boolean", "build": "boolean", "dockerLayers": "boolean", "remote": "turbo | buildkite | none" },
        "timeBudget": { "perPipelineMinutes": "number", "blockingThresholdMinutes": "number | null" },
        "releasePipeline": { "separate": "boolean", "triggeredBy": "tag | manual | schedule", "convention": "release-please | semantic-release | manual | none" }
      },
      "_v1_carryover": {
        "ciAuditAction": "string (mirror of top-level)",
        "autoEvolutionMode": "string (mirror of top-level)",
        "prReviewTrigger": "string (mirror of top-level)"
      }
    }
  },
  "syntheses": {
    "architecturalFraming": { "approvedAt": "ISO-8601", "adjustments": [] },
    "dataArchitecture": { "approvedAt": "ISO-8601", "adjustments": [] },
    "apiIntegration": { "approvedAt": "ISO-8601", "adjustments": [] },
    "cicdAndDelivery": { "approvedAt": "ISO-8601", "adjustments": [] },
    "architecturalValidation": { "approvedAt": "ISO-8601", "adjustments": [] }
  },
  "verificationStrategy": "browser-automation | api-testing | cli-execution | test-runner | combination",
  "pluginsToInstall": [],
  "featureDecomposition": {
    "sprints": [],
    "validated": "boolean — whether developer validated the decomposition"
  },
  "webResearch": {},
  "defaultsAccepted": {
    "AF.Q1": "boolean — true if developer pressed Enter; false if they typed an override",
    "P3.Q1": "boolean",
    "...": "one entry per non-skip-with-Enter question"
  }
}
```

Fields that were skipped are set to `null` or omitted.

## Checkpoint Protocol (for resume support)

This skill MUST write `.claude/greenfield-state.json` after each Step so that `/greenfield:pickup` can pick up mid-wizard if the session is interrupted. See `skills/start/SKILL.md` for the full state schema.

### When to checkpoint
Write a checkpoint **after each named Step completes** (not after each individual question within a step):

| After Step | Write to state file |
|---|---|
| Step 1 complete (Project Vision) | `completedSteps: ["step-1-vision"]`, `currentStep: "step-2-stack"`, `context.appDescription`, `context.appType` |
| Step 2 complete (Tech Stack) | Add `"step-2-stack"`, `currentStep: "step-2.5-architectural-framing"`, `context.stack`, `researchFindings`, `research.mode` |
| Step 2.5 — AF.Q1 answered | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-2.5-architectural-framing"`, `lastAnsweredQuestionId: "AF.Q1"` |
| Step 2.5 — AF.Q4 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "architecturalFraming"`, add `"step-2.5-architectural-framing"` to `completedSteps` |
| Step 2.5 — synthesis-review(architecturalFraming) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`, clear `currentSynthesisPhase`. Add `context.syntheses.architecturalFraming = { approvedAt, adjustments }` |
| Step 3 — P3.Q1 answered | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`, `lastAnsweredQuestionId: "P3.Q1"` |
| Step 3 — P3.Q12 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "dataArchitecture"`, add `"step-3-data-architecture"` to `completedSteps` |
| Step 3 — synthesis-review(dataArchitecture) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-4-api-integration"`, clear `currentSynthesisPhase`. Add `context.syntheses.dataArchitecture = { approvedAt, adjustments }` |
| Step 4 — P4.Q1 answered | Set `currentStep: "step-4-api-integration"`, `lastAnsweredQuestionId: "P4.Q1"` |
| Step 4 — P4.Q10 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "apiIntegration"`, add `"step-4-api-integration"` to `completedSteps` |
| Step 4 — synthesis-review(apiIntegration) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-5-auth"`, clear `currentSynthesisPhase`. Add `context.syntheses.apiIntegration` |
| step-5-auth | step-5-auth → phase-1.8-synthesis-review (currentSynthesisPhase: "auth") → step-6-privacy |
| step-6-privacy (preceded by Privacy.Gate if auth.strategy='none') | step-6-privacy → phase-1.8-synthesis-review (currentSynthesisPhase: "privacy", uses n/a stub if synthesisStatus='n/a') → step-7-security |
| step-7-security | step-7-security → phase-1.8-synthesis-review (currentSynthesisPhase: "security") → step-8-runtime-ops |
| step-8-runtime-ops | step-8-runtime-ops → phase-1.8-synthesis-review (currentSynthesisPhase: "runtimeOperations") → step-9-residual (was step-9-residual) |
| Step 9 — last residual Q answered | Add `"step-9-residual"` to `completedSteps`, set `currentStep: "step-10-workflow"` |
| Step 10 complete (Workflow Preferences) | Add `"step-10-workflow"`, `currentStep: "step-11-cicd"`, all category-4 context fields |
| Step 11 — Q5.1–Q5.17 answered | Add `"step-11-cicd"`, set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "cicdAndDelivery"`, all CI/CD fields under both top-level (Q5.1–Q5.3) AND `context.phases.cicdAndDelivery.cicd` / `context.phases.cicdAndDelivery._v1_carryover` |
| Step 11 — synthesis-review(cicdAndDelivery) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-12-feature-decomp"`, clear `currentSynthesisPhase`. Add `context.syntheses.cicdAndDelivery = { approvedAt, adjustments }` |
| Step 12 complete (Feature Decomposition) | Add `"step-12-feature-decomp"`, `currentStep: "step-13-confirmation"`, `context.featureDecomposition` |
| Step 13 complete (Confirmation) | Add `"step-13-confirmation"`, `currentPhase: "phase-1.5-architectural-research"` (if `parkedQuestions.length > 0`) OR `"phase-1-context-gathering"` `currentStep: "step-15-arch-validation"`, then after Step 15 proceed to `"phase-1.7-grill-spec"` |
| Step 14 complete (Phase 1.5 Research, conditional) | Add `"step-14-arch-research"` (only if parked questions were present), `currentStep: "step-15-arch-validation"` |
| Step 15 — AV.Q1 answered | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-15-arch-validation"`, `lastAnsweredQuestionId: "AV.Q1"` |
| Step 15 — synthesis-review(architecturalValidation) returns | Add `"step-15-arch-validation"` to `completedSteps`, set `currentPhase: "phase-1.7-grill-spec"`, `currentStep: "pre-grill"`, clear `currentSynthesisPhase`. Add `context.syntheses.architecturalValidation = { approvedAt, adjustments }` |

### Atomic write
Always write to `.claude/greenfield-state.json.tmp` first, then `mv` to `.claude/greenfield-state.json`. This avoids corrupted state if the session is killed mid-write. If the tmp file exists from a prior interrupted write, remove it before starting.

### Resume entry contract
When this skill is invoked via `/greenfield:pickup`, it receives a `completedSteps` list. At the start of the flow, check this list and **skip any Step whose identifier is already in `completedSteps`**. Never re-ask questions whose answers are already in the `context` object.

### First write (new sessions)
On the very first checkpoint of a new session, also populate:
- `version: 1`
- `createdAt: <now>`
- `updatedAt: <now>`
- `currentPhase: "phase-1-context-gathering"`
- `research.mode: "agent"` (defaults; updated later if fallback triggers)

## Key Rules

1. **One question per message** — Do not overwhelm with multiple questions.
2. **Research before scaffold decisions** — Never recommend a scaffold approach without web research.
3. **Respect skips** — If the developer says "skip" or "not now", use neutral defaults and move on.
4. **Adaptive, not rigid** — The question order is a guide, not a script. If the developer volunteers information, capture it and skip the corresponding question.
5. **Never ask what you already know** — If Q1.1 reveals the stack, don't re-ask in Q2.
6. **Recommend with reasoning** — Always explain why you suggest something, referencing research when available.
7. **Checkpoint after every Step** — Always write `greenfield-state.json` at Step boundaries so resume works.
