<!-- Extracted from generation/SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Output Styles — Phase 7b

Follow `references/output-styles-guide.md` for archetype inference, frontmatter schema, and `settings.local.json` merge rules. Follow `references/output-styles-catalog.md` for the 5 body templates.

**When to run**: After Phase 7a (MCP) and before Hooks are merged. Phase 7b runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — wizard answer** | `wizardAnswers.outputStyleTuning` present with `mode: "tuned"` | Use wizard's archetype override + activation default. Run Step 6 batched confirmation unless headless. |
| **Path B — internal generation default** | wizard absent OR `mode: "defaults"` | Infer top-priority archetype from signals (Steps 1+3). Emit catalog defaults + snapshot + telemetry `status: "emitted"`. **No silent no-op.** |
| **Path SUPPRESS — tuning disabled** | `callerExtras.disableOutputStyleTuning === true` | Same as Path B but skip Step 6 batched confirmation entirely. Artifacts ARE generated. Telemetry: `outputStyleStatus: { status: "emitted", source: "inferred", ... }`. |
| **Path DECLINED** | wizard `archetypeOverride === "skip-emit"` | No file written. Telemetry: `outputStyleStatus: { status: "declined", reason: "skip-emit-selected" }`. |
| **Path NO-CANDIDATES** | candidate set empty after Steps 1+2 | No file written. Telemetry: `outputStyleStatus: { status: "skipped", reason: "archetype-not-fired" }`. |

**Inputs**:
- `analysis.*` — existing wizard + analysis signals (teamSize, projectMaturity, primaryTasks, securitySensitivity, deployFrequency, painPoints, project description)
- `wizardAnswers.outputStyleTuning` (optional) — `{ mode, archetypeOverride?, activationDefault? }`. Treat absence as `{ mode: "defaults" }`
- `callerExtras.disableOutputStyleTuning` (optional, headless) — see Path SUPPRESS above

**Telemetry contract**: `outputStyleStatus` MUST be present in `onboard-meta.json` after every generation. The SUPPRESS-PROMPT-ONLY family (`disableOutputStyleTuning`) MUST NOT collapse to `status: "skipped"` — that's the SKIP-PHASE family's behavior, and Phase 7b has no SKIP-PHASE flag.

**Step 1 — Classify firing archetypes.** Evaluate the 5 firing conditions from `output-styles-guide.md` § Archetype inference. Record the full firing set — even archetypes that won't be chosen — in `outputStyleStatus.planned[]` for telemetry.

**Step 2 — Apply wizard override.** Read `wizardAnswers.outputStyleTuning.archetypeOverride`:

| Override value | Effect |
|---|---|
| absent / `"inherit"` | Use Step 1 firing set unchanged; pick top priority in Step 3 |
| `onboarding` / `teaching` / `production-ops` / `research` / `solo` | Force that archetype as the sole candidate, regardless of Step 1 firing set. Mark `source: "user-tweaked"` |
| `"skip-emit"` | Record `outputStyleStatus.skipped = [{ reason: "skip-emit-selected" }]`; exit Phase 7b without emitting any file. Do NOT populate snapshot. Do NOT touch settings.local.json |

**Step 3 — Resolve priority.** From the candidate set produced by Steps 1+2, apply priority: `production-ops > onboarding > teaching > research > solo`. Emit ONLY the top match. If the candidate set is empty (no archetype fired, no override), record `outputStyleStatus.skipped = [{ reason: "archetype-not-fired" }]` and exit without emission.

**Step 4 — Pre-existing file check.** Probe `.claude/output-styles/` for a file matching the target filename (e.g., `operator.md` for `production-ops`). If present:
- Do NOT overwrite
- Add the filename stem to `outputStyleStatus.existedPreOnboard[]`
- Do NOT write a snapshot entry for this style
- Skip Steps 6–8 for this style
- Continue to Step 9 (telemetry) so the skip is visible

**Step 5 — Compose frontmatter.** Combine catalog defaults from `output-styles-catalog.md` with internal tracking fields:

