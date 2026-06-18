---
name: wizard
description: Adaptive Q&A flow for gathering developer preferences during /onboard:start. Internal building block invoked by the start skill — not user-invocable.
user-invocable: false
---

# Wizard Skill — Interactive Onboarding Flow

You are guiding a developer through an interactive onboarding wizard for Claude Code. Your goal is to understand their project, workflow, preferences, and pain points so that Claude tooling can be generated to maximize their productivity.

## Guard — interactive choice convention (MUST follow)

**REQUIRED**: Every interactive choice in this wizard MUST use the `AskUserQuestion` tool with structured options. Single-select uses one question per `AskUserQuestion` call; multi-select uses `multiSelect: true`; up to 4 questions can be packed into one `AskUserQuestion` call (each up to 4 options).

**FORBIDDEN**: Inline numbered prompts of the form "Type 1 for X / 2 for Y / 3 for Z". This pattern degrades to plain-text reading + parsing instead of the click-to-select UI affordance, and was the primary UX issue flagged in the 2026-04-16 release-gate test (findings A5, O2, O3).

If you find yourself typing a numbered list and asking the developer to "reply with the number", **stop** — that's a bug. Wrap the choices in `AskUserQuestion` with `options` and let the harness render the picker.

Free-form text inputs (project name, description, paths) are NOT choices and stay as conversational text prompts. The rule applies only to multiple-options-pick-one(or-many) interactions.

## Conversation Style

- **Conversational, not interrogative** — This is a dialogue, not a form. Acknowledge each answer before asking the next question.
- **Connect answers to analysis** — Reference what the codebase analyzer found, and to the research findings. "I see you're using Next.js with the App Router — that's great for server components. Let me ask about..."
- **Adapt dynamically** — Skip questions that the analysis already answered clearly. Add follow-ups when answers reveal complexity.
- **Be concise** — Each question exchange should be brief. Don't over-explain.
- **Group related questions** — Ask 2-3 related questions together when they naturally cluster, rather than one at a time.

## Wizard Flow — grounded confirm/override

The profile and research depth were chosen in `/onboard:start` Step 1.4, and the research dossier already exists from Step 1.5. (`/onboard:adopt` is the same: it runs recon + research at Full depth in its Step A2, then dispatches this wizard in A3 with the dossier in context.) **This wizard does NOT interrogate** — it confirms or overrides what research inferred, in ~2–3 `AskUserQuestion` exchanges. Quick Mode and the old full/Custom wizard have **converged** into this single surface; there is no preset selection here (it happened in `start`) and no Custom path.

The wizard receives the `research` dossier in context. It reads `research.wizardInferences` (per `../research/references/wizard-inference-map.md`) to seed recommended options.

### Exchange 1 — Workflow & preferences (confirm/override)

Build `AskUserQuestion` call(s) (≤4 questions each) covering: `teamSize`, `projectMaturity`, `codeStyleStrictness`, `securitySensitivity`, `codeReviewProcess`, `branchingStrategy`, `deployFrequency`. For each field:

- If a `research.wizardInferences[field]` exists, its `value` is the **recommended (first) option**, and the option description cites the inference's `evidence`.
- If the field is **absent** from `wizardInferences` (signal-or-omit), use the **static default** from § Static Defaults as the recommended option — never a blank.

`primaryTasks` is a separate `multiSelect` question; pre-check options per § primaryWork → primaryTasks mapping using `research.wizardInferences.primaryWork`.

### Exchange 2 — Cold asks (never inferred)

- **`autonomyLevel`** — ALWAYS asked cold (single-select: `always-ask` / `balanced` / `autonomous`). Never pre-filled from research (`wizard-inference-map.md` forbids inferring it).
- **Project intent / description** — research drafts a one-line description from the `architecture` + `domain` findings; present it as **editable free-form text** for the developer to ratify or rewrite.
- **`painPoints`** — research cannot infer these; ask the three free-form prompts (`timeSinks` / `errorProne` / `automationWishes`), or accept "skip" (→ recorded empty + flagged per § Skip Behavior).

