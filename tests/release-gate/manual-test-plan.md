# Release Gate — Manual Test Plan (onboard v3)

End-to-end manual testing for the develop → main release of **onboard 3.0.0** — the research-grounded onboarding rewrite. This plan exercises the v3 Phase 0–7 flow (`/onboard:start`), the Minimal / Standard / Comprehensive **profiles** (no Custom preset, no Quick Mode), the grounded confirm/override wizard, research-consuming generation, the drift lifecycle (`update` / `evolve` / `adopt`), CI/audit infrastructure, and the **durable phase-tracking** feature.

The automated belt (`run-automated-checks.sh`) parses static plugin sources and generated-artifact schemas; it does NOT exercise a live `/onboard:start` run. This manual plan covers the live behavior the belt cannot reach.

**Prerequisites:**
1. Run `./tests/release-gate/run-automated-checks.sh` — all checks must pass (242 checks: structure, manifests, references, ShellCheck, URL convention, phase-numbering belt, generated-artifact schemas via `verify-init-output.sh`).
2. Run `./tests/release-gate/setup-test-repos.sh` — creates 4 scratch repos (`test-nextjs`, `test-python`, `test-monorepo`, `test-empty`).

Test repos are created at `$TMPDIR/release-gate-tests/`. The drift scenario uses `./tests/release-gate/mutate-for-drift.sh` to mutate `test-nextjs` after its initial setup.

---

## Scenario A: Fresh `/onboard:start` — Rich Project (nextjs)

**Target:** `$TMPDIR/release-gate-tests/test-nextjs` (Next.js + Vercel + Prisma)

```bash
cd $TMPDIR/release-gate-tests/test-nextjs
claude
# Then run: /onboard:start
```

When prompted at Phase 2 profile-select, choose **Comprehensive** for the most thorough run, and opt into the advanced tuning cards in the wizard so the full surface is exercised.

### Skills surface

- [ ] Type `/onboard:` — autocomplete shows only the user-facing skills: `start`, `update`, `adopt`, `check`, `verify`, `evolve`
- [ ] Internal skills (`wizard`, `analysis`, `generation`, `generate`, `research`) are NOT in autocomplete

### Phase 0 — Empty-Repo Guard

- [ ] Because `test-nextjs` has source files (`SRC_COUNT > 0`), Phase 0 is skipped silently — the 3-option empty-repo menu (Abort / Placeholder only / Generate canonical stub) does NOT appear

### Phase 1 — Recon

- [ ] No substantial existing Claude config, so the "Existing config" prompt (Adopt / Update / Start fresh / Cancel) does NOT appear — flow proceeds directly to analysis
- [ ] `codebase-analyzer` runs read-only (native Glob/Grep/Read + git one-liners) — nothing is written to disk during recon
- [ ] An analysis summary is presented: project type, languages with file counts, frameworks with versions, testing, CI/CD, complexity score — and asks for confirmation before proceeding
- [ ] Confirm the summary (or correct it); the wizard does NOT start until you confirm

### Phase 2 — Research

- [ ] **profile-select** uses **AskUserQuestion** (single-select, header `Profile`) with exactly three options: `Minimal` / `Standard (Recommended)` / `Comprehensive` — there is **no Custom option** and **no "Type 1/2/3" inline numbered prompt**
- [ ] Choosing `Comprehensive` maps to `depth: "comprehensive"` and records `selectedPreset`
- [ ] The research engine (`Skill(onboard:research)`) fans out read-only specialists per dimension, verifies their claims against the code, then asks **where the four human-readable artifacts land** (committed `docs/onboard/` / local `.claude/` / none)
- [ ] `.claude/onboard-research.json` is written (the dossier), plus — for the committed/local choice — `docs/onboard/` architecture map, risk register, and glossary
- [ ] Research is read-only — no source files are modified

### Phase 3 — Grounded Wizard

The v3 wizard **confirms/overrides** what research inferred — it does NOT interrogate from scratch. Expect ~2–3 `AskUserQuestion` exchanges.

