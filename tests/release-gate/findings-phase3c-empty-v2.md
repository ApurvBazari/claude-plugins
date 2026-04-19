# Phase 3c — /onboard:init on test-empty (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Onboard version:** 1.9.0 (installed) / **1.0.0 (hardcoded in stub output — wrong)**
**Run model:** Opus 4.7 (1M context), `/effort xhigh`
**Project under test:** Empty directory (only `.git/`; 0 source files)
**Path taken:** Option 3 (minimal scaffolding-only stub) — selected after Claude offered three alternatives instead of running the full init
**Generation:** 3 files only (CLAUDE.md, .claude/settings.json, .claude/onboard-meta.json)
**Artifact verifier:** `tests/release-gate/verify-init-output.sh` → **5 PASS / 7 WARN / 18 FAIL**

---

## A. Checklist observations (E1-E9)

| # | Check | Result | Evidence |
|---|---|---|---|
| E1 | Analysis completes without crashing on zero-file input | ✅ PASS | No crash. Claude intercepted before the `codebase-analyzer` agent ran and offered 3 graceful paths. User chose option 3 (stub). |
| E2 | No hallucinated stack detection | ✅ PASS | CLAUDE.md uses placeholders: *"Tech Stack: To be detected after scaffolding"*, *"Project Structure: To be captured once a layout exists"*, etc. Zero fabricated content. |
| E3 | Wizard completes gracefully | ⚪ N/A | Wizard never ran. Option 3 skipped directly to stub generation. This is a 4th preset path that bypasses the wizard entirely. |
| E4 | settings.json valid JSON | ✅ PASS | `{"hooks": {}}` — empty hooks object, valid structure. |
| E5 | No MCP candidates offered | ✅ PASS | No `.mcp.json` file. `detectedPlugins: null` in onboard-meta. |
| E6 | No LSP candidates offered | ✅ PASS | No LSP config anywhere. |
| E7 | Advanced hook types not offered | ✅ PASS | `hooks: {}` — zero events wired. |
| E8 | Session starts cleanly after init | ⚪ UNVERIFIED | User ended transcript before testing a new prompt. Low risk given empty hooks + valid JSON. |
| E9 | `pluginVersion` populated OR consistent with preset pattern | ❌ FAIL | `version: "1.0.0"` hardcoded. Actual installed onboard is **1.9.0**. Stub-generator hardcoded the wrong version string instead of reading from plugin manifest. |

**Checklist pass rate:** 6 PASS · 1 UNVERIFIED · 1 N/A · 1 FAIL.

---

## B. Regressions uncovered — new to Phase 3c

### B14 — Stub mode emits a brand-new 4th onboard-meta schema  ❌ FAIL

Four distinct schemas now exist across the 4 presets tested:

| Preset | Schema signature |
|---|---|
| Custom (Phase 2) | `pluginVersion, _generated, timestamp, source, mcpStatus, skillStatus, agentStatus, outputStyleStatus, lspStatus, builtInSkillsStatus, wizardStatus, hookStatus` |
| Standard (Phase 3b) | Same keys as Custom but: `pluginVersion/_generated/timestamp = null`, `source = "release-gate-test"` placeholder, `wizardStatus` shape-drifted |
| Minimal (Phase 3a) | Same keys as Custom but: `pluginVersion/_generated/timestamp/source = null`, `wizardStatus` uses canonical C4 shape ✅ |
| **Stub / empty-repo (Phase 3c)** | **`version, generatedAt, mode, reason, analysis, wizardAnswers, detectedPlugins, generated, nextSteps`** — zero overlap with the canonical shape |

The stub schema shares **no top-level keys** with the canonical schema. Downstream consumers (verify script, evolve/update skills, drift detectors) cannot reason about it — every C1/C4 telemetry probe returns "key missing".

**Severity:** blocker-class — breaks the single-source-of-truth invariant for onboard metadata.

### B15 — Stub generator hardcodes `version: "1.0.0"` instead of reading plugin manifest  ❌ FAIL

From `onboard-meta.json`:
```json
{ "version": "1.0.0", ... }
```

