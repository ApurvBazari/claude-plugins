---
name: wizard
description: Adaptive Q&A flow for gathering developer preferences during /onboard:init. Internal building block invoked by the init skill — not user-invocable.
user-invocable: false
---

# Wizard Skill — Interactive Onboarding Flow

You are guiding a developer through an interactive onboarding wizard for Claude Code. Your goal is to understand their project, workflow, preferences, and pain points so that Claude tooling can be generated to maximize their productivity.

## Conversation Style

- **Conversational, not interrogative** — This is a dialogue, not a form. Acknowledge each answer before asking the next question.
- **Connect answers to analysis** — Reference what the codebase analyzer found. "I see you're using Next.js with the App Router — that's great for server components. Let me ask about..."
- **Adapt dynamically** — Skip questions that the analysis already answered clearly. Add follow-ups when answers reveal complexity.
- **Be concise** — Each question exchange should be brief. Don't over-explain.
- **Group related questions** — Ask 2-3 related questions together when they naturally cluster, rather than one at a time.

## Wizard Flow

Follow this sequence, adapting based on analysis results and prior answers. See `references/question-bank.md` for the full question catalog with branching logic. See `references/workflow-presets.md` for preset definitions and pre-filled values.

### Phase 0: Preset Selection (Always)

Present the four workflow presets: Minimal, Standard, Comprehensive, and Custom. See `references/workflow-presets.md` for details and pre-filled values.

- If a preset is selected → load pre-filled values, ask Q1.1 (project description is always project-specific), then skip directly to Phase 6 summary for confirmation.
- If Custom is selected → proceed with the full wizard flow starting at Phase 1.

**Preset path is fast** — only project description + summary if a preset is selected.

### Phase 1: Project Context (Always)
Establish what this project is and who works on it.
- Project description
- Solo or team, team size
- New project or existing codebase

### Phase 2: Development Workflow (Always)
Understand how they work day-to-day.
- Primary work types (feature dev, bug fixes, maintenance)
- Code review process
- Branching strategy
- Deploy frequency

### Phase 3: Tech-Stack Specific (Conditional)
Only ask questions relevant to the detected stack. Skip entirely if the stack is simple.
- Frontend-specific (if frontend detected)
- Backend-specific (if backend detected)
- DevOps-specific (if CI/CD detected)

### Phase 4: Pain Points (Always)
Understand where Claude can help most.
- Biggest time sinks
- Error-prone areas
- Automation wishes

### Phase 5: Preferences (Always)
Calibrate the generated tooling.
- Code style strictness
- Security sensitivity
- Claude autonomy level
- Advanced hook events (optional — see Phase 5.1 below)

### Phase 5.1: Advanced Hook Events (Optional, Default No)

After capturing `autonomyLevel`, ask **one** yes/no question:

> Do you want to configure advanced Claude Code hook events? (optional — default is no, and onboard will pick sensible defaults for you)

If the developer answers **no** (or skips): record `wizardAnswers.advancedHookEvents = []` and move on. The generation skill's per-event inference rules fire instead — the empty array is an intentional "no, do not add advanced hooks on top of inference", documented in `generation/SKILL.md` § Advanced Event Hooks § Input sources.

If the developer answers **yes**: use `AskUserQuestion` with `multiSelect: true` to present the 9 events. Each option is one sentence — no long descriptions.

| Label | Description (one line) |
|---|---|
| `SessionEnd` | Run a cleanup script when the session ends (rotate task markers, flush state). |
| `UserPromptSubmit` | Preflight every user prompt (e.g., warn on apparent secret literals). |
| `PreCompact` | Save a checkpoint just before Claude compacts context (large projects). |
| `SubagentStart` | Audit-log every subagent spawn (agent-team workflows). |
| `TaskCreated` | Nudge when a `TaskCreate` subject looks too vague. |
| `TaskCompleted` | Run the project's test command before a task can be marked done. |
| `FileChanged` | Notice when a watched file (lockfiles, configs) changes on disk. |
| `ConfigChange` | Warn when `.claude/` configuration changes mid-session. |
| `Elicitation` | Audit-log prompts from MCP servers (compliance / security review). |

Record the developer's selection verbatim as an array of strings in `wizardAnswers.advancedHookEvents` (e.g., `["SessionEnd", "PreCompact"]`). The generation skill maps these to event keys per the mapping table in `generation/SKILL.md` § Advanced Event Hooks § Wizard opt-in plumbing.

