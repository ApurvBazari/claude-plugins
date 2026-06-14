# Re-Research Orchestration — Staleness Detection + Merge-Aware Re-Grounding (v3)

Shared by `../SKILL.md` (`onboard:update`) and `../../evolve/SKILL.md`. Split into two sections: **§ Detection** is read-only and is ALSO consumed by `../../check/SKILL.md`; **§ Orchestration** writes and is consumed by `update`/`evolve` only.

When a materially-changed codebase invalidates the research dossier, re-run `onboard:research` fresh (scoped or full), merge it into the prior dossier, and regenerate merge-aware so the tooling reflects what the code now is. **Absent a staleness signal, this whole path is skipped** and `update`/`evolve` behave exactly as today (snapshot replay).

## § Detection (read-only)

### Drift → dimension map

Each caller already categorizes raw drift (check Step 4; update Step 3 / 4b; evolve Step 1). Map the categorized drift to the research dimensions it invalidates (names are the `../../research/references/specialist-roster.md` built-ins):

| Categorized drift signal | Invalidated dimension(s) |
|---|---|
| new / removed dependency | `dependencies`, `security` |
| new top-level module / directory | `architecture`, `conventions` |
| config strictness change (tsconfig / eslint) | `conventions` |
| test-structure change (>20% test-file Δ) | `testing` |
| new security-relevant surface (auth / crypto / secret-handling paths) | `security` |
| data-model / schema / migration files added | `data-model` |
| major framework version bump | `architecture`, `dependencies`, `conventions` |

**Depth-cap intersection:** intersect the mapped set with the project's effective roster at its stored depth (`onboard-meta.json.research.depth` / recorded profile: `minimal`→none, `standard`→`architecture`/`data-model`/`testing`/`security`, `comprehensive`→all 7). A mapped dimension outside that roster is dropped (the project's depth excludes it). If the intersected set is empty → **no staleness to re-ground** (report nothing; in `update` note "deepen the profile to ground this", in `evolve` skip silently).

### Escalation rule (scoped → full)

Escalate to a full re-research when ANY of: ≥ 3 distinct dimensions implicated · a major framework version bump · ≥ 2 new top-level modules. Otherwise scoped to the intersected set. Output `{ dimensions[], escalatedToFull }`.

## § Orchestration (writes — update / evolve only)

1. **Decide** (caller-specific):
   - `update` → present the re-ground offer in the Step-6 menu ("Re-ground research: N dimensions", or "full re-research" when escalated); proceed only on approval. On decline → today's snapshot path (no re-research).
   - `evolve` → if NOT escalated, proceed silently (scoped). If escalated → do **NOT** run; surface "Significant drift — run `/onboard:update` to re-ground research" and leave the pass (defer).
2. **Re-research** — invoke `Skill(onboard:research)` in scoped/merge mode with `{ refreshDimensions: dimensions, priorDossier: <.claude/onboard-research.json>, depth: <stored> }`. The engine runs only the scoped specialists, verifies, merges per `../../research/references/dossier-merge.md`, and writes the merged dossier. **Atomic abort:** if the engine fails, leave the prior dossier + tooling untouched, record a warning, and fall back to today's snapshot path — never a half-regrounded state.
3. **Build the v3 context** — use the `version: 3` construction in `drift-application.md` § Artifact gap regeneration, EXCEPT:
   - include the **merged `research`** object (the just-written dossier),
   - set `callerExtras.reResearch = { dimensions, escalatedToFull }`,
   - do **NOT** set `callerExtras.regenerateOnly` (this is a full consume, not a snapshot replay).
   This satisfies `generate` Step 0.1's D2 (research present) and selects the 4b consume path + the 4c merge-aware regen.
4. **Generate** — invoke `Skill(onboard:generate)` with that context. `generate` threads `research` + the `reResearch` marker to `config-generator`, which re-sharpens all artifacts honoring the customization floor + marker surgery (`../../generation/references/re-research-merge.md`) and merges the verify backlog (`../../generation/references/verify-backlog-seeding.md`).
5. **Report** — surface the refreshed dimensions, the backlog merge counts, and any warnings (dropped out-of-roster dimensions, customization conflicts). `metadata.research` (+ the 4c fields) is written by `config-generator` (dispatch contract — `update`/`evolve` do not write it).
