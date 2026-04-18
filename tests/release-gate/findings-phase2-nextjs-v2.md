# Phase 2 — /onboard:init on test-nextjs (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Commit:** `29fad5e` (tests/release-gate scripts aligned to the fix sweep)
**Onboard version:** 1.9.0
**Run model:** Opus 4.7 (1M context) with xhigh effort
**Generation time:** 38m 48s · ~$12 session cost
**Wizard exchanges:** ~15 AskUserQuestion exchanges (well above pre-sweep 6-exchange cap)
**Artifact verifier:** `tests/release-gate/verify-init-output.sh` → **38 PASS / 6 WARN / 1 FAIL**

---

## A. Interactive wizard observations (M1 / C4 / L1 sweep)

| # | Check | Result | Evidence from transcript |
|---|---|---|---|
| A1 | `/onboard:` autocomplete exposes only 5 user-facing skills | ✅ PASS | Transcript opens with `/onboard:init` resolving cleanly; no internal skills offered |
| A2 | Preset selector uses AskUserQuestion chips (not numbered text) | ✅ PASS | `User answered Claude's questions: · Which setup preset fits this project best? → Custom` |
| A3 | Phase 5.0 Custom-preset escape hatch fires once | ✅ PASS | `Keep customizing or use Quick Mode defaults from here? → Continue customizing (Recommended)` |
| A4 | Phase 5.1 advanced-hook opt-in question appeared | ✅ PASS | `Configure advanced Claude Code hook events? → Yes` |
| A5 | 9 events arrived as 3 multi-selects in ONE AskUserQuestion call | ✅ PASS | Single exchange contained `Lifecycle events`, `User events`, `Tool events` multi-selects |
| A6 | Cost-table preamble shown before execution-type selection | ✅ PASS | `shell / prompt / agent / http` table rendered inline |
| A7 | Phase 5.2 skill-tuning gate appeared; model captured | ✅ PASS | `Default model tier for generated skills? → inherit` |
| A8 | Phase 5.3 agent-tuning gate appeared | ✅ PASS | 4 sub-questions including `Default isolation → Worktree for generators` |
| A9 | Phase 5.4 output-style: archetype inference mentions `production-ops` | ⚠️ UNCLEAR | User chose archetype `inherit`; transcript does not surface the inferred archetype label. `production-ops` is never printed |
| A10 | Phase 5.6 + 5.7: LSP + built-in skills in ONE AskUserQuestion call | ⚠️ DEGRADED | Wizard attempted combined call, schema rejected it (see B1). Fell back to sequential. `typescript-lsp` appeared pre-checked. `/loop` offered but user declined. `/schedule` **not visible** in transcript despite `.github/workflows/` presence |
| A11 | Phase 6 summary shows `Model: <id> (<source>)` | ✅ PASS | `Model: claude-opus-4-7[1m] (fallback default — your skill-tuning chose inherit, Custom has no preset default)` |
| A12 | No separate post-summary model prompt | ✅ PASS | Wizard proceeded directly to `Ready to generate, or tweak first?` |
| A13 | No hard 6-exchange cap | ✅ PASS | 15+ AskUserQuestion exchanges; wizard pre-announced `roughly 7 more exchanges` (adaptive sizing confirmed) |
| A14 | Session returns cleanly after init | ✅ PASS | Phase 4 handoff rendered; prompt returned without hook/schema errors |

**Wizard-level pass rate:** 12 PASS · 2 DEGRADED/UNCLEAR · 0 FAIL

---

## B. Regressions and bugs

### B1 — MCP generation skipped despite strong signals  ❌ FAIL

- `onboard-meta.json`:
  ```json
  "mcpStatus": { "status": "skipped", "reason": "no-candidates", "planned": [], "generated": [] }
  ```
- `.mcp.json` **missing** from project root.
- But `onboard/scripts/detect-mcp-signals.sh` on the same repo returns **6 servers**:
  `context7, github, vercel, prisma, supabase, chrome-devtools-mcp`.
