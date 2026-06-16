---
name: adopt
description: Bring a repo's existing hand-crafted Claude tooling under onboard management — synthesizes an onboard baseline (retrofit-mode meta + snapshots) WITHOUT modifying any hand-crafted file, so /onboard:update works afterward. Use only when the user explicitly invokes /onboard:adopt, or when start/update route here.
disable-model-invocation: true
---

# Adopt Skill — Retrofit Foreign Claude Tooling

You are running the onboard adopt skill. It brings a project's **pre-existing, hand-crafted** Claude tooling under onboard management by synthesizing a baseline — `onboard-meta.json` (`mode:"retrofit"`) plus snapshots — so `/onboard:update` can manage it. **Adopt never modifies a hand-crafted file.** It writes only the baseline; all modernization is deferred to `/onboard:update`, per-item approved.

This skill may be entered three ways: directly (`/onboard:adopt`), from `/onboard:start`'s existing-config branch (the **Adopt** option), or from `/onboard:update`'s missing-meta guard (offer adopt → continue into drift detection). When entered from update, after A6 hand back control to update's drift detection.

## Overview

Tell the developer:

> Adopting your existing Claude tooling — I'll catalog what you already have, research your codebase to ground the baseline, confirm a few preferences, then show you a full preview before writing anything. **I won't touch your hand-crafted files** — I only record a baseline so `/onboard:update` can manage them going forward.

## Step A1: Detect & classify the existing surface

Follow `references/detection-and-classification.md`. Enumerate the tooling surface (native Glob/Read, read-only), classify each artifact, and apply the redirect guards:
- no CLAUDE.md and no `.claude/` tooling → redirect to `/onboard:start`, stop.
- `.claude/onboard-meta.json` already present → redirect to `/onboard:update`, stop.

Present a short catalog to the developer:

> I found this existing tooling:
> - [category counts, e.g. "1 CLAUDE.md, 3 rules, 2 skills, 1 agent, .mcp.json, 2 hooks"]
>
> None of these will be modified. I'll research your codebase next.

## Step A2: Recon + Research (Full depth)

1. **Recon** — spawn the `codebase-analyzer` agent (per `../../agents/codebase-analyzer.md`), exactly as `start` Step 1.2. Keep its report + `reconHints` in context.
2. **Research** — dispatch the research engine at **Full depth**:

```
Skill(onboard:research, args: <stringified { projectPath: <cwd>, depth: "comprehensive", reconHints: <from recon> }>)
```

The engine fans out specialists, verifies, synthesizes the dossier, asks the artifact location, writes `.claude/onboard-research.json` (+ docs per that choice), and returns the validated `research-dossier`. Keep it in context — A3 reads `research.wizardInferences`; A4 embeds the `research` telemetry; A5 renders it.

> Researching your codebase in depth to ground the baseline — read-only.

## Step A3: Grounded wizard

Run the `wizard` skill (the grounded confirm/override surface), seeded by `research.wizardInferences`, exactly as `start` Step 2. `autonomyLevel` is asked cold (never inferred). Returns the canonical `wizardAnswers` + `wizardStatus`.

## Step A4: Catalog → synthesize baseline (in context, writes nothing)

Follow `references/baseline-synthesis.md` § A4. Build, in context:
- the **record-set** — one `changes[]` entry per detected artifact (`action:"record"`, `origin:"adopted"`);
- the **`onboard-meta.json`** object (`mode:"retrofit"`, `artifactProvenance` all-adopted, per-category `status:"adopted"` blocks, the `research` telemetry block, `wizardAnswers`/`wizardStatus`, `detectedPlugins`);
- the **snapshots** (current state as the baseline).

Nothing is written in this step.

## Step A5: Assemble previewModel + hard gate

Assemble `previewModel` per `../research/references/render-adapter.md § previewModel` with:
- `flow: "adopt"`;
- `research` = architecture map + top risks + glossary from the A2 dossier (null only if research returned a minimal/empty dossier);
- `changes` = the A4 record-set;
- `decisions` = `{ model: <resolved>, autonomy: wizardAnswers.autonomyLevel, profile: "retrofit", hooks: [...detected hook events], mcp: [...detected servers], lsp: [...detected plugins], pluginIntegration: [...detectedPlugins] }`;
- `warnings` = e.g. "N artifacts have no maintenance header — they'll be offered for modernization on your next `/onboard:update`."

Then render + hard-gate exactly like `start` Step 2.9:

1. **Render.** Map `previewModel` → a walkthrough `session-model` per the render-adapter, then invoke `walkthrough:render` with `{ model, outputPath: ".claude/walkthrough/<YYYY-MM-DD-HHMM>-onboard-adopt.html" }`.
   - **walkthrough absent** → offer install via AskUserQuestion (single-select, header `"Walkthrough"`): **Install now (Recommended)** / **Skip — markdown preview**. Install now → `claude plugin install walkthrough@apurvbazari-plugins` via Bash; re-probe; success → render; failure → markdown fallback.
   - **Skip / failure / runtime render error** → **markdown gate**: present `previewModel` inline as markdown (Overview · What I learned · What I'll record grouped by tier · Key decisions · Risks). Optionally also write `.claude/onboard-adopt-plan.md`.
   - This degrades the HTML render only — never the gate.
2. **Gate.** AskUserQuestion (single-select, header `"Adopt?"`):
   - **Approve & adopt (Recommended)** → proceed to Step A6 (write baseline).
   - **Adjust** → return to Step A3 (revise wizard answers), then re-run A4 → A5.
   - **Cancel** → stop. Write nothing. Print: "Cancelled — no baseline was written; your tooling is untouched."
3. Only **Approve** advances to A6.

**Guard Usage:** the install offer and the gate both use fixed-option single-selects (≥2 options), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

## Step A6: Write baseline only + handoff

Follow `references/baseline-synthesis.md` § A6: write the snapshots + `onboard-meta.json`, then patch `onboard-research.json`'s `artifacts.html` to the A5 render path (or leave null on markdown fallback). **Touch no hand-crafted artifact.**

Then hand off:

> Adopted. I recorded a baseline (`.claude/onboard-meta.json` `mode:"retrofit"` + snapshots) for your existing tooling — **nothing you wrote was changed**.
>
> - Run `/onboard:update` to align your adopted tooling with the latest best practices. Adopted files are offered for modernization (e.g. adding maintenance headers) per-item — you approve each change.
> - Run `/onboard:check` for a health summary.

**If adopt was entered from `/onboard:update`'s guard:** do not print the standalone closing — instead fall straight into update's drift detection (update Step 2 onward), now that a baseline exists.

## Key Rules

- **Never modify a hand-crafted file** — adopt's only writes are the 6 snapshots + `onboard-meta.json` + the `onboard-research.json` html patch (see `references/baseline-synthesis.md` § A6). Reading, cataloging, snapshotting — never editing.
- **Everything is `origin:"adopted"`** — Managed stance; `artifactProvenance` is all-adopted. The `"user"` value is reserved for future stances, not produced here.
- **`action:"record"` only** — the record-set never proposes creating or modifying artifacts; modernization is a later `/onboard:update`.
- **Redirect, don't overwrite** — meta already present → `/onboard:update`; no tooling at all → `/onboard:start`. Adopt is only for foreign tooling.
- **The gate is hard** — Approve writes the baseline; Adjust re-plans; Cancel writes nothing. The HTML render may degrade to markdown, but the gate is never skipped.
- **Does not call `generate`** — adopt synthesizes and writes its own baseline; it never invokes the generation pipeline (that is what keeps hand-crafted files safe).
