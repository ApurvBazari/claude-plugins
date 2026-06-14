<!-- Extracted from generation/SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Generation Quality Checklist

## Quality Checklist

Before finishing generation, verify:

- [ ] Root CLAUDE.md is 100-200 lines and includes all key commands
- [ ] All file paths in rules frontmatter actually exist in the project
- [ ] No duplicate information across CLAUDE.md files and rules
- [ ] Maintenance headers are on every generated file
- [ ] Skills reference patterns that actually exist in the codebase
- [ ] Agent tool lists include only tools they need
- [ ] Hooks reference tools that are actually installed
- [ ] settings.json is merged, not overwritten (if it existed)
- [ ] onboard-meta.json is complete and accurate
- [ ] PR template exists with stack-appropriate checklist items
- [ ] Commit conventions rule matches `codeStyleStrictness` level
- [ ] Root CLAUDE.md includes shared vs local settings guidance
- [ ] Rules reflect actual config settings, not generic defaults
- [ ] Formatter-enforced settings are in CLAUDE.md Key Conventions, not duplicated in rules
- [ ] Observed codebase patterns are captured in architectural rules
- [ ] testing.md rule mandates test-first development (red-green-refactor)
- [ ] If superpowers installed: no standalone TDD skill generated (would conflict)
- [ ] If superpowers NOT installed: standalone TDD skill + TDD test-writer agent exist
- [ ] If any plugin missing: CLAUDE.md includes "Recommended Plugins" section with install commands
- [ ] Maintenance headers use version from plugin.json, not hardcoded values
- [ ] Architecture pattern layers from analysis report are included as subdirectory CLAUDE.md candidates
- [ ] File share thresholds reflect the selected profile (comprehensive = halved, minimal = doubled)
- [ ] Standalone quality-gate hooks match profile + autonomyLevel (comprehensive → all four, standard → SessionStart only, minimal → none)
- [ ] Standalone hooks do not reference plugin skills (no `/superpowers:*`, no `code-review:*`)
- [ ] Standalone preCommit hook uses project's actual test command from analysis
- [ ] effectivePlugins resolution works for all three scenarios: headless (callerExtras), standalone with plugins (self-detected), standalone without plugins (none)
- [ ] Plugin Integration section generates in standalone mode when plugins are self-detected
- [ ] Plugin-referencing quality-gate hooks generated when effectiveQualityGates is present (regardless of entry point)
- [ ] onboard-meta.json records pluginSource
- [ ] onboard-meta.json.detectedPlugins is populated unconditionally (from effectivePlugins resolution), including headless runs — empty object is valid but the field must exist
- [ ] If both plugins installed: no "Recommended Plugins" section in CLAUDE.md
- [ ] CLAUDE.md "Development Workflow" references match actually installed plugins (no dangling refs)
- [ ] PR template includes TDD checklist item ("Tests written first, all pass")
- [ ] No stale references to `minimal`, `write-after`, or `comprehensive` testing philosophies
- [ ] Phase 7a ran before Hooks section (when any MCP candidate fires)
- [ ] `.mcp.json` is pure JSON (no comments) and uses `${VAR}` form for secrets
- [ ] Pre-existing `.mcp.json` was NOT overwritten (check for `mcpStatus.existedPreOnboard`)
- [ ] `.claude/onboard-mcp-snapshot.json` matches what was written to `.mcp.json`
- [ ] `onboard-meta.json.mcpStatus` populated alongside `hookStatus` (with `status` enum value)
- [ ] `.claude/rules/mcp-setup.md` emitted when any server needs auth OR pre-existing file detected
- [ ] Auto-install ran after metadata write (never before)
- [ ] `callerExtras.disableMCP: true` skips artifact writes BUT still emits `mcpStatus: { status: "skipped", reason: "caller-disabled" }` (SKIP-PHASE family contract)
- [ ] Phase 7b ran after Phase 7a and before Hooks
- [ ] Emitted output-style file is at `.claude/output-styles/<archetype-name>.md` with matching `name` frontmatter
- [ ] Pre-existing output-style file was NOT overwritten (check for `outputStyleStatus.existedPreOnboard[]`)
- [ ] `.claude/onboard-output-style-snapshot.json` contains frontmatter-only entry for the emitted style
- [ ] `onboard-meta.json.outputStyleStatus` populated alongside `mcpStatus` (with `status` enum value)
- [ ] `settings.local.json` was NOT created from scratch (Case 1 warns only)
- [ ] Existing `outputStyle` in `settings.local.json` was NOT overwritten (Cases 3/4 warn only)
- [ ] `callerExtras.disableOutputStyleTuning: true` ONLY suppresses Step 6 batched confirmation; artifacts + snapshot + `outputStyleStatus: { status: "emitted", source: "inferred" }` are STILL produced (SUPPRESS-PROMPT family contract)
- [ ] CLAUDE.md Plugin Integration includes the `### Output styles` subsection (built-ins + emitted custom + activation path)
- [ ] Phase 7c (LSP) emitted `lspStatus` regardless of firing path — `status` is one of: `emitted`, `skipped`, `declined`
- [ ] `callerExtras.disableLSP: true` skips artifact writes BUT still emits `lspStatus: { status: "skipped", reason: "caller-disabled" }` (SKIP-PHASE family contract)
- [ ] Phase 7d ran after Phase 7c (LSP) and before Hooks section
- [ ] `<!-- onboard:builtin-skills:start/end -->` markers present in CLAUDE.md (inside Plugin Integration or standalone)
- [ ] `.claude/onboard-builtin-skills-snapshot.json` contains `recommended` and `accepted` arrays (plain JSON, no `_generated`)
- [ ] `onboard-meta.json.builtInSkillsStatus` populated alongside `hookStatus`, `mcpStatus`, `skillStatus`, `agentStatus`, `outputStyleStatus`, `lspStatus` (with `status` enum value)
- [ ] `callerExtras.disableBuiltInSkills: true` skips artifact writes BUT still emits `builtInSkillsStatus: { status: "skipped", reason: "caller-disabled" }` (SKIP-PHASE family contract)
- [ ] CLAUDE.md includes `### Built-in Claude Code skills` subsection (or standalone `## Built-in Claude Code skills` section when no plugins) with project-specific examples
- [ ] **Pre-exit self-audit**: all 4 Phase 7 telemetry keys (`mcpStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`) exist in `onboard-meta.json` — missing key = hard-fail before returning
- [ ] **Research self-audit**: if `metadata.research.consumed`, the block is coherent (`claimsVerified`/`claimsDropped`/`specialistsRun`/`artifactLocation`/`artifactsWritten` present; `artifactsWritten` matches on-disk docs; `htmlRendered` non-null iff walkthrough present) — incoherence is a returned `warnings[]` entry, not a hard-fail; `consumed:false` → research key `status:"skipped"`
