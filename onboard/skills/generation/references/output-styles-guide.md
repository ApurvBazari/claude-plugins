# Output Styles Generation Guide

Output styles are project-scoped system-prompt modifiers that change how Claude Code responds session-wide. They live at `.claude/output-styles/<name>.md` (project) or `~/.claude/output-styles/<name>.md` (user). Claude Code ships three built-in styles that never need files; onboard Phase 7b emits project-specific custom styles.

This guide is the authoritative reference consumed by `generation/SKILL.md` § Phase 7b. For the 5 body templates, see `output-styles-catalog.md`.

---

## What output styles are (and aren't)

Per Claude Code docs (https://code.claude.com/docs/en/output-styles):

- **Output styles modify the system prompt**. They change role, tone, and format — not what Claude knows.
- **Built-in styles (Default / Explanatory / Learning)** are Anthropic-provided. They do NOT require files. They're selectable via `/config` out of the box.
- **Custom styles** are markdown files with YAML frontmatter + body. The body is appended to (or replaces, depending on `keep-coding-instructions`) Claude Code's default system prompt.
- **Activation** is via `/config` menu or by setting `outputStyle: "<style-name>"` in `.claude/settings.local.json`. Changes take effect on the next new session (prompt caching invariant).

**Not in scope for onboard**:
- Re-authoring built-in styles as files (users already have them)
- User-level styles at `~/.claude/output-styles/` (project-scoped only)
- Activation without explicit opt-in — we never force a style onto the user's session

---

## Archetype inference

Onboard classifies each project into one of 5 archetypes and emits the single matching custom style. Archetypes are inferred from signals the wizard already captures.

| Archetype | Firing conditions | Emitted file |
|---|---|---|
| `onboarding` | `teamSize` ≥ 5 AND `projectMaturity` is `new` — OR — `wizardAnswers.painPoints` mentions onboarding/new-contributor friction | `onboarding-mentor.md` |
| `teaching` | `primaryTasks` includes `"docs"` or `"teaching"` — OR — project description contains pedagogy signals (tutorial, course, workshop, docs-site) | `tutorial-guide.md` |
| `production-ops` | `securitySensitivity: "high"` — OR — `deployFrequency` ∈ `{"continuous", "multiple-per-day", "daily"}` | `operator.md` |
| `research` | `primaryTasks` includes `"research"` or `"exploration"` — OR — project description signals exploratory work (prototype, experiment, spike, lab) | `explorer-notes.md` |
| `solo` | `teamSize` ∈ `{"solo", "1"}` AND no other archetype fires | `solo-minimal.md` |

### Priority resolution

Multiple archetypes can fire on the same project (e.g., a 20-person team building a security-critical product). When that happens, the generator resolves in this fixed priority order and emits only the top match:

```
production-ops > onboarding > teaching > research > solo
```

Rationale:
- `production-ops` wins because security constraints are safety-critical and the operator persona is strictest
- `onboarding` next because large-team onboarding signals dominate other project characteristics
- `teaching` next because pedagogical output informs how all other work is framed
- `research` next because hypothesis framing shapes exploration but yields to the above
- `solo` is the fallback when no other signal fires

Record the full firing set in `onboardMeta.outputStyleStatus.planned` (for telemetry) and the chosen archetype in `generated`.

### No-archetype-fires case

If none of the 5 archetypes fire (rare — usually the `solo` fallback catches it), skip emission entirely. Record `outputStyleStatus.skipped[] = [{reason: "archetype-not-fired"}]` and reference only built-in styles in CLAUDE.md.

---

## Frontmatter schema

Emitted frontmatter follows the Claude Code spec plus two internal tracking fields.

| Field | Type | Required | Source | Purpose |
|---|---|---|---|---|
| `name` | string | **Yes** | Filename stem | Activation key — what the developer types in `/config outputStyle: <name>`. Must match the filename stem exactly. |
| `description` | string | **Yes** | Catalog | Shown in the `/config` picker. Emit the catalog description verbatim — no project-specific substitution. |
| `keep-coding-instructions` | boolean | no | Catalog (always `true` for our 5 archetypes) | When `true`, Claude Code's built-in software-engineering instructions are preserved alongside the custom style. When `false` (default per Anthropic docs), coding instructions are stripped — use for non-engineering personas only. |
| `archetype` | string | no (internal) | Generator | Which of the 5 archetypes fired. Not consumed by Claude Code. Used by onboard's drift detector. |
| `source` | string | no (internal) | Generator | Provenance marker: `inferred` \| `wizard-default` \| `user-confirmed` \| `user-tweaked`. Not consumed by Claude Code. Used by onboard's drift detector to distinguish auto-emitted fields from developer overrides. |

Unknown frontmatter keys (`archetype`, `source`) are silently ignored by Claude Code, so they're safe to include.

### `source` values

- `inferred` — archetype inference fired, no wizard tuning, accept-all in batched confirmation
- `wizard-default` — wizard Phase 5.4 was in `tuned` mode but developer kept `archetypeOverride: "inherit"`
- `user-confirmed` — developer explicitly clicked Accept on the batched confirmation
- `user-tweaked` — developer overrode archetype in Phase 5.4 or tweaked during batched confirmation

---

## `settings.local.json` merge rules

When `wizardAnswers.outputStyleTuning.activationDefault` is `"write-to-settings"`, Phase 7b merges `outputStyle: "<emitted-name>"` into the project's `.claude/settings.local.json`. The file is strict JSON (same format as `.claude/settings.json` per `hooks-guide.md` § Settings Merge Strategy).

Four precise cases:

| Case | Condition | Action | `settingsLocalWritten` | `settingsLocalWarning` |
|---|---|---|---|---|
| 1. File missing | `.claude/settings.local.json` does not exist | Surface warning: "settings.local.json not found; outputStyle not written. Create the file manually and add `outputStyle: \"<name>\"` to activate." Do NOT create the file. | `false` | `"file-missing"` |
| 2. Key absent | File exists, `outputStyle` key absent from parsed JSON | Read-modify-write: add `outputStyle: "<emitted-name>"` as a new top-level key, preserve all other fields verbatim | `true` | `null` |
| 3. Key present, same value | File exists, `outputStyle` already equals the emitted name | No-op | `false` | `"already-set-to-same"` |
| 4. Key present, different value | File exists, `outputStyle` has a different value | Block write. Warn "outputStyle is already set to '<existing>' — skipping to avoid overwrite." | `false` | `"conflict:<existing-value>"` |

**Invariants**:
- `settings.local.json` is never created by onboard (Case 1 only warns)
- An existing `outputStyle` value is never overwritten (Cases 3 and 4 are no-ops)
- The value is emitted as a JSON-quoted string (strict JSON format)
- All other keys in the file are preserved byte-for-byte — only the `outputStyle` key is touched

**Rationale**: `settings.local.json` is typically gitignored and per-machine. Creating or overwriting it risks clobbering personal developer settings we can't see. Warnings surface in generation summary so the developer can act manually.

---

## Snapshot contract

After emission, Phase 7b writes `.claude/onboard-output-style-snapshot.json` as the drift baseline. Mirrors the skill/agent snapshot pattern.

### Shape

```json
{
  "<style-file-stem>": {
    "name": "<style-name>",
    "description": "<catalog-description>",
    "keep-coding-instructions": true,
    "archetype": "onboarding | teaching | production-ops | research | solo",
    "source": "inferred | wizard-default | user-confirmed | user-tweaked"
  }
}
```

Pure JSON. No maintenance header. One object per style filename stem.

### Scope: frontmatter only

The snapshot tracks **only** the frontmatter fields listed above. The body (system-prompt prose) is explicitly excluded — developers can freely edit the body and never trigger drift detection.

This mirrors the skill/agent 1.5.0/1.6.0 precedent and keeps the snapshot stable across body revisions.

### Multi-run accumulation

When a second run emits a different archetype (e.g., project grows from `solo` to `onboarding` after team expansion), the snapshot is **additive** — it keeps the previous entry and adds the new one:

```json
{
  "solo-minimal": { ... },        // from earlier run
  "onboarding-mentor": { ... }    // from this run
}
```

Drift detection runs against all entries. Developers who want to prune stale entries delete the file (and any unwanted style files) manually.

### Pre-existing files

Before writing, Phase 7b probes `.claude/output-styles/` for files that existed before the run. Pre-existing files are recorded in `outputStyleStatus.existedPreOnboard[]` and **never overwritten, never added to the snapshot**. They're considered user-owned and fall outside onboard's lifecycle.

---

## Drift state machine

`onboard:update` Step 4b.7 classifies each tracked style into one of 5 states by comparing the live file frontmatter against the snapshot:

| State | Condition | `update` behavior | `evolve` behavior |
|---|---|---|---|
| `new-field` | Snapshot omits a frontmatter field the current generator would now emit (e.g., a new internal field added in a future release) | Surface as addition candidate in Findings Report | Auto-apply — insert the missing field with archetype-inferred value, update snapshot, set `source: "user-confirmed"` |
| `user-edit` | Live frontmatter differs from snapshot (name / description / archetype / source / keep-coding-instructions changed) | Surface as informational — never auto-rewrite | Accept — update snapshot to match live, set `source: "user-tweaked"` |
| `missing-file` | Style file listed in `generated[]` but absent from disk AND not in `existedPreOnboard` | Offer regenerate | Auto-regenerate via `onboard:generate` with `callerExtras.regenerateOnly: [".claude/output-styles/<name>.md"]` and `callerExtras.disableOutputStyleTuning: true` |
| `legacy-no-frontmatter` | File exists but has no YAML frontmatter block (pre-1.7.0 manual file OR missing fields) | Surface migration prompt | Auto-migrate — prepend 5-field YAML block using catalog defaults for the matching archetype; preserve body intact; update snapshot; `source: "wizard-default"` |
| `in-sync` | Live frontmatter matches snapshot exactly | No action | No action |

Pre-existing files (`existedPreOnboard`) are excluded from all drift states — they're never touched.

---

## Interaction with built-in styles

Built-in styles (Default / Explanatory / Learning) are always available via `/config`. Onboard does three things with them:

1. **Never emit them as files**. Built-ins have no file representation.
2. **Reference them in generated CLAUDE.md**. The Plugin Integration § Output styles subsection lists all three built-ins with one-line descriptions and the activation path.
3. **Allow the developer to pick a built-in as the session default** via `outputStyle: "Explanatory"` or `"Learning"` in `.claude/settings.local.json`. Onboard does NOT set this automatically — the wizard only offers to write the emitted *custom* style's name to settings.local.json.

---

## Generation flow summary

```
Phase 7b (Output Styles)
  1. Classify archetype(s) from existing wizard + analysis signals
  2. Apply wizard.outputStyleTuning.archetypeOverride if set
     - "inherit"     → use inferred top priority
     - <archetype>   → force that archetype (even if its firing condition didn't match)
     - "skip-emit"   → record skipped[{reason: "skip-emit-selected"}]; exit early
  3. Resolve priority; select top match
  4. Probe .claude/output-styles/ for existedPreOnboard
     - If target filename already exists → add to existedPreOnboard; do NOT overwrite; skip emission
  5. Compose frontmatter from catalog + internal fields
  6. Batched confirmation (unless callerExtras.disableOutputStyleTuning)
     - Show: archetype, path, activation default
     - Options: Accept / Override archetype / Skip emit
  7. Write style file (frontmatter + catalog body)
  8. Write snapshot entry to .claude/onboard-output-style-snapshot.json
  9. If activationDefault == "write-to-settings": apply 4-case merge
 10. Populate onboardMeta.outputStyleStatus
```

---

## Generation guidelines

1. **Emit exactly one style per run** — the top-priority archetype match. Never emit multiple.
2. **Never overwrite pre-existing files**. Use `existedPreOnboard` as the guard. This matches skill/agent/MCP precedent.
3. **Always populate `outputStyleStatus`** in `onboard-meta.json` — even in no-emit cases (skipped, archetype-not-fired). Telemetry is load-bearing for the drift contract.
4. **Reference built-ins in CLAUDE.md**, not in emitted files. Users already have the built-ins.
5. **Respect the headless escape hatch**. When `callerExtras.disableOutputStyleTuning: true`, skip batched confirmation entirely; emit with inferred + wizard-default values. This is the forge path.
6. **Never touch settings.json** (shared). Only settings.local.json (personal). outputStyle is a per-machine preference by Claude Code's design.
7. **Validate frontmatter before writing**. `name` must be lowercase-hyphen (matches filename stem). `archetype` must be one of the 5. `source` must be one of the 4 values. `keep-coding-instructions` must be boolean.
