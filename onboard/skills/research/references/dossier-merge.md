# Dossier Merge — Scoped Re-Research Into a Prior Dossier (v3)

Loaded by `../SKILL.md` **only in scoped/merge mode** — a re-research run that refreshes a subset of dimensions and merges them into the prior dossier. On first onboard the engine writes a fresh dossier and never loads this file. Merge mode is invoked by the re-research orchestration (`../../update/references/re-research.md`) with `{ refreshDimensions[], priorDossier, depth }`, where `priorDossier` is the current `.claude/onboard-research.json`.

## Scoped set

The dimensions actually re-run = `refreshDimensions ∩ effectiveRoster`, where `effectiveRoster` is the Step-1 roster after the stored-depth cap (`minimal`→none, `standard`→the 4 core dims `architecture`/`data-model`/`testing`/`security`, `comprehensive`→all 7). A refresh dimension outside the effective roster is **dropped** (the project's depth excludes it) and recorded in the run warnings. If the scoped set is empty, dispatch **no** specialists and return the prior dossier unchanged.

## Merge rules (dimension-level)

Run the normal Step 3–5 pipeline (specialist dispatch → Gate-1 → adversarial verify) restricted to the scoped set, then merge into a COPY of the prior dossier:

1. **Re-run dimension** → replace `findings[dim]` wholesale with the fresh finding. Bare `Cn` ids are freshly minted and re-namespaced `dim:Cn` at Gate-1 as usual.
2. **Untouched dimension** → carry forward `findings[dim]` verbatim from the prior dossier.
3. **`verifiedClaims` / `droppedClaims`** → drop every entry whose `dim:` prefix is in the scoped set (the stale ids), then add the fresh scoped-set verified/dropped ids. Carried-forward dimensions' entries stay untouched.
4. **Per-dimension gate (degrade)** → if a fresh dimension fails Gate-1 validation (malformed `research-findings.json`), do NOT merge it: retain the prior dimension's `findings[dim]` + its prior verified/dropped ids, and record a warning. The merged dossier stays Gate-2-valid.
5. **`depth`, `roster`, `engineUsed`** → carried from the prior dossier verbatim (re-research never changes the project's depth or roster shape).
6. **`wizardInferences`** → refresh only the inferences derived from re-run dimensions (per `wizard-inference-map.md`); carry the rest. **Never** re-run the grounded wizard (no re-prompt).
7. **`artifacts.location`** → carried from the prior dossier — **NO re-prompt** (the SKILL Step-7 location ask is skipped in merge mode, keeping `evolve` non-interactive).

## Write

Gate-2 validate the merged dossier, then write `.claude/onboard-research.json` atomically (`.tmp` + rename) — the engine stays the sole writer. When `artifacts.location === "committed"`, re-render the four `docs/onboard/*.md` docs (overwrite) from the merged dossier; for `local`/`none`, only the object is written. This is the one rewrite of the on-disk dossier after first onboard.

## Full re-research (escalated)

When the orchestration escalated to full, every in-roster dimension is in the scoped set → the merge degenerates to a full replace (no dimension carried forward). Same write path.