**Do not combine this question with other preferences** — keep it a single dedicated exchange so the developer can scan the list. If Quick Mode is active, default `advancedHookEvents` to `[]` (inference only) and skip the prompt — advanced events are never inferred as "wanted" without an explicit developer decision.

### Phase 5.1.1: Execution Type Per Event (Conditional, After 5.1 Selections)

**Fires only when** Phase 5.1 returned a non-empty `advancedHookEvents` AND at least one of those events is **judgment-capable**: `UserPromptSubmit`, `Stop`, `TaskCreated`, `TaskCompleted`, `Elicitation`. If none of the selected events are judgment-capable, skip 5.1.1 entirely.

Claude Code hooks can run as one of four types — `command` (shell script, fast, no LLM cost), `prompt` (LLM guardrail with judgment), `agent` (spawn a named subagent), or `http` (POST to an external URL). Most events default to `command`. For the five judgment-capable events above, a non-command type can be a significant upgrade — but has real latency and token costs.

Present this cost table verbatim before asking (one message, no question):

> | Type    | Latency | Cost/fire | Best for |
> |---------|---------|-----------|----------|
> | shell   | <1s     | none      | fast deterministic checks (regex, lint) |
> | prompt  | 2-15s   | ~500-2k   | judgment (commit-msg quality, LLM secret detection) |
> | agent   | 10-60s  | ~5-30k    | heavy verification at boundaries (code-reviewer on TaskCompleted) |
> | http    | network | none local| compliance / SIEM / pager integration |

Then issue **one consolidated `AskUserQuestion` call** with one question per selected judgment-capable event, up to the tool's 4-question limit. If the developer selected all 5 judgment-capable events, split into two exchanges: first 4 events, then the 5th.

**Question shape per event** (single-select, exactly these 4 options — order matters for familiarity):

```
Q: How should the <Event> hook run?
  - Shell script (fast, no LLM cost)
  - Prompt (LLM-evaluated guardrail)
  - Agent (spawn a named subagent)
  - External URL (POST event to https endpoint)
```

**Follow-up exchange** (fires only when needed — skip entirely if every event picked `Shell script`):

For every event where the developer picked a non-shell type, gather the auxiliary field in a **second consolidated `AskUserQuestion` call** (still one question per event, up to 4 per call):

| Selected type | Follow-up question | Field captured |
|---|---|---|
| Prompt | "Paste the prompt text (one line) or provide a file path (e.g., `.claude/hooks/my-prompt.md`). For `UserPromptSubmit` with `securitySensitivity: high`, leave blank to use the shipped default secret-scan prompt." | `promptInline` (if no leading `./` or `/`), else `promptRef` |
| Agent | "Which agent should evaluate this hook? (e.g., `code-reviewer`, `verification-before-completion`)" | `agentRef` |
| External URL | "Paste the https URL to POST events to (must be https-only; http:// is refused)." | `httpUrl` |

**HTTP confirmation** — before accepting any `External URL` selection, present:

> Heads up: `http` hooks POST event payloads (including prompt text, file paths, and MCP elicitations) to your URL. This data leaves the machine. Continue only if your endpoint is internal/audited.
>
> Confirm: set `allowHttpHooks: true` for this project? (yes/no)

If the developer declines, drop the `External URL` selection(s) and record as inference fallback for that event. If accepted, set `wizardAnswers.allowHttpHooks = true` (which the init command then maps to `callerExtras.allowHttpHooks` for the generator).

**Recording the answers**:

- `wizardAnswers.advancedHookTypes[<eventName>]` = one of `"command" | "prompt" | "agent" | "http"`. Example: `{ "taskCompleted": "agent", "elicitation": "http" }`. Events that weren't asked about don't appear in this map (they fall through to defaults).
- `wizardAnswers.advancedHookTypeExtras[<eventName>]` = `{ agentRef?, httpUrl?, promptRef?, promptInline? }` — only the field relevant to that event's chosen type. Events that picked `command` don't appear here.
- `wizardAnswers.allowHttpHooks` = boolean — set to `true` only when the developer accepted at least one HTTP confirmation.

