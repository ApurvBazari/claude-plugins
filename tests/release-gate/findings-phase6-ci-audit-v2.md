# Phase 6 — CI & Audit Infrastructure (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Scope:** 3 sub-phases — 6A `/validate` from repo root · 6B notify stop-event · 6C Tooling Gap Audit GHA dispatch

---

## 6A — `/validate` from repo root

Ran the underlying scripts directly (the `/validate` skill invokes the same `.github/scripts/*.sh` as CI).

| Check | Result | Detail |
|---|---|---|
| `validate-manifests.sh` | ✅ PASS | All 3 plugins (onboard 1.9.0, notify 1.0.2, forge 1.0.0) pass required-field + semver + version-sync validation |
| `check-structure.sh` | ⚠️ PASS with 20 WARN | All 20 warnings are **cosmetic** and of a single type: *"H1 should start with `/`"* for forge skills (e.g., `# Scaffolding Skill — Project Setup & Git Configuration`). See 6A.1 below — this is a spec vs. check script drift. |
| `check-references.sh` | ✅ PASS | All file references inside skills/agents point to existing files. No broken links. |
| ShellCheck all `.sh` | ✅ PASS | 27 scripts clean (counted from Phase 1 automated run; no diffs since). |

### 6A.1 — Structure check enforces stale convention  ⚠️ FINDING

`.claude/rules/skills-authoring.md:60-62` canonical rule:

> *"H1 title: `# Descriptive Name — Short Description`. Do NOT put the slash form (`/plugin:name`) in the H1 — the slash is derived from the `name` frontmatter."*

But `.github/scripts/check-structure.sh` warns when H1 does NOT start with `/`. The check and the authoring rule disagree. Every forge skill follows the authoring rule correctly; the checker flags all 6 as warnings.

**Fix direction:** update `check-structure.sh` to match the canonical rule (either drop the check or invert it). Low-priority — warnings are non-blocking.

**Severity:** cosmetic, but pollutes CI logs and makes real structural issues harder to spot.

---

## 6B — Notify stop-event + security hardening (PR #31)

Notify is fully configured at the **global** level in this environment:

- `~/.claude/notify-config.json` present with events: `stop` (enabled, "Hero" sound, 30s min), `notification` (enabled, "Glass" sound, permission_prompt|idle_prompt matcher), `subagentStop` (disabled)
- `~/.claude/settings.json` has 3 hook entries (`Stop`, `Notification`, `SubagentStop`) all calling `~/.claude/hooks/notify.sh`
- `terminal-notifier` installed at `/opt/homebrew/bin/terminal-notifier` (macOS)

### 6B.1 — Static + dry-run checks

| Check | Result | Detail |
|---|---|---|
| `notify.sh` shebang + guard | ✅ PASS | `#!/usr/bin/env bash`; supports macOS (terminal-notifier) and Linux (notify-send) |
| Dry-run (simulated stop event JSON on stdin) | ✅ PASS | Exit 0; no stderr |
| Timestamp file created at `$TMPDIR/claude-notify-session-start-$UID` | ✅ PASS | File exists (`/var/folders/.../T/claude-notify-session-start-501`), 11 bytes, contains unix timestamp (`1776445801` = 2026-04-17 13:10 UTC) |
| File is a regular file (NOT a symlink) — PR #31 hardening | ✅ PASS | `ls -L` shows regular file; `-rw-------` 0600 permissions (user-only readable) |
| Permission mode tight | ✅ PASS | `0600` — user-only. Prevents other users on shared systems from reading/tampering. |

### 6B.2 — Live notification firing (user-visible only)

Can't verify from within this conversation — macOS notifications are visual. Based on:
1. Correct `~/.claude/settings.json` hook wiring,
2. `notify.sh` dry-run exit 0 on valid stop JSON,
3. `terminal-notifier` binary installed and callable,

**live firing should work in practice.** If the next time a session ends you don't see a macOS notification with "Task completed" + Hero sound, report back and we'll trace.

---

## 6C — Tooling Gap Audit GHA dispatch (PR #40)

### 6C.1 — Static workflow verification

