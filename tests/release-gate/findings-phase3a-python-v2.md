# Phase 3a — /onboard:init on test-python (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Onboard version:** 1.9.0 (claim) / `null` (actual — see B5)
**Run model:** Opus 4.7 (1M context), `/effort high` (NOT xhigh — cost-controlled after Phase 2 lesson)
**Preset:** **Minimal**
**Generation time:** 5m 11s · ~$2.62 session cost (Phase 2 was 38m / $12 — 7× faster on lower effort + simpler preset)
**Wizard exchanges:** 3 (per telemetry: `wizardStatus.exchangesUsed = 3`)
**Artifact verifier:** `tests/release-gate/verify-init-output.sh` → **30 PASS / 4 WARN / 4 FAIL**

---

## A. Checklist observations (P1-P6)

| # | Check | Result | Evidence |
|---|---|---|---|
| P1 | Solo archetype detected | ✅ PASS | `wizardAnswers`: preset=`minimal`, team=`solo`, autonomy=`autonomous`. No production/security/team signals surfaced. |
| P2 | Python-only stack; no Next.js / Prisma / Supabase flags | ✅ PASS | CLAUDE.md Plugin Integration section mentions only `forge` (installed sibling). No stack-plugin references. Analysis correctly classified Click CLI scaffold. |
| P3 | `pyright-lsp` offered in Phase 5.6 | ✅ PASS | User accepted. `lspStatus: {status: "emitted", plugins: ["pyright-lsp"], wiredIn: ".claude/settings.json"}` |
| P4 | Minimal hook set (fewer events than nextjs 11-event rich preset) | ✅ PASS (functional) · ⚠️ WARN (calibration) | Only `PostToolUse` format-only hook generated — correct for Minimal preset. Verify script's `≥5` threshold FAILs because it's calibrated for non-Minimal. Not a real regression. |
| P5 | Output style maps to solo archetype (NOT production-ops) | ✅ PASS | `outputStyleStatus: {status: "skipped", reason: "defaults-only", notes: "Wizard answered outputStyleTuning.mode=defaults; no candidates emerged for a scaffold-stage solo project."}` — clean skip, not production-ops. |
| P6 | Session returns cleanly after init | ✅ PASS | Prompt returned after the Phase 4 handoff; no crash, no hook error, no schema error. |

