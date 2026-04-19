# Changelog

## [1.10.0](https://github.com/ApurvBazari/claude-plugins/compare/onboard-v1.9.0...onboard-v1.10.0) (2026-04-19)


### Features

* add development tooling ecosystem for plugin authoring ([4238a32](https://github.com/ApurvBazari/claude-plugins/commit/4238a3299895101494088943015f7102681c7451))
* add development tooling ecosystem for plugin authoring ([782413d](https://github.com/ApurvBazari/claude-plugins/commit/782413d07fa7a1fed9f1cd02a7dc613fe91a94e0))
* add marketplace manifest and bump plugins to v1.0.0 ([9175afb](https://github.com/ApurvBazari/claude-plugins/commit/9175afb1559a756b6593a3cd3585e499e37567ac))
* **forge,onboard:** Plugin Integration upgrade + D1/D2 deferred items ([#11](https://github.com/ApurvBazari/claude-plugins/issues/11)) ([9e96fbb](https://github.com/ApurvBazari/claude-plugins/commit/9e96fbb74239192733874ec60d36d53d0c51cef3))
* **forge:** add forge plugin + onboard headless mode ([#7](https://github.com/ApurvBazari/claude-plugins/issues/7)) ([cae3b92](https://github.com/ApurvBazari/claude-plugins/commit/cae3b929258e4e645c1aaf42e3904e9433ebc9c8))
* **forge:** resume protocol and inline prerequisite handling ([#10](https://github.com/ApurvBazari/claude-plugins/issues/10)) ([2403130](https://github.com/ApurvBazari/claude-plugins/commit/2403130cbf1d14769a3ebee238b542123def6867))
* **onboard:** built-in Claude Code skill recommendations (1.9.0) ([#39](https://github.com/ApurvBazari/claude-plugins/issues/39)) ([770cdc7](https://github.com/ApurvBazari/claude-plugins/commit/770cdc7b70144a93f395edc293c06d88e5585a12))
* **onboard:** detect plugin/artifact drift in onboard:update ([#33](https://github.com/ApurvBazari/claude-plugins/issues/33)) ([46a7097](https://github.com/ApurvBazari/claude-plugins/commit/46a70977dcd630c1be06ddf89f93ab685ac1f2ec))
* **onboard:** emit extended agent frontmatter (1.6.0) ([#36](https://github.com/ApurvBazari/claude-plugins/issues/36)) ([5dd316d](https://github.com/ApurvBazari/claude-plugins/commit/5dd316d0174cef9b967929deb7f30451772e4997))
* **onboard:** emit project-scoped custom output styles (1.7.0) ([#37](https://github.com/ApurvBazari/claude-plugins/issues/37)) ([a73bd8b](https://github.com/ApurvBazari/claude-plugins/commit/a73bd8bc775676d42f8e4b25c94db0fae7eece02))
* **onboard:** enforce TDD as the only testing approach ([#8](https://github.com/ApurvBazari/claude-plugins/issues/8)) ([af9fa0f](https://github.com/ApurvBazari/claude-plugins/commit/af9fa0ff5e57184e0288b8564d99330047d2f820))
* **onboard:** expand hook coverage to 14+ events and 4 execution types ([#34](https://github.com/ApurvBazari/claude-plugins/issues/34)) ([1cce41f](https://github.com/ApurvBazari/claude-plugins/commit/1cce41f3b13ac74701339ac586e3dba5a8fc14ae))
* **onboard:** generate .mcp.json from detected stack signals ([#35](https://github.com/ApurvBazari/claude-plugins/issues/35)) ([e1a269e](https://github.com/ApurvBazari/claude-plugins/commit/e1a269e856c1710b5d95a881f73f257f105766b4))
* **onboard:** LSP plugin recommendations (1.8.0) ([#38](https://github.com/ApurvBazari/claude-plugins/issues/38)) ([9a8d183](https://github.com/ApurvBazari/claude-plugins/commit/9a8d1830e2ad1cc054d528238148794438d5a357))
* **onboard:** native plugin detection + generation quality fixes ([#16](https://github.com/ApurvBazari/claude-plugins/issues/16)) ([77b54ac](https://github.com/ApurvBazari/claude-plugins/commit/77b54ac06c69b515912f994074ce4ec2a857ec47))
* **onboard:** proactive worktree support via Claude Code native tools ([#12](https://github.com/ApurvBazari/claude-plugins/issues/12)) ([1571702](https://github.com/ApurvBazari/claude-plugins/commit/15717021907df8cf9ce27e83980f6264f17d1044))
* plugin ecosystem integration — cross-plugin wiring, intelligence, and foundation ([#6](https://github.com/ApurvBazari/claude-plugins/issues/6)) ([06e9f33](https://github.com/ApurvBazari/claude-plugins/commit/06e9f3312300f60a4f4abbad393539d20ab989e2))


### Bug Fixes

* address all 29 medium-priority audit items across all plugins ([0edd5f8](https://github.com/ApurvBazari/claude-plugins/commit/0edd5f83ddbb9d837a281fe1c15adbad2abb0f27))
* address remaining high-priority audit items across all plugins ([5ef654f](https://github.com/ApurvBazari/claude-plugins/commit/5ef654f935c8334b24a2c7731dd172d2822545b7))
* address security audit findings from PR [#30](https://github.com/ApurvBazari/claude-plugins/issues/30) ([#31](https://github.com/ApurvBazari/claude-plugins/issues/31)) ([d970691](https://github.com/ApurvBazari/claude-plugins/commit/d9706915f999f44f77a900bae8ba1f5c9714a392))
* **onboard:** correct canonical hook schema in generation references ([#32](https://github.com/ApurvBazari/claude-plugins/issues/32)) ([97d91ce](https://github.com/ApurvBazari/claude-plugins/commit/97d91ce32a7b8ceb8f0130848b44a399e4477563))
* release-43 security hardening + bot-scope expansion (9 findings, 13 commits) ([#44](https://github.com/ApurvBazari/claude-plugins/issues/44)) ([a048d39](https://github.com/ApurvBazari/claude-plugins/commit/a048d39242e7fa52c5fd64d65f1893cd6d7a351f))
* release-gate v2 sweep — close 17 findings across 1.9.1 + 1.10.0 bundles ([#41](https://github.com/ApurvBazari/claude-plugins/issues/41)) ([9b3c46f](https://github.com/ApurvBazari/claude-plugins/commit/9b3c46f0cdb3129071fcbd405afc78d24318d28c))
* resolve critical bugs and high-priority issues across all plugins ([9809b4c](https://github.com/ApurvBazari/claude-plugins/commit/9809b4ce4280e4f82467b13da99d277d1cc8c7ee))
* resolve ShellCheck errors in CI validation ([ac2868f](https://github.com/ApurvBazari/claude-plugins/commit/ac2868ff05e75bdc6d25c0b01678b5e12bc99759))
* security audit hardening from PR [#18](https://github.com/ApurvBazari/claude-plugins/issues/18) findings ([#19](https://github.com/ApurvBazari/claude-plugins/issues/19)) ([e5df20b](https://github.com/ApurvBazari/claude-plugins/commit/e5df20b64b860a33d79b070c2ccda7cf95ae7b62))

## 1.8.0 — 2026-04-16

### Features

- **LSP plugin recommendations (Phase 7c)**: generation now detects project languages via `scripts/detect-lsp-signals.sh` (12-entry language→plugin catalog covering TypeScript, Go, Rust, C/C++, C#, Java, Kotlin, Lua, PHP, Python, Ruby, Swift) and offers matching marketplace LSP plugins through a new wizard step. Onboard does NOT emit project-level `.lsp.json` — LSP config lives inside each `-lsp` plugin's own `plugin.json` under `lspServers`. Installing the right plugin is the complete story.
- **Wizard Phase 5.6 — LSP Plugins (when any detected)**: one `AskUserQuestion` multiSelect presenting each detected candidate sorted by fileCount desc. Entries with `fileCount ≥ 10` pre-checked; lower entries unchecked to quietly nudge against polyglot noise. Headless callers can pass `callerExtras.lspPlugins` (explicit accept list) or `callerExtras.disableLSP: true` (skip entirely).
- **Metadata-first install ordering (mirrors Phase 7a)**: install invocation runs AFTER `onboard-meta.json` write. If `claude plugin install` hangs or errors, `lspStatus` telemetry is already persisted.
- **`lspStatus` telemetry**: new field in `onboard-meta.json`, parallel to `mcpStatus` / `skillStatus` / `agentStatus` / `outputStyleStatus`. Tracks `planned` / `accepted` / `generated` / `skipped` / `autoInstalled` / `autoInstallFailed` / `alreadyInstalled`.
- **Drift snapshot**: `.claude/onboard-lsp-snapshot.json` with shape `{ recommended: [...], accepted: [...] }`. Pure JSON, no maintenance header — machine-owned baseline for `update` / `evolve`. Stable diff target independent of `onboard-meta.json` edits.
- **Drift contract in `onboard:update` (Step 4b.8) and `onboard:evolve` (Step 2g)**: classifies candidates as `newLanguage` / `uninstalled` / `stillValid` / `staleCandidate`. Only `newLanguage` additions are applied on approval. Uninstalls and stale candidates are informational — onboard never auto-reinstalls or auto-removes. Evolve re-prompts (never silent install) to honor the wizard-driven opt-in posture.
- **`callerExtras.disableLSP` + `callerExtras.lspPlugins` escape hatches**: headless callers (forge) can suppress Phase 7c entirely or pass an explicit install list. Forge default: `disableLSP: true` (scaffolded projects have placeholder code; LSP prompts are premature). Forge handoff message nudges developers toward `/onboard:evolve` after they add real source files.
- **CLAUDE.md "LSP support" subsection**: Plugin Integration section gains a small subsection listing installed LSP plugins and their language-server binary install prereqs (pulled from the catalog). Omitted when no candidates detected.

### Documentation

- **New** `references/lsp-plugin-catalog.md`: 12-row authoritative table mapping language → marketplace plugin → extensions → language-server binary → install prereq. Covers rename/deprecation handling and signal strictness rationale.
- `skills/generation/SKILL.md`: new § LSP Plugin Recommendations — Phase 7c (7 numbered steps) between Phase 7b (Output Styles) and Hooks section.
- `skills/generate/SKILL.md`: `callerExtras.disableLSP` + `callerExtras.lspPlugins` documented.
- `skills/wizard/SKILL.md`: new Phase 5.6 with fileCount-sorted multiSelect; output JSON extended with `lspPlugins`.
- `skills/update/SKILL.md`: new Step 4b.8 (classify) + Step 5 findings report section + Step 7 LSP drift application + Step 8 `lspStatus` refresh.
- `skills/evolve/SKILL.md`: new Step 2g (re-prompt for `newLanguage`, never silent install) + Step 2b.3 forge-meta mirror extended with `outputStyleStatus` (entry 9) and `lspStatus` (entry 10) + Step 3 diff-display example extended.
- `references/claude-md-guide.md`: new § LSP Support Reference subsection.
- `forge/skills/tooling-generation/SKILL.md`: docs-only note that LSP recommendations flow through onboard delegation; **functional changes** — Step 1 `callerExtras` template now sets `disableLSP: true`; Step 4 `toolingFlags` mirror schema extended with `mcpStatus`, `outputStyleStatus`, `lspStatus` (previously only `hookStatus` / `skillStatus` / `agentStatus` were documented — consistency fix).

### Internal refactors

- **Renamed `scripts/install-mcp-plugins.sh` → `scripts/install-plugins.sh` (BREAKING INTERNAL)** — the installer is language-agnostic and now shared between Phase 7a (MCP) and Phase 7c (LSP). The rename committed as a standalone prep commit before the LSP feature landed. All 7 call sites updated for audit trail:
  - `onboard/skills/generation/SKILL.md` (line 571)
  - `onboard/skills/generation/references/mcp-guide.md` (line 82)
  - `onboard/agents/config-generator.md` (line 78)
  - `onboard/skills/update/SKILL.md` (lines 398, 449)
  - `onboard/skills/evolve/SKILL.md` (line 139)
  - `onboard/CHANGELOG.md` (historical 1.4.0 entry flagged with rename)

## 1.7.0 — 2026-04-16

### Features

- **Output style generation (Phase 7b)**: generation now emits one project-scoped custom output style at `.claude/output-styles/<name>.md` based on 5 archetypes inferred from existing wizard + analysis signals (onboarding / teaching / production-ops / research / solo). Priority resolution when multiple fire: `production-ops > onboarding > teaching > research > solo`. Built-in styles (`Default` / `Explanatory` / `Learning`) are Anthropic-provided and referenced in the generated CLAUDE.md Plugin Integration section — never re-emitted as files.
- **Wizard Phase 5.4 — Output Style Tuning (optional, default No)**: one opt-in gate followed by two project-level questions (archetype override, activation default). Quick Mode skips Phase 5.4 and emits archetype defaults. Exchange budget guard: auto-skip to defaults if prior phases exhausted the 6-exchange budget.
- **Batched confirmation before emission**: Phase 7b presents the emitted style's computed frontmatter and options: *Accept* (default — keeps headless / Quick Mode frictionless), *Override archetype*, *Skip emit*. Per-style provenance recorded as `source ∈ {inferred, wizard-default, user-confirmed, user-tweaked}`.
- **`outputStyleStatus` telemetry**: new field in `onboard-meta.json`, parallel to `mcpStatus` / `skillStatus` / `agentStatus`. Tracks `planned` / `generated` / `skipped` / `frontmatterFields` / `activationDefault` / `settingsLocalWritten` / `settingsLocalWarning` / `existedPreOnboard` / `warnings`.
- **Drift snapshot**: `.claude/onboard-output-style-snapshot.json` is the byte-diffable baseline onboard writes alongside style emission. Frontmatter-only scope — body edits (system-prompt prose) are intentionally outside the snapshot and never flagged as drift. Multi-run accumulation: the snapshot appends new entries when archetypes change across runs.
- **`settings.local.json` activation with 4-case merge safety**: when `activationDefault: "write-to-settings"`, Phase 7b merges `"outputStyle": "<name>"` into `.claude/settings.local.json` following strict rules — (1) file missing → warn `file-missing`, never create; (2) key absent → add, preserve all others; (3) same value → no-op + `already-set-to-same`; (4) different value → block + `conflict:<existing>`. Invariants: never create the file, never overwrite an existing `outputStyle`.
- **Drift contract in `onboard:update` (Step 4b.7) and `onboard:evolve` (Step 2f)**: diffs live output-style frontmatter against the snapshot. New classification `legacy-no-frontmatter` covers hand-authored styles without YAML frontmatter — update prompts before migrating, evolve auto-migrates using catalog archetype defaults for any filename stem matching the 5-style catalog. User hand-edits are preserved (evolve's default verb is `accept-user-edit`).
- **`callerExtras.disableOutputStyleTuning` escape hatch**: headless callers (forge) can suppress the Phase 7b batched confirmation entirely. Archetype inference emits the matched style directly.

### Documentation

- **New** `references/output-styles-guide.md`: authoritative reference — what output styles are, archetype inference table, priority resolution, frontmatter schema, `settings.local.json` 4-case merge rules, snapshot contract, drift state machine, interaction with built-in styles.
- **New** `references/output-styles-catalog.md`: 5 body templates (`onboarding-mentor`, `tutorial-guide`, `operator`, `explorer-notes`, `solo-minimal`) with per-style purpose, frontmatter, and structured body template.
- `skills/generation/SKILL.md`: new § Output Styles — Phase 7b (11 numbered steps) between Phase 7a (MCP) and Hooks section; Plugin Integration content rule #7 (Output styles) added; acceptance criteria extended with 10 Phase 7b checks.
- `skills/generate/SKILL.md`: `callerExtras.disableOutputStyleTuning` documented alongside `disableMCP` / `disableSkillTuning` / `disableAgentTuning`.
- `skills/wizard/SKILL.md`: new Phase 5.4 with opt-in gate + two project-level questions; Output JSON extended with `outputStyleTuning`; exchange-budget guard documented.
- `skills/update/SKILL.md`: new Step 4b.7 (classify) + Step 5 findings report section + Step 7 output-style drift application with `legacy-no-frontmatter` catalog-match migration + Step 8 `outputStyleStatus` refresh.
- `skills/evolve/SKILL.md`: Guard extended to probe output-style snapshot + new Step 2f (auto-apply rules including legacy migration via catalog match) + Step 3 diff-display example extended.
- `references/claude-md-guide.md`: new § Output Styles Reference subsection pointing to `output-styles-guide.md` and `output-styles-catalog.md`.
- `forge/skills/tooling-generation/SKILL.md`: docs-only note that output-style generation flows through onboard delegation; **functional change** — Step 1 `callerExtras` template now explicitly sets `disableOutputStyleTuning: true` (alongside `disableSkillTuning` / `disableAgentTuning`) for headless runs.

### Hardening (shipped alongside 1.7.0)

Three pre-existing shell-script findings were surfaced by the 1.7.0 security audit and hardened in the same release:

- `onboard/scripts/audit-tooling.sh`: replaced unquoted `ls $rule_path` glob probe with bash builtin `compgen -G "$rule_path"` — no unquoted shell expansion, no external `ls` call, dropped the `# shellcheck disable=SC2086` comment.
- `onboard/scripts/detect-dep-changes.sh`, `detect-config-changes.sh`, `detect-structure-changes.sh`: added defensive `case` guard after the empty-check — rejects option-flag-looking input or shell metacharacters. Hook-script contract preserved (always `exit 0`).
- `notify/scripts/notify.sh`: replaced non-atomic `echo > "$TIMESTAMP_FILE"` with `mktemp` + `mv -f` atomic rename pattern. Closes the TOCTOU window between the existing symlink guard and the write.

None of these findings were introduced by 1.7.0 — all three are defensive hardening that ships with the release because the audit ran against this branch.

## 1.6.0 — 2026-04-15

### Features

- **Extended agent frontmatter emission**: generation now emits `tools`, `disallowedTools`, `model`, `effort`, `isolation`, `color`, `maxTurns`, and `permissionMode` on every generated agent in addition to the existing `name` / `description` surface. Values are computed via archetype classification (reviewer / validator / generator / architect / researcher — see `agents-guide.md` § Per-archetype defaults) and refined by wizard-level `agentTuning`. Omitted fields preserve pre-feature behavior exactly; pre-upgrade fixtures remain byte-identical. Audit-line clarifications: `proactive` is NOT a frontmatter field (encoded via description prefix per archetype); `isolation` only accepts `worktree`; `color` must be one of `red/blue/green/yellow/purple/orange/pink/cyan`.
- **Wizard Phase 5.3 — Agent Tuning (optional, default No)**: one opt-in gate followed by four project-level questions (default model tier, default effort, pre-approval posture, default isolation). Quick Mode skips Phase 5.3 and emits archetype defaults.
- **Batched confirmation before emission**: the generator presents every candidate agent's computed frontmatter in a single table. Options: *Accept all* (default — keeps headless / Quick Mode frictionless), *Tweak agent N*, *Skip agent N*. Per-agent provenance is recorded as `source ∈ {inferred, wizard-default, user-confirmed, user-tweaked}`.
- **`agentStatus` telemetry**: new field in `onboard-meta.json`, parallel to `skillStatus`. Tracks `planned` / `generated` / `skipped` / `frontmatterFields` / `existedPreOnboard` / `warnings`.
- **Drift snapshot**: `.claude/onboard-agent-snapshot.json` is the byte-diffable baseline onboard writes alongside agent emission. Used by `update` / `evolve` for drift detection.
- **Drift contract in `onboard:update` (Step 4b.6) and `onboard:evolve` (Step 2e)**: diffs live agent frontmatter against the snapshot. New classification `legacy-no-frontmatter` covers pre-1.6.0 agents using markdown-sections format — update prompts before migrating, evolve auto-migrates using archetype inference. User hand-edits are preserved (evolve's default verb is `accept-user-edit`).
- **`callerExtras.disableAgentTuning` escape hatch**: headless callers (forge) can suppress the batched confirmation entirely. Archetype + wizard defaults emit directly.

### Documentation

- `references/agents-guide.md`: full rewrite. New § Frontmatter Reference with 10-field surface, 5-archetype inference table, posture clamps, isolation-default rules, 5 worked example blocks (one per archetype); 6 common-agent templates rewritten to use YAML frontmatter; new § Frontmatter Emission Rules at end of file.
- `skills/generation/SKILL.md`: new § Agent Frontmatter Emission (7 numbered steps) mirroring the skill-frontmatter pipeline, placed alongside the existing `### Agents (.claude/agents/)` section.
- `skills/generate/SKILL.md`: `callerExtras.disableAgentTuning` documented in context schema; `wizardAnswers.agentTuning` added.
- `skills/wizard/SKILL.md`: new Phase 5.3 with opt-in gate + four project-level questions; Output JSON extended with `agentTuning`.
- `skills/update/SKILL.md`: new Step 4b.6 (classify) + Step 7 agent frontmatter drift application with `legacy-no-frontmatter` migration prompt + Step 8 `agentStatus` refresh.
- `skills/evolve/SKILL.md`: new Step 2e (auto-apply rules including legacy migration) + Step 3 diff-display example extended.
- `agents/config-generator.md`: bullet 5 (Agents) rewritten to describe archetype classification, wizard tuning composition, validation, batched confirmation, and snapshot writing. Bullet 7 (Metadata) extended to include `agentStatus` and `.claude/onboard-agent-snapshot.json`.
- `forge/skills/tooling-generation/SKILL.md`: docs-only note that extended agent frontmatter flows through onboard delegation; mirrors the skill-tuning precedent.

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
- **Plugin auto-install for emitted MCPs**: `scripts/install-plugins.sh` (renamed from `install-mcp-plugins.sh` in 1.8.0) probes `claude plugin list --json` and installs only missing plugins. Never fails Phase 7a on install errors — failures are telemetry, not blockers.
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
