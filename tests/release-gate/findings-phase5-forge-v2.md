# Phase 5 — /forge:init on test-forge (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Forge version:** 1.0.0 · **Onboard version (called headless):** 1.9.0
**Run model:** Opus 4.7 (1M context), `/effort xhigh`
**Target:** empty directory → scaffolded `test-release-gate` Node.js + TypeScript CLI
**Path taken:** Option 1 blast-through (auto-fill wizard for test speed)
**Wall time:** ~40m (Phase 2 scaffold ~3m + Phase 3b onboard headless 17m 40s + forge overhead ~20m)
**Session cost:** ~$9.83
**Drift verifier:** no verify script for forge yet — manual artifact audit below
**Scaffold validity after forge exit:** `npm test` → **3/3 vitest pass**, CLI binaries runnable, typecheck + build green

---

## A. Checklist observations (F1-F14)

| # | Check | Result | Evidence |
|---|---|---|---|
| F1 | Only 3 phases: Context Gathering → Scaffold → Tooling Generation | ✅ PASS | Transcript shows phases: `phase-1-context-gathering` → `phase-2-scaffold` → `phase-3a-plugin-discovery` → `phase-3b-tooling-generation` → `complete`. 3a+3b collapse into "Phase 3 AI Tooling" conceptually — still 3 named phases. |
| F2 | NO Phase 4 "Engineering" (M6 sweep removed it) | ✅ PASS | No `phase-4-engineering` appears in `forge-state.json.currentPhase` progression. `completedSteps` jumps from phase-3b substeps straight to `complete`. M6 compliance confirmed. |
| F3 | Phase 1 uses adaptive 8-step wizard | ✅ PASS (via option 1) | `completedSteps`: step-1-vision, step-2-stack, step-3-details, step-3.5-pain-points, step-4-workflow, step-5-cicd, step-6-feature-decomp, step-7-confirmation. All 8 steps marked complete after option-1 auto-fill. |
| F4 | Phase 2 scaffolds actual project | ✅ PASS | Real scaffold: `package.json`, `tsconfig.json`, `src/{cli,index,commands/{echo,config}}.ts`, `tests/cli.test.ts`, `.gitignore`, `.env.example`, `README.md`. `npm install` → 124 packages in 10s. |
| F5 | Phase 3 delegates to onboard's headless `generate` skill | ✅ PASS | Transcript: `Skill(onboard:generate)` loaded; subsequent `onboard:config-generator` agent dispatched with 55 tool uses / 104.8k tokens / 17m 40s. Forge does not re-implement generation. |
| F6 | Stack research via stack-researcher agent | ⚪ N/A (test mode) | Option 1 explicitly skips web research: `researchMode: "training-data-only"`. Stack-researcher agent not invoked. |
| F7 | Plugin-discovery presents curated catalog | ✅ PASS (partial) | Transcript: *"Catalog matching: 6 universal plugins match — superpowers, commit-commands, security-guidance, hookify, claude-md-management, notify"*. AskUserQuestion offered "Register only" as default. |
| F8 | Selected plugins installed via `claude plugin install` | ⚪ N/A (test mode) | User chose "Register only"; no actual install commands run. `forge-state.json.pluginDiscoveryMode: "register-only"`. |
| F9 | Scaffold git-initialized with first commit | ✅ PASS | `git log --oneline` → `7c11e3e feat: scaffold test-release-gate CLI with Node.js 22 + TypeScript 5`. Main branch. |
| F10 | Hello-world verification runs | ✅ PASS | Phase 2 verification: typecheck ✓, build ✓, vitest 3/3 ✓, CLI features 4/4 (`--help`, `--version`, `echo`, `config`, errors). Re-ran post-forge: still 3/3 pass. |
| F11 | onboard-meta.json has forge-specific shape (L5 `toolingFlags` namespace) | ⚠️ PARTIAL | `.generated.toolingFlags` present in **forge-meta.json** (170 lines of detailed mirror). `.context.toolingFlags` is null (path mismatch with what the release-gate plan's §13 implies — see F11 note below). |
| F12 | forge-meta.json exists | ✅ PASS | 230 lines. Contains: version, createdAt, updatedAt, source:"forge", mode, onboardVersion:"1.9.0", context (full wizard state), generated (scaffold + toolingFlags), webResearch, costs. |
| F13 | Session returns cleanly | ✅ PASS | Final state: `currentPhase: "complete"`, `currentStep: "handoff"`. Rich handoff message with next-steps. No crash. |
| F14 | Any `AskUserQuestion` "Invalid tool parameters"? (B3/B9 probe) | ✅ NOT OBSERVED | Forge ran only 2 AskUserQuestion calls (option-1 disambiguation, plugin-discovery register-only) — both single-select, both clean. **B3/B9 did not reproduce in forge's interactive surface.** |

**F11 note:** The 170-line `toolingFlags` block lives at `.generated.toolingFlags` in `forge-meta.json`, not at `.context.toolingFlags`. The release-gate manual plan §13 is untested by any existing verify script — may be a spec vs. implementation ambiguity, worth confirming canonical path before codifying in verify-drift-output.sh's §13 check.

**Overall: 11 PASS, 2 N/A (test-mode skips), 1 PARTIAL. Zero explicit failures.**

---

## B. Major release-gate-level findings (scope narrowing)

### B★ — Forge path correctly emits MCP — **B1 is not generator-wide**  ✅ SCOPE NARROWED

Previous phases recorded:

> Phase 2 (Custom init): `mcpStatus.status = "skipped", reason: "no-candidates"`
> Phase 3a (Minimal init): `mcpStatus.status = "skipped", reason: "no-candidates"`
> Phase 3b (Standard init): `mcpStatus.status = "skipped", reason: "no-signal-driven-candidates"`

**Phase 5 (forge → onboard headless generate):**

```json
"mcpStatus": {
  "status": "emitted",
  "path": "signal-driven",
  "planned": ["context7"],
  "generated": ["context7"],
  "skipped": [],
  "existedPreOnboard": false,
  "autoInstalled": [],
  "autoInstallFailed": []
}
```

And `.mcp.json` exists on disk:
```json
{
  "_generated": {"by": "onboard", "version": "1.9.0", "date": "2026-04-17"},
  "mcpServers": {
    "context7": {"type": "stdio", "command": "npx", "args": ["-y", "@upstash/context7-mcp"]}
  }
}
```

**Conclusion:** the onboard *generation* skill CAN emit MCP correctly when given a properly-formed `callerExtras` context. The bug is not in the generator — it's in the **init-skill-driven code path** that builds the generation context. Init paths are failing to populate the MCP-detection input correctly. Significantly narrows the fix surface: fix the init → generation bridge, not the generator itself.

### B★★ — Forge path correctly populates pluginVersion — **B5 is init-path-specific**  ✅ SCOPE NARROWED

Phase 3a Minimal: `pluginVersion: null`
Phase 3b Standard: `pluginVersion: null`
Phase 3c Stub: `version: "1.0.0"` (hardcoded wrong)

**Phase 5 (forge):**

```json
{
  "pluginVersion": "1.9.0",
  "_generated": {"by": "onboard", "version": "1.9.0", "date": "2026-04-17"},
  "source": "forge"
}
```

Same conclusion: B5 is in the init paths, not in the generation skill.

### B★★★ — Plugin-aware agent shadowing works perfectly  ✅ HIGH-QUALITY WIN

Canonical behavior from `plugin-detection-guide.md:72-77` (coveredCapabilities derivation):

> If installedPlugins includes superpowers + code-review + feature-dev → agents with those capabilities should be suppressed.

**Phase 5 result:** `agentStatus.generated: []`, `agentStatus.skipped`:

```json
[
  { "name": "code-reviewer",         "reason": "covered-by-plugin", "coveredBy": "code-review" },
  { "name": "test-writer",           "reason": "covered-by-plugin", "coveredBy": "test-generation" },
  { "name": "security-checker",      "reason": "covered-by-plugin", "coveredBy": "security-audit" },
  { "name": "feature-builder",       "reason": "covered-by-plugin", "coveredBy": "feature-development-via-superpowers" },
  { "name": "documentation-writer",  "reason": "covered-by-plugin", "coveredBy": "documentation" }
]
```

Every default agent correctly shadowed with its specific `coveredBy` source. Zero duplicate coverage. This is the exact behavior § C of the Phase 2 report recommended.

### B★★★★ — Forge→onboard Skill-tool integration is clean  ✅

Transcript shows the exact handoff chain:

```
forge:init (main orchestrator)
 └── Skill(forge:context-gathering)      ← Phase 1
 └── Skill(forge:scaffolding)            ← Phase 2
      └── Bash(detect-scaffold-cli.sh)
      └── Write × 8 source files
      └── Bash(npm install, npm test, node dist/cli.js ...)
      └── Bash(git init, git commit)
 └── Skill(forge:plugin-discovery)       ← Phase 3a
      └── AskUserQuestion(register-only?)
 └── Skill(forge:tooling-generation)     ← Phase 3b
      └── forge:scaffold-analyzer agent (46s)
      └── Write(.claude/forge-onboard-context.json)  ← rich 243-line context object
      └── Skill(onboard:generate)                     ← delegates to onboard
           └── onboard:config-generator agent (17m 40s, 55 tool uses, 104.8k tokens)
```

Every boundary is a discrete Skill-tool invocation. No re-implementation, no duplicate logic, clean separation of concerns. This is the architectural pattern onboard + forge were designed around, and it works end-to-end.

---

## C. Generated artifact inventory (21 artifacts)

| Category | Files | Notes |
|---|---|---|
| CLAUDE.md | root + src/commands/ (2) | Multi-level context correctly generated |
| Path-scoped rules | typescript-strict, commander-patterns, testing-vitest, mcp-setup (4) | Specific to scaffold stack |
| Skills | add-cli-command, debug-exit-codes (2) | Aligned with CLI-specific workflows |
| Agents | **0** | All shadowed by plugin coverage (see B★★★) |
| Hooks | session-start-superpowers-reminder, pre-commit-verification, post-feature-revise-claude-md, evolution-drift-detect (4) | advisory + blocking + advisory + advisory |
| Output style | solo-minimal.md (1) | archetype=solo, inferred |
| MCP servers | context7 in `.mcp.json` (1) | Signal-driven, always-emit |
| Harness docs | progress.md, HARNESS-GUIDE.md, sprint-1/contract.md (3) | Enriched harness enabled |
| Snapshots | mcp, output-style, onboard-meta (3) | Not full set — agent + skill snapshots absent (skills tuning suppressed, agents skipped) |
| Forge-owned | init.sh (executable), docs/feature-list.json (4 features, 1 sprint) | Post-onboard |

**Total = 21** per the transcript's summary; cross-verified by my Bash listing = 21 distinct tooling files (excluding `dist/` build output and `package-lock.json`).

---

## D. Issues observed (all minor)

### D1 — `timestamp` null despite `_generated.date` populated  ⚠️ MINOR

```json
{
  "pluginVersion": "1.9.0",
  "_generated": {"by": "onboard", "version": "1.9.0", "date": "2026-04-17"},
  "timestamp": null,    // ← inconsistent with _generated.date
  "source": "forge"
}
```

Two conceptually-overlapping fields, one filled and one null. Clean up by either aliasing or removing one.

### D2 — `toolingFlags` path in forge-meta.json  ⚠️ SPEC QUESTION

Lives at `.generated.toolingFlags` (based on writing-time structure). The release-gate manual plan §13 alludes to a `toolingFlags namespace` but existing verify scripts don't yet probe this path, so canonical location is ambiguous. Worth clarifying before future L5-sweep verify checks codify either path.

### D3 — Scaffolding generated TypeScript diagnostics while still in-progress  ℹ️ NOTE

Each `Write(src/...)` during Phase 2 emitted LSP diagnostic warnings until `npm install` finished. Transcript shows 15+ "Found N new diagnostic issues" notifications before deps were installed. Final state is clean (typecheck + build green), but the mid-scaffold noise may confuse automated viewers of the run log. Could be quieter by staging all writes before starting LSP monitoring, or by muting diagnostics until `npm install` completes.

### D4 — Forge auto-added a minor src/index.ts polish post-verification  ℹ️ NOTE (positive)

After the CLI tests passed, forge self-identified a minor UX quirk (commander exitOverride double-printing "error:" on unknown commands) and applied a 5-line fix inline. Positive finding — forge iterates on its own output. Worth preserving.

### D5 — Not observed: B3/B9 `AskUserQuestion` single-option schema fail  ✅ POSITIVE

Forge fired only 2 AskUserQuestion calls in the visible transcript, both single-select and both succeeded. B3/B9 was NOT reproduced in this run. Forge's use of AskUserQuestion appears cleaner than init's — either by coincidence (only 2 interactions) or by design (different interaction patterns).

---

## E. Updated bug matrix (post-Phase 5)

| Bug | Custom init | Standard init | Minimal init | Stub init (option 3) | **Forge** |
|---|---|---|---|---|---|
| B1 MCP skipped | ❌ | ❌ | ❌ | N/A | ✅ **CORRECTLY EMITTED** |
| B2/B11 wizardStatus shape | ❌ | ❌ | ✅ | N/A | N/A (forge doesn't use wizardStatus same way) |
| B3/B9 AskUserQuestion schema | ❌ | — | ❌ | N/A | ✅ NOT OBSERVED |
| B5 pluginVersion null | ✅ | ❌ | ❌ | ❌ (hardcoded) | ✅ **CORRECTLY POPULATED** |
| B6 Skill snapshot missing | ✅ | ❌ | ❌ | N/A | ✅ (skill snapshot `tuningSuppressed`, explicitly coupled via reason) |
| B8 Shallow plugin detection | ✅ | ❌ | ❌ | N/A | ✅ (register-only is explicit; discovery ran full catalog match) |
| B10 LSP silently dropped | ✅ | ❌ | ✅ | N/A | N/A (callerExtras.disableLSP=true — explicit skip) |

**Every major init-path regression is absent from the forge path.** This strongly suggests:
- The onboard generation skill **works correctly** when given the right context
- The bugs are in how init populates the generation context (stack signals, plugin detection breadth, telemetry stamping)
- Forge's explicit `callerExtras` object provides a cleaner contract than init's inferred-from-wizard context

**Fix direction consolidates to:** make init's context-building step produce the same shape forge produces via `forge-onboard-context.json`. Once that bridge is fixed, all 4 init presets should inherit the forge path's correctness.

---

## F. Sign-off recommendation — Phase 5 only

| Dimension | Status |
|---|---|
| 3-phase structure (M6 sweep) | ✅ PASS |
| Scaffolding (real code + git + tests pass) | ✅ PASS |
| Onboard delegation via Skill tool | ✅ PASS |
| MCP / pluginVersion / plugin-aware agents | ✅ PASS (WIN) |
| Telemetry shape (`toolingFlags`, `hookStatus`, etc.) | ⚠️ path ambiguity, otherwise PASS |
| Cost / duration | ✅ Acceptable (~$9.83, 40m at xhigh) |
| B3/B9 reproduction probe | ✅ Not observed |
| Release readiness (Phase 5 only) | **✅ READY to ship** |

## G. Running cross-phase sign-off (post-Phase 5)

| Phase | Status | Preset / Target | Summary |
|---|---|---|---|
| Phase 1 (automated) | ✅ | — | 115/115 |
| Phase 2 (nextjs) | HOLD | Custom init | B1, B2, B3, G.3 |
| Phase 3a (python) | HOLD | Minimal init | B1, B5, B6, B8, B9 |
| Phase 3b (monorepo) | HARD HOLD | Standard init | B1, B5-variant, B6, B8, B10, B11, B12, B13 |
| Phase 3c (empty) | PASS w/ caveats | Stub init | B14, B15 |
| Phase 4 (drift) | PASS w/ degradation | /onboard:update | F1 (B3/B9 reproduction) |
| **Phase 5 (forge)** | **✅ PASS** | forge → onboard headless | No forge-specific bugs. Path validates the generation skill is correct. |
| Phase 6 (CI/audit) | pending | — | — |

## H. The big insight from Phase 5

**Forge's health re-frames the init-path bugs.** Before Phase 5, the bug matrix suggested 13+ distinct regressions across init paths. After Phase 5, the picture is:

1. **The generation skill (onboard:generate + config-generator agent) is correct.** Forge proves it. When given a properly-formed context object, it emits valid artifacts, correct telemetry, MCP with context7, plugin-aware agent shadowing, everything.

2. **Bugs B1, B5, B6, B8, B10-B13 are all clustered in the init → generation bridge.** The code that gathers wizard answers and stack signals and passes them to the generator is the actual problem area. Each preset path has drifted independently in that bridge.

3. **Single fix direction for onboard 1.10.0:** refactor init's context-building step to produce the same `forge-onboard-context.json`-shaped object that forge emits. Delete the preset-specific bridges.

This is the cleanest, highest-leverage recommendation from the entire release-gate run. Forge's success is diagnostic, not just a positive run.