**Checklist pass rate:** 6/6 functionally correct (P4's verify-script FAIL is a threshold miss, not a regression).

---

## B. Regressions uncovered — new to Phase 3a, not in Phase 2

### B5 — Minimal preset omits top-level telemetry identity fields  ❌ FAIL

`onboard-meta.json` contains:

```json
{
  "pluginVersion": null,
  "_generated": null,
  "timestamp": null,
  "source": null,
  ...
}
```

Phase 2 Custom preset stamped `pluginVersion: "1.9.0"`, `_generated: {by, version, date}`, `timestamp: "2026-04-17T00:00:00Z"`, `source: "onboard:init"`. Minimal skipped all four. Verify script (L4 sweep) fails on `pluginVersion missing`.

**Severity:** blocker-class — downstream evolve/update skills rely on `pluginVersion` to detect drift.

### B6 — Skill snapshot missing despite `skillStatus="emitted"` (C1 sweep broken)  ❌ FAIL

Telemetry:

```json
"skillStatus": {
  "status": "emitted",
  "skills": ["click-cli-scaffold"]
}
```

But `onboard-skill-snapshot.json` was **not written** to disk. `ls .claude/onboard-*-snapshot.json` returns agent, output-style (intentional skip), lsp, builtin-skills — no skill snapshot.

C1 sweep invariant: status=emitted ⇒ snapshot file exists. Invariant violated on Minimal preset.

**Severity:** high — breaks the snapshot-telemetry coupling that C1 specifically added to prevent drift-under-status-mismatch bugs.

### B7 — Wizard references stale `detect-lsp-signals.sh` path  ⚠️ BUG

Transcript:
```
Bash(bash /Users/apurvbazari/Desktop/projects/claude-plugins/onboard/skills/wizard/scripts/detect-lsp-signals.sh ...)
  ⎿  Error: Exit code 127
```

Retried at `onboard/scripts/detect-lsp-signals.sh` → worked.

The wizard (SKILL.md or the config-generator) has a hard-coded stale path. Recoverable (retry succeeded) but wastes a turn. Phase 2 Custom used the correct path; Phase 3a Minimal hit the stale reference.

**Severity:** low — fallback works, but should not fail once.

### B8 — Minimal preset plugin detection is shallow  ⚠️ BUG

Transcript plugin-detection step:

```
Bash(ROOT="/Users/apurvbazari/Desktop/projects/claude-plugins/onboard/.."; for p in notify forge code-review feature-dev claude-md-management pr-review-toolkit plugi…)
  ⎿  Error: Exit code 1
     FOUND:notify
     FOUND:forge
```

Result: detected only `notify` and `forge` — the sibling plugins inside `~/Desktop/projects/claude-plugins/`. Missed **all** marketplace-installed plugins (`superpowers`, `feature-dev`, `code-review`, `pr-review-toolkit`, `commit-commands`, `hookify`, `claude-md-management`, `frontend-design`, `security-guidance`, `chrome-devtools-mcp`, etc.) which live in `~/.claude/plugins/cache/claude-plugins-official/`.

Contrast Phase 2 Custom preset: correctly detected 14+ plugins across both locations.

**Severity:** high — Minimal-preset users with rich plugin installs lose plugin-integration documentation in their generated CLAUDE.md. Consistent with Minimal being opinionated toward "less", but the detection is just broken, not principled.

Side note: the probe loop exited with code 1 mid-iteration, yet the wizard proceeded. The error was swallowed. Worth hardening.

### B9 — "Invalid tool parameters" from `AskUserQuestion`  ⚠️ BUG (same root as Phase 2 B3)

Transcript:
```
⎿  Invalid tool parameters
```

Fired when the wizard tried to present a single-candidate multiSelect (only 1 LSP language = python). Same `options.minItems: 2` schema violation. Wizard recovered via sequential fallback. **Multi-preset reproduction** confirms this is generator-wide, not preset-specific.

**Severity:** low — recoverable, but UX-degrading and trivially fixable by padding single-option questions with an explicit "None" option.

---

## C. Positive findings (wins vs Phase 2)

### C1 — `wizardStatus` fully populated with C4 sweep sub-keys  ✅ WIN

```json
"wizardStatus": {
  "presetUsed": "minimal",
  "exchangesUsed": 3,
  "phasesAsked": ["phase0", "phase1", "phase5.5+5.6+5.7"],
  "phasesSkipped": ["phase2", "phase3", "phase4", "phase5.0", "phase5.1", "phase5.1.1", "phase5.2", "phase5.3", "phase5.4"],
  "escapeHatchTriggered": false
}
```

All 5 C4-required sub-keys present. Phase 2 Custom FAILED this (shape drift). **B2 in Phase 2 is preset-specific — Custom path has the drift, Minimal doesn't.** Narrows the fix surface.

### C2 — `hookStatus` carries rich descriptive notes

```json
"hookStatus": {
  "status": "emitted",
  "events": ["PostToolUse"],
  "notes": "Format-only hook: ruff format (fallback to black) on Python file writes/edits. No lint gates, no quality gates — minimal preset."
}
```

Clear self-documentation. Makes debugging future drift trivial.

### C3 — 7× faster generation at reasonable quality

5m 11s @ `/effort high` (vs Phase 2's 38m @ `/effort xhigh`). Switching off xhigh is non-regressing for small/minimal scopes.

---

## D. Cross-preset bug matrix

Combining Phase 2 + Phase 3a findings:

| Bug | Phase 2 Custom | Phase 3a Minimal | Multi-preset? |
|---|---|---|---|
| B1 MCP skipped with `reason: "no-candidates"` | ❌ FAIL | ❌ FAIL | **YES — generator-wide** |
| B2 `wizardStatus` shape drift (5 sub-keys missing) | ⚠️ WARN×5 | ✅ pass | Custom-only |
| B3 / B9 `AskUserQuestion` single-option schema fail | ⚠️ 2 occurrences | ⚠️ 1 occurrence | **YES — generator-wide** |
| B5 Top-level telemetry NULL (pluginVersion/_generated/timestamp/source) | ✅ pass | ❌ FAIL | Minimal-only |
| B6 Skill snapshot missing despite `status: "emitted"` | ✅ pass | ❌ FAIL | Minimal-only |
| B7 Stale `detect-lsp-signals.sh` path | ✅ pass | ⚠️ BUG | Minimal-only (first-try fail, recovered) |
| B8 Shallow plugin detection (sibling-only) | ✅ pass | ⚠️ BUG | Minimal-only |

**Conclusion:**
- **B1 and B3/B9 are generator-wide.** Must fix before release.
- **B2 is Custom-specific.** Minimal has the right shape — use Minimal's emission code as the reference.
- **B5/B6/B7/B8 are Minimal-specific.** Minimal's generation path is a thinner code path that has drifted from Custom and lost four guards. Treat as a Minimal-path regression — single PR can likely restore all four.

---

## E. Sign-off recommendation — Phase 3a only

| Dimension | Status |
|---|---|
| Checklist (P1-P6) | ✅ PASS (6/6 functionally; P4 calibration-only) |
| Artifact integrity | ⚠️ 4 FAIL — B1 (MCP, shared w/ Phase 2), B5 (null telemetry, new), B6 (missing skill snapshot, new), hook-count calibration (not a real fail) |
| wizardStatus telemetry | ✅ PASS — Minimal emits correct C4 shape |
| Plugin detection completeness | ⚠️ Shallow on Minimal preset (missed marketplace plugins) |
| Release readiness (Phase 3a only) | **HOLD** — B5 (pluginVersion null) and B6 (snapshot coupling broken) are both blocker-class on the Minimal path. Plus B1 still unresolved from Phase 2. |

## F. Cross-phase sign-off trajectory (running)

| Phase | Status | Key blockers |
|---|---|---|
| Phase 1 (automated checks) | ✅ PASS (115/115) | — |
| Phase 2 (nextjs Custom) | **HOLD** | B1 (MCP skipped), B2 (wizardStatus drift), B3 (AskUserQuestion) + G.3 (security-guidance dangling ref) |
| Phase 3a (python Minimal) | **HOLD** | B1 (MCP), B5 (null telemetry), B6 (skill snapshot missing), B8 (shallow plugin detection) |
| Phase 3b (monorepo Standard) | pending | — |
| Phase 3c (empty edge case) | pending | — |
| Phase 4 (drift) | pending | — |
| Phase 5 (forge) | pending | — |
| Phase 6 (CI/audit) | pending | — |

Release readiness (develop→main) as of end of Phase 3a: **HOLD on 6 distinct bugs** (B1 shared, B2 Custom-only, B3 shared, B5/B6/B8 Minimal-only, + G.3 dangling ref). No new conflicts found versus Phase 2's §G routing audit.
