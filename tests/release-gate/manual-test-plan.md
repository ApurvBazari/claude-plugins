# Release Gate — Manual Test Plan

Comprehensive end-to-end testing for the develop → main release covering PRs #16-#40 + the **2026-04-16 release-gate fix sweep** (16 commits across C1-C4 / M1-M6 / L1-L5+L6 fixing the gaps the previous test run surfaced).

**Prerequisites:**
1. Run `./tests/release-gate/run-automated-checks.sh` — all checks must pass (now includes URL convention, lifecycle-setup absence, wizard cap removal checks)
2. Run `./tests/release-gate/setup-test-repos.sh` — creates 4 scratch repos (test-nextjs, test-python, test-monorepo, test-empty)

Test repos are created at `$TMPDIR/release-gate-tests/`.

---

## Phase 2: Fresh `/onboard:init` — Rich Project

**Target:** `$TMPDIR/release-gate-tests/test-nextjs`
**PRs covered:** #30, #32, #34, #35, #36, #37, #38, #39

```bash
cd $TMPDIR/release-gate-tests/test-nextjs
claude
# Then run: /onboard:init
```

### Skills migration (PR #30)

- [ ] Type `/onboard:` — autocomplete shows only 5 user-facing skills: `init`, `update`, `status`, `verify`, `evolve`
- [ ] Internal skills (`wizard`, `analysis`, `generation`, `generate`) are NOT in autocomplete

### Wizard flow (PRs #34-#39 + 2026-04-16 fix sweep C4 / M1)

Answer "Standard" or "Custom" preset when prompted. For thorough testing, choose Custom and opt YES to advanced options.

- [ ] **Phase 0** — Preset selection uses **AskUserQuestion** with options `Minimal / Standard (Recommended) / Comprehensive / Custom` — NOT inline numbered text "Type 1/2/3" (M1)
- [ ] **Phase 5.0 (Custom only)** — Mid-wizard escape hatch fires once near start of Phase 5: AskUserQuestion with `Continue customizing` (default) vs `Use Quick Mode defaults from here` (C4)
- [ ] **Phase 5.1** — Advanced hook opt-in question appears. Answer YES.
- [ ] **Phase 5.1 follow-up** — When YES, the 9 advanced events are presented as **3 thematic multiSelect questions in ONE AskUserQuestion call**: `Lifecycle events`, `User events`, `Tool events` (M1 — single exchange covers all 9)
- [ ] **Phase 5.1.1** — Execution type selection per judgment-capable event appears with cost-table preamble
- [ ] **Phase 5.2** — Skill tuning gate appears. Accept defaults. The chosen model is captured here (or defaults to `claude-opus-4-7[1m]` for non-Custom presets per L1)
- [ ] **Phase 5.3** — Agent tuning gate appears. Accept defaults.
- [ ] **Phase 5.4** — Output style tuning appears. Verify archetype inference mentions `production-ops` (Vercel + team signals)
- [ ] **Phase 5.6 + 5.7 — combined exchange** — LSP plugins AND built-in skills are presented as TWO multiSelect questions in ONE AskUserQuestion call (C4 + M1). `typescript-lsp` pre-checked (≥10 .tsx files); core skills (`/loop`, `/simplify`, `/debug`, `/pr-summary`) pre-checked; `/schedule` visible (project has `.github/workflows/`)
- [ ] **Phase 6 summary** — explicitly shows `Model: <model-id> (<source>)` line where source is `your selection` / `preset default` / `fallback default` (L1)
- [ ] **No separate post-summary "Which model would you like to use?" prompt** — model is resolved from wizard answers via Step 3.1 of init (L1)
- [ ] **No hard 6-exchange cap** — wizard runs every applicable phase to completion; Custom-preset typical exchange count 5–8 (C4)

### Generation verification (PRs #32, #34-#39)

After init completes, verify the generated artifacts:

