# Phase 4 — /onboard:update drift lifecycle on test-nextjs (v2, 2026-04-17 release-gate sweep)

**Branch under test:** `fix/release-gate-sweep-2026-04-16`
**Onboard version:** 1.9.0
**Run model:** Opus 4.7 (1M context), `/effort xhigh`
**Target:** `test-nextjs` (from Phase 2) with 5 synthetic mutations applied by `mutate-for-drift.sh`
**Path taken:** User chose **Apply all** on the approval pre-question
**Generation time:** 4m 39s · ~$2.84 session cost
**Drift verifier:** `tests/release-gate/verify-drift-output.sh` → **11 PASS / 1 WARN / 0 FAIL**

---

## A. M2 contract — approval-flow compliance (D1-D3)

| # | Check | Result | Evidence |
|---|---|---|---|
| D1 | Approval is a **single** AskUserQuestion call (pre-question + per-group multiSelects) | ⚠️ DEGRADED PASS | Transcript shows `Loading AskUserQuestion to gather approvals. ⎿ Invalid tool parameters` — the single-call attempt FAILED with the same B3/B9 schema bug we've seen in every phase. Update skill then fell back to **3 sequential** AskUserQuestion calls: (1) pre-question `Apply all / Review / Apply later / Skip`, (2) multiSelect for gaps+new-practices, (3) single-select for user-edit handling. Content-wise M2 intent preserved; form-wise M2 contract not met. |
| D2 | Offer groups categorized: Artifact gaps / User-edits / New deps+languages / Best practices (only if ≥1 offer) | ✅ PASS | 3 groups surfaced (Artifact gaps, New deps+languages, User-edits). Best practices not surfaced — no such offers existed. Verify script's §7 confirmed absence of pending-updates snapshot is valid for Apply-all path. |
| D3 | Apply later test (optional) | ⚪ SKIPPED | User chose Apply all per the prep brief. Snapshot absence confirmed via verify §7. |

**M2 verdict:** content preserved, form regresses — **the same AskUserQuestion single-option bug (B3/B9) now reproduces in the update skill**. This is generator-wide, not confined to init.

---

## B. Per-mutation detection & handling (D4-D8)

| # | Mutation | Detected under | Action | Verify result |
|---|---|---|---|---|
| D4 | `.claude/rules/api.md` deleted | "Artifact Gaps (4b.2)" | Regenerate approved → written 69 lines, proper frontmatter + maintenance header | ✅ PASS (verify §1: rules dir has 6 files; api.md 3434 bytes) |
| D5 | `task-clarifier.md` model changed → `claude-haiku-4-5-20251001` | "Agent Frontmatter Drift (4b.6)" — classified as `userEdit` (informational) | Offered "Refresh snapshot to match live" — live file untouched, snapshot refreshed, `source` field changed from `wizard-default` to `user-tweaked` | ✅ PASS (verify §2: haiku still set in live file) |
| D6 | `solo-minimal.md` body appended `## Custom Addition` paragraph | "Output Style Drift (4b.7)" — **NOT flagged** (body outside snapshot scope) | No action needed | ✅ PASS (verify §3: body addition preserved) |
| D7 | `@anthropic-ai/sdk@0.30.0` added to `package.json` deps | "Built-in Skills Drift (4b.9)" — `newSkill: /claude-api` | Add approved → `/claude-api` appended to CLAUDE.md built-in-skills block + snapshot + `builtInSkillsStatus.planned`/`.generated` + `detectionSignals["/claude-api"]: "dependency:@anthropic-ai/sdk"` | ✅ PASS — generated + documented + snapshot updated |
| D8 | `src/main.rs` added | "LSP Plugin Drift (4b.8)" — `newLanguage: rust-analyzer-lsp` | Install approved → `claude plugin install rust-analyzer-lsp --scope user` executed; snapshot + CLAUDE.md LSP section + `lspStatus.autoInstalled: ["rust-analyzer-lsp"]` | ✅ PASS — real `claude plugin install` command executed successfully |