**Exchange budget**: 5.1.1 always fits in ≤3 exchanges total (cost-table preamble → type-pick question → follow-up aux question). When combined with 5.1 (the events question) and the rest of the wizard, we stay within the 6-exchange hard limit. If approaching exchange 5 before 5.1.1 completes, fold remaining aux questions into the final summary confirmation and use sensible defaults for any unanswered fields (record in `skippedFields`).

**Quick Mode behavior**: 5.1.1 is skipped entirely in Quick Mode — per-event type defaults from `generation/SKILL.md` § Per-event defaults apply automatically.

### Phase 5.5: Ecosystem Plugins (Always)
Offer complementary plugins from the ecosystem.
- Notifications (notify plugin) — get alerted when Claude finishes tasks or needs attention

**Offer all ecosystem plugins regardless of install status.** For each one, probe the filesystem and include an install-status marker in the presentation so the developer knows up front what's already installed vs. what will need to be installed later:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null
```

Present each plugin with:
- A one-line capability description
- `[installed]` or `[not installed]` marker based on the probe result
- For `[not installed]`, a note: "Selecting this will prompt you to install it in Phase 3.5."

The developer can select any plugin regardless of install status. Phase 3.5 (`Resolve Requested Ecosystem Plugins` in the init command) handles the inline install for anything selected but missing — the wizard never hides options just because they aren't installed yet.

### Phase 6: Summary & Confirmation
Present everything gathered (analysis + wizard answers) and ask for confirmation before generation.

## Key Rules

1. **Never skip the summary** — Always show the developer what you've gathered before proceeding to generation.
2. **Respect "skip"** — If a developer says they want to skip a section, move on. Don't push.
3. **Hard 6-exchange limit** — The entire wizard must complete within 6 back-and-forth exchanges. If you reach exchange 5 without completing all phases, consolidate remaining questions into a single final exchange. At exchange 6, wrap up: present the summary with any unanswered fields set to defaults, and proceed to confirmation.
4. **Reference the analysis** — Always connect questions to what the analyzer found. This demonstrates value and reduces redundant questions.
5. **Capture autonomy preference carefully** — This determines how much Claude asks vs acts independently. Get this right.

## Skip Behavior

When a developer skips a question or section:

1. **Use neutral defaults** for skipped fields:
   - `autonomyLevel` → `"balanced"`
   - `codeStyleStrictness` → `"moderate"`
   - `securitySensitivity` → `"standard"`
   - Other fields → omit from wizard answers or use analysis inference if available
2. **Record skipped fields** — Add a `skippedFields` array in `onboard-meta.json` listing every field that was skipped (e.g., `["testingPhilosophy", "securitySensitivity"]`)
3. **Flag in generated artifacts** — Add `<!-- TODO: Developer skipped this preference during setup. Review and adjust if needed. -->` comments in generated artifacts where a skipped field affects the output content

## Quick Mode

Quick Mode infers most wizard fields from the codebase analysis, asks only what cannot be inferred, and presents a summary for tweaking.

### Inference Rules

From analysis data, infer:

| Field | Inference Rule |
|-------|---------------|
| `teamSize` | Git contributor count: 1 = solo, 2-5 = small, 6-15 = medium, 15+ = large |
| `projectMaturity` | Source file count: <10 = new, 10-100 = early, 100-500 = established, >500 = legacy |
| `testingPhilosophy` | Always `"tdd"` — hard-wired, not inferred |
| `codeStyleStrictness` | Linter config: none found = relaxed, linter present = moderate, linter + strict config (e.g., `"strict": true` in tsconfig, strict ESLint rules) = strict |
| `securitySensitivity` | Code detection: auth/payment/session code found = elevated, HIPAA/PCI/compliance patterns = high, otherwise = standard |
| `codeReviewProcess` | PR-related CI detected = formal-pr, team >1 = informal, solo = none |
| `branchingStrategy` | Git branch patterns: many feature branches = feature-branches, develop + release branches = gitflow, only main = trunk-based |
| `deployFrequency` | CI/CD with auto-deploy = continuous, CI without auto-deploy = manual, no CI = none |
| `painPoints` | **Cannot infer** — left empty, flagged as `<!-- TODO: ask developer about pain points -->` in generated artifacts |
| `autonomyLevel` | **NEVER infer — always ask explicitly** |

### Quick Mode Flow

1. **Infer** — Apply inference rules to analysis data, fill wizard answers
2. **Ask autonomy** — Always ask the developer their autonomy preference (Q7.3)
3. **Ask project description** — Always ask Q1.1
4. **Present summary** — Show all inferred + asked values with clear "[inferred]" labels
5. **Allow tweaks** — Developer can adjust any value before confirming

### Combining with Presets

Quick mode inference can refine preset defaults. If a developer chose Quick setup after seeing the analysis summary, inference runs first. If any inferred value differs from what a preset would provide, the inferred (more accurate) value wins.

## Output

After the wizard completes, compile all answers into a structured JSON format:

```json
{
  "selectedPreset": "minimal | standard | comprehensive | custom",
  "projectDescription": "...",
  "teamSize": "solo | small (2-5) | medium (6-15) | large (15+)",
  "sharedStandards": "none | informal | documented | enforced",
  "projectMaturity": "new | early | established | legacy",
  "primaryTasks": ["feature-dev", "bug-fixes", "maintenance", "refactoring"],
  "codeReviewProcess": "none | informal | formal-pr",
  "branchingStrategy": "trunk-based | gitflow | feature-branches",
  "deployFrequency": "continuous | daily | weekly | manual | none",
  "frontendPatterns": {
    "componentLibrary": "e.g., MUI, Radix, Shadcn, custom",
    "stateManagement": "e.g., Redux, Zustand, Context, Jotai",
    "styling": "e.g., Tailwind, CSS Modules, Styled Components",
    "routing": "e.g., Next.js App Router, React Router, TanStack Router"
  },
  "backendPatterns": {
    "apiStyle": "e.g., REST, GraphQL, tRPC, gRPC",
    "orm": "e.g., Prisma, Drizzle, SQLAlchemy, GORM",
    "auth": "e.g., NextAuth, Passport, custom JWT",
    "errorHandling": "e.g., Result pattern, exceptions, error codes"
  },
  "devopsPatterns": {
    "ci": "e.g., GitHub Actions, GitLab CI, CircleCI",
    "hosting": "e.g., Vercel, AWS, GCP, self-hosted",
    "containerization": "e.g., Docker, Podman, none",
    "iac": "e.g., Terraform, Pulumi, CDK, none"
  },
  "painPoints": {
    "timeSinks": "...",
    "errorProne": "...",
    "automationWishes": "..."
  },
  "testingPhilosophy": "tdd",
  "codeStyleStrictness": "relaxed | moderate | strict",
  "securitySensitivity": "standard | elevated | high",
  "autonomyLevel": "always-ask | balanced | autonomous",
  "ecosystemPlugins": {
    "notify": true
  },
  "advancedHookEvents": [
    "SessionEnd",
    "PreCompact",
    "TaskCompleted",
    "Elicitation"
  ],
  "advancedHookTypes": {
    "taskCompleted": "agent",
    "elicitation": "http"
  },
  "advancedHookTypeExtras": {
    "taskCompleted": { "agentRef": "code-reviewer" },
    "elicitation":   { "httpUrl":  "https://audit.internal/claude-elicitation" }
  },
  "allowHttpHooks": true
}
```

The `ecosystemPlugins` field captures which ecosystem plugins the developer wants set up. This gets passed to the config-generator agent along with the analysis report. The init command acts on these choices in Phase 3.5.

The `advancedHookEvents` field is an array of event names the developer explicitly selected in Phase 5.1. An empty array (`[]`) means "the developer answered no to the opt-in prompt" — generation suppresses advanced event inference for that run. An absent field (omitted entirely) means "Quick Mode or preset path" — inference runs normally. See `generation/SKILL.md` § Advanced Event Hooks for the full mapping.

The `advancedHookTypes` / `advancedHookTypeExtras` / `allowHttpHooks` fields come from Phase 5.1.1 (execution type per event). `advancedHookTypes` only contains entries for judgment-capable events the developer explicitly picked a non-default type for; events defaulting to `command` are omitted. `advancedHookTypeExtras` carries the auxiliary field (`agentRef` / `httpUrl` / `promptRef` / `promptInline`) required by the chosen type. `allowHttpHooks` is `true` only when the developer confirmed the HTTP data-leaves-machine prompt for at least one event. See `generation/SKILL.md` § Advanced Event Hooks § Per-event defaults and § Hook Type Validation for how these are consumed.
