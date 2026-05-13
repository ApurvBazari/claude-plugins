---
name: context-gathering
description: Greenfield Phase 1 — adaptive wizard that gathers project vision, tech stack, features, and preferences through 10 named Steps. Internal building block invoked by greenfield init — not user-invocable.
user-invocable: false
---

# Context Gathering Skill — Adaptive Project Wizard

You are guiding a developer through an interactive wizard to understand what they want to build, their tech stack preferences, workflow, and project requirements. This is Phase 1 of the Greenfield plugin.

## Purpose

Gather all context needed to scaffold a project and generate AI tooling. Every decision for Phase 2 (scaffolding) and Phase 3 (AI tooling) flows from the answers collected here.

## Conversation Style

- **Conversational, not interrogative** — This is a dialogue, not a survey. Acknowledge answers, connect them to prior context, and be helpful.
- **One question at a time** — Ask a single question per message. If a topic needs exploration, break it into follow-ups.
- **Recommend, don't just list** — When presenting options, lead with your recommendation and explain why.
- **Skip intelligently** — Never ask a question whose answer is already clear from prior context.
- **Research-informed** — After learning the stack, pause for web research before continuing. Use findings to inform subsequent questions and recommendations.

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
  "hasAPI": false
}
```

Update this after every answer. Before asking each question, check its condition in the question bank. If the condition is not met, skip silently.

## Progress Indicator Protocol

At the start of every Step (and whenever the user asks "where are we?"), emit a one-line progress indicator so both Claude and the user can see wizard progress:

> **Wizard progress: Step [X] of 10 — [step name]**
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

### Step 1 of 10: Project Vision (Category 1)

Emit the progress indicator. Then start with Q1.1: "What do you want to build?"

Listen carefully. From the answer, infer:
- `appType` (web-app, api, cli, library, fullstack, mobile-backend)
- `hasFrontend`, `hasBackend`, `hasAPI`
- Whether follow-up Q1.2 is needed (if the answer is vague)

### Step 2 of 10: Tech Stack (Category 2)

Emit the progress indicator. Ask Q2.1 about their stack preference. If they know, ask Q2.2 for details.

**Research pause**: After gathering the stack, dispatch the `stack-researcher` agent with a clear research brief. The agent's first action is a real npm-registry call (zero overhead when web works) — if that fails, the agent immediately returns the sentinel `STACK_RESEARCH_REQUIRES_MAIN_SESSION` (see `greenfield/agents/stack-researcher.md` § Sentinel and `greenfield/skills/init/references/stack-research-checklist.md` § 0 / § Output).

**Handling the two possible agent outcomes**:

#### Outcome A — Agent returns a full research report
Proceed normally. Present findings naturally: *"I looked into [framework] — the current stable version is [X]. The official scaffold CLI `[command]` now supports [features]. I'd recommend using that."*

#### Outcome B — Agent returns the sentinel (sub-agent web access denied)

Detect by greping the agent's response for the literal string `STACK_RESEARCH_REQUIRES_MAIN_SESSION`. Do NOT silently fail; do NOT re-dispatch the agent (that would loop). Instead, **fall back to main-session research using the shared checklist**:

1. Tell the user what happened, concisely:
   > "The background research agent doesn't have web access in this session. I'll run the same research checklist in our main conversation so you can see and approve each web call."

2. Read `greenfield/skills/init/references/stack-research-checklist.md` and run sections 1-7 inline using main-session `WebSearch` and `WebFetch`. Per-call permission prompts will appear to the user; ask them to approve so research can proceed. The checklist is the single source of truth shared with the agent — following it inline produces the same report shape.

3. If the user denies web access entirely, offer a degraded path:
   > "Without web research, I'll use my training data to make stack recommendations, but please verify versions and scaffold CLIs manually before we proceed with scaffolding — my knowledge may be months out of date."

4. Checkpoint the fallback mode in `greenfield-state.json` under `research.mode = "main-session" | "training-data-only"` so downstream skills know the research provenance.

5. **Hard-failure path**: if main-session retries also fail (network down, all per-call permissions denied), surface a clear error to the user — do NOT silently proceed with empty research. Greenfield's downstream phases need at least the basic stack metadata.

Wait for research results (either via agent or main session). Then ask Q2.3 about the scaffold approach, informed by the research findings.

### Step 3 of 10: Data Architecture (Phase P3)

This step is Round 2's first new phase. Captures data-layer decisions via P3.Q1–Q3.12 and closes with an inline Phase 1.8 synthesis-review pass.

**Data layout** — answers populate `context.phases.P3.*` directly (no v1 carryover). The 4 required enum-locked fields are `databaseHost`, `orm`, `migrationsTool`, `multiTenancy`; remaining fields are loose strings.

Tell the developer:

> Step 3 of 10: Data Architecture. I'll ask about your data layer — database engine, ORM, migrations, multi-tenancy, caching, file storage. About 12 questions. Some may be skipped based on your earlier answers.

#### P3 questions (Q3.1–Q3.12)

Ask each P3 question from `references/question-bank.md § Phase P3` in order. Honor the conditions. Write each answer to its destination field under `context.phases.P3`.

| Q | Topic | Writes to (under `context.phases.P3`) |
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

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "P3"`. This is Round 2's first synthesis pass. The skill:

1. Sets `greenfield-state.json.currentPhase` to `phase-1.8-synthesis-review` and `currentSynthesisPhase: "P3"`.
2. Renders `docs/architecture/p3-data.html` in the scaffolded project using the 7-section template.
3. Walks the developer through Approve/Adjust/Skip per section.
4. Writes `context.syntheses.P3 = { approvedAt, adjustments[] }`.
5. Writes `docs/architecture/p3-data-dependencies.json` from the wizard-collected dependency edges.

If the developer adjusts any P3 field via the Adjust dialog, the updated value lives in `context.phases.P3.<field>` directly.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `p3-data.html` ships in Round 2), tell the developer and continue to Step 4.

### Step 4 of 10: API & Integration (Phase P4)

This step is Round 2's second new phase. Captures API surface decisions via P4.Q1–Q4.10 and closes with an inline Phase 1.8 synthesis-review pass.

**Data layout** — answers populate `context.phases.P4.*` directly. The 3 required enum-locked fields are `style`, `versioningPolicy`, `asyncPattern`; remaining fields are loose strings or arrays.

Tell the developer:

> Step 4 of 10: API & Integration. I'll ask about your API surface — style (REST/GraphQL/tRPC), versioning, rate limits, async patterns, real-time, webhooks, external services. About 10 questions; some skipped based on whether you expose an API.

#### P4 questions (Q4.1–Q4.10)

Ask each P4 question from `references/question-bank.md § Phase P4` in order. Honor the conditions.

