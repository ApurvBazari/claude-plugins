# Wizard Question Bank

Catalog of questions for the grounded confirm/override wizard. The profile (Minimal / Standard / Comprehensive) is already chosen in `/onboard:start` Step 1.4 and the research dossier already exists from Step 1.5 — so this wizard does **not** interrogate. It runs ~2–3 `AskUserQuestion` exchanges that **confirm or override** what research inferred.

Two question shapes appear below:

- **Confirm/override** — the research-inferred value (from `research.wizardInferences`, per `../../research/references/wizard-inference-map.md`) is presented as the **recommended (first) option**; the developer can accept it or pick a different enum value. When research omits a field (no signal), the **static default** from `SKILL.md § Static Defaults` is the recommended option — never a blank. The `Map to` field and enum options are unchanged; only the framing is confirm/override.
- **Cold ask** — never inferred, always asked fresh. Only `autonomyLevel` (Q7.3) and the free-form project description / pain points are cold asks.

Detection questions (ecosystem plugins / LSP / built-in skills) keep their detection logic and are issued in Exchange 3.

---

## Category 1: Project Context

### Q1.1: Project Description (cold ask — free-form)
**Ask**: "In a sentence or two, what does this project do?"
**Note**: Research drafts a one-line description from the `architecture` + `domain` findings; present that draft as **editable free-form text** for the developer to ratify or rewrite.
**Purpose**: Sets context for everything else. Used in root CLAUDE.md project overview.
**Map to**: `projectDescription`
**Inference rule**: Cannot infer a final value — always present for ratification (the research draft is a starting point, not an answer).

### Q1.2: Team Structure (confirm/override)
**Ask**: "Confirm or override: team size — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.teamSize` value (or `small (2-5)` static default if absent), with the description citing the inference's evidence (e.g. git contributor count).
**Other options**: `solo` / `small (2-5)` / `medium (6-15)` / `large (15+)`.
**Follow-up if team >5**: "Do you have shared coding standards or a style guide?"
**Purpose**: Determines agent complexity (solo = fewer agents, team = collaboration agents), rule strictness.
**Map to**: `teamSize`, and conditionally `sharedStandards`
**Inference rule**: Git contributor count — 1 = solo, 2-5 = small, 6-15 = medium, 15+ = large.

### Q1.3: Project Maturity (confirm/override)
**Ask**: "Confirm or override: project maturity — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.projectMaturity` value (or `early` static default if absent).
**Other options**: `new` / `early` / `established` / `legacy`.
**Purpose**: Affects rule strictness, convention documentation depth.
**Map to**: `projectMaturity`
**Inference rule**: Source file count — <10 = new, 10-100 = early, 100-500 = established, >500 = legacy.

---

## Category 2: Development Workflow (confirm/override)

### Q2.1: Primary Work Types (confirm/override — multiSelect)
**Ask**: "Confirm or override: the kind of work you primarily do here."
**Pre-checked options**: derived from `research.wizardInferences.primaryWork` per `SKILL.md § primaryWork → primaryTasks mapping`; the developer can add/remove.
**Options**: `feature-dev` / `bug-fixes` / `maintenance` / `refactoring`.
**Purpose**: Determines which skills and agents are most valuable.
**Map to**: `primaryTasks`

### Q2.2: Code Review Process (confirm/override)
**Ask**: "Confirm or override: how code reviews work — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.codeReviewProcess` value (or `informal` static default if absent).
**Other options**: `none` / `informal` / `formal-pr`.
**Purpose**: Determines whether to generate review-focused agents and rules.
**Map to**: `codeReviewProcess`
**Inference rule**: PR-related CI detected = formal-pr, team >1 = informal, solo = none.

