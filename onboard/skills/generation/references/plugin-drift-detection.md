# Plugin Drift Detection

Shared procedure for detecting drift between a project's prior plugin baseline and currently-installed plugins. Used by `onboard:update` (Step 4b), `onboard:evolve` (Step 0), and `onboard:generate` (probe fallback when `callerExtras.installedPlugins` is absent).

Application rules (CLAUDE.md section markers, hook scaffolding, autonomyLevel downgrade) live in `../../evolve/references/plugin-integration-rules.md`. This document is scoped to **detection and diff** only.

## Baseline Resolution

Each caller resolves the baseline `previousPlugins` list using the first source that exists:

| Caller | Baseline order |
|---|---|
| `update` | 1. `.claude/onboard-meta.json.detectedPlugins.installedPlugins` (always populated by init/generate since v1.2.0, regardless of `pluginSource`) → 2. `.claude/onboard-meta.json.callerExtras.installedPlugins` (legacy pre-v1.2.0 projects) → 3. `.claude/forge-meta.json.generated.toolingFlags.installedPlugins` → 4. empty |
| `evolve` | 1. `.claude/forge-meta.json.generated.toolingFlags.installedPlugins` → 2. skip step entirely (evolve requires a forge baseline) |
| `generate` | Falls back to current-state probe only (no baseline diff — it's generating fresh) |

**Empty baseline**: if no baseline source exists, treat `previousPlugins` as `[]`. All currently-probed plugins become additions. Label the report section: "Plugin Integration not tracked before — all detected plugins offered as new additions."

## Probe Procedure

Follow `plugin-detection-guide.md` § Known Plugin Probe List — specifically the two-location probe (sibling + `~/.claude/plugins/cache/**`) that catches both dev-repo monorepo installs and marketplace installs. Also probe any plugin in `previousPlugins` that is **not** in the known catalog (custom/third-party plugins), applying the same two-location logic.

**`CLAUDE_PLUGIN_ROOT` unset or empty**: the cache-location probe still works (it keys off `$HOME`, not `CLAUDE_PLUGIN_ROOT`). Only the sibling probe is skipped. If BOTH locations yield zero hits across the catalog, fall back to "no plugins detected" (`currentPlugins = []`). Do not fail.

Build `currentPlugins` from successful probes.

## Diff Algorithm

```
added   = currentPlugins \ previousPlugins    # in current, not in previous
removed = previousPlugins \ currentPlugins    # in previous, not in current
unchanged = currentPlugins ∩ previousPlugins
```

If both `added` and `removed` are empty, there is no plugin drift. Callers should skip their drift-handling step.

## Output Schema

Every caller produces the same `driftReport` structure:

```jsonc
{
  "driftReport": {
    "baselineSource": "onboard-meta | forge-meta | caller-extras | none",
    "previousPlugins": ["superpowers", "commit-commands"],
    "currentPlugins":  ["superpowers", "commit-commands", "feature-dev"],
    "added":   ["feature-dev"],
    "removed": [],
    "coveredCapabilitiesNext": ["..."],  // derived from currentPlugins per plugin-detection-guide.md
    "qualityGatesNext":        { ... },  // derived from currentPlugins + autonomyLevel
    "phaseSkillsNext":         { ... }   // derived from currentPlugins
  }
}
```

Derivation rules for `coveredCapabilitiesNext`, `qualityGatesNext`, `phaseSkillsNext` come from `plugin-detection-guide.md` §§ coveredCapabilities Derivation, qualityGates Derivation, phaseSkills Derivation. Read `autonomyLevel` from `onboard-meta.json.wizardAnswers.autonomyLevel` (or `forge-meta.json.context.autonomyLevel` when that file is the baseline).

## Presentation

Callers surface the drift report to the developer before applying any changes. Recommended wording:

> **Plugin drift detected:**
>
> **Added**: [comma-separated, or "none"]
> **Removed**: [comma-separated, or "none"]
>
> I'll refresh the Plugin Integration section in CLAUDE.md and update quality-gate hooks to match. Do you want to proceed? (individual items can be approved/rejected in the findings report)

For empty-baseline runs, add the label from the Baseline Resolution section above.

## Application Hand-off

Once the developer approves the drift changes, the caller applies them by following `../../evolve/references/plugin-integration-rules.md`:

- Section Marker Template — wrap / unwrap the Plugin Integration section in CLAUDE.md
- Subsection Content Rules — which subsections render given the current plugin mix
- qualityGates / phaseSkills / coveredCapabilities Derivation — via the pointer into `plugin-detection-guide.md`

Hook script templates come from `hooks-guide.md` § Quality-Gate Hook Templates (same source used by init and evolve today — do not duplicate).

## Post-apply Persistence

After applying drift changes, update the appropriate metadata file:

- `onboard:update` → write `currentPlugins` to `.claude/onboard-meta.json.detectedPlugins.installedPlugins` (create the field if missing). Also refresh `detectedPlugins.coveredCapabilities`, `detectedPlugins.qualityGates`, `detectedPlugins.phaseSkills`, and `hookStatus`.
- `onboard:evolve` → write `currentPlugins` to `.claude/forge-meta.json.generated.toolingFlags.installedPlugins` and refresh the other toolingFlags fields per `evolve/SKILL.md` Step 2b.3.

Never fabricate a baseline — if there was none, do not invent one. Persist the new state so the next run has a comparison point.

## Key Rules

1. **Probe list is canonical** — `plugin-detection-guide.md` is the only source for known plugins and capability mappings. This document does not duplicate it.
2. **Baseline is advisory, not required** — missing baseline is a valid state. The diff becomes "all currently-installed → additions."
3. **Probe decides truth** — filesystem probe results override baseline entries for plugins renamed / uninstalled upstream.
4. **Application rules stay in plugin-integration-rules.md** — this document handles detection only. Do not restate content rules or marker semantics here.
5. **Never fabricate plugin references** — only reference plugins confirmed via probe in the current run.
