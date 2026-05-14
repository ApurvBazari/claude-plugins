# Round 4 — Migration Notes

## For users on alpha.4 with an in-flight wizard

On next `/greenfield:pickup`, the wizard auto-migrates your state:

- `mode.depth = "heavy"` (matches alpha.4 implicit posture)
- `mode.coupling = "hybrid"` (safer than auto-loop for in-flight sessions — see below)
- `mode.domainFormat = "ddd-lite"` (lighter; you can upgrade explicitly)
- `phases.personas` + `phases.domainModel` marked as `not-yet-walked`
- `risks[]` initialized empty

The wizard prompts: "Round 4 added Personas + Domain phases. Resume current step, or run new phases retroactively?"

### Why default coupling=hybrid for migrated sessions?

In a cold-start wizard, auto-loop is the recommended default because every downstream phase from the start gets persona/entity iteration. For an in-flight session, switching to auto-loop retroactively would expand many already-completed phases — too much re-asking. Hybrid is the conservative choice; user can upgrade to auto-loop via `/greenfield:pickup → Adjust mode`.

## For users on alpha.4 with COMPLETED wizard (post-scaffold)

No automatic migration runs. `/greenfield:check` will flag missing `personas.html` + `domain-model.html` and offer to run those phases retroactively in `/greenfield:pickup`. The freshness hook still works on existing R1-R3 syntheses.

## For maintainers — schema break posture

Round 4 is the **first non-hard-cutover schema bump** since R2. It's purely additive:

- New top-level keys: `mode`, `risks`
- New phase blocks: `personas`, `domainModel`
- Extended phase block: `architecturalValidation.riskReconciliation`
- New optional field: `sourceRef` on dependency entries

alpha.4 wizard reads alpha.5 state file by IGNORING unknown keys. alpha.5 wizard reads alpha.4 state by running the migration shim. No data loss in either direction.

## Rollback path

If R4 needs to be reverted post-merge:

- Revert all R4 commits on `feat/greenfield-1.3`.
- `plugin.json` → `3.0.0-alpha.4`.
- alpha.5 state files: on next pickup with alpha.4 wizard, unknown keys silently dropped (lossy but non-corrupting — `risks[]`, `mode`, `personas`, `domainModel` data is lost; R1–R3 phase data is preserved).
- `marketplace.json` reverted to alpha.4 versions.
- Companion docs (`docs/greenfield-3.0-round4/`) can stay as historical reference.
