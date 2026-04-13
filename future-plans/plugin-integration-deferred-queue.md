# Plugin Integration — Deferred Queue

> Last updated: 2026-04-13
> Source session: the Plugin Integration upgrade session that produced 11 commits on
> `feat/forge-plugin-integration-upgrade` (merged to main 2026-04-13).

---

## Completed

| Item | Commit / PR | Status |
|------|-------------|--------|
| D1: `/onboard:evolve` plugin-integration awareness | `8094fa8` | DONE |
| D2: Adaptive SessionStart reminder suppression | `bb02a9a` | DONE |
| Branch cleanup (9 orphaned + 5 stale remote branches) | `61dc293` | DONE |
| `.pre-onboard` gitignore addition | `61dc293` | DONE |
| Observe plugin removal + E7 drop | PR #13 (`chore/remove-observe-plugin`) | DONE |
| CI workflow prompt updates (3-plugin count + stale comment fix) | PR #13 | DONE |

---

## Tier 1 — Complete

All Tier 1 items are done. No remaining actionable work.

### Vercel bootstrap hook false-trigger audit — EXTERNAL

Not in this repo — external plugin config issue. Pattern matchers need Vercel-specific content checks (e.g., `vercel.json`, `next.config.*`) before triggering, not just basename matches.

---

## Tier 2 — Backlog (only if needed)

| # | Item | Notes |
|---|------|-------|
| D3 | `autonomyLevel=strict` mandatory-invocation mode | Only build if a user requests it |
| E1 | Sibling architectural pattern detection (G9) | Forge Phase 2 improvement — detect patterns from neighbor projects |
| E2 | Full phase-locked plugin activation | Large scope, deeper harness integration |
| E3 | Deeper `/forge:status` artifact validation | Parse CLAUDE.md structure, verify hooks match registry |
| E4 | Cross-session memory integration | Experimental — auto-save memories from CLAUDE.md changes |
| E6 | Feature-start detector ML classification | Research-level, far-future |

---

## Dropped

| # | Item | Reason |
|---|------|--------|
| E5 | Engineering plugin in-forge fallback | Rejected — would duplicate 500-1000 LOC. Forge already gracefully skips Phase 4 when absent. Only revisit if upstream plugin becomes unmaintained. |
| E7 | Hook telemetry tracking (fire/skip/dismiss) | Observe plugin removed — native Claude Code OTEL covers general observability. E7's unique value (hook effectiveness) didn't justify the architectural complexity (wrapper layer, cross-plugin contracts, dismiss correlation). Dropped 2026-04-13. |
| — | Observe plugin | Removed entirely (PR #13). ~80% overlap with native Claude Code OTEL + community tools. Reduces plugin count 4→3, eliminates `onboard → observe` cross-plugin contract. |

---

## Architecture (current)

```
.claude-plugin/marketplace.json (3 plugins)
         │
         ├──→ onboard/   ← codebase analyzer + tooling generator
         ├──→ forge/     ← project scaffolder with AI-native tooling
         └──→ notify/    ← cross-platform system notifications
```

Cross-plugin contracts:
- `forge → onboard` (headless generation via `/onboard:generate`)
- `forge → notify` (plugin discovery)

---

## Verification summary (from original integration upgrade)

| Smoke test | Scope | Result |
|---|---|---|
| VP1-full | 5 plugins, balanced autonomy, Next.js scaffold | 45/45 PASS |
| VP2 | 0 plugins, graceful degradation | 22/22 PASS |
| VP3 | 2 plugins, always-ask autonomy (preCommit downgrade) | 22/22 PASS |
| B++3 | 2 plugins, balanced autonomy, MUST-list re-validation | 14/14 PASS (10 invariant + 4 behavioral) |
| VP1-lite | Hand-crafted hook behavioral tests | 23/23 PASS |
| Static validation | /validate marketplace check, shellcheck, cross-plugin consistency | 4/4 PASS |
| **Total** | | **130/130 PASS** |

> Note: Verification was run before observe removal. Post-removal validation (shellcheck, manifest check, reference grep) passed on PR #13.