**Hook schema (PR #32):**
```bash
cat .claude/settings.json | jq '.hooks'
```
- [ ] Events use nested `hooks: [...]` array structure, NOT flat `{ "type": "command" }` directly in event array

**Expanded hooks (PR #34):**
```bash
cat .claude/settings.json | jq '.hooks | keys'
```
- [ ] Keys include expanded events beyond the original 5 (look for: `SessionStart`, `UserPromptSubmit`, `PreCompact`, `TaskCreated`, etc.)
- [ ] If opted YES to advanced types: at least one `"type": "prompt"` or `"type": "agent"` entry present

**MCP generation (PR #35):**
```bash
cat .mcp.json | jq '.mcpServers | keys'
```
- [ ] Contains `context7` (always)
- [ ] Contains `vercel` (vercel.json present)
- [ ] Contains `prisma` (prisma/ directory present)
- [ ] `.claude/rules/mcp-setup.md` exists with auth instructions

**Agent frontmatter (PR #36):**
```bash
head -20 .claude/agents/*.md
```
- [ ] Each agent has YAML frontmatter between `---` markers
- [ ] Frontmatter includes `tools:` field
- [ ] Frontmatter includes at least some of: `model`, `isolation`, `color`, `effort`

**Output styles (PR #37):**
```bash
ls .claude/output-styles/
head -10 .claude/output-styles/*.md
```
- [ ] At least one `.md` file exists in `.claude/output-styles/`
- [ ] File has YAML frontmatter with `name:` and `description:`
- [ ] Archetype matches production-ops (for Vercel project)

**LSP (PR #38):**
- [ ] `typescript-lsp` was installed (check: `claude plugin list 2>/dev/null | grep typescript-lsp`)
- [ ] `.claude/onboard-lsp-snapshot.json` exists with `recommended` and `accepted` arrays

**Built-in skills (PR #39):**
```bash
grep -A 20 'Built-in Claude Code skills' CLAUDE.md
```
- [ ] Section exists in CLAUDE.md with stack-specific examples
- [ ] `/loop`, `/simplify`, `/debug`, `/pr-summary` mentioned as core
- [ ] `.claude/onboard-builtin-skills-snapshot.json` exists

**Telemetry completeness (C1 + C4 release-gate sweep):**
```bash
cat .claude/onboard-meta.json | jq 'keys'
cat .claude/onboard-meta.json | jq '{mcpStatus: .mcpStatus.status, outputStyleStatus: .outputStyleStatus.status, lspStatus: .lspStatus.status, builtInSkillsStatus: .builtInSkillsStatus.status}'
cat .claude/onboard-meta.json | jq '.wizardStatus'
cat .claude/onboard-meta.json | jq '.pluginVersion'
```
- [ ] Contains all status keys: `mcpStatus`, `skillStatus`, `agentStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`
- [ ] **Each Phase 7 status object has `.status` field** with value in `{emitted, skipped, declined, failed}` (C1)
- [ ] **`wizardStatus` present** with `presetUsed` / `exchangesUsed` / `phasesAsked` / `phasesSkipped` / `escapeHatchTriggered` (C4)
- [ ] **`pluginVersion` matches installed onboard version** — NOT a stale literal `1.2.0` (L4 — should reflect 1.10.0+ post-release-gate sweep)

**Snapshot files:**
- [ ] `.claude/onboard-mcp-snapshot.json` exists
- [ ] `.claude/onboard-skill-snapshot.json` exists
- [ ] `.claude/onboard-agent-snapshot.json` exists
- [ ] `.claude/onboard-output-style-snapshot.json` exists
- [ ] `.claude/onboard-lsp-snapshot.json` exists
- [ ] `.claude/onboard-builtin-skills-snapshot.json` exists

**Session validation:**
- [ ] Close and reopen Claude Code in the project — session starts cleanly with no schema errors

---

## Phase 3: Fresh `/onboard:init` — Variant Projects

### test-python (minimal)

```bash
cd $TMPDIR/release-gate-tests/test-python
claude
# Run: /onboard:init — choose Minimal or Standard preset
```

- [ ] Solo archetype detected (no team/security/production signals)
- [ ] `.mcp.json` contains only `context7` (no vercel, no prisma, no chrome-devtools)
- [ ] Phase 5.6: `pyright-lsp` appears as candidate (may not be pre-checked with only 5 .py files)
- [ ] Minimal hook set generated (fewer events than the rich project)
- [ ] Output style maps to solo archetype (not production-ops)
- [ ] Session starts cleanly

### test-monorepo (Turborepo)

```bash
cd $TMPDIR/release-gate-tests/test-monorepo
claude
# Run: /onboard:init — choose Standard preset
```

- [ ] Subdirectory CLAUDE.md candidates offered (apps/web, apps/api, packages/)
- [ ] `/codebase-visualizer` appears in Phase 5.7 built-in skills multiSelect
- [ ] Multiple LSP candidates shown (`typescript-lsp` for .ts files)
- [ ] Complexity score inferred as medium or higher (multiple packages)
- [ ] Session starts cleanly

### test-empty (edge case)

```bash
cd $TMPDIR/release-gate-tests/test-empty
claude
# Run: /onboard:init
```

- [ ] No crashes — wizard completes gracefully
- [ ] No schema errors in generated artifacts
- [ ] Minimal/default hooks only (no advanced types offered)
- [ ] No MCP servers beyond context7 (or no MCP at all)
- [ ] No LSP candidates (no source files detected)
- [ ] Session starts cleanly

---

## Phase 4: Drift Lifecycle

**Target:** `$TMPDIR/release-gate-tests/test-nextjs` (after Phase 2 init)
**PRs covered:** #33, #34-#39

### 4A: `/onboard:update` — Artifact drift (M2 release-gate sweep — AskUserQuestion approval)

```bash
cd $TMPDIR/release-gate-tests/test-nextjs
claude
```

**M2 contract — approval flow:**

- [ ] Approval prompt is a **single AskUserQuestion call** (not inline "all / specific / none" text). Includes a pre-question (`Review and pick` / `Apply all` / `Apply later` / `Skip`) plus per-group multiSelect questions in the same call.
- [ ] Offer groups are categorized: `Artifact gaps`, `User-edit detections`, `New dependencies / languages`, `Best practice suggestions` (only groups with ≥1 offer render)
- [ ] **Apply later test**: Choose `Apply later` in the pre-question. Verify `.claude/onboard-pending-updates.json` is written with a `pendingOffers[]` array. Re-running `/onboard:update` should re-present the pending items merged with any new drift; after applying, the snapshot file is deleted.
- [ ] Doc URLs fetched by update (Step 4) use `https://code.claude.com/docs/en/*`, NOT legacy `docs.anthropic.com/en/docs/claude-code/*` (L2)

**Test 1: Deleted artifact**
```bash
# Before entering Claude, delete a generated rule:
rm .claude/rules/*.md  # pick one rule file
# Then in Claude: /onboard:update
```
- [ ] Update detects the missing artifact under "Artifact Gaps"
- [ ] Offers to regenerate (in the `Artifact gaps` AskUserQuestion group)
- [ ] On approval, rule file is restored

**Test 2: User-edited agent frontmatter**
```bash
# Edit an agent's model field in .claude/agents/*.md
# Change model: to a different value (e.g., sonnet → haiku)
# Then: /onboard:update
```
- [ ] Update classifies the change as `user-edit`
- [ ] Does NOT revert the change (preserves user edits)

**Test 3: Output style body edit**
```bash
# Edit the body (below frontmatter) of .claude/output-styles/*.md
# Add a paragraph of custom instructions
# Then: /onboard:update
```
- [ ] Update does NOT flag this change (body is outside snapshot scope)

**Test 4: New dependency signal**
```bash
# Add @anthropic-ai/sdk to package.json dependencies
# Then: /onboard:update
```
- [ ] Update Step 4b.9 flags `/claude-api` as a newly relevant built-in skill

**Test 5: New language file (M2 release-gate sweep — first-class numbered offer + auto-checked)**
```bash
# Create a Rust file:
echo 'fn main() {}' > src/main.rs
# Then: /onboard:update
```
- [ ] Update Step 4b.8 lists `rust-analyzer-lsp` as a `newLanguage` candidate
- [ ] **`rust-analyzer-lsp` appears as a first-class option in the `New dependencies / languages` AskUserQuestion group, NOT as narrative prose** (M2 / A8)
- [ ] **`rust-analyzer-lsp` is auto-checked by default** (matches wizard Phase 5.6 pre-check behavior, M2)

### 4B: `/onboard:evolve` — Auto-apply

```bash
# With the main.rs still present:
/onboard:evolve
```
- [ ] Evolve re-prompts for `rust-analyzer-lsp` (via batched multiSelect, NOT silent install)

### 4C: Plugin drift (PR #33)

```bash
# Install superpowers plugin:
claude plugin install superpowers
# Then: /onboard:update
```
- [ ] Update surfaces "Plugin Drift" finding with `superpowers` listed
- [ ] On approval: CLAUDE.md gains marker-wrapped `## Plugin Integration` section
- [ ] `onboard-meta.json.detectedPlugins.installedPlugins` includes `"superpowers"`

```bash
# Now uninstall:
claude plugin uninstall superpowers
# Then: /onboard:update
```
- [ ] Update lists the removal
- [ ] On approval: CLAUDE.md markers stripped, obsolete hooks/artifacts cleaned

---

## Phase 6: CI & Audit Infrastructure

**PRs covered:** #17, #19, #31, #40

### 6A: `/validate` from repo root

```bash
cd /path/to/claude-plugins
claude
# Run: /validate
```
- [ ] All checks pass (structure, manifests, references, ShellCheck)

### 6B: Notify security hardening (PR #31)

```bash
# From a project with notify configured:
# Trigger a stop event (let Claude finish a task with notify hooks active)
```
- [ ] Notification fires
- [ ] Timestamp file written at `$TMPDIR/claude-notify-session-start-$UID` (not a symlink)

### 6C: Tooling gap audit workflow (PR #40)

1. Go to **GitHub → Actions → Tooling Gap Audit → Run workflow** (workflow_dispatch)
2. Select branch: `develop`
3. Click **Run workflow**

- [ ] Workflow starts and Phase 1 (Analyze) begins
- [ ] Phase 1 completes — check for `.audit-data-<date>.json` in the commit
- [ ] Phase 2 (Report) completes — check for `<date>-gap-report.md` in the commit
- [ ] PR opens against `develop` with title `chore(audit): tooling gap report <date>`
- [ ] Report follows the strict schema (Summary, Surface Snapshot, Coverage, Patterns, Gap List, Baseline Changes sections)

**No-change cycle:**
4. Re-trigger workflow_dispatch immediately
- [ ] Workflow completes but no new PR opens (content identical to previous report)

---

## Sign-off

Once all phases pass:

| Phase | Status | Notes |
|---|---|---|
| Phase 1 (automated) | [ ] Pass | `run-automated-checks.sh` — now includes URL convention, lifecycle-setup absence, wizard cap removal |
| Phase 2 (nextjs init) | [ ] Pass | Expect findings-phase2-nextjs-v2.md with ≥30 pass / 0 fail (was 14 pass / 13 warn / 6 fail pre-sweep) |
| Phase 3a (python) | [ ] Pass | |
| Phase 3b (monorepo) | [ ] Pass | |
| Phase 3c (empty) | [ ] Pass | |
| Phase 4 (drift) | [ ] Pass | Expect findings-phase4-drift-v2.md — AskUserQuestion approval flow; auto-checked LSP for new-language |
| Phase 5 (CI/audit) | [ ] Pass | |

**Release-ready:** All phases passed. Safe to merge develop → main.

## Legend for this checklist

- `(L#)`, `(M#)`, `(C#)` — finding identifiers from the 2026-04-16 release-gate fix sweep (see `tests/release-gate/findings-*.md` for context)
- `(PR #NN)` — prior enhancement PRs (onboard 1.3.0→1.9.0 + audit infrastructure)
- Where a check cites both, the behavior comes from the original PR and is tightened / corrected by the sweep fix.
