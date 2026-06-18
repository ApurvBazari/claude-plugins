<!-- Extracted from ../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Agent Frontmatter Emission

Every generated agent file carries YAML frontmatter. The generator computes the full surface — `name`, `description`, plus up to nine additional fields (`tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `effort`, `isolation`, `color`, `background`) — based on archetype inference, wizard-level defaults, and a per-agent developer confirmation step. `proactive` is not a frontmatter field; the convention is encoded via a `description` prefix per the archetype table.

**Step 1 — Classify each candidate into an archetype.** Use the agent's purpose description + generation rationale (team size, security signal, stack fit). Five archetypes live in `agents-guide.md` § Per-archetype defaults: `reviewer`, `validator`, `generator`, `architect`, `researcher`. Classification signals are documented in that table and must not be restated here. Ambiguous cases fall back to `researcher` and append an entry to `agentStatus.warnings` (`archetype-inference-fallback`).

**Step 2 — Compose archetype defaults with wizard tuning.** Read `wizardAnswers.agentTuning` (may be absent — treat absence as `{ mode: "defaults" }`):

| `agentTuning.mode` | Effect on archetype output |
|---|---|
| `defaults` (or absent) | Emit archetype values as-is. Wherever the archetype says `inherit` for `model` / `effort`, keep it literal so the final agent file omits the field (omitting preserves pre-feature behavior exactly). |
| `tuned` | Replace any `inherit` model/effort with `agentTuning.defaultModel` / `defaultEffort` (unless those are also `inherit`). Apply `preApprovalPosture` clamp: `minimal` forces `permissionMode: default` and keeps archetype `disallowedTools`; `standard` leaves archetype output untouched; `permissive` may add `permissionMode: acceptEdits` on generator only. Apply `defaultIsolation`: `worktree-for-generators` emits `isolation: worktree` on generator archetype only; `off` never emits `isolation`. |

Archetype-defined `disallowedTools` always win for semantic protection (reviewer/validator/architect/researcher never get `Write`/`Edit`, regardless of posture). Autonomy-level elevation (e.g. `autonomyLevel: "autonomous"`) may broaden `tools` but does not override `disallowedTools`.

**Step 3 — Validation pass (must run before Step 4).** Each computed frontmatter object must pass these checks; failures drop the offending field (never the whole agent) and append to `agentStatus.warnings`:

| Check | Action on fail |
|---|---|
| `color` in `{red, blue, green, yellow, purple, orange, pink, cyan}` | Drop field; warn `invalid-color-value` |
| `effort` in `{low, medium, high, max}` | Drop field; warn `invalid-effort-value` |
| `isolation` equals `worktree` or omitted (no other values accepted) | Drop field; warn `invalid-isolation-value` |
| `model` in `{sonnet, opus, haiku, inherit}` or a full model ID | Drop field; warn `invalid-model-value` |
| `permissionMode` in `{default, acceptEdits, auto, dontAsk, bypassPermissions, plan}` | Drop field; warn `invalid-permissionMode-value` |
| `isolation: worktree` requires a git repository | Drop field; warn `isolation-non-git-dir` |
| `name` matches the agent filename stem (kebab-case) | **Generation bug — fail the agent emission loudly** |
| `maxTurns` is a positive integer | Drop field; warn `invalid-maxTurns-value` |

**Step 4 — Batched confirmation (always runs).** Before writing any agent file, present a single table summarizing every candidate agent and its computed frontmatter. Use `AskUserQuestion` with options:

- **Accept all** — default. Guarantees internal generation (including `callerExtras.disableAgentTuning: true`) passes through without re-prompting.
- **Tweak agent N** — re-prompt only that agent's fields (which to change: model / effort / tools / disallowedTools / color / isolation / maxTurns / permissionMode). Other agents proceed with their accepted values. Mark tweaked fields `source: "user-tweaked"`.
- **Skip agent N** — record `agentStatus.skipped[] = [{ "agent": "<name>", "reason": "user-declined-confirmation" }]`. Skipped agents are not written, not snapshotted, and not included in `agentStatus.generated[]`.

**Programmatic passthrough**: when `callerExtras.disableAgentTuning` is `true`, skip Step 4 entirely and emit with the inferred-plus-tuned values. Record each agent's `frontmatterFields.<name>.source = "inferred"` or `"wizard-default"` per Step 2. This mirrors the `callerExtras.disableSkillTuning` escape hatch.

**Step 5 — Write agent files.** Emit only fields that have concrete values — never emit empty strings or empty lists. Omitted fields preserve pre-feature-equivalent behavior exactly and keep pre-upgrade fixtures byte-identical. The description prefix convention (for encoding `proactive` intent per the archetype table) is applied inline in the final description string, not as a separate field.

**Pre-write validation (HARD-FAIL)**: every agent file content MUST start with `---\n` AND contain at minimum `name:` and `description:` lines within the frontmatter block. The 2026-04-16 release-gate run produced 5 agents with 0 working frontmatter because this check did not exist. If the generated content is missing the frontmatter, **hard-fail** the generation rather than write a degraded markdown-sections-only file. See `agents-guide.md` § REQUIRED for the template.

**Step 6 — Write drift snapshot (re-read pattern).** After writing each agent file, re-read it from disk, parse the actual YAML frontmatter, and use THAT for the snapshot entry. Do not trust the in-memory string — the snapshot must match what landed on disk. If re-read parse fails (no `---`, malformed YAML, missing `name`/`description`), **hard-fail** — the file failed to write what was intended. Snapshot is `.claude/onboard-agent-snapshot.json` — pure JSON, no maintenance header, consumed by `onboard:update` / `onboard:evolve` as the drift baseline.

```jsonc
{
  "code-reviewer": {
    "tools": "Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)",
    "disallowedTools": "Write, Edit",
    "model": "sonnet",
    "effort": "medium",
    "color": "blue"
  },
  "security-checker": {
    "tools": "Read, Glob, Grep, Bash",
    "disallowedTools": "Write, Edit",
    "model": "haiku",
    "effort": "low",
    "color": "green",
    "maxTurns": 2
  }
}
```

**Step 7 — Populate `agentStatus`.** Add to `onboard-meta.json` alongside `hookStatus`, `mcpStatus`, and `skillStatus`:

```jsonc
{
  "agentStatus": {
    "planned": ["code-reviewer", "tdd-test-writer", "security-checker"],
    "generated": ["code-reviewer", "security-checker"],
    "skipped": [{ "agent": "tdd-test-writer", "reason": "covered-by-plugin:superpowers" }],
    "frontmatterFields": {
      "code-reviewer": {
        "tools": "Read, Glob, Grep, Bash(git diff:*), Bash(git log:*)",
        "disallowedTools": "Write, Edit",
        "model": "sonnet",
        "effort": "medium",
        "color": "blue",
        "source": "inferred"
      },
      "security-checker": {
        "tools": "Read, Glob, Grep, Bash",
        "disallowedTools": "Write, Edit",
        "model": "haiku",
        "effort": "low",
        "color": "green",
        "maxTurns": 2,
        "source": "user-tweaked"
      }
    },
    "existedPreOnboard": [],
    "warnings": []
  }
}
```

**`source` values** (per-agent provenance):

- `inferred` — archetype defaults only, wizard was in `defaults` mode.
- `wizard-default` — archetype defaults composed with `agentTuning.mode === "tuned"` values.
- `user-confirmed` — developer chose "Accept all" in Step 4 with at least one wizard-level override applied.
- `user-tweaked` — developer used "Tweak agent N" and edited at least one field. `onboard:update` preserves user-tweaked fields on regenerate.

**`existedPreOnboard`** lists agent filenames (without extension) that already existed on disk before this generation run. Those agents are never rewritten and never enter the snapshot — they're flagged so `onboard:update` can distinguish user-owned agents from generator-owned ones.

**`skipped.reason` values**:
- `user-declined-confirmation` — Step 4 "Skip agent N" choice.
- `covered-by-plugin:<plugin-name>` — the capability map in `#### Plugin-Aware Agent Generation` matched an installed plugin.
- `capability-not-needed` — archetype signal didn't fire for this project (e.g., security-checker skipped on `securitySensitivity: standard`).

**Scope reminder**: `agentStatus` tracks **only** agents emitted by this generator phase. Agents shipped by plugins (via plugin markets) and hand-authored agents that predate onboard are out of scope — the `existedPreOnboard` list names them but does not attempt to track their frontmatter state.