| Q | Topic | Writes to (under `context.phases.P4`) |
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

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "P4"`. The skill:

1. Sets `currentSynthesisPhase: "P4"`.
2. Renders `docs/architecture/p4-api.html` using the 6-section template.
3. Walks Approve/Adjust/Skip per section.
4. Writes `context.syntheses.P4 = { approvedAt, adjustments[] }`.
5. Writes `docs/architecture/p4-api-dependencies.json`.

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen — `p4-api.html` ships in Round 2), tell the developer and continue to Step 5.

### Step 5 of 10: Remaining Project Details (residual)

This step holds the 13 Category 3 questions that have NOT been re-homed to P3 (Data) or P4 (API) in Round 2. They stay here as transitional content until Rounds 3–6 re-home them to P0/P5/P6/P7. See `references/question-bank.md § Category 3 (residual)` for the full question list.

Tell the developer:

> Step 5 of 10: Remaining Project Details. A few miscellaneous questions about scale, auth, deploy target, monitoring, environment, dependencies, accessibility, performance, i18n, monorepo, and styling. Skipped if not relevant to your stack.

Ask Q3.1, Q3.3, Q3.4, Q3.6, Q3.9, Q3.10, Q3.11, Q3.12, Q3.13, Q3.14, Q3.15, Q3.F1, Q3.F2 in order from `references/question-bank.md § Category 3 (residual)`. Honor existing conditions. No synthesis review for this step (it's residual; full split planned for Rounds 3–6).

State checkpoint: `currentStep: "step-5-residual"`.

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

### Step 5.5 of 10: Pain Points (always ask)

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

### Step 6 of 10: Workflow Preferences (Category 4)

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

### Step 7 of 10: CI/CD & Auto-Evolution (Category 5 / P8)

Emit the progress indicator. **Skip Q5.1, Q5.3, and Q5.4–Q5.17 entirely if `willDeploy = false`** — only Q5.2 (auto-evolution mode) applies to local projects.

This step has two halves: the v1 carryover questions (Q5.1–Q5.3) and the expanded P8 question set added in greenfield 3.0 Round 1 (Q5.4–Q5.17 — 14 new questions covering CI provider, gates, env ladder, secrets, notifications, build matrix, caching, release pipeline, and deploy cadence).

**Data layout** — the three v1 questions populate flat top-level context fields (`ciAuditAction`, `autoEvolutionMode`, `prReviewTrigger`) for back-compat AND are mirrored into `context.phases.P8._v1_carryover.*`. The 14 new questions populate `context.phases.P8.cicd.*` directly. Both forms coexist in greenfield-state.json during Round 1; the v1 flat fields are deprecated and slated for removal in Round 6.

#### v1 carryover (Q5.1–Q5.3)

Ask Q5.1 (audit behavior), Q5.2 (auto-evolution mode), Q5.3 (PR review trigger). On answer, write to both the top-level field AND `context.phases.P8._v1_carryover.<field>`.

#### P8 expansion (Q5.4–Q5.17)

Walk these in order. Conditions in the question-bank gate each one — most are `willDeploy`, some additionally require an answer to a prior question (e.g., Q5.7 only fires if Q5.6 selected "Coverage"). Skip silently where the condition is not met.

| Q | Topic | Writes to (under `context.phases.P8.cicd`) |
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

#### Phase 1.8: synthesis review (after Q5.17, or after Q5.1/Q5.2/Q5.3 if `willDeploy = false`)

Invoke the `synthesis-review` skill via the Skill tool with `phaseId: "P8"`. This is Round 1's only synthesis pass. The skill:

1. Sets `greenfield-state.json.currentPhase` to `phase-1.8-synthesis-review` and `currentSynthesisPhase: "P8"`.
2. Renders `<targetProjectRoot>/docs/architecture/p8-cicd.html` from the template.
3. Walks the developer through 8 sections of Approve/Adjust/Skip.
4. Writes `context.syntheses.P8 = { approvedAt, adjustments[] }`.
5. Returns control here. Set `currentPhase` back to `phase-1-context-gathering` and `currentStep` to `step-6-feature-decomp`.

If the developer adjusts any P8 field via the Adjust dialog, the updated value is in `context.phases.P8.cicd.<field>` — the v1 carryover mirrors do NOT update (they preserve the original answer).

If the synthesis-review skill returns `synthesisStatus: "no-template"` (should not happen in Round 1 since `p8-cicd.html` ships in this commit), tell the developer and continue to Step 6.

### Step 8 of 10: Feature Decomposition (Harness Preparation) — REQUIRED

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

**Pre-Phase-1.5 check**: before handing off to Step 7, if `parkedQuestions.length > 0`, inform the user:

> Before we wrap Phase 1, note: you parked **N** questions for deeper research earlier. When we finish the wizard, I'll enter a short "Architectural Research" sub-phase to deep-dive on those before we scaffold. If you'd rather skip that and just go with the placeholder answers, say "skip research" now.

### Step 9 of 10: Confirmation (Category 7)

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

### Step 10 of 10: Phase 1.5 Architectural Research (conditional)

Emit the progress indicator **only if** `parkedQuestions.length > 0` AND the user didn't say "skip research". Otherwise skip Step 8 and go straight to Output.

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

When all parked questions are resolved, set `currentPhase: "phase-2-scaffold"` in the state file and hand off to the scaffolding skill.

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
    "P8": {
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
    "P8": { "approvedAt": "ISO-8601", "adjustments": [] }
  },
  "verificationStrategy": "browser-automation | api-testing | cli-execution | test-runner | combination",
  "pluginsToInstall": [],
  "featureDecomposition": {
    "sprints": [],
    "validated": "boolean — whether developer validated the decomposition"
  },
  "webResearch": {}
}
```