### Exchange 3 — Tuning cards + detection

Present each as an **overridable card with its static/preset default pre-selected** (these are NOT research-inferable):

- Advanced hook events + per-event type (Step 1) — default: none beyond inference.
- Skill tuning / agent tuning / output-style tuning (Steps 2 / 3 / 4) — default: `{ mode: "defaults" }` each.

Then the **detection prompts** (unchanged detection logic, folded into this exchange):

- Ecosystem plugins (Step 5), LSP plugins (Step 6), built-in skills (Step 7). The single-option guard in `.claude/rules/ask-user-question-guard.md` still applies to each dynamically-built group.

A developer who accepts all defaults clears Exchange 3 in one pass.

### Summary & Confirmation

Present everything gathered (recon `analysis` + `research` inferences + confirmed/overridden answers + the chosen model line) and confirm before control returns to `/onboard:start`, which proceeds to Step 2.5 (Plugin Detection). **Always include the model line** as before: `Model: <model-id> (<source>)`.

## Exchange 3 detail — recorded field shapes

Exchange 3's tuning cards and detection prompts use the same recording shapes as before; only the front-of-house presentation changed (cards with pre-selected defaults instead of yes/no opt-in gates). The full field-recording mechanics live in § Output; this is the condensed pointer.

**Advanced hook events + per-event type** — when the developer overrides the "none beyond inference" default and selects advanced events, present the 9 events thematically (lifecycle / user / tool) as `multiSelect` groups and record the merged selection verbatim in `wizardAnswers.advancedHookEvents` (e.g. `["SessionEnd", "PreCompact", "TaskCompleted"]`). The default is `[]` (inference only) — never inferred as "wanted" without an explicit decision.

For judgment-capable events (`UserPromptSubmit`, `Stop`, `TaskCreated`, `TaskCompleted`, `Elicitation`) the developer can pick a non-`command` execution type per event. Before asking, show the cost table:

> | Type    | Latency | Cost/fire | Best for |
> |---------|---------|-----------|----------|
> | shell   | <1s     | none      | fast deterministic checks (regex, lint) |
> | prompt  | 2-15s   | ~500-2k   | judgment (commit-msg quality, LLM secret detection) |
> | agent   | 10-60s  | ~5-30k    | heavy verification at boundaries (code-reviewer on TaskCompleted) |
> | http    | network | none local| compliance / SIEM / pager integration |

Record per-event type in `wizardAnswers.advancedHookTypes[<eventName>]` (`"command" | "prompt" | "agent" | "http"`); the auxiliary field (`agentRef` / `httpUrl` / `promptRef` / `promptInline`) in `wizardAnswers.advancedHookTypeExtras[<eventName>]`. Before accepting any `http` type, present the data-leaves-the-machine confirmation and set `wizardAnswers.allowHttpHooks = true` only on explicit accept; on decline, drop the `http` selection and fall back to inference for that event.

**Skill / agent / output-style tuning** — default `{ mode: "defaults" }` each (archetype inference only). When overridden, record `wizardAnswers.skillTuning` / `agentTuning` / `outputStyleTuning` with `mode: "tuned"` and the per-mode settings documented in § Output. Per-skill / per-agent / per-style tweaks happen in the generation-time confirmation step, not here.

**Detection prompts** — ecosystem plugins, LSP plugins, built-in skills (Steps 5 / 6 / 7):

