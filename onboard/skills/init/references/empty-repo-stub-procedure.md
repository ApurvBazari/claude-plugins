# Empty-Repo Stub Procedure

Canonical procedure for generating a minimal, canonical-shape `.claude/` stub when `/onboard:init` runs on a repo with no source code. Invoked by `init/SKILL.md` § Phase 0 (Empty-Repo Guard) after the developer picks option 3 ("Generate canonical stub") from the Phase 0 menu.

## Why this reference exists

Before Cluster 2 (2026-04-18), `/onboard:init` on an empty repo was intercepted by Claude *before* entering the init skill. Claude improvised a 3-option menu and emitted 3 files ad-hoc. The stub had four problems (2026-04-17 release-gate findings B14, B15, B16):

- **B14**: `onboard-meta.json` used a 4th distinct schema with zero top-level keys in common with the canonical shape. Downstream consumers (verify scripts, `/onboard:update`, `/onboard:evolve`) couldn't reason about it.
- **B15**: The stub hardcoded `version: "1.0.0"` regardless of installed onboard version.
- **B16**: The init skill's own empty-path behavior was never tested because the skill never ran for empty repos.

This procedure closes all three by moving the logic INTO the init skill (Phase 0 Empty-Repo Guard) and prescribing the exact canonical-shape output.

## Invocation

Called from `init/SKILL.md` § Phase 0 Empty-Repo Guard, after:

1. The guard detected no source files (`SRC_COUNT == 0` via the documented `find` filter)
2. The developer selected option 3 ("Generate canonical stub") from the 3-option `AskUserQuestion` menu
3. The developer has been told what will happen next

Do NOT invoke this procedure from any other context — the Phase 0 guard is the only legitimate entry point.

## Output artifacts

Exactly 3 files land on disk. All paths relative to the project root.

### 1. `CLAUDE.md` (project root)

A minimal placeholder CLAUDE.md with every section marked as pending. Clear status banner explaining this is a stub and what to do next.

```markdown
<!-- onboard:maintained version=<dynamic> generated=<ISO-date> -->

# <project-name> — Stub configuration

> **Status**: Stub configuration generated for an empty repository. Re-run `/onboard:init` after scaffolding to produce the full AI tooling setup.
>
> **For scaffolding + onboarding in one step**: run `/forge:init` instead — it creates a project from a template AND generates the full tooling.

## Project overview

**Tech stack**: _To be detected after scaffolding._

**Project structure**: _To be captured once a layout exists._

**Primary tasks**: _To be determined based on project type._

## Working notes for Claude

While this project is empty:

- Ask clarifying questions before creating files — don't invent a stack or framework
- Confirm file locations before writing (the layout is unsettled)
- Reference `/forge:init` if the developer mentions wanting a scaffold
- Re-run `/onboard:init` after at least one source file exists, so the full analysis + wizard can run

## Next steps

1. Add source code (or run `/forge:init` for guided scaffolding)
2. Re-run `/onboard:init` to produce the full tooling setup
3. Once tooling is generated, the `## Working notes for Claude` section above will be replaced with the project-specific setup.

<!-- onboard:maintenance-end -->
```

Use the project's directory name as `<project-name>` (`$(basename "$PWD")`). Replace `<dynamic>` with the resolved plugin version (see § Dynamic version resolution below). Replace `<ISO-date>` with the current UTC date in `YYYY-MM-DD` format.

### 2. `.claude/settings.json`

Minimal valid JSON with no hooks wired in. The file exists so session-start doesn't error on missing settings:

```json
{
  "hooks": {}
}
```

Create the `.claude/` directory if absent. Do not add placeholder hooks — they would fire with no backing scripts and surface misleading errors.

### 3. `.claude/onboard-meta.json` — canonical-shape stub

**The load-bearing artifact.** Every top-level key matches the canonical schema so downstream consumers don't need stub-mode branching. All 7 Phase 7 status blocks emit `status: "skipped"` with a stub-specific reason. `wizardStatus` follows the canonical 5-subkey shape (see `../../wizard/SKILL.md § Key Rule 7`).

```jsonc
{
  "pluginVersion": "<dynamic>",
  "_generated": { "by": "onboard", "version": "<dynamic>", "date": "<ISO-date>" },
  "timestamp": "<ISO-8601 UTC timestamp>",
  "source": "onboard:init",
  "mode": "stub-empty-repo",

  "wizardAnswers": {},
  "wizardStatus": {
    "presetUsed": "stub-empty-repo",
    "exchangesUsed": 0,
    "phasesAsked": [],
    "phasesSkipped": [
      "phase0", "phase1", "phase2", "phase3",
      "phase4", "phase5", "phase5.0", "phase5.1", "phase5.1.1",
      "phase5.2", "phase5.3", "phase5.4", "phase5.5",
      "phase5.6", "phase5.7", "phase6"
    ],
    "escapeHatchTriggered": false
  },

  "hookStatus":          { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [{ "event": "*", "reason": "stub-mode-no-code" }], "warnings": [] },
  "skillStatus":         { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [] },
  "agentStatus":         { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [] },
  "mcpStatus":           { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "autoInstalled": [], "autoInstallFailed": [] },
  "outputStyleStatus":   { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [] },
  "lspStatus":           { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "autoInstalled": [], "autoInstallFailed": [] },
  "builtInSkillsStatus": { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [], "detectionSignals": {} },

  "generatedArtifacts": [
    "CLAUDE.md",
    ".claude/settings.json",
    ".claude/onboard-meta.json"
  ],

  "nextSteps": [
    "Add source code, then re-run /onboard:init",
    "Or: /forge:init for scaffold + onboard in one step"
  ]
}
```

## Dynamic version resolution

**Do NOT hardcode a literal version string.** Resolve the current onboard version at runtime using the same pattern forge's `tooling-generation/SKILL.md § Step 1` uses:

```bash
ONBOARD_VERSION=""