Fields that were skipped are set to `null` or omitted.

## Checkpoint Protocol (for resume support)

This skill MUST write `.claude/greenfield-state.json` after each Step so that `/greenfield:resume` can pick up mid-wizard if the session is interrupted. See `skills/init/SKILL.md` for the full state schema.

### When to checkpoint
Write a checkpoint **after each named Step completes** (not after each individual question within a step):

| After Step | Write to state file |
|---|---|
| Step 1 complete (Project Vision) | `completedSteps: ["step-1-vision"]`, `currentStep: "step-2-stack"`, `context.appDescription`, `context.appType` |
| Step 2 complete (Tech Stack) | Add `"step-2-stack"`, `currentStep: "step-3-details"`, `context.stack`, `researchFindings`, `research.mode` |
| Step 3 complete (Project Details) | Add `"step-3-details"`, `currentStep: "step-3.5-pain-points"`, all category-3 context fields |
| Step 3.5 complete (Pain Points) | Add `"step-3.5-pain-points"`, `currentStep: "step-4-workflow"`, `context.painPoints` |
| Step 3 — P3.Q1 answered | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-3-data-architecture"`, `lastAnsweredQuestionId: "P3.Q1"` |
| Step 3 — P3.Q12 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "P3"`, add `"step-3-data-architecture"` to `completedSteps` |
| Step 3 — synthesis-review(P3) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-4-api-integration"`, clear `currentSynthesisPhase`. Add `context.syntheses.P3 = { approvedAt, adjustments }` |
| Step 4 — P4.Q1 answered | Set `currentStep: "step-4-api-integration"`, `lastAnsweredQuestionId: "P4.Q1"` |
| Step 4 — P4.Q10 answered (or last applicable) | Set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "P4"`, add `"step-4-api-integration"` to `completedSteps` |
| Step 4 — synthesis-review(P4) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-5-residual"`, clear `currentSynthesisPhase`. Add `context.syntheses.P4` |
| Step 5 — last residual Q answered | Add `"step-5-residual"` to `completedSteps`, set `currentStep: "step-6-workflow"` |
| Step 6 complete (Workflow Preferences) | Add `"step-6-workflow"`, `currentStep: "step-7-cicd"`, all category-4 context fields |
| Step 7 — Q5.1–Q5.17 answered | Add `"step-7-cicd"`, set `currentPhase: "phase-1.8-synthesis-review"`, `currentSynthesisPhase: "P8"`, all CI/CD fields under both top-level (Q5.1–Q5.3) AND `context.phases.P8.cicd` / `context.phases.P8._v1_carryover` |
| Step 7 — synthesis-review(P8) returns | Set `currentPhase: "phase-1-context-gathering"`, `currentStep: "step-8-feature-decomp"`, clear `currentSynthesisPhase`. Add `context.syntheses.P8 = { approvedAt, adjustments }` |
| Step 8 complete (Feature Decomposition) | Add `"step-8-feature-decomp"`, `currentStep: "step-9-confirmation"`, `context.featureDecomposition` |
| Step 9 complete (Confirmation) | Add `"step-9-confirmation"`, `currentPhase: "phase-1.7-grill-spec"` (or `"phase-1.5-architectural-research"` if `parkedQuestions.length > 0`), `currentStep: "pre-grill"` (handoff to grill-spec skill, which then hands off to scaffolding) |

### Atomic write
Always write to `.claude/greenfield-state.json.tmp` first, then `mv` to `.claude/greenfield-state.json`. This avoids corrupted state if the session is killed mid-write. If the tmp file exists from a prior interrupted write, remove it before starting.

### Resume entry contract
When this skill is invoked via `/greenfield:resume`, it receives a `completedSteps` list. At the start of the flow, check this list and **skip any Step whose identifier is already in `completedSteps`**. Never re-ask questions whose answers are already in the `context` object.

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