Installed onboard is **1.9.0** (confirmed in Phase 2's onboard-meta: `pluginVersion: "1.9.0"`). The stub path's generator has a literal string `"1.0.0"` baked in — never updated since onboard was first scaffolded.

This is a dynamic-version regression scoped to the stub path. L4 sweep required onboard to query its own version dynamically (see `onboard/scripts/` CLI + sibling fallback per commit `db5a8db` in recent history). Stub path missed the L4 migration.

**Severity:** medium — functionally the stub will still work, but `version: "1.0.0"` signals a 1.x-era artifact and will falsely pass a "version ≥ 1.0" gate forever.

### B16 — `/onboard:init` on empty dir never enters the init skill  ⚠️ FINDING (not a regression, arguably correct)

Transcript shows Claude recognized the empty-repo case **before** calling the init skill agent and offered 3 alternatives. This is Claude's own judgment, not documented in `onboard/skills/init/SKILL.md`. The skill itself was never entered.

Positive reading: graceful degradation, saves cost.
Negative reading: init skill's documented guard/edge-case behavior is UNTESTED — we don't know how the skill itself handles an empty repo if called directly. If a scripted caller (forge, automation) invokes init on an empty dir, does it crash?

**Severity:** low — out of scope for release-gate, but worth a note.

---

## C. Positive findings

- **CLAUDE.md stub is well-designed.** Placeholders for every section, clear status banner (*"Stub configuration generated... Re-run `/onboard:init` after scaffolding"*), explicit Working Notes telling Claude to ask questions instead of inventing facts, pointer to `/forge:init` as the greenfield alternative.
- **settings.json is valid and intentionally empty** (`{"hooks": {}}`). Won't break session start.
- **`nextSteps` array provides developer guidance:** add code → re-run init, or use `/forge:init` for scaffold+onboard flow. Clear next-action framing.
- **Cost:** $0.41, finished in seconds. Cheapest run of the series.

---

## D. Updated cross-preset matrix

| Bug | Custom | Standard | Minimal | Stub (empty) |
|---|---|---|---|---|
| B1 MCP skipped | ❌ | ❌ | ❌ | ⚪ (intentional no-op) |
| B2/B11 wizardStatus shape drift | ❌ (shape A) | ❌ (shape B) | ✅ canonical | ❌ (absent entirely) |
| B5 pluginVersion null / placeholder | ✅ 1.9.0 | ❌ null | ❌ null | ❌ hardcoded "1.0.0" (B15) |
| B6 Skill snapshot missing | ✅ | ❌ | ❌ | ⚪ (stub has no skills) |
| B8 Shallow plugin detection | ✅ deep | ❌ shallow | ❌ shallow | ⚪ (no detection) |
| B10 lspStatus silently dropped | ✅ | ❌ | ✅ | ⚪ (no LSP phase) |
| B14 Schema divergence | — | — | — | ❌ 4th shape |

**Four preset paths. Four distinct `onboard-meta.json` schemas.** This is the headline finding of Phase 3.

---

## E. Sign-off recommendation — Phase 3c only

| Dimension | Status |
|---|---|
| Empty-repo safety (no crash, no hallucination) | ✅ PASS |
| Graceful degradation | ✅ PASS (option 1/2/3 menu is good UX) |
| Stub artifact quality | ✅ PASS (CLAUDE.md + settings.json + meta are well-formed for their purpose) |
| Schema consistency with other preset paths | ❌ FAIL (B14) |
| Dynamic onboard-version stamping (L4 sweep) | ❌ FAIL (B15) |
| Init skill's own empty-repo handling | ⚪ untested (B16) |
| Release readiness (Phase 3c only) | **PASS with caveats** — edge case is handled safely, but schema drift (B14) and hardcoded version (B15) should be fixed before declaring the stub path first-class. |

## F. Running cross-phase sign-off (post-Phase 3)

| Phase | Status | Preset | Unique blockers |
|---|---|---|---|
| Phase 1 (automated) | ✅ 115/115 | — | — |
| Phase 2 (nextjs) | HOLD | Custom | B1, B2, B3, G.3 |
| Phase 3a (python) | HOLD | Minimal | B1, B5, B6, B8, B9 |
| Phase 3b (monorepo) | **HARD HOLD** | Standard | B1, B5-variant, B6, B8, B10, B11, B12, B13 |
| Phase 3c (empty) | PASS w/ caveats | Stub | B14, B15, (B16 untested) |
| Phase 4, 5, 6 | pending | — | — |

**Distinct bugs now tracked:** 16 (B1, B2, B3/B9, B5 + variant, B6, B7, B8, B10, B11, B12, B13, B14, B15, B16, G.3 dangling ref, G.5 routing).

**Phase 3 macro-finding — four preset paths, four drifted implementations:**

| Preset | Canonical? | Fix effort |
|---|---|---|
| Custom | closest to canonical; drift on wizardStatus + MCP skip | low — fix two discrete bugs |
| Standard | heavily drifted; most bugs of any preset | medium — needs targeted rewrite |
| Minimal | partially drifted; unique correct wizardStatus | low-medium — port correct bits to others |
| Stub | entirely separate schema; barely versioned | high — needs to conform to canonical or be formally declared "different mode" |

**Recommendation for onboard 1.10.0:** a preset-path consolidation sprint. Single generation code path with preset-specific flags, not four independent implementations. Tracks with the recommendation already made in Phase 3b's report.