# 1. CLI-first: prefer the official Claude Code CLI when available
if command -v claude >/dev/null 2>&1; then
  ONBOARD_VERSION=$(claude plugins info onboard --format json 2>/dev/null | jq -r '.version // empty')
fi

# 2. Plugin-root fallback: read the manifest directly
#    (init lives inside onboard, so ${CLAUDE_PLUGIN_ROOT} resolves to onboard's root)
if [ -z "$ONBOARD_VERSION" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  ONBOARD_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
fi

# 3. Hard-fail if neither resolved — do NOT write a stub with pluginVersion: null
if [ -z "$ONBOARD_VERSION" ]; then
  echo "ERROR: Cannot resolve onboard plugin version. Reinstall onboard: claude plugins install onboard" >&2
  exit 1
fi
```

Substitute `$ONBOARD_VERSION` everywhere `<dynamic>` appears in the output schemas above. Closes release-gate finding B15.

## Timestamp format

- `timestamp` field → ISO-8601 UTC timestamp with seconds precision: `2026-04-18T14:30:00Z`
- `_generated.date` → UTC date only: `2026-04-18`
- CLAUDE.md maintenance header `generated=` → UTC date only: `2026-04-18`

Use the current time at invocation. Do not read from external time services — any discrepancies with system clock are acceptable.

## Write order

Write files in this order to minimize partial-state exposure on interrupt:

1. `mkdir -p .claude` (if absent)
2. `.claude/onboard-meta.json` first — downstream tools key off its presence
3. `.claude/settings.json` next — session hooks
4. `CLAUDE.md` last — user-facing document

Use atomic writes where possible (`write-to-tmp-then-rename`). On write failure for any artifact, do NOT retry silently — surface the error to the developer with recovery guidance:

> Stub write failed for `<path>`: `<error>`
>
> Recovery: check write permissions on the project root and `.claude/` directory, then re-run `/onboard:init`. No partial state was committed.

## Post-write handoff

After all three files land, return to the init skill for the Phase 4 handoff. Present a minimal handoff message:

> **Stub configuration generated.**
>
> Created:
> - `CLAUDE.md` (placeholder with working-notes for Claude)
> - `.claude/settings.json` (empty hooks object)
> - `.claude/onboard-meta.json` (canonical schema, stub mode, `pluginVersion: <version>`)
>
> **Next steps:**
> 1. Add source code (or run `/forge:init` for guided scaffolding + full tooling in one step)
> 2. Re-run `/onboard:init` to produce the full AI tooling setup once source files exist

Do NOT run Phase 4's full education/handoff content — the stub has nothing to educate about. Skip straight to this short message and return control.

## Edge cases

1. **Repo already has `.claude/onboard-meta.json` from a prior stub run** — Phase 0 guard detects it via `jq -r '.mode // empty'`. If the value is `"stub-empty-repo"`:
   - If `SRC_COUNT` is still 0: offer re-stub (rare — user ran init twice on empty dir). Default: no-op (stub already exists, exit quickly).
   - If `SRC_COUNT > 0` (source code was added since the stub): **auto-promote** to the full flow — skip Phase 0, run Phase 1 Analysis → Phase 2 Wizard → Phase 3 Generation. The full generation overwrites the stub artifacts. Append an `updateHistory` entry to the new `onboard-meta.json` noting the stub→full promotion.

2. **Repo has `.claude/onboard-meta.json` from a prior FULL run** — the Phase 0 guard doesn't fire at all (SRC_COUNT > 0 means Phase 0 falls through to Phase 1). Existing Step 1.1 of Phase 1 already handles the "existing config, choose: Update / Start fresh / Cancel" flow.

3. **Repo has `.gitignore` + `README.md` + `LICENSE` but NO source files** — `SRC_COUNT == 0` (the detector filter excludes these files). Phase 0 fires; stub is the default. README content can be referenced as placeholder context in the generated CLAUDE.md if the developer requests it (but by default, the stub doesn't read READMEs — keep the stub strictly minimal).

4. **Write permissions denied** on `.claude/` or project root — hard-fail at Step 1 of write order; surface the error verbatim. Don't attempt fallback locations.

5. **`jq` missing from PATH during version resolution** — the CLI path requires jq for JSON parsing. If jq is missing, fall through to Step 2 (read plugin.json with a basic bash parse):

   ```bash
   # Fallback parse without jq
   ONBOARD_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
     "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" | \
     head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
   ```

## Key rules

1. **Canonical schema is mandatory** — every top-level key in the `onboard-meta.json` target matches the canonical shape. Downstream consumers must NOT need to branch on stub vs full mode, except to read the top-level `mode: "stub-empty-repo"` marker when they specifically want to.
2. **All 7 Phase 7 status blocks emit `status: "skipped"`** with `reason: "stub-mode-no-code"` — the pre-exit self-audit (config-generator's) accepts `"skipped"` per the existing enum. Do NOT use `"documented"` here; stub mode produces no artifacts for any phase.
3. **Dynamic version resolution is not optional** — hard-fail the stub if the onboard version cannot be resolved. Never write `pluginVersion: null` or a hardcoded literal. Closes B15.
4. **Re-entry into full init is auto-promoted** — when a prior stub is detected and SRC_COUNT > 0, the guard falls through to Phase 1 without re-asking. Users don't have to delete the stub before adding code.
5. **Three files, in this order, atomic writes** — nothing else is emitted; no snapshots, no subdirectory CLAUDE.md files. Stub mode is minimal by design.
