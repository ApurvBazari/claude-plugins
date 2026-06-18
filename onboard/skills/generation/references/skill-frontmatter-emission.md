<!-- Extracted from ../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Skill Frontmatter Emission

Every generated `SKILL.md` carries YAML frontmatter. The generator computes the full surface — `name`, `description`, `user-invocable` / `disable-model-invocation`, plus up to six additional fields (`allowed-tools`, `model`, `effort`, `paths`, `context`, `agent`) — based on archetype inference, wizard-level defaults, and a per-skill developer confirmation step.

**Step 1 — Classify each candidate into an archetype.** Use the draft description + generation rationale (pain point / stack / workflow gap). Five archetypes live in `skills-guide.md` § Per-archetype defaults: `research-only`, `scaffolder`, `reviewer`, `orchestrator`, `workflow-specific`. Classification signals are documented in that table and must not be restated here.

**Step 2 — Compose archetype defaults with wizard tuning.** Read `wizardAnswers.skillTuning` (may be absent — treat absence as `{ mode: "defaults" }`):

| `skillTuning.mode` | Effect on archetype output |
|---|---|
| `defaults` (or absent) | Emit archetype values as-is. Wherever the archetype says `inherit` for `model` / `effort`, keep it literal so the final `SKILL.md` omits the field (omitting preserves pre-feature behavior exactly). |
| `tuned` | Replace any `inherit` model/effort with `skillTuning.defaultModel` / `defaultEffort` (unless those are also `inherit`). Apply `preApprovalPosture` clamp to `allowed-tools`: `minimal` strips `Write`/`Edit`/`Bash(*)`, `standard` leaves untouched, `permissive` broadens `Bash(...)` scoping to detected runners (e.g., add `Bash(npm run *:*)`, `Bash(pnpm *:*)` for Node projects). |

**Step 3 — Validation pass (must run before Step 4).** Each computed frontmatter object must pass these checks; failures drop the offending field (never the whole skill) and append to `skillStatus.warnings`:

| Check | Action on fail |
|---|---|
| `context: fork` requires a non-empty `agent` that exists in `.claude/agents/` or `effectivePlugins` | Demote to no-fork (drop both fields); warn `context-agent-missing` |
| `paths` globs match at least one file in the repo today | Still emit; tag `skillStatus.frontmatterFields.<skill>.pathsWarning = "no-match"` (visible warning only; not a failure) |
| All keys are hyphenated canonical spelling | **Generation bug — fail the skill emission loudly** with a clear error. Underscore keys are silently ignored by Claude Code and must never be written. |
| `model` / `effort` values match the allowed enum | Drop the field; warn `invalid-<field>-value` |

**Step 4 — Batched confirmation (always runs).** Before writing any `SKILL.md`, present a single table summarizing every candidate skill and its computed frontmatter. Use `AskUserQuestion` with options:

- **Accept all** — default. Guarantees internal generation (including `callerExtras.disableSkillTuning: true`) passes through without re-prompting.
- **Tweak skill N** — re-prompt only that skill's fields (which to change: model / effort / allowed-tools / paths / context+agent). Other skills proceed with their accepted values. Mark tweaked fields `source: "user-tweaked"`.
- **Skip skill N** — record `skillStatus.skipped[] = [{ "skill": "<name>", "reason": "user-declined-confirmation" }]`. Skipped skills are not written, not snapshotted, and not included in `skillStatus.generated[]`.

**Programmatic passthrough**: when `callerExtras.disableSkillTuning` is `true`, skip Step 4 entirely and emit with the inferred-plus-tuned values. Record each skill's `frontmatterFields.<name>.source = "inferred"` or `"wizard-default"` per Step 2. This mirrors the `callerExtras.disableMCP` escape hatch in emission Step 1.

**Step 5 — Write `SKILL.md` files.** Emit only fields that have concrete values — never emit empty strings or empty lists. Omitted fields preserve pre-feature-equivalent behavior exactly and keep pre-upgrade fixtures byte-identical.

**Step 6 — Write drift snapshot.** Append `.claude/onboard-skill-snapshot.json` (or create it if absent) with the exact emitted frontmatter block per skill. Same pattern as `.claude/onboard-mcp-snapshot.json` — pure JSON, no maintenance header, consumed by `onboard:update` / `onboard:evolve` as the drift baseline.

```jsonc
{
  "react-component": {
    "allowed-tools": ["Read", "Grep", "Glob", "Write", "Edit"],
    "effort": "medium",
    "paths": ["src/components/**/*.tsx"]
  },
  "pr-summarizer": {
    "allowed-tools": ["Read", "Grep", "Glob", "Bash(git diff:*)", "Bash(git log:*)"],
    "model": "sonnet",
    "effort": "medium",
    "context": "fork",
    "agent": "code-reviewer"
  }
}
```

**Step 7 — Populate `skillStatus`.** Add to `onboard-meta.json` alongside `hookStatus` and `mcpStatus`:

```jsonc
{
  "skillStatus": {
    "planned": ["react-component", "pr-summarizer", "deploy-runner"],
    "generated": ["react-component", "pr-summarizer"],
    "skipped": [{ "skill": "deploy-runner", "reason": "user-declined-confirmation" }],
    "frontmatterFields": {
      "react-component": {
        "allowed-tools": ["Read", "Grep", "Glob", "Write", "Edit"],
        "effort": "medium",
        "paths": ["src/components/**/*.tsx"],
        "source": "inferred"
      },
      "pr-summarizer": {
        "allowed-tools": ["Read", "Grep", "Glob", "Bash(git diff:*)", "Bash(git log:*)"],
        "model": "sonnet",
        "effort": "medium",
        "context": "fork",
        "agent": "code-reviewer",
        "source": "user-tweaked"
      }
    },
    "existedPreOnboard": [],
    "warnings": []
  }
}
```

**`source` values** (per-skill provenance):

- `inferred` — archetype defaults only, wizard was in `defaults` mode.
- `wizard-default` — archetype defaults composed with `skillTuning.mode === "tuned"` values.
- `user-confirmed` — developer chose "Accept all" in Step 4 with at least one wizard-level override applied.
- `user-tweaked` — developer used "Tweak skill N" and edited at least one field. `onboard:update` preserves user-tweaked fields on regenerate.

**`existedPreOnboard`** lists skill directory names that already existed on disk before this generation run. Those skills are never rewritten and never enter the snapshot — they're flagged so `onboard:update` can distinguish user-owned skills from generator-owned ones.

**Scope reminder**: `skillStatus` tracks **only** skills emitted by this generator phase. Skills shipped by plugins (via plugin markets) and hand-authored skills that predate onboard are out of scope — the `existedPreOnboard` list names them but does not attempt to track their frontmatter state.