- Ecosystem plugins: probe install status with `ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null` and present each with an `[installed]` / `[not installed]` marker; selected-but-missing plugins install in /onboard:start Phase 6 (ecosystem-plugin-install step).
- LSP plugins: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh" "$PROJECT_ROOT"`; empty array → skip and record `wizardAnswers.lspPlugins = []`; otherwise present detected plugins (pre-checked when `fileCount ≥ 10`) in fileCount-descending order and record the accepted names in `wizardAnswers.lspPlugins`.
- Built-in skills: detect candidates from the analysis report (4 core always; extras when their signal fires) and record the accepted names in `wizardAnswers.builtInSkills`.
- LSP plugins and built-in skills are issued together as **two `multiSelect` questions in one `AskUserQuestion` call** (the canonical two-block pattern). The single-option guard in `.claude/rules/ask-user-question-guard.md` applies to each dynamically-built group: a standalone group that collapses to 1 candidate becomes a yes/no; a group inside the combined call is padded with an explicit `None / Skip` (envelope intact); a zero-candidate group is dropped.
- **Programmatic mode** (`callerExtras.lspPlugins` / `callerExtras.disableLSP` / `callerExtras.builtInSkills` / `callerExtras.disableBuiltInSkills`): the detection prompt never fires — generation reads the caller-supplied value directly.

## Static Defaults

Used as the recommended option when `research.wizardInferences` omits a field (no signal):

| Field | Static default |
|---|---|
| `teamSize` | `small (2-5)` |
| `projectMaturity` | `early` |
| `codeStyleStrictness` | `moderate` |
| `securitySensitivity` | `standard` |
| `codeReviewProcess` | `informal` |
| `branchingStrategy` | `feature-branches` |
| `deployFrequency` | `manual` |

Note: a `research.wizardInferences` value may be an enum *stem* (e.g. `teamSize: small`) — match it to the canonical `wizardAnswers` enum string (`small (2-5)`) when seeding the recommended option.

## primaryWork → primaryTasks mapping

`research.wizardInferences.primaryWork` is a free-form characterization; map it to the pre-checked `primaryTasks` enum options (the developer can adjust the multi-select):

| `primaryWork` (research) | pre-checked `primaryTasks` |
|---|---|
| library / SDK | `feature-dev`, `refactoring` |
| API service / backend | `feature-dev`, `bug-fixes` |
| frontend app / SPA | `feature-dev`, `bug-fixes` |
| CLI tool | `feature-dev`, `maintenance` |
| data pipeline | `feature-dev`, `maintenance` |
| (absent / unknown) | `feature-dev` |

## Key Rules

1. **Never skip the summary** — Always show the developer what you've gathered before proceeding to generation.
2. **Respect "skip"** — If a developer says they want to skip a section, move on. Don't push.
3. **Three-exchange shape** — the grounded wizard runs Exchange 1 (workflow/preferences) + Exchange 2 (cold asks) + Exchange 3 (tuning + detection), skipping any detection group with no candidates. No preset selection, no Custom path, no mid-wizard escape hatch (those were the v2 model).
4. **Reference the analysis** — Always connect questions to what the analyzer found. This demonstrates value and reduces redundant questions.
5. **Capture autonomy preference carefully** — This determines how much Claude asks vs acts independently. Get this right.
6. **Always populate fields explicitly** — When the wizard skips a detection group (no signal, programmatic mode) or the developer accepts a default, populate the corresponding field in `wizardAnswers` with the explicit default value (full detected list, archetype default, etc.) rather than leaving the field `undefined`. This means downstream generation always receives explicit Path A data and never has to fall back to Path B (which is just the C1-introduced safety net).
7. **Canonical wizardStatus telemetry — Finalize step** — Before the Summary, emit `wizardStatus` to `onboard-meta.json` with **exactly** these 5 subkeys. Emission runs for every profile; no profile-specific shape variant is allowed.

   Track state throughout the wizard run:

   | State field | Updated when |
   |---|---|
   | `state.presetUsed` | Set once from the profile chosen in `/onboard:start` Step 1.4 (`minimal | standard | comprehensive`) |
   | `state.exchangesUsed` | Incremented on every `AskUserQuestion` call the wizard makes |
   | `state.phasesAsked` | Pushed when an exchange presents questions to the developer |
   | `state.phasesSkipped` | Pushed when an exchange (or detection group) is gated off (no signal, programmatic path) |
   | `state.escapeHatchTriggered` | Always `false` — the feature is gone, but the key stays in the canonical shape (see spec §4.3) |

   Emit as the penultimate wizard action (before the Summary renders):

   ```json
   {
     "wizardStatus": {
       "presetUsed": "standard",
       "exchangesUsed": 3,
       "phasesAsked": ["exchange1", "exchange2", "exchange3"],
       "phasesSkipped": [],
       "escapeHatchTriggered": false
     }
   }
   ```

   **Hard emission rules** (load-bearing; verified by `tests/release-gate/verify-init-output.sh`):
   - Every key present. `phasesAsked` / `phasesSkipped` empty arrays are valid; missing keys are not.
   - `presetUsed` values drawn only from the enum above. Never emit `"mode: interactive"` or `"completed: true"` or `"answersPresent: true"` — those were the three distinct legacy shapes observed on the 2026-04-17 release-gate (findings B2 / B11).
   - `escapeHatchTriggered` is **always `false`** (the escape hatch is gone). Keep the key present anyway — dropping it breaks the canonical 5-key shape contract (spec §4.3).
   - `exchangesUsed` defaults to `0` for stub-mode paths that bypass the wizard entirely. Do not emit `null`.
   - No extra keys beyond the 5 canonical. Adding fields creates drift for downstream consumers.

