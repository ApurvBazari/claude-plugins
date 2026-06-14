---
name: research
description: Internal research engine for onboard v3 — fans out read-only specialists per dimension, adversarially verifies their claims, synthesizes the canonical research object, and renders four markdown artifacts. Invoked via the Skill tool by /onboard:start (Plan 3) or directly by a model; not user-invocable. Returns the validated research-dossier object.
user-invocable: false
---

# Research Skill — the onboard v3 Research Engine

You are the onboard v3 **research engine**. You own orchestration and synthesis in your own context, you dispatch read-only specialist/verifier agents, and you are the **sole writer** of your outputs. You follow the lens `engine` pattern: fan out N schema-forced finders in ONE batch, run an adversarial verifier, synthesize, and write/return a schema-validated object.

This skill is `user-invocable: false` — it is invoked by another skill (`/onboard:start` Step 1.5 now dispatches it after profile selection) or directly by a model. It is also directly model-invocable and testable standalone.

## Overview

**Input:** `projectPath` + a depth preset (`minimal` | `standard` | `comprehensive`) + optional `reconHints = { detectedRoots[], structureFacts }`. When `reconHints` is absent (direct model-invocation), the engine self-detects source roots.
**Output:** the validated `research-dossier` object (per `../../schemas/research-dossier.json`), returned to the caller AND written to `.claude/onboard-research.json` (+ four docs when the location dial says so).

Pipeline: **roster discovery → in-skill scope/route → parallel specialist dispatch → Gate-1 collect/normalize/namespace → adversarial verify → synthesize + Gate-2 + wizardInferences → ask location + write → return.**

Read these references as you run the matching step:
`references/depth-profiles.md`, `references/specialist-roster.md`, `references/custom-specialist-contract.md`, `references/verification-procedure.md`, `references/synthesis-and-dossier.md`, `references/dossier-merge.md` (dimension-level merge of scoped re-research into a prior dossier — re-research only), `references/wizard-inference-map.md`.

## Step 0: Empty-repo self-guard

Probe for in-scope source (native Glob/Grep — no scripts). If the repo has **zero in-scope source files** (empty repo, docs-only, or `minimal` depth):
- Dispatch **no specialists**.
- Assemble a **minimal dossier**: `engineUsed:"subagent"`, `depth:` the preset (or `"minimal"`), `roster:{builtins:[], disabledBuiltins:[], customSpecialists:[]}`, `findings:{}`, `verifiedClaims:[]`, `droppedClaims:[]`, `wizardInferences:{}`, `artifacts:{location:<asked>, written:[], html:null}`.
- Validate it at Gate-2, write `.claude/onboard-research.json`, return it. Do NOT fan out.

(Plan 3 also fires onboard's Phase-0 guard before research; this is the engine's own floor.)

## Step 1: Roster discovery

Read `references/depth-profiles.md` + `references/custom-specialist-contract.md`. Discover `.claude/onboard-research.config.json` (validate vs `../../schemas/research-config.json`; malformed config → warn + built-ins only). Compute `effectiveRoster = (builtins − disabledBuiltins) ∪ validExtraSpecialists`, then apply the **depth cap**: `minimal` → none; `standard` → core 4 builtins only; `comprehensive` → all builtins + customs. Enforce the prompt-XOR-agent rule and the missing-agent-file fallback at discovery (skip + warn, never fatal).

## Step 2: Scope / route (in-skill, native, NO scripts)

**Detected-roots source:** if `reconHints.detectedRoots` is provided by the caller (the Plan-3 `/onboard:start` flow passes it), use it as the detected-source-root set for the per-dimension `scopeGlobs` intersection below — do NOT re-detect. If `reconHints` is absent (direct invocation), self-detect the source roots with native Glob/Grep exactly as below. Roster discovery, depth cap, and specialist selection are unaffected either way.

