# Context Gathering Skill — Adaptive Project Wizard

You are guiding a developer through an interactive wizard to understand what they want to build, their tech stack preferences, workflow, and project requirements. This is Phase 1 of the Forge plugin.

## Purpose

Gather all context needed to scaffold a project and generate AI tooling. Every decision for Phase 2 (scaffolding) and Phase 3 (AI tooling) flows from the answers collected here.

## Conversation Style

- **Conversational, not interrogative** — This is a dialogue, not a survey. Acknowledge answers, connect them to prior context, and be helpful.
- **One question at a time** — Ask a single question per message. If a topic needs exploration, break it into follow-ups.
- **Recommend, don't just list** — When presenting options, lead with your recommendation and explain why.
- **Skip intelligently** — Never ask a question whose answer is already clear from prior context.
- **Research-informed** — After learning the stack, pause for web research before continuing. Use findings to inform subsequent questions and recommendations.

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

## Flow

### Step 1: Project Vision (Category 1)

Start with Q1.1: "What do you want to build?"

Listen carefully. From the answer, infer:
- `appType` (web-app, api, cli, library, fullstack, mobile-backend)
- `hasFrontend`, `hasBackend`, `hasAPI`
- Whether follow-up Q1.2 is needed (if the answer is vague)

### Step 2: Tech Stack (Category 2)

Ask Q2.1 about their stack preference. If they know, ask Q2.2 for details.

**Research pause**: After gathering the stack, spawn the `stack-researcher` agent to research:
- Current versions and scaffold CLIs
- Best practices and recommended patterns
- Deployment options and companion ecosystem

Wait for research results. Then ask Q2.3 about the scaffold approach, informed by the research findings.

Present research findings naturally: "I looked into [framework] — the current stable version is [X]. The official scaffold CLI `[command]` now supports [features]. I'd recommend using that."

### Step 3: Project Details (Category 3)

Work through Category 3 questions adaptively. The question bank specifies conditions for each — only ask what's relevant.

Key branching points:
- Q3.1 (scale) → updates `isProduction`, `hasTeam`
- Q3.4 (deploy) → if "Not deploying", sets `willDeploy = false` and skips all CI/CD questions
- Q3.7 (API design) → if "No API layer", skips Q3.8

For frontend projects, also ask Q3.F1 (styling) and Q3.F2 (component library).

Also capture during this step (can be inferred or asked directly):
- **`primaryTasks`**: What will the developer mostly do? (feature dev, bug fixes, maintenance, refactoring). Infer from project maturity + type, or ask.
- **`deployFrequency`**: How often will they deploy? (continuous, daily, weekly, manual, none). Ask alongside Q3.4 if deploying.
- **`frontendPatterns`**: If frontend project — component library, state management, styling, routing. Partially captured by Q3.F1/Q3.F2, fill in the rest from stack research.
- **`backendPatterns`**: If backend project — API style (from Q3.7), ORM (from Q3.2/database choice), auth (from Q3.3), error handling. Compose from existing answers.

### Step 3.5: Pain Points (always ask)

Ask about where Claude can help most:
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

### Step 4: Workflow Preferences (Category 4)

Ask Q4.1 through Q4.5. For Q4.1 (branching), recommend based on team size from Q3.1.

Q4.6 (releases) is only asked for production apps.

### Step 5: CI/CD & Auto-Evolution (Category 5)

**Skip entirely if `willDeploy = false`** (except Q5.2 which applies even to local projects).

Ask Q5.1 (audit behavior), Q5.2 (auto-evolution mode), Q5.3 (PR review trigger).

### Step 6: Feature Decomposition (Harness Preparation)

Before the confirmation step, decompose the app description into testable features. This feeds the harness design's `feature-list.json`.

1. From `appDescription` and all gathered context, generate a sprint-organized feature list
2. Each feature must be concrete, testable, and have verification steps
3. Sprint 1 is always the minimal viable foundation
4. Scale depth by project type: CLI (5-10 features), web app (15-25), production (30-50)

Include the feature breakdown in the confirmation summary (see below). The developer can adjust, add, remove, or skip entirely. If skipped, generate a minimal 3-5 feature list from the app description.

### Step 7: Confirmation (Category 7)

Present a structured summary of everything gathered:

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

Wait for confirmation before returning.

## Output

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
  "pluginsToInstall": [],
  "webResearch": {}
}
```

Fields that were skipped are set to `null` or omitted.

## Key Rules

1. **One question per message** — Do not overwhelm with multiple questions.
2. **Research before scaffold decisions** — Never recommend a scaffold approach without web research.
3. **Respect skips** — If the developer says "skip" or "not now", use neutral defaults and move on.
4. **Adaptive, not rigid** — The question order is a guide, not a script. If the developer volunteers information, capture it and skip the corresponding question.
5. **Never ask what you already know** — If Q1.1 reveals the stack, don't re-ask in Q2.
6. **Recommend with reasoning** — Always explain why you suggest something, referencing research when available.