## Skip Behavior

When a developer skips a question or section:

1. **Use neutral defaults** for skipped fields — and ALWAYS populate them explicitly (do not leave fields `undefined`; downstream generation should never need to guess intent):
   - `autonomyLevel` → `"balanced"`
   - `codeStyleStrictness` → `"moderate"`
   - `securitySensitivity` → `"standard"`
   - `lspPlugins` → full detected list from `${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh` (accept-all default)
   - `builtInSkills` → full candidate list (4 core + fired extras)
   - `outputStyleTuning` → `{ mode: "defaults" }`
   - `skillTuning` → `{ mode: "defaults" }`
   - `agentTuning` → `{ mode: "defaults" }`
   - Other fields → use analysis inference if available; otherwise the default literal documented in `references/question-bank.md`
2. **Record skipped fields** — Add a `skippedFields` array in `onboard-meta.json` listing every field that was skipped (e.g., `["testingPhilosophy", "securitySensitivity"]`)
3. **Flag in generated artifacts** — Add `<!-- TODO: Developer skipped this preference during setup. Review and adjust if needed. -->` comments in generated artifacts where a skipped field affects the output content

## Output

**Canonical shape invariant** — every profile (Minimal / Standard / Comprehensive) and the stub path emits **the same** top-level `wizardAnswers` structure. Missing fields MUST be populated with defaults per § Skip Behavior; never leave a field `undefined` or emit a profile-specific subset. The 2026-04-17 release-gate found three distinct preset-subset shapes in the wild (findings B2 / B11 / B5 / B6) — all caused by paths skipping field emission. The canonical full shape below is the reference; downstream consumers (`onboard:generate` validator, `../start/references/onboard-context-builder.md`, `tests/release-gate/verify-init-output.sh`) assume this shape uniformly.

After the wizard completes, compile all answers into the following structured JSON format:

```json
{
  "selectedPreset": "minimal | standard | comprehensive",
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
  "allowHttpHooks": true,
  "skillTuning": {
    "mode": "tuned",
    "defaultModel": "sonnet",
    "defaultEffort": "medium",
    "preApprovalPosture": "standard"
  },
  "outputStyleTuning": {
    "mode": "tuned",
    "archetypeOverride": "inherit",
    "activationDefault": "none"
  },
  "lspPlugins": ["typescript-lsp", "rust-analyzer-lsp"],
  "builtInSkills": ["/loop", "/simplify", "/debug", "/pr-summary", "/schedule"]
}
```

The `ecosystemPlugins` field captures which ecosystem plugins the developer wants set up. This gets passed to the config-generator agent along with the analysis report. The start command acts on these choices in Phase 6 (ecosystem-plugin-install step).