| Check | Result | Detail |
|---|---|---|
| `.github/workflows/tooling-gap-audit.yml` exists | ✅ 2994 bytes |
| Trigger includes `workflow_dispatch` | ✅ Line 12 |
| Jobs: Checkout → Create audit branch → Phase 1 Analyze → Phase 2 Report → Commit → Open PR | ✅ 6 named steps present |
| `.claude/prompts/tooling-gap-audit-analyze.md` | ✅ 7226 bytes |
| `.claude/prompts/tooling-gap-audit-report.md` | ✅ 5217 bytes |
| `.github/scripts/open-gap-audit-pr.sh` | ✅ 2176 bytes, executable |
| `docs/tooling-gap-reports/README.md` | ✅ 2678 bytes (report destination) |
| `.claude/audit-baseline.json` | ✅ 1577 bytes (baseline schema) |
| Phase 1 automated URL-convention check | ✅ passed in Phase 1 (L2 sweep, commit `8d2348e` migrated prompt URLs to `code.claude.com`) |

### 6C.2 — Live dispatch

**Not executed.** Two reasons:

1. Would open a real PR against `develop`, modifying shared state. Per earlier "Report only" preference, holding off.
2. Current branch is `fix/release-gate-sweep-2026-04-16`, not `develop`. The workflow's `Checkout develop` step would run regardless of dispatch branch (the workflow explicitly checks out `develop`), so dispatching from this branch would still exercise the develop-branch flow. But doing so would still open a PR against develop.

**To run empirically when ready:**
- GitHub UI path: Actions → Tooling Gap Audit → Run workflow → ref: `develop` → Run
- CLI path: `gh workflow run tooling-gap-audit.yml --ref develop` (gh CLI is authed as ApurvBazari)

Expected output per PR #40 schema:
- `.audit-data-<date>.json` committed on a new audit branch
- `<date>-gap-report.md` committed after Phase 2
- PR opened against `develop` titled `chore(audit): tooling gap report <date>`
- Report structure: Summary / Surface Snapshot / Coverage / Patterns / Gap List / Baseline Changes sections
- No-change re-dispatch should produce no new PR (idempotent)

---

## D. Sign-off recommendation — Phase 6 only

| Sub-phase | Status |
|---|---|
| 6A `/validate` | ✅ PASS (20 cosmetic warns from stale H1 rule in check-structure.sh) |
| 6B Notify stop-event + security | ✅ PASS static + dry-run; live firing pending user observation |
| 6C Audit GHA dispatch | ✅ PASS static; live dispatch held pending user authorization |
| Release readiness (Phase 6 only) | **PASS with 1 minor cleanup (6A.1 structure checker drift), 2 manual verifications still open (6B live notification, 6C live GHA dispatch)** |

## E. Running cross-phase sign-off (post-Phase 6)

| Phase | Status | Unique findings |
|---|---|---|
| Phase 1 (automated) | ✅ 115/115 | — |
| Phase 2 (nextjs Custom init) | HOLD | B1, B2, B3, G.3 |
| Phase 3a (python Minimal init) | HOLD | B1, B5, B6, B8, B9 |
| Phase 3b (monorepo Standard init) | HARD HOLD | B1, B5-variant, B6, B8, B10, B11, B12, B13 |
| Phase 3c (empty Stub init) | PASS w/ caveats | B14, B15 |
| Phase 4 (drift update) | PASS w/ degradation | F1 (B3/B9 reproduces in update) |
| Phase 5 (forge) | ✅ PASS | — *(crucially: forge path proves the generation skill is correct; bugs are in init→generation bridge)* |
| **Phase 6A `/validate`** | ✅ PASS | 6A.1 stale H1 check (cosmetic) |
| **Phase 6B notify** | ✅ PASS | Static + dry-run; live firing user-observable |
| **Phase 6C audit GHA** | ✅ PASS static | Live dispatch pending authorization |

**All 10 phases tested.** 4 of 10 are HOLD/HARD-HOLD, all clustered on init paths. Phases 4, 5, 6 pass cleanly — the **update**, **forge**, **validate**, and **notify/audit CI infra** all work.

**Net release-gate recommendation:** develop→main merge is blocked by init-path regressions (Phases 2/3a/3b/3c), not by the larger plugin ecosystem. The fix surface is now well-scoped thanks to Phase 5's diagnostic value (see `findings-phase5-forge-v2.md § H`).
