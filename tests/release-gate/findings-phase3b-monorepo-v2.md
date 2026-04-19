# Phase 3b — /onboard:init on test-monorepo (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Onboard version:** 1.9.0 (claim) / `null` (actual — B5 reproduces)
**Run model:** Opus 4.7 (1M context), `/effort high` (default — not xhigh)
**Preset:** **Standard**
**Project under test:** Turborepo TypeScript monorepo scaffold (apps/api, apps/web, packages/shared, packages/ui — 16 `.ts` files, 16 LOC of stubs)
**Generation time:** 6m 21s · ~$2.89 session cost
**Wizard exchanges:** ~3 (preset pick + project description + summary confirm)
**Artifact verifier:** `tests/release-gate/verify-init-output.sh` → **30 PASS / 10 WARN / 4 FAIL**

---

## A. Checklist observations (M1-M8)

| # | Check | Result | Evidence |
|---|---|---|---|
| M1 | Subdirectory CLAUDE.md for apps/web, apps/api, packages/* | ✅ PASS | 5 files generated: root + apps/{api,web}/CLAUDE.md + packages/{shared,ui}/CLAUDE.md |
| M2 | `/codebase-visualizer` offered in Phase 5.7 | ❌ FAIL | Summary shows "core set (/loop, /simplify, /debug, /pr-summary)" — `/codebase-visualizer` not offered despite multi-package signal (4 workspaces). Root cause: `builtInSkillsStatus.status = "skipped"` — the Phase 5.7 candidate list was never materialized. |
| M3 | `typescript-lsp` offered, pre-checked | ✅ PASS (offered + accepted) · ❌ FAIL (not wired) | Summary mentions it; user accepted. But `lspStatus: {status: "skipped", reason: "no-project-level-lsp-install-path"}` — the wizard promised it, the generator dropped it. See B10. |
| M4 | Complexity inferred as medium or higher | ⚠️ CALIBRATION MISS | Analysis reported "Small (20/100 — 16 files, 16 LOC)". Plan expected medium+ from multi-workspace structure; actual scorer weights LOC (16 is tiny). Not a bug in the scorer — a disagreement with the plan checklist. |
| M5 | Session returns cleanly after init | ✅ PASS | Prompt returned; no hook or schema errors on next input |
| M6 | Plugin detection — deep (like Custom) or shallow (like Minimal)? | ❌ SHALLOW | Only detected `notify` + `forge` (sibling plugins in dev repo). Missed superpowers, feature-dev, code-review, pr-review-toolkit, claude-md-management, hookify, security-guidance, frontend-design, commit-commands — all installed in `~/.claude/plugins/cache/claude-plugins-official/`. **Standard preset matches Minimal's shallow detection, NOT Custom's deep detection.** |
| M7 | `wizardStatus` emits C4 5-subkey shape | ❌ FAIL — new drift | Actual: `{"status": "emitted", "preset": "standard", "answersPresent": true}`. None of `presetUsed / exchangesUsed / phasesAsked / phasesSkipped / escapeHatchTriggered` present. Different shape from both Custom (also broken, different way) and Minimal (correct). |
| M8 | `pluginVersion` / `_generated` / `timestamp` populated | ❌ FAIL | All `null` except `source: "release-gate-test"`. Same as Phase 3a B5. Confirms this is a non-Custom bug. |

**Checklist pass rate:** 2/8 functionally correct (M1, M5). 1 calibration miss (M4). 4 explicit regressions (M2, M3, M6, M7, M8).

---

## B. Regressions uncovered — new to Phase 3b

### B10 — `lspStatus` silently skipped despite user selecting typescript-lsp  ❌ FAIL

Wizard summary:
> *"LSP plugins: typescript-lsp (auto-detected, accepted by default)"*

Telemetry:
```json
"lspStatus": {
  "status": "skipped",
  "reason": "no-project-level-lsp-install-path",
  "notes": "wizard selected typescript-lsp but no project-level install action was required beyond editor configuration"
}
```

The wizard accepted the user's choice, the summary displayed it, then the generator silently dropped it. Contrast Phase 3a Minimal (same LSP selection): `lspStatus: {status: "emitted", plugins: ["pyright-lsp"], wiredIn: ".claude/settings.json"}`.

**Severity:** high — user choice silently discarded. This is the kind of drift that erodes trust in the tool.

### B11 — `wizardStatus` third distinct shape on Standard preset  ❌ FAIL

Three preset paths now emit three distinct shapes:

| Preset | Shape |
|---|---|
| Custom (Phase 2) | `{completed, completedAt, mode, preset}` — 0/5 C4 keys |
| Standard (Phase 3b) | `{status, preset, answersPresent}` — 0/5 C4 keys |
| Minimal (Phase 3a) | `{presetUsed, exchangesUsed, phasesAsked, phasesSkipped, escapeHatchTriggered}` — 5/5 C4 keys ✅ |

The canonical shape is specified in `onboard/skills/wizard/SKILL.md:379-387`. Only the Minimal path adheres; Custom and Standard both drift, each in a different way. The wizardStatus-shape bug (originally B2 in Phase 2) is a **three-way preset divergence**.

**Severity:** blocker-class per C4 sweep requirements — verify script flags all 5 sub-keys as WARN.

### B12 — CLAUDE.md missing built-in skills / LSP / output-style sections  ⚠️ WARN

Verify script §9 flags three missing sections in root CLAUDE.md:
- No built-in skills section
- No LSP reference
- No output style reference

Root cause chain: `builtInSkillsStatus = "skipped"` + `lspStatus = "skipped"` + `outputStyleStatus = "skipped"` → generator wrote no documentation for these. Wizard summary claimed they were configured; CLAUDE.md says nothing.

Contrast Phase 3a Minimal, where CLAUDE.md correctly documented `/simplify` and pyright-lsp despite Minimal being a less elaborate preset. Standard's more-is-actually-less outcome is counterintuitive.

**Severity:** medium — documentation gap. Doesn't break anything at runtime but breaks the wizard→artifact contract.

### B13 — `builtInSkillsStatus` semantically-correct but breaks downstream  ⚠️ BUG

```json
"builtInSkillsStatus": {
  "status": "skipped",
  "reason": "built-in-skills-are-user-level-no-project-artifact"
}
```

The reason is philosophically defensible: built-in slash skills like `/simplify` aren't project files, so there's no artifact to emit. But:
1. CLAUDE.md documentation of which built-in skills to use IS a project artifact (Phase 3a handled this correctly with `documentedIn: "CLAUDE.md"`).
2. With `status: "skipped"`, the verify script's snapshot coupling (C1 sweep) treats the absence as intentional — which means no drift warning even if the CLAUDE.md block is missing.

The fix is semantic: treat *"emitted to CLAUDE.md as documentation"* as its own valid `status` value, or keep `status: "emitted"` with `documentedIn: "CLAUDE.md"` as Phase 3a did.

**Severity:** low — UX / consistency gap.

---

## C. Bugs reproduced from prior phases

### B1 MCP skipped (generator-wide)  ❌ FAIL

`mcpStatus: {status: "skipped", reason: "no-signal-driven-candidates", planned: [], generated: []}`. Slight variation in reason string (`"no-signal-driven-candidates"` vs Phase 2/3a's `"no-candidates"`), but behavior identical. `.mcp.json` missing. Reconfirmed across 3 presets.

### B5 Null top-level telemetry fields  ❌ FAIL

`pluginVersion: null`, `_generated: null`, `timestamp: null`. `source: "release-gate-test"` present (different value than Phase 3a's `null`). The `source` field IS written on Standard — just the wrong value (`"release-gate-test"` is a test/dev marker, not the `"onboard:init"` runtime marker). So this is actually **B5-variant-2**: Standard writes some top-level fields with placeholder values, not null-outright.

### B6 Skill snapshot missing despite `skillStatus="emitted"` (C1 coupling broken)  ❌ FAIL

Same as Phase 3a. `skillStatus: {status: "emitted", generated: ["add-workspace", "pick-framework"]}` but `onboard-skill-snapshot.json` not written. Minimal + Standard both broken; only Custom emitted the snapshot correctly.

### B8 Shallow plugin detection  ⚠️ BUG

Same as Phase 3a — detected only `notify` + `forge`. B8's scope is now: Custom=deep, Standard=shallow, Minimal=shallow. **Deep detection is the exception, not the rule.**

---

## D. Updated cross-preset bug matrix

| Bug | Custom (Phase 2) | Standard (Phase 3b) | Minimal (Phase 3a) | Pattern |
|---|---|---|---|---|
| B1 MCP skipped with no-candidates reason | ❌ | ❌ | ❌ | **All presets** |
| B2/B11 `wizardStatus` shape drift | ❌ (shape A) | ❌ (shape B) | ✅ canonical | **All but Minimal** |
| B3/B9 `AskUserQuestion` single-option schema fail | ❌ ×2 | — (not observed) | ❌ ×1 | **Generator-wide (when single candidate presents)** |
| B5 `pluginVersion` / `_generated` / `timestamp` null | ✅ | ❌ (null + placeholder source) | ❌ (all null) | **All but Custom** |
| B6 Skill snapshot missing despite status="emitted" | ✅ | ❌ | ❌ | **All but Custom** |
| B7 Stale `detect-lsp-signals.sh` path | ✅ | — (not observed) | ❌ | **Minimal-only?** |
| B8 Shallow plugin detection | ✅ deep | ❌ shallow | ❌ shallow | **All but Custom** |
| B10 `lspStatus=skipped` despite user selecting LSP | ✅ | ❌ | ✅ | **Standard-only** |
| B12 CLAUDE.md missing built-in / LSP / output-style sections | ✅ | ❌ | ✅ | **Standard-only** |
| B13 `builtInSkillsStatus` downstream-breaking semantic | ✅ | ❌ | ✅ | **Standard-only** |

### Preset quality ranking (after Phases 2+3a+3b)

| Rank | Preset | Why |
|---|---|---|
| 🥇 1 | **Custom** | Only preset with: correct plugin-version stamping, skill snapshot emission, deep plugin detection, CLAUDE.md completeness. But: wizardStatus drift, MCP skip. |
| 🥈 2 | **Minimal** | Correct wizardStatus shape (only one!), correct LSP wiring, correct CLAUDE.md. But: null telemetry fields, missing skill snapshot, shallow plugin detection. |
| 🥉 3 | **Standard** | Has **every** regression of Minimal plus 3 new ones (B10/B12/B13). Third-distinct wizardStatus shape. `source: "release-gate-test"` placeholder instead of `"onboard:init"`. Standard's generation path appears to be the most drifted. |

**Key insight:** the three preset paths have independently drifted from each other and from `onboard/skills/wizard/SKILL.md`'s canonical spec. No single preset is fully correct. A fix must address all three paths — or consolidate them.

---

## E. Sign-off recommendation — Phase 3b only

| Dimension | Status |
|---|---|
| Checklist (M1-M8) | 2 PASS / 1 calibration / 5 FAIL |
| Artifact integrity | ⚠️ 4 verify-script FAILs: hook-count (calibration), MCP (B1 shared), skill snapshot (B6 shared), pluginVersion (B5 variant) |
| wizardStatus telemetry | ❌ Third distinct shape drift (B11) |
| Plugin detection completeness | ❌ Shallow (B8) |
| CLAUDE.md content | ❌ Missing built-in skills / LSP / output-style sections (B12) |
| LSP user-choice preservation | ❌ User said YES, generator silently dropped (B10) |
| Release readiness (Phase 3b only) | **HARD HOLD** — more broken than 3a Minimal. At least 4 Standard-specific regressions (B10/B11/B12/B13) block Standard-preset release. |

## F. Running cross-phase sign-off

| Phase | Status | Unique blockers |
|---|---|---|
| Phase 1 (automated) | ✅ 115/115 | — |
| Phase 2 (nextjs Custom) | HOLD | B1, B2 (Custom-variant), B3, G.3 dangling ref |
| Phase 3a (python Minimal) | HOLD | B1, B5, B6, B8, B9 |
| Phase 3b (monorepo Standard) | **HARD HOLD** | B1, B5-variant, B6, B8, B10, B11, B12, B13 |
| Phase 3c, 4, 5, 6 | pending | — |

**Distinct bugs tracked so far:** 13 (B1, B2, B3/B9, B5 and variant, B6, B7, B8, B10, B11, B12, B13 + G.3 dangling ref + G.5 routing recommendations).

Standard preset cannot ship in current state. Recommend prioritizing a **preset-path consolidation** effort in onboard 1.10.0 where all three presets share a single generation code path with preset-specific flags, not three independent implementations.