### Q2.3: Branching Strategy (confirm/override)
**Ask**: "Confirm or override: your branching approach — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.branchingStrategy` value (or `feature-branches` static default if absent).
**Other options**: `trunk-based` / `gitflow` / `feature-branches`.
**Purpose**: Affects hook configurations and commit-related rules.
**Map to**: `branchingStrategy`
**Inference rule**: Git branch patterns — many feature/* branches = feature-branches, develop + release branches = gitflow, only main/master = trunk-based.

### Q2.4: Deploy Frequency (confirm/override)
**Ask**: "Confirm or override: how often you deploy — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.deployFrequency` value (or `manual` static default if absent).
**Other options**: `continuous` / `daily` / `weekly` / `manual` / `none`.
**Purpose**: Affects CI/CD rules and deployment-related skills.
**Map to**: `deployFrequency`
**Inference rule**: CI/CD with auto-deploy config = continuous, CI without auto-deploy = manual, no CI detected = none.

---

## Category 3: Frontend-Specific (If Frontend Detected)

**Trigger**: Research/analysis detected React, Vue, Svelte, Angular, or significant HTML/CSS/JS frontend code. These are confirm/override when the research finding is present; framed as a confirmation of the detected pattern.

### Q3.1: Component Patterns (confirm/override)
**Ask**: "Confirm or override: how you organize components."
**Recommended option**: the detected pattern (e.g. atomic / feature-based / flat) from research, when present.
**Purpose**: Drives component-related rules and skills.
**Map to**: `frontendPatterns.componentOrganization`
**Inference rule**: Directory names — atoms/molecules/organisms = atomic, features/ = feature-based, flat components/ = flat.

### Q3.2: Styling Approach (confirm/override)
**Ask**: "Confirm or override: your styling approach."
**Recommended option**: the detected styling solution (e.g. Tailwind), when research found one.
**Offer choices based on detected tools**: Tailwind / CSS Modules / styled-components / Sass / other
**Purpose**: Styling-specific rules.
**Map to**: `frontendPatterns.styling`
**Inference rule**: Detected styling library — tailwindcss found = Tailwind, styled-components found = styled-components, sass found = Sass, etc.

### Q3.3: State Management (confirm/override)
**Ask**: "Confirm or override: how you handle state management."
**Recommended option**: the detected state library, when research found one.
**Only ask if**: React or Vue detected (Svelte has built-in stores)
**Purpose**: State management conventions and rules.
**Map to**: `frontendPatterns.stateManagement`
**Inference rule**: Detected state library — redux/zustand/jotai/recoil/mobx found = that library.

---

## Category 4: Backend-Specific (If Backend Detected)

**Trigger**: Research/analysis detected Express, FastAPI, Django, Go server, Rust server, NestJS, or API routes. Confirm/override the detected value.

### Q4.1: API Style (confirm/override)
**Ask**: "Confirm or override: your API style."
**Recommended option**: the detected style (REST / GraphQL / gRPC), when present.
**Purpose**: API-specific rules and patterns.
**Map to**: `backendPatterns.apiStyle`
**Inference rule**: GraphQL schema files = GraphQL, protobuf files = gRPC, REST route patterns = REST.

### Q4.2: Database Patterns (confirm/override)
**Ask**: "Confirm or override: how you interact with your database."
**Recommended option**: the detected ORM / approach, when present.
**Purpose**: Database interaction rules.
**Map to**: `backendPatterns.databaseApproach`
**Inference rule**: Detected ORM/database library — Prisma/SQLAlchemy/Drizzle = ORM, mongoose = document store.

### Q4.3: Auth Approach (confirm/override)
**Ask**: "Confirm or override: your authentication approach."
**Recommended option**: the detected auth approach, when present.
**Only ask if**: Backend appears to have auth-related code
**Purpose**: Security rules and auth-related conventions.
**Map to**: `backendPatterns.authApproach`
**Inference rule**: JWT library found = JWT, passport/next-auth found = OAuth, session middleware found = sessions.

---

## Category 5: DevOps-Specific (If CI/CD Detected)

**Trigger**: Research/analysis detected GitHub Actions, GitLab CI, CircleCI, Jenkins, or deployment configs. Confirm/override the detected value.

### Q5.1: Deployment Target (confirm/override)
**Ask**: "Confirm or override: where this deploys."
**Recommended option**: the detected target (cloud / serverless / container), when present.
**Purpose**: Deployment-related rules and skills.
**Map to**: `devopsPatterns.deployTarget`
**Inference rule**: Vercel config = Vercel/serverless, Dockerfile = container-based, AWS/GCP/Azure config files = cloud provider.

### Q5.2: Infrastructure as Code (confirm/override)
**Ask**: "Confirm or override: your infrastructure-as-code tooling."
**Recommended option**: the detected IaC tool, when present (else `none`).
**Purpose**: IaC-specific rules.
**Map to**: `devopsPatterns.iacTool`
**Inference rule**: Terraform files = Terraform, Pulumi files = Pulumi, CloudFormation templates = CloudFormation, docker-compose = Docker Compose.

---

## Category 6: Pain Points (cold asks — free-form)

These cannot be inferred from research; they are cold free-form asks (or "skip" → recorded empty + flagged per `SKILL.md § Skip Behavior`).

### Q6.1: Time Sinks
**Ask**: "What part of your development workflow takes the most time or feels most tedious?"
**Purpose**: Identifies highest-value automation opportunities. Directly influences which skills and agents to prioritize.
**Map to**: `painPoints.timeSinks`
**Inference rule**: Cannot infer — developer-specific. Left empty, flagged as TODO if skipped.

### Q6.2: Error-Prone Areas
**Ask**: "What areas of the codebase or workflow are most error-prone?"
**Purpose**: Identifies where stricter rules and review agents would help most.
**Map to**: `painPoints.errorProne`
**Inference rule**: Cannot infer — developer-specific. Left empty, flagged as TODO if skipped.

### Q6.3: Automation Wishes
**Ask**: "If Claude could automate one thing in your workflow, what would it be?"
**Purpose**: Direct input for skill and agent generation priorities.
**Map to**: `painPoints.automationWishes`
**Inference rule**: Cannot infer — developer-specific. Left empty, flagged as TODO if skipped.

---

## Category 7: Preferences

### Q7.1: Code Style Strictness (confirm/override)
**Ask**: "Confirm or override: how strict Claude should be about code style — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.codeStyleStrictness` value (or `moderate` static default if absent).
**Other options**: `relaxed` (just make it work) / `moderate` (follow conventions, don't nitpick) / `strict` (enforce everything).
**Purpose**: Calibrates rule strictness across all generated rules.
**Map to**: `codeStyleStrictness`
**Inference rule**: Linter config — none = relaxed, linter present = moderate, linter + strict config (e.g., `"strict": true` in tsconfig) = strict.

### Q7.2: Security Sensitivity (confirm/override)
**Ask**: "Confirm or override: how security-sensitive this project is — research inferred **<value>**."
**Recommended option**: `research.wizardInferences.securitySensitivity` value (or `standard` static default if absent).
**Other options**: `standard` (typical web app) / `elevated` (user data/payments) / `high` (financial/healthcare/compliance).
**Purpose**: Determines whether to generate security-focused rules and agents.
**Map to**: `securitySensitivity`
**Inference rule**: Auth/payment/session code found = elevated, HIPAA/PCI/compliance patterns = high, otherwise = standard.

### Q7.3: Claude Autonomy Level (COLD ASK — never inferred)
**Ask**: "When working with Claude, do you prefer it to always ask before acting, take a balanced approach (ask for big decisions, act on small ones), or be as autonomous as possible?"
**Options**: `always-ask` / `balanced` / `autonomous` (single-select).
**Purpose**: This is the single most important preference. It shapes the tone and assertiveness of all generated CLAUDE.md content and rules.
**Map to**: `autonomyLevel`
**Inference rule**: **NEVER INFER.** Always ask the developer explicitly — this is a cold ask in every profile. `wizard-inference-map.md` forbids inferring it. This is the most important preference and must come from direct input. It is NOT pre-filled from the profile's generation-scope default; the profile's autonomy value is a fallback only if the developer explicitly skips this question (see `SKILL.md § Skip Behavior`).

---

## Category 8: Ecosystem Plugins (detection — Exchange 3)

### Q8.1: Notifications
**Ask**: "Would you like system notifications when Claude finishes tasks or needs your attention? This uses the **notify** plugin — works on macOS and Linux."
**Options**: Yes (recommended) / No
**Purpose**: Sets up the notify plugin with default config during onboarding.
**Map to**: `ecosystemPlugins.notify`
**Default**: `true`
**Skip if**: notify plugin is not installed in Claude Code.
**Probe install status**: `ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null`; present each plugin with an `[installed]` / `[not installed]` marker. Selected-but-missing plugins install in /onboard:start Phase 3.5.
**Note**: If accepted, the init command will run notify's install script, write a default `notify-config.json`, and merge hooks into `settings.json`.

---

## Category 9: Detection Prompts — LSP & Built-in Skills (Exchange 3)

These two detection groups are issued **together as two `multiSelect` questions in one `AskUserQuestion` call** — the canonical two-block pattern. The single-option guard in `.claude/rules/ask-user-question-guard.md` applies to each dynamically-built group.

### Q9.1: LSP Plugins
- Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh" "$PROJECT_ROOT"`.
- Empty array → drop this group and record `wizardAnswers.lspPlugins = []`.
- Otherwise present detected plugins (pre-checked when `fileCount ≥ 10`) in fileCount-descending order; record accepted names in `wizardAnswers.lspPlugins`.

### Q9.2: Built-in Skills
- Detect candidates from the analysis report (4 core always; extras when their signal fires); record accepted names in `wizardAnswers.builtInSkills`.

### Canonical two-multiSelect-in-one-call example

Issue both groups in a single `AskUserQuestion` call (one user interaction, two grouped multi-selects). Apply the single-option guard per group: a standalone group that collapses to 1 candidate becomes a yes/no; a group inside this combined call is padded with an explicit `None / Skip` (envelope intact); a zero-candidate group is dropped.

```jsonc
AskUserQuestion({
  questions: [
    {
      header: "LSP Plugins",
      question: "Detected language servers — which should I wire up? (override as needed)",
      multiSelect: true,
      options: [
        { label: "typescript-lsp",   description: "TypeScript/JS — 240 source files detected" },
        { label: "rust-analyzer-lsp", description: "Rust — 38 source files detected" }
        // if this list collapsed to ONE candidate, pad with { label: "None / Skip", ... }
      ]
    },
    {
      header: "Built-in Skills",
      question: "Built-in Claude Code skills to enable for this project?",
      multiSelect: true,
      options: [
        { label: "/loop",       description: "Core — recurring interval runner" },
        { label: "/simplify",   description: "Core — quality-only cleanup pass" },
        { label: "/debug",      description: "Core — systematic debugging" },
        { label: "/pr-summary", description: "Core — PR description generator" },
        { label: "/schedule",   description: "Extra — fired: CI/CD detected" }
      ]
    }
  ]
})
```

**Programmatic mode** (`callerExtras.lspPlugins` / `callerExtras.disableLSP` / `callerExtras.builtInSkills` / `callerExtras.disableBuiltInSkills`): the detection prompt never fires — generation reads the caller-supplied value directly.

---

## Exchange Grouping (uniform — ~2–3 exchanges, all profiles)

The grounded wizard does not branch on profile. It runs the same ~2–3 exchanges regardless of which profile was chosen in `/onboard:start` Step 1.4, skipping any group with no candidates or no signal.

```
Exchange 1 — Workflow & preferences (confirm/override):
  Q1.2 + Q1.3 (context) + Q2.1–Q2.4 (workflow) + Q7.1 + Q7.2 (preferences)
  Tech-specific confirm/overrides (Category 3/4/5) fold in when research detected the stack.
  Each field: research-inferred value = recommended option; static default when no signal.

Exchange 2 — Cold asks (never inferred):
  Q7.3 autonomyLevel (cold single-select)
  Q1.1 project description (editable free-form; research draft pre-filled)
  Q6.1 + Q6.2 + Q6.3 pain points (free-form; "skip" allowed)

Exchange 3 — Tuning cards + detection:
  Tuning cards (advanced hooks / skill / agent / output-style) — static/preset defaults pre-selected.
  Q8.1 ecosystem plugins; Q9.1 + Q9.2 LSP + built-in skills (two multiSelects in one call).
  Skip any detection group with zero candidates. Accepting all defaults clears this in one pass.

Summary & confirmation:
  Present everything gathered (recon analysis + research inferences + confirmed/overridden
  answers + the model line); confirm before control returns to /onboard:start Step 2.5.
```

Question selection within an exchange is still **signal-gated**: skip a confirm/override question entirely when analysis/research already answers it unambiguously (the recommended option would be the only sensible answer), skip Category 3/4/5 when the stack isn't detected, and skip Q1.3 when the repo has <10 source files (auto-classify as "new").