The `advancedHookEvents` field is an array of event names the developer explicitly selected in Exchange 3 (advanced hook events card). An empty array (`[]`) means "the developer kept the default — no advanced events beyond inference" — generation suppresses advanced event inference for that run. An absent field (omitted entirely) means "the grounded confirm/override surface didn't run this card (programmatic path)" — inference runs normally. See `../generation/SKILL.md` § Advanced Event Hooks for the full mapping.

The `advancedHookTypes` / `advancedHookTypeExtras` / `allowHttpHooks` fields come from Exchange 3 (per-event execution type). `advancedHookTypes` only contains entries for judgment-capable events the developer explicitly picked a non-default type for; events defaulting to `command` are omitted. `advancedHookTypeExtras` carries the auxiliary field (`agentRef` / `httpUrl` / `promptRef` / `promptInline`) required by the chosen type. `allowHttpHooks` is `true` only when the developer confirmed the HTTP data-leaves-machine prompt for at least one event. See `../generation/SKILL.md` § Advanced Event Hooks § Per-event defaults and § Hook Type Validation for how these are consumed.

The `lspPlugins` field is the developer-accepted list of marketplace LSP plugins from Exchange 3 (LSP detection prompt). An empty array means "detected candidates but developer declined all"; an absent field means "programmatic path — full detected list is the implicit accept". `../generation/SKILL.md` § LSP Plugin Recommendations consumes this alongside `callerExtras.lspPlugins` and `callerExtras.disableLSP`. See `../generation/references/catalogs/lsp-plugin-catalog.md` for the plugin→language mapping.

The `builtInSkills` field is the developer-accepted list of built-in Claude Code skills from Exchange 3 (built-in skills detection prompt). An empty array means "candidates existed but developer declined all"; an absent field means "programmatic path — full candidate list (core + fired extras) is the implicit accept". `../generation/SKILL.md` § Built-in Claude Code Skills — emission Step 4 consumes this alongside `callerExtras.builtInSkills` and `callerExtras.disableBuiltInSkills`. See `../generation/references/catalogs/built-in-skills-catalog.md` for the skill tiers and detection signals.

The `skillTuning` field comes from Exchange 3 (skill tuning card). `mode: "defaults"` (or the field being absent entirely) means "archetype inference only — no project-level override". `mode: "tuned"` carries the three project-level settings: `defaultModel` (model tier hint for generated skills), `defaultEffort` (thinking budget hint), `preApprovalPosture` (how aggressively the `allowed-tools` field is populated). These three settings refine the archetype output in `../generation/SKILL.md` § Skills § Frontmatter emission. Per-skill overrides happen in the generation-time batched confirmation step, not here.

The `outputStyleTuning` field comes from Exchange 3 (output-style tuning card). `mode: "defaults"` (or the field being absent entirely) means "archetype inference only — the generation skill picks the top-priority archetype match and emits with catalog defaults". `mode: "tuned"` carries two project-level settings: `archetypeOverride` (`inherit` keeps inference; a named archetype forces that one regardless of firing conditions; `skip-emit` prevents emission entirely) and `activationDefault` (`none` emits the file without touching settings; `write-to-settings` merges `"outputStyle": "<name>"` into `.claude/settings.local.json` following the 4-case merge safety rules in `../generation/references/catalogs/output-styles-guide.md` § settings.local.json merge rules). Per-style developer tweaks happen in the generation-time batched confirmation step, not here.

The `agentTuning` field comes from Exchange 3 (agent tuning card). `mode: "defaults"` (or the field being absent entirely) means "archetype inference only — no project-level override". `mode: "tuned"` carries `defaultModel` / `defaultEffort` / `preApprovalPosture` / `defaultIsolation`, refining the archetype output in `../generation/SKILL.md` § Agent Frontmatter Emission. Per-agent overrides happen in the generation-time batched confirmation step, not here.