| Field | Source |
|---|---|
| `name` | Filename stem (e.g., `operator`) |
| `description` | Catalog description verbatim (no project substitution) |
| `keep-coding-instructions` | `true` (all 5 archetypes) |
| `archetype` | The chosen archetype string |
| `source` | `inferred` (Step 1+3 only), `wizard-default` (`tuned` mode with `inherit` override), `user-tweaked` (explicit override), `user-confirmed` (accepted in Step 6 batched confirmation) |

**Step 6 — Batched confirmation.** Present a single `AskUserQuestion` with:
- One row showing: archetype, target path, activation default
- Options: **Accept** (default), **Override archetype** (re-prompt with the 7-option archetype list), **Skip emit** (record `{reason: "user-declined-confirmation"}` and exit)

**Headless passthrough**: when `callerExtras.disableOutputStyleTuning` is `true`, skip Step 6 entirely and emit with the Step 5 frontmatter as-is. Mirrors the `callerExtras.disableMCP` and `callerExtras.disableSkillTuning` patterns.

**Step 7 — Write the style file.** Emit `.claude/output-styles/<name>.md` with the frontmatter from Step 5 followed by the catalog body template. Project-specific markers (`<angle-bracket>` placeholders) are filled from `analysis.*`; drop the parent sentence when a marker can't be filled cleanly.

**Step 8 — Write drift snapshot.** Write (or create if absent) `.claude/onboard-output-style-snapshot.json` with ONE entry per emitted style. Snapshot tracks frontmatter fields only — body edits never trigger drift. Pure JSON, no maintenance header. Multi-run accumulation: append, never prune (see `output-styles-guide.md` § Snapshot contract § Multi-run accumulation).

```jsonc
{
  "operator": {
    "name": "operator",
    "description": "Terse production voice for security-sensitive and infrastructure-critical work...",
    "keep-coding-instructions": true,
    "archetype": "production-ops",
    "source": "inferred"
  }
}
```

**Step 9 — Apply `settings.local.json` merge** (only if `wizardAnswers.outputStyleTuning.activationDefault === "write-to-settings"`). Apply the 4-case merge from `output-styles-guide.md` § settings.local.json merge rules:

| Case | Action | Telemetry |
|---|---|---|
| File missing | Warn, do NOT create | `settingsLocalWritten: false`, `settingsLocalWarning: "file-missing"` |
| Key absent | Read-modify-write: add `"outputStyle": "<emitted-name>"`, preserve all other keys | `settingsLocalWritten: true`, `settingsLocalWarning: null` |
| Key present, same value | No-op | `settingsLocalWritten: false`, `settingsLocalWarning: "already-set-to-same"` |
| Key present, different value | Block, warn | `settingsLocalWritten: false`, `settingsLocalWarning: "conflict:<existing-value>"` |

Invariants: never create `settings.local.json` from scratch, never overwrite an existing `outputStyle` value, write value as a JSON-quoted string (strict JSON).

**Step 10 — Populate `outputStyleStatus`.** Add to `onboard-meta.json` alongside `mcpStatus` and `skillStatus`:

```jsonc
{
  "outputStyleStatus": {
    "planned": ["operator"],
    "generated": ["operator"],
    "skipped": [],
    "frontmatterFields": {
      "operator": {
        "name": "operator",
        "description": "...",
        "keep-coding-instructions": true,
        "archetype": "production-ops",
        "source": "inferred"
      }
    },
    "activationDefault": "none",
    "settingsLocalWritten": false,
    "settingsLocalWarning": null,
    "existedPreOnboard": [],
    "warnings": []
  }
}
```

**`skipped[].reason` values**: `user-declined-confirmation` | `archetype-not-fired` | `skip-emit-selected` | `caller-disabled`.
**`source` values**: `inferred` | `wizard-default` | `user-confirmed` | `user-tweaked`.
**`settingsLocalWarning` values**: `null` | `"file-missing"` | `"already-set-to-same"` | `"conflict:<existing-value>"`.

**Step 11 — Post-emit stdout summary.** Print a terse block: the emitted style, activation default, any settings.local.json warning, any pre-existing file we preserved. Keep it under 5 lines — most of the useful detail lives in `onboard-meta.json`.