- Root cause: the generation path records `reason: "no-candidates"` without running (or after discarding) the detection script. Confirmed: manually running the script from the repo returns populated JSON.
- **Severity:** blocker — Phase 2 artifact checks expect `.mcp.json` with at least context7 + vercel + prisma per PR #35.

### B2 — `wizardStatus` telemetry shape drift  ⚠️ WARN (5 sub-keys)

- Specification (`onboard/skills/wizard/SKILL.md:379-387`):
  ```json
  "wizardStatus": { "presetUsed", "exchangesUsed", "phasesAsked", "phasesSkipped", "escapeHatchTriggered" }
  ```
- Actual emission:
  ```json
  "wizardStatus": { "completed": true, "completedAt": "...", "mode": "interactive", "preset": "custom" }
  ```
- All 5 C4-required sub-keys missing (verify script flags each as a WARN). The wizard emitted *some* telemetry but with different key names — `preset` vs `presetUsed`, nothing for exchanges/phases/escape-hatch.

### B3 — `AskUserQuestion` "Invalid tool parameters" × 2  ⚠️ BUG

- Ecosystem plugins step: only `notify` was offered → single-option multiSelect → `options.minItems: 2` schema rejection.
- LSP + built-in-skills combined step: LSP side had only `typescript-lsp` → same single-option failure.
- Wizard recovered by degrading to sequential single-select questions. Degraded UX but init still completed.
- **Fix direction:** wizard should short-circuit multiSelect → plain single-select yes/no when candidate count is 1, OR always render at least 2 options (e.g. append an explicit `None / Skip` option).

### B4 — Generation cost and latency  ℹ️ NOTE

- 38m 48s wall-clock inside `onboard:config-generator` agent on a 17-file scaffold at Opus xhigh.
- Session cost: ~$12 on this run (`📐 1M tokens · 💰 $12.25` shown in transcript).
- Suggests Custom preset + all-advanced-hooks may over-exercise the generator. Worth measuring Minimal/Standard presets for comparison.

---

## C. Positive findings (regressions prevented)

