# Re-Research Merge-Aware Generation (v3)

Loaded by `config-generator` (via `../SKILL.md § Re-Research Merge-Aware Generation (v3)`) **only when `callerExtras.reResearch` is present** — a re-research regen built by `onboard:update` / `onboard:evolve`, not a first onboard or a `regenerateOnly` snapshot replay. When the marker is absent, skip this entire reference — generate exactly as the non-re-research path does.

A re-research regen re-runs the whole generation order from the **merged** `research` dossier (so cross-cutting artifacts — root CLAUDE.md, the verify backlog — stay correct), but it MUST NOT clobber user customizations or remediation progress.

## Customization floor (load-bearing)

Before re-emitting any artifact listed in `onboard-meta.json.generatedArtifacts`, check its maintenance header:
- **Header intact** → onboard-owned → re-emit from the merged dossier (the 4b `research-consumption.md` sharpening rows apply).
- **Header removed / modified** → user-customized → do NOT clobber:
  - in an `update` (interactive) run → honor the merge/replace/skip choice `update` already gathered for user-customized files (Step 6 / Step 7).
  - in an `evolve` (auto-drain) run → **skip silently + warn** (push to `warnings[]`); never rewrite a hand-edited file.
- **Absent** from disk but in `generatedArtifacts` and not `deletedByUser` → re-emit (gap repair).

## Marker-delimited surgery

For `<!-- onboard:plugin-integration:start/end -->` and `<!-- onboard:skill-recommendations:start role="…"/end -->` regions, replace ONLY the content between markers; preserve everything outside verbatim. This is the same marker surgery `update`/`evolve` already use — re-research does not widen it.

## Verify-backlog

The backlog is **merged, not reseeded** — apply `verify-backlog-seeding.md` § Re-research merge (gated on the same marker). Identity is the pinned `sourceClaim` key (`verify-backlog-seeding.md` § `sourceClaim` provenance key — pinned algorithm): SHA-256-12 over the normalized statement + line-stripped evidence path, so a fresh claim matches its existing feature across edits.

## Telemetry

After the regen, complete the `metadata.research` block with the 4c re-research fields — see `config-generator` § Generation Order step 7.