- [ ] **Exchange 1 (workflow & preferences)** — confirm/override cards for `teamSize`, `projectMaturity`, `codeStyleStrictness`, `securitySensitivity`, `codeReviewProcess`, `branchingStrategy`, `deployFrequency`; the recommended option is seeded from `research.wizardInferences` and its description cites the inference evidence. `primaryTasks` is a separate `multiSelect`, pre-checked from inferred `primaryWork`
- [ ] **Exchange 2 (cold asks)** — `autonomyLevel` is **always asked cold** (`always-ask` / `balanced` / `autonomous`), never pre-filled from research; project description is presented as editable free-form text; pain points are three free-form prompts (`timeSinks` / `errorProne` / `automationWishes`) with a skip option
- [ ] **Exchange 3 (tuning cards + detection)** — each presented as an overridable card with its default pre-selected:
  - [ ] **Step 1** Advanced hook events — when overridden, the 9 events render thematically (lifecycle / user / tool) as `multiSelect` groups; for judgment-capable events (`UserPromptSubmit`, `Stop`, `TaskCreated`, `TaskCompleted`, `Elicitation`) the per-event execution-type picker shows the cost table (shell / prompt / agent / http) before asking; choosing `http` triggers the data-leaves-the-machine confirmation
  - [ ] **Steps 2 / 3 / 4** Skill / agent / output-style tuning cards default to `{ mode: "defaults" }`; accept or tune
  - [ ] **Step 5** Ecosystem plugins — each shown with `[installed]` / `[not installed]` marker (e.g. `notify`)
  - [ ] **Step 6 + Step 7 combined** — LSP plugins AND built-in skills issued as **two `multiSelect` questions in ONE `AskUserQuestion` call**. `typescript-lsp` pre-checked (≥10 .tsx files); the 4 core built-in skills (`/loop`, `/simplify`, `/debug`, `/pr-summary`) pre-checked; `/schedule` visible (`.github/workflows/` present)
- [ ] **No preset selection, no Custom path, no mid-wizard escape hatch** appears anywhere in the wizard — those were the v2 model
- [ ] **Summary** shows everything gathered including a `Model: <model-id> (<source>)` line, and announces the full preview before anything is written

### Phase 4 — Plugin Detection & Context

- [ ] Plugin detection probes **both** sibling installs and the marketplace cache; detected plugins are listed ("These will be integrated into your generated CLAUDE.md and quality-gate hooks"), or "No Claude Code plugins detected" if none
- [ ] The build-v3-context step assembles the single context object and runs its validation; if validation fails the run refuses to dispatch and surfaces the offending field (no partial generation)

### Phase 5 — Plan → Preview → HARD GATE