- **Hook schema** uses nested `hooks: [...]` array (PR #32 compliant). 11 events generated: `ConfigChange, Elicitation, FileChanged, PreCompact, PreToolUse, SessionEnd, SessionStart, SubagentStart, TaskCompleted, TaskCreated, UserPromptSubmit`.
- **Advanced hook execution types** honored: `TaskCreated: agent`, `TaskCompleted: prompt`, others: `command` — matches user selections.
- **Agent frontmatter** complete: `task-clarifier.md`, `db-migration-reviewer.md`, `test-scaffolder.md` — 3/3 have name + description + tools fields (C3 / L6 sweep).
- **Snapshots** all coupled to telemetry status (C1 sweep passed): skill/agent snapshot present with `status=unknown`, mcp snapshot intentionally absent matching `mcpStatus.status="skipped"`.
- **Notify partial install** correctly detected (`~/.claude/notify-config.json` exists but no global hooks) and safely deferred to `/notify:setup` in a fresh session.
- **Dynamic onboard version (L4)** — `pluginVersion: 1.9.0` matches installed plugin.
- **Adaptive session-start reminder** — `plugin-integration-reminder.sh` auto-backs off to 1-liner after 5 fires without brainstorming. Smart.

---

## D. Quality of generated tooling

### Root CLAUDE.md (185 lines)  — Grade: A−

Strengths:
- Project-specific: names exact versions, Prisma-vs-Supabase split, shadcn/CSS-Modules conflict.
- 7 concrete Known Risks with actionable fixes (not-found.tsx build-breaking bug caught, gitignore template included).
- Plugin Integration section framed directively: *"MANDATORY first step for any new feature"* → routes to `/superpowers:brainstorming`.
- Per-phase routing table (Research / Core discipline / Per-feature / Commit / Quality gates / Stack ecosystem / Output styles / Built-in skills / LSP).

Gaps:
- Stack Integration mentions `supabase-postgres-best-practices` skill (not installed locally — reference may 404).
- `.gitignore` suggested but not created (plan-appropriate — generator shouldn't modify repo files outside `.claude/`).

### Hooks (10 files)  — Grade: B+

- `user-prompt-preflight.sh` (UserPromptSubmit) — **only** a secret-literal scanner (AKIA / ghp_ / sk- / Bearer / SUPABASE_SERVICE_ROLE_KEY / DATABASE_URL=postgres). **Does NOT route feature/bug keywords to skills.** See § E.
- `feature-start-detector.sh` (PreToolUse / Write) — well-scoped: new files only, critical dirs (`src/app/api/`, `src/lib/`, `prisma/`), brainstorm-marker aware. Fires a stderr reminder to run `/superpowers:brainstorming` + `/feature-dev:code-architect` before implementation. Solid safety-net.
- `plugin-integration-reminder.sh` (SessionStart) — adaptive: full reminder for first 5 fires, then 1-line pointer. Resets when brainstorm marker is created.
- `task-completed-verify.prompt.md` (TaskCompleted / prompt) — LLM guardrail with inline prompt per user choice.
- Other lifecycle hooks (`session-end.sh`, `pre-compact-checkpoint.sh`, `subagent-start-audit.sh`, `file-changed-notice.sh`, `config-change-warn.sh`, `elicitation-audit.sh`) — advisory, always exit 0, good defensive posture.

Gap: UserPromptSubmit could do keyword-based routing but doesn't (see § E below).

### Rules (6 path-scoped)  — Grade: A

`api.md, commit-conventions.md, components.md, prisma-schema.md, security.md, testing.md` — each with proper YAML `paths:` glob frontmatter. Auto-activate when Claude touches matching files. Content sampled: testing.md includes concrete Vitest config template, co-location convention, AAA pattern, running commands. Specific to project.

### Skills (3 local)  — Grade: A−

`route-handler, prisma-migration, supabase-auth-flow` — aligned 1:1 with user's stated pain points (Phase 4 of wizard). Good scoping.

### Agents (3)  — Grade: A

`task-clarifier` (wired to TaskCreated hook), `db-migration-reviewer`, `test-scaffolder`. All have mandatory frontmatter (name / description / tools). Plugin-aware generation skipped redundant agents covered by feature-dev and pr-review-toolkit.

### Output style (1)

`solo-minimal.md` with frontmatter. Activation via `settings.local.json` per user choice. Not content-reviewed in this pass.

---

## E. Auto-invocation analysis — does typing "build feature XYZ" or "fix bug ABC" auto-route?

**TL;DR:** **Yes, but via plugin-native skill auto-invocation, not via onboard's generated hooks.** Onboard's hooks provide *reinforcement* and *safety nets*, not the primary routing.

### The four layers at play

```
Developer types: "I want to build a login feature"
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 1: UserPromptSubmit hook (onboard-generated)               │
│   user-prompt-preflight.sh                                       │
│   Action: scans prompt for secret literals ONLY                  │
│   Routing for "build feature" keywords: NONE                     │
│   → prompt passes through to Claude unchanged                    │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 2: Claude's context at turn-start                          │
│   (a) Root CLAUDE.md auto-loaded                                 │
│       § Plugin Integration explicitly says:                      │
│         "Any non-trivial change — new feature, schema change,    │
│          auth flow tweak — starts with /superpowers:brainstorming"│
│         "Per-feature workflow → /feature-dev:feature-dev is the  │
│          single entry point for structured feature work."        │
│   (b) Installed plugin skill descriptions auto-loaded            │
│       feature-dev:feature-dev description matches "build feature"│
│       superpowers:brainstorming description matches creative work│
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 3: Claude's routing decision                               │
│   Claude reads (a) the CLAUDE.md directive + (b) skill descs     │
│   → Invokes Skill tool with skill="superpowers:brainstorming"    │
│     OR skill="feature-dev:feature-dev"                           │
│   This is NATIVE Claude Code behavior (not onboard-specific).    │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 4: If Claude skips routing and jumps straight to code:     │
│   SessionStart reminder already fired (once per session):        │
│     "Starting new feature work? Begin with /superpowers:         │
│      brainstorming. See root CLAUDE.md § Plugin Integration."    │
│   PreToolUse feature-start-detector.sh late-fires IF Claude      │
│   tries to Write a new file under src/app/api/, src/lib/, or     │
│   prisma/ without a brainstorm marker, emitting to stderr:       │
│     "[onboard] Consider /superpowers:brainstorming and           │
│      /feature-dev:code-architect before implementation."         │
└──────────────────────────────────────────────────────────────────┘
```

### Direct answer to the question

| Prompt | Will Claude auto-invoke? | Via what mechanism? |
|---|---|---|
| "I want to build feature XYZ" | **Yes, typically** | Skill tool picks `superpowers:brainstorming` (from its description) first, OR `feature-dev:feature-dev`; CLAUDE.md reinforces brainstorming as mandatory |
| "I want to fix bug ABC" | **Yes, typically** | Skill tool picks `superpowers:systematic-debugging` (description literally says "Use when encountering any bug…before proposing fixes"); CLAUDE.md reinforces `systematic-debugging` + `/debug` |
| Implicit prompts (e.g. "add a PATCH handler to /users") | **Probably not at prompt time** — Claude may just code. But the PreToolUse feature-start-detector fires when Claude writes `src/app/api/users/route.ts` as a new file, injecting a stderr reminder. Late safety net kicks in. |

### Where the mechanism is strong

1. **CLAUDE.md directive framing** — using the word MANDATORY gives Claude a clear instruction, not just a suggestion.
2. **Plugin-native skill descriptions** — `superpowers:brainstorming.description` says *"You MUST use this before any creative work"* — this is the primary trigger, independent of onboard.
3. **PreToolUse safety net** — the feature-start-detector catches the case where Claude bypasses brainstorming and jumps straight to writing files in critical directories.
4. **SessionStart adaptive reminder** — plants the routing reminder into every new session's context.

### Where the mechanism is weak

1. **UserPromptSubmit does nothing for routing.** Prompts like "fix bug ABC" or "build feature X" pass through untouched. A stronger design would scan for intent keywords (`build`, `fix`, `debug`, `refactor`) and inject a routing hint *before* Claude begins.
2. **No deterministic gate.** Claude can still skip the directive if it judges the work trivial. There's no hard block on `Write` without a brainstorm marker — only an advisory nudge.
3. **Skill auto-invocation is probabilistic.** It depends on Claude reading the description, matching it to the prompt, and choosing the Skill tool. It's not a deterministic pipeline.

### Recommended improvements (out of scope for this test, but worth noting)

- Make `user-prompt-preflight.sh` dual-purpose: keep the secret scan, add keyword-based routing hints to stderr:
  ```
  prompt ~= /(build|add|implement).*(feature|endpoint|flow|module)/i → emit: "Consider /superpowers:brainstorming then /feature-dev:feature-dev"
  prompt ~= /(fix|debug|investigate).*(bug|error|issue|failure)/i     → emit: "Consider /superpowers:systematic-debugging then /feature-dev:code-reviewer"
  ```
- Optionally upgrade the PreToolUse detector to `decision: "ask"` for the first new-file-in-critical-dir when no brainstorm marker exists — turns the advisory nudge into a confirmation gate.

---

## F. Sign-off recommendation

| Dimension | Status |
|---|---|
| Wizard UX (M1 / C4 / L1 sweep) | ✅ PASS (with 2 minor degrades: A9 unclear, A10 schema fallback) |
| Generated-artifact integrity | ⚠️ 1 FAIL (MCP skipped), 6 WARN (wizardStatus sub-keys) |
| Plugin integration in CLAUDE.md | ✅ Strong — mandatory-framed, routes all work types |
| Auto-invocation behavior | ✅ Works for explicit feature/bug prompts via native skill auto-invoke + CLAUDE.md directive; ⚠️ UserPromptSubmit adds nothing to routing |
| Release readiness (Phase 2 only) | **HOLD** — B1 (MCP skipped) must be fixed before merging develop→main. B2 (wizardStatus shape) and B3 (AskUserQuestion single-option) are follow-up fixes. |

---

## G. Plugin routing audit (empirical verification + cross-plugin scan)

**Triggered by:** Empirical test on 2026-04-17 — developer typed *"I want to build a login feature"* in `test-nextjs`; **`superpowers` fired exclusively; `feature-dev` never fired** despite both being documented in CLAUDE.md § Plugin Integration as part of the feature workflow.

**Method:** Read `description` frontmatter and flow rules of every universal/workflow-category plugin's entry point (command or skill) from `~/.claude/plugins/cache/claude-plugins-official/`, then cross-checked against the generated CLAUDE.md's routing statements.

**Sources consulted (23 files across 9 plugins):**
- `superpowers/5.0.7/skills/{brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion, executing-plans, finishing-a-development-branch}/SKILL.md`
- `feature-dev/unknown/commands/feature-dev.md` + `agents/{code-architect, code-reviewer, code-explorer}.md`
- `code-review/unknown/commands/code-review.md`
- `pr-review-toolkit/unknown/commands/review-pr.md` + `agents/{code-reviewer, silent-failure-hunter, code-simplifier, comment-analyzer, pr-test-analyzer, type-design-analyzer}.md`
- `frontend-design/unknown/skills/frontend-design/SKILL.md`
- `commit-commands/unknown/commands/{commit, commit-push-pr, clean_gone}.md`
- `hookify/unknown/commands/hookify.md` + `skills/writing-rules/SKILL.md`
- `claude-md-management/1.0.0/commands/revise-claude-md.md` + `skills/claude-md-improver/SKILL.md`
- `security-guidance/unknown/` — hooks-only, no commands or skills

### G.1 — Pair-by-pair conflict grid

| Pair | Shared trigger | Grade | Evidence |
|---|---|---|---|
| `superpowers:brainstorming` ↔ `feature-dev` (command) | *"building components / creating features / new feature"* | 🔴 **CONFLICT (confirmed)** | brainstorming.description: *"You MUST use this before any creative work - creating features, building components, adding functionality"*; feature-dev.description: *"Guided feature development"*. brainstorming/SKILL.md:66 hard-forbids invoking any skill other than writing-plans. feature-dev runs 7 phases that functionally duplicate brainstorming's Phases 1-4. |
| `superpowers:brainstorming` ↔ `frontend-design:frontend-design` | *"build web components / building components"* | 🔴 **CONFLICT** | frontend-design.description: *"Use this skill when the user asks to build web components, pages, or applications"* — verbatim overlap with brainstorming's *"creating features, building components"*. Both carry MUST-style imperatives; Claude picks one. |
| `feature-dev` (command) ↔ `frontend-design:frontend-design` | UI feature work | 🔴 **CONFLICT** | feature-dev is a generic feature orchestrator; frontend-design targets the same intent for UI work. No routing rule distinguishes them; CLAUDE.md lists both. |
| `feature-dev:code-reviewer` (agent) ↔ `pr-review-toolkit:code-reviewer` (agent) | code review on recent changes | 🔴 **CONFLICT (name collision)** | Both agents are literally named `code-reviewer`. Descriptions overlap heavily (*"Reviews code for bugs, logic errors, security vulnerabilities"* vs *"review code for adherence to project guidelines, style guides"*). Callers must prefix with plugin name; onboard's generated CLAUDE.md does not explain which to prefer when. |
| `code-review:code-review` ↔ `pr-review-toolkit:review-pr` | PR review | 🟡 **OVERLAP** | code-review.description: *"Code review a pull request"* (command-only, single-pass). review-pr.description: *"Comprehensive PR review using specialized agents"* (command + 6 sub-agents). Same trigger, different depth; CLAUDE.md lists both consecutively without telling Claude when to pick which. |
| `superpowers:writing-plans` ↔ `feature-dev` Phase 4 Architecture Design | multi-step implementation plan | 🟡 **OVERLAP** | writing-plans.description: *"Use when you have a spec or requirements for a multi-step task, before touching code"*; feature-dev Phase 4 performs equivalent work via `code-architect` agents. Neither references the other. |
| `superpowers:test-driven-development` ↔ `feature-dev` Phase 5 Implementation | TDD discipline during feature work | 🟡 **OVERLAP** | test-driven-development.description: *"Use when implementing any feature or bugfix, before writing implementation code"*; feature-dev Phase 5 says *"Build the feature... Write clean, well-documented code"* with zero TDD reference. If feature-dev is driving, TDD does not get invoked from inside it. |
| `superpowers:systematic-debugging` ↔ built-in `/debug` | debugging | 🟡 **OVERLAP** | systematic-debugging.description: *"Use when encountering any bug, test failure"*; built-in `/debug` has very similar trigger surface. CLAUDE.md lists both; out of scope for plugin-vs-plugin audit but noted. |
| `pr-review-toolkit:silent-failure-hunter` ↔ CLAUDE.md `/security-guidance:security-review` | security posture | ⚠️ **DANGLING REFERENCE** | CLAUDE.md references `/security-guidance:security-review` but this slash command **does not exist** — `security-guidance/unknown/` contains only `hooks/` (no `commands/`, no `skills/`). The reference is fabricated. See G.3. |
| `commit-commands:*` ↔ any | git workflow | 🟢 **INDEPENDENT** | commit, commit-push-pr, clean_gone have narrow, tool-specific descriptions (*"Create a git commit"*) that don't overlap with any other plugin's trigger surface. Clean. |
| `hookify:*` ↔ any | hook authoring | 🟢 **INDEPENDENT** | Description constrained to *"create a hookify rule / write a hook rule"* — specific phrase. No overlap. |
| `claude-md-management:*` ↔ any | CLAUDE.md maintenance | 🟢 **INDEPENDENT** | Description constrained to *"check, audit, update, improve, or fix CLAUDE.md files"* — specific. No overlap. |

**Summary: 4 hard conflicts, 4 overlaps, 1 dangling reference, 3 clean.**

### G.2 — Why only `superpowers` fired on "build a login feature"

1. Both `superpowers:brainstorming` and `feature-dev` match the prompt.
2. `superpowers:brainstorming.description` uses *"You MUST"* imperative + explicit keyword *"creating features"*. `feature-dev.description` is descriptive (*"Guided feature development"*). Imperative wins the auto-invoke tiebreak.
3. Once `brainstorming` is invoked, `SKILL.md:66` **forbids** it from invoking anything except `writing-plans`. There is no path back to `feature-dev` from inside the superpowers pipeline.
4. `feature-dev` has no way to be pulled in post-hoc; Claude would have to manually call its sub-agents (`code-architect`, `code-reviewer`) — which the CLAUDE.md does suggest, but only as adjunct tools, not as a parallel pipeline.

**Practical implication:** In any project where `superpowers` is installed, `feature-dev` as a top-level orchestrator is effectively dead code. Its sub-agents remain useful as tactical tools.

### G.3 — Dangling reference: `security-guidance`

Generated `test-nextjs/CLAUDE.md:136`:

> *"`/security-guidance:security-review` or `/security-review` — security audit. Mandatory for any diff touching `src/lib/auth.ts`..."*

Reality:
- `~/.claude/plugins/cache/claude-plugins-official/security-guidance/unknown/` contains only `hooks/` + `LICENSE` + `.claude-plugin/plugin.json`.
- No `commands/`, no `skills/`. The slash command `/security-guidance:security-review` **does not exist**.
- The built-in `/security-review` does exist (visible in available-skills list), so the fallback works.

**Violation:** `onboard/skills/generation/references/plugin-detection-guide.md:115` rule #5 — *"Never fabricate plugin references — if a plugin is not in `installedPlugins`, drop all references to it."* The generator detected security-guidance as installed, then invented a skill namespace for it. Two-part fix: (a) detect the plugin's actual entry surface (commands? skills? hooks-only?) before templating references; (b) when the plugin is hooks-only, surface only the hook behavior, not a fictitious slash command.

### G.4 — Cross-reference: onboard's canonical routing drifts from the generated CLAUDE.md

`plugin-detection-guide.md:133-139` — onboard's canonical `phaseSkills`:

```jsonc
{
  "feature": ["feature-dev:code-architect", "superpowers:test-driven-development"],
  ...
}
```

Canonical design: feature-dev contributes **only** its `code-architect` sub-agent; superpowers contributes TDD. This is a clean split.

Generated `test-nextjs/CLAUDE.md:123`:

> *"`/feature-dev:feature-dev` — the single entry point for structured feature work."*

The generator promoted `feature-dev:feature-dev` (the competing orchestrator) to "single entry point", directly contradicting the canonical design. The generation step drifted from its own reference doc.

### G.5 — Recommendations, priority-ordered

| Priority | Fix | Target file |
|---|---|---|
| 1 (P0) | Stop fabricating slash commands for hooks-only plugins. Check plugin's `commands/` and `skills/` before emitting `/<plugin>:<name>` references. | `onboard/skills/generation/references/claude-md-guide.md` (plugin-integration template) |
| 2 (P1) | When `superpowers` is installed, suppress `feature-dev:feature-dev` as a top-level entry in § Plugin Integration. Keep `feature-dev:code-architect` and `feature-dev:code-reviewer` as adjunct tools. Matches canonical `phaseSkills`. | `claude-md-guide.md` + templating in `generation/SKILL.md` |
| 3 (P1) | When both `code-review` and `pr-review-toolkit` are installed, disambiguate: light review → code-review; heavy review → pr-review-toolkit. Explicit in CLAUDE.md, not left to Claude. | `claude-md-guide.md` |
| 4 (P2) | When `frontend-design` is installed and the project has a frontend framework, frontend-design owns UI feature work; feature-dev is for non-UI feature work. Explicit routing rule. | `claude-md-guide.md` |
| 5 (P2) | Rename the agent name collision: `feature-dev:code-reviewer` and `pr-review-toolkit:code-reviewer` both called `code-reviewer`. Either always use fully-qualified plugin-prefixed names in CLAUDE.md, or add a note explaining the distinction. | `claude-md-guide.md` |
| 6 (P3) | Document the reality that `superpowers:brainstorming` + `superpowers:writing-plans` form a self-contained pipeline that won't invoke external plugins mid-flow. Set expectation explicitly in CLAUDE.md so developers aren't surprised. | `claude-md-guide.md` |

**Highest-priority single fix:** #1 — the dangling `/security-guidance:security-review` reference is a correctness bug (the slash command doesn't exist; invoking it would fail), whereas 2-6 are documentation/routing quality issues. Fix #1 blocks release readiness; the rest should be queued for a post-release onboard release.

### G.6 — Effect on Phase 2 sign-off

Adds one new finding to § F:

| Dimension | Status |
|---|---|
| Plugin reference correctness | ⚠️ **1 dangling reference** (`/security-guidance:security-review`) in generated CLAUDE.md — violates plugin-detection-guide.md rule #5. Not a release blocker on its own (built-in `/security-review` fallback works), but combined with B1 (MCP skipped) strengthens the **HOLD** recommendation on merging develop→main. |

No change to the other Phase 2 dimensions.