**Per-mutation verdict:** 5/5 mutations detected and handled correctly. This is the **highest-quality preset path we've tested**. The 4b.x detection rules work end-to-end.

Note on D8 "auto-checked by default" M2 requirement: can't verify strictly because the single-call fallback changed how the multiSelect rendered. User's selection log shows `Install rust-analyzer-lsp (pre-checked)` which implies it WAS pre-checked in the fallback multiSelect — so content-wise M2 pre-check behavior preserved, just in the fallback form rather than the canonical single call.

---

## C. L2 URL convention compliance (D9)

- **Verify §8:** no `docs.anthropic.com/en/docs/claude-code` references leaked into project artifacts.
- No WebFetch calls visible in transcript (update didn't hit external docs this run).
- PASS.

---

## D. Post-update artifact state (D10-D12)

| # | Check | Result | Evidence |
|---|---|---|---|
| D10 | `api.md` regenerated | ✅ PASS | 69 lines, includes frontmatter (`paths: src/app/api/**/route.ts`), maintenance header, 6 sections (file shape / validation / auth / database / errors / response / testing / security sensitivity) |
| D11 | `task-clarifier.md` model preserved | ✅ PASS | `grep "^model:" task-clarifier.md` → `model: claude-haiku-4-5-20251001` (unchanged from mutation) |
| D12 | Session returned cleanly | ✅ PASS | Transcript shows clean prompt return after update handoff |

---

## E. New positive findings in Phase 4

### E1 — `updateHistory` array added to `onboard-meta.json`

New top-level array append-on-each-update:

```json
"updateHistory": [
  {
    "date": "2026-04-17T13:45:00Z",
    "pluginVersion": "1.9.0",
    "source": "onboard:update",
    "changes": [
      "Regenerated .claude/rules/api.md (was missing from disk)",
      "Installed rust-analyzer-lsp (new language: src/main.rs) ...",
      "Added /claude-api to built-in skills ...",
      "Added LSP entry for rust-analyzer-lsp in CLAUDE.md Plugin Integration",
      "Accepted user-edit on task-clarifier.model ..."
    ]
  }
]
```

Good design. Gives `/onboard:status` a history to query against. Not documented in `verify-init-output.sh` (doesn't check for this), so not tested in Phase 2/3 runs — but it shows up here consistently.

### E2 — `agentStatus` source tracking

`onboard-meta.json` upgraded `task-clarifier.source` from `wizard-default` to `user-tweaked` after the update classified the model change as `userEdit`. This is exactly the right behavior — the snapshot-refresh-only pattern preserves user intent without overwriting.

### E3 — Real `claude plugin install` command invoked successfully

Transcript shows:
```
claude plugin install rust-analyzer-lsp --scope user
⎿ Installing plugin "rust-analyzer-lsp"...✔ Successfully installed plugin: rust-analyzer-lsp@claude-plugins-official (scope: user)
```

`lspStatus.autoInstalled: ["rust-analyzer-lsp"]` reflects this. The update skill went beyond detection/documentation into actually running the plugin manager. This is the first phase where we see onboard exercise real plugin-management integration end-to-end.

### E4 — `detectionSignals` object explains WHY a skill was added

```json
"detectionSignals": {
  "/claude-api": "dependency:@anthropic-ai/sdk"
}
```

Single-key object that traces each emission back to the stack signal that caused it. Makes audits cheap — no guessing which signal triggered which output.

---

## F. Issues observed

### F1 — `AskUserQuestion` single-call approval errored (B3/B9 reproduction)  ⚠️ BUG

Same schema bug seen in Phase 2 (×2) and Phase 3a (×1). Now reproduces in the update skill. The single-call shape (pre-question + up to 4 multiSelect groups in one call) hits `options.minItems: 2` when a group has only 1 candidate item.

**Status:** generator-wide — confirmed across init (Custom, Minimal) AND update. The fix direction is the same as proposed earlier: pad single-option questions with an explicit "None" option or short-circuit to single-select.

### F2 — Verify script brittle jq path check  ⚠️ VERIFY-SCRIPT BUG (not onboard)

`verify-drift-output.sh:85`:
```bash
BSS=$(jq '.builtInSkillsStatus // {}' .claude/onboard-meta.json)
if echo "$BSS" | jq -e 'to_entries | map(select(.key | test("claude-api";"i"))) | length > 0'; then
```

This tests **top-level keys** of `builtInSkillsStatus` for "claude-api". But `/claude-api` is nested in `.planned[]`, `.generated[]`, `.detectionSignals["/claude-api"]` — not a top-level key. The check always WARNs even when the data is correct, as observed here.

**Fix:** change to `jq -e '.builtInSkillsStatus | tostring | test("claude-api"; "i")'` or walk the nested structures explicitly.

**Severity:** low — false-negative WARN in verify script, the actual onboard data is correct.

### F3 — Plugin drift (4b.1) not formally probed  ⚠️ NOTE

Update skill noted:
> *"Not formally probed (no `claude plugin list --json` in this environment). Skills list from session suggests baseline plugins all loaded; no definitive additions/removals."*

Meaning: the skill detected `claude` CLI is available but did not invoke `claude plugin list` for authoritative plugin state. Phase 4C from the manual plan (install superpowers, then uninstall, observe drift) was skipped to keep the test tight. Would be worth a follow-up run to exercise the plugin-drift path explicitly.

---

## G. Sign-off recommendation — Phase 4 only

| Dimension | Status |
|---|---|
| Drift detection (all 5 mutation types) | ✅ PASS (5/5 correctly classified) |
| User-edit preservation | ✅ PASS (live file untouched, snapshot refreshed) |
| Output-style body-edit exemption | ✅ PASS (body outside snapshot scope, not flagged) |
| Real plugin install (rust-analyzer-lsp) | ✅ PASS (`claude plugin install --scope user` succeeded) |
| New artifacts introduced (updateHistory, detectionSignals, source tracking) | ✅ POSITIVE FINDINGS |
| M2 contract (single AskUserQuestion call) | ⚠️ DEGRADED — content preserved, form broken (B3/B9 reproduces) |
| URL convention (L2) | ✅ PASS |
| Release readiness (Phase 4 only) | **PASS with 1 degradation** — the update skill itself works well end-to-end; only known-bug B3/B9 affects form compliance. |

## H. Running cross-phase sign-off (post-Phase 4)

| Phase | Status | Preset | Summary |
|---|---|---|---|
| Phase 1 (automated) | ✅ | — | 115/115 |
| Phase 2 (nextjs) | HOLD | Custom | B1, B2, B3, G.3 |
| Phase 3a (python) | HOLD | Minimal | B1, B5, B6, B8, B9 |
| Phase 3b (monorepo) | HARD HOLD | Standard | B1, B5-variant, B6, B8, B10, B11, B12, B13 |
| Phase 3c (empty) | PASS w/ caveats | Stub | B14, B15 |
| **Phase 4 (drift)** | **PASS w/ degradation** | — | F1 (B3/B9 reproduction in update skill) |
| Phase 5 (forge) | pending | — | — |
| Phase 6 (CI/audit) | pending | — | — |

**Distinct bugs tracked so far:** 17 (B1, B2, B3/B9/F1, B5+variant, B6, B7, B8, B10, B11, B12, B13, B14, B15, B16, F2 verify-script, F3 plugin-drift-untested, G.3 dangling ref).

### Phase 4 key insight

The update skill is the **most mature piece of onboard** we've tested so far. Detection classifies correctly, user-edit preservation works (the hardest UX problem — don't revert developer changes), real plugin install commands execute, and the metadata output (`updateHistory`, `detectionSignals`, `source: user-tweaked`) is richer than the init path emits. The single outstanding defect is B3/B9 (inherited, not Phase 4-specific).

Recommendation: **after fixing B3/B9, Phase 4's update flow can ship as-is.** No Phase 4-specific blockers.