- [ ] Generation runs in **plan mode first** — a `generationManifest` is computed (`changes[]` + `decisions` + `warnings`) and **nothing is written**
- [ ] A preview is rendered via `walkthrough:render` to `.claude/walkthrough/<date>-onboard-plan.html`. If walkthrough is absent, an install offer appears (Install now / Skip — markdown preview); a render failure degrades to the **markdown gate** (Overview · What I learned · What I'll build by tier · Key decisions · Risks) — the gate itself never degrades
- [ ] The gate is an **AskUserQuestion** (header `Generate?`): `Approve & generate (Recommended)` / `Adjust` / `Cancel`
- [ ] **Confirm nothing is on disk yet** — no `.claude/` artifacts beyond the research dossier + walkthrough preview exist before you Approve
- [ ] **Adjust path** (optional): choosing `Adjust` returns to the wizard summary to revise, then re-runs context → plan → preview → gate (the gate loops). No artifacts written during the loop
- [ ] Approve to continue

### Phase 6 — Generation

After Approve, generation writes the artifacts. Verify them:

**Core tier:**
```bash
cat .claude/settings.json | jq '.hooks | keys'
ls .claude/rules/ .claude/skills/ .claude/agents/ 2>/dev/null
```
- [ ] Root `CLAUDE.md` exists (100–200 lines, maintenance header present)
- [ ] Hook events use the nested `hooks: [...]` array structure (not a flat `{ "type": "command" }` directly in the event array)
- [ ] If advanced hook types were chosen: at least one `"type": "prompt"`, `"type": "agent"`, or `"type": "http"` entry is present
- [ ] Path-scoped rules in `.claude/rules/` reflect the actual detected stack (not generic templates)
- [ ] 2–3 stack/pain-point-driven skills in `.claude/skills/`, each with valid frontmatter
- [ ] Agents in `.claude/agents/` each have YAML frontmatter with `tools:` and some of `model` / `isolation` / `color` / `effort`. Plugin-covered capabilities are skipped (e.g. no generic `code-reviewer.md` if a review plugin is installed)

**MCP (emission Step 1):**
```bash
cat .mcp.json | jq '.mcpServers | keys'
```
- [ ] Contains `context7` (always), `vercel` (vercel.json present), `prisma` (prisma/ present)
- [ ] `.claude/rules/mcp-setup.md` exists with auth instructions

**Output styles (emission Step 2):**
```bash
ls .claude/output-styles/ && head -10 .claude/output-styles/*.md
```
- [ ] At least one `.md` with `name:` + `description:` frontmatter; archetype matches a production-ops/team signal for this Vercel + team project

**LSP (emission Step 3):**
- [ ] `typescript-lsp` install attempted (`claude plugin list 2>/dev/null | grep typescript-lsp`); onboard emits NO project-level `.lsp.json`

**Built-in skills (emission Step 4):**
```bash
grep -A 20 'Built-in Claude Code skills' CLAUDE.md
```
- [ ] CLAUDE.md subsection (marker-delimited `<!-- onboard:builtin-skills:start/end -->`) lists the core skills with stack-specific examples

**Research-grounded generation (v3):**
- [ ] Generated CLAUDE.md / rules / skills / agents reflect **verified** research claims (sharpened from the dossier, not generic boilerplate)
- [ ] `docs/feature-list.json` is seeded from verified security/risk/test-gap claims (seed-if-absent — an existing list is never clobbered)

**Telemetry — `onboard-meta.json` (v3 self-audit keys):**
```bash
cat .claude/onboard-meta.json | jq 'keys'
cat .claude/onboard-meta.json | jq '{mcp:.mcpStatus.status, outStyle:.outputStyleStatus.status, lsp:.lspStatus.status, builtin:.builtInSkillsStatus.status, skill:.skillStatus.status, agent:.agentStatus.status, hook:.hookStatus.status}'
cat .claude/onboard-meta.json | jq '.wizardStatus'
cat .claude/onboard-meta.json | jq '.research'
cat .claude/onboard-meta.json | jq '{pluginVersion, currentPhase}'
```
- [ ] All 7 generation-phase status objects present: `mcpStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`, `skillStatus`, `agentStatus`, `hookStatus` — each with a `.status` field
- [ ] **`wizardStatus`** has **exactly the 5 canonical keys**: `presetUsed`, `exchangesUsed`, `phasesAsked`, `phasesSkipped`, `escapeHatchTriggered`
- [ ] `wizardStatus.presetUsed` is in `{minimal | standard | comprehensive}` — never `custom` / `quick-mode` / `interactive` (dropped v2 shapes)
- [ ] `wizardStatus.escapeHatchTriggered` is **always `false`** (escape hatch removed; key retained for shape stability)
- [ ] `wizardAnswers.selectedPreset` is in `{minimal | standard | comprehensive}`
- [ ] **`research` self-audit block** is coherent: `consumed: true`; `.claude/onboard-research.json` exists; `claimsVerified`, `claimsDropped`, `specialistsRun`, `artifactLocation`, `artifactsWritten` present; `artifactsWritten` paths match the on-disk docs for the recorded `artifactLocation`; `htmlRendered` non-null iff `walkthrough` was present at render time
- [ ] **`pluginVersion`** matches the installed onboard version (3.0.0+) — not a stale literal
- [ ] **`currentPhase` is `"done"`** after a complete run (set to `6` after Phase 6, flipped to `"done"` at Phase 7 — see Scenario E)

**Snapshot files:**
- [ ] `.claude/onboard-mcp-snapshot.json`, `-skill-snapshot.json`, `-agent-snapshot.json`, `-output-style-snapshot.json`, `-lsp-snapshot.json`, `-builtin-skills-snapshot.json` all exist

### Phase 7 — Handoff

- [ ] A handoff narration explains the key artifacts (CLAUDE.md, rules, skills, agents, hooks) and suggests stack/pain-point-based "try these first" items
- [ ] Next steps mention reviewing `docs/onboard/` research artifacts (or `.claude/onboard-research.json`), `/onboard:check`, and `/onboard:update`

### Session validation

- [ ] Close and reopen Claude Code in the project — session starts cleanly with no schema errors

---

## Scenario B: Fresh `/onboard:start` — Variant Projects

### test-python (Minimal profile)

```bash
cd $TMPDIR/release-gate-tests/test-python
claude
# Run: /onboard:start — choose the Minimal profile at Phase 2 profile-select
```

- [ ] Minimal profile → Phase 2 research dispatches **no specialists** and returns a minimal dossier quickly (the fast/cheap path); `research.consumed` may be `false`/minimal — meta records the research key accordingly
- [ ] Solo/relaxed archetype detected (no team/security/production signals)
- [ ] `.mcp.json` contains only `context7` (no vercel, no prisma, no chrome-devtools)
- [ ] Phase 3 Exchange 3: `pyright-lsp` appears as a candidate (may not be pre-checked with only 5 .py files)
- [ ] Format-only / minimal hook set generated (fewer events than the rich project)
- [ ] Output style maps to a solo/relaxed archetype (not production-ops)
- [ ] Session starts cleanly

### test-monorepo (Standard profile)

```bash
cd $TMPDIR/release-gate-tests/test-monorepo
claude
# Run: /onboard:start — choose the Standard profile
```

- [ ] Standard profile → Phase 2 dispatches Core-4 specialists + verify
- [ ] Subdirectory CLAUDE.md candidates offered for the packages (apps/web, apps/api, packages/) — each package is an automatic architectural-boundary candidate
- [ ] Phase 3 Exchange 3: `typescript-lsp` shown for the .ts files; multiple LSP candidates possible
- [ ] Complexity inferred as medium or higher (multiple packages)
- [ ] Session starts cleanly

### test-empty (Phase 0 edge case)

```bash
cd $TMPDIR/release-gate-tests/test-empty
claude
# Run: /onboard:start
```

- [ ] **Phase 0 fires** (`SRC_COUNT == 0`): the 3-option **AskUserQuestion** menu appears — `Abort` / `Placeholder only` / `Generate canonical stub` (default)
- [ ] Choosing **Generate canonical stub** writes exactly 3 files — `CLAUDE.md`, `.claude/settings.json`, `.claude/onboard-meta.json` — in canonical schema with stub-mode markers; all 7 generation-phase status keys are `status: "skipped"` with `reason: "stub-mode-no-code"`
- [ ] `pluginVersion` in the stub meta is resolved dynamically (no hardcoded literal)
- [ ] The stub run does **not** run the wizard, research, or full generation — and (per phase-tracking) creates **no** task list
- [ ] Re-running `/onboard:start` after adding source files **auto-promotes** the stub to a full run (overwrites stub artifacts; appends a `"stub → full"` `updateHistory` entry)
- [ ] Session starts cleanly

---

## Scenario C: Drift Lifecycle (update / evolve)

**Target:** `$TMPDIR/release-gate-tests/test-nextjs` (after Scenario A completed). Apply the standard drift mutations first:

```bash
cd $TMPDIR/release-gate-tests/test-nextjs
bash /path/to/claude-plugins/tests/release-gate/mutate-for-drift.sh
```

The mutations are: (1) delete a generated rule, (2) edit an agent's frontmatter, (3) edit an output-style body, (4) add `@anthropic-ai/sdk` to package.json, (5) add `src/main.rs`.

### C1: `/onboard:update` — artifact + signal drift

```bash
cd $TMPDIR/release-gate-tests/test-nextjs
claude
# Run: /onboard:update
```

**Approval flow:**
- [ ] The approval prompt is a **single AskUserQuestion call** (not inline "all / specific / none" text): a pre-question (`Review and pick` / `Apply all` / `Apply later` / `Skip`) plus per-group `multiSelect` questions in the same call
- [ ] Offer groups are categorized (`Artifact gaps`, `User-edit detections`, `New dependencies / languages`, `Best practice suggestions`); only groups with ≥1 offer render
- [ ] **Apply later**: choosing it writes `.claude/onboard-pending-updates.json` with a `pendingOffers[]` array. Re-running `/onboard:update` re-presents pending items merged with new drift; after applying, the snapshot file is deleted
- [ ] Any doc URLs fetched during update use `https://code.claude.com/docs/en/*`, not legacy `docs.anthropic.com/en/docs/claude-code/*`

**Per-mutation expectations:**
- [ ] **Mutation 1 (deleted rule)** — detected under `Artifact gaps`; on approval the rule file is regenerated/restored
- [ ] **Mutation 2 (edited agent frontmatter)** — classified as a `user-edit`; the change is **not** reverted (user edits preserved)
- [ ] **Mutation 3 (output-style body edit)** — **not** flagged (the body is outside snapshot scope)
- [ ] **Mutation 4 (`@anthropic-ai/sdk`)** — `/claude-api` flagged as a newly relevant built-in skill under `Best practice suggestions`
- [ ] **Mutation 5 (`src/main.rs`)** — `rust-analyzer-lsp` listed as a `newLanguage` candidate under `New dependencies / languages`, as a **first-class selectable option** (not narrative prose), **auto-checked by default** (matching the wizard LSP pre-check behavior)

**v3 re-research (staleness):**
- [ ] If the dependency/language changes constitute a staleness signal, `update` re-runs `onboard:research` scoped (auto-escalating to full when warranted), merges into the prior dossier, and regenerates **merge-aware** (customization floor honored — the user-edited agent from Mutation 2 is not clobbered)

### C2: `/onboard:evolve` — auto-apply

```bash
# With src/main.rs still present:
/onboard:evolve
```
- [ ] Evolve re-prompts for `rust-analyzer-lsp` via batched `multiSelect` (not a silent install)
- [ ] Evolve runs the scoped re-research path **silently** and defers full-escalation to `update`; after applying it shows a diff (evolve has **no** hard gate)

### C3: Plugin drift

```bash
claude plugin install superpowers
# Then: /onboard:update
```
- [ ] Update surfaces a "Plugin Drift" finding listing `superpowers`
- [ ] On approval, CLAUDE.md gains the marker-wrapped `## Plugin Integration` section; `onboard-meta.json.detectedPlugins.installedPlugins` includes `"superpowers"`

```bash
claude plugin uninstall superpowers
# Then: /onboard:update
```
- [ ] Update lists the removal; on approval the Plugin Integration markers are stripped and obsolete hooks/artifacts cleaned

### C4: `/onboard:adopt` — retrofit foreign tooling

On a project with hand-crafted (non-onboard) Claude config — e.g. a fresh repo where you manually create a `CLAUDE.md` + `.claude/rules/` without onboard:

```bash
# In a repo with hand-crafted CLAUDE.md / .claude/ but NO onboard-meta.json:
/onboard:start
# At Phase 1 "Existing config", choose Adopt (Recommended)
```
- [ ] The "Existing config" prompt offers `Adopt` / `Update` / `Start fresh` / `Cancel`; choosing **Adopt** runs the `adopt` skill
- [ ] Adopt synthesizes a `mode: "retrofit"` baseline: writes `onboard-meta.json` (each artifact tracked `origin: "adopted"` in `artifactProvenance`) + snapshots, but **never modifies a hand-crafted file**
- [ ] A subsequent `/onboard:update` treats adopted artifacts as diffable-with-caution and defers modernization (e.g. adding maintenance headers) to per-item approval

---

## Scenario D: CI & Audit Infrastructure

### D1: `/validate` from repo root

```bash
cd /path/to/claude-plugins
claude
# Run: /validate
```
- [ ] All checks pass (structure, manifests, references, ShellCheck)

### D2: Notify security hardening

```bash
# From a project with notify configured, trigger a Stop event (let Claude finish a task with notify hooks active)
```
- [ ] Notification fires; the session-start timestamp file is a regular file (not a symlink) at `$TMPDIR/claude-notify-session-start-$UID`

### D3: Tooling gap audit workflow

1. **GitHub → Actions → Tooling Gap Audit → Run workflow** (workflow_dispatch), branch `develop`, **Run workflow**.
- [ ] Phase 1 (Analyze) begins and completes — `.audit-data-<date>.json` appears in the commit
- [ ] Phase 2 (Report) completes — `<date>-gap-report.md` appears in the commit
- [ ] A PR opens against `develop` titled `chore(audit): tooling gap report <date>`, following the strict schema (Summary, Surface Snapshot, Coverage, Patterns, Gap List, Baseline Changes)

**No-change cycle:**
2. Re-trigger workflow_dispatch immediately.
- [ ] Workflow completes but no new PR opens (content identical to the previous report)

---

## Scenario E: Durable Phase Tracking

The v3 phase-tracking feature surfaces each phase as a durable `TaskCreate`/`TaskUpdate` task and supports checkpoint resume. Verify the live task transitions and the resume probe. Contract: `onboard/skills/start/references/phase-tracking.md`.

### E1: `/onboard:start` task list

On a fresh `/onboard:start` run (use `test-nextjs` before Scenario A, or a fresh clone), watch the task list (the in-session task panel):

- [ ] At Step 0, **8** tasks are created up front, all `pending`, with bare-slug subjects `empty-repo-check` … `handoff`
- [ ] `empty-repo-check` transitions to `completed` immediately (the guard ran/was skipped)
- [ ] Each subsequent phase task goes `in_progress` **before** its work begins (and before any agent/Skill dispatch) and `completed` after — exactly one task `in_progress` at a time
- [ ] The internal skills (`research`, `wizard`, `generate`) and the dispatched agents (`codebase-analyzer`, `config-generator`) create **no** tasks of their own — only the orchestrator transitions the list

### E2: HARD GATE task states

During Phase 5 (Plan → Preview → gate):
- [ ] While awaiting the gate decision, `plan-gate` stays **`in_progress`** (the enum has no "awaiting" state)
- [ ] **Approve** → `plan-gate` → `completed`, then Phase 6 runs
- [ ] **Adjust** → `plan-gate` stays `in_progress` (no status change) while the gate loops back to the wizard summary
- [ ] **Cancel** → `plan-gate`, `generation`, and `handoff` are all marked **`deleted`**; tasks 0–4 remain `completed`; **nothing is written to disk** and the run prints "Cancelled — no files were created."

### E3: `currentPhase` anchor in meta

```bash
cat .claude/onboard-meta.json | jq '.currentPhase'
```
- [ ] After Phase 6 generation returns, `onboard-meta.json.currentPhase` is the integer **`6`** (meta's first existence — the orchestrator, not the config-generator, writes it)
- [ ] After Phase 7 handoff completes, `currentPhase` is flipped to the string **`"done"`**
- [ ] On a **Cancel** run (E2), no `onboard-meta.json` is created at all (the gate precedes the only write phase) — there is no `currentPhase`

### E4: Resume / Restart on re-run

The cross-session resume anchor is the **durable on-disk artifacts**, not the task list.

- [ ] **Probe 2 (post-research resume)** — interrupt a run after Phase 2 research (so `.claude/onboard-research.json` exists but `onboard-meta.json` does NOT). Re-run `/onboard:start`: a two-option **AskUserQuestion** (header `Resume?`) offers `Resume (Recommended)` / `Restart`. Choosing **Resume** rehydrates `research` from the dossier and re-confirms the wizard from `research.wizardInferences` (it does NOT skip the wizard), then continues forward through context → plan-gate → generation
- [ ] **Probe 1 (generation-era resume)** — interrupt after Phase 6 but before Phase 7 (so `onboard-meta.json` has integer `currentPhase: 6`). Re-run `/onboard:start`: the same Resume/Restart offer appears; **Resume** finishes from Phase 7 Handoff
- [ ] **Done meta → no resume** — after a fully completed run (`currentPhase: "done"`), re-running `/onboard:start` does **not** offer Resume — it routes to the existing-config flow (Adopt / Update / Start fresh)
- [ ] **Restart** — choosing Restart marks leftover incomplete tasks `deleted`, creates a fresh list, and begins at Phase 0; a Restart that re-reaches Phase 6 is merge-aware (does not clobber user edits)
- [ ] **Cancel-resume guard** — a list whose gate-or-later tasks are `deleted` (the Cancel signature) does NOT trigger a resume offer on a same-session re-run (treated as a clean start)

### E5: update / evolve / adopt task lists

Each user-facing entry point owns its own task list; `start` uses bare slugs, the secondary three prefix the slug with the entry-point name:

- [ ] `/onboard:update` creates **8** tasks `update:verify-baseline` … `update:summary`; the gate task is `update:approve-gate` (stays `in_progress` while awaiting approval; Cancel → `5/6/7` `deleted`)
- [ ] `/onboard:evolve` creates **4** tasks `evolve:detect-drift` … `evolve:clear-entries`; **gateless** — every phase is a straight `in_progress → completed`, no `deleted`-on-cancel transition
- [ ] `/onboard:adopt` creates **6** tasks `adopt:detect-classify` … `adopt:write-handoff`; the gate task is `adopt:preview-gate`. When `adopt` is entered from `/onboard:update`'s missing-baseline guard, the two lists coexist and neither touches the other's tasks

---

## Sign-off

Once all scenarios pass:

| Scenario | Status | Notes |
|---|---|---|
| Phase 1 (automated) | [ ] Pass | `run-automated-checks.sh` — 242 checks green |
| A (nextjs start) | [ ] Pass | Comprehensive profile; full Phase 0–7 + telemetry. See `findings-phase2-nextjs-v2.md` |
| B-a (python) | [ ] Pass | Minimal profile. See `findings-phase3a-python-v2.md` |
| B-b (monorepo) | [ ] Pass | Standard profile. See `findings-phase3b-monorepo-v2.md` |
| B-c (empty) | [ ] Pass | Phase 0 stub + auto-promote. See `findings-phase3c-empty-v2.md` |
| C (drift: update/evolve/adopt) | [ ] Pass | Batched approval; auto-checked LSP; re-research. See `findings-phase4-drift-v2.md` |
| D (CI/audit) | [ ] Pass | See `findings-phase6-ci-audit-v2.md` |
| E (phase-tracking) | [ ] Pass | Task list, HARD GATE states, `currentPhase`, Resume/Restart |

**Release-ready:** all scenarios passed. Safe to merge develop → main (merge commit, never squash).

## Legend

- **Phase 0–7** — the `/onboard:start` flow phases (Empty-Repo Guard / Recon / Research / Grounded Wizard / Plugin Detection & Context / Plan→Preview→Gate / Generation / Handoff).
- **Profile** — Minimal / Standard / Comprehensive, chosen at the Phase 2 profile-select step; sets research depth + generation scope. There is no Custom profile and no Quick Mode in v3.
- **Exchange / emission Step** — the wizard runs Exchanges 1–3 (tuning cards as Steps 1–7); generation emits the catalog as emission Steps 1–4 (MCP / Output Styles / LSP / Built-in Skills).
- Scenario names (`nextjs` / `python` / `monorepo` / `empty` / `drift` / `ci-audit`) match the release-gate's own `setup-test-repos.sh` repos and `findings-*-v2.md` files — that is the test harness's structure, independent of onboard's phases.