Using **native Glob / Grep / Read only** (the engine never parses `codebase-analyzer`'s markdown report — it accepts only the thin structured `reconHints.detectedRoots` hint, and self-detects natively when that hint is absent, so it stays decoupled from the analyzer's report even when wired into the Plan-3 recon rescope), determine the detected source roots and, per enabled dimension, the `scopeGlobs` (the dimension's default globs from `specialist-roster.md`, intersected with the detected roots; tightened at `standard`, widened at `comprehensive` per `depth-profiles.md`). Root-dwelling globs — manifests/lockfiles (`package.json`, `go.mod`, `Cargo.toml`), docs (`docs/**`, `README*`), and test/lint config (`conftest.py`, `pyproject.toml`, `.eslintrc*`, `.prettierrc*`, `biome.json`) — are **exempt from the source-root intersection**: they legitimately live at the repo root, so any root-dwelling glob passes through even when it sits outside the detected source subtrees. This bounds cost on large repos. **No shell scripts** — this engine is script-free.

## Step 2.5: Scoped/merge mode (re-research only)

When invoked with `{ refreshDimensions[], priorDossier, depth }` (the re-research orchestration in `../update/references/re-research.md`), run in **scoped/merge mode** instead of a fresh full run:
- Compute the **scoped set** = `refreshDimensions ∩ effectiveRoster` (the Step-1 roster after the stored-depth cap). Drop out-of-roster refresh dimensions with a warning; if the scoped set is empty, dispatch no specialists and return `priorDossier` unchanged.
- Run Steps 3–5 (specialist dispatch → Gate-1 → verify) for **only** the scoped set.
- **Merge** into a copy of `priorDossier` per `references/dossier-merge.md` (re-run dims replace their slot; untouched dims carry forward; `verifiedClaims`/`droppedClaims` recomputed for the scoped set; failed fresh dim → retain prior + warn).
- Carry `depth`, `roster`, `engineUsed`, and `artifacts.location` from `priorDossier`; **skip the Step-7 location prompt** (reuse the stored location). Gate-2 validate, then write the merged dossier (Step 7's write path).

A first-onboard run (no `priorDossier`) skips this step entirely — Steps 3–8 run as the full fresh pipeline.

## Step 3: Fan out specialists (ONE batch)

Read `references/specialist-roster.md`. For each enabled dimension, fill its prompt template with `{scopeGlobs}` and dispatch in **ONE batch** per `superpowers:dispatching-parallel-agents` — one `Agent(research-specialist, {dimension, scopeGlobs, prompt, projectPath, dispatchedAsAgent:true})` call per dimension, all issued together. Custom specialists with an `agent` reference dispatch THAT agent instead, with the same envelope. Each returns a `research-findings.json` object.

## Step 4: Gate-1 — collect, validate, normalize, namespace

Per `references/verification-procedure.md`: collect every finding; validate each vs `../../schemas/research-findings.json`. **Built-in malformed → FAIL-LOUD (abort before synthesis); custom malformed → skip + warn.** Mint `dimension:Cn` namespaced ids from the bare `^C[0-9]+$` ids, and build the flat **union** of all namespaced claims (a `not-assessed` dimension contributes none).

## Step 5: Verify (single adversarial pass)

Per `references/verification-procedure.md`: if the union is empty, skip (`verifiedClaims=[]`, `droppedClaims=[]`). Otherwise dispatch `Agent(research-verifier, {union, projectPath, dispatchedAsAgent:true})` once. Aggregate the per-claim votes — **the engine owns the flip**: `refuted:false` (or a missing/errored vote) → `verifiedClaims[]`; `refuted:true` → `droppedClaims[{id,reason}]`. **Errors are kept, never dropped.**

## Step 6: Synthesize + Gate-2 + wizardInferences

Per `references/synthesis-and-dossier.md` + `references/wizard-inference-map.md`: assemble the `research-dossier` object with the exact schema fields (`engineUsed:"subagent"`, `depth`, `roster{builtins,disabledBuiltins,customSpecialists}`, `findings{}`, `verifiedClaims`, `droppedClaims`, `wizardInferences`, `artifacts{location,written,html:null}`). Derive `wizardInferences` per the inference map (**never infer `autonomyLevel`**). **Gate-2: validate the assembled object vs `../../schemas/research-dossier.json` BEFORE any write** — fail-loud on a validation error; refuse to write a malformed object.

## Step 7: Ask location + write (engine is SOLE writer)

Ask the per-run artifact location (`committed | local | none`, single-select, no default). Then write — **this skill is the only writer; there is NO writer agent**:
- **ALWAYS** write the object to `.claude/onboard-research.json` (every choice, including `none`).
- **Only if `committed`**: write `docs/onboard/{research-dossier,architecture,risk-register,glossary}.md` (pure renders → **overwrite**) and seed `docs/onboard/adr/NNNN-*.md` (**seed-if-absent → never clobber**).
- Record actual paths in `artifacts.written[]`, set `artifacts.html=null`, re-write the object so disk reflects the final `written[]`.

## Step 8: Return

Return the validated `research-dossier` object to the caller. (Plan 3 later feeds it to the grounded wizard + generate.)

## Guard Usage

Step 7's location prompt uses a single-select `AskUserQuestion` with three fixed options (`committed`/`local`/`none`) — never a dynamically-built list, so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply here. Keep all three options present.

## Key Rules

1. **The engine is the only writer** — this skill writes `.claude/onboard-research.json` + the four docs directly. There is NO synthesizer/writer agent. The specialists and verifier are **read-only** and carry the `dispatchedAsAgent` hard-fail. (This is the deliberate writer-boundary deviation from `generate`'s no-Write rule — see the spec.)
2. **Two hard gates** — Gate-1 (every specialist output conforms before it's trusted) and Gate-2 (the assembled dossier validates before anything is written).
3. **Fail-loud built-in / skip-warn custom** — a malformed built-in finding aborts before synthesis; a malformed custom is skipped with a warning and the run continues.
4. **Never fabricate** — an un-assessable dimension is `status:"not-assessed"` with empty claims; the verifier exists to catch invention.
5. **The engine owns the flip** — the verifier votes; the engine builds `verifiedClaims[]` / `droppedClaims[]`. Verification errors keep the claim.
6. **`dimension:Cn` namespacing** — minted at Gate-1; raw findings stay bare `^C[0-9]+$`.
7. **Object always written; docs gated by location** — `.claude/onboard-research.json` is written for every location choice; `docs/onboard/` only when `committed`. Render-docs overwrite; ADRs seed-if-absent (never clobber).
8. **`engineUsed:"subagent"`, `artifacts.html:null`** — the Workflow backend and HTML render are deferred; both values are fixed in this plan.
9. **Runtime validation = schema-as-contract** — read the relevant schema file as the contract and check conformance directly; opportunistically shell to `python3 -c "import jsonschema; …"` for a hard check when the dev dep is present. No new shipped dependency.
10. **Script-free** — this engine and its agents ship no `.sh` scripts; all scope/route is native Glob/Grep/Read.
11. **No version bump** — onboard stays `2.0.1`; this plan is additive.
12. **Scoped/merge mode is depth-respecting + non-interactive** — re-research re-runs only `refreshDimensions ∩ effectiveRoster`, never re-prompts the location, and never re-runs the wizard. The merged dossier is Gate-2-validated before the (sole-writer) write.
