# Changelog

## 1.5.0 — 2026-04-15

### Features

- **Extended skill frontmatter emission**: generation now emits `allowed-tools`, `model`, `effort`, `paths`, `context`, and `agent` on every generated `SKILL.md` in addition to the existing `name` / `description` / `user-invocable` / `disable-model-invocation` surface. Values are computed via archetype classification (research-only / scaffolder / reviewer / orchestrator / workflow-specific — see `skills-guide.md` § Per-archetype defaults) and refined by wizard-level `skillTuning`. Omitted fields preserve pre-feature behavior exactly; pre-upgrade fixtures remain byte-identical.
- **Wizard Phase 5.2 — Skill Tuning (optional, default No)**: one opt-in gate followed by three project-level questions (default model tier, default effort, pre-approval posture). Quick Mode skips Phase 5.2 and emits archetype defaults.
- **Batched confirmation before emission**: the generator presents every candidate skill's computed frontmatter in a single table. Options: *Accept all* (default — keeps headless / Quick Mode frictionless), *Tweak skill N*, *Skip skill N*. Per-skill provenance is recorded as `source ∈ {inferred, wizard-default, user-confirmed, user-tweaked}`.
- **`skillStatus` telemetry**: new field in `onboard-meta.json`, parallel to `hookStatus` and `mcpStatus`. Tracks `planned` / `generated` / `skipped` / `frontmatterFields` / `existedPreOnboard` / `warnings`. Mirrored into `forge-meta.json` by `evolve` Step 2b.3.
- **Drift snapshot**: `.claude/onboard-skill-snapshot.json` is the byte-diffable baseline onboard writes alongside skill emission. Used by `update` / `evolve` for drift detection.
- **Drift contract in `onboard:update` (Step 4b.5) and `onboard:evolve` (Step 2d)**: diffs live `SKILL.md` frontmatter against the snapshot. User hand-edits are preserved (evolve's default verb is `accept-user-edit`); missing-file regeneration and new-field additions apply on approval (update) or automatically (evolve).
- **`callerExtras.disableSkillTuning` escape hatch**: headless callers (forge) can suppress the batched confirmation entirely. Archetype + wizard defaults emit directly.

### Documentation

- `references/skills-guide.md`: new § Frontmatter Reference with full field surface, archetype table, posture clamps, two worked example blocks (research-only reviewer, scaffolder); 4 existing example skills updated to show realistic frontmatter; new § Frontmatter Emission Rules at end of file.
- `skills/generation/SKILL.md`: Phase 4 Skills section extended with new § Skill Frontmatter Emission (7 numbered steps) and `skillStatus` schema.
- `skills/generate/SKILL.md`: `callerExtras.disableMCP` and `callerExtras.disableSkillTuning` documented in context schema; `wizardAnswers.skillTuning` added; `skillStatus` added to results summary and `onboard-meta.json` metadata list.
- `skills/wizard/SKILL.md`: new Phase 5.2 with opt-in gate + three project-level questions; Output JSON extended with `skillTuning`.
- `skills/update/SKILL.md`: new Step 4b.5 (classify) + Step 7 skill frontmatter drift application + Step 8 `skillStatus` refresh.
- `skills/evolve/SKILL.md`: new Step 2d (auto-apply rules) + Step 2b.3 forge-meta mirror extended to include `skillStatus`.
- `forge/skills/tooling-generation/SKILL.md`: docs-only note that extended skill frontmatter flows through onboard delegation; `toolingFlags` schema extended to mirror `skillStatus`.

## 1.4.0 — 2026-04-15

### Features

- **`.mcp.json` generation from stack signals (Phase 7a)**: generation pipeline now emits `.mcp.json` and `.claude/onboard-mcp-snapshot.json` when detected stack signals match the catalog. Initial 6-entry catalog: `context7` (always, any project), `github` (when `.github/workflows/` present), `vercel` (when `vercel.json` or `@vercel/*` dep), `prisma` (when `prisma/` dir or `@prisma/client` dep), `supabase` (when `@supabase/*` dep or `supabase/` dir), `chrome-devtools-mcp` (when frontend framework detected). Forge inherits automatically via `onboard:generate` delegation.
- **`.claude/rules/mcp-setup.md` auto-emission**: project-scoped rule listing per-server auth requirements (env vars, `claude mcp auth <name>` OAuth flows). Generated only when needed (any server requires auth OR pre-existing `.mcp.json` detected).
- **Plugin auto-install for emitted MCPs**: `scripts/install-mcp-plugins.sh` probes `claude plugin list --json` and installs only missing plugins. Never fails Phase 7a on install errors — failures are telemetry, not blockers.
- **`mcpStatus` telemetry**: new field in `onboard-meta.json`, parallel to `hookStatus`. Tracks `planned` / `generated` / `skipped` / `autoInstalled` / `autoInstallFailed` / `existedPreOnboard`. Mirrored into `forge-meta.json` by `evolve` Step 2b.3.
- **MCP drift contract in `onboard:update` (Step 4b.4) and `onboard:evolve` (Step 2c)**: compares `.mcp.json` vs `.claude/onboard-mcp-snapshot.json` vs fresh signal scan. Additions auto-apply on approval (or automatically in evolve); user edits and removals are informational only — never rewritten.
- **`callerExtras.disableMCP` escape hatch**: headless callers (forge) can suppress Phase 7a entirely when the scaffold template already ships an `.mcp.json`.

### Documentation

- `references/plugin-detection-guide.md`: probe table extended with `MCP Server` / `Transport` / `Auth` columns; added `MCP Auto-Emit Signals` section mapping stack fingerprints to servers with confidence tiers.
- `references/mcp-guide.md` (new): emission rules, catalog shape, drift-snapshot pattern, auto-install contract, post-emit stdout summary, inline `mcp-setup.md` template.
- `skills/generation/SKILL.md`: new Phase 7a section (8 numbered steps) between Recommended Plugins and Hooks; 9 new checklist items for MCP emission.
- `skills/update/SKILL.md` and `skills/evolve/SKILL.md`: drift steps + metadata refresh for `mcpStatus`.
- `agents/config-generator.md`: new steps 6a and 8 for MCP emission and auto-install.
- `forge/skills/tooling-generation/SKILL.md`: docs-only note that `.mcp.json` flows through onboard delegation, mentions `callerExtras.disableMCP`.

## 1.3.0 — 2026-04-15

### Features

- **Hook event coverage expansion**: generated tooling now covers 14+ Claude Code hook events (previously 5). Added: `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `SubagentStart`, `TaskCreated`, `TaskCompleted`, `FileChanged`, `ConfigChange`, `Elicitation`. Wizard Phase 5.1 lets developers opt in; inference rules auto-emit safe defaults.
- **Hook type support — `prompt` / `agent` / `http`**: generation now emits all four Claude Code hook types (previously `command` only). `prompt` unlocks LLM-evaluated guardrails, `agent` wires subagents (e.g., code-reviewer) into `TaskCompleted`, `http` enables compliance/SIEM integration via POST-to-URL. Caller schema extended with per-entry `hookType` / `promptRef` / `promptInline` / `agentRef` / `httpUrl` / `httpHeaders` / `timeout` fields. Wizard Phase 5.1.1 asks developers which execution type per judgment-capable event.
- **`hookStatus` telemetry extended**: keys now use `<Event>[:<Matcher>][:<Type>]` format. Type suffix omitted for `command` — fully backward compatible with pre-upgrade fixtures. `generated[<key>]` holds type-appropriate artifact (script basename / prompt filename / agent name / URL).
- **Safety rules enforced**: `prompt`/`agent` refused on per-tool-call events; `http` requires explicit `callerExtras.allowHttpHooks: true` + https-only URLs; 11 structured skip reasons recorded in `hookStatus.skipped[]`.
- **Default prompt library**: ships one prompt template (`user-prompt-secret-scan.md`) used by the inference path when `securitySensitivity === "high"`.

### Documentation

- `references/hooks-guide.md`: new § "Hook Types Reference" + § "Type Variants Per Event" with canonical JSON shapes, cost/latency matrix, response-format rules.
- `skills/generate/SKILL.md` and `skills/generation/SKILL.md`: new § "Hook Type Validation" with the 11-rule validator and skip reasons.
- `skills/wizard/SKILL.md`: new Phase 5.1.1 documentation with cost-table preamble and HTTP opt-in confirmation.

### Bug Fixes

- **Harden `task-completed-verify.sh` template**: drop the `eval "${CLAUDE_TEST_COMMAND:-}"` pattern in favor of a literal `__TEST_CMD__` placeholder substituted at generation time. `eval` was unnecessary (word-splitting already handles multi-token test commands) and the invented env-var fallback opened an arbitrary-command-execution path if consumers copied the template verbatim. Generation now skips the hook entirely when no test command is detected instead of emitting an advisory no-op. Addresses auto-security-review Medium finding on PR #34.
- **Add `jq`/`grep`/`sed` fallback to Rustfmt, ESLint, and Ruff Lint templates**: three PostToolUse format/lint templates in `references/hooks-guide.md` were the only ones still invoking `jq` without the fallback chain used by every other template. They now match the fallback-safe pattern, so the hooks remain functional on systems without `jq` installed.

## [1.2.0](https://github.com/ApurvBazari/claude-plugins/compare/onboard-v1.1.0...onboard-v1.2.0) (2026-04-14)


### Features

* **onboard:** native plugin detection + generation quality fixes ([#16](https://github.com/ApurvBazari/claude-plugins/issues/16)) ([77b54ac](https://github.com/ApurvBazari/claude-plugins/commit/77b54ac06c69b515912f994074ce4ec2a857ec47))


### Bug Fixes

* security audit hardening from PR [#18](https://github.com/ApurvBazari/claude-plugins/issues/18) findings ([#19](https://github.com/ApurvBazari/claude-plugins/issues/19)) ([e5df20b](https://github.com/ApurvBazari/claude-plugins/commit/e5df20b64b860a33d79b070c2ccda7cf95ae7b62))

## 1.1.0

### Features

- **Native plugin detection** (#16): `/onboard:init` now probes for installed Claude Code plugins and generates the full Plugin Integration section, quality-gate hooks, per-directory skill annotations, and plugin-aware agent skipping — previously only available via forge headless mode
- **Architecture-aware subdirectory CLAUDE.md** (#16): Recognized architecture patterns (Clean Architecture, MVVM, Hexagonal, etc.) are automatic candidates for subdirectory CLAUDE.md, with profile-scaled file-share thresholds
- **Standalone quality-gate hooks** (#16): Generate SessionStart, preCommit, featureStart, postFeature hooks in standalone mode driven by profile + autonomy level
- **Dynamic version resolution** (#16): Maintenance headers now read the current version from `plugin.json` instead of using hardcoded examples

### Bug Fixes

- **Hardened Python string interpolation** in detection scripts (#19): All `python3 -c "..."` blocks in `detect-*.sh` scripts now pass paths via `sys.argv` instead of interpolating into Python source

## 1.0.0

Initial release.

- Interactive wizard with adaptive Q&A and preset profiles (Minimal / Standard / Comprehensive / Custom)
- Codebase analyzer agent (read-only) with `analyze-structure.sh`, `detect-stack.sh`, `measure-complexity.sh` scripts
- Config generator agent producing root + subdirectory CLAUDE.md files, path-scoped rules, project-specific skills, agents, hooks, and PR templates
- Headless generation mode (`/onboard:generate`) for programmatic consumers like forge
- Plugin-aware agent generation via `coveredCapabilities` — skips generating agents whose capability is already covered by an installed plugin
- Quality-gate hook generation: SessionStart reminders, feature-start detector, pre-commit blocking, post-feature advisory
- Adaptive SessionStart reminder suppression (counter-based, resets on brainstorming)
- Enriched mode: CI/CD pipelines, harness artifacts, auto-evolution hooks, sprint contracts
- `/onboard:update` for aligning with latest best practices
- `/onboard:evolve` for applying pending drift updates
- `/onboard:verify` for independent feature verification via feature-evaluator agent
- Supports Node.js/TypeScript, Python, Go, Rust, Ruby, monorepos, and mixed-language projects
